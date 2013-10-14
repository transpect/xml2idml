<?xml version="1.0" encoding="utf-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" 
  xmlns:c="http://www.w3.org/ns/xproc-step"  
  xmlns:cx="http://xmlcalabash.com/ns/extensions"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:bc="http://transpect.le-tex.de/book-conversion"
  xmlns:idml2xml  = "http://www.le-tex.de/namespace/idml2xml"
  xmlns:xml2idml  = "http://www.le-tex.de/namespace/xml2idml"
  xmlns:letex="http://www.le-tex.de/namespace"
  version="1.0"
  name="add-aid"
  type="xml2idml:add-aid"
  >

  <p:option name="mapping-schema" select="'../schema/mapping.rng'"/>
  <p:option name="debug" required="false" select="'no'"/>
  <p:option name="debug-dir-uri" required="false" select="resolve-uri('debug')"/>

  <p:input port="source" primary="true"/>
  <p:input port="paths" kind="parameter" primary="true"/>
  <p:input port="mapping-xml" primary="false" />

  <p:output port="result" primary="true" />

  <p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl" />
  <p:import href="http://transpect.le-tex.de/calabash-extensions/ltx-validate-with-rng/rng-validate-to-PI.xpl"/>
  <p:import href="http://transpect.le-tex.de/xproc-util/store-debug/store-debug.xpl" />

  <cx:message message="xml2idml (add-aid): validating mapping xml">
    <p:input port="source"><p:empty/></p:input>
  </cx:message>

  <bc:load-cascaded name="load-mapping-rng" fallback="http://transpect.le-tex.de/xml2idml/schema/mapping.rng">
    <p:with-option name="filename" select="'xml2idml/mapping.rng'"/>
    <p:with-option name="set-xml-base-attribute" select="'no'"/>
    <p:input port="paths">
      <p:pipe port="paths" step="add-aid"/>
    </p:input>
    <p:with-option name="debug" select="$debug"/>
    <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
  </bc:load-cascaded>

  <p:sink/>

  <bc:load-cascaded name="load-mapping-xsl" fallback="http://transpect.le-tex.de/xml2idml/xsl/mapping2xsl.xsl">
    <p:with-option name="filename" select="'xml2idml/mapping2xsl.xsl'"/>
    <p:with-option name="set-xml-base-attribute" select="'yes'"/>
    <p:input port="paths">
      <p:pipe port="paths" step="add-aid"/>
    </p:input>
    <p:with-option name="debug" select="$debug"/>
    <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
  </bc:load-cascaded>

  <p:sink/>

  <letex:validate-with-rng-PI name="validate-mapping">
    <p:input port="source">
      <p:pipe step="add-aid" port="mapping-xml"/>
    </p:input>
    <p:input port="schema">
      <p:pipe step="load-mapping-rng" port="result"/>
    </p:input>
    <p:with-option name="debug" select="'yes'"/>
    <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
  </letex:validate-with-rng-PI>

  <cx:message message="xml2idml (add-aid): validated. now generating mapping"/>

  <p:xslt name="mapping-xslt">
    <p:with-param name="debug" select="$debug" />
    <p:input port="parameters"><p:empty/></p:input>
    <p:input port="source">
      <p:pipe step="add-aid" port="mapping-xml" />
    </p:input>
    <p:input port="stylesheet">
      <p:pipe step="load-mapping-xsl" port="result" />
<!--      <p:document href="../xsl/mapping2xsl.xsl" />-->
    </p:input>
  </p:xslt>

  <letex:store-debug pipeline-step="xml2idml/add-aid-attributes/map">
    <p:with-option name="active" select="$debug" />
    <p:with-option name="extension" select="'xsl'" />
    <p:with-option name="base-uri" select="$debug-dir-uri" />
  </letex:store-debug>

  <cx:message message="xml2idml (add-aid): generated mapping"/>

  <cx:message message="xml2idml (add-aid): now mapping xml"/>

  <p:sink/>

  <p:xslt name="mapped" template-name="main">
    <p:with-param name="debug" select="$debug" />
    <p:input port="parameters"><p:empty/></p:input>
    <p:input port="source">
      <p:pipe step="add-aid" port="source" />
    </p:input>
    <p:input port="stylesheet">
      <p:pipe step="mapping-xslt" port="result" />
    </p:input>
  </p:xslt>

  <cx:message message="xml2idml (add-aid): mapped"/>

  <letex:store-debug pipeline-step="xml2idml/add-aid-attributes/mapped">
    <p:with-option name="active" select="$debug" />
    <p:with-option name="base-uri" select="$debug-dir-uri" />
  </letex:store-debug>

</p:declare-step>
