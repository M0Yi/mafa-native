# 音频退出残留诊断

核查日期：2026-09-13。当前运行时：4.7.2-stable (official)。此项未标记修复。

## 本机证据

`game/tests2011/audio_engine_exit_probe.gd` 不实例化游戏场景，不加载客户端音频、不打开存档，仅创建 AudioStreamGenerator 播放器，play → stop → 清空 stream → SceneTree.quit。

运行命令：

```sh
.cache/godot/Godot.app/Contents/MacOS/Godot --headless --verbose --path game --log-file /tmp/mafa-engine-audio-exit.log --script res://tests2011/audio_engine_exit_probe.gd
```

日志：`artifacts/closeout-engine-audio-exit.log`。进程退出0，但报告一个 AudioStreamGeneratorPlayback 残留。这将至少一种退出残留隔离到独立引擎音频路径，而不是游戏窗口、SQLite或客户端WAV独有问题。不能据此把其他任意资源警告都归给引擎。

完整场景证据：`artifacts/closeout-window-close-audio.log` 中保存失败保护与成功备份/清空播放器断言通过，但退出仍留下 field2.wav、106.wav 的播放资源。仅清空应用引用不等于混音端引用已释放。

## 上游依据与限制

- [Godot #76745](https://github.com/godotengine/godot/issues/76745)：确认的间歇音频退出泄漏，查询时仍开放。
- [候选修复 #122742](https://github.com/godotengine/godot/pull/122742)：查询时仍开放。其说明指出 stop 标记待删除，移除依赖后续混音步骤，音频驱动先关闭会留下引用；拟在 AudioServer::finish 清理播放列表。此为上游候选分析，不等于本项目二进制已经包含修复。

本机独立复现与该解释相符，但没有构建候选引擎进行前后验证。不擅自升级固定运行时、替换三平台引擎或隐藏警告。

## 后续处理

1. 保留正式退出前 stop_audio 清理及存档保护。
2. 保留回归报告的 resource_shutdown_warning，不将退出0视作清洁释放。
3. 把运行中持续增长与进程结束时残留分开验证；本复现不能证明游戏运行时持续泄漏，也不能证明两小时稳定性已通过。
4. 后续引擎修复可用时，先用该独立脚本及窗口关闭回归验证，再决定兼容性验证范围。
5. 无新增本地证据时，不反复扩大UI释放改动来消除这一已隔离的引擎路径问题；继续其余操作页面收尾。

## 2026-09-14 复活回归复查

33 组汇总中的 `reentry_revival_test` 曾报告 4 个 ObjectDB 实例及 2 个资源退出残留。随后用同一脚本加 `--verbose` 复查，退出 0、功能断言通过，但未再次出现 ObjectDB/resource 残留，因此本次不能取得泄漏实例类型，也不能将该例归因为引擎音频或认定已修复。详细日志：`artifacts/reentry-revival-exit-diagnosis.log`。该直接命令另含默认 user 日志目录写入受限及预期只读数据库注入错误，不作为清洁启动证明。保留原组测失败警告；后续需要在复现时捕获实例类型，不根据一次无警告结果改动运行时或关闭缺口。

## 2026-09-14 范围技能结算回归的具体残留

对当前fireball_resolution_test执行一次headless --verbose，正常退出0、所有功能断言通过。artifacts/fireball-resolution-verbose.log第83—89行列出7个实例：5个AudioStreamPlaybackWAV、2个AudioStreamWAV；第91—92行标明field2.wav和1800-4.wav。没有列出Node、窗口、特效或SQLite实例残留。这次明确定位为音频资源退出路径，与此前独立引擎音频复现类型一致，但没有验证同一根因，也不能证明运行中持续泄漏。保留警告，不修改引擎、不屏蔽日志、不将此列为稳定性通过。下一步需要运行中采样或上游修复对照，而不是反复改动窗口销毁逻辑。
