@tool
class_name Actor extends Node

@export var start_synchronized := true
@export var physics_desynchronized := false
@export var actor_process_desynchronized := true
@export var actor_physics_process_desynchronized := true

signal _physics_desynchronized_cycle(dt)
signal _desynchronized_cycle(dt)
signal _synchronized_cycle

func desynchronize()->int:
	if (is_physics_processing()):
		await _physics_desynchronized_cycle
	else:
		await _desynchronized_cycle
	return 1
func desynchronize_physics()->int:
	await _physics_desynchronized_cycle
	return 1
func synchronize()->int:
	await get_tree().process_frame
	return 1
func synchronize_physics()->int:
	await get_tree().physics_frame
	return 1

# Called when the node enters the scene tree for the first time.
func _ready():
	if not Engine.is_editor_hint():
		process_thread_messages = Node.FLAG_PROCESS_THREAD_MESSAGES
		process_thread_group = Node.PROCESS_THREAD_GROUP_SUB_THREAD
		if physics_desynchronized:
			process_thread_messages |= Node.FLAG_PROCESS_THREAD_MESSAGES_PHYSICS
		_synchronized_cycle.emit()
		if has_method(&"_start"):
			if start_synchronized:
				await synchronize()
			else:
				await desynchronize()
			call(&"_start")
	else:
		process_thread_group = Node.PROCESS_THREAD_GROUP_MAIN_THREAD

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	_desynchronized_cycle.emit(delta)
	if has_method(&"_actor_process"):
		if not actor_process_desynchronized:
			await synchronize()
		call(&"_actor_process",delta)

func _physics_process(delta):
	_physics_desynchronized_cycle.emit(delta)
	if has_method(&"_actor_physics_process"):
		if not actor_physics_process_desynchronized:
			await synchronize()
		call(&"_actor_physics_process",delta)

# virtual
#func _start(): pass
# virtual
#func _actor_process(delta): pass
# virtual
#func _actor_physics_process(delta): pass
