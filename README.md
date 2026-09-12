# 玛法 · 火龙神殿

经典像素风单机重建，提供 macOS Apple Silicon、Windows x86_64 和 Linux x86_64 预发布构建。源码与发布包 **不包含热血传奇的图片、地图、音乐、音效或其转换结果**。

首次启动选择自行准备的 **2.0.1.11 十周年客户端目录**；十六周年客户端可选作补充。程序只读原始文件，在本机生成独立缓存，不执行原客户端 EXE。转换完成后可离线游戏。

[下载预发布](https://github.com/M0Yi/mafa-native/releases) · [启动与操作说明](release/README.zh-CN.md) · [项目介绍](release/宣传文章.md) · [第三方说明](release/THIRD_PARTY_NOTICES.md)

## 已有玩法

本机账号与角色、战法道技能书学习、任务与 NPC 服务、装备背包、区域探索、怪物战斗与掉落拾取，以及可配置的本地技能辅助。手柄使用独立操作面板，LB/RB 切页，键鼠操作继续保留。进度使用本地 SQLite 保存。

范围以当前已实现玩法收尾。707 张地图已登记接入，但不等同于全部历史地图内容完整还原；部分场景使用登记的替代素材。当前不支持局域网或互联网联机，也不是官方客户端或私服服务端。

## 开发运行

安装 Godot **4.7.2 标准版**，Compatibility 渲染器。打开 `game/project.godot` 或 `godot --path game`。源码不附素材，首次通过资源设置导入。

开发导入器使用 Python 3.13+：

```sh
python -m pip install -r release/requirements.txt
python tools/import_client.py --source "/path/to/client" --output "/path/to/local-cache"
# 可选 --supplement "/path/to/client16"
```

缓存完成后，选择其中的 `generation-*` 文件夹；内部应包含 `client2011`。可以设置 `MAFA_PYTHON` 指向安装好依赖的 Python，以便开发启动页直接导入。日常修改不需要导出安装包。

## 发布与验证

`.github/workflows/release.yml` 构建三平台独立导入器并导出程序。`tools/release/build.py --release --platform <macOS|Windows|Linux> --importer <path>` 仅在显式发布时使用；`GODOT` 指定引擎路径。

构建先建立不含素材的工程副本，再审计输出 PCK 和外部文件。发布文件附 SHA-256 与审计报告。`python -m unittest discover -s tests/release -v` 执行导入和平台配置检查。公开同步采用 `tools/release/source_files.py` 白名单，不上传用户数据和历史参考仓库。

Windows/Linux CI 构建与启动检查不能代替完整实际硬件游玩；实体手柄、各区域视觉与长时间性能仍需要实际机器验证。详情以版本发布记录为准。
