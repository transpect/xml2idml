<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
  version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"
  xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/"
  xmlns:idPkg = "http://ns.adobe.com/AdobeInDesign/idml/1.0/packaging"
  xmlns:xml2idml="http://www.le-tex.de/namespace/xml2idml"
  xmlns:idml2xml  = "http://www.le-tex.de/namespace/idml2xml"
  xmlns:letex="http://www.le-tex.de/namespace"
  xmlns:css="http://www.w3.org/1996/css"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="css letex xs xml2idml idml2xml"
  >

  <xsl:import href="http://transpect.le-tex.de/idml2xml/xslt/common-functions.xsl" />
  <xsl:import href="http://transpect.le-tex.de/xslt-util/lengths/lengths.xsl" />

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
    <xml2idml:stories>
      <xsl:copy-of select="*/@xml2idml:keep-stories,
                           */@xml2idml:keep-xml-space-preserve" />
      <xsl:apply-templates mode="#current" />
    </xml2idml:stories>
  </xsl:template>

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
       To do: honor @xml:space='preserve'. 

       A terminal Br in Stories, Footnotes, and Cells will be removed.

       -->

  <xsl:template match="*[@xml2idml:storyname]" mode="xml2idml:storify" priority="4">
    <!-- DOMVersion 8.0: CS6 -->
    <idPkg:Story DOMVersion="8.0" xml:base="{concat($base-uri, '/Stories/st_', generate-id(), '.xml')}">
      <Story Self="st_{generate-id()}" StoryTitle="{@xml2idml:storyname}">
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
    <idPkg:Story DOMVersion="8.0" xml:base="{concat($base-uri, '/Stories/st_', generate-id(), '.xml')}">
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
    <Cell Self="{$base-id}" 
      Name="{@data-colnum - 1}:{@data-rownum - 1}"
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

  <xsl:template match="*[@aid:pstyle]" mode="xml2idml:storify" priority="3">
    <ParagraphStyleRange>
      <xsl:apply-templates select="@xml2idml:condition" mode="#current"/>
      <xsl:apply-templates select="@css:* | @aid:pstyle" mode="#current" />
      <xsl:next-match>
        <xsl:with-param name="pstyle" select="()" tunnel="yes" />
      </xsl:next-match>
      <Br/>
    </ParagraphStyleRange>
  </xsl:template>

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

  <xsl:variable name="xml2idml:icon-element-role-regex" as="xs:string"
    select="'^icon|hru-infobox-icon$'"/>

  <xsl:function name="xml2idml:icon-reference-name" as="xs:string">
    <xsl:param name="el" as="element(*)"/>
    <xsl:sequence select="$el"/>
  </xsl:function>

  <xsl:template match="*:span[matches(@class, $xml2idml:icon-element-role-regex)]" mode="xml2idml:storify" priority="1">
    <xsl:variable name="new-story-id" select="concat('st_icon_', generate-id())" as="xs:string"/>
    <xsl:variable name="icon-lookup" as="element(*)?"
      select="key('icon', xml2idml:icon-reference-name(.), $expanded-template)"/>
    <xsl:choose>
      <xsl:when test="$icon-lookup">
        <xsl:apply-templates select="$icon-lookup" mode="xml2idml:reproduce-icons">
          <xsl:with-param name="new-story-id" select="$new-story-id" tunnel="yes"/>
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
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current" />
      <xsl:attribute name="ParentStory" select="$new-story-id"/>
      <xsl:attribute name="Self" select="concat('TextFrame_', $new-story-id)"/>
      <xsl:apply-templates select="*" mode="#current" />
      <!-- Let's just hope that this id is unique enough. It isn't if there's an error
           that no two docs may be written to the same URL -->
      <xsl:variable name="newer-story-id" select="string-join(($new-story-id, string(position())), '_')" as="xs:string"/>
      <xsl:apply-templates select="key( 'story', current()/@ParentStory, $expanded-template )" mode="#current">
        <xsl:with-param name="new-story-id" select="$newer-story-id" tunnel="yes"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="Group" mode="xml2idml:reproduce-icons">
    <xsl:param name="new-story-id" as="xs:string" tunnel="yes"/>
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current" />
      <xsl:attribute name="Self" select="concat('Group_', $new-story-id)"/>
      <xsl:apply-templates select="*" mode="#current" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="Story" mode="xml2idml:reproduce-icons">
    <xsl:param name="new-story-id" as="xs:string" tunnel="yes"/>
    <idPkg:Story DOMVersion="8.0" xml:base="{concat($base-uri, '/Stories/', $new-story-id, '.xml')}">
      <xsl:copy copy-namespaces="no">
        <xsl:attribute name="Self" select="$new-story-id"/>
        <xsl:apply-templates select="@* except @Self, node()" mode="#current" />
      </xsl:copy>
    </idPkg:Story>
  </xsl:template>

  <xsl:template match="@xml2idml:condition" mode="xml2idml:storify">
    <xsl:attribute name="AppliedConditions" select="concat('Condition/', .)" />
  </xsl:template>

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
        <xsl:apply-templates select="@xml2idml:condition" mode="#current"/>
        <xsl:choose>
          <xsl:when test="@xml2idml:insert-special-char-method eq 'replace'">
            <xsl:attribute name="AppliedCharacterStyle" 
              select="concat('CharacterStyle/', (@xml2idml:insert-special-char-format, @aid:cstyle,'$ID/[No character style]')[1])"/>
            <xsl:sequence select="xml2idml:insert-special-char(@xml2idml:insert-special-char)"/>
          </xsl:when>
          <xsl:when test="@xml2idml:insert-content-method eq 'replace'">
            <xsl:attribute name="AppliedCharacterStyle" 
              select="concat('CharacterStyle/', (@xml2idml:insert-content-format, @aid:cstyle, '$ID/[No character style]')[1])"/>
              <xsl:message select="'inner:', concat('CharacterStyle/', (@xml2idml:insert-content-format, @aid:cstyle, '$ID/[No character style]')[1])"/>
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

  <xsl:template match="*[not(namespace-uri() = 'http://www.le-tex.de/namespace/xml2idml')]
                        [not(
                             self::*:tr[parent::*[@aid:table eq 'table']]
                          or self::*:colgroup[parent::*[@aid:table eq 'table']]
                          or self::*:col[../parent::*[@aid:table eq 'table']]
                         )]" mode="xml2idml:storify" priority="2">
    <XMLElement Self="elt_{generate-id()}" MarkupTag="XMLTag/{name()}">
      <xsl:if test="/*/@xml2idml:keep-xml-space-preserve eq 'yes'
                    and @xml:space eq 'preserve'">
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
                            xs:string($cstyle-node/@xml2idml:insert-special-format),
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

  <xsl:function name="xml2idml:insert-special-char" as="node()">
    <xsl:param name="character-name" />
    <xsl:variable name="content" as="node()">
      <xsl:choose>
        <xsl:when test="$character-name eq 'tabulator'">
          <Content xml:space="preserve"><xsl:value-of select="'&#x9;'"/></Content>
        </xsl:when>
        <xsl:when test="$character-name eq 'line-break'">
          <Content><xsl:value-of select="'&#x2028;'"/></Content>
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

  <xsl:template match="@*" mode="xml2idml:storify_atts">
    <XMLAttribute Self="att_{generate-id()}" Name="{name()}" Value="{.}" />
  </xsl:template>

  <xsl:template match="@xml2idml:hidden | @xml2idml:condition" mode="xml2idml:storify_atts" />

  <xsl:template match="*[@aid:table eq 'table']" mode="xml2idml:storify" priority="1.5">
    <xsl:variable name="base-id" select="concat('tb_', generate-id())" as="xs:string"/>
    <Table Self="{$base-id}">
      <xsl:apply-templates select="  @aid5:tablestyle 
                                   | *:tbody/@data-colcount | @data-colcount
                                   | *:tbody/@data-rowcount | @data-rowcount" mode="#current" />
      <xsl:apply-templates select="." mode="xml2idml:storify_table-declarations" />
      <!-- default template rules (i.e., process content): -->
      <xsl:next-match/>
    </Table>
  </xsl:template>

  <xsl:template match="@aid:table" mode="xml2idml:storify" />

  <xsl:template match="@data-colcount" mode="xml2idml:storify">
    <xsl:attribute name="ColumnCount" select="." />
  </xsl:template>

  <!-- §§§ provisional (headers) -->
  <xsl:template match="@data-rowcount" mode="xml2idml:storify">
    <xsl:attribute name="BodyRowCount" select="." />
    <xsl:attribute name="HeaderRowCount" select="0" />
    <xsl:attribute name="FooterRowCount" select="0" />
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
    <xsl:apply-templates select="*:tbody/*:colgroup/*:col | *:colgroup/*:col | *:col" mode="#current" />
  </xsl:template>

  <xsl:template match="*:col" mode="xml2idml:storify_table-declarations">
    <!-- 2000 is a default twips value (100pt) -->
    <xsl:variable name="width" select="if (@css:width) then @css:width else '2000'"/>
    <Column Self="col_{generate-id()}_{position() - 1}" Name="{position() - 1}"
      SingleColumnWidth="{(letex:length-to-unitless-twip($width), 2000)[1] * 0.05}" />
  </xsl:template>


  <xsl:template match="*[@xml2idml:ObjectStyle]" mode="xml2idml:storify" priority="5">
    <xsl:variable name="AppliedObjectStyle" select="concat('ObjectStyle/', @xml2idml:ObjectStyle)" as="xs:string" />
    <TextFrame Self="tf_{generate-id()}"
      PreviousTextFrame="n"
      NextTextFrame="n"
      ContentType="TextType"
      AppliedObjectStyle="{$AppliedObjectStyle}"
      xml2idml:anchoring="{@xml2idml:anchoring}">
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
            <xsl:apply-templates select="current-group()[position() gt 2]" mode="#current"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="current-group()" mode="#current"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each-group>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="text()[not(normalize-space())][not(ancestor::ParagraphStyleRange)]" mode="xml2idml:storify_content-n-cleanup" priority="3"/>
 
  <!-- The next stylerange when looking upwards is a ParagraphStyleRange (i.e., CharacterStyleRange is missing yet) -->
  <xsl:template match="node()[self::text() or self::Table or self::Footnote or self::Note or self::TextFrame]
                             [(ancestor::ParagraphStyleRange | ancestor::CharacterStyleRange)[last()]/self::ParagraphStyleRange]"
    mode="xml2idml:storify_content-n-cleanup" priority="2">
    <CharacterStyleRange AppliedCharacterStyle="CharacterStyle/$ID/[No character style]">
      <xsl:next-match/>
    </CharacterStyleRange>
  </xsl:template>

  <!-- disassemble invalid csr in csr construct (i.e., created by nested special-char) -->
  <xsl:template match="CharacterStyleRange[
                         ancestor::*[not(self::XMLElement)][1]/self::CharacterStyleRange
                       ]" mode="xml2idml:storify_content-n-cleanup" priority="2">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>

  <xsl:template match="text()[not(parent::Content)]" mode="xml2idml:storify_content-n-cleanup">
    <Content>
      <xsl:choose>
        <xsl:when test="//@xml2idml:keep-xml-space-preserve eq 'yes' and ancestor::*[@xml:space eq 'preserve']">
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

  <!-- Unwrap additional ParagraphStyleRange immediately below Story if there's an indication
       that proper ParagraphStyleRanges have been created below. -->
  <xsl:template match="ParagraphStyleRange[XMLElement/ParagraphStyleRange]"
    mode="xml2idml:storify_content-n-cleanup____">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>


  <!-- Remove a Br at the end of a story, a footnote, or a table cell (with no content after it).
       These Brs have been inserted in the previous pass, after each paragraph. 
       Ok, the pattern's predicate looks weird. Suggestions on how to simplify it? -->
  <xsl:template mode="xml2idml:storify_content-n-cleanup"
    match="Br[for $scoper in ancestor::*[idml2xml:is-scope-origin(.)][1]
              (: a let statement might come in handy here – if only for the sake of syntactic sweetness :)
              return 
                current() is (
                              $scoper//*[name() = $idml2xml:idml-scope-terminal-names]
                                [idml2xml:same-scope(., $scoper)]
                             )[last()]
             ]
             (: We'll reprieve the last Br in the Document :)
             [not(. is (//Br)[last()])]
           " />

  <xsl:template match="@xml2idml:anchoring" mode="xml2idml:storify_content-n-cleanup" />


</xsl:stylesheet>
