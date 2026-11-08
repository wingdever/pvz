class_name HumanPiece
extends Unit
## [B5] A BRAWL PIECE - the body every faction of that mode shares (BRAWL.md §7: 阵营至少三类，
## 人类是其中之一).
##
## [P110f] THE NAME IS NOW NARROWER THAN THE FILE. The monster faction (激光眼 / 火焰眼 / 眼球塔)
## is fielded through this same class: what separates a monster from a militiaman is its SHEET ROW
## - its numbers, its reach, and which of the five attack shapes it uses - and that is exactly
## the argument this header has always made for one file per faction. Renaming the class and the
## file to BrawlPiece is a `git mv` the user runs (AGENTS.md §2); nothing else would change.
##
## ONE SCRIPT FOR THE WHOLE FACTION, on purpose. A plant file exists because a plant's
## BEHAVIOUR differs (a shooter, a wall, a one-shot); a human piece differs only in its
## NUMBERS, and numbers are what the sheets own (AGENTS.md §2). So this file is the body and
## data/units/humans.csv is the row: HP / attack come from units.csv (the shared columns),
## 费用 / attack距离 / 移速 / attack间隔 from the race sheet (PieceDB). Adding a human piece is
## adding a row - no file, no dispatch table.
##
## HOW THE ID ARRIVES: the body is built and then told what it is (apply_piece), the way a
## zombie is (Zombie.apply_type) and NOT the way a plant is (its id is a const in its own
## file). The brawl's spawn door owns the order - Spawn.create_unit -> Brawl.spawn_human -
## so apply_piece() always runs BEFORE the body is placed, which is what lets
## Unit._load_art() / _load_view() see the paths (they run inside place()).
##
## WHAT IT DELIBERATELY DOES NOT HAVE: no act(), no skills.csv skill code, no garden. The turn
## engine never drives this body (BRAWL.md §12 bans a driven unit from act()), and the brawl asks
## it for its numbers through the doors below.
##
## [B14] IT DOES HAVE AN ULTIMATE NOW - the brawl's own kind. A piece whose row fills an ultimate
## cell (大招持续 = its own beam held long, or [B38] 大招范围 = a leap into the enemy line) banks
## energy with every ordinary blow (BalanceBrawl.ENERGY_*) and spends the whole bar on it; the four
## overrides at the bottom of this file are what makes the SAME bar the turn engine's plants draw
## mean that (see the header of that block).

## The sheet row this body was built from ("" until apply_piece runs).
var piece_id: String = ""

## AP price of one attack, in the turn engine's currency. A human does not act on AP - the
## brawl's actor asks brawl_strike_seconds() instead - but Unit.can_act()-style readers and
## BrawlActor.can_strike() both treat "threshold <= 0" as "this body never attacks", so the
## value has to be a real one. 1 = "it does attack".
const ATTACK_AP := 1


func apply_piece(p_id: String) -> void:
	## Everything this body IS, read from the sheets in one place. Called by Brawl.spawn_human
	## before the body is attached (see the header).
	piece_id = p_id
	is_zombie = false
	body_shape = Shape.CIRCLE
	body_size = BalanceUI.UNIT_BODY_SIZE
	## The flat placeholder shape's colour when no art loads: the piece's own tier, so a
	## roster with no pictures still reads as "these are different champions".
	body_color = Balance.rarity_color(PieceDB.rarity(p_id))
	art_path = PieceDB.art(p_id)
	view_path = PieceDB.view(p_id)
	max_hp = PieceDB.hp(p_id)
	hp = max_hp
	## [B11] 防御 off the shared units.csv row (see UnitSheet.defence): a piece does not level,
	## so this is the sheet's base value and nothing grows it.
	defence = UnitSheet.defence(p_id)
	## [B16] ...and WHICH WAY ITS PICTURE LOOKS, read off the same row (units.csv `face`): a
	## piece drawn facing left (雷角兽) says so there, and the board mirrors it when it stands
	## in a camp its art was not drawn for. The fall-back is the family rule (right).
	faces_left = UnitSheet.face_left(p_id)
	## [B17] the height axis off the same merged row, through Unit's one read (D103/D104).
	read_height(p_id)
	## [P114] the two REAL-TIME traits off the same row (regen/rolling), through Unit's one read: a
	## piece whose sheet row states them rolls / self-heals in the live bout, one that leaves them
	## blank (every human, monster, pokemon, machine, animal today) is byte-for-byte the old body.
	read_realtime(p_id)
	skill_value = PieceDB.attack(p_id)
	threshold = ATTACK_AP
	action_label = "ATTACK"
	action_key = "action.fire"
	set_display_name("piece." + p_id)


# ---------------------------------------------------------------- what the brawl asks for
## THE THREE DOORS BELOW ARE STATIC, and the instances call them. Why it matters: "what would a
## piece of this row actually walk / reach / swing at" is asked TWICE - once by the arena
## (BrawlActor, through the instance) and once by a PAGE that has no piece instance at all
## (the formation page's hover panel). Two answers to that question is exactly the drift this
## project keeps outlawing, so the choosing happens here once and the instance doors are
## one-liners over it.
static func effective_move_speed(p_id: String) -> float:
	## Cells per second. 0 in the sheet = "this row says nothing", and BalanceBrawl's pace
	## answers - the reader never invents a number, it only chooses whose number wins.
	var stated := PieceDB.move_speed(p_id)
	return stated if stated > 0.0 else BalanceBrawl.MOVE_CELLS_PER_SECOND


static func effective_reach(p_id: String) -> float:
	## How far this piece strikes, in cells: 0.75 is "a body fights what it can touch" and
	## 3.0 is a ranged piece. Same fall-back rule as above, and the fall-back is the MELEE
	## one - a row that says nothing is a melee body, which is what most humans are.
	var stated := PieceDB.reach(p_id)
	return stated if stated > 0.0 else BalanceBrawl.MELEE_REACH_CELLS


static func effective_strike_seconds(p_id: String) -> float:
	## Seconds between two attacks at rest. This is where a human's rhythm comes from - the
	## turn engine derives a plant's from 技能消耗AP x ROUND_SECONDS and has no opinion about
	## a human. 0 = the row said nothing -> BalanceBrawl.DEFAULT_STRIKE_SECONDS.
	var stated := PieceDB.strike_seconds(p_id)
	return stated if stated > 0.0 else BalanceBrawl.DEFAULT_STRIKE_SECONDS


static func effective_shot(p_id: String) -> String:
	## [B7+] WHICH PROJECTILE THIS ROW FIRES, or "" for a body that fights what it can touch.
	## No fall-back number to choose here: the cell is a shot id or it is nothing, and
	## "nothing" is the answer for four of the six pieces - a ranged piece is ranged because
	## its row says so, not because its attack距离 is long (the captain reaches 1.1 cells and
	## swings, the archer reaches 3.0 and looses an arrow).
	return PieceDB.shot(p_id)


static func effective_melee_fx(p_id: String) -> String:
	## [P110e] WHICH PICTURE THIS ROW'S MELEE BLOW LEAVES, or "" for the generic spark. The
	## same shape as effective_shot() above, for the other half of the roster: no fall-back
	## number to choose, because the cell either names a drawing or names nothing - and
	## "nothing" is the answer for three of the six pieces today.
	return PieceDB.melee_fx(p_id)


static func effective_ranged_fx(p_id: String) -> String:
	## [P110f] WHICH BEAM THIS ROW ATTACKS WITH, or "" for the other two shapes. The same shape
	## as effective_shot / effective_melee_fx: the cell names a beam or it names nothing, and the
	## three of them are read in that order by BrawlActor.
	return PieceDB.ranged_fx(p_id)


func brawl_move_speed() -> float:
	return effective_move_speed(piece_id)


func brawl_attack_reach() -> float:
	return effective_reach(piece_id)


func brawl_strike_seconds() -> float:
	return effective_strike_seconds(piece_id)


func brawl_shot_id() -> String:
	## [B7+] The fourth door, and the one BrawlActor asks before every blow: "" means this body
	## lands its hit itself (melee), anything else means it hands the blow to a projectile.
	## Named brawl_shot_id and not shot_id because ShooterPlant already owns that name for the
	## TURN engine's shot, and one name must not mean two things on one body.
	return effective_shot(piece_id)


func melee_fx_id() -> String:
	## [P110e] The fifth door, and the twin of the fourth one: a piece whose 射弹 cell is blank
	## lands its blow itself, and THIS is the picture that blow leaves (民兵 slash / 骑士
	## slash_heavy / 队长 slash_divine). "" = no picture of its own, and the arena draws the
	## generic spark.
	##
	## Deliberately NOT called brawl_melee_fx_id like its four neighbours: the turn engine asks
	## the same question of a zombie (Zombie.act's BITE), so the name belongs to the body rather
	## than to one mode - see Unit.melee_fx_id.
	return effective_melee_fx(piece_id)


static func effective_beam_seconds(p_id: String) -> float:
	## [P110g] HOW LONG THIS ROW'S BEAM BURNS, in seconds; 0.0 = it lands once. The cell decides
	## whether 连续冲击光束 is a channel or a flash - the laser eye's row leaves it blank and the
	## eye tower's says 3.
	return PieceDB.beam_seconds(p_id)


static func effective_ult_seconds(p_id: String) -> float:
	## [B14] HOW LONG THIS ROW'S ULTIMATE HOLDS, in seconds; 0.0 = this row has none, which is
	## every row but 雷角兽 today. It has a static twin for the reason the four above it do: "what
	## does this row's sheet say" is a question a PAGE can ask without a piece instance (the
	## formation page's hover panel already reads three of these), and leaving one of the five
	## without a twin is how the next reader ends up writing a second answer.
	return PieceDB.ult_seconds(p_id)


func ranged_fx_id() -> String:
	## [P110f] The sixth door: the BEAM this piece attacks with (the monsters' three - 瞬发光束 /
	## 喷射火焰 / 连续冲击光束). BrawlActor asks it BEFORE it decides how the blow lands, because
	## the answer changes the shape of the attack itself: a body that names a beam hits on the
	## frame it strikes and never sends anything across the board.
	return effective_ranged_fx(piece_id)


func brawl_beam_seconds() -> float:
	## [P110g] The seventh door, and the one that tells the two RANGED shapes apart: a beam that
	## flashes (0.0) or a beam that BURNS. BrawlActor asks it right after ranged_fx_id, and a
	## positive answer hands the rest of the attack to the arena (brawl_beam.gd).
	return effective_beam_seconds(piece_id)


func brawl_knockback_cells() -> int:
	## [B9] The eighth door: HOW MANY CELLS THIS PIECE'S BLOW THROWS ITS VICTIM, or 0 for a body
	## whose blows only damage. Asked by BrawlActor AFTER the damage of every landed blow has been
	## settled (land_hit), so "a shieldman's bash throws you back" is one sheet cell and no branch
	## in the arena - the same shape 射弹 / 近战特效 / 远程特效 already have.
	##
	## DELIBERATELY NO STATIC TWIN beside effective_* above: those exist to CHOOSE between the
	## sheet and a fall-back number, and there is nothing to choose here - a blank cell is not
	## "the sheet said nothing", it is the answer ("this row does not push"). BalanceBrawl owns
	## only the PACE of a shove, never whether one happens.
	return PieceDB.knockback(piece_id)


func brawl_gulp_seconds() -> float:
	## [B10] The ninth door: HOW LONG THIS PIECE DIGESTS WHAT IT SWALLOWS, or 0.0 for a body that
	## merely hits. The fourth ATTACK SHAPE, read off the sheet the same way the other three are
	## (射弹 / 远程特效 / 吞噬 / 近战), so "make this piece a devourer" is one cell in
	## data/units/<faction>.csv and no branch in the arena.
	##
	## Unlike the seven doors above it is NOT a rider on a blow: a positive cell REPLACES the
	## blow. 绿史莱姆 does no damage on contact - it takes the enemy inside and pays the damage
	## out while it digests (BrawlActor._begin_strike's fourth shape -> Brawl.swallow).
	return PieceDB.gulp_seconds(piece_id)


func brawl_ult_seconds() -> float:
	## [B14] The tenth door: HOW LONG THIS PIECE'S ULTIMATE HOLDS, or 0.0 for a body whose blows
	## are the whole of it. Asked by BrawlActor on the frame the energy bar fills up: what the
	## ultimate IS (a beam, held this many seconds) is the row's, while what it COSTS is one rule
	## for the whole mode (BalanceBrawl.ENERGY_*).
	##
	## It is a duration and not a flag for the same reason 持续 and 吞噬 are: "3 seconds" and "5
	## seconds" are two rows of one rule rather than two code paths, and a piece whose ultimate
	## should hit harder says so by holding it longer.
	return effective_ult_seconds(piece_id)


func brawl_ult_radius() -> float:
	## [B38] The eleventh door: HOW MANY CELLS THIS PIECE'S ULTIMATE SLAMS, or 0.0 for a body whose
	## full bar holds its own beam (the [B14] reading above) rather than jumping. A POSITIVE answer
	## REPLACES that reading - this row's ultimate is the leap, and the leap's own three numbers (the
	## crouch, the pace, the arc) are the mode's rule (BalanceBrawl.LEAP_*), while how wide its
	## landing is and how far it throws are this row's (data/units/pokemon.csv 大招范围 / 大招震飞).
	##
	## No static twin beside the effective_* above, for the reason brawl_knockback_cells() gives: a
	## blank cell here is not "the sheet said nothing", it is the answer ("this row does not jump").
	return PieceDB.ult_radius(piece_id)


func brawl_ult_knock_cells() -> int:
	## [B38] The twelfth door: HOW MANY CELLS THE SLAM THROWS every body it lands on, or 0 for a slam
	## that only damages. This is the 震飞 half of 卡比兽's jump, and it is a second distance rather
	## than the 击退 cell above because the two sentences differ - "my bump pushes you" against "the
	## ground I land on throws everybody near it".
	return PieceDB.ult_knock(piece_id)


func brawl_tornado_cells() -> float:
	## [B39] The thirteenth door: HOW MANY CELLS THE WHIRLWIND THIS PIECE SUMMONS WALKS, or 0.0 for
	## a body that does not call one up. The FIFTH attack shape's number, and a positive cell REPLACES
	## the blow rather than riding on it - like 吞噬 above, the bird's strike IS the storm.
	##
	## [B41] The funnel is summoned IN FRONT of this body, along its own facing, and the arena is given
	## no target - so this is a distance walked, not a range fired.
	##
	## No static twin beside the effective_* above, for the reason brawl_knockback_cells() gives: a
	## blank cell here is not "the sheet said nothing", it is the answer ("this row does not storm").
	## How fast the funnel walks, how wide it is, how often it pulses and what a pulse is worth are
	## all one rule for every whirlwind (BalanceBrawl.TORNADO_*); how FAR this bird's goes is the
	## row's (data/units/animals.csv 旋风).
	return PieceDB.tornado_cells(piece_id)


func brawl_ult_knockback_cells() -> int:
	## [W12c] The fourteenth door: HOW MANY CELLS THIS PIECE'S ULTIMATE PUSHES EVERYBODY IT RINGS
	## OUT, or 0 for a row whose full bar is a beam or a leap rather than a shove. This is the
	## 盾卫's 盾墙冲击: the slam ring opens at its own feet and the enemies standing near it slide
	## one cell away - damage ZERO, because what this body sells is the wall, not the blow.
	##
	## A second push distance next to brawl_knockback_cells() and brawl_ult_knock_cells() for the
	## same reason those two are three: "my bump pushes you", "the ground I land on throws them",
	## and "my full bar shoves the ring around me" are three different sentences.
	##
	## No static twin, per the brawl_knockback_cells() rule: a blank cell is the answer.
	return PieceDB.ult_push(piece_id)


func brawl_energy_per_hit() -> int:
	## [W12c] The fifteenth door: HOW MUCH ENERGY THIS PIECE BANKS ON EVERY BLOW IT TAKES, or 0 for
	## a row that charges only on its own strikes and from the passive trickle. The 盾卫's column:
	## a wall earns its ultimate by being hit, so 受击积攒 25 makes standing in the line the fastest
	## way to fill it - and it is a SHEET CELL rather than an archetype rule so any future tank can
	## price the same idea without a code path.
	##
	## The door is on the VICTIM, and BrawlActor.land_hit asks it after the damage settles: asking
	## the attacker instead would make every piece fund the shieldman's bar, which is a different
	## (and much louder) game.
	return PieceDB.hit_charge(piece_id)


## [B16] NO drawn_left() HERE ANY MORE. [B14] made it the eleventh door, reading a 朝向 column
## of this faction's sheet; the mechanism moved to the BASE UNIT and to units.csv (`face`), so
## this body answers like every other one - `faces_left`, filled by apply_piece above from the
## same shared row its HP and defence come from. Two owners for one fact is what that move was
## for; a piece that needs a fourth door will find one fewer to copy. ([B38] did take that freed
## number for 大招范围, so the count above is continuous again.)


# ---------------------------------------------------------------- the energy bar [B14]
## THE BAR IS THE ULTIMATE BAR, AND IT IS ALREADY DRAWN. Unit has one bar slot under the hp bar
## (has_ultimate / ult_charge / ult_bar_ratio / _draw_ult_bar) and it means "this body is
## charging something big" in both modes - so the brawl does not draw a second bar of its own,
## it answers the four questions that bar asks with the BRAWL's rule:
##
##   who has one     any of the three ultimate cells of the row: 大招持续 (a beam, held),
##                   大招范围 (a leap) or 大招击退 (a shove-ring) - a row that fills NONE of them
##                   has no ultimate and draws no bar, which is also the base's answer for every
##                   piece that leaves all three cells blank
##   how full is it  BalanceBrawl.ENERGY_MAX, filled ENERGY_PER_STRIKE at a time by BrawlActor
##   what does it say "%d/%d" - a brawl piece has no skills.csv ult row for the base's
##                   "<name> x/y" wording, and the name it does have (the 技能 cell) is its
##                   ordinary attack, which would be a lie on this bar
##
## ult_charge is therefore this piece's ENERGY, and nothing of the turn engine is involved:
## ult_code stays empty, no turn-engine code ever holds one of these bodies (BRAWL.md §12), and
## the engine's own charge events (a cast, a hit taken) cannot reach it - ult_charge_source()
## answers "", so take_damage() banks nothing on a hit.
func has_ultimate() -> bool:
	## [B14] Overridden because a brawl piece's ultimate is a SHEET CELL and not a skills.csv code
	## (the base asks ult_code != "" and ult_implemented(); this body has neither, on purpose).
	## [B38] There are now TWO cells that say "this row has one": 大招持续 (its own beam, held) and
	## 大招范围 (a leap into the enemy line). Either one draws the bar and banks energy; a row that
	## fills neither has no ultimate and no bar, exactly as before.
	## [W12c] A THIRD cell joins them: 大招击退 (the shove-ring 盾卫 opens at full bar). The same
	## two-line rule covers it - any one of the three draws the bar, a row that fills none has
	## neither an ultimate nor a bar, which is why no other human's row changed when this appeared.
	return brawl_ult_seconds() > 0.0 or brawl_ult_radius() > 0.0 \
		or brawl_ult_knockback_cells() > 0


func ult_charge_cap() -> int:
	## [B14] How full the bar has to get: one rule for every ultimate in the mode
	## (BalanceBrawl.ENERGY_MAX), exactly as BalanceBattle.ULT_CHARGE_MAX is one rule for every
	## plant's. The day a row prices its own, this is the single function to extend.
	return BalanceBrawl.ENERGY_MAX


func ult_bar_text() -> String:
	## [B14] Just the numbers: the base's "<大招名> x/y" has no name to print here (see the block
	## above), and a 64 px bar cannot carry the word ULTIMATE plus two numbers anyway.
	return "%d/%d" % [ult_charge, ult_charge_cap()]


func ult_shout_text() -> String:
	## [P112] The ultimate's shout-name, read off the SHARED 大招 column on units.csv (the base's
	## ult_name_text would fall through to a generic "大招" for a piece, because a brawl ultimate is
	## a sheet cell and not a skills.csv code - see the block above). A row that left the cell blank
	## answers "", and Unit.shout() refuses an empty text rather than drawing a blank balloon.
	return PieceDB.text(piece_id, "ultimate")


func skill_shout_text() -> String:
	## [P112] The signature skill's shout-name (the devour, the whirlwind), straight off the row's
	## 技能 column. The base says nothing because a turn-mode act() is an ordinary blow; only the
	## real-time engine calls this, and only for the two shapes that REPLACE the blow.
	return PieceDB.text(piece_id, "skill")
