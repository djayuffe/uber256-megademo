# FINAL DESIGN / ARCHITECTURE REVIEW

## Release verdict

The project is structured as two deliberately different products:

1. `intro256.asm` — sizecoding experiment with a hard <=256-byte build gate.
2. `showcase.asm` — a conventional real-mode VGA production where visual continuity,
   cleanup and readability take priority over byte count.

This separation is the correct architecture. The showcase does not pretend that
production-safe DOS allocation, backbuffering, transitions and audio belong in 256 bytes.

## Rendering architecture

`UBERSHOW.COM` uses VGA mode 13h (320x200x8) and **double-buffers in real video
memory**: it widens the VGA CPU window to 128K, renders each frame entirely into
whichever of the two 64,000-byte pages is not currently displayed, then flips the
CRTC start address to present it. This is hardware page flipping — there is no
software backbuffer, no `REP MOVSW` blit, and no DOS allocation of any kind. (An
earlier build did allocate 4000 paragraphs and blit; that was replaced.)

All sixteen field scenes obey one renderer contract:
- ES points at the page being rendered.
- DI starts at zero.
- the full-screen renderer emits 64,000 pixels.
- presentation overlays are applied afterward.

The two 3D scenes (`scene_cube`, `scene_starfield`) deliberately break the
full-field contract, clearing the page with `rep stosw` and drawing vector/point
work instead; `audit_final.py` carries an explicit per-scene check for that shape
rather than a blanket exemption.

This keeps effects independent of DOS memory management, since no effect ever
touches VGA state or host memory outside the page it was handed.

## Art direction

The sixteen field scenes are organized conceptually into four four-scene acts:

- ACT I / ANALOG: plasma, tunnel, multiplier field, moire.
- ACT II / GEOMETRY: grid, ripple, ribbons, feedback.
- ACT III / DIGITAL: copper, diamond, lattice, warp.
- ACT IV / TERMINAL: scanwave, bitplane, vortex, wireframe cube.

Scenes 17 (starfield) and 18 (finale) close the show as a pair. The music's
transposition is keyed to `cur_scene >> 3`, so the audio groups the show as
0-7 / 8-15 / 16-17 — three pitch groups, not four visual acts.

The common raster treatment and scene-progress strip make the sixteen algorithms
feel like one production instead of sixteen unrelated test patterns. Palette
generation uses the global frame clock plus scene-family phase, so the acts change
chromatic character without loading assets.

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

Waiting for VGA vertical retrace before the start-address flip improves
presentation phase stability but does not guarantee that the flip and the palette
update both complete inside vertical blank on every original PC: `palette_tick`
writes 768 DAC bytes and `music_tick` steps the sequencer in between. The release
therefore does not claim universal tear-free output. The page flip itself is sound
for planar mode 13h only because a scanline is 320 bytes there, which keeps
`65536 + 199 x 320 = 129216` bytes inside the 128K window.

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

The 6.1 fixes below were derived from static analysis plus simulation of the exact
16-bit arithmetic, and re-verified by assembling and checking the emitted
instructions; they have **not** yet been confirmed in a running DOSBox. A
headless run of at least 20 minutes of frames would be needed to exercise the
former crash point, and short of that the starfield and scene-cycling behaviour
should be watched once by eye.

## 6.0 expansion: scene 16 (3D), text scroller, music, raster glow

The showcase grew a 17th scene and a persistent bottom overlay:

- **scene_cube** breaks the established "every scene is a full-field STOSB sweep"
  contract on purpose: it's a real 3D vector object (two-axis rotation, true
  perspective projection with a distance divide, a from-scratch Bresenham line
  draw), not another procedural per-pixel field. It clears the page with
  `rep stosw` instead, and `audit_final.py` was extended with a scene-specific
  check for that shape rather than relaxing the general per-scene invariant.
- A 5x7 bitmap-font **sine-wave text scroller** runs along the bottom every frame,
  reusing the cube's sine table for its wave and glyph columns for a classic wavy
  look, with a small fixed rainbow foreground that cycles along the message and
  over time.
- **DAC indices 1-7 are now reserved** immediately after `palette_tick`'s main
  animated loop, overriding whatever it just assigned those indices, so the
  scroller and cube stay legibly high-contrast regardless of the current
  per-scene animated palette. Before this fix the scroller/cube used indices that
  were *also* written by the animated loop and could converge to near-identical
  tones -- confirmed visually (and then fixed) by actually running the showcase
  in DOSBox, not by static review.
- Raster bars changed from one flat scanline to a dim/bright/dim three-line glow.
- Music: replaced an ad hoc note table and linear-subtraction transposition with
  an explicit A-minor-pentatonic scale, real rests, a short pre-retrigger mute for
  staccato note attacks, and octave-consistent transposition (halving the PIT
  divisor, which is always exactly one octave regardless of starting pitch, unlike
  the previous raw subtraction).

`UBERSHOW.COM` grew from 1523 bytes (first audited build) to 3,987 bytes; the
SETBLOCK memory shrink in `start:` was widened from 256 to 512 paragraphs (8 KiB)
to keep comfortable headroom for the added font/scroller/cube tables. That ceiling
is now load-bearing rather than cosmetic: nothing is allocated from DOS any more,
but if the image ever exceeded 8 KiB the shrink would leave code outside the
program's own block. `build.sh` prints the size on every build for that reason.

## 6.1 audit: arithmetic-range and sequencing bugs

A later audit pass, working from the assembled output rather than the source text,
found two defects that every existing check had passed:

- **`scene_starfield` divided by zero.** The 16-bit phase accumulator is not a
  multiple of its 240-frame period, so `div 240` returns up to 273, driving the
  star's Z to negative and then exactly zero — and `IDIV word [star_z]` faults
  with `#DE` (no handler installed, so the program dies). 291 frames per 65536-frame
  cycle contained a zero divisor; the first was frame 63709, 221 frames into a
  starfield scene. Fixed by reducing the quotient back into 0..239 with a compare
  and one conditional subtract, restoring the documented 16..255 depth ramp.
- **The 18-scene sequence never recurred.** Scene index was computed as
  `(frame >> 9) mod 18`, but the frame clock is 16-bit: only 128 groups exist, and
  `128 mod 18 != 0`, so every wrap replayed scenes 0 and 1. Fixed with an explicit
  0..17 counter wrapped in `present:`, which also removes a divide from the hot
  path and lets `scene_marker`/`music_tick` share one unambiguous value.

Both were invisible to a short interactive run, which is the point worth
recording: the first needs roughly 15 minutes of frames to reach, the second half
that again. Neither is a matter of style, and neither was caught by the static
audits, all of which are textual. `TECHNICAL.md` now documents the 16-bit
divisor-range hazard and the sequencing decision, and this section supersedes the
earlier claims in this file that the demo was software-blitted from a DOS
allocation.
