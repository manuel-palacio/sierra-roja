# Sierra Roja

A real-time stealth tactics game for the browser, on a desktop or on a phone or tablet held sideways, set in the Spanish Civil War and after. You
command two fictional Republican guerrillas, the Dynamiter and the Marksman, through six missions set at
real events, in the order of their dates:

1. **Sierra de Guadarrama, May 1937.** Blow up a bridge behind the lines as the Segovia offensive opens.
2. **Teruel, December 1937.** Raid a depot in the snow.
3. **Fort Carchuna, 23 May 1938.** Bring a prisoner out by night.
4. **The Ebro, 24–25 July 1938.** Silence the sentries on the far bank before the boats cross.
5. **The Volkhov front, early 1942.** In exile and in Soviet service: steal the División Azul's orders.
6. **Krasny Bor, 9 February 1943.** Cut the telephone lines and blow up the artillery store, the night
   before the battle.

Both of them have to get out each time. The events, places and dates are real; the pair and their part in
each are invented, and the game says so. Low-poly 3D, isometric camera, Godot 4.7 (Compatibility
renderer, single-threaded web export). "Sierra Roja" is a working title.

## Controls

| Input | Action |
|---|---|
| Left click on ground | Move the selected specialist (double-click to run) |
| Left click on a specialist | Select them (or press `1` / `2`; press the same key again to bring the camera to them) |
| Left click on a guard | Show that guard's vision cones (red: seen even crawling; yellow: seen standing), and a panel with his portrait, whether he is a sentry or a patrol, and his state |
| `3` | Select both: move and stance orders go to both |
| `Q` Knife, `R` Pistol, `E` Rifle (Marksman) | Arm the ability, then click a guard; `Esc` or right click disarms |
| `E` Charge (Dynamiter) | Plants a charge at your feet on the key press (10 s fuse) |
| `T` Stone | Arm it, then click a spot within 12 m in clear view: the stone lands there and the guards in earshot (9 m) walk over to look, wait, and go back. No alarm comes of it. A few seconds pass before the next; a guard brought out twice in a short while waits longer the second time |
| `F` Use / Carry | Uses or takes what is next to you (a cell door, the orders, a telephone pole to cut), or puts down what you hold; otherwise the Dynamiter lifts the nearest body in reach, or drops the one carried |
| `C` | Crawl / stand |
| `Space` | Pause / resume |
| `O` / `L` | Quick save (not once the mission has ended) / quick load |
| Mouse wheel | Zoom |
| `Z` / `X` | Turn the camera a quarter turn |
| `M` | Map: the whole ground at once, with each guard and the beat he walks, the pair, and the way out. `M` again goes back |
| Mouse at the screen edge | Scroll the camera |

On a phone or a tablet the game is played with fingers, and the briefing says so:

| Touch | Action |
|---|---|
| Tap the ground | Move the selected specialist (double tap to run) |
| Tap a specialist or a guard | Select them / show the guard's vision cones; a tap just beside one counts |
| Drag | Scroll the view |
| Two fingers | Pinch to zoom, twist to turn the camera a quarter turn |
| The pictures, bottom right | The abilities: tap one, then its target; tap it again to put it away |
| The buttons, top right | Both, Crawl, Use (what `F` does), Map, Save, Load, Pause |

The HUD and the briefing are drawn larger there, and a phone held upright is asked to turn. The touch
buttons also appear on any screen from the first touch on; `?touch=1` in the address shows them from the start.

The game is in English and Spanish. It starts in the browser's language; the button under the list of
missions on the briefing switches, and the choice is kept in the browser (`?lang=es` or `?lang=en` in the
address sets it too). The Spanish is in `assets/i18n/es.po`, looked up by the English text as it stands in
the code and the scenes; `tests/ui/test_language.gd` fails when a text has none.

The game opens on its title, which says what the game is and lists its six missions: `Start`, `Enter` or `Space` goes on, and `Continue`, once a mission is won,
goes to the furthest mission that is open. Then comes a briefing with the objectives and these controls; `Start`, `Enter` or `Space`
begins. Sound starts after your first click or key press (browser rule).

The missions are a campaign in date order: the briefing lists them with their place and date, tells
what history says of each, and opens the next one when the one before is won (wins are kept in the
browser). A win shows what really happened. `?mission=<id>` (`guadarrama`, `teruel`, `carchuna`, `ebro`, `volkhov`, `krasny_bor`) in the
address starts on that mission whether it is open or not.

The briefing also sets how sharp the guards are: Easy (they take longer to be sure, see less far and hit
less hard), Normal, or Hard (quicker to raise the alarm, slower to stand down, and their rifles hit harder;
no distance changes, so a way that is unseen on Normal is unseen on Hard). The choice is kept in the browser.

A win shows its score: the time, the guards killed, the alarms raised and the quick loads used, and the
name it earns (Ghost: no alarm and nobody killed; Unseen: no alarm; Done). The best win of each mission
is kept in the browser and shown on its briefing.

What a mission asks for is a list of objectives in its scene:

- **Destroy** something with the Dynamiter's charge.
- **Rescue** a prisoner: open his cell and bring him out.
- **Steal** something and carry it out.
- **Silence** named sentries before a clock runs out, with no alarm raised anywhere until the last is down.
- **Cut** telephone lines at marked poles.

Haystacks and trucks are hiding places, marked `F: hide` when one of the pair is near. `F` beside one with a
body in your arms leaves the body inside, where no guard finds it; with empty arms it hides the specialist,
who is then seen by nobody and can do nothing until `F` or an order to move brings them out. Each holds one
body and one person, and nobody gets in while a guard is suspicious or alarmed.

`F` uses what is next to the selected specialist (a cell door), takes up what lies there (the orders) and
puts it down again, and at a marked pole starts cutting the line, which takes four seconds of standing
still. Whoever holds something cannot carry a body.

A mission's map tables also say how it looks: `SEASON` ("summer" or "snow": the land, trees, roofs and a
frozen river drawn for winter), `LIGHT` ("dawn", "overcast", "dusk", or "predawn" with `NIGHT`), `SNOWFALL`,
and `DRESS` (which uniforms its units wear: "spain_winter" or "russia"). None of these changes the rules:
snow and white smocks hide nobody.

Each mission's map is authored as tables of numbers in its own file (`tools/make_bridge_map.py`,
`tools/make_powder_map.py` (Teruel), `tools/make_carchuna_map.py`, `tools/make_ebro_map.py`,
`tools/make_volkhov_map.py`, `tools/make_krasny_bor_map.py`), which `tools/mapgen.py` turns into the land
(`resources/missions/<name>_land.tres`) and the mission scene; `tools/map_preview.gd` draws the
result from above. A new mission is a new table file and a line in `src/mission/missions.gd`. The
soldier model and its uniforms come from `tools/make_soldier.py`; helmets, caps, rifles and bags
are in `src/units/soldier_gear.gd`, and `tools/unit_preview.gd` renders the units close up.

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

Units behind trees and walls show through as flat silhouettes. If your browser does not draw them,
add `?markers=1` to the address: every guard then gets a ring on the ground that is always visible.

The game only starts in a secure context: over plain HTTP the browser has no audio worklet, and the
page says so instead of starting. `localhost` counts as secure, so to play from another machine, put
the build behind HTTPS.

## Host it on Fly.io

Every push to `main` on GitHub is tested, built and deployed by `.github/workflows/deploy.yml`; a push
whose tests fail deploys nothing. It needs the repository secret `FLY_API_TOKEN` (a Fly deploy token for
the app; the command is at the top of that file). To deploy by hand from your own machine,
`ops/deploy-fly.sh` builds the game and deploys it as a static site (`Dockerfile`, `ops/nginx.conf`,
`fly.toml`). It needs the [fly CLI](https://fly.io/docs/flyctl/), logged in, and an app with the name in
`fly.toml` (`fly apps create <name>` once). The site is public, served over HTTPS, and its one machine
stops while nobody is playing.

## Test

Install the browser test tools once with `npm install`, then:

    ops/test.sh                 # GUT unit and mission tests (headless Godot)
    ops/build-web.sh && npx playwright test   # real-build checks; the perf spec opens a window

Credits for the third-party art and sound are in `CREDITS.md`.
