class_name GameState
extends RefCounted
## Values that need to survive scene changes.

## The player's name from the choose-chef screen (empty if they left it blank).
static var nickname := ""
static var selected_chef_name := ""
static var selected_chef_texture: Texture2D
## Which level is being played (0-based, an index into Levels.ALL).
static var level_index := 0

# --- Stars and score for the current run of a level -------------------------------------
const PHASE_COUNT := 3
const MAX_STARS := 3
## Multiplier when every phase got 3 stars (instead of the usual 1 per star).
const PERFECT_MULTIPLIER := 10
## Multiplier for collecting every ingredient piece in Phase 1 (all the extras).
const ALL_EXTRAS_MULTIPLIER := 3
## Each second left on a phase's clock adds this much to that phase's multiplier
## (75 s left = x1.75, 0 s = x1.00, so it never lowers the score).
const TIME_BONUS_PER_SECOND := 0.01
## Share of the possible stars needed for the monster's neutral / happy reaction.
const NEUTRAL_RATIO := 0.55

enum Mood { SAD, NEUTRAL, HAPPY }

## Stars earned per phase, e.g. {1: 3, 2: 2}. Cleared when a level starts or restarts.
static var phase_stars := {}
## Seconds left on the clock when each phase ended, e.g. {1: 75.2, 2: 40.0, 3: 126.9}.
static var phase_time_left := {}
## True if the chef left Phase 1 holding every ingredient piece of the level.
static var all_extras := false


## The finished levels of this game, for the game over screen: level index ->
## { "stars": int, "points": int, "score": int }. Replaying a level replaces its entry.
static var level_results := {}

# --- Level map ------------------------------------------------------------------------
## The highest level (0-based) the player may start.
static var unlocked_level := 0
## A level that was just unlocked: the map plays its unlock animation once, then sets -1.
static var just_unlocked := -1
## True after the last level's tally: the map offers the results (game over) screen.
static var game_complete := false

static func reset_run() -> void:
	phase_stars = {}
	phase_time_left = {}
	all_extras = false


## A new game starts: forget the levels of the last one.
static func reset_game() -> void:
	level_results = {}
	unlocked_level = 0
	just_unlocked = -1
	game_complete = false
	reset_run()


## Call when a level's tally is shown, while its stars are still in `phase_stars`.
static func record_level_result(level: int, points: int) -> void:
	level_results[level] = {
		"stars": total_stars(),
		"points": points,
		"score": final_score(points),
	}


static func game_score() -> int:
	var total := 0
	for result in level_results.values():
		total += result.score
	return total


static func record_stars(phase: int, stars: int) -> void:
	phase_stars[phase] = clampi(stars, 0, MAX_STARS)

static func record_time_left(phase: int, seconds: float) -> void:
	phase_time_left[phase] = maxf(seconds, 0.0)


## Whole seconds, rounded up like the HUD clock shows them (0:01 left = 1 s).
static func whole_seconds(phase: int) -> int:
	return ceili(phase_time_left.get(phase, 0.0))


## One phase's time bonus: x(1 + seconds left / 100).
static func time_multiplier_for(phase: int) -> float:
	return 1.0 + whole_seconds(phase) * TIME_BONUS_PER_SECOND


## All phases' time bonuses multiplied together.
static func time_multiplier() -> float:
	var total := 1.0
	for phase in phase_time_left:
		total *= time_multiplier_for(phase)
	return total


static func extras_multiplier() -> int:
	return ALL_EXTRAS_MULTIPLIER if all_extras else 1


## Everything multiplied together, as shown on the tally (e.g. 10 x 3 x 5.54 = 166.2).
static func total_multiplier() -> float:
	return multiplier() * extras_multiplier() * time_multiplier()


static func total_stars() -> int:
	var total := 0
	for stars in phase_stars.values():
		total += stars
	return total


## Stars are the score multiplier (9 stars = x9), except a perfect run, which is x10.
static func multiplier() -> int:
	if phase_stars.size() >= PHASE_COUNT and total_stars() == PHASE_COUNT * MAX_STARS:
		return PERFECT_MULTIPLIER
	return total_stars()


## XP x stars x all extras x time (phase 1) x time (phase 2) x time (phase 3). Rounded only here.
static func final_score(xp: int) -> int:
	return roundi(xp * total_multiplier())


## How the monster reacts: from the share of the stars it was possible to earn so far.
static func mood() -> Mood:
	var possible := phase_stars.size() * MAX_STARS
	if possible == 0:
		return Mood.SAD
	var ratio := float(total_stars()) / possible
	if ratio >= 1.0:
		return Mood.HAPPY
	return Mood.NEUTRAL if ratio >= NEUTRAL_RATIO else Mood.SAD
