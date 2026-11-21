"""Opt-in continuous title with exact return to the confirmed Go to UI."""
import base64,gzip,hashlib,io,json,pathlib,re,tarfile,zipfile,zlib
HERE=pathlib.Path(__file__).resolve().parent
PROJECT=HERE.parent.parent
WORK=PROJECT/'work/Patchman-v1.5-Final'
CONFIRMED='0c6fcf30ef48ccc2ff029d777d71b13cf633f26a6019ef4945c7cce777c8cea3'
SHA=lambda b:hashlib.sha256(b).hexdigest()
def write(p,s):
    p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(s.encode('utf-8'))
def once(s,a,b):
    assert s.count(a)==1,repr(a)
    return s.replace(a,b,1)
def compact(s):
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S)
    s=re.sub(r'(?m)(?:^[ \t]*|[ \t]+)//[^\n]*','',s)
    return '\n'.join(x.strip() for x in s.splitlines() if x.strip())+'\n'
def patch_player(original):
    result=bytearray(original);changes=[]
    def resource(off,edit,compressed=True,minify=True):
        n=int.from_bytes(original[off:off+4],'big');slot={0x6315a1:1469,0x5ec469:1943,0x61f1db:4333,0x65ba26:2319}[off]
        raw=zlib.decompress(original[off+8:off+4+n]) if compressed else original[off+4:off+4+n]
        text=compact(edit(compact(raw.decode('utf-8')))) if minify else edit(raw.decode('utf-8'))
        data=text.encode()
        body=len(data).to_bytes(4,'big')+zlib.compress(data,9) if compressed else data
        packed=len(body).to_bytes(4,'big')+body
        assert len(packed)<=slot,(hex(off),len(packed),slot)
        result[off:off+slot]=packed.ljust(slot,b'\0')
        changes.append(dict(offset=off,slot=slot,used=len(packed)))
        write(WORK/('%x.qml'%off),text)
    def metadata(text):
        return once(text,'id: labelTitle\n','id: labelTitle\ncontinuous: base.compactMetadata\n')
    resource(0x6315a1,metadata)
    resource(0x5ec469,lambda text:once(text,'id: playTitleText\n','id: playTitleText\ncontinuous: true\n'))
    def marquee(text):
        text=once(text,'id: base','id: base\nproperty bool continuous: false\nproperty string loopText: p.mainText\nreadonly property bool useLoop: continuous && loopLoader.status === Loader.Ready\nonUseLoopChanged: checkMarqueeScroll()')
        for marker in ['visible: !p.mainTextDisp && isUseMarquee && p.strBufJudge','visible: p.mainTextDisp && ( p.strBufJudge || !isUseMarquee )','visible: !p.strBufJudge','visible: p.strBufJudge && marqueeScroll.running','visible: p.strBufJudge\n']:
            text=once(text,marker,marker.replace('visible: ','visible: !base.useLoop && (').rstrip()+')'+('\n' if marker.endswith('\n') else ''))
        text=once(text,'fixingTime.running = isUseMarquee ? p.strBufJudge : false','fixingTime.running = !base.useLoop && isUseMarquee ? p.strBufJudge : false')
        text=once(text,'function checkMarqueeScroll() {','function checkMarqueeScroll() {\nif (base.useLoop) { marqueeScroll.stop(); fixingTime.stop(); return }')
        assert text.rstrip().endswith('}')
        return text.rstrip()[:-1]+\
            '\nLoader { id: loopLoader; anchors.fill: parent; active: base.continuous && base.visible; source: "file:///system/vendor/sony-peq/ui/ContinuousTitle.qml"; onLoaded: item.titleHost = base }\n}\n'
    resource(0x61f1db,marquee,False)
    resource(0x65ba26,lambda text:once(text,'info: "Patchman v1.1"','info: "Patchman v1.5"'),minify=False)
    cursor=0
    for c in sorted(changes,key=lambda x:x['offset']):
        assert result[cursor:c['offset']]==original[cursor:c['offset']]
        cursor=c['offset']+c['slot']
    assert result[cursor:]==original[cursor:] and len(result)==len(original)
    assert 46+20+11+43+5+37+17==179
    return bytes(result),changes

def allow(s,player):
    # Also accept the spacing ZIP built just before the smaller controls.
    prior='5dac3d022189a3e940b0cc8fb7ecdb93baebf82c01dc35c86638a72c02397830'
    previous='9f4dc0e4b9d53c4847d63c2226bc72c30276c2373b6268424f83b0c1e5e5b6c9'
    prior_shuffle='eb0ac7270fc7bca791288d632ccab35c75e61e0884a329a965845b709ba037da'
    prior_repeat='a3856572beeea8c39d29f0b0eebe3b1b040e645121ba728ff7a7eab11efc8b0e'
    prior_continuous='3e7bdb894cf9a1a8599f04651168fdcfe524c5c829113900b7b6e99f45413a2d'
    lines=''.join('  hash_is "$1" "'+d+'" && return 0\n' for d in sorted({player,prior,previous,prior_shuffle,prior_repeat,prior_continuous}))
    return once(s,'known_player() {\n','known_player() {\n'+lines)
def main():
    WORK.mkdir(parents=True,exist_ok=True)
    archive=(HERE/'backups/confirmed.zip').read_bytes();assert SHA(archive)==CONFIRMED
    prefix='Patchman-ShuffleSpacing/'
    with zipfile.ZipFile(io.BytesIO(archive)) as z:
        assert z.testzip() is None
        base=json.loads(z.read(prefix+'manifest.json'))
        for line in z.read(prefix+'SHA256SUMS.txt').decode().splitlines():
            digest,name=line.split(None,1);assert SHA(z.read(prefix+name))==digest
        for action,origin in [('Install','Install'),('Remove','Remove'),('ReturnToConfirmed','Install'),('ReturnToV1.1','Install')]:
            start=prefix+origin+'/'
            for name in z.namelist():
                if name.startswith(start) and not name.endswith('/') and not name.endswith('.UPG'):
                    p=HERE/action/name[len(start):];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(z.read(name))
            title='Patchman v1.5-stable - '+action
            p=HERE/action/'Data/Device/SWUpdate.xml'
            p.write_bytes(re.sub(rb'<Product>.*?</Product>',('<Product>'+title+'</Product>').encode(),p.read_bytes()))
            notice=title+'\r\n\r\nSony NW-A55 with compatible Walkman One 3.02. '
            notice+=('Continuous leftward long-title scrolling on Now Playing and the mini-player. Short titles stay centered. Screen-off and hidden titles stop animation. Existing v1.1 users can install directly. New users must first complete the stock and fresh Walkman One setup in README.md. ' if action=='Install' else 'Restores the exact last device-confirmed UI, including the new Go to, shuffle and repeat icons and all confirmed spacing. ' if action=='ReturnToConfirmed' else 'Removes active Patchman features; keeps Walkman One. ')
            notice+='Music, profiles and preferences are kept. Disconnect USB and fully power off and on after the update. Read README.md for the update and first-install steps.\r\n'
            if action=='Install':
                notice=(HERE/'installer-notice.txt').read_text(encoding='utf-8').replace('\n','\r\n')
            if action=='ReturnToV1.1':
                notice=title+'\r\n\r\nRestores the complete public Patchman v1.1 feature payload on this NW-A55 with supported Walkman One 3.02. Use this if v1.5 causes a problem. Do not run Remove first.\r\n\r\nThis restores the v1.1 player, interface and native album ordering. Sorting Options and the new v1.5 top bar, battery percentage and continuous titles will no longer be active. Unit Information will show Patchman v1.1.\r\n\r\nMusic, PEQ profiles, artist photos and supported preferences are kept. A valid existing PEQ playback check is kept. This does not install stock Sony firmware or remove Walkman One.\r\n\r\nWhen complete, disconnect USB and fully power the player off and on. See README.md for the steps.\r\n'
            for p in (HERE/action/'Data/Device').glob('disclaimer_*.txt'):p.write_bytes(b'\xff\xfe'+notice.encode('utf-16-le'))
    frozen=(HERE/'backups/bundle.tar.gz').read_bytes();assert SHA(frozen)==base['values']['BUNDLE_SHA']
    confirmed=base;recovery=frozen
    with tarfile.open(fileobj=io.BytesIO(frozen),mode='r:gz') as t:payload={f['name']:t.extractfile(f['name']).read() for f in base['files']}
    for f in base['files']:assert SHA(payload[f['name']])==f['sha256']
    payload['player'],changes=patch_player(payload['player'])
    payload['continuous-title']=(HERE/'source/ContinuousTitle.qml').read_bytes()
    entries=[dict(f) for f in base['files']]+[dict(name='continuous-title',destination='$ROOT/ui/ContinuousTitle.qml',mode='644')];buf=io.BytesIO()
    with tarfile.open(fileobj=buf,mode='w',format=tarfile.USTAR_FORMAT) as t:
        for f in entries:
            data=payload[f['name']];(WORK/f['name']).write_bytes(data);f.update(source=str(WORK/f['name']),sha256=SHA(data))
            info=tarfile.TarInfo(f['name']);info.size=len(data);info.mode=int(str(f['mode']),8);info.mtime=0;t.addfile(info,io.BytesIO(data))
    bundle=gzip.compress(buf.getvalue(),compresslevel=9,mtime=0)
    (WORK/'bundle.tar.gz').write_bytes(bundle);(WORK/'return-stable.tar.gz').write_bytes(recovery)
    write(WORK/'stable-manifest.json',json.dumps(confirmed,indent=2)+'\n')
    values=dict(base['values'],BUNDLE_SHA=SHA(bundle),BUNDLE_SIZE=str(len(bundle)))
    values['CONTENTS_KIB']=str((len(bundle)+1088*1024+1023)//1024)
    digest=SHA(payload['player']);old=next(f['sha256'] for f in base['files'] if f['name']=='player')
    script=allow((HERE/'backups/install.sh').read_text(encoding='utf-8'),digest)
    assert base['values']['BUNDLE_SHA'] in script
    script=once(script,'hash_is "$TMP/files/player" "'+old+'"','hash_is "$TMP/files/player" "'+digest+'"')
    script=script.replace(base['values']['BUNDLE_SHA'],values['BUNDLE_SHA']).replace('head -c '+base['values']['BUNDLE_SIZE']+' ','head -c '+values['BUNDLE_SIZE']+' ')
    script=script.replace('require_space /contents '+base['values']['CONTENTS_KIB'],'require_space /contents '+values['CONTENTS_KIB'])
    script=script.replace('Patchman shuffle, repeat, Go to and title spacing test installer','Patchman v1.5-stable full installer')
    script=script.replace('Patchman shuffle-repeat-goto-spacing-test-3','Patchman v1.5')
    member=base['values']['PAYLOAD_MEMBERS']
    assert member in script
    script=script.replace(member,member+' continuous-title')
    checksum='hash_is "$TMP/files/continuous-title" "'+SHA(payload['continuous-title'])+'" || fail "Payload checksum: continuous-title"\n'
    marker='hash_is "$TMP/files/player"'
    at=script.index(marker);script=script[:at]+checksum+script[at:]
    marker='put "$TMP/files/player" "$BIN/HgrmMediaPlayerApp.album-test" 755 || fail "Stage player"'
    script=once(script,marker,'put "$TMP/files/continuous-title" "$ROOT/ui/ContinuousTitle.qml" 644 || fail "Stage continuous title"\n'+marker)
    values['PAYLOAD_MEMBERS']=member+' continuous-title'
    values['SYSTEM_KIB']=str(int(base['values']['SYSTEM_KIB'])+16)
    script=once(script,'require_space /system '+base['values']['SYSTEM_KIB'],'require_space /system '+values['SYSTEM_KIB'])
    write(HERE/'scripts/install.sh',script)
    restore=allow((HERE/'backups/install.sh').read_text(encoding='utf-8'),digest)
    restore=restore.replace('Patchman shuffle, repeat, Go to and title spacing test installer','Patchman return to confirmed Go to UI installer').replace('SUCCESS: Patchman full installer completed;','SUCCESS: Patchman confirmed Go to UI restored;')
    write(HERE/'scripts/return-stable.sh',restore)
    v11=json.loads((HERE/'backups/v11-manifest.json').read_text())
    v11bundle=(HERE/'backups/v11-bundle.tar.gz').read_bytes()
    assert SHA(v11bundle)==v11['values']['BUNDLE_SHA']
    with tarfile.open(fileobj=io.BytesIO(v11bundle),mode='r:gz') as t:
        assert set(t.getnames())=={f['name'] for f in v11['files']}
        for f in v11['files']:assert SHA(t.extractfile(f['name']).read())==f['sha256']
    (WORK/'return-v11.tar.gz').write_bytes(v11bundle)
    return_v11=allow((HERE/'backups/v11-install.sh').read_text(encoding='utf-8'),digest)
    launcher=SHA(payload['launcher'])
    return_v11=once(return_v11,'known_launcher() {\n','known_launcher() {\n  hash_is "$1" "'+launcher+'" && return 0\n')
    return_v11=return_v11.replace('Patchman v1.1 full clean installer test','Patchman return to v1.1-stable installer').replace('Patchman 1.1-photo-no-flash','Patchman v1.1').replace('SUCCESS: Patchman full installer completed;','SUCCESS: Patchman v1.1 restored;')
    write(HERE/'scripts/return-v11.sh',return_v11)
    write(HERE/'scripts/remove.sh',allow((HERE/'backups/remove.sh').read_text(encoding='utf-8'),digest))
    write(HERE/'scripts/exec_file.sh',(HERE/'backups/exec_file.sh').read_text(encoding='utf-8'))
    manifest=dict(base,version='1.5-stable',build='nw-a55-v1.5-stable',release_date='2026-11-21',values=values,files=entries)
    manifest['resources']=[dict(r,used=next(c['used'] for c in changes if c['offset']==r['offset'])) if r['name']=='unit-info' else r for r in base['resources']]
    manifest['metadata_resources']=changes
    write(HERE/'manifest.json',json.dumps(manifest,indent=2)+'\n')
    print('PASS continuous title: four scoped resources; Unit Information Patchman v1.5; native fallback; exact confirmed Go to UI recovery; unchanged audio and header')
if __name__=='__main__':main()
