class_name ClassicPlayer
extends RefCounted

signal route_blocked(cell: Vector2i)

const CELL := Vector2(48,32)
var nav: ClassicNavigation
var cell := Vector2i.ZERO
var destination := Vector2i.ZERO
var anchor := Vector2.ZERO
var direction := 4
var action := "stand"
var elapsed := 0.0
var progress := 1.0
var step_seconds := 0.32
var step_duration_override := 0.0
var route: Array[Vector2i] = []
var completed_steps := 0
var route_replanner: Callable
var replans_without_step:=0
var replan_wait:=0.0
var step_filter: Callable
var path_avoid: Array[Vector2i]=[]

func reset(p: Vector2i) -> void:
	replans_without_step=0;replan_wait=0.0
	cell = p
	destination = p
	anchor = Vector2(p) * CELL
	progress = 1.0
	route.clear()
	action = "stand"

func go_to(p: Vector2i, extra_avoid: Array[Vector2i]=[]) -> bool:
	replans_without_step=0;replan_wait=0.0
	var start := destination if progress < 1.0 else cell
	var avoid: Array[Vector2i]=path_avoid.duplicate()
	avoid.append_array(extra_avoid)
	route = nav.path_avoiding(start, p,avoid)
	if not route.is_empty():
		route.pop_front()
	return start == p or not route.is_empty()

func begin_step(next: Vector2i, running: bool) -> bool:
	if not nav.can_step(cell,next) or (step_filter.is_valid() and not step_filter.call(next)):
		return false
	destination = next
	direction = ClassicNavigation.DIRECTIONS.find(next-cell)
	action = "run" if running else "walk"
	step_seconds = step_duration_override if step_duration_override>0 else (0.16 if running else 0.32)
	progress = 0.0
	elapsed = 0.0
	return true

func update(delta: float, manual: Vector2i, running: bool) -> void:
	elapsed += delta
	if manual != Vector2i.ZERO:
		route.clear();replan_wait=0.0
	if progress < 1.0:
		progress = minf(1.0,progress + delta/step_seconds)
		anchor = Vector2(cell).lerp(Vector2(destination),progress) * CELL
		if progress < 1.0:
			return
		cell = destination
		completed_steps += 1
		replans_without_step=0;replan_wait=0.0
	if manual != Vector2i.ZERO:
		if begin_step(cell+manual,running):
			return
	elif not route.is_empty():
		if replan_wait>0:
			replan_wait=maxf(0,replan_wait-delta);action="stand";return
		var goal: Vector2i=route.back()
		var next := route.pop_front() as Vector2i
		if begin_step(next,running):
			return
		var pending: Array[Vector2i]=route.duplicate();pending.push_front(next)
		route.clear()
		if route_replanner.is_valid() and replans_without_step<3:
			replans_without_step+=1
			var replacement: Array[Vector2i]=route_replanner.call(goal)
			if not replacement.is_empty():route=replacement
			elif replans_without_step<3:route=pending
			if not route.is_empty():replan_wait=0.25
		if route.is_empty():route_blocked.emit(next)
	if action != "stand":
		elapsed = 0.0
	action = "stand"

func frame() -> int:
	if action == "stand":
		return int(elapsed*5.0) % 4
	# Running completes its six-frame cycle over two cells, as in classic movement.
	if action == "run":
		return mini(5,int((float(completed_steps % 2)+progress)*3.0))
	return mini(5,int(progress*6.0))
