extends RefCounted
class_name SingleThreadedTask

var _mtx:=Mutex.new()
var _tasks:=[]
var _completed:={}
var _offline:=true

signal task_completed(task: int, result)

func _offline_check()->void:
	_mtx.lock()
	if _offline:
		_offline = false
		var thr = Thread.new()
		thr.start(_thread_task.bind(thr))
	_mtx.unlock()

func terminate()->void:
	_mtx.lock()
	_offline = true
	_tasks.clear()
	_mtx.unlock()

func is_online()->bool:
	_mtx.lock()
	var x := not _offline
	_mtx.unlock()
	return x

func is_busy()->bool:
	_mtx.lock()
	var x := not _offline and len(_tasks) == 0
	_mtx.unlock()
	return x

func _thread_task(thr: Thread)->void:
	_mtx.lock()
	var offline_time:=0
	while not _offline:
		#_mtx.unlock()
		#_mtx.lock()
		if len(_tasks) > 0:
			offline_time = 0
			var task:Dictionary= _tasks.pop_front()
			_completed[task["id"]]=false
			_mtx.unlock()
			var callable:Callable= task["func"]
			var ret = callable.callv(task["args"])
			_mtx.lock()
			_completed[task["id"]]=true
			_mtx.unlock()
			task_completed.emit(task["id"],ret)
		else:
			_mtx.unlock()
			offline_time += 1
			if offline_time > 100:
				_offline = true
				return
			else:
				OS.delay_msec(50)
		_mtx.lock()
	_mtx.unlock()

func add_task(f: Callable,args:=[],high_priority:=false)->int:
	_mtx.lock()
	_offline_check()
	var task_id := randi()
	if high_priority:
		_tasks.insert(0,{
			"func":f,
			"args":args,
			"id":task_id
		})
	else:
		_tasks.append({
			"func":f,
			"args":args,
			"id":task_id
		})
	_mtx.unlock()
	return task_id

func add_tasks(funcs:Array[Callable],args:Array[Array]=[],high_priority:=false)->Array[int]:
	var minlen:= min(len(funcs),len(args))
	var task_ids:Array[int]=[]
	_mtx.lock()
	for i in range(minlen):
		var task_id:=randi()
		if high_priority:
			_tasks.insert(0,{
				"func":funcs[i],
				"args":args[i],
				"id":task_id
			})
		else:
			_tasks.append({
				"func":funcs[i],
				"args":args[i],
				"id":task_id
			})
		task_ids.append(task_id)
	_mtx.unlock()
	return task_ids

func wait_for_existing(task: int):
	_mtx.lock()
	if _completed.get(task,false):
		_mtx.unlock()
		return
	_mtx.unlock()
	var _mutex:=Semaphore.new()
	var result_:=[]
	var _hook := func _hook(otaskid:int,result):
		if task == otaskid:
			result_.append(result)
			_mutex.post()
	task_completed.connect(_hook)
	_mutex.wait()
	return result_[0]

func add_task_and_wait(f: Callable,args=[],high_priority:=false):
	_mtx.lock()
	_offline_check()
	var task_id := randi()
	if high_priority:
		_tasks.insert(0,{
			"func":f,
			"args":args,
			"id":task_id
		})
	else:
		_tasks.append({
			"func":f,
			"args":args,
			"id":task_id
		})
	_mtx.unlock()
	var _mutex:=Semaphore.new()
	var result_:=[]
	var _hook := func _hook(otaskid:int,result):
		if task_id == otaskid:
			result_.append(result)
			_mutex.post()
	task_completed.connect(_hook)
	_mutex.wait()
	return result_[0]
