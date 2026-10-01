# FINAL DESIGN / ARCHITECTURE REVIEW

## Release verdict

The project is structured as two deliberately different products:

1. `intro256.asm` — sizecoding experiment with a hard <=256-byte build gate.
2. `showcase.asm` — a conventional real-mode VGA production where visual continuity,
   cleanup and readability take priority over byte count.

This separation is the correct architecture. The showcase does not pretend that
production-safe DOS allocation, backbuffering, transitions and audio belong in 256 bytes.

## Rendering architecture

`UBERSHOW.COM` uses VGA mode 13h (320x200x8), allocates 4000 (decimal) paragraphs —
exactly 64,000 bytes, matching the 320x200 framebuffer — through DOS, renders into
that software backbuffer through ES:DI, then copies exactly 32,000 words to A000:0000.
This is software backbuffering, not hardware page flipping.

All sixteen primary scenes obey one renderer contract:
- ES points at the backbuffer.
- DI starts at zero.
- the full-screen renderer emits 64,000 pixels.
- presentation overlays are applied afterward.
- the presenter owns the DS switch required by `REP MOVSW`.

This keeps effects independent of DOS memory management and VGA presentation.

## Art direction

The final show is organized conceptually into four four-scene acts:

- ACT I / ANALOG: plasma, tunnel, multiplier field, moire.
- ACT II / GEOMETRY: grid, ripple, ribbons, feedback.
- ACT III / DIGITAL: copper, diamond, lattice, warp.
- ACT IV / TERMINAL: scanwave, bitplane, vortex, finale.

The common raster treatment and scene-progress strip make the sixteen algorithms feel
like one production instead of sixteen unrelated test patterns. Palette generation
uses the global frame clock plus scene-family phase, so the acts change chromatic
character without loading assets.

## Motion and pacing

Every effect is driven by the same monotonically increasing frame word. Scenes last
512 frames. A 32-frame DAC fade enters/exits each scene and a short shutter overlay
reinforces the cut. The audio sequencer and raster motion never reset at a scene
boundary, which avoids the 'slideshow' feel produced by restarting all phases.

The renderers intentionally favor 16-bit integer recurrence, shifts, XOR and adds.
Multiply-heavy radial effects exist for contrast but are not used for every scene.

## Audio

PIT channel 2 / PC speaker is deliberately minimal and period-correct. The scene index
transposes the note table so the soundtrack follows the visual progression. It is not
presented as AdLib/Sound Blaster music.

## Input and cleanup

Keyboard reads are guarded by the 8042 status register. Because interrupts stay enabled
and the BIOS's own INT 9 handler is still attached to IRQ1, polling port 60h directly
without masking that IRQ loses the race almost every time — the BIOS ISR drains the
controller's output buffer first, so Esc would rarely be seen. The demo therefore masks
IRQ1 at the 8259 PIC for its duration and restores the original mask on exit. ESC exits.
The demo disables the speaker, unmasks IRQ1, restores the original video mode, releases
DOS conventional memory and returns through INT 21h.

## Known hardware boundary

Waiting for VGA vertical retrace before a 64,000-byte CPU copy improves presentation
phase stability but does not guarantee that the entire copy fits inside vertical blank
on every original PC. The release therefore does not claim universal tear-free output.

## Final layout

- `intro256.asm` strict sizecode source
- `showcase.asm` full show
- `build.sh` reproducible NASM build and <=256-byte enforcement
- `run-dosbox.sh` launch helper
- `DOSBOX.CONF` emulator configuration
- `audit.py` baseline structural audit
- `audit_final.py` 16-scene renderer audit
- `release_audit.py` final architecture/release audit
- `README.md` user-facing build/run documentation
- `TECHNICAL.md` implementation notes
- `FINAL_REVIEW.md` this design review
- `MANIFEST.sha256` release hashes

## Validation boundary

NASM and DOSBox are now installed and have been used directly: both `.COM` files
assemble cleanly via `build.sh`, and both were launched in real DOSBox and watched
render, animate and exit cleanly on Esc. This is what actually caught the two bugs
that the static source/package audits could not see — an illegal opcode that kept
`showcase.asm` from assembling at all, and a missing own-memory-block shrink that
kept `UBERSHOW.COM` from ever getting past "not enough conventional memory" even
once it did assemble. Static audits remain useful as a fast regression gate, but
they are not a substitute for an actual build-and-run pass, which should be repeated
whenever `showcase.asm` or `intro256.asm` change.
