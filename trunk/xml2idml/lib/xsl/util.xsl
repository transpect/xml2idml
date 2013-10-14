<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
  version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"
  xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/"
  xmlns:htmltable="http://www.le-tex.de/namespace/htmltable"
  xmlns:xml2idml="http://www.le-tex.de/namespace/xml2idml"
  xmlns:letex="http://www.le-tex.de/namespace"
  xmlns:css="http://www.w3.org/1996/css"
  xmlns:saxon="http://saxon.sf.net/"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  >

  <xsl:function name="letex:contains-token" as="xs:boolean">
    <xsl:param name="string" as="xs:string?" />
    <xsl:param name="tokens" as="xs:string+" />
    <xsl:sequence select="tokenize($string, '\s+') = $tokens" />
  </xsl:function>

</xsl:stylesheet>
