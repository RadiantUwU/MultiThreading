extends Node

var obj: Object

# Called when the node enters the scene tree for the first time.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_thread_messages = Node.FLAG_PROCESS_THREAD_MESSAGES_ALL
	process_thread_group = Node.PROCESS_THREAD_GROUP_SUB_THREAD


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	obj.mtx.lock()
	obj.emit_signal(&"process_frame",delta)
	obj.mtx.unlock()
