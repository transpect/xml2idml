<?xml version="1.0" encoding="utf-8"?>
<p:declare-step 
  xmlns:p="http://www.w3.org/ns/xproc" 
  xmlns:c="http://www.w3.org/ns/xproc-step"  
  xmlns:cx="http://xmlcalabash.com/ns/extensions"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:tr="http://transpect.io"
  xmlns:tr-internal="http://transpect.io/internal"
  xmlns:xml2idml="http://transpect.io/xml2idml"
  xmlns:idml2xml="http://transpect.io/idml2xml"
  version="1.0"
  name="xml2idml"
  type="tr:xml2idml"
  >

  <p:input port="source" primary="true">
    <p:documentation>XML source document. HTML is recommended; any format apply.</p:documentation>
  </p:input>
  <p:input port="paths"  kind="parameter">
    <p:documentation>A paths document for loading necessary xml2idml components, cascading.</p:documentation>
  </p:input>

  <p:option name="template">
    <p:documentation xmlns="http://www.w3.org/1999/xhtml">
      <p>IDML Template file.</p>
      <p>If the path is not an absolute uri (starts with 'file:/'), xml2idml searches 
      for the template file in cascade paths.</p></p:documentation>
  </p:option>
  <p:option name="mapping">
    <p:documentation xmlns="http://www.w3.org/1999/xhtml">
      <p>xml2idml mapping file.</p>
      <p>Will be used to create paragraphs, tables, character style, etc.</p>
      <p>See ../schema/mapping.rng.</p></p:documentation>
  </p:option>
  <p:option name="idml-target-uri" select="''">
    <p:documentation xmlns="http://www.w3.org/1999/xhtml">
      <p>URI where the generated idml will be saved. Possibilities:</p>
      <ul>
        <li>leave it empty to save the idml near input source xml file (only file suffix is changed)</li>
        <li>absolute path to a file.</li>
        <li>absolute path to a directory (path ends with '/'). Filename taken from base-uri().</li>
      </ul>
    </p:documentation>
  </p:option>
  <p:option name="idmltemplate-expanded-dir-uri" required="false" select="''">
    <p:documentation>
      <p>When no value for the current option is set the idmltemplate will be temporarily expanded to disk into 
        the following directory: 'template' option value plus '.idmltemplate.tmp' instead of suffix '.idml'.</p>
    </p:documentation>
  </p:option>
  <p:option name="debug">
    <p:documentation>Debug option - values: yes or no.</p:documentation>
  </p:option>
  <p:option name="debug-dir-uri" required="false" select="resolve-uri('debug')"/>
  <p:option name="status-dir-uri" required="false" select="concat($debug-dir-uri, '/status')"/>

  <p:output port="result" primary="true" sequence="true">
    <p:pipe step="group" port="result"/>
    <p:documentation>XML as requested for the separate InDesign XML-Import 
      functionality. An alternative usage scenario with limitations.</p:documentation>
  </p:output>
  <p:serialization port="result" indent="true" omit-xml-declaration="false"/>

  <p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl" />
  <p:import href="http://transpect.io/cascade/xpl/dynamic-transformation-pipeline.xpl"/>
  <p:import href="http://transpect.io/cascade/xpl/load-cascaded.xpl"/>
  <p:import href="http://transpect.io/xproc-util/simple-progress-msg/xpl/simple-progress-msg.xpl"/>
  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl" />
  <p:import href="http://transpect.io/xproc-util/file-uri/xpl/file-uri.xpl" />
  <p:import href="add-aid-attributes.xpl" />
  <p:import href="store.xpl" />
  <p:import href="http://transpect.io/calabash-extensions/unzip-extension/internal-unzip-declaration.xpl" />

  <tr:simple-progress-msg name="start-xml2idml-msg" file="xml2idml-start.txt">
    <p:input port="msgs">
      <p:inline>
        <c:messages>
          <c:message xml:lang="en">Starting XML to IDML synthesis</c:message>
          <c:message xml:lang="de">Beginne IDML aus XML zu synthetisieren</c:message>
        </c:messages>
      </p:inline>
    </p:input>
    <p:with-option name="status-dir-uri" select="$status-dir-uri"/>
  </tr:simple-progress-msg>

  <p:sink/>

  <cx:message>
  	<p:input port="source"><p:empty/></p:input>
    <p:with-option name="message" select="'### xml2idml: now unzipping IDML template: ', $template"/>
  </cx:message> 

  <p:choose>
    <p:documentation>Retrieve the path of IDML template.</p:documentation>
    <p:when test="matches($template, '^file:/+')">
      <p:add-attribute match="/*" attribute-name="uri">
        <p:with-option name="attribute-value" select="$template"/>
        <p:input port="source">
          <p:inline><tr:result/></p:inline>
        </p:input>
      </p:add-attribute>
    </p:when>
    <p:otherwise>
      <tr:load-cascaded-binary name="idml-template-uri">
        <p:with-option name="filename" select="$template"/>
        <p:input port="paths">
          <p:pipe port="paths" step="xml2idml"/>
        </p:input>
      </tr:load-cascaded-binary>
    </p:otherwise>
  </p:choose>
  
  <tr:file-uri fetch-http="false">
    <p:with-option name="filename" select="/*/@uri"/>
  </tr:file-uri>
  
  <p:group name="group">
    <p:output port="result" sequence="true" primary="true">
      <p:pipe step="with-aid" port="result"/>
    </p:output>
    <p:variable name="idml-os-path" select="/*/@os-path"/>
    <p:variable name="unzip-dir-os-path" 
      select="if(not($idmltemplate-expanded-dir-uri = '')) 
              then replace($idmltemplate-expanded-dir-uri, 'file:', '') 
              else concat(/*/@os-path, '.idmltemplate.tmp')"/>
  
    <cx:message>
      <p:with-option name="message" select="'#### xml2idml: retrieved template path for unzipping, ', $idml-os-path"/>
    </cx:message> 
  
    <tr-internal:unzip name="expand-template">
      <p:documentation>Unzip the IDML template to a temporary directory.</p:documentation>
      <p:with-option name="zip" select="$idml-os-path" />
      <p:with-option name="dest-dir" select="$unzip-dir-os-path">
        <p:pipe step="xml2idml" port="source"/>
      </p:with-option>
      <p:with-option name="overwrite" select="'yes'" />
    </tr-internal:unzip>
  
    <cx:message>
      <p:with-option name="message" select="'### xml2idml: unzipped IDML template into directory ', $unzip-dir-os-path"/>
    </cx:message>
  
    <p:sink/>
  
    <p:load name="template-designmap">
      <p:documentation>Load the designmap.xml: the key in each IDML file 
        to all its included files.</p:documentation>
      <p:with-option name="href" select="concat(/c:files/@xml:base, '/designmap.xml')">
        <p:pipe step="expand-template" port="result"/>
      </p:with-option>
    </p:load>
  
    <cx:message message="xml2idml: now creating single doc from template"/>
  
    <p:xslt name="template-as-single-doc" initial-mode="idml2xml:Document">
      <p:documentation>Use first step of idml2xml to get a single XML instance 
        of the entire template file.</p:documentation>
      <p:with-param name="src-dir-uri" select="/c:files/@xml:base">
        <p:pipe step="expand-template" port="result" />
      </p:with-param>
      <p:input port="parameters"><p:empty/></p:input>
      <p:input port="stylesheet">
        <p:document href="http://transpect.io/idml2xml/xsl/idml2xml.xsl" />
      </p:input>
    </p:xslt>
  
    <cx:message message="xml2idml: created single doc"/>
  
    <tr:store-debug pipeline-step="idml2xml/expanded-template">
      <p:with-option name="active" select="$debug" />
      <p:with-option name="base-uri" select="$debug-dir-uri" />
    </tr:store-debug>
  
    <cx:message message="xml2idml: about to add aid attributes"/>
  
    <tr:load-cascaded name="load-mapping">
      <p:documentation>Load the xml to idml character, paragraph, object, table, 
        cells mapping file, cascading.</p:documentation>
      <p:with-option name="filename" select="$mapping"/>
      <p:with-option name="set-xml-base-attribute" select="'no'"/>
      <p:input port="paths">
        <p:pipe port="paths" step="xml2idml"/>
      </p:input>
      <p:with-option name="debug" select="$debug"/>
      <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
    </tr:load-cascaded>
  
    <xml2idml:add-aid name="with-aid">
      <p:documentation>Map the XML input to aid:* attributes and values given 
        by the loaded mapping.</p:documentation>
      <p:with-option name="debug" select="$debug" />
      <p:with-option name="debug-dir-uri" select="$debug-dir-uri" />
      <p:input port="source">
        <p:pipe step="xml2idml" port="source" />
      </p:input>
      <p:input port="paths">
        <p:pipe step="xml2idml" port="paths" />
      </p:input>
      <p:input port="mapping-xml">
        <p:pipe step="load-mapping" port="result" />
      </p:input>
    </xml2idml:add-aid>
  
    <tr:simple-progress-msg name="xßml2idml-mapandstorify-msg" file="xml2idml-mappingandstorify.txt">
      <p:input port="msgs">
        <p:inline>
          <c:messages>
            <c:message xml:lang="de">Mapping-Instruktionen erfolgreich angewendet, beginne mit Erstellung der IDML-Struktur</c:message>
            <c:message xml:lang="en">Mapping instructions successfully applied, about to start IDML structure</c:message>
          </c:messages>
        </p:inline>
      </p:input>
      <p:with-option name="status-dir-uri" select="$status-dir-uri"/>
    </tr:simple-progress-msg>
  
    <cx:message message="xml2idml: now storifying"/>
  
    <tr:load-cascaded name="load-storify" fallback="http://transpect.io/xml2idml/xsl/storify.xsl">
      <p:documentation>Load the storify.xsl.</p:documentation>
      <p:with-option name="filename" select="'xml2idml/storify.xsl'"/>
      <p:with-option name="set-xml-base-attribute" select="'no'"/>
      <p:input port="paths">
        <p:pipe port="paths" step="xml2idml"/>
      </p:input>
      <p:with-option name="debug" select="$debug"/>
      <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
    </tr:load-cascaded>
  
    <tr:load-cascaded name="load-remove-tagging" fallback="http://transpect.io/xml2idml/xsl/remove-tagging.xsl">
      <p:documentation>Load stylesheet for the optional step.</p:documentation>
      <p:with-option name="filename" select="'xml2idml/remove-tagging.xsl'"/>
      <p:with-option name="set-xml-base-attribute" select="'no'"/>
      <p:input port="paths">
        <p:pipe port="paths" step="xml2idml"/>
      </p:input>
      <p:with-option name="debug" select="$debug"/>
      <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>    
    </tr:load-cascaded>
  
    <p:xslt name="storify-pass1" initial-mode="xml2idml:storify">
      <p:documentation>Convert/wrap content elements into IDML notation. 
        Creating Character, ParagraphStyleRanges and so on.</p:documentation>
      <p:with-param name="base-uri" select="replace(base-uri(/*), '\.\w+$', '.idml.tmp')">
        <p:pipe step="xml2idml" port="source"/>
      </p:with-param>
      <p:input port="parameters">
        <p:pipe port="paths" step="xml2idml"/>
      </p:input>
      <p:input port="source">
        <p:pipe step="with-aid" port="result"/>
        <p:pipe step="template-as-single-doc" port="result"/>
      </p:input>
      <p:input port="stylesheet">
        <p:pipe step="load-storify" port="result"/>
      </p:input>
    </p:xslt>
  
    <cx:message message="xml2idml: storified"/>
  
    <tr:store-debug pipeline-step="xml2idml/10.storify-pass1">
      <p:with-option name="active" select="$debug" />
      <p:with-option name="base-uri" select="$debug-dir-uri" />
    </tr:store-debug>
  
    <cx:message message="xml2idml: now cleaning up storifying"/>
  
    <p:xslt name="storify-pass2" initial-mode="xml2idml:storify_content-n-cleanup">
      <p:documentation>Cleanup mode in storify.xsl, i.e. remove unecessary 
        line break commands. See also the included stylesheet documentation.</p:documentation>
      <p:input port="parameters"><p:empty/></p:input>
      <p:input port="stylesheet">
        <p:pipe step="load-storify" port="result"/>
      </p:input>
    </p:xslt>
  
    <cx:message message="xml2idml: cleaned up storifying"/>
  
    <tr:store-debug pipeline-step="xml2idml/11.storify_content-n-cleanup">
      <p:with-option name="active" select="$debug" />
      <p:with-option name="base-uri" select="$debug-dir-uri" />
    </tr:store-debug>
  
    <p:choose>
      <p:documentation>Wether the tagging (input xml) should be retained or removed.</p:documentation>
      <p:xpath-context>
        <p:pipe step="load-mapping" port="result" />
      </p:xpath-context>
      <p:when test="not(/*/@retain-tagging = 'true')">
        <cx:message message="xml2idml: now removing tagging"/>
        <p:xslt name="remove-tagging">
          <p:input port="parameters"><p:empty/></p:input>
          <p:input port="stylesheet">
            <p:pipe step="load-remove-tagging" port="result" />
          </p:input>
        </p:xslt>
        <tr:store-debug pipeline-step="xml2idml/15.remove-tagging">
          <p:with-option name="active" select="$debug" />
          <p:with-option name="base-uri" select="$debug-dir-uri" />
        </tr:store-debug>
      </p:when>
      <p:otherwise>
        <p:identity/>
      </p:otherwise>
    </p:choose>
  
    <cx:message message="xml2idml: removed"/>
  
    <p:identity name="stories" />
  
    <cx:message message="xml2idml: now merging generated stories into template and creating new spreads eventually"/>
  
    <tr:load-cascaded name="load-merge" fallback="http://transpect.io/xml2idml/xsl/merge.xsl">
      <p:documentation>Load the merge.xsl file.</p:documentation>
      <p:with-option name="filename" select="'xml2idml/merge.xsl'"/>
      <p:with-option name="set-xml-base-attribute" select="'no'"/>
      <p:input port="paths">
        <p:pipe port="paths" step="xml2idml"/>
      </p:input>
      <p:with-option name="debug" select="$debug"/>
      <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>    
    </tr:load-cascaded>
  
    <p:sink/>
  
    <p:xslt name="merge">
      <p:documentation>XSLT mode to merge the converted input XML with the idml template.</p:documentation>
      <p:input port="parameters"><p:empty/></p:input>
      <p:input port="source">
        <p:pipe step="template-as-single-doc" port="result" />
        <p:pipe step="stories" port="result" />
      </p:input>
      <p:input port="stylesheet">
        <p:pipe step="load-merge" port="result" />
      </p:input>
    </p:xslt>
  
    <cx:message message="xml2idml: merged"/>
  
    <tr:store-debug pipeline-step="xml2idml/30.merge">
      <p:with-option name="active" select="$debug" />
      <p:with-option name="base-uri" select="$debug-dir-uri" />
    </tr:store-debug>
  
    <p:identity name="merged-document" />
  
    <cx:message message="xml2idml: now checking for styles not defined in template"/>
  
    <tr:load-cascaded name="load-add-nonexisting-styles" fallback="http://transpect.io/xml2idml/xsl/add-nonexisting-styles.xsl">
      <p:documentation>Load stylesheet add-nonexisting-styles.xsl.</p:documentation>
      <p:with-option name="filename" select="'xml2idml/add-nonexisting-styles.xsl'"/>
      <p:with-option name="set-xml-base-attribute" select="'no'"/>
      <p:input port="paths">
        <p:pipe port="paths" step="xml2idml"/>
      </p:input>
      <p:with-option name="debug" select="$debug"/>
      <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>    
    </tr:load-cascaded>
  
    <p:sink/>
  
    <p:xslt name="add-nonexisting-styles">
      <p:documentation>Used styles not included in the idml file will be created here, so the mapping information cannot be lost.</p:documentation>
      <p:input port="parameters"><p:empty/></p:input>
      <p:input port="source">
        <p:pipe step="merged-document" port="result" />
      </p:input>
      <p:input port="stylesheet">
        <p:pipe step="load-add-nonexisting-styles" port="result"/>
      </p:input>
    </p:xslt>
  
    <cx:message message="xml2idml: checked styles"/>
  
    <tr:store-debug pipeline-step="xml2idml/35.add-nonexisting-styles">
      <p:with-option name="active" select="$debug" />
      <p:with-option name="base-uri" select="$debug-dir-uri" />
    </tr:store-debug>
  
    <p:delete name="delete-xml-space-attr" match="@xml:space">
      <p:documentation>Another important cleanup step to remove the xml:space attribute, 
        otherwise the result won't be valid.</p:documentation>
    </p:delete>
  
    <p:xslt name="zip-file-uri" template-name="main">
      <p:documentation xmlns="http://www.w3.org/1999/xhtml">
        <p>Compute the save file path of the created IDML file. The result of this step will be, in dependency of param idml-target-uri:</p>
        <ul>
          <li>no path (empty string) given: use base-uri of the XML input 
            and change the file extension to idml</li>
          <li>full path given: resolve and use this path</li>
          <li>idml-target-uri is a directory (ends with '/'): use this param, concat it with the basename of the XML input base-uri and add 'idml' file extension.</li>
        </ul></p:documentation>
      <p:with-param name="idml-uri" select="$idml-target-uri"/>
      <p:with-param name="base-uri" select="resolve-uri(base-uri(/*))">
        <p:pipe step="xml2idml" port="source"/>
      </p:with-param>
      <p:input port="stylesheet">
        <p:inline>
          <xsl:stylesheet version="2.0" 
            xmlns:c="http://www.w3.org/ns/xproc-step" 
            xmlns:xs="http://www.w3.org/2001/XMLSchema"
            xmlns:tr="http://transpect.io">
            <xsl:param name="idml-uri" required="yes" as="xs:string" />
            <xsl:param name="base-uri" required="yes" as="xs:string" />
            <xsl:include href="http://transpect.io/xslt-util/resolve-uri/xsl/resolve-uri.xsl"/>
            <xsl:template name="main">
              <xsl:variable name="result" as="element(c:result)">
                <c:result>
                  <xsl:choose>
                    <!-- no path (empty string) given -->
                    <xsl:when test="$idml-uri eq ''">
                      <xsl:value-of select="tr:resolve-system-from-uri(
                                              replace($base-uri, '\.\w+$', '.idml')
                                            )"/>
                    </xsl:when>
                    <!-- full path given -->
                    <xsl:when test="matches($idml-uri, '^.+\.\w+$')">
                      <xsl:value-of select="tr:resolve-system-from-uri($idml-uri)"/>
                    </xsl:when>
                    <!-- path ends with '/' -->
                    <xsl:when test="matches($idml-uri, '^.+/$')">
                      <xsl:value-of select="tr:resolve-system-from-uri(
                                              concat(
                                                $idml-uri, 
                                                replace(
                                                  tokenize($base-uri,'/')[last()], 
                                                  '\.\w+$', 
                                                  '.idml'
                                                )
                                              )
                                            )"/>
                    </xsl:when>
                    <!-- hm? -->
                    <xsl:otherwise>
                      <xsl:value-of select="tr:resolve-system-from-uri(
                                              replace($base-uri, '\.\w+$', '.idml')
                                            )"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </c:result>
              </xsl:variable>
              <xsl:message select="concat('xml2idml: now storing as zip in ', $result)"/>
              <xsl:sequence select="$result"/>
            </xsl:template>
          </xsl:stylesheet>
        </p:inline>
      </p:input>
    </p:xslt>
    <p:sink/>
  
    <xml2idml:store name="store">
      <p:documentation>Save the created IDML file to hard disc.</p:documentation>
      <p:input port="source">
        <p:pipe step="delete-xml-space-attr" port="result"/>
      </p:input>
      <p:with-option name="debug" select="$debug" />
      <p:with-option name="debug-dir-uri" select="$debug-dir-uri" />
      <p:with-option name="zip-file-uri" select="/c:result">
        <p:pipe step="zip-file-uri" port="result"/>
      </p:with-option>
    </xml2idml:store>
    
    <cx:message message="xml2idml: stored"/>
  
    <tr:simple-progress-msg name="success-xml2idml-msg" file="xml2idml-success.txt">
      <p:input port="msgs">
        <p:inline>
          <c:messages>
            <c:message xml:lang="en">Successfully synthesized IDML from XML</c:message>
            <c:message xml:lang="de">IDML-Synthese aus XML erfolgreich beendet</c:message>
          </c:messages>
        </p:inline>
      </p:input>
      <p:with-option name="status-dir-uri" select="$status-dir-uri"/>
    </tr:simple-progress-msg>
    
    <p:sink/>

  </p:group>


</p:declare-step>
