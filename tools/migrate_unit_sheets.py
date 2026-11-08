#!/usr/bin/env python3
# [P29] One-shot migration for OPTIMIZATIONS C3 (the user's race design):
# split the two unit sheets into the layered layout UnitSheet reads.
#
#   data/units/units.csv    NEW: one row per unit + the new `race` column, holding
#                           every column BOTH rosters share
#                           (名称 英文名称 race HP 天赋 技能 特殊机制 svg tscn + twins)
#   data/units/plants.csv   rewritten: 英文名称 + the plant-only columns
#   data/units/zombies.csv  rewritten: 英文名称 + the zombie-only columns
#
# Run from the project root:   python3 tools/migrate_unit_sheets.py
#
# Safety: aborts WITHOUT writing unless every id is unique across the two old
# sheets and every id has a race; refuses to run on an already-migrated layout
# (the marker is the `race` column / a missing 名称 column in plants.csv). The
# old files are overwritten - commit the baseline first, git can bring it back.

import csv
import sys
from pathlib import Path

DATA = Path("data/units")
PLANTS_OLD = DATA / "plants.csv"
ZOMBIES_OLD = DATA / "zombies.csv"
UNITS_NEW = DATA / "units.csv"

UNITS_COLS = ["名称", "英文名称", "race", "HP", "天赋", "技能", "特殊机制",
              "svg", "tscn", "天赋英文", "技能英文", "特殊机制英文"]
PLANT_COLS = ["英文名称", "技能效果", "大招", "大招效果", "attack", "费用", "卡片冷却",
              "技能效果英文", "大招英文", "大招效果英文", "HP成长", "技能成长", "天赋加成"]
# [P30-A] The plant skill AP price is NOT a plants.csv column: it lives in the
# skill sheet data/units/skills.csv (SkillDB), keyed by 技能代码.
ZOMBIE_COLS = ["英文名称", "护甲", "移动", "attack", "啃脑伤害"]

# The sub-race assignments (race = "<root>/<family>"). Everything not listed
# stays at its race root: plants are "plants", zombies are "zombies/normal"
# (the user: 大部分都是一般名称的僵尸). Plant families follow the svg folders;
# zombie families are the user's size classes.
PLANT_FAMILIES = {
    "plants/pea": ["peashooter", "repeater", "split_pea", "gatling_pea",
                   "threepeater", "snow_pea"],
    "plants/mushroom": ["mushroom_sun", "puff_shroom", "fume_shroom", "gloom_shroom",
                        "scaredy_shroom", "hypno_shroom", "ice_shroom", "doom_shroom",
                        "magnet_shroom", "gold_magnet", "sea_shroom"],
    "plants/pult": ["cabbage_pult", "kernel_pult", "melon_pult", "winter_melon"],
    "plants/youkia": ["strawberry_mini", "pomegranate_doll", "blaze_pepper",
                      "pepper_king", "pepper_king_omega", "flame_king"],
}
ZOMBIE_FAMILIES = {
    "zombies/mini": ["zombie_imp", "zombie_backup_dancer", "zombie_bobsled",
                     "snow_goblin", "zombie_dog", "zombie_dolphin_ride"],
    "zombies/huge": ["zombie_gargantuar", "zombie_gargantuar_red", "zomboss",
                     "zombie_zamboni"],
}
DEFAULT_RACE = {"plants": "plants", "zombies": "zombies/normal"}


def read_sheet(path: Path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.reader(f, delimiter="\t"))
    if not rows:
        sys.exit(f"FAIL: {path} is empty")
    header = [h.strip() for h in rows[0]]
    out = []
    for r in rows[1:]:
        if not any(c.strip() for c in r):
            continue  # a blank line is not a row
        d = {}
        for i, h in enumerate(header):
            d[h] = r[i].strip() if i < len(r) else ""
        out.append(d)
    return header, out


def need(header, path, cols):
    missing = [c for c in cols if c not in header]
    if missing:
        sys.exit(f"FAIL: {path} lacks columns {missing} - unexpected layout, nothing written")


def get(row, col):
    v = row.get(col, "")
    return v if v != "" else "—"  # the sheets' own blank mark (UnitCsvManager.BLANKS)


def race_of(sheet_key, uid, by_id):
    fams = PLANT_FAMILIES if sheet_key == "plants" else ZOMBIE_FAMILIES
    for race, ids in fams.items():
        if uid in ids:
            by_id.setdefault(race, []).append(uid)
            return race
    return DEFAULT_RACE[sheet_key]


def write_sheet(path, cols, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(cols)
        for r in rows:
            w.writerow(r)
    print(f"wrote {path}  ({len(rows)} rows x {len(cols)} cols)")


def main():
    ph, plants = read_sheet(PLANTS_OLD)
    zh, zombies = read_sheet(ZOMBIES_OLD)
    if "race" in ph or "名称" not in ph:
        sys.exit("FAIL: plants.csv is already in the migrated shape - run this once, "
                 "on the git baseline, nothing written")
    need(ph, PLANTS_OLD, ["名称", "英文名称", "HP", "天赋", "技能", "特殊机制", "svg", "tscn",
                          "技能效果", "大招", "大招效果", "attack", "费用", "卡片冷却",
                          "技能英文", "特殊机制英文", "技能效果英文", "大招英文", "大招效果英文",
                          "HP成长", "技能成长", "天赋加成"])
    need(zh, ZOMBIES_OLD, ["名称", "英文名称", "HP", "天赋", "技能", "特殊机制", "svg", "tscn",
                           "护甲", "移动", "attack", "啃脑伤害",
                           "天赋英文", "技能英文", "特殊机制英文"])

    seen = {}
    for src, name in ((plants, "plants.csv"), (zombies, "zombies.csv")):
        for r in src:
            uid = r["英文名称"]
            if uid == "":
                sys.exit(f"FAIL: a {name} row has no 英文名称, nothing written")
            if uid in seen:
                sys.exit(f"FAIL: id '{uid}' appears in {seen[uid]} AND {name} - "
                         "a cross-sheet join would be ambiguous, nothing written")
            seen[uid] = name

    by_id = {}
    units_rows, plant_rows, zombie_rows = [], [], []
    for key, src in (("plants", plants), ("zombies", zombies)):
        for r in src:
            uid = r["英文名称"]
            race = race_of(key, uid, by_id)
            units_rows.append([get(r, c) if c != "race" else race for c in UNITS_COLS])
            if key == "plants":
                plant_rows.append([uid] + [get(r, c) for c in PLANT_COLS[1:]])
            else:
                zombie_rows.append([uid] + [get(r, c) for c in ZOMBIE_COLS[1:]])

    # every listed family member must be a real unit, or the map above has a typo
    for race, ids in {**PLANT_FAMILIES, **ZOMBIE_FAMILIES}.items():
        for uid in ids:
            if uid not in seen:
                sys.exit(f"FAIL: family {race} names '{uid}' which no sheet has, nothing written")

    write_sheet(UNITS_NEW, UNITS_COLS, units_rows)
    write_sheet(PLANTS_OLD, PLANT_COLS, plant_rows)
    write_sheet(ZOMBIES_OLD, ZOMBIE_COLS, zombie_rows)
    print(f"\nunits: {len(units_rows)} row(s) = {len(plants)} plants + {len(zombies)} zombies")
    for race in sorted(by_id):
        print(f"  {race}: {len(by_id[race])}")
    plain_p = len(plants) - sum(len(v) for v in PLANT_FAMILIES.values())
    plain_z = len(zombies) - sum(len(v) for v in ZOMBIE_FAMILIES.values())
    print(f"  plants (no family): {plain_p}")
    print(f"  zombies/normal: {plain_z}")
    print("\nNext: start the game and compare the [Plants]/[Zombies] self-check logs - "
          "every parsed value must be identical to the baseline.")


if __name__ == "__main__":
    main()
