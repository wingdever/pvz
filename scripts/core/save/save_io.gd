## scripts/core/save_io.gd
##
## [P109] 无状态存档 IO。只管"字节和格式"，不知道花园、档案、进度是什么。
##
## 和 SafeIO 的分工：
##   SafeIO  = 原子换入（.tmp + rename）、坏档归档（.bak）、文件在不在
##   SaveIO  = 格式判断（JSON 还是 ConfigFile，空文件算不算坏）、解析
##
## 读不写盘。"要不要补一份默认档"是调用方的事——那是领域知识，不是 IO。

class_name SaveIO
extends RefCounted

## [P109] SafeIO is a BY-PATH module (no class_name), so this file must declare the
## constant it uses - `[Arch] every script that uses a preload constant declares it
## itself` caught the port leaving the call without the const.
const SafeIO := preload("res://scripts/core/save/safe_io.gd")


## 读 JSON。返回 {data, status}：
##   status == "ok"       文件在，解析成功；data 是 Dictionary
##   status == "missing"  文件不在（首次启动）；data 是空 Dictionary
##   status == "broken"   文件在但坏（已归档到 .bak）；data 是空 Dictionary
##
## 坏档先由 SafeIO.keep_broken() 归档（只保留第一份），再返回 broken——
## 否则"读不出来"会在几秒内变成"进度没了"（§8.3 第 2 条）。
static func read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"data": {}, "status": "missing"}
    var text := FileAccess.get_file_as_string(path)
    if text == "":
        SafeIO.keep_broken(path)
        return {"data": {}, "status": "broken"}
    var parsed = JSON.parse_string(text)
    if parsed == null or not parsed is Dictionary:
        SafeIO.keep_broken(path)
        return {"data": {}, "status": "broken"}
    return {"data": parsed, "status": "ok"}


## 读 ConfigFile。返回 {data, status}，语义同 read_json，只是 data 是 ConfigFile。
static func read_cfg(path: String) -> Dictionary:
    var cfg := ConfigFile.new()
    if not FileAccess.file_exists(path):
        return {"data": cfg, "status": "missing"}
    var err := cfg.load(path)
    if err != OK:
        SafeIO.keep_broken(path)
        return {"data": ConfigFile.new(), "status": "broken"}
    return {"data": cfg, "status": "ok"}


## 写 JSON 文本。false = 磁盘上还是写之前那份（原子换入，§8.1 第一条纪律）。
static func write_json(path: String, text: String) -> bool:
    return SafeIO.write_text_atomic(path, text)


## 写 ConfigFile。false = 磁盘上还是写之前那份。
static func write_cfg(path: String, cfg: ConfigFile) -> bool:
    return SafeIO.write_config_atomic(path, cfg)