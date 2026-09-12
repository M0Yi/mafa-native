# 0.14.0-preview.2 验证记录

- GitHub Actions 三个平台全部通过：macos-14 / Apple Silicon、windows-latest / x86_64、ubuntu-24.04 / x86_64。
- 每个平台运行导入器启动检查、5 项 Python 配置/错误输入测试、实际原生程序的无素材设置页启动，以及 PCK 内部审计。
- 三个平台的 PCK 均扫描 213 个文件，禁用素材引用检查为空；源代码同步采用显式白名单。外部打包文件同样检查原始库、音频、地图、缓存和登录文件扩展名。
- 三份下载包的 SHA-256 与随包 JSON 报告一致。
- 本机 macOS：十周年原始客户端完整转换成功。冻结的独立导入器再次完成十周年＋十六周年补充的完整转换；后者补充 75 帧图像和 1 个声音文件。
- macOS 原生程序读取外部缓存进入新手村，短时运行资源错误为空。此检查为 headless 资源/逻辑验证，不是 FPS 验收。
- Windows/Linux 未导入用户客户端进行完整游玩，不把 CI 通过描述为全硬件兼容。Linux 导入器在 Ubuntu 24.04 构建，建议 Ubuntu 24.04 或兼容 glibc 环境；较旧发行版可运行 Python 源码导入器后选择已有缓存。macOS 未公证，Windows 未使用商业代码签名。
- 45 秒宣传视频已完成本地制作与分镜检查，1280×800 / 30 FPS / H.264 + AAC；配乐独立合成。含客户端实机图像，经用户明确授权公开上传至该版本 Release。

构建记录：https://github.com/M0Yi/mafa-native/actions/runs/34665120489

导出机制参考 Godot 官方文档：https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html
