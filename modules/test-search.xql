xquery version "3.1";

module namespace test="http://www.tei-c.org/tei-simple/test";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace lapi="http://www.tei-c.org/tei-simple/query/tei-lex" at "query-tei-lex.xql";

declare function test:search($request as map(*)) {
    let $query := $request?parameters?query
    let $options := $request?body?options
    return <result length="{string-length($options)}"> {$query, string-length($options)} <options>{$request?body}</options> </result>
};

