# CakeGame (working title)

A cozy seaside bakery game: bake from recipes, decorate cakes by hand in 3D, and
fit each customer's theme. Windows PC on Steam only, mouse-first, built in Godot
(GDScript, Forward+ renderer).

## Open the project

1. Install Godot 4.x (Standard build) from godotengine.org.
2. In Godot's Project Manager choose **Import**, pick this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** to run. You should see a pink cake tier on a grey background, and the
   Output panel should print `CakeGame project loaded OK`.

If your Godot is newer than 4.6, it may offer to convert the project. Accept.

## First Git commit

```
git init
git lfs install
git add .
git commit -m "Initial Godot project structure"
```

Then create a private GitHub repository and follow its "push an existing repository" steps.

## Folder layout

| Folder | What goes there |
| --- | --- |
| `art/` | models, materials, textures, UI art |
| `audio/` | music and sound effects |
| `data/` | content as data files: tips, ingredients, decorations, recipes, customers, orders |
| `scenes/` | Godot scenes: main, bakery, decorating, town, ui |
| `scripts/` | GDScript: core, cake, piping, orders, economy, ui, save |
| `addons/` | plugins, such as the Steam integration later |
| `docs/` | design notes |
| `builds/` | local exports (ignored by Git) |

Content lives in data files (Godot custom Resources) instead of code, so adding a
topping, recipe or customer does not need a code change.
