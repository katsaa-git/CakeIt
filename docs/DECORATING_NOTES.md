# Decorating notes

Running notes on the cake decorating core: what exists, how to use it, how
to extend it, and what still needs work. Newest milestone first in the log.

## Handoff: where things stand (end of session 1)

**Finished and committed:** milestone A (version check, piping core,
performance) and milestone B (turntable, tiers, coat, spatula, interface
layout).

**In progress: milestone C (lighting, environment, look).** Stable and
working, but not finished. Done so far:

- A seaside bakery corner built in code (`scripts/env/bakery_set.gd`,
  `scripts/env/props.gd`): marble counter, tiled backsplash, white window with
  a sea view and lighthouse, sheer swaying curtains, shelf with jars, linen
  cloth under the stand, tulips in a jug, sprinkle jar, mixing bowl, plates,
  herb pot.
- New lighting (`scripts/env/studio_lighting.gd`): warm window key light from
  behind-left, soft front fill from the left, warm window glow, reflection
  probe, AgX tone mapping, SSAO, mild bloom, light haze, dust motes, warm
  vignette. Stronger depth of field (`scripts/core/orbit_camera.gd`).
- Camera orbit limited to about ±65° around the front (±86° in photo mode,
  once photo mode exists). The turntable turns the cake instead.
- New shaders in `art/shaders/`: marble, tiles, window_view, linen, curtain,
  vignette.

**Exact next steps to finish milestone C:**

1. **Performance of the new set.** The laptop was throttling during the last
   measurements, so only side-by-side numbers are trustworthy. Against the
   milestone B build under the same conditions, the heavy test cake went from
   65 to 47 fps (`--scenario=bench`). GPU time is only ~7 ms, so most of the
   frame is CPU.
   - The new "scripts" timer in the benchmark printed implausible values
     (60–90 ms). First check whether `Performance.TIME_PROCESS` already
     returns milliseconds, then find what costs CPU.
   - Suspects: ~300 draw calls (many small prop meshes and interface
     controls), per-frame `_process` work in interface widgets
     (`TurntableDial` redraws every frame), the transparent curtains, the
     particles.
   - Options: merge static prop meshes into a few meshes, only redraw idle
     widgets when something changes.
   - Target: a steady 60+ fps on the heavy cake.
2. **Art pass on the remaining weak spots.** Check them with
   `--scenario=showcase --angles=front,close,wide`.
   - The cake still reads slightly flat and milky.
   - The sky is still a little too cyan.
   - The herb pot looks like a cactus.
   - The curtains are stiff.
   - The white piping has a faint bright halo at its edges.
   - The metal nozzle should now reflect the room; check that it does.
3. Run the checks (below) and commit milestone C.

**Remaining milestones after C** (from the original brief, in order):

- **D. The 10 tips** as data in `data/tips/`. Round and open star already
  exist; the rest:
  - **Closed star:** `StarProfile` with more points, deeper grooves and higher
    `ridge_fullness`.
  - **Leaf:** new `LeafProfile`, `end_style` POINT.
  - **Petal:** new `PetalProfile` (tilted teardrop).
  - **Ruffle:** petal plus `wave_amplitude`. The profile has to supply per-point
    `wave` offsets.
  - **Ribbon / basketweave:** new `RibbonProfile` (flat, with a ridged top).
  - **Grass:** `StampShape` subclass (a tuft of tapered strands).
  - **Drop flower:** `StampShape` (lobed star profile swept up the surface
    normal with a twist).
  - **Shell:** `StampShape` (star profile, teardrop scale, follows the drag
    direction).

  The stamp plumbing already exists in `StrokeBuilder` (`_commit_stamps`,
  `_emit_stamp`, `StampContext`). Also add 3D thumbnails for the tip cards.
- **E. Decorations** as data in `data/decorations/`. `DecorationData` and
  `AddDecorationsCommand` already exist; `Content.decorations()` expects
  resources that have `category`, `sort_order`, `id` and `validate()`.
  - Items: sprinkles (scatter brush, drawn with MultiMesh), sugar pearls and
    metallic dragées, candles with a flickering flame and a light, ganache
    drip along the rim (stored as rim angles in `DecorationData.path`),
    chocolate curls, fondant cut-outs, daisy, rose, berry, cherry, topper
    sign.
  - Each is a builder resource, with an optional `.glb` scene override.
  - Enable the greyed-out Decorations button.
- **F. Juice and audio:**
  - An audio manager with procedurally generated sounds: squeeze loop,
    sprinkle patter, pearl clicks, tier thunk, undo, UI taps.
  - Placement pops, particle puffs and camera nudges (`OrbitCamera.nudge`
    already exists).
  - Credit any CC0 clips in `docs/CREDITS.md`.
- **G. UI polish and photo mode:**
  - Bigger icons, tip and decoration thumbnails, better tooltips.
  - Photo mode: UI hidden, freer camera, click to focus, saves a PNG to
    `user://screenshots`.
- **H. Save/load and tests:**
  - Versioned JSON of tiers, strokes and decorations. Every data class
    already has `to_dict` / `from_dict`.
  - A save/load panel and autosave.
  - A save/load round-trip test.

## Design decisions so far

- The look test from `CakeGame_update_1.zip` was committed as the starting
  point, then replaced by the new architecture.
- `docs/reference/` (Cake Studio screenshots) is git-ignored: they are
  inspiration only, not ours to redistribute. `docs/` has a `.gdignore`, so
  Godot does not import those images.
- New tiers come pre-coated, so the first 30 seconds are spent piping, not on
  setup. "Semi-naked" is a coat option.
- Clear all removes piping and decorations but keeps tiers and coats, and it
  can be undone.
- The stand's plate is the turntable; there is also an on-screen ring to grab.
- Render settings were chosen by measuring each one (see Performance).
- Strokes and decorations stay sorted by id, so undo/redo restores exactly
  the same lists.

## Engine version

- Godot **4.7.2** (installed at `C:\Users\celia\CakeGame\Godot_v4.7.2-stable_win64.exe`).
- The project was created on 4.6.2. It opens on 4.7.2 without an upgrade
  prompt and imports with no errors or deprecation warnings.
  `config/features` in `project.godot` already says `4.7`.

## Controls

| Input | Action |
| --- | --- |
| Left-drag on the cake | Pipe |
| Left-click on the cake | A dot / kiss / single stamp (hold still to make it bigger) |
| Right-drag | Orbit the camera |
| Mouse wheel | Zoom |
| Middle-drag | Pan up and down |
| Drag the stand's rim, or Space + left-drag | Spin the turntable (flick it to let it coast) |
| A / D (hold) | Spin the turntable smoothly |
| R | Auto-spin on / off |
| 1, 2, 3 | Tip size presets |
| Ctrl + wheel, or [ and ] | Fine-tune tip size |
| Tab / Shift + Tab | Next / previous tip |
| B, C, F, V, T | Tools: piping bag, frosting coat, smoothing scraper, decorations, tiers |
| Turntable ring (bottom right) | Drag round to spin; click the middle for auto-spin |
| H | Controls card |
| Ctrl + Z, Ctrl + Y (or Ctrl + Shift + Z) | Undo, redo |

## How it is built

Everything is created from code; there are no hand-made models.

- **Data (gameplay side)** lives in `scripts/cake/`: `CakeModel` holds the
  tiers (`TierData`), piped strokes (`StrokeData`, with tip id, size preset,
  colour and path) and decorations (`DecorationData`). A future scoring system
  only needs to read this.
- **Every change is a command** (`scripts/commands/`), run through
  `CommandStack`, so undo and redo work the same for everything.
- **Visuals** (`CakeView`, `TierView`, `StrokeBatch`) only react to the model's
  signals. Undo, redo, loading and tools all go through the same path.
- **Piping** (`scripts/piping/`): `StrokeBuilder` turns mouse samples into
  frosting, incrementally. Only the last few "slices" near the nozzle are
  rebuilt each frame; the rest is frozen in chunks. The exact same code
  rebuilds a stroke from saved data, so what you saw while piping is exactly
  what is kept (tested).
- **Merging**: finished strokes are merged into a few big meshes per tier
  (`StrokeBatch`) in the background, a little per frame, so a busy cake is
  only a handful of draw calls and releasing a stroke never hitches.
- **Turntable**: the cake spins, but its collision shapes don't. The mouse ray
  is turned into the cake's own frame instead, so picking is exact even while
  spinning fast.

## The tools

- **Piping bag (B)**: pipe lines, dots and kisses. Tips, sizes and fine size
  are on the bottom shelf; colours on the right.
- **Frosting coat (C)**: pick a colour (and "Smooth buttercream" or
  "Semi-naked"), then click a tier. The new coat spreads from the top centre
  down the sides.
- **Smoothing scraper (F)**: hold it against a coated tier and let the cake
  spin under it (A / D or the ring), or drag along the side. Spatula marks fade
  to a glass-smooth finish; one undo step per press.
- **Tiers (T)**: click a tier to select it, then pick a width (Petite, Small,
  Medium, Large) and height (Short, Classic, Tall), add a tier on top or
  remove one. Piping and decorations on a resized tier move with its surface.

## Adding a new piping tip

1. Copy a file in `data/tips/` (for example `02_open_star.tres`) and rename it.
2. Change `id`, `display_name`, `description` and `sort_order`.
3. Adjust the profile numbers (points, depth, ridge fullness...) and the feel
   settings (end style, lift, speed thinning, dwell growth, sizes).
4. Run the tests. No code changes needed.

A brand-new cross-section shape needs a small `TipProfile` subclass in
`scripts/piping/profiles/` (one function that returns the outline points).

## Adding tier sizes or colours

- Tier sizes: add a `.tres` in `data/tiers/` (copy one): `kind` 0 = width
  (value is the radius), 1 = height. The tier shelf picks it up automatically.
- Colours: edit `data/palettes/frosting.tres` (colour and name lists).

## Tests and tools

- Headless tests:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd`
- End-to-end input test (injects real mouse/keyboard events):
  `Godot_v4.7.2-stable_win64_console.exe --path . -- --scenario=input_test`
- Screenshots with the real renderer:
  `... --path . -- --scenario=showcase --shots=C:/some/folder --angles=front,close,high`
- Benchmark: `... --path . -- --scenario=bench`
- Render settings cost sweep: `... --path . -- --scenario=sweep`
- Shadow layout comparison: `... --path . -- --scenario=shadow_sweep`
- Tier demo: `... --path . -- --scenario=tiers --shots=C:/some/folder`
- Extra flags: `--ui=true` keeps the interface in shots, `--tools=true` shows
  the piping bag, `--tool=tiers` picks a tool first.
- Both executables live in `C:\Users\celia\CakeGame\`. Use the `_console`
  one from a terminal so you see the output.

## Performance (measured at the end of milestone A)

Measured on the target laptop (RTX 3050 6 GB Laptop GPU, 1600x900 window,
vsync off; the display caps at 120 fps).

| Case | Result |
| --- | --- |
| Empty cake | ~160 fps, GPU 3.9 ms |
| Overloaded 3-tier cake: 375 strokes, 377k frosting vertices, spinning | **112 fps avg, 94 fps 1% low**, GPU 7.0 ms, 74 draw calls |
| Piping a very long line live on that cake | stroke cost 2.0 ms avg / 4.7 ms worst per frame, scene 104 fps |
| Releasing that long line | 4.4 ms (handover, no rebuild) |
| Undo / redo of it | 0.3 ms / 3.0 ms |

Before this milestone the same cake ran at 30 fps (GPU 27 ms), and releasing
a long stroke cost ~39 ms. What changed:

- Rings are only placed where the line bends or changes thickness (2.5x fewer
  vertices, no visible difference).
- The most expensive render settings were measured one by one and dialled
  down where the look did not suffer (soft shadow filter, sun disc size,
  bokeh quality, MSAA 4x -> 2x): empty-scene GPU time went from 18 ms to 4 ms.
- The live stroke's meshes are handed to the batch on release instead of
  being rebuilt; collision is built in small slices over a few frames.

## Known issues

- The interface layout is in place but still needs its polish pass
  (bigger icons, thumbnails for tips, nicer tooltips).
- The decorations button is greyed out until the decorations milestone.
- Milestone C is unfinished: see the handoff section (performance of the new
  set, remaining art weak spots).
- The end-to-end input test failed once, on its first run right after a fresh
  import (shaders were still compiling, so frames stalled). It passed on the
  next three runs. If it fails, run it again before investigating.
- Photo mode is still the simple "save a picture" from the look test (P key or
  the camera button).

## Ideas for later

- Pressure-sensitive pen tablet support (pressure straight into stroke pressure).
- A "steady hand" slider for players who want extra smoothing.

## Milestone log

- **C. Lighting and set (in progress).** Seaside bakery set, new light rig,
  reflection probe, haze, dust motes, vignette, stronger depth of field,
  camera orbit limits. Still needs a performance pass and a final art pass.
- **B. Turntable and tiers.** Tier tool with data-driven width/height presets,
  add/remove/resize with undo (piping follows the surface), frosting coat
  tool with a spreading-coat animation, semi-naked sponge look, smoothing
  scraper, on-screen turntable ring, new cozy interface layout (tool rail,
  shelves, palette, top bar, help card, clear-all confirm), command tests.
- **A. Version check and piping core.** 4.7.2 check. New data model,
  command-based undo/redo, incremental stroke builder, merged stroke batches,
  turntable-proof picking, piping bag and cursor preview, dev runner for
  screenshots, benchmarks and input tests.
