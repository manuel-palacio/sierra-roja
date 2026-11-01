# Sierra Roja

A real-time stealth tactics game for the desktop browser, set in the Spanish Civil War. You command two
fictional Republican guerrillas, the Dynamiter and the Marksman, through one night mission: blow up the
Nationalist railway bridge, then get both of them to the extraction pad. Low-poly 3D, fixed isometric
camera, Godot 4.7 (Compatibility renderer, single-threaded web export). "Sierra Roja" is a working title.

## Controls

| Input | Action |
|---|---|
| Left click on ground | Move the selected specialist (double-click to run) |
| Left click on a specialist | Select them (or press `1` / `2`) |
| Left click on a guard | Show that guard's vision cones |
| `Q` Knife, `R` Pistol, `E` Rifle (Marksman) | Arm the ability, then click a guard; `Esc` or right click disarms |
| `E` Charge (Dynamiter) | Plants a charge at your feet on the key press (10 s fuse) |
| `F` Carry | On the key press, lifts the nearest body in reach, or drops the one you carry |
| `C` | Crawl / stand |
| `Space` | Pause / resume |
| `O` / `L` | Quick save (not once the mission has ended) / quick load |
| Mouse wheel | Zoom |
| Mouse at the screen edge | Scroll the camera |

Sound starts after your first click or key press (browser rule).

## Test

    ops/test.sh                 # GUT unit and mission tests (headless Godot)
    ops/build-web.sh && npx playwright test   # real-build checks; the perf spec runs headed

## Build and serve

    ops/build-web.sh            # exports to build/web
    ops/serve.sh                # http://127.0.0.1:8003/; override with SIERRAROJA_HOST, SIERRAROJA_PORT

The game needs a secure context: over plain HTTP the browser has no audio worklet, and the page says
so instead of starting. `localhost` counts as secure. To play from another machine, put the build
behind HTTPS.

Credits for the third-party art and sound are in `CREDITS.md`.
