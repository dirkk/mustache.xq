(:
  mustache.xq — Logic-less templates in XQuery
  See http://mustache.github.com/ for more info.
:)
xquery version "3.0" ;

module namespace mustache = "http://basex.org/modules/mustache/mustache";

import module namespace parser = "http://basex.org/modules/mustache/parser";
import module namespace compiler = "http://basex.org/modules/mustache/compiler";

declare function mustache:render(
  $template as xs:string,
  $json as xs:string) as element()
{
  mustache:compile(mustache:parse($template), $json)
};

declare function mustache:parse($template as xs:string) as element()
{
  parser:parse($template)
};

declare function mustache:compile(
  $parseTree as element(),
  $json as xs:string) as element()
{
  compiler:compile($parseTree, $json)
};
