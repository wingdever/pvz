## scripts/core/save_ledger.gd
##
## [P109] 存档账本的协调器。是"游戏写盘"这件事的独立对象形态——
## 状态（三份账本引用 + 未落盘记录）和写入策略在一起，离开 GameManager 的切片。
##
## 职责边界（刻意划死的三条）：
##   1. 它持有 garden / profile / run 的引用——因为门要调它们的 save_to_disk()
##   2. 它持有 _unsaved——因为"谁没落盘"是它记账记出来的事实
##   3. 它不碰 UI、不碰 battle、不碰页面流——那些改成信号，由 Game 接
##
## 三层里的位置：
##   SaveIO（无状态 static，只读字节）
##     → SaveLedger（本文件，管账本 + 告警）
##       → Game（autoload，接信号、贴 UI）

class_name SaveLedger
extends RefCounted


## 某个账本第一次被拒绝写盘。调用方通常在这里清掉 UI 上的基准消息行——
## [P65] 空基准行 + 追加的告警 = 完整的提示（原文：the appended note IS the message）。
signal write_refused(ledger: String)

## 某个账本从"未落盘"变成"已落盘"。调用方通常在这里刷新或清掉告警提示。
signal ledger_landed(ledger: String)


## 三份账本的引用。谁创建、谁 load、谁负责生命周期，是调用方（Game）的事——
## 本对象只是持有并使用它们。
var garden: Garden = null
var profile: Profile = null
var run: RunState = null


## 哪些账本有未落盘的改动。键 = 账本名（"garden" / "profile" / "run"）。
## 对外只读——通过 is_dirty() / dirty_ledgers() 查询，通过三道门写入。
var _unsaved: Dictionary = {}


# ---------------------------------------------------------------- 三道门

func save_garden() -> void:
    if garden == null:
        return
    _record_write(garden.save_to_disk(), "garden")


func save_profile() -> void:
    if profile == null:
        return
    _record_write(profile.save_to_disk(), "profile")


func save_run() -> void:
    if run == null:
        return
    _record_write(run.save_to_disk(), "run")


# ---------------------------------------------------------------- 查询

func is_dirty() -> bool:
    return not _unsaved.is_empty()


func dirty_ledgers() -> Array:
    return _unsaved.keys()


# ---------------------------------------------------------------- 内部：漏斗

func _record_write(wrote: bool, ledger: String) -> void:
    ## [P65] 一笔账本写盘的结果落到这里。
    ## 成功 → 清掉该账本的告警（清了才发信号，避免空转）。
    ## 失败 → push_warning 一次；如果该账本已经在 _unsaved 里就到此为止，
    ##        否则记入 _unsaved 并发 write_refused。
    ##
    ## 为什么没有"失败音效"：P55 的账算过——"no" 声代表"你点了但没发生"。
    ## 这里是反的：点发生了，磁盘坏了，把拒绝音效对准玩家是在怪他。
    if wrote:
        if _unsaved.erase(ledger):
            ledger_landed.emit(ledger)
        return
    push_warning("[Save] %s: the write was refused - that change is in RAM only" % ledger)
    if _unsaved.has(ledger):
        return                     # 这一账本的告警线已经在屏幕上或骑着了
    _unsaved[ledger] = true
    write_refused.emit(ledger)