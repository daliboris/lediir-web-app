xquery version "3.1";

module namespace lapi="http://www.tei-c.org/tei-simple/query/tei-lex";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace map = "http://www.w3.org/2005/xpath-functions/map";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
(:import module namespace nav="http://www.tei-c.org/tei-simple/navigation/tei-lex" at "navigation-tei-lex.xql";:)
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation/tei" at "navigation-tei.xql";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "query.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace dapi="http://teipublisher.com/api/documents" at "lib/api/document.xql";
import module namespace router="http://exist-db.org/xquery/router";
import module namespace capi="http://teipublisher.com/api/collection" at "lib/api/collection.xql";
(: import module namespace facets="http://teipublisher.com/facets" at "facets.xql"; :)
import module namespace lfacets="http://www.tei-c.org/tei-simple/query/tei-lex-facets";
(:
 Semantic categories

 Implementation based on tutorial available at https://faq.teipublisher.com/api/tutorial/
:)

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
             collection($config:data-root)//id($id)
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

    let $doc := collection($config:data-root || "/dictionaries")/id($dictionaryId)
    (:
     For example, to view all articles in the collection you could pass in an empty sequence in place of the query string like this
     //db:article[ft:query(., (), map { "fields": ("title", "author") })]

     http://exist-db.org/exist/apps/doc/lucene.xml#display-facets
     Function ft:facets expects a sequence of nodes belonging to a result set obtained from one or more calls to ft:query. 
    :)
    (: let $hitsAll := for $hit in $doc//tei:entry[ft:query(., (), map { "fields": ("sortKey") } )] order by ft:field($hit, "sortKey") return $hit :)
    let $hitsAll := lapi:query-default(("entry"), "*", $dictionaryId, (), $position)
    (: let $hitsAll := for $hit in $doc//tei:entry[not(parent::tei:entry)] order by $hit/@sortKey return $hit :)
    let $hitCount := count($hitsAll)

    let $hits := if ($max-hits > 0 and $hitCount > $max-hits) 
        then subsequence($hitsAll, 1, $max-hits) 
        else $hitsAll
            (:Store the result in the session.:)
    let $store := (
        session:set-attribute($config:session-prefix || ".hits", $hitsAll),
        session:set-attribute($config:session-prefix || ".hitCount", $hitCount),
        session:set-attribute($config:session-prefix || ".query", if (empty($request?parameters?query))
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
    let $format := $request?parameters?format
    let $parts := $request?parameters?dictionaryParts
    let $entry-id := $request?parameters?entry-id

    let $hits := collection($config:data-root)//id($entry-id)
    let $hits := $hits/ancestor-or-self::tei:entry[1]

    return if($format = "xml") then 
        lapi:show-hits-xml($request, $hits, $request?parameters?id)
    else 
        lapi:show-hits-html($request, $hits, $request?parameters?id)
};

(: Dictionary entries :)
declare function lapi:browse($request as map(*)) { 
    
    let $max-hits := $config:maximum-hits-limit

    let $format := $request?parameters?format
    let $chapter := $request?parameters?chapter
    let $dictId := $request?parameters?id
    let $query := $request?parameters?query

    let $dictId := lapi:get-dictionary-id($dictId)

    let $chapter := lapi:get-chapter-id($dictId,  $chapter)
    
    (: return <request>
             <parameter name="format" value="{$format}" emtpy="{empty($format)}" />
             <parameter name="chapter" value="{$chapter}" emtpy="{empty($chapter)}"/>
             <parameter name="dictId" value="{$dictId}" emtpy="{empty($dictId)}"/>
             <parameter name="query" value="{$query}" emtpy="{empty($query)}" />
        </request> :)
    
    
    
    return
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
            let $hitsAll := lapi:browse-default($chapter, $dictId)
            let $hitCount := count($hitsAll)
            (:Store the result in the session.:)
            let $store := (
                session:set-attribute($config:session-prefix || ".hits", $hitsAll),
                session:set-attribute($config:session-prefix || ".hitCount", $hitCount),
                session:set-attribute($config:session-prefix || ".query", if (empty($query))
             then () else xmldb:decode($query)),
                session:set-attribute($config:session-prefix || ".chapter", if (empty($chapter))
             then () else xmldb:decode($chapter)),
                session:set-attribute($config:session-prefix || ".docs", $dictId)
            )

            let $hits := if ($max-hits > 0 and $hitCount > $max-hits) then subsequence($hitsAll, 1, $max-hits) else $hitsAll
            
            
            return if($format = "xml") then 
                lapi:show-hits-xml($request, $hits, $dictId, "div", "http://www.tei-c.org/ns/1.0")
            else lapi:show-hits-html($request, $hits, $dictId)
                (:lapi:show-hits($request, $hits, $request?parameters?doc):) 
            
};

(: Dictionary entries :)
declare function lapi:search($request as map(*)) {

(:
   let $params := lapi:get-parameters($request)
   return if($params) then ($params, 
   <modification>
        {lapi:modify-query($request?parameters?query, $request?parameters?position)}
    </modification>
    )
    else
    :)
    
          (:If there is no query string, fill up the map with existing values:)
    if (empty($request?parameters?query))
    then
        let $max-hits := $config:maximum-hits-limit
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
        (:The query passed to a Luecene query in ft:query is an XML element <query> containing one or two <bool>. The <bool> contain the original query and the transliterated query, as indicated by the user in $query-scripts.:)
       let $max-hits := $config:maximum-hits-limit
       let $hitsAll :=
                (:If the $query-scope is narrow, query the elements immediately below the lowest div in tei:text and the four major element below tei:teiHeader.:)
                for $hit in lapi:query-default($request?parameters?field, if (empty($request?parameters?query))
             then () else xmldb:decode($request?parameters?query), 
                tokenize($request?parameters?ids), (), 
                $request?parameters?position)
                (: sorting by @sortKey attribute using default collation :)
                order by $hit/@sortKey
                return $hit
        let $hitCount := count($hitsAll)
        (:Store the result in the session.:)
        let $store := (
            session:set-attribute($config:session-prefix || ".hits", $hitsAll),
            session:set-attribute($config:session-prefix || ".hitCount", $hitCount),
            session:set-attribute($config:session-prefix || ".query", if (empty($request?parameters?query))
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
            session:set-attribute($config:session-prefix || ".query", if (empty($request?parameters?query))
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
    let $config := ()
    return subsequence($hits, $request?parameters?start, $request?parameters?per-page)
};

declare %private function lapi:show-hits-xml($request as map(*), $hits as item()*, $docs as xs:string*, $containter as xs:string, $namespace as xs:string) {
    response:set-header("pb-total", xs:string(count($hits))),
    response:set-header("pb-start", xs:string($request?parameters?start)),
    response:set-header("pb-docs", string-join($docs, ';')),
    response:set-header( "Content-Type", "application/xml" ),
    let $config := ()
    return element {QName($namespace, $containter)} {subsequence($hits, $request?parameters?start, $request?parameters?per-page)}
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
    let $div :=
    if(empty($dictId)) then
        collection($config:data-root || "/dictionaries/")//tei:div[@type='letter'][1]
    else
        doc($config:data-root || "/dictionaries/LeDIIR-" || $dictId || ".xml")//tei:div[@type='letter'][1]
    return data($div/@n)
};

declare %private function lapi:get-dictionary-id($dictId) {
    let $dictId := $dictId[. != ''][1]
    let $dictId := if ($dictId || ""  = "") then
            lapi:get-first-dictionary()
        else
            $dictId
    return $dictId
};

declare %private function lapi:get-first-dictionary() {
    let $project := lapi:project-xml()
    return $project/dictionary[1]/@xml:id
};

declare %private function lapi:show-hits-html($request as map(*), $hits as item()*, $docs as xs:string*) {
    response:set-header("pb-total", xs:string(count($hits))),
    response:set-header("pb-start", xs:string($request?parameters?start)),
    let $config := if(empty($hits)) 
        then config:default-config(()) 
        else tpu:parse-pi(root($hits[1]), $request?parameters?view)
    return lapi:get-html(subsequence($hits, $request?parameters?start, $request?parameters?per-page), $request, $config)
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

declare function lapi:get-html($hits as item()*, $request as map(*), $config) {
    let $xml := <tei:div xmlns="http://www.tei-c.org/ns/1.0">{$hits}</tei:div>
    (: set root parameter to the root document of hits :)
    let $root := if(empty($hits)) then $xml else root($hits[1])
    let $out := $pm-config:web-transform($xml, map { "root": $root, "webcomponents": 7 }, $config?odd)
    let $styles := if (count($out) > 1) then $out[1] else ()
    return
        dapi:postprocess(($out[2], $out[1])[1], $styles, $config?odd, $request?parameters?base, $request?parameters?wc)
};

declare function lapi:browse-default($chapter as xs:string,
    $text as xs:string) {

    let $query := if(number($chapter) != xs:double('NaN')) then
         "chapterN:(" || $chapter || ")"
         else
         "letter:(" || $chapter || ")"

    return if (exists($text)) then
            doc($config:data-root || "/dictionaries/LeDIIR-" || $text || ".xml")
            //tei:entry[ft:query(., $query)][not(@copyOf)]
        else
            collection($config:data-root || "/dictionaries/")
            //tei:entry[ft:query(., $query)][not(@copyOf)]

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
                            $config:data-root ! doc(. || "/dictionaries/LeDIIR-" || $text || ".xml")//tei:entry[not(@copyOf)][ft:query(., $query, query:options($sortBy))]
                    else
                        collection($config:data-root || "/dictionaries/")//tei:entry[not(@copyOf)][ft:query(., $query, query:options($sortBy))]
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
                            $config:data-root ! doc(. || "/dictionaries/LeDIIR-" || $text || ".xml")//tei:entry[not(@copyOf)][ft:query(., $query, query:options($sortBy))]
                    else
                        collection($config:data-root || "/dictionaries/")//tei:entry[not(@copyOf)][ft:query(., $query, query:options($sortBy))]
    else ()
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
    (: lapi:get-parameters($request) :)

    let $q := request:get-parameter("query", ())
    let $type := request:get-parameter("field", "entry")
    let $doc := request:get-parameter("ids", ())
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
    
    (:
    let $f := function($k, $v) {concat('Key: ', $k, ', value: ', $v)}
    let $params := lapi:get-parameters($request)
    let $hits := session:get-attribute($config:session-prefix || ".hits")
    let $facet-dimension := for $dim in $config:facets?*
        let $facets-map := ft:facets($hits, $dim?dimension, 5)
        return <dimension name="{$dim?dimension}" parameter="{request:get-parameter("facet-" || $dim?dimension, ())}">
            <facet>{map:for-each($facets-map, $f)}</facet>
        </dimension>
    let $facets := <facets count="{count($config:facets?*)}">
                        <dimensions>{$facet-dimension}</dimensions>
                    </facets>    

    return ($params, $facets, <hits count="{count($hits)}">{count($hits)}</hits>)
:)

    
    let $hits := session:get-attribute($config:session-prefix || ".hits")
    where count($hits) > 0
    return
        <div>
        {
            for $config in $config:facets?*
            return
                lfacets:display($config, $hits)
        }
        </div>
    
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
                    doc($config:data-root || "/dictionaries/LeDIIR-" || $doc || ".xml")/util:index-keys-by-qname(xs:QName("tei:entry"), $lower-case-q,
                        $f, $max-items, $index)
                else
                    collection($config:data-root)/util:index-keys-by-qname(xs:QName("tei:entry"), $lower-case-q,
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
            case "polysemy"
            case "lemma" return
                if ($doc) then
                    doc($config:data-root || "/dictionaries/LeDIIR-" || $doc || ".xml")/ft:index-keys-for-field($field, $lower-case-q,
                    $f, $max-items)
                else
                    collection($config:data-root)/ft:index-keys-for-field($field, $lower-case-q,
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
    let $query := session:get-attribute($config:session-prefix || ".query")
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
    let $items := collection($config:data-root || "/dictionaries")/tei:TEI 
                    
    let $dictionary := for $item in $items
        return <dictionary xml:id="{$item/@xml:id}">
            <title>{$item/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title}</title>
         </dictionary>
    return <project>{$dictionary}</project>
};

declare function lapi:get-parameters($request as map(*)) {

    let $f := function($k, $v) {<parameter name="{$k}">{$v}</parameter>}

    let $items := map:for-each($request?parameters, $f)
    return <parameters>{$items}</parameters>
};
declare function lapi:contents($request as map(*)) { 
    lapi:dictionary-contents($request)
};
declare function lapi:dictionary-contents($request as map(*)) {
    let $dictionaryId := $request?parameters?id
    let $chapter := $request?parameters?chapter
    let $format := $request?parameters?format

    let $dictionaryId := lapi:get-dictionary-id($dictionaryId)

    let $doc := collection($config:data-root || "/dictionaries")/id($dictionaryId)
    let $lang := ($doc/tei:TEI/tei:teiHeader/tei:profileDesc/tei:langUsage/tei:language[@role='objectLanguage']/@ident | $doc/@xml:lang)[1]
    let $items := $doc//tei:text/tei:body/tei:div[tei:head]

    let $chapter := lapi:get-chapter-id($dictionaryId, $chapter)

    
    (: let $result := <div type="contents" xmlns="http://www.tei-c.org/ns/1.0"> {
        for $item in $items 
        return <div xml:id="{$item/@xml:id}">{$item/tei:head[1]}</div>
    }</div> :)
    let $result := <ul class="chapters" lang="{$lang}"> {
        for $item in $items
        let $count := count($item/tei:entry)
        return <li class="{if($item/@n = $chapter) then 'chapter active' else 'chapter'}">
         <a title="{$count}" tooltip="{$count}" href="browse.html?id={$dictionaryId}&amp;chapter={$item/@n}">{$item/tei:head[1]}</a>
         </li>}</ul>
    
    return $result
};
