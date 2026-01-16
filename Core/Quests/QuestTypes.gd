class_name QuestTypes
extends RefCounted

## Quest Type Definitions
## Defines different kinds of quests beyond simple delivery

enum Type {
	DELIVERY,       # Deliver X resources (current system)
	SHAPE_ACHIEVE,  # Achieve target observable value once
	SHAPE_MAINTAIN, # Maintain observable value for duration
	EVOLUTION,      # Change observable by delta amount
	ENTANGLEMENT,   # Create coherence between species
	# Quantum mechanics quest types
	ACHIEVE_EIGENSTATE,    # Reach dominant eigenstate (purity > threshold)
	MAINTAIN_COHERENCE,    # Keep coherence above threshold for duration
	INDUCE_BELL_STATE,     # Create entanglement between specific pair
	PREVENT_DECOHERENCE,   # Don't let purity drop below threshold
	COLLAPSE_DELIBERATELY, # Measure to lock in specific state
}


static func get_type_icon(type: Type) -> String:
	"""Get emoji icon for quest type"""
	match type:
		Type.DELIVERY:
			return "📦"
		Type.SHAPE_ACHIEVE:
			return "🎯"
		Type.SHAPE_MAINTAIN:
			return "⏱️"
		Type.EVOLUTION:
			return "🌀"
		Type.ENTANGLEMENT:
			return "🔗"
		Type.ACHIEVE_EIGENSTATE:
			return "🔮"
		Type.MAINTAIN_COHERENCE:
			return "🧵"
		Type.INDUCE_BELL_STATE:
			return "⚛️"
		Type.PREVENT_DECOHERENCE:
			return "🛡️"
		Type.COLLAPSE_DELIBERATELY:
			return "💥"
	return "❓"


static func get_type_name(type: Type) -> String:
	"""Get human-readable type name"""
	match type:
		Type.DELIVERY:
			return "Delivery"
		Type.SHAPE_ACHIEVE:
			return "Shape Achievement"
		Type.SHAPE_MAINTAIN:
			return "Shape Maintenance"
		Type.EVOLUTION:
			return "Evolution"
		Type.ENTANGLEMENT:
			return "Entanglement"
		Type.ACHIEVE_EIGENSTATE:
			return "Eigenstate Prophecy"
		Type.MAINTAIN_COHERENCE:
			return "Coherence Weaving"
		Type.INDUCE_BELL_STATE:
			return "Bell Binding"
		Type.PREVENT_DECOHERENCE:
			return "Decoherence Ward"
		Type.COLLAPSE_DELIBERATELY:
			return "Deliberate Collapse"
	return "Unknown"


static func get_type_description(type: Type) -> String:
	"""Get description of what this quest type requires"""
	match type:
		Type.DELIVERY:
			return "Deliver resources to complete"
		Type.SHAPE_ACHIEVE:
			return "Reach target quantum state once"
		Type.SHAPE_MAINTAIN:
			return "Hold quantum state for duration"
		Type.EVOLUTION:
			return "Change quantum observable by amount"
		Type.ENTANGLEMENT:
			return "Create quantum coherence"
		Type.ACHIEVE_EIGENSTATE:
			return "Reach the prophesied eigenstate (high purity)"
		Type.MAINTAIN_COHERENCE:
			return "Keep quantum threads woven for duration"
		Type.INDUCE_BELL_STATE:
			return "Entangle specific pair in Bell state"
		Type.PREVENT_DECOHERENCE:
			return "Prevent purity from falling below threshold"
		Type.COLLAPSE_DELIBERATELY:
			return "Measure to lock in a specific state"
	return ""


static func requires_tracking(type: Type) -> bool:
	"""Does this quest type need continuous state monitoring?"""
	match type:
		Type.DELIVERY:
			return false  # Checked on resource events only
		Type.SHAPE_ACHIEVE, Type.SHAPE_MAINTAIN, Type.EVOLUTION, Type.ENTANGLEMENT:
			return true  # Need _physics_process monitoring
		Type.ACHIEVE_EIGENSTATE, Type.MAINTAIN_COHERENCE, Type.INDUCE_BELL_STATE, \
		Type.PREVENT_DECOHERENCE, Type.COLLAPSE_DELIBERATELY:
			return true  # Quantum mechanics quests need continuous monitoring
	return false
