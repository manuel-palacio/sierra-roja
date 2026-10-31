# Sierra Roja: first milestone design

Date: 2026-10-31
Status: awaiting review
"Sierra Roja" is a working title. Check that no other game uses it before any public release.

## Goal

Build a new real-time stealth tactics game inspired by the genre of Commandos: Behind Enemy Lines,
set in the Spanish Civil War. The first milestone is one small playable mission, whose purpose is to
find out whether the stealth is fun.

## Decisions

| Topic | Decision |
|---|---|
| Relationship to the original | New game. Reuses genre mechanics only |
| Original game files | Not used, extracted or referenced in the repo |
| Setting | Spanish Civil War |
| Player side | Fictional Republican guerrilla squad |
| Platform | Desktop browser, mouse and keyboard |
| Engine | Godot 4, GDScript, single-threaded web export |
| Visuals | Low-poly 3D with a fixed isometric camera |

## Content rules

- No original maps, art, audio, text or names from Commandos.
- Characters are fictional. Real battles may be used as settings, but real people do not speak or act
  in the game.
- Missions focus on sabotage and rescue against military targets, not the wider politics.
- Fascist and Condor Legion symbols are avoided in the first milestone. Their use needs a separate
  decision and a legal check before any public release.
- Only assets whose licence allows redistribution enter the repo. `CREDITS.md` records each asset's
  source and licence.

## First mission

Blow up a Nationalist railway bridge at night, then escape.

- Win: the bridge is destroyed and both specialists reach the extraction point.
- Lose: either specialist dies.
- Opposition: three guards.
- Art: placeholder models. Audio: placeholder sounds.

## Stealth rules

- **Vision cones:** clicking a guard shows their cone. The near zone spots the player in any stance.
  The far zone spots the player only when standing, so crawling passes through it. Walls and height
  block sight.
- **Noise:** running, gunfire and explosions have a radius. Guards inside it investigate.
- **Guard states:** patrol, suspicious, investigate, alarm.
- **Alarm:** guards converge on the last known position, then eventually return to patrol, more alert
  than before ("more alert" means a longer vision range, set per mission).
- **Bodies:** a guard who finds a body raises the alarm. Bodies can be carried out of sight.

## Specialists

| | Dynamiter | Marksman |
|---|---|---|
| Main ability | Plants a timed charge | Long-range rifle, few bullets, each shot loud |
| Stealth kill | Knife, up close | None |
| Carries bodies | Yes | No |

Both can walk, run, crawl and use a pistol, which is loud.

## Controls

Click to move, double-click to run, hotkeys for stance and abilities, edge-scroll and zoom for the
camera. Pause lets the player look around the map. Quick save and quick load.

## Out of scope for this milestone

Disguises, vehicles, swimming, the campaign, story scenes, more specialists, final art and audio,
touch controls, a Mac app, and anything from the Vampire: The Masquerade - Redemption idea.

## Architecture

Game rules do not depend on what is on screen, so detection and AI can be tested headlessly.

| Part | Job | Depends on |
|---|---|---|
| Mission | Map geometry, spawn points, patrol routes, objectives | Nothing |
| Units | Movement, stance, health, carrying bodies, using Godot navigation | Mission map |
| Abilities | One small script each: knife, charge, rifle, pistol, carrying | Units |
| Perception | Whether a guard sees or hears something: cones, stance, line of sight, noise | Units, physics |
| Guard AI | Patrol, suspicious, investigate and alarm states | Perception, Units |
| Mission rules | Objectives, win and loss, alarm level | Signals from other parts |
| Player input and camera | Turns clicks and hotkeys into orders | Units, Abilities |
| HUD and overlays | Portraits, ability bar, vision cones. Display only | Units, Perception |
| Save and load | Mission state as JSON in browser storage. Each part saves its own state | All stateful parts |

**Missions** are Godot scenes, with patrol routes placed as paths on the map. Unit stats and mission
settings are Godot text resource files. A new mission needs no engine code.

**Libraries:** Godot provides navigation, physics, animation and web export. GUT provides unit tests.
Playwright drives the web build. The guard AI is a hand-written GDScript state machine, because four
states do not justify a behaviour-tree library.

## Error handling

- **Bad mission data:** checked on load for missing spawn points, empty patrol routes and unreachable
  objectives. Development builds stop with a clear message, and tests catch the same problems before a
  build goes out.
- **Unreachable move orders:** the unit goes to the nearest reachable point. A stuck guard picks its
  next waypoint.
- **Saves:** each records a version number. A corrupt or out-of-date save produces a message and an
  offer to restart the mission.
- **Browser:** without WebGL2, the page shows a plain message explaining why the game cannot start.

## Testing

| Layer | Checks | How |
|---|---|---|
| Rules | Vision zones by stance, walls blocking sight, noise radius, guard state changes, win and loss | GUT, headless |
| Mission | Mission data valid, every objective reachable | GUT, headless |
| Scripted run | A bot follows a fixed route, plants the charge and escapes | Headless on each change |
| Browser | Web build loads without console errors, screenshots show the map and cones | Playwright |
| Performance | Frame rate on the real mission with every guard active | Measured in the web build |

Tests cannot show whether the game is fun or whether the controls feel right. Manuel judges both.

## Build and hosting

- Web builds use the single-threaded export, which needs no special server headers.
- The host machine serves the static build over Tailscale on a new port. Manuel loads its launchd agent
  himself, because agent loading is blocked for Claude on this machine.
- The repo lives at `~/Projects/sierra-roja` and `manuel-palacio/sierra-roja` on GitHub, private
  until a release is decided.

## Performance

Target 60 fps, minimum 30 fps, on a mid-range laptop in a desktop browser, with every guard active.
Godot web builds use the Compatibility renderer, so lighting is simpler than on a native build.

If the target is missed, first simplify the map and lighting and reduce how often guards run vision
checks. Rethink the browser as the main platform only if that fails. This is measured early, because
it is the main technical risk.

## Definition of done

1. The game opens in a desktop browser over Tailscale and the mission starts.
2. Both specialists can be controlled with every ability: movement, stance, knife, charge, rifle,
   pistol and carrying bodies.
3. Three guards patrol, spot the player by the vision rules, react to noise and bodies, and can raise
   the alarm and later stand down.
4. Destroying the bridge and reaching extraction wins. Losing either specialist fails the mission.
5. Pause, quick save and quick load all work.
6. All automated tests pass.
7. The performance target is met, measured on the host machine and confirmed by Manuel on the computer he
   plays on.
8. Manuel has played it and decided whether to build more missions or change the rules first.

## Open items for the plan

- Godot is not installed on the host machine. The plan's first step installs a pinned Godot 4 version with
  its web export templates.
- Choose the specific CC0 model packs and the port for the static build.
