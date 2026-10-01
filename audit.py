#!/usr/bin/env python3
from pathlib import Path
import re, sys
root=Path(__file__).resolve().parent
errors=[]
def need(name,s,needle,label):
    if needle not in s: errors.append(f"{name}: missing {label}")
for name in ("intro256.asm","showcase.asm"):
    s=(root/name).read_text()
    for needle,label in [("BITS 16","16-bit declaration"),("ORG 100h","COM origin"),("mov ax,13h","VGA mode 13h"),("0A000h","VGA framebuffer")]: need(name,s,needle,label)
    if re.search(r"\b(?:sil|dil|spl|bpl)\b",s,re.I): errors.append(f"{name}: x86-64 byte register in 16-bit source")
s=(root/"showcase.asm").read_text()
for needle,label in [("mov ah,48h","DOS backbuffer allocation"),("mov ah,49h","DOS backbuffer free"),("in al,64h","8042 status check"),("wait_vsync:","vertical-retrace pacing"),("rep movsw","backbuffer blit"),("speaker_on:","PC speaker setup"),("speaker_off:","PC speaker cleanup"),("music_tick:","sound sequencer"),("old_mode","video-mode preservation"),("palette_tick:","animated palette"),("pal_limit","palette transition envelope"),("and ax,511","scene-local transition phase")]: need("showcase.asm",s,needle,label)
if "in al,60h" in s and "in al,64h" not in s: errors.append("showcase.asm: keyboard data read without status guard")
if "mov cx,32000" not in s or "rep movsw" not in s: errors.append("showcase.asm: exact 64000-byte VGA blit missing")
for n in ["plasma","tunnel","xor","moire","checker","ripples","twister","feedback"]: need("showcase.asm",s,"scene_"+n+":",n+" scene")
print("static source audit:", "PASS" if not errors else "FAIL")
for e in errors: print(" -",e)
sys.exit(bool(errors))
