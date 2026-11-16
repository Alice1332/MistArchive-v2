// Node >=22.13；只擦除共享ArkTS文件的类型，不复制业务实现。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { stripTypeScriptTypes } from 'node:module';
import { spawnSync } from 'node:child_process';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=path.join(root,'.test-build');fs.mkdirSync(out,{recursive:true});
const base=path.join(root,'entry/src/main/ets');
const files=['model/GameModel','data/CaseData','domain/GameEngine','domain/SaveCodec','domain/InvestigationSession','data/SaveRepository','testing/CoreCases'];
for(const f of files){
  const input=fs.readFileSync(path.join(base,f+'.ets'),'utf8').replace(/^import\s+\{[^}]+\}\s+from\s+['"][^'"]*GameModel['"];?\s*$/gm,'');
  let code=stripTypeScriptTypes(input,{mode:'transform'});
  code=code.replace(/from\s+(['"])(\.\.?\/[^'"]+)\1/g,(_,q,p)=>`from ${q}${p}.mjs${q}`);
  const dest=path.join(out,f+'.mjs');fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,code);
}
const {CASES,play}=await import(pathToFileURL(path.join(out,'testing/CoreCases.mjs')));
const results=[];
for(const c of CASES){
  const t=Date.now();try{await c.run();results.push({id:c.id,category:c.category,name:c.name,pass:true,ms:Date.now()-t});console.log(`PASS ${c.id} [${c.category}] ${c.name}`);}
  catch(e){results.push({id:c.id,category:c.category,name:c.name,pass:false,error:String(e)});console.error(`FAIL ${c.id}: ${e}`);}
}
// 文件Mock：新子进程重新读取磁盘，验证业务仓库的跨进程序列化恢复。
const fixture=path.join(out,'restart-fixture.json');
fs.writeFileSync(fixture,JSON.stringify({state:play('cooperate','transfer',true,8)}));
const worker=path.join(out,'restart-worker.mjs');
fs.writeFileSync(worker,`import fs from 'node:fs';
import { SaveRepository, CURRENT } from './data/SaveRepository.mjs';
import { encode } from './domain/SaveCodec.mjs';
const f=process.argv[2],mode=process.argv[3];
const seed=JSON.parse(fs.readFileSync(f,'utf8'));
class FileStore {
 async read(k){const d=JSON.parse(fs.readFileSync(f,'utf8'));return d[k]||'';}
 async write(k,v){const d=JSON.parse(fs.readFileSync(f,'utf8'));d[k]=v;fs.writeFileSync(f,JSON.stringify(d));}
 async flush(){}
}
const r=new SaveRepository(new FileStore());
if(mode==='save'){await r.save(seed.state);console.log('WRITE events='+seed.state.events.length+' clues='+seed.state.clues.length);}
else {const x=await r.load();if(JSON.stringify(x.state)!==JSON.stringify(seed.state))throw Error('restart mismatch');console.log('READ events='+x.state.events.length+' clues='+x.state.clues.length+' source='+x.source);}`);
let restart=true;const restartLog=[];
for(const mode of ['save','load']){const r=spawnSync(process.execPath,[worker,fixture,mode],{encoding:'utf8'});restartLog.push(r.stdout.trim());console.log(r.stdout.trim());if(r.status!==0){restart=false;console.error(r.stderr);}}
const evidence=path.join(root,'evidence');fs.mkdirSync(evidence,{recursive:true});
fs.writeFileSync(path.join(evidence,'host-test-results.json'),JSON.stringify({executedAt:new Date().toISOString(),runtime:process.version,scope:'Host Node executes type-erased shared ArkTS domain and repository source; not HarmonyOS compilation or Preferences device evidence',results,restart:{pass:restart,log:restartLog}},null,2));
fs.writeFileSync(path.join(evidence,'flow-traces.json'),JSON.stringify({truth:play(),rush:play('accuse'),wrongJudgment:play('cooperate','theft')},null,2));
console.log(`RESULT ${results.filter(r=>r.pass).length}/${results.length} shared core cases; file Mock restart ${restart?'PASS':'FAIL'}`);
if(results.some(r=>!r.pass)||!restart)process.exitCode=1;
