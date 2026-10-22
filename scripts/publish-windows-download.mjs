import {readFile,writeFile,copyFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {basename} from 'node:path';
import {validateWindowsDownload} from '../packages/release-manifest/validate.mjs';
const [file,sourceFile]=process.argv.slice(2);if(!file||!sourceFile)throw Error('Usage: node scripts/publish-windows-download.mjs verified-setup.exe corresponding-sources.zip');
const bytes=await readFile(file);if(bytes[0]!==0x4d||bytes[1]!==0x5a)throw Error('Not a Windows executable');
const filename=basename(file),sha256=createHash('sha256').update(bytes).digest('hex');
const manifest=validateWindowsDownload({schemaVersion:1,platform:'windows',channel:'development',release:{version:'0.4.0-dev',date:'2026-10-21',minimumWindows:'Windows 11 22H2',architectures:['x64'],installerPath:'/downloads/'+filename,size:bytes.length,sha256,releaseNotesPath:'/windows/',signing:'unsigned'}});
const publicFolder=new URL('../apps/web/public/downloads/',import.meta.url);await mkdir(publicFolder,{recursive:true});await copyFile(file,new URL(filename,publicFolder));await writeFile(new URL(filename+'.sha256',publicFolder),`${sha256}  ${filename}\n`);
await writeFile(new URL('../packages/release-manifest/windows.json',import.meta.url),JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify(manifest,null,2));

const {validateEngineSources}=await import('../packages/release-manifest/validate.mjs');
const sourceBytes=await readFile(sourceFile);if(sourceBytes[0]!==0x50||sourceBytes[1]!==0x4b)throw Error('Not a source ZIP');const sourceName=basename(sourceFile);const sources=validateEngineSources({schemaVersion:1,version:'0.4.0',path:'/downloads/'+sourceName,size:sourceBytes.length,sha256:createHash('sha256').update(sourceBytes).digest('hex')});await copyFile(sourceFile,new URL(sourceName,publicFolder));await writeFile(new URL(sourceName+'.sha256',publicFolder),`${sources.sha256}  ${sourceName}\n`);await writeFile(new URL('../packages/release-manifest/windows-sources.json',import.meta.url),JSON.stringify(sources,null,2)+'\n');
