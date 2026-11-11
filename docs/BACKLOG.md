# Backlog

Known gaps and ideas, most useful first. Done items are removed; the git history has them.

## Play

- **The gorge path may not be winnable unseen.** Guards on an east-west beat swing round through
  the south at each end, which sweeps the south ramp and the south trackside crate. The test bot
  wins by the hill and north side only. Check by play, then change how guards turn or reshape the
  south approach, and add a bot run for it.
- **Guards turn instantly and never pause.** A short pause and a slower, visible turn at each end
  of a beat would make patrols easier to read and time.
- **Only one specialist can be ordered at a time.** Add select-both, so a move order goes to both.
- **A second mission.** `tools/make_bridge_map.py` is specific to the bridge; generalise it and
  add a mission select.

## Look and sound

- **No rifle-aiming animation.** Shots use a pistol stance; the free animation set has no rifle
  aim. The paid version of Quaternius's Universal Animation Library has one.
- **Sound is thin.** No night ambience, no knife or falling-body sounds, no music.
- **The extraction point is a green slab.** Give it something to arrive at.

## Technical

- **Silhouettes are verified in Chromium only.** They use the engine's stencil x-ray mode; check
  Safari and Firefox, and fall back to a ring marker where stencil is unavailable.
- **The navmesh is close to the path-search limit.** About 2,800 polygons against Godot's 4,096;
  the test cap is 3,200. Reduce polygons before adding more blocking props.
- **The validator checks position only.** It does not check slope, height, or that a patrol route
  is connected.
