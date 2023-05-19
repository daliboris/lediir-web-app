
xquery version "3.1";

module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config";

import module namespace pm-lediir-web="http://www.tei-c.org/pm/models/lediir/web/module" at "../transform/lediir-web-module.xql";
import module namespace pm-lediir-print="http://www.tei-c.org/pm/models/lediir/print/module" at "../transform/lediir-print-module.xql";
import module namespace pm-lediir-latex="http://www.tei-c.org/pm/models/lediir/latex/module" at "../transform/lediir-latex-module.xql";
import module namespace pm-lediir-epub="http://www.tei-c.org/pm/models/lediir/epub/module" at "../transform/lediir-epub-module.xql";
import module namespace pm-lediir-fo="http://www.tei-c.org/pm/models/lediir/fo/module" at "../transform/lediir-fo-module.xql";
import module namespace pm-docx-tei="http://www.tei-c.org/pm/models/docx/tei/module" at "../transform/docx-tei-module.xql";

declare variable $pm-config:web-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "lediir.odd" return pm-lediir-web:transform($xml, $parameters)
    default return pm-lediir-web:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:print-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "lediir.odd" return pm-lediir-print:transform($xml, $parameters)
    default return pm-lediir-print:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:latex-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "lediir.odd" return pm-lediir-latex:transform($xml, $parameters)
    default return pm-lediir-latex:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:epub-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "lediir.odd" return pm-lediir-epub:transform($xml, $parameters)
    default return pm-lediir-epub:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:fo-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "lediir.odd" return pm-lediir-fo:transform($xml, $parameters)
    default return pm-lediir-fo:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:tei-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "docx.odd" return pm-docx-tei:transform($xml, $parameters)
    default return error(QName("http://www.tei-c.org/tei-simple/pm-config", "error"), "No default ODD found for output mode tei")
            
    
};
            
    