<?xml version="1.0" encoding="utf-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" 
  xmlns:c="http://www.w3.org/ns/xproc-step"  
  xmlns:cx="http://xmlcalabash.com/ns/extensions"
  xmlns:cxf="http://xmlcalabash.com/ns/extensions/fileutils"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:bc="http://transpect.le-tex.de/book-conversion"
  xmlns:xml2idml  = "http://www.le-tex.de/namespace/xml2idml"
  xmlns:letex="http://www.le-tex.de/namespace"
  version="1.0"
  name="store"
  type="xml2idml:store"
  >

  <p:option name="zip-file-uri" required="true"/>
  <p:option name="debug" />
  <p:option name="debug-dir-uri" required="false" select="resolve-uri('debug')"/>

  <p:input port="source" primary="true" />
  <p:input port="paths" kind="parameter"/>

  <p:output port="result" primary="true">
    <p:pipe step="zip" port="result"/>
  </p:output>
  <p:serialization port="result" indent="true" omit-xml-declaration="false"/>

  <p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl" />
  <p:import href="http://transpect.le-tex.de/xproc-util/store-debug/store-debug.xpl" />

  <bc:load-cascaded name="load-serialize-compound-idml-xsl" 
    fallback="http://transpect.le-tex.de/xml2idml/xsl/serialize-compound-idml.xsl">
    <p:with-option name="filename" select="'xml2idml/serialize-compound-idml.xsl'"/>
    <p:with-option name="set-xml-base-attribute" select="'no'"/>
    <p:input port="paths">
      <p:pipe port="paths" step="store"/>
    </p:input>
    <p:with-option name="debug" select="$debug"/>
    <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
  </bc:load-cascaded>

  <p:sink/>

  <p:xslt name="split">
    <p:with-param name="zip-file-uri" select="$zip-file-uri"/>
    <p:input port="parameters"><p:empty/></p:input>
    <p:input port="source">
      <p:pipe step="store" port="source" />
    </p:input>
    <p:input port="stylesheet">
      <p:pipe step="load-serialize-compound-idml-xsl" port="result"/>
    </p:input>
  </p:xslt>

  <p:choose>
    <p:when test="$debug = 'yes'">
      <letex:store-debug pipeline-step="xml2idml/zip-manifest">
        <p:with-option name="active" select="$debug" />
        <p:with-option name="base-uri" select="$debug-dir-uri" />
      </letex:store-debug>
      <p:sink/>
    </p:when>
    <p:otherwise>
      <p:sink/>
    </p:otherwise>
  </p:choose>

  
  <cxf:delete recursive="true" >
    <p:with-option name="href" select="concat($zip-file-uri, '.tmp')" />
    <p:with-option name="fail-on-error" select="'false'" />
  </cxf:delete>

  <p:for-each name="serialize">
    <p:iteration-source>
      <p:pipe step="split" port="secondary"/>
    </p:iteration-source>
    <p:store omit-xml-declaration="false" indent="true">
      <p:with-option name="href" select="base-uri()"/>
    </p:store>
  </p:for-each>
  
  <p:store method="text">
    <p:with-option name="href" select="concat($zip-file-uri, '.tmp/mimetype')" />
    <p:input port="source">
      <p:inline><bogo>application/vnd.adobe.indesign-idml-package</bogo></p:inline>
    </p:input>
  </p:store>

  <cx:zip compression-method="deflated" compression-level="default" command="create" name="zip">
    <p:with-option name="href" select="$zip-file-uri" />
    <p:input port="source"><p:empty/></p:input>
    <p:input port="manifest">
      <p:pipe step="split" port="result"/>
    </p:input>
  </cx:zip>


</p:declare-step>
