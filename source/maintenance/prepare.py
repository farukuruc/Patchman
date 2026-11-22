"""Native Sony scrolling, half-ring battery and v1.5.1 version label."""
import gzip,hashlib,io,json,pathlib,re,tarfile,zipfile

HERE=pathlib.Path(__file__).resolve().parent
PROJECT=HERE.parent.parent
BASE=HERE.parent/'Patchman-v1.5-Final'
WORK=PROJECT/'work/Patchman-v1.5.1'
SHA=lambda b:hashlib.sha256(b).hexdigest()
STABLE_SHA='defa2b99758edc4e7dcd1da9bdf4e5196efc6152bc6dc639b7c052d86a7e3a78'

def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(data.encode('utf-8') if isinstance(data,str) else data)

def main():
    WORK.mkdir(parents=True,exist_ok=True)
    archive=(BASE/'Patchman_NW-A55.zip').read_bytes()
    assert SHA(archive)==STABLE_SHA
    with zipfile.ZipFile(io.BytesIO(archive)) as z:
        assert z.testzip() is None
        original=json.loads(z.read('Patchman_NW-A55/manifest.json'))
        for line in z.read('Patchman_NW-A55/SHA256SUMS.txt').decode().splitlines():
            digest,name=line.split(None,1);assert SHA(z.read('Patchman_NW-A55/'+name))==digest
        for action,origin in [('Install','Install'),('Remove','Remove')]:
            prefix='Patchman_NW-A55/'+origin+'/'
            for name in z.namelist():
                if name.startswith(prefix) and not name.endswith('/') and not name.endswith('.UPG'):
                    write(HERE/action/name[len(prefix):],z.read(name))
            title='Patchman v1.5.1 - '+action
            p=HERE/action/'Data/Device/SWUpdate.xml'
            p.write_bytes(re.sub(rb'<Product>.*?</Product>',('<Product>'+title+'</Product>').encode(),p.read_bytes()))
            notice=title+'\r\n\r\nSony NW-A55 with compatible Walkman One 3.02. '
            notice+=('Restores original Sony title scrolling and adds a half-ring battery display. Unit Information shows Patchman v1.5.1. ' if action=='Install' else 'Restores the exact public v1.5 payload. ' if action=='ReturnToV15' else 'Removes Patchman and keeps Walkman One. ')
            notice+='Music, profiles and preferences are kept. Disconnect USB and fully power off and on after installation. Read README.md.\r\n'
            for p in (HERE/action/'Data/Device').glob('disclaimer_*.txt'):p.write_bytes(b'\xff\xfe'+notice.encode('utf-16-le'))
    frozen=(PROJECT/'work/Patchman-v1.5-Final/bundle.tar.gz').read_bytes()
    assert SHA(frozen)==original['values']['BUNDLE_SHA']
    with tarfile.open(fileobj=io.BytesIO(frozen),mode='r:gz') as t:
        payload={f['name']:t.extractfile(f['name']).read() for f in original['files']}
    for f in original['files']:assert SHA(payload[f['name']])==f['sha256']
    # Restore the three original Sony marquee resource slots from the last
    # confirmed pre-continuous player. Keep the v1.5 Unit Information resource.
    with tarfile.open(BASE/'backups/bundle.tar.gz','r:gz') as t:
        native=t.extractfile('player').read()
    before=payload['player'];player=bytearray(before)
    slots={0x6315a1:1469,0x5ec469:1943,0x61f1db:4333}
    cursor=0
    for off,size in sorted(slots.items()):
        player[off:off+size]=native[off:off+size]
        assert player[cursor:off]==before[cursor:off]
        cursor=off+size
    assert player[cursor:]==before[cursor:] and len(player)==len(before)
    payload['player']=bytes(player)
    for off,size in slots.items():assert payload['player'][off:off+size]==native[off:off+size]
    import zlib
    for off in (0x6315a1,0x5ec469):
        n=int.from_bytes(player[off:off+4],'big')
        assert b'continuous:' not in zlib.decompress(player[off+8:off+4+n])
    off=0x61f1db;n=int.from_bytes(player[off:off+4],'big')
    assert b'loopLoader' not in player[off+4:off+4+n]
    off=0x65ba26;n=int.from_bytes(player[off:off+4],'big')
    assert b'Patchman v1.5' in zlib.decompress(player[off+8:off+4+n])
    off=0x65ba26;slot=2319;n=int.from_bytes(player[off:off+4],'big')
    unit=zlib.decompress(player[off+8:off+4+n])
    assert unit.count(b'info: "Patchman v1.5"')==1
    unit=unit.replace(b'info: "Patchman v1.5"',b'info: "Patchman v1.5.1"')
    body=len(unit).to_bytes(4,'big')+zlib.compress(unit,9)
    packed=len(body).to_bytes(4,'big')+body
    assert len(packed)<=slot
    player[off:off+slot]=packed.ljust(slot,b'\0')
    payload['player']=bytes(player)
    payload['topbar-batteryindicator']=(HERE/'source/BatteryIndicator.qml').read_bytes()
    for f in original['files']:
        if f['name'].startswith('topbar-'):
            write(HERE/'source/topbar'/pathlib.PurePosixPath(f['destination']).name,payload[f['name']])
    new_player_sha=SHA(payload['player'])
    def allow(text):
        marker='known_player() {\n'
        assert text.count(marker)==1
        return text.replace(marker,marker+'  hash_is "$1" "'+new_player_sha+'" && return 0\n',1)
    entries=[dict(f) for f in original['files']]
    raw=io.BytesIO()
    with tarfile.open(fileobj=raw,mode='w',format=tarfile.USTAR_FORMAT) as t:
        for f in entries:
            data=payload[f['name']];write(WORK/f['name'],data)
            f.update(source=str(WORK/f['name']),sha256=SHA(data))
            info=tarfile.TarInfo(f['name']);info.size=len(data);info.mode=int(str(f['mode']),8);info.mtime=0
            t.addfile(info,io.BytesIO(data))
    bundle=gzip.compress(raw.getvalue(),compresslevel=9,mtime=0)
    write(WORK/'bundle.tar.gz',bundle);write(WORK/'return-stable.tar.gz',frozen)
    write(WORK/'stable-manifest.json',json.dumps(original,indent=2)+'\n')
    write(HERE/'backups/install.sh',(BASE/'scripts/install.sh').read_bytes())
    write(HERE/'backups/v11-install.sh',(BASE/'backups/v11-install.sh').read_bytes())
    write(WORK/'return-v11.tar.gz',(BASE/'backups/v11-bundle.tar.gz').read_bytes())
    for name in ('v11-bundle.tar.gz','v11-manifest.json'):write(HERE/'backups'/name,(BASE/'backups'/name).read_bytes())
    values=dict(original['values'],BUNDLE_SHA=SHA(bundle),BUNDLE_SIZE=str(len(bundle)))
    values['CONTENTS_KIB']=str((len(bundle)+1088*1024+1023)//1024)
    script=(BASE/'scripts/install.sh').read_text(encoding='utf-8')
    script=script.replace(original['values']['BUNDLE_SHA'],values['BUNDLE_SHA'])
    script=script.replace('head -c '+original['values']['BUNDLE_SIZE']+' ','head -c '+values['BUNDLE_SIZE']+' ')
    old=next(f['sha256'] for f in original['files'] if f['name']=='player')
    script=allow(script.replace('hash_is "$TMP/files/player" "'+old+'"','hash_is "$TMP/files/player" "'+new_player_sha+'"'))
    script=script.replace('require_space /contents '+original['values']['CONTENTS_KIB'],'require_space /contents '+values['CONTENTS_KIB'])
    old_battery=next(f['sha256'] for f in original['files'] if f['name']=='topbar-batteryindicator')
    script=script.replace(old_battery,SHA(payload['topbar-batteryindicator']))
    script=script.replace('Patchman v1.5-stable full installer','Patchman v1.5.1 full installer')
    script=script.replace('Patchman v1.5','Patchman v1.5.1')
    script=script.replace('v1.5.1.1','v1.5.1')
    write(HERE/'scripts/install.sh',script)
    for name in ('remove.sh','exec_file.sh','return-v11.sh'):
        write(HERE/'scripts'/name,allow((BASE/'scripts'/name).read_text(encoding='utf-8')) if name!='exec_file.sh' else (BASE/'scripts'/name).read_bytes())
    write(HERE/'scripts/return-stable.sh',allow((BASE/'scripts/install.sh').read_text(encoding='utf-8')))
    manifest=dict(original,version='1.5.1-stable',build='nw-a55-v1.5.1-stable',release_date='2026-11-22',values=values,files=entries)
    manifest['metadata_resources']=[dict(offset=off,slot=size,used=4+int.from_bytes(player[off:off+4],'big')) for off,size in sorted(slots.items())]
    manifest['metadata_resources'].append(dict(offset=0x65ba26,slot=2319,used=len(packed)))
    manifest['resources']=[dict(r,used=len(packed)) if r.get('offset')==0x65ba26 else r for r in original['resources']]
    manifest.pop('release',None)
    manifest['baseline_zip_sha256']=STABLE_SHA
    write(HERE/'manifest.json',json.dumps(manifest,indent=2)+'\n')
    a={f['name']:f['sha256'] for f in original['files']};b={f['name']:f['sha256'] for f in entries}
    assert set(a)==set(b) and {k for k in a if a[k]!=b[k]}=={'player','topbar-batteryindicator'}
    assert (BASE/'Patchman_NW-A55.zip').read_bytes()==archive
    print('PASS v1.5.1: original Sony full/mini scrolling; half-ring battery; Unit Information v1.5.1; unchanged audio and PEQ verification')

if __name__=='__main__':main()
