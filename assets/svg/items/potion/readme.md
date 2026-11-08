按你现有的药剂瓶形状（软木塞 + 瓶颈 + 瓶身 + 液体），通用药剂去掉顶部的植物标记，仅靠**液体颜色**区分rarity。

## 一、命名建议

### 英文显示名（推荐）

| rarity | 中文 | 英文显示名 | 代码 / 文件名 |
|---|---|---|---|
| 初级 | 灰色 | `Common Talent Potion` | `potion_talent_common` |
| 中级 | 绿色 | `Uncommon Talent Potion` | `potion_talent_uncommon` |
| 高级 | 蓝色 | `Rare Talent Potion` | `potion_talent_rare` |
| 史诗 | 紫色 | `Epic Talent Potion` | `potion_talent_epic` |
| 传说 | 金色 | `Legendary Talent Potion` | `potion_talent_legendary` |
| 神话 | 红色 | `Mythic Talent Potion` | `potion_talent_mythic` |

> 如果想和已有 `Hard Pea I` / `Big Sun I` 的阶数命名统一，也可以改叫 `Talent Potion I` ~ `Talent Potion VI`，但rarity味会淡一些。

### 液体颜色对应

| rarity | 颜色 | Hex |
|---|---|---|
| 初级 | 灰 | `#B0B8C0` |
| 中级 | 绿 | `#40BF4D` |
| 高级 | 蓝 | `#4AB8D8` |
| 史诗 | 紫 | `#8A7FB8` |
| 传说 | 金 | `#F4C430` |
| 神话 | 红 | `#E53935` |

---

## 二、六种通用药剂 SVG

所有通用药剂共用同一个瓶型，只有液体颜色不同。顶部**不画植物标记**，留作“专属药剂”的贴图区。

## 三、专属药剂 = 通用药剂 + 植物标记

按你的规则，专属天赋药剂就是“在通用药剂的顶部空白区叠加对应植物的贴图”。可用以下方式合成，不必为每种植物单独画一瓶：

```gdscript
func build_talent_potion(rarity: String, plant_id: String) -> Node2D:
    var root := Node2D.new()

    # 1. 通用药剂底图（按rarity选液体颜色）
    var potion := Sprite2D.new()
    potion.texture = load("res://assets/placeholder/svg/items/potion_talent_%s.svg" % rarity)
    root.add_child(potion)

    # 2. 植物标记叠加到顶部空白区
    var mark := Sprite2D.new()
    mark.texture = load("res://assets/placeholder/svg/units/%s.svg" % plant_id)
    mark.position = Vector2(0, -34)      # 对应 SVG 中 x64 y10..38 的标记区
    mark.scale = Vector2(0.3, 0.3)       # 缩到标记区大小
    root.add_child(mark)

    return root
```

**标记区约定**：通用药剂顶部 `x 44..84, y 10..38` 是空白，专门留给植物标记。只要植物素材内容落在自己的中心 ±30 内，按 `scale = 0.3` 叠加就能落在标记区内。

现有 `potion_peashooter.svg` 就是把 `peashooter` 的标记画成了菱形叶；如果你决定改用这套叠加方案，可以把它替换为「通用底图 + `peashooter.svg` 标记」的组合，减少重复素材。

---

## 四、文档同步

### `PvZ Turn-Based.txt`

```text
| `potion_talent_common.svg`    | 通用天赋药剂（初级/灰），无植物标记 |
| `potion_talent_uncommon.svg`  | 通用天赋药剂（中级/绿），无植物标记 |
| `potion_talent_rare.svg`      | 通用天赋药剂（高级/蓝），无植物标记 |
| `potion_talent_epic.svg`      | 通用天赋药剂（史诗/紫），无植物标记 |
| `potion_talent_legendary.svg` | 通用天赋药剂（传说/金），无植物标记 |
| `potion_talent_mythic.svg`    | 通用天赋药剂（神话/红），无植物标记 |
```

并补一句：

```text
- 专属天赋药剂 = 通用药剂底图 + 植物贴图叠加到顶部标记区（x 44..84, y 10..38）。
  新增植物名称时无需新画瓶子，只需在代码里叠加对应 plant_id 的单位贴图。
```

### `readme.md`

```text
| `potion_talent_common.svg`    | 通用天赋药剂（初级/灰） | 道具 | `#DBE6F2` / `#6B4A2E` / `#B0B8C0` | 无植物标记 |
| `potion_talent_uncommon.svg`  | 通用天赋药剂（中级/绿） | 道具 | `#DBE6F2` / `#6B4A2E` / `#40BF4D` | 无植物标记 |
| `potion_talent_rare.svg`      | 通用天赋药剂（高级/蓝） | 道具 | `#DBE6F2` / `#6B4A2E` / `#4AB8D8` | 无植物标记 |
| `potion_talent_epic.svg`      | 通用天赋药剂（史诗/紫） | 道具 | `#DBE6F2` / `#6B4A2E` / `#8A7FB8` | 无植物标记 |
| `potion_talent_legendary.svg` | 通用天赋药剂（传说/金） | 道具 | `#DBE6F2` / `#6B4A2E` / `#F4C430` | 无植物标记 |
| `potion_talent_mythic.svg`    | 通用天赋药剂（神话/红） | 道具 | `#DBE6F2` / `#6B4A2E` / `#E53935` | 无植物标记 |
```

### `balance.gd`

```gdscript
const ART_POTION_COMMON    := "res://assets/placeholder/svg/items/potion_talent_common.svg"
const ART_POTION_UNCOMMON  := "res://assets/placeholder/svg/items/potion_talent_uncommon.svg"
const ART_POTION_RARE      := "res://assets/placeholder/svg/items/potion_talent_rare.svg"
const ART_POTION_EPIC      := "res://assets/placeholder/svg/items/potion_talent_epic.svg"
const ART_POTION_LEGENDARY := "res://assets/placeholder/svg/items/potion_talent_legendary.svg"
const ART_POTION_MYTHIC    := "res://assets/placeholder/svg/items/potion_talent_mythic.svg"

# rarity → 底图路径
const POTION_TIER_PATHS := {
    "common":    ART_POTION_COMMON,
    "uncommon":  ART_POTION_UNCOMMON,
    "rare":      ART_POTION_RARE,
    "epic":      ART_POTION_EPIC,
    "legendary": ART_POTION_LEGENDARY,
    "mythic":    ART_POTION_MYTHIC,
}
```

---

## 五、可选优化

- **瓶塞颜色**：目前 6 种都是同一个棕色 `#6B4A2E`。如果想再强化rarity，可以把瓶塞也染成对应颜色，但会破坏“通用瓶型统一”的简洁感，建议不改。
- **液体形状**：目前 6 瓶完全一致，只有颜色差异。如果需要，可以给高rarity加一点“液面上升”或“气泡”细节，但会牺牲扁平风，建议保持。
- **阶数标记**：如果以后要区分 I / II / III 阶，可以在瓶身正面加一个小号罗马数字，位置约 `x 60..68, y 88..98`。
