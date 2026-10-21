import {readFile,readdir,stat} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import assert from 'node:assert/strict';
import {validateManifest,validateDevelopmentDownload} from '../packages/release-manifest/validate.mjs';
const root=resolve(process.argv[2]??'apps/web/dist');
async function files(dir){const out=[];for(const e of await readdir(dir,{withFileTypes:true})){const p=join(dir,e.name);out.push(...(e.isDirectory()?await files(p):[p]));}return out;}
let count=0;
for(const p of(await files(root)).filter(p=>p.endsWith('.html'))){
const html=await readFile(p,'utf8');assert.match(html,/<html[^>]+lang="es"/);assert.match(html,/<title>[^<]+<\/title>/);assert.match(html,/<meta[^>]+name="viewport"/);
for(const m of html.matchAll(/(?:href|src)="([^"#?]+)(?:[?#][^"]*)?"/g)){const u=m[1];if(/^(https?:|data:|mailto:)/.test(u))continue;let target=u.startsWith('/')?join(root,u):resolve(p,'..',u);try{if((await stat(target)).isDirectory())target=join(target,'index.html');await stat(target);}catch{throw Error(`${p}: broken link ${u}`);}}count++;
}
validateManifest({schemaVersion:1,channel:'stable',release:null});
assert.throws(()=>validateManifest({schemaVersion:1,channel:'beta',release:null}));
assert.throws(()=>validateManifest({schemaVersion:1,channel:'stable',release:{version:'fake'}}));
validateManifest(JSON.parse(await readFile(new URL('../packages/release-manifest/stable.json',import.meta.url),'utf8')));
console.log(`${count} HTML pages: local links, language, titles, viewport and manifest checks passed.`);

const development=JSON.parse(await readFile(new URL('../packages/release-manifest/development.json',import.meta.url),'utf8'));
const dev=validateDevelopmentDownload(development).download;
assert.throws(()=>validateDevelopmentDownload({...development,download:{...dev,notarized:true}}));
assert.throws(()=>validateDevelopmentDownload({...development,download:{...dev,installerPath:'/downloads/../bad.dmg'}}));
assert.throws(()=>validateDevelopmentDownload({...development,download:{...dev,sha256:'bad'}}));
const downloadPage=await readFile(join(root,'descarga/index.html'),'utf8');
assert.ok(downloadPage.includes(dev.installerPath) && downloadPage.includes('download') && downloadPage.includes(dev.sha256));
assert.equal((await stat(join(root,dev.installerPath))).size,dev.size);
console.log('Development download schema, artifact size and page link checks passed.');

const coverage=JSON.parse(await readFile(new URL('../packages/release-manifest/image-routes.json',import.meta.url),'utf8'));
assert.equal(coverage.schemaVersion,1);assert.equal(new Set(coverage.routes.map(r=>r.input+'>'+r.output)).size,coverage.routes.length);
assert.ok(coverage.routes.every(r=>r.verification==='representative-fixture'));
const formatsPage=await readFile(join(root,'formatos/index.html'),'utf8');
assert.ok(formatsPage.includes(`${coverage.routes.length} rutas de imagen comprobadas`));

const {validateEngineSources}=await import('../packages/release-manifest/validate.mjs');
const sources=validateEngineSources(JSON.parse(await readFile(new URL('../packages/release-manifest/engine-sources.json',import.meta.url),'utf8')));
assert.throws(()=>validateEngineSources({...sources,path:'/downloads/../unsafe.zip'}));
assert.throws(()=>validateEngineSources({...sources,size:0}));
const licenses=await readFile(join(root,'licencias/index.html'),'utf8');
assert.ok(licenses.includes(sources.path) && licenses.includes(sources.sha256));
assert.equal((await stat(join(root,sources.path))).size,sources.size);
console.log('Engine sources schema, size, checksum display and download link passed.');
