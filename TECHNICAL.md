# Low-level notes

## DOS COM execution

DOS loads a COM image at offset `0100h` of its program segment. `CS`, `DS`, `ES`, and `SS` initially describe the program's PSP environment, but this demo explicitly installs `ES=A000h` before framebuffer stores. `ORG 100h` tells NASM to calculate labels for that load convention; it does not emit a header.

## VGA framebuffer

Mode 13h is packed-pixel VGA: 320*200 = 64,000 byte pixels. `ES:DI` is therefore a natural streaming destination. `STOSB` writes AL to `ES:[DI]` and advances DI when the direction flag is clear. DOS normally enters applications with DF clear; production code that must tolerate arbitrary callers can issue `CLD`, at a one-byte size cost.

## Palette DAC

Writing zero to `3C8h` selects DAC entry zero. Subsequent writes to `3C9h` are consumed as R,G,B triplets and automatically advance the palette index. The generated palette intentionally uses modular six-bit ramps rather than storing 768 bytes of palette data.

## Retrace

Input Status Register 1 is available at `3DAh`; bit 3 reflects vertical retrace. The showcase first waits until outside retrace and then until retrace begins. This gives one unambiguous edge per rendered frame. It is synchronization, not a guarantee that rendering itself fits one refresh interval.

## Sizecoding trade-offs

A 256-byte intro optimizes encoded bytes rather than conventional software structure. Registers carry several meanings over their lifetime; arithmetic overflow is useful; tables and abstractions are expensive; direct hardware access replaces APIs. Such code is intentionally unlike maintainable application code.

## CPU baseline

The sources declare a 386+ target because the compact arithmetic uses later x86 instruction forms. They remain 16-bit real-mode programs; 386+ refers to the instruction set, not 32-bit protected mode.


## Frame presentation accuracy

`wait_vsync` waits for the beginning of vertical retrace and then starts the 64,000-byte backbuffer copy. This provides stable frame pacing and generally reduces visible tearing. It must not be described as mathematically tear-free on every historical VGA/CPU combination: the complete copy can outlast vertical blank on slower machines. True hardware page flipping would require a different VGA memory/layout strategy.

Scene changes use a palette-domain fade envelope. The renderer therefore pays no second full-frame blend pass: DAC output is clamped toward black for 32 frames before/after each 512-frame boundary while the procedural effect clock remains continuous.


## Register-lifetime audit

Rendering loads ES with the allocated backbuffer segment once at frame start. Individual effects may freely reuse AX/BX/CX/DX/SI because STOSB addresses ES:DI; BX is not a persistent framebuffer pointer. The presentation path reloads DS from `backseg` explicitly before `REP MOVSW`, then restores DS. Every scene uses a 320 x 200 loop and therefore emits exactly 64,000 STOSB writes before overlays.

## Presentation choreography

Version 5.0 combines two transition mechanisms. `palette_tick` performs the inexpensive DAC-domain fade, while `transition_wipe` covers symmetric top/bottom scanline regions during the first and last 16 frames of each 512-frame scene. `scene_marker` renders sixteen tiny progress blocks directly into the backbuffer. Both overlays execute after the scene renderer and before the retrace/presentation path, so they cannot leave stale pixels between scenes.
