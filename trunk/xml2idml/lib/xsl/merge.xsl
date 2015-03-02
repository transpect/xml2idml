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
       collection()[2]/* is the /xml2idml:document with following children:
                       xml2idml:stories: newly generated stories wrapped in idPkg:Story,
                       xml2idml:index (optional): newly generated Topic's wrapped in Index,
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
                          )"/>
  </xsl:function>

  <xsl:variable name="stories-to-keep" as="element(Story)*" 
    select="key('xml2idml:story-by-name', collection()[2]/*/@xml2idml:keep-stories, collection()[1])
            union (: keep all Stories in MasterSpreads :)
            key('xml2idml:story-by-self', collection()[1]/Document/idPkg:MasterSpread/MasterSpread//TextFrame/@ParentStory, collection()[1])
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
    select="collection()[2]/xml2idml:document/xml2idml:stories//idPkg:Story/Story/@StoryTitle" />


  <xsl:template match="* | @* | processing-instruction()" mode="#default xml2idml:merge_newstories_inner" priority="-1">
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
      <xsl:apply-templates select="Properties" mode="#current" />
      <xsl:apply-templates select="Language" mode="#current" />
      <xsl:apply-templates select="idPkg:Graphic" mode="#current" />
      <xsl:apply-templates select="idPkg:Fonts" mode="#current" />
      <xsl:apply-templates select="KinsokuTable" mode="#current" />
      <xsl:apply-templates select="MojikumiTable" mode="#current" />
      <xsl:apply-templates select="idPkg:Styles" mode="#current" />
      <xsl:apply-templates select="NumberingList" mode="#current" />
      <xsl:apply-templates select="NamedGrid" mode="#current" />
      <xsl:apply-templates select="MotionPreset" mode="#current" />
      <xsl:apply-templates select="Condition" mode="#current" />
      <xsl:apply-templates select="ConditionSet" mode="#current" />
      <xsl:apply-templates select="idPkg:Preferences" mode="#current" />
      <xsl:apply-templates select="LinkedStoryOption" mode="#current" />
      <xsl:apply-templates select="LinkedPageItemOption" mode="#current" />
      <xsl:apply-templates select="TaggedPDFPreference" mode="#current" />
      <xsl:apply-templates select="MetadataPacketPreference" mode="#current" />
      <xsl:apply-templates select="WatermarkPreference" mode="#current" />
      <xsl:apply-templates select="ConditionalTextPreference" mode="#current" />
      <xsl:apply-templates select="TextVariable" mode="#current" />
      <xsl:apply-templates select="idPkg:Tags" mode="#current" />
      <xsl:apply-templates select="Layer" mode="#current" />
      <xsl:apply-templates select="idPkg:MasterSpread" mode="#current" />
      <xsl:apply-templates select="idPkg:Spread" mode="#current" />
      <xsl:apply-templates select="Section" mode="#current" />
      <xsl:apply-templates select="DocumentUser" mode="#current" />
      <xsl:apply-templates select="CrossReferenceFormat" mode="#current" />
      <xsl:copy-of copy-namespaces="no"
        select="collection()[2]/xml2idml:document/xml2idml:index/node()"/>
      <xsl:apply-templates select="idPkg:BackingStory" mode="#current" />
      <xsl:apply-templates select="idPkg:Story" mode="#current" />
      <xsl:apply-templates select="HyperlinkPageDestination" mode="#current" />
      <xsl:apply-templates select="HyperlinkURLDestination" mode="#current" />
      <xsl:apply-templates select="HyperlinkExternalPageDestination" mode="#current" />
      <xsl:apply-templates select="HyperlinkPageItemSource" mode="#current" />
      <xsl:apply-templates select="Hyperlink" mode="#current" />
      <xsl:apply-templates select="idPkg:Mapping" mode="#current" />
      <xsl:apply-templates select="Bookmark" mode="#current" />
      <xsl:apply-templates select="PreflightProfile" mode="#current" />
      <xsl:apply-templates select="DataMergeImagePlaceholder" mode="#current" />
      <xsl:apply-templates select="HyphenationException" mode="#current" />
      <xsl:apply-templates select="ParaStyleMapping" mode="#current" />
      <xsl:apply-templates select="CharStyleMapping" mode="#current" />
      <xsl:apply-templates select="TableStyleMapping" mode="#current" />
      <xsl:apply-templates select="CellStyleMapping" mode="#current" />
      <xsl:apply-templates select="IndexingSortOption" mode="#current" />
      <xsl:apply-templates select="ABullet" mode="#current" />
      <xsl:apply-templates select="Assignment" mode="#current" />
      <xsl:apply-templates select="Article" mode="#current" />
     </xsl:copy>
  </xsl:template>

  <xsl:template mode="#default"
    match="idPkg:Story[empty(. intersect $idPkg-stories-to-keep)]"/>

  <xsl:template match="idPkg:Story[exists(. intersect $idPkg-stories-to-keep)]" mode="#default">
    <xsl:copy-of select="." copy-namespaces="no" />
  </xsl:template>

  <!-- save template stories -->
  <xsl:template match="idPkg:Story[
                         not(@src) (: Story in designmap.xml :)
                       ][last()]" mode="#default" priority="2">
    <xsl:choose>
      <xsl:when test="$xml2idml:use-pages-config
                      or
                      (
                        collection()[2]/xml2idml:document/xml2idml:stories//idPkg:Story and 
                        exists(key('xml2idml:story-by-name', 'main', collection()[1]))
                      )">
        <xsl:next-match/>
        <xsl:apply-templates select="collection()[2]/xml2idml:document/xml2idml:stories//idPkg:Story" mode="xml2idml:merge_newstories" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="@*" mode="#current"/>
            <Story Self="{replace(tokenize(@xml:base, '/')[last()], '^Story_(.+)\.xml$', '$1')}">
              <xsl:copy-of select="collection()[2]/xml2idml:document/xml2idml:stories/ParagraphStyleRange" copy-namespaces="no"/>
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
                                              collection()[2]/xml2idml:document/xml2idml:stories//idPkg:Story
                                              union
                                              $idPkg-stories-to-keep
                                            )/Story/@Self" />
  </xsl:template>

  <xsl:template match="TextFrame[not(ancestor::MasterSpread)]
                         /@ParentStory[
                           . = key('xml2idml:story-by-name', $names-of-newly-generated-stories, collection()[1])/@Self
                         ]" mode="#default">
    <xsl:variable name="storytitle" as="xs:string?"
      select="xml2idml:story-name-from-conditional-text(
                key('xml2idml:story-by-self', ., collection()[1])
              )" />
    <xsl:attribute name="ParentStory" select="collection()[2]/xml2idml:document/xml2idml:stories//idPkg:Story/Story[@StoryTitle = $storytitle]/@Self" />
  </xsl:template>

  
  <!-- START: create pages and set masterpage properties -->

  <xsl:variable name="xml2idml:pages-config" as="element(xml2idml:Pages)?"
    select="collection()[2]/*/xml2idml:OtherMappingConfiguration/xml2idml:Pages"/>
  <xsl:variable name="xml2idml:use-pages-config" as="xs:boolean"
    select="exists($xml2idml:pages-config)"/>

  <!-- xml2idml:use-pages-config=true(): select first spread to insert all new spreads -->
  <xsl:template match="idPkg:Spread[$xml2idml:use-pages-config][not(preceding-sibling::idPkg:Spread)]" mode="#default">

    <!-- process user mapping configuration and build temporary/internal configuration -->
    <xsl:variable name="new-spreads" as="element(xml2idml:Spread)+">
      <xsl:call-template name="xml2idml:create-spread-and-story-info"/>
    </xsl:variable>

    <xsl:variable name="spreads-base-dir" as="xs:string"
      select="replace(@xml:base, '^(.*/)[^/]+$', '$1')"/>

    <!-- insert new Spread elements -->
    <xsl:for-each select="$new-spreads">
      <xsl:variable name="all-story-textframes" as="xs:string*"
        select="for $i in .//@TextFrames return tokenize($i, '\s+')"/>
      <xsl:element name="idPkg:Spread">
        <xsl:attribute name="xml:base" select="concat( $spreads-base-dir, @Self, '.xml' )"/>
        <xsl:attribute name="DOMVersion" select="collection()[1]/*/@DOMVersion"/>
        <xsl:element name="Spread">
          <xsl:apply-templates select="@*[name() != 'masterspread-self'][ . ne '']" mode="#current"/>
          <xsl:apply-templates mode="default_copy-pages-and-story-textframes-to-new-spreads"
            select="collection()[1]//MasterSpread[@Self eq current()/@masterspread-self]/Page,
                    collection()[1]//MasterSpread//TextFrame[
                      @Self = $all-story-textframes
                    ]">
            <xsl:with-param name="current-spread" select="." tunnel="yes"/>
            <xsl:with-param name="all-new-spreads" select="$new-spreads" tunnel="yes"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:element>
    </xsl:for-each>

    <xsl:message select="'INFO: Number of inserted spreads:', xs:integer(sum($xml2idml:pages-config/xml2idml:Spread/@Repeat))"/>
  </xsl:template>

  <!-- xml2idml:use-pages-config = true(): remove all other spreads of the template -->
  <xsl:template match="idPkg:Spread[$xml2idml:use-pages-config][preceding-sibling::idPkg:Spread]" mode="#default" />

  <xsl:template name="xml2idml:create-spread-and-story-info">

    <xsl:for-each select="$xml2idml:pages-config/xml2idml:Spread">
      <xsl:variable name="current-spreadconfig" select="current()" as="element(xml2idml:Spread)"/>
      <xsl:variable name="group-pos" select="position()" as="xs:integer"/>
      <xsl:variable name="current-spreadconf" select="." as="element()"/>

      <xsl:for-each select="1 to abs(xs:integer(($current-spreadconf/@Repeat, '1')[1]))">
        <xsl:variable name="spread-pos-in-current-spreadconfig" as="xs:integer"
          select="position()"/>
        <xsl:variable name="spread-id" as="xs:string"
          select="concat('sp_', $group-pos, '_', $spread-pos-in-current-spreadconfig)"/>
        <xsl:variable name="MasterSpread" as="element(MasterSpread)"
          select="(
                    collection()[1]//MasterSpread[@Name eq $current-spreadconf/@MasterPageName],
                    (collection()[1]//MasterSpread)[1]
                  )[1]"/>
        <xsl:if test="$MasterSpread/@Name ne $current-spreadconf/@MasterPageName">
          <xsl:message select="'WARNING: Configured master page name not found in template:', $current-spreadconf/@MasterPageName"/>
        </xsl:if>
            
        <xsl:element name="xml2idml:Spread">
          <xsl:attribute name="Self" select="$spread-id"/>
          <xsl:attribute name="masterspread-self" select="$MasterSpread/@Self"/>
          <xsl:attribute name="PageCount" 
            select="(
                      $current-spreadconf/@PageCount,
                      $MasterSpread/@PageCount,
                      '2'
                    )[1]"/>
          <xsl:attribute name="BindingLocation" 
            select="(
                      $current-spreadconf/@BindingLocation,
                      $MasterSpread/@BindingLocation,
                      '1'
                    )[1]"/>
          <xsl:attribute name="ShowMasterItems" 
            select="(
                      $current-spreadconf/@ShowMasterItems,
                      $MasterSpread/@ShowMasterItems,
                      'true'
                    )[1]"/>
          <xsl:variable name="spread-stories" as="element(Spread-Story)*">
            <!-- main story -->
            <xsl:if test="$current-spreadconfig/@MainStoryName">
              <xsl:sequence 
                select="xml2idml:retrieve-textframe-info-for-story(
                          $current-spreadconf/@MasterPageName,
                          $current-spreadconfig,
                          $spread-pos-in-current-spreadconfig
                        )"/>
            </xsl:if>
            <!-- other stories -->
            <xsl:for-each select="$current-spreadconfig/xml2idml:Stories/*">
              <xsl:sequence 
                select="xml2idml:retrieve-textframe-info-for-story(
                          $current-spreadconf/@MasterPageName,
                          .,
                          $spread-pos-in-current-spreadconfig
                        )"/>
            </xsl:for-each>
          </xsl:variable>

          <!-- Warning message: configured story cannot be found in idml template -->
          <xsl:if test="position() = last()">
            <xsl:for-each select="distinct-values($spread-stories[@TextFrames eq '']/@StoryName)">
              <xsl:message select="concat(
                                     'WARNING: No textframes found for story with name &quot;', ., '&quot;',
                                     ' on masterpage &quot;', $current-spreadconf/@MasterPageName, '&quot;'
                                   )"/>
            </xsl:for-each>
          </xsl:if>

          <!-- return only configured and existing stories with at least one textframe -->
          <xsl:sequence select="$spread-stories[@TextFrames ne '']"/>

        </xsl:element>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>

  <!-- function xml2idml:retrieve-textframe-info-for-story
       param masterspread-name: 
          name of the masterpage, where the textframe(s) are searched for
       param story-mapping: 
          a Page/Spread element (see "mapping.pages.atts.spreadinfo" in schema/mapping.rng)
          or a Page/Spread/Stories/mapping-instruction element (see "")
       param spread-pos-in-current-spreadconfig:
          for every spread-config element an @Repeat can be set. 
          The value of this parameter is the value of iterating the @Repeat (begin with 1).
          Used to break a @*StoryContinued='false' for $spread-pos-in-current-spreadconfig greater 1
  -->
  <xsl:function name="xml2idml:retrieve-textframe-info-for-story" as="element(Spread-Story)?">
    <xsl:param name="masterspread-name" as="xs:string"/>
    <xsl:param name="story-mapping" as="element()"/>
    <xsl:param name="spread-pos-in-current-spreadconfig" as="xs:integer"/>

    <xsl:variable name="story-name" as="xs:string"
      select="if ($story-mapping/@MainStoryName ne '') 
              then $story-mapping/@MainStoryName 
              else $story-mapping/xml2idml:name"/>
    <xsl:variable name="story-textframes" 
      select="collection()[1]//MasterSpread[@Name eq $masterspread-name]
                //TextFrame[
                  @ParentStory[
                    . = key('xml2idml:story-by-name', $story-name, collection()[1])
                          /@Self
                  ]
                ]"/>
    <!-- Spread-Story temporary/internal configuration element -->
    <Spread-Story 
      StoryName="{$story-name}" 
      StoryContinued="{if ($spread-pos-in-current-spreadconfig gt 1)
                       then 'true'
                       else 
                         if ($story-mapping/@*[name() = ('MainStoryContinued', 'StoryContinued')] eq 'true') 
                         then 'true' 
                         else 'false'
                      }"
      TextFrames="{for $i in $story-textframes return $i/@Self}"
      TextFrameFirst="{$story-textframes[@PreviousTextFrame eq 'n']/@Self}" 
      TextFrameLast="{$story-textframes[@NextTextFrame eq 'n']/@Self}"/>
  </xsl:function>

  <!-- set the based on property for the copied page -->
  <xsl:template match="Page/@AppliedMaster" mode="default_copy-pages-and-story-textframes-to-new-spreads">
    <xsl:param name="current-spread" tunnel="yes"/>
    <xsl:attribute name="AppliedMaster" select="$current-spread/@masterspread-self"/>
  </xsl:template>

  <!-- context: a story textframe on the chosen MasterSpread (by name), placed in content area -->
  <xsl:template match="TextFrame" mode="default_copy-pages-and-story-textframes-to-new-spreads">
    <xsl:param name="current-spread" tunnel="yes"/>
    <xsl:param name="all-new-spreads" tunnel="yes"/>
    <!-- select the Spread-Story element for the current TextFrame -->
    <xsl:variable name="current-spread-story" as="element(Spread-Story)"
      select="($current-spread/Spread-Story[current()/@Self = tokenize(@TextFrames, '\s')])[1]"/>
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#default"/>
      <xsl:attribute name="Self" select="concat(@Self, '_copiedto_', $current-spread/@Self)"/>
      <xsl:attribute name="ParentStory" 
        select="collection()[2]/xml2idml:document/xml2idml:stories
                  //idPkg:Story/Story[@StoryTitle = $current-spread-story/@StoryName]/@Self"/>
      <xsl:variable name="previous-spread-story" as="element(Spread-Story)?"
        select="(
                  $all-new-spreads[ 
                    . &lt;&lt; $current-spread and
                    Spread-Story[@StoryName eq $current-spread-story/@StoryName]
                  ]/Spread-Story[@StoryName eq $current-spread-story/@StoryName]
                )[last()]"/>
      <xsl:attribute name="PreviousTextFrame">
        <xsl:choose>
          <!-- very first TextFrame for the current Story OR story starts new from here -->
          <xsl:when test="(
                            @PreviousTextFrame eq 'n' and
                            not($previous-spread-story)
                          ) 
                          or 
                          (
                            $current-spread-story/@StoryContinued eq 'false' and
                            $current-spread-story/@TextFrameFirst eq @Self
                          )">
            <xsl:value-of select="'n'"/>
          </xsl:when>
          <!-- non-first TextFrame for the current Story, but first on current spread, and continued!  -->
          <xsl:when test="@PreviousTextFrame eq 'n' and 
                          $previous-spread-story and 
                          $current-spread-story/@StoryContinued eq 'true'">
            <xsl:value-of select="concat($previous-spread-story/@TextFrameLast, '_copiedto_', $previous-spread-story/../@Self)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="concat(@PreviousTextFrame, '_copiedto_', $current-spread/@Self)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>

      <xsl:variable name="next-spread-story" as="element(Spread-Story)?"
        select="(
                  $all-new-spreads[ 
                    . &gt;&gt; $current-spread and
                    Spread-Story[@StoryName eq $current-spread-story/@StoryName]
                  ]/Spread-Story[@StoryName eq $current-spread-story/@StoryName]
                )[1]"/>
      <xsl:attribute name="NextTextFrame">
        <xsl:choose>
          <!-- very last TextFrame for the current Story OR no continuation -->
          <xsl:when test="@NextTextFrame eq 'n' and
                          (
                            not($next-spread-story) or 
                            $next-spread-story/@StoryContinued eq 'false'
                          )">
            <xsl:value-of select="'n'"/>
          </xsl:when>
          <!-- non-last TextFrame for the current Story, continued!  -->
          <xsl:when test="@NextTextFrame eq 'n' and $next-spread-story/@StoryContinued eq 'true'">
            <xsl:value-of select="concat($next-spread-story/@TextFrameFirst, '_copiedto_', $next-spread-story/../@Self)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="concat(@NextTextFrame, '_copiedto_', $current-spread/@Self)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>

      <xsl:apply-templates select="node()" mode="#default"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="node()|@*" mode="default_copy-pages-and-story-textframes-to-new-spreads">
    <xsl:copy>
      <xsl:apply-templates select="@*, node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@Self" mode="default_copy-pages-and-story-textframes-to-new-spreads">
    <xsl:param name="current-spread" tunnel="yes"/>
    <xsl:attribute name="Self" select="concat(., '_copiedto_', $current-spread/@Self)"/>
  </xsl:template>

  <!-- END: create pages and set masterpage properties -->

</xsl:stylesheet>
