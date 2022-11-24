
xquery version "3.1";

module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config";

import module namespace pm-LeDIIR-web="http://www.tei-c.org/pm/models/LeDIIR/web/module" at "../transform/LeDIIR-web-module.xql";
import module namespace pm-LeDIIR-print="http://www.tei-c.org/pm/models/LeDIIR/fo/module" at "../transform/LeDIIR-print-module.xql";
import module namespace pm-LeDIIR-latex="http://www.tei-c.org/pm/models/LeDIIR/latex/module" at "../transform/LeDIIR-latex-module.xql";
import module namespace pm-LeDIIR-epub="http://www.tei-c.org/pm/models/LeDIIR/epub/module" at "../transform/LeDIIR-epub-module.xql";
import module namespace pm-docx-tei="http://www.tei-c.org/pm/models/docx/tei/module" at "../transform/docx-tei-module.xql";

declare variable $pm-config:web-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "LeDIIR.odd" return pm-LeDIIR-web:transform($xml, $parameters)
    default return pm-LeDIIR-web:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:print-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "LeDIIR.odd" return pm-LeDIIR-print:transform($xml, $parameters)
    default return pm-LeDIIR-print:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:latex-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "LeDIIR.odd" return pm-LeDIIR-latex:transform($xml, $parameters)
    default return pm-LeDIIR-latex:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:epub-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "LeDIIR.odd" return pm-LeDIIR-epub:transform($xml, $parameters)
    default return pm-LeDIIR-epub:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:tei-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "docx.odd" return pm-docx-tei:transform($xml, $parameters)
    default return error(QName("http://www.tei-c.org/tei-simple/pm-config", "error"), "No default ODD found for output mode tei")
            
    
};
            
    