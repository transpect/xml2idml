<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
  version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"
  xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/"
  xmlns:idPkg = "http://ns.adobe.com/AdobeInDesign/idml/1.0/packaging"
  xmlns:xml2idml="http://transpect.io/xml2idml"
  xmlns:idml2xml  = "http://transpect.io/idml2xml"
  xmlns:tr="http://transpect.io"
  xmlns:css="http://www.w3.org/1996/css"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="css tr xs xml2idml idml2xml"
  >

  <!-- collection()[1]/* is the mapped document.
       collection()[2]/* is the /Document (expanded IDML template)
  -->

  <xsl:import href="http://transpect.io/idml2xml/xsl/common-functions.xsl" />
  <xsl:import href="http://transpect.io/xslt-util/lengths/xsl/lengths.xsl" />
  <xsl:import href="http://transpect.io/xslt-util/mime-type/xsl/mime-type.xsl" />

  <xsl:param name="base-uri" as="xs:string" />

  <xsl:variable name="expanded-template" as="document-node(element(Document))?"
    select="collection()[2]" />

  <xsl:key name="object" match="TextFrame" use="@AppliedObjectStyle" />
  <xsl:key name="story" match="Story" use="@Self" />
  <xsl:key name="pstyle" match="ParagraphStyle" use="@Self" />
  <xsl:key name="cellstyle" match="CellStyle" use="@Self" />
  <xsl:key name="icon" match="*[self::Polygon or self::TextFrame or self::Group or self::Rectangle]
                               [ancestor::*/@AppliedConditions = 'Condition/icon']" 
    use="normalize-space(
           (
             following-sibling::Content
             union
             ../following-sibling::CharacterStyleRange/Content
           )[matches(., '\S')][1]
         )" />

  <xsl:template match="* | @* | processing-instruction()" mode="xml2idml:storify_content-n-cleanup xml2idml:reproduce-icons">
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="@*, node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="/" mode="xml2idml:storify">
    <xml2idml:document>
      <xsl:copy-of select="/*/xml2idml:OtherMappingConfiguration"/>
      <xml2idml:stories>
        <xsl:copy-of select="*/@xml2idml:keep-stories" />
        <xsl:apply-templates mode="#current" />
      </xml2idml:stories>
      <xml2idml:index>
        <xsl:if test="//*[@xml2idml:is-indexterm-level]">
          <Index Self="X2I">
            <xsl:sequence select="xml2idml:build-topic-structure($distinct-topics)"/>
          </Index>
        </xsl:if>
      </xml2idml:index>
      <xml2idml:hyperlinks>
        <xsl:sequence select="xml2idml:create-hyperlinks(//*[@xml2idml:hyperlink-source])"/>
        <xsl:sequence select="xml2idml:create-hyperlink-url-destinations(//*[matches(@xml2idml:hyperlink-source, '^www|ftp|http')])"/>
      </xml2idml:hyperlinks>
    </xml2idml:document>
  </xsl:template>

  <xsl:template match="/*/xml2idml:OtherMappingConfiguration" mode="xml2idml:storify" priority="100"/>

  <!-- Overview of mode="xml2idml:storify" and mode="xml2idml:storify_content-n-cleanup"
       
       Priority cascade. The markup created will be from outer to inner, that is, each template
       will create one or more nested elements and then call xsl:next-match within that element.
       5:    Create TextFrames for objects with an ObjectStyle.
             The stories that populate these frames will be created within. The resulting
             document will be split into individual story files at a later stage, in a separate 
             pass.
             Next match.
       4.25: Some span preprocessing (for the icons). Will be includable as custom templates soon.
       4:    Create the stories that populate the text frames with 'storytitle' conditional text.
             Recreate the conditional text. 
             Next match.
             This top-level story creation should not interfere with this template:
       4:    Create stories for objects with an ObjectStyle.
             If we already see that no paragraph style will apply to the same object,
             we'll use the style of a synthetic wrapping paragraph (xml2idml:ParagraphStyleRange)
             or NormalPragraphStyle if no wrapping and no pstyle is present.
             Next match.
       3.5:  Apply cell style. This should be the first template that elements with @aid:table = 'cell' 
             encounter.
             Next match (as parameter: a pstyle that is connected to the cellstyle, if present).
       3.25: Surround text that should be hidden with appropriate tagging.
             Next match.
       3:    Apply paragraph style (explicitly declared @aid:pstyle).
             Terminate each paragraph with Br (some of which will be removed in the next pass).
             Next match (with empty pstyle parameter, because there is already a pstyle).
       2.5:  Apply character style (explicitly declared @aid:cstyle).
             If a parameter pstyle is passed, the created CharacterStyleRange will be wrapped
             in an appropriate ParagraphStyleRange.
             Next match.
       2.3:  Create images (EPS Rectangle, WMF Image, ...)
       2.3:  Wrap element self::*[@aid:cstyle][@xml2idml:is-footnote] with Footnote element
       2.2:  Create hyperlinks from elements self::*@xml2idml:hyperlink-source] and self::*[@xml2idml:hyperlink-dest]
       2:    Original tagging will be converted to piggyback tagging (XMLElement).
             Other elements in the xml2idml namespace (namely, xml2idml:ParagraphStyleRange)
             will be stripped of their namespaces.
             Next match.
       1.5:  Table markup will be created. That means: for @aid:table='table' elements,
             first the XMLElement markup will be created, then the table. For @aid:table='cell'
             elements, first the Cells and then the XMLElements will be created. This ensures
             that there will be no intermediate elements between a Table and its Cells.
             Next match.
       1:    Custom span processing (will soon be configurable), typically for inserting icons
             (polygons, copies of text frames) from the expanded template. 
             Next match.
       default: mostly Attributes will be created by templates with default priority.


       In a second pass (xml2idml:storify_content-n-cleanup), the raw IDML will be enhanced:

       WS-only text nodes that are not contained in a ParagraphStyleRange will be discarded. 

       Text nodes, Tables, Footnotes, and TextFrames that are immediately within a ParagraphStyleRange
       (module intermediate XMLElements) will be surrounded with a default CharacterStyleRange.

       Text nodes that don’t yet have Content around them will be enclosed in Content.
       At the same time, they’ll be WS-normalized (multiple consecutive WS chars become a single space).

       A terminal Br in Stories, Footnotes, and Cells will be removed.

       -->

  <xsl:template match="*[@xml2idml:storyname]" mode="xml2idml:storify" priority="4">
    <idPkg:Story DOMVersion="{$expanded-template/Document/@DOMVersion}">
      <xsl:attribute name="xml:base" select="concat($base-uri, '/Stories/st_', generate-id(), '.xml')"/>
      <Story Self="st_{generate-id()}" StoryTitle="{@xml2idml:storyname}">
        <xsl:copy-of select="@xml2idml:keep-xml-space-preserve"/>
        <HiddenText>
          <ParagraphStyleRange AppliedParagraphStyle="ParagraphStyle/$ID/NormalParagraphStyle">
            <CharacterStyleRange AppliedCharacterStyle="CharacterStyle/$ID/[No character style]"
              AppliedConditions="Condition/storytitle">
              <Content>
                <xsl:value-of select="@xml2idml:storyname" />
              </Content>
              <Br/>
            </CharacterStyleRange>
          </ParagraphStyleRange>
        </HiddenText>
        <xsl:next-match/>
      </Story>
    </idPkg:Story>
  </xsl:template>

  <xsl:template match="*[@xml2idml:ObjectStyle]" mode="xml2idml:storify" priority="4">
    <idPkg:Story DOMVersion="{$expanded-template/Document/@DOMVersion}">
      <xsl:attribute name="xml:base" select="concat($base-uri, '/Stories/st_', generate-id(), '.xml')"/>
      <Story Self="st_{generate-id()}">
        <xsl:choose>
          <xsl:when test="@aid:pstyle">
            <xsl:next-match/>
          </xsl:when>
          <xsl:otherwise>
            <!-- Just in case that no ParagraphStyleRanges will be created within. 
                 Will unwrap later if ParagraphStyleRange present below. -->
<!--             <ParagraphStyleRange AppliedParagraphStyle="{(parent::xml2idml:ParagraphStyleRange/@AppliedParagraphStyle, '$ID/NormalParagraphStyle')[1]}"> -->
              <xsl:next-match/>
<!--             </ParagraphStyleRange> -->
          </xsl:otherwise>
        </xsl:choose>
      </Story>
    </idPkg:Story>
  </xsl:template>

  <xsl:template match="*[@aid:table eq 'cell']" mode="xml2idml:storify" priority="3.5">
    <xsl:variable name="base-id" select="concat('cl_', generate-id())" as="xs:string"/>
    <xsl:variable name="row-start" as="xs:double"
      select="sum(
                if(ancestor::*[local-name() = ('thead', 'tbody', 'tfoot')][1]/self::*:thead) 
                then 0
                else 
                  if(ancestor::*[local-name() = ('thead', 'tbody', 'tfoot')][1]/self::*:tbody) 
                  then ancestor::*:tbody[1]
                      /preceding-sibling::*:thead
                        /@data-rowcount
                  else
                    ancestor::*:tfoot[1]
                      /preceding-sibling::*[local-name() = ('thead', 'tbody')]
                        /@data-rowcount,
                0
              )"/>
    <Cell Self="{$base-id}"
      Name="{@data-colnum - 1}:{@data-rownum - 1 + $row-start}"
      RowSpan="{(@rowspan, 1)[1]}" ColumnSpan="{(@colspan, 1)[1]}">
      <xsl:apply-templates select="@aid5:cellstyle" mode="#current" />
      <!-- other rules (create XMLElement, presumably): -->
      <xsl:next-match>
        <xsl:with-param name="pstyle" select="key(
                                                'pstyle',
                                                key(
                                                  'cellstyle', 
                                                  concat('CellStyle/', xml2idml:escape-stylename(@aid5:cellstyle)), 
                                                  $expanded-template
                                                )/@AppliedParagraphStyle,
                                                $expanded-template
                                              )" tunnel="yes" />
      </xsl:next-match>
    </Cell>
  </xsl:template>

  <xsl:template match="*[@aid:pstyle][not(xml2idml:invalid-nested-pstyle(.))]" mode="xml2idml:storify" priority="3">
    <ParagraphStyleRange>
      <xsl:apply-templates select="@xml2idml:condition" mode="#current"/>
      <xsl:apply-templates select="@css:* | @aid:pstyle" mode="#current" />
      <xsl:next-match>
        <xsl:with-param name="pstyle" select="()" tunnel="yes" />
      </xsl:next-match>
      <xsl:sequence select="xml2idml:insert-Br(.)"/>
    </ParagraphStyleRange>
  </xsl:template>

  <!-- invalid pstyle in pstyle: dissolve as CSR, add specific info into style name -->
  <xsl:template match="*[@aid:pstyle][xml2idml:invalid-nested-pstyle(.)]" mode="xml2idml:storify" priority="3">
    <CharacterStyleRange AppliedCharacterStyle="{concat('CharacterStyle/xml2idml-ParagraphInParagraph-', @aid:pstyle)}">
      <xsl:apply-templates select="@xml2idml:condition" mode="#current"/>
      <xsl:apply-templates select="@css:*, node()" mode="#current" />
    </CharacterStyleRange>
    <Br/>
  </xsl:template>

  <xsl:variable name="xml2idml:mapping2xsl-paragraph-attribute-names" as="xs:string+"
    select="('aid:pstyle', 'xml2idml:ObjectStyle', 'aid5:tablestyle', 'aid5:cellstyle')"/>

  <xsl:variable name="xml2idml:mapping2xsl-paragraph-attribute-names-without-pstyle" as="xs:string+"
    select="$xml2idml:mapping2xsl-paragraph-attribute-names[ . ne 'aid:pstyle']"/>

  <xsl:function name="xml2idml:invalid-nested-pstyle" as="xs:boolean">
    <xsl:param name="p-el" as="element()"/>
    <xsl:sequence select="(: current element has also an object mapping :)
                          not(
                            $p-el[@xml2idml:ObjectStyle or @aid5:tablestyle]
                          )
                          and
                          (: first PSR equivalent ancestor is a footnote :)
                          not(
                            $p-el/ancestor::*[@aid:pstyle or @xml2idml:is-footnote][1][
                              @xml2idml:is-footnote eq 'yes'
                            ]
                          )
                          and
                          (: first ancestor table/object mapping has no aid:pstyle attribute :)
                          boolean(
                            $p-el/ancestor::*[@aid:pstyle]
                            and
                            $p-el/ancestor::*
                              [
                                @*[name() = $xml2idml:mapping2xsl-paragraph-attribute-names]
                              ][1]/@aid:pstyle
                          )"/>
  </xsl:function>

  <xsl:function name="xml2idml:insert-Br" as="element(Br)?">
    <xsl:param name="node" as="element(*)"/>
    <xsl:variable name="ancestor-scope" as="element(*)?"
      select="$node/ancestor::*[
                @*[ name() = $xml2idml:mapping2xsl-paragraph-attribute-names
                    or name() eq 'xml2idml:is-footnote'
                  ]
              ][1]"/>
    <xsl:variable name="ancestor-last-break-child" as="element(*)*"
      select="(
                $ancestor-scope//*[
                  @*[name() = $xml2idml:mapping2xsl-paragraph-attribute-names]
                ]
              )[last()]"/>
    <xsl:if test="not($ancestor-scope) or
                    (
                      $ancestor-last-break-child and
                      not( $node is $ancestor-last-break-child)
                    )">
      <Br/>
    </xsl:if>
  </xsl:function>

  <!-- provisional -->
  <xsl:template match="@css:*" mode="xml2idml:storify" />


  <xsl:template match="*[@xml2idml:hidden]" mode="xml2idml:storify" priority="3.25">
    <HiddenText>
      <xsl:next-match/>
    </HiddenText>
  </xsl:template>

  <xsl:template match="*:span[@class eq 'tab-indent-to-here']" mode="xml2idml:storify">
    <Content>
      <xsl:processing-instruction name="ACE" select="'7'"/>
    </Content>
  </xsl:template>
  
  <xsl:attribute-set name="hyperlink-style">
    <xsl:attribute name="Visible" select="'false'"/>
    <xsl:attribute name="Highlight" select="'None'"/>
    <xsl:attribute name="Width" select="'Thin'"/>
    <xsl:attribute name="BorderStyle" select="'Solid'"/>
    <xsl:attribute name="Hidden" select="'false'"/>
  </xsl:attribute-set>
  
  <xsl:function name="xml2idml:create-hyperlinks" as="element(Hyperlink)*">
    <xsl:param name="link-source" as="element(*)*"/>
    <xsl:for-each select="$link-source">
      <xsl:variable name="destination" as="element(*)?" select="key('linking-item-by-dest', @xml2idml:hyperlink-source)"/>
      <xsl:variable name="source" select="current()/@xml2idml:hyperlink-source" as="attribute(xml2idml:hyperlink-source)"/>
      <xsl:choose>
        <xsl:when test="$destination or matches($source, '^www|ftp|http')">
          <Hyperlink xsl:use-attribute-sets="hyperlink-style"
            Self="{concat('link_', generate-id())}"
            Name="{concat($source, '_', generate-id())}"
            Source="{generate-id()}"
            DestinationUniqueKey="{concat('00', count($destination/preceding::node()))}">
            <Properties>
              <BorderColor type="enumeration">Black</BorderColor>
              <Destination type="object">
                <xsl:choose>
                  <xsl:when test="matches($source, '^(www|ftp|http)')">
                    <xsl:value-of select="concat('HyperlinkURLDestination/', $source)"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="concat('HyperlinkTextDestination/', $source)"/>
                  </xsl:otherwise>
                </xsl:choose>
              </Destination>
            </Properties>
          </Hyperlink>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message select="concat('############# can not create hyperlink: missing destination for link ', current()/@xml2idml:hyperlink-source)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:function>
  
  <xsl:function name="xml2idml:create-hyperlink-url-destinations" as="element(HyperlinkURLDestination)*">
    <xsl:param name="link-source" as="element(*)*"/>
    <xsl:for-each select="$link-source">
      <xsl:variable name="link-dest" select="current()/@xml2idml:hyperlink-source" as="attribute(xml2idml:hyperlink-source)"/>
      <HyperlinkURLDestination 
        Self="{concat('HyperlinkURLDestination/', $link-dest)}"
        DestinationUniqueKey="{concat('00', count(preceding::node()))}"
        DestinationURL="{$link-dest}"
        Name="{$link-dest}"
        Hidden="false"/>
    </xsl:for-each>
  </xsl:function>
  

  <xsl:variable name="distinct-topics" as="xs:string*"
    select="distinct-values(for $i in //*[@xml2idml:is-indexterm-level][. != ''] return xml2idml:generate-ReferencedTopic($i))"/>
  <xsl:variable name="indexterm-crossrefs" as="element(CrossReference)*"
    select="for $i in //*[@xml2idml:is-indexterm-crossref][. != ''] return xml2idml:generate-crossrefs($i)"/>
  
  <!-- function xml2idml:build-topic-structure
       param topics example: ('TopicnFaceTopicnEyesTopicnGreen', 'TopicnFaceTopicnNoise') (without @Self prefix!) -->
  <xsl:function name="xml2idml:build-topic-structure" as="element(Topic)+">
    <xsl:param name="topics" as="xs:string+"/>
    <xsl:for-each select="$topics">
      <xsl:sequence select="xml2idml:build-topic-element(., 1)"/>
    </xsl:for-each>
  </xsl:function>
  
  <!-- function xml2idml:build-topic-element
       param topics example: TopicnFaceTopicnNoise (without @Self prefix!) -->
  <xsl:function name="xml2idml:build-topic-element" as="element(Topic)">
    <xsl:param name="topics" as="xs:string"/>
    <xsl:param name="levels" as="xs:integer"/>
    <!-- : needs to be replaced for @Self value or InDesign will crash -->
    <xsl:variable name="normalized-topics" as="xs:string" 
      select="replace($topics, ':', '-')"/>
    <xsl:variable name="splitted-topics" as="xs:string+"
      select="tokenize($topics, 'Topicn')[ . != '']"/>
    <xsl:variable name="normalized-splitted-topics" as="xs:string+"
      select="tokenize($normalized-topics, 'Topicn')[ . != '']"/>
    <Topic SortOrder="">
      <xsl:attribute name="Name">
        <xsl:value-of select="$splitted-topics[$levels]"/>
      </xsl:attribute>
      <xsl:attribute name="Self">
        <xsl:value-of select="concat('X2ITopicn', string-join($normalized-splitted-topics[position() le $levels], 'Topicn'))"/>
      </xsl:attribute>
      <xsl:if test="count($splitted-topics) gt $levels">
        <xsl:sequence select="xml2idml:build-topic-element($topics, $levels + 1)"/>
      </xsl:if>
      <xsl:if test="some $i in $indexterm-crossrefs/@Self satisfies $i eq $topics">
        <xsl:sequence select="$indexterm-crossrefs[@Self eq $topics]"/>
      </xsl:if>
    </Topic>
  </xsl:function>
  
  <xsl:template match="*[@xml2idml:is-indexterm-level][not(@xml2idml:is-indexterm-crossref)]" mode="xml2idml:storify" priority="2.3">
    <CharacterStyleRange AppliedCharacterStyle="CharacterStyle/$ID/[No character style]">
      <PageReference Self="pr_{generate-id()}" PageReferenceType="CurrentPage" ReferencedTopic="{concat('X2I', replace(xml2idml:generate-ReferencedTopic(.), ':', '-'))}" />
    </CharacterStyleRange>
  </xsl:template>
  <xsl:template match="*[@xml2idml:is-indexterm-crossref]" mode="xml2idml:storify" priority="2.3"/>
  
  <xsl:function name="xml2idml:generate-crossrefs" as="element(CrossReference)">
    <xsl:param name="indexterm-crossref" as="element()"/>
    <xsl:variable name="indexterm-child" select="$indexterm-crossref/preceding-sibling::*[@xml2idml:is-indexterm-level][1]"/>
    <CrossReference>
      <!-- @Self will be replaced by random string in mode storify_content-n-cleanup -->
      <!-- now it serves as identifier to find matching topic -->
      <xsl:attribute name="Self" select="xml2idml:generate-ReferencedTopic($indexterm-child)"/>
      <xsl:attribute name="ReferencedTopic" select="concat('X2ITopicn', $indexterm-crossref)"/>
      <xsl:attribute name="CrossReferenceType">
        <xsl:choose>
          <xsl:when test="$indexterm-crossref/@xml2idml:crossref-type eq 'see'">
            <xsl:value-of select="'See'"/>
          </xsl:when>
          <xsl:when test="$indexterm-crossref/@xml2idml:crossref-type eq 'seealso'">
            <xsl:value-of select="'SeeAlso'"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:message select="'#####  CrossReferenceType not supported; #####'"/>
            <xsl:value-of select="'See'"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:attribute name="CustomTypeString" select="''"/>
    </CrossReference>
  </xsl:function>
  
  <xsl:function name="xml2idml:generate-ReferencedTopic" as="xs:string">
    <xsl:param name="indexterm-child" as="element()"/>
    <xsl:variable name="level" select="xs:integer($indexterm-child/@xml2idml:is-indexterm-level)" as="xs:integer"/>
    <xsl:choose>
      <xsl:when test="$level = 1">
        <xsl:value-of select="concat('Topicn', $indexterm-child)"/>
      </xsl:when>
      <xsl:when test="$level = 2">
        <xsl:value-of select="concat(
                                'Topicn', $indexterm-child/preceding-sibling::*[1][xs:integer(@xml2idml:is-indexterm-level) = 1 ], 
                                'Topicn', $indexterm-child
                              )"/>
      </xsl:when>
      <xsl:when test="$level = 3">
        <xsl:value-of select="concat(
                                'Topicn', $indexterm-child/preceding-sibling::*[1][xs:integer(@xml2idml:is-indexterm-level) = 1 ], 
                                'Topicn', $indexterm-child/preceding-sibling::*[1][xs:integer(@xml2idml:is-indexterm-level) = 2 ], 
                                'Topicn', $indexterm-child
                              )"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="'#####  Indexlevel 4 or more not supported  #####'"></xsl:message>
        <xsl:value-of select="'4thLevelIndexentry'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:variable name="xml2idml:icon-element-role-regex" as="xs:string"
    select="'^icon|hru-infobox-icon$'"/>

  <xsl:function name="xml2idml:icon-reference-name" as="xs:string">
    <xsl:param name="el" as="element(*)"/>
    <xsl:sequence select="$el"/>
  </xsl:function>

  <xsl:template match="*:span[matches(@class, $xml2idml:icon-element-role-regex)]" mode="xml2idml:storify" priority="1">
    <xsl:variable name="new-story-id" as="xs:string"
      select="concat('st_icon_', generate-id())"/>
    <xsl:variable name="icon-lookup" as="element(*)?"
      select="key('icon', xml2idml:icon-reference-name(.), $expanded-template)"/>
    <xsl:choose>
      <xsl:when test="$icon-lookup">
        <xsl:apply-templates select="$icon-lookup" mode="xml2idml:reproduce-icons">
          <xsl:with-param name="new-story-id" select="$new-story-id" tunnel="yes"/>
          <xsl:with-param name="icon-element" select="." tunnel="yes"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="' Could not found icon in idml template:', xml2idml:icon-reference-name(.)"/>
        <xsl:next-match/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="TextFrame" mode="xml2idml:reproduce-icons">
    <xsl:param name="new-story-id" as="xs:string" tunnel="yes"/>
    <!-- newer-story-id: because we tunnel new-story-id we use newer-story-id to set an another id -->
    <xsl:param name="newer-story-id" select="''" as="xs:string" tunnel="no"/>
    <xsl:variable name="newer-story-id" as="xs:string"
      select="if($newer-story-id eq '') 
              then string-join(($new-story-id, string(generate-id())), '_') 
              else $newer-story-id"/>
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current" />
      <xsl:attribute name="Self" select="concat('TextFrame_', $new-story-id)"/>
      <xsl:attribute name="ParentStory" select="concat('Story_', $newer-story-id)"/>
      <xsl:apply-templates select="*" mode="#current" />
      <xsl:apply-templates select="key( 'story', current()/@ParentStory, $expanded-template )" mode="#current">
        <!-- Let's just hope that this id is unique enough. If it isn't there's an error
             that two docs (stories) cannot be written to the same URI -->
        <xsl:with-param name="new-story-id" select="$newer-story-id" tunnel="yes"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="Group" mode="xml2idml:reproduce-icons">
    <xsl:param name="new-story-id" as="xs:string" tunnel="yes"/>
    <xsl:param name="icon-element" tunnel="yes"/>
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current" />
      <xsl:attribute name="Self" select="concat('Group_', $new-story-id)"/>
      <xsl:apply-templates select="*" mode="#current" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="Story" mode="xml2idml:reproduce-icons">
    <xsl:param name="new-story-id" as="xs:string" tunnel="yes"/>
    <idPkg:Story DOMVersion="{$expanded-template/Document/@DOMVersion}">
      <xsl:attribute name="xml:base" select="concat($base-uri, '/Stories/', $new-story-id, '.xml')"/>
      <xsl:copy copy-namespaces="no">
        <xsl:attribute name="Self" select="concat('Story_', $new-story-id)"/>
        <xsl:apply-templates select="@* except @Self, node()" mode="#current" />
      </xsl:copy>
    </idPkg:Story>
  </xsl:template>

  <xsl:template match="@xml2idml:condition" mode="xml2idml:storify">
    <xsl:attribute name="AppliedConditions" select="concat('Condition/', .)" />
  </xsl:template>

  <xsl:template match="*[@aid:cstyle]/@xml:lang" mode="xml2idml:storify">
    <xsl:sequence select="xml2idml:langAttr-to-AppliedLanguageAttr(.)"/>
  </xsl:template>

  <xsl:function name="xml2idml:langAttr-to-AppliedLanguageAttr" as="node()?">
    <xsl:param name="lang-attr" as="attribute()"/>
    <xsl:variable name="lang" select="lower-case($lang-attr)" as="xs:string?"/>
    <xsl:variable name="apply" as="xs:string">
      <xsl:value-of>
        <xsl:choose>
          <xsl:when test="$lang eq ''">[No Language]</xsl:when>
          <xsl:when test="starts-with($lang, 'ar')">Arabic</xsl:when>
          <xsl:when test="starts-with($lang, 'bn-in')">bn_IN</xsl:when>
          <xsl:when test="starts-with($lang, 'bg')">Bulgarian</xsl:when>
          <xsl:when test="starts-with($lang, 'ca')">Catalan</xsl:when>
          <xsl:when test="starts-with($lang, 'hr')">Croatian</xsl:when>
          <xsl:when test="starts-with($lang, 'cs')">Czech</xsl:when>
          <xsl:when test="starts-with($lang, 'da')">Danish</xsl:when>
          <xsl:when test="starts-with($lang, 'nl')">nl_NL_2005</xsl:when>
          <!--<xsl:when test="starts-with($lang, 'nl')">Dutch</xsl:when>-->
          <xsl:when test="starts-with($lang, 'en-ca')">English: Canadian</xsl:when>
          <xsl:when test="starts-with($lang, 'en-gb')">English: UK</xsl:when>
          <xsl:when test="starts-with($lang, 'en-us-legal')">English: USA Legal</xsl:when>
          <xsl:when test="starts-with($lang, 'en-us-medical')">English: USA Medical</xsl:when>
          <xsl:when test="starts-with($lang, 'en-us')">English: USA</xsl:when>
          <xsl:when test="starts-with($lang, 'en')">English: USA</xsl:when><!-- fallback for english -->
          <xsl:when test="starts-with($lang, 'et')">Estonian</xsl:when>
          <xsl:when test="starts-with($lang, 'fi')">Finnish</xsl:when>
          <xsl:when test="starts-with($lang, 'fr-ca')">French: Canadian</xsl:when>
          <xsl:when test="starts-with($lang, 'fr')">French</xsl:when>
          <xsl:when test="starts-with($lang, 'el')">Greek</xsl:when>
          <xsl:when test="starts-with($lang, 'de-de-1996')">German: Reformed</xsl:when>
          <xsl:when test="starts-with($lang, 'de-de-2006')">de_DE_2006</xsl:when>
          <xsl:when test="starts-with($lang, 'de-de-tradnl')">German: Traditional</xsl:when>
          <xsl:when test="starts-with($lang, 'de')">de_DE_2006</xsl:when>
          <xsl:when test="starts-with($lang, 'gu-in')">gu_IN</xsl:when>
          <xsl:when test="starts-with($lang, 'he')">Hebrew</xsl:when>
          <xsl:when test="starts-with($lang, 'hi-in')">hi_IN</xsl:when>
          <xsl:when test="starts-with($lang, 'it')">Italian</xsl:when>
          <xsl:when test="starts-with($lang, 'kn-in')">kn_IN</xsl:when>
          <xsl:when test="starts-with($lang, 'lv')">Latvian</xsl:when>
          <xsl:when test="starts-with($lang, 'lt')">Lithuanian</xsl:when>
          <xsl:when test="starts-with($lang, 'ml-in')">ml_IN</xsl:when>
          <xsl:when test="starts-with($lang, 'mr-in')">mr_IN</xsl:when>
          <xsl:when test="starts-with($lang, 'nb')">Norwegian: Bokmal</xsl:when>
          <xsl:when test="starts-with($lang, 'nn')">Norwegian: Nynorsk</xsl:when>
          <xsl:when test="starts-with($lang, 'or-in')">or_IN</xsl:when>
          <xsl:when test="starts-with($lang, 'pa-in')">pa_IN</xsl:when>
          <xsl:when test="starts-with($lang, 'pl')">Polish</xsl:when>
          <xsl:when test="starts-with($lang, 'pt-BR')">Portuguese: Brazilian</xsl:when>
          <xsl:when test="starts-with($lang, 'pt-PT')">Portuguese: Orthographic Agreement</xsl:when>
          <xsl:when test="starts-with($lang, 'pt')">Portuguese</xsl:when>
          <xsl:when test="starts-with($lang, 'ro')">Romanian</xsl:when>
          <xsl:when test="starts-with($lang, 'ru')">Russian</xsl:when>
          <xsl:when test="starts-with($lang, 'sv')">Swedish</xsl:when>
          <xsl:when test="starts-with($lang, 'sk')">Slovak</xsl:when>
          <xsl:when test="starts-with($lang, 'sl')">Slovenian</xsl:when>
          <xsl:when test="starts-with($lang, 'es')">Spanish: Castilian</xsl:when>
          <xsl:when test="starts-with($lang, 'ta-in')">ta_IN</xsl:when>
          <xsl:when test="starts-with($lang, 'te-in')">te_IN</xsl:when>
          <xsl:when test="starts-with($lang, 'tr')">Turkish</xsl:when>
          <xsl:when test="starts-with($lang, 'uk')">Ukrainian</xsl:when>
          <xsl:when test="starts-with($lang, 'hu')">Hungarian</xsl:when>
          <xsl:otherwise>[No Language]<xsl:message select="' xml2idml, Applying spelling language: Unsupported value:', xs:string($lang)"/></xsl:otherwise>
        </xsl:choose>
      </xsl:value-of>
    </xsl:variable>
    <xsl:if test="$apply ne '[No Language]'">
      <xsl:attribute name="AppliedLanguage" select="concat('$ID/', $apply)"/>
    </xsl:if>
  </xsl:function>

  <xsl:template match="*[@aid:cstyle]" mode="xml2idml:storify" priority="2.5">
    <xsl:param name="pstyle" as="xs:string?" tunnel="yes" />
    <xsl:variable name="csr" as="element(CharacterStyleRange)+">
      <xsl:if test="@xml2idml:insert-special-char-method eq 'before'">
        <xsl:sequence select="xml2idml:insert-special-char-wrapper(.)"/>
      </xsl:if>
      <xsl:if test="@xml2idml:insert-content-method eq 'before'">
        <xsl:sequence select="xml2idml:insert-content-wrapper(.)"/>
      </xsl:if>
      <CharacterStyleRange AppliedCharacterStyle="CharacterStyle/{@aid:cstyle}">
        <xsl:apply-templates select="@xml:lang, @xml2idml:condition" mode="#current"/>
        <xsl:choose>
          <xsl:when test="@xml2idml:insert-special-char-method eq 'replace'">
            <xsl:attribute name="AppliedCharacterStyle" 
              select="concat('CharacterStyle/', (@xml2idml:insert-special-char-format, @aid:cstyle,'$ID/[No character style]')[1])"/>
            <xsl:sequence select="xml2idml:insert-special-char(@xml2idml:insert-special-char)"/>
          </xsl:when>
          <xsl:when test="@xml2idml:insert-content-method eq 'replace'">
            <xsl:attribute name="AppliedCharacterStyle" 
              select="concat('CharacterStyle/', (@xml2idml:insert-content-format, @aid:cstyle, '$ID/[No character style]')[1])"/>
            <Content>
              <xsl:value-of select="@xml2idml:insert-content"/>
            </Content>
          </xsl:when>
          <xsl:otherwise>
            <xsl:next-match>
              <xsl:with-param name="pstyle" select="()" tunnel="yes" />
            </xsl:next-match>
          </xsl:otherwise>
        </xsl:choose>
      </CharacterStyleRange>
      <xsl:if test="@xml2idml:insert-special-char-method eq 'after'">
        <xsl:sequence select="xml2idml:insert-special-char-wrapper(.)"/>
      </xsl:if>
      <xsl:if test="@xml2idml:insert-content-method eq 'after'">
        <xsl:sequence select="xml2idml:insert-content-wrapper(.)"/>
      </xsl:if>
    </xsl:variable>
    <xsl:variable name="psr" as="element(*)+">
      <xsl:choose>
        <xsl:when test="$pstyle">
          <ParagraphStyleRange AppliedParagraphStyle="{$pstyle}">
            <xsl:sequence select="$csr" />
          </ParagraphStyleRange>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="$csr" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="$psr" />
  </xsl:template>

  <xsl:template match="*[@aid:cstyle][@xml2idml:is-footnote]" mode="xml2idml:storify" priority="2.3">
    <Footnote>
      <xsl:next-match/>
    </Footnote>
  </xsl:template>

  <!-- for finding source to a given destination: -->
  <xsl:key name="linking-item-by-source" match="*[@xml2idml:hyperlink-source]" use="@xml2idml:hyperlink-source" />
  <!-- for finding destination to a given source: -->
  <xsl:key name="linking-item-by-dest" match="*[@xml2idml:hyperlink-dest]" use="@xml2idml:hyperlink-dest" />
  
  <xsl:template match="*[@aid:cstyle][@xml2idml:hyperlink-source]" mode="xml2idml:storify" priority="2.2">
    <xsl:variable name="destination" as="element(*)?" select="key('linking-item-by-dest', @xml2idml:hyperlink-source)"/>
    <xsl:choose>
      <xsl:when test="$destination or matches(@xml2idml:hyperlink-source, '^(www|http|ftp)')">
        <HyperlinkTextSource Hidden="false" AppliedCharacterStyle="n" Name="{concat('Hyperlink ', generate-id())}" Self="{generate-id()}">
          <xsl:next-match/>
        </HyperlinkTextSource>
      </xsl:when>
      <xsl:otherwise>
        <xsl:next-match/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="*[@aid:cstyle][@xml2idml:hyperlink-dest]" mode="xml2idml:storify" priority="2.2">
    <xsl:variable name="source" as="element(*)*" select="key('linking-item-by-source', @xml2idml:hyperlink-dest)"/>
    <xsl:choose>
      <xsl:when test="$source">
        <HyperlinkTextDestination Hidden="false" Name="{@xml2idml:hyperlink-dest}" DestinationUniqueKey="{concat('00', count(preceding::node()))}" Self="{concat('HyperlinkTextDestination/', @xml2idml:hyperlink-dest)}">
          <xsl:next-match/>
        </HyperlinkTextDestination>
      </xsl:when>
      <xsl:otherwise>
        <xsl:next-match/>
        <xsl:message select="'############# could not find link source for destination: ', @xml2idml:hyperlink-dest"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*[@xml2idml:is-block-image]" mode="xml2idml:storify" priority="2.3">
    <xsl:choose>
      <xsl:when test="not(@aid:pstyle)">
        <ParagraphStyleRange AppliedParagraphStyle="ParagraphStyle/Figure">
          <CharacterStyleRange AppliedCharacterStyle="CharacterStyle/$ID/[No character style]">
            <xsl:sequence select="xml2idml:create-image-container(.)"/>
          </CharacterStyleRange>
        </ParagraphStyleRange>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="xml2idml:create-image-container(.)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*[@xml2idml:is-inline-image]" mode="xml2idml:storify" priority="2.3">
    <xsl:sequence select="xml2idml:create-image-container(.)"/>
  </xsl:template>

  <xsl:function name="xml2idml:create-image-container" as="element()?">
    <xsl:param name="mapped-image" as="element()"/>
    <xsl:variable name="created-image" as="element()?">
      <xsl:choose>
        <xsl:when test="not(unparsed-text-available($mapped-image/@xml2idml:image-path)) and
                        not(unparsed-text-available(concat($mapped-image/@xml2idml:image-path, '.ASCII')))">
          <xsl:sequence select="xml2idml:output-warning-image-path-not-available($mapped-image)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="new-image" as="element(xml2idml:image)"
            select="xml2idml:get-image-info($mapped-image)"/>
          <xsl:variable name="width-in-pt" as="xs:double"
            select="xs:double($new-image/@width) * 0.75"/>
          <xsl:variable name="height-in-pt" as="xs:double"
            select="xs:double($new-image/@height) * 0.75"/>
          <Rectangle Self="image_{generate-id($mapped-image)}"
                       AppliedObjectStyle="ObjectStyle/$ID/[None]"
                       ItemTransform="1 0 0 1 0 0">
               <Properties>
                  <PathGeometry>
                     <GeometryPathType PathOpen="false">
                       <!--<PathPointArray>
                          <PathPoint Anchor="{$left} {$top}" LeftDirection="{$left} {$top}" RightDirection="{$left} {$top}"/>
                          <PathPoint Anchor="{$left} {$bottom}" LeftDirection="{$left} {$bottom}" RightDirection="{$left} {$bottom}"/>
                          <PathPoint Anchor="{$right} {$bottom}" LeftDirection="{$right} {$bottom}" RightDirection="{$right} {$bottom}"/>
                          <PathPoint Anchor="{$right} {$top}" LeftDirection="{$right} {$top}" RightDirection="{$right} {$top}"/>
                        </PathPointArray>-->
                        <PathPointArray>
                          <PathPointType Anchor="-{$width-in-pt div 2} -{$height-in-pt div 2}"
                            LeftDirection="-{$width-in-pt div 2} -{$height-in-pt div 2}"
                            RightDirection="-{$width-in-pt div 2} -{$height-in-pt div 2}"/>
                          <PathPointType Anchor="-{$width-in-pt div 2} {$height-in-pt div 2}"
                            LeftDirection="-{$width-in-pt div 2} {$height-in-pt div 2}"
                            RightDirection="-{$width-in-pt div 2} {$height-in-pt div 2}"/>
                          <PathPointType Anchor="{$width-in-pt div 2} {$height-in-pt div 2}"
                            LeftDirection="{$width-in-pt div 2} {$height-in-pt div 2}"
                            RightDirection="{$width-in-pt div 2} {$height-in-pt div 2}"/>
                          <PathPointType Anchor="{$width-in-pt div 2} -{$height-in-pt div 2}"
                            LeftDirection="{$width-in-pt div 2} -{$height-in-pt div 2}"
                            RightDirection="{$width-in-pt div 2} -{$height-in-pt div 2}"/>
                        </PathPointArray>
                     </GeometryPathType>
                  </PathGeometry>
               </Properties>
               <EPS Self="image_eps_{generate-id($mapped-image)}"
                 ItemTransform="1 0 0 1 -{$width-in-pt div 2} -{$height-in-pt div 2}">
                  <Link Self="image_eps_link_{generate-id($mapped-image)}"
                    LinkResourceURI="{if(not(starts-with($mapped-image/@xml2idml:image-path, 'file:'))) 
                                      then concat('file:/', $mapped-image/@xml2idml:image-path) 
                                      else $mapped-image/@xml2idml:image-path}"
                        LinkResourceFormat="$ID/EPS"/>
               </EPS>
            </Rectangle>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="$created-image"/>
  </xsl:function>
  
  <xsl:function name="xml2idml:get-image-info" as="element(xml2idml:image)">
    <xsl:param name="mapped-image" as="element()"/>
    <xsl:variable name="mime-type" as="xs:string"
      select="tr:fileext-to-mime-type($mapped-image/@xml2idml:image-path)"/>
    <xsl:variable name="unparsed-text" as="xs:string*"
      select="if(unparsed-text-available(concat($mapped-image/@xml2idml:image-path, '.ASCII')))
              then unparsed-text(concat($mapped-image/@xml2idml:image-path, '.ASCII'))
              else unparsed-text($mapped-image/@xml2idml:image-path)"/>
    <xsl:variable name="new-image" as="element(xml2idml:image)">
      <xml2idml:image>
        <xsl:attribute name="mime-type" select="$mime-type"/>
        <xsl:choose>
          <xsl:when test="$mime-type eq 'image/x-eps'">
            <xsl:variable name="boundingbox" as="xs:string"
              select="tokenize($unparsed-text,
                        '\n'
                      )[matches(., '^%%(HiRes)?BoundingBox:')][last()]"/>
            <xsl:attribute name="width" select="replace($boundingbox, '^[^:]+:\s[-]?[\d.]+\s[-]?[\d.]+\s([\d.]+)\s[\d.]+$', '$1')"/>
            <xsl:attribute name="height" select="replace($boundingbox, '^[^:]+:\s[-]?[\d.]+\s[-]?[\d.]+\s[\d.]+\s([\d.]+)$', '$1')"/>
            <xsl:attribute name="height" select="replace($boundingbox, '^[^:]+:\s[-]?[\d.]+\s[-]?[\d.]+\s[\d.]+\s([\d.]+)$', '$1')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:message select="'xml2idml, function xml2idml:get-image-info: mime-type of ', $mapped-image/@xml2idml:image-path, 'unknown!'"/>
            <xsl:attribute name="width" select="($mapped-image/@css:width, '0')[1]"/>
            <xsl:attribute name="height" select="($mapped-image/@css:height, '0')[1]"/>
          </xsl:otherwise>
        </xsl:choose>
      </xml2idml:image>
    </xsl:variable>
    <xsl:sequence select="$new-image"/>
  </xsl:function>
  
  <xsl:function name="xml2idml:output-warning-image-path-not-available" as="element(CharacterStyleRange)">
    <xsl:param name="mapped-image" as="element()"/>
    <xsl:variable name="csr" as="element(CharacterStyleRange)">
      <CharacterStyleRange AppliedCharacterStyle="CharacterStyle/$ID/_ImageNotFound">
        <Content>
          <xsl:value-of select="'WARNING: Image', $mapped-image/@xml2idml:image-path, 'could not be found!'"/>
        </Content>
      </CharacterStyleRange>
    </xsl:variable>
    <xsl:sequence select="$csr"/>
    <xsl:message select="'WARNING: Image', $mapped-image/@xml2idml:image-path, 'could not be found!'"/>
  </xsl:function>

  <xsl:template match="*[/*/@retain-tagging eq 'true']
                        [not(namespace-uri() = 'http://transpect.io/xml2idml')]
                        [not(
                             self::*:tr[parent::*[@aid:table eq 'table']]
                          or self::*:colgroup[parent::*[@aid:table eq 'table']]
                          or self::*:col[../parent::*[@aid:table eq 'table']]
                         )]" mode="xml2idml:storify" priority="2">
    <XMLElement Self="elt_{generate-id()}" MarkupTag="XMLTag/{name()}">
      <xsl:if test="ancestor::*[@xml2idml:keep-xml-space-preserve eq 'true'] and
                    @xml:space eq 'preserve'">
        <xsl:attribute name="xml:space" select="'preserve'"/>
      </xsl:if>
      <xsl:apply-templates select="@*" mode="xml2idml:storify_atts" />
      <!-- default template rules or table: -->
      <xsl:next-match/>
    </XMLElement>
  </xsl:template>

  <!-- n.b.: same as above, without the negation -->
  <xsl:template match="xml2idml:*" mode="xml2idml:storify" priority="2">
    <xsl:element name="{local-name()}">
      <xsl:apply-templates select="@*, node()" mode="#current" />
    </xsl:element>
  </xsl:template>

  <xsl:template match="@AppliedParagraphStyle | @AppliedCharacterStyle" mode="xml2idml:storify">
    <xsl:attribute name="{name()}" select="xml2idml:escape-stylename(.)" />
  </xsl:template>

  <xsl:template match="@aid:pstyle" mode="xml2idml:storify">
    <xsl:attribute name="AppliedParagraphStyle" select="concat('ParagraphStyle/', xml2idml:escape-stylename(.))" />
  </xsl:template>

  <xsl:template match="@aid:cstyle" mode="xml2idml:storify">
    <xsl:attribute name="AppliedCharacterStyle" select="concat('CharacterStyle/', xml2idml:escape-stylename(.))" />
  </xsl:template>

  <xsl:function name="xml2idml:escape-stylename" as="xs:string">
    <xsl:param name="name" as="xs:string" />
    <!-- shouldn't have CharacterStyle/ etc. at the beginning -->
    <xsl:sequence select="replace(replace($name, ':', '%3a'), '^([^%]+Style)%2f', concat('$1', '/'))" />
  </xsl:function>

  <xsl:function name="xml2idml:insert-special-char-wrapper" as="element(CharacterStyleRange)">
    <xsl:param name="cstyle-node" as="element(*)" />
    <xsl:sequence select="xml2idml:insert-csr-wrapper(
                            (xs:string($cstyle-node/@xml2idml:insert-special-format), '')[1],
                            xml2idml:insert-special-char($cstyle-node/@xml2idml:insert-special-char)
                          )"/>
  </xsl:function>

  <xsl:function name="xml2idml:insert-content-wrapper" as="element(CharacterStyleRange)">
    <xsl:param name="cstyle-node" as="element(*)" />
    <xsl:variable name="content" as="element(Content)">
      <Content>
        <xsl:value-of select="$cstyle-node/@xml2idml:insert-content"/>
      </Content>
    </xsl:variable>
    <xsl:sequence select="xml2idml:insert-csr-wrapper(
                            ($cstyle-node/@xml2idml:insert-content-format, $cstyle-node/@aid:cstyle)[1],
                            $content
                          )"/>
  </xsl:function>

  <xsl:function name="xml2idml:insert-csr-wrapper" as="element(CharacterStyleRange)">
    <xsl:param name="csr-format" as="xs:string" />
    <xsl:param name="content" as="node()*" />
    <CharacterStyleRange>
      <xsl:if test="$csr-format ne ''">
        <xsl:attribute name="AppliedCharacterStyle" 
          select="concat('CharacterStyle/', $csr-format)"/>
      </xsl:if>
      <xsl:sequence select="$content"/>
    </CharacterStyleRange>
  </xsl:function>

  <!-- output of this function will be wrapped with <CharacterStyleRange> -->
  <xsl:function name="xml2idml:insert-special-char" as="node()*">
    <xsl:param name="character-name" />
    <xsl:variable name="content" as="node()*">
      <xsl:choose>
        <xsl:when test="$character-name eq 'tabulator'">
          <Content xml:space="preserve"><xsl:value-of select="'&#x9;'"/></Content>
        </xsl:when>
        <xsl:when test="$character-name eq 'line-break'">
          <Content><xsl:value-of select="'&#x2028;'"/></Content>
        </xsl:when>
        <xsl:when test="$character-name eq 'page-break'">
          <xsl:attribute name="ParagraphBreakType" select="'NextPage'"/>
          <Br/>
        </xsl:when>
        <xsl:when test="$character-name eq 'page-odd-break'">
          <xsl:attribute name="ParagraphBreakType" select="'NextOddPage'"/>
          <Br/>
        </xsl:when>
        <xsl:when test="$character-name eq 'page-even-break'">
          <xsl:attribute name="ParagraphBreakType" select="'NextEvenPage'"/>
          <Br/>
        </xsl:when>
        <xsl:when test="$character-name eq 'column-break'">
          <xsl:attribute name="ParagraphBreakType" select="'NextColumn'"/>
          <Br/>
        </xsl:when>
        <xsl:when test="$character-name eq 'frame-break'">
          <xsl:attribute name="ParagraphBreakType" select="'NextFrame'"/>
          <Br/>
        </xsl:when>
        <xsl:when test="$character-name eq 'stop-nested-style'">
          <xsl:processing-instruction name="ACE" select="'3'"/>
        </xsl:when>
        <xsl:when test="$character-name eq 'footnote-symbol'">
          <xsl:processing-instruction name="ACE" select="'4'"/>
        </xsl:when>
        <xsl:when test="$character-name eq 'indent-to-here'">
          <xsl:processing-instruction name="ACE" select="'7'"/>
        </xsl:when>
        <xsl:when test="$character-name eq 'right-indent-tab'">
          <xsl:processing-instruction name="ACE" select="'8'"/>
        </xsl:when>
        <xsl:when test="$character-name eq 'section-marker'">
          <xsl:processing-instruction name="ACE" select="'19'"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message terminate="no" select="'WARNING: Unknown special char: ', $character-name" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="$content"/>
  </xsl:function>

  <xsl:template match="@*[/*/@retain-tagging eq 'true']" mode="xml2idml:storify_atts">
    <XMLAttribute Self="att_{generate-id()}" Name="{name()}" Value="{.}" />
  </xsl:template>

  <xsl:template match="@xml2idml:hidden | @xml2idml:condition" mode="xml2idml:storify_atts" />

  <xsl:template match="*[@aid:table eq 'table']" mode="xml2idml:storify" priority="1.5">
    <xsl:variable name="base-id" select="concat('tb_', generate-id())" as="xs:string"/>
    <Table Self="{$base-id}">
      <xsl:apply-templates select="  @aid5:tablestyle 
                                   | (@data-colcount, *:tbody/@data-colcount)[1]
                                   | @data-rowcount
                                   | *[local-name() = ('thead', 'tbody', 'tfoot')]/@data-rowcount" mode="#current" />
      <xsl:apply-templates select="." mode="xml2idml:storify_table-declarations" />
      <!-- default template rules (i.e., process content): -->
      <xsl:next-match/>
    </Table>
  </xsl:template>

  <xsl:template match="@aid:table" mode="xml2idml:storify" />

  <xsl:template match="@data-colcount" mode="xml2idml:storify">
    <xsl:attribute name="ColumnCount" select="." />
  </xsl:template>

   <xsl:template match="*:table/@data-rowcount" mode="xml2idml:storify">
      <xsl:attribute name="BodyRowCount" select="."/>
   </xsl:template>

  <xsl:template match="*:thead/@data-rowcount" mode="xml2idml:storify">
    <xsl:attribute name="HeaderRowCount" select="." />
  </xsl:template>

  <xsl:template match="*:tbody/@data-rowcount" mode="xml2idml:storify">
    <xsl:attribute name="BodyRowCount" select="." />
  </xsl:template>

  <xsl:template match="*:tfoot/@data-rowcount" mode="xml2idml:storify">
    <xsl:attribute name="FooterRowCount" select="." />
  </xsl:template>

  <xsl:template match="@aid5:tablestyle" mode="xml2idml:storify">
    <xsl:attribute name="AppliedTableStyle" select="concat('TableStyle/', xml2idml:escape-stylename(.))" />
  </xsl:template>

  <xsl:template match="@aid5:cellstyle" mode="xml2idml:storify">
    <xsl:attribute name="AppliedCellStyle" select="concat('CellStyle/', xml2idml:escape-stylename(.))" />
    <xsl:attribute name="AppliedCellStylePriority" select="(if (../@xml2idml:cellStylePriority = 'higher') then 2
                                                           else if (../@xml2idml:cellStylePriority = 'lower') then -1
                                                           else 0)
                                                           + (../@data-rownum, 0)[1]" />
  </xsl:template>

  <xsl:template match="*[@aid:table eq 'table']" mode="xml2idml:storify_table-declarations">
    <xsl:variable name="context" select="." as="element(*)"/>
    <xsl:for-each select="0 to xs:integer((@data-rowcount, count(*:tr))[1]) - 1">
      <Row Self="{concat('tb_', generate-id($context))}Row{.}" Name="{.}"/>
    </xsl:for-each>
    <xsl:variable name="temporary-colgroup" as="element(colgroup)?">
      <xsl:if test="not(*:tbody/*:colgroup/*:col | *:colgroup/*:col | *:col)">
        <colgroup>
          <xsl:for-each select="1 to xs:integer((@data-colcount, *:tbody/@data-colcount)[1])">
            <col/>
          </xsl:for-each>
        </colgroup>
      </xsl:if>
    </xsl:variable>
    <xsl:apply-templates select="*:tbody/*:colgroup/*:col | *:colgroup/*:col | *:col | $temporary-colgroup" mode="#current" />
  </xsl:template>

  <xsl:variable name="xml2idml:use-main-story-width-for-tables" select="false()" as="xs:boolean"/>
  
  <xsl:variable name="xml2idml:use-main-story-width-for-textframes" select="false()" as="xs:boolean"/>

  <xsl:variable name="xml2idml:main-story-in-template" as="element(Story)?"
    select="(
              collection()[2]
                //Story[
                  .//CharacterStyleRange[@AppliedConditions eq 'Condition/storytitle'][. eq 'main']
              ]
            )[1]"/>

  <xsl:variable name="xml2idml:main-story-textframes-in-template" as="element(TextFrame)*"
    select="collection()[2]
              //TextFrame[
                @ParentStory = $xml2idml:main-story-in-template/@Self
              ]"/>

  <!-- get TextColumnFixedWidth from first main story TextFrame -->
  <xsl:variable name="xml2idml:main-story-TextColumnFixedWidth" as="xs:string?"
    select="(
              $xml2idml:main-story-in-template/TextFramePreference/@TextColumnFixedWidth,
              if ($xml2idml:main-story-in-template)
              then xs:string(
                idml2xml:get-shape-width(
                  ($xml2idml:main-story-textframes-in-template)[1]
                )
              )
              else ''
            )[1]"/>

  <xsl:template match="*:col" mode="xml2idml:storify_table-declarations">
    <xsl:variable name="width" as="xs:string"
      select="if (not($xml2idml:use-main-story-width-for-tables) and @css:width) 
              then @css:width 
              else 
                if ($xml2idml:main-story-TextColumnFixedWidth ne '') 
                then concat(
                  xs:double($xml2idml:main-story-TextColumnFixedWidth) div count(../*:col),
                  'pt'
                )
                else '2000'"/><!-- 2000 is a default twips value (100pt) -->
    <Column Self="col_{generate-id()}_{position() - 1}" Name="{position() - 1}"
      SingleColumnWidth="{(tr:length-to-unitless-twip($width), 2000)[1] * 0.05}" />
  </xsl:template>


  <xsl:template match="*[@xml2idml:ObjectStyle]" mode="xml2idml:storify" priority="5">
    <xsl:variable name="AppliedObjectStyle" select="concat('ObjectStyle/', @xml2idml:ObjectStyle)" as="xs:string" />
    <xsl:variable name="text-width" as="xs:string"
      select="if (not($xml2idml:use-main-story-width-for-textframes) and @css:width) 
              then @css:width 
              else 
                if ($xml2idml:main-story-TextColumnFixedWidth ne '') 
                then concat(
                  xs:double($xml2idml:main-story-TextColumnFixedWidth),
                  'pt'
                )
                else '2000'"/>
    <TextFrame Self="tf_{generate-id()}"
      PreviousTextFrame="n"
      NextTextFrame="n"
      ContentType="TextType"
      AppliedObjectStyle="{$AppliedObjectStyle}"
      xml2idml:anchoring="{@xml2idml:anchoring}">
      <xsl:if test="$xml2idml:use-main-story-width-for-textframes">
        <TextFramePreference TextColumnFixedWidth="{(tr:length-to-unitless-twip($text-width), 2000)[1] * 0.05}" 
                             UseFixedColumnWidth="true"
                             AutoSizingType="HeightOnly"
                             AutoSizingReferencePoint="TopCenterPoint"/>
      </xsl:if>
      <xsl:if test="exists($expanded-template)">
        <xsl:copy-of select="key('object', $AppliedObjectStyle, $expanded-template)[1]/*" />
      </xsl:if>
      <!-- will match the idPkg:Story template rule: -->
      <xsl:next-match/>
    </TextFrame>
  </xsl:template>


  <!-- TextFrame anchoring cleanup: move to next psr when 'inline' or create psr for 'empty-para' -->
  <xsl:template mode="xml2idml:storify_content-n-cleanup" priority="3"
    match="*[TextFrame[@xml2idml:anchoring]]">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:for-each-group select="node()" group-starting-with="TextFrame">
        <xsl:choose>
          <xsl:when test="@xml2idml:anchoring eq 'inline' and
                          current-group()[2][self::ParagraphStyleRange]">
            <ParagraphStyleRange>
              <xsl:apply-templates select="current-group()[2]/@*" mode="#current"/>
              <CharacterStyleRange AppliedCharacterStyle="CharacterStyle/$ID/[No character style]">
                <xsl:apply-templates select="current-group()[1]" mode="#current"/>
              </CharacterStyleRange>
              <xsl:apply-templates select="current-group()[2]/node()" mode="#current"/>
            </ParagraphStyleRange>
            <xsl:apply-templates select="current-group()[position() gt 2]" mode="#current"/>
          </xsl:when>
          <xsl:when test="@xml2idml:anchoring eq 'empty-para' and
                          not(ancestor::ParagraphStyleRange)">
            <ParagraphStyleRange AppliedParagraphStyle="{(parent::xml2idml:ParagraphStyleRange/@AppliedParagraphStyle, 'ParagraphStyle/$ID/NormalParagraphStyle')[1]}">
              <CharacterStyleRange AppliedCharacterStyle="CharacterStyle/$ID/[No character style]">
                <xsl:apply-templates select="current-group()[1]" mode="#current"/>
                <Br />
              </CharacterStyleRange>
            </ParagraphStyleRange>
            <xsl:apply-templates select="current-group()[position() gt 1]" mode="#current"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="current-group()" mode="#current"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each-group>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="text()[not(normalize-space())][not(ancestor::ParagraphStyleRange)]" mode="xml2idml:storify_content-n-cleanup" priority="3"/>

  <!-- remove any text not mapped to a textframe or story -->
  <xsl:template match="xml2idml:stories/Content" mode="xml2idml:storify_content-n-cleanup" priority="10"/>
  <xsl:template match="xml2idml:stories/text()" mode="xml2idml:storify_content-n-cleanup" priority="10"/>
  <xsl:template match="@xml2idml:keep-xml-space-preserve" mode="xml2idml:storify_content-n-cleanup"/>
 
  <xsl:variable name="xml2idml:ignorable-property-elements" as="xs:string*"
    select="('TextFramePreference', 'BaselineFrameGridOption', 'Hyperlink')"/>

  <xsl:function name="xml2idml:is-children-of-any-settings-element" as="xs:boolean">
    <xsl:param name="context" as="node()"/>
    <xsl:sequence select="exists($context/ancestor::*[local-name() = $xml2idml:ignorable-property-elements])"/>
  </xsl:function>

  <!-- The next stylerange when looking upwards is a ParagraphStyleRange (i.e., CharacterStyleRange is missing yet) -->
  <xsl:template match="node()
                             [
                                not(xml2idml:is-children-of-any-settings-element(.))
                             ][
                                self::text()[not(parent::Contents)] or 
                                self::Table or 
                                self::Footnote or 
                                self::Note or 
                                self::TextFrame[not(parent::Group)]
                             ][
                               (ancestor::ParagraphStyleRange | ancestor::CharacterStyleRange)[last()]/self::ParagraphStyleRange
                               or
                               self::Table[not(ancestor::CharacterStyleRange)]
                             ]"
    mode="xml2idml:storify_content-n-cleanup" priority="2">
    <CharacterStyleRange AppliedCharacterStyle="CharacterStyle/$ID/[No character style]">
      <xsl:next-match/>
    </CharacterStyleRange>
  </xsl:template>

  <xsl:template match="Table[ not(ancestor::ParagraphStyleRange) ] | Cell/Table" 
    mode="xml2idml:storify_content-n-cleanup" priority="3">
    <ParagraphStyleRange AppliedParagraphStyle="ParagraphStyle/$ID/NormalParagraphStyle">
      <xsl:next-match/>
      <Br/>
    </ParagraphStyleRange>
  </xsl:template>

  <xsl:template match="Footnote[ not(ParagraphStyleRange) ]" 
    mode="xml2idml:storify_content-n-cleanup" priority="3">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <ParagraphStyleRange AppliedParagraphStyle="ParagraphStyle/$ID/NormalParagraphStyle">
        <xsl:apply-templates select="node()" mode="#current"/>
      </ParagraphStyleRange>
    </xsl:copy>
  </xsl:template>

  <!-- resolve nested inline paragraph-break, todo: nested break in mid of a lot of cstyle ranges -->
  <xsl:template match="CharacterStyleRange[
                         .//CharacterStyleRange[@ParagraphBreakType]
                       ]" 
    mode="xml2idml:storify_content-n-cleanup" priority="3">
    <xsl:if test=".//node()[self::text() or self::CharacterStyleRange][1][ 
                      . is (current()//CharacterStyleRange[@ParagraphBreakType])[1]
                  ]">
      <xsl:sequence select="(.//CharacterStyleRange[@ParagraphBreakType])[1]"/>
    </xsl:if>
    <xsl:next-match/>
    <xsl:if test="count(.//node()[self::text() or self::CharacterStyleRange]) gt 1 and
                  .//node()[self::text() or self::CharacterStyleRange][last()][ 
                      . is (current()//CharacterStyleRange[@ParagraphBreakType])[last()]
                  ]">
      <xsl:sequence select="(.//CharacterStyleRange[@ParagraphBreakType])[last()]"/>
    </xsl:if>
  </xsl:template>
  <xsl:template match="CharacterStyleRange//CharacterStyleRange[@ParagraphBreakType]/Br" 
    mode="xml2idml:storify_content-n-cleanup"/>
  <!-- remove 2nd <Br/> in paragraphs with ParagraphBreakType 
       (only when there is no more content is after the ParagraphBreak) -->
  <xsl:template match=" ParagraphStyleRange
                        /Br[
                          preceding-sibling::node()[1][
                            self::CharacterStyleRange[
                              @ParagraphBreakType
                            ]/Br
                          ]
                        ]" mode="xml2idml:storify_content-n-cleanup"/>

  <!-- disassemble invalid csr in csr construct (i.e., created by nested special-char) -->
  <xsl:template match="CharacterStyleRange
                         [ancestor::*[not(self::XMLElement)][1]/self::CharacterStyleRange]" 
    mode="xml2idml:storify_content-n-cleanup" priority="2">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>

  <!-- text node without surrounding Content element -->
  <xsl:template match="text()[not(xml2idml:is-children-of-any-settings-element(.))]
                             [not(parent::Content or parent::Contents)]" mode="xml2idml:storify_content-n-cleanup">
    <Content>
      <xsl:choose>
        <xsl:when test="ancestor::*[@xml2idml:keep-xml-space-preserve eq 'true'] and 
                        ancestor::*[@xml:space eq 'preserve']">
          <xsl:attribute name="xml:space" select="'preserve'"/>
          <xsl:value-of select="."/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="replace(., '\s+', ' ')"/>
        </xsl:otherwise>
      </xsl:choose>
    </Content>
  </xsl:template>

  <xsl:template match="processing-instruction('ACE')[not(parent::Content)]" mode="xml2idml:storify_content-n-cleanup">
    <Content>
      <xsl:copy-of select="."/>
    </Content>
  </xsl:template>

  <xsl:template match="@xml2idml:anchoring" mode="xml2idml:storify_content-n-cleanup" />
  
  <xsl:template match="CrossReference[matches(@Self, 'Topicn')]/@Self" mode="xml2idml:storify_content-n-cleanup">
    <xsl:attribute name="Self" select="generate-id()"/>
  </xsl:template>

</xsl:stylesheet>
