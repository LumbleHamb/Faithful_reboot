# scripts/ui/transient_message.gd
extends Label

@export var stay_duration: float = 2.0
@export var fade_duration: float = 1.0

func _ready() -> void:
	# Make sure the label starts fully visible
	var start_color = self.modulate
	start_color.a = 1.0
	self.modulate = start_color

	# Create a tween for the fade-out animation
	var tween = create_tween()
	
	# The tween will wait for 'stay_duration', then animate the alpha property
	# of the modulate color over 'fade_duration' seconds.
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_delay(stay_duration)
	
	# After the tween is finished, call queue_free() to remove the node.
	tween.tween_callback(queue_free)
