// Acorn's ES5 mode also accepts block function declarations as an extension.
// Stock iOS 6 rejects those in strict code. Use the portable ES5 placement rule.
import {createRequire} from 'node:module';
import path from 'node:path';
const require=createRequire(path.resolve(import.meta.dirname,'../../tools/package.json'));
const acorn=require('acorn');
export function assertStockGrammar(source) {
  const ast=acorn.parse(source,{ecmaVersion:5,locations:true});
  function visit(node,parent,grandparent) {
    if(!node||typeof node.type!=='string')return;
    if(node.type==='FunctionDeclaration'&&parent?.type!=='Program'&&
       !(parent?.type==='BlockStatement'&&/Function/.test(grandparent?.type)&&grandparent.body===parent))
      throw new SyntaxError('Nonportable ES5 block function at line '+node.loc.start.line);
    for(const [key,value]of Object.entries(node)) {
      if(key==='loc')continue;
      for(const child of Array.isArray(value)?value:[value])if(child&&typeof child.type==='string')visit(child,node,parent);
    }
  }
  visit(ast);
}
