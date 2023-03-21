xquery version "3.1";

module namespace edq = "http://www.daliboris.cz/schema/ns/xquery";
declare namespace map = "http://www.w3.org/2005/xpath-functions/map";

(:~ 
 : Contains map with these main keys:
 : query:
 : options:
 : fields:
 : facets:
 : full-options:
 : xml: xml representation of the input exist-db-query and query, options, fields and facets values of the map
 :)
declare function edq:parse-exist-db-query($input as element(exist-db-query)) as map(*) {
    let $query :=  edq:parse-query($input/query-option)
    let $options := edq:parse-options($input/query-option)
    let $fields := edq:parse-fields($input)
    let $facets := edq:parse-facets($input/facets)

    (: return edq:return-as-xml($input, $query,$options,$fields, $facets) :)
    return edq:return-as-maps($input, $query, $options, $fields, $facets)
    
};

declare %private function edq:return-as-maps($input as element(exist-db-query), $query, $options, $fields, $facets) {
    map:merge( (
            map:entry("query", $query),
            map:entry("options", $options),
            map:entry("fields", $fields),
            map:entry("facets", $facets),
            map:entry("full-options", map:merge(($options, $fields, $facets))),
            map:entry("xml", edq:return-as-xml($input, $query, $options, $fields, $facets) )
    ) )
};

declare %private function edq:return-as-xml($input as element(exist-db-query), $query, $options, $fields, $facets) {
<exist-db-query>
    {
          <query>{$query}</query>
        , <options>{edq:map-to-xml($options)}</options>
        , <fields>{edq:map-to-xml($fields)}</fields>
        , <facets>{edq:map-to-xml($facets)}</facets>
        , <input>{$input}</input>
    }
</exist-db-query>
};

(:~ 
 : Expected input:
 :<pre>
 :<query-option field="headword">
 :   <query>
 :       <bool>
 :           <term occur="must">fortress</term>
 :           <wildcard occur="must">hrad*</wildcard>
 :       </bool>
 :   </query>
 :   <options>
 :       <default-operator>and</default-operator>
 :       <phrase-slop>1</phrase-slop>
 :       <leading-wildcard>yes</leading-wildcard>
 :       <filter-rewrite>yes</filter-rewrite>
 :   </options>
 : </query-option>
 :</pre>
 : @author Boris Lehečka
 : @version 1.0
 : @since 1.0
 : @param $input an element <query-option> with options element for each query
 : @return: headword: (fortress AND hrad*)
:)
declare %private function edq:parse-query($input as element(query-option)*) as xs:string? {
    let $result :=
    if(empty($input)) then
        ()
    else
        for $qo in $input
        let $field := $qo/@field
        let $query := string-join($qo/query/bool/*, ' AND ')
        return concat($field, ':', '(', $query, ') ')

    return string-join($result, ' AND ')
};

(:~
 : Expected input:
 : <pre>
 :    <options>
 :       <default-operator>and</default-operator>
 :       <phrase-slop>1</phrase-slop>
 :       <leading-wildcard>yes</leading-wildcard>
 :       <filter-rewrite>yes</filter-rewrite>
 :   </options>
 : </pre>
 : @author Boris Lehečka
 : @version 1.0
 : @since 1.0
 : @param $input an element <query-option> with options element for each query
 : @return: <pre>
 : map {
 :  "leading-wildcard": "no",
 :  "default-operator": "and",
 :  "phrase-slop": "1",
 :  "filter-rewrite": "yes"
 : }
 :</pre>
:)
declare %private function edq:parse-options($input as element(query-option)*) {
    let $result :=
    if(empty($input)) then
        map{}
    else
        let $options := $input/options
        let $names := distinct-values($options/*/local-name())
        for $name in $names
            let $values := distinct-values($options/*[local-name() = $name]/data())
            let $value := if (count($values) = 1) then $values
            else
            switch($name)
            case "leading-wildcard" return "yes"
            case "filter-rewrite" return "yes"
            case "default-operator" return "or"
            case "phrase-slop" return format-number(max($values), "0")
            default return $values[1]
        return map:entry($name, $value)

        (:
            for $qo in $input
        return for $options in $qo/options
            for $item in $options/*
            return map { local-name($item) : $item
            }
        :)
            
    return map:merge($result)
};

(:~
 : Expected input:
 : <pre>
 :   <fields>
 :      <field name="headword" />
 :      <filed name="sortKey" />
 :   </fields>
 : </pre>
 : @author Boris Lehečka
 : @version 1.0
 : @since 1.0
 : @param $input an element <query-option> with options element for each query
 : @return: <pre>
 : map {
 :  "fields": ("headword", "sortKey")
 : }
 :</pre>
:)
declare %private function edq:parse-fields($input as element(exist-db-query)*) {
    let $result :=
        if(empty($input/query-option/@field | $input/fields)) then
            map{}
        else
            let $values := distinct-values($input/query-option/@field | $input/fields/field/@name)
            return map { "fields" : distinct-values($values) }
    return $result
};

(:~
 : Parses XML input
 : <pre>
 :    <facets>
 :       <facet name="partOfSpeechAll">
 :           <value>adj</value>
 :           <value>adv</value>
 :       </facet>
 :       <facet name="polysemy">
 :           <value>2</value>
 :       </facet>
 :   </facets>
 : </pre>
 :
 : @author Boris Lehečka
 : @version 1.0
 : @since 1.0
 : @param $input an element <facets> with individual facets and selected values
 : @return: <pre>
 : map {
 :   "facets": map {
 :   "keyword": ("indexing", "facets")
 :  }
 : </pre>
:)
declare %private function edq:parse-facets($input as element(facets)?) {
    let $result :=
         if(empty($input)) then
            map {}
        else
           map { "facets" :
             map:merge(
              for $facet in $input/facet
               let $values :=distinct-values($facet/value)
               return map:entry($facet/@name,  $values)
              )
            }
    return $result

};

declare %private function edq:map-to-xml-format-value($value) {
    let $result :=
    if ($value instance of map(*)) then
        edq:map-to-xml($value)
    else
        if(count($value) = 1) then
            $value
        else
            let $items := for $i in $value return concat('"', $i, '"')
            return concat('(', string-join($items, ', '), ')')
        
    return $result
};

declare %private function edq:map-to-xml-kvp($key, $value) as element(item) {
<item>
    <name>{$key}</name>
    <value>{edq:map-to-xml-format-value($value)}</value>
</item>
};

declare %private function edq:map-to-xml($input as map(*)) as element(item)* {

    let $items := map:for-each($input, edq:map-to-xml-kvp#2)

    return $items
};