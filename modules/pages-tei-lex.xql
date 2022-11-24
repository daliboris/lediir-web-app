xquery version "3.1";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";

(:~
 : Template functions to handle page by page navigation and display
 : pages using TEI Simple.
 :)
module namespace lpages="http://www.tei-c.org/tei-simple/pages/tei-lex";

declare 
    %templates:wrap
function lpages:search-fields($form-id as string, $node as node(), $model as map(*)) {
    let $main-section := "search"
    let $json := json-doc($config:app-root || "/resources/i18n/seach.json")
    let $form-id := if(empty($form-id)) then "advanced" else $form-id 
    let $form := $json?forms($form-id)
    let $label := $form("label")
    let $fields := $form("fields")

   return
        <paper-dropdown-menu id="{$label}" part="field-dropdown" data-i18n="[label]{$main-section}.labels.field" aria-disabled="false" dir="null">
        <paper-listbox id="{$label}-list" slot="dropdown-content" class="dropdown-content" attr-for-selected="value" aria-expanded="false" role="listbox" tabindex="0">
        {
        map:for-each($fields, function($key, $value) {
            <paper-item value="{$key}"><pb-i18n key="{$main-section}.fields.{$key}">{$value}</pb-i18n></paper-item>
        })
        }
        </paper-listbox>
        </paper-dropdown-menu>
};