xquery version "3.1";


module namespace test="http://www.tei-c.org/tei-simple/test";
declare namespace map = "http://www.w3.org/2005/xpath-functions/map";
declare namespace array = "http://www.w3.org/2005/xpath-functions/array";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace functx = "http://www.functx.com";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "query.xql";
import module namespace qrp="https://www.daliboris.cz/ns/xquery/query-parser/1.0"  at "query-parser.xql";
import module namespace edq = "http://www.daliboris.cz/schema/ns/xquery" at "exist-db-query-parser.xql"; 
import module namespace rq="http://www.daliboris.cz/ns/xquery/request" at "request.xql";
import module namespace lapi="http://www.tei-c.org/tei-simple/query/tei-lex" at "query-tei-lex.xql";

declare function test:search($request as map(*)) { 
  (: lapi:get-exist-db-query-xml($request) :)
  let $parameters := rq:get-all-parameters($request)
    let $hasQuery := not(empty($parameters/parameter[@name='query']/value[node()]))
    let $hasChapter := not(empty($parameters/parameter[@name='chapter']/value[node()]))
    let $lucene := if($hasChapter and $hasQuery) then
            (
            lapi:get-lucene-query($parameters/parameter[@name=('query', 'field', 'position')])
            , lapi:get-lucene-query-for-chapter($parameters/parameter[@name=('chapter')])
            )
         else if ($hasChapter) then
            lapi:get-lucene-query-for-chapter($parameters/parameter[@name=('chapter')])
        else if($hasQuery) then
        lapi:get-lucene-query($parameters/parameter[@name=('query', 'field', 'position')])
        else
        for $group in $parameters/group[parameter[@name='query-advanced'][node()]]
        order by $group/@name
        return lapi:get-lucene-query($group/parameter)
    let $facets := lapi:get-facets-values($request)
    let $combined := qrp:combine-queries($lucene)
    let $exist-db-query := if (empty($combined)) then () else <exist-db-query>{($combined, $facets)}</exist-db-query>
    return  ($parameters, <facets>{$facets}</facets>,  <lucene>{$lucene}</lucene>, <exist-db-query>{$exist-db-query}</exist-db-query>)
    
};

declare function test:lucene-search($request as map(*)) {
    let $query := $request?parameters?query
    let $options := $request?body?options
    return <result length="{string-length($options)}"> {$query, string-length($options)} <options>{$request?body}</options> </result>
};

declare function test:fulltext-search($request as map(*)) {
    let $query := $request?body/*

    let $result := edq:parse-exist-db-query($query)
    let $hits := test:execute-query-return-hits($result?query, $result?full-options)
    let $hits := subsequence($hits, 1, 20)
    (: return <result>{$result?xml}</result> :)
    return $hits
    (:
    return <result>
      <input>{$options}</input>
      <output>
        {test:query-advanced($options, (), (), ())}
      </output>
     </result>
     :)
};

declare %private function test:fulltext-search-exist-db-query($query as element(exist-db-query)) {
    let $result := edq:parse-exist-db-query($query)
    let $hits := test:execute-query-return-hits($result?query, $result?full-options)
    let $hits := subsequence($hits, 1, 20)
    return $hits
};

declare function test:execute-query-return-hits($query as item(), $options as item()? ) {
 
 let $query-start-time := util:system-time()
 
 let $ft := collection($config:data-root || "/dictionaries/")//tei:entry[ft:query(., $query, $options)]
 let $result := $ft

 let $query-end-time := util:system-time()
 let $query-duration := ($query-end-time - $query-start-time) div xs:dayTimeDuration('PT1S')
 
 return
    $result
 };

declare function test:query($request as map(*)) { 
  let $parameters := rq:get-request-parameters($request)
  let $parameters-api := rq:get-api-parameters($request)
  let $merged := rq:get-all-parameters($request)
  return <result>{($parameters, $parameters-api, $merged)}</result>
};



declare function test:advanced-query($request as map(*)) { 
  (: let $parameters := test:get-parameters-simple($request) :)
  let $parameters := rq:get-api-parameters($request)
  let $lucene := for $group in $parameters/group[parameter[@name='query-advanced'][node()]]
      order by $group/@n
      return test:get-lucene-query($group/parameter)
  let $exist-db-query := <exist-db-query>{qrp:combine-queries($lucene)}</exist-db-query>
  let $hits :=  test:fulltext-search-exist-db-query($exist-db-query)
  return ($exist-db-query, $parameters, <lucene>{$lucene}</lucene>, <hits>{$hits}</hits>)
};
declare %private function test:get-parameter-as-xml($key, $value)  as element(parameter) {

let $indexed := '([^\[]*)\[([^\]]*)\]'
let $n := function($k) { if(matches($k, $indexed)) then 
      (
        attribute name {analyze-string($k, $indexed)/*/*[1]}, 
        attribute group {analyze-string($k, $indexed)/*/*[2]}
      ) 
      else 
        attribute name {$k} 
      }

let $get-value := function($v) {
        typeswitch ($v)
        case map(*)
          return map:for-each($v, $p)
        default
          return $v
    }

return
<parameter>{$n($key), $get-value($value)}</parameter>
};

declare function test:get-parameters-simple($request as map(*)) as element(parameters) {

    let $indexed := '([^\[]*)\[([^\]]*)\]'
    let $n := function($k) { if(matches($k, $indexed)) then 
      (
        attribute name {analyze-string($k, $indexed)/*/*[1]}, 
        attribute group {analyze-string($k, $indexed)/*/*[2]}
      ) 
      else 
        attribute name {$k} 
      }

    let $get-value := function($v) {
        typeswitch ($v)
        case map(*)
          return map:for-each($v, test:get-parameters-simple#1)
        case array(*)
          return array:for-each($v, function($x) { <value>{$x}</value> })
        case xs:string
          return $v
        default
          return if(empty($v)) then $v else "ELSE: " || $v
    }

    let $p := function($k, $v) {<parameter>{$n($k), $get-value($v)}</parameter>}

    let $items := map:for-each($request?parameters, $p)
    let $items := for $item in $items
      let $group := $item/@group
      group by $group
      return if(exists(($group))) then <group n="{$group}">
        {$item}
      </group>
      else $item
    return <parameters type="simple">{$items}</parameters>
};

declare function test:get-lucene-query($parameter as element(parameter)*) {
  qrp:get-query-options($parameter[@name='query-advanced']/., $parameter[@name='position']/., $parameter[@name='field']/., $parameter[@name='condition']/.)
};

declare function test:get-parameters($request as map(*)) {


  let $get-query := function($parameter as element(param)*) {
    qrp:get-query-options($parameter[@name='query-advanced']/@value, $parameter[@name='position']/@value, $parameter[@name='field']/@value, $parameter[@name='condition']/@value)
  }

  let $create-query := function($parameters as element(parameters)) {
    
    let $groups := for $params in $parameters/param
     let $group := $params/@group
     group by $group
    return <group condition="{$params[@name='condition']/@value}">{$params}</group>
   
   (:return $groups:)
   
    for $group in $groups
     return $get-query($group/param)
   
  }
  
  let $pattern := "^(.[^\[]*)\[(\d+)\]$"
  
   let $positions := function($param) {
    if( matches($param, $pattern)) then
      (attribute {"group"} {replace($param, $pattern, "$2")}, attribute {"name"} {replace($param, $pattern, "$1")})
     else attribute {"name"} {$param}
   }

    let $vaules := function($param) {
     let $value := tokenize($param, "=")
     return 
      if($value = $param) then ()
     else
      element {"param"} {
      $positions ($value[1]),
      attribute {"value"} {$value[2]}
    }
   }


   let $array := function($value) {
     let $params := tokenize($value, "&amp;amp;")
     for $param in $params return $vaules($param)
    }
    

    let $f := function($k, $v) {
     (<parameter name="{$k}">{$v}</parameter>, $array($v) )
    }
    

    let $items := map:for-each($request?parameters, $f)
    let $params := <parameters>{$items}</parameters>
    
    
    let $result := $create-query($params)
    
(:    let $result := $params:)
    
    return <result>{$result}</result>
    
};

declare function test:query-advanced(
    $query-options as element(query-option)+,
    $target-texts as xs:string*,
    $sortBy as xs:string*,
    $position as xs:string?
    ) {

        for $query-option in $query-options
        let $field := $query-option/@field
        let $query := $query-option/query
        let $options := local:options-to-map($query-option/options)
        let $hits := (: <hits /> :)
          
            switch ($field)
            case "lemma" return
                    if (exists($target-texts)) then
                        for $text in $target-texts
                        return
                            $config:data-root ! doc(. || "/dictionaries/LeDIIR-" || $text || ".xml")//tei:entry[not(@copyOf)][ft:query(., $query, $options)]
                    else
                        collection($config:data-root || "/dictionaries/")//tei:entry[not(@copyOf)][ft:query(., $query, $options)]
            case "part-of-speech" return
                    collection($config:data-root || "/dictionaries/")//tei:entry[not(@copyOf)]//tei:gram[@type='pos'][ft:query(., $query, $options)]
            case "pronunciation" return
                    collection($config:data-root || "/dictionaries/")//tei:entry[not(@copyOf)]//tei:pron[ft:query(., $query, $options)]
            case "domain" return
                    collection($config:data-root || "/dictionaries/")//tei:entry[not(@copyOf)]//tei:usg[@type='domain'][ft:query(., $query, $options)]
            case "headword" return
                    (: collection($config:data-root || "/dictionaries/")//tei:entry[not(@copyOf)]//(tei:form[@type=('lemma', 'variant')]/tei:orth | tei:ref[@type='reversal'] | tei:form[@type=('lemma', 'variant')]/tei:pron)[ft:query(., $query, $options)] :)
                    collection($config:data-root || "/dictionaries/")//tei:entry[not(@copyOf)]//tei:ref[@type='reversal'][ft:query(., $query, $options)]
            default return
                    collection($config:data-root || "/dictionaries/")//tei:entry[not(@copyOf)][ft:query(., $query, $options)]
          
        return (<field>{$field}</field>, $query, $options, <hits>{$hits}</hits>)
};


declare function local:value-tokenizer ($value) {
 tokenize(data($value), '\s?\|\s?')
};

declare function local:facets-to-map 
  ($option as element()) as item()* {
  
  map {
   local-name($option) : local:value-tokenizer($option)
  }
};

declare function local:options-to-map
($options as element()) as item()* {

 map:merge(
  for $option in $options/*
  return
   if ($option[self::facets]) then
     map { local-name($option) : local:facets-to-map($option/*) }
   else if ($option/*) then
    map { local-name($option) : local:options-to-map($option) }
   else
    map { local-name($option) : local:value-tokenizer($option) }
  )
};