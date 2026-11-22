"""Package verified v1.5.1 Install and Remove only."""
import hashlib,json,pathlib,re,xml.etree.ElementTree as ET,zipfile
HERE=pathlib.Path(__file__).resolve().parent
WORK=HERE.parent.parent/'work/Patchman-v1.5.1'
BUILD=HERE.parent.parent/'work/Patchman-v1.5.1-build'
SHA=lambda b:hashlib.sha256(b).hexdigest()

def main():
    package_log=(WORK/'test-results.log').read_text()
    ui_log=(WORK/'ui-test-results.log').read_text()
    battery_log=(WORK/'battery-test-results.log').read_text()
    assert re.search(r'Ran \d+ tests in ',package_log) and package_log.rstrip().endswith('OK')
    assert 'PASS native title:' in ui_log
    assert 'PASS battery QML:' in battery_log and 'PASS half-ring header:' in battery_log
    manifest=json.loads((HERE/'manifest.json').read_text())
    assert manifest['version']=='1.5.1-stable'
    assert SHA((WORK/'bundle.tar.gz').read_bytes())==manifest['values']['BUNDLE_SHA']
    files={};upgs={}
    for action,script,bundle in [('Install','install.sh','bundle.tar.gz'),('Remove','remove.sh',None)]:
        members=[HERE/'scripts/exec_file.sh',HERE/'scripts'/script]
        if bundle:members.append(WORK/bundle)
        for i,p in enumerate(members):
            expected=p.read_bytes();actual=(BUILD/('verify-'+action)/(str(i)+'.bin')).read_bytes()
            assert actual[:len(expected)]==expected and not any(actual[len(expected):])
        for p in (HERE/action).rglob('*'):
            if not p.is_file():continue
            data=p.read_bytes();name=p.relative_to(HERE).as_posix()
            if p.name=='SWUpdate.xml':
                xml=ET.fromstring(data)
                assert xml.findtext('Common/Version')=='3.02'
                assert xml.findtext('Package/Product')=='Patchman v1.5.1 - '+action
            if p.name.startswith('disclaimer_'):
                assert data.startswith(b'\xff\xfe') and 'Patchman v1.5.1' in data.decode('utf-16')
            if p.suffix=='.UPG':upgs[name]=SHA(data)
            files[name]=data
    assert len(upgs)==2
    manifest['files']=[{k:v for k,v in f.items() if k!='source'} for f in manifest['files']]
    manifest['release']=dict(public_folders=['Install','Remove'],unit_information='Patchman v1.5.1',upg_sha256=upgs,device_verification='author confirmed installation and updated UI on NW-A55; clean first install and every charging condition not separately device-tested')
    files['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
    files['README.md']=(HERE/'README.md').read_bytes()
    assert b'ReturnToV1.1/' not in files['README.md']
    files['SHA256SUMS.txt']=''.join(SHA(v)+'  '+k+'\n' for k,v in sorted(files.items())).encode()
    target=HERE/'Patchman_NW-A55.zip';temp=target.with_suffix('.zip.tmp')
    with zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED) as z:
        for name,data in sorted(files.items()):z.writestr('Patchman_NW-A55/'+name,data)
    with zipfile.ZipFile(temp) as z:
        assert z.testzip() is None
        assert not any('/ReturnTo' in n for n in z.namelist())
        for line in z.read('Patchman_NW-A55/SHA256SUMS.txt').decode().splitlines():
            digest,name=line.split(None,1);assert SHA(z.read('Patchman_NW-A55/'+name))==digest
    temp.replace(target)
    (HERE/'Patchman_NW-A55.zip.sha256').write_bytes((SHA(target.read_bytes())+'  '+target.name+'\n').encode())
    report=dict(version='1.5.1-stable',zip_sha256=SHA(target.read_bytes()),filesystem_tests=int(re.search(r'Ran (\d+) tests',package_log)[1]),original_sony_marquee='restored',half_ring_layout='host Qt tests passed',unit_information='Patchman v1.5.1',upg_roundtrip='passed',public_folders=['Install','Remove'],device_verification='author confirmed installation and updated UI on NW-A55')
    (HERE/'release-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('PASS v1.5.1 ZIP integrity, checksums and Install/Remove only:',target)
    print('SHA256:',SHA(target.read_bytes()))

if __name__=='__main__':main()
