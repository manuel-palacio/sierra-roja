# Sierra Roja

A real-time stealth tactics game for the desktop browser, set in the Spanish Civil War. You command two
fictional Republican guerrillas, the Dynamiter and the Marksman, through one night mission: blow up the
Nationalist railway bridge, then get both of them to the extraction pad. Low-poly 3D, isometric
camera, Godot 4.7 (Compatibility renderer, single-threaded web export). "Sierra Roja" is a working title.

## Controls

| Input | Action |
|---|---|
| Left click on ground | Move the selected specialist (double-click to run) |
| Left click on a specialist | Select them (or press `1` / `2`) |
| Left click on a guard | Show that guard's vision cones (red: seen even crawling; yellow: seen standing) |
| `Q` Knife, `R` Pistol, `E` Rifle (Marksman) | Arm the ability, then click a guard; `Esc` or right click disarms |
| `E` Charge (Dynamiter) | Plants a charge at your feet on the key press (10 s fuse) |
| `F` Carry | On the key press, lifts the nearest body in reach, or drops the one you carry |
| `C` | Crawl / stand |
| `Space` | Pause / resume |
| `O` / `L` | Quick save (not once the mission has ended) / quick load |
| Mouse wheel | Zoom |
| `Z` / `X` | Turn the camera a quarter turn |
| Mouse at the screen edge | Scroll the camera |

The game opens on a briefing with the objectives and these controls; `Start`, `Enter` or `Space`
begins. Sound starts after your first click or key press (browser rule).

The map is authored as numbers in `tools/make_bridge_map.py`, which writes the land
(`resources/missions/bridge_land.tres`) and the mission scene; `tools/map_preview.gd` draws the
result from above. The uniforms come from `tools/recolour_uniforms.py`.

## Run it locally

You need:

- [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) with `godot` on your `PATH`
  (on a Mac: `brew install --cask godot`).
- Godot's 4.7.2 web export templates. In the Godot editor, open Editor > Manage Export Templates and
  download them.
- Python 3 and a desktop browser with WebGL2. `ops/serve.sh` also needs `zsh`, which Macs have.

Then, from the repo root:

    ops/build-web.sh            # exports the game to build/web
    ops/serve.sh                # serves it until you press Ctrl+C

Open http://localhost:8003/ and click the game once to enable sound. To use another port, start it
with `SIERRAROJA_PORT=8080 ops/serve.sh`. Run `ops/build-web.sh` again after changing the game.

The game only starts in a secure context: over plain HTTP the browser has no audio worklet, and the
page says so instead of starting. `localhost` counts as secure, so to play from another machine, put
the build behind HTTPS.

## Test

Install the browser test tools once with `npm install`, then:

    ops/test.sh                 # GUT unit and mission tests (headless Godot)
    ops/build-web.sh && npx playwright test   # real-build checks; the perf spec opens a window

Credits for the third-party art and sound are in `CREDITS.md`.
