xquery version "3.1";

module namespace lapi="http://www.tei-c.org/tei-simple/query/tei-lex";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace map = "http://www.w3.org/2005/xpath-functions/map";
declare namespace exist = "http://exist.sourceforge.net/NS/exist";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
(:import module namespace nav="http://www.tei-c.org/tei-simple/navigation/tei-lex" at "navigation-tei-lex.xql";:)
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation/tei" at "navigation-tei.xql";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "query.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace dapi="http://teipublisher.com/api/documents" at "lib/api/document.xql";
import module namespace router="http://e-editiones.org/roaster";
import module namespace capi="http://teipublisher.com/api/collection" at "lib/api/collection.xql";
(: import module namespace facets="http://teipublisher.com/facets" at "facets.xql"; :)
import module namespace lfacets="http://www.tei-c.org/tei-simple/query/tei-lex-facets";
import module namespace rq="http://www.daliboris.cz/ns/xquery/request"  at "request.xql";
import module namespace qrp="https://www.daliboris.cz/ns/xquery/query-parser/1.0"  at "query-parser.xql";
import module namespace edq = "http://www.daliboris.cz/schema/ns/xquery" at "exist-db-query-parser.xql"; 
import module namespace console="http://exist-db.org/xquery/console";

(:
 Semantic categories

 Implementation based on tutorial available at https://faq.teipublisher.com/api/tutorial/
:)

declare variable $lapi:debug := false();

declare variable $lapi:default-browse-sort-field := <sort field="sortKey" />;
declare variable $lapi:default-search-sort-field := <sort field="sortKeyWithFrequency" />;

declare function lapi:domains($request as map(*)) {
    let $all := "all"
    let $format := $request?parameters?format
    let $query := normalize-space(if (empty($request?parameters?query))
             then () else xmldb:decode($request?parameters?query))
    let $idnoParam := $request?parameters?idno
    let $limit := $request?parameters?limit
    let $categories :=
        if ($query and $query != '') then
            (collection($config:data-root)//id($config:lex-taxonomy-ids))[1]//tei:category[tei:catDesc[@xml:lang='en'][contains(., $query)]]
        else
            (collection($config:data-root)//id($config:lex-taxonomy-ids))[1]/tei:category[tei:catDesc[@xml:lang='en']]
    (: let $sorted := sort($categories, "?lang=en", function($categories) { $categories/tei:catDesc[@xml:lang='en']/tei:idno }) :)
    let $sorted := $categories
    let $letter := 
        if (count($categories) < $limit or $limit = 0) then 
            $all
        else if ($idnoParam = '') then
            $sorted[1]/tei:catDesc[@xml:lang='en']/tei:idno
        else
            $idnoParam
    let $byLetter :=
        if ($letter = $all) then
            $sorted
        else
            filter($sorted, function($entry) {
                starts-with(lower-case($entry/tei:catDesc[@xml:lang='en']/tei:idno), lower-case($letter))
            })
    return
        if($format = "html") then
            for $category in $categories
              return lapi:output-domain-get-hmtl($category)
        else
        map {
            "items": lapi:output-domain($byLetter, $letter, $query),
            "list-count" : count($byLetter),
            "list-categories" : count($categories),
            "limit" : $limit,
            "categories":
                if (count($categories) lt $limit) then
                    []
                else array {
                    for $index in 1 to string-length('123456789')
                    let $alpha := substring('123456789', $index, 1)
                    let $hits := count(filter($sorted, function($entry) { starts-with(lower-case($entry/tei:catDesc[@xml:lang='en']/tei:idno), lower-case($alpha))}))
                    where $hits > 0
                    return
                        map {
                            "category": $alpha,
                            "count": $hits
                        },
                    map {
                        "category": $all,
                        "count": count($sorted)
                    }
                }
        }
};

declare function lapi:output-domain($list, $idno as xs:string, $query as xs:string?) as element()? {
    array {
        for $category in $list
        let $categoryParam := if ($idno = "all") then $category/tei:catDesc[@xml:lang='en']/tei:idno else $idno
        let $params := "category=" || $categoryParam || "&amp;query=" || $query
        let $desc := $category/tei:catDesc[@xml:lang='en']
        let $label := $desc/tei:idno || " " || $desc/tei:term
        return
            <span class="place">
                <a href="?{$params}">{$label}</a>
            </span>
    }
};


declare function lapi:output-domain-get-summary($catDesc as element(tei:catDesc)?) as item()* { 
if ($catDesc) then
     <span lang="{$catDesc/@xml:lang}" xml:lang="{$catDesc/@xml:lang}" class="tei-catDesc">
        <span class="tei-idno">{concat($catDesc/tei:idno, " ")}</span>
        <span class="tei-term">{string($catDesc/tei:term)}</span>
     </span>
    else ()
 }; 


declare function lapi:output-domain-get-hmtl ($category as element(tei:category)) as item()* 
{ 

 if ($category/tei:category) then
  <article class="category" id="{$category/@xml:id}">
            <details>
                <summary>
                    <h4><input type="checkbox" value="{$category/@xml:id}" />
                     {lapi:output-domain-get-summary($category/tei:catDesc[@xml:lang='en'])} 
                    </h4>
                </summary>
                {
                 for $cat in $category/tei:category
                  return lapi:output-domain-get-hmtl($cat)
                }
            </details>
        </article>
  else
   <h4><input type="checkbox" value="{$category/@xml:id}" />
   {lapi:output-domain-get-summary($category/tei:catDesc[@xml:lang='en'])}
   </h4>
};

declare function lapi:entry($request as map(*)) {
    let $id := $request?parameters?id
    let $format := $request?parameters?format
    let $hits :=
        if ($id) then
             collection($config:data-default)//id($id)
        else
            ()
    return
            if($hits) then
                if($format = "html") then 
                    let $config := tpu:parse-pi(root($hits[1]), ()) 
                    return lapi:get-html($hits, $request, $config)
                else (
                    response:set-header( "Content-Type", "application/xml" ),
                    $hits
                    )
             else router:response(404, "application/json", map {
                "status": "Not Found",
                "path": $request?parameters?id,
                "report": "[Entry with @xml:id " || $id || " doesn't exist.]"
            })
};

declare function lapi:dictionaries($request as map(*)) {  
    let $format := $request?parameters?format
    let $parts := $request?parameters?dictionary-parts

    return capi:list($request)
};

declare function lapi:dictionary-entries($request as map(*)) { 
    (:
    if (empty($request?parameters?query)) then
        if($request?parameters?format = "xml") then 
            lapi:show-hits-xml($request, 
            session:get-attribute($config:session-prefix || ".hits"),
            session:get-attribute($config:session-prefix || ".docs"))
            else 
            lapi:show-hits-html($request, 
            session:get-attribute($config:session-prefix || ".hits"),
            session:get-attribute($config:session-prefix || ".docs"))
    else
    :)

    let $dictionaryId := $request?parameters?id
    let $format := $request?parameters?format
    let $start := $request?parameters?start
    let $per-page := $request?parameters?per-page
    let $position := $request?parameters?position

    let $max-hits := $config:maximum-hits-limit

    let $doc := collection($config:data-default)/id($dictionaryId)
    (:
     For example, to view all articles in the collection you could pass in an empty sequence in place of the query string like this
     //db:article[ft:query(., (), map { "fields": ("title", "author") })]

     http://exist-db.org/exist/apps/doc/lucene.xml#display-facets
     Function ft:facets expects a sequence of nodes belonging to a result set obtained from one or more calls to ft:query. 
    :)
    (: let $hitsAll := for $hit in $doc//tei:entry[ft:query(., (), map { "fields": ("sortKey") } )] order by ft:field($hit, "sortKey") return $hit :)
    let $hitsAll := lapi:query-default(("entry"), "*", $dictionaryId, (), $position)
    let $hitsAll := for $hit in $doc//tei:entry[not(parent::tei:entry)] order by $hit/@sortKey return $hit
    let $hitCount := count($hitsAll)

    let $hits := if ($max-hits > 0 and $hitCount > $max-hits) 
        then subsequence($hitsAll, 1, $max-hits) 
        else $hitsAll
            (:Store the result in the session.:)
    let $store := (
        session:set-attribute($config:session-prefix || ".hits", $hitsAll),
        session:set-attribute($config:session-prefix || ".hitCount", $hitCount),
        session:set-attribute($config:session-prefix || ".search", if (empty($request?parameters?query))
             then () else xmldb:decode($request?parameters?query)),
        session:set-attribute($config:session-prefix || ".docs", $request?parameters?id)
    )

    (: 
    let $target-texts := $request?parameters?id
    let $files := if (exists($target-texts)) then
                        for $text in $target-texts
                        return
                            $config:data-root || "/dictionaries/LeDIIR-" || $text || ".xml"
                else "nic"

   return <items>
        <item name="dictionaryId">{$dictionaryId}</item>
        <item name="files">{$files}</item>
        <item name="start">{$start}</item>
        <item name="per-page">{$per-page}</item>
        <item name="hitCount">{$hitCount}</item>
        <item name="max-hits">{$max-hits}</item>
        <item name="hits">{$config:session-prefix || ".hits"}</item>
    </items>
   :)
     
    return if($format = "xml") then 
        lapi:show-hits-xml($request, $hits, $request?parameters?id)
    else 
        lapi:show-hits-html($request, $hits, $request?parameters?id)
    
    
};

declare function lapi:dictionary-entry($request as map(*)) {  
    let $dictionaryId := $request?parameters?id
    let $format := $request?parameters?format
    let $parts := $request?parameters?dictionaryParts
    let $entry-id := $request?parameters?entry-id

    let $hits := collection($config:data-default)//id($entry-id)
    let $hits := $hits/ancestor-or-self::tei:entry[1]

    return if($format = "xml") then 
        lapi:show-hits-xml($request, $hits, $dictionaryId)
    else 
        lapi:show-hits-html($request, $hits, $dictionaryId)
};

(: Dictionary entries :)
declare function lapi:browse($request as map(*)) { 
    
    let $query-start-time := util:system-time()
    let $max-hits := $config:maximum-hits-limit

    let $format := $request?parameters?format
    let $chapter := $request?parameters?chapter
    let $dictId := $request?parameters?id
    let $query := $request?parameters?query

    let $dictId := lapi:get-dictionary-id($dictId)

    let $chapter := lapi:get-chapter-id($dictId,  $chapter)

    let $log := if($lapi:debug) then console:log("[lapi:browse] $chapter: " || $chapter || "; $dictId: " || $dictId) else ()
    let $log := if($lapi:debug) then lapi:log-duration($query-start-time, "[lapi:browse] $query-duration:") else ()
    

    
    return
    (: (::)
    if(true()) then

        let $exist-db-query := lapi:get-exist-db-query-xml($request)
        let $qry := edq:parse-exist-db-query($exist-db-query)

        <result>{(<request>
                        <parameter name="format" value="{$format}" emtpy="{empty($format)}" />
                        <parameter name="chapter" value="{$chapter}" emtpy="{empty($chapter)}"/>
                        <parameter name="dictId" value="{$dictId}" emtpy="{empty($dictId)}"/>
                        <parameter name="query" value="{$query}" emtpy="{empty($query)}" />
                    </request>
                    , $exist-db-query
                    , $qry?xml
                    )}
        </result>
        else
     :)
    
    
    
    if (empty($chapter))
        then
            if($format = "html") then 
            (:lapi:show-hits($request, session:get-attribute($config:session-prefix || ".hits"), session:get-attribute($config:session-prefix || ".docs")):)
                lapi:show-hits-html($request, session:get-attribute($config:session-prefix || ".hits"), 
                session:get-attribute($config:session-prefix || ".docs"))
            else
                lapi:show-hits-xml($request, session:get-attribute($config:session-prefix || ".hits"), 
                session:get-attribute($config:session-prefix || ".docs"))
        else
            (:Otherwise, perform the query.:)
            (: Here the actual query commences. This is split into two parts, the first for a Lucene query and the second for an ngram query. :)
            (:The query passed to a Luecene query in ft:query is an XML element <query> containing one or two <bool>. The <bool> contain the original query and the transliterated query, as indicated by the user in $query-scripts.:)
            let $exist-db-query := lapi:get-exist-db-query-xml($request, $lapi:default-browse-sort-field)
            let $hitsAll := if(empty($exist-db-query)) then
                    lapi:browse-default($chapter, $dictId)
                 else 
                    let $qry := edq:parse-exist-db-query($exist-db-query)
                    (: 
                    let $hits := lapi:browse-default($chapter, $dictId)
                    return  lapi:execute-query-return-hits($qry?query, $qry?full-options, $hits)
                     :)
                     return  lapi:execute-query-return-hits($qry?query, $qry?full-options, $exist-db-query/sort/@field) (: $exist-db-query/sort/@field :)

            let $hitCount := count($hitsAll)
            let $log := if($lapi:debug) then console:log("[lapi:browse] $hitCount: " || $hitCount) else ()
            let $log := if($lapi:debug) then lapi:log-duration($query-start-time, "[lapi:browse] alfter $hitCount $query-duration:") else ()

            (:Store the result in the session.:)
            let $store := (
                session:set-attribute($config:session-prefix || ".hits", $hitsAll),
                session:set-attribute($config:session-prefix || ".hitCount", $hitCount),
                session:set-attribute($config:session-prefix || ".search", if (empty($query))
             then () else xmldb:decode($query)),
                session:set-attribute($config:session-prefix || ".chapter", if (empty($chapter))
             then () else xmldb:decode($chapter)),
                session:set-attribute($config:session-prefix || ".docs", $dictId)
            )

            let $log := if($lapi:debug) then lapi:log-duration($query-start-time, "[lapi:browse] after $store $query-duration:") else ()

            let $hits := if ($max-hits > 0 and $hitCount > $max-hits) then subsequence($hitsAll, 1, $max-hits) else $hitsAll
            
            
            let $result := if($format = "xml") then 
                lapi:show-hits-xml($request, $hits, $dictId, "div", "http://www.tei-c.org/ns/1.0")
            else lapi:show-hits-html($request, $hits, $dictId)
                (:lapi:show-hits($request, $hits, $request?parameters?doc):) 
            
            let $log := if($lapi:debug) then lapi:log-duration($query-start-time, "[lapi:browse] after lapi:show-hits $query-duration:") else ()
            return $result
};

(: Dictionary entries :)
declare function lapi:search($request as map(*)) {

   let $exist-db-query := lapi:get-exist-db-query-xml($request)
   (: (::)
   let $param-values := rq:get-request-parameters($request)
   let $rq-parameters := rq:get-api-parameters($request)
   let $facets := lapi:get-facets-values($request)
   let $parameters := rq:get-all-parameters($request)
   let $qa := empty($request?parameters("query-advanced[1]"))
   let $q := empty($request?parameters?query)

    let $q := empty($param-values/parameter[@name='query']/value)
    let $qa := empty($param-values/group[@name='1']/parameter)

   let $empties := empty($request?parameters?query) and empty($request?parameters("query-advanced[1]"))
   let $lucene := if(not($q)) then
                    lapi:get-lucene-query($param-values/parameter[@name=('query', 'field', 'position')])
                else for $group in $parameters/group[parameter[@name='query-advanced'][node()]]
                    order by $group/@name
                    return lapi:get-lucene-query($group/parameter)
    let $combined := qrp:combine-queries($lucene)
    let $exist-db-query := if (empty($combined)) then () else <exist-db-query>{($combined, $facets)}</exist-db-query>
   return if($parameters) then (
        <result>{($rq-parameters, $param-values, <fcs>{$facets}</fcs>, $parameters, $exist-db-query, <empty>{($qa, $q, $empties)}</empty>)}</result>, 
            if($parameters/parameters/parameter[@name='query']) then
                <modification>
                        {lapi:modify-query($request?parameters?query, $request?parameters?position)}
                </modification>
            else ()
    )
    else
    :) (::)
    
          (:If there is no query string, fill up the map with existing values:)
    let $log := if($lapi:debug) then console:log($exist-db-query) else ()
    let $max-hits := $config:maximum-hits-limit
    return
    if ((empty($request?parameters?query) and empty($request?parameters("query-advanced[1]"))) or empty($exist-db-query))
    then
        let $hitsAll := session:get-attribute($config:session-prefix || ".hits")
        let $hitCount := count($hitsAll)
        let $hits := if ($max-hits > 0 and $hitCount > $max-hits) then subsequence($hitsAll, 1, $max-hits) else $hitsAll

        (:lapi:show-hits($request, session:get-attribute($config:session-prefix || ".hits"), session:get-attribute($config:session-prefix || ".docs")):)
        return if($request?parameters?format = "xml") then
                lapi:show-hits-xml($request, $hits, session:get-attribute($config:session-prefix || ".docs"), "div", "http://www.tei-c.org/ns/1.0")
            else
             lapi:show-hits-html($request, $hits, session:get-attribute($config:session-prefix || ".docs"))
    else
        (:Otherwise, perform the query.:)
        (: Here the actual query commences. This is split into two parts, the first for a Lucene query and the second for an ngram query. :)
        (:The query passed to a Luecene query in ft:query is an XML element <query> containing one or two <bool>. 
        The <bool> contain the original query and the transliterated query, as indicated by the user in $query-scripts.:)
       let $hitsAll :=
                let $qry := edq:parse-exist-db-query($exist-db-query)
                return  lapi:execute-query-return-hits($qry?query, $qry?full-options, $exist-db-query/sort/@field)

        let $hitCount := count($hitsAll)
        (:Store the result in the session.:)
        let $store := (
            session:set-attribute($config:session-prefix || ".hits", $hitsAll),
            session:set-attribute($config:session-prefix || ".hitCount", $hitCount),
            session:set-attribute($config:session-prefix || ".search", if (empty($request?parameters?query))
             then () else xmldb:decode($request?parameters?query)),
            session:set-attribute($config:session-prefix || ".field", $request?parameters?field),
            session:set-attribute($config:session-prefix || ".position", $request?parameters?position),
            session:set-attribute($config:session-prefix || ".docs", $request?parameters?ids)
        )
        let $hits := if ($max-hits > 0 and $hitCount > $max-hits) then 
            subsequence($hitsAll, 1, $max-hits) else $hitsAll
        
        
        return if($request?parameters?format = "xml") then
                lapi:show-hits-xml($request, $hits, $request?parameters?ids, "div", "http://www.tei-c.org/ns/1.0")
            else
                lapi:show-hits-html($request, $hits, $request?parameters?ids)
        
};


declare %private function lapi:get-facets-values($request as map(*)) as element(facets)? {
    let $item-name := "facet"
    let $items-name := "facets"
    let $parameters := rq:get-all-parameters($request)
    let $items := $parameters/group[@name=$item-name]/parameter
    let $items := if(empty($items)) then ()
        else element {$items-name} {
                for $i in $items return 
                    element {$item-name} {
                        $i/@*,
                        $i/node()
                    }
                }
    return $items
};

declare %private function lapi:execute-query-return-hits($query as item(), $options as item()?, $sort as xs:string? ) {
 
 lapi:execute-query-return-hits($query, $options, $sort, ())

 };

declare %private function lapi:execute-query-return-hits($query as item(), $options as item()?, $sort as xs:string?,
    $hits as element(tei:entry)* ) {

    let $console := if($lapi:debug) then 
        (
            console:log("[lapi:execute-query-return-hits] $query:"),
            console:log($query),
            console:log("[lapi:execute-query-return-hits] $options:"),
            console:log($options),
            console:log("[lapi:execute-query-return-hits] $sort:"),
            console:log($sort)
        )
        else ()

    let $query-start-time := util:system-time()
    let $ft := if(empty($hits)) then
            collection($config:data-default)//tei:entry[not(parent::tei:entry)][ft:query(., $query, $options)]
        else 
            $hits[ft:query(., $query, $options)]
    (: let $result := $ft :)
    let $console := if($lapi:debug) then console:log("[lapi:execute-query-return-hits] $sort: " || $sort || "; empty or '': " || (empty($sort) or $sort = '')) else ()
    (: let $console := if($lapi:debug) then console:log("ft") else ()
    let $console := if($lapi:debug) then console:log($ft) else () :)
    let $result := if(empty($sort) or $sort = '') then $ft
         else if($sort = 'score') then
         for $f in $ft order by ft:score($f) descending return $f
         (: else if($sort = 'lemma' or empty($sort)) then $ft :)
         else for $f in $ft order by ft:field($f, $sort) ascending return $f

    let $log := if($lapi:debug) then lapi:log-duration($query-start-time, "[lapi:execute-query-return-hits] after sort:") else ()

    return
        $result

};

declare %private function lapi:prepare-session($request as map(*), $function as xs:string) {
    let $max-hits := $config:maximum-hits-limit

    let $hitsAll :=
        if($function = 'browse') then
            let $format := $request?parameters?format
            let $chapter := $request?parameters?chapter
            let $dictId := $request?parameters?id
            let $query := $request?parameters?query

            let $dictId := if ($dictId || ""  = "") then
                    lapi:get-first-dictionary()
                else
                    $dictId

            let $chapter := if ($chapter || ""  = "") then
                    lapi:get-first-chapter($dictId)
                else
                    $chapter

            return lapi:browse-default($chapter, $dictId)
        else
            for $hit in lapi:query-default(
                $request?parameters?field, 
                if (empty($request?parameters?query))
                    then () 
                else xmldb:decode($request?parameters?query), 
                tokenize($request?parameters?ids),
                (),
                $request?parameters?position
                )
                    (: sorting by @sortKey attribute using default collation :)
                    order by $hit/@sortKey
                    return $hit
        let $hitCount := count($hitsAll)

    let $hitCount := count($hitsAll)
        (:Store the result in the session.:)
        let $store := (
            session:set-attribute($config:session-prefix || ".hits", $hitsAll),
            session:set-attribute($config:session-prefix || ".hitCount", $hitCount),
            session:set-attribute($config:session-prefix || ".search", if (empty($request?parameters?query))
             then () else xmldb:decode($request?parameters?query)),
            session:set-attribute($config:session-prefix || ".field", $request?parameters?field),
            session:set-attribute($config:session-prefix || ".docs", $request?parameters?ids)
        )
                return()
};

declare %private function lapi:show-hits-xml($request as map(*), $hits as item()*, $docs as xs:string*) {
    response:set-header("pb-total", xs:string(count($hits))),
    response:set-header("pb-start", xs:string($request?parameters?start)),
    response:set-header("pb-docs", string-join($docs, ';')),
    response:set-header( "Content-Type", "application/xml" ),
    let $highlight := xs:boolean($request?parameters?highlight)
    let $config := ()
    let $result := subsequence($hits, $request?parameters?start, $request?parameters?per-page)
    let $expanded :=
        if ($highlight and exists($result)) then
            util:expand($result)
        else
            $result
    return $expanded
};

declare %private function lapi:show-hits-xml($request as map(*), $hits as item()*, $docs as xs:string*, $containter as xs:string, $namespace as xs:string) {
    let $result := lapi:show-hits-xml($request, $hits, $docs)
    return element {QName($namespace, $containter)} {$result}
};

declare %private function lapi:get-chapter-id($dictId as xs:string, $chapter) {
    let $dictId := lapi:get-dictionary-id($dictId)
    let $chapter := $chapter[. !=''][1]
    let $chapter := if($chapter || "" = "") then
            lapi:get-first-chapter($dictId)
        else
            $chapter
    return $chapter
};

declare %private function lapi:get-first-chapter($dictId as xs:string) {
    let $div := if(empty($dictId)) then
                    collection($config:metadata-default)//tei:div[@type='letter'][1]
                else
                    let $id := $dictId || "-metadata"
                    return collection($config:metadata-default)/tei:TEI[@xml:id=$id]//tei:div[@type='letter'][1] (: || "/LeDIIR-" || $dictId || ".xml" :)
    let $console := if($lapi:debug) then 
        (
            console:log("[lapi:get-first-chapter] $config:metadata-default: " || $config:metadata-default),
            console:log("[lapi:get-first-chapter] $dictId: " || $dictId),
            console:log("[lapi:get-first-chapter] $firstChapterId: " || $div/@subtype/data())
        )
        else ()
    return $div/@subtype/data()
};

declare %private function lapi:get-dictionary-id($dictId) {
    let $dictId := $dictId[. != ''][1]
    let $dictId := if ($dictId || ""  = "") then
            lapi:get-first-dictionary()
        else
            $dictId
    let $console := if($lapi:debug) then console:log("[llapi:get-dictionary-id($dictId)] $dictId: " || $dictId) else ()
    return $dictId
};

declare %private function lapi:get-first-dictionary() {
    let $project := lapi:project-xml()
    let $console := if($lapi:debug) then console:log("[lapi:get-first-dictionary] @xml:id: " || $project//dictionary[1]/@xml:id || "; dictionary: " || $project//dictionary[1]) else ()
    return $project//dictionary[1]/@xml:id
};

declare %private function lapi:show-hits-html($request as map(*), $hits as item()*, $docs as xs:string*) {
    response:set-header("pb-total", xs:string(count($hits))),
    response:set-header("pb-start", xs:string($request?parameters?start)),
    let $query-start-time := util:system-time()
    let $highlight := xs:boolean($request?parameters?highlight)
    let $config := if(empty($hits)) 
        then config:default-config(()) 
        else tpu:parse-pi(root($hits[1]), $request?parameters?view)
    let $result := subsequence($hits, $request?parameters?start, $request?parameters?per-page)
    let $expanded :=
        if ($highlight and exists($result)) then
            util:expand($result)
        else
            $result
    let $log := if($lapi:debug) then (
            console:log("api:show-hits-html: ODD" || $config?odd),
            console:log("api:show-hits-html: $highlight: " || ($highlight and exists($result)))
            )
             else ()
    let $result-html := lapi:get-html($expanded, $request, $config)
    let $log := lapi:log-duration($query-start-time, "[lapi:show-hits-html] after lapi:get-html:")
    return 
        $result-html
};

declare %private function lapi:show-hits($request as map(*), $hits as item()*, $docs as xs:string*) {
    response:set-header("pb-total", xs:string(count($hits))),
    response:set-header("pb-start", xs:string($request?parameters?start)),
    for $hit at $p in subsequence($hits, $request?parameters?start, $request?parameters?per-page)
    let $config := tpu:parse-pi(root($hit), $request?parameters?view)
    let $parent := query:get-parent-section($config, $hit)
    let $parent-id := config:get-identifier($parent)
    let $parent-id := if (exists($docs)) then replace($parent-id, "^.*?([^/]*)$", "$1") else $parent-id
    let $div := query:get-current($config, $parent)
    let $expanded := util:expand($hit, "add-exist-id=all")
    let $docId := config:get-identifier($div)
    return
        <paper-card>
            <header>
                <div class="count">{$request?parameters?start + $p - 1}</div>
                { query:get-breadcrumbs($config, $hit, $parent-id) }
            </header>
            <div class="matches">
            {
                $hit
                (:
                for $match in subsequence($expanded//exist:match, 1, 5)
                let $matchId := $match/../@exist:id
                let $docLink :=
                    if ($config?view = "page") then
                        (\: first check if there's a pb in the expanded section before the match :\)
                        let $pbBefore := $match/preceding::tei:pb[1]
                        return
                            if ($pbBefore) then
                                $pbBefore/@exist:id
                            else
                                (\: no: locate the element containing the match in the source document :\)
                                let $contextNode := util:node-by-id($hit, $matchId)
                                (\: and get the pb preceding it :\)
                                let $page := $contextNode/preceding::tei:pb[1]
                                return
                                    if ($page) then
                                        util:node-id($page)
                                    else
                                        util:node-id($div)
                    else
                        (\: Check if the document has sections, otherwise don't pass root :\)
                        if (nav:get-section-for-node($config, $div)) then util:node-id($div) else ()
                let $config := <config width="60" table="no" link="{$docId}?{if ($docLink) then 'root=' || $docLink || '&amp;' else ()}action=search&amp;view={$config?view}&amp;odd={$config?odd}#{$matchId}"/>
                return
                    kwic:get-summary($expanded, $match, $config):)
            }
            </div>
        </paper-card>
};

(:
 See dapi:print in /modules/lib/api/document.xql 
:)
declare function lapi:get-html($hits as item()*, $request as map(*), $config) {
  lapi:get-html($hits, $request, $config, "print")
};

(:
 See dapi:generate-html in /modules/lib/api/document.xql 
:)

declare function lapi:get-html($hits as item()*, $request as map(*), $config, $outputMode as xs:string) {
    let $addStyles :=
        for $href in $request?parameters?style
        return
            <link rel="Stylesheet" href="{$href}"/>
    let $addScripts :=
        for $src in $request?parameters?script
        return
            <script src="{$src}"></script>
    let $xml := <tei:TEI xmlns="http://www.tei-c.org/ns/1.0">{$hits}</tei:TEI>
    (: set root parameter to the root document of hits :)
    let $root := if(empty($hits)) then $xml else root($hits[1])
    (:    let $out := $pm-config:web-transform($xml, map { "root": $root, "webcomponents": 7 }, $config?odd):)
    let $out :=  if ($outputMode = 'print') then
                            $pm-config:print-transform($xml, map { "root": $root, "webcomponents": 7 }, $config?odd)
                        else
                            $pm-config:web-transform($xml, map { "root": $root, "webcomponents": 7 }, $config?odd)
    let $styles := ($addStyles,
                    if (count($out) > 1) then $out[1] else (),
                        <link rel="stylesheet" type="text/css" href="transform/{replace($config?odd, "^.*?/?([^/]+)\.odd$", "$1")}.css"/>
                    )

    (:   
    let $log := console:log("lapi:get-html: styles count=" || count($styles) || ", content: " || $styles[1])
    let $log := console:log("lapi:get-html: $config?odd=" || $config?odd)
    let $log := console:log("lapi:get-html: $parameters?root")
    let $log := console:log(($out[2], $out[1])[1]) 
    :)
    

    let $main := <html>{($out[2], $out[1])[1]}</html>
    return
      (:        dapi:postprocess(($out[2], $out[1])[1], $styles, $config?odd, $request?parameters?base, $request?parameters?wc):)
      (: dapi:postprocess(($out[2], $out[1])[1], $styles, $addScripts, $request?parameters?base, $request?parameters?wc) :)
      dapi:postprocess($main, $styles, $addScripts, $request?parameters?base, $request?parameters?wc)
};

declare function lapi:browse-default($chapter as xs:string,
    $text as xs:string?) {

    let $query := if(number($chapter) != xs:double('NaN')) then
         "chapter:(" || $chapter || ")"
         else
         "letter:(" || $chapter || ")"

    return if (exists($text)) then
            doc($config:data-default || "/LeDIIR-" || $text || ".xml")
            //tei:entry[ft:query(., $query)][not(@copyOf)]
        else
            collection($config:data-default)
            //tei:entry[ft:query(., $query)][not(@copyOf)]

};

declare function lapi:query-default($fields as xs:string+, $query as xs:string, $target-texts as xs:string*,
    $sortBy as xs:string*) {
    lapi:query-default($fields, $query, $target-texts, $sortBy, ())
};

declare function lapi:query-default($fields as xs:string+, 
    $query as xs:string,
    $target-texts as xs:string*,
    $sortBy as xs:string*,
    $position as xs:string?) {
    if(string($query)) then
        let $query := lapi:modify-query($query, $position)
        for $field in $fields
        return
            switch ($field)
             (: searchning only in selected parts of the dictioanry's entry :)
                case "lemma" return
                    if (exists($target-texts)) then
                        for $text in $target-texts
                        return
                            $config:data-default ! doc(. || "/LeDIIR-" || $text || ".xml")//tei:entry[not(@copyOf)][ft:query(., $query, query:options($sortBy))]
                    else
                        collection($config:data-default)//tei:entry[not(@copyOf)][ft:query(., $query, query:options($sortBy))]
                (:
                case "domain" return
                    if (exists($target-texts)) then
                        for $text in $target-texts
                        return
                            $config:data-root ! doc(. || "/" || $text)//tei:entry//tei:usg[@type='domain'][ft:query(., $query, query:options($sortBy))]
                    else
                        collection($config:data-root)//tei:entry//tei:usg[@type='domain'][ft:query(., $query, query:options($sortBy))]
                case "partOfSpeach" return
                    if (exists($target-texts)) then
                        for $text in $target-texts
                        return
                            $config:data-root ! doc(. || "/" || $text)//tei:entry//tei:gram[@type='pos'][ft:query(., $query, query:options($sortBy))]
                    else
                        collection($config:data-root)//tei:entry//tei:gram[@type='pos'][ft:query(., $query, query:options($sortBy))]
               :)
               default return
                    if (exists($target-texts)) then
                        for $text in $target-texts
                        return
                            $config:data-default ! doc(. || "/LeDIIR-" || $text || ".xml")//tei:entry[not(@copyOf)][ft:query(., $query, query:options($sortBy))]
                    else
                        collection($config:data-default)//tei:entry[not(@copyOf)][ft:query(., $query, query:options($sortBy))]
    else ()
};


(: TODO :)
declare function lapi:query-metadata($path as xs:string?, $field as xs:string?, $query as xs:string?, $sort as xs:string) {
    let $queryExpr := 
        if ($field = "file" or empty($query) or $query = '') then 
            "file:*" 
        else
            ($field, "text")[1] || ":" || $query
    let $options := query:options($sort, ($field, "text")[1])
    let $result :=
        $config:data-default ! (
            collection(. || "/" || $path)//tei:text[ft:query(., $queryExpr, $options)]
        )
    return
        query:sort($result, $sort)
};

(: 
<query-option field="headword">
        <query>
            <bool>
                <term occur="must">fortress</term>
                <wildcard occur="must">*hrad</wildcard>
            </bool>
        </query>
        <options>
            <default-operator>and</default-operator>
            <phrase-slop>1</phrase-slop>
            <leading-wildcard>yes</leading-wildcard>
            <filter-rewrite>yes</filter-rewrite>
        </options>
    </query-option>
:)
declare function lapi:query-advanced(
    $query-options as element(query-option)+,
    $target-texts as xs:string*,
    $sortBy as xs:string*,
    $position as xs:string?
    ) {

        let $fields := $query-options/@field
        for $field in $fields
        let $query := $query-options[@field = $field]/query
        return
            switch ($field)
            case "lemma" return
                    if (exists($target-texts)) then
                        for $text in $target-texts
                        return
                            $config:data-default ! doc(. || "/LeDIIR-" || $text || ".xml")//tei:entry[not(@copyOf)][ft:query(., $query, query:options($sortBy))]
                    else
                        collection($config:data-default)//tei:entry[not(@copyOf)][ft:query(., $query, query:options($sortBy))]
            case "part-of-speech" return
                    collection($config:data-default)//tei:entry[not(@copyOf)]//tei:gram[@type='pos'][ft:query(., $query, query:options($sortBy))]
            case "pronunciation" return
                    collection($config:data-default)//tei:entry[not(@copyOf)]//tei:pron[ft:query(., $query, query:options($sortBy))]
            case "domain" return
                    collection($config:data-default)//tei:entry[not(@copyOf)]//tei:usg[@type='domain'][ft:query(., $query, query:options($sortBy))]
            default return
                    collection($config:data-default)//tei:entry[not(@copyOf)][ft:query(., $query, query:options($sortBy))]
};

declare function lapi:modify-query($query as xs:string?, $position as xs:string?) as xs:string {
        
    switch ($position)
        case "exactly"
            return $query
        case "end"
            return "*" || $query
        case "start"
            return $query || "*"
        case "everywhere"
            return "*" || $query || "*"
        default 
            return $query
};


declare function lapi:query-metadata($field as xs:string, $query as xs:string, $sort as xs:string) {
    for $rootCol in $config:data-root
    for $doc in collection($rootCol)//tei:text[ft:query(., $field || ":(" || $query || ")", query:options($sort))]
    return
        $doc/ancestor::tei:TEI
};

declare function lapi:autocomplete($request as map(*)) {
    (: rq:get-parameters-advanced($request) :)

    let $q := request:get-parameter("query", ())
    let $type := request:get-parameter("field", "entry")
    let $doc := request:get-parameter("ids", ())
    let $position := request:get-parameter("position", "start")
    let $items :=
        if ($q) then
            lapi:autocomplete($doc, $type, $q)
        else
            ()
    return
        array {
            for $item in $items
            return
                map {
                    "text": $item,
                    "value": $item
                }
        }
};

declare function lapi:facets($request as map(*)) {
     
    let $hits := session:get-attribute($config:session-prefix || ".hits")
    return if($request?parameters?format = "xml") then
    
    let $params := rq:get-all-parameters($request)
    let $f := function($k, $v) {<item value="{$k}" count="{$v}" />}
    let $facet-dimension := for $dim in $config:facets?*
        let $facets-map := ft:facets($hits, $dim?dimension, 5)
        return <dimension name="{$dim?dimension}" parameter="{request:get-parameter("facet[" || $dim?dimension || "]", ())}">
            <facet>{map:for-each($facets-map, $f)}</facet>
        </dimension>
    let $facets := <facets count="{count($config:facets?*)}">
                        <dimensions>{$facet-dimension}</dimensions>
                    </facets>
    return
        (response:set-header("Content-Type", "application/xml"),
        <result>{($params, $facets, <hits count="{count($hits)}">{$hits}</hits>)}</result>)
    
    else if(count($hits) > 0) then
    
        <div>
        {
            for $config in $config:facets?*
            return
                lfacets:display($config, $hits)
        }
        </div>
        else ()
    
};

declare function lapi:autocomplete($doc as xs:string?, $fields as xs:string+, $q as xs:string) {
    let $max-items := $config:autocomplete-max-items
    let $f := $config:autocomplete-return-values
    let $index := "lucene-index"

    let $lower-case-q := lower-case($q)
    for $field in $fields
    let $field := config:get-index-field-for-localized-values($field)
    return
        switch ($field)
            case "author" return
                collection($config:data-root)/ft:index-keys-for-field("author", $lower-case-q,
                    $f, $max-items)
            case "file" return
                collection($config:data-root)/ft:index-keys-for-field("file", $lower-case-q,
                    $f, $max-items)
            case "text" return
                if ($doc) then (
                    doc($config:data-root || "/" || $doc)/util:index-keys-by-qname(xs:QName("tei:div"), $lower-case-q,
                        $f, $max-items, $index),
                    doc($config:data-root || "/" || $doc)/util:index-keys-by-qname(xs:QName("tei:text"), $lower-case-q,
                        $f, $max-items, $index)
                ) else (
                    collection($config:data-root)/util:index-keys-by-qname(xs:QName("tei:div"), $lower-case-q,
                        $f, $max-items, $index),
                    collection($config:data-root)/util:index-keys-by-qname(xs:QName("tei:text"), $lower-case-q,
                        $f, $max-items, $index)
                )
            case "head" return
                if ($doc) then
                    doc($config:data-root || "/" || $doc)/util:index-keys-by-qname(xs:QName("tei:head"), $lower-case-q,
                        $f, $max-items, $index)
                else
                    collection($config:data-root)/util:index-keys-by-qname(xs:QName("tei:head"), $lower-case-q,
                        $f, $max-items, $index)
            
            
            case "entry" return
                if ($doc) then
                    doc($config:data-default || "/LeDIIR-" || $doc || ".xml")/util:index-keys-by-qname(xs:QName("tei:entry"), $lower-case-q,
                        $f, $max-items, $index)
                else
                    collection($config:data-default)/util:index-keys-by-qname(xs:QName("tei:entry"), $lower-case-q,
                        $f, $max-items, $index)
            case "objectLanguage"
            case "targetLanguage"
            case "definition"
            case "example"
            case "translation"
            case "headword"
            case "pronunciation"
            case "partOfSpeechAll"
            case "styleAll"
            case "domain" 
            case "reversal" 
            case "polysemy"
            case "lemma" return
                if ($doc) then
                    doc($config:data-default || "/LeDIIR-" || $doc || ".xml")/ft:index-keys-for-field($field, $lower-case-q,
                    $f, $max-items)
                else
                    collection($config:data-default)/ft:index-keys-for-field($field, $lower-case-q,
                    $f, $max-items)       
            
            
            
            default return
                collection($config:data-root)/ft:index-keys-for-field("title", $lower-case-q,
                    $f, $max-items)
};

declare function lapi:get-parent-section($node as node()) {
    ($node/self::tei:text, $node/ancestor-or-self::tei:entry[1], $node/ancestor-or-self::tei:div[1], $node)[1]
};


declare function lapi:get-breadcrumbs($config as map(*), $hit as node(), $parent-id as xs:string) {
    let $work := root($hit)/*
    let $work-title := nav:get-document-title($config, $work)/string()
    return
        <div class="breadcrumbs">
            <a class="breadcrumb" href="{$parent-id}">{$work-title}</a>
            {
                for $parentDiv in $hit/ancestor-or-self::tei:div[tei:head]
                let $id := util:node-id(
                    if ($config?view = "page") then ($parentDiv/preceding::tei:pb[1], $parentDiv)[1] else $parentDiv
                )
                return
                    <a class="breadcrumb" href="{$parent-id || "?action=search&amp;root=" || $id || "&amp;view=" || $config?view || "&amp;odd=" || $config?odd}">
                    {$parentDiv/tei:head/string()}
                    </a>
            }
        </div>
};



(:~
 : Expand the given element and highlight query matches by re-running the query
 : on it.
 :)
declare function lapi:expand($data as node()) {
    let $query := session:get-attribute($config:session-prefix || ".search")
    let $field := session:get-attribute($config:session-prefix || ".field")
    let $div :=
        if ($data instance of element(tei:pb)) then
            let $nextPage := $data/following::tei:pb[1]
            return
                if ($nextPage) then
                    if ($field = "text") then
                        (
                            ($data/ancestor::tei:div intersect $nextPage/ancestor::tei:div)[last()],
                            $data/ancestor::tei:text
                        )[1]
                    else
                        $data/ancestor::tei:text
                else
                    (: if there's only one pb in the document, it's whole
                      text part should be returned :)
                    if (count($data/ancestor::tei:text//tei:pb) = 1) then
                        ($data/ancestor::tei:text)
                    else
                      ($data/ancestor::tei:div, $data/ancestor::tei:text)[1]
        else
            $data
    let $result := lapi:query-default-view($div, $query, $field)
    let $expanded :=
        if (exists($result)) then
            util:expand($result, "add-exist-id=all")
        else
            $div
    return
        if ($data instance of element(tei:pb)) then
            $expanded//tei:pb[@exist:id = util:node-id($data)]
        else
            $expanded
};


declare %private function lapi:query-default-view($context as element()*, $query as xs:string, $fields as xs:string+) {
    for $field in $fields
    return
        switch ($field)
            case "head" return
                $context[./descendant-or-self::tei:head[ft:query(., $query, $query:QUERY_OPTIONS)]]
            default return
                $context[./descendant-or-self::tei:div[ft:query(., $query, $query:QUERY_OPTIONS)]] |
                $context[./descendant-or-self::tei:text[ft:query(., $query, $query:QUERY_OPTIONS)]]
};

declare function lapi:get-current($config as map(*), $div as node()?) {
    if (empty($div)) then
        ()
    else
        if ($div instance of element(tei:teiHeader)) then
            $div
        else
            (nav:filler($config, $div), $div)[1]
};

declare function lapi:version($request as map(*)) {
    let $format := $request?parameters?format
    let $result := if($format = "xml") then
        <api version="1.2.0" />
            else "{ 'api' : '1.2.0'}"
    return $result
};

declare function lapi:project($request as map(*)) {
    let $format := $request?parameters?format
    let $items := lapi:project-xml()
    return $items
};

declare function lapi:project-xml() {
    let $items := collection($config:metadata-default)/tei:TEI 
    let $dictionary := for $item in $items
        return <dictionary xml:id="{substring-before($item/@xml:id, '-metadata')}">
            {$item/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title}
            <contents n="{$item/tei:text/tei:body/@n}">{$item/tei:text/tei:body/tei:div}</contents>
         </dictionary>
    return <project>{$dictionary}</project>
};

declare function lapi:contents($request as map(*)) { 
    lapi:dictionary-contents($request)
};
declare function lapi:dictionary-contents($request as map(*)) {
    let $dictionaryId := $request?parameters?id
    let $chapter := $request?parameters?chapter
    let $format := $request?parameters?format

    let $dictionaryId := lapi:get-dictionary-id($dictionaryId)

    let $doc := collection($config:metadata-default)/id(concat($dictionaryId, '-metadata'))
    let $lang := ($doc/tei:TEI/tei:teiHeader/tei:profileDesc/tei:langUsage/tei:language[@role='objectLanguage']/@ident | $doc/@xml:lang)[1]
    let $items := $doc//tei:text/tei:body/tei:div[tei:head]

    let $chapter := lapi:get-chapter-id($dictionaryId, $chapter)

    let $console := if($lapi:debug) then 
        (
            console:log("[lapi:dictionary-contents] $dictionaryId:"),
            console:log($dictionaryId),
            console:log("[lapi:dictionary-contents] $chapter:"),
            console:log($chapter),
            console:log("[lapi:dictionary-contents] $lang: " || $lang)
        )
        else ()
    
    (: let $result := <div type="contents" xmlns="http://www.tei-c.org/ns/1.0"> {
        for $item in $items 
        return <div xml:id="{$item/@xml:id}">{$item/tei:head[1]}</div>
    }</div> :)
    let $result := <ul class="chapters" lang="{$lang}"> {
        for $item in $items
        let $count := $item/@n (: count($item/tei:entry) :)
        return <li class="{if($item/@subtype = $chapter) then 'chapter active' else 'chapter'}">
         <a title="{$count}" tooltip="{$count}" href="{$config:context-path}/browse.html?id={$dictionaryId}&amp;chapter={$item/@subtype}">{$item/tei:head[1]}</a>
         </li>}</ul>
    
    return $result
};


declare %private function lapi:get-lucene-query($parameter as element(parameter)*) {
  qrp:get-query-options(
    ($parameter[@name='query-advanced']/. | $parameter[@name='query']/.), 
    $parameter[@name='position']/., 
    $parameter[@name='field']/., 
    $parameter[@name='condition']/.
    )
};

declare %private function lapi:get-lucene-query-for-chapter($parameter as element(parameter)*) {
  qrp:get-query-options(
    <parameter name="query">{$parameter[@name='chapter']/value}</parameter>, 
    <parameter name="position"><value>exactly</value></parameter>, 
    <parameter name="field"><value>chapter</value></parameter>,
    ()
    )
};
declare %public function lapi:get-exist-db-query-xml($request as map(*), $sort-field as element()?) as element()* { 
    let $parameters := rq:get-all-parameters($request)
    (: let $console := console:log($parameters) :)
    let $sort := if(empty($parameters/parameter[@name='sort']/value) or $parameters/parameter[@name='sort']/value = '') 
        then ($sort-field, $lapi:default-search-sort-field)[1]
        else <sort field="{$parameters/parameter[@name='sort']/value}" />
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
    let $exist-db-query := if (empty($combined)) then () else <exist-db-query>{($combined, $facets, $sort)}</exist-db-query>
    (: return  ($parameters, <lucene>{$lucene}</lucene>, $exist-db-query) :)
    return $exist-db-query
};

declare %public function lapi:get-exist-db-query-xml($request as map(*)) as element()* {
    lapi:get-exist-db-query-xml($request, ())
};

declare %private function lapi:log-duration($query-start-time as xs:time, $message as xs:string?) {
    let $query-end-time := if($lapi:debug) then util:system-time() else ()
    let $query-duration := if($lapi:debug) then ($query-end-time - $query-start-time) div xs:dayTimeDuration('PT1S') else ()
    return if($lapi:debug) then console:log($message || " " || $query-duration) else ()
};