class_name RWLock extends RefCounted

var _mtx := Mutex.new()
var _exc_mtx := Mutex.new()
var _sem := Semaphore.new()
var _thread_ids: PackedInt64Array = []
var _waiting_thread: int

func _lock_exc()->void:
	if not _exc_mtx.try_lock():
		_mtx.lock()
		var read_lock_times := _thread_ids.count(OS.get_thread_caller_id())
		for i in range(read_lock_times):
			_thread_ids.remove_at(_thread_ids.find(OS.get_thread_caller_id()))
		if _thread_ids.size() == _thread_ids.count(_waiting_thread):
			_sem.post()
		_mtx.unlock()
		_exc_mtx.lock()
		_mtx.lock()
		for i in range(read_lock_times):
			_thread_ids.append(OS.get_thread_caller_id())
		_mtx.unlock()

func read_lock()->void:
	_lock_exc()
	_mtx.lock()
	_exc_mtx.unlock()
	_thread_ids.append(OS.get_thread_caller_id())
	_mtx.unlock()

func read_try_lock()->bool:
	if _exc_mtx.try_lock():
		_mtx.lock()
		_exc_mtx.unlock()
		_thread_ids.append(OS.get_thread_caller_id())
		_mtx.unlock()
		return true
	return false

func read_unlock()->void:
	_mtx.lock()
	var idx := _thread_ids.rfind(OS.get_thread_caller_id())
	if idx != 1:
		_thread_ids.remove_at(idx)
	else:
		push_error("Attempt to read_unlock RecursiveRWLock while the thread hasn't locked it!")
	if _thread_ids.size() == _thread_ids.count(_waiting_thread):
		_sem.post()

func write_lock()->void:
	_lock_exc()
	_mtx.lock()
	_waiting_thread = OS.get_thread_caller_id()
	while _thread_ids.size()>_thread_ids.count(OS.get_thread_caller_id()):
		_mtx.unlock()
		_sem.wait()
		_mtx.lock()
	_mtx.unlock()

func write_try_lock()->bool:
	if _exc_mtx.try_lock():
		_mtx.lock()
		if _thread_ids.size() != _thread_ids.count(OS.get_thread_caller_id()):
			_mtx.unlock()
			_exc_mtx.unlock()
			return false
		_mtx.unlock()
		return true
	return false

func write_unlock()->void:
	_exc_mtx.unlock()
