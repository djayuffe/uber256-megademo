# UBER256 / UBERSHOW — authentic DOS VGA demo project

A zero-asset real-mode PC demoscene project intended for DOSBox and real VGA-compatible DOS PCs.

## Targets

| File | Purpose | CPU | Video |
|---|---|---|---|
| `intro256.asm` | strict <=256-byte intro | 386+ | VGA mode 13h |
| `showcase.asm` | multi-scene procedural demo | 386+ | VGA mode 13h |

Both are flat DOS `.COM` programs (`BITS 16`, `ORG 100h`). Graphics are generated directly into segment `A000h`; there are no images, fonts, libraries, runtime files, or protected-mode extenders.

## Build

Install NASM, then run:

```sh
./build.sh
```

The build performs a static source audit, assembles both programs, rejects `UBER256.COM` if it is over 256 bytes, and emits SHA-256 hashes. No padding is used to fake the 256-byte class: the executable must be **at most** 256 bytes.

## Run in DOSBox

```sh
./run-dosbox.sh
```

Or manually mount this directory in DOSBox and execute `UBER256.COM` or `UBERSHOW.COM`. Press **Esc** to return to DOS.

## Hardware model

BIOS `INT 10h`, AX=0013h selects 320x200, 256-colour VGA. One byte represents one pixel, giving a 64,000-byte visible framebuffer at `A000:0000`. Because 64,000 < 65,536, the complete frame fits in one real-mode segment and a linear `STOSB` renderer can traverse it without bank switching.

The showcase programs the VGA DAC through ports `3C8h/3C9h`. VGA DAC components are six-bit values (0..63). Port `3DAh` is sampled for vertical-retrace bit 3, providing a simple hardware-paced presentation point. Keyboard scan codes are sampled from controller data port `60h`; Esc make code `01h` terminates the demo.

## Strict intro

`intro256.asm` deliberately spends almost all complexity on the inner pixel recurrence. For each frame it combines X, Y and a frame phase using XOR, addition and multiplication. Overflow is intentional: wrapping integer arithmetic is itself the texture generator. The low byte becomes the palette index and is written with `STOSB`.

This is characteristic sizecoding: coordinates double as loop counters, phase lives in a general register, there is no asset data, no clearing pass, and BIOS/DOS are only used for mode entry/exit.

## Showcase timeline

`UBERSHOW.COM` derives its scene number from bits of the global frame counter and automatically cycles through four renderers:

1. **Interference plasma** — affine X/Y waves folded through XOR.
2. **Pseudo tunnel** — Manhattan radial distance plus a phase-shifted angular-like field.
3. **XOR multiplier field** — `x*y` creates dense nonlinear lattices.
4. **Moire/radial field** — squared centered coordinates create expanding rings and interference.

Every scene is procedural and renders the full 320x200 surface. The global frame counter changes both scene selection and texture phase, while the DAC palette maps byte-valued fields to visible colour.

## Why mode 13h

The address of a pixel is simply:

```
offset = y * 320 + x
```

For a complete sequential renderer we do not even need that multiplication: start `DI=0` and execute 64,000 stores. This makes mode 13h unusually useful for tiny intros despite its modest resolution.

## Timing and authenticity

This is intentionally not a modern SDL program disguised as DOS. Rendering is 16-bit real-mode code and talks directly to VGA and keyboard I/O. Vertical retrace is used as a presentation boundary, but rendering speed still depends on emulated/real CPU speed. DOSBox cycle settings therefore influence animation rate, just as CPU performance influences many historical DOS effects.

## Source audit

`audit.py` catches structural mistakes without pretending to be an assembler. It verifies COM origin/mode declarations, VGA entry/framebuffer usage, text-mode restoration, and rejects accidental x86-64 low-byte register names. `build.sh` remains authoritative for actual NASM syntax and the final strict byte count.

## Files

- `intro256.asm` — strict sizecoded intro source
- `showcase.asm` — multi-effect demo source
- `audit.py` — source-level sanity checks
- `build.sh` — reproducible NASM build and byte-limit enforcement
- `run-dosbox.sh` — DOSBox launcher
- `DOSBOX.CONF` — example DOSBox configuration

## Toolchain limitation of this packaged build

The environment used to package this source did not contain NASM or DOSBox. Consequently no fabricated `.COM` binaries are included. `audit.py` was executed successfully, while final opcode encoding, exact byte count and runtime behaviour must be established by `build.sh` with NASM and by DOSBox/real hardware respectively.

## 3.0 closure pass

The showcase is now deliberately different from the strict sizecoded entry. It allocates a 64,000-byte DOS conventional-memory backbuffer, renders complete frames off-screen, waits for VGA vertical retrace, and copies 32,000 words to A000h. It preserves/restores the caller video mode, frees allocated memory, checks the 8042 status register before consuming keyboard data, and shuts the PC speaker down on normal exit.

Audio is a procedural PIT channel-2 / PC-speaker arpeggio, requiring no sample or music asset. The visual timeline contains four independently generated scenes plus animated DAC palette cycling and a moving raster overlay. ESC exits cleanly.

`UBER256.COM` remains intentionally tiny and direct-to-VRAM. `UBERSHOW.COM` is the robust production target.

## Version 4.0 effect expansion

`showcase.asm` now contains eight procedural scenes: interference plasma, radial tunnel,
x/y XOR field, concentric moire, zooming checker grid, dual-source ripples, vertical
twister ribbons, and a cellular/feedback-style field. Three independently moving raster
bars and scene-aware palette morphing run over the entire timeline.

Scene length is 512 VGA frames (roughly 7.3 seconds on a normal 70 Hz Mode 13h display),
which prevents the previous rapid hard-cut feel. All animation derives from one 16-bit
frame counter, so motion, palette, overlays, and PC-speaker sequencing remain phase locked.
The presentation path still uses a 64,000-byte off-screen buffer and a retrace-synchronized
word copy to A000h.


## 5.0 polish pass

- Corrected DAC palette indexing to an exact 0..255 cycle.
- Added 32-frame palette-domain fade-in/fade-out around every scene boundary.
- Kept one global frame clock for visual motion, palette motion and speaker sequencing.
- Clarified that retrace-start pacing reduces tearing but a 64 KB software blit is not guaranteed to complete inside VGA vertical blank on original hardware.
- Expanded static release checks for scene presence, exact 64,000-byte blit structure, transition envelope and guarded keyboard reads.


## FINAL scene expansion

UBERSHOW now contains 16 timed procedural scenes. The added half emphasizes inexpensive integer recurrences (copper waves, Manhattan diamonds, lattice, warp bands, scanwave, bitplane interference, vortex mixer and a combined finale) so visual variety increases without making every frame multiply-heavy. Scene fades remain palette-domain operations and the global frame counter never resets.

## 5.0 presentation pass

The showcase now has a scene-progress marker and a symmetric shutter transition layered with the existing DAC fade. The marker costs only a few hundred stores per frame. Transition geometry is rendered into the existing backbuffer before presentation, so there is no second framebuffer and no BIOS drawing in graphics mode. The PC-speaker sequence also changes pitch range with the current scene while retaining the same deterministic frame clock.


## Post-release audit fixes

This build was never actually assembled before packaging (NASM/DOSBox were absent from
the packaging environment, as noted below). A real build turned up issues the static
text-grep audits (`audit.py`, `audit_final.py`, `release_audit.py`) could not catch:

- `showcase.asm` **did not assemble**: `scene_tunnel` used `add al,si`, which is illegal
  in 16-bit real mode (SI has no addressable low byte, unlike AX/BX/CX/DX). Fixed by
  routing the value through `BX` (`mov bx,si` / `add al,bl`).
- `scene_feedback` was missing its `jmp overlay`, so execution fell through into
  `scene_copper`'s renderer with `DI` already at the end of the 64,000-byte backbuffer.
  The second 64,000-byte render wrapped `DI` past the end of the real-mode segment and
  overran the DOS-allocated block, corrupting adjacent memory. Fixed by adding the
  missing jump, and `audit_final.py` now checks every scene for a terminating
  `jmp overlay` so this class of bug can't pass silently again.
- Esc-key handling raced the BIOS's own IRQ1 handler: with interrupts enabled and no
  masking, the BIOS ISR almost always drained the keyboard controller before the
  demo's own `in al,64h`/`in al,60h` poll saw it, making ESC unreliable. Fixed by
  masking IRQ1 at the 8259 PIC for the demo's duration and restoring the original
  mask on exit.
- `build.sh` and `run-dosbox.sh` shipped without the executable bit, so the documented
  `./build.sh` / `./run-dosbox.sh` commands failed outright. Fixed with `chmod +x`.
- `FINAL_REVIEW.md` mis-described the backbuffer allocation as "4000h paragraphs
  (64 KiB)"; the source actually requests decimal 4000 paragraphs, which is exactly
  64,000 bytes (not 65,536). Corrected.

All three audit scripts and a full `./build.sh` now pass with NASM producing a 54-byte
`UBER256.COM` and a working `UBERSHOW.COM`.

## Final release architecture

The final tree is intentionally split between a strict <=256-byte intro and the full 16-scene showcase. The showcase is a software-backbuffered Mode 13h production, not a hardware page-flipped engine. See `FINAL_REVIEW.md` for the final design, art-direction, timing and validation review.
