class_name BalanceUI
extends RefCounted
## [P28-UI] The presentation half of Balance, split out of scripts/balance/balance.gd
## (docs/OPTIMIZATIONS.md C9, at the user's request).
## The split rule: a constant lives here when ONLY drawing / layout code reads it -
## pixels, fonts, colours and animation timings the player sees. Balance keeps the
## numbers and tables that decide the GAME: economy, unit stats and their sheet
## fall-backs, tools, items, shop, garden rules, file paths.
## Nothing in balance.gd reads this file, so the two classes cannot form a cycle.
## [P69] The rule is not "one file per reader" either: the audio vocabulary left for
## its own BalanceAudio (scripts/balance/balance_audio.gd) by the same test, so this file and
## that one are two cuts of C9, not two halves of one.

# ---------------------------------------------------------------- board colours
const COLOR_LAWN_A := Color(0.34, 0.60, 0.26)
const COLOR_LAWN_B := Color(0.30, 0.55, 0.23)
## [P34] The two row-tint knobs the MVP used to brighten its one live row and sink
## the rest are gone: the whole lawn plays now, so the checkerboard stands alone.
const COLOR_GRID_LINE := Color(0.20, 0.38, 0.16)
const COLOR_HOVER := Color(1.0, 1.0, 0.40, 0.30)
const COLOR_HOVER_LINE := Color(1.0, 1.0, 0.55, 0.85)

const COLOR_TEXT := Color(0.95, 0.95, 0.95)
const COLOR_TEXT_DIM := Color(0.65, 0.68, 0.72)
const COLOR_BRAIN := Color(0.90, 0.45, 0.65)

const COLOR_PEA := Color(0.80, 0.95, 0.35)

## [P34] How a frozen zombie looks: the body colour and the sprite both pull towards
## this blue by FREEZE_TINT while the rider binds (Zombie._body_tint / _art_tint).
## Only the drawing reads them, so they live here and not in Balance.
const COLOR_FREEZE := Color(0.45, 0.78, 1.00)
const FREEZE_TINT := 0.45

## [P39] How a plant that is BUSY looks (the chomper mid-chew): the same trick as the
## freeze rider above, in a green that reads "stuffed" rather than "cold". Only the
## drawing reads them, so they live here and not in Balance.
const COLOR_CHEW := Color(0.55, 0.85, 0.45)
const CHEW_TINT := 0.35

## [P68] How an ENRAGED zombie looks (the newspaper that lost its paper): the same trick
## again in the red the reference game paints that sprite, because our sheet gives the
## newspaper no picture of its own to swap into and its TYPE does not change - the rage is
## two numbers, so without a tint the only way to notice it is to watch the move bar.
## 0.40 sits between the chew and the freeze: strong enough to read at a glance, weak
## enough that the hp bar over it still says how hurt the body is.
const COLOR_RAGE := Color(0.95, 0.30, 0.22)
const RAGE_TINT := 0.40

## [P49] The melon a pult throws: the rind green of the projectile itself (the icy one
## reuses COLOR_FREEZE above, exactly like the snow pea's shot). Only the drawing reads
## it, so it lives here and not in Balance.
const COLOR_MELON := Color(0.36, 0.56, 0.22)
## [P89] THE SUN DROP. Sizes, speeds and colours - pixel values, so they belong here and
## not in a content sheet (AGENTS §2). The RULES (how many may lie around, how long the
## auto-collect waits) are BalanceBattle.SUN_DROP_MAX / SUN_AUTO_ROUNDS_*.
const SUN_DROP_RADIUS := 17.0           # the click target and the fall-back disc
const SUN_DROP_CLICK_SLACK := 1.25      # a click slightly beside it still counts
const SUN_DROP_ART_SIZE := Vector2(34.0, 34.0)
const SUN_DROP_FALL_SPEED := 90.0       # px/s: slow enough to be seen coming (天际)
const SUN_DROP_TOSS_TIME := 0.35        # seconds of hop for a producer's own sun (落地)
const SUN_DROP_TOSS_LIFT := 26.0        # px the hop rises above the straight line
const SUN_DROP_SKY_MARGIN := 60.0       # px above the lawn a 天际 sun enters from
const COLOR_SUN_DROP := Color(1.00, 0.86, 0.28)
const COLOR_SUN_DROP_CORE := Color(1.00, 0.97, 0.72)
## [P51] The cabbage a 卷心菜投手 throws: the same thrown ball in a paler, bluer green.
## The two are told apart by that colour and by whether the rind is drawn at all - see
## PultProjectile._draw(), where the melon's arcs belong to a shot that splashes.
const COLOR_CABBAGE := Color(0.55, 0.78, 0.52)

const COLOR_BG := Color(0.07, 0.09, 0.12)    # full-viewport backdrop behind the lawn

const COLOR_HP_BG := Color(0.12, 0.12, 0.12, 0.80)
const COLOR_HP_FILL := Color(0.85, 0.25, 0.25)
const COLOR_BAR_BG := Color(0.12, 0.12, 0.12, 0.80)
const COLOR_BAR_FILL := Color(0.35, 0.75, 0.95)

# ---------------------------------------------------------------- ultimate (P30-B)
# The 大招 charge bar under a plant's body. Gold, because it must read as "the big
# one is filling up" at a glance, distinct from the blue action bar and the red hp bar.
const COLOR_ULT_BG := Color(0.12, 0.12, 0.12, 0.80)
const COLOR_ULT_FILL := Color(0.95, 0.75, 0.30)

# ---------------------------------------------------------------- armour (P26)
# A zombie's armour is a second health layer in FRONT of its hp (the sheet's 护甲
# column). It is drawn as a thin strip right above the hp bar, because "the bucket is
# still on" is the one thing a player has to be able to read off the board.
const COLOR_ARMOR_FILL := Color(0.82, 0.86, 0.92)
const COLOR_ARMOR_BG := Color(0.12, 0.12, 0.12, 0.80)
## The strip sits in the gap between the name (UNIT_NAME_Y = -50) and the hp bar
## (UNIT_HP_BAR_Y = -42), so it never covers either of them.
const UNIT_ARMOR_BAR_Y := -46.0
const UNIT_ARMOR_BAR_HEIGHT := 4.0

# ---------------------------------------------------------------- unit visuals
const UNIT_BODY_SIZE := 60.0
const UNIT_NAME_Y := -50.0
const UNIT_HP_BAR_Y := -42.0
const UNIT_ACTION_BAR_Y := 32.0
const UNIT_BAR_WIDTH := 64.0
const UNIT_BAR_HEIGHT := 6.0
const FONT_SIZE_UNIT_NAME := 11
const FONT_SIZE_BAR := 10

const UNIT_ART_SIZE := 60.0            # square box the sprite is drawn into
const UNIT_ART_LINEAR_FILTER := true   # vector art wants smoothing, not nearest

## [P112] THE SHOUT BUBBLE - the speech balloon a body wears over its head when it casts an
## ultimate or a signature skill, saying only the NAME (the user's rule: 大招必喊、特殊技能才喊、
## 普攻不喊、文案只喊名字). Read ONLY by Unit._draw_shout(), so every number is presentation and
## lives here. The balloon is anchored to the NAME's own fixed Y (not to art_scale): a name does
## not scale with a brawl body's picture and neither does its shout, so the two keep the same
## head-line in every mode. Colours are the sky-blue skill bubble and the gold ultimate bubble -
## the gold matches the ult bar (COLOR_ULT_FILL), so "this was the big one" reads the same twice.
const SHOUT_FONT_SIZE := 12
const SHOUT_PAD_X := 7.0               # horizontal padding inside the balloon
const SHOUT_PAD_Y := 5.0               # vertical padding inside the balloon
const SHOUT_BOTTOM_Y := -66.0          # the balloon's bottom edge (above the name's cap line)
const SHOUT_TAIL_H := 7.0              # the little triangle that points back down at the head
const SHOUT_TIME := 1.6                # seconds a skill shout holds
const SHOUT_TIME_ULT := 2.4            # ...and an ultimate's (a beat longer, so it reads as bigger)
const SHOUT_FADE := 0.45               # the last fraction of seconds that fades the balloon out
const COLOR_SHOUT_BG := Color(0.08, 0.08, 0.11, 0.85)
const COLOR_SHOUT_TEXT := Color(0.96, 0.96, 0.99)
const COLOR_SHOUT_TEXT_ULT := Color(1.0, 0.84, 0.32)
const COLOR_SHOUT_BORDER := Color(0.96, 0.96, 0.99, 0.65)
const COLOR_SHOUT_BORDER_ULT := Color(1.0, 0.84, 0.32, 0.85)

## [P70] A VIEW SCENE is ART ONLY - the Unit keeps every bit of the logic - and the board
## draws it IN PLACE OF the unit's sprite, so the numbers that place it are presentation.
## C9's second cut moved these three here from Balance; the lookup ORDER a unit is drawn
## in (tscn -> svg -> flat) is a data question and stayed next to Balance.plant_view().
## UnitArt is the only reader of all three.
## Three rules a view has to obey, so that the code can place ANY view with one scale and
## one offset:
##   * the root origin (0,0) is the unit's FEET CENTRE
##   * the art is drawn on a 128 px canvas, the same canvas the SVG pipeline uses
##   * the root carries no script and no logic
## A view is drawn into the same UNIT_ART_SIZE box as a sprite, which is why swapping
## sprite -> scene cannot move the plant on the lawn, and why a view can never reach the
## name / hp bar / action bar that Unit._draw() paints itself.
const VIEW_ART_CANVAS := 128.0
## The "ground line" of that canvas: the view's FEET CENTRE sits on it, i.e. the art keeps
## 16 px of margin under the feet - exactly where the peashooter and sunflower SVGs end
## (their ink bottoms are both at y = 112). The sprite pipeline lands its ink bottom on
## the SAME line, (112 - 64) * 60 / 128 = +22.5 in local pixels, which is what makes a
## view and a sprite of the same art cover the same pixels: the swap is pixel-identical.
const VIEW_ART_FEET_LINE := 112.0
## The clip a view is asked to play the moment it is instantiated (UnitArt.play_view_idle,
## which the board and the almanac panel both go through). A part that does not carry it is
## NOT an error: a view may be still, or play its own animation from its own script -
## spikerock_view.tscn keeps "spike_attack" and has no "idle" at all - so this is a best
## effort. UnitArt's self-check prints which registered parts carry the clip.
const VIEW_IDLE_ANIMATION := "idle"

# Idle animation: plants breathe. position stays a pure visual quantity (see
# HANDOFF 7.9) - these offsets never reach col/row/hp/ap.
const IDLE_SPEED := 1.5                # radians per second
const IDLE_BOB := 1.2                  # vertical pixels
const IDLE_SWAY := 0.8                 # horizontal pixels
const IDLE_BREATHE := 0.03             # +-3% squash/stretch of the sprite
const IDLE_PHASE_STEP := 0.9           # per-unit phase offset, so units never sync up
# [B33] THE NEW DEFAULT IDLE (docs/prompt/FX.md §3): the body's picture swings between
# long-and-thin and short-and-wide about its FEET - "纵向伸长、横向拉扁，然后反过来".
# The old breathing (the five constants above) stays on the table as the `breath` presentation.
const IDLE_STRETCH_AMP := 0.07         # +-7%: y up goes with x in, then the reverse
const IDLE_STRETCH_SPEED := 2.2        # radians per second of the stretch cycle

# Size the top bar's readout icon is drawn at, in logical pixels. [P22] dropped
# ICON_ROW_INSET and [P96] the row pair (ICON_ROW_SIZE / ICON_ROW_TEXT_GAP) with it:
# the level page is a card grid now, and no entry carries an icon any more.
const ICON_HUD_SIZE := 18.0            # next to a top bar readout
const ICON_HUD_GAP := 4.0

# ---------------------------------------------------------------- HUD layout
const HUD_TOP_BG := Color(0.10, 0.12, 0.16, 0.92)
const HUD_BOTTOM_BG := Color(0.10, 0.12, 0.16, 0.92)
const COLOR_CARD_BG_DISABLED := Color(0.16, 0.17, 0.19)
const COLOR_BTN_BG := Color(0.22, 0.45, 0.30)
const COLOR_BTN_BG_HOVER := Color(0.30, 0.58, 0.38)
const COLOR_BTN_BG_DISABLED := Color(0.18, 0.20, 0.22)
const COLOR_PLACEABLE := Color(0.30, 0.95, 0.40, 0.20)
const COLOR_BLOCKED := Color(0.95, 0.25, 0.25, 0.28)
const COLOR_MESSAGE := Color(1.00, 0.85, 0.35)

const CARD_SIZE := Vector2(170.0, 50.0)
const CARD_GAP := 8.0
## [P26] The unit sprite drawn on the left edge of a PLANT card (its own art, from the
## sheet's svg column through Balance.plant_art). Inside the 50 px card this leaves 12 px
## of margin and a 34 px picture; the two text lines are centred in what is left of the
## card, which is why CARD_ICON_MARGIN counts twice (left edge + gap to the text).
const CARD_ICON_SIZE := 34.0
const CARD_ICON_MARGIN := 6.0
## [P31-B] The spirit card's icon tint: a cold cast over the BASE plant's sprite
## (the copy borrows the picture, the name and the tint say whose it is).
## Presentation only - the board unit itself stays untinted.
const COLOR_SPIRIT_TINT := Color(0.72, 0.82, 1.0)
const CARD_ROW_GAP := 4.0             # between the plant row and the tool row
const CARD_ROW_TOP_OFFSET := 6.0      # between the bottom bar top and the plant row
const CARD_TITLE_Y := 5.0             # label offsets inside one card
const CARD_SUB_Y := 26.0
const CARD_LABEL_HEIGHT := 18.0
# [P12] cooldown strip along the bottom edge of a PLANT card. It is made of two
# ColorRect children of the button: a Control's _draw() renders UNDER its
# children, so a strip painted by hud.gd itself would be hidden by the card's
# opaque stylebox.
const CARD_CD_STRIP_H := 3.0          # thickness of the cooldown strip
const CARD_CD_STRIP_INSET := 10.0     # kept clear of the rounded corners
const CARD_CD_STRIP_BOTTOM := 3.0     # distance from the bottom edge of the card
const MIN_CARD_WIDTH := 96.0          # last-resort shrink when the window is narrow
const CARD_END_TURN_GAP := 16.0       # minimum gap between the card rows and END TURN
const ROW_LABEL_WIDTH := 112.0        # "SCROLLS" / "TOOLS" column, left of the cards
const ROW_LABEL_GAP := 8.0            # between the label column and the cards
const ROW_LABEL_SCROLLS := "SUMMONS"  # [P13] the plant card row: per-round summon budget
const ROW_LABEL_TOOLS := "TOOLS"
## [P20] Neither string is drawn any more: the bottom-bar row labels come from
## LocUi ("hud.row.summons" / "hud.row.tools"), because these two cannot follow the
## language. Kept as the reference wording - if you ever show them again, show the
## Loc ones instead of adding a second key for the same words.
const END_TURN_SIZE := Vector2(170.0, 104.0)   # height always spans both card rows
const END_TURN_MARGIN := 40.0

# [P13] In-battle corner buttons, top right: SETTINGS and RETREAT. They live in
# the top bar, so the right aligned readouts (next wave / LEVEL) stop short of
# them - Layout.top_buttons is the reserved box.
const TOP_BUTTON_SIZE := Vector2(120.0, 34.0)
const TOP_BUTTON_GAP := 8.0
const TOP_BUTTON_MARGIN := 12.0       # from the right edge of the window
const TOP_BUTTON_COUNT := 3           # [P15] SETTINGS / PACK / RETREAT
const COLOR_BTN_RETREAT := Color(0.52, 0.27, 0.25)
const HUD_SIDE_MARGIN := 24.0         # outer margin of every HUD text line
const HUD_LINE_GAP := 28.0            # gap between two readouts in the top bar
const HUD_GAP_RATIO := 0.035          # ... which grows with the window, up to
const HUD_GAP_MAX := 56.0             # ... this ceiling
const HUD_TOP_LINE1_Y := 38.0         # baselines inside the 100 px top bar
const HUD_TOP_LINE2_Y := 74.0
const HUD_STATUS_BOTTOM_MARGIN := 16.0   # status / hover line above the bottom bar
const TEXT_BASELINE_NUDGE := 5.0      # centres a text baseline inside a box
const FONT_SIZE_HUD := 20
const FONT_SIZE_HUD_SMALL := 15
const FONT_SIZE_CARD := 13
const FONT_SIZE_BUTTON := 17
const FONT_SIZE_OVERLAY := 48
const FONT_SIZE_OVERLAY_SUB := 21

# ---------------------------------------------------------------- presentation (P5)
const ANIM_MOVE_TIME := 0.18
# ANIM_PEA_TIME was replaced in P11 by the speed based PEA_SPEED below.
const ANIM_DEATH_TIME := 0.30
const ANIM_SPAWN_TIME := 0.20
const ANIM_SHAKE_TIME := 0.18
const ANIM_SHAKE_DIST := 7.0
const ANIM_LUNGE_DIST := 6.0
const ANIM_BAR_SMOOTH := 8.0
const FLASH_DECAY := 3.5

# ---------------------------------------------------------------- named unit effects (P110)
# The effects themselves are scripts/core/unit_fx.gd and their rules are docs/prompt/FX.md; every
# number they read lives here, like every other presentation number in this project.
const FX_HIT_LEAN := 0.28              # radians a body tips BACKWARD when it is hit
const FX_ATTACK_LEAN := 0.22           # radians it tips FORWARD as it strikes
const FX_PELLET_SCALE := 0.6           # a shot's flinch against a chomp's (P5's 0.6, named)
const FX_IDLE_STANDDOWN := 12.0        # how fast the idle sway yields while an effect plays
# [B33] THE STUN SWAY (docs/prompt/FX.md §3): a dazed body rocks about its FEET, back and
# forth, each pass smaller than the last, and settles upright. The hinge is the same
# one-number compensation a topple pays (Unit._turn_anchor), put back by sway_pose() alone.
const FX_STUN_LEAN := 0.14             # radians the FIRST pass swings (then damped)
const FX_STUN_SWINGS := 3              # swinging passes, plus the one that rocks upright
const FX_STUN_SWING_TIME := 0.22       # s per pass; the whole rock is UnitFx.stun_time()
const FX_STUN_DAMP := 0.72             # each pass is this fraction of the one before
# [B34] THE JELLY SQUASH (docs/prompt/FX.md §2/§3): the DEFAULT hit feedback now also DEFORMS
# the body - it snaps short-and-wide, then oscillates back through the reverse, damped to rest.
# Like the [B33] idle it is a scale of the PICTURE about the feet, never node.scale. One damped
# cosine drives it (Unit.jelly_pose) on a NORMALISED clock (0 at the strike, 1 when the flinch
# is over): AMP is the first squash (a fraction of the size), FREQ / DAMP are the rad/s and the
# e^-rate measured over THAT unit, with the clock itself borrowed from ANIM_SHAKE_TIME. A pellet
# does not add its own numbers: the hit rows scale this amplitude by FX_PELLET_SCALE like the lean.
const FX_JELLY_AMP := 0.14             # first squash: y −14%, x +14%, then the ringing
const FX_JELLY_FREQ := 18.0            # rad/s over the 0.18 s clock: a full ring inside a hit
const FX_JELLY_DAMP := 7.0             # e^-7t over it: the last pass is ~1%, rest is exact at 0

# [B25] THE DEATH EFFECTS (the table is scripts/core/unit_fx.gd's `death_spec`, the prose is
# docs/prompt/FX.md §4). The default the user asked for (2026-10-08) is 倒地并淡出: the body tips
# BACKWARD about its own FEET, goes a little past flat, settles back to flat, and only then
# fades out where it fell. THE THREE TIMES RUN IN SERIES - fall + settle + fade is what a viewer
# waits for, and BalanceBrawl.BOUT_CURTAIN_SECONDS has to outlast that sum (0.74 today, 0.9 there).
const DEATH_TOPPLE_ANGLE := 1.5708     # radians = 90 deg: flat on the lawn
const DEATH_TOPPLE_TIME := 0.34        # s: down to the ground (eased INTO the fall, like gravity)
const DEATH_TOPPLE_OVERSHOOT := 0.07   # fraction PAST flat it rocks, before settling back
const DEATH_TOPPLE_SETTLE_TIME := 0.10 # s: that settle
const DEATH_FADE_SHRINK := 0.55        # the plain fade's scale end (was a literal in play_death)

# [P110b/P110e] THE MELEE PICTURES (Fx.spawn_melee_fx): a PICTURE on the board, not a pose.
# One box for the whole family - the claw and the three slashes are all authored on a 128 px
# canvas with their ink filling it, so one number fits them all. A drawing that ever wants its
# own size is a per-id table here, not a change at the call site.
const MELEE_FX_SIZE := 70.0            # px box the 128 px drawing is fitted into
const MELEE_FX_TIME := 0.34            # seconds it lives
const MELEE_FX_HOLD := 0.35            # fraction of that life it stays at full strength
const MELEE_FX_POP := 0.78             # scale it is born at; it grows into MELEE_FX_SIZE

# [B10] THE POSE OF BEING EATEN (BrawlActor.be_swallowed): how the prey is DRAWN while it is inside
# a devourer, which is a presentation fact and nothing else. Three things at once, because one
# alone does not read: it is SMALL (it is in a belly, not standing on the lawn), it is TINTED the
# colour of the body around it (a body seen THROUGH a green slime), and it is drawn OVER that body
# rather than under it - the slime's art is an opaque blob (assets/svg/units/monsters/slim/), so a
# prey put BEHIND it would simply not be visible at all, which is the one thing this effect owes
# the player. z_index 1 is "above the pieces": the alternative (reordering the field's children)
# would put the prey under every piece spawned after it instead.
const GULP_PREY_SCALE := 0.5           # how big the prey is drawn while it is inside
const COLOR_GULP_PREY := Color(0.62, 0.95, 0.58, 0.92)   # the tint, alpha included
const GULP_PREY_Z := 1                 # drawn over the body that ate it (see above)

# [B38] THE LEAP, SEEN (BrawlActor._open_leap / _advance_leap / _finish_leap). The jump's ARC is not a
# presentation number - it is the height AXIS (BalanceBrawl.LEAP_*, and the lift itself is drawn by
# _sync_position from the body's own z) - but everything that makes that axis READ lives here, because
# a charge nobody can see is a word in a sheet. Three poses and one ring:
#   CROUCH is the DEEPEST squat, and _advance_leap WALKS to it over the wind-up (rest → CROUCH, eased)
#   rather than switching it on: an eye reads "loading" from a body pressing down, and reads nothing
#   from one that is simply already bent. A squat is drawn WIDER AND SHORTER - the same ink pushed into
#   the ground, which is the reading the eye has for a weight about to move.
#   STRETCH is the AIR pose: thin and tall, the classic answer to "something just left the ground". It
#   is the pose's half of a cue the mode already pays for - the shadow shrinks and dims by
#   BRAWL_SHADOW_FALLOFF per cell of z (BrawlShadow), so a higher arc leaves a visibly smaller mark on
#   the ground while the body itself is stretched over it.
#   REST is never named: it is Vector2.ONE, written the frame the body lands.
# Both are node SCALE, written by the one door (_set_leap_pose) so a jump can never leave a body bent;
# the landing rebound is the other channel, the jelly, which scales the PICTURE about the feet and so
# composes with a pose instead of fighting it (the [B33]/[B34] split).
const BRAWL_LEAP_CROUCH := Vector2(1.22, 0.78)
const BRAWL_LEAP_STRETCH := Vector2(0.86, 1.18)

# [P110f] THE BEAMS (Fx.spawn_beam; four of them since [B14]). Unlike the melee marks there
# is no SVG for these - a beam is a LINE BETWEEN TWO BODIES, so it is drawn in code and this is
# where its numbers live. A closed list, the way Projectile's 外观 table next door is closed: a new beam means a
# branch in Fx.BeamLance._draw plus a row here.
const BEAM_LASER := "laser"            # 瞬发光束: one thin flash, gone before the eye settles
const BEAM_FLAME := "flame"            # 喷射火焰: a cone of fire that stops short of the target
const BEAM_IMPULSE := "impulse"        # 连续冲击光束: a thick lance, held, with bands running out
const BEAM_THUNDER := "thunder"        # [B14] 雷角电击: a jagged bolt out of the caster's horn
## "phase_speed" is how fast THIS look's clock wraps when it is CHANNELLED (cycles per second) -
## a property of the picture, not of the channel, which is why it is a cell here rather than one
## number beside the cadence: fire has to flicker several times a second or it reads as slow
## motion, where a lance's bands travel slowly on purpose. A look that does not animate its phase
## leaves it at 0. A one-shot FLASH never reads this at all - it runs its phase 0 -> 1 over its own
## short life instead.
## "muzzle" is [B14]'s third cell: WHERE THIS LOOK LEAVES THE BODY THAT FIRES IT, as a FRACTION
## of that body's art box (negative x = left, negative y = up; ZERO = the body's centre, which is
## what a beam of pure light does). It is a fraction rather than pixels because the brawl draws a
## piece bigger than the design box (BrawlLayout.piece_scale -> Unit.art_scale), and it lives on
## the LOOK rather than on the sheet because it is a fact about the drawing: the thundercorn's
## bolt comes out of the horn, and the horn is where the SVG puts it - texture (16, 16) on the
## 128 px canvas whose centre is 64, i.e. -0.375 of the drawn box on both axes.
const BEAMS := {
	BEAM_LASER:   {"time": 0.14, "width": 4.0,  "phase_speed": 0.0,
		"color": Color(0.55, 0.90, 1.00), "muzzle": Vector2.ZERO},
	BEAM_FLAME:   {"time": 0.30, "width": 15.0, "phase_speed": 9.0,
		"color": Color(1.00, 0.52, 0.12), "muzzle": Vector2.ZERO},
	BEAM_IMPULSE: {"time": 0.42, "width": 11.0, "phase_speed": 1.8,
		"color": Color(0.72, 0.42, 1.00), "muzzle": Vector2.ZERO},
	## A bolt is SHORTER than a lance (lightning is a flash, not a beam that is held) and folds
	## fourteen times a second while it is channelled, which is what makes three seconds of it
	## read as a sustained strike rather than as one long still line.
	BEAM_THUNDER: {"time": 0.16, "width": 5.0,  "phase_speed": 14.0,
		"color": Color(0.68, 0.82, 1.00), "muzzle": Vector2(-0.375, -0.375)},
}
const BEAM_FLAME_REACH := 0.90         # fraction of the gap the flame's longest tongue fills
const BEAM_FLAME_SPREAD := 17.0        # degrees, half-angle of that cone
const BEAM_FLAME_TONGUES := 7          # how many triangles the cone is built from
const BEAM_IMPACT_FLASH := 1.7         # how much wider than the beam its landing bloom opens
## [B14] 雷角电击 (BEAM_THUNDER) - what a BOLT does that a lance does not: it is drawn as a
## folded path instead of a straight line, so the picture is a polyline and these are its folds.
## The fold is deterministic (no rng in a picture): the same strike looks the same twice, and the
## same number of times on a fast machine as on a slow one.
const THUNDER_SEGMENTS := 7            # how many spans the path is folded into
const THUNDER_JITTER := 9.0            # px the MIDDLE of the path is thrown sideways
const THUNDER_FOLD := 2.7              # radians per span: how sharply the zigzag alternates
const THUNDER_SHUFFLE := 11.0          # radians per unit of phase: how fast the bolt re-folds
const THUNDER_FORKS := 2               # how many branches come off the bolt
const THUNDER_FORK_REACH := 0.45       # a branch is this share of the whole span long
## [P110g] The CHANNELLED beam (scripts/core/brawl/brawl_beam.gd) - the eye tower's 3 seconds of
## burning. How LONG it burns and what a tick is WORTH are game rules and live in BalanceBrawl;
## these three are only what the picture does.
const BEAM_CHANNEL_RAMP := 0.10        # seconds it takes to come up to full strength
const BEAM_CHANNEL_TAIL := 0.22        # seconds it takes to go out once the channel is over

const PEA_RADIUS := 7.0
# Where the pea leaves the peashooter: the CENTRE of the muzzle, so the pea is
# half inside the mouth and half outside it at spawn (that reads as "coming out
# of the barrel"; a horizontal only offset put it at the lower lip instead).
# The muzzle of assets/svg/units/plants/pea/peashooter.svg is the vertical edge
# x 90, y 40..58, so its centre is texture (90, 49). A 128 px sprite drawn into
# UNIT_ART_SIZE (60) maps texture to local as (tex - 64) * 60 / 128:
#   x: (90 - 64) * 0.46875 = +12.2   y: (49 - 64) * 0.46875 = -7.0
# Keep both numbers in sync when the muzzle moves in the SVG.
const PEA_MUZZLE_OFFSET := Vector2(12.0, -7.0)

# Pea flight is SPEED based, not duration based. A fixed duration (the old
# ANIM_PEA_TIME = 0.16 s) made a point blank shot and a full lawn shot move at
# wildly different speeds, and put the muzzle spawn on screen for a single frame
# - which is exactly why the pea looked like it came out of the middle of the plant.
const PEA_SPEED := 1100.0              # px per second
## [P49] A lobbed melon is a different picture from a fired pea, and every number here
## is only what the eye sees - the damage, the splash and the freeze are elsewhere.
## Slower because a thrown melon has to be FOLLOWED, not just noticed: at PEA_SPEED the
## arc would be over in two frames and read as a teleport. PULT_ARC_HEIGHT is how many
## pixels above the straight line the top of the throw sits, so the picture stays a
## fraction of the row height whatever the window. The muzzle is
## the cup on the pult's head, read off its own sprite by eye rather than by the texel
## arithmetic above - move it if the melon seems to start inside the plant.
const PULT_SPEED := 480.0              # px per second
const PULT_ARC_HEIGHT := 64.0          # px of lift at the top of the throw
const PULT_MUZZLE_OFFSET := Vector2(10.0, -16.0)
const MELON_RADIUS := 10.0             # a melon is not a pea: 3 px fatter
## [B7+] THE BRAWL'S TWO SHOTS, drawn by Projectile.draw_shot() - the same painter the turn
## engine's pea and melon go through, so "what an arrow looks like" has one owner. These are
## PIXELS and COLOURS, which is why they live here and not in BalanceBrawl (the brawl's own
## table owns the pace of its shots in CELLS - see BalanceBrawl.SHOT_CELLS_PER_SECOND).
## An arrow is its own palette (a wooden shaft is not a plant's colour) and POINTS where it
## flies, so it is drawn in a rotated frame; the ball is round and only its smoke cares.
const ARROW_LEN := 20.0                # from the nock to the tip, in px
const ARROW_WIDTH := 2.0
const ARROW_HEAD_LEN := 9.0            # where the head's base sits (and how far the tip is past it)
const ARROW_HEAD_HALF := 3.5
const ARROW_FLETCH := 7.0
const COLOR_ARROW_SHAFT := Color(0.72, 0.55, 0.32)
const COLOR_ARROW_HEAD := Color(0.84, 0.88, 0.92)
const COLOR_ARROW_FLETCH := Color(0.82, 0.34, 0.30)
const MUSKET_RADIUS := 5.0
const MUSKET_SMOKE_RADIUS := 10.0      # the puff trails BEHIND the ball, at this distance
const MUSKET_SMOKE_OFFSET := 8.0
const COLOR_MUSKET_BALL := Color(0.28, 0.30, 0.34)
const COLOR_MUSKET_HIGHLIGHT := Color(0.55, 0.58, 0.62)
const COLOR_MUSKET_SMOKE := Color(0.86, 0.86, 0.84, 0.45)
## [B19] THE LOBBER'S SHELL - a cast-iron sphere, a size fatter than the musket round and
## darker than it: the player must read "this lands and bursts" from the silhouette alone.
const BOMB_RADIUS := 9.0
const COLOR_BOMB := Color(0.12, 0.12, 0.14)
const COLOR_BOMB_HIGHLIGHT := Color(0.42, 0.44, 0.48, 0.85)
## The trail every brawl shot drags behind it: a short fading line the length of one body, so a
## ball that crosses the arena in half a second still reads as a MOVING thing and not as a
## flicker. And the impact burst: two rings that expand and fade over SHOT_FLASH_SECONDS
## (BalanceBrawl), which is longer than one frame by an order of magnitude - a hit the eye
## cannot catch is the same as no feedback at all.
const SHOT_TRAIL_LEN := 26.0
const SHOT_TRAIL_WIDTH := 3.0
const COLOR_SHOT_TRAIL := Color(1.0, 0.96, 0.86, 0.30)
const SHOT_FLASH_R_MIN := 5.0
const SHOT_FLASH_R_MAX := 30.0
const SHOT_FLASH_WIDTH := 3.0
const COLOR_SHOT_FLASH := Color(1.0, 0.90, 0.66, 0.85)
## [B20] THE BLAST'S OWN PICTURE (docs/prompt/BRAWL.md §8.17 补记). Everything below is measured
## as a FRACTION of the shot's 溅射半径 in pixels, because the whole point of this burst is that
## the ring the eye sees STOPS WHERE THE DAMAGE STOPS - the shockwave's final circle is the
## splash area itself, drawn once per landing (BrawlField.world_of is isotropic, so a cell-space
## reach becomes a screen-space circle with no second ruler).
const BLAST_CORE_SHARE := 0.55         # the fireball is drawn over this fraction of the burst
const BLAST_CORE_R := 0.42             # its pop radius, as a share of the blast reach
const BLAST_CORE_HOT_R := 0.55         # the white heart inside the fireball, of the core radius
const COLOR_BLAST_CORE := Color(1.0, 0.72, 0.28, 0.92)
const COLOR_BLAST_CORE_HOT := Color(1.0, 0.98, 0.88, 0.95)
const BLAST_WAVE_R_MIN := 0.18         # where the shockwave starts (a stub around the core)
const BLAST_WAVE_W_MAX := 7.0          # its line weight when it leaves, and when it arrives...
const BLAST_WAVE_W_MIN := 1.5          # ...it is a hairline by the time it marks the reach
const COLOR_BLAST_WAVE := Color(1.0, 0.92, 0.70, 0.85)
const BLAST_PUFFS := 7                 # powder smoke flung over the ring; the heading rotates
const BLAST_PUFF_R := 0.13             #   the pattern so two shots do not print the same puff
const BLAST_PUFF_GROW := 1.4           # how fat a puff is by the end, relative to its start
const COLOR_BLAST_SMOKE := Color(0.24, 0.23, 0.25, 0.50)
## [B38] THE SLAM'S OWN PICTURE (Fx.spawn_slam / Fx.SlamRing - a body that fell out of the air). The
## argument BLAST_* above made for an explosion carries over word for word: the circle the eye watches
## die is the circle the damage was paid inside, so the ring's LAST radius is the row's 大招范围 and the
## caller converts it with the live cell (BrawlField.cell()). Two things differ from a blast, both
## because a jump LANDS rather than detonates: the ground is painted before the ring runs out (CORE -
## "here is what I claimed", at full size, dying early), and the whole picture lies FLAT, squashed by
## BRAWL_SHADOW_DEPTH_SHARE - the arena's one ground-plane ratio - so a slam reads as a fact about the
## floor and not as a billboard in front of the bodies on it. Everything is a FRACTION of the reach, so
## one class draws a 1.5-cell slam and a 4-cell one.
const SLAM_TIME := 0.40                # longer than a spark (0.22): something fell from the sky
const SLAM_CORE_SHARE := 0.45          # the lit ground is drawn over this first part of the burst
const COLOR_SLAM_CORE := Color(0.98, 0.82, 0.50, 0.42)
const SLAM_WAVE_R_MIN := 0.12          # where the ring starts - a stub at the feet
const SLAM_WAVE_W_MAX := 9.0           # its line weight when it leaves...
const SLAM_WAVE_W_MIN := 2.0           # ...and a hairline by the time it marks the reach
const COLOR_SLAM_WAVE := Color(1.0, 0.92, 0.66, 0.90)
const SLAM_DUST := 10                  # earth kicked up over the edge of the circle
const SLAM_DUST_SCATTER := 0.35        # how far PAST the reach it lands, as a share of it
const SLAM_DUST_R := 0.07              # one puff's size, of the reach
const COLOR_SLAM_DUST := Color(0.44, 0.34, 0.24, 0.55)
## The jumper's own rebound, on the jelly channel an ordinary hit already uses. It is LOUDER on
## purpose: FX_JELLY_AMP is one pellet, and a 900-HP body arriving from the air is the loudest thing
## this piece does (Unit.jelly_pose, [B34]).
const SLAM_JELLY_AMP := 0.34
const SLAM_JELLY_TIME := 0.24
## [B39] THE WHIRLWIND'S OWN PICTURE (brawl_tornado.gd). The rule both painters obey is a RADIUS:
## the widest footprint drawn on the grass is exactly the damage ring's DIAMETER (2 ×
## BalanceBrawl.TORNADO_REACH_CELLS), so the mark a player watches is the mark their body was touched
## inside (B20's argument, and the slam's, word for word). [B41] adds a SECOND painter - the two-frame
## picture under assets/svg/fx/ - and moves the default to it; the rule is unchanged, only the tool
## is, and the sprite is sized by its own measured INK so that the ring stays the truth
## (UnitArt.ink_fractions, the same door [B36] measures bodies with).
## The column's height is likewise not a number
## here - the node draws up to its OWN z_thickness, the height the sweep actually judges against, so
## "this whirlwind reaches this high" stays a fact with one owner.
## Everything below is a fraction or a count of that one shape:
##   BANDS stack from the ground upward and each one is NARROWER (TAPER) and turned a little further
##   (LAG), which is what makes a column of spinning arcs read as a vortex rather than as a stack of
##   rings. SPIN is revolutions per second of the visible sweep.
##   ARC_SHARE is how much of each circle is drawn: a full ring shows no rotation, a little over half
##   does - and the same flattening as the slam's ring (BRAWL_SHADOW_DEPTH_SHARE) lays every band on
##   the arena's ground plane, so the funnel belongs to the floor like everything else drawn here.
##   DEBRIS are the puffs caught at the edge, carried round by the same phase: motion the eye can
##   follow even when the whirlwind is over nobody.
##   RAMP / TAIL are the two fades: a tornado that appears at full strength on the frame the bird
##   calls it up is a glitch (BrawlBeam's ramp-in argument), and one that reaches its distance and is
##   simply gone leaves the player without the "it ended" the picture owes them. [B40] ONE meter does
##   both jobs in this drawing: the same 0→1→0 value is the alpha AND how far the column has STOOD UP,
##   so the funnel grows tall out of the grass and sinks back into it - and it never paints a height
##   above the one the sweep judges, because the node's own z_thickness is frozen at the full column
##   from the muzzle and this meter only ever draws SHORTER than the rule. (The reverse - a picture
##   taller than the air it occupies - would be a promise the damage does not keep.)
## [B40] WHAT "旋风 is 大" BUYS, and what it cannot. The whirlwind's magnitude is
## BalanceBrawl.TORNADO_SIZE_TIER (大 = 1.5×), and it is spent on the column and on everything BELOW
## that is a fraction of the column: BANDS (one per cell of air, so a bigger storm is also a denser
## one), the stroke weight, how many puffs ride the funnel and how far the top of it SWAYS and LEANS.
## It is never spent on the floor radius, because that one number is the sentence
## "the damage was paid inside this ring" (B20 again) - and a prettier circle may not be allowed to
## say a bigger one. That is why bigness here is HEIGHT, MASS and MOTION, and not width.
##   SPIN_SHEAR turns the higher bands a little faster than the floor band, which is what makes a
##   stack of arcs read as one body ROTATING instead of as rings sliding up.
##   WOBBLE / WOBBLE_HZ sway the TOP of the column side to side while the FOOT stays pinned to the
##   centre it walks on: a column that only ever stands perfectly straight is a diagram, and one whose
##   foot slides is a lie about where it is. The sway grows with height, so it is the top that moves.
##   LEAN tilts the whole column AGAINST the walk (the top trails behind the foot) - the picture of a
##   thing being pushed across the arena by a bird, and the reason the node asks its own field for the
##   screen direction of travel instead of assuming "to the right".
##   PULSE_AMP / PULSE_SECONDS are the tell that a tick LANDED: the frame the funnel strikes a body,
##   every band brightens and thickens and then decays. It is driven by the sweep's own hit count and
##   not by a clock, so a whirlwind that walks over nobody stays quiet - the payout the picture owes
##   is for the pulse that actually paid.
##   DEBRIS_RISE_HZ / DEBRIS_SPIRAL make the puffs climb the funnel and spiral INWARD as they rise,
##   which is the one motion every real whirlwind has and this drawing was missing: debris goes up the
##   column, it does not orbit the bottom forever.
## [B41] THE SECOND PAINTER: a TWO-FRAME SEQUENCE, assets/svg/fx/tornado_0.svg and tornado_1.svg,
## flipped every FRAME_SECONDS. The user asked for it by name after [B40]'s column still did not read
## on the board ("受够了，还是完全看不到旋风"), and the reason it is now the DEFAULT is structural and not
## a preference: a code-drawn column of arcs can only ever be as loud as its thinnest stroke, while an
## artist's funnel carries its own body, its own white 风线 and its own ground circle - and it cannot be
## quietly too subtle, which is exactly the failure this batch is about. FRAME_SECONDS is 0.08 at the
## sim's 30 Hz, so the flip lands every 2.4 steps: one full cycle (0.16 s) is a fifth of the pulse
## period, so the funnel visibly churns between two contact ticks instead of blurring into one.
## PATHS ARE SHORT IDS, not files: Fx.MELEE_FX_ROOT spells the folder once for the whole FX picture
## family (slash, claw, and now these two), and a missing import is answered by the node falling back
## to the vector painter below - a whirlwind that cannot paint is the bug this batch exists to kill,
## so it must never be able to also be invisible.
const TORNADO_PAINTER_FRAMES := "frames"
const TORNADO_PAINTER_VECTOR := "vector"
## THE SWITCH. One word, two painters, and the node asks it ONCE at summoning: a funnel that changed
## how it is drawn mid-flight would be a different object on screen, exactly like one that changed
## size (the frozen-_tier argument). To see the old column again, write TORNADO_PAINTER_VECTOR here.
const TORNADO_PAINTER := TORNADO_PAINTER_FRAMES
const TORNADO_FRAMES := ["tornado_0", "tornado_1"]
const TORNADO_FRAME_SECONDS := 0.08
## THE WHITE WIND TRACE (用户: "通过白色风痕表现旋风"). A funnel that walks leaves the grass combed
## behind it, and the trace says WHICH GROUND is being swept - the one thing neither painter could say
## on its own, because a body standing outside the ring cannot tell what is about to arrive. It is
## drawn by BOTH painters (it is a statement about the rule, not about the look): the corridor is as
## wide as the ring, WHITE, brightest at the funnel and gone at the far end, and it only remembers the
## last TRACE_CELLS of walk - a comet tail and not a painted road, because a stripe from one end of the
## arena to the other would claim damage the storm has long since stopped paying.
## SEGMENTS is how many slabs that tail is cut into: one polygon with one alpha would be a solid band,
## and N slabs with a decaying alpha is the fade the sentence "it has already been here" needs.
const TORNADO_TRACE_SEGMENTS := 9
const TORNADO_TRACE_CELLS := 2.2
const COLOR_TORNADO_TRACE := Color(1.0, 1.0, 1.0, 0.26)
## The ring the FRAMES painter draws under the sprite, in the arena's own pixels: the artist's funnel
## has its own ground circle (0.5 opacity in the file), and this is the same ruler stated where a
## spectator can measure it - and where [B40]'s landed-pulse glow can be told, because modulate cannot
## brighten a texture past itself. The weight, as usual, is a share of the radius it strokes.
const COLOR_TORNADO_RING := Color(1.0, 1.0, 1.0, 0.55)
const TORNADO_RING_SHARE := 0.05
## ---- The [B39]/[B40] VECTOR painter's own numbers: the bands, the spin, the wobble, the debris and
## the three colours. They are a section even though the [B41] switch above sits between them and the
## comment that explains them, because the frames painter is the default and reads first.
## NOTE TORNADO and not STORM: `*_storm` is already the turn engine's id for a plant's ultimate.
const TORNADO_BANDS := 4               # bands at the ladder's 标准; the tier adds one per step
const TORNADO_SPIN_HZ := 1.4           # revolutions per second of the sweep
const TORNADO_SPIN_SHEAR := 0.45       # how much faster the TOP band turns than the floor one
const TORNADO_TAPER := 0.32            # the top band's width, as a share of the bottom one's
const TORNADO_LAG := 0.09              # how much further each higher band is turned
const TORNADO_ARC_SHARE := 0.62        # the part of each band that is drawn
const TORNADO_LINE_SHARE := 0.14       # one band's line weight, of the funnel's own radius
const TORNADO_WOBBLE := 0.28           # how far the top sways, of the funnel's radius
const TORNADO_WOBBLE_HZ := 0.75        # how often it sways (slower than the spin, on purpose)
const TORNADO_LEAN := 0.16             # the top's trail behind the foot, of the column's height
const TORNADO_DEBRIS := 9
const TORNADO_DEBRIS_R := 0.075        # one puff's size, of the radius
const TORNADO_DEBRIS_RISE_HZ := 0.55   # how fast a puff climbs the column and wraps
const TORNADO_DEBRIS_SPIRAL := 0.42    # how far inward the puffs pull at the bottom
const TORNADO_RAMP_SECONDS := 0.14
const TORNADO_TAIL_SECONDS := 0.30
const TORNADO_PULSE_SECONDS := 0.24    # how long one landed pulse keeps glowing
const TORNADO_PULSE_AMP := 0.55        # the brightest frame of that glow
const COLOR_TORNADO_BAND := Color(0.80, 0.88, 0.94, 0.52)
const COLOR_TORNADO_CORE := Color(0.95, 0.97, 1.00, 0.20)
const COLOR_TORNADO_DEBRIS := Color(0.62, 0.68, 0.72, 0.55)
# [P33] PEA_TIME_MIN / PEA_TIME_MAX retired with the tween flight: the pea now
# crosses the lawn at exactly this speed (Projectile._process), and the swept
# collision needs no duration clamp - distance / speed IS the flight time.
## [P30-B] The cap on the round's wait for airborne visuals (the storm fires a
## whole lane of peas at once). Normal pea flight never nears it - it exists for
## the one failure mode that must not eat the player's time: a pending animation
## whose callback can never arrive.
const ANIM_RESOLVE_TIMEOUT := 3.0
const SPARK_RADIUS := 5.0
## [B12] THE DAMAGE NUMBER: what a blow actually took off, as it lands (BrawlActor.land_hit).
## The brawl has no other numbers on screen, so this one is the fight's readout - and it is
## deliberately WARM WHITE rather than the hp bar's red: it is information, not alarm, and a
## hundred red numbers a minute would read as one long alarm. The height is the same "above the
## body's centre" the campaign's own popups use (a chomp sits at -34).
const COLOR_DAMAGE := Color(1.00, 0.92, 0.72)
const DAMAGE_POPUP_DY := -34.0        # px above the body's centre
const POPUP_RISE := 40.0
const POPUP_TIME := 0.9
const POPUP_WIDTH := 90.0
const FONT_SIZE_POPUP := 15
const BANNER_TIME := 1.1
const BANNER_Y := 152.0
const BANNER_WIDTH := 900.0
const FONT_SIZE_BANNER := 30
## [P38] OPTIMIZATIONS B7: the floor any timed effect may be given - Fx divides by the
## duration it is handed, so a tuning constant zeroed out to "switch the effect off"
## would paint NaN rather than nothing.
const MIN_FX_TIME := 0.05
## [P76] OPTIMIZATIONS B7: the draw height of the one effect layer. Units and shots never
## set a z_index, so they sit at 0 and tree order decided who covered whom; an effect used
## to win that by being added last, which a permanent layer cannot do (the lawn is built
## before any unit exists). This is the number that keeps a damage number above the zombie
## it belongs to. Anything strictly above 0 does the job; 100 leaves room for a future
## middle layer without touching the units.
const FX_Z_INDEX := 100

const COLOR_FLASH := Color(1.00, 0.55, 0.55)

# ---------------------------------------------------------------- result panel (P7)
# The panel keeps its fixed size: with stretch aspect "expand" the logical space
# is never smaller than WINDOW_SIZE, so it always fits. It is centred by Layout.
# [P12] height raised 380 -> 410 for the garden line; [P14] raised to 480 because
# the panel now also lists the level rewards and what the backpack collected.
const OVERLAY_PANEL_SIZE := Vector2(620.0, 480.0)
const OVERLAY_PANEL_BG := Color(0.09, 0.11, 0.14, 0.96)
const OVERLAY_PANEL_BORDER := Color(0.55, 0.60, 0.70)
const OVERLAY_PANEL_BORDER_WIDTH := 2.0
const OVERLAY_DIM := Color(0.0, 0.0, 0.0, 0.55)   # dims the whole window behind the panel
const OVERLAY_TITLE_Y := 56.0         # inside the panel, from its top edge
const OVERLAY_REASON_Y := 92.0
const OVERLAY_STATS_X := 40.0
const OVERLAY_STATS_Y := 126.0
const OVERLAY_STATS_STEP := 24.0
const OVERLAY_RESTART_BOTTOM_MARGIN := 28.0
const RESTART_SIZE := Vector2(200.0, 56.0)
const RESULT_BUTTON_GAP := 20.0       # between RESTART and MAIN MENU
const RESULT_BUTTON_COUNT := 2

# ---------------------------------------------------------------- front-end (P10)
const MENU_TITLE_Y := 96.0             # baseline of the screen title
const MENU_SUB_OFFSET := 34.0          # subtitle baseline = title + this
const MENU_LIST_TOP := 176.0           # first button, from the top of the window
const MENU_LIST_TOP_MIN := 120.0       # ... relaxed when many rows have to fit

# ---------------------------------------------------------------- adventure card grid (P96)
## [P96] The ADVENTURE page is a GRID of level cards, not one row per level: 24 rows could
## only be stacked by squeezing each to MENU_ROW_MIN_HEIGHT, and a 36 px row has no room for
## the first-clear chest. A card carries the same facts the row did.
## The grid is ARITHMETIC (Menu.level_grid_metrics) and [Menu] audits those numbers at
## Balance.WINDOW_SIZE - the smallest logical page, since Layout only grows the design box.
const LEVEL_GRID_TOP := 150.0          # page content starts below the header (title 96 + subtitle 130)
const LEVEL_GRID_GAP := 14.0           # between two cards
const LEVEL_GRID_MIN_W := 150.0        # narrower than this and the level name stops fitting
## [P96] The floor is what a card is MADE OF: inset + name + numbers + the bottom row
## (2*10 + 26 + 18 + 30 = 94). [Menu] asserts that relationship, so lowering this number
## below the card's own parts goes red instead of quietly overlapping two lines.
const LEVEL_GRID_MIN_H := 96.0
const LEVEL_GRID_MAX_W := 260.0        # a card bigger than this stops reading as a cell
const LEVEL_GRID_MAX_H := 180.0
const LEVEL_GRID_BACK_H := 48.0        # the BACK button, under the grid
const LEVEL_GRID_BACK_GAP := 18.0
const LEVEL_CARD_INSET := 10.0         # padding inside one card
const LEVEL_CARD_TITLE_H := 26.0       # the level's name, on top
const LEVEL_CARD_STAT_H := 18.0        # the numbers line AND the status word (same height)
const LEVEL_CARD_CHEST := 30.0         # the first-clear chest, bottom right

# ---------------------------------------------------------------- main menu props (P22)
# Screens are entered by clicking their OBJECT instead of reading a word: a watering
# can, a crate, a key, a bag and [D74] a book LYING ON THE FLOOR of the main menu.
#
# They are deliberately NOT cells (no frame, no background, no badge) and they are
# smaller than the text options, because on this screen the LIST is what the menu is
# for: it owns the middle of the screen, and the objects are what you happen to find
# lying on the ground next to it. Each one is drawn by ui/menu_prop.gd.
const ART_ICON_GARDEN := "res://assets/svg/items/garden_watering_can.svg"
const ART_ICON_WAREHOUSE := "res://assets/svg/items/warehouse_crate.svg"
const ART_ICON_SHOP := "res://assets/svg/items/shop_key.svg"
const ART_ICON_BACKPACK := "res://assets/svg/items/backpack.svg"
## [D74] The almanac's own picture, and the reason "content" exists below: it is an open book
## drawn across 88 x 85 of its 128 px canvas (the spine and the magnifier are strokes, so the
## ink reaches x=108 / y=105). Measured off the file, like the other four.
const ART_ICON_ALMANAC := "res://assets/svg/items/tools/almanac.svg"

## The art files do NOT share one content box: the key is a flat 76x30 shape in the
## middle of its 128x128 canvas while the crate is 88x72, so drawing the whole canvas
## would make the key a sliver. Every prop therefore names the rect its picture really
## fills, in MENU_ART_CANVAS pixels, plus how wide that rect should be drawn - that is
## what makes five different pictures look like five objects of comparable size
## standing on one floor. Keep these numbers in step with the SVGs.
##
##   content   the filled area of the SVG, in canvas pixels
##   wide      how wide that area is drawn on screen (the height follows the aspect)
##   x         the object's centre, as a fraction of the window width
##   lift      how far above the floor line it sits (further back = higher up)
##   key       the LocUi entry, so the caption follows the language
##   turn_only the four META screens are the turn shell's (D29); an entry without it is on
##             the floor of BOTH shells - which today is the almanac alone (D74)
const MENU_ICONS := [
	{"id": "garden", "key": "menu.main.garden", "art": ART_ICON_GARDEN,
		"content": Rect2(14.0, 30.0, 102.0, 74.0), "wide": 84.0, "x": 0.09, "lift": 14.0,
		"turn_only": true},
	{"id": "warehouse", "key": "menu.main.warehouse", "art": ART_ICON_WAREHOUSE,
		"content": Rect2(20.0, 28.0, 88.0, 72.0), "wide": 88.0, "x": 0.27, "lift": 0.0,
		"turn_only": true},
	## [D74] The almanac sits in the gap the four leave in the middle of the floor, and it is
	## the one object the CLASSIC shell shows too: it reads the turn engine's three sheets
	## (plants / zombies / levels), which is why P26 kept it off this floor, but the user
	## 2026-10-05 asked for a picture of it in both shells. Drawn at 76 px wide (the crate's
	## 88 is the widest of the five) so the book does not dwarf its neighbours.
	{"id": "almanac", "key": "menu.main.almanac", "art": ART_ICON_ALMANAC,
		"content": Rect2(20.0, 20.0, 88.0, 85.0), "wide": 76.0, "x": 0.5, "lift": 0.0},
	{"id": "shop", "key": "menu.main.shop", "art": ART_ICON_SHOP,
		"content": Rect2(24.0, 32.0, 76.0, 30.0), "wide": 84.0, "x": 0.73, "lift": 18.0,
		"turn_only": true},
	{"id": "backpack", "key": "menu.main.backpack", "art": ART_ICON_BACKPACK,
		"content": Rect2(32.0, 24.0, 64.0, 80.0), "wide": 62.0, "x": 0.90, "lift": 5.0,
		"turn_only": true},
]

const MENU_ART_CANVAS := 128.0          # the canvas the "content" rects are measured in
const MENU_PROP_SIZE := Vector2(120.0, 128.0)   # clickable box of one object
const MENU_PROP_BOTTOM := 24.0          # from the bottom edge of the window
const MENU_PROP_CAPTION_H := 18.0       # the strip the name is drawn in
const MENU_PROP_FLOOR_PAD := 8.0        # between the object's feet and its caption
const MENU_PROP_SHADOW_RATIO := 0.62    # shadow width / object width
const MENU_PROP_SHADOW_SQUASH := 0.26   # how flat the shadow ellipse is
const MENU_PROP_GLOW_RATIO := 0.90      # hover halo diameter / object width
const MENU_PROP_GLOW_SQUASH := 0.55     # the halo is an ellipse too, a rounder one
const MENU_PROP_IDLE_ALPHA := 0.78      # an un-hovered object is a touch dimmed
const FONT_SIZE_MENU_PROP := 13

## The floor band the objects stand on. The text list keeps clear of it.
const MENU_FLOOR_H := 168.0
const MENU_FLOOR_EDGE_H := 2.0
const COLOR_MENU_FLOOR := Color(0.09, 0.11, 0.14)
const COLOR_MENU_FLOOR_EDGE := Color(0.20, 0.27, 0.22)
const COLOR_MENU_PROP_SHADOW := Color(0.0, 0.0, 0.0, 0.45)
const COLOR_MENU_PROP_GLOW := Color(0.95, 0.85, 0.35, 0.10)


static func menu_icon_paths() -> Array:
	## [P22] The four main menu objects, so UnitArt.self_check() reports whether the
	## editor has imported them (a missing one leaves an empty shape, never a crash).
	var out: Array = []
	for entry in MENU_ICONS:
		var row: Dictionary = entry
		var path := str(row.get("art", ""))
		if path != "" and not out.has(path):
			out.append(path)
	return out


static func menu_icon_title(p_id: String) -> String:
	## The caption under a menu picture. One literal key per branch: a key built by
	## concatenation would be invisible to a key audit (same rule as item_kind_label).
	match p_id:
		"garden":
			return Loc.t("menu.main.garden")
		"warehouse":
			return Loc.t("menu.main.warehouse")
		"shop":
			return Loc.t("menu.main.shop")
		"backpack":
			return Loc.t("menu.main.backpack")
		"almanac":
			return Loc.t("menu.main.almanac")
	return p_id
const MENU_LIST_BOTTOM_GAP := 24.0     # between the last button and the hint line
const MENU_HINT_BOTTOM_MARGIN := 42.0  # hint baseline, from the bottom of the window
const MENU_BUTTON_SIZE := Vector2(360.0, 64.0)
# Floor for a squeezed menu list. [P21] lowered 40 -> 36: the SETTINGS page now has 10
# rows in windowed mode (6 switches + the 4 window presets) and at 40 px the last row
# overlapped the hint line.
const MENU_ROW_MIN_HEIGHT := 36.0
const MENU_BUTTON_GAP := 16.0

const COLOR_MENU_BG := Color(0.06, 0.08, 0.11)
const COLOR_MENU_TITLE := Color(0.62, 0.88, 0.58)
const COLOR_MENU_SUB := Color(0.62, 0.66, 0.72)
const COLOR_MENU_MARK := Color(0.45, 0.95, 0.55)
const FONT_SIZE_MENU_TITLE := 52
const FONT_SIZE_MENU_BUTTON := 22
const FONT_SIZE_MENU_ROW := 18
const FONT_SIZE_MENU_SUB := 17

const SETTINGS_WINDOW_PRESETS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

# ---------------------------------------------------------------- item tiles (P22)
# The WAREHOUSE, the SHOP and the in-battle BACKPACK all show their contents the
# same way from now on: a wrapping grid of cells, each cell a big icon with the
# item's NAME in small text along its bottom edge, and clicking a cell brings up
# the detail + the actions in the panel next to (or under) the grid.
#
# One cell, from its top edge down:
#   icon box      square, centred, ITEM_TILE_ICON_TOP .. +ITEM_TILE_ICON_MAX
#   badge         count ("x3") or price ("100"), bottom right corner of the icon
#   name          small font, centred, the bottom strip of the cell
#   note          optional extra tiny line under the name (scroll durability)
#
# The grid SHRINKS the cells (down to ITEM_TILE_MIN_SCALE) so a partly full box still
# fills its space, and since [P42] a box that runs out of room TURNS A PAGE instead:
# the item kinds outgrew every box the game has, and shrinking past the floor clips.
# Both rules are audited at start-up by ItemGrid.self_check().
const ITEM_TILE_SIZE := Vector2(108.0, 130.0)
const ITEM_TILE_GAP := 12.0
const ITEM_TILE_PAD := 6.0              # inset of the name, and of the icon box
const ITEM_TILE_ICON_MAX := 84.0        # the icon never grows past this
const ITEM_TILE_ICON_TOP := 8.0         # from the top edge of the cell
const ITEM_TILE_NAME_H := 16.0          # the strip the name is drawn in
const ITEM_TILE_NOTE_H := 14.0          # ... and the optional line under it
const ITEM_TILE_FOOTER_PAD := 5.0
const ITEM_TILE_BADGE_INSET := 4.0      # from the corner of the icon box
const ITEM_TILE_BADGE_PAD := 5.0        # padding inside the badge
const ITEM_TILE_MIN_SCALE := 0.55       # shrink floor; below it the grid clips
const ITEM_GRID_MAX_COLS := 6
const ITEM_GRID_FIT_PASSES := 6         # bounded shrink loop, see ItemGrid.fit_for()

# [P42] The page bar a PAGED ItemGrid reserves at the bottom of its own box. The strip is
# reserved whether or not the list needs a second page (same rule as the almanac's, which
# had the first one), so turning a page never moves the cells and "1 / 1" is how the
# player learns a list is short enough not to be paged at all.
const ITEM_PAGE_BAR_H := 36.0           # button height, = ALMANAC_PAGE_BAR_H
const ITEM_PAGE_GAP := 12.0             # between the last cell row and the bar
const ITEM_PAGE_BTN_W := 96.0           # PREV / NEXT, narrower than the almanac's pair
const ITEM_PAGE_LABEL_W := 140.0        # centred between them

const FONT_SIZE_ITEM_TILE := 12         # the name under the icon
const FONT_SIZE_ITEM_TILE_MIN := 9      # ... shrunk to this before being trimmed
const FONT_SIZE_ITEM_NOTE := 11
const FONT_SIZE_ITEM_BADGE := 12
## [P53] How far a tail-trim may cut before it gives up and leaves the text whole.
## `UiStyle.trim_tail()` is now the only code that trims: the menu, the item screen and
## the item tile each carried a copy of the loop, and the copies had grown **two** floors
## (8 outside a cell, 3 inside one - a cell is narrow and "Wa..." still reads as "Walnut").
const TEXT_FIT_MIN_CHARS := 8
const ITEM_TILE_TEXT_MIN_CHARS := 3

const COLOR_ITEM_TILE_BG := Color(0.13, 0.15, 0.19)
const COLOR_ITEM_TILE_HOVER := Color(0.21, 0.25, 0.32)
const COLOR_ITEM_TILE_BORDER := Color(0.30, 0.35, 0.42)
const COLOR_ITEM_TILE_SELECTED := Color(0.95, 0.85, 0.35)
const COLOR_ITEM_TILE_DIM := Color(0.0, 0.0, 0.0, 0.45)   # over an unusable icon
const COLOR_ITEM_TILE_BADGE_BG := Color(0.06, 0.07, 0.09, 0.85)
const ITEM_TILE_DIM_ALPHA := 0.40       # icon alpha when the cell cannot be used
const ITEM_TILE_BORDER_W := 2.0
const ITEM_TILE_SELECTED_W := 3.0

# ---------------------------------------------------------------- item screens (P22)
# WAREHOUSE and SHOP share one body (scripts/ui/item_screen.gd): the tile grid on
# the left, the detail + action panel on the right. These are the design values;
# the real positions come from Layout.size at runtime, like the garden page.
const ITEM_SCREEN_TOP := 176.0          # first row of the grid, from the top
const ITEM_GRID_COLS := 4               # grid area: 4 x 3 cells at full size,
const ITEM_GRID_ROWS := 3               # i.e. exactly the 12 item kinds of today
const ITEM_PANEL_W := 360.0
const ITEM_PANEL_GAP := 24.0            # between the grid and the panel
const ITEM_PANEL_INSET := 18.0
const ITEM_PANEL_BOTTOM := 20.0
const ITEM_PANEL_TITLE_Y := 18.0        # offsets INSIDE the panel
const ITEM_PANEL_TITLE_H := 28.0
const ITEM_PANEL_LINES_Y := 56.0
const ITEM_PANEL_LINE_STEP := 24.0
const ITEM_PANEL_LINE_H := 22.0
const ITEM_PANEL_LINES := 3             # type / count / value, then the description
const ITEM_PANEL_DESC_GAP := 10.0
const ITEM_PANEL_DESC_H := 64.0
const ITEM_PANEL_STATUS_GAP := 8.0
const ITEM_PANEL_STATUS_H := 50.0
const ITEM_PANEL_BUTTON_H := 36.0
const ITEM_PANEL_BUTTON_GAP := 10.0
const ITEM_PANEL_BUTTONS := 3           # two actions + BACK, laid out bottom-up
const FONT_SIZE_ITEM_PANEL_TITLE := 20
const FONT_SIZE_ITEM_PANEL_LINE := 15

# ---------------------------------------------------------------- backpack panel (P22)
# The in-battle backpack borrows the result panel's box, so Layout keeps it
# centred. [P22] It shows the same ItemTile grid, two buttons (USE + CLOSE) and a
# detail line under the grid; the old "one row per item" list is gone, which also
# raises how many kinds fit on screen from 6 to 8.
const PACK_PANEL_INSET := 40.0          # from the panel edge to the grid
const PACK_PANEL_GRID_Y := 112.0        # top of the grid, from the panel top
const PACK_PANEL_GRID_H := 200.0
const PACK_PANEL_DETAIL_Y := 340.0      # the detail line under the grid
const PACK_PANEL_DETAIL_H := 46.0
const PACK_BUTTON_W := 200.0
const PACK_BUTTON_H := 56.0
const PACK_BUTTON_GAP := 20.0

# ---------------------------------------------------------------- almanac (P26)
# The 图鉴 / ALMANAC page answers the questions a player asks outside a battle:
# "which plants exist", "what am I up against", "what is this thing", "what is in this
# level". One page, THREE sections ([P29-UI]), all of them fed by the data the game
# itself plays with:
#   UNITS / PLANTS   data/units/plants.csv    (one row per plant, via PlantDB)
#   UNITS / ZOMBIES  data/units/zombies.csv   (one row per zombie type, via ZombieDB)
#   ITEMS            data/items.csv           (one row per item, via ItemDB - [P27])
#   LEVELS           the level pack           (every valid *.json in Balance.LEVEL_DIR, via LevelList)
#
#   tabs     three buttons in a row under the page title: 单位 / 道具 / 关卡
#   races    [P29-UI] a smaller second row, shown only on UNITS: 植物 / 僵尸
#   grid     the SAME ItemGrid the warehouse uses: one cell per plant / zombie / item / level
#   panel    the selected entry's numbers and prose, with BACK at its bottom
#
# [P27] The page shows EIGHT cells per row and the selected entry's own picture in the
# top right corner of the panel. Eight 108 px cells would be 948 px wide, i.e. 1332 px
# together with the 360 px panel - wider than the design window - so the almanac has
# its OWN cell box (ALMANAC_TILE_SIZE) instead of ITEM_TILE_SIZE: 8 x 96 + 7 x 12 =
# 852 px leaves the panel its full width and 22 px of margin on each side. The grid
# also takes the whole band under the tabs and fills it from the TOP (ItemGrid.top_align),
# because at eight per row a tab holds one to three rows and a fixed box would float
# the short tabs (LEVELS = one row) down the middle of the page.
#
# [P28] A tab shows ONE PAGE at a time and the page bar under the cells turns it: the
# roster is free to grow past a page (PLANTS already has 49 rows) and the cells keep
# their full ALMANAC_TILE_SIZE instead of being shrunk until the whole list fits a box
# it cannot fit - the shrinking used to push the bottom rows out of the clipped grid.
# The bar is carved out of the band under the tabs for the GRID only: the PANEL keeps
# that band's full height, so its own layout (8 lines, prose, picture, BACK) is
# unchanged. AlmanacView.metrics_for() returns the page capacity the window allows.
#
# The panel is TALLER than the warehouse's (8 lines instead of 3) because a level has
# more readouts than an item. Every box is derived from the window at runtime by
# AlmanacView._layout(), never from fixed pixels (HANDOFF 7.56).
## [P29-UI] UNITS / ITEMS / LEVELS, and [D78] PROJECTILES - the fourth tab both modes' almanacs
## share. The tab row is ALMANAC_TAB_COUNT boxes wide (4 x 190 + 3 x 12 = 796 px), which still
## fits the 8-cell grid band (852 px) it is centred on.
const ALMANAC_TAB_COUNT := 4
## Kept at 190 even though three tabs now share the row: the width is what a Chinese
## two-character word plus padding needs to look like a button, and three times 190 plus
## two gaps lands at 594 of the grid's 852 px - AlmanacView.self_check() asserts the row
## still fits the cells' column.
const ALMANAC_TAB_SIZE := Vector2(190.0, 40.0)
const ALMANAC_TAB_GAP := 12.0
## The tab row sits under the drawn header: the title baseline is MENU_TITLE_Y (96) and
## the subtitle MENU_TITLE_Y + MENU_SUB_OFFSET (130), so 140 clears both.
const ALMANAC_TAB_Y := 140.0
## [P29-UI] The race row: a smaller second row under the tabs, shown only while the
## UNITS section is up (植物 / 僵尸). Hidden on the other sections, but the row's band is
## kept either way so the grid never jumps when you switch sections.
const ALMANAC_RACE_COUNT := 2
## [B24] The CLASSIC page's race row: the turn page's two (植物 / 僵尸) plus the three piece
## factions the brawl owns (人类 / 怪兽 / 机械). Five buttons stand in
## scenes/ui/brawl_almanac.tscn; the base class wires the first two by the constant above and
## BrawlAlmanacView appends the rest up to THIS number, so adding a fourth faction is one scene
## node, one row here and one branch in the subclass - nothing else moves.
## [B39] 6 -> 7: the animals (动物) page, 卡比兽's faction's younger sibling.
const ALMANAC_BRAWL_RACE_COUNT := 7
const ALMANAC_RACE_SIZE := Vector2(150.0, 30.0)
const ALMANAC_RACE_GAP := 12.0
const ALMANAC_RACE_Y := 186.0          # the tab row ends at ALMANAC_TAB_Y + 40 = 180
## [P29-UI] The item row: the ITEMS section's second row (道具 / 装备 / 材料 / 货币).
## It REUSES the race row's geometry (same Y, same button box and gap) - both rows
## answer the same question one level under the tabs, and only one of them is ever up,
## so two constant sets would only be two chances to disagree about one line. Four
## times 150 plus three gaps lands at 636 of the grid's 852 px, which
## AlmanacView.self_check() audits like every other row.
const ALMANAC_GROUP_COUNT := 4
const ALMANAC_GRID_COLS := 8           # [P27] cells per row
## [P28] Rows one PAGE holds at the design window, i.e. 24 cells per page. The real
## number comes from the window (ItemGrid.capacity_for) - this is the design promise the
## self-check audits, and the reason the roster no longer has to fit one screen.
const ALMANAC_GRID_ROWS := 3
const ALMANAC_TILE_SIZE := Vector2(96.0, 116.0)   # [P27] this page's own cell box
## [P29-UI] Was 190; the race row (ALMANAC_RACE_Y + 30 = 216) has to clear it, so the
## cells start below both. The band's BOTTOM edge is unchanged (window height minus
## ALMANAC_BOTTOM_BAND), so the page bar and the panel's BACK keep their exact line.
const ALMANAC_GRID_TOP := 228.0        # first row of cells, from the top
const ALMANAC_BOTTOM_BAND := 54.0      # room kept for the hint line at the bottom
## [P28] The page bar: PREV at the left edge of the cell column, the "3 / 7" in the
## middle and NEXT at the right edge. It is as tall as the panel's BACK button and sits
## on the same line (ITEM_PANEL_BOTTOM above the band's bottom edge), so the two bottom
## controls of the page read as one row.
const ALMANAC_PAGE_BAR_H := 36.0       # the height of its buttons (= BACK)
const ALMANAC_PAGE_GAP := 12.0         # between the last row of cells and the bar
const ALMANAC_PAGE_BTN_W := 132.0
const ALMANAC_PAGE_LABEL_W := 200.0    # centred between the two buttons
const ALMANAC_PANEL_LINES := 9         # [P30-A4] the unit panels are the longest readout:
									   # a plant has 9 lines since the LOADOUT line joined
									   # the detail panel (a level still has 8)
## [P30-A5] The 9th line pushed the prose block under its 104px floor (the shared
## ITEM_PANEL_LINE_STEP=24 leaves a 2px gap per line the almanac does not need:
## its labels are exactly ITEM_PANEL_LINE_H=22 tall), so the panel rows breathe
## 2px tighter and the prose minimum survives. Only the almanac panel reads this.
const ALMANAC_PANEL_LINE_STEP := 22.0
const ALMANAC_PANEL_DESC_H := 104.0    # the prose block under those lines
const ALMANAC_TILE_DIM_ALPHA := 0.55   # a "not implemented yet" cell is dimmed

# [P27] The picture of the selected entry, in the top right corner of the detail panel.
# The unit sprites are 128x128 canvases, so the box is square and the frame around it is
# the same one the cells use (COLOR_ITEM_TILE_BG / _BORDER). The title and the lines
# that share the picture's rows are narrowed by ART_SIZE + GAP so nothing is written
# under it; TEXT_MIN_W is the floor that keeps a widened picture from squeezing the
# readouts away (AlmanacView.self_check() audits all three).
const ALMANAC_PANEL_ART_SIZE := 104.0  # square, from the panel's top right corner
const ALMANAC_PANEL_ART_TOP := 12.0    # from the panel's top edge
const ALMANAC_PANEL_ART_GAP := 12.0    # between the picture and the text column
const ALMANAC_PANEL_TEXT_MIN_W := 120.0

const COLOR_ALMANAC_TAB_ON := Color(0.95, 0.85, 0.35)     # the tab you are on
const COLOR_ALMANAC_TAB_OFF := Color(0.62, 0.66, 0.72)
const COLOR_ALMANAC_BADGE_PLANT := Color(0.95, 0.80, 0.20)    # the sun a plant costs
const COLOR_ALMANAC_BADGE_ZOMBIE := Color(0.88, 0.48, 0.48)   # a zombie's hp
const COLOR_ALMANAC_BADGE_ITEM := Color(0.62, 0.80, 0.95)     # [P27] an item's 价值
## [D75] The classic almanac's third race (humans): the same idea one door down - a cell's badge
## is coloured by WHICH KIND OF THING it is, so a page of mixed entries stays readable at a glance.
const COLOR_ALMANAC_BADGE_PIECE := Color(0.78, 0.72, 0.95)
## [B24] ...and the classic almanac's two remaining piece factions (怪兽 / 机械), same idea again:
## the badge says which KIND of body the cell is. They sit near the humans' violet so a page of
## pieces reads as a family, and apart enough that the three are never mistaken for each other.
const COLOR_ALMANAC_BADGE_MONSTER := Color(0.62, 0.86, 0.72)
const COLOR_ALMANAC_BADGE_MACHINE := Color(0.72, 0.80, 0.88)
## [B38] ...and the fourth piece faction (宝可梦). Kept WARM on purpose: the three above are
## violet / green / blue-grey, so the one badge colour a mixed page cannot mistake for a sibling is
## the amber nobody has taken yet.
const COLOR_ALMANAC_BADGE_POKEMON := Color(0.95, 0.74, 0.45)
## [B39] ...and the fifth piece faction (动物). TEAL, because every hue this page already wears is
## spoken for: gold is the plants', violet the humans', mint the monsters', blue-grey the machines'
## and amber the pokemon's. The badge only has to
## answer "which KIND of body is this cell" at a glance, and teal is the one colour on this page no
## sibling is wearing.
const COLOR_ALMANAC_BADGE_ANIMAL := Color(0.42, 0.78, 0.76)
## [D78] The projectile sub-almanac: a shot's badge (its speed) and the neutral tint the panel
## paints a code-drawn shot with. The tint is NEUTRAL on purpose - the board uses the SHOOTER's
## colour, and the almanac has no shooter; the arrow and the ball ignore it anyway (they own
## their palettes, see Projectile.draw_shot).
const COLOR_ALMANAC_BADGE_SHOT := Color(0.95, 0.72, 0.45)
const COLOR_ALMANAC_SHOT_TINT := Color(0.86, 0.90, 0.94)

# ---------------------------------------------------------------- garden screen (P25)
# Menu-style page. Top to bottom, all of it derived from Layout.size at runtime by
# GardenView._layout():
#   header    centred title + subtitle, shared with the menu (MENU_TITLE_Y ...)
#   tool bar  [P25] the four care items, TOP RIGHT, one cell each (was: inside the
#             detail panel, which now carries information only)
#   plots     BalanceGarden.GARDEN_COLS x GARDEN_ROWS cells on the left, each the biggest
#             square that fits the area (GARDEN_PLOT_MIN .. GARDEN_PLOT_MAX)
#   panel     right hand column: the selected plant's numbers, its talent, the advice
# The numbers below are the DESIGN values (1280 x 720).
const GARDEN_TITLE_BAND := 150.0        # page content starts below the page header
const GARDEN_SIDE_MARGIN := 24.0
const GARDEN_BOTTOM_BAND := 58.0        # room kept for the hint line at the bottom
const GARDEN_PLOT_GAP := 14.0
const GARDEN_PLOT_MIN := 84.0           # below this the plot's own text stops fitting
const GARDEN_PLOT_MAX := 150.0
const GARDEN_PANEL_W := 320.0
const GARDEN_PANEL_GAP := 24.0
const GARDEN_PANEL_INSET := 18.0
const GARDEN_PANEL_BOTTOM := 20.0
const GARDEN_PANEL_TITLE_Y := 18.0     # offsets INSIDE the detail panel
const GARDEN_PANEL_LINES_Y := 52.0
const GARDEN_PANEL_LINE_STEP := 24.0
## [P25] TYPE / LEVEL / HEALTH / STATE / TALENT - the talent has a line of its own now.
## It used to be glued onto the level line, which made that one line twice as long as
## every other line and hid the talent behind the level and the exp.
const GARDEN_PANEL_LINES := 5
const GARDEN_PANEL_STATUS_Y := 178.0
const GARDEN_PANEL_STATUS_H := 250.0    # the advice text gets the room the tools left
const GARDEN_BUTTON_HEIGHT := 38.0
const GARDEN_BUTTON_GAP := 12.0

# ---------------------------------------------------------------- garden tools (P24/P25)
# [P24] The garden's four care actions are ICON cells instead of text buttons: the
# picture says what the item IS, the badge says how many you have. Clicking a cell
# PICKS THE ITEM UP - the picture then follows the cursor (GARDEN_GHOST_SIZE) and the
# next click on a pot uses it THERE, so a potion goes to the plant you point at and
# not to whatever happened to be selected before.
#
# [P25] The cells sit in a BAR AT THE TOP RIGHT of the page, one row, level with the
# title - the first place a player looks for "what can I do here". The bar is sized by
# its cells and right-aligned to GARDEN_SIDE_MARGIN, so it can never fight the panel
# below it.
const GARDEN_TOOLBAR_Y := 20.0
const GARDEN_TOOL_SIZE := Vector2(112.0, 72.0)
const GARDEN_TOOL_GAP := 10.0
const GARDEN_TOOL_ICON := 42.0         # icon box inside one cell
const GARDEN_TOOL_ICON_TOP := 5.0
const GARDEN_TOOL_BADGE_PAD := 4.0     # padding inside the badge box
const GARDEN_TOOL_NAME_INSET := 4.0    # the name never touches the cell edge
const GARDEN_TOOL_NAME_BOTTOM := 7.0   # baseline of the name, from the bottom edge
## [P95] The PAGE BAR of the roster, level with the tool bar on the LEFT of the same
## header row: the tools are right-aligned, so the two can never meet at any window
## width, and the page / prev / next labels are the ones ItemGrid already uses
## (grid.page / grid.page.prev / grid.page.next) so every paged screen reads the same.
const GARDEN_PAGE_BAR_H := 40.0
const GARDEN_PAGE_BTN_W := 96.0
const GARDEN_PAGE_LABEL_W := 132.0
const GARDEN_PAGE_GAP := 10.0
const GARDEN_GHOST_SIZE := 64.0        # the picture that follows the cursor
const GARDEN_GHOST_ALPHA := 0.92
const GARDEN_TARGET_FRAME_W := 4.0     # frame on the pot under the cursor

# ---------------------------------------------------------------- one plot (P25)
# A plot draws, from its top edge down:
#   ribbon  a 5 px health strip along the whole top edge (green/amber/red = state)
#   row 1   "SLOT 3" on the left, the state word (or the DOWNED countdown) on the right
#   row 2   the plant's name
#   pot     the pot art, with the plant standing IN it - the one relationship that
#           matters is documented on GardenPlot._plant_ink_rect()
# Every offset is a RATIO of the cell, because the cell is sized to the window
# (GARDEN_PLOT_MIN .. GARDEN_PLOT_MAX). The old absolute pixels were tuned for one
# cell size and broke the moment the grid needed a 4th row: keep ratios here.
const GARDEN_HP_RIBBON_H := 5.0
const GARDEN_SLOT_Y_RATIO := 0.13      # row 1 baseline
const GARDEN_NAME_Y_RATIO := 0.28      # row 2 baseline
const GARDEN_INSET_RATIO := 0.05       # inset of "SLOT 3" / the state word
const GARDEN_POT_BOTTOM_PAD := 5.0
## The pot and the plant as ONE piece of geometry (GardenPlot._plant_ink_rect):
## the plant is centred on the pot, sized by its INK height, and its feet end
## GARDEN_PLANT_SINK of that height BELOW the pot's soil surface - that overlap is
## what makes it read as "planted" instead of "standing next to".
const GARDEN_POT_W_RATIO := 0.64       # the pot's ink width / the cell width
const GARDEN_POT_SOIL_RATIO := 0.16    # where the soil surface sits, in the pot's ink
const GARDEN_PLANT_INK_H_RATIO := 0.25 # the plant's ink height / the cell height
const GARDEN_PLANT_SINK := 0.10        # how deep the feet go below the soil surface
const ART_GARDEN_POT := "res://assets/svg/items/garden_pot.svg"
const GARDEN_POT_CANVAS := 128.0       # canvas the rect below is measured in
## The pot art's INK inside that canvas (same idea as MENU_ICONS' "content"): the art
## is drawn by its ink, not by its canvas, so changing the SVG's margins cannot move
## the pot or the plant standing on it.
const GARDEN_POT_CONTENT := Rect2(14.0, 40.0, 100.0, 76.0)
## The plant sprites' INK boxes, in their OWN texture pixels - read through
## plant_art_ink(), which consults this table FIRST and only [B35]'s auto_ink_box() after.
## They matter because these three carry very different empty margins (the wall-nut fills its
## canvas, the peashooter leaves 12% under its stem), and a 120 px cell shows every one of
## those pixels; the hand-measured rows are what P25's "measure before you place" left behind,
## and they OUTRANK the automatic box (see auto_ink_box's edge caveat for when to keep one).
const PLANT_ART_INK := {
	"peashooter": Rect2(18.0, 30.0, 92.0, 82.0),
	"sunflower": Rect2(18.0, 20.0, 92.0, 92.0),
	## wallnut.svg is 96x96 for a 100-unit viewBox, hence the .96 factors:
	## viewBox x 16..84, y 8..94 -> texture pixels x 15.4..80.6, y 7.7..90.2
	"wallnut": Rect2(15.4, 7.7, 65.3, 82.6),
}


static func plant_art_ink(p_plant_id: String, p_texture: Texture2D) -> Rect2:
	## [P25] What a plant sprite actually DRAWS, in its own texture's pixels. The TABLE row
	## wins while it lasts (the three measured plants keep their hand-tuned boxes, P25's
	## "measure first" experience); a plant without one gets [B35]'s automatic box instead
	## of the whole canvas, and only a texture that cannot answer at all still stands on
	## its full canvas (slightly smaller than the others) instead of dividing by zero.
	var measured: Rect2 = PLANT_ART_INK.get(p_plant_id, Rect2())
	if measured.size.x > 0.0 and measured.size.y > 0.0:
		return measured
	return auto_ink_box(p_texture)


static var _auto_ink_cache: Dictionary = {}


static func auto_ink_box(p_texture: Texture2D) -> Rect2:
	## [B35] THE AUTOMATIC INK BOX: the bounding rectangle of the texture's NOT-fully-transparent
	## pixels (Image.get_used_rect), so a new sprite does not need a hand-measured row to sit
	## correctly in the pot. ONE cost per texture, then cached - the scan walks every pixel once
	## (≈66k at 128², one-off, on the frame the pot first draws it).
	## ⚠ THE EDGE CAVEAT, stated once here because it decides when a row must be added BACK:
	## ThorVG anti-aliases SVG outlines, so pixels 1-2 outside the visible ink carry a faint
	## alpha and count as "used". If a plant ever reads as a size too big / feet sunk too deep,
	## the fix is a measured PLANT_ART_INK row (the table still outranks this door), not a
	## threshold in here.
	## ⚠ THE CONTRACT THAT KEEPS THIS ALIVE: the sprites import as lossless RGBA with no VRAM
	## texture (compress/mode=0, vram_texture=false in every .svg.import). If an art pass ever
	## compresses or atlases one, get_image() answers null and this quietly degrades to the old
	## whole-canvas fallback - which is why the null paths return rather than assert.
	if p_texture == null:
		return Rect2()
	var key := p_texture.resource_path
	if key == "":
		## An unnamed texture has no stable cache key; measuring every draw would be the P38
		## waste this file always refused, so a one-off texture simply goes unmeasured.
		key = str(p_texture.get_instance_id())
	if _auto_ink_cache.has(key):
		return _auto_ink_cache[key]
	var box := Rect2(Vector2.ZERO, p_texture.get_size())
	var img := p_texture.get_image()
	if img != null:
		var used := img.get_used_rect()
		## An all-transparent texture answers an EMPTY rect (Rect2i has no is_empty - [B35]).
		if used.size.x > 0 and used.size.y > 0:
			box = Rect2(used)
	_auto_ink_cache[key] = box
	return box

# ---------------------------------------------------------------- potion mark geometry (P23)
## [P70] The other half of a talent potion's two-layer picture, cut out of Balance by the
## same test as the view numbers. Which BOTTLE an item uses is a data answer
## (Balance.POTION_TIER_PATHS, read through Balance.potion_bottle_art() and the item DB),
## but where the plant MARK lands on that bottle is only ever a drawing answer - and
## UnitArt.draw_potion_icon() is its one reader, sitting here beside GARDEN_POT_CANVAS and
## PLANT_ART_INK, which measure exactly the same kind of thing.
const POTION_ART_CANVAS := 128.0         # canvas the rect below is measured in
## The blank top area of every generic bottle, in bottle-canvas pixels - the plant
## mark belongs in here (the cork sits at y 14..30, the glass body starts at y 46).
const POTION_MARK_AREA := Rect2(44.0, 10.0, 40.0, 28.0)
## How much of the drawn icon box one mark takes: 0.3 of the 128 canvas = 38 px, the
## readme's number. It is wider than the area is TALL on purpose - a unit sprite
## carries empty margin around the plant, so the ink lands inside the area.
const POTION_MARK_SCALE := 0.3

# ---------------------------------------------------------------- scroll mark geometry (P92)
## [P92] The same two-layer picture for a SUMMON SCROLL: the one scroll svg every scroll row
## names, plus the plant that scroll unlocks - so 寒冰射手卷轴 and 向日葵卷轴 stop looking like
## the same object. The numbers are measured in the scroll svg's own 0..100 viewBox: the
## parchment body is the rect x 20..80, y 14..86, and the mark lands on its blank middle.
const SCROLL_ART_CANVAS := 100.0
## The blank face of the parchment, in scroll-canvas units (inside x 20..80 / y 14..86)
const SCROLL_MARK_AREA := Rect2(30.0, 36.0, 40.0, 32.0)
## Slightly smaller than the potion's 0.3: the parchment is narrower than the bottle, and a
## bigger mark would reach over the axle bands at the top and bottom of the scroll.
const SCROLL_MARK_SCALE := 0.26

# ---------------------------------------------------------------- plant chest mark (P95)
## [P95] A PLANT CHEST is the same two-layer picture one level further: the one chest svg
## every chest row names (ui/chest_closed), plus the plant inside it. The chest's own
## 0..100 canvas is full below y 30 (body 18..82 x 30..86, two gold bands, the lock), so
## the mark goes in the EMPTY strip ABOVE the lid - a plant standing on the chest rather
## than a plant drawn over its hardware. Only the CENTRE of the area is read (see
## UnitArt.draw_item_icon), so the rect is a position, not a box.
const CHEST_ART_CANVAS := 100.0
const CHEST_MARK_AREA := Rect2(34.0, 2.0, 32.0, 28.0)
const CHEST_MARK_SCALE := 0.30

# ---------------------------------------------------------------- first-clear chest (P93)
## [P93] The chest drawn beside a cleared level on the level list. The two PICTURES are
## code-named paths (a missing file is a FAIL in [Art], not a silent blank) and the glow
## behind a claimable one is drawn here rather than baked into the svg, so it can pulse.
const ART_CHEST_CLOSED := "res://assets/svg/ui/chest_closed.svg"
const ART_CHEST_OPEN := "res://assets/svg/ui/chest_open.svg"
## [P96] The box the picture is drawn in is LEVEL_CARD_CHEST now: the chest lives in a
const CHEST_GLOW_RADIUS := 26.0
const CHEST_GLOW_RINGS := 3
const CHEST_GLOW_COLOR := Color(1.00, 0.86, 0.35)
const CHEST_GLOW_ALPHA := 0.22           # the outermost ring; inner ones are brighter
const CHEST_GLOW_PULSE_SPEED := 2.2      # radians per second


static func chest_art_paths() -> Array:
	## What [Art] has to be able to load for the chest (see unit_art.gd code_art_paths).
	return [ART_CHEST_CLOSED, ART_CHEST_OPEN]


static func mark_geometry(p_kind: String) -> Dictionary:
	## [P92] WHERE a plant mark lands on an item's base picture, per KIND of item. One reader
	## (UnitArt.draw_item_icon) and one table, which is what keeps a scroll looking the same
	## in the warehouse, the shop, the backpack and the almanac. A kind with no entry draws
	## its icon plain - that is the answer for every other item, not an error.
	match p_kind:
		"talent":
			return {"canvas": POTION_ART_CANVAS, "area": POTION_MARK_AREA, "scale": POTION_MARK_SCALE}
		"scroll":
			return {"canvas": SCROLL_ART_CANVAS, "area": SCROLL_MARK_AREA, "scale": SCROLL_MARK_SCALE}
		"plant_chest":
			return {"canvas": CHEST_ART_CANVAS, "area": CHEST_MARK_AREA, "scale": CHEST_MARK_SCALE}
	return {}


## [P25] The pot is an SVG now (ART_GARDEN_POT), so this colour is only the GDScript
## half of the palette pair: the soil band inside the pot is drawn with it in the file.
## Same rule as Balance.COLOR_PEASHOOTER and friends - change both, or the two drift apart.
const COLOR_GARDEN_SOIL := Color(0.34, 0.24, 0.16)
const COLOR_GARDEN_EMPTY := Color(0.11, 0.13, 0.16)
const COLOR_GARDEN_EMPTY_LINE := Color(0.24, 0.28, 0.33)
const COLOR_GARDEN_SELECTED := Color(0.95, 0.85, 0.35)
const COLOR_GARDEN_OK := Color(0.55, 0.90, 0.60)
const COLOR_GARDEN_WOUNDED := Color(0.95, 0.75, 0.35)
const COLOR_GARDEN_DOWNED := Color(0.90, 0.40, 0.40)
const COLOR_GARDEN_DOWNED_TINT := Color(0.42, 0.42, 0.48, 0.85)
const COLOR_WATER := Color(0.35, 0.65, 0.95)
const COLOR_FERTILIZER := Color(0.72, 0.58, 0.34)
## [P24] one garden tool cell: idle, hovered, and the frame of the item in hand
## (which shares the gold of a selected plot on purpose).
const COLOR_GARDEN_TOOL_BG := Color(0.13, 0.16, 0.20)
const COLOR_GARDEN_TOOL_HOVER := Color(0.19, 0.23, 0.29)
const COLOR_GARDEN_TOOL_DIM := Color(1.0, 1.0, 1.0, 0.32)   # icon of an empty stock
const COLOR_GARDEN_TOOL_BADGE_BG := Color(0.05, 0.07, 0.10, 0.88)
const COLOR_COIN_SILVER := Color(0.80, 0.83, 0.88)   # [P14] drop / warehouse colours
const COLOR_COIN_GOLD := Color(0.95, 0.80, 0.25)
const COLOR_COIN_DIAMOND := Color(0.55, 0.90, 0.95)
const COLOR_MONEY := Color(0.95, 0.85, 0.45)
const COLOR_LOCKED := Color(0.85, 0.40, 0.40)        # "no scroll" card state
const FONT_SIZE_GARDEN_TITLE := 20
const FONT_SIZE_GARDEN_LINE := 15
const FONT_SIZE_GARDEN_STATE := 10
const FONT_SIZE_GARDEN_TOOL := 12      # [P24] the name under a tool icon
const FONT_SIZE_GARDEN_TOOL_BADGE := 11

# ---------------------------------------------------------------- run screens (P31-A)
# [P31-A] The four adventure pages (squad / roadmap / reward pick / node choice)
# share ONE skeleton, built by scripts/ui/run_screen.gd: menu-style header, a few
# wrapped body lines, stacked ROW GROUPS (one line per group - the roadmap's
# layers, the squad's pairs of plants), a status line, footer buttons and BACK.
# All numbers are design-window (1280 x 720) pixels; the column is centred.
const RUN_COL_W := 620.0               # width of the button column
const RUN_TOP := 172.0                 # first body line / first row group, from the top
const RUN_ROW_H := 38.0                # one row button (= the footer / BACK height)
const RUN_ROW_GAP := 6.0               # vertical space between two lines
const RUN_GROUP_GAP := 10.0            # horizontal space between two buttons of one line
const RUN_BODY_LINE_H := 24.0          # one wrapped body line
const RUN_BODY_GAP := 14.0             # space between the body block and the rows
const RUN_STATUS_H := 26.0             # the last action's answer line
const RUN_FOOTER_GAP := 12.0
## [P98] 32 = the deck page's 6 seed slots + two 12-tile regions; the other run pages use
## a fraction of it (16-plant squad / 14-node chapter).
const RUN_MAX_ROWS := 32               # pooled row buttons
const RUN_MAX_BODY := 4                # pooled body labels
const RUN_MAX_FOOTERS := 2             # SET OUT + friends; BACK is its own button
## Row text colours: which of these could the player act on RIGHT now.
const COLOR_RUN_PICKED := Color(0.95, 0.85, 0.35)    # enlisted / the node you stand in
const COLOR_RUN_OPEN := Color(0.45, 0.95, 0.55)      # an enterable node
const COLOR_RUN_DONE := Color(0.62, 0.66, 0.72)      # cleared (read-only)
const COLOR_RUN_LOCKED := Color(0.35, 0.38, 0.44)    # not reachable yet

# ------------------------------------------------------- roadmap graph (P31-UI)
# [P31-UI] The CAMPAIGN ROUTE draws its layers as an ICON GRAPH instead of the
# shared text column: one COLUMN per layer (left -> right), one TILE per node,
# an EDGE per `next` link. Only roadmap_view.gd reads these numbers.
const RUN_GRAPH_PAD_X := 60.0          # the graph band keeps this much air left/right
const RUN_GRAPH_BOTTOM_RESERVE := 150.0 # status + BACK + hint live under the band
const RUN_GRAPH_MIN_H := 120.0         # never squeeze the band below this
const RUN_NODE_MAX := 72.0             # tile side ceiling (design-window px)
const RUN_NODE_MIN := 40.0             # tile side floor; labels take the hit instead
const RUN_NODE_COL_SHARE := 0.50       # tile side / column width
const RUN_NODE_ROW_SHARE := 0.62       # tile side / (band height / busiest layer)
const RUN_NODE_PITCH_Y := 112.0        # wanted vertical distance between tiles
const RUN_GRAPH_LABEL_H := 24.0        # the title line under a tile
const RUN_NODE_CORNER := 10.0          # tile corner radius
const RUN_TILE_BORDER_W := 2.0         # locked / done tiles get the thin edge
const RUN_TILE_LIVE_W := 3.0           # an enterable tile
const RUN_TILE_CURRENT_W := 4.0        # the tile you stand in
const RUN_NODE_ICON_SHARE := 0.78      # icon side / tile side
const RUN_LINE_W := 3.0
const FONT_SIZE_RUN_NODE_LABEL := 14
const FONT_SIZE_RUN_NODE_FEE := 12
const COLOR_RUN_NODE_BG := Color(0.13, 0.15, 0.19)
const COLOR_RUN_LINE := Color(0.30, 0.33, 0.38)          # an edge not travelled yet
const COLOR_RUN_LINE_DONE := Color(0.50, 0.54, 0.60)     # edge between two cleared nodes
const COLOR_RUN_LINE_LIVE := Color(0.45, 0.95, 0.55)     # edge leading INTO a live node
const COLOR_RUN_ICON_DIM := Color(0.55, 0.55, 0.62, 0.45) # a locked node's icon
const COLOR_RUN_ICON_DONE := Color(0.80, 0.82, 0.86, 0.85)
## The node-type picture. Reuses imported SVGs the almanac/units already ship, so
## no new art is needed: a wave of zombies, the chapter's gargantuar, the shop's
## key, the event scroll, the treasure crate and the garden pot you rest beside.
const RUN_NODE_ART := {
	"battle": "res://assets/svg/units/zombies/zombie.svg",
	"boss": "res://assets/svg/units/zombies/zombie_gargantuar.svg",
	"shop": "res://assets/svg/items/shop_key.svg",
	"event": "res://assets/svg/items/scroll.svg",
	"treasure": "res://assets/svg/items/warehouse_crate.svg",
	"rest": "res://assets/svg/items/garden_pot.svg",
}

# ------------------------------------------------------- deck select tiles (P32-UI)
# [P32-UI] The seed-picking page draws its two bands - the seed SLOTS row on top
# and the owned-card pool below - as self-painted tiles over the RunScreen button
# pool (the roadmap's trick). Colours, corner radius and the label/fee fonts are
# the shared roadmap vocabulary on purpose; only the geometry unique to the deck
# page lives here. Only deck_view.gd reads these numbers.
const DECK_TILE_SIDE := 110.0          # tile side ceiling (design-window px)
const DECK_TILE_MIN := 62.0            # tile side floor; the page shrinks to fit width
const DECK_TILE_GAP := 12.0            # space between two tiles in a line
const DECK_POOL_COLS := 6              # pool tiles per row (matches the slot row width)
const DECK_BAND_GAP := 16.0            # between the slot band and the pool regions
const DECK_HEAD_H := 22.0              # one band heading line

# ---------------------------------------------------------------- deck regions (P98)
## [P98] The card pool is TWO REGIONS side by side (花园卷轴 / 灵界卷轴), each showing ONE
## PAGE of DECK_REGION_COLS x DECK_REGION_ROWS tiles; one page bar under them turns both, so
## the two sides always show the same page number. The 49-card roster used to run straight
## past the bottom of the window (9 rows do not fit 720 px).
const DECK_SLOT_TILE := 78.0            # the seed-slot band's tile side
const DECK_SLOT_LABEL_H := 28.0         # name + cost under a slot tile
const DECK_REGION_COLS := 6             # tiles per line inside one region
const DECK_REGION_ROWS := 2             # lines per region per page (12 cards a page)
const DECK_REGION_GAP := 28.0           # between the two regions
const DECK_PAGE_BAR_H := 24.0           # PREV / "page i / n" / NEXT under the regions
const DECK_PAGE_BTN_W := 78.0
const DECK_PAGE_LABEL_W := 120.0
const DECK_PAGE_GAP := 8.0
## [P32-UI] The scroll-kind corner badge: every card tile wears a one-character
## chip top-right saying WHICH scroll summons it - 园/green for a garden scroll,
## 灵/blue for a spirit scroll (the blue is the board's own COLOR_SPIRIT_TINT, so
## the badge and the icon tint on the same tile say one thing).
const DECK_BADGE_SIDE := 18.0          # badge chip side (design-window px)
const DECK_BADGE_INSET := 3.0          # gap from the tile's top-right corner
const FONT_SIZE_DECK_BADGE := 12       # the one character inside the chip
const COLOR_DECK_BADGE_GARDEN := Color(0.55, 0.85, 0.55)
const COLOR_DECK_BADGE_TEXT := Color(0.08, 0.10, 0.13)   # dark ink on both chips

# ------------------------------------------ overlay tints, stack offset, ui tick (P71)
## [P71] C9's third cut: the seven leftovers the reader census counted (plan §1 P70 item 3).
## Each of these has ONE drawing reader and no rule reader at all, which is exactly why they
## never travelled with a group: they are not a family, they are the residue. Only the host
## file changed - every value is byte-identical to the line it replaces.
## The cell tints a tool wears while it is being aimed: Grid._draw_tool_tint() paints the
## candidate cell (fill + a 3 px outline) and the picked source cell, and lightens the fill
## under the cursor. The three per-tool IDENTITY colours stayed in Balance because TOOL_DEFS
## carries them as a column - a dict whose two columns belong to different readers
## (AGENTS §2 ④), so splitting the block would tear one table in half.
const COLOR_TOOL_READY := Color(0.45, 0.95, 0.55)
const COLOR_TOOL_TARGET := Color(1.00, 0.62, 0.20, 0.22)
const COLOR_TOOL_TARGET_LINE := Color(1.00, 0.74, 0.30, 0.95)
const COLOR_TOOL_SOURCE := Color(0.40, 0.75, 1.00, 0.30)
## Several zombies may share one tile (original PvZ behaviour); these two numbers only
## decide WHERE a shared body is painted - they feed `Unit.position` through
## Unit.stack_offset(), and every rule in the battle reads the CELL (col/row), never pixels.
## Who may stack at all is behaviour, and the game_self_checks probe at `:355` is what keeps
## the two halves agreeing.
const STACK_OFFSET_STEP := Vector2(12.0, 9.0)
const STACK_OFFSET_MAX_INDEX := 2      # 3 distinct slots; extra units reuse the last one
## How often the GARDEN PAGE repaints its countdown labels (GardenView._process). The
## recovery rules those labels display - Balance.recovery_seconds, RECOVERY_BASE_SECONDS,
## NATURAL_RECOVERY_HP_RATIO - all stayed in Balance: this is a paint timer, not a game clock.
const GARDEN_TICK := 0.5                # how often the garden page refreshes countdowns

# ---------------------------------------------------------------- [B1] the brawl arena
## Read by scripts/core/brawl/brawl_field.gd and nothing else: the two deployment halves and
## the strip of no man's land between them (docs/prompt/BRAWL.md §3.1 - 4 columns | 1 | 4).
## They are HERE rather than in BalanceBrawl because colour is presentation, which is the
## same division every other colour in this project already obeys.
## [B2c] and the formation page's own pixels: how far a piece's icon sits inside its cell and
## how thick the lattice is. Read by scripts/ui/brawl/brawl_formation.gd (and the grid by
## brawl_field.gd) only.
## [S2] NOTHING ON THIS PAGE IS MEASURED against the chrome the TURN ENGINE reserves any more -
## that is BrawlLayout's job now (see the budget block below). What D67 deleted was the RIGHT
## column, because the offers had moved into the band and the bag kept the left one.
## [B26] The shop lost its PAGE, but no new region was carved out for it either: the shelf lies ON
## the board, over the enemy half (the user's correction: "商店选项直接覆盖战场上右侧的敌阵区，而不是
## 开出来一个新的区域专门放商店选项"). The page therefore still reads bag | board - the board's own
## width is what the shelf pays for itself with.
const BRAWL_MARGIN := 8.0
## [S2] One offer card, and the height of the whole band under the board (D67) - the offers are
## laid out in a row in it now, so the card and the strip are the same 46 px by construction.
## [B28] It holds TWO lines of the band's type (BRAWL_OFFER_FONT_SIZE), which is what a card that
## names an opponent, counts it and prices its 战力 needs - and it is the reason that type is 14
## rather than 18: the height the band does not take comes off the board, cell for cell.
const BRAWL_POOL_TILE_H := 46.0
const BRAWL_POOL_GAP := 8.0             # between two cells of the band's strip (opponents, 商店)
## [S2] THE BRAWL'S OWN LAYOUT BUDGET (docs/prompt/BRAWL.md §10.2, D65-D69). Read by
## scripts/core/brawl/brawl_layout.gd and by nothing else - the page and the arena both take their
## rectangles from there, so these numbers have exactly one reader and one owner.
##
## The arithmetic they encode, at the 1280x720 design window (cell = c):
##   height: 2*8 margin + 48 top band + 6 + 5c board + 4 + 0.72c bench + 4 + 46 band <= 720
##           => 5.72c <= 596 => c = 104  (board 936x520 = 53% of the screen; the old shared
##           with the turn engine's chrome was 864x480 = 45%)
##   width : 2*8 margin + 64 bag column + 12 + 9c board <= 1280
##           => c <= 132 (not the wall at the design window, and it stays NOT one: the shelf [B26]
##           lies ON the board rather than beside it, so it costs the cell nothing)
## The bench row is priced in CELLS rather than pixels because its pitch is one cell (D39) and
## its height should follow the board: 0.72 of a cell is what a slot needs for an icon, a name
## and the three attachment squares.
const BRAWL_TOP_BAR_H := 48.0           # the shared header: two lines, both pages
const BRAWL_TOP_TITLE_BASELINE := 26.0  # baseline of line 1 (title / score)
const BRAWL_TOP_LINE_PAD := 8.0         # line 2's baseline sits this far above the band's foot
const BRAWL_TOP_TITLE_FONT_SIZE := 24
const BRAWL_TOP_STATUS_FONT_SIZE := 16
const BRAWL_TOP_HINT_FONT_SIZE := 14
## [P111] THE SIDE-HP TUG-OF-WAR on top-bar line 1, in the empty middle between the left text
## (brawl's score / war's round) and the right text (the clock). One thin strip per side faces the
## other: ally (SIDE_LEFT, green) hugs the left, enemy (SIDE_RIGHT, red) hugs the right, each with
## its `cur/peak` number. The denominator is the side's HP when the bout opened (the roster is
## fixed for the bout, so it only ever falls - the bar never grows). Pure presentation → here.
const BRAWL_SIDE_BAR_W := 120.0            # nominal length of one strip (shrinks to fit the gap)
const BRAWL_SIDE_BAR_H := 8.0              # strip thickness
const BRAWL_SIDE_BAR_LINE_Y := 12.0        # strip's top edge, inside the 48 px band on line 1
const BRAWL_SIDE_BAR_GAP := 6.0            # between a strip and its own number
const BRAWL_SIDE_BAR_TEXT_PAD := 16.0      # between an end text and the strip nearest it
const BRAWL_SIDE_BAR_TEXT_TO_TEXT_GAP := 16.0  # center gutter between the two numbers
const BRAWL_SIDE_BAR_MIN_W := 24.0         # narrower than this and the pair is dropped, not crushed
const COLOR_SIDE_BAR_ALLY := Color(0.35, 0.78, 0.42)
const COLOR_SIDE_BAR_ENEMY := Color(0.86, 0.32, 0.30)
const BRAWL_TOP_GAP := 6.0              # between the header and the board
const BRAWL_ROW_GAP := 4.0              # between board / bench row / band
const BRAWL_BENCH_BAR_SHARE := 0.72     # bench row height, as a share of cell
const BRAWL_BENCH_SLOT_SHARE := 0.90    # slot box width, as a share of cell (pitch stays = cell)
## NOTE: the band's height is BRAWL_POOL_TILE_H (above) - one offer card tall, so the cards fill
## the strip exactly. There is deliberately no second constant holding the same 46.
const BRAWL_BAG_W := 64.0               # the bag column, left of the board (O38: one column)
const BRAWL_BAG_GAP := 12.0             # between that column and the board
## [B26] THE SHELF, laid OVER the board's enemy half (the user's call, 2026-10-08: "现在右侧有一个
## 购买棋子的区域，商店不用另外开页面了", corrected the same evening: "商店选项直接覆盖战场上右侧的
## 敌阵区，而不是开出来一个新的区域专门放商店选项"). D67 deleted this side of the page because the
## offers had moved into the band; what comes back is not a COLUMN - it is the right four columns of
## the board itself, so the shelf costs no board width and no cell size, and a purchase is made while
## the player is still looking at the formation it is for.
## THERE IS NO WIDTH CONSTANT HERE ON PURPOSE: the shelf is as wide as
## BrawlField.half_rect(SIDE_RIGHT) is, which is HALF_COLS cells - the same rectangle the enemy
## pieces would stand in. Only the row metrics are authored.
## [B27] It covers that half ONLY WHILE THE PLAYER ASKS FOR IT (the user, 2026-10-08: "敌阵选项里
## 点击商店才会把货架UI覆盖敌阵，点击某敌阵时会显示对应敌阵"), so the same four columns serve both
## things the page shows: the opponent's preview, or the shelf. Nothing about the GEOMETRY changed
## with that - what the toggle opens is the panel, not a rectangle.
## A shelf row is a BUTTON, not a drawn tile - the one exception on this page besides the band, and
## for the same reason: buying is a click on a line of text. The height clamps between a readable
## minimum and a little under a fifth of the board (the half is exactly Balance.ROWS cells tall, so
## MAX at 88 means five rows can fill a design-window half and a cramped window still gets five
## legible lines instead of five banners).
const BRAWL_SHOP_FONT_SIZE := 15
const BRAWL_SHOP_ROW_MIN_H := 44.0
const BRAWL_SHOP_ROW_MAX_H := 88.0
const BRAWL_SHOP_ROW_GAP := 6.0
const BRAWL_BAND_ENGAGE_W := 120.0      # 出战, pinned to the band's right end
## [B15] 遣散, pinned to the band's LEFT end. The same width as 出战 on purpose - the two ends
## of the band are the two things a player does with a round (throw a piece away / commit it),
## and a mismatched pair would read as one being an afterthought. What it costs is the offers'
## width, so this is the number to reach for if a card in the band ever gets too narrow.
const BRAWL_BAND_DISMISS_W := 120.0
## [B27] THE SHELF'S DOOR, the cell of the offers strip that sits right of 遣散 (the user,
## 2026-10-08: "敌阵选项里点击商店才会把货架UI覆盖敌阵，点击某敌阵时会显示对应敌阵"). It is a WIDTH
## rather than a fourth equal card because it is not an opponent: the three 敌阵 cards are the round's
## choice and each needs its name and count, this one says two characters. It is capped to a quarter
## of the strip by BrawlFormation._layout_columns(), so a window narrow enough to make 120 too much
## takes the toggle's width back rather than the offers'.
## WHY IT IS NOT NEXT TO 出战: a stray click here costs a redraw, a stray click on 出战 spends the
## round. The two are kept as far apart as the band allows, which is the same rule [B15] used for
## 遣散 - the destructive door sits at the end away from the commit.
const BRAWL_BAND_SHOP_W := 120.0
## [B28] THE OFFER CARD'S TYPE - and it went 18 → 14 for a reason worth keeping: a card now carries
## THREE facts (name / count / 战力) and reads as TWO lines, while the band is one card tall by
## construction (BRAWL_POOL_TILE_H, 46). Two lines of 18 need ~56, and the band is the one number in
## this block that the BOARD pays for: at the 1280x720 design window the height budget leaves the
## cell 2 px in total (avail_h 596 => 104; a 47 px band still floors to 104, a 48 px band drops it to
## 103), so growing the strip would shrink every piece on the field - the wall [B26] was routed
## around. 14 px is the size that answers the arithmetic rather than a taste: a Button keeps ~4 px
## of content margin, so the band leaves ~38 for text, and two lines need ~19 each - which is what a
## CJK fallback draws at 14, and would have been ~24 at 18. If a card ever clips, the FIRST lever is
## BRAWL_POOL_TILE_H 46 → 47 (cell still 104), only then 48 (cell 103). The 商店 cell wears this same
## size (BrawlFormation._build()), because a strip of two sizes reads as two strips.
const BRAWL_OFFER_FONT_SIZE := 14       # a band card - opponent or 商店 cell, never a shelf row
## [D68] The arena draws the lattice too, at this fraction of its colour: a spectator wants the
## field, not a chessboard, but the two pages must read as the same place.
const BRAWL_GRID_ARENA_ALPHA := 0.35
## [D72] A piece's picture follows the brawl's cell: this is the clamp on cell / Balance.CELL_SIZE
## (the design cell the 60 px art box was measured for), so a cramped window cannot shrink a unit
## into a dot and a huge one cannot turn it into a billboard.
const BRAWL_PIECE_SHARE_MIN := 0.6
const BRAWL_PIECE_SHARE_MAX := 1.5
const BRAWL_CELL_INSET := 8.0
const BRAWL_GRID_WIDTH := 1.0
## [B17] THE HEIGHT AXIS, as far as the DRAWER is concerned (docs/prompt/HEIGHT.md §8).
## BRAWL_AIR_Z is the layer a body with z_height > 0 is lifted to: above every grounded piece
## (0, and the belly's 1), below the FX (100) - a floating unit is seen, never a decoration.
## THE SHADOW constants belong to brawl_shadow.gd and to nothing else: one ellipse per living
## body under its ground point, GROUND UNITS INCLUDED (D102 - the shadow is the ground anchor
## that makes "flew up" readable at all). Alpha and size fade on ONE curve,
## 1 / (1 + z * FALLOFF), so a rising body shrinks and dims together and lands back exactly.
## [B36] THE ELLIPSE TAKES ITS SIZE FROM THE BODY, not from the cell (D111): the width is the
## measured ink width (Unit.art_ink() / UnitArt.ink_rect()) and the ground depth is HALF of that
## width - the same footprint arithmetic the collision shape is authored with (D99's
## `body_depth = body_width / 2`). What used to be here - a width ratio of the cell and a flatten
## ratio of the shadow's own - is gone; only this share and the curve survive. The ink's HEIGHT is
## not a drawing number at all: it is the body's reach on the height axis, and `Unit.read_height()`
## reads it into `z_thickness` there (D112) - and since [B37] D113 the ink is the WHOLE answer,
## because the 1-cell floor that used to swallow it is retired: a body painted short now really
## does reach less, which is the cost the user took on when ink became the ruler.
const BRAWL_AIR_Z := 10
## [B39] ...and the layer a TRAVELLING WHIRLWIND is drawn on (brawl_tornado.gd): above every body,
## grounded or airborne, because the whirlwind is the thing currently happening to them - and still
## under the FX (100), because it is a body of the bout and not a decoration laid over it.
const BRAWL_TORNADO_Z := 20
const BRAWL_SHADOW_FALLOFF := 0.8       # per cell of height: how fast the shadow shrinks and dims
const BRAWL_SHADOW_DEPTH_SHARE := 0.5   # ellipse depth / its width (D99's body_depth = width/2)
const COLOR_BRAWL_SHADOW := Color(0.0, 0.0, 0.0, 0.35)
## The glyph drawn in an enemy cell whose occupant is hidden (SettingsStore.show_enemy_pieces).
const BRAWL_MARK_FONT_SIZE := 28
const COLOR_BRAWL_LEFT := Color(0.22, 0.38, 0.58, 0.55)
const COLOR_BRAWL_RIGHT := Color(0.58, 0.26, 0.24, 0.55)
const COLOR_BRAWL_GAP := Color(0.13, 0.14, 0.17, 0.80)
## [B5+] THE BENCH and the hover panel, both drawn by scripts/ui/brawl/brawl_formation.gd alone.
## THE BENCH IS ONE ROW OF NINE SLOTS UNDER THE BOARD, and the PITCH of that row is still exactly
## one board cell: slot k sits under column k, so the row reads as a continuation of the board
## instead of a separate shelf (D39, kept). What changed in [S2] is the BOX: it is
## BRAWL_BENCH_SLOT_SHARE of a cell, centred in its own pitch (D69), because a full cell of height
## under the board is the single most expensive thing on the page - see the budget block below.
## A slot this tall has room for a readable name under the icon.
const BRAWL_BENCH_NAME_FONT_SIZE := 15
const BRAWL_BENCH_NAME_H := 22.0
## An empty slot: the same frame as an occupied one, dimmer, and never a hover target.
const COLOR_BRAWL_BENCH_EMPTY := Color(0.10, 0.12, 0.15)
## [B7] THE BAG AND THE THREE ATTACHMENT SLOTS, all drawn by brawl_formation.gd alone.
## [S2] THE BAG OWNS THE LEFT COLUMN NOW (D67, the user's call: "背包改为左侧一列"): the two text
## lines that used to share it moved into the shared header (BrawlHUD), so the column is the bag
## and nothing else, from the board's top edge down to the band's bottom. It is a grid of tiles,
## not a Button, exactly as the bench row is. BRAWL_BAG_COLS tiles fill the column's width; how
## many rows fit is computed from the box at layout time, and a bag longer than the box puts a
## "+N" mark in the LAST tile (the bag itself has no capacity - O38 - so the mark is a drawing
## limit, not a rule).
const BRAWL_BAG_COLS := 1
## How many bag rows the column may show at most. The column is as tall as the board, the bench
## row and the band together, so this is a cap for absurd windows rather than a real limit.
const BRAWL_BAG_ROWS_MAX := 12
const BRAWL_BAG_TILE_GAP := 4.0
## [B26] THE CAPTION LINE at the head of a panel, and the height it reserves. Named for the COLUMN
## rather than for the bag because the bag's head and [B26]'s shelf head spend these same two numbers
## (the shelf is a panel over the board's right half, not a column - it just heads itself the way the
## bag heads its own). They were BRAWL_BAG_TITLE_* while the bag was the only one.
const BRAWL_COLUMN_TITLE_FONT_SIZE := 14
const BRAWL_COLUMN_TITLE_H := 20.0
const BRAWL_BAG_ICON_H := 34.0
## The bag's icon is the SAME picture the turn-mode menu hangs on its backpack prop: one item,
## one file, and the constant that names it already exists (ART_ICON_BACKPACK below).
const BRAWL_BAG_MORE_FONT_SIZE := 14
const COLOR_BRAWL_BAG_MORE := Color(0.62, 0.68, 0.76)
## The three attachment squares along the bottom of a piece's cell. Their height is a FRACTION of
## the cell (not a constant) so a shrunk board shrinks them with it, and they never exceed
## BRAWL_SLOT_MAX_H - a cell that fits no readable square draws the row anyway, dimmer, so the
## three slots stay visible as capacity (the same rule the bench's empty frames follow).
const BRAWL_SLOT_ROW_RATIO := 0.26
const BRAWL_SLOT_MAX_H := 18.0
const BRAWL_SLOT_GAP := 2.0
const COLOR_BRAWL_SLOT_EMPTY := Color(0.12, 0.14, 0.18, 0.90)
const COLOR_BRAWL_SLOT_FILLED := Color(0.34, 0.46, 0.60, 0.95)
const COLOR_BRAWL_SLOT_BORDER := Color(0.42, 0.48, 0.56)
## How far the pointer must travel with the button held before a CLICK becomes a DRAG. Below it
## the press is the old two-step click (pick up / put down), so both idioms live on one button.
const BRAWL_DRAG_THRESHOLD := 6.0
const BRAWL_DRAG_ALPHA := 0.85
## The hover panel: one fixed width, one line per stat, drawn beside the cursor and flipped to
## the other side when it would leave the page.
const BRAWL_INFO_WIDTH := 272.0
const BRAWL_INFO_PAD := 8.0
const BRAWL_INFO_LINE_H := 19.0
const BRAWL_INFO_FONT_SIZE := 14
const BRAWL_INFO_TITLE_FONT_SIZE := 18
const BRAWL_INFO_MARGIN := 14.0
const COLOR_BRAWL_INFO_BG := Color(0.07, 0.09, 0.12, 0.96)
const COLOR_BRAWL_INFO_BORDER := Color(0.35, 0.42, 0.50)
## What a cell under a dragged piece wears when it CANNOT take it (the enemy half, no man's
## land): the red twin of COLOR_PLACEABLE, so "no" is visible before the button comes up.
const COLOR_BRAWL_DROP_BAD := Color(0.85, 0.28, 0.28, 0.22)
