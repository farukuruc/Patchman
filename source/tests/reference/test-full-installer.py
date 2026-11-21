"""Install the complete bundle into a filesystem with NO previous Patchman.

Only hardware operations are mocked. File copying, checksums, chmod, extraction,
boot state and shell execution are real. chown is recorded, not privileged.
"""
import hashlib, importlib.util, json, pathlib, re, shlex, subprocess, unittest, tarfile, zipfile
HERE=pathlib.Path(__file__).resolve().parent.parent
PROJECT=HERE.parent.parent
WORK=PROJECT/'work/Patchman-v1.5-Final'
spec=importlib.util.spec_from_file_location('installer_fixture',PROJECT/'outputs/Patchman-GoTo/tests/test-package.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
MANIFEST=json.loads((HERE/'manifest.json').read_text())
STABLE=json.loads((WORK/'stable-manifest.json').read_text())
base.HERE=HERE;base.MANIFEST=MANIFEST;base.VALUES=MANIFEST['values']
VALUES=base.VALUES
SHA=lambda data:hashlib.sha256(data).hexdigest()

class Package(unittest.TestCase):
    mock_busybox=base.Patchman.mock_busybox
    mock_space=base.Patchman.mock_space
    installed=base.Patchman.installed

    def setup_device(self,migrate=False):
        base.Patchman.setup_device(self,False)
        self.state=self.fixture.state
        lib=self.root/'system/vendor/sony/lib/libMediaStoreServiceClient.so'
        lib.parent.mkdir(parents=True,exist_ok=True)
        lib.write_bytes((PROJECT/'work/Patchman-AlbumYears/research/native-order/binaries/vendor/sony/lib/libMediaStoreServiceClient.so').read_bytes())
        self.archive(WORK/'bundle.tar.gz')
        # This is deliberately not legacy.CassettePackage or an earlier install.
        for relative in ('system/vendor/patchman','system/vendor/sony-peq','system/vendor/sony-cassette','data/sony-peq','data/sony-album-test','contents/PEQ','contents/ARTIST-PHOTOS'):
            self.assertFalse((self.root/relative).exists(),relative)
        if migrate:
            self.archive(WORK/'return-stable.tar.gz')
            self.assertIn('SUCCESS:',self.run_script('baseline'))
            self.archive(WORK/'bundle.tar.gz')
            (self.state/'confirmed').write_text(VALUES['BUILD_ID']+'\n')

    def archive(self,path):
        self.fixture.tool('fwpchk','#!/bin/sh\ncat '+shlex.quote(str(path))+' > "$5"\ndd if=/dev/zero bs=16 count=1 >> "$5" 2>/dev/null\n')

    def mapped(self,text):
        return re.sub(r'/xbin/busybox|/system|/data|/contents|/tmp/patchman|/proc/mounts|/proc/sys/kernel/random/boot_id|/sys/',
            lambda m:str(self.root/('tools/busybox' if m[0]=='/xbin/busybox' else m[0].lstrip('/')))+('/' if m[0]=='/sys/' else ''),text)

    def run_script(self,name):
        script=self.root/(name+'-full.sh')
        source=HERE/'backups/install.sh' if name=='baseline' else HERE/'backups/v11-install.sh' if name=='v11' else HERE/'scripts'/(name+'.sh')
        script.write_text('umask 077\n'+self.mapped(source.read_text()))
        result=subprocess.run(['sh',str(script)],env=self.fixture.env,capture_output=True,text=True,timeout=45)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        log='remove' if name=='remove' else 'install'
        return (self.root/('contents/Patchman-'+log+'.log')).read_text()

    def guard(self,boot,usb=False):
        self.fixture.boot(boot)
        node=self.root/'sys/class/android_usb/android0/state'
        node.parent.mkdir(parents=True,exist_ok=True);node.write_text('CONFIGURED\n' if usb else 'DISCONNECTED\n')
        # ARM DSP/profile binary byte identities are verified by package tests.
        # Isolate shell boot policy from ARM execution, as in existing guard tests.
        body=self.mapped((WORK/'guard').read_text())
        helper=self.fixture.backend/'sony-peq-profile'
        helper.write_text('#!/bin/sh\necho test-control > "$3"\n');helper.chmod(0o755)
        body=body.replace(VALUES['PROFILE_SHA'],SHA(helper.read_bytes()))
        script=self.root/'guard-test.sh';script.write_text('umask 077\n'+body)
        result=subprocess.run(['sh',str(script)],env=self.fixture.env,capture_output=True,text=True,timeout=10)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def status(self):return (self.state/'status').read_text()
    def audio_flowed(self):
        (self.state/'runtime/cinder_mono_shim').write_text('alive\n')
        (self.state/'state/mono_shim_boots').unlink(missing_ok=True)

    def test_fresh_install_has_every_component_and_readable_qml_ancestors(self):
        self.setup_device();self.assertIn('SUCCESS:',self.run_script('install'));self.installed()
        for item in MANIFEST['files']:
            if not item['destination']:continue
            dest=item['destination'].replace('$ROOT','/system/vendor/sony-peq').replace('$PM','/system/vendor/patchman').replace('$BIN','/system/vendor/sony/bin').replace('$STATE','/data/sony-peq')
            path=self.root/dest.lstrip('/')
            self.assertEqual(SHA(path.read_bytes()),item['sha256'],item['name'])
            self.assertEqual(path.stat().st_mode&0o777,int(str(item['mode']),8),item['name'])
            # Model another UID's traversal using permission bits (fixture chown is mocked).
            for parent in path.parents:
                if parent==self.root:break
                self.assertTrue(parent.stat().st_mode&0o001,str(parent))
        self.assertEqual((self.root/'system/vendor/patchman/native-years').stat().st_mode&0o777,0o755)
        self.assertEqual((self.root/'contents/PEQ/active.txt').read_text().strip(),'off')
        self.assertEqual((self.state/'runtime/cassette-enabled.txt').read_text().strip(),'off')
        self.assertFalse((self.state/'confirmed').exists())
        self.assertEqual((self.state/'armed').read_text().strip(),VALUES['BUILD_ID'])

    def test_update_from_public_v11_and_reinstall_v15_preserve_user_data(self):
        self.setup_device()
        self.archive(HERE/'backups/v11-bundle.tar.gz')
        self.assertIn('SUCCESS:',self.run_script('v11'))
        old=json.loads((HERE/'backups/v11-manifest.json').read_text())
        old_player=next(f['sha256'] for f in old['files'] if f['name']=='player')
        self.assertEqual(SHA((self.bin/'HgrmMediaPlayerApp.album-test').read_bytes()),old_player)
        peq=self.root/'contents/PEQ';(peq/'My IEM.txt').write_text('Preamp: -4 dB\n')
        (peq/'active.txt').write_text('My IEM.txt\n')
        photos=self.root/'contents/ARTIST-PHOTOS';photos.mkdir(exist_ok=True)
        (photos/'Queen.jpg').write_bytes(b'user-photo-kept')
        (self.state/'runtime/cassette-enabled.txt').write_text('on\n')
        (self.state/'confirmed').write_text(VALUES['BUILD_ID']+'\n')
        self.archive(WORK/'bundle.tar.gz')
        for attempt in range(2):
            self.assertIn('Preserved verified PEQ backend state',self.run_script('install'))
            for item in MANIFEST['files']:
                if not item['destination']:continue
                dest=item['destination'].replace('$ROOT','/system/vendor/sony-peq').replace('$PM','/system/vendor/patchman').replace('$BIN','/system/vendor/sony/bin').replace('$STATE','/data/sony-peq')
                self.assertEqual(SHA((self.root/dest.lstrip('/')).read_bytes()),item['sha256'])
            self.assertEqual((peq/'active.txt').read_text(),'My IEM.txt\n')
            self.assertEqual((peq/'My IEM.txt').read_text(),'Preamp: -4 dB\n')
            self.assertEqual((photos/'Queen.jpg').read_bytes(),b'user-photo-kept')
            self.assertEqual((self.state/'runtime/cassette-enabled.txt').read_text(),'on\n')
            self.assertEqual((self.state/'confirmed').read_text().strip(),VALUES['BUILD_ID'])
            self.assertEqual((self.state/'runtime/album-sort.txt').read_text(),'newest\n')
            self.assertEqual((self.root/'system/vendor/patchman/version.txt').read_text().strip(),'Patchman v1.5')

    def test_v15_return_to_public_v11_preserves_data_and_can_update_again(self):
        self.setup_device();self.run_script('install')
        (self.state/'confirmed').write_text(VALUES['BUILD_ID']+'\n')
        peq=self.root/'contents/PEQ';(peq/'My IEM.txt').write_text('Preamp: -4 dB\n')
        (peq/'active.txt').write_text('My IEM.txt\n')
        photos=self.root/'contents/ARTIST-PHOTOS';photos.mkdir(exist_ok=True)
        (photos/'Queen.jpg').write_bytes(b'keep-photo')
        music=self.root/'contents/MUSIC';music.mkdir(exist_ok=True)
        (music/'keep.flac').write_bytes(b'keep-music')
        (self.state/'runtime/cassette-enabled.txt').write_text('on\n')
        (self.state/'runtime/album-sort.txt').write_text('za\n')
        self.archive(WORK/'return-v11.tar.gz')
        log=self.run_script('return-v11')
        self.assertIn('SUCCESS: Patchman v1.1 restored;',log)
        self.assertIn('Preserved verified PEQ backend state',log)
        old=json.loads((HERE/'backups/v11-manifest.json').read_text())
        for item in old['files']:
            if not item['destination']:continue
            dest=item['destination'].replace('$ROOT','/system/vendor/sony-peq').replace('$PM','/system/vendor/patchman').replace('$BIN','/system/vendor/sony/bin').replace('$STATE','/data/sony-peq')
            self.assertEqual(SHA((self.root/dest.lstrip('/')).read_bytes()),item['sha256'],item['name'])
        self.assertEqual((self.root/'system/vendor/patchman/version.txt').read_text().strip(),'Patchman v1.1')
        for upgrade in [False,True]:
            if upgrade:
                self.archive(WORK/'bundle.tar.gz');self.assertIn('SUCCESS:',self.run_script('install'))
            self.assertEqual((peq/'active.txt').read_text(),'My IEM.txt\n')
            self.assertEqual((peq/'My IEM.txt').read_text(),'Preamp: -4 dB\n')
            self.assertEqual((photos/'Queen.jpg').read_bytes(),b'keep-photo')
            self.assertEqual((music/'keep.flac').read_bytes(),b'keep-music')
            self.assertEqual((self.state/'runtime/cassette-enabled.txt').read_text(),'on\n')
            self.assertEqual((self.state/'runtime/album-sort.txt').read_text(),'za\n')
            self.assertEqual((self.state/'confirmed').read_text().strip(),VALUES['BUILD_ID'])

    def test_sort_preference_is_readable_and_preserved_on_upgrade_and_return(self):
        self.setup_device();self.assertIn('SUCCESS:',self.run_script('install'))
        preference=self.state/'runtime/album-sort.txt'
        self.assertEqual(preference.read_text(),'newest\n')
        self.assertEqual(preference.stat().st_mode&0o777,0o666)
        preference.write_text('za\n')
        (self.state/'confirmed').write_text(VALUES['BUILD_ID']+'\n')
        self.assertIn('SUCCESS:',self.run_script('install'))
        self.assertEqual(preference.read_text(),'za\n')
        self.archive(WORK/'return-stable.tar.gz')
        self.assertIn('SUCCESS:',self.run_script('return-stable'))
        for f in STABLE['files']:
            if not f['destination']:continue
            dest=f['destination'].replace('$ROOT','/system/vendor/sony-peq').replace('$PM','/system/vendor/patchman').replace('$BIN','/system/vendor/sony/bin').replace('$STATE','/data/sony-peq')
            self.assertEqual(SHA((self.root/dest.lstrip('/')).read_bytes()),f['sha256'],f['name'])
        self.assertEqual(preference.read_text(),'za\n')

    def test_multiple_usb_boots_do_not_consume_first_cable_free_trial(self):
        self.setup_device();self.run_script('install')
        for i in range(3):
            self.guard('usb-'+str(i),True)
            self.assertFalse((self.state/'pending').exists());self.assertFalse((self.state/'off').exists())
            self.assertIn('verification deferred',self.status())
            (self.state/'state/mono_shim_boots').write_text('1\n')
        self.guard('first-free')
        self.assertTrue((self.state/'pending').exists());self.assertFalse((self.state/'confirmed').exists())
        self.audio_flowed();self.guard('second-free')
        self.assertEqual((self.state/'confirmed').read_text().strip(),VALUES['BUILD_ID'])
        self.assertFalse((self.state/'off').exists())

    def test_cable_free_trial_without_audio_still_rolls_back(self):
        self.setup_device();self.run_script('install');self.guard('first-free');self.guard('second-free')
        self.assertIn('trial-did-not-reach-audio',self.status())
        self.assertEqual(SHA((self.bin/'hagodaemon').read_bytes()),VALUES['ORIGINAL_HAGO'])

    def test_usb_boot_cannot_hide_previous_failed_cable_free_trial(self):
        self.setup_device();self.run_script('install');self.guard('first-free');self.guard('usb-after-failure',True)
        self.assertTrue((self.state/'off').exists());self.assertIn('trial-did-not-reach-audio',self.status())

    def test_known_good_audio_confirmation_is_preserved_on_upgrade(self):
        self.setup_device(True)
        selection=self.root/'contents/PEQ/active.txt';selection.write_text('My IEM.txt\n')
        (selection.parent/'My IEM.txt').write_text('custom profile')
        cassette=self.state/'runtime/cassette-enabled.txt';cassette.write_text('on\n')
        log=self.run_script('install')
        self.assertIn('Preserved verified PEQ backend state',log)
        self.assertEqual(selection.read_text(),'My IEM.txt\n');self.assertEqual(cassette.read_text(),'on\n')
        self.assertEqual((self.state/'confirmed').read_text().strip(),VALUES['BUILD_ID'])
        self.assertEqual((self.root/'system/vendor/patchman/native-years').stat().st_mode&0o777,0o755)


    def test_confirmed_backend_still_rejects_repeated_audio_load_failure(self):
        self.setup_device();self.run_script('install')
        (self.state/'confirmed').write_text(VALUES['BUILD_ID']+'\n')
        (self.state/'state/mono_shim_boots').write_text('2\n')
        self.guard('failed-load')
        self.assertTrue((self.state/'off').exists());self.assertIn('repeated-audio-load-failure',self.status())

    def test_fresh_install_remove_and_exact_stable_return(self):
        self.setup_device();self.run_script('install')
        (self.root/'contents/PEQ/My IEM.txt').write_text('keep')
        self.archive(WORK/'return-stable.tar.gz')
        self.assertIn('SUCCESS: Patchman confirmed Go to UI restored;',self.run_script('return-stable'))
        for name,dest in [('guard',self.fixture.backend/'boot.sh'),('player',self.bin/'HgrmMediaPlayerApp.album-test')]:
            expected=next(f['sha256'] for f in STABLE['files'] if f['name']==name)
            self.assertEqual(SHA(dest.read_bytes()),expected)
        self.assertIn('SUCCESS:',self.run_script('remove'));base.Patchman.native(self)
        self.assertEqual((self.root/'contents/PEQ/My IEM.txt').read_text(),'keep')

    def test_unknown_player_rejected_with_actual_hash_before_activation(self):
        self.setup_device();p=self.bin/'HgrmMediaPlayerApp';p.write_bytes(b'another Walkman One player')
        log=self.run_script('install')
        self.assertIn('ERROR: Unsupported Walkman One player version',log)
        self.assertIn('actual='+SHA(p.read_bytes()),log)
        self.assertFalse((self.root/'system/vendor/patchman').exists())
        self.assertEqual(SHA((self.bin/'hagodaemon').read_bytes()),VALUES['ORIGINAL_HAGO'])

    def test_corrupt_bundle_and_low_space_do_not_activate(self):
        self.setup_device();self.fixture.tool('fwpchk','#!/bin/sh\nprintf corrupt > "$5"\n')
        self.assertIn('ERROR: Bundle checksum',self.run_script('install'))
        self.assertFalse((self.bin/'sony-album-launch.sh').exists())
        self.archive(WORK/'bundle.tar.gz');self.mock_space('data',0)
        self.assertIn('ERROR: Insufficient space',self.run_script('install'))
        self.assertFalse((self.bin/'sony-album-launch.sh').exists())

    def test_only_native_header_and_logging_changed_confirmed_return_exact(self):
        old={f['name']:f['sha256'] for f in STABLE['files']};new={f['name']:f['sha256'] for f in MANIFEST['files']}
        self.assertEqual(set(new)-set(old),{'continuous-title'});self.assertEqual({k for k in old if old[k]!=new[k]},{'player'})
        self.assertEqual(SHA((WORK/'return-stable.tar.gz').read_bytes()),STABLE['values']['BUNDLE_SHA'])
        body=(HERE/'scripts/install.sh').read_text()
        for f in MANIFEST['files']:self.assertIn('hash_is "$TMP/files/'+f['name']+'" "'+f['sha256']+'"',body)
if __name__=='__main__':unittest.main(verbosity=2)
