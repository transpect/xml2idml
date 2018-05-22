<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xslout="bogo"
  xmlns:xml2idml="http://transpect.io/xml2idml"
  xmlns:htmltable="http://transpect.io/htmltable"
  xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"
  xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/"
  xmlns:tr="http://transpect.io"
  xmlns:saxon="http://saxon.sf.net/"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  >

  <xsl:namespace-alias 
     stylesheet-prefix="xslout" 
     result-prefix="xsl" />

  <xsl:output
     method="xml"
     encoding="UTF-8"
     indent="yes"
     />

  <xsl:param name="debug" as="xs:string?" />

  <xsl:variable name="root" select="/" as="document-node()"/>

  <!-- default xslt-pipeline when no pipeline is given in mapping-instructions -->
  <xsl:variable name="xslt-pipeline-default" as="document-node()">
    <xsl:document>
      <xml2idml:xslt-pipeline/>
    </xsl:document>
  </xsl:variable>

  <!-- variable to save non-mapping configuration for xml2idml XProc steps storify and merge -->
  <xsl:variable name="other-mapping-configuration" as="element(OtherMappingConfiguration)">
    <OtherMappingConfiguration>
      <xsl:sequence select="/xml2idml:mapping-instructions/xml2idml:Pages"/>
      <!--<xsl:copy-of select="/xml2idml:mapping-instructions/xml2idml:TemplateDefaultOverrides"/>-->
    </OtherMappingConfiguration>
  </xsl:variable>

  <xsl:variable name="collect-included-instructions" as="element(xml2idml:collect-included-instructions)">
    <xsl:element name="xml2idml:collect-included-instructions">
      <xsl:apply-templates select="/xml2idml:mapping-instructions/xml2idml:include-mapping" 
      mode="xml2idml:collect-included-instructions">
        <xsl:with-param name="lowest-priority-of-parent" tunnel="yes"
          select="min((//xml2idml:mapping-instructions//xml2idml:path/@priority, 0))"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:variable>

  <xsl:variable name="included-mappings" as="element(xml2idml:mapping-instructions)">
      <!-- set apply start point to innermost mapping-instructions, 
       then apply parent mapping-instructions (and so on) for overwrite importance  -->
    <xsl:element name="xml2idml:mapping-instructions">
      <xsl:apply-templates select="$collect-included-instructions//xml2idml:mapping-instructions[not(xml2idml:mapping-instructions)]" mode="xml2idml:set-lower-priority-and-clean" />
    </xsl:element>
  </xsl:variable>

  <xsl:template match="include-mapping"
    xpath-default-namespace="http://transpect.io/xml2idml"
    mode="xml2idml:collect-included-instructions">
    <xsl:param name="lowest-priority-of-parent" select="0" tunnel="yes" as="xs:double"/>

    <xsl:variable name="lowest-priority-of-current" as="xs:double"
      select="min((doc(@href)/mapping-instructions//path/@priority, 0))"/>

    <xsl:variable name="highest-priority-of-current" as="xs:double"
      select="max((doc(@href)/mapping-instructions//path/@priority, 0))"/>

    <xsl:variable name="lowhighest-possible-priority-for-current" as="xs:double"
      select="$lowest-priority-of-parent + $lowest-priority-of-current + (-1 * abs($highest-priority-of-current)) - 1"/>

    <mapping-instructions included="true" 
      lowhighest-possible-priority-for-current="{$lowhighest-possible-priority-for-current}"
      xmlns="http://transpect.io/xml2idml">
      <xsl:apply-templates mode="#current" select="doc(@href)/mapping-instructions/@*"/>
      <xsl:apply-templates mode="#current" select="doc(@href)/mapping-instructions/node()">
        <xsl:with-param name="lowest-priority-of-parent" tunnel="yes"
          select="$lowhighest-possible-priority-for-current"/>
      </xsl:apply-templates>
    </mapping-instructions>
  </xsl:template>

  <xsl:template mode="xml2idml:collect-included-instructions"
    match="*[local-name() = ('ParaStyles', 'InlineStyles', 'TableStyles', 'CellStyles', 'ObjectStyles')]" >
    <xsl:apply-templates select="." /><!-- default mode! -->
  </xsl:template>

  <!-- template-match: in mode xml2idml:set-lower-priority-and-clean 
       the namespace already changed from xslout to xsl -->

  <xsl:template match="xsl:template[@match]" mode="xml2idml:set-lower-priority-and-clean">
    <xsl:param name="lowhighest-possible-priority-for-current" tunnel="yes" as="xs:double"/>
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current" />
      <!-- set new priority: an included template cannot have more importance than the including one -->
      <xsl:attribute name="priority"
        select="xs:double((@priority, 0)[1]) + $lowhighest-possible-priority-for-current"/>
      <xsl:apply-templates select="node()" mode="#current" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="mapping-instructions" mode="xml2idml:set-lower-priority-and-clean"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:apply-templates mode="#current"
      select="@*, 
              ancestor::mapping-instructions[1]/@*,
              ancestor::mapping-instructions[1],
              node()[not(self::mapping-instructions)]">
      <xsl:with-param name="lowhighest-possible-priority-for-current" as="xs:double"
        select="@lowhighest-possible-priority-for-current" tunnel="yes"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="mapping-instructions/import" mode="xml2idml:set-lower-priority-and-clean"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:if test="not(@href = ancestor::mapping-instructions[2]/import/@href)">
      <xsl:copy-of select="." />
    </xsl:if>
  </xsl:template>

  <xsl:template match="mapping-instructions/xslt-pipeline" mode="xml2idml:set-lower-priority-and-clean"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:if test="not(ancestor::mapping-instructions[2][xslt-pipeline])">
      <xsl:copy-of select="."/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="mapping-instructions/inline" mode="xml2idml:set-lower-priority-and-clean"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:if test="not(ancestor::mapping-instructions[2][inline])">
      <xsl:copy-of select="."/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="mapping-instructions/Discard" mode="xml2idml:set-lower-priority-and-clean"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:if test="not(ancestor::mapping-instructions[2][Discard])">
      <xsl:copy-of select="."/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="mapping-instructions/Stories" mode="xml2idml:set-lower-priority-and-clean"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:if test="not(ancestor::mapping-instructions[2][Stories])">
      <xsl:copy-of select="."/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="mapping-instructions/Pages" mode="xml2idml:set-lower-priority-and-clean"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:if test="not(ancestor::mapping-instructions[2][Pages])">
      <xsl:copy-of select="."/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="@* | node() | comment() | processing-instruction()" 
    mode="xml2idml:set-lower-priority-and-clean xml2idml:collect-included-instructions">
    <xsl:copy>
      <xsl:apply-templates select="@*, node()" mode="#current" />
    </xsl:copy>
  </xsl:template>


  <xsl:template match="/mapping-instructions"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:stylesheet 
      version="2.0" 
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"
      xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/"
      xmlns:letex="http://www.le-tex.de/namespace"	
      xmlns:xml2idml="http://transpect.io/xml2idml"
      xmlns:saxon="http://saxon.sf.net/"
      xmlns:idPkg="http://ns.adobe.com/AdobeInDesign/idml/1.0/packaging"
      xmlns:xs="http://www.w3.org/2001/XMLSchema"
      xmlns:css="http://www.w3.org/1996/css"
      xmlns="http://ns.adobe.com/AdobeInDesign/4.0/"
      >
      
      <xsl:copy-of select="$included-mappings/@xpath-default-namespace,
                           @xpath-default-namespace" />
      
      <xslout:import href="{resolve-uri('util.xsl')}" />
      <xslout:import href="http://transpect.io/xslt-util/lengths/xsl/lengths.xsl" />
      <xsl:apply-templates select="import[not(@href = $included-mappings/import/@href)],
                                   $included-mappings/import"/>
      <xsl:apply-templates select="if(not(inline)) 
                                   then $included-mappings/inline
                                   else inline" />
      
      <xslout:output method="xml" encoding="UTF-8" indent="no" />
      <xslout:output name="debug" method="xml" encoding="UTF-8" indent="yes" />

      <xslout:variable name="retain-tagging" as="xs:boolean">
        <xsl:attribute name="select" select="if(@retain-tagging eq 'true') then 'true()' else 'false()'"/>
      </xslout:variable>

      <xsl:text>&#xa;&#xa;</xsl:text>
      <xsl:comment select="' PIPELINE '"/>
      <xsl:text>&#xa;  </xsl:text>
      <xsl:choose>
        <xsl:when test="not(xslt-pipeline)">
          <xsl:choose>
            <xsl:when test="$included-mappings/xslt-pipeline">
              <xsl:apply-templates select="$included-mappings/xslt-pipeline"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="$xslt-pipeline-default"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="xslt-pipeline"/>
        </xsl:otherwise>
      </xsl:choose>

      <xsl:text>&#xa;&#xa;</xsl:text>
      <xsl:comment select="' GENERATED RULES '"/>
      <xsl:text>&#xa;  </xsl:text>

      <xsl:apply-templates select="if(not(Stories/mapping-instruction)) 
                                   then $included-mappings/Stories/mapping-instruction
                                   else ()" />
      <xsl:apply-templates select="if(not(Stories[keep])) 
                                   then $included-mappings/Stories[keep]
                                   else Stories[keep]" />
      <xsl:apply-templates select="if(not(Discard)) 
                                   then $included-mappings/Discard/mapping-instruction
                                   else ()" />
      <xsl:apply-templates select="*/mapping-instruction"/>

      <xsl:copy-of select="$included-mappings/*:template"/>

    </xslout:stylesheet>

  </xsl:template>

  <xsl:template match="Discard/mapping-instruction"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:template match="{normalize-space(path)}" mode="xml2idml:{name(..)}" />
  </xsl:template>

  <!-- The stories to be kept will be inserted as Attributes to /*
       in xml2idml:Discard mode. Reason: While there may well be situations
       where someone wants to attach xml2idml:storyname attributes to /*
       (or style attributes in the other modes), nobody will discard /*. 
       So it seems safe to abuse xml2idml:Discard for listing the stories
       to be kept. -->
  <xsl:template match="Stories[
                         keep[
                           if (@debug-only eq 'true')
                           then ($debug = 'yes')
                           else false()
                         ]
                       ]"
                       xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:param name="included-mapping" tunnel="yes"/>
    <xslout:template match="/*" mode="xml2idml:Discard">
      <xslout:copy copy-namespaces="no">
        <xslout:copy-of select="@*" />
        <xslout:attribute name="xml2idml:keep-stories" select="'{keep/name}'" />
        <xslout:apply-templates mode="#current" />
      </xslout:copy>
    </xslout:template>
  </xsl:template>

  <xsl:template match="Pages/Spread"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:template match="{@MainStoryXPath}" mode="xml2idml:Stories">
      <xslout:copy copy-namespaces="no">
        <xslout:copy-of select="@*" />
        <xslout:attribute name="xml2idml:storyname" select="'{@MainStoryName}'" />
        <xslout:apply-templates mode="#current" />
      </xslout:copy>
    </xslout:template>
  </xsl:template>

  <xsl:template match="Stories/mapping-instruction"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:template match="{normalize-space(path)}" mode="xml2idml:{name(..)}">
      <xslout:copy copy-namespaces="no">
        <xslout:copy-of select="@*" />
        <xsl:if test="@keep-xml-space-preserve">
          <xslout:attribute name="xml2idml:keep-xml-space-preserve" select="'{@keep-xml-space-preserve}'" />
        </xsl:if>
        <xsl:apply-templates select="." mode="xml2idml:style-atts" />
        <xslout:apply-templates mode="#current" />
      </xslout:copy>
    </xslout:template>
  </xsl:template>

  <xsl:template match="ParaStyles/mapping-instruction[nest]"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:template match="{normalize-space(path)}" mode="xml2idml:{name(..)}">
      <xsl:apply-templates select="path/@priority" mode="#current" />
      <xslout:copy copy-namespaces="no">
        <xslout:copy-of select="@*" />
        <xsl:apply-templates select="." mode="xml2idml:style-atts" />
        <xml2idml:ParagraphStyleRange AppliedParagraphStyle="{xml2idml:escaped-style-name('ParagraphStyle', (format, '$ID/NormalParagraphStyle')[1])}">
          <xslout:apply-templates mode="#current" />
        </xml2idml:ParagraphStyleRange>
      </xslout:copy>
    </xslout:template>
  </xsl:template>

  <xsl:template match="path/@priority" xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:attribute name="priority" select="." />
  </xsl:template>

  <xsl:template match="ParaStyles/mapping-instruction[wrap]"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:template match="{normalize-space(path)}" mode="xml2idml:{name(..)}">
      <xsl:apply-templates select="path/@priority" mode="#current" />
      <xml2idml:ParagraphStyleRange AppliedParagraphStyle="{xml2idml:escaped-style-name('ParagraphStyle', (format, '$ID/NormalParagraphStyle')[1])}">
        <xslout:next-match/>
        <xml2idml:Br/>
      </xml2idml:ParagraphStyleRange>
    </xslout:template>
  </xsl:template>

  <xsl:template match="mapping-instruction"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:template match="{normalize-space(path)}" mode="xml2idml:{name(..)}">
      <xsl:apply-templates select="path/@priority" mode="#current" />
      <xslout:copy copy-namespaces="no">
        <xslout:copy-of select="@*" />
        <xsl:apply-templates select="." mode="xml2idml:style-atts" />
        <xslout:apply-templates mode="#current" />
      </xslout:copy>
    </xslout:template>
    <!-- Scaling, snap to grid for table and object styles -->
    <xsl:apply-templates select="width" />
  </xsl:template>
  
  <xsl:template match="Dissolve/mapping-instruction"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:template match="{normalize-space(path)}" mode="xml2idml:Dissolve">
      <xslout:choose>
        <xslout:when test=". instance of attribute()"/>
        <xslout:when test="@aid:* or @aid5:*">
          <xslout:message select="'Info: cannot dissolve mapped element:', name()"/>
          <xslout:next-match/>
        </xslout:when>
        <xslout:otherwise>
          <xsl:apply-templates select="path/@priority" mode="#current"/>
          <xslout:apply-templates select="@*, node()" mode="#current"/>
        </xslout:otherwise>
      </xslout:choose>
    </xslout:template>
  </xsl:template>

  <!-- Width / snap to grid 
       By virtue of xsl:next-match, will invoke the standard templates for the aid5:tablestyle / aid5:cellstyle
       attribute attachment, but with a twist: the params of width (e.g., scaling factor, grid) will be passed 
       on to the standard templates.
       -->
  <xsl:template match="TableStyles/mapping-instruction/width[@type eq 'xml2idml:snap-scaled-to-grid']"
    priority="2"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:template match="{normalize-space(../path)}" mode="htmltable:tables-add-atts" priority="2">
      <xsl:apply-templates select="../path/@priority" mode="#current" />
      <xsl:comment>Width / snap to grid</xsl:comment>
      <xslout:next-match>
        <xsl:apply-templates select="param"/>
      </xslout:next-match>
    </xslout:template>
  </xsl:template>

  <xsl:template match="param"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:with-param tunnel="yes">
      <xsl:copy-of select="@*" />
    </xslout:with-param>
  </xsl:template>

  <xsl:template match="TableStyles/mapping-instruction/width" priority="-0.5"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:message>
      Non-implemented width processing:
      <xsl:copy-of select="."/>
    </xsl:message>
  </xsl:template>

  <xsl:template match="TableStyles/mapping-instruction/*[self::width or self::height][@type eq 'xml2idml:static-dimension']" 
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:template match="{normalize-space(../path)}" mode="htmltable:tables-add-atts" priority="2">
      <xsl:apply-templates select="../path/@priority" mode="#current" />
      <xsl:comment>Width / snap to grid</xsl:comment>
      <xslout:next-match>
        <xslout:with-param name="grid" select="{@select}" />
        <xslout:with-param name="scaling" select="1" />
      </xslout:next-match>
    </xslout:template>
  </xsl:template>

  <xsl:template match="TableStyles/mapping-instruction/*[self::width or self::height][@type eq 'xml2idml:from-cells']" 
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:template match="{normalize-space(../path)}" mode="htmltable:tables-add-atts" priority="2">
      <xsl:apply-templates select="../path/@priority" mode="#current" />
      <xslout:apply-imports />
    </xslout:template>
  </xsl:template>


  <!-- Won't be treated in default mode (wich meant: create own xmlout template).
       Static widths will rather be treated when creating the objectstyle attributes
       in mode xml2idml:style-atts.
       It's difference from tables because of the table size calculations / scalings /
       snap to grid that need to take place in separate modes. -->
  <xsl:template match="ObjectStyles/mapping-instruction/width" xpath-default-namespace="http://transpect.io/xml2idml"/>

  <xsl:template match="ObjectStyles/mapping-instruction/*[self::width or self::height][@type eq 'xml2idml:static-dimension']" 
    xpath-default-namespace="http://transpect.io/xml2idml" mode="xml2idml:style-atts">
    <xslout:attribute name="xml2idml:{name()}" select="tr:length-to-unitless-twip({@select}) * 0.05" />
  </xsl:template>
  

  <xsl:template match="import"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:import href="{if (not (matches(@href, '^(file|https?):')))
                          then resolve-uri(@href)
                          else @href}" />
  </xsl:template>

  <xsl:template match="inline"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:copy-of select="node()" />
  </xsl:template>

  <xsl:template match="xslt-pipeline"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:variable name="augmented-pipeline" as="element(xslt-pipeline)">
      <xsl:copy xmlns="http://transpect.io/xml2idml">
        <xsl:copy-of select="*[@before eq 'xml2idml:Discard']" />
        <step mode="xml2idml:Discard"/>
        <xsl:copy-of select="*[@before eq 'xml2idml:Stories']" />
        <step mode="xml2idml:Stories"/>
        <xsl:copy-of select="*[@before eq 'xml2idml:ParaStyles']" />
        <step mode="xml2idml:ParaStyles"/>
        <xsl:copy-of select="*[@before eq 'xml2idml:InlineStyles']" />
        <step mode="xml2idml:InlineStyles"/>
        <xsl:copy-of select="*[@before eq 'xml2idml:TableStyles']" />
        <step mode="xml2idml:TableStyles"/>
        <xsl:copy-of select="*[@before eq 'xml2idml:CellStyles']" />
        <step mode="xml2idml:CellStyles"/>
        <xsl:copy-of select="*[@before eq 'xml2idml:ObjectStyles']" />
        <step mode="xml2idml:ObjectStyles"/>
        <xsl:copy-of select="*[@before eq 'xml2idml:PullUpNestedInlines']" />
        <step mode="xml2idml:PullUpNestedInlines"/>
        <xsl:if test="$root//Dissolve">
          <step mode="xml2idml:Dissolve"/>
        </xsl:if>
        <xsl:copy-of select="*[not(@before)]" />
      </xsl:copy>
    </xsl:variable>
    <!-- Create the micropipeline in the target XSLT: -->
    <xsl:apply-templates select="$augmented-pipeline/step[1]" mode="#current">
      <xsl:with-param name="input-xpath-expr" select="'/'" />
    </xsl:apply-templates>

    <xsl:text>&#xa;&#xa;</xsl:text>
    <xsl:comment select="' OTHER NAMED TEMPLATES (for intermediate results) '"/>
    <xsl:text>&#xa;  </xsl:text>
    <xsl:for-each select="$augmented-pipeline/step">
      <xslout:template name="{replace(@mode, '^.+:', '')}">
        <xslout:sequence select="${@mode}" />
      </xslout:template>
    </xsl:for-each>

    <xsl:text>&#xa;&#xa;</xsl:text>
    <xsl:comment select="' INITIAL TEMPLATE '"/>
    <xsl:text>&#xa;  </xsl:text>
    <xslout:template name="main">
      <xslout:sequence select="${$augmented-pipeline/step[last()]/@mode}" />
    </xslout:template>

    <xslout:function name="xml2idml:is-mapped-block-element" as="xs:boolean">
      <xslout:param name="node" as="node()"/>
      <xslout:sequence select="boolean($node/self::*[@aid:pstyle or @aid:table or @xml2idml:is-footnote = 'yes'])"/>
    </xslout:function>

    <xslout:template match="*[@aid:cstyle]
                             [*[@aid:cstyle]]
                             [not(xml2idml:is-mapped-block-element(.))]" mode="xml2idml:PullUpNestedInlines">
      <xslout:variable name="context" select="." as="element(*)"/>
      <xslout:for-each select="node()">
        <xslout:choose>
          <xslout:when test=". instance of text()">
            <xslout:element name="{{$context/name()}}">
              <xslout:sequence select="$context/@*"/>
              <xslout:value-of select="."/>
            </xslout:element>
          </xslout:when>
          <xslout:when test="@aid:cstyle and not(xml2idml:is-mapped-block-element(.))">
            <xslout:apply-templates select="." mode="#current"/>
          </xslout:when>
          <xslout:otherwise>
            <xslout:copy>
              <xslout:apply-templates select="@*, node()" mode="#current"/>
            </xslout:copy>
          </xslout:otherwise>
        </xslout:choose>
      </xslout:for-each>
    </xslout:template>

    <xsl:variable name="pages-config" as="element(xml2idml:Pages)?"
      select="if(not($other-mapping-configuration/xml2idml:Pages)) 
              then $included-mappings/Pages 
              else $other-mapping-configuration/xml2idml:Pages"/>

    <!-- save other configuration for later usage in xml2idml -->
    <xslout:template match="/*" mode="{$augmented-pipeline/step[last()]/@mode}" priority="1000">
      <xslout:copy>
        <xslout:apply-templates select="@*" mode="#current" />
        <xsl:if test="$other-mapping-configuration/xml2idml:Pages
                      or
                      (
                        $included-mappings/Pages 
                        and not($root/xml2idml:mapping-instructions/xml2idml:Stories)
                      )">
          <xslout:element name="xml2idml:OtherMappingConfiguration">
            <xsl:sequence select="$pages-config"/>
          </xslout:element>
        </xsl:if>
        <xslout:apply-templates select="node()" mode="#current" />
      </xslout:copy>
    </xslout:template>

    <xsl:text>&#xa;&#xa;</xsl:text>
    <xsl:comment select="' IDENTITY TEMPLATE '"/>
    <xsl:text>&#xa;  </xsl:text>
    <!-- Declare identity templates as needed in the imported stylesheets 
         (can't generate them here because they'd have higher import precedence
         than any of the imported templates) -->
    <xslout:template match="* | @* | processing-instruction()"
      mode="xml2idml:Discard xml2idml:Stories xml2idml:ParaStyles xml2idml:InlineStyles xml2idml:TableStyles xml2idml:CellStyles xml2idml:ObjectStyles xml2idml:PullUpNestedInlines xml2idml:Dissolve" priority="-100">
      <xslout:copy copy-namespaces="no">
        <xslout:apply-templates select="@*, node()" mode="#current" />
      </xslout:copy>
    </xslout:template>

    <xslout:template match="/*"
      mode="xml2idml:Discard" priority="200">
      <xslout:copy>
        <xslout:attribute name="retain-tagging" 
          select="$retain-tagging"/>
        <xslout:apply-templates select="@*, node()" mode="#current"/>
      </xslout:copy>
    </xslout:template>
    
    <xslout:template match="*[ancestor::*][not(@aid:* or @aid5:* or @xml2idml:ObjectStyle)]" mode="xml2idml:Dissolve" priority="-50">
      <xslout:message select="'Unmapped element:', name()"/>
      <xslout:copy>
        <xslout:attribute name="xml2idml:unmapped"/><!-- empty! -->
        <xslout:apply-templates select="@*, node()" mode="#current"/>
      </xslout:copy>
    </xslout:template>
    
    <xslout:template match="*[ancestor::*][not(@aid:* or @aid5:* or @xml2idml:ObjectStyle)]/@*" mode="xml2idml:Dissolve" priority="-50">
      <xslout:message select="' - with unmapped attribute, not in output now:', name()"/>
    </xslout:template>
    
    <xsl:text>&#xa;&#xa;&#xa;</xsl:text>
    <xsl:comment>GENERATED RULES FROM PAGES CONFIG</xsl:comment>
    <xsl:text>&#xa;  </xsl:text>
    <!-- create/output templates here for a main story in Pages configuration -->
    <xsl:apply-templates select="$pages-config/xml2idml:Spread"/>
    <!-- create/output templates here for other stories in Pages configuration -->
    <xsl:apply-templates select="$pages-config/xml2idml:Spread/xml2idml:Stories/*"/>

  </xsl:template>

  <xsl:template match="xslt-pipeline/step"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xsl:param name="input-xpath-expr" as="xs:string" />
    <xslout:variable name="{@mode}">
      <xslout:apply-templates select="{$input-xpath-expr}" mode="{@mode}"/>
    </xslout:variable>
    <xsl:apply-templates select="following-sibling::step[1]" mode="#current">
      <!-- A global variable with the same name as the mode's: -->
      <xsl:with-param name="input-xpath-expr" select="concat('$', @mode)" />
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="Stories/mapping-instruction" mode="xml2idml:style-atts"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:attribute name="xml2idml:storyname" select="'{name}'" />
  </xsl:template>

  <xsl:template match="ParaStyles/mapping-instruction" mode="xml2idml:style-atts"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:attribute name="aid:pstyle" select="'{(xml2idml:escape-style-name(format), '$ID/NormalParagraphStyle')[. ne ''][1]}'" />
    <xsl:if test="condition">
      <xslout:attribute name="xml2idml:condition" select="'{condition}'" />
      <xsl:if test="condition/@hidden = 'true'">
        <xslout:attribute name="xml2idml:hidden" select="'true'" />
      </xsl:if>
    </xsl:if>
    <xsl:if test="@is-image eq 'true'">
      <xslout:attribute name="xml2idml:is-block-image" select="'true'" />
      <xslout:attribute name="xml2idml:image-path" select="{@path-to-image-uri}" />
    </xsl:if>
  </xsl:template>

  <xsl:template match="InlineStyles/mapping-instruction" mode="xml2idml:style-atts"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:attribute name="aid:cstyle" select="'{(xml2idml:escape-style-name(format), '$ID/[No character style]')[. ne ''][1]}'" />
    <xsl:if test="condition">
      <xslout:attribute name="xml2idml:condition" select="'{condition}'" />
      <xsl:if test="condition/@hidden = 'true'">
        <xslout:attribute name="xml2idml:hidden" select="'true'" />
      </xsl:if>
    </xsl:if>
    <xsl:if test="xml2idml:insert-special-char/@name">
      <xslout:attribute name="xml2idml:insert-special-char" select="'{insert-special-char/@name}'" />
      <xslout:attribute name="xml2idml:insert-special-char-method" select="'{insert-special-char/@method}'" />
    </xsl:if>
    <xsl:if test="xml2idml:insert-special-char/@format[. ne '']">
      <xslout:attribute name="xml2idml:insert-special-char-format" select="'{insert-special-char/@format}'" />
    </xsl:if>
    <xsl:if test="xml2idml:insert-content">
      <xslout:attribute name="xml2idml:insert-content" select="'{insert-content/@content}'" />
      <xslout:attribute name="xml2idml:insert-content-method" select="'{insert-content/@method}'" />
    </xsl:if>
    <xsl:if test="xml2idml:insert-content/@format[. ne '']">
      <xslout:attribute name="xml2idml:insert-content-format" select="'{insert-content/@format}'" />
    </xsl:if>
    <xsl:if test="@is-footnote">
      <xslout:attribute name="xml2idml:is-footnote" select="'yes'" />
    </xsl:if>
    <xsl:if test="@hyperlink-source">
      <xslout:attribute name="xml2idml:hyperlink-source" select="{@hyperlink-source}" />
    </xsl:if>
    <xsl:if test="@hyperlink-dest">
      <xslout:attribute name="xml2idml:hyperlink-dest" select="{@hyperlink-dest}" />
    </xsl:if>
    <xsl:if test="xs:integer(@is-indexterm-level) gt 3">
      <xsl:message select="'Warning: Indexlevel 4 or more not supported. Please check your mappings.'"></xsl:message>
    </xsl:if>
    <xsl:if test="@is-indexterm-level and xs:integer(@is-indexterm-level) lt 4 and not(@is-indexterm-crossref eq 'true')">
      <xslout:attribute name="xml2idml:is-indexterm-level" select="{@is-indexterm-level}" />
    </xsl:if>
    <xsl:if test="@is-indexterm-crossref eq 'true'">
      <xslout:attribute name="xml2idml:is-indexterm-level" select="{@is-indexterm-level}" />
      <xslout:attribute name="xml2idml:is-indexterm-crossref" select="'true'" />
      <xslout:attribute name="xml2idml:crossref-type" select="'{@crossref-type}'" />
    </xsl:if>
    <xsl:if test="@is-image eq 'true'">
      <xslout:attribute name="xml2idml:is-inline-image" select="'true'" />
      <xslout:attribute name="xml2idml:image-path" select="{@path-to-image-uri}" />
    </xsl:if>
  </xsl:template>
  <xsl:template match="ObjectStyles/mapping-instruction" mode="xml2idml:style-atts"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:attribute name="xml2idml:ObjectStyle" select="'{(xml2idml:escape-style-name(format), '$ID/[None]')[. ne ''][1]}'" />
    <xslout:attribute name="xml2idml:anchoring" select="'{xml2idml:anchoring/@type}'" />
    <xsl:apply-templates select="width | height" mode="#current" />
  </xsl:template>
  <xsl:template match="TableStyles/mapping-instruction" mode="xml2idml:style-atts"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:attribute name="aid5:tablestyle" select="'{(xml2idml:escape-style-name(format), '$ID/[No table style]')[. ne ''][1]}'" />
    <xslout:attribute name="aid:table" select="'table'" />
  </xsl:template>
  <xsl:template match="CellStyles/mapping-instruction" mode="xml2idml:style-atts"
    xpath-default-namespace="http://transpect.io/xml2idml">
    <xslout:attribute name="aid5:cellstyle" select="'{(xml2idml:escape-style-name(format), '$ID/[None]')[. ne ''][1]}'" />
    <xslout:attribute name="aid:table" select="'cell'" />
    <xsl:apply-templates select="format/@priority" mode="#current" />
  </xsl:template>

  <xsl:template match="CellStyles/mapping-instruction/format/@priority" 
    xpath-default-namespace="http://transpect.io/xml2idml" mode="xml2idml:style-atts">
    <xslout:attribute name="xml2idml:cellStylePriority" select="'{.}'" />
  </xsl:template>

  <xsl:function name="xml2idml:escaped-style-name" as="xs:string">
    <xsl:param name="style-type" as="xs:string" />
    <xsl:param name="unescaped-style-name" as="xs:string?" />
    <xsl:variable name="escaped-style-name" as="xs:string">
      <xsl:choose>
        <xsl:when test="$style-type eq 'CharacterStyle' and not($unescaped-style-name)">
          <xsl:sequence select="'$ID/[No character style]'" />
        </xsl:when>
        <xsl:when test="not($unescaped-style-name)">
          <xsl:sequence select="'UNDEFINED'" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="xml2idml:escape-style-name($unescaped-style-name)" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="concat($style-type, '/', $escaped-style-name)" />
  </xsl:function>

  <xsl:function name="xml2idml:escape-style-name" as="xs:string">
    <xsl:param name="unescaped-style-name" as="xs:string?"/>
    <xsl:sequence select="replace($unescaped-style-name, ':', '%3a')" />
  </xsl:function>

</xsl:stylesheet>
