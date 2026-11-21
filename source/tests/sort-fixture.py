import pathlib, struct, sys

root=pathlib.Path(sys.argv[1])
records=[(0x84000019,0x81000001,1979),(0x84000019,0x81000002,2016),(0x84000019,0x81000003,0),
         (0x8400001a,0x81000001,2020),(0x8400001a,0x81000002,1979),(0x8400001a,0x81000003,0),
         (0x8400001b,0x81000001,1979),(0x8400001b,0x81000002,1979),(0x8400001b,0x81000003,0),
         (0x8400001c,0x81000001,0),(0x8400001c,0x81000002,0),(0x8400001c,0x81000003,0)]
data=b''.join(struct.pack('<III',*r) for r in records)
checksum=2166136261
for n in data:checksum=((checksum^n)*16777619)&0xffffffff
(root/'album-years.bin').write_bytes(struct.pack('<IIII',0x52594d50,1,len(records),checksum)+data)
