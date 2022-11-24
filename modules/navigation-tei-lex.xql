xquery version "3.1";

module namespace nav="http://www.tei-c.org/tei-simple/navigation/tei-lex";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace nav-tei="http://www.tei-c.org/tei-simple/navigation/tei";


(:~
 : By-division view:
 : Return additional content to fill up a parent division which otherwise would not have
 : enough text to show. By default adds the first subdivision.
 :)
declare function nav:filler($config as map(*), $div) {
    let $child := $div/tei:div[1]
    return
        if ($config?fill > 0 and $child and count(($child)/preceding-sibling::*/descendant-or-self::*) < $config?fill) then
            $child
        else
            ()
};

(:~
 : By-division view: get the top fragment to display for the division. If the division is on a level
 : above the configured max depth, sub-divisions will be shown on their own page - except if the
 : content before the first child division is less than the number of elements configured for the
 : fill parameter. In this case, the first sub-division will be shown together with its parent.
 :)
declare function nav:fill-entries($config as map(*), $div) {
    if ($div/tei:div and $config?fill > 0 and count($div/ancestor-or-self::tei:div) < $config?depth) then
        let $filler := nav:filler($config, $div)
        return
            if ($filler) then
                element { node-name($div) } {
                    $div/@* except $div/@exist:id,
                    attribute exist:id { util:node-id($div) },
                    util:expand(($filler/preceding-sibling::node(), $filler), "add-exist-id=all")
                }
            else
                element { node-name($div) } {
                    $div/@* except $div/@exist:id,
                    attribute exist:id { util:node-id($div) },
                    util:expand($div/tei:div[1]/preceding-sibling::*, "add-exist-id=all")
                }
    else
        $div
};


declare function nav:get-content($config as map(*), $div as element()) {
    typeswitch ($div)
    case element(tei:div) return
            nav-tei:fill($config, $div)
        case element(tei:entry)
            return nav:fill-entries($config, $div)
        default return nav-tei:get-content($config, $div)
};

(:~
 : By-division view: compute and return the next division to show in sequence.
 :)
declare function nav:next-page($config as map(*), $div) {
    let $filled := nav:filler($config, $div)
    return
        if ($filled) then
            $filled/following::tei:div[1]
        else
            (
                $div/descendant::tei:div[count(ancestor-or-self::tei:div) <= $config?depth],
                $div/following::tei:div[count(ancestor-or-self::tei:div) <= $config?depth]
            )[1]
};

(:~
 : By-division view: compute and return the previous division to show in sequence.
 :)
declare function nav:previous-page($config as map(*), $div) {
    let $preceding := $div/preceding::tei:div[count(ancestor-or-self::tei:div) <= $config?depth][1]
    let $parent := $div/ancestor::tei:div[1]
    let $previous := if ($preceding << $parent) then $parent else $preceding
    return
        if ($previous) then
            (: Check if the section would be displayed together with any of its ancestors.
             : For this we need to traverse the tree upwards and check each ancestor.
             :)
            let $nearest := filter(
                $previous/ancestor-or-self::tei:div[count(ancestor-or-self::tei:div) <= $config?depth], 
                function($ancestor) {
                    exists(nav:filler($config, $ancestor)/descendant-or-self::tei:div[. is $previous])
                }
            )
            return
                if ($nearest) then
                    $nearest
                else
                    $previous
        else
            $div/ancestor::tei:div[1]
};

declare function nav:get-next($config as map(*), $div as element(), $view as xs:string) {
    let $next :=
        switch ($view)
            case "page" return
                $div/following::tei:pb[1]
            case "body" return
                ($div/following-sibling::*, $div/../following-sibling::*)[1]
            default return
                nav:next-page($config, $div)
    return
        if (empty($config?context) or $config?context instance of document-node() or $next/ancestor::*[. is $config?context]) then
            $next
        else
            ()
};

declare function nav:get-previous($config as map(*), $div as element(), $view as xs:string) {
    let $previous :=
        switch ($view)
            case "page" return
                $div/preceding::tei:pb[1]
            case "body" return
                ($div/preceding-sibling::*, $div/../preceding-sibling::*)[1]
            default return
                nav:previous-page($config, $div)
    return
        if ($config?context instance of document-node() or $previous/ancestor::*[. is $config?context]) then
            $previous
        else
            ()
};
