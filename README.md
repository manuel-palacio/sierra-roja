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
| `Q` Knife, `E` Charge / Rifle, `R` Pistol, `F` Carry | Arm an ability, then click a target; `Esc` or right click disarms |
| `C` | Crawl / stand |
| `Space` | Pause / resume |
| `O` / `L` | Quick save / quick load |
| Mouse wheel | Zoom |
| Mouse at the screen edge | Scroll the camera |

Sound starts after your first click or key press (browser rule).

## Test

    ops/test.sh                 # GUT unit and mission tests (headless Godot)
    ops/build-web.sh && npx playwright test   # real-build checks; the perf spec runs headed

## Build and serve

`build/` is not in git, so build first, then serve:

    ops/build-web.sh            # exports to build/web
    ops/serve.sh                # http://100.64.0.1:8003/ (Tailscale); SIERRAROJA_HOST=127.0.0.1 for local only

To keep it running, load the agent in place (no copy into LaunchAgents is needed) with
`launchctl bootstrap gui/$(id -u) ops/com.sierraroja.serve.plist` (logs in `logs/serve.log`).

Credits for the third-party art and sound are in `CREDITS.md`.
