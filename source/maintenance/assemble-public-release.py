"""Assemble v1.1-stable from immutable, device-confirmed UPGs.

Only external installer notices, XML Product labels and release documents change.
Encrypted firmware payloads and Windows executables remain byte-identical.
"""
import hashlib,json,pathlib,re,zipfile,xml.etree.ElementTree as ET

HERE=pathlib.Path(__file__).resolve().parent
ROOT='Patchman_NW-A55'
VERSION='1.1-stable'
def sha(data):return hashlib.sha256(data).hexdigest()
def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)

INSTALL_NOTICE='''Patchman v1.1-stable - Install

REQUIRED BEFORE INSTALLATION - EVEN IF WALKMAN ONE 3.02 IS ALREADY INSTALLED:

Back up your files. Remove active Patchman with its matching remover, if present. Return fully to stock using the StockRevert package for your current Walkman One A50 firmware, then apply the official Sony NW-A55 firmware update as instructed. Download and install Walkman One for NW-A50 again from the official MrWalkman website. Confirm it works, then install Patchman.

Required order: stock Sony firmware > fresh official Walkman One 3.02 > Patchman. Do not install directly over an old Walkman One setup. A settings reset alone is not a stock firmware return. Read the full steps in README.md.

Requires Sony NW-A55. This package does not install Walkman One. A factory reset is a separate optional step that erases internal user data; keep backups on the PC.

Adds album Play and total time, newest-first album years, queue Remaining time, Parametric EQ, optional Cassette Screen, Audio Path, Go to Album / Album Artist, and optional artist photos.

Go to requires Playback Settings > Artist List Display > Album Artist.

Optional artist photos belong in ARTIST-PHOTOS on the player's internal storage. Match the Album Artist name, for example Queen.jpg or Pink Floyd.png. Without a photo, the original album cover stays. Fully restart after adding or changing photos.

The Patchman installer keeps your music, photos, PEQ profiles and supported preferences. Earlier preparation or a factory reset can erase files or reset settings, so keep backups. No WM1Z sound signature is required.

After installation completes, disconnect USB and fully turn the player off and on. Check Patchman after a start without USB.

USB-connected starts defer the first PEQ playback check. On the first start without USB, connect wired headphones and play normal PCM/FLAC audio before another full restart. Existing verified installations keep their playback check.

This is the complete installer. No earlier Patchman package is required. The stock return and fresh Walkman One preparation above also apply when installing this release on a player that has used Patchman before. If installation reports an unsupported player version, read README.md and share the latest install log; do not bypass the check.

Direct Source + PEQ was tested with wired headphones. Bluetooth playback and PEQ were not tested; the author listens by wired headphones.
'''
REMOVE_NOTICE='''Patchman v1.1-stable - Remove

Removes active Patchman features from a compatible Sony NW-A55 installation.

The player returns to Walkman One's original player. This does not install stock Sony firmware or return to an older Patchman release.

Your music, ARTIST-PHOTOS files and PEQ profile files are kept. Walkman One remains installed.

After removal completes, disconnect USB and fully turn the player off and on.
'''

def main():
    receipt=json.loads((HERE/'backups/receipt.json').read_text())
    source_path=HERE/'backups'/receipt['source_zip_name']
    source_root=receipt['source_zip_root']
    source=source_path.read_bytes()
    assert sha(source)==receipt['source_zip_sha256']
    payload={};source_upg={};exe_hashes={};source_manifest=None
    with zipfile.ZipFile(source_path) as z:
        assert z.testzip() is None
        source_manifest=json.loads(z.read(source_root+'manifest.json'))
        assert source_manifest['version']==receipt['source_version']
        for line in z.read(source_root+'SHA256SUMS.txt').decode().splitlines():
            digest,name=line.split(None,1);assert sha(z.read(source_root+name.strip()))==digest
        for action in ('Install','Remove'):
            for name in z.namelist():
                prefix=source_root+action+'/'
                if not name.startswith(prefix) or name.endswith('/'):continue
                relative=name[len(source_root):]
                assert '..' not in pathlib.PurePosixPath(relative).parts
                data=z.read(name)
                if relative.endswith('/NW_WM_FW.UPG'):source_upg[relative]=sha(data)
                if relative.endswith('.exe'):exe_hashes[relative]=sha(data)
                if relative.endswith('/SWUpdate.xml'):
                    data,n=re.subn(rb'<Product>.*?</Product>',('<Product>Patchman v1.1-stable - '+action+'</Product>').encode(),data);assert n==1
                    assert ET.fromstring(data).findtext('Common/Version')=='3.02'
                if pathlib.PurePosixPath(relative).name.startswith('disclaimer_'):
                    text=INSTALL_NOTICE if action=='Install' else REMOVE_NOTICE
                    data=b'\xff\xfe'+text.replace('\n','\r\n').encode('utf-16-le')
                    assert data.decode('utf-16').startswith('Patchman v1.1-stable - '+action)
                    assert 'trial' not in data.decode('utf-16').lower()
                payload[relative]=data
    assert len(source_upg)==2
    assert source_manifest['values']['BUNDLE_SHA']==receipt['source_bundle_sha256']
    manifest=dict(source_manifest,version=VERSION,build='nw-a55-v1.1-stable',release_date='2026-11-20')
    manifest['files']=[{k:v for k,v in f.items() if k!='source'} for f in manifest['files']]
    manifest['release']={'firmware_payloads_unchanged':True,'upg_sha256':source_upg,'source_zip_sha256':receipt['source_zip_sha256']}
    manifest['release']['distribution_revision']=receipt.get('distribution_revision','original-v1.1')
    payload['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
    payload['README.md']=(HERE/'README.md').read_bytes()
    readme=payload['README.md'].decode('utf-8')
    for required in ('Walkman One 3.02','ARTIST-PHOTOS','Album Artist','Direct Source','Bluetooth','newest','Remove'):
        assert required in readme,required
    assert 'Final confirmation is still pending' not in readme
    for name,digest in source_upg.items():assert sha(payload[name])==digest
    for name,digest in exe_hashes.items():assert sha(payload[name])==digest
    payload['SHA256SUMS.txt']=''.join(sha(payload[name])+'  '+name+'\n' for name in sorted(payload)).encode()
    for name,data in payload.items():write(HERE/ROOT/name,data)
    target=HERE/'Patchman_NW-A55.zip';temporary=HERE/'Patchman_NW-A55.zip.tmp'
    with zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED) as z:
        for name,data in sorted(payload.items()):z.writestr(ROOT+'/'+name,data)
    with zipfile.ZipFile(temporary) as z:
        assert z.testzip() is None
        assert set(z.namelist())=={ROOT+'/'+name for name in payload}
        assert not any('ReturnTo' in name for name in z.namelist())
        for line in z.read(ROOT+'/SHA256SUMS.txt').decode().splitlines():
            digest,name=line.split(None,1);assert sha(z.read(ROOT+'/'+name))==digest
        for name,digest in source_upg.items():assert sha(z.read(ROOT+'/'+name))==digest
        for name in z.namelist():
            if pathlib.PurePosixPath(name).name.startswith('disclaimer_'):
                assert z.read(name).startswith(b'\xff\xfe')
                assert z.read(name).decode('utf-16').startswith('Patchman v1.1-stable')
    temporary.replace(target)
    digest=sha(target.read_bytes())
    write(HERE/'Patchman_NW-A55.zip.sha256',(digest+'  Patchman_NW-A55.zip\n').encode())
    report={'version':VERSION,'zip_sha256':digest,'zip_crc':'passed','all_packaged_file_checksums':'passed','upgs_identical_to_device_confirmed_build':source_upg,'executables_identical_to_confirmed_source':exe_hashes,'source_bundle_sha256':receipt['source_bundle_sha256'],'installer_xml_firmware_version':'3.02 unchanged','all_notices':'UTF-16 LE with BOM','public_folders':['Install','Remove'],'device_confirmed_features':receipt['device_confirmed']}
    report['distribution_revision']=receipt.get('distribution_revision','original-v1.1')
    if 'clean_install_tests' in receipt:report['clean_install_tests']=receipt['clean_install_tests']
    write(HERE/'release-verification.json',(json.dumps(report,indent=2)+'\n').encode())
    print('PASS final release: unchanged confirmed UPGs/executables, stable labels, UTF-16 notices, clean folders, manifest and all file checksums')
    print('DONE:',target)
    print('SHA256:',digest)
if __name__=='__main__':main()
