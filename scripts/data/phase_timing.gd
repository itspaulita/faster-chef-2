class_name PhaseTiming
extends Resource
## How long a phase lasts and when the chef loses stars for being slow. Everyone starts a
## phase with 3 stars. Times are in seconds LEFT on the clock, so tuning a phase is just
## editing its .tres file.

@export var duration := 90.0
## 3 stars while at least this much time is left, then 2.
@export var two_star_below := 60.0
## 2 stars while at least this much time is left, then 1. At 0:00 the stars hit 0.
@export var one_star_below := 30.0


func stars_for(time_left: float) -> int:
	if time_left <= 0.0:
		return 0
	if time_left < one_star_below:
		return 1
	if time_left < two_star_below:
		return 2
	return 3


## Where the countdown bar's edge sits, 0..1: full at the start, draining evenly to empty
## at 0:00, so a position on the bar is a point in time.
func bar_fraction(time_left: float) -> float:
	return clampf(time_left / maxf(duration, 0.001), 0.0, 1.0)


## Where star `star` (1-3) sits on the bar (0..1): the point where it is lost, so the star
## dims just as the bar's edge drains past it. Star 1 is lost at 0:00, so it sits at the end.
func star_fraction(star: int) -> float:
	match star:
		3:
			return bar_fraction(two_star_below)
		2:
			return bar_fraction(one_star_below)
	return 0.0
