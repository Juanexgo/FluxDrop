import {readFile,writeFile,mkdir,access} from 'node:fs/promises';
const root=new URL('../../../',import.meta.url);
const shared=new URL('packages/release-manifest/',root);
await mkdir(new URL('../src/data/',import.meta.url),{recursive:true});
for (const name of ['stable.json','capabilities.json','development.json','image-routes.json','engine-sources.json','windows.json','windows-capabilities.json','windows-sources.json']) {
  try { const bytes=await readFile(new URL(name,shared)); await writeFile(new URL('../src/data/'+name,import.meta.url),bytes); }
  catch(error) { if(error.code!=='ENOENT') throw error; await access(new URL('../src/data/'+name,import.meta.url)); }
}
const {validateManifest,validateDevelopmentDownload}=await import('../src/data/validate.mjs');
validateManifest(JSON.parse(await readFile(new URL('../src/data/stable.json',import.meta.url),'utf8')));

const development=validateDevelopmentDownload(JSON.parse(await readFile(new URL('../src/data/development.json',import.meta.url),'utf8'))).download;
const {createHash}=await import('node:crypto');
const {createReadStream}=await import('node:fs');
const {stat}=await import('node:fs/promises');
if(development.installerPath){const artifact=new URL('../public'+development.installerPath,import.meta.url);
if ((await stat(artifact)).size!==development.size) throw Error('Development artifact size mismatch');
const digest=createHash('sha256');
for await (const chunk of createReadStream(artifact)) digest.update(chunk);
if (digest.digest('hex')!==development.sha256) throw Error('Development artifact checksum mismatch');}

const {validateEngineSources}=await import('../src/data/validate.mjs');
const sources=validateEngineSources(JSON.parse(await readFile(new URL('../src/data/engine-sources.json',import.meta.url),'utf8')));
const sourceArchive=new URL('../public'+sources.path,import.meta.url);
if ((await stat(sourceArchive)).size!==sources.size) throw Error('Engine source archive size mismatch');
const sourceHash=createHash('sha256');
for await (const chunk of createReadStream(sourceArchive)) sourceHash.update(chunk);
if (sourceHash.digest('hex')!==sources.sha256) throw Error('Engine source archive checksum mismatch');

const {validateWindowsDownload}=await import('../src/data/validate.mjs');
const windows=validateWindowsDownload(JSON.parse(await readFile(new URL('../src/data/windows.json',import.meta.url),'utf8'))).release;
if(windows?.installerPath){const artifact=new URL('../public'+windows.installerPath,import.meta.url);if((await stat(artifact)).size!==windows.size)throw Error('Windows installer size mismatch');const hash=createHash('sha256');for await(const chunk of createReadStream(artifact))hash.update(chunk);if(hash.digest('hex')!==windows.sha256)throw Error('Windows installer checksum mismatch');}

const windowsSourceValue=JSON.parse(await readFile(new URL('../src/data/windows-sources.json',import.meta.url),'utf8'));
if(windows&&!windowsSourceValue)throw Error('Windows corresponding sources required before publication');
if(windowsSourceValue){const sources=validateEngineSources(windowsSourceValue);const archive=new URL('../public'+sources.path,import.meta.url);if((await stat(archive)).size!==sources.size)throw Error('Windows source size mismatch');const hash=createHash('sha256');for await(const chunk of createReadStream(archive))hash.update(chunk);if(hash.digest('hex')!==sources.sha256)throw Error('Windows source checksum mismatch');}
