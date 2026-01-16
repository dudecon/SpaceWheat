## OuterFactions.gd
## The outer ring - weird, dangerous, reality-bending
## 11 factions that push the boundaries of what's possible

class_name OuterFactions
extends RefCounted

const Faction = preload("res://Core/Factions/Faction.gd")

## ========================================
## BATCH 7: THE OUTER RING (11 factions)
## Reality breaks down here
## ========================================


## Void Troubadours (second ring, edge)
## "We sing to what listens." Musicians at the edge.
static func create_void_troubadours() -> Faction:
	var f = Faction.new()
	f.name = "Void Troubadours"
	f.description = "Musicians who perform at the edge of known space. Their songs reach into the void, and sometimes the void sings back."
	f.ring = "second"
	f.signature = ["🎸", "🎼", "💫", "🏮"]
	f.tags = ["music", "void", "edge", "communication"]

	# COOL IDEAS:
	# - Music as void-signal
	# - Resonance with unknown
	# - Driver for performance cycles
	# IMPLEMENTED: Musical void-contact with resonance

	f.self_energies = {
		"🎸": 0.2,    # Guitar - the instrument
		"🎼": 0.25,   # Music - the message
		"💫": 0.15,   # Sparkle - void response (unstable)
		"🏮": 0.2,    # Lantern - light in darkness
	}

	# Imaginary coupling for void resonance
	f.hamiltonian = {
		"🎸": {
			"🎼": 0.6,   # Guitar makes music
			"💫": Vector2(0.3, 0.4),  # Void response (imaginary)
			"🏮": 0.3,
		},
		"🎼": {
			"🎸": 0.6,
			"💫": Vector2(0.5, 0.3),  # Music reaches void
			"🏮": 0.4,   # Music and light
		},
		"💫": {
			"🎸": Vector2(0.3, -0.4),  # Conjugate
			"🎼": Vector2(0.5, -0.3),
		},
		"🏮": {
			"🎸": 0.3,
			"🎼": 0.4,
		},
	}

	# Performance cycle driver
	f.drivers = {
		"🎼": {
			"type": "sine",
			"amplitude": 0.12,
			"frequency": 0.4,
			"phase": 0.0,
		},
		"💫": {
			"type": "sine",
			"amplitude": 0.15,
			"frequency": 0.4,
			"phase": 1.57,  # π/2 offset - responds to music
		},
	}

	f.lindblad_incoming = {
		"💫": {
			"🎼": 0.04,  # Music summons void response
		},
	}

	f.decay = {
		"💫": {"rate": 0.05, "target": "🗑"},  # Void fades fast
	}

	f.alignment_couplings = {
		"🎼": {
			"🔊": +0.20,  # Sound amplifies
			"🔇": -0.25,  # Silence suppresses
		},
		"💫": {
			"🌑": +0.30,  # Darkness enhances void contact
			"🕳": +0.25,
		},
		"🏮": {
			"🌑": +0.20,  # Light visible in dark
		},
	}

	return f


## The Vitreous Scrutiny (third ring)
## "We measure the unmeasurable." Deep observation.
static func create_vitreous_scrutiny() -> Faction:
	var f = Faction.new()
	f.name = "The Vitreous Scrutiny"
	f.description = "Obsessive observers who stare into reality's structure until it stares back. Their mathematics touches things that shouldn't exist."
	f.ring = "third"
	f.signature = ["🔬", "🧲", "📐", "🧮", "🔭"]
	f.tags = ["observation", "mathematics", "dangerous", "deep"]

	# COOL IDEAS:
	# - Observation changes things (measurement behavior)
	# - Math as reality manipulation
	# - Danger from looking too deep
	# IMPLEMENTED: Deep observation with measurement effects

	f.self_energies = {
		"🔬": 0.2,    # Microscope - close look
		"🧲": 0.15,   # Magnet - attraction of attention
		"📐": 0.25,   # Ruler - measurement
		"🧮": 0.2,    # Abacus - calculation
		"🔭": 0.2,    # Telescope - far look
	}

	f.hamiltonian = {
		"🔬": {
			"📐": 0.5,   # Microscope measures
			"🧲": 0.4,   # Magnets in lab
			"🔭": 0.5,   # Both observation tools
		},
		"🧲": {
			"🔬": 0.4,
			"🧮": 0.3,
		},
		"📐": {
			"🔬": 0.5,
			"🧮": 0.6,   # Measurement and calculation
			"🔭": 0.4,
		},
		"🧮": {
			"🧲": 0.3,
			"📐": 0.6,
			"🔭": 0.4,
		},
		"🔭": {
			"🔬": 0.5,
			"📐": 0.4,
			"🧮": 0.4,
		},
	}

	# Measurement behavior - observation affects reality
	f.measurement_behavior = {
		"🔬": {
			"collapses": true,
			"inverts": false,
			"strength": 0.3,
		},
		"🔭": {
			"collapses": true,
			"inverts": false,
			"strength": 0.2,
		},
	}

	f.lindblad_incoming = {
		"📐": {
			"🔬": 0.03,  # Observation produces measurements
			"🔭": 0.02,
		},
		"🧮": {
			"📐": 0.03,  # Measurements need calculation
		},
	}

	f.decay = {
		"🧲": {"rate": 0.02, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🔬": {
			"🧬": +0.20,  # Genetics to observe
			"🦠": +0.15,
		},
		"🔭": {
			"🌠": +0.25,  # Stars to watch
			"🌑": +0.15,  # Deep space
		},
		"🧮": {
			"🔢": +0.15,
		},
	}

	# Decoherence coupling: Observation causes decoherence (quantum measurement effect)
	f.decoherence_coupling = {
		"🔬": +0.35,  # Microscope - close observation
		"🔭": +0.25,  # Telescope - far observation
		"📐": +0.15,  # Measurement
	}

	return f


## Resonance Dancers (third ring)
## "We dance reality stable." Rhythm as physics.
static func create_resonance_dancers() -> Faction:
	var f = Faction.new()
	f.name = "Resonance Dancers"
	f.description = "Dancers whose movements stabilize unstable regions of space. Where they perform, reality holds together. Where they don't..."
	f.ring = "third"
	f.signature = ["💃", "🎼", "🔊", "📡", "🩰"]
	f.tags = ["dance", "stability", "resonance", "ritual"]

	# COOL IDEAS:
	# - Dance as reality stabilization
	# - Broadcast presence through space
	# - Negative effects when they stop
	# IMPLEMENTED: Stabilizing dance with broadcast effect

	f.self_energies = {
		"💃": 0.3,    # Dancer - the practitioner
		"🎼": 0.25,   # Music - the rhythm
		"🔊": 0.2,    # Speaker - broadcast
		"📡": 0.2,    # Antenna - reach
		"🩰": 0.25,   # Ballet shoes - precision
	}

	f.hamiltonian = {
		"💃": {
			"🎼": 0.7,   # Dance to music
			"🔊": 0.4,   # Dance heard
			"🩰": 0.6,   # Dance with shoes
		},
		"🎼": {
			"💃": 0.7,
			"🔊": 0.6,   # Music broadcast
			"🩰": 0.4,
		},
		"🔊": {
			"💃": 0.4,
			"🎼": 0.6,
			"📡": 0.5,   # Sound through antenna
		},
		"📡": {
			"🔊": 0.5,
			"🎼": 0.3,
		},
		"🩰": {
			"💃": 0.6,
			"🎼": 0.4,
		},
	}

	# Dance cycle driver
	f.drivers = {
		"💃": {
			"type": "sine",
			"amplitude": 0.1,
			"frequency": 0.5,
			"phase": 0.0,
		},
		"🩰": {
			"type": "sine",
			"amplitude": 0.08,
			"frequency": 0.5,
			"phase": 0.0,  # In phase with dance
		},
	}

	f.lindblad_incoming = {
		"📡": {
			"🔊": 0.04,  # Sound broadcasts
		},
	}

	# Dance stabilizes - positive alignments
	f.alignment_couplings = {
		"💃": {
			"🌀": -0.25,  # Counteracts chaos
			"⚖": +0.20,  # Supports balance
		},
		"🔊": {
			"🔇": -0.30,  # Opposes silence
		},
		"🎼": {
			"🎵": +0.20,  # Music synergy
		},
	}

	return f


## The Opalescent Hegemon (third ring)
## "We watch the watcher." Cosmic oversight.
static func create_opalescent_hegemon() -> Faction:
	var f = Faction.new()
	f.name = "The Opalescent Hegemon"
	f.description = "They claim to observe from outside time itself. Their judgments are final because they've already seen all outcomes."
	f.ring = "third"
	f.signature = ["🔭", "⚫", "🌠", "⚖"]
	f.tags = ["cosmic", "observation", "judgment", "timeless"]

	# COOL IDEAS:
	# - Outside-time perspective
	# - Judgment as measurement
	# - Black orb as focal point
	# IMPLEMENTED: Cosmic oversight with judgment mechanics

	f.self_energies = {
		"🔭": 0.25,   # Telescope - observation
		"⚫": 0.3,    # Black circle - the unknown
		"🌠": 0.2,    # Stars - the cosmic
		"⚖": 0.3,    # Scale - judgment
	}

	# Imaginary coupling for timeless observation
	f.hamiltonian = {
		"🔭": {
			"⚫": Vector2(0.5, 0.4),  # Looking into void
			"🌠": 0.6,   # Watching stars
			"⚖": 0.4,
		},
		"⚫": {
			"🔭": Vector2(0.5, -0.4),
			"🌠": Vector2(0.4, 0.3),  # Void among stars
			"⚖": 0.5,   # Void and judgment
		},
		"🌠": {
			"🔭": 0.6,
			"⚫": Vector2(0.4, -0.3),
		},
		"⚖": {
			"🔭": 0.4,
			"⚫": 0.5,
		},
	}

	# Measurement behavior - judgment collapses outcomes
	f.measurement_behavior = {
		"⚖": {
			"collapses": true,
			"inverts": false,
			"strength": 0.4,
		},
	}

	f.lindblad_incoming = {
		"⚖": {
			"🔭": 0.03,  # Observation leads to judgment
		},
	}

	f.decay = {
		"🌠": {"rate": 0.015, "target": "⚫"},  # Stars fall into void
	}

	f.alignment_couplings = {
		"⚫": {
			"🕳": +0.30,  # Void alignment
			"🌑": +0.25,
		},
		"🔭": {
			"🔬": +0.15,  # Observation synergy
		},
		"⚖": {
			"🏛": +0.20,  # Order alignment
		},
	}

	return f


## Void Emperors (third ring)
## "The void has laws." Administration of nothing.
static func create_void_emperors() -> Faction:
	var f = Faction.new()
	f.name = "Void Emperors"
	f.description = "They administer the emptiness between stars. Their bureaucracy governs nothing, yet their edicts shape what might emerge."
	f.ring = "third"
	f.signature = ["⚫", "⚜", "♟", "🕰"]
	f.tags = ["void", "administration", "nothing", "law"]

	# COOL IDEAS:
	# - Bureaucracy of emptiness
	# - Time manipulation
	# - Chess as strategy in void
	# IMPLEMENTED: Void administration with temporal effects

	f.self_energies = {
		"⚫": 0.35,   # Black circle - the void (stable)
		"⚜": 0.25,   # Fleur-de-lis - authority
		"♟": 0.2,    # Chess pawn - strategy
		"🕰": 0.15,   # Clock - time (unstable at edge)
	}

	# Imaginary couplings for void-time interaction
	f.hamiltonian = {
		"⚫": {
			"⚜": 0.5,   # Void and authority
			"♟": 0.4,   # Strategy in void
			"🕰": Vector2(0.3, 0.5),  # Void-time bridge
		},
		"⚜": {
			"⚫": 0.5,
			"♟": 0.5,   # Authority directs strategy
			"🕰": 0.3,
		},
		"♟": {
			"⚫": 0.4,
			"⚜": 0.5,
			"🕰": 0.4,   # Strategy over time
		},
		"🕰": {
			"⚫": Vector2(0.3, -0.5),
			"⚜": 0.3,
			"♟": 0.4,
		},
	}

	# Slow driver for void time
	f.drivers = {
		"🕰": {
			"type": "sine",
			"amplitude": 0.06,
			"frequency": 0.1,  # Very slow - void time
			"phase": 0.0,
		},
	}

	f.lindblad_incoming = {
		"⚜": {
			"⚫": 0.02,  # Void grants authority
		},
	}

	# Everything decays to void
	f.lindblad_outgoing = {
		"everything": {
			"⚫": 0.01,  # Generic void pull
		},
	}

	f.decay = {
		"♟": {"rate": 0.02, "target": "⚫"},  # Pawns fall to void
	}

	f.alignment_couplings = {
		"⚫": {
			"🕳": +0.35,  # Void synergy
			"✨": -0.20,  # Light opposes
		},
		"🕰": {
			"⏳": +0.20,  # Time synergy
		},
		"⚜": {
			"👑": +0.15,
		},
	}

	return f


## Flesh Architects (third ring)
## "We build in meat." Bio-construction.
static func create_flesh_architects() -> Faction:
	var f = Faction.new()
	f.name = "Flesh Architects"
	f.description = "Builders who work in living tissue. Their constructions grow, heal, and hunger. Some of their buildings have learned to want."
	f.ring = "third"
	f.signature = ["🫀", "🧬", "🩸", "🧫", "🧵"]
	f.tags = ["biology", "construction", "horror", "living"]

	# COOL IDEAS:
	# - Living buildings
	# - Blood as mortar
	# - Genetics as blueprint
	# IMPLEMENTED: Bio-construction with blood binding

	f.self_energies = {
		"🫀": 0.2,    # Heart - the engine
		"🧬": 0.25,   # DNA - the blueprint
		"🩸": 0.15,   # Blood - the binding
		"🧫": 0.2,    # Petri dish - growth medium
		"🧵": 0.15,   # Thread - sinew
	}

	f.hamiltonian = {
		"🫀": {
			"🩸": 0.7,   # Heart pumps blood
			"🧬": 0.5,   # Heart from genes
			"🧵": 0.3,
		},
		"🧬": {
			"🫀": 0.5,
			"🧫": 0.6,   # Genes in culture
			"🧵": 0.4,   # Genetic thread
		},
		"🩸": {
			"🫀": 0.7,
			"🧫": 0.4,   # Blood in culture
		},
		"🧫": {
			"🧬": 0.6,
			"🩸": 0.4,
			"🧵": 0.3,
		},
		"🧵": {
			"🫀": 0.3,
			"🧬": 0.4,
			"🧫": 0.3,
		},
	}

	# Blood-gated growth
	f.gated_lindblad = {
		"🫀": [
			{
				"source": "🧬",   # Genes → Heart
				"rate": 0.05,
				"gate": "🩸",     # REQUIRES blood
				"power": 1.2,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"🩸": {
			"🫀": 0.04,  # Heart produces blood
		},
		"🧵": {
			"🧬": 0.03,  # Genes produce sinew
		},
	}

	f.decay = {
		"🩸": {"rate": 0.04, "target": "🗑"},  # Blood dries
		"🧫": {"rate": 0.025, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🧬": {
			"🔬": +0.20,  # Science helps
			"🦠": +0.15,
		},
		"🫀": {
			"💀": -0.20,  # Death stops hearts
		},
		"🩸": {
			"⚔": +0.15,  # Combat draws blood
		},
	}

	return f


## Cult of the Drowned Star (third ring)
## "It fell and waits." Void worship.
static func create_cult_of_drowned_star() -> Faction:
	var f = Faction.new()
	f.name = "Cult of the Drowned Star"
	f.description = "They worship a star that fell into nothing. They believe it waits at the bottom of the void, dreaming of return."
	f.ring = "third"
	f.signature = ["⭐", "🫧", "🕳", "⚱"]
	f.tags = ["cult", "void", "worship", "fallen"]

	# COOL IDEAS:
	# - Fallen star theology
	# - Bubble as void-surfacing
	# - Urns for offerings
	# IMPLEMENTED: Void worship with drowning mechanics

	f.self_energies = {
		"⭐": -0.1,   # Star - fallen (negative!)
		"🫧": 0.15,   # Bubble - void surfacing
		"🕳": 0.3,    # Hole - the void (stable for them)
		"⚱": 0.2,    # Urn - offerings
	}

	# Imaginary coupling for star-void relationship
	f.hamiltonian = {
		"⭐": {
			"🫧": 0.4,   # Star bubbles up
			"🕳": Vector2(0.6, 0.5),  # Star in void (complex)
			"⚱": 0.3,   # Star worshipped
		},
		"🫧": {
			"⭐": 0.4,
			"🕳": 0.5,   # Bubbles from void
		},
		"🕳": {
			"⭐": Vector2(0.6, -0.5),
			"🫧": 0.5,
			"⚱": 0.4,   # Offerings to void
		},
		"⚱": {
			"⭐": 0.3,
			"🕳": 0.4,
		},
	}

	# Star pulls things into void
	f.lindblad_outgoing = {
		"⭐": {
			"🕳": 0.03,  # Stars fall to void
		},
	}

	f.lindblad_incoming = {
		"🫧": {
			"🕳": 0.04,  # Void produces bubbles
		},
		"⚱": {
			"💀": 0.03,  # Death fills urns
		},
	}

	f.decay = {
		"⭐": {"rate": 0.02, "target": "🕳"},  # Stars drown
		"🫧": {"rate": 0.05, "target": "🗑"},  # Bubbles pop
	}

	f.alignment_couplings = {
		"🕳": {
			"⚫": +0.30,  # Void synergy
			"🌑": +0.25,
		},
		"⭐": {
			"🌠": +0.20,  # Star alignment
			"☀": -0.15,   # Opposed to living sun
		},
		"⚱": {
			"💀": +0.20,  # Death fills urns
		},
	}

	return f


## Laughing Court (third ring)
## "The joke is on everyone." Chaos entertainment.
static func create_laughing_court() -> Faction:
	var f = Faction.new()
	f.name = "Laughing Court"
	f.description = "A court of jesters, fools, and tricksters who've realized the cosmic joke. Their laughter is contagious - dangerously so."
	f.ring = "third"
	f.signature = ["🤡", "🃏", "🍷", "🥂", "🎪"]
	f.tags = ["chaos", "entertainment", "memetic", "madness"]

	# COOL IDEAS:
	# - Memetic infection through laughter
	# - Wine as intoxication vector
	# - Circus as chaos zone
	# IMPLEMENTED: Memetic spread with celebration drivers

	f.self_energies = {
		"🤡": 0.15,   # Clown - unstable
		"🃏": 0.2,    # Joker - wildcard
		"🍷": 0.1,    # Wine - intoxicant
		"🥂": 0.2,    # Champagne - celebration
		"🎪": 0.25,   # Circus - the venue
	}

	f.hamiltonian = {
		"🤡": {
			"🃏": 0.6,   # Clowns and jokers
			"🎪": 0.7,   # Clowns in circus
			"🍷": 0.4,
		},
		"🃏": {
			"🤡": 0.6,
			"🎪": 0.5,
			"🥂": 0.4,
		},
		"🍷": {
			"🤡": 0.4,
			"🥂": 0.7,   # Wine and champagne
			"🎪": 0.3,
		},
		"🥂": {
			"🃏": 0.4,
			"🍷": 0.7,
			"🎪": 0.5,   # Celebration at circus
		},
		"🎪": {
			"🤡": 0.7,
			"🃏": 0.5,
			"🥂": 0.5,
		},
	}

	# Celebration driver - party cycle
	f.drivers = {
		"🥂": {
			"type": "pulse",
			"amplitude": 0.15,
			"frequency": 0.3,
			"phase": 0.0,
		},
		"🤡": {
			"type": "sine",
			"amplitude": 0.1,
			"frequency": 0.4,
			"phase": 0.0,
		},
	}

	# Memetic spread - laughter is contagious
	f.lindblad_incoming = {
		"🤡": {
			"🎪": 0.05,  # Circus breeds clowns
			"🍷": 0.03,  # Wine makes fools
		},
		"🃏": {
			"🤡": 0.04,  # Clowns become jokers
		},
	}

	f.lindblad_outgoing = {
		"🍷": {
			"🗑": 0.04,  # Wine gets drunk
		},
	}

	f.decay = {
		"🍷": {"rate": 0.04, "target": "🗑"},
		"🥂": {"rate": 0.03, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🤡": {
			"😂": +0.25,  # Laughter helps
			"🏛": -0.20,  # Order opposes
		},
		"🎪": {
			"🎭": +0.20,  # Theater synergy
		},
		"🃏": {
			"🌀": +0.15,  # Chaos helps jokers
		},
	}

	return f


## Chorus of Oblivion (third ring)
## "We sing the ending." Identity dissolution.
static func create_chorus_of_oblivion() -> Faction:
	var f = Faction.new()
	f.name = "Chorus of Oblivion"
	f.description = "Their songs dissolve identity. Those who join the chorus forget who they were. Eventually, the song is all that remains."
	f.ring = "third"
	f.signature = ["🎶", "🔔", "🫥", "🪦", "🕸", "🕯"]
	f.tags = ["dissolution", "identity", "song", "oblivion"]

	# COOL IDEAS:
	# - Identity destruction
	# - Music as erasure
	# - Measurement inversion - being observed makes you fade
	# IMPLEMENTED: Identity dissolution with inversion mechanics

	f.self_energies = {
		"🎶": 0.2,    # Music - the song
		"🔔": 0.2,    # Bell - the call
		"🫥": -0.1,   # Dotted face - fading identity (negative!)
		"🪦": 0.15,   # Tombstone - ending
		"🕸": 0.15,   # Web - connection
		"🕯": 0.2,    # Candle - vigil
	}

	# Imaginary couplings for identity dissolution
	f.hamiltonian = {
		"🎶": {
			"🔔": 0.6,   # Music and bells
			"🫥": Vector2(0.5, 0.4),  # Music dissolves (imaginary)
			"🕯": 0.4,
		},
		"🔔": {
			"🎶": 0.6,
			"🫥": 0.4,   # Bells call to oblivion
			"🪦": 0.4,
		},
		"🫥": {
			"🎶": Vector2(0.5, -0.4),
			"🔔": 0.4,
			"🪦": 0.5,   # Fading leads to death
			"🕸": 0.4,   # Caught in web
		},
		"🪦": {
			"🔔": 0.4,
			"🫥": 0.5,
			"🕯": 0.5,   # Candles at graves
		},
		"🕸": {
			"🫥": 0.4,
			"🕯": 0.3,
		},
		"🕯": {
			"🎶": 0.4,
			"🪦": 0.5,
			"🕸": 0.3,
		},
	}

	# Measurement inversion - being observed accelerates fading
	f.measurement_behavior = {
		"🫥": {
			"collapses": true,
			"inverts": true,   # Being measured makes you fade faster!
			"strength": 0.4,
		},
	}

	# Identity dissolution
	f.lindblad_incoming = {
		"🫥": {
			"🎶": 0.05,  # Music dissolves identity
			"🕸": 0.03,  # Web traps
		},
		"🪦": {
			"🫥": 0.04,  # Fading leads to death
		},
	}

	f.lindblad_outgoing = {
		"👤": {
			"🫥": 0.04,  # Identity → fading
		},
	}

	f.decay = {
		"🕯": {"rate": 0.03, "target": "🗑"},
		"🫥": {"rate": 0.02, "target": "🪦"},  # Fading → death
	}

	f.alignment_couplings = {
		"🎶": {
			"🔇": -0.25,  # Silence opposes
		},
		"🫥": {
			"🌑": +0.25,  # Darkness helps fading
			"☀": -0.20,   # Light opposes
		},
		"🕸": {
			"🕷": +0.20,  # Spider synergy
		},
	}

	return f


## Black Horizon (outer ring)
## "The edge is everywhere." Boundary of reality.
static func create_black_horizon() -> Faction:
	var f = Faction.new()
	f.name = "Black Horizon"
	f.description = "They live at the edge of everything - the boundary where something becomes nothing. They're not sure which side they're on."
	f.ring = "outer"
	f.signature = ["⚫", "🕳", "🪐", "🌀"]
	f.tags = ["boundary", "void", "edge", "nothing"]

	# COOL IDEAS:
	# - Boundary condition of reality
	# - Everything decays here
	# - Spiral as the pull
	# IMPLEMENTED: Reality boundary with strong void pull

	f.self_energies = {
		"⚫": 0.4,    # Black circle - void (very stable at edge)
		"🕳": 0.35,   # Hole - the pull
		"🪐": 0.1,    # Planet - falling in (unstable)
		"🌀": 0.2,    # Spiral - the motion
	}

	# Imaginary couplings for reality boundary
	f.hamiltonian = {
		"⚫": {
			"🕳": 0.7,   # Void and hole
			"🪐": Vector2(0.4, 0.5),  # Planets falling (imaginary)
			"🌀": 0.5,
		},
		"🕳": {
			"⚫": 0.7,
			"🪐": 0.5,   # Hole pulls planets
			"🌀": 0.6,   # Spiral into hole
		},
		"🪐": {
			"⚫": Vector2(0.4, -0.5),
			"🕳": 0.5,
			"🌀": 0.5,   # Planets spiral
		},
		"🌀": {
			"⚫": 0.5,
			"🕳": 0.6,
			"🪐": 0.5,
		},
	}

	# Strong void pull
	f.lindblad_incoming = {
		"🕳": {
			"🪐": 0.04,  # Planets fall in
			"⚫": 0.02,  # Void expands
		},
	}

	f.lindblad_outgoing = {
		"🪐": {
			"🕳": 0.03,  # Planets → void
		},
		"✨": {
			"⚫": 0.04,  # Light → dark
		},
	}

	# Everything decays to void here
	f.decay = {
		"🪐": {"rate": 0.03, "target": "🕳"},
		"🌀": {"rate": 0.02, "target": "⚫"},
	}

	f.alignment_couplings = {
		"⚫": {
			"🌑": +0.35,  # Darkness synergy
			"☀": -0.30,   # Light opposes
		},
		"🕳": {
			"⭐": +0.20,  # Stars fall in
		},
		"🌀": {
			"🌊": +0.15,  # Wave motion
		},
	}

	return f


## Reality Midwives (outer ring)
## "We birth what could be." Pattern emergence.
static func create_reality_midwives() -> Faction:
	var f = Faction.new()
	f.name = "Reality Midwives"
	f.description = "They assist in the birth of new patterns from chaos. What emerges isn't always what was expected. Not everything should be born."
	f.ring = "outer"
	f.signature = ["✨", "💫", "🌠", "🤲"]
	f.tags = ["creation", "emergence", "pattern", "birth"]

	# COOL IDEAS:
	# - Opposite of Black Horizon
	# - Creation from nothing
	# - Hands as gentle creation
	# IMPLEMENTED: Pattern emergence with creation dynamics

	f.self_energies = {
		"✨": 0.25,   # Sparkle - emergence
		"💫": 0.2,    # Dizzy star - new pattern
		"🌠": 0.3,    # Shooting star - creation
		"🤲": 0.25,   # Hands - receiving
	}

	# Imaginary couplings for creation dynamics
	f.hamiltonian = {
		"✨": {
			"💫": 0.6,   # Sparkle becomes star
			"🌠": 0.5,   # Sparkle and shooting star
			"🤲": Vector2(0.4, 0.3),  # Hands receive (imaginary)
		},
		"💫": {
			"✨": 0.6,
			"🌠": 0.5,   # Stars together
			"🤲": 0.4,
		},
		"🌠": {
			"✨": 0.5,
			"💫": 0.5,
			"🤲": 0.5,   # Caught in hands
		},
		"🤲": {
			"✨": Vector2(0.4, -0.3),
			"💫": 0.4,
			"🌠": 0.5,
		},
	}

	# Creation dynamics - opposite of Black Horizon
	f.lindblad_incoming = {
		"✨": {
			"🕳": 0.03,  # Void births sparkles!
			"⚫": 0.02,  # Darkness births light
		},
		"💫": {
			"✨": 0.04,  # Sparkles become stars
		},
		"🌠": {
			"💫": 0.03,  # Stars shoot
		},
	}

	# Very slow decay - new patterns persist
	f.decay = {
		"✨": {"rate": 0.01, "target": "🗑"},
		"💫": {"rate": 0.015, "target": "✨"},  # Stars fade to sparkle
	}

	f.alignment_couplings = {
		"✨": {
			"🌑": +0.25,  # Light in darkness
			"⚫": +0.20,  # Birth from void
		},
		"🌠": {
			"🌙": +0.20,  # Night sky
			"🔭": +0.15,  # Being watched
		},
		"🤲": {
			"👶": +0.20,  # Birth alignment
		},
	}

	# Decoherence coupling: ✨ REDUCES decoherence (stabilizes coherence)
	# This counters the chaos of 🌀 in SemanticDrift
	f.decoherence_coupling = {
		"✨": -0.4,   # Sparkle strongly decreases decoherence (stabilizes!)
		"💫": -0.2,   # Stars help stabilize
		"🌠": -0.15,  # Shooting stars bring order
	}

	f.tags.append("drift_stabilizer")  # Counters semantic drift from 🌀

	return f


## ========================================
## Utility Functions
## ========================================

static func get_all() -> Array:
	return [
		create_void_troubadours(),
		create_vitreous_scrutiny(),
		create_resonance_dancers(),
		create_opalescent_hegemon(),
		create_void_emperors(),
		create_flesh_architects(),
		create_cult_of_drowned_star(),
		create_laughing_court(),
		create_chorus_of_oblivion(),
		create_black_horizon(),
		create_reality_midwives(),
	]

static func get_factions_for_emoji(emoji: String) -> Array:
	var result: Array = []
	for faction in get_all():
		if faction.speaks(emoji):
			result.append(faction)
	return result
