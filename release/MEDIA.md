# 宣传素材

- 公开成片：[MafaNative-preview.mp4](https://github.com/M0Yi/mafa-native/releases/download/v0.14.0-preview.2/MafaNative-preview.mp4)，45 秒，1280×800，H.264 + AAC。含客户端实机画面，已获用户明确授权公开上传。首页 GIF 和 JPG 从该成片提取，仅用于演示，不参与游戏素材加载或程序导出。
- 文章：[宣传文章.md](宣传文章.md)。
- 游戏画面采用独立演示角色、固定 30 FPS 时间步逐帧录制，展示村庄移动、手柄分类面板、本地辅助与盟重区域。字幕说明预发布、自备素材及单机重建。
- 配乐由 tools/release/score.py 合成，是宣传片独立配乐，不是原作音乐或游戏内声音验收。
- 录制脚本 game/tests2011/promo_capture.gd；需要先按说明载入本机客户端。录制输出为 .cache/promo-frames，视频用 FFmpeg 编码。常规使用无需安装 FFmpeg。
- 原始客户端、缓存、截图序列、音频和演示存档不随代码及程序包发布。
