class_name GameState
extends RefCounted
## Values that need to survive scene changes.

## The player's name from the choose-chef screen (empty if they left it blank).
static var nickname := ""
static var selected_chef_name := ""
static var selected_chef_texture: Texture2D

# --- Stars and score for the current run of a level -------------------------------------
const PHASE_COUNT := 3
const MAX_STARS := 3
## Multiplier when every phase got 3 stars (instead of the usual 1 per star).
const PERFECT_MULTIPLIER := 10
## Share of the possible stars needed for the monster's neutral / happy reaction.
const NEUTRAL_RATIO := 0.55

enum Mood { SAD, NEUTRAL, HAPPY }

## Stars earned per phase, e.g. {1: 3, 2: 2}. Cleared when a level starts or restarts.
static var phase_stars := {}


static func reset_run() -> void:
	phase_stars = {}


static func record_stars(phase: int, stars: int) -> void:
	phase_stars[phase] = clampi(stars, 0, MAX_STARS)


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


static func final_score(xp: int) -> int:
	return xp * multiplier()


## How the monster reacts: from the share of the stars it was possible to earn so far.
static func mood() -> Mood:
	var possible := phase_stars.size() * MAX_STARS
	if possible == 0:
		return Mood.SAD
	var ratio := float(total_stars()) / possible
	if ratio >= 1.0:
		return Mood.HAPPY
	return Mood.NEUTRAL if ratio >= NEUTRAL_RATIO else Mood.SAD
