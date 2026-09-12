# 玛法 · 火龙神殿 — 0.14.0 预发布

这是社区单机重建项目，不是官方客户端或历史服务器的完整复刻。本包只提供程序、规则和可再分发依赖，不包含热血传奇的原始或转换后的图片、地图与音频。

## 首次运行

1. 完整解压发布包。macOS 打开 MafaNative.app；Windows 打开 MafaNative.exe；Linux 运行 MafaNative.x86_64（必要时 `chmod +x MafaNative.x86_64 mafa-importer`）。
2. 选择自己准备的 **2.0.1.11 十周年客户端目录**，包含 Data、Map、Wav。十六周年目录可选作缺图与音效补充，不能单独作基础客户端。
3. 等待本机转换，可能需要数分钟和数 GB 缓存空间。程序不会启动原客户端 EXE，也不会修改客户端文件。
4. 完成后注册本机账号、创建角色进入游戏。后续启动复用缓存，正常游戏无需联网。

发布版包含独立导入器，无需自行安装 Python。没有客户端时会停留在资源设置页，不会伪装成可进入完整地图。`--asset-setup` 可重新选择资源。也可载入已经转换好的资源根目录，目录中应有 client2011，补充素材放同级 supplement16。

## 操作

WASD 移动、Shift 跑步、左键寻路/交互、空格攻击、E 交互、B 背包、P 暂停。技能需使用技能书学习，可绑定快捷键。手柄面板用 LB/RB 切背包、装备、技能和任务；X 打开内挂，方向键选择和调节，A 确认，B 返回。自动辅助默认关闭。

## 本机数据

数据目录由 Godot 的 `user://` 管理，目录名 MafaNative2011：macOS 位于 `~/Library/Application Support/`，Windows 位于 `%APPDATA%/`，Linux 位于 `$XDG_DATA_HOME/` 或 `~/.local/share/`。原有账号与存档目录不变。resources.cfg 保存资源根路径，resource-cache 保存本机生成的素材，worlds.sqlite 保存游戏状态。

## 兼容性与边界

发布目标：macOS Apple Silicon、Windows x86_64、Linux x86_64。Compatibility 渲染器；提供 Noto 中文字体。macOS 为临时签名、未公证；Windows 未代码签名。Windows/Linux 原生构建与基础启动在 CI 验证，无法代替实际显卡、音频和实体手柄游玩测试。

当前范围以已实现玩法收尾；不宣称全部历史内容或所有素材完整还原。部分缺图使用明确登记的替代素材。局域网联网尚未实现。请勿把原始客户端、转换缓存、账号存档或登录凭据上传到仓库。
