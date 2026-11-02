# Project Overview

| | |
|---|---|
| Status | Planning |
| Event | 7-day game jam |
| Theme | Pacifist |
| Team | Paula Garcia, Chi Tran |
| Tech | Godot 4 (GDScript), HTML5 web export. Fresh project; existing Faster Chef sprites and sounds are imported |
| Target platform | Browser (Godot web export, hosted on itch.io) |
| Participants | @Paula Garcia |

# Summary

Faster Chef started as a 2–4 player real-time cooking game. For the jam we are rebuilding it from scratch in Godot as a single-player, three-phase cooking run. The player picks a chef, meets a hungry monster customer who wants a specific dish, then gathers ingredients on a side-scrolling stage, chops and cooks them, and delivers the dish. The monster grades the dish on freshness. Nobody is ever hurt: monsters are just hungry, and cats only steal or spoil food.

# Goals

- Ship a polished, finishable game in 7 days
- Make the pacifist theme the core mechanic, not decoration: the only way to "win" a monster is to feed it well
- Reuse existing assets: chef sprites, cats, potions and sounds (imported into Godot); the chop and cook logic is rewritten
- Have a playable build at the end of every day

Non-goals: online multiplayer, chat and server-side simulation (dropped for the jam).

# Key decisions

**Drop the netcode.** Platformer movement needs instant input response, and a 30 Hz server-authoritative loop makes it feel floaty. The game runs entirely client-side. Co-op is a stretch goal only.

**Rebuild in Godot.** The design is scene-heavy and physics-heavy. Godot gives us physics, tilemaps, camera, animation, particles, audio and scene switching out of the box, so the old JavaScript code is left behind and only the art and sounds carry over. Each phase is its own Godot scene.

# Core concept: "Feed, don't fight"

Every level is one order from one hungry monster, played in three phases: **Gather → Chop and Cook → Deliver**. Quality carries through all phases, so ingredients gathered in Phase 1 and mistakes in Phase 3 both affect the final grade.

## Level flow

1. **Title screen:** [Start] → **Choose Chef**. Each chef shows stats: a strength (e.g. Power: speed) and a disadvantage (e.g. cats steal 2× the amount of items).
2. **Order cutscene:** quick scene showing the monster customer and the dish it wants. After the cutscene the chef runs to the right edge of the screen.
3. **Screen transition → Countdown 3…2…1 → Game start.**
4. **Phase 1: Gather.** Move left/right and jump to collect ingredients. A progress bar (top left) shows how many have been gathered. Cats run left and right; touching a cat makes it steal ingredients (amount depends on chosen chef).
5. **Minimum reached.** Popup: "You have collected enough ingredients. You can proceed to the next phase." The chef chooses:
   - Stay and collect the rest (100% = extra XP and a more delicious dish), or
   - Run to the right end and enter the teleport point to start Phase 2.
6. **Phase 2: Chop and cook.** Scene change. The chef goes to the chopping spot and plays a chopping minigame. This should be longer and harder than pressing [E] ×3 (minigame design TBD, see open questions).
7. **Phase 3: Deliver.** After chopping, the chef goes to the pickup spot to collect the cooked dish. Popup: "Food is ready! Delivering…" with a countdown timer bar. If the chef fails to reach the Delivery Hub in time, they must run back to the pickup spot and carry the dish again.
8. **Delivery run.** Obstacles to dodge or pass through. Cats appear again, but this time a hit makes the food less good instead of stealing ingredients.
9. **Serve.** The monster scene returns. The monster eats the dish and gives Stars/Points based on the dish's freshness (ingredients gathered, chop quality, delivery hits/time).
10. **End of level:** back to the Level Select or Choose Chef screen.

No chef or monster ever dies. Failing a phase means retrying it or getting a lower grade, never game over.

Win condition: finish all levels; "true pacifist" ending if every monster is served with a 3-star dish.

# Feature scope

## Must-have (MVP)

- Screens: title, choose chef (with stats), order cutscene, countdown, level end/grade
- Scene switching between screens and phases (one Godot scene per screen/phase)
- 2 playable chefs with different strengths/disadvantages
- Phase 1: side-scrolling movement (run, jump, coyote time, jump buffering), ingredient pickups, progress bar, minimum-ingredient popup, teleport point
- Cats that patrol and steal ingredients (amount depends on chef)
- Phase 2: chopping minigame (one solid version) and cooking
- Phase 3: pickup spot, delivery timer bar, delivery hub, obstacles, cats that reduce dish quality
- Freshness score and star grading, monster reaction
- 3 levels with different monsters and dishes, levels built as TileMap scenes (or JSON loaded into a TileMap)

## Should-have

- Third chef
- A second, different chopping minigame
- Different dish and monster per level with its own ingredient list
- XP for 100% ingredient collection, and a more delicious dish as a result
- Potions repurposed as temporary movement or protection boosts
- Parallax background, screen shake, dust particles, music per phase

## Nice-to-have

- Boss monster that needs a multi-course meal
- Secret areas and collectible recipes
- localStorage leaderboard
- Local co-op on one keyboard

# Sprint plan

Rule: playable at the end of every day. Cut features, never the deadline.

| Day | Sprint goal | Done when |
|---|---|---|
| 1 | Foundation: lock scope, create Godot project, import old sprites/sounds, scene switching, player (`CharacterBody2D`) movement and Camera2D. **Test a web export early** | Run and jump feels good on a test level; scenes can be switched; web export loads in a browser |
| 2 | Flow shell: title, choose chef with stats, order cutscene, countdown. Phase 1 level layout with TileMap, collisions, one-way platforms | Can go from title to a traversable Phase 1 |
| 3 | Phase 1 complete: ingredient pickups, progress bar, minimum popup, teleport, cats stealing, chef stat effects | Full Phase 1 can be played and ended |
| 4 | Phases 2 and 3: chopping minigame, cooking, pickup spot, delivery timer, obstacles, cats lowering quality | A full level can be played start to finish |
| 5 | Grading and content: freshness and star scoring, monster serve scene, levels 2 and 3, more chefs/dishes, HUD | Full 3-level run is possible; new player can finish without explanation |
| 6 | Freeze and juice: feature freeze, particles, music mix, tuning, playtests, bug fixes. Upload insurance build | No known crashes, playtest feedback handled |
| 7 | Ship: final bug pass, README, controls guide, GIF/screenshots, deploy, submission page | Live and tested from a fresh browser by midday |

# Risks and mitigations

| Risk | Mitigation |
|---|---|
| Platformer physics feel poor | Spend real time on Day 1; use proven gravity/jump values and coyote time |
| Godot learning curve | Do tutorials and the player controller on Day 1; keep scripts simple; use built-in nodes instead of custom systems |
| Web export problems (audio, threading, size, headers) | Export to the web on Day 1 and re-test every day; host on itch.io; keep an insurance build |
| Too many scenes and phases for 7 days | Build the scene manager first; each phase is its own self-contained scene with a simple result (quality score) passed through an autoload singleton |
| Chopping minigame takes too long to design | Ship one simple-but-longer version (e.g. timed key sequences) first; extras are should-have |
| Level design is slower than code | Use the TileMap editor with a small tileset so levels can be edited in seconds |
| Art workload (monsters, cutscenes, extra scenes) | Reuse existing sprites; fixed pixel scale; import with nearest-neighbor filtering; cutscene can be a static scene with a speech bubble |
| Falling behind | Cut order: boss, co-op, level 3, extra chefs, second minigame. Never cut the gather → cook → deliver → grade loop |
| Late submission problems | Insurance build on Day 6, final deploy by midday Day 7 |

# Open questions

- What is the chopping minigame (timed key sequence, rhythm bars, drag along a line, memory)?
- How does the freshness score combine gather %, chop quality, and delivery hits?
- Which chefs and what exact stats (speed, jump, cat steal multiplier, carry capacity)?
- Is the timer in Phase 3 fixed, or does it depend on dish and chef?

# Responsibilities

| Area | Owner |
|---|---|
| Scene switching, screens and cutscenes | |
| Player controller, physics, tilemap and camera | |
| Phase 1: ingredients, cats, progress bar | |
| Phases 2 and 3: chopping, cooking, delivery | |
| Grading, monsters and levels | |
| Art, animation and UI | |
| Audio and juice | |
| Build, deploy and submission | |

# Submission checklist

- Web build deployed (itch.io) and playable in a fresh browser
- README with controls and how to play
- Screenshots and gameplay GIF
- Submission page filled in with theme explanation
- Credits for all assets and sounds
