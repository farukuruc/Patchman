import hashlib,json,pathlib,re,tarfile,unittest,zlib
HERE=pathlib.Path(__file__).resolve().parent.parent
PROJECT=HERE.parent.parent
BASE=HERE.parent/'Patchman-v1.5-Final'
WORK=PROJECT/'work/Patchman-v1.5.1'
SHA=lambda b:hashlib.sha256(b).hexdigest()

class Preparation(unittest.TestCase):
    def test_scoped_player_and_payload_changes(self):
        before=(PROJECT/'work/Patchman-v1.5-Final/player').read_bytes();after=(WORK/'player').read_bytes()
        with tarfile.open(BASE/'backups/bundle.tar.gz') as t:native=t.extractfile('player').read()
        cursor=0
        slots={0x6315a1:1469,0x5ec469:1943,0x61f1db:4333,0x65ba26:2319}
        for off,size in sorted(slots.items()):
            self.assertEqual(after[cursor:off],before[cursor:off])
            if off!=0x65ba26:self.assertEqual(after[off:off+size],native[off:off+size])
            cursor=off+size
        self.assertEqual(after[cursor:],before[cursor:]);self.assertEqual(len(before),len(after))
        a=json.loads((WORK/'stable-manifest.json').read_text());b=json.loads((HERE/'manifest.json').read_text())
        old={f['name']:f['sha256'] for f in a['files']};new={f['name']:f['sha256'] for f in b['files']}
        self.assertEqual(set(old),set(new));self.assertEqual({k for k in old if old[k]!=new[k]},{'player','topbar-batteryindicator'})
        self.assertEqual(a['values']['BUILD_ID'],b['values']['BUILD_ID'])
        for key in ('SHIM_SHA','PROFILE_SHA','BOOT_SHA','WRAPPER_SHA'):self.assertEqual(a['values'][key],b['values'][key])

    def test_original_marquee_and_unit_version(self):
        player=(WORK/'player').read_bytes();original=(PROJECT/'work/walkman-one/HgrmMediaPlayerApp').read_bytes();off=0x61f1db
        n=int.from_bytes(original[off:off+4],'big');m=int.from_bytes(player[off:off+4],'big')
        self.assertEqual(original[off+4:off+4+n],player[off+4:off+4+m])
        for off in (0x6315a1,0x5ec469):
            n=int.from_bytes(player[off:off+4],'big');self.assertNotIn(b'continuous:',zlib.decompress(player[off+8:off+4+n]))
        off=0x65ba26;n=int.from_bytes(player[off:off+4],'big')
        self.assertIn(b'info: "Patchman v1.5.1"',zlib.decompress(player[off+8:off+4+n]))

    def test_checksums_version_and_distribution(self):
        m=json.loads((HERE/'manifest.json').read_text())
        with tarfile.open(WORK/'bundle.tar.gz') as t:
            for f in m['files']:self.assertEqual(SHA(t.extractfile(f['name']).read()),f['sha256'])
        script=(HERE/'scripts/install.sh').read_text()
        self.assertIn(m['values']['BUNDLE_SHA'],script)
        self.assertIn('Patchman v1.5.1" > "$PM/version.txt"',script)
        self.assertNotIn('v1.5.1.1',script)
        for f in m['files']:self.assertIn('hash_is "$TMP/files/'+f['name']+'" "'+f['sha256']+'"',script)
        self.assertNotIn('pack ReturnTo',(HERE/'build.sh').read_text())
        self.assertEqual(SHA((BASE/'Patchman_NW-A55.zip').read_bytes()),'defa2b99758edc4e7dcd1da9bdf4e5196efc6152bc6dc639b7c052d86a7e3a78')

    def test_readme_internal_links(self):
        text=(HERE/'README.md').read_text(encoding='utf-8')
        anchors={re.sub(r'[^\w\- ]','',s.lower()).replace(' ','-') for s in re.findall(r'^#+ (.*)$',text,re.M)}
        for target in re.findall(r'\]\(#([^)]*)\)',text):self.assertIn(target,anchors)
        self.assertNotIn('ReturnToV1.1/',text)

if __name__=='__main__':unittest.main(verbosity=2)
