extends RefCounted
class_name MultiThreadedTask

func add_task(f: Callable, args=[],high_priority:=false)->int:
	return WorkerThreadPool.add_task(f.bindv(args),high_priority,"MultiThreadedTask")

func add_tasks(funcs:Array[Callable],args:Array[Array]=[],high_priority:=false)->Array[int]:
	var minlen:= min(len(funcs),len(args))
	var task_ids:=[]
	for i in range(minlen):
		task_ids.append(WorkerThreadPool.add_task(funcs[i].bindv(args),high_priority,"MultiThreadedTask-Multiple"))
	return task_ids

func wait_for_task_existing(task: int)->Error:
	return WorkerThreadPool.wait_for_task_completion(task)

func add_task_and_wait(f: Callable, args=[],high_priority:=false)->Error:
	return WorkerThreadPool.wait_for_task_completion(WorkerThreadPool.add_task(f.bindv(args),high_priority,"MultiThreadedtask"))
