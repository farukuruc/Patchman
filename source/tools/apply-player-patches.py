"""Apply source edits to a user-supplied, hash-checked Walkman One player.

No firmware bytes are embedded here. Output is a local build file, not a device
installation. This tool never flashes anything or mounts a device partition.
"""
import hashlib,json,pathlib,sys,zlib
HERE=pathlib.Path(__file__).resolve().parent.parent
SHA=lambda b:hashlib.sha256(b).hexdigest()
def edited(before,spec):
    assert SHA(before.encode())==spec['before_sha256'],'Unexpected original QML'
    lines=before.splitlines(keepends=True)
    for item in reversed(spec['edits']):
        lines[item['start']:item['start']+item['delete']]=item['insert']
    result=''.join(lines)
    assert SHA(result.encode())==spec['after_sha256'],'QML source reconstruction mismatch'
    return result
def read(data,off,compressed=True):
    n=int.from_bytes(data[off:off+4],'big')
    return (zlib.decompress(data[off+8:off+4+n]) if compressed else data[off+4:off+4+n]).decode('utf-8')
def main():
    if len(sys.argv)!=3:raise SystemExit('Usage: python3 tools/apply-player-patches.py ORIGINAL_PLAYER OUTPUT_DIRECTORY')
    source=pathlib.Path(sys.argv[1]).resolve();out=pathlib.Path(sys.argv[2]).resolve()
    assert source!=out/'HgrmMediaPlayerApp','Input must not be overwritten'
    spec=json.loads((HERE/'patches/player.json').read_text(encoding='utf-8'))
    data=source.read_bytes();assert SHA(data)==spec['input_sha256'],'Unsupported original player'
    patched=bytearray(data)
    for item in spec['resources']:
        off=item['offset'];slot=item['slot']
        d=json.loads((HERE/item['patch']).read_text(encoding='utf-8'))
        raw=edited(read(data,off,item['compressed']),d).encode()
        body=len(raw).to_bytes(4,'big')+zlib.compress(raw,9) if item['compressed'] else raw
        packed=len(body).to_bytes(4,'big')+body
        assert len(packed)<=slot,'Resource exceeds reserved slot'
        patched[off:off+slot]=packed+b'\0'*(slot-len(packed))
    assert SHA(patched)==spec['output_sha256'],'Final player differs from released binary'
    out.mkdir(parents=True,exist_ok=True)
    (out/'HgrmMediaPlayerApp').write_bytes(patched)
    for item in spec['external']:
        d=json.loads((HERE/item['patch']).read_text(encoding='utf-8'))
        text=edited(read(data,item['resource_offset']),d)
        (out/item['output']).write_bytes(text.encode())
    print('PASS: exact v1.1 player and external Sony-layout QML reconstructed from source edits')
if __name__=='__main__':main()
