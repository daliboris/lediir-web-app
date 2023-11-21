(:
 :
 :  Copyright (C) 2019 Wolfgang Meier
 :
 :  This program is free software: you can redistribute it and/or modify
 :  it under the terms of the GNU General Public License as published by
 :  the Free Software Foundation, either version 3 of the License, or
 :  (at your option) any later version.
 :
 :  This program is distributed in the hope that it will be useful,
 :  but WITHOUT ANY WARRANTY; without even the implied warranty of
 :  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 :  GNU General Public License for more details.
 :
 :  You should have received a copy of the GNU General Public License
 :  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :)
xquery version "3.1";

module namespace facets="http://www.tei-c.org/tei-simple/query/tei-lex-facets";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function facets:sort($facets as map(*)?) {
    array {
        if (exists($facets)) then
            for $key in map:keys($facets)
            let $value := map:get($facets, $key)
            order by $key ascending
            return
                map { $key: $value }
        else
            ()
    }
};

declare function facets:print-table($config as map(*), $nodes as element()+, $values as xs:string*, $params as xs:string*) {
    let $all := request:get-parameter("all-" || $config?dimension, ())
    let $count := if ($all) then 100 else $config?max
    let $paths := if(exists($values)) then 
            distinct-values(for $i in $values return  tokenize($i, "\|"))
        else
            ()
    let $facets :=
        if ($all) then 
            if (exists($values)) then
                ft:facets($nodes, $config?dimension, (), $values)
            else
                ft:facets($nodes, $config?dimension, ())
        else 
            if (exists($values)) then
                ft:facets($nodes, $config?dimension, $count, $values)
            else
                ft:facets($nodes, $config?dimension, $count)
    return
        if (map:size($facets) > 0) then
            <table>
            {
                array:for-each(facets:sort($facets), function($entry) {
                    map:for-each($entry, function($label, $freq) {
                        let $value := if(exists($values)) then 
                            concat(string-join($values, '|'), '|', $label)
                        else $label
                        return
                        <tr>
                            <td>
                                <paper-checkbox class="facet" name="facet[{$config?dimension}]" value="{$label}">
                                    { if ($label = $params) then attribute checked { "checked" } else () }
                                    {
                                        if (exists($config?output)) then
                                            $config?output($label)
                                        else
                                            $label
                                    }
                                </paper-checkbox>
                                <!--
                                <br />values: {$values}
                                <br />value: {$value}
                                <br />params: {string-join($params, "~")}
                                <br />paths: {string-join($paths, "~")}
                                <br />label: {$value}
                                <br />head: {head($params)}
                                -->
                            </td>
                            <td>{$freq}</td>
                        </tr>,
                        if (empty($params)) then
                            ()
                        else
                            if(head($params) ne $label) then () 
                            else
                            let $new-params := ($values, head($params))
                            (: let $new-params := head($params) :)
                            let $nested := facets:print-table($config, $nodes, $new-params, tail($params))
                            return
                                if ($nested) then
                                    <tr class="nested">
                                        <td colspan="2">
                                        {$nested}
                                        </td>
                                    </tr>
                                else
                                    ()
                            })
                })
            }
            </table>
        else
            ()
};

declare function facets:display($config as map(*), $nodes as element()+) {
    let $params := request:get-parameter("facet[" || $config?dimension || "]", ())
    let $table := facets:print-table($config, $nodes, (), $params)

    let $maxcount := 100
    (: maximum number shown :)
    let $max := head(($config?max, 100))

    (: facet count for current values selected :)
    let $fcount :=
    map:size(
     if (count($params)) then
            ft:facets($nodes, $config?dimension, $maxcount, $params)
        else
            ft:facets($nodes, $config?dimension, $maxcount)
    )

    where $table
    return
        <div>
            <h3><pb-i18n key="{$config?heading}">{$config?heading}</pb-i18n>
            {
                if ($fcount > $max) then
                    <paper-checkbox class="facet" name="all-{$config?dimension}">
                        { if (request:get-parameter("all-" || $config?dimension, ())) then attribute checked { "checked" } else () }
                        <pb-i18n key="app.facets.show-all">Show all</pb-i18n> ({$fcount})
                    </paper-checkbox>
                else
                    ()
            }
            </h3>
            <div class="facet-block">
            {
                $table
            }
            </div>
        </div>
};

declare function facets:infoPopover($label) {
    <pb-popover theme="light">
        <span slot="default"><iron-icon icon="info" style="color: gray;"/></span>
            <template slot="alternate">
                <pb-i18n key="info.{$label}"/>
            </template>
    </pb-popover>
};
