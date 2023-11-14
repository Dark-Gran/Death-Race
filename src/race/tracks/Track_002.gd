extends Track

func _on_TrainTimer_timeout() -> void: # signal from TrainTimer
	anims_play()

func anims_play() -> void:
	$Train/AnimationPlayer.play("TrainMove")
	$RailroadGate/RailroadGatePartA/AnimationPlayer.play("GateMove")
	if $RailroadGate/RailroadGatePartB.has_node("AnimationPlayer"):
		$RailroadGate/RailroadGatePartB/AnimationPlayer.play("GateMove")
	$RailroadGate2/RailroadGatePartA/AnimationPlayer.play("GateMove")
	if $RailroadGate2/RailroadGatePartB.has_node("AnimationPlayer"):
		$RailroadGate2/RailroadGatePartB/AnimationPlayer.play("GateMove")
