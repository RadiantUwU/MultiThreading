extends RefCounted
class_name ComputeModule

var _mtx:=Mutex.new()
var _sync:=SingleThreadedTask.new()
var _multi:=MultiThreadedTask.new()

var _active:=0

func _deferred_call(f:Callable,args:Array)->void:
	f.callv(args)
	
func get_active()->int:
	_mtx.lock()
	var r := _active
	_mtx.unlock()
	return r

func _on_run(compute_func:Callable,output_func:Callable,pass_original_args_aswell:bool,high_priority:bool,run_on_main:bool,args:Array)->void:
	_mtx.lock()
	_active+=1
	_mtx.unlock()
	var ret = compute_func.callv(args)
	if pass_original_args_aswell:
		args.push_front(ret)
	else:
		args = [ret]
	_mtx.lock()
	if run_on_main:
		_deferred_call.call_deferred(output_func,args)
	else:
		var sync := _sync
		_mtx.unlock()
		sync.add_task_and_wait(output_func,args,high_priority)
		_mtx.lock()
	_active -= 1
	_mtx.unlock()
	

func run(compute_func:Callable,output_func:Callable,args_array:Array,pass_original_args_aswell:=true,high_priority:=false,run_on_main:=false):
	for args in args_array:
		_multi.add_task(_on_run,[compute_func,output_func,pass_original_args_aswell,high_priority,run_on_main,args.duplicate()],high_priority)
