extends Node
class_name ResLoader
# Manages Resources loaded on its thread. See Main (Singleton) and LoadingScene.

var thread:Thread
var mutex:Mutex
var semaphore:Semaphore

var time_max:int = 100

var exit_thread:bool = false
var queue:Array = []
var pending:Dictionary = {} # path : Resource

func start() -> void:
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	thread = Thread.new()
	thread.start(self, "thread_func", 0)

func thread_func(_u:Object) -> void:
	while true:
		mutex.lock()
		var should_exit:bool = exit_thread
		mutex.unlock()
		if should_exit:
			break
		thread_process()
	Main.call_deferred("loader_thread_ended")

func thread_process() -> void:
	semaphore.wait()
	mutex.lock()

	while queue.size() > 0:
		var res = queue[0]
		mutex.unlock()
		var ret:int = res.poll()
		mutex.lock()

		if ret == ERR_FILE_EOF || ret != OK:
			var path:String = res.get_meta("path")
			if path in pending:
				pending[res.get_meta("path")] = res.get_resource()
			queue.erase(res)
	mutex.unlock()

func queue_resource(path:String, p_in_front:bool = false) -> bool: # returns whether the resource exists
	if !ResourceLoader.exists(path):
		return false
	mutex.lock()
	if path in pending:
		mutex.unlock()
		return true
	elif ResourceLoader.has_cached(path):
		var res:Resource = ResourceLoader.load(path)
		pending[path] = res
		mutex.unlock()
		return true
	else:
		var res:ResourceInteractiveLoader = ResourceLoader.load_interactive(path)
		res.set_meta("path", path)
		if p_in_front:
			queue.insert(0, res)
		else:
			queue.push_back(res)
		pending[path] = res
		semaphore.post()
		mutex.unlock()
		return true

func cancel_resource(path:String) -> void:
	mutex.lock()
	if path in pending:
		if pending[path] is ResourceInteractiveLoader:
			queue.erase(pending[path])
		pending.erase(path)
	mutex.unlock()

func get_progress(path:String) -> float:
	mutex.lock()
	var ret:float = 0.0
	if path in pending:
		if pending[path] is ResourceInteractiveLoader:
			ret = float(pending[path].get_stage()) / float(pending[path].get_stage_count())
		else:
			ret = 1.0
	mutex.unlock()
	return ret

func is_ready(path:String) -> bool:
	var ret:bool
	mutex.lock()
	if path in pending:
		ret = !(pending[path] is ResourceInteractiveLoader)
	else:
		ret = false
	mutex.unlock()
	return ret

func wait_for_resource(res:Resource, path:String) -> Resource:
	mutex.unlock()
	while true:
		VisualServer.sync()
		OS.delay_usec(16000)
		mutex.lock()
		if queue.size() == 0 || queue[0] != res:
			return pending[path]
		mutex.unlock()
	return null # unreachable, but needed to avoid type error from the compiler

func get_resource(path:String) -> Resource:
	mutex.lock()
	if path in pending:
		if pending[path] is ResourceInteractiveLoader:
			var res:Resource = pending[path]
			if res != queue[0]:
				var pos:int = queue.find(res)
				queue.remove(pos)
				queue.insert(0, res)
			res = wait_for_resource(res, path)
			pending.erase(path)
			mutex.unlock()
			return res
		else:
			var res:Resource = pending[path]
			pending.erase(path)
			mutex.unlock()
			return res
	else:
		mutex.unlock()
		return ResourceLoader.load(path)

func exit() -> void: # called on app quit
	mutex.lock()
	exit_thread = true
	queue.clear() # dropping q so the thread can exit asap
	pending.clear()
	mutex.unlock()
	semaphore.post()
