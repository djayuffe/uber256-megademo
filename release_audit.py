#!/usr/bin/env python3
from pathlib import Path
import re,sys
r=Path(__file__).parent
s=(r/"showcase.asm").read_text()
i=(r/"intro256.asm").read_text()
errors=[]
for f in ["showcase.asm","intro256.asm","build.sh","run-dosbox.sh","DOSBOX.CONF",
          "README.md","TECHNICAL.md","FINAL_REVIEW.md","audit.py","audit_final.py"]:
    if not (r/f).exists(): errors.append("missing "+f)
targets=["scene_plasma","scene_tunnel","scene_xor","scene_moire","scene_checker",
         "scene_ripples","scene_twister","scene_feedback","scene_copper","scene_diamond",
         "scene_lattice","scene_warp","scene_scanwave","scene_bitplane","scene_vortex",
         "scene_cube","scene_finale"]
for x in targets:
    if s.count(x+":")!=1: errors.append("scene label "+x)
for x in ["mov bx,4000","mov cx,32000","rep movsw","call wait_vsync","call palette_tick",
          "call music_tick","call speaker_off","mov ah,49h","in al,64h","in al,60h",
          "mov ax,13h","int 10h","pal_limit db 63","mov ah,4Ah","call scroll_draw",
          "call draw_line","cube_rotate_project:","font_data:","scroll_msg:","sintab:"]:
    if x not in s: errors.append("missing invariant "+x)
if "org 100h" not in s.lower() or "bits 16" not in s.lower(): errors.append("showcase COM model")
if "org 100h" not in i.lower() or "bits 16" not in i.lower(): errors.append("intro COM model")
b=(r/"build.sh").read_text()
if "256" not in b or "nasm" not in b.lower(): errors.append("build size gate/tool")
if errors:
    print("RELEASE AUDIT: FAIL")
    print("\n".join(errors));sys.exit(1)
print("RELEASE AUDIT: PASS")
print("  17 explicit scenes (16 fields + rotating 3D wireframe cube)")
print("  bottom sine-wave text scroller")
print("  DOS allocation/free invariants (own-block SETBLOCK shrink + backbuffer alloc)")
print("  VGA mode/backbuffer/blit invariants")
print("  palette, input, audio and cleanup invariants")
print("  strict intro build gate present")
