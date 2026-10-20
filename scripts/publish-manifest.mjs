import {readFile,writeFile,rename} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {validateManifest} from '../packages/release-manifest/validate.mjs';
const [candidate,proof]=process.argv.slice(2);
if(!candidate||!proof)throw Error('Usage: node scripts/publish-manifest.mjs candidate.json notarization-proof.json');
const manifest=validateManifest(JSON.parse(await readFile(candidate,'utf8'))),r=manifest.release;
if(!r)throw Error('A published installer is required');
const attestation=JSON.parse(await readFile(proof,'utf8'));
if(attestation.status!=='Accepted'||attestation.sha256!==r.sha256)throw Error('Notarization proof must match the exact installer');
const response=await fetch(r.installerURL,{redirect:'error'});
if(!response.ok||!response.body)throw Error('Installer is not publicly downloadable');
const hash=createHash('sha256');let size=0;
for await(const chunk of response.body){size+=chunk.length;if(size>r.size)throw Error('Installer exceeds expected size');hash.update(chunk);}
if(size!==r.size||hash.digest('hex')!==r.sha256)throw Error('Published installer checksum or size mismatch');
if(!(await fetch(r.releaseNotesURL,{method:'HEAD',redirect:'error'})).ok)throw Error('Release notes unavailable');
const target=new URL('../packages/release-manifest/stable.json',import.meta.url),temp=new URL(target.href+'.tmp');
await writeFile(temp,JSON.stringify(manifest,null,2)+'\n');await rename(temp,target);
console.log('Verified installer; stable manifest updated. Rebuild and publish the website.');
