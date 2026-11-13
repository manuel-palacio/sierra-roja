# Sierra Roja: third milestone design, "a campaign from history"

Date: 2026-11-12
Status: approved by Manuel on 2026-11-12 (design, then this written spec). All three batches are built (2026-11-13).

## Goal

The game has two missions with the same objective (blow something up, get out), each also offered
"by night". Manuel wants missions taken from real events of the Spanish Civil War, mixed with the
Eastern Front and the División Azul. This milestone turns the mission list into a six-mission
campaign in date order, 1937 to 1943, with a different thing to do in most missions and a winter
setting for Teruel and Russia.

## Decisions

| Topic | Decision |
|---|---|
| Player characters | The same two fictional guerrillas throughout. After 1939 they are exiles in the USSR, serving in a Soviet guerrilla unit against the División Azul |
| History | Events, places and dates are real; the pair and their part in each event are invented, and the briefing says so |
| Missions | Six, in date order (table below) |
| Existing missions | The bridge becomes mission 1, the powder store becomes mission 2 re-dressed in snow |
| Night variants | "The bridge by night" and "The powder store by night" are removed. Night belongs to the missions where it was true |
| Objectives | A list each mission declares, replacing the rules that know only one bridge |
| Symbols | No swastikas or other Nazi symbols are drawn. The División Azul is told apart by field grey and the red-and-yellow arm shield |
| Stealth rules | Unchanged |
| Renderer, export | Unchanged: Compatibility, single-threaded web |

## The campaign

| # | Id | Date and place | Objective | Setting |
|---|---|---|---|---|
| 1 | `guadarrama` | End of May 1937, Sierra de Guadarrama | Destroy the bridge | Dawn |
| 2 | `teruel` | December 1937, outside Teruel | Destroy the supply depot | Snow, day |
| 3 | `carchuna` | 23 May 1938, Fort Carchuna, Granada coast | Free the prisoners' officer and bring him out | Night |
| 4 | `ebro` | Night of 24–25 July 1938, the Ebro | Silence the bank sentries before the boats cross | Night, searchlights |
| 5 | `volkhov` | Early 1942, Volkhov front | Steal the orders from a División Azul command post | Snow, dusk |
| 6 | `krasny_bor` | 9–10 February 1943, Krasny Bor | Cut the telephone lines and destroy the artillery store | Snow, before dawn |

Every mission still ends with both specialists alive at the extraction point.

### Historical notes

Each mission shows a short note before it and a "what really happened" note after it. The text
below is what the sources checked on 2026-11-12 support. Where a source was thin, the wording is
kept loose on purpose; nothing stronger goes into the game without a further source.

| # | What is real | What is invented | Sources |
|---|---|---|---|
| 1 | The Republican Segovia offensive ran from 31 May to 6 June 1937 (another account has it open on the 30th, so the game says "the end of May"), to draw Nationalist forces away from their advance on Bilbao. It reached La Granja, was counter-attacked on 1 June and was over within the week; it held up the offensive against Bilbao by about two weeks. It is the offensive in Hemingway's *For Whom the Bell Tolls*, in which a dynamiter blows a bridge behind the lines | The bridge itself, as in the novel | [Segovia Offensive](https://en.wikipedia.org/wiki/Segovia_Offensive) |
| 2 | The Republican attack on Teruel began on 15 December 1937 while snow fell, with no preliminary air or artillery bombardment. A four-day blizzard followed, with temperatures of −18 °C. Republican forces were in the town by 21 December and the garrison surrendered on 8 January 1938; the Nationalists retook Teruel on 22 February 1938 | The depot raid | [Battle of Teruel](https://en.wikipedia.org/wiki/Battle_of_Teruel) |
| 3 | 308 Asturian soldiers, captured after the Nationalist victory in the north, were held in the fort of Carchuna, very close to the front. Four officers escaped to Republican lines on 16 May 1938, and the rescue was planned on what they told. 35 volunteers, five of them from the International Brigades, crossed by launch from Castell de Ferro on the 23rd, took the fort and led the prisoners back to Republican lines in two columns under cover of an artillery barrage. Twenty-five prisoners chose to stay in the fort | The pair's place in the raid; in the game one prisoner stands for the 308 | [The fort of Carchuna](https://vscw.ca/en/node/345) |
| 4 | The Republican army started the crossing of the Ebro on the night of 24–25 July 1938, during a no-moon period; the first wave was ninety boats, each carrying ten men. The page says Republican commandos crossed the river, killed the Nationalist guards and fastened lines for the assault boats. The battle was the longest and largest of the war and ended on 16 November 1938 | The pair being those men; as one page is the only source checked for them, the note says "it is said" | [Battle of the Ebro](https://en.wikipedia.org/wiki/Battle_of_the_Ebro) |
| 5 | The División Azul, a unit of volunteers from Francoist Spain within the German army (its 250th Infantry Division), was first deployed on the Volkhov river front (the page gives no date for that; a photograph it carries shows the division's soldiers on skis near the Volkhov in 1942, so the game says "early 1942"), and in August 1942 was transferred north to the south-eastern flank of the siege of Leningrad. Spanish Republican exiles in the USSR served in Soviet guerrilla units, and some died fighting near Leningrad (one is recorded killed "luchando en guerrilleros" near Leningrad on 27 December 1942) | The command post and the raid; the note does not claim exiles fought on the Volkhov itself | [Blue Division](https://en.wikipedia.org/wiki/Blue_Division), [Relación de españoles caídos](https://www.ninosderusia.org/wp-content/uploads/2026/02/Relacion-Espanoles-Caidos-en-Ejercito-Sovietico-PFM.pdf) |
| 6 | The Soviet offensive at Krasny Bor, south of Leningrad, began on Wednesday 10 February 1943 with a bombardment of the Spanish lines at 6:45, by the 55th Army. On 15 February the División Azul reported 3,645 killed or wounded and 300 missing or taken prisoner, a 70–75% casualty rate of the troops engaged. By 13 February the 55th Army had lost almost a third of its initial strength and most of its tanks; the Spanish division held the Red Army inside the perimeter of the siege of Leningrad | The raid the night before; the last sentence of the closing note is about the invented pair | [Battle of Krasny Bor](https://en.wikipedia.org/wiki/Battle_of_Krasny_Bor) |

The campaign has no last-mission triumph: the closing note of mission 6 says what the battle cost
both sides.

## Objectives

`MissionRules` stops knowing about a bridge. A mission carries an ordered list of `Objective`
nodes; the rules ask each whether it is done or has failed. The mission is won when every objective
is done and both specialists are alive at the extraction. It is lost when a specialist dies, an
objective fails, or (as now) the pair is cut off from the extraction.

| Objective | Done when | Fails when | Used in |
|---|---|---|---|
| `DestroyObjective` | A charge goes off within range of its target | Never | 1, 2, 6 |
| `RescueObjective` | The prisoner is at the extraction | The prisoner dies | 3 |
| `StealObjective` | A specialist carrying the item is at the extraction | Never (the item cannot be destroyed) | 5 |
| `SilenceObjective` | Every named sentry is down | The clock runs out, or any guard reaches ALARM, before that | 4 |
| `CutObjective` | Every listed point has been cut | Never | 6 |

What each one adds to play:

- **Rescue.** The prisoner is a unit in a locked cell inside a building. A specialist next to the
  door opens it with the carry key (`F`). From then on the prisoner follows that specialist, takes
  the same stance, and is seen by guards exactly as a specialist is. He cannot fight.
- **Steal.** The item lies on a table inside a building. `F` next to it picks it up; it shows on
  the carrier, and drops where the carrier falls or is told to drop it. A specialist carrying it
  can still crawl and use the knife, but cannot carry a body.
- **Silence.** The HUD shows the sentries left and the time until the boats set out. Killing a
  sentry by any means counts, but a shot fired, or an alarm anywhere on the map, before the last
  of them is down fails the mission at once, because the far bank is then awake. When it is done the boats are seen crossing and the objective line
  changes to the extraction.
- **Cut.** Telephone lines run on the existing poles. `F` at a marked pole cuts the line there:
  a few seconds standing still, silent. Three poles in mission 6.
- **Destroy** is today's behaviour. Only the bridge mission breaks the navmesh; the other targets
  just blow up.

The HUD objective line shows the first objective not yet done, then "Reach the extraction point".
The objective marker points at the same thing. The briefing lists them all.

## Winter

One snow look shared by missions 2, 5 and 6:

- Land colours: snow on flat ground, grey rock on steep faces, trodden grey-brown on roads and
  paths. The colour table becomes a per-mission choice in the map tables (`PALETTE="snow"`).
- A frozen river: the water plane with an ice material and no movement. Ice is walkable in
  mission 5, where it is the exposed short way across.
- Scatter: bare trees, snow-laden pines, birch for Russia; no grass, wheat or flowers.
- Buildings: the stone farm stays for Teruel; log houses with snow on the roof for Russia.
- Light: flat overcast for Teruel; low orange dusk for the Volkhov; blue pre-dawn with lamps and
  one searchlight for Krasny Bor. Light snowfall as a particle effect, capped so the 30 fps check
  holds.
- Uniforms, as new kits in `soldier_gear.gd` and colours in `tools/make_soldier.py`:
  - The pair in Spain, winter: blanket capes over what they wear now.
  - The pair in Russia: white snow smocks over padded jackets, fur caps.
  - División Azul guards: field-grey greatcoat, German helmet, the Spanish arm shield.
- Footprints and the effect of white smocks on being seen are out of scope: stealth rules do not
  change.

## Briefing, endings and the campaign list

- The briefing shows the campaign as a list of six: number, place, date. A mission is open once
  the one before it has been won; mission 1 is always open. Which missions are won is kept in the
  browser's local storage. `?mission=<id>` still starts any mission, open or not.
- Choosing a mission shows its date and place, the historical note, the objectives and the
  controls that matter for it (the new `F` uses are listed where they apply).
- The end screen, on a win, shows the "what really happened" note above the button for the next
  mission. After mission 6 it shows the closing note and returns to the list.
- Old addresses keep working: `?mission=bridge` and `?mission=powder_store` open missions 1 and 2;
  the two night ids open the same missions.

## Architecture

New parts:

| Part | Job | Depends on |
|---|---|---|
| `Objective` (base) and the five kinds above | One win condition each: state, done/failed, HUD text, marker position, save and load | `Mission` |
| `Prisoner` | A unit that follows a specialist and can be seen and killed | `Unit` |
| `Carryable` | The item to steal: picked up, carried, dropped | `Specialist` |
| `CutPoint` | A place on a pole line that can be cut | Nothing |
| `Campaign` | Which missions are won; what is open | `Missions` |
| `History` | The notes for each mission, as data in one file | Nothing |

Changed parts:

- `MissionRules`: generic over the objective list. Breaking the span and dropping whoever is on
  it move into `DestroyObjective`, which calls the mission's existing bridge-breaking code (it
  already serves both a span and a stack of stores). The cut-off check stays in the rules and
  runs whenever the navmesh is baked again.
- `Mission`: exposes `objectives()`; `bridge_target()` and the text exports give way to what the
  objectives report.
- `Missions`: six entries with date and place; the old ids map to the new ones.
- `tools/mapgen.py`: tables for `OBJECTIVES`, `PALETTE`, `ICE`, `PRISONER`, `ITEM`, `CUT_POINTS`
  and a light preset; one new table file per new mission; the night copies go.
- `MissionValidator`: checks each objective's own needs (below).
- Briefing, end screen, HUD and objective marker: read from the objective list, `Campaign` and
  `History`.
- Save: objective states, the prisoner, the carried item and cut points are saved; the save
  version goes up and an old save gives the existing "out of date" message.

Game rules still do not depend on what is drawn.

## Error handling

The validator fails a mission when:

- it declares no objective, or an objective's target, cell, item or cut point is off the navmesh
  or cannot be reached from the spawns;
- a `SilenceObjective` names a sentry that is not in the mission, or has no clock;
- a `RescueObjective` has no prisoner, or the cell has no door a specialist can stand next to;
- the extraction cannot be reached once every objective is done (the bridge case, kept).

A mission id in the address that is not known falls back to mission 1, as now.

## Testing

| Layer | Checks |
|---|---|
| Objectives | Each kind: done and failed conditions, HUD text, save and load round trip |
| Rules | Win needs every objective and both at extraction; each loss reason gives its own text |
| Prisoner | Follows, matches stance, is seen as a specialist is, dies, fails the mission |
| Carryable | Pick up, drop on death, counts only when carried into the extraction |
| Silence | Clock expiry fails; an alarm fails; all sentries down passes |
| Cut | Takes its time, is interrupted by moving, all three complete it |
| Missions | The validator passes on all six; the scripted bot wins each one unseen; a careless route is caught |
| Campaign | Locking and unlocking; old ids map to new missions |
| Browser | Each mission loads with no console errors; screenshots of each reviewed by eye |
| Performance | 30 fps or better on each mission, snowfall included |

All existing tests keep passing or are updated for the generic rules in the same change.

## Delivery

Three batches, each playable, tested, pushed and deployed before the next starts:

1. Objective list and generic rules; campaign list, notes and end screen; mission 1 re-framed;
   mission 3, Carchuna (rescue). The night variants go in this batch.
2. Winter look and uniforms; mission 2, Teruel; mission 5, Volkhov (steal).
3. Mission 4, the Ebro (silence); mission 6, Krasny Bor (cut and destroy).

## Out of scope

New player characters, playing as the División Azul, new stealth rules (snow tracks, camouflage),
vehicles that move, spoken or translated text, touch controls, and a native build.

## Definition of done

1. Six missions play in order from the campaign list, each with its date, place and notes.
2. The five objective kinds work, save and load.
3. Missions 2, 5 and 6 are in snow, with winter uniforms and División Azul guards in 5 and 6.
4. Every mission passes the validator and is won unseen by the scripted bot.
5. All automated tests pass, including the 30 fps browser check on every mission.
6. Every historical statement shown in the game is in the table above with its source.
7. Manuel has played it.
