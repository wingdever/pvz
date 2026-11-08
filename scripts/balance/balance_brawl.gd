class_name BalanceBrawl
extends RefCounted
## [B1] The BRAWL's half of Balance - the numbers that ONLY the real-time mode reads.
##
## WHO READS THIS FILE: scripts/core/brawl/** and nothing else. The rule that gave
## BalanceBattle / BalanceGarden / BalanceRun / BalanceShop their own files (P108) is the
## rule here too - a scene's own constants live with that scene. Nothing in balance.gd
## reads this file, and this file reads NO other table; a table reading a table is the one
## direction P108 forbids, which is why AP_BUDGET is spelled out below instead of reaching
## into BalanceBattle.ROUND_AP. The two hold the same number today and are allowed to
## drift, because a brawl "round" is a LENGTH OF TIME and the turn engine's round is a pile
## of phases.
##
## THE BRIDGE (docs/prompt/BRAWL.md §5): the turn engine hands every unit 3 AP per round.
## The brawl hands out the same 3 AP spread over ROUND_SECONDS, so a sheet number like the
## peashooter's 技能消耗AP=1 keeps meaning "this plant fires three times a round" and no
## table in data/ has to learn a second currency. What changes is WHO decides when.

# ---------------------------------------------------------------- the clock
## Logic steps per second. The picture runs at the display's rate; the SIMULATION runs at
## this one, so a bout is reproducible and a headless run can drive it faster than the
## screen shows it. 30 Hz is the first pass: GDScript, up to 40 pieces, one bucket each.
const TICK_HZ := 30
## A frame that arrives late (a debugger pause, a window drag) must not turn into a burst
## of catch-up steps. Past this many, the debt is DROPPED instead of paid.
const MAX_STEPS_PER_FRAME := 5
## What one round of the turn engine is worth here, in seconds.
const ROUND_SECONDS := 2.5
## The AP budget a round carries in the turn engine (BalanceBattle.ROUND_AP). Named apart
## on purpose: two number tables may not share a constant name ([Arch] rule 4).
const AP_BUDGET := 3
## The spectator's ladder (SPACE pauses, F cycles this).
const SPEED_CHOICES: Array[float] = [1.0, 2.0, 4.0]


static func ap_rate() -> float:
	## Action points per second of SIMULATED time - the bridge between the two clocks.
	return float(AP_BUDGET) / ROUND_SECONDS


# ---------------------------------------------------------------- the arena [D11]
## The board is the turn engine's 9 x 5 (Balance.COLS / ROWS / CELL_SIZE) because O4 asked
## for reuse; the partition below is what makes that fit. Four columns a side, one column
## of no man's land, and 4 x 5 = 20 cells a half - which is exactly MAX_PIECES_PER_SIDE,
## so every piece gets a slot (BRAWL.md §2.2).
const HALF_COLS := 4
const GAP_COLS := 1
const MAX_PIECES_PER_SIDE := 20

# ---------------------------------------------------------------- the pieces
## How big a piece is, in cells. Pieces PUSH each other apart and never BLOCK: hard
## blocking deadlocks a real-time arena (D14 / D31).
const BODY_RADIUS_CELLS := 0.4
## The push's reach in body radii, and how hard it is (cells per second).
const SEPARATION_RANGE := 2.6
const SEPARATION_STRENGTH := 1.2
## Movement in cells per second. The turn engine's plain zombie walks 移动=3 rounds a cell
## - 7.5 s here - and an arena bout wants a readable skirmish, so the brawl has its own
## pace. [B2] the piece sheet owns a per-piece speed and this becomes its fall-back.
const MOVE_CELLS_PER_SECOND := 0.75
## [P114] HOW FAST A ROLLING BODY TURNS: radians of spin per cell of ground it walks, applied by
## BrawlActor._advance_roll to the pieces whose sheet row says 滚动 (today the wallnut alone). It is a
## RULE of the live bout (the reader is the walk, not the draw code), so it lives here beside the pace
## it multiplies rather than in BalanceUI. Larger = the wheel spins more turns per cell and the roll
## reads faster; 2.2 rad/cell is a readable starting spin at MOVE_CELLS_PER_SECOND, tunable after play.
const ROLL_RADIANS_PER_CELL := 2.2
## Attack reach in cells: a body fights what it can touch, a plant shoots without lanes.
## [B2] the piece sheet owns attack距离 and these become the fall-backs.
const MELEE_REACH_CELLS := 0.75
const RANGED_REACH_CELLS := 3.0
## The AP one attack costs when the piece's own row says nothing. The turn engine prices a
## bite at 1 AP; a plant's price is its sheet's 技能消耗AP, which the actor reads instead.
const DEFAULT_ATTACK_AP := 1.0

# ---------------------------------------------------------------- the shove (击退) [B9]
## HOW FAST A SHOVED BODY TRAVELS while a blow is knocking it back, in CELLS per second. The
## DISTANCE is never a number here - it is the row's own 击退 cell, because "this piece throws
## what it hits one cell back" is part of what the piece IS (AGENTS.md §2: a unit's own numbers
## live in its sheet). This one only decides how long that cell takes to travel: 1 cell at 6 is
## five ticks of TICK_HZ, which is the slowest slide that still reads as a violent push rather
## than as a body walking backwards on purpose (a piece walks at 0.6-0.9 cells a second, a shot
## flies at 9). Reach for THIS number when a bash looks like a teleport; reach for the sheet when
## the bash is not strong enough.
const SHOVE_CELLS_PER_SECOND := 6.0

# ---------------------------------------------------------------- the devour (吞噬) [B10]
## WHAT A SECOND INSIDE A BELLY IS WORTH. 绿史莱姆 (and any row whose 吞噬 cell is filled) does not
## damage what it touches: it takes the enemy INSIDE and pays the damage out while it digests,
## one blow every GULP_TICK_SECONDS - the same cadence-not-a-table shape the channelled beam uses
## (BEAM_TICK_* above), and the same reason: every tick goes through the devourer's own land_hit(),
## so the rage, the attachments and the prey's own books keep their one owner (BRAWL.md §12).
##
## HOW LONG it holds its prey is the SHEET's (monsters.csv 吞噬 = seconds, 绿史莱姆 2.0 since
## [W12b]) and deliberately not here: that is what the piece IS. These are the global rules, and
## they are the numbers to reach for when a slime is too strong or too weak:
##   the 2-second window pays FOUR half-second bites (see BrawlGulp.tick's order), and at
##   GULP_TICK_SHARE 3.5 a 26-attack slime bites for 91: 4 × 91 = 364 - enough to eat a militia
##   (320 HP, 16 防御 = full damage) whole and NOT enough for a shieldman (800 HP, its wall
##   trims each bite to 61 - 244 across the window), which is the point: whoever survives being
##   spat back out is a counter to it, and since [W12b] the failed meal costs the devourer a
##   minute of daze (STUN_FAILED_DEVOUR_SECONDS below). The share was 1.0 for the OLD six-second
##   digestion (twelve ordinary-strength bites, same total); [W12b] kept the meal and moved the
##   money into fewer, heavier bites, because the user's window is two seconds.
##   GULP_LAND_TOLERANCE_CELLS: the pounce ([W12b]) locks its mark at take-off and the flight
##   lasts a wind-up plus a hop, during which the prey keeps walking (≈0.65 cells a second); if
##   it has drifted further than a cell when the slime lands, the hop clearly missed and the
##   blow falls back to an ordinary hit - "a devourer that cannot eat still hits".
const GULP_TICK_SECONDS := 0.5
const GULP_TICK_SHARE := 3.5
const GULP_LAND_TOLERANCE_CELLS := 1.0

# ---------------------------------------------------------------- the stun (眩晕) [W12]
## WHAT BEING DAZED COSTS. The stun itself is a rule of the MODE (BrawlActor carries the branch,
## BRAWL.md §8.14 in prose), and so is its price list: how long the first daze in this mode runs
## is HERE, not on the slime's row - the day a second devourer (or a stun-blow) shows up, it pays
## the same indigestion, and a future dazing piece adds its own cell only if its daze differs.
## The victim of a failed devour needs no entry: it is spat out whole and back to its driver.
const STUN_FAILED_DEVOUR_SECONDS := 1.0

# ---------------------------------------------------------------- the leap (蓄力跳跃) [B38]
## HOW A JUMPING ULTIMATE MOVES. The two numbers a row owns are NOT here: the slam's RADIUS is
## the row's 大招范围 and how far it throws bodies is its 大招震飞 (data/units/<faction>.csv), because
## "how big is this piece's slam" is part of what the piece IS (AGENTS.md §2, the same split the
## 击退 / 吞噬 cells already use). What lives below is the SHAPE every leap shares - the rule, not
## the piece - and they are the numbers to reach for when a jump reads as a teleport or as a crawl:
##   WINDUP is the crouch the eye sees before the body leaves the ground (蓄力); at 30 Hz it is
##   eighteen ticks. The first batch had fourteen and the user's read was that the jump was not
##   visible enough - which is a statement about the WINDUP, since the flight was already a third of
##   a second: a charge the eye has not finished registering makes whatever follows it a blink. Long
##   enough to be a wind-up, still short enough never to look stuck.
##   PACE is how fast the jump crosses the GROUND, in cells per second - between a shove (6) and a
##   walk (0.75), because a body flying over a scrum should read as thrown, not as walking a curve.
##   Slowed once for the same reason as the wind-up: at 4.5 a 3-cell leap spent 0.67 s in the air and
##   the arc was over before it could be followed.
##   APEX is the arc's height as a SHARE of the span it covers, and that single shape is what buys
##   the launch angle at every range: LOB_APEX_SHARE (B18) made the same argument for an arrow.
##   It is the number that decides whether a leap is SEEN as a leap, because the air is measured by
##   the ground: the shadow shrinks and dims per cell of z (BRAWL_SHADOW_FALLOFF), so a low arc is a
##   body sliding sideways and a high one is a body that came down. Raising it is safe now that
##   BrawlActor._finish_leap puts the feet back on the ground BEFORE it measures its circle - the
##   slam's damage never depended on the arc, and only had to not be disturbed by it.
##   MAX is how far a leap may reach, in cells - HALF_COLS minus one. A piece that could jump the
##   whole arena would pick its own landing out of the far corner and the arena's partition (D11)
##   would stop meaning anything; 3 cells means it hops INTO the line it is fighting, no further.
const LEAP_WINDUP_SECONDS := 0.55
const LEAP_CELLS_PER_SECOND := 4.0
const LEAP_APEX_SHARE := 0.55
const LEAP_MAX_CELLS := 3.0

# ---------------------------------------------------------------- the whirlwind (旋风) [B39]
## WHAT A TRAVELLING WHIRLWIND IS WORTH AND HOW IT MOVES. The distance it walks is NOT here: it is
## the row's own 旋风 cell (data/units/<faction>.csv), because "how far does this bird's tornado go"
## is part of what the piece IS - the same split 击退 / 吞噬 / 大招范围 already use. What lives below
## is the shape every whirlwind shares:
##   PACE, in cells per second. A shot flies at 9 and a body walks at 0.6-0.9; a whirlwind sits far
##   closer to the walk because it is the one summoned thing the player is meant to WATCH and step
##   out of - a wall of air that crossed the arena in a third of a second would be a second shotgun
##   and not a weather front. Slow is also what makes the OTHER half of the number legible: a body
##   caught inside pays every TICK, so the pulse has to be seen as pulses.
##   [B41] 2.2 → 1.4 (用户: "降低旋风移速"). The front was crossing a body's own width in about a
##   third of a second, which is less time than the eye needs to read the thing as a weather front at
##   all - and at 30 Hz the whole walk of a 5-cell storm was 81 steps of picture. What the slower
##   number is worth is spelled out under TICK below, because it is NOT free: the same SHARE now pays
##   more per body.
##   REACH is the funnel's own radius in cells; a body is touched at REACH + BODY_RADIUS_CELLS (0.4),
##   so 0.8 means anything whose edge comes within a little over one cell of the funnel's centre -
##   roughly the width of two bodies standing side by side. THE PICTURE IS THIS RADIUS (BalanceUI
##   draws the lowest band at exactly REACH), for the B20 reason: the circle the eye watches eat
##   people is the circle the damage was paid inside.
##   TICK / SHARE are the contact cadence, and they are the gulp's and the channel's shape again: every
##   blow goes through the SUMMONER's own land_hit(), so a whirlwind is a cadence and never a second
##   damage table (BRAWL.md §12). The first tick comes one full period after summoning (BrawlGulp's
##   rule), which makes the payout exactly countable. At [B41]'s 1.4 cells a second the bird's own
##   5.0-cell row lives 3.57 s and pays SEVEN ticks; a body it walks straight over is inside REACH +
##   BODY_RADIUS (1.2 cells) on both sides, so 2.4 cells of walk = 1.71 s = THREE ticks = 1.05 of the
##   bird's blow (~42 点, against its 40). THAT IS A BUFF and it is stated rather than hidden: the old
##   2.2 pace walked the same body in 1.09 s and paid two ticks (0.7 of a blow, ~28 点). The knob that
##   buys the legibility back down to the old payout is TORNADO_TICK_SHARE (0.25 instead of 0.35 puts
##   three ticks back at seven-tenths of a blow); the row's own 旋风 cell is the one that buys WIDER
##   coverage instead. Weak against one body either way, strong against a LINE, which is what a
##   whirlwind is for.
##   HEIGHT is the column of air it actually occupies, and that is what the height axis is FOR here
##   (docs/prompt/HEIGHT.md §3): the sweep asks z_hits like every other blow, so a body standing on the
##   ground is hit inside 0..2.2 cells and a body that has jumped over the funnel (LEAP_APEX puts a
##   3-cell jump's feet above ~1.65) is hit too, while one high enough to clear the column walks the
##   bout through untouched. A column of 0 would have made this thing melee-only.
##   SIZE_TIER [B40] is where "旋风 is a BIG projectile" is said, in the same word the shot sheet
##   writes (data/projectiles.csv 体型): 大 = 1.5×, and this is the one non-sheet caller because the
##   whirlwind is deliberately NOT a projectiles.csv row (its 轨迹 would lie for one of the two
##   engines - see scripts/core/brawl/brawl_tornado.gd). WHAT THE TIER SCALES is height and nothing
##   else: the column becomes 2.2 × 1.5 ≈ 3.3 cells of air, and with it the picture's mass (bands,
##   strokes, debris, how far the top sways). WHAT IT DOES NOT SCALE is the floor radius, because
##   BalanceUI draws the lowest band at exactly REACH and REACH is where the pulse was paid - a tier
##   that widened the ring would make the prettiest circle on the board a lie about reach (B20, and
##   the sentence above). The day a WIDER storm is wanted, the number to change is this table's
##   TORNADO_REACH_CELLS, and the paint follows it for free.
## NOTE the word: TORNADO and not STORM - `*_storm` is already the TURN engine's id for a plant's
## ultimate skill (data/units/skills.csv 豌豆风暴 / 弹幕 / 尖刺风暴), and one name must not mean two
## things in one project. The Chinese is 旋风 in both directions.
const TORNADO_CELLS_PER_SECOND := 1.4
const TORNADO_REACH_CELLS := 0.8
const TORNADO_TICK_SECONDS := 0.5
const TORNADO_TICK_SHARE := 0.35
const TORNADO_HEIGHT_CELLS := 2.2
## [B40] The magnitude word, and the ONLY number the whirlwind's bigness is decided by - the ladder and
## the ratio it means are Balance's (SIZE_TIERS), so 大 is 1.5× here, on 暖阳's row, and nowhere else.
const TORNADO_SIZE_TIER := Balance.SIZE_LARGE

# ---------------------------------------------------------------- the shots [B7+]
## WHAT A SHOT DOES WHEN ITS ROW SAYS NOTHING. The shot's own row (data/projectiles.csv) owns
## the look, the two cues and the flight shape; its 速度 column is written in the TURN ENGINE's
## pixels, and a row that leaves the cell blank means "the default for this trajectory" - which
## the brawl does not have, because BalanceUI.PEA_SPEED is a pea's speed and not an arrow's.
## So a row that states nothing gets the pace below, and a row that states one is converted by
## the flight itself (BrawlShot.speed_cells: px / Balance.CELL_SIZE). In CELLS per second,
## because that is the only unit the arena has (BrawlActor.pos is a float cell).
const SHOT_CELLS_PER_SECOND := 9.0
## A shot lands when it is this close to the point it is flying at. The flight ALSO lands when
## the distance left is smaller than the step it is about to take (see BrawlShot.tick), so a
## fast ball cannot tunnel through a body between two 30 Hz steps - this number is the floor.
const SHOT_HIT_RADIUS_CELLS := 0.35
## How fat a shot is, for the swept collision: the segment a step covers is tested against every
## enemy body widened by BODY_RADIUS_CELLS + this. Small on purpose - a shot should hit what it
## visibly flies through and nothing beside it.
const SHOT_BODY_RADIUS_CELLS := 0.16
## The impact burst, in seconds. Long enough to be SEEN at 30 Hz (two frames is a flicker) and
## short enough that four shots a second do not pile flashes on top of each other.
const SHOT_FLASH_SECONDS := 0.16
## [B20] HOW LONG A BLAST BURNS, on top of the ordinary hit flash above. A graze says "something
## landed"; a shell says "an AREA just died", and that message needs time to be read - the
## shockwave alone travels from the core out to the 溅射半径, which a 0.16 s ring could never
## show without turning into a blink. Only a row that STATES 溅射半径 gets this length.
const BLAST_FLASH_SECONDS := 0.5
## The safety net: a shot that has flown this long is over, wherever it is. It exists for the
## two ways a flight can fail to arrive - a target that left the arena, and a sheet typo that
## gave the row a speed of 0 - and it is deliberately far above any real flight (the widest
## shot crosses nine cells in well under a second).
const SHOT_MAX_SECONDS := 4.0

# ---------------------------------------------------------------- the height axis [B17]
## WHAT A SHOT FLIES AT WHEN ITS ROW SAYS NOTHING, all in CELLS (docs/prompt/HEIGHT.md §5,
## D96: the lift is no longer decoration - the shot's z interval is the second gate on every
## hit path). The authored 128 that appears below is the ART DESIGN BASELINE used to derive
## these from old pixel values, never the live BrawlField.cell() (D100 revised: that stays
## dynamic, and cells convert to pixels only at the draw).
## Cruising height of a straight / homing shot, chest-high: its interval [0.45, 0.70] meets a
## grounded body and clears anything that will one day float high. ⚠ SINCE [B37] D113 the body's
## reach is its MEASURED INK, not a guaranteed cell: a body whose art paints less than ~0.45 of a
## box is now flown OVER, and no number here catches it. The roster has never been measured on this
## axis (the floor made the question moot), so the first acceptance run after D113 is where "every
## ground unit eats every flat shot" gets looked at. If a body turns out genuinely LOW there are
## two honest answers, both in its ROW: state `z_thickness`, or state `z_height` on the shot.
const SHOT_Z_CELLS := 0.45
## The shot's own thickness on the axis - small on purpose, the same discipline as
## SHOT_BODY_RADIUS_CELLS: it should hit what it visibly flies through.
const SHOT_Z_THICKNESS_CELLS := 0.25
## [B18] The lob's apex when the row leaves the cell BLANK: not a fixed height but a PROPORTION
## of the ground span it covers - and that single change is what buys the launch angle. A
## parabola thrown to apex `SHARE * span` leaves the muzzle at `atan(4 * SHARE)` ≈ 33°, at EVERY
## range (replacing B17's fixed 0.5-cell apex, on the user's order "弓箭要展现抛射的美感，有出射角":
## a fixed apex made the short shots nearly flat and the long ones nearly straight-up). A row
## that STATES a z_height keeps the old meaning - a fixed apex, authoritative - so the high
## melting-iceball lob is still writable data.
const LOB_APEX_SHARE := 0.16
## The default fall: the axis's gravity for anything with z_velocity (dives and jumps are
## Phase 2 behaviour; the integrate() this feeds runs on zeros today, frame-identical).
const Z_GRAVITY_CELLS := 4.0


# ---------------------------------------------------------------- the bout [D13 / D36]
const BOUT_SECONDS := 120.0
## THE RAGE (超时狂暴). Two minutes in, BOTH sides start losing health over time while
## hitting faster and harder and guarding worse, one step every RAGE_STEP_SECONDS. It is
## there to make a stalemate IMPOSSIBLE, not to decide one: at the last step a full-health
## piece bleeds 3% of its maximum every second and takes 48% more damage. First pass.
const RAGE_START := 120.0
const RAGE_STEP_SECONDS := 10.0
const RAGE_MAX_LEVEL := 6
const RAGE_DRAIN_PER_LEVEL := 0.005      # x maximum hp, per second, per level
const RAGE_ATTACK_SPEED_PER_LEVEL := 0.10
const RAGE_ATTACK_PER_LEVEL := 0.08
const RAGE_DEFENSE_PER_LEVEL := 0.08     # extra damage the target TAKES, per level
## [B23] THE CURTAIN (终场落幕): how long the arena stays on screen AFTER the last body has
## fallen, before the result page is opened. A whistle used to be the same frame as the teardown,
## so the deaths that decided the bout never finished falling - the eye needs to read "the fight
## is over because those bodies went down", and three fades' worth (BalanceUI.ANIM_DEATH_TIME,
## 0.3 s real seconds each) is what that came to. PRESENTATION time and not simulated time,
## because the sim is frozen for the whole of it (the tween that fades a body is not clocked by
## BrawlClock, so a 4x bout would otherwise be cut off from its own ending).
## [B25] A death is now a TOGGLE-AND-FADE and takes UnitFx.death_time() = 0.34 + 0.10 + 0.30
## = 0.74 s, so ONE of those still fits here with a beat to spare. If the last body ever looks
## cut off mid-fall, THIS number is the one to lengthen - not the fall: the topple is the same
## length everywhere in the game, and the lawn has no curtain to protect it.
const BOUT_CURTAIN_SECONDS := 0.9

# ---------------------------------------------------------------- the sides
const SIDE_LEFT := 0
const SIDE_RIGHT := 1
const SIDE_NAMES: Array[String] = ["LEFT", "RIGHT"]

# ---------------------------------------------------------------- the attachments (挂件) [B7]
## [D42 / D43] WHAT A PIECE WEARS. B5's augments were one multiplier per key applied to EVERY
## piece the player owned; B7 turned them into things that hang off ONE piece, and added
## equipment beside them. The two are the same object (BRAWL.md §8.6): a {kind, id} pair whose
## numbers come from data/brawl/gear.csv. What differs is only who offers it and how big it is -
## the fight cannot tell them apart, and that is the design, not a shortcut.
const KIND_AUGMENT := "augment"
const KIND_EQUIPMENT := "equipment"
const ATTACH_KINDS: Array[String] = [KIND_AUGMENT, KIND_EQUIPMENT]
## [D42] HOW MANY ATTACHMENTS ONE PIECE MAY WEAR - the user's own number: three, the same one
## TFT gives a champion. The fourth has nowhere to go and waits in the bag until something comes
## off (BrawlSession.equip / unequip), which is why the drop is REFUSED rather than swapped.
const ATTACH_SLOTS := 3

# ---------------------------------------------------------------- the player's roster [B5]
## [D16] How many pieces may be FIELDED AT ONCE. It starts at three and only a reward or the
## shop grows it, one step at a time, up to one piece per cell of the half - "a piece per
## slot" is the arithmetic D6 and D11 already agreed on, so there is no second ceiling to keep
## in step (BRAWL.md §2.2). THE OPENING LINE-UP IS NOT HERE ANY MORE: which pieces a session
## starts with and where they stand is data/brawl/roster.csv (RosterDB), and the two code
## fixtures this replaces (STANDIN_POOL / STANDIN_ROWS) are gone with B5.
const DEPLOY_CAP_START := 3
const DEPLOY_CAP_STEP := 1
const DEPLOY_CAP_MAX := MAX_PIECES_PER_SIDE
## [B5+] HOW MANY PIECES THE BENCH (候战区) HOLDS - nine, laid out three by three. It is
## CAPACITY and not decoration: a piece dragged onto the board LEAVES the bench and frees its
## slot, a piece dragged back takes one, and a session whose bench is full cannot take another
## piece at all (the shop greys the row out, and a win offers coin instead of a piece it could
## not hand over). The board's own ceiling is DEPLOY_CAP_MAX, so a session holds at most
## DEPLOY_CAP_MAX + BENCH_SLOTS pieces.
const BENCH_SLOTS := 9
## What a piece costs in the shop. PieceDB.cost() is the TIER (1-4, TFT's 费用); this turns a
## tier into coins. Two numbers instead of one because "this is a cheap champion" is a design
## fact and the price is a balance one - B6 is where the second may move.
const PIECE_PRICE_PER_COST := 4

# ---------------------------------------------------------------- a round's three offers [D35 / B26]
## [D35] How many opponents a round offers to fight, and the floor under that number: a round
## offering nothing to fight would have no reward to earn.
## [B26] The shop used to take one of these three slots (D22: an offer could be a BATTLE or the
## SHOP, and picking the shop spent the round on it). The shelf lies on the board (over the enemy
## half) now, so every offer is a fight and OFFER_BATTLES_MIN is the guard that keeps it that way if
## OFFER_COUNT is ever lowered to 0.
const OFFER_COUNT := 3
const OFFER_BATTLES_MIN := 1
## [B5 → B26] The KIND an offer row carries. It stayed a string because it travels in session
## dictionaries and is printed; it used to have a twin ("shop") and a door that read it
## (BrawlSession.chosen_kind()), and both went with the shop EVENT. What is left answers one
## question - is this offer a fight? - which is what BrawlSession.chosen_formation() asks.
const EVENT_BATTLE := "battle"

# ---------------------------------------------------------------- the round's power floor [B29]
## [B29] THE ENEMY'S 战力总值 CLIMBS EVERY ROUND. The rate is the user's number - "预设敌阵每回合增长
## 100战力总值水平" (2026-10-08) - and POWER_PER_ROUND below is that 100, nothing else owns it.
## The mode used to ramp by WALKING the formation sheet (D35: the three offers are a window that
## slides one row per round), which works exactly as many rounds as the sheet has rows - four today -
## and then stops: the window parks on the last formation and round 9 fights what round 4 fought.
## A floor in 战力 is what lets the run go on without the sheet going on: the sheet keeps supplying
## the SHAPE (who stands where, what the 概率 dice picked) and the round supplies the SIZE, by
## topping the rolled roster up with generated bodies.
## TWO DOORS, ONE SLOPE, because the two kinds of opponent are anchored differently:
##   authored_floor() - a written formation's OWN rolled 战力 plus 100 a round. At round 1 the
##     increment is zero, so the ladder's opening rounds are exactly what their author wrote, and
##     the climb is measured FROM each row's own size. That is the shape the request named.
##   power_floor()    - what a GENERATED opponent builds to: POWER_BASE plus the same 100 a round,
##     because a fight nobody wrote has no own size to grow from and needs a starting point.
## Linear, on purpose: +100 a round is readable in the log and on the card ("this round is 100
## stronger than the last"), and a compound curve is one line inside either function if the pacing
## ever wants it.
## WHAT +100 BUYS IS BOUNDED BY THE POOL, not by this number. The bodies the generator may draw are
## worth 120 (弓手) to 455 (骑士) 战力 each, and the body the SHEET mostly fields - one 普通僵尸 -
## is worth 421. So an increment smaller than one figure closes as "one body, slightly over the line",
## and a round's real growth is the floor plus at most one body. That is deliberate: the floor is a
## MINIMUM and the card prints the rolled sum, and the alternative to a slightly-over round is
## fractional bodies, which this mode cannot draw.
## POWER_BASE sits the round-1 GENERATED fight BETWEEN the round-1 AUTHORED window (哨兵 rolls one
## zombie = 421 战力, 双人组 two = 842): two to four mixed bodies, a step up from the written opener
## and short of the written pair - the random card reads as the middle choice, not as a freebie.
## It is deliberately ABOVE the cheapest body: a base under 120 could only ever be satisfied by one
## 弓手, and every seed would deal the same single archer.
const POWER_BASE := 600
const POWER_PER_ROUND := 100
## How many of a round's OFFER_COUNT opponents are generated rather than read from the sheet. The
## rest stay authored (and are raised to authored_floor() below). A round whose formation sheet could
## not be read generates ALL of them instead - the mode then has opponents, which is more than the old
## code had (it returned an empty offer list and a dead page).
const GEN_OFFERS := 1
## The ceiling on bodies in a generated (or topped-up) opponent, in pieces - not cells. The enemy
## half holds HALF_COLS x ROWS = 20 cells, so this is the number that stops a deep round turning the
## preview into wallpaper, and it is also what bounds how far BELOW the floor an opponent can end up
## once every cell it is allowed to use is taken.
const GEN_MAX_PIECES := 12
## A GENERATED opponent's target is the round's floor moved by up to this SHARE either way, drawn
## with the session's RNG. It keeps the random card off an exact arithmetic line - the fight you are
## offered is not always the same size - and it is bounded, so no offer is ever off the round's curve
## by more than this.
const GEN_TARGET_JITTER := 0.15
## What a win pays, in the authored ladder's own currency: 战力 per 金币. The sheet's four rows
## divide out to 37-47 (哨兵 421/10, 双人组 842/18, 三人线 1263/28, 精锐队 1684/45 - each the ROLLED
## total, before any [B29] reinforcement), so 40 sits a generated - or reinforced - opponent on the
## same line a written one is on, and a deeper round, being bigger, pays more. That is the intended
## shape (reward tracks difficulty); it also means the purse outruns the shelf's fixed prices the
## further a run goes, which is a SHOP tuning problem, not this divisor's.
const GEN_COINS_PER_POWER := 40
## The id a generated opponent carries. It is NEVER a row of data/brawl/formations.csv (FormationDB
## answers a stranger id with the id itself, which is why nothing may ask the sheet about these), and
## it exists for the logs and the result line: "gen5.0" reads as round 5's first generated offer.
const GEN_ID_PREFIX := "gen"


static func power_floor(p_round_no: int) -> int:
	## [B29] What a GENERATED opponent assembles to. Round 1 sits at POWER_BASE; the argument is the
	## SESSION's round counter, which is the only clock this mode ramps on.
	return POWER_BASE + POWER_PER_ROUND * maxi(0, p_round_no - 1)


static func authored_floor(p_own_power: int, p_round_no: int) -> int:
	## [B29] What a WRITTEN formation must be raised to: its own 战力 plus the round's share of the
	## climb - the user's "预设敌阵每回合增长100战力总值", one increment per round past the first.
	## Feed it the total of THIS round's ROLL (FormationDB.power_total_of over the rolled rows), not
	## the sheet's authored list: the 概率 dice move the base every round, and the increment is the
	## part that must not. Round 1 asks nothing of a written row - the ladder opens exactly as its
	## author wrote it - so the counter is clamped and the increment can never go negative.
	return p_own_power + POWER_PER_ROUND * maxi(0, p_round_no - 1)

# ---------------------------------------------------------------- the win's reward [D16]
## [D16] A WIN pays the opponent's 金币 column (D4, the session adds it) AND opens a three-card
## choice - the TFT 三选一 shape BRAWL.md §8.4 asks for. Every card is one of the four kinds
## below, they are drawn WITHOUT replacement so the three are always different kinds, and the
## numbers behind three of them (a piece, an augment, +1 cap) come from their own sheets: only
## the coin card and the cap step are authored here.
const REWARD_PICKS := 3
const REWARD_KIND_PIECE := "piece"
## [B7] An augment card and an equipment card ARE the two attachment kinds (KIND_* above): both
## land in the same bag and _grant() hands them to the same door. Spelled as the attachment
## tokens rather than as fresh literals so the two vocabularies cannot drift.
const REWARD_KIND_AUGMENT := KIND_AUGMENT
const REWARD_KIND_EQUIPMENT := KIND_EQUIPMENT
const REWARD_KIND_CAP := "cap"
const REWARD_KIND_COINS := "coins"
## Relative weights, one per kind. A kind drawn with weight 0 is simply never offered. [B7] The
## five now add up to 100: equipment took its share from the piece card (40 -> 35) and from the
## augment card (30 -> 22), because two of the three cards a win opens can now be attachments.
const REWARD_WEIGHTS := {
	REWARD_KIND_PIECE: 35,
	REWARD_KIND_AUGMENT: 22,
	REWARD_KIND_EQUIPMENT: 18,
	REWARD_KIND_CAP: 10,
	REWARD_KIND_COINS: 15,
}
## What the coin card pays. It has to sit between what a level pays (10-45, the opponent's own
## column) and what the shop charges (4-16) to be worth picking over a piece.
const REWARD_COINS := 12

# ---------------------------------------------------------------- the shop [D22 / D33]
## [B5] WHAT A SESSION STARTS WITH IN ITS PURSE. Zero would make the FIRST shop round a dead
## screen (a session begins with no money and a shop option can be the very first pick - the
## offers are rolled before any bout is won), so a session opens with just enough for the
## cheapest rung of each kind (a 1-cost piece is PIECE_PRICE_PER_COST, the cap rung is
## SHOP_CAP_PRICE). Set it to 0 to go back to "a win is the only income"; D33 and BRAWL.md
## §8.5 say where coin comes from, and this is the one number that decides where it starts.
const START_COINS := 10
## [B5] THE SHELF: how many slots of each kind one stock has, and what the +1 cap rung costs.
## The pieces, the augments and [B7] the equipment are DRAWN from their own sheets (RosterDB /
## GearDB), which is what makes "add a shop item" mean "add a row" - the brawl's tables are the
## shelf, and the equipment row is priced off the same tier ladder the augments use.
const SHOP_PIECE_SLOTS := 2
const SHOP_AUGMENT_SLOTS := 1
const SHOP_EQUIPMENT_SLOTS := 1
const SHOP_CAP_SLOTS := 1
const SHOP_CAP_PRICE := 8

# ---------------------------------------------------------------- the effect keys (效果) [B7]
## BRAWL.md §8.2 / §8.6: the SHAPE is the campaign's mod (a key and a value) but the WHITELIST is
## the brawl's own - sharing BalanceRun.RUN_MOD_KEYS would mean "editing the campaign moves the
## brawl". Every key below is read by BrawlActor and nowhere else, and a sheet row whose 效果
## names none of them is reported at boot (GearDB) rather than quietly doing nothing.
##
## The first five MULTIPLY: the sheet writes a DELTA, so +0.15 is "15% more" and -0.15 is "takes
## 15% less". They are the five an augment has always used, and equipment may use them too.
## [B7] The last two ADD, and they are what made equipment something other than a small augment
## (BRAWL.md §8.6.5 / O35): +120 hit points on a 240-hp militia is a decision, +20% of it is a
## rounding error - and a flat bonus is the one thing a multiplier can never be.
const KEY_HP := "hp_mult"
const KEY_ATTACK := "attack_mult"
const KEY_SPEED := "speed_mult"
const KEY_HASTE := "haste"
const KEY_TAKEN := "taken_mult"
const KEY_HP_FLAT := "hp_flat"
const KEY_ATTACK_FLAT := "attack_flat"
const EFFECT_KEYS: Array[String] = [KEY_HP, KEY_ATTACK, KEY_SPEED, KEY_HASTE, KEY_TAKEN,
	KEY_HP_FLAT, KEY_ATTACK_FLAT]
## The tiers a 等级 cell may name, what the shop charges for one, and how often one is drawn
## (silver is the common rung, prism the rare one). A tier no ladder lists is reported by GearDB
## and answered with the LAST rung here, so a typo is loud AND harmless. [B7] BOTH KINDS SHARE
## THE TWO LADDERS: an equipment row is smaller than an augment of its tier, not cheaper to
## stock, so there is no second pair of numbers to keep in step.
const TIER_SILVER := "silver"
const TIER_GOLD := "gold"
const TIER_PRISM := "prism"
const GEAR_TIERS: Array[String] = [TIER_SILVER, TIER_GOLD, TIER_PRISM]
const GEAR_PRICES := {TIER_SILVER: 6, TIER_GOLD: 10, TIER_PRISM: 16}
const GEAR_WEIGHTS := {TIER_SILVER: 6, TIER_GOLD: 3, TIER_PRISM: 1}
## The floor a stack of 厚皮 can bring "damage taken" down to: a quarter of every blow still
## lands, so no pile of attachments can make a bout unendable (BRAWL.md §14's third rule).
const TAKEN_FLOOR := 0.25

# ---------------------------------------------------------------- the pieces' fall-backs [B5]
## What a human piece's rhythm is when its attack间隔 cell is blank: a readable pace for a body
## that fights on foot, and the one number in this block that is not a turn-engine conversion
## (a human attacks on seconds, not on AP).
const DEFAULT_STRIKE_SECONDS := 1.0

# ---------------------------------------------------------------- the channelled beam [P110g]
## 连续冲击光束 (the eye tower) is the one attack in the brawl that does not land once: it burns
## for as long as its row's 持续 cell says, dealing damage in TICKS. How long it burns is the
## sheet's (a row states 持续), and the 间歇 between two channels is not a number of its own -
## attack间隔 is the whole CYCLE, so 4.0 with a 3.0 second channel leaves exactly one second of gap.
##
## These two are GAME RULES and live here rather than in BalanceUI: they decide what a tower is
## worth, and they are the numbers to reach for when it is too strong or too weak.
const BEAM_TICK_SECONDS := 0.5
## What share of ONE blow each tick is worth. 0.5 over a 3 s channel is six ticks, i.e. three
## blows per channel: 0.75 blows a second against the laser eye's 0.71, which is what a 4-cost
## tower with more health and more reach should be paying out. Change it BEFORE changing the
## channel's length - the length is the sheet's, the worth is this.
const BEAM_TICK_SHARE := 0.5


# ---------------------------------------------------------------- the energy and the ultimate [B14]
## HOW A BRAWL PIECE EARNS ITS ULTIMATE. 雷角兽 is the first piece in this mode whose attack is
## not the whole of it: every ORDINARY blow it lands banks ENERGY_PER_STRIKE, and when the bank
## is full the next blow is replaced by the ULTIMATE - the same beam, HELD for as long as the
## row's 大招持续 cell says (data/units/<faction>.csv; the cell is also the on/off switch - a row
## that leaves it blank has no ultimate at all and never draws a bar).
##
## ONE RULE FOR EVERY ULTIMATE, exactly the way BalanceBattle.ULT_CHARGE_PER_CAST /
## ULT_CHARGE_MAX is one rule for every plant's: how much a blow banks and how full the bar has
## to get are the MODE's numbers, while WHAT the ultimate is (which beam, how many seconds) is
## the row's. 25 x 4 = twenty ordinary blows per ultimate.
## ⚠ The day a row needs its own rate, THIS is the pair to move into the sheet - do not grow a
## second charging rule beside it.
const ENERGY_PER_STRIKE := 25
const ENERGY_MAX := 100
## [W12] THE CLOCK'S DEPOSIT: every bar in this mode also fills ON ITS OWN, at 10 a second,
## asked by BrawlActor.tick and paid through the same Unit.charge_ultimate door as a blow's
## deposit (the one exemption is the belly - a digested prey does not charge). This is the
## user's rule "所有能量槽每秒自动积攒10能量", and it deliberately changes the feel of the
## existing ultimates: thundercorn and snorlax now reach 100 without landing four blows, so a
## stalemate ends on a TIMER. Reach for THIS number when every ultimate in a bout fires too
## soon or too late; the per-strike amount above stays for the active half of the fill.
const ENERGY_PER_SECOND := 10.0
## WHAT ONE TICK OF AN ULTIMATE IS WORTH. The ordinary channel above pays BEAM_TICK_SHARE per
## tick because a tower's 3-second burn is a CADENCE - it is how that piece attacks. An ultimate
## is a BURST: every tick is a whole blow, so the opening blow plus the five that fit inside
## three seconds are six blows, i.e. about three times what the piece would have landed by
## attacking normally for the same three seconds (it strikes every 1.6 s). That ratio is the one
## number to reach for when an ultimate feels flat or decides a bout on its own.
const ULT_TICK_SHARE := 1.0


static func effect_known(p_effect: String) -> bool:
	## Does anything apply this key? GearDB asks at load, so a 效果 nothing reads is a reported
	## problem instead of a row that silently does nothing.
	return EFFECT_KEYS.has(p_effect)


static func effect_is_flat(p_effect: String) -> bool:
	## [B7] Does this key ADD an amount rather than multiply by a delta? GearDB asks so it prints
	## "+120" instead of "+15%", and BrawlActor asks so it knows which of its two doors to walk.
	return p_effect == KEY_HP_FLAT or p_effect == KEY_ATTACK_FLAT


static func kind_known(p_kind: String) -> bool:
	## [B7] Is this a 名称 a gear row may name? GearDB reports a typo rather than filing the row
	## under a kind no reward and no shelf will ever draw from.
	return ATTACH_KINDS.has(p_kind)


static func gear_price(p_tier: String) -> int:
	return int(GEAR_PRICES.get(p_tier, GEAR_PRICES[TIER_PRISM]))


static func gear_weight(p_tier: String) -> int:
	return int(GEAR_WEIGHTS.get(p_tier, GEAR_WEIGHTS[TIER_PRISM]))


static func tier_known(p_tier: String) -> bool:
	return GEAR_TIERS.has(p_tier)
