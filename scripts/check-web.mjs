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
assert.ok(downloadPage.includes(dev.installerURL??dev.installerPath) && downloadPage.includes('download') && downloadPage.includes(dev.sha256));
if(dev.installerPath)assert.equal((await stat(join(root,dev.installerPath))).size,dev.size);
console.log('Mac download schema and page link checks passed; remote artifacts are verified by verify-installer-downloads.mjs.');

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

const homepage=await readFile(join(root,'index.html'),'utf8');
assert.ok(homepage.includes('data-file-actions') && homepage.includes('/file-actions.js'));
assert.equal([...homepage.matchAll(/data-select-action=/g)].length,6);
assert.ok(homepage.includes('no recibe ni procesa tus archivos'));
console.log('File actions section: six controls, external script and local-processing disclosure passed.');

const {validateWindowsDownload}=await import('../packages/release-manifest/validate.mjs');
const windows=validateWindowsDownload(JSON.parse(await readFile(new URL('../packages/release-manifest/windows.json',import.meta.url),'utf8'))).release;
validateWindowsDownload({schemaVersion:1,platform:'windows',channel:'development',release:null});
assert.throws(()=>validateWindowsDownload({schemaVersion:1,platform:'windows',channel:'stable',release:null}));
if(windows){assert.throws(()=>validateWindowsDownload({schemaVersion:1,platform:'windows',channel:'development',release:{...windows,signing:'signed'}}));assert.throws(()=>validateWindowsDownload({schemaVersion:1,platform:'windows',channel:'development',release:{...windows,installerPath:'/downloads/../unsafe.exe'}}));assert.ok(downloadPage.includes(windows.installerURL??windows.installerPath)&&downloadPage.includes(windows.sha256));if(windows.installerPath){assert.equal((await stat(join(root,windows.installerPath))).size,windows.size);const {createHash}=await import('node:crypto');const {createReadStream}=await import('node:fs');const hash=createHash('sha256');for await(const chunk of createReadStream(join(root,windows.installerPath)))hash.update(chunk);assert.equal(hash.digest('hex'),windows.sha256);}}
assert.ok(formatsPage.includes('Compatibilidad de Windows'));assert.ok((await readFile(join(root,'windows/index.html'),'utf8')).includes('No hay paridad total de formatos'));
console.log('Windows download schema and platform disclosure passed; remote artifacts are verified by verify-installer-downloads.mjs.');
const windowsSourceValue=JSON.parse(await readFile(new URL('../packages/release-manifest/windows-sources.json',import.meta.url),'utf8'));
if(windows){const sources=validateEngineSources(windowsSourceValue);assert.equal((await stat(join(root,sources.path))).size,sources.size);assert.ok((await readFile(join(root,'windows/index.html'),'utf8')).includes(sources.sha256));}

for(const [value,key,validator] of [[development,'download',validateDevelopmentDownload],[{schemaVersion:1,platform:'windows',channel:'development',release:windows},'release',validateWindowsDownload]]){if(!value[key]?.installerURL)continue;for(const url of ['https://example.com/fake.msi','http://github.com/Juanexgo/FluxDrop-Releases/releases/download/v0.4-installers/fake.pkg','https://github.com/other/repo/releases/download/v/file.msi'])assert.throws(()=>validator({...value,[key]:{...value[key],installerURL:url}}));assert.throws(()=>validator({...value,[key]:{...value[key],installerPath:'/downloads/duplicate.pkg'}}));}
