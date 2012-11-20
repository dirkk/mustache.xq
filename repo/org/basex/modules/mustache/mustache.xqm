(:
  mustache.xq — Logic-less templates in XQuery
  See http://mustache.github.com/ for more info.
:)
xquery version "3.0" ;

module namespace mustache = "http://basex.org/modules/mustache/mustache";

import module namespace parser = "http://basex.org/modules/mustache/parser";
import module namespace compiler = "http://basex.org/modules/mustache/compiler";

declare function mustache:render( $template, $json ) {
  mustache:compile( mustache:parse( $template ), $json ) } ;

declare function mustache:parse( $template ) {
  parser:parse( $template) } ;

declare function mustache:compile($parseTree, $json) {
  compiler:compile( $parseTree, $json ) } ;
