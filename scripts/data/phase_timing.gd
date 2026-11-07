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
