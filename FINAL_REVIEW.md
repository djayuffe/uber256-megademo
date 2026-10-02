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

The 6.1 items below were settled by executing instrumented builds under DOSBox rather
than by reading the source: each build writes its per-frame scene index and computed
star divisor to a host file, which is then compared against expectations. A
headless DOSBox run (`SDL_VIDEODRIVER=dummy`) makes this reproducible without a
window. Those runs also have **not** been confirmed as pixel-accurate VGA output — no
framebuffer capture is possible in the current environment (screen-recording
permission and keystroke injection are both denied), so the visual result still wants
one look by eye.

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

## 6.1 audit: one real bug, one phantom bug, and one regression

An audit pass claimed two defects in `UBERSHOW.COM`. Instrumented runs under DOSBox
(one instrumented build per claim, logging the scene index and the computed star
divisor to a host file) split them apart:

- **The 18-scene sequence did not loop cleanly.** The scene index was
  `(frame >> 9) mod 18`, and the frame clock is 16-bit, so one clock cycle is only
  128 groups of 512 frames. `128 mod 18` is 2, not 0: at every wrap the show replayed
  scenes 0 and 1 instead of continuing the cycle. Replaced with an explicit 0..17
  counter advanced in `present:` and wrapped at `SCENE_COUNT`. Verified by running
  both revisions across the clock wrap: the old index jumped backwards from 1 to 0,
  the new one continues 16 to 17.
- **The claimed `#DE` crash in `scene_starfield` was not real.** The argument was that
  `div 240` yields up to 273, so `Z = 255 - dx` goes negative and then hits zero and
  `IDIV word [star_z]` faults some 15 minutes in. That misreads the instruction:
  `DIV r/m16` returns the **quotient in AX** and the **remainder in DX**, DX is zeroed
  first, and the code consumes DX. A remainder is 0..239 by construction, so Z is
  16..255 always. Running the pre-"fix" code for 1024 starfield frames with the phase
  accumulator swept through its whole range recorded a minimum Z of 16, zero zero
  divisors and zero negative values. The clamp that was added in the name of this fix
  was unreachable (`dx` can never reach 240) and has been removed; the comment now
  spells out the quotient/remainder split, since reading it the other way is exactly
  the mistake that produced the phantom.
- **The counter fix regressed the pacing on its first attempt.** Incrementing
  `cur_scene` every frame rather than every 512 frames strobed all 18 scenes 70 times
  a second; the instrumented log showed the index cycling 16,17,0,1,… on every single
  frame. The advance is now gated on `bp mod 512 == 0`, so scene length still tracks
  `SCENE_SHIFT`. All three static audits passed throughout, because every check they
  make is textual and none of them reason about how often a counter is advanced.

The general lesson is the one worth keeping: the three audits in this directory are
source-text pattern matches, so a change that compiles cleanly, keeps the image size
plausible and matches every `needle` in `audit.py` can still be badly wrong at
runtime. Assertions about behaviour — "this sequence recurs", "this divisor is never
zero" — need to be executed, not grepped.
