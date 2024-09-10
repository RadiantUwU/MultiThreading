class_name WorkerThreadsActor extends Node

var _idx := -1
var _size := 0
@export_range(0,0,1,"hide_slider","or_greater") var size := 0
@export var worker_script: Script
var mtx := Mutex.new()

signal _deferred_signal
signal _all_and_wait_resume

func _ready():
	if size != 0 and worker_script != null:
		create_workers.call_deferred(worker_script,size)

func get_size()->int:
	return _size

func __assert_is_actor_script(script: Script):
	pass

func _assert_is_actor_script(script: Script):
	pass

func create_workers(script: Script, size: int):
	assert(_size==0,"Workers already created.")
	assert(OS.get_thread_caller_id()==OS.get_main_thread_id(),"Cannot run create_workers() in desynchronized mode")
	_assert_is_actor_script(script)
	mtx.lock()
	_size = size
	for i in range(size):
		var n: Node = script.new()
		n.name = "Worker"+str(i)
		add_child(n)
	_idx = 0
	mtx.unlock()

func call_on_worker(wid: int, method: StringName, args: Array):
	assert(wid <= _size and wid >= 0,"cannot select a worker that doesn't exist")
	var worker: Node = get_node("Worker"+str(wid))
	var a := [method]
	a.append_array(args)
	worker.callv(&"call_thread_safe",a)

func call_one(method: StringName, args: Array):
	mtx.lock()
	var worker: Node = get_node("Worker"+str(_idx))
	var a := [method]
	a.append_array(args)
	worker.callv(&"call_thread_safe",a)
	_idx+=1
	if _idx>=_size:
		_idx = 0
	mtx.unlock()

func call_on_all(method: StringName, args: Array):
	for i in range(_size):
		var worker: Node = get_node("Worker"+str(i))
		var a := [method]
		a.append_array(args)
		worker.callv(&"call_thread_safe",a)

func call_on_worker_and_wait(wid: int, method: StringName, args: Array):
	assert(wid <= _size and wid >= 0,"cannot select a worker that doesn't exist")
	var worker: Node = get_node("Worker"+str(wid))
	var a := [method]
	a.append_array(args)
	var ret = await worker.callv(&"call_thread_safe",a)
	emit_signal.call_deferred(&"_deferred_signal")
	await _deferred_signal
	return ret

func call_one_and_wait(method: StringName, args: Array):
	var a := [method]
	a.append_array(args)
	mtx.lock()
	var worker: Node = get_node("Worker"+str(_idx))
	_idx+=1
	if _idx>=_size:
		_idx = 0
	mtx.unlock()
	var ret = worker.callv(&"call_thread_safe",a)
	emit_signal.call_deferred(&"_deferred_signal")
	await _deferred_signal
	return ret

func call_var_and_wait(method: StringName, args_array: Array):
	var mtx := Mutex.new()
	var ret_vals := []
	for args in args_array:
		var f := func():
			var ret = await call_one_and_wait(method, args)
			mtx.lock()
			ret_vals.append(ret)
			if len(ret_vals)==len(args_array):
				mtx.unlock()
				emit_signal(&"_all_and_wait_resume")
			else:
				mtx.unlock()
		f.call()
	while true:
		mtx.lock()
		if len(ret_vals)==len(args_array):
			break
		mtx.unlock()
		await _all_and_wait_resume
	emit_signal.call_deferred(&"_deferred_signal")
	await _deferred_signal
	return ret_vals
	


func destroy_workers():
	assert(OS.get_thread_caller_id()==OS.get_main_thread_id(),"Cannot run destroy_workers() in desynchronized mode")
	for i in range(_size):
		var n: Node = get_node_or_null("Worker"+str(i))
		if n:
			remove_child(n)
			n.queue_free()
	_size = 0
