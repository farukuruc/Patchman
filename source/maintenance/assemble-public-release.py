"""Publish Install, Remove and exact v1.1 recovery after the complete build."""
import hashlib,json,pathlib,re,zipfile,zlib
import xml.etree.ElementTree as ET

HERE=pathlib.Path(__file__).resolve().parent
WORK=HERE.parent.parent/'work/Patchman-v1.5-Final'
BUILD=HERE.parent.parent/'work/Patchman-v1.5-Final-build'
ROOT='Patchman_NW-A55'
SHA=lambda b:hashlib.sha256(b).hexdigest()

def main():
    manifest=json.loads((HERE/'manifest.json').read_text())
    assert manifest['version']=='1.5-stable'
    assert SHA((WORK/'bundle.tar.gz').read_bytes())==manifest['values']['BUNDLE_SHA']
    player=(WORK/'player').read_bytes();off=0x65ba26
    length=int.from_bytes(player[off:off+4],'big')
    unit=zlib.decompress(player[off+8:off+4+length]).decode('utf-8')
    assert 'info: "Patchman v1.5"' in unit and 'Patchman v1.1' not in unit
    package_log=(WORK/'test-results.log').read_text()
    ui_log=(WORK/'ui-test-results.log').read_text()
    assert re.search(r'Ran \d+ tests in ',package_log) and package_log.rstrip().endswith('OK')
    assert 'test_update_from_public_v11_and_reinstall_v15_preserve_user_data' in package_log
    assert 'test_v15_return_to_public_v11_preserves_data_and_can_update_again' in package_log
    assert 'PASS continuous title:' in ui_log
    payload={};upgs={};executables={}
    for action,script,bundle in [('Install','install.sh','bundle.tar.gz'),('Remove','remove.sh',None),('ReturnToV1.1','return-v11.sh','return-v11.tar.gz')]:
        # The tool reopens each UPG; compare all decoded members with this build.
        members=[HERE/'scripts/exec_file.sh',HERE/'scripts'/script]
        if bundle:members.append(WORK/bundle)
        for i,source in enumerate(members):
            expected=source.read_bytes();actual=(BUILD/('verify-'+action)/(str(i)+'.bin')).read_bytes()
            assert actual[:len(expected)]==expected and not any(actual[len(expected):]),(action,i)
        for p in (HERE/action).rglob('*'):
            if not p.is_file():continue
            name=p.relative_to(HERE).as_posix();data=p.read_bytes()
            if p.name=='SWUpdate.xml':
                xml=ET.fromstring(data)
                assert xml.findtext('Common/Version')=='3.02'
                assert xml.findtext('Package/Product')=='Patchman v1.5-stable - '+action
            if p.name.startswith('disclaimer_'):
                assert data.startswith(b'\xff\xfe')
                text=data.decode('utf-16')
                assert text.startswith('Patchman v1.5-stable - '+action)
                assert 'test package' not in text.lower()
            if p.suffix=='.exe':executables[name]=SHA(data)
            if p.name=='NW_WM_FW.UPG':upgs[name]=SHA(data)
            payload[name]=data
    assert len(upgs)==3
    manifest['files']=[{k:v for k,v in f.items() if k!='source'} for f in manifest['files']]
    manifest['release']={
        'distribution':'complete-first-install-and-update',
        'public_folders':['Install','Remove','ReturnToV1.1'],
        'return_to_v11_bundle_sha256':SHA((WORK/'return-v11.tar.gz').read_bytes()),
        'upgrade_baseline':'public v1.1 complete installer; filesystem upgrade and reinstall tested',
        'unit_information':'Patchman v1.5',
        'upg_sha256':upgs,
        'device_validation':'UI features reported working by author; final v1.5 first installation not separately device-tested',
    }
    payload['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
    payload['README.md']=(HERE/'README.md').read_bytes()
    readme=payload['README.md'].decode('utf-8')
    for phrase in ['Update from working v1.1','Required clean setup','Patchman v1.5','Sorting Options','Bluetooth','Direct Source','continuous','ARTIST-PHOTOS']:
        assert phrase.lower() in readme.lower(),phrase
    payload['SHA256SUMS.txt']=''.join(SHA(v)+'  '+k+'\n' for k,v in sorted(payload.items())).encode()
    target=HERE/'Patchman_NW-A55.zip';temp=HERE/'Patchman_NW-A55.zip.tmp'
    with zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED) as z:
        for name,data in sorted(payload.items()):z.writestr(ROOT+'/'+name,data)
    with zipfile.ZipFile(temp) as z:
        assert z.testzip() is None
        assert set(z.namelist())=={ROOT+'/'+name for name in payload}
        assert not any('ReturnToConfirmed/' in name or '-Test/' in name for name in z.namelist())
        for line in z.read(ROOT+'/SHA256SUMS.txt').decode().splitlines():
            digest,name=line.split(None,1);assert SHA(z.read(ROOT+'/'+name))==digest
    temp.replace(target)
    for name,data in payload.items():
        p=HERE/ROOT/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    digest=SHA(target.read_bytes())
    (HERE/'Patchman_NW-A55.zip.sha256').write_bytes((digest+'  Patchman_NW-A55.zip\n').encode())
    report=dict(version='1.5-stable',zip_sha256=digest,all_file_checksums='passed',
                unit_information='Patchman v1.5',upg_round_trips='passed',upg_sha256=upgs,
                executable_sha256=executables,notices='UTF-16LE with BOM',
                filesystem_tests=int(re.search(r'Ran (\d+) tests',package_log)[1]),
                fresh_install_and_public_v11_upgrade='passed in filesystem fixtures',
                return_to_public_v11_and_update_again='passed in filesystem fixtures',
                qml_layout_lifecycle_and_fallback='passed on host Qt',
                device_validation=manifest['release']['device_validation'])
    (HERE/'release-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('PASS v1.5 release: fresh/update tests, Unit Information, UPG round trips, UTF-16 notices, clean public ZIP and checksums')
    print('DONE:',target)
    print('SHA256:',digest)

if __name__=='__main__':main()
