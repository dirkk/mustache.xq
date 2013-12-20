(:
  XQuery Generator for mustache
:)
xquery version "3.0" ;
module namespace compiler = "http://basex.org/modules/mustache/compiler";

import module namespace parser = "http://basex.org/modules/mustache/parser";

declare function compiler:compile(
  $parseTree as element(),
  $json as xs:string) as node()
{
  let $div := parse-xml(concat('&lt;div&gt;', string-join(
    compiler:compile-xpath($parseTree, json:parse($json)/*), ''), '&lt;/div&gt;'))
  return compiler:handle-escaping($div)
};

declare function compiler:compile-xpath(
  $parseTree as element(),
  $json as element(json)) as item()*
{
  compiler:compile-xpath($parseTree, $json, 1, '')
}; 

declare function compiler:compile-xpath(
  $parseTree as element(),
  $json as element(json),
  $pos as xs:integer,
  $xpath as xs:string) as item()*
{
  for $node in $parseTree/node() 
  return compiler:compile-node($node, $json, $pos, $xpath)
};

declare function compiler:compile-node(
  $node as element(),
  $json as element(json),
  $pos as xs:integer,
  $xpath as xs:string) as item()*
{
  typeswitch($node)
    case element(etag) return compiler:eval($node/@name, $json, $pos, $xpath)
    case element(utag) return compiler:eval($node/@name, $json, $pos, $xpath,
      false())
    case element(rtag) return string-join(compiler:eval( $node/@name, $json,
      $pos, $xpath, true(), 'desc'), " ")
    case element(static) return $node/string()
    case element(partial) return compiler:compile-xpath(parser:parse(
      file:read-text($node/@name)), $json, $pos, $xpath)
    case element(comment) return ()
    case element(inverted-section) return
      let $sNode := compiler:unpath(string($node/@name), $json, $pos, $xpath)
      return 
        if ($sNode/@boolean = "true" or (not(empty(
          tokenize($json/@booleans, '\s')[.=$node/@name])) and
            $sNode/text() = "true" ))
        then ()
        else if ($sNode/@type = "array" or (not(empty(
          tokenize($json/@arrays, '\s')[.=$node/@name]))))
             then if (exists($sNode/node())) 
                  then () 
                  else compiler:compile-xpath($node, $json)
             else compiler:compile-xpath($node, $json)
    case element(section) return
      let $sNode := compiler:unpath(string($node/@name), $json, $pos, $xpath)
      return 
        if ($sNode/@boolean = "true" or ($sNode/@type = "boolean" and $sNode = "true") or (not(empty(
          tokenize($json/@booleans, '\s')[.=$node/@name])) and
            $sNode/text() = "true"))
        then compiler:compile-xpath($node, $json, $pos, $xpath)
        else
          if ($sNode/@type = "array" or (not(empty(
            tokenize($json/@arrays, '\s')[.=$node/@name]))))
          then (for $n at $p in $sNode/node()
                return compiler:compile-xpath($node, $json, $p,
                         concat($xpath, '/', node-name($sNode), '/value')))
          else if($sNode/@type = "object" or (not(empty(
                  tokenize($json/@objects, '\s')[.=$node/@name]))))
               then compiler:compile-xpath($node, $json, $pos,
                      concat( $xpath,'/', node-name($sNode)))
               else ()
    case text() return $node
    default return compiler:compile-xpath( $node, $json )
};

declare function compiler:eval(
  $node-name as xs:string,
  $json as element(json),
  $pos as xs:integer) as item()*
{ 
  compiler:eval($node-name, $json, $pos, '', true())
};
      
declare function compiler:eval(
  $node-name as xs:string,
  $json as element(json),
  $pos as xs:integer,
  $xpath as xs:string) as item()*
{ 
  compiler:eval($node-name, $json, $pos, $xpath, true())
};
      
declare function compiler:eval(
  $node-name as xs:string,
  $json as element(json),
  $pos as xs:integer,
  $xpath as xs:string,
  $etag as xs:boolean) as item()*
{ 
  compiler:eval($node-name, $json, $pos, $xpath, $etag, '')
};
      
declare function compiler:eval(
  $node-name as xs:string,
  $json as element(json),
  $pos as xs:integer,
  $xpath as xs:string,
  $etag as xs:boolean,
  $desc as xs:string) as item()*
{
  let $unpath := compiler:unpath($node-name, $json, $pos, $xpath, $desc)
  return try {
    let $value := string($unpath)
    return
      if ($etag) 
      then '{{b64:' || Q{java:org.basex.util.Base64}encode($value) || '}}'
      else $value
  } catch * { $unpath }
};

declare function compiler:unpath(
  $node-name as xs:string,
  $json as element(json),
  $pos as xs:integer,
  $xpath as xs:string) as item()*
{ 
  compiler:unpath( $node-name, $json, $pos, $xpath, '' )
};

declare function compiler:unpath(
  $node-name as xs:string,
  $json as element(json),
  $pos as xs:integer,
  $xpath as xs:string,
  $desc as xs:string) as item()*
{ 
  let $xp := 'declare variable $json external;' ||
             '$json' || $xpath || '[' || $pos || ']/' ||
             (if ($desc='desc') then '/' else '') || $node-name
  return xquery:eval($xp, { '$json' : $json })
};

declare function compiler:handle-escaping($div as node()*) as item()*
{
  for $n in $div/node()
  return compiler:handle-base64($n)
};

declare function compiler:handle-base64($node) as item()*
{
  typeswitch($node)
    case element() return
      element {node-name($node)} {
        for $a in $node/@*
        return attribute {node-name($a)} {compiler:resolve-mustache-base64($a)},
        compiler:handle-escaping($node)
      }
    case text() return compiler:resolve-mustache-base64($node)
    default return compiler:handle-escaping($node)
};

declare function compiler:resolve-mustache-base64($text as xs:string) as xs:string
{
  string-join(
    for $token in tokenize($text, " ")
    return 
      if (matches($token, '\{\{b64:(.+?)\}\}'))
      then 
        let $as := analyze-string($token, '\{\{b64:(.+?)\}\}')
        let $b64 := $as//*:group[@nr=1]
        let $before := $as/*:match[1]/preceding::*:non-match[1]/string()
        let $after := $as/*:match[last()]/following::*:non-match[1]/string()
        return
          string-join(($before, 
            for $b64-single in $b64 
            let $decoded := Q{java:org.basex.util.base64}decode( string($b64-single) )
            let $executed := 
              if (matches($decoded, "(&lt;|&gt;|&amp;|&quot;|&apos;)"))
              then string($decoded)
              else string(try { xquery:eval($decoded) } catch * { $decoded })
            return $executed, $after
          ), '' )
      else if (matches($token, '\{\{b64:\}\}'))
      then ""
      else $token, " ")
};
