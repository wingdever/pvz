class_name LocGarden
extends RefCounted
## [P20] Messages produced by the persistent GARDEN roster itself
## (scripts/core/garden.gd). They are separate from LocMsgs because they belong to
## the roster, not to the battle: garden.water() / fertilize() / apply_talent()
## return {ok, message} and the GARDEN page shows that message verbatim.
##
## Keys use the "roster." prefix. "%%" is a literal percent sign; both variants
## must keep the same %-specifiers in the same order (Loc.self_check enforces it).

const TABLE := {
	# ------------------------------------------------------------ water / fertilize
	"roster.no_plant": {"zh": "第 %d 号花圃没有植物", "en": "There is no plant in slot %d"},
	"roster.water.downed": {
		"zh": "这株植物已濒死——要用肥料，浇水没用",
		"en": "That plant is DOWNED - it needs FERTILIZER, not water",
	},
	"roster.water.full": {"zh": "生命值已满（%d/%d）", "en": "Already at full health (%d/%d)"},
	"roster.water.ok": {
		"zh": "给 %s 第 %d 号花圃浇水：生命 %d -> %d",
		"en": "Watered %s slot %d: %d -> %d hp",
	},
	"roster.fertilize.healthy": {
		"zh": "这株植物没有濒死——用肥料会浪费",
		"en": "That plant is not DOWNED - fertilizer would be wasted",
	},
	"roster.fertilize.ok": {
		"zh": "给 %s 第 %d 号花圃施肥：濒死解除，生命 0 -> %d",
		"en": "Fertilized %s slot %d: DOWNED cured, hp 0 -> %d",
	},

	# ------------------------------------------------------------ talent potion
	"roster.talent.wrong_type": {
		"zh": "%s 用不了 %s",
		"en": "%s cannot take %s",
	},
	"roster.talent.already": {
		"zh": "%s 已经有这个天赋了——不会叠加",
		"en": "%s already has this talent - it does not stack",
	},
	"roster.talent.ok": {
		"zh": "%s 第 %d 号花圃使用了 %s：%s",
		"en": "%s slot %d took %s: %s",
	},

	# ------------------------------------------------------------ natural recovery
	"roster.recover.self": {
		"zh": "%s 第 %d 号花圃自行恢复 -> 生命 %d/%d",
		"en": "%s slot %d recovered on its own -> %d/%d hp",
	},
}
