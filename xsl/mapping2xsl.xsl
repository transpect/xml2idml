<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
   version="2.0" 
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xslout="bogo"
   xmlns:xml2idml="http://www.le-tex.de/namespace/xml2idml"
   xmlns:htmltable="http://www.le-tex.de/namespace/htmltable"
   xmlns:letex="http://www.le-tex.de/namespace"
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

  <xsl:template match="/mapping-instructions"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:stylesheet 
      version="2.0" 
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"
      xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/"
      xmlns:letex="http://www.le-tex.de/namespace"	
      xmlns:xml2idml="http://www.le-tex.de/namespace/xml2idml"
      xmlns:saxon="http://saxon.sf.net/"
      xmlns:idPkg="http://ns.adobe.com/AdobeInDesign/idml/1.0/packaging"
      xmlns:xs="http://www.w3.org/2001/XMLSchema"
      xmlns:css="http://www.w3.org/1996/css"
      xmlns="http://ns.adobe.com/AdobeInDesign/4.0/"
      >
      <xsl:variable name="included-mapping" as="element(mapping-instructions)?"
        select="doc(include-mapping/@href)/mapping-instructions"/>

      <xsl:if test="$included-mapping[include-mapping]">
        <xsl:message terminate="yes" 
          select="'&#xa;ERROR: Element xml2idml:include-mapping in included mapping not supported!'"/>
      </xsl:if>

      <xsl:copy-of select="@xpath-default-namespace, $included-mapping/@xpath-default-namespace" />

      <xslout:import href="{resolve-uri('util.xsl')}" />
      <xslout:import href="http://transpect.le-tex.de/xslt-util/lengths/lengths.xsl" />
      <xsl:apply-templates select="$included-mapping/import, import[@href != $included-mapping/import/@href]" />
      <xsl:apply-templates select="inline, $included-mapping/inline" />
      <xslout:output method="xml" encoding="UTF-8" indent="no" />
      <xslout:output name="debug" method="xml" encoding="UTF-8" indent="yes" />

      <xsl:text>&#xa;&#xa;</xsl:text>
      <xsl:comment select="' PIPELINE '"/>
      <xsl:text>&#xa;  </xsl:text>
      <xsl:apply-templates select="xslt-pipeline | $included-mapping/xslt-pipeline" />

      <xsl:text>&#xa;&#xa;</xsl:text>
      <xsl:comment select="' GENERATED RULES '"/>
      <xsl:text>&#xa;  </xsl:text>
      <xsl:apply-templates select="  $included-mapping/Stories[keep[name != Stories/keep/name]]
                                   | Stories[keep[name != $included-mapping/Stories/keep/name]] 
                                   | */mapping-instruction 
                                   | $included-mapping/*/mapping-instruction">
        <xsl:with-param name="included-mapping" select="$included-mapping" tunnel="yes"/>
      </xsl:apply-templates>

    </xslout:stylesheet>

  </xsl:template>

  <xsl:template match="Discard/mapping-instruction"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:template match="{path}" mode="xml2idml:{name(..)}" />
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
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xsl:param name="included-mapping" tunnel="yes"/>
    <xslout:template match="/*" mode="xml2idml:Discard">
      <xslout:copy copy-namespaces="no">
        <xslout:copy-of select="@*" />
        <xslout:attribute name="xml2idml:keep-stories" select="'{keep/name}'" />
        <xslout:attribute name="xml2idml:keep-xml-space-preserve" 
          select="'{if(
                        $included-mapping//Stories[keep/name[ . eq current()/keep/name]]/@keep-xml-space-preserve eq 'true'
                          and 
                        not(@keep-xml-space-preserve eq 'false')
                        or
                        @keep-xml-space-preserve eq 'true'
                      ) 
                    then 'yes' else 'no'}'" />
        <xslout:apply-templates mode="#current" />
      </xslout:copy>
    </xslout:template>
  </xsl:template>

  <xsl:template match="Stories/mapping-instruction"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:template match="{path}" mode="xml2idml:{name(..)}">
      <xslout:copy copy-namespaces="no">
        <xslout:copy-of select="@*" />
        <xsl:apply-templates select="." mode="xml2idml:style-atts" />
        <xslout:apply-templates mode="#current" />
      </xslout:copy>
    </xslout:template>
  </xsl:template>

  <xsl:template match="ParaStyles/mapping-instruction[nest]"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:template match="{path}" mode="xml2idml:{name(..)}">
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

  <xsl:template match="path/@priority" xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xsl:attribute name="priority" select="." />
  </xsl:template>

  <xsl:template match="ParaStyles/mapping-instruction[wrap]"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:template match="{path}" mode="xml2idml:{name(..)}">
      <xsl:apply-templates select="path/@priority" mode="#current" />
      <xml2idml:ParagraphStyleRange AppliedParagraphStyle="{xml2idml:escaped-style-name('ParagraphStyle', (format, '$ID/NormalParagraphStyle')[1])}">
        <xslout:next-match/>
        <xml2idml:Br/>
      </xml2idml:ParagraphStyleRange>
    </xslout:template>
  </xsl:template>

  <xsl:template match="mapping-instruction"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:template match="{path}" mode="xml2idml:{name(..)}">
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

  <!-- Width / snap to grid 
       By virtue of xsl:next-match, will invoke the standard templates for the aid5:tablestyle / aid5:cellstyle
       attribute attachment, but with a twist: the params of width (e.g., scaling factor, grid) will be passed 
       on to the standard templates.
       -->
  <xsl:template match="TableStyles/mapping-instruction/width[@type eq 'xml2idml:snap-scaled-to-grid']"
    priority="2"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:template match="{../path}" mode="htmltable:tables-add-atts" priority="2">
      <xsl:apply-templates select="../path/@priority" mode="#current" />
      <xsl:comment>Width / snap to grid</xsl:comment>
      <xslout:next-match>
        <xsl:apply-templates select="param"/>
      </xslout:next-match>
    </xslout:template>
  </xsl:template>

  <xsl:template match="param"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:with-param tunnel="yes">
      <xsl:copy-of select="@*" />
    </xslout:with-param>
  </xsl:template>

  <xsl:template match="TableStyles/mapping-instruction/width" priority="-0.5"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xsl:message>
      Non-implemented width processing:
      <xsl:copy-of select="."/>
    </xsl:message>
  </xsl:template>

  <xsl:template match="TableStyles/mapping-instruction/*[self::width or self::height][@type eq 'xml2idml:static-dimension']" 
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:template match="{../path}" mode="htmltable:tables-add-atts" priority="2">
      <xsl:apply-templates select="../path/@priority" mode="#current" />
      <xsl:comment>Width / snap to grid</xsl:comment>
      <xslout:next-match>
        <xslout:with-param name="grid" select="{@select}" />
        <xslout:with-param name="scaling" select="1" />
      </xslout:next-match>
    </xslout:template>
  </xsl:template>

  <xsl:template match="TableStyles/mapping-instruction/*[self::width or self::height][@type eq 'xml2idml:from-cells']" 
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:template match="{../path}" mode="htmltable:tables-add-atts" priority="2">
      <xsl:apply-templates select="../path/@priority" mode="#current" />
      <xslout:apply-imports />
    </xslout:template>
  </xsl:template>


  <!-- Won't be treated in default mode (wich meant: create own xmlout template).
       Static widths will rather be treated when creating the objectstyle attributes
       in mode xml2idml:style-atts.
       It's difference from tables because of the table size calculations / scalings /
       snap to grid that need to take place in separate modes. -->
  <xsl:template match="ObjectStyles/mapping-instruction/width" xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml"/>

  <xsl:template match="ObjectStyles/mapping-instruction/*[self::width or self::height][@type eq 'xml2idml:static-dimension']" 
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml" mode="xml2idml:style-atts">
    <xslout:attribute name="xml2idml:{name()}" select="letex:length-to-unitless-twip({@select}) * 0.05" />
  </xsl:template>
  

  <xsl:template match="import"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:import href="{if (not (matches(@href, '^(file|https?):')))
                          then resolve-uri(@href)
                          else @href}" />
  </xsl:template>

  <xsl:template match="inline"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xsl:copy-of select="node()" />
  </xsl:template>

  <xsl:template match="xslt-pipeline"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xsl:variable name="augmented-pipeline" as="element(xslt-pipeline)">
      <xsl:copy xmlns="http://www.le-tex.de/namespace/xml2idml">
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

    <xsl:text>&#xa;&#xa;</xsl:text>
    <xsl:comment select="' IDENTITY TEMPLATE '"/>
    <xsl:text>&#xa;  </xsl:text>
    <!-- Declare identity templates as needed in the imported stylesheets 
         (can't generate them here because they'd have higher import precedence
         than any of the imported templates) -->
    <xslout:template match="* | @* | processing-instruction()"
      mode="xml2idml:Discard xml2idml:Stories xml2idml:ParaStyles xml2idml:InlineStyles xml2idml:TableStyles xml2idml:CellStyles xml2idml:ObjectStyles">
      <xslout:copy copy-namespaces="no">
        <xslout:apply-templates select="@*, node()" mode="#current" />
      </xslout:copy>
    </xslout:template>
  </xsl:template>

  <xsl:template match="xslt-pipeline/step"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
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
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:attribute name="xml2idml:storyname" select="'{name}'" />
  </xsl:template>

  <xsl:template match="ParaStyles/mapping-instruction" mode="xml2idml:style-atts"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:attribute name="aid:pstyle" select="'{(xml2idml:escape-style-name(format), '$ID/NormalParagraphStyle')[1]}'" />
    <xsl:if test="condition">
      <xslout:attribute name="xml2idml:condition" select="'{condition}'" />
      <xsl:if test="condition/@hidden = 'true'">
        <xslout:attribute name="xml2idml:hidden" select="'true'" />
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <xsl:template match="InlineStyles/mapping-instruction" mode="xml2idml:style-atts"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:attribute name="aid:cstyle" select="'{(xml2idml:escape-style-name(format), '$ID/[No character style]')[1]}'" />
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
    <xsl:if test="xml2idml:insert-special-char/@format">
      <xslout:attribute name="xml2idml:insert-special-char-format" select="'{insert-special-char/@format}'" />
    </xsl:if>
  </xsl:template>
  <xsl:template match="ObjectStyles/mapping-instruction" mode="xml2idml:style-atts"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:attribute name="xml2idml:ObjectStyle" select="'{(xml2idml:escape-style-name(format), '$ID/[None]')[1]}'" />
    <xslout:attribute name="xml2idml:anchoring" select="'{xml2idml:anchoring/@type}'" />
    <xsl:apply-templates select="width | height" mode="#current" />
  </xsl:template>
  <xsl:template match="TableStyles/mapping-instruction" mode="xml2idml:style-atts"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:attribute name="aid5:tablestyle" select="'{(xml2idml:escape-style-name(format), '$ID/[No table style]')[1]}'" />
    <xslout:attribute name="aid:table" select="'table'" />
  </xsl:template>
  <xsl:template match="CellStyles/mapping-instruction" mode="xml2idml:style-atts"
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml">
    <xslout:attribute name="aid5:cellstyle" select="'{(xml2idml:escape-style-name(format), '$ID/[None]')[1]}'" />
    <xslout:attribute name="aid:table" select="'cell'" />
    <xsl:apply-templates select="format/@priority" mode="#current" />
  </xsl:template>

  <xsl:template match="CellStyles/mapping-instruction/format/@priority" 
    xpath-default-namespace="http://www.le-tex.de/namespace/xml2idml" mode="xml2idml:style-atts">
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
