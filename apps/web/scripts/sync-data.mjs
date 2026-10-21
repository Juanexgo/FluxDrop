import {readFile,writeFile,mkdir,access} from 'node:fs/promises';
const root=new URL('../../../',import.meta.url);
const shared=new URL('packages/release-manifest/',root);
await mkdir(new URL('../src/data/',import.meta.url),{recursive:true});
for (const name of ['stable.json','capabilities.json','development.json','image-routes.json','engine-sources.json']) {
  try { const bytes=await readFile(new URL(name,shared)); await writeFile(new URL('../src/data/'+name,import.meta.url),bytes); }
  catch(error) { if(error.code!=='ENOENT') throw error; await access(new URL('../src/data/'+name,import.meta.url)); }
}
const {validateManifest,validateDevelopmentDownload}=await import('../src/data/validate.mjs');
validateManifest(JSON.parse(await readFile(new URL('../src/data/stable.json',import.meta.url),'utf8')));

const development=validateDevelopmentDownload(JSON.parse(await readFile(new URL('../src/data/development.json',import.meta.url),'utf8'))).download;
const {createHash}=await import('node:crypto');
const {createReadStream}=await import('node:fs');
const {stat}=await import('node:fs/promises');
const artifact=new URL('../public'+development.installerPath,import.meta.url);
if ((await stat(artifact)).size!==development.size) throw Error('Development artifact size mismatch');
const digest=createHash('sha256');
for await (const chunk of createReadStream(artifact)) digest.update(chunk);
if (digest.digest('hex')!==development.sha256) throw Error('Development artifact checksum mismatch');

const {validateEngineSources}=await import('../src/data/validate.mjs');
const sources=validateEngineSources(JSON.parse(await readFile(new URL('../src/data/engine-sources.json',import.meta.url),'utf8')));
const sourceArchive=new URL('../public'+sources.path,import.meta.url);
if ((await stat(sourceArchive)).size!==sources.size) throw Error('Engine source archive size mismatch');
const sourceHash=createHash('sha256');
for await (const chunk of createReadStream(sourceArchive)) sourceHash.update(chunk);
if (sourceHash.digest('hex')!==sources.sha256) throw Error('Engine source archive checksum mismatch');
