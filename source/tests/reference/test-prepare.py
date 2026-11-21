import hashlib,json,pathlib,tarfile,unittest,zlib
HERE=pathlib.Path(__file__).resolve().parent.parent
WORK=HERE.parent.parent/'work/Patchman-v1.5-Final'
SHA=lambda b:hashlib.sha256(b).hexdigest()

class Preparation(unittest.TestCase):
    def test_scoped_changes_and_complete_payload(self):
        old=json.loads((WORK/'stable-manifest.json').read_text())
        new=json.loads((HERE/'manifest.json').read_text())
        a={f['name']:f['sha256'] for f in old['files']};b={f['name']:f['sha256'] for f in new['files']}
        self.assertEqual(set(b)-set(a),{'continuous-title'})
        self.assertEqual({k for k in a if a[k]!=b[k]},{'player'})
        with tarfile.open(HERE/'backups/bundle.tar.gz','r:gz') as t:before=t.extractfile('player').read()
        after=(WORK/'player').read_bytes();cursor=0
        self.assertEqual(len(before),len(after))
        self.assertEqual({c['offset'] for c in new['metadata_resources']},{0x6315a1,0x5ec469,0x61f1db,0x65ba26})
        for c in sorted(new['metadata_resources'],key=lambda c:c['offset']):
            self.assertEqual(before[cursor:c['offset']],after[cursor:c['offset']])
            self.assertLessEqual(c['used'],c['slot']);cursor=c['offset']+c['slot']
        self.assertEqual(before[cursor:],after[cursor:])
        for off,marker in [(0x6315a1,'continuous: base.compactMetadata\n'),(0x5ec469,'continuous: true\n')]:
            n=int.from_bytes(before[off:off+4],'big');original=zlib.decompress(before[off+8:off+4+n]).decode()
            patched=(WORK/('%x.qml'%off)).read_text(encoding='utf-8')
            self.assertEqual(patched.replace(marker,''),original)
        off=0x65ba26;n=int.from_bytes(before[off:off+4],'big')
        original=zlib.decompress(before[off+8:off+4+n]).decode()
        patched=(WORK/'65ba26.qml').read_text(encoding='utf-8')
        self.assertEqual(patched.replace('Patchman v1.5','Patchman v1.1'),original)
        self.assertEqual(patched.count('Patchman v1.5'),1)
        with tarfile.open(WORK/'bundle.tar.gz','r:gz') as t:
            self.assertEqual(set(t.getnames()),set(b))
            for f in new['files']:self.assertEqual(SHA(t.extractfile(f['name']).read()),f['sha256'])

    def test_exact_latest_checkpoint_return_and_dependency_staging(self):
        old=json.loads((WORK/'stable-manifest.json').read_text())
        new=json.loads((HERE/'manifest.json').read_text())
        self.assertEqual(old['version'],'1.5-shuffle-repeat-goto-spacing-test-3')
        self.assertEqual((WORK/'return-stable.tar.gz').read_bytes(),(HERE/'backups/bundle.tar.gz').read_bytes())
        self.assertEqual(SHA((WORK/'return-stable.tar.gz').read_bytes()),'bd506500931861516ff82d90627512267ab41f1c4a49a8edf07c17dab0088a2d')
        digest=next(f['sha256'] for f in new['files'] if f['name']=='player')
        for action in ('install','return-stable','remove'):self.assertIn(digest,(HERE/'scripts'/(action+'.sh')).read_text())
        script=(HERE/'scripts/install.sh').read_text()
        self.assertIn(SHA((HERE/'source/ContinuousTitle.qml').read_bytes()),script)
        dependency='put "$TMP/files/continuous-title" "$ROOT/ui/ContinuousTitle.qml" 644'
        self.assertLess(script.index(dependency),script.index('put "$TMP/files/player"'))
        self.assertEqual(old['values']['BUILD_ID'],new['values']['BUILD_ID'])
        marquee=(WORK/'61f1db.qml').read_text()
        self.assertIn('property bool continuous: false',marquee)
        self.assertIn('loopLoader.status === Loader.Ready',marquee)
        self.assertIn('!base.useLoop',marquee)
        self.assertIn('active: base.continuous && base.visible',marquee)

    def test_public_v11_recovery_exact_payload_and_known_v15_hashes(self):
        old=json.loads((HERE/'backups/v11-manifest.json').read_text())
        current=json.loads((HERE/'manifest.json').read_text())
        data=(WORK/'return-v11.tar.gz').read_bytes()
        self.assertEqual(data,(HERE/'backups/v11-bundle.tar.gz').read_bytes())
        self.assertEqual(SHA(data),old['values']['BUNDLE_SHA'])
        script=(HERE/'scripts/return-v11.sh').read_text()
        for name in ['player','launcher']:
            self.assertIn(next(f['sha256'] for f in current['files'] if f['name']==name),script)
        for item in old['files']:
            self.assertIn('hash_is "$TMP/files/'+item['name']+'" "'+item['sha256']+'"',script)
        with tarfile.open(WORK/'return-v11.tar.gz') as t:
            self.assertEqual(set(t.getnames()),{f['name'] for f in old['files']})
            for item in old['files']:self.assertEqual(SHA(t.extractfile(item['name']).read()),item['sha256'])
        self.assertIn('Patchman v1.1" > "$PM/version.txt"',script)

if __name__=='__main__':unittest.main(verbosity=2)
