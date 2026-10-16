# Decorating notes

Running notes on the cake decorating core: what exists, how to use it, how
to extend it, and what still needs work. Newest milestone first in the log.

## Handoff: where things stand

**Finished and committed:** milestones A (version check, piping core,
performance), B (turntable, tiers, coat, spatula, interface layout), C
(lighting, set and look), D (the ten piping tips) and E (decorations).

**Next: milestone F (juice and audio).** Not started. The plan for F to H
is below.

**Exact next steps for F:**

1. An `AudioManager` (autoload or a node in `main.gd`) that plays short
   sounds made in code at start-up (AudioStreamWAV from generated samples):
   a soft squeeze loop whose volume follows `PipingTool.flow_changed`, a
   sprinkle patter for SCATTER placement, little clicks for pearls and
   candies (`DecorationTool.placed`), a soft thunk when a tier lands
   (`CakeView.tier_added_visual`), a whoosh for undo/redo
   (`ToolController.undo_performed` / `redo_performed`) and UI taps
   (`IconButton.tapped`, card presses). A master volume setting.
2. Juice: a small pop (scale spring) for placed decorations, a puff of
   sugar-dust particles where a coat lands (`CoatTool.coat_applied`) and
   when the spatula finishes (`SpatulaTool.fully_smooth`), a gentle camera
   nudge (`OrbitCamera.nudge`) when a tier drops in, and a short cream
   fade-in at launch that hides the first-second shader compile stutter.
3. `docs/CREDITS.md` for any CC0 clips (none so far: everything is made in
   code).

**Remaining milestones** (from the original brief, in order):

- **F. Juice and audio** (see the steps just above).
- **G. UI polish and photo mode:**
  - Bigger icons, nicer tooltips, a way to pick up or erase a single
    decoration, and a check of every shelf at 1280x720 and 2560x1440.
  - A graphics quality option (SSAO, depth of field, glow, render scale)
    for weaker or throttling laptops (see Performance).
  - Photo mode: UI hidden, freer camera, click to focus, saves a PNG to
    `user://screenshots`.
- **H. Save/load and tests:**
  - Versioned JSON of tiers, strokes and decorations. Every data class
    already has `to_dict` / `from_dict` (strokes keep their click
    direction, decorations their words and drip angles).
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
- The room is closed on all sides (a wall behind the camera that is never on
  screen) so metal and glossy surfaces reflect a room, not black.
- Static props are merged per group, never into one huge mesh (so culling
  still works).
- Tip thumbnails are rendered in white and tinted on the card, so changing
  colour never re-renders them.
- Decorations draw with one MultiMesh per kind per tier; only drips and
  signs (built to fit, or with their own words) are separate meshes.
- A ganache drip that goes all the way round covers the whole top.
- Candles and toppers only go on top surfaces; the ghost fades where a
  piece is not allowed.
- Single-click shapes point along the camera's right at the moment of the
  click, and that direction is saved with the stroke.

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
| Decorations: click / drag / hold | Place one, a string (pearls), a spray (sprinkles), or drag along the rim (drips) |
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

- **Piping bag (B)**: pipe lines, dots, kisses, shells, flowers, leaves,
  ruffles, basketweave and grass with ten tips (see below). Tips, sizes and
  fine size are on the bottom shelf; colours on the right.
- **Frosting coat (C)**: pick a colour (and "Smooth buttercream" or
  "Semi-naked"), then click a tier. The new coat spreads from the top centre
  down the sides.
- **Smoothing scraper (F)**: hold it against a coated tier and let the cake
  spin under it (A / D or the ring), or drag along the side. Spatula marks fade
  to a glass-smooth finish; one undo step per press.
- **Decorations (V)**: pick a tab and an item on the shelf, then click,
  drag or hold on the cake (see "The decorations" below). Colours come from
  the palette unless the item has its own (cherries, gold, rainbow mixes).
- **Tiers (T)**: click a tier to select it, then pick a width (Petite, Small,
  Medium, Large) and height (Short, Classic, Tall), add a tier on top or
  remove one. Piping and decorations on a resized tier move with its surface.

## The piping tips

Ten tips, all data in `data/tips/` (shelf order):

| Tip | How it works | Drag | Click |
| --- | --- | --- | --- |
| Round | `RoundProfile` | lines, writing | dot / pearl (hold to grow) |
| Open Star | `StarProfile`, 8 soft ridges | ridged lines, borders | star kiss with a twist |
| Closed Star | `StarProfile`, 10 deep, tight grooves | bold borders, ropes | twisted star |
| Shell | `ShellStamp` on a star profile | a row of overlapping shells | one shell |
| Drop Flower | `DropFlowerStamp` on a 5-lobed star | a row of flowers | one flower with a sunny middle |
| Leaf | `LeafProfile` (V-notch vein, pointed sides), `end_style` POINT | a leaf drawn out to a point | a small leaf |
| Petal | `PetalProfile` (slanted teardrop) | swags, ribbons | one petal |
| Ruffle | `PetalProfile` with `frill`, plus `wave_amplitude` | a frilly border | one petal |
| Basketweave | `RibbonProfile` (flat band, ribbed top) | ribbons | one bar of the weave |
| Grass | `GrassStamp` (tufts of tapered strands) | a lawn | one tuft |

- **Clicks** (`click_length` above 0): a short piece laid along the surface
  the way the bag is held (the camera's right). The direction is stored in
  `StrokeData.forward`, so rebuilding from data (resizing a tier, loading)
  gives exactly the same piece.
- **Stamps** (`behavior` STAMP): `StrokeBuilder` places one every
  `stamp_spacing` tip radii along the drag; a `StampShape` subclass builds
  each one. Stamps are gathered into pieces of ~6000 vertices, and each gets
  a 24-triangle dome for picking (`StampShape.add_collision` /
  `collision_extent`) instead of its full geometry.
- **Thumbnails**: `TipThumbnails` pipes a small white sample of each tip in a
  hidden mini scene once at start-up; the tip cards tint it with the current
  colour. Its multisampling matches the main view (2x): a different setting
  made the GPU build a new pipeline and caused a 60 ms hitch.
- Sampler of every tip: `--scenario=tips --shots=... --angles=overhead,close`.

## Adding a new piping tip

1. Copy a file in `data/tips/` (for example `02_open_star.tres`) and rename it.
2. Change `id`, `display_name`, `description` and `sort_order`.
3. Adjust the profile numbers (points, depth, ridge fullness...) and the feel
   settings (end style, lift, click length, speed thinning, dwell growth,
   sizes).
4. Run the tests (they check every tip: valid data, sound geometry, live
   piping identical to a rebuild, fast enough). No code changes needed.

A brand-new cross-section shape needs a small `TipProfile` subclass in
`scripts/piping/profiles/` (one function that returns the outline points;
`counter_clockwise()` fixes the winding). A new repeated shape needs a
`StampShape` subclass in `scripts/piping/stamps/` (`emit` adds one stamp's
geometry). **After adding any new script with a `class_name`, run the
editor import once** (`--headless --path . --import`), or the game fails to
start with "Identifier not declared".

## The decorations

Eighteen decorations, all data in `data/decorations/` (one
`DecorationDefinition` each), in seven shelf tabs:

| Tab | Decorations | How you place them |
| --- | --- | --- |
| Sprinkles | rainbow sprinkles, confetti, nonpareils | hold and move to spray |
| Pearls | sugar pearls, gold and silver dragées | click for one, drag for a string |
| Chocolate | ganache drip, chocolate curls | drag along a tier's top edge / spray |
| Fondant | heart, star, blossom | click (they face up the screen) |
| Flowers | daisy, rose | click |
| Fruit | raspberry, blueberry, cherry | click |
| Candles & toppers | candle (lit), topper sign with your own words | click, top of a tier only |

How it works:

- **Definition** (`scripts/decorations/decoration_definition.gd`): what it
  is (id, name, tab, tags), how it is placed (`placement` SINGLE / LINE /
  SCATTER / RIM, `align` on the surface or upright, `facing` random or
  toward the viewer, `top_only`, spacing, spray radius and rate, sink, tilt
  and size jitter), how it looks (`builder`, optional `scene_override`
  .glb, `color_mode` PICKED / FIXED / MIX with `colors`, roughness,
  metallic, clearcoat, subsurface, pearl sheen, shadows) and its three sizes.
- **Builders** (`scripts/decorations/builders/`) make one piece at size 1
  with `MeshArrays`; vertex colour alpha marks the parts that take the
  piece's colour (a daisy's yellow middle keeps its own). Drips and topper
  signs are "unique": built per placed piece (drips from the tier's size and
  the rim angles in `DecorationData.path`; signs with `DecorationData.text`
  shown by a Label3D).
- **Drawing** (`DecorationLayer`, one per tier and one for the stand's
  plate): one MultiMesh per kind, with each piece's colour and a random
  number in the instance custom data (`art/shaders/decoration.gdshader`).
  Candle flames are one MultiMesh of billboards
  (`art/shaders/candle_flame.gdshader`) plus one flickering warm light per
  tier. Changes are applied once per frame, or at once with `flush()`.
- **Tool** (`DecorationTool`, key V): a translucent ghost shows the piece
  before you click (faded where it is not allowed); sprays re-pick the
  surface under every sprinkle so they land on piping, over the edge and on
  the stand; drips follow the cursor round the rim, and spinning the cake
  while holding pours further round. Everything from one press is one undo
  step (shown in a temporary layer while the button is held).
- **Shelf**: tabs over 3D cards (pictures by `ThumbnailRenderer`, the same
  one the tips use), three sizes, a hint for the current item, and the words
  for the topper sign.
- Decorations on a resized tier move with its surface (`ItemRemap`); drips
  rebuild to fit.

## Adding a new decoration

1. Copy a file in `data/decorations/` and change `id`, `display_name`,
   `description`, `category` (one of the tabs in
   `DecorationDefinition.CATEGORIES`) and `sort_order`.
2. Pick a builder and its numbers (a new shape needs a small
   `DecorationBuilder` subclass with `build()` and `radius()`), the placement
   settings and the look.
3. Run the import once if you added a script, then the tests (every
   decoration is checked for valid data and sound geometry).

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
- What each part of the bakery set costs: `... --path . -- --scenario=set_sweep`
- Shadow layout comparison: `... --path . -- --scenario=shadow_sweep`
- Tier demo: `... --path . -- --scenario=tiers --shots=C:/some/folder`
- Every tip on one cake: `... --path . -- --scenario=tips --shots=C:/some/folder --angles=overhead,close`
- Every decoration on a two-tier cake: `... --path . -- --scenario=decorations --shots=C:/some/folder --angles=front,close,high`
- Decorated cake benchmark: `... --path . -- --scenario=deco_bench`
- Extra flags: `--ui=true` keeps the interface in shots, `--tools=true` shows
  the piping bag, `--tool=tiers` picks a tool first.
- Benchmarks at a tiny window (`--resolution 384x216` before `--`) show the
  CPU cost on its own.
- Both executables live in `C:\Users\celia\CakeGame\`. Use the `_console`
  one from a terminal so you see the output.

## Performance

Measured on the target laptop (RTX 3050 6 GB Laptop GPU, 1600x900 window,
vsync off, on mains power).

**Laptop speed changes a lot.** Throttled (hot, or on battery) the same build
measured 47 fps where it now measures 149 fps. Only compare numbers taken
side by side, and alternate the two builds (B, C, B, C) when you do.

### End of milestone C (full bakery set)

| Case | Result |
| --- | --- |
| Empty cake | ~176 fps, GPU 5.1 ms |
| Overloaded 3-tier cake: 375 strokes, 373k frosting vertices, spinning | **149 fps avg, 129 fps 1% low**, no hitches, GPU 6.1 ms, CPU render 0.7 ms, scripts 0.3 ms |
| Piping a very long line live on that cake | stroke cost 1.5 ms avg per frame, scene 153 fps |
| Releasing that long line | 1.7 ms |
| Undo / redo of it | 0.2 ms / 1.7 ms |

At a tiny resolution (so the GPU barely works) the whole frame costs only
~2 ms of CPU, so the game is GPU-bound. What the set costs, measured with
`--scenario=set_sweep` (each part switched off on its own):

- Shading the room itself (walls, counter, backsplash) instead of a flat
  background: ~1 ms. That is the price of having a room.
- SSAO ~0.8–1.0 ms, depth of field ~0.6 ms, glow ~0.3–0.4 ms, the reflection
  probe ~0.2 ms, the window glow light ~0.2 ms, SMAA ~0.2 ms.
- Fog, colour adjustment, dust motes, vignette, curtains, window view: ~0.

What changed in C's performance pass:

- The "scripts" number in the benchmark was misleading: Godot's
  `TIME_PROCESS` monitor is the worst frame of the last second, not a
  per-frame value. The benchmark now times every node's `_process` itself
  (two probe nodes, first and last), counts hitches, skips its own warm-up
  frame, and no longer prints inside timed sections (console printing on
  Windows took ~28 ms and showed up as a fake "release" cost).
- The herb pot's 12 leaves were default spheres: 50,000 triangles. Now a
  low-poly basil (~700). The whole set went from 72k to 23k triangles.
- Static props are merged per group (window frame, shelf, each prop) into one
  mesh per material (`StaticBatcher`): about 45 fewer draw calls. Merging the
  whole set into one mesh was worse (nothing could be culled any more).
- The reflection probe only influences the space around the cake (it still
  captures the whole room).
- Idle interface widgets (buttons, swatches, tip cards, turntable ring) no
  longer redraw or tick every frame.

For weaker or throttling laptops the next step is a graphics quality option
(SSAO, depth of field, glow, render scale), planned with the settings in G.

### End of milestone A (before the set; grey background)

| Case | Result |
| --- | --- |
| Empty cake | ~160 fps, GPU 3.9 ms |
| Overloaded 3-tier cake, spinning | 112 fps avg, 94 fps 1% low, GPU 7.0 ms, 74 draw calls |
| Piping a very long line live on that cake | stroke cost 2.0 ms avg / 4.7 ms worst per frame, scene 104 fps |

Before milestone A the same cake ran at 30 fps (GPU 27 ms), and releasing
a long stroke cost ~39 ms. What changed then:

- Rings are only placed where the line bends or changes thickness (2.5x fewer
  vertices, no visible difference).
- The most expensive render settings were measured one by one and dialled
  down where the look did not suffer (soft shadow filter, sun disc size,
  bokeh quality, MSAA 4x -> 2x): empty-scene GPU time went from 18 ms to 4 ms.
- The live stroke's meshes are handed to the batch on release instead of
  being rebuilt; collision is built in small slices over a few frames.

## Known issues

- Decorations are not pickable (you cannot pipe on top of a fondant heart;
  the piping lands on the cake underneath).
- A single decoration can only be removed with undo or Clear all; a "pick
  up" or eraser is planned for G.
- Start-up: the first second can stutter while shaders compile; a short
  cream fade-in at launch would hide it (planned for F).
- Clicks with the petal and ruffle tips lean one way or the other depending
  on drag direction (like a real slanted tip); possibly worth an "always
  thin edge up" option.
- The topper sign's words come from a system font (Segoe UI); a bundled
  cosy font would look better (G).
- The interface still needs its polish pass (bigger icons, nicer tooltips,
  checks at other window sizes).
- On battery the laptop throttles to about half speed (heavy cake ~90 fps
  instead of ~150). Compare benchmark numbers only side by side.
- The end-to-end input test failed once, on its first run right after a fresh
  import (shaders were still compiling, so frames stalled). If it fails, run
  it again before investigating.
- Photo mode is still the simple "save a picture" from the look test (P key or
  the camera button).

## Ideas for later

- Pressure-sensitive pen tablet support (pressure straight into stroke pressure).
- A "steady hand" slider for players who want extra smoothing.

## Milestone log

- **E. Decorations.** Eighteen decorations as data in seven shelf tabs:
  sprinkles, confetti, nonpareils, sugar pearls, gold and silver dragées,
  ganache drip, chocolate curls, fondant heart / star / blossom, daisy,
  rose, raspberry, blueberry, cherry, lit candles and a topper sign with
  your own words. `DecorationDefinition` + builders, `DecorationLayer`
  (MultiMesh per kind, flames and a candle light per tier),
  `DecorationTool` (click, string, spray, rim drag; ghost preview; one undo
  step per press), a tabbed shelf with 3D cards (`ThumbnailRenderer`, now
  shared with the tips). Decoration tests, input test steps, showcase and
  benchmark scenarios. The per-tip speed test now compares with the round
  tip so it does not fail on battery.
- **D. The ten tips.** Closed star, shell, drop flower, leaf, petal, ruffle,
  basketweave and grass join round and open star, all as data. New
  `LeafProfile`, `PetalProfile` (with a frill for ruffles), `RibbonProfile`,
  and `ShellStamp`, `DropFlowerStamp`, `GrassStamp`. Clicks with leaf, petal
  and basketweave make a small leaf, petal or bar pointing the way the bag
  is held; that direction is now saved with the stroke, so rebuilds match.
  Stamps are gathered into large pieces with light dome collision. 3D tip
  thumbnails tinted with the current colour. Content tests, a per-tip speed
  test and a tip sampler scenario.
- **C. Lighting and set.** Seaside bakery set built in code, new light rig,
  reflection probe, haze, dust motes, vignette, stronger depth of field,
  camera orbit limits. Performance pass (see Performance). Art pass: the
  cake now shades across its face with a soft sheen band (fill light swung
  to the side with more specular, less flat ambient, AgX contrast up, less
  subsurface and rim), no more bright fringe on white piping (higher bloom
  threshold, frosting ripples fade out at the silhouette, SMAA on top of 2x
  MSAA), a soft periwinkle sky and calm blue sea with big clouds and a hazy
  horizon, sheer café curtains tied back with a ribbon, a low-poly basil
  plant instead of the "cactus", marble with flowing veins instead of
  contour rings, a filled piping bag, and a wall behind the camera so the
  steel nozzle and glossy surfaces reflect a room instead of black.
- **B. Turntable and tiers.** Tier tool with data-driven width/height presets,
  add/remove/resize with undo (piping follows the surface), frosting coat
  tool with a spreading-coat animation, semi-naked sponge look, smoothing
  scraper, on-screen turntable ring, new cozy interface layout (tool rail,
  shelves, palette, top bar, help card, clear-all confirm), command tests.
- **A. Version check and piping core.** 4.7.2 check. New data model,
  command-based undo/redo, incremental stroke builder, merged stroke batches,
  turntable-proof picking, piping bag and cursor preview, dev runner for
  screenshots, benchmarks and input tests.
