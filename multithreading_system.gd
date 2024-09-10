extends Node

const thread_object = preload("res://addons/multithreading/thread_object.gd")

var rw := RWLock.new()

var _synced := false
var _synced_deferred := false

var _size := 0
var _idx := 0
@export var _enabled := true

class UnsafeSignalBearingObject extends Object:
	signal process_frame(delta: float)
	var mtx := Mutex.new()

var _sync_deferred_obj := UnsafeSignalBearingObject.new()
var _sync_obj := UnsafeSignalBearingObject.new()
var _objects : Array[UnsafeSignalBearingObject] = []

func reload() -> void:
	if not OS.get_thread_caller_id()==OS.get_main_thread_id():
		await get_tree().process_frame
	rw.write_lock()
	for i: thread_object in get_children():
		i.queue_free()
	for i in _objects:
		i.process_frame.emit(get_process_delta_time())
		i.free()
	_objects.clear()
	_idx = 0
	if _enabled:
		_size = OS.get_processor_count()
		for tid in range(_size):
			var thr_node := thread_object.new()
			thr_node.name = "Thread %s" % tid
			var obj := UnsafeSignalBearingObject.new()
			thr_node.obj = obj
			_objects.append(obj)
			add_child(thr_node)
	else:
		_size = 0
	rw.write_unlock()

func _ready()->void:
	get_tree().process_frame.connect(_process_relayed)
	reload()

func _deferred_emit()->void: # exclusive access guaranteed
	rw.write_lock()
	_synced_deferred = true
	_sync_deferred_obj.process_frame.emit(0)
	_synced_deferred = false
	rw.write_unlock()

func _process_relayed()->void:
	rw.write_lock()
	_synced = true
	rw.read_lock()
	rw.write_unlock()
	_deferred_emit.call_deferred()
	_sync_obj.process_frame.emit(get_process_delta_time())
	rw.write_lock()
	rw.read_unlock()
	_synced = false
	rw.write_unlock()

func is_synced()->bool:
	rw.read_lock()
	var b := _synced or _synced_deferred
	rw.read_unlock()
	return b

func is_synced_deferred()->bool:
	rw.read_lock()
	var b := _synced_deferred
	rw.read_unlock()
	return b

func is_synced_exclusive()->bool:
	rw.read_lock()
	var b := _synced_deferred
	rw.read_unlock()
	return b

func synchronize()->float:
	rw.read_lock()
	if not (_synced or _synced_deferred):
		var o := Object.new()
		o.add_user_signal(&"process_frame",[{"name":&"delta","type":TYPE_FLOAT}])
		rw.write_lock() # whoopsy this requires write lock to edit signal connections!
		rw.read_unlock()
		_sync_obj.process_frame.connect(o.emit_signal.bind(&"process_frame"))
		rw.write_unlock()
		var f: float = await Signal(o, &"process_frame")
		rw.write_lock()
		o.free() # freeing involves editing _sync_obj to disconnect it.
		rw.write_unlock()
		return f
	else:
		rw.read_unlock()
		return get_process_delta_time()

func synchronize_deferred()->float:
	rw.read_lock()
	if not _synced_deferred:
		var o := Object.new()
		o.add_user_signal(&"process_frame",[{"name":&"delta","type":TYPE_FLOAT}])
		rw.write_lock() # whoopsy this requires write lock to edit signal connections!
		rw.read_unlock()
		_sync_deferred_obj.process_frame.connect(o.emit_signal.bind(&"process_frame"))
		rw.write_unlock()
		var f: float = await Signal(o, &"process_frame")
		rw.write_lock()
		o.free() # freeing involves editing _sync_obj to disconnect it.
		rw.write_unlock()
		return f
	else:
		rw.read_unlock()
		return 0

func synchronize_exclusive()->float:
	rw.read_lock()
	if not _synced_deferred:
		var o := Object.new()
		o.add_user_signal(&"process_frame",[{"name":&"delta","type":TYPE_FLOAT}])
		rw.write_lock() # whoopsy this requires write lock to edit signal connections!
		rw.read_unlock()
		_sync_deferred_obj.process_frame.connect(o.emit_signal.bind(&"process_frame"))
		rw.write_unlock()
		var f: float = await Signal(o, &"process_frame")
		rw.write_lock()
		o.free() # freeing involves editing _sync_obj to disconnect it.
		rw.write_unlock()
		return f
	else:
		rw.read_unlock()
		return 0

func desynchronize()->float:
	rw.read_lock()
	if _synced or _synced_deferred:
		var o := Object.new()
		o.add_user_signal(&"process_frame",[{"name":&"delta","type":TYPE_FLOAT}])
		rw.write_lock() # whoopsy this requires write lock to edit signal connections!
		rw.read_unlock()
		if _size == 0:
			_sync_deferred_obj.process_frame.connect(o.emit_signal.bind(&"process_frame"))
		else:
			var obj := _objects[_idx]
			obj.mtx.lock()
			obj.process_frame.connect(o.emit_signal.bind(&"process_frame"))
			obj.mtx.unlock()
			_idx += 1
			_idx %= _size
		rw.write_unlock()
		var f: float = await Signal(o, &"process_frame")
		rw.write_lock()
		o.free() # freeing involves editing _sync_obj to disconnect it.
		rw.write_unlock()
		return f
	else:
		rw.read_unlock()
		return 0 # unknown
