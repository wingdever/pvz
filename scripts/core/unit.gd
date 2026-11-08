class_name Unit
extends Node2D
## Base class for every board unit (plant or zombie).
## [P5] Presentation layer added. It never blocks the turn engine:
##   _move_offset   : slide-in after a logical move
##   _shake_offset  : impact jitter (bites, projectiles)
##   _lean          : [P110] the BODY's tilt - the pose half of the named effects, and the
##                    only channel that also works in a brawl (a rotation is not ink);
##                    [B33] the stun sway ROCKS this value about the feet
##   _turn_anchor   : [B25] what that tilt turns ABOUT (0 = the origin; a topple - and since
##                    [B33] a stun sway - put it at the feet)
##   _idle_stretch  : [B33] the new DEFAULT idle: this body's picture scaled long-and-thin
##                    against short-and-wide about the feet, and back through the reverse
##   _jelly         : [B34] the hit JELLY: the same scale channel RINGED, not moved - a struck
##                    body snaps short-and-wide and oscillates back to rest about its feet
##   _display_ratio : smoothly animated action bar
##   play_death()   : [B25] the death effect - topple + fade by default - then free
## Logic only reads col / row / hp / ap. position is purely cosmetic.
##
## [P110] NAMED EFFECTS. play_fx(id) is the door. scripts/core/unit_fx.gd owns WHICH effects
## exist and who wins when two collide, docs/prompt/FX.md owns those rules in prose, and THIS class
## owns the channels an effect is made of: the red flash, the lean (rocked about the feet by
## the [B33] stun sway), the shake offset, and the idle baseline - its sway and its [B33]
## stretch. A new effect is a row over there; a new CHANNEL has to be built here first.
##
## [P30-A] The action bar became an ACTION POINT budget: every unit is granted
## BalanceBattle.ROUND_AP points when its side's action phase opens, one use of its skill
## costs `threshold` points, and unspent points expire when the phase ends (AP never
## carry over). The budget is PLAIN ACCOUNTING, not a bar: plants draw no bar for it
## (see bar_shown) - the only bar under a unit is the walking zombie's MOVE progress.
## [P30-B] The bar slot a plant DOES draw is the ULTIMATE charge: the code it loads
## (ult_code) fills by ULT_CHARGE_PER_CAST per charge event (casts, or hits for a
## "hit" ultimate like the wall-nut), and at ULT_CHARGE_MAX the engine fires
## act_ultimate() inside the same action phase and resets the bar.

enum Shape { CIRCLE, RECT }
## [B17] The shared Z-axis struct (scripts/core/height_body.gd, D103). Preloaded BY PATH on
## purpose - it carries no class_name, so no editor registration pass is needed (§1.4).
const HeightBody := preload("res://scripts/core/height_body.gd")

signal died(unit: Unit)

var grid: Node2D = null
## [P106] The battle this unit stands on, injected by the factory. Deliberately UNTYPED, exactly
## as `game` was before it: Battle preloads the unit scripts, so typing this would be a cycle.
var board = null

var col: int = 0
var row: int = 0
var stack_index: int = 0        # visual slot inside its cell when units share it

var max_hp: int = 1
var hp: int = 1

var threshold: int = 1          # [P30-A] AP cost of ONE skill use; <= 0 means "never acts"
var ap: int = 0                 # [P30-A] action points left in this round's action phase
## [P30-A4] The 技能代码 this instance actually loads (units.csv 技能代码 column
## through Balance.plant_skill_code, fall-back the script's const SKILL). The
## almanac and hover read it as the unit's ACTION SEQUENCE; the day the player
## can re-fit skills, this is the field that changes. "" = not a skill-bearing
## unit (a wall-nut, a zombie: their sequence is fixed in code or sheet prose).
var skill_code: String = ""
## [P30-B] The ULTIMATE this instance loads: the 大招代码 of its units.csv row
## (Balance.plant_ult_code; "" = no ultimate, no bar). `ult_charge` fills one
## point of the bar below the hp bar; the engine reads has_ultimate() /
## ult_ready() / consume_ult_charge() and calls act_ultimate(). `ult_immune` is
## the wall-nut's 铁壁 flag: while set, damage against this plant is refused
## (GameManager clears it at the next TURN_START - the ult's own round plus the
## zombie phase that follows it, which is what "本回合内免疫伤害" means).
var ult_code: String = ""
## [P30-B] The plant id the bar's NAME looks up in the plant sheet (its 大招 /
## 大招效果 prose columns, language twins and all). Same as the id for today's
## loadouts; kept apart from ult_code because the code is a skills.csv key.
var ult_id: String = ""
var ult_charge: int = 0
var ult_immune: bool = false
## [P34] How many round-starts are still left behind that wall: GameManager spends
## one at each TURN_START and drops `ult_immune` with the last one. That is what made
## 铁壁 mean "this round only" in P30-B, and the default 1 keeps every existing unit
## behaving exactly as before - a wall whose 大招效果 says 2 回合 (the tall-nut) just
## starts the brace with 2 (see WallPlant.immunity_rounds).
var immune_rounds: int = 1
## [P39] Rounds this unit must STAND DOWN before it acts again, ticked at TURN_START
## next to the wall-nut's brace (GameManager). `can_act()` refuses while it is above 0,
## which is how a chomper mid-swallow skips its whole action phase instead of biting
## again with the AP it still has. 0 = nothing pending, so no existing unit changes.
var stand_down_rounds: int = 0
## [P39] What those rounds are spent ON, for the battle log ("chewing"). The engine
## prints `stand_down_text()` when a plant does nothing, and the walls' case is the
## empty note - so a plant that stands down for a reason of its own says which one
## rather than being mis-reported as a threshold-0 blocker.
var stand_down_note: String = ""
var action_label: String = "IDLE"
## [P20] LocNames key for action_label ("action.fire", "action.advance" ...), so the
## word under the action bar follows the language too. Empty = draw action_label.
var action_key: String = "action.idle"

var is_zombie: bool = false
## [P114] THE TWO REAL-TIME TRAITS this body was authored with, cached once at setup by
## read_realtime() (see the shape of read_height() below). Both default OFF, so any body that
## never calls read_realtime (every zombie, and every plant that has no realtime row to speak
## of) keeps walking, taking damage and dying exactly as before - these two fields are read only
## by the live brawl driver, never by the turn-based engine.
## HP recovered per SECOND while alive (units.csv `regen`); 0 = no self-heal. The single writer
## is BrawlActor's regen accumulator, and it lands through Unit.heal() - never the §3 defence formula.
var regen_per_second: int = 0
## True = this body ROLLS while it moves (units.csv `rolling`): the live driver feeds _roll below
## from the distance walked. False = the ordinary walk, with no rotation added.
var rolls: bool = false
## [P110] WHICH WAY THIS BODY IS TURNED, in screen directions. The pose effects are the only
## readers, and this is what lets one table row say "lean forward" for a plant looking right
## and for a zombie looking left. ZERO means "nobody said", and facing_dir() then answers the
## side's own default. The brawl is the one writer that differs: its driver copies the
## actor's float facing in every frame, because a piece may be deployed TURNED or be walking
## on a diagonal (_sync_position).
var facing := Vector2.ZERO
## [P63] Whether a body that reaches this unit's own cell may bite it at all. A plant-side
## fact, and the only reader is the zombie's decision (`_decide_zombie_act`): 地刺 stands on
## the ground the zombie walks along, so sharing its cell is normal for it and the ordinary
## "there is a plant one step ahead, so stop and eat it" answer would freeze the line
## in front of a spike that cannot be eaten. False for every unit until a sheet row says
## otherwise - SpikePlant is the first to read the cell (PlantDB.is_uneatable).
##
## A flag on the instance rather than a `is SpikePlant` test at the call site for the same
## reason P59's fear gate reads the sheet once at spawn: the class check would have to be
## rewritten the day a second family grows the words, and it would say YES to a spike whose
## row had them REMOVED. The table stays the writer, this var stays the fact.
var ignores_biting: bool = false
var display_name: String = "UNIT"
## [P20] Language-aware naming: `display_key` is the LocNames key for this unit's
## base name ("plant.peashooter" / "unit.zombie") and `display_tag` is whatever
## trails it (the "#2" that tells two garden plants apart). refresh_display_name()
## rebuilds display_name from both, which is what a live language switch calls.
var display_key: String = ""
var display_tag: String = ""
## [P37] `display_name` minus `display_tag` - the string refresh_display_name() works
## from, so a name can be rebuilt any number of times without the tag compounding.
var base_display_name: String = "UNIT"
var body_color: Color = Color.WHITE
var body_shape: int = Shape.CIRCLE
var body_size: float = BalanceUI.UNIT_BODY_SIZE
## [P11] Sprite for this unit. Empty means "draw the flat placeholder shape", so
## a unit without art (or a sprite that failed to load) still looks like before.
var art_path: String = ""
## [P28] The unit's VIEW SCENE: the scene the `tscn` column of its row in
## data/units/plants.csv / zombies.csv registers (through Balance.plant_view() /
## zombie_view()), already resolved - "" means "this unit has no scene", and the sprite
## above is drawn instead. See _load_view() for what the board does with it.
var view_path: String = ""
## [P12] Which garden slot this plant was summoned from, or -1 when the level put
## it there. Only garden plants write their wounds back: a level's starting plants
## are level property, they consume nothing and come home to nobody.
var garden_slot: int = -1
## [P15] What this instance is worth in battle. `level` is the garden plant's level,
## `skill_value` is its skill resolved through its attributes (pea damage / sun per
## produce); a level starting plant uses the plain base values.
var level: int = 1
var skill_value: int = 0
## [B11c] 防御: this body's term in the damage formula's DENOMINATOR (Balance.hurt_after_defence,
## the one place a hit becomes a number - docs/NUMBERS.md §3). Read off units.csv through
## UnitSheet.defence(); a garden plant grows it with its level, a brawl piece takes the sheet's
## number, and a unit whose row says nothing gets the race default (20 today). 0 means NO
## DEFENCE, not immunity: the factor is 128 / (128 + 0) = 1, so the blow lands at full attack.
var defence: int = 0
## [B17] THE HEIGHT BODY - the authored "ink" copy of the unit's Z interval and ground footprint
## (docs/prompt/HEIGHT.md §2, D103). Every family's apply point fills it from the sheet doors
## the way `defence` and `faces_left` are filled; BrawlActor.setup() then COPIES it and becomes
## the solver (the body is the book, the actor does the arithmetic). The classic engine reads
## none of it this phase (spec §10-1): every field defaults to a body flat on the ground, so an
## untouched row cannot change anything.
var height: HeightBody = HeightBody.new()
## [B16] 朝向: WHICH WAY THIS BODY'S PICTURE LOOKS - true when the art was DRAWN looking left.
## Read off units.csv's `face` column at spawn (UnitSheet.face_left), the way defence above is,
## and by the same rule: the row's own cell wins, a blank one has been answered by the race
## default row, and the family hands in its own last resort (a zombie looks left, everything
## else right). Every family writes it - the five plant bases, the chomper, the zombie and the
## brawl piece - so "which way does this body look" has ONE owner for the whole roster.
##
## IT IS A FACT ABOUT THE ART, not about the fight: which way the body AIMS is `facing`
## (see facing_dir), and a brawl piece re-aims at its target every tick. The two disagree
## exactly when a body stands in the camp its model was not built for - and that is what
## `mirrored` below fixes.
var faces_left: bool = false
## [B16] IS THIS BODY DRAWN MIRRORED? Set by whatever DEPLOYS the body, when the art faces the
## wrong way for the camp it was put in (BrawlActor.is_turned is the only writer today: it is
## the brawl that puts a piece on either half). Every art level honours it - a sprite through
## the draw transform in _draw_body, a view scene through its BodyPivot's x scale.
## ⚠ NOT `scale`: play_death() tweens unit.scale and the belly pose writes it (BrawlActor), so
## a mirror kept there would be undone by either of them.
var mirrored: bool = false:
	set(p_on):
		if mirrored == p_on:
			return
		mirrored = p_on
		_apply_mirror()
		queue_redraw()
## [P15] Who hit this unit last, so a kill can be credited to the plant that made
## it (exp follows the killing blow). Null means "nobody": tools, debug kills and
## zombies themselves do not earn a plant any experience.
var last_attacker: Unit = null

var _flash: float = 0.0
var _display_ratio: float = 0.0
## [P30-B] The smoothed fill of the ULTIMATE bar - its own value, so a zombie's
## move bar and a plant's charge bar can never cross-fade through each other.
var _ult_display_ratio: float = 0.0
var _move_offset := Vector2.ZERO
var _shake_offset := Vector2.ZERO
## [P110] The POSE channel: how many radians the body is tipped by right now. Rotation is
## clockwise-positive in Godot's y-down space, so a body facing right leans forward with a
## POSITIVE value - _facing_sign() is the only place that decides which way "forward" is.
var _lean: float = 0.0
## [P114] The ROLL component of the same rotation channel, kept SEPARATE from _lean on purpose:
## _lean is borrowed by flinch, stun sway and the death topple, each of which writes it as its own
## whole answer. A rolling body must not be stolen by those, and must not steal them either, so the
## two are simply ADDED wherever a rotation is applied (_draw_body / _apply_lean read _lean + _roll).
## The live driver owns the value (set_roll), and only ever while this body actually walks.
var _roll: float = 0.0
## [B25] THE POINT that lean turns ABOUT, this many pixels BELOW the unit's origin. 0.0 is
## "the origin", which is what every P110 flinch has always meant and what still answers for
## them. A TOPPLE moves it: a body that rotates 90 degrees about its own centre ends up
## lying half a body above the lawn it fell on, so the death effect plants the feet and swings
## the rest of the picture around them. [B33] added a second living writer: the stun sway
## rocks about the same hinge for as long as it lasts and hands the origin back when it
## settles. See _turn_offset() for the compensation it costs.
var _turn_anchor: float = 0.0
## [P110] Which named effect is playing and how much of it is left. "" = the idle baseline.
## The pair IS the whole priority state: UnitFx reads it (fx_priority) and writes it
## (fx_begin), and _tick_fx() in _process is what expires it.
var _fx_id: String = ""
var _fx_time: float = 0.0
## [P112] THE SHOUT BUBBLE's state (see _draw_shout): what the balloon says, how long is left,
## and whether it was an ULTIMATE (which decides the gold). "" / 0.0 = no balloon. ONE text lives
## here because a body wears exactly one shout at a time - a new cast simply overwrites the last.
var _shout_text: String = ""
var _shout_time: float = 0.0
var _shout_ult: bool = false
var _move_tween: Tween = null
var _shake_tween: Tween = null
var _lean_tween: Tween = null
var _dying: bool = false
var _art_texture: Texture2D = null
var _art_tried: bool = false
## [S4/D72] HOW MUCH BIGGER THIS BODY'S PICTURE IS THAN THE DESIGN BOX. 1.0 everywhere except in
## a brawl, whose board is not the turn engine's 96 px cell (BrawlLayout.piece_scale feeds it):
## the brawl sets it BEFORE place(), because place() is what loads the view and fits it. The HP
## bar, the name and the action bars are Unit's own and do NOT follow it - a body may look bigger
## without its readouts shouting.
var art_scale: float = 1.0
var art_view: Node2D = null          # [P28] the instantiated view scene, if any
## [P110] The view's parent: a plain Node2D sitting at this unit's origin, which is what the
## lean rotates. See _load_view for why the view cannot carry the lean itself.
var _body_pivot: Node2D = null
var _view_tried: bool = false
static var _view_warned: Dictionary = {}   # path -> true, so the warning prints once
var _idle_phase: float = 0.0
var _idle_offset := Vector2.ZERO
## [B33] The STRETCH half of the idle baseline: a per-axis scale of the body's PICTURE about
## its feet - short-and-wide against long-and-thin, rocking through the reverse every cycle
## (UnitFx.idle_spec). ONE whenever the body breathes the old way, an effect is playing, or
## the body is dying. NOT node.scale: play_death() tweens that and the belly pose writes it.
var _idle_stretch := Vector2.ONE
## [B34] THE JELLY CLOCK: 1.0 the instant a body is struck, tweened down to 0.0 as the ring
## dies away (0.0 also means "no jelly" — the resting value). The scale is never stored: it is
## read out of this one number by _jelly_scale(), multiplied by the row's signed strength
## (`_jelly_str` — a pellet's FX_PELLET_SCALE makes it ring quieter, not shorter), so a hit
## taken mid-ring simply rewrites both and restarts the ring snapped.
var _jelly := 0.0
var _jelly_str := 0.0
var _jelly_tween: Tween = null
## [B33] Which idle presentation this body wears ("" = UnitFx.IDLE_DEFAULT). A CALLER's pick
## through set_idle_fx(), never the unit's own data - docs/prompt/FX.md §9.
var idle_fx: String = ""
## [B33] The row of the idle table this body is wearing, cached so that the baseline can ask
## its own shape once per set_idle_fx() instead of once per frame (P38's rule: nothing in this
## loop allocates). It is a COPY OF A TABLE ROW, not a second owner of any number; place()
## fills it the moment the body knows what it is, set_idle_fx() replaces it on a switch.
var _idle_spec: Dictionary = {}


# ---------------------------------------------------------------- placement
func place(p_grid: Node2D, p_col: int, p_row: int) -> void:
	grid = p_grid
	col = p_col
	row = p_row
	_move_offset = Vector2.ZERO
	_shake_offset = Vector2.ZERO
	## [P110] A fresh body starts upright with nothing playing: the pose channels are
	## per-life state, and place() is where this body's life starts.
	_set_lean(0.0)
	_turn_anchor = 0.0            # [B33] a sway or a topple may have left the hinge at the feet
	_idle_stretch = Vector2.ONE   # [B33] same per-life reason for the idle scale
	_jelly = 0.0                  # [B34] and for the hit ring riding the same channel
	_jelly_str = 0.0
	_idle_spec = UnitFx.idle_spec(idle_fx)   # [B33] which baseline this body wears
	_fx_id = ""
	_fx_time = 0.0
	# start each unit at a different point of the idle cycle, otherwise a whole
	# row of plants breathes in lockstep and looks mechanical
	_idle_phase = float((col * 7 + row * 3) % 10) * BalanceUI.IDLE_PHASE_STEP
	if BalanceUI.UNIT_ART_LINEAR_FILTER:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_load_art()
	_load_view()
	_apply_position()
	_play_spawn_pop()


func read_height(p_id: String) -> void:
	## [B17] THE ONE READ of the height axis for a body (docs/prompt/HEIGHT.md §7, dev plan §2):
	## every family's apply point calls this right after its `faces_left` line, so the six sheet
	## doors have exactly one caller shape and the families cannot drift about them.
	##
	## THE ONE RULE HERE: a row that states a number is never touched by any of this -
	## `UnitSheet.z_thickness()` keeps the table in front, and only a BLANK cell asks art.
	##
	## [B36] THE INK, NOT THE CANVAS (D112): z_thickness is "how tall the body REACHES from its
	## feet", so the honest reading is the box the picture actually paints, not the box it was
	## saved in. Every sprite keeps margin above its head and under its sole, which is the same
	## eighth of a box the militia's shadow tripped over.
	##
	## [B37] THE FLOOR IS GONE (D113, user ruling 2026-10-09): D104's
	## `max(…, Balance.UNIT_Z_THICKNESS_CELLS)` held every body to a full cell while the ruler
	## still measured the canvas - once it measures the ink, the floor was what answered, and it
	## quietly overestimates the reach of anything painted shorter than a cell. Bodies are now as
	## tall as their art, and `UNIT_Z_THICKNESS_CELLS` shrinks to what it always was underneath:
	## the whole-body guess for a picture that cannot be measured (no file at all), so a unit whose
	## art failed to import never becomes a zero-thickness sliver that nothing can hit.
	var tex := UnitArt.load_texture(art_path)
	var texture_w := 0.0
	var texture_h := Balance.UNIT_Z_THICKNESS_CELLS
	if tex != null:
		texture_w = tex.get_size().x / Balance.ART_DESIGN_CELL_PX
		texture_h = tex.get_size().y / Balance.ART_DESIGN_CELL_PX * UnitArt.ink_span_y(art_path)
	height.z_height = UnitSheet.z_height(p_id)
	height.z_thickness = UnitSheet.z_thickness(p_id, texture_h)
	var authored_width := UnitSheet.body_width(p_id, texture_w)
	height.body_width = authored_width
	height.body_depth = UnitSheet.body_depth(p_id, authored_width * 0.5)
	height.body_xoff = UnitSheet.body_xoff(p_id)
	height.body_yoff = UnitSheet.body_yoff(p_id)


func read_realtime(p_id: String) -> void:
	## [P114] THE ONE READ of the two REAL-TIME TRAITS, the sibling of read_height() above: a body's
	## setup copies the two authored cells into itself once, and the live driver reads the FIELDS
	## (like it reads unit.threshold) rather than asking the sheet every tick. Both cells are plain
	## sheet readers, so a blank resolves to the OFF value inside UnitSheet (regen 0 / rolling false)
	## and only a row that deliberately states a number turns either trait on - which today is the
	## wallnut alone. Both family apply points call this right after their read_height() line, so the
	## two doors keep the same one-caller shape and cannot drift.
	regen_per_second = UnitSheet.regen(p_id)
	rolls = UnitSheet.rolling(p_id)


func _load_art() -> void:
	## Once per unit. A missing sprite only costs the flat placeholder shape.
	if _art_tried:
		return
	_art_tried = true
	if art_path == "":
		return
	_art_texture = UnitArt.load_texture(art_path)
	if _art_texture == null:
		UnitArt.warn_once(art_path)


func has_art() -> bool:
	## Subclasses that drew extra markers on top of the flat shape use this to
	## skip them once a real sprite is in place.
	return _art_texture != null

func _load_view() -> void:
	## [P28] A view scene replaces the sprite as this unit's body. What the board draws is
	## one chain, tried in this order (see Balance's "unit VIEW scenes" block):
	##   tscn  this scene            - loaded here, "" or a broken file costs the next step
	##   svg   art_path's texture    - Unit._draw_art()
	##   flat  the placeholder shape - Unit._draw_body()
	##
	## The instance becomes a child of a PIVOT under this node ([P110], see below) and is
	## drawn BEHIND our own painting (show_behind_parent on the pivot): the name, the hp bar
	## and the action bar are painted by Unit._draw() and must stay on top of the plant, while
	## the flat placeholder shape has to step aside (see _draw_body()).
	if _view_tried or view_path == "":
		return
	_view_tried = true
	var packed := UnitArt.load_scene(view_path)
	if packed == null:
		_warn_view()
		return
	var node := packed.instantiate()
	art_view = node as Node2D
	if art_view == null:
		node.free()          # a root that is not a Node2D cannot be placed: keep the sprite
		_warn_view()
		return
	## The scale and the offset are UnitArt's business, not this class's: every drawer of a
	## view (this one and the almanac panel) goes through fit_view(), which is what keeps a
	## plant the same size on the lawn and in the almanac.
	UnitArt.fit_view(art_view, BalanceUI.UNIT_ART_SIZE * art_scale)
	## [P110] The view hangs off a PIVOT at this unit's own origin rather than off the unit
	## directly: a lean must turn the body ABOUT THE UNIT'S CENTRE, and a view's own origin is
	## its FEET (UnitArt.fit_view puts it there so a view and a sprite cover the same pixels).
	## Rotating the view itself would pivot the lean at the ankles and make the same picture
	## lean differently depending on which of the three art levels drew it. The pivot sits at
	## the origin, so the view's own scale and position are untouched by this.
	_body_pivot = Node2D.new()
	_body_pivot.name = "BodyPivot"
	_body_pivot.show_behind_parent = true
	add_child(_body_pivot)
	_body_pivot.add_child(art_view)
	## And so is starting its idle clip ("" = the part has nothing to play, which is not an
	## error: see UnitArt.play_view_idle).
	UnitArt.play_view_idle(art_view)
	## [B16] A view built AFTER the mirror flag was set has to be flipped here: the setter only
	## reaches a pivot that already exists (a brawl piece is told what it is before place(), but
	## place() is what builds the view).
	_apply_mirror()
	queue_redraw()


func set_view_path(p_path: String) -> void:
	## [P28] Hand this unit the scene its row registers NOW. Called by the units
	## themselves (_init for a plant, apply_type() for a zombie), and again whenever a
	## zombie's TYPE changes under it - a conehead that loses its cone becomes the base
	## zombie, which may be a different part. An unchanged path is left alone, so the
	## animation keeps running through a "downgrade" that does not change the art.
	if p_path == view_path:
		return
	view_path = p_path
	_drop_view()
	## Before the unit is in the tree (a zombie resolves its type in _init) the scene is
	## NOT built here: place() calls _load_view() anyway, and a part must be inside the tree
	## before its AnimationPlayer can be asked to play.
	if is_inside_tree():
		_load_view()


func _drop_view() -> void:
	## The scene is detached and freed right away, so the new one (or the sprite) never
	## shares the cell with a corpse of the old body for a frame.
	## [P110] The pivot owns the view and goes first, and the lean is dropped with it: the
	## body arriving next must not inherit the pose of the one leaving.
	if _body_pivot != null and is_instance_valid(_body_pivot):
		remove_child(_body_pivot)
		_body_pivot.queue_free()        # takes the view with it
	elif art_view != null and is_instance_valid(art_view):
		remove_child(art_view)          # defensive: a view that somehow has no pivot
		art_view.queue_free()
	_body_pivot = null
	art_view = null
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	_set_lean(0.0)
	_view_tried = false
	queue_redraw()


func _tick_view_tint() -> void:
	## [P28] A view is drawn by its own nodes, so the damage flash reaches it through
	## `modulate` - the sprite path tints its texture instead (see _art_tint()), and both
	## end up showing the same red blink. modulate multiplies down the tree, so the death
	## fade of the unit itself still reaches the scene.
	if art_view == null:
		return
	var tint := _art_tint()
	if art_view.modulate != tint:
		art_view.modulate = tint


func _warn_view() -> void:
	## Once per path: a battle holds several peashooters and they would all complain.
	## Both reasons a view cannot be used land here, and neither is fatal - the sprite (and
	## after that the flat shape) is what the unit draws instead.
	if bool(_view_warned.get(view_path, false)):
		return
	_view_warned[view_path] = true
	push_warning("[View] cannot use " + view_path
		+ " (missing, or its root is not a Node2D) -> the unit keeps its sprite / flat placeholder shape")


func has_view() -> bool:
	## [P28] Subclasses that draw extra markers on top of the flat shape use this (and
	## has_art()) to stand down once real art is in place: the scene IS the body.
	return art_view != null

func _apply_mirror() -> void:
	## [B16] THE VIEW'S HALF OF THE MIRROR, and the only half with a node to write: a sprite is
	## flipped by the transform _draw_body installs, and the flat placeholder shape is symmetric.
	## The BodyPivot is turned rather than the view itself, for the reason the lean rotates it -
	## it sits at this unit's origin, so the flip happens about the body's centre and the view's
	## own scale and position (UnitArt.fit_view) stay untouched.
	## ⚠ unit.scale is NOT the place for this: play_death() tweens it and the belly pose writes
	## it, so the two would fight (see the field's own note).
	## [B33] There is nothing to write any more: the pivot carries ONE composed pose (lean +
	## mirror + stretch together, see _apply_lean), so the mirror simply says "redo the pose".
	_apply_lean()


func _draw_body() -> void:
	if art_view != null:
		## [P28] the view scene IS the body now (and it draws behind us). [P110] it is
		## the BodyPivot that carries the lean, never this function: a child node cannot
		## be turned by draw_set_transform.
		return
	## [P110] The lean is a BODY transform and nothing else. It is set here and taken back
	## off at the end of this function, so the name, the hp bar and the action bars - all
	## drawn after it - never tilt along with the flinch.
	## [B16] ...and so is the MIRROR, in the same transform and for the same reason: a body
	## whose art faces the wrong way for the camp it stands in (雷角兽 on the player's half)
	## is drawn with a negative x scale. Both live in one transform because both are "how this
	## body is drawn right now" and neither may leak into the readouts above it.
	## [P114] The ROLL is a rotation of the SAME body, so it rides this one transform too: the angle
	## applied is _lean + _roll, and `posed` (the "does anything turn this body" gate) now fires on
	## the SUM, so a rolling body whose flinch/stun lean happens to be zero still gets its transform
	## set - without that, a bare walk-roll would silently skip draw_set_transform and paint upright.
	## Named `spin`, not `rotation`, because the latter is Node2D's own property and a local `var` of
	## the same name would shadow it (the SHADOWED_VARIABLE_BASE_CLASS warning).
	var spin := _lean + _roll
	var posed := not is_zero_approx(spin)
	## [B33] The idle STRETCH rides the same transform, on purpose: one place answers "how is
	## this body drawn right now" for all three art levels, and names/bars drawn after the
	## reset never ride it - exactly the rule the lean and the mirror already keep.
	## [B34] The hit JELLY rides it too: it is the same scale channel, multiplied in, so an
	## idle-stretched body rings from wherever it stands and a breath body simply rings.
	## ⚠ While a jelly rings this IS a per-frame picture change (like the stretch under P38) -
	## _apply_lean() is what asks for the redraw, never the _process needs_redraw collector.
	var deform := _idle_stretch * _jelly_scale()
	var stretched := not deform.is_equal_approx(Vector2.ONE)
	var across := -1.0 if mirrored else 1.0
	if posed or mirrored or stretched:
		draw_set_transform(_turn_offset() + _deform_offset(), spin,
			Vector2(across * deform.x, deform.y))
	if _art_texture != null:
		_draw_art()
	else:
		var c := _body_tint()
		if body_shape == Shape.CIRCLE:
			draw_circle(Vector2.ZERO, body_size * 0.5, c)
		else:
			draw_rect(Rect2(Vector2(-body_size * 0.5, -body_size * 0.5),
				Vector2(body_size, body_size)), c)
	if posed or mirrored or stretched:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func move_to_cell(p_col: int, p_row: int) -> void:
	var from_center := Vector2.ZERO
	if grid != null:
		from_center = grid.cell_center(col, row)
	col = p_col
	row = p_row
	_apply_position()
	if grid != null:
		_slide_from(grid.cell_center(col, row) - from_center)


func stack_offset() -> Vector2:
	## [P71] The two stagger numbers moved to BalanceUI: this offset only feeds
	## `position` (_apply_position), while every rule below reads col/row.
	var i := mini(stack_index, BalanceUI.STACK_OFFSET_MAX_INDEX)
	return BalanceUI.STACK_OFFSET_STEP * float(i)


func set_stack_index(index: int) -> void:
	## Called by the grid whenever the occupancy list of this cell changes.
	if stack_index == index:
		return
	stack_index = index
	_apply_position()


func refresh_layout() -> void:
	## Called by the grid when the window resized and the lawn moved under us.
	## position stays a pure visual quantity (col/row/hp/ap are logic).
	_apply_position()


func _apply_position() -> void:
	if grid == null:
		return
	position = grid.cell_center(col, row) + stack_offset() + _move_offset + _shake_offset + _idle_offset
	queue_redraw()


func tag() -> String:
	return display_name


func set_display_name(p_key: String, p_tag: String = "") -> void:
	display_key = p_key
	display_tag = p_tag
	refresh_display_name()


func refresh_display_name() -> void:
	## [P37] Rebuilt from `base_display_name`, never from `display_name`: appending to
	## the previous result made the tag grow one copy per call ("Peashooter #2#2#3")
	## for any unit whose row had no Loc key to fall back on (OPTIMIZATIONS A6).
	if display_key != "":
		base_display_name = Loc.t(display_key, base_display_name)
	display_name = base_display_name + display_tag


func action_text() -> String:
	## [P20] The word under the action bar, in the current language.
	return Loc.t(action_key, action_label) if action_key != "" else action_label


func is_garden_plant() -> bool:
	## [P12] True when this plant came out of the player's garden roster, i.e. when
	## its wounds belong to a persistent instance (see garden.gd).
	return garden_slot >= 0


# ---------------------------------------------------------------- presentation
func _play_spawn_pop() -> void:
	scale = Vector2(0.65, 0.65)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, BalanceUI.ANIM_SPAWN_TIME)


func shake(dir: Vector2, dist: float, p_time: float = BalanceUI.ANIM_SHAKE_TIME) -> void:
	## [P110] The RAW knock-back channel - the two refusals below (dying, no grid) are its
	## contract and every caller inherits them. Named effects go through play_fx() instead;
	## this door stays public for a MOVE's own choreography, which is what the giant zombie's
	## hammer uses (it throws a body DOWN and its victim UP - neither is "forward").
	if _dying or grid == null:
		return
	_shake_offset = dir.normalized() * dist
	_apply_position()
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_method(_set_shake_offset, _shake_offset, Vector2.ZERO, p_time)


func _set_shake_offset(v: Vector2) -> void:
	_shake_offset = v
	_apply_position()


func _slide_from(delta: Vector2) -> void:
	_move_offset = -delta
	_apply_position()
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_method(_set_move_offset, _move_offset, Vector2.ZERO, BalanceUI.ANIM_MOVE_TIME)


func _set_move_offset(v: Vector2) -> void:
	_move_offset = v
	_apply_position()


# ---------------------------------------------------------------- named effects (P110)
func play_fx(p_id: String) -> bool:
	## THE door for named unit effects: "hit" / "hit_shot" / "attack" / "stun" [B33] / "idle" / "death".
	## docs/prompt/FX.md owns the rules in prose, scripts/core/unit_fx.gd owns the table and the
	## priority, and this class owns the channels. Answers whether the effect was TAKEN: a
	## body already playing something better keeps doing it and this call changes nothing.
	return UnitFx.play(self, p_id)


func set_idle_fx(p_name: String) -> void:
	## [B33] The CALLER's door for which idle presentation this body wears ("" = the table's
	## default). Same rule as a death presentation: a call-site choice, NOT a per-unit column
	## (docs/prompt/FX.md §9). A typo is rejected here, once, so the per-frame idle_spec()
	## lookups in _tick_idle never warn.
	var wanted := p_name
	if wanted != "" and not UnitFx.has_idle(wanted):
		push_warning("[Fx] no such idle effect: " + wanted)
		wanted = ""
	idle_fx = wanted
	_idle_spec = UnitFx.idle_spec(wanted)
	## Switching mid-life hands the scale channel back: a breath body must not keep wearing
	## the stretch it was standing in, and vice versa the phase is left where it is.
	_idle_stretch = Vector2.ONE
	_apply_lean()


func melee_fx_id() -> String:
	## [P110e] WHICH PICTURE A MELEE BLOW OF MINE LEAVES WHERE IT LANDS - the id of a drawing
	## under assets/svg/fx/ (Fx.spawn_melee_fx resolves it), or "" for a body with none of its
	## own, which is when the caller draws the generic impact spark.
	##
	## A door on the BODY and not a brawl question, which is why it is NOT spelled
	## `brawl_something` like the four HumanPiece answers: a zombie claws in BOTH modes, and
	## Zombie.act's BITE asks this same door. The base has nothing to say - a plant that swings
	## leaves the generic spark - and the two families that do say it read their own sheet.
	return ""


func ranged_fx_id() -> String:
	## [P110f] THE BEAM a ranged attack of mine draws, or "" for a body that does not attack that
	## way - the third shape, read off the same kind of sheet cell the other two are
	## (PieceDB.COL_RANGED_FX). A body that answers this neither fires a flying shot nor swings:
	## the blow lands on the frame it is thrown (hitscan) and Fx.spawn_beam draws the line between
	## the two bodies. The base has nothing to say; the monster faction is what answers today.
	return ""


func facing_dir() -> Vector2:
	## Which way this body is turned. ZERO on the field means "nobody said", and then the
	## side answers: a plant is drawn looking right (the way the zombies come from) and a
	## zombie looking left (the way it walks) - the same two facts BrawlActor.natural_facing
	## spells out for the brawl.
	if facing != Vector2.ZERO:
		return facing
	return Vector2.LEFT if drawn_left() else Vector2.RIGHT


func drawn_left() -> bool:
	## [B16] WHICH WAY THIS BODY'S PICTURE LOOKS, before anybody deploys it. The answer is the
	## `faces_left` field above - filled at spawn from units.csv's `face` column, whose last
	## resort is the family's own rule (a zombie looks left, a plant right), which is all the
	## two families ever needed before a row could say otherwise.
	##
	## It says NOTHING about which way the body is AIMING: a piece re-aims at its target every
	## tick, so a left-drawn body on the left half still looks at the enemy - `mirrored` is what
	## makes the PICTURE agree with it.
	return faces_left


func _facing_sign() -> float:
	## WHICH SIGN "FORWARD" IS, and the only place that decides it. Rotation is clockwise
	## positive in y-down space, so a body looking right tips forward with +1 and one looking
	## left with -1. A diagonal facing (a brawl piece mid-charge) counts by its x half, which
	## is the half a lean actually reads.
	return 1.0 if facing_dir().x >= 0.0 else -1.0


func lean_pose(p_forward_radians: float, p_time: float) -> void:
	## [P110] The POSE channel: forward-positive, resolved against this body's own facing.
	## Snapped into the pose and eased back upright - the shape shake() has always had, because
	## a flinch that eases IN reads as a shove rather than as a hit.
	## Deliberately says nothing about the grid: a rotation is not ink, so this is the one
	## effect channel that works for a brawl body too (BRAWL.md R1 gives that body's position
	## to its driver and to nobody else).
	## [B25] The `_dying` refusal below is what makes play_death() the ONLY writer of a falling
	## body's lean: a flinch that eased a corpse back upright would undo the topple mid-fall.
	if _dying:
		return
	## [B33] A sway may have left the hinge at the feet; a flinch has always turned about the
	## origin, so the pose that takes over puts the hinge back BEFORE it moves the body.
	_turn_anchor = 0.0
	_set_lean(p_forward_radians * _facing_sign())
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	_lean_tween = create_tween()
	_lean_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lean_tween.tween_method(_set_lean, _lean, 0.0, p_time)


func sway_pose(p_amp_radians: float, p_time: float) -> void:
	## [B33] THE STUN SWAY: rock the body back and forth about its FEET, each pass damped
	## smaller than the last, and settle upright. This is the first pose a LIVING body has
	## whose pivot is not the origin - the topple already proved the feet are the honest
	## hinge, and a dizzy body stands on them the same way. Facing decides only which way
	## the FIRST pass swings; the rock itself is symmetric.
	if _dying:
		return
	_turn_anchor = _feet_offset_y()
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	var dir := _facing_sign()
	if is_zero_approx(dir):
		dir = 1.0
	var amp := p_amp_radians * dir
	## Legs: FX_STUN_SWINGS swinging passes + the one that rocks upright; UnitFx.stun_time()
	## spends the SAME clock over the SAME legs, so the priority expires exactly as the tween
	## lands. from/to are frozen per leg at chain time, hence the running `from`.
	var per := p_time / float(BalanceUI.FX_STUN_SWINGS + 1)
	var from := _lean
	_lean_tween = create_tween()
	_lean_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for _leg in BalanceUI.FX_STUN_SWINGS:
		_lean_tween.tween_method(_set_lean, from, amp, per)
		from = amp
		amp = -amp * BalanceUI.FX_STUN_DAMP
	_lean_tween.tween_method(_set_lean, from, 0.0, per)
	_lean_tween.tween_callback(_finish_sway)


func _finish_sway() -> void:
	## [B33] The hinge goes back to the origin with the effect: a later flinch must not find
	## itself rocking on the feet. If the sway is cut short, the taker says so itself -
	## lean_pose() zeroes the anchor and play_death() writes the feet line unasked.
	_turn_anchor = 0.0


func _set_lean(p_radians: float) -> void:
	_lean = p_radians
	_apply_lean()


func set_roll(p_radians: float) -> void:
	## [P114] The ROLL entry point, the sibling of _set_lean: the live driver hands over the angle it
	## accumulated from the distance walked, and _apply_lean() then turns BOTH body kinds through the
	## SUM _lean + _roll (a view pivot's .rotation, or the sprite's draw transform). Keeping roll in
	## its own field - rather than writing _lean - is what lets a flinch/stun/topple and a roll coexist.
	_roll = p_radians
	_apply_lean()


func _apply_lean() -> void:
	## Two kinds of body, two ways to turn one: a view scene is a NODE (its pivot is rotated),
	## while the sprite and the flat shape are PAINTED (their draw transform is turned - see
	## _draw_body).
	## [B25] ...and BOTH of them get the same one-number compensation, because the pivot is not
	## the origin any more once a topple has chosen its feet: see _turn_offset().
	## [B33] ONE composed writer for the pivot, because the pivot now carries three facts about
	## this body at once - the lean, the mirror and the idle stretch - and each of them needs
	## the SAME hinge compensation: the mirror flips the x scale, the stretch rides it, and the
	## sway's feet anchor must not jitter between whoever wrote last. Whoever changes ANY of
	## the three calls this and nothing else.
	## [B34] ...and a fourth: the hit jelly, multiplied into the same size on the way.
	## [P114] ...and a fifth turner: the ROLL, added into the SAME rotation the lean already sets
	## (the pivot and the sprite path both read _lean + _roll), so a walking roll and a pose tip
	## share one hinge without either stealing the channel from the other.
	if _body_pivot != null and is_instance_valid(_body_pivot):
		var deform := _idle_stretch * _jelly_scale()
		_body_pivot.rotation = _lean + _roll
		_body_pivot.position = _turn_offset() + _deform_offset()
		_body_pivot.scale = Vector2(
			(-1.0 if mirrored else 1.0) * deform.x, deform.y)
	if not has_view():
		queue_redraw()


func _deform_offset() -> Vector2:
	## [B33] The same hinge trick _turn_offset() plays, for a SCALE instead of a rotation: a
	## stretch about the FEET must not lift the body off the lawn, so the whole picture shifts
	## by (f - S∘f) where f is the foot line and S the scale being applied. It is then turned by
	## the lean like everything else on this body, so a swaying, stretched body still keeps its
	## feet down. ZERO for a body at rest size, which is every sprite that never got the
	## stretch presentation - the lean-only picture is exactly the picture it always was.
	## [B34] S is the COMPOSED size (the idle stretch times the hit jelly) - one foot line
	## answers for both writers, so a ringing body keeps its feet on the grass too.
	var deform := _idle_stretch * _jelly_scale()
	if deform.is_equal_approx(Vector2.ONE):
		return Vector2.ZERO
	var f := Vector2(0.0, _feet_offset_y() * (1.0 - deform.y))
	return f.rotated(_lean)


func _turn_offset() -> Vector2:
	## [B25] The compensation that makes an anchor real: the point named by `_turn_anchor` must
	## stay exactly where it was while everything around it turns, so the whole picture is
	## shifted by (anchor - anchor.rotated(lean)). ZERO whenever the anchor is the origin,
	## which is every lean P110 ever had - a flinch is the same picture it always was.
	if is_zero_approx(_turn_anchor) or is_zero_approx(_lean):
		return Vector2.ZERO
	var anchor := Vector2(0.0, _turn_anchor)
	return anchor - anchor.rotated(_lean)


func _feet_offset_y() -> float:
	## [B25] How far BELOW this body's origin its feet are - the question a topple asks once, at
	## the moment it starts falling, and the line a stretched or swaying body is pinned to
	## (`_deform_offset()`).
	## [B36] It used to answer that from the SIZE of the picture ("a sprite is painted centred on
	## the origin, so it ends half a box below it") - the canvas bottom, which sits an eighth of a
	## box under the sole of every sprite that obeys the authoring contract. That is the same guess
	## D111 removed from the shadow, and the user pointed it out there: the topple pivot and the
	## jelly foot line were hinging on empty canvas.
	## [B37] IT IS ONE DOOR NOW (D114): `art_ink().end.y` - the measured ink bottom of whichever of
	## the three art levels is drawing. A view scene still answers exactly (its origin IS its feet
	## line, so its ink ends there), the flat placeholder still fills its box (so the answer is the
	## same number it always was), and only a sprite moves: about 1/8 of a box HIGHER, which is
	## where its picture actually stops. Two modes read it, because both topple and jelly live here.
	return art_ink().end.y


func push_pose(p_forward_pixels: float, p_time: float) -> void:
	## [P110] The KNOCK-BACK half of an effect: forward-positive and facing-relative, handed
	## to shake(). That is where the second refusal comes from: a body with no grid cannot be
	## pushed, which is why a brawl attack is a LEAN and nothing else today (see lean_pose).
	if _dying or grid == null:
		return
	shake(facing_dir() * signf(p_forward_pixels), absf(p_forward_pixels), p_time)


func jelly_pose(p_amp: float, p_time: float) -> void:
	## [B34] THE JELLY CHANNEL: the default hit now also DEFORMS the body — snapped
	## short-and-wide, then ringing back through the reverse, damped to rest about the FEET
	## (docs/prompt/FX.md §2/§3). Like the [B33] idle stretch it scales the PICTURE, never
	## node.scale, and it rides the SAME composed pose as the lean, so both modes read it: the
	## brawl refuses the push, not the squash. `p_amp` is the signed strength the TABLE row
	## carries (ID_HIT passes FX_JELLY_AMP, a pellet's row scales it by FX_PELLET_SCALE):
	## positive starts short-and-wide, which is what being struck looks like.
	if _dying:
		return
	if _jelly_tween != null and _jelly_tween.is_valid():
		_jelly_tween.kill()
	## The row's SIGNED strength: positive squashes first, negative rings from long-and-thin.
	_jelly_str = p_amp
	_jelly = 1.0
	_jelly_tween = create_tween()
	## The clock is a plain linear 1 -> 0 over the flinch's own clock; the SHAPE of the ring
	## (how fast it oscillates, how fast it dies) is the damped cosine in _jelly_scale(),
	## recomputed on every written value. A softer hit rides the SAME clock at a smaller
	## strength - a pellet rings quieter, not shorter: the row scales the amplitude only.
	_jelly_tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	_jelly_tween.tween_method(_set_jelly, 1.0, 0.0, p_time)


func _set_jelly(p_v: float) -> void:
	_jelly = p_v
	_apply_lean()


func _jelly_scale() -> Vector2:
	## [B34] The one formula the jelly ring is: a damped cosine struck at the row's strength
	## (snapped, the way every pose in this file enters) and ringing through the reverse as it
	## dies — with today's constants that reads squash → stretch → a last small squash → rest,
	## and the clock's own expiry lands the ring on the flinch's expiry (the [B33] trick: the
	## table and the tween spend ONE time, ANIM_SHAKE_TIME). At the clock hitting 0 the value
	## is exactly Vector2.ONE, so nothing has to "clean up" the channel, and a fresh hit
	## mid-ring just rewrites the strength and restarts it snapped.
	if is_zero_approx(_jelly):
		return Vector2.ONE
	var e := (1.0 - _jelly) * BalanceUI.FX_JELLY_FREQ
	return Vector2.ONE + Vector2(1.0, -1.0) \
		* (_jelly_str * _jelly * cos(e) * exp(-BalanceUI.FX_JELLY_DAMP * (1.0 - _jelly)))


func fx_priority() -> int:
	## What this body is playing right now, as a number UnitFx compares (-1 = nothing).
	return UnitFx.priority(_fx_id)


func fx_begin(p_id: String, p_time: float) -> void:
	## Taken: this is what the body is doing now. Written by UnitFx alone, because the
	## ordering rule that makes the pair meaningful lives there.
	_fx_id = p_id
	_fx_time = p_time


func fx_settle() -> bool:
	## Back to the idle baseline (play_fx("idle")). Refused while something better is playing
	## or while the body is dying, so a caller cannot breathe a corpse back to life.
	if _fx_blocks_idle():
		return false
	_fx_id = ""
	_fx_time = 0.0
	return true


func fx_body_plays(p_id: String) -> bool:
	## [P110] THE FALLBACK DOOR behind this whole feature: "does my own body have an animation
	## for this event?" Asked of the view scene itself (UnitArt.play_view_clip) and never of a
	## list kept beside the effect table - a part that grows a "hit" clip must be found by this
	## question the day it is authored, not the day somebody remembers to register it. False
	## for a sprite or a flat shape, which is what every unit is today.
	return UnitArt.play_view_clip(art_view, p_id)


func _tick_fx(p_delta: float) -> void:
	## The effect clock. Nothing else expires an effect: each pose channel eases back on its
	## own tween, and this is what says the effect AS A WHOLE is over - which is what lets the
	## idle sway start again.
	if _fx_time <= 0.0:
		return
	_fx_time = maxf(0.0, _fx_time - p_delta)
	if _fx_time <= 0.0:
		_fx_id = ""


func _fx_blocks_idle() -> bool:
	## The priority rule seen from the baseline's side: 死亡 > 受击 > 被射 > 眩晕 > attack > 空闲,
	## so the idle baseline stands down for anything above it. A dying body never breathes again.
	return _dying or (_fx_id != "" and _fx_id != UnitFx.ID_IDLE)


# ---------------------------------------------------------------- life
func is_alive() -> bool:
	return hp > 0 and not _dying


func is_dying() -> bool:
	## [P110] The other half of is_alive(), on its own because the named effects need exactly
	## this half: the blow that KILLS a body still has to land on it. take_damage() writes hp 0
	## first and the engine calls play_death() later, so "is_alive() is false" and "this body is
	## already falling" are two different moments - a flinch belongs to the first one.
	return _dying


func take_damage(amount: int, p_source: Unit = null, _p_opts: Dictionary = {}) -> void:
	## [P34] The third argument is where a hit says HOW it lands, not only how hard:
	## "pierce_armor" (a fume-shroom breath walks straight over a screen door). The
	## base ignores it on purpose - a plant has no armour to skip - but the shape is
	## shared so Projectile can hand the same riders to anything it hits. Zombie reads
	## it (see its override).
	## [P77] The second key a hit may carry is "straight_shot", and it belongs to the
	## screen door alone: Projectile says true, PultProjectile false, and every source
	## that is not a shot at all says nothing - which is exactly what the door obeys.
	## [B11] 防御: the number the caller hands in is the ATTACK, and what lands on this body is
	## the ratio of the two (Balance.hurt_after_defence, the one damage formula - docs/NUMBERS.md
	## §2 spells the whole reading out). A body with no defence takes the blow as it was sent,
	## plus the formula's own one point, which is what keeps this column an ADDITION to the game
	## rather than a rebalance of it.
	##
	## THE ORDER: the no-op guards first, the formula second, the ultimate's immunity last. A call
	## that used to change nothing (0, negative, or an already-fallen body) must not start dealing
	## the formula's minimum point of damage.
	##
	## WHAT IT COVERS: every HP loss that comes through this door, including the rage's bleed in a
	## brawl (BrawlActor.drain) - defence protects the body, not one kind of blow. What it does NOT
	## cover is anything that writes hp directly (the 1/3 execution, a chomp that swallows a body
	## whole): those are not damage, they are a rule.
	if amount <= 0 or not is_alive():
		return
	amount = Balance.hurt_after_defence(amount, defence)
	if ult_immune:
		## [P30-B] 铁壁: the wall-nut's own ultimate refuses the hit outright.
		## Nothing is charged by it either - an immune hit is not a hit.
		return
	if p_source != null:
		last_attacker = p_source
	hp = maxi(0, hp - amount)
	_flash = 1.0
	## [P30-B] A "hit" ultimate (the wall-nut's 铁壁, per its 大招充能 cell) feeds
	## on exactly this moment: one hit taken, one point of charge.
	if ult_charge_source() == "hit":
		charge_ultimate()
	queue_redraw()
	if hp <= 0:
		died.emit(self)


func heal(amount: int) -> int:
	## [B30] The mirror of take_damage's write, and the ONE door that puts HP back: the ceiling
	## is this body's own max_hp, and 0 / a negative / a fallen body change nothing. It ANSWERS
	## how many points actually landed rather than the number the healer sent, because the log
	## and the "+N" both want the truth about a body that was two points off whole (the same
	## reading WallPlant's 铁壁 already gives by hand: `mini(max_hp, hp + n)`).
	##
	## WHAT IT DOES NOT DO is the presentation - Fx owns that, at the call that knows where the
	## mend came from - and what it does not RESPECT is `ult_immune`: that flag is the wall-nut's
	## answer to a blow, and a mend is not a blow.
	if amount <= 0 or not is_alive():
		return 0
	var before := hp
	hp = mini(max_hp, hp + amount)
	if hp != before:
		queue_redraw()
	return hp - before


func apply_hit_effects(p_effects: Dictionary, _p_opts: Dictionary = {}) -> void:
	## [P34] The status half of a hit, called by Projectile right after the damage on
	## BOTH impact paths (the staged flight and the synchronous resolver). The base has
	## nothing to hold: only a zombie keeps effect counters today (Zombie.effect_rounds),
	## and only its type knows what it is immune to. An empty dict - which is what every
	## plant that shoots today hands over - returns here without a sound.
	## [P77] The second argument is the SAME package the damage got, so a body cannot
	## refuse a rider for a hit it just let through the door (Zombie reads it).
	if p_effects.is_empty():
		return


func play_death(p_fx: String = "") -> void:
	## Called by GameManager instead of queue_free() so the unit can play itself out.
	## [B25] THE DEATH EFFECT. Which presentation this body gets is answered by UnitFx's death
	## table: the caller's `p_fx` first (that is how the shovel asks for a plain fade - a plant
	## that was simply lifted out of the lawn has not fallen over), and otherwise the default
	## 倒地并淡出. A unit does NOT get its own row: docs/prompt/FX.md §9 keeps one table for every
	## body, and a part that wants to die its own way grows an animation clip instead.
	if _dying:
		return
	_dying = true
	hp = 0
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_move_offset = Vector2.ZERO
	_shake_offset = Vector2.ZERO
	## [P110] The pose goes with the other two, and the idle sway stops for good: _dying is
	## what _fx_blocks_idle() answers first, so a falling body is never also breathing.
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	## [P114] The roll is released with the lean before the topple begins: a body that died mid-stride
	## would otherwise start its fall already tipped by however far its last walk had turned it, and the
	## death pose wants to own the whole rotation from upright. Cleared as a plain field (no _apply_lean
	## call here) because the _set_lean(0.0) directly below refreshes both channels through one sum.
	_roll = 0.0
	_set_lean(0.0)
	var fx := UnitFx.death_spec(p_fx)
	var fade := float(fx["fade_time"])
	var tw := create_tween()
	if not fx.has("fall"):
		## THE OLD DEATH, still exactly right where nothing fell: alpha and scale go together.
		tw.set_parallel(true)
		tw.tween_property(self, "modulate:a", 0.0, fade)
		var shrink := float(fx["shrink"])
		tw.tween_property(self, "scale", Vector2(shrink, shrink), fade)
	else:
		## TOPPLE: the body turns about its own FEET (the anchor is read once, here, before
		## anything moves), rocks a little past flat and settles, and only then fades out where
		## it lies. NO scale tween: a corpse flat on the lawn is a body, not a balloon letting
		## out - and shrinking it would pull the picture off the ground it just reached.
		_turn_anchor = _feet_offset_y()
		var ground := float(fx["fall"]) * _facing_sign()
		var rock := ground * (1.0 + float(fx["overshoot"]))
		tw.tween_method(_set_lean, _lean, rock, float(fx["fall_time"]))
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_method(_set_lean, rock, ground, float(fx["settle_time"]))
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 0.0, fade)
	tw.chain().tween_callback(queue_free)


# ---------------------------------------------------------------- action points
func bar_shown() -> bool:
	## [P30-A] Whether the generic bar under this unit is drawn at all. A plant's
	## basic attack needs NO bar - firing three times a round is AP accounting,
	## not progress towards anything (the user's call). A walking zombie keeps its
	## move-progress bar (Zombie.bar_shown). [P30-B] The ULTIMATE bar is a
	## separate, plant-only drawing (ult_shown / _draw_ult_bar), so the two bars
	## can never fight over the one slot.
	return false


func action_bar_ratio() -> float:
	## [P30-A] What the generic bar under the unit is filled to: the AP still
	## unspent this round. Zombies that are WALKING show their move progress
	## instead (override).
	if threshold <= 0:
		return 0.0
	return clampf(float(ap) / float(BalanceBattle.ROUND_AP), 0.0, 1.0)


func bar_text() -> String:
	## [P30-A] The line under the bar, in the old "<word> a/b" shape: a zombie's
	## bar reads "ADVANCE 1/3"; the (unshown) plant reading would be "FIRE 2/3".
	return "%s %d/%d" % [action_text(), ap, BalanceBattle.ROUND_AP]


func can_act() -> bool:
	## [P39] The third clause is new: a unit that is busy (a chomper chewing) holds its
	## whole action phase, exactly like a frozen zombie holds its own.
	return threshold > 0 and is_alive() and stand_down_rounds <= 0


func stand_down_text() -> String:
	## [P39] Why `can_act()` said no, in the log's own words. Only the busy case has a
	## note to add; the wall-nut's answer stays the sentence the log always printed.
	if stand_down_rounds > 0 and stand_down_note != "":
		return "%s (%d round(s) left)" % [stand_down_note, stand_down_rounds]
	return "threshold=0 -> blocking"


func has_target() -> bool:
	## Overridden by units that can idle (e.g. a peashooter with nothing to shoot).
	return true


func grant_ap() -> void:
	## [P30-A] Called once per unit when its side's action phase opens (GameManager).
	## AP never carry over: whatever is unspent here is gone at the end of the round.
	ap = BalanceBattle.ROUND_AP
	queue_redraw()


func can_afford_action() -> bool:
	## [P30-A] One use is payable right now. The threshold > 0 guard doubles as the
	## engine loop's death-loop guard: a unit that must never act uses threshold = 0
	## (the wall-nut) instead of a free action, because a 0-cost skill would let the
	## `while ap >= threshold` loop spend AP it never loses.
	return threshold > 0 and ap >= threshold and is_alive()


func spend_action_ap() -> void:
	ap -= maxi(1, threshold)
	queue_redraw()


# ---------------------------------------------------------------- ultimate (P30-B)
func has_ultimate() -> bool:
	## [P30-B] True when this unit LOADS an ultimate: a code the skill sheet has
	## an ULTIMATE row for, AND a script that can actually run it. The second
	## half is the same "the sheet names numbers, the code acts" wiring as the
	## playable flag: a future plant may hold a 大招代码 its script has no
	## implementation for, and that unit must draw no bar rather than a bar that
	## fills and never pays out.
	return ult_code != "" and ult_implemented()


func ult_implemented() -> bool:
	## The script's side of the wiring (overridden by the plants that run an
	## ultimate; act_ultimate() is only ever called when this says true).
	return false


func ult_charge_source() -> String:
	## What fills this bar, straight from the sheet's 大招充能 phrase:
	## "cast" (basic-skill uses) or "hit" (hits taken). Unknown = "cast".
	return Balance.plant_ult_charge(ult_code) if ult_code != "" else ""


func charge_ultimate(amount: int = BalanceBattle.ULT_CHARGE_PER_CAST) -> void:
	## The ONE charge entry point. The bar CAPS at max - it does not bank extra
	## casts and does not expire with the round (unlike AP); a full bar simply
	## waits for the next action phase to fire in.
	if not has_ultimate() or _dying:
		return
	ult_charge = mini(ult_charge + maxi(0, amount), ult_charge_cap())
	queue_redraw()


func ult_charge_cap() -> int:
	## [P30-B] How full the bar must get before the ultimate fires. Today this is
	## the one global BalanceBattle.ULT_CHARGE_MAX for every ultimate; the day a sheet
	## column prices them individually, this is the single function to extend.
	return BalanceBattle.ULT_CHARGE_MAX


func ult_ready() -> bool:
	return has_ultimate() and ult_charge >= ult_charge_cap()


func ult_can_fire() -> bool:
	## [P30-B] Whether firing NOW would actually do something - the engine will
	## not spend a full bar on an empty effect. The default only requires a real
	## value (a code whose 大招数值 resolves to 0 is a wiring bug, and a free
	## ult is not a feature); units that need prey on the lane override this
	## and call back into it via super.
	return BalanceBattle.plant_ult_value(ult_code) > 0


func consume_ult_charge() -> void:
	ult_charge = 0
	queue_redraw()


func act_ultimate() -> String:
	## Performs the loaded ultimate. Returns a human-readable log fragment,
	## exactly like act(). Only ever called by the engine when ult_ready().
	return "(no ultimate)"


func ult_bar_ratio() -> float:
	## What the ultimate bar is filled to (the RAW logic value; the drawer
	## smooths it, see _ult_display_ratio).
	if not has_ultimate():
		return 0.0
	return clampf(float(ult_charge) / float(maxi(1, ult_charge_cap())), 0.0, 1.0)


func ult_bar_text() -> String:
	## The line under the ultimate bar: the sheet's 大招名称 plus the charge, so
	## "豌豆风暴 7/10" reads the same on the board as in the almanac.
	return "%s %d/%d" % [ult_name_text(), ult_charge, ult_charge_cap()]


func ult_name_text() -> String:
	## The ultimate's name in the CURRENT language: the plant row's 大招 prose
	## columns come first (they have an English twin); the skills.csv 大招名称 is
	## the fall-back, so a loadout the sheet only names by code still reads well.
	var text := ""
	if ult_id != "":
		text = PlantDB.text(ult_id, "ultimate")
	if text == "":
		text = SkillDB.ult_name(ult_code)
	return Loc.t("action.ult") if text == "" else text


func ult_shown() -> bool:
	## The plant bar of [P30-B]: drawn by Unit._draw() for any plant that loads
	## an ultimate. Zombies never do (the confirmed scope of P30-B).
	return not is_zombie and has_ultimate()


func shout(p_text: String, p_is_ult: bool = false) -> void:
	## [P112] PUT A SHOUT ON THIS BODY. The engine calls it at the cast site it owns (the turn
	## battle's auto-ult, the brawl/war actor's ultimate / devour / whirlwind) with the NAME already
	## resolved by the language layer; the body just wears the balloon and lets _process age it out.
	## A caller that hands an empty text (a piece whose 大招 cell nobody filled) is silently refused
	## - no balloon, so a shout is never a blank bubble over a head - and a dying body never shouts,
	## because play_death() has already taken the picture down.
	if p_text == "" or _dying:
		return
	_shout_text = p_text
	_shout_ult = p_is_ult
	_shout_time = BalanceUI.SHOUT_TIME_ULT if p_is_ult else BalanceUI.SHOUT_TIME
	queue_redraw()


func ult_shout_text() -> String:
	## [P112] The ULTIMATE's name for a shout, read off the SAME door the ult bar already uses
	## (ult_name_text: the plant row's 大招 prose with its English twin, then skills.csv, then a
	## generic label). The base answers for the turn engine; a brawl piece overrides to read its
	## own sheet (HumanPiece.ult_shout_text), which is where its new 大招 column lives.
	return ult_name_text()


func skill_shout_text() -> String:
	## [P112] The SKILL's name for a shout. The base says NOTHING: a turn-mode plant's act() is its
	## ordinary attack, and the user's rule is that a normal blow stays silent. Only the real-time
	## engine shouts a skill - the two shapes that REPLACE the blow (a devour, a whirlwind) - and a
	## HumanPiece overrides this to answer its sheet's 技能.
	return ""


func act() -> String:
	## Performs this unit's action. Returns a human-readable log fragment.
	return "(no action)"


func has_skill() -> bool:
	## [P15] True when this unit has a SKILL an energy bean can resolve (the
	## wall-nut has none, which is why a bean refuses to work on it).
	return false


func resolve_skill_once() -> bool:
	## [P15] One instant resolution of the skill, used by the energy bean (which
	## calls it ENERGY_BEAN_HITS times). Returns false when there was nothing to do
	## - no target, or no skill at all - so the bean is not spent on a wasted use.
	return false


# ---------------------------------------------------------------- drawing
func _process(delta: float) -> void:
	## [P38] OPTIMIZATIONS B2: this used to end in an unconditional queue_redraw(), which
	## made EVERY unit rebuild its draw commands 60 times a second whether or not anything
	## it paints had changed. Only three things in _draw() move on their own between steps,
	## and they are collected here:
	##   * the damage flash - including the frame where it reaches 0, which is the one that
	##     paints the unit without the red tint again;
	##   * the two bars, but only while they are still smoothing;
	##   * the breathing squash, which _draw_art() reads out of _idle_phase (see
	##     _breath_shown() for which units that is).
	## [B33] A fourth thing can move the picture - the idle STRETCH - and it is deliberately NOT
	## collected here: _tick_idle() only asks for a redraw on the frame its value actually
	## changed, through the same door every pose uses (_apply_lean).
	## Everything else the drawer looks at is a STEP (hp, armour, name, AP, a new body) and
	## already redraws at its own call site. The idle BOB is deliberately NOT one of them:
	## it moves the node, not the picture.
	var needs_redraw := false
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * BalanceUI.FLASH_DECAY)
		needs_redraw = true
	## [P112] The shout balloon ages out on the same decay channel as the flash: it is the one
	## thing in _draw() that moves between steps for no reason but time, so it asks for a redraw
	## only while it is still up (and on the frame it reaches 0, which paints the body without it).
	if _shout_time > 0.0:
		_shout_time = maxf(0.0, _shout_time - delta)
		needs_redraw = true
	var target_ratio := action_bar_ratio()
	if absf(_display_ratio - target_ratio) > 0.0005:
		_display_ratio = lerpf(_display_ratio, target_ratio,
			clampf(delta * BalanceUI.ANIM_BAR_SMOOTH, 0.0, 1.0))
		if absf(_display_ratio - target_ratio) < 0.005:
			_display_ratio = target_ratio
		needs_redraw = true
	## [P30-B] the ultimate charge bar smooths on its own channel (see above)
	var target_ult := ult_bar_ratio()
	if absf(_ult_display_ratio - target_ult) > 0.0005:
		_ult_display_ratio = lerpf(_ult_display_ratio, target_ult,
			clampf(delta * BalanceUI.ANIM_BAR_SMOOTH, 0.0, 1.0))
		if absf(_ult_display_ratio - target_ult) < 0.005:
			_ult_display_ratio = target_ult
		needs_redraw = true
	_tick_fx(delta)            # [P110] expires the named effect before the idle asks about it
	_tick_idle(delta)
	if _breath_shown() and not _fx_blocks_idle():
		## [P110] A body holding a pose is not breathing, and asking for a redraw of a picture
		## that is deliberately frozen is exactly the waste P38 took out of this loop.
		needs_redraw = true
	_tick_view_tint()          # [P28] the damage flash of a scene-drawn body
	if needs_redraw:
		queue_redraw()


func _breath_shown() -> bool:
	## [P38] Whether this unit's OWN picture moves with _idle_phase. _draw_art() is the
	## only drawer that reads the phase (the breathing squash), so a unit whose body is a
	## view scene, or the flat placeholder shape, paints the same picture every frame and
	## needs no redraw to keep breathing. A zombie never advances the phase at all
	## (_tick_idle stands down for it). These units still move: the bob is a position
	## change, which the canvas item transform handles by itself.
	## [B33] ...and never under the stretch presentation: there the phase moves the body's
	## SHAPE through the draw transform, and _apply_lean() asks for that redraw the moment the
	## scale actually changed. Leaving this true would be the very waste P38 took out.
	return not is_zombie and not has_view() and has_art() and not _idle_is_stretched()


func _tick_idle(delta: float) -> void:
	## THE BASELINE - what a body does when nothing is happening to it. [B33] It is a
	## PRESENTATION now, not one shape: the default rocks the picture between long-and-thin and
	## short-and-wide (below), the old breath (a slow bob plus a tiny sway) is one `set_idle_fx`
	## away. Purely cosmetic either way: it only feeds the draw transform or the position.
	## P11 scope: plants breathe, zombies keep their old static stance.
	if is_zombie:
		return
	if _fx_blocks_idle():
		## [P110] Lowest priority: while a flinch or a blow is playing the sway stands down,
		## AND lets go of whatever it was holding, so the two never pull the body at once. The
		## phase is left where it is rather than reset, so breathing resumes without a jump.
		if not _idle_offset.is_zero_approx():
			_idle_offset = _idle_offset.lerp(Vector2.ZERO,
				clampf(delta * BalanceUI.FX_IDLE_STANDDOWN, 0.0, 1.0))
			_apply_position()
		if _idle_is_stretched() and not _idle_stretch.is_equal_approx(Vector2.ONE):
			## [B33] the same letting-go for the SHAPE channel: an effect owns the body's size
			## for as long as it lasts, so the stretch releases it the way the bob does.
			_idle_stretch = _idle_stretch.lerp(Vector2.ONE,
				clampf(delta * BalanceUI.FX_IDLE_STANDDOWN, 0.0, 1.0))
			_apply_lean()
		return
	if _idle_is_stretched():
		## [B33] THE NEW DEFAULT (docs/prompt/FX.md §3b): the picture rocks between
		## long-and-thin and short-and-wide, one sine and its own clock - long goes with thin,
		## then the reverse. No bob and no sway with it: this presentation IS the body changing
		## shape rather than moving, and two motions on one baseline would read as jitter.
		## The size goes through the DRAW TRANSFORM and never through node.scale - see the field.
		_idle_phase += delta * float(_idle_spec["speed"])
		var s := sin(_idle_phase) * float(_idle_spec["amp"])
		var want_size := Vector2(1.0 - s, 1.0 + s)
		if want_size.is_equal_approx(_idle_stretch):
			return
		_idle_stretch = want_size
		_apply_lean()
		return
	_idle_phase += delta * BalanceUI.IDLE_SPEED
	var want := Vector2(sin(_idle_phase * 0.5) * BalanceUI.IDLE_SWAY,
		sin(_idle_phase) * BalanceUI.IDLE_BOB)
	if want.is_equal_approx(_idle_offset):
		return
	_idle_offset = want
	_apply_position()


func _idle_is_stretched() -> bool:
	## [B33] Whether the baseline this body wears is the shape one rather than the moving one.
	## Asked of the cached table row, never of a name kept here - but a THIRD presentation
	## still needs a third leg in _tick_idle(): the table says what to wear, only a channel
	## can wear it (docs/dev/FX.md §10).
	return _idle_spec.get("kind", "") == UnitFx.IDLE_STRETCH


func _body_tint() -> Color:
	return body_color.lerp(BalanceUI.COLOR_FLASH, _flash)


func _art_tint() -> Color:
	## The sprite brings its own colours, so the damage flash modulates it from
	## white instead of replacing the colour (that is what _body_tint does).
	return Color.WHITE.lerp(BalanceUI.COLOR_FLASH, _flash)


func _draw() -> void:
	_draw_body()
	_draw_name()
	_draw_hp_bar()
	if bar_shown():         # [P30-A] no AP bar for plants; the walking zombie has one
		_draw_action_bar()
	if ult_shown():          # [P30-B] the plant slot carries the ULTIMATE charge bar
		_draw_ult_bar()
	_draw_shout()          # [P112] the shout balloon, painted LAST so it rides above every layer


func art_box() -> float:
	## [B14] How many pixels across this body's picture is drawn - the square a sprite and a view
	## scene are both fitted into. One owner for it because things have started asking WHERE a
	## point of the picture is: the muzzle of a beam (Fx.beam_muzzle) has to walk the horn's own
	## spot out of the art, and the brawl draws a piece at BrawlLayout.piece_scale (art_scale)
	## rather than at the design size.
	return BalanceUI.UNIT_ART_SIZE * art_scale


func art_ink() -> Rect2:
	## [B36] What this body ACTUALLY PAINTS, in the local pixels of the art_box() square that
	## _draw_body() fills - so the origin is the body's centre and y points down, which is exactly
	## the space a ground anchor is asked about. Three art levels, in the order _draw_body() tries
	## them: a view scene answers for itself (fit_view() put its origin ON its own feet line), a
	## sprite is measured pixel by pixel (UnitArt.ink_rect over [B35]'s door), and the flat
	## placeholder paints its whole box, so its ink IS body_size.
	## WHY THE DOOR EXISTS: the [B17-fix] anchor walked down to "half a box below the mark", which
	## is the CANVAS bottom. Every sprite keeps 16 px of canvas under its sole (VIEW_ART_FEET_LINE
	## = 112 of 128), so that guess sat an eighth of a box below the feet of every body that obeys
	## the contract - the user's report about the militia, and the reason for D111.
	var box := art_box()
	var top_left := Vector2(-box * 0.5, -box * 0.5)
	if art_view != null and is_instance_valid(art_view):
		return Rect2(top_left, Vector2(box, art_view.position.y - top_left.y))
	if _art_texture != null:
		return UnitArt.ink_rect(art_path, top_left, box)
	return Rect2(Vector2(-body_size * 0.5, -body_size * 0.5), Vector2(body_size, body_size))


func _draw_art() -> void:
	## The breathing squash lives here, in the drawn size, and never touches
	## `scale` - that one belongs to the spawn / death tweens.
	## [B33] Not under the stretch presentation: that one's shape lives in the DRAW TRANSFORM
	## instead (both axes, about the feet) so that the flat placeholder shape rocks exactly the
	## way a sprite does. A body wears one presentation or the other, never both - otherwise
	## the two squashes would multiply.
	var stretch := 1.0
	if not _idle_is_stretched():
		stretch = 1.0 + sin(_idle_phase) * BalanceUI.IDLE_BREATHE
	var box := Vector2(art_box(), art_box() * stretch)
	draw_texture_rect(_art_texture, Rect2(-box * 0.5, box), false, _art_tint())


func _draw_name() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(-48.0, BalanceUI.UNIT_NAME_Y), display_name,
		HORIZONTAL_ALIGNMENT_CENTER, 96.0, BalanceUI.FONT_SIZE_UNIT_NAME, BalanceUI.COLOR_TEXT)


func _draw_hp_bar() -> void:
	var w := BalanceUI.UNIT_BAR_WIDTH
	var h := BalanceUI.UNIT_BAR_HEIGHT
	var top := BalanceUI.UNIT_HP_BAR_Y
	draw_rect(Rect2(Vector2(-w * 0.5, top), Vector2(w, h)), BalanceUI.COLOR_HP_BG)
	var ratio := 1.0 if max_hp <= 0 else clampf(float(hp) / float(max_hp), 0.0, 1.0)
	if ratio > 0.0:
		draw_rect(Rect2(Vector2(-w * 0.5, top), Vector2(w * ratio, h)), BalanceUI.COLOR_HP_FILL)


func _draw_action_bar() -> void:
	## Only ever called while bar_shown() is true (see Unit._draw): the "no action"
	## label for the wall-nut is gone with the plants' AP bar - a plant simply draws
	## nothing under its hp bar now.
	var w := BalanceUI.UNIT_BAR_WIDTH
	var h := BalanceUI.UNIT_BAR_HEIGHT
	var top := BalanceUI.UNIT_ACTION_BAR_Y
	draw_rect(Rect2(Vector2(-w * 0.5, top), Vector2(w, h)), BalanceUI.COLOR_BAR_BG)
	if _display_ratio > 0.0:
		draw_rect(Rect2(Vector2(-w * 0.5, top), Vector2(w * _display_ratio, h)), BalanceUI.COLOR_BAR_FILL)
	draw_string(ThemeDB.fallback_font, Vector2(-48.0, top + h + 12.0), bar_text(),
		HORIZONTAL_ALIGNMENT_CENTER, 96.0, BalanceUI.FONT_SIZE_BAR, BalanceUI.COLOR_BAR_FILL)


func _draw_ult_bar() -> void:
	## [P30-B] The ultimate charge bar, in the slot under the hp bar (a plant
	## never draws the generic bar there, so the two never collide). Gold reads
	## "charge", the full bar additionally the 大招's name - the almanac words,
	## the sheet's numbers.
	var w := BalanceUI.UNIT_BAR_WIDTH
	var h := BalanceUI.UNIT_BAR_HEIGHT
	var top := BalanceUI.UNIT_ACTION_BAR_Y
	draw_rect(Rect2(Vector2(-w * 0.5, top), Vector2(w, h)), BalanceUI.COLOR_ULT_BG)
	if _ult_display_ratio > 0.0:
		draw_rect(Rect2(Vector2(-w * 0.5, top),
			Vector2(w * _ult_display_ratio, h)), BalanceUI.COLOR_ULT_FILL)
	draw_string(ThemeDB.fallback_font, Vector2(-48.0, top + h + 12.0), ult_bar_text(),
		HORIZONTAL_ALIGNMENT_CENTER, 96.0, BalanceUI.FONT_SIZE_BAR, BalanceUI.COLOR_ULT_FILL)


func _draw_shout() -> void:
	## [P112] THE SHOUT BALLOON. A rounded-enough rectangle of the sheet's own WORDS over the head,
	## with a little triangle pointing back down at it - a name shouted, nothing more (the user's
	## rule: 文案只喊名字). It follows the body for free because it is painted in the body's local
	## space, exactly like the name it sits above; that is the whole reason this lives on Unit and
	## not on Fx (whose floating text drops where it spawned and would NOT walk with a charging slime).
	##
	## It is anchored to the NAME's fixed Y and a fixed font, NOT to art_scale - a name does not
	## swell with a brawl body's bigger picture and neither does its shout, so the two keep one
	## head-line in every mode. The last SHOUT_FADE seconds fade the whole balloon out together, so
	## the only per-frame work is one colour multiplier and one polygon.
	if _shout_time <= 0.0 or _shout_text == "":
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var size := BalanceUI.SHOUT_FONT_SIZE
	var tw := font.get_string_size(_shout_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pad_x := BalanceUI.SHOUT_PAD_X
	var pad_y := BalanceUI.SHOUT_PAD_Y
	var w := tw + pad_x * 2.0
	var h := float(size) + pad_y * 2.0
	var bottom := BalanceUI.SHOUT_BOTTOM_Y
	var box := Rect2(Vector2(-w * 0.5, bottom - h), Vector2(w, h))
	var fade := clampf(_shout_time / BalanceUI.SHOUT_FADE, 0.0, 1.0)
	var bg := BalanceUI.COLOR_SHOUT_BG
	# the tail first, so the box's lower edge overlaps and hides its base - one clean balloon
	var tail := PackedVector2Array([
		Vector2(-BalanceUI.SHOUT_TAIL_H, bottom),
		Vector2(BalanceUI.SHOUT_TAIL_H, bottom),
		Vector2(0.0, bottom + BalanceUI.SHOUT_TAIL_H),
	])
	draw_colored_polygon(tail, Color(bg, bg.a * fade))
	draw_rect(box, Color(bg, bg.a * fade))
	var border := (BalanceUI.COLOR_SHOUT_BORDER_ULT if _shout_ult
		else BalanceUI.COLOR_SHOUT_BORDER)
	draw_rect(box, Color(border, border.a * fade), false, 1.0)
	var text_col := (BalanceUI.COLOR_SHOUT_TEXT_ULT if _shout_ult
		else BalanceUI.COLOR_SHOUT_TEXT)
	# draw_string's position is the baseline, so sit it pad_y above the box's bottom edge, centered
	draw_string(font, Vector2(-tw * 0.5, bottom - pad_y), _shout_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(text_col, text_col.a * fade))
