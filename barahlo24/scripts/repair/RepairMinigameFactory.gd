class_name RepairMinigameFactory
extends RefCounted
## RepairMinigameFactory — создаёт нужный Control-скрипт мини-игры ремонта
## по строковому идентификатору из defects.json ("screwdriver", "part_swap",
## "cleaning", "soldering"). Все мини-игры лёгкие: простая геометрия 2D-UI,
## без тяжёлых вычислений, с сигналом finished(quality: float).

static func create(minigame_type: String) -> Control:
	match minigame_type:
		"screwdriver":
			return ScrewdriverMinigame.new()
		"part_swap":
			return PartSwapMinigame.new()
		"cleaning":
			return CleaningMinigame.new()
		"soldering":
			return SolderingMinigame.new()
		_:
			return ScrewdriverMinigame.new()
