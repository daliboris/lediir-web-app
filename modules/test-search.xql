xquery version "3.1";

module namespace test="http://www.tei-c.org/tei-simple/test";
declare namespace map = "http://www.w3.org/2005/xpath-functions/map";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace lapi="http://www.tei-c.org/tei-simple/query/tei-lex" at "query-tei-lex.xql";
import module namespace qrp="https://www.daliboris.cz/ns/xquery/query-parser/1.0"  at "query-parser.xql";

declare function test:search($request as map(*)) {
    let $query := $request?parameters?query
    let $options := $request?body?options
    return <result length="{string-length($options)}"> {$query, string-length($options)} <options>{$request?body}</options> </result>
};

declare function test:get-parameters($request as map(*)) {


  let $get-query := function($parameter as element(param)*) {
    qrp:get-query-options($parameter[@name='query-advanced']/@value, $parameter[@name='position']/@value, $parameter[@name='field']/@value)
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
