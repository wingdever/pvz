class_name BalanceWar
extends RefCounted
## [W2] The WAR's half of Balance - the numbers that ONLY the war mode reads.
##
## WHO READS THIS FILE: scripts/core/war/**, scripts/ui/war/** and scenes/war.tscn. The rule
## that gave BalanceBrawl its file ([B1]) is the rule here too - a mode's own constants live
## with that mode, balance.gd does not read this file, and this file reads NO other table
## (a table reading a table is the one direction P108 forbids).
##
## THE ONE SHARED CURRENCY: the sides. A war body is a BrawlActor and the engine keys its
## facing, targeting and half-rects off BalanceBrawl.SIDE_LEFT / SIDE_RIGHT, so war reuses
## those two ints rather than declaring WAR_SIDE_* twins - two names for one fact is exactly
## what the [Arch] dup-owner check exists to catch. What is war's OWN here is the WORLD the
## actors live in: its cell, its camera, its deployment cap.

# ---------------------------------------------------------------- the world [W2]
## THE FIXED WORLD CELL, in pixels. The brawl recomputes its cell from the window every
## resize (BrawlLayout); war deliberately does NOT - the board is a fixed world of
## rows x cols x WORLD_CELL pixels and "how much of it you see" is the camera's zoom and
## nothing else. Three things fall out of this choice:
##   - art_scale stays 1.0 for every body (the sheet's picture is drawn at its own size);
##   - a shot table written in px/second keeps ONE absolute meaning on every map;
##   - a window resize changes zero pixels of the battlefield itself.
## 96.0 = Balance.CELL_SIZE, the art baseline, so the same SVG the classic board draws at
## one cell lands here at exactly the same size.
const WORLD_CELL := 96.0
## The map the sheets fall back to when nothing is picked (data/war/maps.csv row 1).
const WAR_DEFAULT_MAP := "default"
## How many pieces one side may field at the deployment table (the cap the page enforces
## and the "%d / %d" line prints). 12 on a 10 x 30 board keeps the opening skirmish
## readable; the enemy's side of the ledger is its waves, not this number.
const WAR_DEPLOY_LIMIT := 12
## The curtain: how long the arena stays on screen after the outcome, before the result
## page takes the window. Longer than the brawl's 0.9 (BOUT_CURTAIN_SECONDS) because a war
## arena is bigger and the last fall should be findable on it; 2.0 is a first pass and a
## W6 tuning candidate.
const WAR_CURTAIN_SECONDS := 2.0

# ---------------------------------------------------------------- the HUD [W5]
## The receipt the arena puts over the field after the curtain: one dim wash, the verdict
## word, its one line of facts, and the way out. The TOP BAND of the same HUD is not here -
## it is drawn through BrawlHUD.draw_top_bar on the brawl's own band rectangle (D66's one
## drawer), and only these four numbers belong to the war's receipt.
const WAR_HUD_DIM_ALPHA := 0.45
const WAR_HUD_RESULT_FONT_SIZE := 44
const WAR_HUD_RESULT_LINE_FONT_SIZE := 20
const WAR_HUD_RESULT_HINT_FONT_SIZE := 15
## Where the three receipt lines sit, as SHARES of the window height (baselines): the word
## above the middle so it reads first, its facts just under, the ESC line low where nothing
## of the field's centre is.
const WAR_HUD_RESULT_Y := 0.42
const WAR_HUD_RESULT_LINE_Y := 0.50
const WAR_HUD_RESULT_HINT_Y := 0.86

# ---------------------------------------------------------------- the deployment page [W4/W6]
## The page's three strips in px of WINDOW height (the header strip is not here - it IS
## `CAMERA_HUD_RESERVED_PX`, the same number the arena HUD reserves, by plan). [W6] moved
## these out of war_formation.gd: they are the mode's own feel numbers, and the one place a
## resize of the shelf or the hint line is decided must be this table (AGENTS §2).
## The shelf tile: [W7] the band is a grid of SQUARE tiles now (see WAR_PAGE_SHELF_PER_ROW),
## and inside one the picture owns everything but the unit's name line at its foot.
const WAR_PAGE_SHELF_NAME_LINE_PX := 22.0
## The page's one feedback line (the refusal sentences live here).
const WAR_PAGE_HINT_LINE_PX := 26.0
## The shelf tile clamp: never below MIN (a name line needs readable text), never above
## SHARE x the world cell (seventeen tiles must still cross the narrowest window together).
const WAR_PAGE_TILE_MIN_PX := 48.0
const WAR_PAGE_TILE_MAX_SHARE := 0.9
## [W7] The shelf became a GRID: at most PER_ROW tiles in a row, and the band grows a row
## whenever the pool outgrows one (seventeen units read as 9 + 8). The clamp above still
## rules a tile's side - rows are what made the icons bigger, not wider tiles.
const WAR_PAGE_SHELF_PER_ROW := 9
## The 出征 button - a fixed box at the hint strip's right end - and [W7]'s 清空 next to it.
const WAR_PAGE_BUTTON_W_PX := 200.0
const WAR_PAGE_CLEAR_W_PX := 140.0
## [W7] THE PAGE'S OWN LADDER. The arena's floor is a share of the VIEWPORT's fit; the page
## measures its floor against its own view box, and 1.0 means "you cannot zoom out past all
## of the board" (beyond it is wall, and a placement page has no reason to show wall). The
## top is deeper than the arena's 2.0 on purpose: the arena frames a fight, the page inspects
## a cell before committing a body to it.
const WAR_PAGE_ZOOM_MIN_SHARE := 1.0
const WAR_PAGE_ZOOM_MAX := 3.0
## Motion a press must accumulate before it stops being a click and starts being a grab -
## [W7b] amended: the grab is ctrl+left ALONE (the right button's tap now just frees the
## hand at its press), and this is the line between a ctrl press that means nothing and a
## ctrl press that means "I am sliding the map". One wheel notch multiplies (or divides)
## with CAMERA_ZOOM_STEP, the arena's own ladder: the same click of the wheel should feel
## the same on both grounds.
const WAR_PAGE_DRAG_SLOP_PX := 6.0
## [W7] The range-preview ring: its stroke in px and the arc's segment count (the page draws
## one circle per hovered cell, so the segments are a picture knob, not simulation).
const WAR_PAGE_RANGE_RING_PX := 3.0
const WAR_PAGE_RANGE_RING_SEGMENTS := 96
## [W10] The page's two ZONE SEAMS in px of window width: thicker than the grid
## (BalanceUI.BRAWL_GRID_WIDTH) because they separate zones, not cells - one closing the
## player's deployment band on its right, its mirror closing the enemy band on its left.
const WAR_PAGE_ZONE_LINE_PX := 4.0

# ---------------------------------------------------------------- the mode's stat shape [W7b]
## [W7b] THE WAR GROUND BENDS TWO NUMBERS, by the user's ruling: what is RANGED (fires a
## projectile - BrawlActor.is_ranged asks shot_id(), the same door the strike takes) strikes
## at twice the sheet's reach, and what is MELEE walks at twice its speed. The multipliers
## live BEHIND two instance doors on BrawlField that answer 1.0 there - a bout is untouched
## to the bit - and WarField overrides them to these two. Classification is by PROJECTILE,
## not by reach length: the 刀剑客 states 1.1 cells and swings, and doubling its reach would
## be doubling the wrong answer.
const WAR_RANGED_REACH_MULT := 2.0
const WAR_MELEE_SPEED_MULT := 2.0

# ---------------------------------------------------------------- the rounds [W8]
## [W8] THE WAR IS ROUNDS, not a timed wave line (the user's ruling): each round the enemy
## fields ONE rolled bout, the field is cleared when that bout falls, and the player returns
## to the deployment table for the next one. The round COUNT and the per-round unit COUNT
## stay data-driven - they are the wave labels and their authored row counts in
## data/war/waves.csv (WarDB.wave_starts) - and the delay column stops landing bodies.
## [W10] THE SPAWN BAND retired its own number (the user's symmetry ruling): the roller drops
## bodies into the map's right-most `deploy_cols` columns (data/war/maps.csv, read through
## WarDB.deploy_cols_of), the exact mirror of the player's deployment zone - one sheet column
## now owns both wings and the two zones are one shape BY CONSTRUCTION. The old
## WAR_ENEMY_SPAWN_COLS := 3 earned its 30 cells by being wide-cheap; the mirrored 8x10 = 80
## outgrows any authored round's count by far more, and the page's two seam lines
## (WAR_PAGE_ZONE_LINE_PX below) draw at the same mirrored x the roller rolls into.

# ---------------------------------------------------------------- the camera [W3]
## THE FIT: the zoom that makes the WHOLE fixed world fit the window. It is computed, never
## stored (the window moves, the world does not); these are its three knobs.
## How much of the window the world is allowed to fill when fitted (1.0 = edge to edge;
## 0.96 leaves a visible margin so the board edge reads as an edge).
const CAMERA_FIT_PAD := 0.96
## The vertical px the self-drawn HUD eats at the top, subtracted from the window BEFORE
## fitting so "the whole battlefield" means "the whole battlefield you can actually see".
const CAMERA_HUD_RESERVED_PX := 56.0
## The zoom ladder. The top is "one cell drawn at twice its art size" - close enough to
## read a body's sheet picture, not so close that a 30-col board becomes a scroll hunt.
const CAMERA_MAX_ZOOM := 2.0
## The bottom is a SHARE of the fit zoom (zooming out past "all of it on screen" shows
## wall, so the floor moves with the window by design).
const CAMERA_MIN_ZOOM_SHARE := 0.9
## One wheel notch / one +/- keypress multiplies (or divides) the zoom by this.
const CAMERA_ZOOM_STEP := 1.25
## Free pan speed, in px of WORLD space per second at zoom 1.0. The camera divides by its
## own zoom, so holding a key moves the same on-screen distance at every zoom while the
## world itself always passes at this absolute rate (~13 cells a second: fast enough to
## cross a 30-col board in about two seconds, slow enough to follow a line while it pushes).
const CAMERA_PAN_PX_PER_SECOND := 1280.0
