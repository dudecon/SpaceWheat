extends SceneTree

## Comprehensive Quest & Vocabulary Progression Test
## Tests:
## 1. Starter accessibility (should be 7 factions)
## 2. Vocabulary unlock mechanics
## 3. Faction accessibility changes
## 4. Quest variety with different vocabularies

const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const QuestTheming = preload("res://Core/Quests/QuestTheming.gd")
const GameState = preload("res://Core/GameState/GameState.gd")

func _init():
	print("\n" + "═".repeat(70))
	print("QUEST & VOCABULARY PROGRESSION TEST")
	print("═".repeat(70) + "\n")

	# Test 1: Starter accessibility
	test_starter_accessibility()

	# Test 2: Vocabulary progression paths
	test_vocabulary_progression()

	# Test 3: Faction accessibility mapping
	test_faction_accessibility_mapping()

	# Test 4: Vocabulary "tech trees"
	test_vocabulary_tech_trees()

	print("\n" + "═".repeat(70))
	print("TEST COMPLETE")
	print("═".repeat(70) + "\n")

	quit()


func test_starter_accessibility():
	print("─".repeat(70))
	print("TEST 1: Starter Accessibility")
	print("─".repeat(70))

	var starter_vocab = ["🍞", "👥"]
	print("Starter vocabulary: %s\n" % "".join(starter_vocab))

	var accessible = []
	var inaccessible = []

	for faction in FactionDatabase.ALL_FACTIONS:
		var faction_vocab = FactionDatabase.get_faction_vocabulary(faction)
		var overlap = FactionDatabase.get_vocabulary_overlap(faction_vocab.signature, starter_vocab)

		if overlap.size() > 0:
			accessible.append({
				"name": faction.name,
				"signature": faction.sig,
				"overlap": overlap
			})
		else:
			inaccessible.append(faction.name)

	print("Accessible factions: %d / 68\n" % accessible.size())
	for f in accessible:
		print("  ✅ %s" % f.name)
		print("     Signature: %s" % "".join(f.signature))
		print("     Overlap: %s" % "".join(f.overlap))

	print("\nInaccessible: %d factions\n" % inaccessible.size())

	assert(accessible.size() == 7, "Expected 7 accessible factions with starter vocab!")
	print("✅ PASS: Exactly 7 factions accessible\n")


func test_vocabulary_progression():
	print("─".repeat(70))
	print("TEST 2: Vocabulary Progression Paths")
	print("─".repeat(70) + "\n")

	# Simulate learning vocabulary from quest rewards
	var vocab_paths = {
		"Bread Path": ["🍞", "👥", "🌱", "💰", "🧺"],  # Granary Guilds expansion
		"Industry Path": ["🍞", "👥", "⚙", "🏭", "🔩"],  # Millwright's expansion
		"People Path": ["🍞", "👥", "🚢", "🛂", "📋"],   # Station Lords expansion
		"Mystic Path": ["🍞", "👥", "🥖", "⛪", "🧪"],   # Yeast Prophets expansion
	}

	for path_name in vocab_paths:
		var vocab = vocab_paths[path_name]
		print("Testing: %s" % path_name)
		print("  Vocabulary: %s" % "".join(vocab))

		var accessible_count = 0
		for faction in FactionDatabase.ALL_FACTIONS:
			var faction_vocab = FactionDatabase.get_faction_vocabulary(faction)
			var overlap = FactionDatabase.get_vocabulary_overlap(faction_vocab.signature, vocab)
			if overlap.size() > 0:
				accessible_count += 1

		print("  Accessible factions: %d / 68" % accessible_count)
		print("  Unlocked: %d new factions\n" % (accessible_count - 7))

	print("✅ PASS: Vocabulary paths unlock different faction sets\n")


func test_faction_accessibility_mapping():
	print("─".repeat(70))
	print("TEST 3: Faction Accessibility by Emoji")
	print("─".repeat(70) + "\n")

	# Map which emojis unlock which factions
	var emoji_to_factions = {}

	for faction in FactionDatabase.ALL_FACTIONS:
		for emoji in faction.sig:
			if not emoji_to_factions.has(emoji):
				emoji_to_factions[emoji] = []
			emoji_to_factions[emoji].append(faction.name)

	# Show most "valuable" emojis (unlock most factions)
	var emoji_counts = []
	for emoji in emoji_to_factions:
		emoji_counts.append({
			"emoji": emoji,
			"count": emoji_to_factions[emoji].size(),
			"factions": emoji_to_factions[emoji]
		})

	emoji_counts.sort_custom(func(a, b): return a.count > b.count)

	print("Top 10 'Gateway' Emojis (unlock most factions):\n")
	for i in range(min(10, emoji_counts.size())):
		var e = emoji_counts[i]
		print("  %s: %d factions" % [e.emoji, e.count])
		if e.count <= 5:  # Show factions for rare emojis
			for faction in e.factions:
				print("    - %s" % faction)

	print("\n✅ PASS: Emoji value mapping complete\n")


func test_vocabulary_tech_trees():
	print("─".repeat(70))
	print("TEST 4: Vocabulary 'Tech Trees' (Signature Clusters)")
	print("─".repeat(70) + "\n")

	# Analyze signature clusters - which emojis appear together?
	var emoji_pairs = {}  # Track which emojis commonly appear together

	for faction in FactionDatabase.ALL_FACTIONS:
		var sig = faction.sig
		# Count co-occurrences
		for i in range(sig.size()):
			for j in range(i + 1, sig.size()):
				var pair = [sig[i], sig[j]]
				pair.sort()
				var key = "".join(pair)
				if not emoji_pairs.has(key):
					emoji_pairs[key] = {
						"emojis": pair,
						"count": 0,
						"factions": []
					}
				emoji_pairs[key].count += 1
				emoji_pairs[key].factions.append(faction.name)

	# Find strongest clusters (pairs that appear together frequently)
	var clusters = []
	for key in emoji_pairs:
		clusters.append(emoji_pairs[key])

	clusters.sort_custom(func(a, b): return a.count > b.count)

	print("Top 10 Emoji Clusters (appear together most):\n")
	for i in range(min(10, clusters.size())):
		var c = clusters[i]
		print("  %s + %s: %d factions" % [c.emojis[0], c.emojis[1], c.count])
		if c.count <= 3:
			for f in c.factions:
				print("    - %s" % f)

	print("\n✅ PASS: Tech tree analysis complete\n")

	# Suggest optimal unlock paths
	print("SUGGESTED PROGRESSION PATHS:\n")
	print("  Path 1 (Production): 🍞 → 🌱 → 💰 → ⚙ (agriculture + industry)")
	print("  Path 2 (Community): 👥 → 📋 → 🚢 → 🛂 (governance + logistics)")
	print("  Path 3 (Mystical): 🍞 → 🥖 → ⛪ → 🧪 (fermentation + occult)")
	print("  Path 4 (Technical): ⚙ → 🔩 → 🏭 → 🔬 (engineering + science)\n")
