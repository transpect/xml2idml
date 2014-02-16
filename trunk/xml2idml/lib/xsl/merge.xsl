<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
  version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"
  xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/"
  xmlns:idPkg = "http://ns.adobe.com/AdobeInDesign/idml/1.0/packaging"
  xmlns:htmltable="http://www.le-tex.de/namespace/htmltable"
  xmlns:xml2idml="http://www.le-tex.de/namespace/xml2idml"
  xmlns:idml2xml  = "http://www.le-tex.de/namespace/idml2xml"
  xmlns:letex="http://www.le-tex.de/namespace"
  xmlns:css="http://www.w3.org/1996/css"
  xmlns:saxon="http://saxon.sf.net/"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="css letex xs xml2idml idml2xml"
  >

  <!-- collection()[1]/* is the /Document (expanded IDML template).
       collection()[2]/* is the /xml2idml:stories document (newly generated stories wrapped in idPkg:Story,
       and prolly some XMLElements around it which is later going to become an XMLStory)
       Please note that this won’t work standalone (outside XProc) since there is no default collection in plain Saxon. 
       -->

  <xsl:import href="http://transpect.le-tex.de/idml2xml/xslt/common-functions.xsl" />

  <!-- The old stories are expected to carry their names in conditional text (condition name: storytitle) -->
  <xsl:key name="xml2idml:story-by-name" match="Story[.//*[@AppliedConditions eq 'Condition/storytitle'][idml2xml:same-scope(., current())]]" 
    use="xml2idml:story-name-from-conditional-text(.)" />

  <xsl:key name="xml2idml:story-by-self" match="Story" use="@Self" />

  <xsl:function name="xml2idml:story-name-from-conditional-text" as="xs:string?">
    <xsl:param name="story" as="element(Story)" />
    <xsl:sequence select="normalize-space(
                            string-join(
                              $story//*[@AppliedConditions eq 'Condition/storytitle']
                                         [idml2xml:same-scope(., $story)]
                                          //Content,
                              ''
                            )
                          )" />
  </xsl:function>

  <xsl:variable name="stories-to-keep" as="element(Story)*" 
    select="key('xml2idml:story-by-name', collection()[2]/*/@xml2idml:keep-stories, collection()[1])
            union (: keep all Stories in MasterSpreads :)
            key('xml2idml:story-by-self', collection()[1]/Document/idPkg:MasterSpread/MasterSpread/TextFrame/@ParentStory, collection()[1])
              [not(xml2idml:story-name-from-conditional-text(.) = tokenize(collection()[2]/*/@xml2idml:keep-stories, '\s+'))]" />

  <xsl:function name="xml2idml:resolve-dependent-stories" as="element(Story)*">
    <xsl:param name="initial-stories" as="element(Story)*"/>
    <xsl:variable name="dependent-stories" as="element(Story)*" select="key('xml2idml:story-by-self', $initial-stories//@ParentStory, collection()[1])" />
    <xsl:choose>
      <xsl:when test="$dependent-stories">
        <xsl:sequence select="$initial-stories union xml2idml:resolve-dependent-stories($dependent-stories)"/> 
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$initial-stories"/> 
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:variable name="idPkg-stories-to-keep" as="element(idPkg:Story)*" 
    select="xml2idml:resolve-dependent-stories($stories-to-keep)/.." />


  <!-- The newly generated stories that are scheduled to flow into an existing TextFrame carry their name
       in the @StoryTitle attribute: -->
  <xsl:variable name="names-of-newly-generated-stories" as="xs:string*"
    select="collection()/xml2idml:stories//idPkg:Story/Story/@StoryTitle" />


  <xsl:template match="* | @* | processing-instruction()" mode="#default xml2idml:merge_newstories_inner">
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="@*, node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@*" mode="xml2idml:merge_newstories">
    <xsl:copy/>
  </xsl:template>

  <xsl:template match="Document" mode="#default">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current" />
      <xsl:apply-templates select="*" mode="#current" />
    </xsl:copy>
  </xsl:template>

  <xsl:template mode="#default"
    match="idPkg:Story[empty(. intersect $idPkg-stories-to-keep)]" />

  <xsl:template match="idPkg:Story[exists(. intersect $idPkg-stories-to-keep)]" mode="#default">
    <xsl:copy-of select="." copy-namespaces="no" />
  </xsl:template>

  <xsl:template match="idPkg:Story[
                         not(@src) (: Story in designmap.xml :)
                       ][last()]" mode="#default" priority="2">
    <xsl:choose>
      <xsl:when test="collection()/xml2idml:stories//idPkg:Story">
        <xsl:next-match/>
        <xsl:apply-templates select="collection()/xml2idml:stories//idPkg:Story" mode="xml2idml:merge_newstories" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="@*" mode="#current"/>
            <Story Self="{replace(tokenize(@xml:base, '/')[last()], '^Story_(.+)\.xml$', '$1')}">
              <xsl:copy-of select="collection()/xml2idml:stories/ParagraphStyleRange" copy-namespaces="no"/>
              <xsl:message select="'&#xa;&#xa;WARNING: No story in converted document found! Moving all paragraphs to last story in template.&#xa;'" terminate="no"/>
          </Story>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="idPkg:Story" mode="xml2idml:merge_newstories">
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="@*, node()" mode="xml2idml:merge_newstories_inner" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="idPkg:Story" mode="xml2idml:merge_newstories_inner" />

  <xsl:template match="TextFrame[idPkg:Story]" mode="xml2idml:merge_newstories_inner" >
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="@*" mode="#current" />
      <xsl:attribute name="ParentStory" select="idPkg:Story/Story/@Self" />
      <xsl:apply-templates mode="#current" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="Document/@StoryList" mode="#default">
    <xsl:attribute name="StoryList" select="(
                                              collection()[2]/xml2idml:stories//idPkg:Story
                                              union
                                              $idPkg-stories-to-keep
                                            )/Story/@Self" />
  </xsl:template>

  <xsl:template match="TextFrame/@ParentStory[. = key('xml2idml:story-by-name', $names-of-newly-generated-stories, collection()[1])/@Self]"
    mode="#default">
    <xsl:variable name="storytitle" as="xs:string?"
      select="xml2idml:story-name-from-conditional-text(
                key('xml2idml:story-by-self', ., collection()[1])
              )" />
    <xsl:attribute name="ParentStory" select="collection()/xml2idml:stories//idPkg:Story/Story[@StoryTitle = $storytitle]/@Self" />
  </xsl:template>

</xsl:stylesheet>
