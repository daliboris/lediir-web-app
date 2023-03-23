xquery version "3.1";

module namespace idx="http://teipublisher.com/index";

declare namespace array = "http://www.w3.org/2005/xpath-functions/array";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace dbk="http://docbook.org/ns/docbook";

declare variable $idx:app-root :=
    let $rawPath := system:get-module-load-path()
    return
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    ;

(:~
 : Helper function called from collection.xconf to create index fields and facets.
 : This module needs to be loaded before collection.xconf starts indexing documents
 : and therefore should reside in the root of the app.
 :)
declare function idx:get-metadata($root as element(), $field as xs:string) {
    let $header := $root/tei:teiHeader
    return
        switch ($field)
            case "title" return
                string-join((
                    $header//tei:msDesc/tei:head, $header//tei:titleStmt/tei:title[@type = 'main'],
                    $header//tei:titleStmt/tei:title,
                    $root/dbk:info/dbk:title
                ), " - ")
            case "author" return (
                $header//tei:correspDesc/tei:correspAction/tei:persName,
                $header//tei:titleStmt/tei:author,
                $root/dbk:info/dbk:author
            )
            case "language" return
                head((
                    $header//tei:langUsage/tei:language[@role='objectLanguage']/@ident,
                    $root/@xml:lang,
                    $header/@xml:lang
                ))
            case "date" return head((
                $header//tei:correspDesc/tei:correspAction/tei:date/@when,
                $header//tei:sourceDesc/(tei:bibl|tei:biblFull)/tei:publicationStmt/tei:date,
                $header//tei:sourceDesc/(tei:bibl|tei:biblFull)/tei:date/@when,
                $header//tei:fileDesc/tei:editionStmt/tei:edition/tei:date,
                $header//tei:publicationStmt/tei:date
            ))
            case "sortKey" return if($root/@sortKey) 
              then $root/@sortKey 
              else $root//tei:form[@type=('lemma', 'variant')][1]/tei:orth[1]
              
            case "letter" return $root/ancestor-or-self::tei:div[@type='letter']/tei:head[@type='letter']
            case "chapterId" return $root/ancestor-or-self::tei:div[1]/@xml:id
            case "chapter" return $root/ancestor-or-self::tei:div[@type='letter']/@n
            case "lemma" return $root//tei:form[@type=('lemma', 'variant')]/tei:orth
            case "headword" return $root//(tei:form[@type=('lemma', 'variant')]/tei:orth | tei:ref[@type='reversal'] | tei:form[@type=('lemma', 'variant')]/tei:pron)
            case "object-language" return idx:get-object-language($root)
            case "target-language" return idx:get-target-language($root)
            case "definition" return $root//tei:sense//tei:def
            case "example" return $root//tei:sense//tei:cit[@type='example']/tei:quote
            case "translation" return $root//tei:sense//tei:cit[@type='example']/tei:cit[@type='translation']/tei:quote
            case "partOfSpeech" return $root//tei:gram[@type='pos']
            case "partOfSpeechAll" return idx:get-pos($root)
            case "pronunciation" return $root//tei:form[@type=('lemma', 'variant')]/tei:pron
            case "reversal" return $root//tei:xr[@type='related' and @subtype='Reversals']/tei:ref[@xml:lang=('en', 'cs-CZ')]
            case "domain" return idx:get-domain($root)
            case "domainHierarchy" return idx:get-domain-hierarchy($root)
            case "style" return $root//tei:usg[@type='textType']
            case "styleAll" return idx:get-style($root)
            case "category-idno" return $root/tei:idno
            case "category-term" return $root/tei:term
            case "polysemy" return count($root//tei:sense)
            case "frequency" return $root//tei:usg[@type='frequency']/@value
            case "complexFormType" return idx:get-complex-form-type($root)
            default return
                ()
};
declare function idx:get-domain-hierarchy($entry as element()?) { 
if (empty($entry)) then ()
else
let $root := root($entry)
let $targets := $entry//tei:usg[@type='domain']
let $ids := if (empty($targets)) then () 
    else $targets/substring-after(@ana, '#')

return if (empty($ids)) 
            then ()
            else
            idx:get-hierarchical-descriptor($ids, $root)
};

(:~
 : Helper functions for hierarchical facets with several occurrences in a single document of the same vocabulary
 :)
declare function idx:get-hierarchical-descriptor($keys as xs:string*, $root as item()) {
  array:for-each (array {$keys}, function($key) {
        id($key,$root)
        /ancestor-or-self::tei:category/tei:catDesc[@xml:lang='en']/concat(tei:idno, ' ', tei:term)
    })
};

declare function idx:get-domain($entry as element()?) {
    for $target in $entry//tei:usg[@type='domain']
    return $target/concat(tei:idno, ' ', tei:term)
    (:
    for $target in $entry//tei:usg[@type='domain']/@ana
    let $category := id(substring($target, 2), root($entry))
    return
       $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc[@xml:lang='en']/concat(tei:idno, ' ', tei:term)
    :)
    
};

declare function idx:get-complex-form-type($entry as element()?) {
    idx:get-values-from-terminology($entry, $entry//tei:entry[@type='complexForm'][contains(@ana, 'complexFormType')]/@ana)
    (:
    for $target in $entry//tei:ref[@type='entry'][contains(@ana, 'complexFormType')]/@ana
        let $category := id(substring($target, 2), root($entry))
    return $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term) 
    :)
};


declare function idx:get-style($entry as element()?) {
    idx:get-values-from-terminology($entry, $entry//tei:usg[@type='textType']/@ana)
    (:
    for $target in $entry//tei:usg[@type='textType']/@ana
        let $category := id(substring($target, 2), root($entry))
    return $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term)
    :)
};

declare function idx:get-pos($entry as element()?) {
    idx:get-values-from-terminology($entry, $entry//tei:gram/@ana)
    (:
    let $category := id(substring($target, 2), root($entry))
    return
        $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term)
    :)
};

declare function idx:get-values-from-terminology($entry as element()?, $targets as item()*) {
    for $target in $targets
    let $category := id(substring($target, 2), root($entry))
    return
        $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term)
};


declare function idx:get-object-language($entry as element()?) {
    for $target in $entry//tei:form[@type=('lemma', 'variant')]/tei:orth[@xml:lang]
    let $category := $target/@xml:lang
    return
        $category
};

declare function idx:get-target-language($entry as element()?) {
    for $target in $entry//(tei:def | tei:cit[@type='translation'])
    let $category := $target/@xml:lang
    return
        $category
};