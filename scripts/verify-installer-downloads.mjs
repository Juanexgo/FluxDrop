import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {validateDevelopmentDownload,validateWindowsDownload} from '../packages/release-manifest/validate.mjs';
const mac=validateDevelopmentDownload(JSON.parse(await readFile(new URL('../packages/release-manifest/development.json',import.meta.url)))).download;
const windows=validateWindowsDownload(JSON.parse(await readFile(new URL('../packages/release-manifest/windows.json',import.meta.url)))).release;
for(const [platform,release] of [['macOS',mac],['Windows',windows]]){
 if(!release)continue;
 const url=release.installerURL??new URL(release.installerPath,'https://fluxdrop-ruby.vercel.app').href;
 const response=await fetch(url,{signal:AbortSignal.timeout(300000)});if(!response.ok)throw Error(`${platform}: HTTP ${response.status}`);
 const hash=createHash('sha256');let size=0;let magic=Buffer.alloc(0);
 for await(const chunk of response.body){if(magic.length<8)magic=Buffer.concat([magic,Buffer.from(chunk)]).subarray(0,8);size+=chunk.length;hash.update(chunk);}
 const digest=hash.digest('hex');if(size!==release.size||digest!==release.sha256)throw Error(`${platform}: download size/checksum mismatch`);
 if(url.endsWith('.pkg')&&magic.subarray(0,4).toString()!=='xar!')throw Error('PKG is not an Apple XAR package');
 if(url.endsWith('.msi')&&magic.toString('hex')!=='d0cf11e0a1b11ae1')throw Error('MSI is not a Windows Installer OLE package');
 const checksum=await fetch(url+'.sha256',{signal:AbortSignal.timeout(30000)});if(!checksum.ok||(await checksum.text()).trim().split(/\s+/)[0]!==digest)throw Error(`${platform}: sidecar mismatch`);
 console.log(`${platform}: complete HTTPS download verified; ${size} bytes; SHA-256 ${digest}`);
}
