<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
  version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:c="http://www.w3.org/ns/xproc-step"  
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xs c"
  >

  <xsl:param name="zip-file-uri" as="xs:string" />

  <xsl:template match="/">
    <c:zip-manifest>
      <xsl:call-template name="additional-files" />
      <xsl:apply-templates mode="export" />
    </c:zip-manifest>
  </xsl:template>

  <xsl:function name="c:relative-name" as="xs:string">
    <xsl:param name="uri" as="xs:string" />
    <xsl:sequence select="replace($uri, '^.+\.tmp/+', '')" />
  </xsl:function>

  <xsl:template match="*[@xml:base]" mode="export">
    <xsl:variable name="basename" select="c:relative-name(@xml:base)" as="xs:string" />
    <xsl:variable name="uri" select="concat($zip-file-uri, '.tmp/', $basename)" as="xs:string" />
    <xsl:result-document href="{$uri}">
      <xsl:if test="not(parent::*)">
        <xsl:processing-instruction name="aid">name="<xsl:value-of select="name()"/>" style="50" type="document" readerVersion="6.0" featureSet="257" product="8.0(370)"</xsl:processing-instruction>
      </xsl:if>
      <xsl:copy>
        <xsl:apply-templates select="@* | node()" mode="export-just-this" />
      </xsl:copy>
    </xsl:result-document>
    <c:entry href="{$uri}" name="{$basename}" method="deflated" level="default" />
    <xsl:apply-templates mode="#current" />
  </xsl:template>

  <xsl:template match="@xml:base" mode="export-just-this" />

  <xsl:template match="*[@xml:base]" mode="export-just-this">
    <xsl:copy copy-namespaces="no">
      <xsl:attribute name="src" select="c:relative-name(@xml:base)" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@* | processing-instruction() | comment() | text()" mode="export" />

  <xsl:template name="additional-files">
    <!-- mimetype will be created by XProc -->
    <xsl:for-each select="('mimetype', 'META-INF/container.xml')">
      <xsl:variable name="uri" as="xs:string" select="concat($zip-file-uri, '.tmp/', .)" />
      <c:entry href="{$uri}" name="{.}" method="stored" level="none" />
      <xsl:if test=". eq 'META-INF/container.xml'">
        <xsl:result-document href="{$uri}">
          <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
              <rootfile full-path="designmap.xml" media-type="text/xml">
              </rootfile>
            </rootfiles>
          </container>
        </xsl:result-document>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="@* | * | processing-instruction()"
    mode="export-just-this">
    <xsl:copy>
      <xsl:apply-templates select="@*, node()" mode="#current" />
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
