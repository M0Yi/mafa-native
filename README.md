<div align="center">

# 玛法 · 火龙神殿

**回到玛法，按自己的节奏冒险。**

经典像素风 · 单机重建 · 键鼠与手柄 · 本地存档

[![三平台构建](https://github.com/M0Yi/mafa-native/actions/workflows/release.yml/badge.svg)](https://github.com/M0Yi/mafa-native/actions/workflows/release.yml)
![版本](https://img.shields.io/badge/版本-0.14.0_Preview-c69b51)
![平台](https://img.shields.io/badge/平台-macOS%20%7C%20Windows%20%7C%20Linux-435b63)

[**下载游戏**](https://github.com/M0Yi/mafa-native/releases/tag/v0.14.0-preview.2) · [**观看 45 秒宣传片**](https://github.com/M0Yi/mafa-native/releases/download/v0.14.0-preview.2/MafaNative-preview.mp4) · [**首次启动**](#三步开始冒险) · [**项目介绍**](release/宣传文章.md)

[![新手村实机动态预览，点击观看完整宣传片](release/homepage/preview.gif)](https://github.com/M0Yi/mafa-native/releases/download/v0.14.0-preview.2/MafaNative-preview.mp4)

*以上为实机演示画面。点击预览可打开完整 MP4；GitHub 或浏览器可能以下载方式打开。*

</div>

> **开始前请准备客户端素材。** 程序包不附带可供游戏加载的热血传奇原始或转换素材。基础适配 **2.0.1.11 十周年客户端**，十六周年客户端可选补充。首页图片和视频仅作功能演示，不是可用素材包。

## 这段旅程里有什么

从新手村出发，与 NPC 交谈，完成委托、学习技能、整理装备，继续探索城镇与野外。这里保留经典像素画面，也为本机游玩补上了更方便的操作方式。

| 玩法 | 当前可以体验 |
| --- | --- |
| 角色与成长 | 本机注册登录、角色创建、战法道技能书学习与装备成长 |
| 探索与任务 | 村庄委托、区域旅行、NPC 对话与服务、任务进度保存 |
| 战斗与拾取 | 怪物战斗、地面掉落、手动拾取及可选脚下自动拾取 |
| 装备与物品 | 背包、装备、商店与仓库等日常管理 |
| 手柄操作 | 独立面板，LB / RB 切换背包、装备、技能与任务 |
| 本地辅助 | 自动补给、拾取过滤、职业技能辅助；自动行为默认关闭 |

技能需要通过技能书学习。职业辅助支持法师补魔法盾、战士使用刺杀、道士自疗与护甲，并遵守等级、消耗和冷却。

## 实机画面

### 从新手村再次出发

![新手村中的角色、NPC 与任务标记](release/homepage/village.jpg)

### 手柄有自己的操作面板

![手柄分类面板，肩键切换背包、装备、技能和任务](release/homepage/controller.jpg)

### 把重复操作交给可配置的辅助

![全屏分类内挂与职业技能辅助设置](release/homepage/assist.jpg)

[观看完整宣传片 →](https://github.com/M0Yi/mafa-native/releases/download/v0.14.0-preview.2/MafaNative-preview.mp4) · [阅读项目介绍 →](release/宣传文章.md)

## 下载游戏

当前版本：**0.14.0-preview.2**。每个包包含程序及独立素材导入器，玩家无需安装 Python 或搭建服务端。

| 平台 | 下载 | 验证情况 |
| --- | --- | --- |
| macOS · Apple Silicon | [下载 ARM64 ZIP](https://github.com/M0Yi/mafa-native/releases/download/v0.14.0-preview.2/MafaNative-0.14.0-preview.2-macOS-arm64.zip) | 本机外部素材导入与运行检查、CI 构建通过 |
| Windows · x86_64 | [下载 Windows ZIP](https://github.com/M0Yi/mafa-native/releases/download/v0.14.0-preview.2/MafaNative-0.14.0-preview.2-Windows-x86_64.zip) | CI 构建与基础启动通过，完整游玩待实测 |
| Linux · x86_64 | [下载 Linux ZIP](https://github.com/M0Yi/mafa-native/releases/download/v0.14.0-preview.2/MafaNative-0.14.0-preview.2-Linux-x86_64.zip) | Ubuntu 24.04 构建与基础启动通过 |

Linux 建议 Ubuntu 24.04 或兼容的 glibc 环境。macOS 包未公证，Windows 包未使用商业代码签名。下载页附每份程序包的 SHA-256 与素材审计报告。

[全部发布文件与更新说明](https://github.com/M0Yi/mafa-native/releases/tag/v0.14.0-preview.2) · [详细验证记录](release/VALIDATION.md)

## 三步开始冒险

1. **解压并启动。** macOS 打开 `MafaNative.app`；Windows 打开 `MafaNative.exe`；Linux 运行 `MafaNative.x86_64`。
2. **选择本机客户端。** 指定包含 `Data`、`Map`、`Wav` 的十周年客户端目录；有十六周年目录时可同时选择作为补充。等待首次转换完成。
3. **创建角色，进入游戏。** 素材缓存生成后会复用，账号和进度保存在本机，正常游戏无需联网。

导入只读取原始文件，不执行客户端 EXE，不修改原目录。转换可能需要数分钟和数 GB 空间。十六周年客户端不能单独代替基础素材；本仓库不提供客户端下载。

[完整启动说明与存档位置](release/README.zh-CN.md)

## 常用操作

| 键鼠 | 功能 | 手柄面板 | 功能 |
| --- | --- | --- | --- |
| WASD / Shift | 移动 / 跑步 | LB / RB | 分类切页 |
| 左键 / E | 寻路、交互 / 近处交互 | 方向键 | 选择条目、调节数值 |
| 空格 | 基础攻击 | A / B | 确认 / 返回 |
| B / P | 背包 / 暂停 | X | 打开内挂设置 |

技能学会后可配置快捷键。键鼠面板与手柄面板各自保留对应操作。

## 当前版本的边界

这是社区制作的**单机重建预发布**，不是原游戏官方客户端，也不是私服服务端。当前以已有玩法收尾，不宣称历史内容已完整还原。

- 707 张地图已登记接入，不等于每张地图的历史内容均已复原；部分场景使用登记的替代素材。
- 当前不支持局域网或互联网联机。
- Windows/Linux CI 检查不能替代完整硬件游玩；实体手柄、全地图视觉和长时间性能仍需要实测。
- 宣传片使用独立演示角色录制，配乐为独立合成，不代表原作音乐还原验收。

遇到问题可[提交反馈](https://github.com/M0Yi/mafa-native/issues)，附上系统、程序版本、复现步骤和错误提示即可。请勿上传原始客户端、转换缓存、账号存档或登录凭据。

<details>
<summary><strong>开发运行与发布流程</strong></summary>

安装 Godot **4.7.2 标准版**，使用 Compatibility 渲染器。三平台可通过 `python tools/run_dev.py` 启动源码，环境变量 `GODOT` 指定引擎路径；也可打开 `game/project.godot`。日常开发不需要导出安装包。

开发导入器使用 Python 3.13+：

```sh
python -m pip install -r release/requirements.txt
python tools/import_client.py --source "/path/to/client" --output "/path/to/local-cache"
# 可选 --supplement "/path/to/client16"
```

转换完成后，在启动页选择包含 `client2011` 的 `generation-*` 文件夹。`MAFA_PYTHON` 可指向安装好依赖的 Python。

`.github/workflows/release.yml` 构建三平台独立导入器并导出程序。发布时使用 `tools/release/build.py --release --platform <macOS|Windows|Linux> --importer <path>`。

构建先建立不含素材的工程副本，再审计输出 PCK 和外部文件。`python -m unittest discover -s tests/release -v` 执行导入与平台配置检查。公开同步采用 `tools/release/source_files.py` 白名单；宣传截图与视频不参与游戏运行和程序包导出。

</details>

---

[项目介绍](release/宣传文章.md) · [素材与第三方说明](release/THIRD_PARTY_NOTICES.md) · [验证记录](release/VALIDATION.md) · [宣传材料说明](release/MEDIA.md)
