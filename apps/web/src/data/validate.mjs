export function validateManifest(value) {
  if (!value || value.schemaVersion !== 1 || value.channel !== 'stable' || !Object.hasOwn(value,'release') || Object.keys(value).some(k=>!['schemaVersion','channel','release'].includes(k))) throw Error('Invalid release manifest envelope');
  const r=value.release;
  if (r===null) return value;
  const fields=['version','date','minimumMacOS','architectures','installerURL','size','sha256','releaseNotesURL'];
  if (!r || fields.some(k=>!Object.hasOwn(r,k)) || Object.keys(r).some(k=>!fields.includes(k))) throw Error('Missing or unknown release fields');
  if (!/^\d+\.\d+\.\d+$/.test(r.version) || !/^\d{4}-\d{2}-\d{2}$/.test(r.date) || !Number.isFinite(Date.parse(r.date)) || new Date(r.date).toISOString().slice(0,10)!==r.date || !/^\d+\.\d+$/.test(r.minimumMacOS)) throw Error('Invalid version/date/macOS');
  if (!Array.isArray(r.architectures) || !r.architectures.length || new Set(r.architectures).size!==r.architectures.length || r.architectures.some(a=>!['arm64','x86_64'].includes(a))) throw Error('Invalid architectures');
  if (!Number.isSafeInteger(r.size) || r.size<=0 || !/^[a-f0-9]{64}$/.test(r.sha256)) throw Error('Invalid size/checksum');
  for (const field of ['installerURL','releaseNotesURL']) { const u=new URL(r[field]); if (u.protocol!=='https:' || u.username || u.password) throw Error('Release URLs must use HTTPS without credentials'); }
  return value;
}

export function validateDevelopmentDownload(value) {
  if (!value || value.schemaVersion !== 1 || value.status !== 'development' || Object.keys(value).sort().join(',') !== 'download,schemaVersion,status') throw Error('Invalid development download envelope');
  const r=value.download;
  const fields=['version','date','minimumMacOS','architectures','installerPath','size','sha256','releaseNotesPath','signing','notarized'];
  if (!r || fields.some(k=>!Object.hasOwn(r,k)) || Object.keys(r).some(k=>!fields.includes(k))) throw Error('Invalid development download fields');
  if (!/^\d+\.\d+\.\d+-dev$/.test(r.version) || !/^\d{4}-\d{2}-\d{2}$/.test(r.date) || !Number.isFinite(Date.parse(r.date)) || new Date(r.date).toISOString().slice(0,10)!==r.date || !/^\d+\.\d+$/.test(r.minimumMacOS)) throw Error('Invalid development version/date/macOS');
  if (!Array.isArray(r.architectures) || !r.architectures.length || new Set(r.architectures).size!==r.architectures.length || r.architectures.some(a=>!['arm64','x86_64'].includes(a))) throw Error('Invalid development architectures');
  if (!Number.isSafeInteger(r.size) || r.size<=0 || !/^[a-f0-9]{64}$/.test(r.sha256)) throw Error('Invalid development size/checksum');
  if (!/^\/downloads\/[A-Za-z0-9.-]+\.dmg$/.test(r.installerPath) || !/^\/[a-z0-9-]+\/$/.test(r.releaseNotesPath) || r.signing!=='ad-hoc' || r.notarized!==false) throw Error('Invalid development artifact/signing status');
  return value;
}

export function validateEngineSources(value) {
  if (!value || value.schemaVersion!==1 || Object.keys(value).sort().join(',')!=='path,schemaVersion,sha256,size,version' || !/^\d+\.\d+\.\d+$/.test(value.version) || !/^\/downloads\/[A-Za-z0-9.-]+\.zip$/.test(value.path) || !Number.isSafeInteger(value.size) || value.size<=0 || !/^[a-f0-9]{64}$/.test(value.sha256)) throw Error('Invalid engine source archive');
  return value;
}

export function validateWindowsDownload(value) {
  if(!value || Object.keys(value).sort().join(',')!=='channel,platform,release,schemaVersion' || value.schemaVersion!==1 || value.platform!=='windows' || value.channel!=='development') throw Error('Invalid Windows download envelope');
  const r=value.release;if(r===null)return value;
  const fields=['version','date','minimumWindows','architectures','installerPath','size','sha256','releaseNotesPath','signing'];
  if(!r || fields.some(k=>!Object.hasOwn(r,k)) || Object.keys(r).some(k=>!fields.includes(k)))throw Error('Invalid Windows release fields');
  if(!/^\d+\.\d+\.\d+-dev$/.test(r.version) || !/^\d{4}-\d{2}-\d{2}$/.test(r.date) || !Number.isFinite(Date.parse(r.date)) || new Date(r.date).toISOString().slice(0,10)!==r.date || r.minimumWindows!=='Windows 11 22H2' || !Array.isArray(r.architectures) || r.architectures.join(',')!=='x64')throw Error('Invalid Windows version or requirements');
  if(!/^\/downloads\/FluxDrop-[A-Za-z0-9.-]+-setup\.exe$/.test(r.installerPath) || !Number.isSafeInteger(r.size) || r.size<1 || !/^[a-f0-9]{64}$/.test(r.sha256) || r.releaseNotesPath!=='/windows/' || r.signing!=='unsigned')throw Error('Invalid Windows artifact or signing');
  return value;
}
