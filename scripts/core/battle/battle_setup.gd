extends RefCounted
class_name BattleSetup
## [P106] EVERYTHING ONE BATTLE NEEDS, IN ONE OBJECT.
##
## Game fills this in _start_new_game() and Battle reads it in begin(). One symbol instead of nine
## parameters, and a tenth input never changes a signature.
##
## PLAIN DATA - plus exactly two READ-ONLY domain references (the summon pool and the backpack the
## player is carrying). There is no service here, and in particular no GameManager: this file is
## where the boundary is written down, so nothing in it may point back at Game.

var level: LevelData = null            # waves, rows, starting plants, brain hp, cards
var level_path: String = ""
var garden: Garden = null              # READ-ONLY for the battle: who may be summoned
var profile: Profile = null            # the carried backpack; in-battle ledgers only
var deck: Array[String] = []           # the cards this board plays with (battle_cards order)
var zombie_hp_mult: float = 1.0        # the difficulty (and the run's mods) already folded in
var sun_start: int = 0
var sun_per_turn: int = 0
var sunflower_sun: int = 0
var run_battle: bool = false           # a campaign node's battle, not a free level
## [P31-A] The garden slots a campaign battle may summon (empty = a free level: any of them).
## The board gets the LIST, never the RunState - that is the boundary.
var squad: Array[int] = []