#!/usr/bin/env python3
"""Deterministic tiny hostile archives for rejection tests. Never extracts them."""
from pathlib import Path
import io, tarfile, zipfile
root = Path(__file__).resolve().parents[1] / 'apps/macos/Tests/FluxCoreTests/Fixtures'
root.mkdir(parents=True, exist_ok=True)
def write_zip(name, entries):
    with zipfile.ZipFile(root/name, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path, content, mode in entries:
            item = zipfile.ZipInfo(path, date_time=(2020,1,1,0,0,0))
            item.create_system = 3; item.external_attr = mode << 16; item.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(item,content)
write_zip('traversal.zip',[('../outside.txt',b'escape',0o100600)])
write_zip('absolute.zip',[('/outside.txt',b'escape',0o100600)])
write_zip('case-collision.zip',[('report.txt',b'first',0o100600),('REPORT.txt',b'second',0o100600)])
write_zip('symlink.zip',[('shortcut',b'../outside.txt',0o120777)])
with zipfile.ZipFile(root/'expansion.zip','w',compression=zipfile.ZIP_DEFLATED) as archive:
    item=zipfile.ZipInfo('expanded.bin',date_time=(2020,1,1,0,0,0)); item.compress_type=zipfile.ZIP_DEFLATED
    with archive.open(item,'w') as target:
        for _ in range(272): target.write(bytes(65536))
for name, kind in [('hardlink.tar',tarfile.LNKTYPE),('symlink.tar',tarfile.SYMTYPE)]:
    with tarfile.open(root/name,'w',format=tarfile.USTAR_FORMAT) as archive:
        entry=tarfile.TarInfo('link');entry.type=kind;entry.linkname='../outside.txt';entry.mtime=0
        archive.addfile(entry)
(root/'corrupt.zip').write_bytes(b'PK\x03\x04broken')
print('Generated eight rejection fixtures in',root)
