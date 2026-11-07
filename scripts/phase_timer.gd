class_name PhaseTimer
extends Node
## Counts a phase down and takes stars away as time runs low (see PhaseTiming). Being a
## plain node it stops while the tree is paused, so the pause menu freezes the clock.

signal tick(time_left: float)
## Emitted each time a star is lost, with how many are left (0 on time-out).
signal star_lost(stars_left: int)
## The clock hit 0:00 (and the stars hit 0).
signal timed_out

var timing: PhaseTiming
var time_left := 0.0
var stars := 3
var running := false


func start(new_timing: PhaseTiming) -> void:
	timing = new_timing
	time_left = timing.duration
	stars = timing.stars_for(time_left)
	running = true
	tick.emit(time_left)


## Freezes the clock and returns the stars earned.
func stop() -> int:
	running = false
	return stars


func _process(delta: float) -> void:
	advance(delta)


## Moves the clock on by `delta` seconds. _process calls it; tests can too.
func advance(delta: float) -> void:
	if not running:
		return
	time_left = maxf(time_left - delta, 0.0)
	tick.emit(time_left)
	var now := timing.stars_for(time_left)
	if now < stars:
		stars = now
		star_lost.emit(stars)
		if stars <= 0:
			running = false
			timed_out.emit()
