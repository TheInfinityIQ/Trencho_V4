extends RefCounted
## One FIFO console consumer. No scene, ledger, counter or renderer access.
var _thread := Thread.new()
var _mutex := Mutex.new()
var _available := Semaphore.new()
var _pending: Array[PackedStringArray] = []
var _stopping := false
var _busy := false
var _delivered := 0

func start() -> Error:
	return _thread.start(_run,Thread.PRIORITY_LOW)

func enqueue(lines: PackedStringArray) -> void:
	if lines.is_empty(): return
	_mutex.lock()
	_pending.append(lines.duplicate())
	_mutex.unlock()
	_available.post()

func status() -> Dictionary:
	_mutex.lock()
	var result := {"queued_batches":_pending.size(),"busy":_busy,"delivered_lines":_delivered,"started":_thread.is_started()}
	_mutex.unlock()
	return result

func _run() -> void:
	while true:
		_available.wait()
		_mutex.lock()
		var batches: Array[PackedStringArray] = _pending
		_pending = []
		_busy = not batches.is_empty()
		var stop: bool = _stopping
		_mutex.unlock()
		var delivered := 0
		# A blocked native console never holds the queue mutex. The main thread
		# can enqueue the next immutable report without waiting for these writes.
		for lines in batches:
			for line in lines:
				print(line)
				delivered += 1
		_mutex.lock()
		_delivered += delivered
		_busy = false
		stop = stop and _pending.is_empty()
		_mutex.unlock()
		if stop: return

func close() -> void:
	_mutex.lock()
	_stopping = true
	_mutex.unlock()
	_available.post()
	if _thread.is_started():
		_thread.wait_to_finish()
	else:
		# Thread creation failure retains text until shutdown rather than
		# silently discarding reports or blocking a gameplay callback.
		for lines in _pending:
			for line in lines:
				print(line)
				_delivered += 1
		_pending.clear()
