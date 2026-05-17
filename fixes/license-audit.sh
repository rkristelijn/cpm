#!/usr/bin/env bash
# fixes/license-audit.sh — Check dependency licenses for compatibility issues
set -o errexit -o nounset -o pipefail

REPO="${1:-.}"

[ -f "$REPO/package.json" ] || { echo "  ✗ No package.json"; exit 1; }
[ -d "$REPO/node_modules" ] || { echo "  ✗ No node_modules"; exit 1; }

echo "  Checking dependency licenses..."

cd "$REPO" && node -e "
const fs=require('fs'),path=require('path');
const issues=[];
const nm='./node_modules';
function check(dir){
  try{
    const p=JSON.parse(fs.readFileSync(path.join(dir,'package.json'),'utf8'));
    const l=(p.license||'UNKNOWN').toUpperCase();
    if(l.includes('UNLICENSED')||l==='UNKNOWN') issues.push('error|'+p.name+'|'+p.license);
    else if(['GPL','LGPL','AGPL'].some(c=>l.includes(c))) issues.push('warning|'+p.name+'|'+p.license);
  }catch(e){}
}
for(const e of fs.readdirSync(nm)){
  if(e.startsWith('.'))continue;
  if(e.startsWith('@')){
    for(const s of fs.readdirSync(path.join(nm,e))) check(path.join(nm,e,s));
  } else check(path.join(nm,e));
}
if(!issues.length){console.log('  ✓ All licenses permissive');process.exit(0);}
console.log('');
let err=0,warn=0;
for(const i of issues){
  const[sev,name,lic]=i.split('|');
  if(sev==='error'){console.log('  \x1b[31merror\x1b[0m    '+name.padEnd(40)+lic);err++;}
  else{console.log('  \x1b[33mwarning\x1b[0m  '+name.padEnd(40)+lic+' (copyleft)');warn++;}
}
console.log('\n  '+err+' errors, '+warn+' warnings');
"
