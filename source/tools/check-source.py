"""Check the source snapshot without a firmware image or device access."""
import ast,hashlib,json,pathlib
HERE=pathlib.Path(__file__).resolve().parent.parent
SHA=lambda b:hashlib.sha256(b).hexdigest()
def main():
    sources=json.loads((HERE/'SOURCE-MAP.json').read_text(encoding='utf-8'))
    for item in sources['files']:
        p=(HERE/item['path']).resolve();assert p.is_relative_to(HERE)
        assert SHA(p.read_bytes())==item['sha256'],item['path']
    files=[p for p in HERE.rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    forbidden={'.exe','.dll','.so','.bin','.upg','.zip','.gz','.png','.jpg','.pem','.key','.log'}
    for p in files:
        data=p.read_bytes();assert p.suffix.lower() not in forbidden,p
        assert not data.startswith((b'\x7fELF',b'MZ')),p
        text=data.decode('utf-8')
        for secret in ('C:\\Users\\','/mnt/c/Users/','/home/farukuruc/','ghp_','github_pat_'):
            # This validator contains the literal patterns intentionally.
            if p.name!='check-source.py':assert secret not in text,p
        if p.suffix=='.py':ast.parse(text,filename=str(p))
    spec=json.loads((HERE/'patches/player.json').read_text())
    assert len(spec['resources'])==sources['player_resource_count']
    assert sources['version']=='1.5.1-stable'
    manifest=json.loads((HERE/'release-manifest.json').read_text())
    assert manifest['version']==sources['version']
    assert spec['output_sha256']==next(f['sha256'] for f in manifest['files'] if f['name']=='player')
    for line in (HERE/'SHA256SUMS.txt').read_text().splitlines():
        digest,name=line.split(None,1);assert SHA((HERE/name).read_bytes())==digest,name
    assert all('source' not in f for f in json.loads((HERE/'release-manifest.json').read_text())['files'])
    print('PASS source hashes, Python syntax, text-only export and no private build paths')
if __name__=='__main__':main()
