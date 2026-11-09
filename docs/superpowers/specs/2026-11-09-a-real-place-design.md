# Sierra Roja: second milestone design, "a real place"

Date: 2026-11-09
Status: approved by Manuel on 2026-11-09 (design approved in conversation; he asked for the spec
and plan to be written and committed without a separate review, then built)

## Goal

The first milestone proved the rules. Playing it, Manuel found the scene hard to read, the map dull,
and the placeholder look too rough to enjoy. This milestone turns the bridge mission into a place:
terrain with height, a map with routes to choose between, night lighting, real props, and the
on-screen help needed to read what is going on. The stealth rules do not change.

## Decisions

| Topic | Decision |
|---|---|
| Terrain | Low-poly height-field mesh generated in the repo, with matching collision |
| Terrain library | None. Terrain3D was considered; its web export is experimental and needs custom export templates |
| Map | The same mission (blow the bridge, extract), on a new, larger layout with three routes |
| Guards | Five instead of three; one stands sentry on the bridge |
| Stealth rules | Unchanged. No hiding in grass, no light-dependent vision |
| Characters | The blocky figures stay, with clearer uniforms and a prone pose instead of the squash |
| Props | CC0 model kits only, each recorded in `CREDITS.md` |
| Renderer | Still Compatibility, single-threaded web export |

## Terrain

- The mission owns a height field: a grid of heights over the mission bounds. A `Terrain` node turns
  it into a flat-shaded mesh and a `HeightMapShape3D` on the world collision layer, so sight rays,
  mouse picking and the navmesh bake all see the same ground.
- The height field is produced by a deterministic generator from a short list of authored features
  (gorge, embankment, hill, road, flattened pads for buildings) plus low-amplitude noise. The same
  input always gives the same land, so tests and saves stay stable.
- Colour comes from slope and height: grass, dry earth, rock on steep faces, ballast under the track,
  packed dirt on the road. It is baked into vertex colours; no texture splatting.
- Slopes steeper than a walkable limit are not walkable. The navmesh bake enforces this, and the
  rock colour shows it.
- Units already take their height from the navmesh. That stays.
- The terrain extends past the playable bounds as a skirt, and fog hides its end, so the map no
  longer ends in a cut slab.

## Map layout

West to east: the squad starts in the south-west. The railway crosses the map on an embankment and
spans the gorge on the bridge. The extraction point is on the east bank.

| Route to the bridge | Character |
|---|---|
| The road through the checkpoint | Short, lit, guarded by two patrols |
| Along the gorge edge under the embankment | Hidden from the top by height; narrow, with one crawl-only stretch in a far vision zone |
| Over the hill past a ruined farmhouse | Long; high ground with a rifle line onto the bridge sentry |

Cover is rocks, dry-stone walls (hide a crawler, not a stander), tree trunks and buildings. The
twelve crates go, apart from a few at the checkpoint.

Five guards: two at the checkpoint, one walking the track, one sentry on the bridge, one patrolling
the east bank near the extraction. The mission must stay winnable without being seen, proved by the
scripted bot run.

## Graphics

- Moonlight casts shadows. A second, dim fill light keeps shadowed faces readable.
- Night sky with stars instead of a flat colour, and distance fog matched to the horizon.
- The river is a moving-water shader on a plane in the gorge.
- Warm lamps at the checkpoint and the guard hut, with visible lamp posts.
- Props from CC0 kits: pines and scrub, rocks, dry-stone walls, fences, the checkpoint hut, a ruined
  farmhouse, sleepers and rails, bridge trusses.
- Guards and specialists get uniforms that read apart at a glance at night.
- Crawling uses a prone pose.

## Readability

- Vision cones follow the ground instead of floating on a flat plane.
- A marker above a guard shows `?` when suspicious or investigating and `!` when alarmed.
- A short-lived marker shows where a move order landed. Selection rings are clearer.
- A unit behind a tree or building shows as a silhouette.
- The camera rotates in 90 degree steps with `Z` and `X`. Edge scroll and zoom work as before in
  every orientation.

## Briefing

- The game opens on a briefing screen: mission title, objective, the controls, and a start button.
  The first click also unlocks sound.
- The HUD shows the current objective: "Destroy the bridge", then "Reach the extraction point".

## Architecture

New parts, each with one job:

| Part | Job | Depends on |
|---|---|---|
| `HeightField` | Grid of heights with sampling (height and slope at a point) | Nothing |
| `TerrainGenerator` | Builds a `HeightField` from authored features and seeded noise | `HeightField` |
| `Terrain` | Scene node: mesh, vertex colours and collision from a `HeightField` | `HeightField` |
| `PropScatter` | Places trees, rocks and scrub from seeded rules, keeping clear of paths and pads | `HeightField` |
| `GuardMarker` | The `?` / `!` marker above a guard. Display only | Guard state |
| `OrderMarker` | The move-order marker. Display only | Player input signal |
| `Briefing` | The opening screen | Nothing |

Changed parts: `Mission` (terrain source for the navmesh bake, five guards), `VisionOverlay` (drape
on terrain), `IsoCamera` (rotation), `UnitVisual` (prone pose, silhouette), `MissionValidator`
(spawns and route points must lie on walkable ground), `main.tscn` (lighting, sky, fog), the HUD
(objective line), and the save schema only if a new field is needed (camera rotation is not saved).

Game rules still do not depend on what is drawn. Props that block sight or movement carry collision
on the world layer; decorative ones carry none and are skipped by the navmesh bake.

## Error handling

- The validator fails a mission whose spawn, route point, objective or extraction is off the navmesh
  or on a slope over the walkable limit.
- A prop kit model that fails to load stops a development build with the file name.
- Saves from the first milestone do not fit the new map. The save version goes up, and an old save
  gives the existing "out of date" message.

## Testing

| Layer | Checks |
|---|---|
| Height field | Sampling, slope, determinism of the generator for a fixed seed |
| Terrain | Collision height matches the field; a hill blocks a sight ray that flat ground would not |
| Mission | Validator passes on the new map; every route and objective is reachable; five guards patrol |
| Scripted run | The bot wins unseen on the new map, and is caught when it walks the road |
| Camera | Rotation keeps the focus point; edge scroll moves the right way in each orientation |
| Browser | Build loads with no console errors; screenshots reviewed by eye for each slice |
| Performance | 30 fps or better in the browser check with all five guards active |

All existing tests keep passing or are updated for the new map in the same change.

## Delivery

Four slices, each playable, tested and pushed:

1. Terrain and the new map, on the existing look.
2. Lighting, sky, water and props.
3. Readability and camera rotation.
4. Briefing and objective line.

## Out of scope

New characters, new stealth rules, more missions, music, touch controls, and a native build.

## Definition of done

1. The mission plays on the new terrain with three distinct routes and five guards.
2. Height blocks sight and steep ground blocks movement.
3. Shadows, sky, fog, water, lamps and props are in, and the map has no visible edge.
4. Cones follow the ground, guard markers and order markers show, silhouettes work, the camera rotates.
5. The briefing opens the game and the HUD shows the objective.
6. All automated tests pass, including the scripted win and the 30 fps browser check.
7. Manuel has played it.
