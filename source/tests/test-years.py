import json,pathlib,sqlite3,struct,subprocess,sys,tempfile,unittest,re
PROGRAM=sys.argv.pop(1) if __name__=='__main__' else None
def fixture(db):
    with sqlite3.connect(db) as c:
        c.executescript('''CREATE TABLE object_body(media_type,albumartist_id,album_id,releaseyear_id);
CREATE TABLE albumartists(id PRIMARY KEY,value UNIQUE); CREATE TABLE releaseyears(id PRIMARY KEY,value);
INSERT INTO albumartists VALUES(25,'Kate Bush'),(26,'Other'),(27,'Tied');
INSERT INTO releaseyears VALUES(1,1979),(2,2016),(3,0),(4,2020);
INSERT INTO object_body VALUES(1,25,1,1),(1,25,2,2),(1,25,3,3),(1,25,4,1),(1,25,4,2),
(1,26,1,4),(1,26,2,1),(1,26,3,3),(1,27,1,1),(1,27,2,1),(1,27,3,3);
''')
def checksum(data):
    result=2166136261
    for value in data:result=((result^value)*16777619)&0xffffffff
    return result
class Cache(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=pathlib.Path(self.tmp.name);self.db=self.root/'library.db';fixture(self.db);self.out=self.root/'runtime';self.out.mkdir()
    def run_builder(self,db=None):return subprocess.run([PROGRAM,'once',str(db or self.db),str(self.out)],capture_output=True,text=True,timeout=8)
    def test_same_named_album_scoped_by_album_artist_and_read_only(self):
        before=self.db.read_bytes();p=self.run_builder();self.assertEqual(p.returncode,0,p.stderr);self.assertEqual(before,self.db.read_bytes())
        raw=(self.out/'album-years.bin').read_bytes();magic,version,count,crc=struct.unpack('<4I',raw[:16]);self.assertEqual((magic,version),(0x52594d50,1));self.assertEqual(crc,checksum(raw[16:]));self.assertEqual(len(raw),16+count*12)
        records=list(struct.iter_unpack('<3I',raw[16:]));self.assertEqual(records,sorted(records,key=lambda r:r[:2]))
        values={(a,b):y for a,b,y in records};self.assertEqual(values[(0x84000019,0x81000001)],1979);self.assertEqual(values[(0x8400001a,0x81000001)],2020)
        self.assertEqual(values[(0x84000019,0x81000003)],0);self.assertEqual(values[(0x84000019,0x81000004)],0)
        js=(self.out/'AlbumYearCache.js').read_text();self.assertIn('"$Kate Bush":2214592537',js);self.assertIn('"$2214592537:2164260866":2016',js)
        self.assertEqual((self.out/'AlbumYearCache.js').stat().st_mode&0o777,0o666)
    def test_missing_database_does_not_create_it_and_writes_valid_empty_js(self):
        missing=self.root/'missing.db';p=self.run_builder(missing);self.assertNotEqual(p.returncode,0);self.assertFalse(missing.exists());self.assertIn('function year(artist,album){return ""}',(self.out/'AlbumYearCache.js').read_text())
    def test_unicode_and_js_line_separators_are_escaped(self):
        with sqlite3.connect(self.db) as c:c.execute('UPDATE albumartists SET value=? WHERE id=25',('Björk\u2028"Live"\\',))
        self.assertEqual(self.run_builder().returncode,0)
        js=(self.out/'AlbumYearCache.js').read_text(encoding='utf-8');self.assertNotIn('\u2028',js);self.assertIn('\\u2028',js)
        names=json.loads(re.search(r'var artistIds=(\{.*?\})\n',js).group(1));self.assertEqual(names['$Björk\u2028"Live"\\'],0x84000019)
if __name__=='__main__':unittest.main(verbosity=2)
