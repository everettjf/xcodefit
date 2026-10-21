// SPDX-License-Identifier: Apache-2.0
'use strict';
const areas = {
  builds: {name:'Build products & indexes', icon:'▣', color:'blue', tag:'REBUILDABLE · INSPECT FIRST', path:'~/Library/Developer/Xcode/DerivedData/', description:'The apps, intermediate files, and source indexes your projects leave behind. Idle data can make room for the next build; rebuilding and indexing take time.', care:'Build folders containing dSYMs stay out of Standard Clean. Those symbols may be needed for a particular released build.'},
  caches: {name:'Compiler caches', icon:'≋', color:'mint', tag:'REGENERABLE · A GENTLE START', path:'~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/', description:'Reusable compilation results and modules help Xcode work faster. Cleaning them makes room, but the next build may take longer as Xcode regenerates what it needs.', care:'Standard Clean includes identified compiler caches. Files are rechecked before they move to Trash; protected locations are excluded.'},
  simulators: {name:'Simulator devices', icon:'▯', color:'peach', tag:'LOCAL TEST STATE · EXPLICIT CHOICE', path:'~/Library/Developer/CoreSimulator/Devices/', description:'Your virtual devices carry apps, sandboxes, databases, and settings. Their size includes local test state, not just disposable operating-system files.', care:'Deep Clean offers supported simulator removal through Apple’s simctl. This permanently discards local test data and needs an extra acknowledgment.'},
  archives: {name:'Release archives & dSYMs', icon:'▤', color:'violet', tag:'RELEASE HISTORY · KEEP WITH CARE', path:'~/Library/Developer/Xcode/Archives/', description:'Each distributed build needs its own matching symbols for crash analysis. XcodeFit shows product and symbol sizes, checks UUID matches, and groups archives by app, platform, and signing team.', care:'Keep the latest 1, 3, or 5 versions with every build, or explicitly select all unprotected archives. Unknown versions stay under retention rules. A newer dSYM cannot replace an older one.'}
};
const tabs = [...document.querySelectorAll('[data-report-part]')];
function selectArea(key, moveFocus=false) {
  const area=areas[key]; if(!area)return;
  document.querySelectorAll('[data-part]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.part===key)));
  tabs.forEach(tab=>{const selected=tab.dataset.reportPart===key;tab.setAttribute('aria-selected',String(selected));tab.tabIndex=selected?0:-1;if(selected&&moveFocus)tab.focus();});
  ['name','tag','path','description','care'].forEach(field=>{document.getElementById(`detail-${field}`).textContent=area[field];});
  const icon=document.getElementById('detail-icon');icon.className=`part-symbol ${area.color}`;icon.textContent=area.icon;
  document.getElementById('part-detail').setAttribute('aria-labelledby',`tab-${key}`);
}
document.querySelectorAll('[data-part]').forEach(button=>button.addEventListener('click',()=>selectArea(button.dataset.part)));
tabs.forEach((tab,index)=>{
 tab.addEventListener('click',()=>selectArea(tab.dataset.reportPart));
 tab.addEventListener('keydown',event=>{let next;if(event.key==='ArrowRight')next=(index+1)%tabs.length;if(event.key==='ArrowLeft')next=(index+tabs.length-1)%tabs.length;if(event.key==='Home')next=0;if(event.key==='End')next=tabs.length-1;if(next!==undefined){event.preventDefault();selectArea(tabs[next].dataset.reportPart,true);}});
});
let checkupRunning=false;
document.getElementById('start-checkup').addEventListener('click',()=>{
 if(checkupRunning)return;checkupRunning=true;
 const scene=document.querySelector('.checkup-scene');const status=document.getElementById('scan-status');const trigger=document.getElementById('start-checkup');
 scene.classList.add('is-scanning');trigger.disabled=true;status.textContent='Checking the example storage areas…';
 const reduce=window.matchMedia('(prefers-reduced-motion: reduce)').matches;
 setTimeout(()=>{scene.classList.remove('is-scanning');checkupRunning=false;trigger.disabled=false;selectArea('builds');status.textContent='Example fitness scan ready. Your real files stay untouched.';document.getElementById('checkup').scrollIntoView({behavior:reduce?'auto':'smooth',block:'start'});document.getElementById('part-detail').focus({preventScroll:true});},reduce?100:2700);
});
document.getElementById('copy-command').addEventListener('click',async()=>{
 const status=document.getElementById('copy-status');
 try{await navigator.clipboard.writeText(document.getElementById('install-command').textContent);status.textContent='Copied. Paste into Terminal to install XcodeFit.';}
 catch{status.textContent='Select and copy the command above.';}
});
