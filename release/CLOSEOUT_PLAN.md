# 项目收尾目标与任务清单

建立日期：2026-09-13。基线：0.14.0-preview.2 及当前 main 源码。

## 目标

以现有《玛法·火龙神殿》单机内容完成一轮可追溯的收尾：玩家能从准备本机素材开始，完成创建角色、任务、战斗、物品管理、旅行、死亡恢复和退出续玩；代码、程序包、操作说明和宣传内容一致。

范围冻结：不新增地图、任务链、职业体系、联机、CG 或商城机制。保留现有入口和存档，不通过隐藏故障功能来降低验收要求。后续联网等需求记入下一阶段，不混入收尾。

日常仅修改源码、运行开发入口和必要测试；不逐次打包、安装或增加发布版本号。最终发布仍按明确发布指令执行。

## 用户最新调整：操作页面优先（2026-09-13）

本条覆盖下文历史记录中的全地图人工核对或逐张扫描要求。用户明确要求收尾主要关注操作页面，不需要把所有地图全部检查一遍。地图仅按操作闭环抽查新手村、代表商铺、传送入口及已知石墓卡点；已有707张格式检查保留为历史证据，不继续扩展全地图验收任务。

当前推进顺序：
1. 登录、注册、创建选角：布局、焦点、确认/返回、动画反馈。
2. 背包、装备、快捷栏：B开关、拖拽、穿脱、使用、绑定及失败反馈。
3. NPC、商店、仓库与任务：选择、买卖数量、存取、接取/提交、奖励与返回。
4. 设置、内挂、独立手柄面板：开关、肩键切页、焦点、滚动、关闭及位置记忆。
5. 各页面在最小窗口、默认窗口、宽屏下的遮挡、文本、点击区域；最后回归存档与代表场景。

现有素材边界、用户存档保护和平台兼容要求继续保留。已发现的阻断问题继续修复，页面验收过程中不展开新的地图普查。

## 最新执行方式：代码审查与自动回归优先

用户要求尽可能通过代码检查修复BUG，减少逐页模拟操作。后续优先审查共享窗口、物品事务、焦点与输入、存档、NPC服务边界；按缺陷增加针对性测试。图形和硬件特有问题才安排必要实机验证。此调整改变执行方法，不将未经实机验证的平台或手柄标为完成。

## 已有证据与边界

- 三平台构建、原生无素材设置页启动、包内素材审计已通过；证据见 VALIDATION.md。该记录是历史基线，不等于当前源码已经重新通过全套测试。
- macOS 已有十周年及十六周年完整导入、外部缓存读取与短时资源检查记录。
- 2026-09-13 重新执行 tests/release：5 项通过，覆盖目录大小写、缺目录、错误客户端、导出排除规则和平台库存在性；不代表完整异常恢复或实际游玩测试。
- 1833 个缺失图像引用登记了替代；读取得到图像不代表建筑外形、碰撞和遮挡正确。
- Windows/Linux 完整硬件游玩、实体手柄及两小时性能测试仍缺证据；地图视觉改为代表场景抽查。
- 旧目标移除后，新的收尾自动目标已于 2026-09-13 启用，按本清单执行。

## 当前验收缺口（2026-09-13 更新）

页面逐项进度与下一轮操作见 [操作页面收尾验收表](UI_ACCEPTANCE.md)，优先按该表完成实际流程。

最近开发源码已修复贴图缓存开销、角色占位更新开销、持续运行时名称消失、三种战士技能音效映射。现有正式预发布未重新打包，不能视为包含这些修改。

- 真实游玩：仅女战士创建、新手前两项任务及退出恢复等部分流程有实际键鼠证据；六种新角色、战斗拾取、代表室内路线及后续任务尚未完整走通。
- 操作：工具拖拽未提供按住移动事件，实体鼠标快捷栏拖拽待确认；实体手柄未测。
- 表现：名称恢复已有原生像素证据；完整窗口尺寸、动作听感、技能时序仍需实测。
- 性能：最近原生自动场景长测累计有效 2695.422 秒后提前结束，退出码0但缺少完成报告，原因未定；两小时验收未通过。539条采样中8条低于60FPS，最低49。它不代表实际键鼠探索或战斗验收；详见 RELEASE_READINESS.md 和 artifacts/closeout-native-soak-session.json。
- 平台：Windows/Linux只有历史构建及源码路径检查，真实图形环境游玩待完成。
- 发布：当前源码同步状态以 GitHub main 提交记录为准，尚未重新打包；最终归档与宣传资料仍需按实际成果复核。

## 缺陷分级

- P0：存档损坏、财富/奖励复制、无法启动、原始客户端被改写、原素材或登录数据进入发布包。发现后优先处理，未清零不交付。
- P1：任务卡死、通路无出口、主要操作无效、职业技能/声音错配、遮挡或输入错位妨碍游戏。当前范围内必须修复并回归。
- P2：不阻断流程的轻微表现与文案问题。逐项记录影响和处理决定，不以“全部完成”掩盖未修复项。

## 按顺序推进

### 第一批：基线与素材入口

- C00【完成】建立收尾目标、范围、证据和任务编号。
- C01【完成】发布/导入/启动回归当前 33 项通过（artifacts/closeout-release-regression.log）；不等同平台实机通过。
- C02【进行中】审查导入异常：错误目录、缺文件、缓存损坏、空间不足、写入失败、转换中断、重试和切换资源。先补可复现用例，再修复。
- C03【进行中】补齐缓存验收：707 张地图 ID 与文件结构、必要库和声音可读；失败提示定位文件；旧可用缓存与存档保持完整。
- C04【进行中】复核发布和公开同步边界：原始/转换素材及用户数据不得进入程序包，获授权的宣传图文单独放置。

首轮审查发现：当前导入校验以文件存在性和少数关键库检查为主，不能证明所有地图内容、所有引用帧完整；状态文件与失败重试也需要专门用例。这些是待验证/补强项，不直接宣称已发生数据损坏。

### 第二批：从新账号到退出续玩的完整流程

- C05【进行中】使用隔离存档覆盖战法道男女角色的新手流程；尤其复查女角色装备奖励、职业物品、任务前置与提交。
- C06【进行中】任务领取—目标达成—交付—奖励—重登；重复提交与失败重试不复制奖励。
- C07【进行中】战斗、技能书、技能快捷键、掉落与手动/自动拾取；背包满、负重满、材料或魔法不足时反馈明确。
- C08【进行中】背包拖拽、穿脱、快捷栏、商店、修理、仓库；失败不丢物，数量和装备实例不混淆。
- C09【进行中】NPC 碰撞、地图入口、室内进出、传送、安全落点、出口和存档位置恢复；仅抽查操作闭环涉及的新手村、代表商铺、传送入口及已知石墓卡点，不逐张检查全部地图。
- C10【进行中】死亡灰色停留、30 秒返回、立即选角、暂停/失焦与退出恢复；写入失败及损坏备份恢复。

每个闭环记录角色/地图/操作步骤、预期、结果、源码提交和日志。自动调用规则不能替代鼠标键盘操作验证。

### 第三批：表现、声音与操作

- C11【进行中】入口、HUD、装备背包、任务和辅助菜单：800×600、1280×800、宽屏与 Retina；检查贴图、文字、点击区域、缩放和遮挡。
- C12【进行中】角色/怪物/NPC 名称、受伤血条、任务标记、地面物品和地图光效；对缺图替代的代表场景留截图，严重建筑/碰撞不一致列为缺陷。
- C13【进行中】选角、八方向移动、受击死亡、怪物与云玩家、已接入技能、物品使用及拾取声音；共享或缺失声音明确登记。
- C14【进行中】实体手柄完成打开面板、肩键切页、使用/绑定物品、技能、NPC、仓库及辅助设置；复查输入焦点、断开重连和文字输入。无实体设备时保持未实测，不用注入事件冒充。

### 第四批：兼容性与稳定性

- C15【进行中】macOS 开发入口以前台默认窗口连续运行两小时，覆盖开窗、战斗、切图、暂停和存档，记录帧率与内存趋势；大型战斗另记，不拿 headless 数据当 FPS。
- C16【待做】Windows/Linux 真实机器或具备图形环境的测试机：干净启动、导入、中文路径、中文显示、音频、存档和基本游玩。明确 OS/架构/图形驱动，保留未覆盖设备范围。

实体设备不可用时，继续完成独立任务并留下具体缺口。可以交付有明确限制的预发布，不能宣布全平台完整实测或自动转为稳定版。

### 第五批：资料与最终交付

- C17【进行中】使 README、启动指南、版本说明、素材替代记录、宣传片及 B 站稿与实际版本一致；补充已知问题、恢复方法和反馈格式。
- C18【进行中】复核源码差异、测试证据和未关闭缺陷。仅清理本轮临时/失败构建及重复开发归档，保留客户端、源码、存档、引擎和正式成果。
- C19【待做】达到门槛后整理验收报告；有明确发布指令再执行一次最终无素材构建、校验、GitHub 同步及发布验证。

## 完成门槛

1. 当前范围内 P0/P1 清零，每项修复有针对性回归证据。
2. 主平台核心闭环通过，存档、素材源和经济状态保持一致。
3. 已登记地图完成自动完整性/连接检查，人工检查范围及未覆盖部分清晰可查。
4. 声音、界面、手柄和平台结果分别登记，不互相代替。
5. 性能记录、版本说明和已知问题可复核；未通过的门槛不得勾选完成。
6. 发布包不带可加载的原始/转换素材与用户数据；宣传图文与游戏资源边界明确。

当前执行重点：按操作页面清单优先代码审查与针对性自动回归，继续处理入口账号、技能和跨窗口边界；已通过的经济边界不无故重复。实机仅用于无法由代码证明的视觉、输入和性能项目，地图仅代表场景及已知卡点。每批更新具体证据与剩余缺口。

## 2026-09-13 第一批进展

C02 持续进行：启动页每次导入使用独立状态目录；缓存创建失败有明确提示；导入器防止将输出写入基础或补充客户端目录；状态写入失败不再引发二次未处理异常；失败后重试替换陈旧状态且保留旧缓存。统一 Windows 返回路径分隔符。

发布单元测试 12 项通过，其中新增 7 项故障注入检查。源码启动脚本已进行语法检查。本次没有打包、安装或修改用户存档。中断恢复和实际界面并发操作尚需继续验证，不将 C02 标为完成。

C03 进展：导入器新增地图 ID 唯一性/合法性、地图头与尺寸/长度一致性、通行数据与落点、全部基础图像库 SHA-256 和帧索引边界、已登记 WAV 的 RIFF/WAVE 头与 SHA-256 检查。真实导入缓存全部通过上述检查；测试合计 21 项通过。保留原始 DOS 短名地图 3~1。该证据不代表所有图像已逐帧解码或全部声音已播放，已有缓存入口和补充包验收继续待做。


C02/C03 追加进展：已有缓存入口现在先运行完整检查再保存设置并进入场景。十六周年补充包增加 SHA-256、帧边界、逐 PNG 解码/尺寸及登记声音校验，真实基础＋补充缓存检查通过。共 29 项发布单元测试通过；Godot 无界面集成测试使用真实 Python 子进程，验证有效缓存进入回调、缺失缓存拒绝、状态目录隔离和重试按钮恢复。

窗口关闭请求与页面退出按钮统一等待素材处理完成。中断故障注入验证未完成代不会发布为 ready，重试使用新目录且保留旧数据。此处没有模拟操作系统强制终止，也没有替代真实鼠标操作；相关项目仍进行中。证据：artifacts/closeout-supplement-tests.log、artifacts/closeout-cache-startup.json、artifacts/closeout-cache-startup-engine.log。本轮仍只改源码及测试，没有重新导出安装版。


资源配置保存补强：先写同目录唯一临时文件，再重命名替换正式配置；保留未知设置字段。配置读取失败时保留原文件并提示，保存失败时清理本次临时文件且不进入游戏。隔离的 Godot 实际文件测试通过，覆盖正常替换、损坏配置保留、父目录不存在的写入失败；未触碰用户 resources.cfg 或存档。证据：artifacts/closeout-resource-settings.json。操作系统在重命名时拒绝及强制中断尚未模拟，不将其计为完成。


第二批开始：六种职业/性别新手装备与第二任务、旧男装纠正、失败回滚及重载共 100 项检查通过；故事奖励事务 18 项检查通过，覆盖背包/负重拒绝、世界行更新后凭据插入失败的 SQL 回滚、重试及防重复领取。上述为隔离规则测试，并非新账号实际注册到退出的完整人工流程。

界面回归发现系统字体产生 FreeType 加载及塑形错误。主界面、世界标签、素材入口统一使用项目自带 Noto 中文字体，移除对 macOS 专用字体路径的依赖；女角色任务界面与视口注入双击穿装备测试通过，原字体错误消失。仍有 macOS 沙箱系统证书读取错误，未将其归为字体问题。真实屏幕布局和实际硬件输入仍待验收。证据见 artifacts/closeout-novice-gender.log、closeout-story-transaction.log、closeout-novice-font.log。未打包或修改用户存档。


战斗/物品/死亡回归：死亡等待边界、暂停、写入失败及重试 10 项通过；背包实例、拆分、仓库、穿脱与保存 25 项通过。旧背包测试未按现目录准备铁剑价格/穿戴等级，已修正测试前置并增加实际扣款断言、采购失败及时退出，未放宽游戏规则。

技能书测试在 headless 等待 frame_post_draw 无法结束，现仅图形模式保存截图。重跑 332 项通过，覆盖当前 23 项运行时技能的书籍学习、职业/等级限制、写入失败保留书籍、攻击模式、事件声音次数与聊天存档。无界面运行未产生新的截图，不能用这些断言证明声音实际播放或渲染正确。证据：artifacts/closeout-books.log、closeout-inventory_test.log、closeout-death_return_test.log。


地图回归发现未关闭问题：connections_test 遍历707地图、7511断言，7条失败：0151商铺回程在30/60/120 FPS失败及对应返回省份断言，另0159铁匠服务断言失败。需要区分相邻入口防反弹和寻路逻辑问题、旧服务名称断言差异，不计地图验收通过。报告 artifacts/closeout-connections.log 与 artifacts/connections-0.9.3/tests.json。基于本轮实际NPC坐标的 Python 通路检查已启动，尚待结果。发布源文件白名单264项路径/后缀检查通过，尚不等于实际仓库内容全量审计。

上述图检查现已完成：707地图、3747通路、856实际地面连通分区，计入NPC占位后0个图连通错误。因此下一步重点是运行时门槛触发与服务断言，不能将静态图通过视为运行时返程已修复。


0151与铁匠检查已定位为旧测试入口/数据假设：直接 player.go_to 跳过 world.approach 的相邻门格择路，(6,22)到(7,23)被邻门避让规则拒绝；实际交互通过相邻(6,23)门格可返程。测试改为调用正式 world.approach，未修改游戏通行规则。0159铁匠为 reference 服务，测试现验证实际参考商店目录存在，保留名称断言。完整重跑707地图、7511检查均通过，含30/60/120 FPS商铺往返。诊断证据 artifacts/closeout-route-probe.log；修正后 artifacts/closeout-connections.log。真实硬件输入和视觉检查仍未完成，C09保持进行中。


公开源文件边界：当前259个Git跟踪工作文件均在白名单，无符号链接、SQLite/M211/WAV文件头。该扫描不证明Git历史或任意重命名图片无问题，范围见 artifacts/closeout-source-boundary.json。发现原白名单仅交付宣传测试，遗漏游戏回归源码；现允许 game/tests2011 下 .gd/.uid 文件，测试输出/截图/数据库仍不纳入。发布单元测试共30项通过（artifacts/closeout-publication-tests.log）。未执行git暂存、推送或打包，新增测试在下次获授权同步时纳入。


声音实文件检查：外部基础＋补充缓存781个WAV经游戏实际加载器均可解码且时长非零；12个索引条目缺文件（可能未使用，待追踪）。解码仍有读取长度警告，定位记录 artifacts/closeout-audio-warnings.json；未将可解码等同听感/时序合格。新增可复现脚本 audio_decode_closeout_test.gd，报告 artifacts/closeout-audio-decode.json。C13进行中，未修改原始音频或打包。


WAV警告修复：flashbox/newysound3均为完整音频＋零循环smpl元数据。运行时仅剔除36字节且循环数/采样数据长度均0的smpl块，重算RIFF长度，不改源文件、不改PCM或有效循环。781文件重跑解码无读取长度警告；两文件字节对照及非空循环保持检查通过。证据 artifacts/closeout-audio-normalized.log；缺失索引仍12条，16周年目录按同名搜索无匹配，未用通用声音掩盖缺口。


缺失声音实际用途核查：启用区域怪物的profile声音覆盖表及启用刷怪记录不引用12个缺失索引，不能依据旧monster-sounds目录判定区域运行时缺声。范围/结果见 artifacts/closeout-missing-sound-usage.json；脚本生成怪物和动态技能尚未覆盖。怪物出场不重复事件2项、物品事件映射425项回归通过；仍非实际播放/听感验收。没有重新生成可能覆盖人工核对的旧声音目录。


原生操作验收启动：新增 closeout_manual.gd 隔离临时SQLite入口；通过computer-use真实鼠标点击新用户、键盘填写账号/密码/确认、Tab切换及提交，已显示账号创建成功与恢复码确认页。未记录恢复码或测试密码到交付文档，未碰用户存档。运行进程session58534保留在确认页，后续继续登录选角；该进展不代表六种角色完整流程。


隔离原生操作继续：通过真实键鼠完成登录、本机世界、开门过渡、中文名字女角色创建、选择开始和公告确认，已进入边界村，NPC任务感叹号可见。截图 artifacts/closeout-manual-village.png。剪贴板工具报告读取超时但重新观察确认中文已填入，未重复粘贴。游戏仍使用session58534的隔离数据库；六种角色及新手任务交付未全部手工走通。


原生女角色新手第二任务已真实键鼠完成：领取初到边界村奖励、接整装出发、B打开背包、双击木剑及布衣(女)、回村长提交，已解锁村外鸡群。截图 artifacts/closeout-manual-equipped.png。操作中发现接受/完成任务消息在聊天栏重复出现，作为UI反馈缺陷待定位；不能据重复文字推断奖励重复。当前测试进程保持隔离存档运行。


真实游玩发现的任务重复消息已修复源码：quest_panel先写pending_message后调info，info再次写pending_message触发两次聊天；移除前一次赋值。story_panel/controller_npc同模式一并修正。回归验证接受/提交各一条，奖励仍一次，两个独立相同反馈不被误去重。证据 artifacts/closeout-quest-chat.json，主脚本语法检查通过。session58534仍为旧代码图形进程，尚未重启复核修复后的真实点击，不将其声称已实测。


隔离窗口已通过原生关闭按钮正常退出，旧session58534退出码0；SQLite完整性检查ok，任务/装备状态证据 artifacts/closeout-manual-exit.json。manual入口支持显式复用/tmp/mafa-closeout-manual-前缀数据库，拒绝其他路径；新代码图形进程session89064已启动，复用该测试库，后续仍需登录后核对恢复与消息显示。未触碰用户数据库。


重启后实际键鼠登录、世界选择、选角进入地图完成：女装外观及289,618位置恢复，任务推进到村外鸡群。真实点击接受新任务，聊天只新增一条接受消息（旧存档两条重复历史保留）；截图 artifacts/closeout-manual-chat-fixed.png，确认quest_panel修复已在原生界面生效。故事及手柄NPC仍需分别实测。隔离进程session89064保持运行。


真实背包快捷栏拖拽未通过：B打开背包后sky.drag药品至第六栏，界面与只读数据库确认未绑定、药品仍7，未造成移动或消耗。暂不能区分工具拖拽路径与应用输入/缩放问题，需继续定位。截图 artifacts/closeout-manual-quickbar-unbound.png；测试进程89064仍运行。不要将既有注入事件测试当作本次实际拖拽通过。


拖拽诊断准备：核对item_slot拖拽字典与quick_slot的角色/容器/暂停检查，未发现足以解释实际失败的确定根因。隔离manual入口新增--trace-drag，记录鼠标事件位置、视口、命中控件矩形、引擎拖拽状态及暂停；仅测试入口启用，不记录键盘文本。语法检查通过，当前89064旧进程未加载探针，下一步需正常退出并用相同隔离存档+--trace-drag重启实测；暂不改游戏拖拽规则。


拖拽诊断新证据：已正常关闭89064（exit0）并启用--trace-drag重启session1482。登录点击可记录，但游戏内拖拽和暂停确认点击均未出现在_input日志，说明现探针不足以证明事件没到应用。观察到失焦暂停确认框；不据此断言游戏拖拽坏或工具坏。已补可选_process鼠标按键/位置/焦点采样，需下次重启加载；当前窗口仍使用同一隔离库。


C12/C14针对性回归：finish_scope 1863项通过，包括当前脚下名称、满血隐藏、受伤血条、回血、已学开盾/刺杀辅助及暂停/冷却、注入肩键、窗口边界与全部替代帧加载。地图光效测试覆盖新手村4个混合光格及各动画帧锚点，通过。两个测试在无图形环境下现在跳过截图，避免把空渲染当视觉证据。日志 artifacts/closeout-finish-scope.log、closeout-map-light.log；实体手柄、场景视觉仍待验收，拖拽实测问题仍未关闭。


存档恢复修复：主文件不存在但.backup.sqlite存在时，先校验恢复，避免SQLite自动创建空库。真实隔离数据库测试通过：备份进度恢复、损坏主库隔离且字节保留、主备同时坏时拒绝且不覆盖。测试写损坏字节显式关闭文件后再检查，避免缓冲未落盘导致伪结果。证据 artifacts/closeout-store-recovery.json。未模拟断电/COMMIT中断，也未修改用户存档。


事务中断补充：新增test_sqlite_interruption.py，在独立Python SQLite进程中按现store事务结构，分别在世界行写入后、凭据插入后、COMMIT后等待，经父进程确认边界后kill。前两处世界行/凭据一起回滚，提交后一起保留，integrity_check均ok。发布测试现31项通过，证据 artifacts/closeout-interruption-tests.log。该用例使用真实WAL+FULL但不是Godot实例崩溃、COMMIT进行中或断电，相关验收仍待补。临时数据库自动清理，不影响用户存档。


恢复边界补强：无主库/无备份但残留WAL或SHM时拒绝空库初始化；隔离文件名加入随机后缀。实际隔离文件回归通过，孤立WAL内容保留。新增 release/SAVE_RECOVERY.md 说明重试、备份及未验证范围。仍未模拟断电；未修改用户数据库。


特殊入口回归：石墓6项、火龙侧门16项、火龙委托34项通过，含可移动落点、旧卡点恢复、凭证扣除与失败回滚。火龙旧测试要求新角色可见锁定任务，与已确认隐藏未解锁任务规则冲突，改为断言隐藏；后续前置完成夹具下的接取/双奖励顺序与防重复断言保留。石墓测试在headless跳过frame_post_draw截图避免挂起。上述均非真实硬件输入/自然勘察旅行。证据 artifacts/closeout-stone_tomb_test.log、closeout-fire_passage_test.log、closeout-fire_dragon_story_entry_test.log。


仓库跨进程验证：正常存入退出(11项)与新进程取回/交付(9项)通过。进一步启用MAFA_RESTART_HOLD，确认Godot活进程写出已提交标记后SIGKILL，退出码-9；新Godot进程读取同库/WAL，9项恢复检查通过。证据 artifacts/closeout-warehouse-crash.json 及对应日志。被复用测试内scope文案仅描述普通重启，强制终止证据以外层报告为准；不宣称COMMIT中断或断电已测。普通测试退出有2个ObjectDB/1资源未释放提示，待verbose定位，不能略去。临时数据库由外层隔离目录清理，用户存档未动。


仓库退出残留诊断：verbose三次中一次记录field2.wav的AudioStreamPlaybackWAV/AudioStreamWAV残留。main已停止音频并清引用，测试只等三个极速headless帧。测试退出增加0.2秒混音清理时间，三次结果见 artifacts/closeout-leak-settle.json；不将短测试清理问题等同持续游戏内存泄漏，也不据此宣布两小时稳定性通过。


C15记录器准备：manual入口新增--record-performance，独立JSONL每5秒记录焦点/暂停/模式/有效时间/FPS/静态内存/纹理缓存/地图。被动采样不驱动游戏，不自动判定通过。headless排除有效时间与日志写入测试通过（artifacts/closeout-performance-test.log）；尚未在当前1482进程加载，两小时测试未开始。静态内存并非RSS，外部采样仍待补。


被动采样已实际启动：旧1482与短暂33958均退出后，单实例28852运行带trace与performance的隔离入口，日志 artifacts/closeout-performance-590abe19c72c50a7.jsonl。当前登录/失焦阶段不计入有效游玩，两小时尚未达标。已向用户询问Windows/Linux及实体手柄可用性，等待回复，不将未回复视为缩减验收范围。


原生拖拽工具记录起点背包/终点快捷栏点击命中，但无按住移动事件且dragging=false，尚不能证明实体鼠标拖拽失败；已向用户请求一次实体操作确认。当前采样显示前台村庄开背包约35 FPS、约960 draw calls（1280×800），低于60目标，是下一步性能定位重点；不是两小时测试通过。日志 closeout-observed.log / closeout-performance-590abe19c72c50a7.jsonl。进程28852继续运行。


C15贴图缓存首项优化：原生进程72153采样保存在 artifacts/closeout-native-cpu-sample.txt（ARM64，物理占用513.5 MB；符号不足，不能直接定位GDScript函数）。发现frame()在纹理缓存命中前仍解析素材索引，现改为命中后直接更新LRU返回，缓存未命中才解析。五批各10万次缓存访问中位耗时173075→66403微秒，约降低62%；仅微基准，不等同游戏FPS提升。缓存大小写、LRU、替代帧、清缓存重解析、无效索引回归通过，证据 closeout-frame-cache-before/after/test.log。当前已运行进程尚未重载此修改，实机帧率复测与两小时测试仍待完成。


C15移动更新定位与优化：新增隔离CPU诊断 closeout_cpu_profile.gd，村庄开包main_process中位17123→8021µs，world_update中位12145→6523µs，HUD约16µs。actors每个实体/占位格的any闭包改为唯一owner数量与ID判断；释放占位仅访问该实体原步进的两个端点，保留双端点预留。微基准不等同前台FPS，原生进程仍需重载复测。monster_ai 67项（30/60/120Hz命中次数均5）、story_pig_entry_occupancy 11项通过；actor_reservation_closeout_test验证四名村庄旅人12秒模拟平滑移动和双端点互斥。其退出资源残留提示保留，待进一步清理诊断。旧living_world_test调用已删除recruit_hero且仍断言1.1秒复活，已确认失效并停止其挂起进程，本轮不计通过。证据 artifacts/closeout-cpu-profile*.log、closeout-*-optimization.log、closeout-actor-reservation.log。


C15原生复测：正常退出旧进程28852（exit0），启动源码新进程会话59132，保留同一隔离存档；通过真实键鼠登录、选世界、选角并按B打开背包。1280×800，村庄无背包46–47FPS、背包约42FPS，前台focused=true/paused=false；比此前29–37改善但仍未达到60。证据 artifacts/closeout-performance-5b33f5f8e3cb2994.jsonl、closeout-optimized-village.png。世界模拟与实体位置有自然变化，非严格固定场景A/B；未通过两小时验收。


C15按需占位集合：actors逐步碰撞直接查询该格owner，完整blocked表仅用于旅人路径和怪物追击重定向；跟随落点同样检查实时owner。保留玩家起终点、旅人门口保护与双方步进端点预留。隔离CPU world_update中位1592µs、main_process1862µs，不能等同FPS；证据closeout-cpu-profile-lazy.log。旅人12秒30/60/120Hz占位和平滑移动、monster_ai67项、石墓11项均通过（closeout-*-lazy.log）。石墓测试退出仍有音频资源残留提示，未隐藏。当前原生会话59132未重载此轮，前台复测仍待。


C15第二次原生复测：旧59132正常exit0，最新源码会话34956运行同一隔离存档，经真实键鼠完整登录/选角/进入村庄/按B开包。前台1280×800短时读数无包59FPS、开包58FPS，达到接近60而非已证明稳定60。证据 artifacts/closeout-performance-c82ac046f5863da8.jsonl、closeout-lazy-village.png。后续跨地图/战斗/两小时和RSS仍未完成；进程保留运行。


C15实际村庄行走：确认原生PID77599活跃，RSS采样会话13389每5秒记录到closeout-native-rss-77599.csv；真实鼠标沿道路从289,618走到300,614，摄像机与坐标随行走变化。短时帧率约59–63，摘要closeout-native-walk-summary.json。点击移动中的鸡未确认命中，空格返回附近无合适目标，不能计战斗通过。仅同一地图短时行走，不是两小时或跨地图验收；保留游戏与采样进程。


C11名称可见性排查：实机截图名称不明显，隔离诊断确认labels可见、global_transform为单位矩阵，旅人名称矩形(41,416,48,24)处于1280×800视区；不是重复摄像机变换的证据。日志artifacts/closeout-label-diagnostic.log。此检查只证明投影/节点可见性，不证明像素实际绘制或层次正确，下一步应验证渲染层次，尚未做无依据偏移修改。


C11实际渲染缺陷已定位修复：冻结场景单次绘制能显示名称，但持续main更新时名称消失；提高z_index不解决。world._draw内对top_level labels排队刷新导致持续更新显示异常，现将labels.queue_redraw移至update_world（保留正常层级）。原生隔离图形测试持续40帧，修复前后截图closeout-label-live-before.png / closeout-label-live-fixed.png，已人工查看确认NPC/旅人/怪物名称与村长感叹号恢复。该测试冻结模拟但持续运行主循环，不替代移动/受伤血条实机检查；当前手动游戏进程未重载此修改。测试源码label_render_closeout_test.gd。


C11名称运动后像素验证：label_render_closeout_test改为真实原生渲染，AI运行180帧后冻结，测试将镜头定位到已走离原视区的旅人，再设置半血/满血夹具。两种状态名称区均检测到624个与隐藏名称层时不同的像素；半血血条可见、满血隐藏；退出0。截图closeout-label-injured.png/full.png与closeout-label-motion.json/log。人工查看半血截图名称与血条已出现（角色在屋檐后被地图遮挡，名称覆盖地图）；不声称自然受击或实体键鼠操作已验收。初次测试旅人走出视区导致name_pixels0，已修正观察夹具，未调整生产投影去迎合测试。


C13技能阶段审计：当前23项运行技能×3阶段共69条，发现12条unlisted（不是missing_file），详见closeout-skill-audio.json/log。其中半月25、烈火26现按魔法公式查询不存在索引；mirgo/cmd/client/actorsound.go:209–240明确SMLongHit/SMWideHit/SMFireHit在动作frame2使用独立近战音效，soundconst.go提供132/133等。应修复运行映射和时序，不将unlisted直接判为有意静音；其余刺杀/疾光/灭天火未登记阶段仍需核对。新增审计测试失败为预期缺口证据，未标记C13完成。游戏34956与RSS13389均已通过句柄轮询确认仍运行。


C13近战技能声音修复：依据mirgo actorsound.go frame2与soundconst.go，刺杀/半月/烈火采用132(m12-1.wav)/133(m25-1.wav)/137(m26-3.wav)，stage1叠加既有武器声；其余两阶段不套魔法公式。释放延迟=当前HUMAN动作帧长×2，规则伤害时点不变。melee_skill_audio_test通过专用映射、阶段静音、武器层、解码和延迟断言。skill_audio审计已按实际运行分支更新，其他未列阶段继续列缺口；证据closeout-melee-audio.log/closeout-skill-audio.json。尚无实际听感、动画取消与掉帧验证，不标C13完成。


C13剩余四阶段来源核验：十周年与16周年sound.lst均只登记10100(M10-1.wav)、10450(M45-0.wav)，两套目录无另四阶段文件。release/SKILL_AUDIO_SOURCE_EVIDENCE.json记录两原始索引SHA256和逐行摘录，可分类为源包单阶段声音；不声称知道原作者有意静音，也不添假音效。运行逻辑继续只播放存在索引。暂停由available阻止效果推进、死亡ensure_death清spell_events、切图有map过滤；源码检查不替代事件运行测试。


C13技能声音队列运行验证：skill_audio_queue_test使用真实gameplay队列及sound_started信号，30/60/120模拟Hz暂停保留事件、恢复后133一次；3秒掉帧137只一次；不匹配地图事件丢弃；死亡状态写入后update清空队列，全部通过。证据closeout-skill-audio-queue.log。事件由测试置入，地图不匹配不是实际切图操作，死亡是状态夹具；不代替真实施法/听感/技能动画完整验收。


C12全基础PNG实际解码启动：verify_client2011_packets.py新增--base/--output、拒绝空输入，并在PNG verify后调用Image.load进行完整像素解压。会话86302扫描当前开发基础98个库，日志closeout-full-png-decode.log，最终报告closeout-full-png-decode.json；当前尚未完成，不能计通过。C15采样显示原生游戏已暂停，有效游戏累计约303秒，暂停期间80FPS不作为游戏性能证据。


C12全量基础PNG完成：86302 exit0，98库985709帧，77.681秒，SHA256/范围/尺寸/PNG CRC/完整像素解压全部通过，errors[]。证据closeout-full-png-decode.json。范围为当前开发基础转换库；不能据此证明所有世界引用正确、遮挡正确或补充库全部覆盖。C18修复四个新增测试的清理后缀为实际.backup.sqlite，按精确随机ID文件名清理13个已结束测试的临时文件（closeout-fixture-cleanup.json），保留手动验收库与用户存档。


C04历史边界只读审计：tools/release/audit_git_history.py扫描git rev-list --all的4提交270唯一blob，原始素材/缓存路径扩展名及SQLite/WAV/M211签名findings0；证据closeout-git-history.json。不覆盖远端不可达对象、重命名专有图片、密钥或版权人工审核，保留未完成范围。未暂存、推送或改写历史。


C16开发启动兼容性：run_dev.py按当前平台识别.cache/godot与.cache/ci-godot固定4.7.2可执行文件，GODOT显式覆盖优先且路径无效明确报错，不静默改用其他引擎；无缓存时保留PATH查找。三平台路径（含空格根目录）与无效覆盖测试2项通过；只是模拟文件路径，不声明Win/Linux实机启动通过。未下载/导出/安装引擎。


C02/C03真实校验工作进程中断：Python校验进程写出running且poll确认活跃后SIGKILL，exit-9；同output路径再次执行--verify-cache成功exit0/ready，2469缓存文件size/mtime_ns完全不变，重试同时执行完整现有校验。证据closeout-verify-interruption.json、closeout-verify-retry.log。状态输出与缓存分离，临时目录已自动删除；不包括客户端转换worker、整个应用强退或真实按钮重试。


C02真实基础客户端转换中断验证已启动，会话4745。隔离.cache临时目录，start_new_session创建本次进程组；观察到大于4096字节PNG包且主进程活跃后SIGKILL本组，随后同output路径进行完整重试（2个worker）。日志closeout-conversion-killed.log/retry.log；尚未完成，不计通过。外层完成后核对原始文件size/mtime、新代次与ready状态，再由TemporaryDirectory清理本次完整/失败测试缓存，保留原可用缓存与客户端。


C02基础转换中断/完整重试完成：4745 exit0；首个转换进程组在部分PNG生成后被SIGKILL(-9)，同output重试exit0/ready，采用新generation，原失败代次在重试期间保留且未被当成完成；1796原始文件size/mtime_ns无变化。最终报告closeout-conversion-interruption.json。TemporaryDirectory已清理本次测试的完整和失败缓存；现有用户缓存未涉及。本结果不覆盖16周年补充转换中断或GUI应用强退。


最新手动进程：旧34956/13389正常退出0，新会话17482，日志closeout-current-native.log，性能closeout-performance-91c0e794939b4ec6.jsonl。真实键鼠登录恢复300,614位置，短时60FPS。截图closeout-current-manual-names.png中附近鸡外观未见名称，不能凭其外观确认是可攻击实体（此前点击只触发移动）；需核对该坐标场景对象与真实实体，再验证名称层，不直接宣称手动名称验收通过。旧RSS摘要closeout-rss-ended.json，含长暂停时间，不能作为两小时游戏结论。


C11/C07村庄300,614目标诊断：隔离实际地图实体中region:130:*鸡kind=monster/can_target=true，多只处于视区，日志closeout-target-probe.log记录body/name坐标。此前装饰假设不能成立为结论。手动截图仍有名称与鸡外观对应不清，需动态投影/绘制进一步核验；不计名称全通过或点击攻击通过。临时诊断脚本已清理。


C07近战距离空档修复：原生同帧覆盖图closeout-target-projection.png显示鸡贴图落在红色body命中矩形内，名称绿框对应脚下。发现interact统一4格才靠近而attack_target仅1.5格，导致中间距离点击不移动又打不到；monster阈值改1.5，NPC仍4，沿用靠近后再次点击流程。monster_approach_closeout_test验证3格外走向相邻格、不重叠、不提前伤害，通过（closeout-monster-approach.log），非实体鼠标战斗验收。


C07接近失败反馈：interact检查world.approach返回值，不可达显示“无法到达目标附近，请换一条路线”，而非成功靠近提示。接近回归新增地图外不可达目标夹具，断言路径为空、反馈明确、无攻击提交；同3格可达检查通过，日志closeout-monster-approach-feedback.log。该夹具验证失败分支，不等同真实室内阻挡路线。


C07/C11真实内挂交互：当前17482隔离角色通过鼠标进入内挂→战斗辅助，切自动攻击开关并Esc返回，聊天确认设置保存。实际追击建筑附近鸡出现反复“前方被阻挡，已停止寻路”提示，随后人工点空地仍遇阻挡；未确认有效命中/掉落。需检查自动追击的选点与手动移动优先级，不能将本流程计战斗通过。隔离角色自动攻击现处开启状态，后续继续操作需注意；不影响用户存档默认关闭设置。


C07自动追击路径修复：approach_target此前从player.cell静态path后直接写route，不考虑移动中的destination与其他角色占位。改为从步进终点规划path_avoiding，排除动态双端点与通道预留，通过player.go_to统一提交；保留candidate→target可迈步判定。回归明确断言半步状态、非空路线、第一步邻接destination、路线不含角色预留格，通过closeout-chase-route.log。手动移动优先级与原生追击仍待验证，不能把路径测试等同战斗闭环。


C07手动路线优先：world记录实际地面点击/方向移动的0.5秒短暂手动控制窗口；自动攻击选目标前等待手动窗口、现有路线和步进结束。喝药、低血回城、脚下拾取及职业保护仍在此前执行。回归启用真实assist配置，验证手动窗口内以及窗口结束但路线仍进行时，不改写route、不选择自动目标，通过closeout-manual-priority.log。真实键鼠/手柄交替控制仍未验收。


C07主循环自动战斗验证：新无装备女战士在300,614，开启自动攻击且关闭拾取，真实main._process按60Hz模拟60秒。最终4次区域击杀、4条地面掉落、背包不变、1次受阻后仍完成战斗，exit0。证据closeout-auto-combat.json/log与auto_combat_closeout_test.gd；初版计数闭包捕获整数不回写，改数组计数后重跑，报告已采用正确值。此为规则/AI集成测试，不是键鼠游玩或FPS证明。

C07拾取与恢复补验：扩展同一集成测试，关闭攻击后开启拾取，确认远处掉落保留，角色沿实际路线走到掉落格后收到物品；save_world 后关闭并重开同一 SQLite，再 attach，背包及剩余地面掉落的实例、数量、坐标均保持。首次严格比较失败来自 JSON 将整数读取为浮点数，测试将期望值按同一 JSON 契约归一化后通过，未改存储实现。最新报告 closeout-auto-combat.json、日志 closeout-auto-pickup.log：4击杀、4掉落、战斗时背包不变，四项拾取/恢复布尔检查全部为真。本次随机路线受阻0次，前次1次仍属前次结果。仅模拟主循环及同进程数据库重开，不替代真实输入、进程重启或性能验收；C07继续进行中。


C13审计分类补齐：skill_audio_closeout_test读取来源证据，69阶段中四条未登记阶段明确附带两客户端索引均缺失的分类和证据路径。报告增加source_documented_gaps及passed=false，继续以exit1保留未解决门槛，不把源包缺失自动认定为有意静音。最新closeout-skill-audio.json/log已核对四个ID：10101、10102、10451、10452；仍需实际播放或参考流程核验。


C07拾取失败与保护循环解耦：原auto_pickup_underfoot失败写assist_left=2，连带延迟喝药/低血回城等整个辅助循环。改为独立pickup_retry_left，仅在可运行状态递减，暂停冻结；本轮继续处理同格其他掉落，使背包满时金币仍可领取。pickup_retry_closeout_test实际规则/SQLite夹具48格背包验证矿石保留、金币到账、assist_left不变、重试期不重复提示、暂停不消耗计时，exit0，日志closeout-pickup-retry.log。尚未声称真实低血战斗或输入验收完成。


C07拾取重试保护补验：pickup_retry_closeout_test新增低血夹具，真实gameplay.update在拾取重试仍大于0时调用自动药品使用，生命增加、药品恰好减少1、地面矿石保留，exit0；退出有6个ObjectDB/3资源残留警告，未据此声明内存验收通过。旧gameplay_test误以headless运行，涉及frame_post_draw/截图，已中止exit130，不计完整回归结果；增加启动模式保护，headless明确exit2要求图形运行，日志closeout-gameplay-headless-guard.log。真实图形玩法回归仍待执行。


C15音频退出对照：pickup_retry同一测试headless verbose显示3组AudioStreamPlaybackWAV/WAV引用（field2、106、108）；真实图形/CoreAudio 48000Hz运行exit0，无残留警告，证据closeout-pickup-resources.log与closeout-pickup-native.log。仅此短流程驱动对照，不能推断长时间内存稳定。C07/C08/C10图形gameplay_test实际完成995检查，exit1，四失败：拖拽快捷栏、trap伤害、满血跳过治愈选择下一技能、死亡倒计时返回。日志closeout-gameplay-native.log；测试为注入事件及状态夹具，需分别判断旧断言与当前行为，未当作真实硬件操作通过。


C10旧回归死亡失败定位：closeout-death-diagnostic.log精确打印重载deadline比旧局部due晚0.000000000000227秒，零delta不跨过严格规则门槛。测试改为到期后实际1/60秒更新，生产等待规则不变；图形重跑995检查，死亡返回项通过，仍有拖拽/trap伤害/自动技能三失败（closeout-death-frame.log，exit1）。本项是浮点重载边界测试修正，不替代30秒真实键鼠等待验收。


C07技能回归修复：trap对应困魔咒，当前规则明确零伤害控制，测试改为检查HP不变且trap_status有效，图形验证通过。自动技能真实忽略skill_keys，目录首项trap抢占heal/talisman配置；新增auto_skills按绑定数字顺序过滤当前职业可用技能并去重，无可用绑定保留原可用列表回退，update采用此顺序。closeout-auto-order.log显示满血跳过heal后实际pending_attack.skill=talisman，995项检查仅剩拖拽失败，exit1。未更改技能伤害或将该图形注入测试称为实机手柄通过。


C08拖拽命中定位：原生图形closeout-drag-hit.log显示引擎拖动已启动且数据正确，快捷栏3中心(670,621)落在冒险面板“下一页 ▶”按钮矩形(504,614,190,28)内，hover路径为冒险面板导航按钮，非EditionQuickSlot。因此此次失败为窗口遮挡投放位置，不证明bind事务失败；需调整布局/验证移动窗口后可达目标，禁止以输入穿透绕过覆盖控件。图形测试仍exit1、该项未完成。


C08默认背包位置修复：无保存位置的冒险面板首次打开y=24，避开默认1280×800快捷栏；已有保存位置仍保留，未启用点击穿透。closeout-bag-placement.log实际hover路径与目标EditionQuickSlot一致，原图形注入拖拽成功绑定且背包数量不变，995检查failures[]、resource_errors{}、exit0。仅默认窗口与新位置配置通过；小窗口/已保存重叠位置及物理鼠标手柄仍待验收，不将此视为全部布局完成。


C08/C11小窗口修复：新增gameplay_test --small-window真实800×600图形分支，初次仍遮挡；冒险面板设置reserved_bottom=200逻辑UI单位（快捷栏顶距底196），窗口布局和拖动共同限制在保留区域上方，尺寸不足时降低面板高度并使用既有ScrollContainer，其他窗口不改。closeout-small-fixed.log目标命中EditionQuickSlot，995检查failures[]、resource_errors{}、exit0。需继续人工核查滚动内容可读性、缩放与旧保存位置转换；不以该注入流程替代实体鼠标验收。


C11小窗口视觉检查：gameplay_test --small-window --capture-bag保存真实800×600顶部和滚动到底截图closeout-bag-small.png、closeout-bag-small-bottom.png，已逐图查看。顶部背包格/纸娃娃清晰且快捷栏全部露出；底部截图确认腰带/护符等槽位及上一页/关闭/下一页/说明完整可见，滚动内容受面板裁剪未压住快捷栏。滚动由测试设置scroll_vertical，不宣称物理滚轮或手柄滚动已验收；其后恢复顶部继续原拖拽回归。


C18玩法测试临时库清理：gameplay_test退出前记录自身随机fixture路径，节点退出关闭数据库后仅删除该路径及-wal/-shm/.backup.sqlite，清理失败退出非零。实际默认窗口图形重跑995检查通过，exit0；脚本外按日志精确路径核对四文件均不存在，证据closeout-gameplay-cleanup.log。用户库、客户端和正式发布成果未涉及。


C11保存位置与缩放恢复：window_position_closeout_test用独立库分别写入旧像素位置[104,500]和归一化anchor[0.8,1]，实际窗口节点经历1280×800→800×600→1280×800及关闭重开；六组边界检查通过，面板下沿分别600/400，快捷栏上沿604/404，始终保留4像素间隔，原横向锚点随窗口变化恢复。headless节点布局与存储验证exit0，报告closeout-window-position.json；不等同图形Retina或物理拖动验收。


C07自动技能配置边界：发现绑定存在但全部暂不可用时，auto_skills回退整个职业技能列表，可能越过用户选择。改为仅无任何绑定的旧状态回退；有绑定则严格过滤，空结果保留普通攻击分支。auto_skill_order_test检查数值顺序、去重、跨职业/不存在/等级不足过滤及空绑定兼容，通过closeout-auto-order-boundary.log；为选择函数边界夹具，不是实机施法验证。


C07技能绑定失败反馈：bind_skill原先忽略apply结果始终提示已更新，改为失败显示rules.message并返回；成功才显示更新。skill_bind_failure_test独立SQLite query_only拒绝写入，断言状态不变和失败提示，恢复写入后重试成功且load_world读到新顺序，exit0，证据closeout-bind-failure.log。技能学习状态为夹具，非真实书籍购买或UI绑定验收。


C07当前技能选择失败反馈：select_skill原失败静默，补充rules.message。扩展skill_bind_failure_test，SQLite拒写时从治愈术切灵魂火符保持原状态和当前技能并显示失败；恢复写入重试后当前技能及load_world均为灵魂火符，exit0，closeout-bind-selection.log。覆盖逻辑入口，物理Q/手柄Y施法未在本次验证。


C14当前手柄面板图形复核：controller_panel_test在800×600注入Back/Y/LB/RB/B事件，failures[]、exit0，日志closeout-controller-panel-current.log。实际查看artifacts/controller-panel/panel.png发现手柄面板底部提示裁剪，仍需布局修复；事件通过不能标记视觉通过，更不是实体手柄验收。


C14手柄提示裁剪修复：controller_panel根据窗口滚动视区扣除页签、详情、提示和间距后动态计算列表高度（80–250），为底部操作说明保留空间。800×600原生图形controller_panel_test exit0/failures[]；已查看closeout-controller-fit.png，方向键/LB/RB/A/B/X及左右选快捷栏/Y绑定两行提示完整显示，当前物品列表可见。长任务详情及实体手柄仍待验收，未声称全页视觉完成。


C14独立手柄面板实时刷新：controller_panel按规则revision变化刷新列表/详情，按uid/skill/quest保持当前对象，避免背包或任务外部更新后仍显示旧数据。扩展原图形controller_panel_test，外部库存减少夹具后数量实时变化且选中uid保持，肩键/绑定/返回检查继续通过，closeout-controller-refresh.log exit0。外部变更为规则夹具，任务页外部提交及实体手柄未在本次覆盖。


C06/C14任务进度回归：controller_novice_progress_test当前源码16检查通过，涵盖击杀进度与材料分别更新、拾取后可交付、仓库存入/取出后状态更新且选中项保持、A提交完成。closeout-controller-progress-current.json/log记录来源范围：前置任务/击杀夹具和注入手柄事件，不是天然战斗或实体手柄。结构化C14清单同步最近布局/实时刷新/任务证据，硬件与长文本视觉门槛继续保留。


C04当前源码交付边界：source_files.audit当前805允许文件通过路径/扩展名检查，新增技能顺序、保存失败、拾取重试、窗口位置回归源码均在交付清单，publication单测通过；证据closeout-publication-current.json。未stage、生成归档或推送；不覆盖重命名素材、密钥或许可人工检查，发布门槛仍未完成。


C04交付二进制内容核对：当前允许清单含4个首页演示JPG/GIF、1个OFL字体、6个godot-sqlite平台扩展，逐文件大小/SHA256与用途记录closeout-publication-binaries.json，所需字体/扩展/Godot/mirgo许可证文件存在。全部允许文件扫描SQLite/WAV魔数未发现存档或音频。首页画面按已有MEDIA.md独立演示范围记录，不把它们说成无版权素材；此检查非完整敏感信息/许可审查，未发布。


C07/C14三职业技能书当前回归：controller_skill_guide_test 72检查通过，任务引导→背包→学习→返回，覆盖实际商店购书、等级不足拒用、SQLite拒写保留技能书/任务、重试恰好消耗一本、重复学习不消耗、任务学习目标和存档一致。closeout-skill-books-current.json/log；为任务/等级/资金夹具与Viewport事件，非实体手柄。headless退出1资源残留警告保留，未声明内存通过。


C18当前差异检查：git diff --check通过，核对最近gameplay/window/windows/controller_panel运行代码无DIAG或print诊断残留，文件SHA记录closeout-current-diff-review.json；技能声音注释改为缺索引仍属审计缺口，避免未经来源证明的“有意静音”表述。仅上述近期差异范围，非全项目代码审查或完整运行验收。


C14手柄任务外部更新补验：controller_panel_test新增已接故事夹具，通过RB进入任务页后外部规则提交done；无需重开，列表移除该条目，空列表详情替换为无已接任务，原背包/肩键/绑定/返回检查仍通过。closeout-controller-task-refresh.log图形exit0/failures[]；完成状态为夹具，不声称真实任务NPC交付流程在本次覆盖。


C15当前原生冒烟完成：soak_test实际120.008秒、地图0/3交替，exit0/resource_errors{}，日志与报告closeout-soak-current.log/json。启动后村庄多数55–67FPS，盟重稳定段119–120FPS，切图瞬间样本不作稳态依据；RSS峰725616KiB，末538720KiB，没有本次单调增长，但不能证明无泄漏。旧工具未记录暂停/活动时长，且automation绕过保存，因此只作两分钟绘制/加载冒烟，不是两小时游戏/存档验收。村庄稳定60FPS门槛仍未满足。


C15稳定性采样补齐：soak_test现在分别记录active_wall_seconds/paused_wall_seconds，每条包含paused、game_seconds和cell，防止仅按墙钟宣称探索。原生20秒分支实际运行exit0，字段检查通过（closeout-soak-timing.log）；未启用Godot电影输出，仅验证采样，非视频交付/两小时验收。


C15当前CPU分段：closeout_cpu_profile当前headless120样本/段，main中位2008us/P95 2755us，world1590/2054us，HUD16/18us，tracker1/1us，证据closeout-cpu-current.json/log。此工具不含draw/GPU，不能解释或替代原生55–67FPS结论；下一定位方向为实际绘制/渲染，未无依据改玩法逻辑。


C15渲染计数采样：soak_test新增Performance处理时间、draw_calls、render_objects、render_primitives。当前原生20秒村庄采样启动后FPS57–58、draw_calls622–817、render_objects930–1143，TIME_PROCESS24.455–24.982ms（引擎指标，不等同先前仅GDScript方法计时，也不是GPU耗时）。证据closeout-render-sample.json/log，exit0。需要进一步分离地图/角色/文字绘制贡献再优化；未据此证明GPU瓶颈或性能达标。


C15静止图层对照：render_layers_closeout_test原生同一暂停村庄，基准812 draw calls，隐藏labels792、lights811、HUD629、world187；median TIME_PROCESS分别16.779/14.856/14.664/12.954/12.684ms。closeout-render-layers.json/log，exit0。图层只在隔离诊断隐藏，正式内容不变；顺序测试/暂停场景，不可把差值直接认定GPU耗时或玩法FPS收益。主要绘制调用来自世界与HUD，后续需针对批次/重绘定位。


C15小地图细分：图层对照增加no_minimap，基准812绘制调用，隐藏小地图687，隐藏整个HUD629；小地图约占125次调用。closeout-minimap-cost.json/log。同次no_world处理时间反而升至18.377ms，说明顺序/调度噪声明显，不能把处理时间差当确定收益。下一候选为合并小地图标记绘制，保持全部标记语义与视觉，不删除内容。


C15小地图批量绘制：标记以同顺序外黑内彩24段圆盘组成ArrayMesh，复用相同顶点/颜色的网格，仍保留全部有效实体和自身标记。原生对照总调用812→693，no_minimap仍687，小地图差值125→6；closeout-minimap-batch.log。实际查看closeout-minimap-batch.png，当前场景金/绿/红/白标记、描边和坐标可见。未完成像素级旧版对照、所有缩放/移动和真实FPS收益验证；首次接口缺texture参数编译失败已修正并重跑。正式内容未删减。


C15批量标记移动运行：同soak20秒分支原生采样5/10/15秒FPS均59，绘制调用662/537/459，TIME_PROCESS23.827/24.487/24.413ms；此前同路线采样57–58FPS及817/698/622调用。closeout-minimap-runtime.json/log，exit0。短时单次对照仅证明调用减少，帧率差可能受运行噪声影响，稳定60仍未通过。当前实现每帧仍生成顶点再比较缓存，可进一步按标记描述变化重建。


C15标记几何缓存：minimap先收集屏幕位置/颜色/半径描述，仅描述变化时生成24段顶点和更新ArrayMesh；静止标记不再逐帧三角函数与顶点数组构造。语法检查和原生分层回归exit0，绘制调用仍693，closeout-minimap-cache.log；本次基准TIME_PROCESS22.435ms存在噪声，不能声称已得到确定CPU/FPS收益，移动/样式切换失效验证仍待补齐。


C11/C15小地图缓存更新：minimap_cache_closeout_test原生图形验证静止描述保持、移动标记变化、死亡移除、全图/收起/附近循环及展开恢复，exit0/无脚本错误，closeout-minimap-invalidation.log。最小实体夹具仅供小地图，隐藏世界避免它参与完整角色绘制；非自然移动/实际鼠标点击或全局画面验收。


C18隔离数据库清理：按已知mafa-gameplay/mafa-controller/controller-novice-progress/controller-skill-guide/mafa-soak加16位随机hex精确文件名识别104个测试SQLite及附属文件；lsof exit1/stdout stderr空确认无打开句柄后删除，逐路径核对均不存在。报告closeout-isolated-db-cleanup.json。排除手动验收库、用户worlds、客户端、源码及发布成果。


C18旧脚本退出清理补齐：controller_panel/controller_novice_progress/controller_skill_guide/soak退出时仅清理自身fixture及-wal/-shm/.backup.sqlite，清理失败返回非零。技能书72检查重跑通过，另三个脚本check-only通过（soak局部变量冲突已修复）。未重复无关图形验收；证据closeout-cleanup-guide.log、closeout-soak-cleanup-parse.log。


C15/C16采样器平台兼容：soak不再硬编码/bin/ps或无条件output[0]，支持的类Unix平台通过PATH运行ps并检查退出码/数字；Windows等未实现RSS平台明确null，失败/空输出/零负数同样null而非误报零内存。soak_rss_test有效输出及六种不可用分支通过closeout-rss-parser.log。未声称Windows实机或Windows内存采样已完成。


C16正式入口静态检查：game/scripts及run_dev/import_client无/Users或/System/Library硬编码；唯一运行外部进程入口bootstrap按平台选择导入器且使用参数数组，开发Python按环境配置，未执行原客户端EXE。未找到列出的常用网络API调用，但静态搜索不能证明依赖/OS无网络访问，更不替代三平台实机。报告closeout-runtime-portability-review.json。


C08当前真实窗口复核：关闭旧进程后使用现有隔离库启动当前源码（会话78414），实际工具鼠标登录/本地世界/选角/公告进入场景，B打开背包，旧保存位置已避开快捷栏。截图closeout-manual-bag-latest.png。sky.drag从药品格到第六快捷格，日志closeout-manual-latest.log仍只有起止MouseButton、无按住移动、dragging=false，未绑定；不能以本工具失败判定物理拖拽实现错误，也不能宣称通过。此处仍需实体鼠标验证，应用保持当前源码运行。


C11真实窗口小地图复核：当前开发版实际鼠标点击完成全图→收起→附近，重新展开标记可见，打开地图按钮打开世界地图窗口。截图closeout-manual-minimap-full.png、closeout-manual-minimap-collapsed.png、closeout-manual-minimap-nearby.png、closeout-manual-map-panel.png。仅本次1280×800窗口，不代表全部缩放/平台。世界地图说明已移除源文件名和地图尺寸，保留地图名、人物坐标、出入口指引；main.gd check-only通过，运行中的旧实例未热更新此文案，待下次启动视觉复核。素材缺失诊断仍保留。


C03/C10切图失败状态保护：world.enter_map先读取目标元数据、通行文件和地图文件，成功准备后才替换当前场景。main仅在成功后清理待执行攻击/技能/死亡计时并记录旧地图实体；保留旧实体快照供region.reset记忆，避免丢失刷怪状态。map_failure_closeout_test使用隔离目录模拟缺walk与缺mapbin，两者保持当前地图、文件句柄、碰撞、位置、实体和待执行状态；随后有效切图成功且旧spawn记录保留。closeout-map-failure.log exit0/PASS；headless系统CA证书环境警告存在，无脚本错误。此为故障注入，不替代自然传送和实机损坏缓存界面验收。原素材、用户存档未修改，测试临时目录/库清理。


C03/C10损坏地图拦截：运行时在替换场景前核对M211标识、宽高、stride与精确文件长度，拒绝截断及不匹配包。map_failure_closeout_test扩充为六种缺失/损坏情况，保留当前状态并可成功重试；headless exit0/PASS，系统CA环境警告仍在。当前707张缓存地图按相同头部/长度规则逐张通过，closeout-map-header-compatibility.json errors[]；只证明格式兼容，不代表逐地图视觉/通行验收。


传送失败上层回归：移除NPC传送、通路和死亡回城在目标加载失败后重新加载原场景的多余操作，避免底层保留状态又被上层重置；保存失败后的回退仍保留。六类缺失/损坏包经cross_passage和teleport_with_npc验证原文件/实体/待执行攻击保持、金币不扣、入口重试标志复位。closeout-map-failure.log exit0；死亡回城失败补充可重试/返回选角提示，该提示尚未实际界面复核。


C08/C11原生窗口实际操作：恢复失焦暂停、Esc关闭地图、B打开冒险面板、Right切装备、鼠标点击技能和任务页、Esc关闭返回游戏均成功。默认1280×800，装备/技能/任务标签切换正确，底部返回导航及快捷栏可见。截图closeout-manual-equipment-tab.png、closeout-manual-skill-tab.png、closeout-manual-quest-tab.png、closeout-manual-panel-closed.png。当前角色未学技能，此次未验施法绑定；未含实体拖拽、全部尺寸或手柄。任务详情长句右缘需在后续宽度测量/截图放大复核，未断言全部文本无裁切。运行实例为此前已启动的源码基线，不含随后地图异常保护改动。


C11任务文字宽度复核：journal_width_closeout_test在800×600、1280×800、1920×1080检查已接nv_hunt与旅途指引详情，共30个可见Label，水平边界均在详情滚动容器内，长段落记录实际换行数。closeout-journal-width.json/log failures[]。隔离任务状态夹具、headless布局测量，不代表字体实际像素、滚动末尾或全部文本验收；目前未证实先前截图疑似裁切，因此未盲目改布局。测试库已清理，系统CA环境警告仍存在。


C11/C14内挂焦点同步：复选框、SpinBox内部编辑框与活动按钮获取焦点时同步手柄cursor，避免键鼠选中后A/方向键仍操作旧行。assist_focus_closeout_test验证焦点同步、A切换当前蓝药开关、右键调节当前数值、活动页焦点和切页归零，headless exit0/PASS；直接事件与焦点调用，非实体手柄或实际鼠标验收。closeout-assist-focus.log。首轮夹具缺assist默认字典已修正；中止该失败进程后清理本测试精确随机库，用户数据未改动。


C11/C14内挂保存异常：assist_focus_closeout_test对隔离SQLite启用query_only，复选框/数值修改失败后控件恢复原值、规则状态不变、页面notice显示失败消息；恢复可写后数值重试落库，关闭重开恢复值。原焦点/A/方向键检查仍通过。closeout-assist-focus.log exit0；两条readonly SQL错误为主动故障注入，另有系统CA环境警告。此为控件信号与数据库测试，非真实磁盘故障或实体手柄验收。


C11内挂真实显示：实际H打开补给保护、鼠标切职业技能页，默认窗口中开关/阈值和职业说明可见，截图closeout-manual-assist-supply.png、closeout-manual-assist-profession.png。观察到关闭状态也统一写“开启”，源码改为已开启/已关闭并在保存失败回退后同步文字；assist_focus_closeout_test补充成功/失败两种文案断言通过。旧运行实例截图不含此文案修复，待重启视觉验收；非实体手柄。


C11内挂布局矩阵：800×600、1280×800、1920×1080下五个页签共15组合，窗口及关闭按钮位于视口内，各操作控件横向位于滚动容器内；hint在全部组合无需垂直滚动即可到达。closeout-assist-layout.json，assist_focus_closeout_test exit0；保存拒写/重试和焦点检查仍通过。headless几何检查，非像素视觉/实体输入或长错误消息状态验收。


C08/C14手柄操作面板反馈：operate结果及取消追踪改为同时写入当前面板notice与聊天消息，失败不再仅在被面板遮住的底部聊天区显示。controller_feedback_closeout_test隔离SQLite拒写绑定，确认规则不变、notice显示错误；恢复写入重试落库、成功提示替换失败提示。closeout-controller-feedback.log exit0/PASS，SQL readonly为注入预期；未做实体手柄/长提示实际布局验收。测试库已清理。


C11/C14错误提示挤压修复：800×600手柄操作面板显示多行保存失败说明时，hint底边632超过scroll底边583。列表高度计算现扣除body中可见的其他控件及间距，重测hint底边583与可视区相同；controller_feedback_closeout_test增加断言，保存失败/重试检查仍通过。closeout-controller-feedback.log。headless几何回归，真实画面及更长文本滚动仍待实际检查。


C11/C14手柄长提示原生截图：controller_feedback_closeout_test在800×600图形渲染exit0，查看closeout-controller-feedback.png确认两行保存失败文字、四行物品、详情及两行按键说明完整可见，关闭按钮可见；hint底边583位于scroll底边583。closeout-controller-feedback-native.log，SQL只读为预期故障注入，退出IMK环境日志保留。截图为实际渲染、操作由测试调用，不代表实体鼠标/手柄完成。


C08/C14手柄仓库实时刷新：监听规则revision刷新列表，并按实例uid恢复选择。warehouse_refresh_closeout_test通过外部规则夹具扣除一瓶药，验证数量即时更新、选中实例保留；移除该实例后列表无残留且cursor有效。closeout-warehouse-refresh.log exit0，headless环境CA警告；不是实体操作或真实自动喝药过程。隔离库清理。


C08/C14仓库存取当前原生回归：story_warehouse_controller_test 14检查failures[]，从NPC服务入口通过Viewport手柄事件进入仓库，拒写保持状态、重试存入、RB切页、距离/暂停拒绝、取回推进任务、B关闭通过。查看artifacts/world-story/warehouse-controller.png确认800×600说明和结果可见；列表此时为空为取回后状态。closeout-warehouse-controller.log；地图/任务前置为隔离夹具，非实体手柄或自然任务验收。脚本新增自身数据库及附属文件退出清理，不改用户存档。


C08/C11满背包商店原生回归：merchant_scroll_test当前源码10检查通过，48独立矿石出售行保留，焦点滚动可到最后一行；出售后该行禁用、邻行数量有效且滚动位置保持，修理入口独立可见。查看world-story/merchant-scroll.png确认800×600列表末尾/修理/关闭按钮可见；顶部半行是列表滚动裁剪，非整窗遮挡。closeout-merchant-scroll.log，世界隐藏为图形夹具、交易规则直接调用，非实际鼠标交易。测试增加自身库退出清理。


C08实际鼠标便利用品购买：隔离手动账号560金币，点洗点石2000金币得到聊天“金币不足”；点回城石500金币后聊天购买×1、背包新增物品且金币60，截图closeout-manual-shop-insufficient.png、closeout-manual-return-stone-purchase.png。发现购买结果未显示面板notice，源码购买改用app.info；加点重建页面后再显示结果防止提示被清空。check-only通过，当前旧实例截图不含新反馈修复，待重启验证。非全部NPC商店交易验收。


C08便利用品反馈回归：utilities_feedback_closeout_test通过实际页面Button信号验证金币不足不改状态、500金币购买回城石新增物品且notice显示结果、2级夹具加力量后重建面板保留结果与已加1文本。closeout-utilities-feedback.log exit0；首轮1级无点可加的夹具断言已改为2级，失败进程中止并清理本测试随机库。非实体鼠标/自然升级测试，用户数据未修改。


C11设置缩放保存反馈：UI/map缩放由先改显示改为metadata保存成功后应用，失败显示store.error且保留当前倍率。settings_save_closeout_test控件信号+query_only验证两个选项失败不变、可写后重试保存和应用，closeout-settings-save.log exit0；SQL只读为预期注入，非实体鼠标/缩放画面验证。隔离库清理。


C11声音设置保存一致性：set_sound_level保存成功后才应用音频总线，返回bool供滑块失败时恢复原值；静音同样先保存再生效。settings_save_closeout_test新增音量/静音拒写保持与提示、可写重试持久化，原缩放回归仍通过。closeout-settings-save.log exit0，SQL readonly为故障注入，非听感/实体滑块验收。测试隔离库已清理。


C11设置按钮反馈：保存进度失败现在写入当前notice，成功文案为游戏进度已保存；恢复窗口需先成功清除保存尺寸再应用，失败显示原因。settings_save_closeout_test增加readonly保存/恢复拒绝提示与恢复写入后保存成功断言，exit0。此为隔离数据库与控件信号回归，实际窗口尺寸恢复未在headless验收。


C11设置操作说明整理：删除过时的补充素材75帧/1音效统计和设置页内开发里程碑说明，保留资源版本基准；补充K技能页、手柄X/Y、肩键战斗切技能与面板切页的区别、Back独立面板、Start暂停及账号键盘输入。按当前main输入处理核对；check-only与diff检查通过，证据closeout-settings-copy.log。未因此宣称全部功能或手柄硬件完成，长说明页面滚动待视觉复核。


C11设置原生底部截图：settings_save_closeout_test图形800×600滚动到底，保存按钮全矩形在scroll内，查看closeout-settings-bottom.png确认地图缩放/全屏/恢复/静音/保存均可见；关闭设置恢复world.paused=false通过。closeout-settings-native.log exit0；滚动为脚本操作，非实体鼠标。新发现：底部点击保存后notice在滚动顶部不可见，虽聊天可见仍需改善面板反馈可达性，不能将文字赋值当成可见验收。


C11设置固定反馈区：EditionWindow新增按需pin_notice，设置页将notice移出滚动body固定在底部，列表按提示高度让出空间。800×600原生测试滚动到底再保存，notice在窗内且位于scroll下方；查看closeout-settings-bottom.png确认“游戏进度已保存”完整可见。closeout-settings-native.log exit0，原保存/缩放/音量拒写重试仍通过。仅设置页启用，其他面板未改变；长异常文本另待验证。


C11固定提示多行验收：settings_save_closeout_test新增多行错误夹具，notice多行位于窗口内且不与scroll交叠，列表可滚到保存按钮；清空提示后隐藏且列表恢复高度。800×600原生查看closeout-settings-error-footer.png三行错误完整可见，closeout-settings-native.log exit0。为图形与脚本滚动，不代表实际磁盘错误/鼠标滚动。


C10/C11设置暂停语义修复：打开设置记住原暂停状态，正常关闭恢复该状态；设置页失焦后确认继续时若设置仍打开，保持settings暂停，避免设置中世界运行。settings_save_closeout_test新增原先手动暂停→设置关闭仍暂停、游戏运行→设置→失焦确认仍暂停→关闭恢复运行断言通过。headless方法/确认信号回归，不代表实际OS失焦操作。


C10/C11失焦取消路径：确认框canceled不再无条件清空pause_reason，设置仍打开则保留settings并给出关闭设置指引；普通失焦取消保持暂停、允许P继续。settings_save_closeout_test新增两种取消状态和关闭设置恢复断言通过，closeout-settings-save.log exit0；信号测试，实际Esc取消待验。


C05/C11当前源码手动启动：正常CmdQ退出旧实例，list_apps确认Godot不存在后启动当前源码会话41294，沿用隔离manual库。实际登录→本地世界→石门→既有女战士选角→公告→游戏，H打开内挂。closeout-manual-current-assist.png已查看显示当前“已关闭”文字，确认新代码加载；closeout-manual-ui-current.log记录本次启动。未重新创建账号、不触及用户库，后续继续该实例验证。


C11内挂当前源码实际开关：鼠标点击自动蓝药，文字变已开启且顶部提示设置已保存；Esc关闭再H打开仍已开启，closeout-manual-assist-reopened.png。随后实际点击恢复关闭，已查看已关闭及保存提示。使用隔离验收库。发现首次提示出现会把开关行整体下移，后续可沿用固定提示区减少布局跳动；未宣称阈值、所有开关或实体手柄通过。


C11内挂提示跳动修复：show_assist启用已有pin_notice，保存结果移至底部，不再在开关上方插入一行；assist_focus_closeout_test新增第一次切换前后global_position相等断言通过，原15组合布局/焦点/拒写回退仍通过。同步finish_scope_test与promo_capture的内挂视图索引以适配notice移出body，未重跑宣传录制。当前手动实例未热更新，实际新布局待下次启动验证。


C11当前手动设置验收：实际点击HUD设置入口，鼠标滚动到尾部，点击保存进度；closeout-manual-settings-save-footer.png中固定底部显示游戏进度已保存，聊天同步显示。当前源码实例41294、隔离账号，非信号触发。默认1280×800截图640×432展示比例；未据此覆盖所有尺寸、音量拖动与OS失焦。


C11当前源码音乐滑块实际操作：鼠标滚动到设置顶部，点击音乐轨道中部，Esc关闭再点击HUD设置；closeout-manual-volume-reopened.png显示音乐滑块保留新位置，其余三路不变。随后鼠标点击原音乐位置并查看恢复。只证明鼠标点击滑块/重开恢复，未验证持续拖动、跨进程持久化或实际听感，操作仅隔离验收库。


C10/C11真实Esc发现及修复：当前手动实例设置中按Esc无反应，P也不继续；定位main._unhandled_input在paused分支先return，跳过Esc关闭。现将非modal Esc关闭置于暂停分支之前，仍不释放其他战斗输入。settings_save_closeout_test改用Viewport Escape事件关闭预暂停设置，窗口关闭且保持原暂停断言通过；closeout-settings-save.log exit0。手动旧实例未加载本次修复，需重启后真实复核。


C11/C14手柄B弹窗保护：main.controller_button的B提前分支加入has_modal判断，确认框存在时不再关闭底层窗口。settings_save_closeout_test方法调用验证确认框/设置/暂停保留，弹窗隐藏后B关闭设置恢复原运行状态；exit0，非实体手柄测试。


C11确认框回调隔离：settings_save_closeout_test新增取消第一操作后确认第二操作仅触发第二回调、重复confirmed不重复执行、失焦确认替换业务确认后不执行旧回调三条断言通过。现有confirm清理旧连接/单次连接逻辑有效，无需改生产代码；closeout-settings-save.log exit0，信号注入不替代真实确认/取消点击。


C11实际NPC列表可用性：地图→本区NPC入口及多次鼠标滚动正常，但原数据顺序混排全省远处NPC，附近村庄人物藏在列表末段，未完成商店入口预期。show_region_info现对NPC按距玩家格坐标距离排序，默认/安全区仍在前，无移除NPC或变更坐标。check-only通过closeout-npc-order.log；当前手动实例未热更新排序，后续验证实际效果与商店入口。


C08/C09实际NPC购买链路：在本区NPC列表鼠标选择边界村店铺[291,610]，角色由[302,612]自动走至[292,610]，E打开该NPC商品页；实际点击金创药(小量)40金币，面板与聊天显示购买×1/花费40。closeout-manual-npc-purchase.png已查看。没有直接改人物坐标或调用交易规则，使用隔离manual库。此次未核对买后数据库/重登和出售；可见若干未支持商品仍禁用显示，未将商店全部完成。


C08实际NPC购买后核对：再次点击40金币药品，商店/聊天明确提示金币不足；B打开背包显示金币20。隔离库只读核对金币20、potion8、单一背包药品实例，与界面数量一致。证据closeout-manual-npc-insufficient.png、closeout-manual-npc-purchase-bag.png、closeout-manual-npc-purchase-state.json。未采集购买前物品快照，未将数量增量/重登/出售标完成。


C08商店出售与提示修复：实际鼠标滚动找到出售药品，点击后余量8→7，商店/聊天提示获得20金币；隔离库只读核对金币20→40、药品7，截图closeout-manual-npc-sale.png。发现首次结果提示挤动列表，show_reference_npc启用固定底部notice。merchant_scroll_test加入提示后列表原点保持与提示窗内可见检查，原生800×600共12项通过，closeout-merchant-scroll.log；查看world-story/merchant-scroll.png确认底部提示与修理入口可见。修复后的实际鼠标复核待重启，未当作已完成。


C05/C08/C10/C11最新源码实际重启：旧实例用窗口关闭按钮退出，确认进程不在后启动41000（closeout-manual-ui-final.log）。实际登录→世界→既有女战士→公告。旧档HP已为0，灰色死亡页继续倒计时后回边界村安全区[290,613]，聊天提示装备物品保留。B背包显示金币40、药品7，与隔离库一致，closeout-manual-restart-state.json/closeout-manual-restart-bag.png。点击设置后真实Esc关闭成功，closeout-manual-settings-escape.png。未精确计时30秒、未验证商店固定提示和内挂开关新布局。此前CmdQ无效不单独归因于失焦：解除失焦后仍未退出，使用窗口关闭正常退出；快捷键另待定位。


C11最新源码内挂实际验收：H打开，鼠标自动蓝药开关开启，保存提示固定底部，原开关仍在同一位置；Esc关闭/H重开保持开启，随后恢复关闭。鼠标选择魔法阈值、CmdA输入35、Tab提交，切到拾取页再回补给页仍35；随后同样操作恢复30。隔离库恢复后只读记录closeout-manual-assist-state.json。截图closeout-manual-assist-fixed-feedback.png、closeout-manual-assist-threshold.png。仅该开关/阈值及页签流程，未将全部内挂/实体手柄标完成。


C08/C11当前源码NPC固定提示真实点击通过：传送员2000金币路线余额不足，底部提示且按钮原位（closeout-manual-npc-fixed-feedback.png）；附近NPC列表先显示传送员、村庄商人/村长，实际选商人[291,610]自动走近，E打开商品。点击40金币药品后底部购买提示，商品仍在同一位置（closeout-manual-shop-fixed-feedback.png）；隔离库金币40→0、药品7→8。覆盖默认窗口一次购买/一次传送失败；未覆盖所有商品、长错误或仓库。


C08拆分选择修复：拆分弹窗优先选择当前选中的可拆分物品，选项显示格位，同名堆叠可区分；数量上限按选中实例初始化。split_selection_closeout_test隔离库验证第二叠被拆、第一叠不变、总量守恒及上限正确通过（closeout-split-selection.log）。headless退出有环境日志写入/CA与资源释放警告，未据此宣称原生操作通过。


C08拆分异常流程：弹窗不再无条件关闭；保存失败保留并显示错误，成功后关闭，待删除弹窗重复确认忽略。提交时验证UID仍属于原容器，物品移走不在其他容器继续拆分。split_selection_closeout_test注入SQLite只读失败，验证revision/总量不变、原弹窗重试成功、重复确认不重复提交通过（closeout-split-selection.log）。错误注入日志为预期，退出资源释放警告仍保留待查。


C08拆分陈旧弹窗回归：打开弹窗后通过规则将所选堆叠移动至仓库，再确认原弹窗；revision不变、原堆叠数量保持3、提示物品已移动，弹窗可取消。closeout-split-selection.log退出0，原失败重试/重复提交/守恒检查仍通过。此次正常日志未出现先前ObjectDB/资源仍在用警告；单次未复现不能断言根因修复。verbose探查closeout-split-verbose.log仅记录退出StringName遗留，未定位到应用对象泄漏，保留观察。


C08拖拽入口保护：普通物品格校验非空字符串UID且实例仍存在，拒绝死亡时拖出/投放；缺UID不再进入data.uid读取。item_drag_guard_closeout_test覆盖缺失/错误类型/过期/其他角色数据、暂停/死亡拒绝、revision不变和正常移动至格20通过。closeout-item-drag-guard.log，headless方法级测试；不替代实际鼠标拖动。退出ObjectDB/资源警告仍需追踪。


C08快捷栏数据回归：item_drag_guard_closeout_test扩展SQLite拒写绑定，旧quickbar/items/revision均保留；恢复写入后同次投放重试成功且items完全不变。随后将物品移入仓库，旧拖拽数据无法绑定且revision不变。closeout-item-drag-guard.log退出0；SQL拒写为故障注入预期，本次无对象泄漏警告。该路径实现有效无需改生产代码；为控件方法调用非真实持续鼠标拖动。


C08/C11拆分弹窗输入释放：split_selection_closeout_test新增打开后has_modal为true、成功提交销毁后has_modal为false、物品移走错误后取消销毁且无残留ConfirmationDialog三项断言。自动测试全部通过，closeout-split-selection.log；该路径无须修改共享窗口实现，不代表所有弹窗均已验收。


C08物品使用反馈修复：item_panel使用按钮不再以旧rules.message覆盖gameplay提示；仓库取出仍显示move结果。item_use_feedback_closeout_test按钮信号验证冷却提示保留、拒绝不改变revision、冷却结束成功使用仅减少一份，通过closeout-item-use-feedback.log。初版测试把EditionSkinButton误认Button导致夹具异常，已修正并清理本测试临时库；未产生发布包。


C08使用物品拒绝反馈：use_item_uid对非游戏、死亡、暂停、UID不存在分别返回明确提示，避免静默失败沿用旧成功消息。item_use_feedback_closeout_test扩展暂停/死亡按钮操作、过期UID方法调用，确认提示及revision/数量不变，原冷却/正常使用检查继续通过（closeout-item-use-feedback.log）。非游戏提示已实现但本测试未覆盖。


C08回城物品前置检查：gameplay.use_item_uid在enter_map前拒绝非背包回城物品，避免规则稍后拒绝时已扰动地图/待处理攻击。item_use_feedback_closeout_test新增仓库回城石夹具，验证拒绝提示、revision/数量/玩家坐标/待处理攻击保持，全部断言通过（closeout-item-use-feedback.log）。退出对象释放警告再次出现，未据此断言长期内存稳定。


C11退出警告定位：item_use_feedback与split_selection测试增加WeakRef销毁断言，app与item_panel节点均已释放，功能断言继续通过。use测试仍报4个ObjectDB/2资源，split未报；verbose单次仅StringName遗留。证据排除这两个顶层节点未销毁，未排除其他孤儿资源，也不归因为引擎缺陷。无需为未定位原因改生产清理逻辑，后续需取得具体残留对象类型。


C11退出警告假设排除：尝试将use反馈测试退出延后到run返回后的下一帧，连续3次功能/节点释放断言均通过，但两次仍有资源警告（closeout-use-cleanup.json及三个日志）。因此局部函数尚未返回不是充分解释，已撤回试验性退出改动，未宣称修复。现有测试功能不受此警告影响；资源残留根因仍未定位。


C08自动检查入口：tools/check_item_ui_closeout.py集中运行三项独立隔离库测试，记录退出状态、完成标志、脚本错误与诊断行，45秒超时防断言卡住；--godot支持显式引擎路径。首次执行3/3功能通过，artifacts/item-ui-closeout/report.json保留预期拒写及环境/释放警告。该入口不是整体验收或无警告证明。


C08仓库暂停入口一致性：物品格右键/双击及仓库取出按钮增加暂停拒绝提示，避免与拖拽限制不一致。item_drag_guard_closeout_test新增仓库物品夹具，暂停时右键和取出按钮revision不变，恢复后取出成功。统一入口check_item_ui_closeout.py本轮3/3功能通过，artifacts/item-ui-closeout/report.json；为信号与方法回归，未冒充实体输入验收。


C08暂停操作一致性补齐：item_panel整理、打开拆分和已有拆分弹窗确认增加暂停拒绝；已有弹窗保留以便恢复后重试。split_selection_closeout_test新增三种入口revision不变、暂停不新建弹窗、已开弹窗不销毁断言；恢复后原成功/拒写重试流程通过。统一物品UI检查3/3功能通过，报告仍保留资源诊断，未宣称无警告。


C08任务存取刷新：新增quest_inventory_refresh_closeout_test，准备合法已接鸡肉任务与3份材料，仓库存入后交付按钮禁用/鸡肉0/3；取回后重新可交付，自动回归通过。初版夹具缺novice.patrol被规则拒绝，补全后通过，未修改生产规则；已清理本测试失败临时库。日志closeout-quest-inventory-refresh.log含退出资源警告，未宣称无警告。


C08任务事务回归：鸡肉任务提交注入SQLite拒写，整个state不变；恢复后重试成功，消耗3份鸡肉、增加2份蓝药及档位金币，重复提交state不变；已完成历史页按钮禁用。quest_inventory_refresh_closeout_test通过，closeout-quest-inventory-refresh.log。初版测试误要求默认隐藏完成任务的列表仍停留已完成条目，改为明确打开历史并选该任务，未改生产行为；本次失败临时库已清理。


C08任务按钮边界：quest_inventory_refresh_closeout_test新增暂停与离开村长后的pressed信号，明确提示且revision不变；原材料存取/拒写重试/重复领奖全部通过。纳入check_item_ui_closeout统一入口，当前4/4功能通过；报告保留退出资源警告，无须改动已有效的生产任务检查。


C08商店死亡限制：rules.shop与reference_trade增加死亡拒绝，避免旧页面或其他调用者绕过UI边界。shop_death_guard_closeout_test隔离规则库验证两种入口买/卖均拒绝且整个state不变，恢复生命后普通出售成功；closeout-shop-death-guard.log退出0。NPC入口测试验证死亡前置拦截，不代表活体该NPC商品交易已覆盖。


C08经济规则死亡限制：旧warehouse和通用repair补齐死亡拒绝，与inventory_action/reference_repair一致。shop_death_guard_closeout_test覆盖死亡存/取/两种修理state不变，存活后普通出售、仓库存取往返、无损装备修理可完成。该测试加入统一入口，当前5/5功能通过；受损装备修理计费不由此新用例证明，保留原专项测试。


C08通用修理计费回归：新增耐久60武器夹具，39金币不足以支付40修理费时整个state不变；100金币时注入拒写也不变，恢复写入重试后金币60/耐久100，再修理不重复扣费。shop_death_guard_closeout_test通过（closeout-shop-death-guard.log），无生产逻辑改动；不代表所有NPC分品类报价已覆盖。


C08 NPC修理品类回归：铁匠server:merchant:56的已装备木剑耐久60、女布衣50、背包备用木剑20夹具，报价只包含已装备木剑；修理按报价扣费，仅该武器恢复100，其余耐久不变，再修理无目标拒绝且state不变。shop_death_guard_closeout_test通过，closeout-shop-death-guard.log。该代表商人规则有效，不扩展为逐NPC普查。


C11暂停键输入保护：main暂停分支P恢复增加not typing，避免模态确认或文字焦点绕过后续输入保护。settings_save_closeout_test通过直接未处理事件调用验证modal/LineEdit下保持暂停，释放焦点后P正常恢复；原设置拒写与暂停回归继续通过，closeout-settings-save.log。非实体输入法验收。


C11/C14手柄窗口焦点回归：assist_focus_closeout_test在内挂上方打开手柄面板，同次肩键方法调用只改变上层页；确认框打开后两页不变；关闭上层后肩键恢复内挂切页。原15尺寸/页面组合、焦点和拒写测试仍通过（closeout-assist-focus.log）。共享顶层判断有效无需生产修改；控件事件调用不代表实体手柄验收。


C08自动报告判定加固：统一runner对非预期ERROR判失败，不再只检查SCRIPT ERROR；只读注入仅四个明确测试允许，CA/已记录退出资源提示单列仍保留。tests/release/test_item_ui_runner.py四项通过，覆盖PASS后资源载入错误、非注入用例只读错误和其他SQL错误不误报。新判定运行5/5功能通过；报告新增unexpected_errors，不宣称诊断全清。


C08同名装备实例出售：铁匠测试增加耐久20/90两把背包木剑及已装备木剑；指定20耐久UID出售时拒写整个state不变，重试只移除该实例，其余两件保留；再次使用旧UID拒绝且state不变。shop_death_guard_closeout_test通过，closeout-shop-death-guard.log。该追加用例未单独断言折旧售价，未扩大为全部出售数值已验收。


C08商店库存原子性回归：铁匠木剑剩余1件夹具，拒写购买整个state不变；重试后背包+1、库存0；第59秒售罄购买拒绝且state不变，第60秒按目录补货50再售1余49。shop_death_guard_closeout_test通过，closeout-shop-death-guard.log。时间通过参数推进，非实机等待；代表商品规则检查。


C08满背包购买原子性：48件独立木剑占满背包、等级100避免负重干扰夹具；NPC购买失败整个state不变（含库存/金币/物品），存入一件腾出格后重试成功，背包恢复48格且商店库存仅减1。shop_death_guard_closeout_test通过，closeout-shop-death-guard.log。只覆盖容量边界，负重单独保留规则验证。


C08容量/负重提示：商店用例明确断言满格提示“背包或仓库没有空格”；新增只有1叠药品、有空格但负重达上限夹具，购买木剑拒绝提示“背包负重不足”，整个state不变。shop_death_guard_closeout_test通过；现有生产提示区分正确，无需修改。


C05入口失败状态回归：entry_failure_closeout_test调用认证失败完成路径，验证busy清除、按钮恢复、账号密码输入保留，注册/登录切换按页面重建confirm字段。closeout-entry-failure.log通过；合成失败结果不证明真实密码哈希或线程启动错误路径，未改生产代码。


C05认证线程启动失败：entry.authenticate检查Thread.start返回值，错误时清busy、恢复按钮并显示错误码/重试指引，避免永久等待。entry_failure_closeout_test直接注入ERR_CANT_CREATE恢复方法验证通过；实际OS线程创建失败未人为制造，区分方法回归与系统故障实测。closeout-entry-failure.log。


C05新增待修缺陷：entry_creation_failure_probe使用拒绝世界初始化的Rules测试替身复现：账号角色身份保存成功后attach失败，创建页再次提交同名提示已被使用，无法原地重试初始化。日志closeout-entry-creation-probe.log明确REPRODUCED；这是故障复现不是通过验收。下一步保存待初始化身份并避免再次创建，或实现跨两次写入的原子操作；不删除已有角色绕过。


C05创建初始化重试修复：entry保留当前账号待初始化角色ID和原档位，同一表单重试不重复创建；身份/账号失效清除待处理引用，改名职业性别时提示原身份已保存。连续两次初始化失败后恢复真实attach，角色仍仅1个，切换表单档位也保持原easy，成功转选角并清待处理状态。entry_creation_failure_probe改为回归测试，closeout-entry-creation-retry.log PASS；覆盖同进程重试，不证明退出重启后的待初始化档位恢复。

### 创建角色恢复补充

初始成长档位随角色身份原子保存，缺失世界初始化读取该档位，避免中途失败后重新加载账号变为默认轻松档。创建失败重试及数据库重载断言通过；没有打包、修改用户存档或逐地图检查。测试日志 `artifacts/closeout-entry-creation-retry.log`，保留退出资源警告，实际中断进程恢复未验证。

### 技能页状态同步自动回归

修复技能页常驻时不跟随外部购买技能书、升级、背包学习和当前技能变化的问题。按存档 revision 检测，比较页面相关状态后刷新；金币与熟练度变化不重建控件。新回归 `game/tests2011/skill_panel_refresh_closeout_test.gd` 验证购买、等级按钮、外部学习与无关更新，日志 `artifacts/closeout-skill-panel-refresh.log` 通过。当前技能外部切换的刷新代码已接入，未在该新增用例单独断言。

既有 `skill_bind_failure_test.gd` 重新验证绑定和技能选择拒写不改变内存状态、重试后持久化通过，日志 `artifacts/closeout-skill-bind-failure.log`；只读数据库报错为主动故障注入。两项是隔离存档代码测试，未模拟实体手柄或证明全部施法时序完成。无安装版导出。

### 仓库服务距离收尾

新增 `warehouse_distance_closeout_test.gd`：手柄仓库离开5格、暂停、切图、死亡均拒绝操作，附近存取保持实例ID；方法级自动回归通过。修复区域NPC打开的键鼠仓库未绑定服务对象：每次拖入/拖出、双击/取出及拆分重新检查NPC距离。新增自动断言覆盖远距离双向拖拽拒绝、附近成功；双击与拆分距离分支本轮仅代码检查。日志 `artifacts/closeout-warehouse-distance.log`。

原有五组 `tools/check_item_ui_closeout.py` 全部通过，报告 `artifacts/item-ui-closeout/report.json`，退出资源警告保留。村长、旧室内及通用无参数仓库入口仍未绑定服务对象，需要继续统一；本轮不将所有仓库距离问题标记完成。没有操作用户存档或导出应用。

### 仓库入口绑定补齐

村长、故事任务、室内仓库与旧向导/通用NPC仓库入口均传入服务对象；室内与旧向导捕获打开对话时的地图，避免切图后重新绑定到错误地图。无参数 show_warehouse 拒绝打开且不清除已有绑定，自动断言已通过（`artifacts/closeout-warehouse-distance.log`）。旧布局测试已改为明确服务位置的夹具，故事鼠标测试改为传入实际任务NPC，本轮未重新进行它们的图形操作验收。退出资源警告继续保留。

### 仓库关闭后残留拖拽

已绑定NPC的键鼠仓库操作同时检查“个人仓库”窗口仍存在，阻止关闭窗口后向背包投放旧仓库拖拽数据。`warehouse_distance_closeout_test.gd` 新增关闭→旧数据拒绝且状态不变→重新打开→成功取回断言通过；日志 `artifacts/closeout-warehouse-distance.log`。这是方法级拖拽数据回归，不代替真实鼠标持续拖动。此次退出日志未出现资源残留警告，但此前间歇性问题仍未证明解决。

### 手柄仓库旧回调失效

`controller_warehouse.operate` 拒绝已离开场景树或等待销毁的面板。仓库回归改用真实窗口管理器承载面板，新增关闭后调用旧操作、创建同名新窗口后调用旧操作均不改变物品状态的断言，四项PASS，日志 `artifacts/closeout-warehouse-distance.log`。未进行实体手柄验收，没有打包。

### 页面回归统一执行

`tools/check_item_ui_closeout.py --suite pages` 现纳入入口/创建恢复、技能页/技能保存、仓库生命周期，共5项通过；工具单元测试6项通过。支持 items/pages/all，默认保留原items行为。报告独立记录资源退出警告，未知错误、缺标志和超时不放行。证据 `artifacts/ui-closeout-pages/report.json`；不替代剩余实机验收。

### 跨角色药品冷却和界面状态

修复共用 gameplay.potion_ready 以不同角色游戏时间比较造成长时间无法喝药：切换不同角色时清理药品冷却、待拾取、拾取重试和自动辅助临时状态；进入角色清除旧窗口、物品选择和仓库绑定。重进同一角色保留当前药品冷却。`character_switch_closeout_test.gd` 验证跨角色可喝药、同角色仍拒绝冷却中使用，日志 `artifacts/closeout-character-switch.log` 通过。已纳入 pages（现在6项，all为11项）；本轮单独运行新增测试及6项工具单测，未宣称扩展整套已重跑。

### 11组操作回归整合验证

跨角色时重置攻击间隔、AI/保存计时与旧提示；新增断言验证待命中攻击和延迟法术事件在角色进入后清空。`python3 tools/check_item_ui_closeout.py --suite all` 本轮11/11功能通过，报告 `artifacts/ui-closeout-all/report.json`。部分退出资源警告仍存在，未标记稳定性或实机验收完成；未导出安装版。

### 退出资源残留定位到音频

详细日志3次采样中2次复现：残留 `AudioStreamPlaybackWAV` 与 `AudioStreamWAV`，资源为 field2.wav 和108.wav，证据 `artifacts/closeout-item-exit-samples.json` 及对应详细日志。主脚本 _exit_tree 已有 stop、stream=null、sounds.clear，不能以增加同样清理作为修复。新增独立 `audio_shutdown_probe.gd`（不载入游戏/SQLite），音频播放后停止释放3次均未复现，记录 `artifacts/closeout-audio-only.json`。目前只能定位音频对象，尚不能断言引擎问题或游戏音频生命周期根因；没有将此问题标记解决。

### 音频释放顺序对照

独立音频诊断改用父节点持有播放器，对照提前stop与父_exit_tree内stop，各3次；再增加0.1秒播放等待，各3次，两组均未复现音频对象残留。记录 `artifacts/closeout-audio-order.json`、`artifacts/closeout-audio-active.json`。这只说明最小条件下未复现，不足以证明退出顺序无关，也不证明修复。未修改生产音频退出代码；后续应从游戏内音频生命周期交互继续定位，避免无依据增加等待。

### 静音恢复不重放过期短音效

修复设置静音时暂停短音效、解除静音后重放旧攻击/物品声音的问题：短音效停止并释放播放器stream，音乐保留暂停语义。提取 toggle_mute 统一持久化成功后变更状态。`mute_feedback_closeout_test.gd` 验证拒写不变、重试保存、静音期间不播放、恢复不重放旧音效以及新音效可发起，日志 `artifacts/closeout-mute-feedback.log` 通过；数据库只读报错为故障注入。未做实际听音，不将此独立行为修复描述为退出资源残留修复。本轮未打包。

### 静音切换音乐回归

扩展静音测试验证静音期间设置field2.wav时不播放，解除静音后播放当前曲目而非上一曲；音频播放器状态断言通过，未实际听音。该测试加入pages（7组）和all（12组），只读故障注入仅对此明确用例放行，其他未知错误仍失败。新增测试和6项运行器单测通过，日志 `artifacts/closeout-mute-feedback.log`；扩展后的整套尚未重跑。

### 故事任务筛选状态回归

新增 `story_filter_closeout_test.gd`，用隔离状态夹具验证可接取任务接受后退出可接取列表、进入当前任务、完成后退出当前列表，以及已完成归档仅含完成任务。面板revision自动刷新断言通过，日志 `artifacts/closeout-story-filter.log`。本轮未发现该筛选链路缺陷，未改生产代码；任务接取/交付本身采用状态夹具，不能据此声称实际奖励结算或全部任务流程通过。

### 角色切换取消旧确认框

修复 close_all 只关闭普通窗口、保留通用确认回调的问题：统一隐藏modal并断开旧confirmed处理。角色切换回归新增旧确认不执行、新确认可正常执行断言通过，证据 `artifacts/closeout-character-switch.log`；设置保存/焦点暂停/P拦截既有测试也通过 `artifacts/closeout-settings-save.log`（主动只读故障注入保留）。不以回调测试替代真实任务放弃流程或实机输入。

### 取消确认立即释放回调

通用确认框 canceled 事件立即断开旧confirmed回调，避免等待下次打开才清除闭包引用。设置回归新增取消后直接触发confirmed不执行操作、确认连接为空、新确认仍正常的断言，连同原暂停/保存回退用例通过，日志 `artifacts/closeout-settings-save.log`。这是取消事件测试，未声称实际Esc按键验收或解决音频残留。

### 通用窗口按钮生命周期保护

main.button生成的按钮在回调入口拒绝离开场景树、等待销毁或禁用状态，避免关闭/换角色后的旧按钮继续执行。角色切换回归增加正常按钮可执行、禁用不执行、切换后旧按钮不执行的断言，通过 `artifacts/closeout-character-switch.log`。覆盖该通用按钮工厂，不声称其他独立控件全部已审计。

### 任务技能共用按钮保护

journal_layout.action拒绝禁用、离开场景树和等待销毁按钮的回调；避免页面refresh移除旧控件后旧回调仍执行。故事筛选测试新增有效/禁用/刷新后旧按钮断言通过，技能面板刷新回归同时通过。证据 `artifacts/closeout-story-filter.log` 与 `artifacts/closeout-skill-panel-refresh.log`，不代表物理快速点击压力验收。

### 精神力战法说明准确刷新

技能页当前准确展示加入刷新依赖，仅选中spirit时计算。新增装备准确加成/装备耐久归零状态夹具验证说明更新，`artifacts/closeout-skill-panel-refresh.log` 两项PASS，完成标志加入统一运行器。夹具直接准备装备状态，不代表实际穿戴输入或全部装备规则验收。

### 手柄仓库弹窗与遮挡输入

新增确认框下A/肩键/B不操作仓库、不切页、不关底层窗口，以及被另一窗口遮挡时不切页、移除遮挡后肩键恢复的事件方法回归，全部通过。完成标志加入统一运行器，日志 `artifacts/closeout-warehouse-distance.log`。本轮有9个ObjectDB和3个资源退出警告，不能据此声明清洁退出或实体手柄验收通过；未改生产输入逻辑。

### 手柄物品旧列表校验

controller_panel执行使用/绑定/脱装前重新核对实例所在容器，旧列表引用已移走物品时显示原因并刷新，离开场景树的面板拒绝操作。新增 `controller_stale_item_closeout_test.gd` 验证移入仓库后的旧行无法使用或绑定，关闭面板旧操作不改变状态，日志 `artifacts/closeout-controller-stale-item.log` 通过。未进行物理手柄测试。

### 手柄选择保持实例

物品列表前一行移入仓库后，所选物品从索引1移动到0，刷新仍保留同一UID和ItemList选择，新增断言通过。`controller_stale_item_closeout_test.gd` 两项PASS，加入pages（8组）/all（13组）；扩展整套本轮未重跑。日志 `artifacts/closeout-controller-stale-item.log` 有退出资源警告，实体手柄与稳定性仍未验收。

### 手柄面板统一操作入口弹窗保护

controller_panel与controller_warehouse的operate入口补充游戏模式/模态检查，防止列表激活或直接回调绕过_input中的弹窗判断。新增模态期间item_activated、绑定和仓库存取不改变状态的断言，两份既有手柄回归通过。证据 `artifacts/closeout-controller-stale-item.log`、`artifacts/closeout-warehouse-distance.log`，未做实际鼠标双击或实体手柄验收。

### 手柄任务操作生命周期

controller_npc.operate补充模态、游戏模式和场景树检查。新增任务面板在确认框覆盖及关闭后调用operate不改变规则状态的断言，通过 `artifacts/closeout-controller-stale-item.log`，完成标志纳入统一运行器。未将此回调保护当成完整任务实机验收。

### 任务放弃确认时重新校验

故事面板确认放弃时重新检查暂停与面板存活；手柄任务finish_abandon检查面板存活，A/B改为发出通用confirmed/canceled事件，统一释放回调。故事筛选新增确认后暂停保留任务断言通过；controller_abandon既有15项事件回归通过，含取消、确认、焦点替换、拒写重试。证据 `artifacts/closeout-story-filter.log`、`artifacts/closeout-controller-abandon.log`。后者是Viewport事件模拟，实体手柄未测；只读错误为故障注入。

### 任务放弃完整事务回归

故事面板回调保护后，story_abandon_test的14项通过：确认/取消、拒写保留进度与追踪、成功仅清理对应任务、重新接取进度归零、死亡和已完成任务拒绝放弃，财富物品技能保持。日志 `artifacts/closeout-story-abandon.log`、报告 `artifacts/world-story/abandon-tests.json`。日志旧scope写native mouse，但本次实际是headless下Viewport合成鼠标事件；已更正测试源码与报告描述。补测试自身SQLite清理，不删除其他存档。

### 返回选角保存失败回归

新增logout_failure_closeout_test，经过HUD返回选角确认回调，SQLite拒写时保持游戏模式与完整规则状态并显示错误；恢复写入后重试保存世界并进入roster，断言通过。日志 `artifacts/closeout-logout-failure.log`。本轮未发现该路径缺陷，未改生产代码；这是方法/确认信号测试，不是原生关闭窗口或实际退出进程测试。

### 返回选角备份失败

扩展logout_failure_closeout_test：在本次随机测试库备份临时路径创建目录，真实触发VACUUM备份失败；验证主世界写入仍可读、界面停留游戏并提示，移除本次障碍后重试返回选角成功。`artifacts/closeout-logout-failure.log` 两项PASS，预期只读及备份路径错误保留；退出资源警告仍有。测试障碍已清理，不涉及用户存档。

### 备份重试错误状态

backup与其他Store操作保持一致，在开始时清理上次error，失败写入新原因。修复独立备份重试成功仍保留旧错误的状态。logout_failure回归增加真实备份失败后直接重试成功且error为空的断言，通过 `artifacts/closeout-logout-failure.log`。

### 开发启动器命令回归

确认固定macOS command直接以--path启动源码。跨平台run_dev新增命令组装测试，覆盖含空格/中文的引擎与日志路径、参数列表传递、返回码保留、显式MAFA_PYTHON保留及本地Python缺失回退。test_dev_launcher共4项通过；subprocess使用mock，三平台引擎查找使用夹具，不代表Windows/Linux实际启动验收。没有启动安装版或执行导出。

### 启动器执行失败提示

run_dev捕获启动进程的OSError，显示具体引擎路径、系统原因和权限/GODOT配置提示并返回1，避免仅抛Python栈。新增权限不足、引擎查找后消失的mock测试，启动器共5项通过。固定macOS command未改，未安装/打包，跨平台实机仍未验收。

### 源码交付遗漏修复

发布源码白名单补入 tools/check_item_ui_closeout.py，避免带上测试却遗漏其运行器依赖。白名单回归通过（同时审计原素材/存档排除）；项目venv下导入失败8项测试通过。首次系统python因缺numpy未加载测试，改用项目既有venv后通过，未安装新依赖。只修改交付清单，没有打包或发布。

### 开发回归说明同步

README加入items/pages/all命令、引擎路径、资源前置条件、隔离存档、报告位置、退出警告与实机验收区别，并明确导入测试使用同一依赖环境。源码白名单测试通过；未执行发布。

### 删除记录完整性校验

账号valid_db将archived条目纳入字段、职业性别、成长档位与全局角色ID唯一性检查；仅在用角色限制同名，保留正常删除后新建同名行为。归档缺字段、与在用ID重复拒绝；已有恢复/同名/槽位事务回归均通过，日志 `artifacts/closeout-character-restore.log`。未迁移或覆盖用户存档。

### 缓存异常回归复核

项目venv执行cache_integrity 9项、supplement_integrity 7项全部通过：地图夹具截断/维度/通行/重复ID、原DOS短名、包哈希变化/帧越界、补充图片解码尺寸与校验失败保留现有缓存。范围为临时夹具，不是707地图扫描，不修改原客户端或运行缓存；C03仍在进行中。

### 缓存校验重试状态

补充素材测试新增缓存校验先失败后成功的状态回归：旧error被ready与当前root替换、无残留临时状态文件、原缓存标记不变。supplement_integrity共8项通过；验证器结果采用mock以隔离状态上报行为，不代替真实全量缓存检查。

### 导入路径大小写兼容

importer测试扩展真实中文空格临时目录查找和大小写重复条目拒绝（后者mock大小写敏感目录枚举），共7项通过。仅证明路径函数与配置/库存在检查，不代表Windows/Linux实际素材导入。没有改动客户端目录。

### SQLite中断金币物品一致性

扩展test_sqlite_interruption，在独立Python子进程世界行写入后、操作记录写入后、COMMIT后真实kill，重开临时数据库核对integrity_check、revision、金币、物品UID/数量与提交记录。三个边界全部通过：未提交全回退，已提交全保留。使用与Store相同事务形状的SQL夹具，不是Godot崩溃或断电测试；不影响用户数据库。

### 操作页面统一回归扩展至16组

将故事筛选/暂停后放弃保护、修理拒写与重试扣费纳入all入口，16/16功能通过，运行器6项单测通过。报告artifacts/ui-closeout-all/report.json；退出资源警告用例：item_drag_guard_closeout_test, item_use_feedback_closeout_test, repair_feedback_closeout_test, story_filter_closeout_test, skill_panel_refresh_closeout_test。更新UI_ACCEPTANCE当前速览，保留历史记录；不代表真实手柄、听音或稳定性完成。未导出应用或操作用户存档。

### 音频退出时序对照（尚未修复）

修理回归verbose复现field2.wav与106.wav各一组AudioStreamWAV/PlaybackWAV残留（artifacts/closeout-repair-audio-detail.log）。同一测试新增仅诊断参数--settle-audio，在销毁应用前等待0.1秒，一次对照无残留（artifacts/closeout-repair-settle-audio.log）；默认用例仍保持原退出流程，不用等待掩盖统一回归警告。最小audio_shutdown_probe新增--same-frame一次未复现（artifacts/closeout-audio-same-frame.log）。证据仅提示完整场景退出时序相关，不能确认根因、真实运行泄漏或稳定修复。下一步需要区分音频混音更新与场景清理时序；未改生产逻辑。

### 统一退出前停止音频

修理场景对照新增2组默认退出（1组残留）及2组提前stop（均无残留），见artifacts/closeout-repair-stop-comparison.json；另一次提前stop也无残留。main新增stop_audio与quit_application，所有主脚本quit调用在退出请求前停止并清空播放器及缓存；_exit_tree保留兜底。没有加入等待或改变存档失败返回路径。修理测试--stop-audio调用正式helper并断言stream为空/缓存清空，本次无残留（artifacts/closeout-repair-audio-helper.log）。返回选角拒写/备份失败/重试通过（artifacts/closeout-logout-audio-closeout.log，预期故障注入报错）。这证明提前停止路径可工作，不证明间歇问题彻底修复；直接queue_free的统一测试仍不改动，真实应用退出与长时稳定性待核验。

### 实际quit调用的窗口关闭回归

新增window_close_audio_closeout_test：调用主脚本WM_CLOSE通知处理方法（非OS鼠标），真实query_only拒写后仍在游戏、状态与音乐保留；重试经正式quit_application调用SceneTree.quit，断言主库关闭、重新打开有世界与备份、播放器stream及缓存已清空。两个功能标志通过，但进程退出仍残留field2.wav与106.wav播放资源，证据artifacts/closeout-window-close-audio.log。这进一步证明提前stop不能视为彻底修复；C15继续未完成。用例加入pages/all，all现17组；此次仅新增用例与运行器单测执行，未声称17组全跑。临时数据库清理，用户存档未访问。

### 独立引擎音频路径复现

无游戏场景/客户端素材/存档的audio_engine_exit_probe在当前4.7.2生成音频后stop并清空，退出仍有AudioStreamGeneratorPlayback残留。详见release/AUDIO_EXIT_DIAGNOSIS.md与artifacts/closeout-engine-audio-exit.log；上游#76745及候选#122742作为机制依据，尚未应用或验证修复。保持警告可见，不宣称稳定性通过；后续继续其他收尾，避免没有新证据的UI释放反复改动。

### 修理与合成旧窗口回调保护

controller_repair/controller_crafting输入入口补场景树及待删除检查，防止关闭后同名窗口重开时，旧实例仍接受延迟/直接输入回调。repair_feedback扩展已损坏装备fixture验证旧修理回调不扣金币或修复；旧合成确认保持phase与状态。3个PASS，日志artifacts/closeout-repair-stale.log；运行器6项单测通过，标志纳入统一套件。本次为输入方法回归，不证明物理手柄或完整合成规则；未打包。

### 源码交付路径核验

source_files.audit补充拒绝符号链接文件与经父目录链接解析到项目外的路径，覆盖exact名单原先未检查的分支。当前源码清单838项通过，publication三项测试通过（真实临时链接夹具，不接触外部用户文件）。本次没有发现现有清单实际外链泄露，不宣称历史Git内容审计完成；没有暂存、发布或打包。

### 手柄任务返回按任务ID恢复

发现任务关系导航历史仅存cursor索引，返回时列表重排/任务消失会打开另一条详情。历史改为同时保存selected_id，back按ID定位；原任务已不可见则留在列表，不打开替代任务。controller_stale_item回归用历史索引999及缺失ID夹具分别验证身份恢复、缺失不打开详情，4个功能标志通过，日志artifacts/closeout-task-history.log；运行器6项单测通过。退出资源警告仍保留。该项验证返回方法与身份规则，非实际手柄完整导航。

### 合成任务服务返回回归

controller_crafting_test按当前代码完成16项，无失败：任务接取、7配方导航、预览材料、取消、来源、报价过期拒绝、暂停拒绝、拒写保留、成功一次扣费、返回原任务列表/详情及交付不消耗成品。日志artifacts/closeout-crafting-navigation.log，报告artifacts/world-story/controller-crafting-tests.json。本次headless通过Viewport注入按键，不是实体手柄；800×600仅矩形边界断言。测试改为headless不生成截图（避免将无绘制结果当视觉证据），并清理自身随机SQLite。现有人工图像未覆盖。未改生产功能、未打包。

### 当前17组回归与清单同步

统一all 17/17功能通过，资源退出警告用例：quest_inventory_refresh_closeout_test, skill_panel_refresh_closeout_test。同步UI_ACCEPTANCE速览与closeout-tasks最新统一报告、C04/C13/C14/C17/C18证据；未提升任何未完成状态，硬件/三平台/长时测试仍待验收。

### 启动导入错误提示兜底

bootstrap错误报告不再直接访问缺失message；缺失/null/空白文字显示明确重试提示，正常错误原样展示。import_error_feedback_closeout_test四种临时状态文件夹具通过，重试按钮恢复、pid复位；没有实际启动导入进程，非真实鼠标验收。日志artifacts/closeout-import-feedback.log，加入统一入口现18组，尚未整套重跑。

### 启动资源配置类型检查

bootstrap在读取配置失败或root非字符串时显示恢复页面，保留原配置而非类型赋值报错。import_error_feedback新增数字/数组/字典路径夹具，通过真实_ready验证未启动、按钮可用、错误明确、文件字节不变。日志artifacts/closeout-import-feedback.log两项PASS。初始null夹具因ConfigFile把null作为删除键而断言失败，移除该无效夹具，清理本次失败临时目录；不是生产修复失败。新标志加入统一回归。

### 错误资源路径恢复保存

import_error_feedback在数字/数组/字典路径错误后调用正式save_and_launch保存替换路径，重新读取临时配置验证新路径与future字段42均保留，launch仅记录不启动。3个PASS，日志artifacts/closeout-import-feedback.log；运行器6项通过。验证范围是校验后的配置保存步骤，不是实际目录选择或完整导入。未修改生产逻辑。

### 发布底座47项与本机启动链路

当前tests/release 47项全通过，日志artifacts/closeout-release-regression.log，覆盖导入/缓存/补充资源/启动器/源码边界/回归运行器/SQLite中断。另通过tools/run_dev.py真实启动本机Godot执行import_error_feedback三个标志，通过artifacts/closeout-launcher-startup-regression.log；没有启动真实游戏或做Windows/Linux硬件验收。同步机器任务证据，不提升完成状态，不打包。

### 设置滑块关闭保护

设置页音量value_changed加入场景树/待删除检查，阻止关闭窗口后的旧滑块信号继续修改音量与元数据。settings_save_closeout新增关闭后更改旧滑块断言，原有拒写回退、缩放保存、提示位置及暂停焦点检查仍通过（artifacts/closeout-settings-stale.log）。6条SQLite readonly为主动注入，未做实际听音或物理输入；未打包。

### 背包拆分关闭保护

split_prompt及确认回调补面板/弹窗场景树检查，防止父窗口移除但子确认框未释放时继续拆分。split_selection新增把面板移出场景后确认及重开请求均不改变状态的断言，原数量/实例/拒写重试/重复确认/物品移位/模态释放仍通过。日志artifacts/closeout-split-detached.log，3个PASS；运行器6项通过。仅生命周期方法回归，未声称真实鼠标关闭验证。

### 背包其余按钮关闭保护

整理/使用/翻页/关闭回调加入面板场景树检查。拆分回归扩展面板移除后触发整理、使用、翻页，规则状态/页码/提示保持，四个PASS；日志artifacts/closeout-item-lifecycle.log。运行器6项通过，新标志纳入统一入口。仅回调生命周期验证，未打包或操作用户存档。

### 素材与音频公开边界整理

核对PNG解码报告、finish-fallbacks和SKILL_AUDIO_SOURCE_EVIDENCE后新增release/ASSET_ACCEPTANCE_LIMITS.md，明确可读性不等于视觉还原、替代素材不代表历史外形、缺阶段声音不能推断刻意静音。README链接该说明并去除全地图视觉普查要求，改为操作页和代表场景。未修改素材或提升验收状态。

### 回归证据源码摘要

运行器加入UTC起止时间、各进程引擎banner、脚本/内容JSON/主场景/project配置/运行器SHA256，前后摘要不同则总返回失败。限定范围不含原素材和原生插件，不能作完整构建指纹。当前18/18功能通过且摘要未变化；运行器7项单测通过，包括脚本编辑与删除摘要变化。报告与任务速览已同步；资源退出警告保留，未做实机验收或发布。

### 回归工具引擎启动失败报告

捕获子进程启动OSError，写入launch_error及具体错误日志、functional_pass=false并返回失败。运行器8项单测通过，其中mock PermissionError验证覆盖旧成功报告而非保留误导状态。此为运行器错误处理验证，非实际Windows权限测试；引擎路径参数不存在仍由argparse提前拒绝。未重复整套游戏测试或打包。

### 物品格动作前校验位置

item_slot点击/右键双击/拖拽起点新增实时UID容器格子校验，拒绝刷新前旧引用操作已移位物品。item_drag_guard新增仓库物品移出后旧格点击和拖拽无效断言，两个PASS，日志artifacts/closeout-item-cell-stale.log；运行器8项通过。原快捷栏拒写重试与仓库暂停检查保留。退出资源警告仍在，不代表实体鼠标验收。

### 拖拽落点生命周期

item_slot与quick_slot的_can_drop_data拒绝已脱离场景/待释放的控件，_drop_data复用检查。item_drag_guard移除落点后分别调用can_drop/drop，确认不移动物品或绑定快捷栏；3标志通过artifacts/closeout-drop-lifecycle.log，运行器8项通过。资源退出警告保留；非实际鼠标拖拽验收。

### 物品格保护后整套复核

当前all18/18通过，含近距离正常仓库存取、快捷栏绑定拒写重试、使用物品和失效格保护，源码摘要前后一致。report.json及UI速览/任务摘要已同步。音频退出警告仍保留，不推断真实鼠标与稳定性完成。未打包。

### 死亡物品操作回归

扩展death_return_test：死亡期间use/split/move/drop/sort/bind及gameplay.use_item_uid拒绝且全状态不变；原30秒等待、暂停、拒写重试、复活位置生命同步保存和重载保留。17项通过，artifacts/closeout-death-items.log。清理测试自身随机SQLite；未改正式规则或做实机验收。

### 死亡面板保存失败反馈

死亡页增加独立自动换行错误Label，返回选角保存失败时直接显示在灰色遮罩上方，不只写底层HUD。回调拒绝已释放死亡层。death_return_test拒写点击返回按钮验证死亡状态保留及Label具体文案，连同原复活/物品保护19项通过（artifacts/closeout-death-feedback.log）。为headless节点文案验证，视觉布局尚未实机核验；未打包。

### 死亡提示最小窗口尺寸

死亡回归新增800×600长错误文案的容器尺寸检查，面板位于窗口内且错误Label在面板内；21项通过artifacts/closeout-death-layout.log。该结果只证明headless布局矩形，不代表字体渲染/灰度遮罩/实际操作已验收。没有改生产代码或打包。

### 死亡面板原生渲染检查

新增可选--capture-death，仅非headless时截图。原生Godot执行21项通过（artifacts/closeout-death-render.log），人工查看artifacts/closeout-death-feedback-800.png：800×600中文长错误提示在按钮下完整两行、未超窗且位于灰色遮罩上方。测试隐藏世界地图，灰度地图外观和真实操作未验收。首次沙箱原生启动退出134无日志，随后获执行权限启动成功；未改变用户存档或导出应用。

### 死亡继续按钮取消旧确认

继续倒计时不再仅hide通用确认框，而是发出canceled以断开旧confirmed回调；死亡页按钮绑定创建时的死亡层，旧层按钮不作用于后来新建层。death_return_test新增继续后再次confirmed不执行旧操作断言，22项通过artifacts/closeout-death-modal.log。代码回调测试，非实际鼠标验收；未打包。

### 窗口位置元数据校验

窗口恢复坐标先验证两项为有限数值；错误类型回退默认位置，旧像素坐标转换Vector2前限幅，归一化锚点夹到0..1，避免极大浮点溢出。window_position_closeout覆盖7种正常/错误/极端保存值×3次窗口尺寸与各次关闭重开，全通过artifacts/closeout-window-malformed.log。仅headless矩形布局检查，非实体拖动；不改用户存档。

### 窗口位置写入失败反馈

窗口关闭仍正常执行，但put_metadata失败会通过pending_message说明位置未保存。window_position_closeout注入query_only确认窗口关闭、旧位置元数据不变、错误提示明确；恢复可写重新关闭后新锚点保存。原异常位置/尺寸检查仍通过artifacts/closeout-window-save-feedback.log。非真实磁盘故障或物理拖动，未打包。

### 位置保存重试提示

错误提示包含窗口名称；同一窗口重试成功且仍显示该错误时替换为已保存，不覆盖无关操作提示。window_position_closeout新增成功反馈断言通过artifacts/closeout-window-retry-message.log，保留异常坐标与尺寸回归。未打包。

### 错误位置使用面板默认布局

错误数组/字典位置现在与缺省记录一样使用冒险面板y24起点，保留reserved_bottom。window_position回归在首帧布局前断言错误记录默认起点，原尺寸/重开/拒写重试均通过artifacts/closeout-window-default.log。未进行实机拖动或打包。

### 窗口修改后的设置联动复核

当前settings_save_closeout通过，覆盖设置保存拒写回退与重试、底部提示尺寸、关闭恢复暂停、模态确认释放、P与文本焦点、旧滑块。日志artifacts/closeout-window-settings-regression.log。同步C10/C11最近证据，不提升实机完成状态；未打包。

### 实体手柄条件核实

原生macOS运行controller_device_probe，当前Input.get_connected_joypads为空；artifacts/closeout-controller-devices.json与.log保留。未模拟手柄或声称实体测试通过，已异步询问可用设备/跨平台环境。其他代码与Mac检查可继续，整体目标不标记阻塞。

### 开发测试素材路径说明纠正

核对EditionResources静态BASE及回归直接实例化edition2011场景，确认回归不走bootstrap外部缓存配置。README明确当前game/assets/client2011及supplement16开发路径/本地链接要求，正式游戏外部导入行为不变。回归运行器独立外部缓存参数尚未提供，记录为开发可复现性缺口，不宣称仅配置resources.cfg就能运行所有测试；没有创建链接或复制素材。

### 回归外部缓存参数已接入

check_item_ui_closeout新增--asset-root：临时GDScript继承原测试并在_initialize前设置EditionResources基础/补充路径，调用原初始化，结束自动清理入口。使用.cache/frozen-import-test/generation-bb7a7704f2c94b859dc22fc4db348cd2真实外部缓存18/18通过，报告记录asset_root，源码摘要未变化；运行器8项单测通过。README与当前报告已更新，关闭前述运行器无外部缓存参数缺口；不证明新机器完整导入/WindowsLinux实机已完成。未复制素材或打包。

### 回归日志固定UTF-8

子进程stdout/stderr解码与日志/JSON写入显式使用UTF-8，避免依赖Windows系统代码页。运行器9项测试通过，新增模拟中文输出验证解码参数与落盘UTF-8字节；这是编码单测，非Windows/Linux实机验收。未重复整套游戏测试或打包。

### 文本编辑时手柄按钮隔离

通用按钮导航在LineEdit/TextEdit聚焦时不以A提交首按钮或以DPad抢焦点，B仍允许关闭。行会公告回归新增直接Joypad输入方法断言，连同保存/拒写/取消/持久化22项通过artifacts/closeout-guild-text-focus.log；原鼠标为Viewport合成、文字直接赋值，非IME/实体手柄验收。补测试自身临时数据库清理，未打包。

### 聚焦文本框时手柄B返回

行会公告回归增加TextEdit聚焦、草稿未保存时经Viewport注入B按下/释放，确认关闭编辑页且规则状态不变；23项通过artifacts/closeout-guild-back.log。验证合成事件分发，不是实体手柄；未改正式代码或打包。


### 操作页面自动回归汇总（2026-09-13，21 组）

按用户要求，收尾以代码检查、无界面回归和异常注入为主，不逐张检查全部地图。统一入口 `tools/check_item_ui_closeout.py --suite all` 已纳入死亡返回、行会公告及窗口位置恢复检查，使用外部转换缓存运行，21/21 组功能检查通过；源码指纹在运行前后保持一致。完整记录见 `artifacts/ui-closeout-all/report.json`。

本轮修复覆盖窗口位置异常数据与保存失败反馈、关闭面板后的旧回调、物品移动后的失效格子、死亡页面保存错误显示与确认框清理、文字编辑时手柄焦点保护，以及资源导入配置错误提示。自动回归不等于真实鼠标拖动、输入法、实体手柄或画面和音效验收；仅对这些无法靠代码充分确认的部分保留专项实测。四组检查仍出现退出资源释放警告，功能通过不代表该警告已解决，也不代表两小时稳定性或 Windows/Linux 运行验收通过。


### 同名窗口快速重开保护

修复旧窗口延迟关闭事件误关新窗口的问题：窗口管理器按实际实例校验关闭和置顶事件；已排队释放的窗口不再响应手柄输入。`window_position_closeout_test.gd` 在同一帧关闭并重新打开冒险面板，触发旧窗口关闭信号及 B 键处理，确认新窗口仍存在。统一 21 组回归通过，源码指纹前后一致；这是程序化生命周期检查，不是实体手柄验收。最新结果以 `artifacts/ui-closeout-all/report.json` 为准，退出资源警告仍单独保留。


### 快捷栏存档结构校验

已有 quickbar 字段现在校验六个槽位、字符串类型及有效物品 ID，防止损坏绑定进入 HUD 后越界或类型错误。字段缺失的历史兼容行为保持不变。新增隔离 SQLite 检查覆盖 null、字典、字符串、空数组、短数组、非文字槽位和未知物品 ID：加载拒绝后数据库内容保持不变，恢复有效绑定后角色正常进入，物品与金币保持一致。测试初版的存档版本冲突及 JSON 数字类型比较问题已修正，失败测试的独立临时库已清理。最新统一回归 22/22 功能通过，运行器自身 9 项检查通过；退出资源释放警告仍保留，非三平台或实体输入验收。证据：artifacts/ui-closeout-all/report.json。


### 缺失快捷栏字段的旧存档兼容

修复已有物品实例但没有 quickbar 字段时，栏位显示为空、数字键使用默认药水且重新绑定报错的不一致。显示和使用现在共享默认六格绑定；绑定操作在规则层副本中创建该字段，保存失败不修改内存原状态。新增旧存档加载、只读保存回滚、重试绑定、重载绑定及物品守恒检查。统一 22/22 组功能回归通过，运行器 9 项检查通过；源码指纹前后一致，退出资源警告仍按报告单独保留。未操作用户存档，未打包。


### 背包与仓库满容量检查

新增隔离 SQLite 回归：背包 48 格、仓库 50 格占满时，拆分明确失败且内存状态、持久化物品保持不变；移走一个完整实例腾出格子后拆分成功，源实例和物品总量守恒。该检查未发现需要修改的运行时代码。本测试不覆盖堆叠上限合并或真实拖拽。初始夹具超过单容器同类物品总量限制、序列化比较受数字类型影响，已修正；独立失败临时库已清理。统一 23/23 组功能通过，运行器 9 项通过；退出资源警告仍单独记录，不等同于稳定性验收。


### 当前源码与本地 Git 历史边界复核

`source_files.py` 当前允许清单843项通过。`audit_git_history.py --output artifacts/closeout-git-history-current.json` 完成4个本地可达提交、270个blob检查，0发现；覆盖禁止路径/扩展名及SQLite、WAV、M211文件头。它不验证远端不可达对象、秘密信息、改名图片来源或许可证。C04保持进行中，正式归档及人工来源检查尚未完成。本轮没有暂存、提交、推送、改写历史或打包。


### 宣传与下载说明的证据范围

首页新增已发布预览版与当前未打包源码的明确区分。宣传文章与哔哩哔哩 HTML 补充实体手柄、两小时前台稳定性待验收说明；HTML可见正文和复制payload同步更新，6处内嵌图片数据未变。证据：artifacts/closeout-article-consistency.json。仅本地文案修改，没有重新打包或对外发布，未重新执行浏览器复制动作。C17仍进行中。


### RSS采样失败不再当作进程结束

`tools/sample_process.py` 现在对ps非正常错误及异常输出报错退出，仅无匹配PID或僵尸状态视为进程终止。修复权限不足时静默结束CSV的误判；输出使用UTF-8及CSV换行，自动创建输出父目录。新增3项模拟测试通过，未将其作为真实RSS或两小时前台测试证据。C15保持进行中。


### 有效游玩时长不补算恢复间隔

性能记录器仅在相邻采样帧均为前台未暂停游戏时累计有效时间，失焦通知清除连续状态，避免恢复第一帧补算等待间隔。专用Godot测试验证无界面时间为零、恢复间隔排除和失焦通知清除；日志artifacts/closeout-performance-recorder.log。没有运行两小时前台验收；本次只改记录器及专用测试，未重新运行页面全套回归。


### 导入状态损坏与真实子进程退出

新增真实短命子进程检查：Godot --headless --version退出后，状态文件缺失、截断JSON、数组格式均恢复选择按钮并提示未完成。发现并修复bootstrap使用JSON.parse_string读取截断状态导致错误日志的问题，改为检查JSON.parse返回值。18组pages回归通过，证据artifacts/ui-closeout-pages/report.json；本轮未重跑items组，不声称完整转换器强制中断或多应用实测通过。


### 原生注册入口专项复核

通过computer-use读取当前原生隔离开发窗口，实际点击新用户后注册页面显示；保存artifacts/closeout-native-registration-current.png，指针日志closeout-native-input-current.log。窗口关闭按钮正常结束进程（0）。只证明当前入口页面切换和显示，不代表注册输入、六职业性别流程、输入法或拖拽完成。未提交账号或使用用户存档，未打包。


### 入口旧控件回调保护

登录/注册输入框和按钮现在检查节点在树中、未等待释放及可操作状态。防止切页后的旧提交回调作用于新页面；禁用按钮及不可编辑输入框也不接受直接回调。entry_failure_closeout_test验证旧注册按钮、旧输入提交及禁用控件不改变当前登录页。18组pages、运行器9项通过，未重复items组。未更改注册布局，未打包。


### Python交付相关检查汇总

当前 `.cache/venv/bin/python -m unittest discover -s tests/release` 共53项通过，日志artifacts/closeout-release-regression.log。覆盖导入/缓存夹具、SQLite中断事务、源码发布边界、开发启动器、回归运行器和进程采样错误判定。包含模拟调用与隔离数据，不作为完整客户端中断、Windows/Linux图形实机或性能验收。入口认证回调代码本轮未发现新增缺陷，未修改运行时逻辑。


### 当前音频目录完整性复核

当前开发client2011音频清单780文件全部存在且SHA-256匹配。清单仍含15条源索引缺失引用，完整列于artifacts/closeout-audio-files-current.json；这不证明对应运行时事件回退正确，不替代技能阶段缺口及听感/时序验收。未重新转换或替换声音素材，C13保持进行中。


### 缺失声音引用的补充库核对

15条源缺失引用中3条（1922、10110、10111）共享m11-1.wav，当前补充库文件存在。其余12条在用户十六周年目录的780个WAV中没有同名匹配。详见artifacts/closeout-audio-missing-resolution.json。该结果仅是文件存在性与索引核对，不是运行时声音事件覆盖或听感验收；未采用无依据的相邻音效替换。


### 区域怪物的缺失声音调用追踪

静态外观公式扫描得到23条候选记录（含审计目录与实际配置重复），不能直接认定运行时缺音。进一步通过生产EditionCreatures.sound_id检查区域目录379种怪物、全部声音事件，12条未补齐索引均未命中。区域专属sounds覆盖了相关外观公式。证据和可重跑脚本：artifacts/closeout-regional-audio-calls.log、.gd；候选列表closeout-missing-audio-callsite-candidates.json。脚本实体、技能和实际听感仍待检查，C13未完成。


### 技能路径缺失引用核对

通过生产play_skill_stage记录23个技能、0/1/2阶段共69次入口分发，没有调用12条未补齐源索引。可重跑脚本及结果见artifacts/closeout-skill-audio-calls.gd/.json/.log。测试只截获声音分发，不执行实际施法，不证明静默阶段均正确，也不覆盖其他独立音效路径或声音播放。既知技能阶段缺口继续保留。


### 技能分发声音实际解码

前轮技能分发记录的40个唯一声音ID，经当前EditionResources.initialize/sound_id实际加载，全部解码且时长大于0。证据artifacts/closeout-skill-audio-decode.json/.gd/.log。仅当前开发素材配置下资源加载，不包含扬声器试听、静默阶段合理性、运行时释放时点与其他武器切换路径。未修改素材，未打包。


### 真实缓存校验中断重试

对现有完整外部缓存执行实际verify-cache进程，在状态running且进程仍存活时SIGKILL，确认退出-9；同独立输出目录再次运行exit0并写入ready。报告artifacts/closeout-cache-verify-interruption.json，脚本check_cache_verify_interruption.py。仅只读校验缓存，状态写入独立artifacts目录。此证据不覆盖完整转换中断、应用强退或GUI重选，相关待办保留。


### 真实基础客户端转换中断恢复

使用原十周年客户端，独立缓存下chrsel.pngpack.tmp写入1888464字节时，确认转换进程存活并SIGKILL整个子进程组，退出-9。随后同输出目录全量重试，使用不同generation，完整转换与校验exit0/ready，707地图和780音频。报告与日志closeout-full-import-interruption.json/.log，可重跑脚本check_full_import_interruption.py。本次独立失败与成功缓存均已清理，保留报告；未修改原客户端、正常缓存和用户存档。GUI强退恢复、补充库中断及多应用交互仍未因此验收。


### 双缓存校验进程

同时启动两个真实verify-cache进程读取相同完整缓存、各自使用独立状态输出，均exit0/ready。报告closeout-parallel-cache-verification.json，可重跑脚本check_parallel_cache_verification.py。没有同时写入应用resources.cfg，不代表多窗口界面竞态已验收。C02待办已按现有基础转换中断成功证据细化为GUI恢复、补充转换阶段和共享设置多实例验证。


### 共享资源配置并发保存

两个真实Godot进程各30次执行生产save_and_launch，截获launch避免进入游戏，每次配置读取正常，静态附加字段42保留，最终配置完整，无.tmp残留。独立临时目录自动清理。证据closeout-parallel-settings.json与两份writer日志，脚本保留。首轮测试脚本类型推断错误已修正后重跑成功；未修改生产逻辑。仅Mac后校验保存步骤，不覆盖GUI、验证目录真实性、并发修改不同附加字段或Windows/Linux文件替换语义。


### 实际配置写权限拒绝与重试

临时配置父目录设为555后，生产保存步骤拒写、提示无法保存，原配置字节不变，未调用launch。恢复755后保存成功，附加字段保留，无临时配置残留；临时目录已清理。报告closeout-settings-permission.json，复查脚本check_settings_permission.py和closeout-config-permission.gd。只在Mac真实文件权限下验证保存步骤，不替代GUI或其他平台测试。


### 采样工具源码依赖交付修复

差异检查git diff --check通过；近期入口/窗口/背包脚本无调试输出残留，bootstrap打印仅显式审计入口使用。发现source_files清单遗漏采样测试依赖tools/sample_process.py，已补入。publication3项通过，当前清单846项；将采样器及测试独立复制到临时目录运行3项通过，证明该依赖无需工作区其他文件。报告closeout-sampling-source-dependency.json。未生成源码归档或安装包。


### 发布清单独立目录验证

将当前发布允许清单846文件复制至独立临时目录，仅在该目录运行53项tests/release，全部通过。日志closeout-isolated-source-tests.log，结果closeout-isolated-source-tests.json；临时目录自动清理。使用已安装依赖的原虚拟环境，不声称无依赖的新系统可直接运行，也不是正式源码归档或游戏启动验收。未生成ZIP、安装包或推送。


### 发布审计报告写入失败保护

bootstrap显式审计入口现在检查FileAccess打开与flush错误，无法写报告时明确打印错误并exit1，避免空对象调用导致脚本异常。实际不存在输出父目录用例通过；有效路径报告正常写出且退出码与code_only结果一致。证据closeout-audit-write-failure.json、closeout-audit-write-success.json。开发目录含素材，未声称其通过发布code-only检查；未打包。


### 审计写入回归纳入日常检查

新增tests/release/test_audit_report.py实际运行Godot审计入口，覆盖不可写目标和成功输出退出码一致性，使用独立临时日志/报告。当前55项Python检查全部通过，无跳过。未配置MAFA_GODOT且本机默认引擎不存在时两项明确skip。没有打包或执行平台游戏验收；证据closeout-release-regression.log。


### 剩余验收项结构化复核

按本计划原有C10/C12/C17/C18/C19要求，为任务JSON补充明确remaining字段，避免只有历史证据却没有剩余验收条件。所有未完成任务现均有可定位待办；没有因测试数量增长将实机、视觉、来源或发布门槛自动标为完成。保留代表场景抽查范围，不新增全地图人工验收。


### 技能操作说明与实现对齐

代码核对：main处理Q施法/R切换；gameplay.bind_skill保存的是0–7自动技能顺序，不是物理键码。README和启动指南原“可配置快捷键”不准确，已改为当前操作并明确没有任意键位重绑定界面。本次只修正文案，不新增功能或修改操作习惯。


### 当前源码完整操作回归汇总

入口控件及审计写入保护修改后，重新运行--suite all外部缓存检查，23/23功能通过，运行前后源码指纹一致。报告artifacts/ui-closeout-all/report.json，任务清单指纹及退出警告列表已同步；RELEASE_READINESS已替换此前混合批次说明。未关闭退出资源警告，也未将自动功能检查作为真实输入或稳定性验收。


### 原生注册实际输入闭环

隔离manual原生窗口真实鼠标键盘完成Tab切三输入框、Enter提交错误确认提示、修正确认后成功注册、恢复码确认返回登录，关闭exit0。证据closeout-native-registration-input.json及mismatch/return截图。不含凭据或恢复码记录；未覆盖后续登录、六种角色和中文输入法，不标记C05整体完成。未改生产代码或用户库，未打包。


### 注册后重启登录原生复核

只读确认此前隔离库测试账号存在后重开该库，真实鼠标键盘Tab/Enter登录，抵达世界选择；点击本机世界后观察门过渡及空选角页，窗口关闭exit0。证据closeout-native-login-restart.json及两张截图。不写凭据或恢复码到报告。六角色创建与动画听感仍待核验；未改用户库，未打包。


### 自动技能顺序状态保护

补齐bind_skill在暂停、死亡及非游戏模式下的状态保护，与select_skill一致。新检查比较内存与持久化状态不变，原只读保存失败/重试继续通过；18组pages功能通过，源码指纹稳定。该接口修改的是自动技能顺序，不是任意键位重绑定。没有扩展功能、改变用户存档或打包。
