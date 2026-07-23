## TimeManager (autoload)
## The single game clock every timer-based system reads from. See
## docs/ARCHITECTURE.md §2.4.
##
## Durations in the original data are real seconds (BuildTime, shop-item
## time, worktime, hunger length) with no evidence of an accelerated
## game-day cycle — so this clock is wall-clock time, not a scaled
## simulation tick (see docs/ARCHITECTURE.md §2.4 and
## docs/MISSING_INFORMATION.md for the day/night assumption).
##
## Timers are represented elsewhere (SaveGame, future BuildingInstance) as
## absolute Unix timestamps ("started_at") compared against now(), never as
## a stored countdown — this is what makes save/reload and offline
## catch-up correct by construction rather than a special case later. See
## docs/ARCHITECTURE.md §2.3 "Timer persistence design."
##
## Phase 1: now()/is_elapsed()/seconds_remaining() are implemented and
## tested (tests/test_foundation.gd). Offline catch-up dispatch (calling
## catch_up() on other managers after a load) is NOT implemented yet — there
## are no timer-bearing managers to catch up (Buildings/Economy are Phase
## 2/3). See docs/IMPLEMENTATION_STATUS.md.
extends Node

signal tick(delta: float)

var is_paused: bool = false

var _elapsed_since_start: float = 0.0


func _process(delta: float) -> void:
	if is_paused:
		return
	_elapsed_since_start += delta
	tick.emit(delta)


## Current Unix timestamp (seconds), truncated to whole seconds to match
## SaveGame's int-typed timestamp fields.
func now() -> int:
	return int(Time.get_unix_time_from_system())


func pause() -> void:
	is_paused = true


func resume() -> void:
	is_paused = false


## Real seconds elapsed since this TimeManager started running (process
## time, not wall clock) — for diagnostics/tests only, not for authoritative
## completion checks (use is_elapsed() for those).
func elapsed_since_start() -> float:
	return _elapsed_since_start


## True once [param duration_seconds] have passed since [param started_at]
## (an absolute Unix timestamp), per the current game clock.
func is_elapsed(started_at: int, duration_seconds: float) -> bool:
	return seconds_remaining(started_at, duration_seconds) <= 0.0


func seconds_remaining(started_at: int, duration_seconds: float) -> float:
	var elapsed: float = float(now() - started_at)
	return max(0.0, duration_seconds - elapsed)
