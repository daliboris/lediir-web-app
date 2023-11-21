(:
 Module for preparing <query> element for fulltext search.
 
 Converts query string and parameters to <query> element: 
  - qrp:query-to-element($query as xs:string?, $position as xs:string) as element(query);
  - qrp:query-to-options($query as xs:string?, $position as xs:string) as element(option);
 
 TODO: práce s mezerami a nestandardními znaky. 
 
 Converts Lucence syntax to <query> element: 
  - qrp:parse-lucene($string as xs:string);
  - qrp:create-query($query-string as xs:string?, $mode as xs:string)
  
:)
xquery version "3.1";

module namespace qrp="https://www.daliboris.cz/ns/xquery/query-parser/1.0";

declare function qrp:contains-any-of
  ( $arg as xs:string? ,
    $searchStrings as xs:string* )  as xs:boolean {

   some $searchString in $searchStrings
   satisfies contains($arg,$searchString)
 } ;

(:modified by applying qrp:escape-for-regex() :)
declare function qrp:number-of-matches 
  ( $arg as xs:string? ,
    $pattern as xs:string )  as xs:integer {
       
   count(tokenize(qrp:escape-for-regex(qrp:escape-for-regex($arg)),qrp:escape-for-regex($pattern))) - 1
 } ;

declare function qrp:escape-for-regex
  ( $arg as xs:string? )  as xs:string {

   replace($arg,
           '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
 } ;

declare variable $qrp:POSITION-START := "start";
declare variable $qrp:POSITION-END := "end";
declare variable $qrp:POSITION-EVERYWHERE := "everywhere";
declare variable $qrp:EXACTLY := "exactly";
declare variable $qrp:DOUBLE-QUOT := '&#x22;';


declare function qrp:prepare-query-string($query as xs:string?, $position as xs:string) as xs:string? {
 let $query := if($query) then
  switch($position)
  case $qrp:POSITION-END return "*" || $query
  case $qrp:POSITION-START return $query || "*"
  case $qrp:POSITION-EVERYWHERE return "*" || $query || "*"
  default return $query
  else
   $query
 return $query
};

declare function qrp:parse-text-to-tokens($text as xs:string?) as element(token)* {
 let $tokens := tokenize($text)
 for $token in $tokens
  return <token type="simple">{$token}</token>
};

declare function qrp:parse-quoted-string($query as xs:string?) as element(root)? {
 let $items := if(contains($query, $qrp:DOUBLE-QUOT)) then
   let $start := substring-before($query, $qrp:DOUBLE-QUOT)
   let $rest := substring-after($query, $qrp:DOUBLE-QUOT)
   let $quote := if(contains($rest, $qrp:DOUBLE-QUOT)) then
     substring-before($rest, $qrp:DOUBLE-QUOT)
    else 
     $rest
   let $after-quote := substring-after($rest, $qrp:DOUBLE-QUOT)
   let $end := $after-quote
   return <root>{(
    qrp:parse-text-to-tokens($start), 
    if($quote = '') then () else
    <token type="quotted">{qrp:parse-text-to-tokens($quote)}</token>, 
    qrp:parse-text-to-tokens($end))
    }</root>
  else
   <root>{<token type="simple">{$query}</token>}</root>
   
  return $items
  
};

declare function qrp:query-to-element($query as xs:string?, $position as xs:string) as element(query) {

 let $query := qrp:prepare-query-string($query, $position)
 
 let $element-name := switch ($position) 
  case $qrp:POSITION-START
  case $qrp:POSITION-END return "wildcard"
  case $qrp:POSITION-EVERYWHERE return "wildcard"
  default return "term"

 return <query>
  {
   if(contains($query, ' ')) then 
   <phrase>{$query}</phrase> 
   else element{$element-name} {$query}
   }
 </query>
};

declare function qrp:query-to-options($query as xs:string?, $position as xs:string) as element(options) {
(:
If set to no, all matching terms will be added to a single boolean query which is then executed.
This may generate a "too many clauses" exception when applied to large data sets.
Setting filter-rewrite to yes avoids those issues.
:)
let $options :=
    <options>
        <default-operator>and</default-operator>
        <phrase-slop>1</phrase-slop>
        <leading-wildcard>{if($position = ($qrp:POSITION-END, $qrp:POSITION-EVERYWHERE) or ($position = ($qrp:EXACTLY, "")  and matches($query, '^\*|\?'))) then "yes" else "no"}</leading-wildcard>
        <filter-rewrite>yes</filter-rewrite>
    </options>
 return $options
};

declare function qrp:get-query-options($query as xs:string?, $position as xs:string, 
  $field as xs:string?, $condition as xs:string?) as element(query-options) {
<query-options field="{$field}" condition="{$condition}">
  {
   (
    qrp:query-to-element($query, $position),
    qrp:query-to-options($query, $position)
   )
  }
 </query-options>
};

declare function qrp:get-query-options($query as xs:string?, $position as xs:string) as element(query-options)
{
  qrp:get-query-options($query, $position, (), ())
};

(:
 https://rvdb.wordpress.com/2010/08/04/exist-lucene-to-xml-syntax/
:)

declare function qrp:parse-lucene-regex($string as xs:string) as element(query) {
  let $text := qrp:parse-lucene-regex-impl($string)
  let $xml := parse-xml-fragment($text)
  return qrp:lucene2xml($xml/*)
};

declare function qrp:parse-lucene-regex-impl($string as xs:string) as xs:string {
  if (matches($string, '[^\\](\|{2}|&amp;{2}|!) ')) then
    let $rep := replace(replace(replace($string, '&amp;{2} ', 'AND '), '\|{2} ', 'OR '), '! ', 'NOT ')
    return qrp:parse-lucene($rep)
  else if (matches($string, '[^<](AND|OR|NOT) ')) then
    let $rep := replace($string, '(AND|OR|NOT) ', '<$1/>')
    return qrp:parse-lucene($rep)
  else if (matches($string, '(^|[^\w&#x22;&#x27;])\+[\w&#x22;&#x27;(]')) then   
    let $rep := replace($string, '(^|[^\w&#x22;&#x27;])\+([\w&#x22;&#x27;(])', '$1<AND type=_+_/>$2')
    return qrp:parse-lucene($rep)
  else if (matches($string, '(^|[^\w&#x22;&#x27;])-[\w&#x22;&#x27;(]')) then   
    let $rep := replace($string, '(^|[^\w&#x22;&#x27;])-([\w&#x22;&#x27;(])', '$1<NOT type=_-_/>$2')
    return qrp:parse-lucene($rep)
  else if (matches($string, '(^|[\W-[\\]]|>)\(.*?[^\\]\)(\^(\d+))?(<|\W|$)')) then   
    let $rep := 
      if (matches($string, '(^|\W|>)\(.*?\)(\^(\d+))(<|\W|$)')) then
        replace($string, '(^|\W|>)\((.*?)\)(\^(\d+))(<|\W|$)', '$1<bool boost=_$4_>$2</bool>$5')
      else 
        replace($string, '(^|\W|>)\((.*?)\)(<|\W|$)', '$1<bool>$2</bool>$3')
    return qrp:parse-lucene($rep)
  else if (matches($string, '(^|\W|>)(&#x22;|&#x27;).*?\2([~^]\d+)?(<|\W|$)')) then
    let $rep := 
      if (matches($string, '(^|\W|>)(&#x22;|&#x27;).*?\2([\^]\d+)?(<|\W|$)')) then 
        replace($string, '(^|\W|>)(&#x22;|&#x27;)(.*?)\2([~^](\d+))?(<|\W|$)', '$1<near boost=_$5_>$3</near>$6')
      else 
        replace($string, '(^|\W|>)(&#x22;|&#x27;)(.*?)\2([~^](\d+))?(<|\W|$)', '$1<near slop=_$5_>$3</near>$6')
    return qrp:parse-lucene($rep)
  else if (matches($string, '[\w-[<>]]+?~[\d.]*')) then
    let $rep := replace($string, '([\w-[<>]]+?)~([\d.]*)', '<fuzzy min-similarity=_$2_>$1</fuzzy>')
    return qrp:parse-lucene($rep)
  else concat('<query>', replace(normalize-space($string), '_', '"'), '</query>')
};

declare function qrp:lucene2xml($node) {
  typeswitch ($node)
    case element(query) return 
      element { node-name($node)} {
        element bool {
          $node/node()/qrp:lucene2xml(.)
        }
      }
    case element(AND) return ()
    case element(OR) return ()
    case element(NOT) return ()
    case element(bool) return
      if ($node/parent::near) then
        concat("(", $node, ")") 
      else element {node-name($node)} {
        $node/@*,
        $node/node()/qrp:lucene2xml(.)
      }
    case element() return
      let $name := if (($node/self::phrase|$node/self::near)[not(@slop > 0)]) then 'phrase' else node-name($node)
      return 
        element { $name } {
          $node/@*,
          if (($node/following-sibling::*[1]|$node/preceding-sibling::*[1])[self::AND or self::OR or self::NOT]) then
            attribute occur { 
              if ($node/preceding-sibling::*[1][self::AND]) then 'must' 
              else if ($node/preceding-sibling::*[1][self::NOT]) then 'not'
              else if ($node/following-sibling::*[1][self::AND or self::OR or self::NOT][not(@type)]) then 'should' (:'must':)
              else 'should'
            }
          else (),
          $node/node()/qrp:lucene2xml(.)
        }
    case text() return 
      if ($node/parent::*[self::query or self::bool]) then
        for $tok at $p in tokenize($node, '\s+')[normalize-space()]
        (: here is the place for further differentiation between  term / wildcard / regex elements :)
        (: currently differentiating between term and regex, based on detection of metacharacters :)
        let $el-name := if
         (matches($tok, '^[\\^0-9]*')) then 'term'
         else if
         (matches($tok, '(^|[^\\])[$^|+\p{P}-[,]](?!\d+)')) then 'regex' else 'term'                
        return element { $el-name } {
          attribute occur {
            if ($p = 1 and $node/preceding-sibling::*[1][self::AND]) then 'must'
            else if ($p = 1 and $node/preceding-sibling::*[1][self::NOT]) then 'not'
            else if ($p = 1 and $node/following-sibling::*[1][self::AND or self::OR or self::NOT][not(@type)]) then 'should' (:'must':)
            else 'should'
          },
          if (matches($tok, '(.*?)(\^(\d+))(\W|$)')) then
            attribute boost {
              replace($tok, '(.*?)(\^(\d+))(\W|$)', '$3')
            }
            else (),
          lower-case(normalize-space(replace($tok, '(.*?)(\^(\d+))(\W|$)', '$1')))
        }
      else 
        normalize-space($node)
  default return
    $node
};


(:~
    Helper function: create a lucene query from the user input
    https://gist.github.com/tonyahowe/f773ad8a53ff7a6eeea5
:)
declare %private function qrp:create-query($query-string as xs:string?, $mode as xs:string) {
    let $query-string := 
        if ($query-string) 
        then qrp:sanitize-lucene-query($query-string) 
        else ''
    let $query-string := normalize-space($query-string)
    let $query:=
        (:If the query contains any operator used in sandard lucene searches or regex searches, pass it on to the query parser;:) 
        if (qrp:contains-any-of($query-string, ('AND', 'OR', 'NOT', '+', '-', '!', '~', '^', '.', '?', '*', '|', '{','[', '(', '<', '@', '#', '&amp;')) and $mode eq 'any')
        then 
            let $luceneParse := qrp:parse-lucene($query-string)
            let $luceneXML := <query /> (:util:parse($luceneParse):)
            let $lucene2xml := qrp:lucene2xml($luceneXML/node(), $mode)
            return $lucene2xml
        (:otherwise the query is performed by selecting one of the special options (any, all, phrase, near, fuzzy, wildcard or regex):)
        else
            let $query-string := tokenize($query-string, '\s')
            let $last-item := $query-string[last()]
            let $query-string := 
                if ($last-item castable as xs:integer) 
                then string-join(subsequence($query-string, 1, count($query-string) - 1), ' ') 
                else string-join($query-string, ' ')
            let $query :=
                <query>
                    {
                        if ($mode eq 'any') 
                        then
                            for $term in tokenize($query-string, '\s')
                            return <term occur="should">{$term}</term>
                        else if ($mode eq 'all') 
                        then
                            <bool>
                            {
                                for $term in tokenize($query-string, '\s')
                                return <term occur="must">{$term}</term>
                            }
                            </bool>
                        else 
                            if ($mode eq 'phrase') 
                            then <phrase>{$query-string}</phrase>
                            else
                                if ($mode eq 'near-unordered')
                                then <near slop="{if ($last-item castable as xs:integer) then $last-item else 5}" ordered="no">{$query-string}</near>
                                else 
                                    if ($mode eq 'near-ordered')
                                    then <near slop="{if ($last-item castable as xs:integer) then $last-item else 5}" ordered="yes">{$query-string}</near>
                                    else 
                                        if ($mode eq 'fuzzy')
                                        then <fuzzy max-edits="{if ($last-item castable as xs:integer and number($last-item) < 3) then $last-item else 2}">{$query-string}</fuzzy>
                                        else 
                                            if ($mode eq 'wildcard')
                                            then <wildcard>{$query-string}</wildcard>
                                            else 
                                                if ($mode eq 'regex')
                                                then <regex>{$query-string}</regex>
                                                else ()
                    }</query>
            return $query
    return $query
    
};


(: This functions provides crude way to avoid the most common errors with paired expressions and apostrophes. :)
(: TODO: check order of pairs:)
declare %private function qrp:sanitize-lucene-query($query-string as xs:string) as xs:string {
    let $query-string := replace($query-string, "'", "''") (:escape apostrophes:)
    (:TODO: notify user if query has been modified.:)
    (:Remove colons – Lucene fields are not supported.:)
    let $query-string := translate($query-string, ":", " ")
    let $query-string := 
	   if (qrp:number-of-matches($query-string, '"') mod 2) 
	   then $query-string
	   else replace($query-string, '"', ' ') (:if there is an uneven number of quotation marks, delete all quotation marks.:)
    let $query-string := 
	   if ((qrp:number-of-matches($query-string, '\(') + qrp:number-of-matches($query-string, '\)')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '()', ' ') (:if there is an uneven number of parentheses, delete all parentheses.:)
    let $query-string := 
	   if ((qrp:number-of-matches($query-string, '\[') + qrp:number-of-matches($query-string, '\]')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '[]', ' ') (:if there is an uneven number of brackets, delete all brackets.:)
    let $query-string := 
	   if ((qrp:number-of-matches($query-string, '{') + qrp:number-of-matches($query-string, '}')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '{}', ' ') (:if there is an uneven number of braces, delete all braces.:)
    let $query-string := 
	   if ((qrp:number-of-matches($query-string, '<') + qrp:number-of-matches($query-string, '>')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '<>', ' ') (:if there is an uneven number of angle brackets, delete all angle brackets.:)
    return $query-string
};

(: Function to translate a Lucene search string to an intermediate string mimicking the XML syntax, 
with some additions for later parsing of boolean operators. The resulting intermediary XML search string will be parsed as XML with util:parse(). 
Based on Ron Van den Branden, https://rvdb.wordpress.com/2010/08/04/exist-lucene-to-xml-syntax/:)
(:TODO:
The following cases are not covered:
1)
<query><near slop="10"><first end="4">snake</first><term>fillet</term></near></query>
as opposed to
<query><near slop="10"><first end="4">fillet</first><term>snake</term></near></query>
w(..)+d, w[uiaeo]+d is not treated correctly as regex.
:)
declare %private function qrp:parse-lucene($string as xs:string) {
    (: replace all symbolic booleans with lexical counterparts :)
    if (matches($string, '[^\\](\|{2}|&amp;{2}|!) ')) 
    then
        let $rep := 
            replace(
            replace(
            replace(
                $string, 
            '&amp;{2} ', 'AND '), 
            '\|{2} ', 'OR '), 
            '! ', 'NOT ')
        return qrp:parse-lucene($rep)                
    else 
        (: replace all booleans with '<AND/>|<OR/>|<NOT/>' :)
        if (matches($string, '[^<](AND|OR|NOT) ')) 
        then
            let $rep := replace($string, '(AND|OR|NOT) ', '<$1/>')
            return qrp:parse-lucene($rep)
        else 
            (: replace all '+' modifiers in token-initial position with '<AND/>' :)
            if (matches($string, '(^|[^\w&quot;])\+[\w&quot;(]'))
            then
                let $rep := replace($string, '(^|[^\w&quot;])\+([\w&quot;(])', '$1<AND type=_+_/>$2')
                return qrp:parse-lucene($rep)
            else 
                (: replace all '-' modifiers in token-initial position with '<NOT/>' :)
                if (matches($string, '(^|[^\w&quot;])-[\w&quot;(]'))
                then
                    let $rep := replace($string, '(^|[^\w&quot;])-([\w&quot;(])', '$1<NOT type=_-_/>$2')
                    return qrp:parse-lucene($rep)
                else 
                    (: replace parentheses with '<bool></bool>' :)
                    (:NB: regex also uses parentheses!:) 
                    if (matches($string, '(^|[\W-[\\]]|>)\(.*?[^\\]\)(\^(\d+))?(<|\W|$)'))                
                    then
                        let $rep := 
                            (: add @boost attribute when string ends in ^\d :)
                            (:if (matches($string, '(^|\W|>)\(.*?\)(\^(\d+))(<|\W|$)')) 
                            then replace($string, '(^|\W|>)\((.*?)\)(\^(\d+))(<|\W|$)', '$1<bool boost=_$4_>$2</bool>$5')
                            else:) replace($string, '(^|\W|>)\((.*?)\)(<|\W|$)', '$1<bool>$2</bool>$3')
                        return qrp:parse-lucene($rep)
                    else 
                        (: replace quoted phrases with '<near slop="0"></bool>' :)
                        if (matches($string, '(^|\W|>)(&quot;).*?\2([~^]\d+)?(<|\W|$)')) 
                        then
                            let $rep := 
                                (: add @boost attribute when phrase ends in ^\d :)
                                (:if (matches($string, '(^|\W|>)(&quot;).*?\2([\^]\d+)?(<|\W|$)')) 
                                then replace($string, '(^|\W|>)(&quot;)(.*?)\2([~^](\d+))?(<|\W|$)', '$1<near boost=_$5_>$3</near>$6')
                                (\: add @slop attribute in other cases :\)
                                else:) replace($string, '(^|\W|>)(&quot;)(.*?)\2([~^](\d+))?(<|\W|$)', '$1<near slop=_$5_>$3</near>$6')
                            return qrp:parse-lucene($rep)
                        else (: wrap fuzzy search strings in '<fuzzy max-edits=""></fuzzy>' :)
                            if (matches($string, '[\w-[<>]]+?~[\d.]*')) 
                            then
                                let $rep := replace($string, '([\w-[<>]]+?)~([\d.]*)', '<fuzzy max-edits=_$2_>$1</fuzzy>')
                                return qrp:parse-lucene($rep)
                            else (: wrap resulting string in '<query></query>' :)
                                concat('<query>', replace(normalize-space($string), '_', '"'), '</query>')
};

(: Function to transform the intermediary structures in the search query generated through app:parse-lucene() and util:parse() 
to full-fledged boolean expressions employing XML query syntax. 
Based on Ron Van den Branden, https://rvdb.wordpress.com/2010/08/04/exist-lucene-to-xml-syntax/:)
declare %private function qrp:lucene2xml($node as item(), $mode as xs:string) {
    typeswitch ($node)
        case element(query) return 
            element { node-name($node)} {
            element bool {
            $node/node()/qrp:lucene2xml(., $mode)
        }
    }
    case element(AND) return ()
    case element(OR) return ()
    case element(NOT) return ()
    case element() return
        let $name := 
            if (($node/self::phrase | $node/self::near)[not(@slop > 0)]) 
            then 'phrase' 
            else node-name($node)
        return
            element { $name } {
                $node/@*,
                    if (($node/following-sibling::*[1] | $node/preceding-sibling::*[1])[self::AND or self::OR or self::NOT or self::bool])
                    then
                        attribute occur {
                            if ($node/preceding-sibling::*[1][self::AND]) 
                            then 'must'
                            else 
                                if ($node/preceding-sibling::*[1][self::NOT]) 
                                then 'not'
                                else 
                                    if ($node[self::bool]and $node/following-sibling::*[1][self::AND])
                                    then 'must'
                                    else
                                        if ($node/following-sibling::*[1][self::AND or self::OR or self::NOT][not(@type)]) 
                                        then 'should' (:must?:) 
                                        else 'should'
                        }
                    else ()
                    ,
                    $node/node()/qrp:lucene2xml(., $mode)
        }
    case text() return
        if ($node/parent::*[self::query or self::bool]) 
        then
            for $tok at $p in tokenize($node, '\s+')[normalize-space()]
            (:Here the query switches into regex mode based on whether or not characters used in regex expressions are present in $tok.:)
            (:It is not possible reliably to distinguish reliably between a wildcard search and a regex search, so switching into wildcard searches is ruled out here.:)
            (:One could also simply dispense with 'term' and use 'regex' instead - is there a speed penalty?:)
                let $el-name := 
                    if (matches($tok, '((^|[^\\])[.?*+()\[\]\\^|{}#@&amp;<>~]|\$$)') or $mode eq 'regex')
                    then 'regex'
                    else 'term'
                return 
                    element { $el-name } {
                        attribute occur {
                        (:if the term follows AND:)
                        if ($p = 1 and $node/preceding-sibling::*[1][self::AND]) 
                        then 'must'
                        else 
                            (:if the term follows NOT:)
                            if ($p = 1 and $node/preceding-sibling::*[1][self::NOT])
                            then 'not'
                            else (:if the term is preceded by AND:)
                                if ($p = 1 and $node/following-sibling::*[1][self::AND][not(@type)])
                                then 'must'
                                    (:if the term follows OR and is preceded by OR or NOT, or if it is standing on its own:)
                                else 'should'
                    }
                    (:,
                    if (matches($tok, '((^|[^\\])[.?*+()\[\]\\^|{}#@&amp;<>~]|\$$)')) 
                    then
                        (\:regex searches have to be lower-cased:\)
                        attribute boost {
                            lower-case(replace($tok, '(.*?)(\^(\d+))(\W|$)', '$3'))
                        }
                    else ():)
        ,
        (:regex searches have to be lower-cased:)
        lower-case(normalize-space(replace($tok, '(.*?)(\^(\d+))(\W|$)', '$1')))
        }
        else normalize-space($node)
    default return
        $node
};

(: 
<query-options field="headword" condition="and">
        <query>
            <term>fortress</term>
        </query>
        <options>
            <default-operator>and</default-operator>
            <phrase-slop>1</phrase-slop>
            <leading-wildcard>no</leading-wildcard>
            <filter-rewrite>yes</filter-rewrite>
        </options>
    </query-options>
:)

declare function qrp:combine-queries($items as element(query-options)*) as element(query-option)* {

  let $result := for $item in $items 
    let $field := $item/@field
    group by $field
    return <query-option field="{$field}">
     {
      qrp:merge-lucene-queries($item/query),
      qrp:merge-lucene-options($item/options)
     }
    </query-option>
  return $result
};

declare %private function qrp:merge-lucene-queries($items as element(query)*) as element(query) {
  <query>
  <bool>
  {
    for $item at $i in $items/*
    return element {node-name($item)} {
      attribute {"occur"} {"must"},
      $item/node()
    }
  }
  </bool>
  </query>
};

(:
<options>
    <default-operator>and</default-operator>
    <phrase-slop>1</phrase-slop>
    <leading-wildcard>no</leading-wildcard>
    <filter-rewrite>yes</filter-rewrite>
</options>
:)
declare %private function qrp:merge-lucene-options($items as element(options)*) as element(options) {
<options>
  {
    for $item in $items[1]/*
    return element {node-name($item)} {
      switch (local-name($item))
        case "default-operator" return if($items[default-operator[. = 'or']]) then 'or' else 'and'
        case "leading-wildcard" return if($items[leading-wildcard[. = 'yes']]) then 'yes' else 'no'
        case "filter-rewrite" return   if($items[filter-rewrite[. = 'yes']]) then 'yes' else 'no'
        default return $item/node()
    }
  }
  </options>
};