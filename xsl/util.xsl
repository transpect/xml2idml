<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
  version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"
  xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/"
  xmlns:htmltable="http://transpect.io/htmltable"
  xmlns:xml2idml="http://transpect.io/xml2idml"
  xmlns:tr="http://transpect.io"
  xmlns:css="http://www.w3.org/1996/css"
  xmlns:saxon="http://saxon.sf.net/"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  >

  <xsl:function name="tr:contains-token" as="xs:boolean">
    <xsl:param name="string" as="xs:string?" />
    <xsl:param name="tokens" as="xs:string+" />
    <xsl:sequence select="every $t in $tokens satisfies tokenize($string, '\s+') = $t" />
  </xsl:function>

</xsl:stylesheet>
