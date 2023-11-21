xquery version "3.1";

module namespace rq = "http://www.daliboris.cz/ns/xquery/request";

declare variable $rq:values-delimiter := "\|";
declare variable $rq:deepObjects := ("facet");
declare variable $rq:indexed-regex := "([^\[]*)\[([^\]]*)\]";

declare function rq:get-api-parameters($request as map(*)) as element(parameters) {

    let $p := function($k, $v) {<parameter>{
            rq:get-parameter-attributes($k),
            rq:get-parameters-value($v)}
        </parameter>}

    let $items := map:for-each($request?parameters, $p)

    let $items := rq:group-parameters($items)

    let $items := rq:hierarchize-parameters($items)

    let $items := rq:sort-parameters($items)

    return <parameters type="api">{$items}</parameters>
};

declare function rq:get-request-parameters($request as map(*)) as element(parameters) {

    let $items := for $param in request:get-parameter-names()
                    return
                        <parameter>
                                {
                                    rq:get-parameter-attributes($param),
                                    rq:get-parameters-value(request:get-parameter($param, ()))
                                }
                        </parameter>

    let $items := rq:group-parameters($items)

    let $items := rq:hierarchize-parameters($items)

    let $items := rq:sort-parameters($items)

    return <parameters type="request">{$items}</parameters>
};

declare function rq:get-all-parameters($request as map(*)) as element(parameters) {

    let $api := rq:get-api-parameters($request)
    let $request := rq:get-request-parameters($request)
    let $result := rq:merge-parameters($api, $request)
    return $result
};

declare %private function rq:merge-parameters(
        $api as element(parameters), 
        $request as element(parameters)
        ) as element(parameters) {
    let $items := for $item in $api/*
        let $related := $request/*[@name = $item/@name]
        return if ($related) then
            element {node-name($related[1])} {
                $item/@*,
                $related/node()
            }
        else $item
    let $new := for $item in $request/*
        return if ($api/*[@name = $item/@name]) then
            ()
        else $item

    let $result := rq:sort-parameters(($items, $new))

    return <parameters type="merged">{$result}</parameters>
};

declare %private function rq:get-parameter-attributes($key as xs:string) {

    if(matches($key, $rq:indexed-regex)) then 
        let $name := analyze-string($key, $rq:indexed-regex)/*/*[1]
        let $group := analyze-string($key, $rq:indexed-regex)/*/*[2]
        return if($name = $rq:deepObjects) then
        (
            attribute name {$group}, 
            attribute group {$name}
        )
        else
        (
            attribute name {$name}, 
            attribute group {$group}
        ) 
      else 
        attribute name {$key} 
};

declare %private function rq:get-parameters-value($value as item()*) {
    
        if (empty($value)) then ()
        else 
            if(count($value) = 1) then
                typeswitch ($value)
                    case map(*)
                        return map:for-each($value, rq:get-request-parameters#1)
                    case array(*)
                        return rq:get-value-items($value)
                    case xs:string
                        return if(matches($value, $rq:values-delimiter)) then 
                            let $items := array{tokenize($value, $rq:values-delimiter)}
                            return rq:get-value-items($items)
                        else
                            if($value = "") then ()
                            else
                            <value>{$value}</value>
                    case xs:integer
                        return <value>{$value}</value>
                default
                return <value type="unknown">{$value}</value>
            else
                rq:get-value-items(array {$value})

};

declare %private function rq:get-value-items($value as array(*)) {
    array:for-each($value, function($x) {<value>{$x}</value>})
};

declare %private function rq:sort-parameters($items as element()*) as element()* {
    for $item in $items
        order by if($item/@n) then $item/@n else $item/@name 
        return if($item/*) then 
            element {node-name($item)}
                {
                    $item/@*,
                    rq:sort-parameters($item/*) 
                }
            else $item
};

declare %private function rq:group-parameters($items as element(parameter)*) as element()* {
    let $items := for $item in $items
      let $group := $item/@group
      group by $group
      return if(exists(($group))) then <group name="{$group}">
        {
            for $element in $item
                return element {node-name($element)}
                 { 
                    $element/(@* except @group),
                    $element/node() 
                }
        }
      </group>
      else $item
    
    let $items := for $item in $items 
    return if(local-name($item) = 'group' and (every $param in $item/parameter satisfies $param[not(text() | *[node()])]))
        then ()
    else $item
    
    return $items

};

declare %private function rq:hierarchize-parameters($items as element()*) as element()* {
       let $delim := "\|"
   
    let $result := for $item in $items 
     return if($item[value[matches(., $delim)]]) then
     <parameter name="{$item/@name}" has-hierarchy="true">
    {rq:hierarchize-values($item/value)}
   </parameter>
     else if($item[value]) then
       $item
      else
     element {node-name($item)}
                 { 
                    $item/@*,
                    rq:hierarchize-parameters($item/*) 
                } 
   
   return $result
};

declare %private function rq:hierarchize-values($values as xs:string*) {
let $delim := "|"
return
 for $value in $values
                let $prefix := if(contains($value, $delim)) then substring-before($value, $delim) else $value
                 group by $prefix
                
               return
               

               <value text="{$prefix}"> 
               {
                  for $item in $value
                  where contains($item, $delim)
                  let $val := substring-after($item, $delim)
                  return if(contains($val, $delim)) then rq:hierarchize-values($val) else <value text="{$val}" />
                  }
                  </value>
                
};