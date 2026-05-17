#!/usr/bin/env bash
# checks/javascript/check-licenses.sh
# Check for problematic dependency licenses (UNLICENSED, copyleft)
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-licenses" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0
[ -d "$REPO/node_modules" ] || { echo "  ⊘ No node_modules (skip license check)"; exit 0; }

cd "$REPO"
node -e "
const fs=require('fs'),path=require('path');
const issues=[];
const nm='./node_modules';
function check(dir){
  try{
    const p=JSON.parse(fs.readFileSync(path.join(dir,'package.json'),'utf8'));
    const l=(p.license||'UNKNOWN').toUpperCase();
    if(l.includes('UNLICENSED')||l==='UNKNOWN') issues.push('error|'+p.name+'|'+(p.license||'UNKNOWN'));
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
let err=0,warn=0;
for(const i of issues){
  const[sev,name,lic]=i.split('|');
  if(sev==='error'){console.log('  \x1b[31merror\x1b[0m    '+name.padEnd(40)+lic);err++;}
  else{console.log('  \x1b[33mwarning\x1b[0m  '+name.padEnd(40)+lic+' (copyleft)');warn++;}
}
console.log('  '+err+' errors, '+warn+' warnings');
"
