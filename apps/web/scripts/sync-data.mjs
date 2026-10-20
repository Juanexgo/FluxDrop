import {readFile,writeFile,mkdir,access} from 'node:fs/promises';
const root=new URL('../../../',import.meta.url);
const shared=new URL('packages/release-manifest/',root);
await mkdir(new URL('../src/data/',import.meta.url),{recursive:true});
for (const name of ['stable.json','capabilities.json']) {
  try { const bytes=await readFile(new URL(name,shared)); await writeFile(new URL('../src/data/'+name,import.meta.url),bytes); }
  catch(error) { if(error.code!=='ENOENT') throw error; await access(new URL('../src/data/'+name,import.meta.url)); }
}
const {validateManifest}=await import('../src/data/validate.mjs');
validateManifest(JSON.parse(await readFile(new URL('../src/data/stable.json',import.meta.url),'utf8')));
