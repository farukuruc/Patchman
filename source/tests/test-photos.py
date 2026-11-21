import json,pathlib,re,runpy,sqlite3,subprocess,sys,tempfile,unittest,urllib.parse
HERE=pathlib.Path(__file__).resolve().parent.parent
PROJECT=HERE.parent.parent
PROGRAM=sys.argv.pop(1)
previous=runpy.run_path(str(HERE/'tests/test-years.py'))
previous['Cache'].run_builder.__globals__['PROGRAM']=PROGRAM
class Metadata(previous['Cache']):pass
class Photos(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=pathlib.Path(self.tmp.name);self.db=self.root/'db';self.photos=self.root/'ARTIST-PHOTOS';self.photos.mkdir();self.out=self.root/'runtime';self.out.mkdir()
        previous['fixture'](self.db)
        with sqlite3.connect(self.db) as c:c.execute('UPDATE albumartists SET value=? WHERE id=25',('Pink Floyd',))
    def image(self,artist,ext='.jpg',folder=None):
        p=self.photos/(folder or '')/(artist+ext);p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'test image candidate');return p
    def run_builder(self):
        p=subprocess.run([PROGRAM,'once',str(self.db),str(self.out),str(self.photos)],capture_output=True,text=True,timeout=8)
        self.assertEqual(p.returncode,0,p.stderr)
        self.last_log=p.stdout
        js=(self.out/'AlbumYearCache.js').read_text(encoding='utf-8')
        return json.loads(re.search(r'var artistPhotos=(\{.*?\})\n',js).group(1))
    def test_exact_metadata_name_and_internal_flat_path_read_only(self):
        target=self.image('Pink Floyd');self.image('Pink Floyd Live');before=self.db.read_bytes()
        images=self.run_builder();self.assertEqual(set(images),{'$2214592537'})
        self.assertEqual(pathlib.Path(urllib.parse.unquote(urllib.parse.urlsplit(images['$2214592537']).path)),target)
        self.assertIn('Pink%20Floyd',images['$2214592537']);self.assertEqual(self.db.read_bytes(),before);self.assertEqual(target.read_bytes(),b'test image candidate')
    def test_missing_photo_folder_keeps_years(self):
        self.assertEqual(self.run_builder(),{});first=(self.out/'album-years.bin').read_bytes()
        self.photos.rmdir();self.assertEqual(self.run_builder(),{});self.assertEqual((self.out/'album-years.bin').read_bytes(),first)
    def test_png_and_jpg_priority(self):
        png=self.image('Pink Floyd','.png');images=self.run_builder();self.assertTrue(images['$2214592537'].endswith('.png'))
        jpg=self.image('Pink Floyd','.jpg');images=self.run_builder();self.assertTrue(images['$2214592537'].endswith('.jpg'));self.assertTrue(png.exists() and jpg.exists())
    def test_near_name_unrelated_album_and_wrong_folder_do_not_match(self):
        self.image('Pink Floyd Live');self.image('The Wall');self.image('Pink Floyd',folder='Other')
        self.assertEqual(self.run_builder(),{})
    def test_reserved_characters_have_no_path_traversal(self):
        with sqlite3.connect(self.db) as c:c.execute('UPDATE albumartists SET value=? WHERE id=25',('AC/DC',))
        target=self.image('AC%2FDC','.png');images=self.run_builder();self.assertIn('AC%252FDC',images['$2214592537'])
        self.assertEqual(pathlib.Path(urllib.parse.unquote(urllib.parse.urlsplit(images['$2214592537']).path)),target)
    def test_empty_and_over_limit_candidates_are_ignored(self):
        p=self.image('Pink Floyd');p.write_bytes(b'');self.assertEqual(self.run_builder(),{})
        with p.open('wb') as f:f.truncate(8*1024*1024+1)
        self.assertEqual(self.run_builder(),{})
    def test_root_diagnostic_is_small_and_read_only(self):
        target=self.image('Pink Floyd');target.unlink();before=self.db.read_bytes()
        self.assertEqual(self.run_builder(),{})
        self.assertIn('internal-flat-v1',self.last_log);self.assertIn('available=1',self.last_log)
        self.assertLess(len(self.last_log.encode()),26000);self.assertEqual(self.db.read_bytes(),before)
if __name__=='__main__':unittest.main(verbosity=2)
