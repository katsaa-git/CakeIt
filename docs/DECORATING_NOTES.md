# Decorating notes

Running notes on the cake decorating core: what exists, how to use it, how
to extend it, and what still needs work. Newest milestone first in the log.

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

## Adding a new piping tip

1. Copy a file in `data/tips/` (for example `02_open_star.tres`) and rename it.
2. Change `id`, `display_name`, `description` and `sort_order`.
3. Adjust the profile numbers (points, depth, ridge fullness...) and the feel
   settings (end style, lift, speed thinning, dwell growth, sizes).
4. Run the tests. No code changes needed.

A brand-new cross-section shape needs a small `TipProfile` subclass in
`scripts/piping/profiles/` (one function that returns the outline points).

## Tests and tools

- Headless tests:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd`
- End-to-end input test (injects real mouse/keyboard events):
  `Godot_v4.7.2-stable_win64_console.exe --path . -- --scenario=input_test`
- Screenshots with the real renderer:
  `... --path . -- --scenario=showcase --shots=C:/some/folder --angles=front,close,high`
- Benchmark: `... --path . -- --scenario=bench`
- Render settings cost sweep: `... --path . -- --scenario=sweep`

## Performance (milestone A)

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

- The interface is still the interim toolbar (default grey buttons).
- Lighting and set are placeholders (flat background, grey counter).
- The metal nozzle looks dark because there is nothing for it to reflect yet.

## Ideas for later

- Pressure-sensitive pen tablet support (pressure straight into stroke pressure).
- A "steady hand" slider for players who want extra smoothing.

## Milestone log

- **A. Version check and piping core.** 4.7.2 check. New data model,
  command-based undo/redo, incremental stroke builder, merged stroke batches,
  turntable-proof picking, piping bag and cursor preview, dev runner for
  screenshots, benchmarks and input tests.
