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
  exclude-result-prefixes="css letex xs xml2idml idml2xml saxon htmltable"
  >

  <xsl:template 
    match="RootCharacterStyleGroup |
           RootParagraphStyleGroup |
           RootCellStyleGroup | 
           RootTableStyleGroup |
           RootObjectStyleGroup" 
    mode="#default">
    <xsl:variable 
      name="style-type" 
      select="replace(local-name(), '^Root(.*)Group$', '$1')"/>
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current" />
      <xsl:apply-templates mode="#current" />
      <xsl:variable 
        name="defined-styles"
        select="*[local-name() eq $style-type]/@Self 
                union 
                *[local-name() eq concat( $style-type, 'Group') ]/*[local-name() eq $style-type]/@Self"
        as="xs:string*"/>
      <xsl:variable 
        name="elementname-to-check"
        as="xs:string">
        <xsl:choose>
          <xsl:when test="$style-type eq 'ObjectStyle'">
            <xsl:sequence select="'TextFrame'"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- ChracterStyleRange, ParagraphStyleRange, and so on-->
            <xsl:sequence select="concat($style-type, 'Range')"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <!-- look at all used styles of style-type -->
      <xsl:for-each select="distinct-values(//*[local-name() eq $elementname-to-check]
			                       /@*[local-name() eq concat('Applied', $style-type)])">
        <xsl:if test="not(current() = $defined-styles)">
          <xsl:variable 
            name="style-name-displayed" 
            select="replace(current(), concat($style-type, '/'),'')"/>
          <xsl:message select="$style-type, ' not defined in template:', $style-name-displayed"/>
          <xsl:element name="{$style-type}">
            <xsl:attribute name="Self" select="current()" />
            <xsl:attribute name="Name" select="$style-name-displayed"/>
          </xsl:element>
        </xsl:if>
      </xsl:for-each>
    </xsl:copy>
  </xsl:template>

  <!-- catch and copy all -->
  <xsl:template match="@* | * | processing-instruction() | comment()"
    mode="#all">
    <xsl:copy>
      <xsl:apply-templates select="@*, node()" mode="#current" />
    </xsl:copy>
  </xsl:template>


</xsl:stylesheet>
