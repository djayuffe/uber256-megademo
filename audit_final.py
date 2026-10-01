#!/usr/bin/env python3
from pathlib import Path
import re, sys
p=Path(__file__).with_name("showcase.asm")
s=p.read_text()
errors=[]
required=[
"%define SCENE_MASK  15","mov bx,4000","mov cx,32000","rep movsw",
"call wait_vsync","call palette_tick","call speaker_off","mov ah,49h",
"in al,64h","in al,60h","scene_finale:","pal_limit db 63","scene_marker:","transition_wipe:","call scene_marker","call transition_wipe"
]
for x in required:
    if x not in s: errors.append("missing: "+x)
scenes=re.findall(r"^scene_(?!marker)[a-z0-9_]+:",s,re.M)
if len(scenes)!=16: errors.append(f"expected 16 scenes, found {len(scenes)}")
for label in scenes:
    start=s.index(label)
    nxt=min([i for i in [s.find("\nscene_",start+1),s.find("\noverlay:",start+1)] if i!=-1])
    body=s[start:nxt]
    if "stosb" not in body: errors.append(label+" has no pixel store")
    if "cmp cx,320" not in body or "cmp dx,200" not in body:
        errors.append(label+" lacks canonical 320x200 bounds")
    if label != "scene_finale:" and "jmp overlay" not in body:
        errors.append(label+" does not jump to overlay (falls through into next scene / overruns backbuffer)")
if "mov ax,[backseg]\n    mov es,ax" not in s:
    errors.append("ES backbuffer load missing")
if errors:
    print("AUDIT FAIL")
    print("\n".join(errors)); sys.exit(1)
print("AUDIT PASS: 16 scenes, framebuffer/presentation/cleanup invariants present")
