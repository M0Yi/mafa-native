# 操作页面收尾验收表

更新：2026-09-13。按用户最新要求，页面操作优先；地图仅抽查操作涉及区域和已知卡点。


## 当前结果速览

- 统一代码回归：`python3 tools/check_item_ui_closeout.py --suite all`，当前18/18功能通过；运行器单元测试最近8项通过。报告含运行时间、引擎版本与限定范围源码摘要。
- 报告：`artifacts/ui-closeout-all/report.json`。本次使用外部缓存，18/18通过，5组有退出资源警告；稳定性仍未完成。
- 任务筛选与修理反馈已纳入统一入口；放弃事务、返回选角写入/备份失败等独立回归见下文。
- 尚缺：实体手柄、实际听音与部分视觉输入验收、Windows/Linux完整游玩、主平台两小时前台稳定性及最终交付一致性。不得将代码回归解释为这些项目已完成。
- 继续冻结功能，不逐图普查，不例行打包。以下历史记录保留具体范围与限制。

## 本轮收尾边界

- 先解决影响操作的问题：按钮错位、遮挡、滚动、输入焦点、拖拽、切页、关闭，以及操作成功或失败后的明确反馈。
- 每个主要流程检查“打开 → 操作 → 结果提示 → 关闭/返回 → 重开恢复”；涉及物品、金币和设置时核对保存结果。
- 页面覆盖最小窗口、默认窗口和宽屏；键鼠与手柄分别记录证据。
- 地图只为任务、商店、仓库、传送和死亡恢复提供代表场景。707张逐张检查不作为本轮收尾完成条件，不因本轮抽查宣称全部地图无问题。
- 不扩大游戏内容，也不为每轮修复重新生成安装包。

“脚本通过”“截图已看”“实际点击通过”是不同证据，不互相替代。下表未将任何整类页面标记为全部完成。

| 页面 | 当前有效证据 | 下一项重点 |
|---|---|---|
| 注册、登录、选角 | 女角色实际创建、重登与位置恢复 | 审查失败重试、软删除恢复、账号输入状态；三槽位预览保留视觉抽查 |
| 背包、装备、快捷栏 | 拆分选中实例、拒写重试、暂停保护、拖拽数据校验、快捷栏绑定不消耗物品自动回归 | 审查装备替换与快捷键冲突；实际持续拖拽只保留必要检查 |
| 技能页 | 已有技能书规则与控件回归 | 代码核对学习条件、绑定后施法、取消与消耗时点 |
| 任务与NPC | 材料存取刷新、暂停/距离拒绝、提交拒写回退与防重复奖励回归 | 审查任务页筛选、跨页选择和规则/显示一致性 |
| 商店与修理 | 实际买卖与重登；固定提示；实例出售、修理品类、库存/容量/负重及事务失败回归 | 集中结果已记录，无新缺陷不重复这些用例；补真实发布材料中的限制说明 |
| 仓库 | 实例数量刷新、存取任务联动、死亡/暂停限制自动回归 | 审查跨窗口生命周期与服务距离约束 |
| 设置 | 固定反馈区、保存/音量拒写、Esc实际关闭、P输入保护 | 审查键位设置与持久化；OS失焦及输入法留必要实机检查 |
| 内挂 | 开关与阈值实际恢复、15页面/尺寸组合、保存失败回退、上层窗口肩键隔离 | 职业辅助规则和技能条件仍需覆盖 |
| 手柄 | 焦点、肩键层级隔离、弹窗拦截方法/事件回归 | 实体设备、断连重连未验收，不以自动测试替代 |

当前自动检查入口 `python3 tools/check_item_ui_closeout.py` 覆盖五组功能；设置与内挂各有独立回归。退出资源警告仍未定位，功能通过不等于稳定性通过。

## 最新执行方式：代码检查优先

按用户最新要求，主要通过代码审查、规则层测试和控件事件回归定位修复；不再逐页重复模拟鼠标操作。优先覆盖状态变化、实例ID、事务失败回退、输入分发、窗口布局与保存恢复。仅贴图观感、输入法、持续拖拽和实体手柄等代码无法充分确认的事项保留必要实机检查，自动测试不冒充实机证据。

以下旧操作队列仅保留为缺口参考，不再按逐页模拟方式执行。

## 历史实际操作队列

1. 正常退出旧手动验收进程，用同一隔离账号库启动当前源码，确认近期修改真正加载。
2. 先走设置与内挂上述未测路径，再走NPC商店与任务，保留操作前后截图。
3. 最后集中处理物理拖拽与实体手柄；工具不产生持续按住移动时保留硬件验收缺口，不反复重跑同一拖拽。
4. 每个发现只追加具体缺陷与证据；仅有新改动、新失败或未解疑问才重复对应测试。

## 已核对的近期证据

- `../artifacts/closeout-settings-save.log`：设置保存/拒写及暂停状态；真实OS失焦未覆盖。
- `../artifacts/closeout-settings-error-footer.png`：800×600固定多行提示。
- `../artifacts/closeout-controller-feedback-native.log`：手柄面板长提示图形回归。
- `../artifacts/closeout-warehouse-controller.log`：14项仓库存取检查，无失败。
- `../artifacts/closeout-merchant-scroll.log`：10项满背包滚动检查，无失败。
- `../artifacts/closeout-assist-focus.log`：内挂焦点、保存失败回退和15组合布局。

三平台实机、声音听感、长时稳定性、最终交付仍按总清单保留。禁止据本表宣布整体验收完成或重新开始全地图普查。

## NPC购买补充证据

实际鼠标购买金创药后，再次点击40金币购买，面板与聊天均提示金币不足；B打开背包显示20金币。只读核对隔离库：20金币、药品8个且位于单一背包实例。证据：`../artifacts/closeout-manual-npc-purchase-state.json`及其中两张截图。未记录买前物品快照，不据此单独证明数量差值；未覆盖出售或重登。

实际出售补充：鼠标滚动并出售药品成功，药品8→7、金币20→40，与隔离库一致（closeout-manual-npc-sale.png）。首次提示导致列表下移已修复；原生12项布局/滚动回归通过，尚待重启后实际点击复核固定提示。

最新源码实际复核：设置Esc关闭通过；交易后重启并经死亡回村仍保留40金币、7份药品，证据closeout-manual-restart-state.json及截图。商店固定提示和内挂新布局尚待实际点击。

内挂最新源码实际复核：蓝药开关关闭重开保留、阈值输入35并切页保留、固定提示不挤动控件；已恢复关闭和30。证据closeout-manual-assist-state.json及两张截图。其余辅助规则与实体手柄仍未全部验收。

NPC固定反馈已实际复核：传送余额不足和商店成功购买，提示固定底部、按钮原位；附近NPC排序已实际显示。截图closeout-manual-npc-fixed-feedback.png、closeout-manual-shop-fixed-feedback.png。仓庫实际存取仍待完成。

快捷栏自动回归补充：拒写保持原绑定和物品，恢复后重试成功且不消耗物品；已移入仓库的拖拽数据拒绝绑定。closeout-item-drag-guard.log。

## 物品页面自动检查入口

运行 `python3 tools/check_item_ui_closeout.py`；可用 `--godot` 指定引擎。覆盖拆分、拖拽/快捷栏、使用反馈，单项45秒超时；必须退出0且出现全部完成标志、没有脚本/断言错误才记功能通过。报告在 `artifacts/item-ui-closeout/report.json`，故障注入与资源警告原样保留，不代表图形或硬件验收。不会导出应用或修改用户存档。

统一自动入口现含4组：任务材料刷新/提交事务、拆分、拖拽快捷栏、使用反馈。任务按钮暂停和距离检查已覆盖；退出资源警告继续保留。

### 创建失败恢复：代码回归补充

角色身份与初始成长档位在同一次账号写入中保存。世界初始化失败可用同一角色重试；重新加载账号后初始化缺失世界仍使用创建时档位，已有世界不受重新传入档位影响。`entry_creation_failure_probe.gd` 的同进程重试、SQLite 账号重新加载和档位保持断言通过，日志：`artifacts/closeout-entry-creation-retry.log`。这是数据库重载测试，不是实际进程崩溃测试。退出时仍有 ObjectDB/资源残留警告，未列为清洁退出通过。

收尾优先代码审查、隔离存档和故障注入回归；地图只抽查代表场景与已知入口问题。视觉、输入法和真实手柄保留必要人工验证。

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

## 可重复执行的页面代码回归

- `python3 tools/check_item_ui_closeout.py --suite pages`：入口失败恢复、创建恢复、技能页同步、技能保存回退、仓库距离与生命周期，共5组。
- `--suite items`（默认）：既有5组物品/交易测试；`--suite all`：两组合计10组。
- 每项45秒超时，必须退出0、具备所有完成标志且无未预期错误。`resource_shutdown_warning` 独立记录退出资源警告，功能通过不等于稳定性验收。

本轮 pages 5/5通过，工具自身6项单元测试通过。报告 `artifacts/ui-closeout-pages/report.json`。本轮没有重新运行 all，也没有实机手柄或跨平台验收。

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

### 当前整合回归与结构化清单

公共按钮、确认框、音效和技能准确刷新修改后，all套件12/12功能通过，报告 `artifacts/ui-closeout-all/report.json`。已同步 `release/closeout-tasks.json` 的C05/C06/C07/C08/C11/C13对应自动证据，未提升任务完成状态。退出资源残留仍间歇出现，不等于稳定性通过。

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

### 删除恢复角色事务

新增character_restore_closeout_test：错误名称拒绝删除、删除/恢复拒写保留账号、重试恢复原ID及原世界、重复恢复拒绝、重新加载账号只保留一个角色，断言通过。记录按JSON实际序列化比较（初始原始浮点时间直接相等断言因精度差异失败，已修正测试）。日志 `artifacts/closeout-character-restore.log`；隔离测试数据库已清理，未做真实选角输入。

### 恢复角色槽位和同名边界

角色恢复回归补充同名冲突、三槽已满时拒绝且账号与归档不变；归档一个在用角色后恢复原ID、原世界成功，仍为三个角色。`artifacts/closeout-character-restore.log` 两项PASS，未改生产规则；不代表三槽预览视觉验收。

### 删除记录完整性校验

账号valid_db将archived条目纳入字段、职业性别、成长档位与全局角色ID唯一性检查；仅在用角色限制同名，保留正常删除后新建同名行为。归档缺字段、与在用ID重复拒绝；已有恢复/同名/槽位事务回归均通过，日志 `artifacts/closeout-character-restore.log`。未迁移或覆盖用户存档。

### 损坏归档数据库读写保护

角色恢复回归实际写入包含重复角色ID的损坏账号JSON，再调用load_database，验证失败、healthy=false、当前登录清空；后续persist新空账号拒绝，原JSON逐字保留且世界数据不变。`artifacts/closeout-character-restore.log` 四项PASS，全部在临时数据库内完成并清理。

### 归档校验整合回归

角色删除恢复/损坏保护加入pages，扩展后的9组页面回归全部通过，运行器6项单测通过。报告 `artifacts/ui-closeout-pages/report.json`；all现14组，本轮未整套重跑。技能页测试仍出现退出资源警告，稳定性未完成。

### 修理面板拒写重试

repair_feedback_closeout_test通过：准备武器耐久与服务位置夹具，向修理面板注入A事件；拒写时原面板保留并显示规则错误，金币与完整状态不变；恢复写入后修复耐久并扣费。日志 `artifacts/closeout-repair-feedback.log`。本轮未改生产代码，不证明真实走到NPC或实体手柄操作。

### 修理报价与防重复收费

修理反馈测试进一步核对面板合计报价、实际金币扣除精确相等，已修复后再次A确认完整状态不变并提示无受损装备。`artifacts/closeout-repair-feedback.log`通过，不扩大到所有商人价格或实机验收。

### 统一退出前停止音频

修理场景对照新增2组默认退出（1组残留）及2组提前stop（均无残留），见artifacts/closeout-repair-stop-comparison.json；另一次提前stop也无残留。main新增stop_audio与quit_application，所有主脚本quit调用在退出请求前停止并清空播放器及缓存；_exit_tree保留兜底。没有加入等待或改变存档失败返回路径。修理测试--stop-audio调用正式helper并断言stream为空/缓存清空，本次无残留（artifacts/closeout-repair-audio-helper.log）。返回选角拒写/备份失败/重试通过（artifacts/closeout-logout-audio-closeout.log，预期故障注入报错）。这证明提前停止路径可工作，不证明间歇问题彻底修复；直接queue_free的统一测试仍不改动，真实应用退出与长时稳定性待核验。

### 实际quit调用的窗口关闭回归

新增window_close_audio_closeout_test：调用主脚本WM_CLOSE通知处理方法（非OS鼠标），真实query_only拒写后仍在游戏、状态与音乐保留；重试经正式quit_application调用SceneTree.quit，断言主库关闭、重新打开有世界与备份、播放器stream及缓存已清空。两个功能标志通过，但进程退出仍残留field2.wav与106.wav播放资源，证据artifacts/closeout-window-close-audio.log。这进一步证明提前stop不能视为彻底修复；C15继续未完成。用例加入pages/all，all现17组；此次仅新增用例与运行器单测执行，未声称17组全跑。临时数据库清理，用户存档未访问。

### 独立引擎音频路径复现

无游戏场景/客户端素材/存档的audio_engine_exit_probe在当前4.7.2生成音频后stop并清空，退出仍有AudioStreamGeneratorPlayback残留。详见release/AUDIO_EXIT_DIAGNOSIS.md与artifacts/closeout-engine-audio-exit.log；上游#76745及候选#122742作为机制依据，尚未应用或验证修复。保持警告可见，不宣称稳定性通过；后续继续其他收尾，避免没有新证据的UI释放反复改动。

### 修理与合成旧窗口回调保护

controller_repair/controller_crafting输入入口补场景树及待删除检查，防止关闭后同名窗口重开时，旧实例仍接受延迟/直接输入回调。repair_feedback扩展已损坏装备fixture验证旧修理回调不扣金币或修复；旧合成确认保持phase与状态。3个PASS，日志artifacts/closeout-repair-stale.log；运行器6项单测通过，标志纳入统一套件。本次为输入方法回归，不证明物理手柄或完整合成规则；未打包。

### 手柄任务返回按任务ID恢复

发现任务关系导航历史仅存cursor索引，返回时列表重排/任务消失会打开另一条详情。历史改为同时保存selected_id，back按ID定位；原任务已不可见则留在列表，不打开替代任务。controller_stale_item回归用历史索引999及缺失ID夹具分别验证身份恢复、缺失不打开详情，4个功能标志通过，日志artifacts/closeout-task-history.log；运行器6项单测通过。退出资源警告仍保留。该项验证返回方法与身份规则，非实际手柄完整导航。

### 合成任务服务返回回归

controller_crafting_test按当前代码完成16项，无失败：任务接取、7配方导航、预览材料、取消、来源、报价过期拒绝、暂停拒绝、拒写保留、成功一次扣费、返回原任务列表/详情及交付不消耗成品。日志artifacts/closeout-crafting-navigation.log，报告artifacts/world-story/controller-crafting-tests.json。本次headless通过Viewport注入按键，不是实体手柄；800×600仅矩形边界断言。测试改为headless不生成截图（避免将无绘制结果当视觉证据），并清理自身随机SQLite。现有人工图像未覆盖。未改生产功能、未打包。

### 启动导入错误提示兜底

bootstrap错误报告不再直接访问缺失message；缺失/null/空白文字显示明确重试提示，正常错误原样展示。import_error_feedback_closeout_test四种临时状态文件夹具通过，重试按钮恢复、pid复位；没有实际启动导入进程，非真实鼠标验收。日志artifacts/closeout-import-feedback.log，加入统一入口现18组，尚未整套重跑。

### 启动资源配置类型检查

bootstrap在读取配置失败或root非字符串时显示恢复页面，保留原配置而非类型赋值报错。import_error_feedback新增数字/数组/字典路径夹具，通过真实_ready验证未启动、按钮可用、错误明确、文件字节不变。日志artifacts/closeout-import-feedback.log两项PASS。初始null夹具因ConfigFile把null作为删除键而断言失败，移除该无效夹具，清理本次失败临时目录；不是生产修复失败。新标志加入统一回归。

### 设置滑块关闭保护

设置页音量value_changed加入场景树/待删除检查，阻止关闭窗口后的旧滑块信号继续修改音量与元数据。settings_save_closeout新增关闭后更改旧滑块断言，原有拒写回退、缩放保存、提示位置及暂停焦点检查仍通过（artifacts/closeout-settings-stale.log）。6条SQLite readonly为主动注入，未做实际听音或物理输入；未打包。

### 背包拆分关闭保护

split_prompt及确认回调补面板/弹窗场景树检查，防止父窗口移除但子确认框未释放时继续拆分。split_selection新增把面板移出场景后确认及重开请求均不改变状态的断言，原数量/实例/拒写重试/重复确认/物品移位/模态释放仍通过。日志artifacts/closeout-split-detached.log，3个PASS；运行器6项通过。仅生命周期方法回归，未声称真实鼠标关闭验证。

### 背包其余按钮关闭保护

整理/使用/翻页/关闭回调加入面板场景树检查。拆分回归扩展面板移除后触发整理、使用、翻页，规则状态/页码/提示保持，四个PASS；日志artifacts/closeout-item-lifecycle.log。运行器6项通过，新标志纳入统一入口。仅回调生命周期验证，未打包或操作用户存档。

### 物品格动作前校验位置

item_slot点击/右键双击/拖拽起点新增实时UID容器格子校验，拒绝刷新前旧引用操作已移位物品。item_drag_guard新增仓库物品移出后旧格点击和拖拽无效断言，两个PASS，日志artifacts/closeout-item-cell-stale.log；运行器8项通过。原快捷栏拒写重试与仓库暂停检查保留。退出资源警告仍在，不代表实体鼠标验收。

### 拖拽落点生命周期

item_slot与quick_slot的_can_drop_data拒绝已脱离场景/待释放的控件，_drop_data复用检查。item_drag_guard移除落点后分别调用can_drop/drop，确认不移动物品或绑定快捷栏；3标志通过artifacts/closeout-drop-lifecycle.log，运行器8项通过。资源退出警告保留；非实际鼠标拖拽验收。

### 死亡面板保存失败反馈

死亡页增加独立自动换行错误Label，返回选角保存失败时直接显示在灰色遮罩上方，不只写底层HUD。回调拒绝已释放死亡层。death_return_test拒写点击返回按钮验证死亡状态保留及Label具体文案，连同原复活/物品保护19项通过（artifacts/closeout-death-feedback.log）。为headless节点文案验证，视觉布局尚未实机核验；未打包。

### 死亡面板原生渲染检查

新增可选--capture-death，仅非headless时截图。原生Godot执行21项通过（artifacts/closeout-death-render.log），人工查看artifacts/closeout-death-feedback-800.png：800×600中文长错误提示在按钮下完整两行、未超窗且位于灰色遮罩上方。测试隐藏世界地图，灰度地图外观和真实操作未验收。首次沙箱原生启动退出134无日志，随后获执行权限启动成功；未改变用户存档或导出应用。

### 死亡继续按钮取消旧确认

继续倒计时不再仅hide通用确认框，而是发出canceled以断开旧confirmed回调；死亡页按钮绑定创建时的死亡层，旧层按钮不作用于后来新建层。death_return_test新增继续后再次confirmed不执行旧操作断言，22项通过artifacts/closeout-death-modal.log。代码回调测试，非实际鼠标验收；未打包。

### 窗口位置元数据校验

窗口恢复坐标先验证两项为有限数值；错误类型回退默认位置，旧像素坐标转换Vector2前限幅，归一化锚点夹到0..1，避免极大浮点溢出。window_position_closeout覆盖7种正常/错误/极端保存值×3次窗口尺寸与各次关闭重开，全通过artifacts/closeout-window-malformed.log。仅headless矩形布局检查，非实体拖动；不改用户存档。

### 窗口位置写入失败反馈

窗口关闭仍正常执行，但put_metadata失败会通过pending_message说明位置未保存。window_position_closeout注入query_only确认窗口关闭、旧位置元数据不变、错误提示明确；恢复可写重新关闭后新锚点保存。原异常位置/尺寸检查仍通过artifacts/closeout-window-save-feedback.log。非真实磁盘故障或物理拖动，未打包。

### 文本编辑时手柄按钮隔离

通用按钮导航在LineEdit/TextEdit聚焦时不以A提交首按钮或以DPad抢焦点，B仍允许关闭。行会公告回归新增直接Joypad输入方法断言，连同保存/拒写/取消/持久化22项通过artifacts/closeout-guild-text-focus.log；原鼠标为Viewport合成、文字直接赋值，非IME/实体手柄验收。补测试自身临时数据库清理，未打包。


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

## 拖拽状态边界回归

代码测试复现：应用切到选角状态时，尚在树中的背包格和快捷栏仍接受原角色拖拽数据。两个投放入口现统一拒绝非游戏状态；新增测试核对物品、绑定和版本号不变，返回游戏后正常流程仍通过。

物品操作 5 项回归全部通过，证据：`artifacts/item-ui-closeout/report.json`。源码指纹：`4964850c5e284af6716bb38153230de275ae5f0e88c4b4c75f3023a09863981c`。这是 headless 状态与事务验证，不代表实际鼠标拖拽或手柄验收；未导出安装包。

## 死亡重进与城市安全区

按用户最新要求，死亡后返回选角再进入，立即恢复生命与魔法并清除死亡倒计时、中毒及石化。城市按现有出口图最少地图跳数选择，同图按安全区距离选择；安全区落点排除 NPC、入口触发格及不可移动格。写入失败停留入口并保留死亡存档，不扣装备或金币。留在死亡页面的 30 秒等待流程保留。

城市安全区新增浅绿地面覆盖、边界和文字，绘于地面之上、实体之下；范围与安全判断共用现有区域数据。未新增素材。

`reentry_revival_test.gd` 覆盖立即复活、城市选择、存档恢复、物品金币保留、只读写入失败以及安全区边界。19 项页面回归通过后，进一步收紧落点为 mobile 且不落入口触发格，专项再次通过，见 `artifacts/reentry-revival-test.log`。专项退出仍有已有的资源释放警告，不能据此宣称资源泄漏已修复。以上为代码和 headless 验证；地面标记的最终视觉效果尚未实机验收。未打包安装版。

### 复活失败的入口恢复

修复 `entry.confirm_modal` 在启动角色前隐藏入口的问题。进入失败后恢复选角页并显示具体原因，成功才由游戏入口隐藏页面。专项通过实际确认回调验证只读 SQLite 导致复活保存失败、复活地图目录缺失、恢复目录后重试成功；均使用隔离账号和存档。证据 `artifacts/reentry-revival-test.log`，未进行物理鼠标或视觉验收，退出资源警告仍单独保留。

### 安全区边界及暂停命中

专项以生产 `monster_hit` 信号验证盟重安全区两个边界角及中心均不扣血，区外命中仍生效。同时复现并修复暂停时延迟命中仍扣血：玩家受击入口现在统一检查 gameplay.available（游戏状态、未暂停、存活）。`artifacts/reentry-revival-test.log` 的新 PASS 标记证明上述回调级验证；不等于真实怪物走位或听感验收，退出资源警告仍存在。

### 盟重安全区原生画面

使用 Apple M1 Max / OpenGL Compatibility 开发窗口、1280×800 隔离存档渲染并查看 `artifacts/closeout-safe-zone-mengzhong.png`：浅绿边界、顶部安全区文字清楚，人物在覆盖层上方。脚本 `artifacts/closeout-safe-capture.gd`，日志 `artifacts/closeout-safe-capture.log`，进程退出0；不包含实际键鼠走入走出、其它缩放、手柄或全部地图验收。界面仍有素材缺口提示，此截图不作为整体画面已收尾的证明。

### 安全区最小窗口

`artifacts/closeout-safe-zone-mengzhong-800.png` 为 M1 Max 800×600 原生正常帧更新截图，已查看：人物居中，左上角安全区状态可见；绿色边界及地面文字因范围大于当前视野位于屏幕外。首次夹具禁用主更新导致摄像机未适配，已修正并覆盖无效截图；保留有效脚本 `artifacts/closeout-safe-small.gd`。这是代表尺寸渲染，不是物理拖动窗口、走出边界或手柄验收。

### 日常进入提示去除索引术语

场景进入仅提示“已进入”及地图名；缺帧目录保持不变，地图信息页仍提供 library/索引数量诊断。专项核对盟重进入提示不含索引术语、原缺口记录仍存在，复活与安全区回归通过。调整对应仓库测试旧提示期望，但该鼠标夹具未在本轮重跑。最新完整24组报告早于这次文案修改；当前证据为 `artifacts/reentry-revival-test.log` 专项，不冒充全套再次通过。

### 盟重仓库当前源码回归

M1 Max Compatibility 原生窗口运行 `mongchon_storage_mouse_test.gd`，14项通过、退出0。入口提示、任务页打开实际仓库、注入鼠标拖入药品、任务进度更新、双击取回及准备提示清除均通过。已查看 `artifacts/world-story/warehouse-mouse-story_mongchon_storage.png`；窗口位置和任务前置为夹具，不算物理鼠标/手柄验收。日志 `artifacts/closeout-mongchon-warehouse-current.log`，结构报告 `artifacts/world-story/warehouse-mouse-story_mongchon_storage-tests.json`。

### 当前死亡页最小窗口画面

已查看 `artifacts/closeout-death-reentry-800.png`：M1 Max原生800×600场景灰色覆盖、倒计时与“返回选角（重新进入即可就近复活）”按钮文字完整、居中且未裁切。测试直接注入致死伤害并渲染一秒，截图显示29秒；不构成真实怪物致死、30秒计时或物理点击验收。脚本及日志同名 `.gd`/`.log`，进程正常退出。

### 切图与火龙预警回归

当前 `map_failure_closeout_test` 六类损坏/缺失地图保护与成功切图清预警通过。火龙测试首次headless超时：夹具无条件等待frame_post_draw截图；现仅图形后端执行截图，headless保留全部26项规则断言并通过，覆盖30/60/120步进、暂停、躲避、安全保护与切图取消。日志 `artifacts/closeout-current-map_failure_closeout_test.log`、`artifacts/closeout-current-dragon_attack_test.log`。本轮没有新火龙截图，不以headless通过宣称音画完整；退出资源警告仍保留。

### 无界面截图等待检查

story_tracker、merchant_scroll、guild_log_ui、controller_npc 的截图段仅在图形后端等待 frame_post_draw，无界面保留行为断言。前三项31/12/12检查通过；第四项在第40行读取已释放view.reading报错，45秒超时后测试进程被终止，不能计为通过。报告 `artifacts/closeout-headless-ui-capture-guards.json`；这些旧报告的native措辞不适用于本轮headless执行，以本汇总范围为准。手柄NPC旧夹具与当前返回行为尚需核对，未改生产行为或伪造新截图。

### 手柄 NPC 返回夹具修正

确认第40行失效对象并非生产页重复消费B：operate成功后refresh回列表，旧夹具继续两次A办理下一条任务后已再次回列表；B正常关闭窗口。测试现先打开详情再核对B回列表，保留关闭、Y服务入口、事务失败重试、距离与任务提交全部断言，20项通过、退出0。生产逻辑未改。`artifacts/closeout-headless-controller_npc_test.log`；本轮为headless注入Joypad事件，旧报告native字样不表示原生图形或实体手柄通过。

### 测试后端标注

五组专项报告新增显示后端、physical_input=false及截图分支字段，重跑共101检查通过，均为headless，无新截图，汇总 `artifacts/closeout-evidence-scopes.json`。随后将源码字段名 screenshots_generated 改为 capture_enabled：后端只决定是否进入截图分支，不足以证明PNG成功落盘；本轮旧报告false仍准确。图形验收仍需检查实际截图文件。

### 手柄详情底部提示裁切修复

原生controller_npc测试首次20项通过的截图中，三行提示末行LB被底边裁切。正文最小高度从285减为235，保留正文滚动，给提示让出空间。`artifacts/closeout-controller-hint-800.png`已查看三行完整显示；此最终截图为固定NPC和固定三行提示的布局夹具，不能证明实际故事导航。修复后完整原生测试另一次在初始A未打开目标NPC处失败、后续空节点错误，进程已中止，记录 `artifacts/closeout-controller-npc-native.log`；不能声称修复后全流程通过，初始目标/输入失败尚待核对。

### 当前手柄NPC原生复验

增加首次输入状态记录及失败及时退出，避免再访问空面板。当前原生运行20项通过：首次位置289,618、村长287,618、无焦点、无窗口且未暂停。已查看真实故事详情 `artifacts/world-story/controller-npc.png`，缩短正文最小高度后三行提示含LB完整显示，无需固定hint夹具。日志 `artifacts/closeout-controller-npc-probe.log`。此前偶发首次A失败未复现，原因仍未确定；本次通过不能抹去历史失败，尚非实体手柄验收。

### NPC首次注入时序复查

旧测试在start_character同步建HUD后立即注入A，现等待8个process_frame完成入口节点切换再注入，与测试后续步骤一致。三次独立原生进程各20项通过、退出0，见 `artifacts/closeout-controller-start-repeat.json` 及逐次日志。未更改生产输入规则；该结果支持夹具时序改进，不证明历史偶发失败唯一原因，也不是实体手柄稳定性验收。

### 补充素材转换中断恢复

实际supplement_client16转换读取用户十六周年目录和现有只读基础缓存；在首段4039字节写入并flush后以trace检查点暂停，确认进程存活并SIGKILL(-9)。同一隔离输出未经插桩重试，转换及validate_supplement通过、退出0，随后删除本测试输出。75补充帧、1音频仅为此内容目录的转换结果，1551未解决图像记录及12声音引用仍在报告，不代表缺失资源补齐。`artifacts/closeout-supplement-interruption.json`及同名log，复现脚本`artifacts/check_supplement_interruption.py`。首次轮询未命中临时文件不计中断证据；两次测试目录均清理，未修改原客户端。此测试不覆盖应用GUI强退或完整导入器状态转移。

### 导入正常退出保护

`import_quit_lifecycle_test.gd`在macOS创建真实短时子进程：运行期间调用request_quit保留子进程并提示等待；确认子进程已退出后_process释放pid、恢复重试按钮和错误提示，request_quit正常结束，退出0。`artifacts/closeout-import-quit-lifecycle.log`。这验证入口生命周期回调，不是完整转换或真实GUI点击；其它系统明确SKIP，不伪称三平台通过。生产逻辑未改。

### 启用城市安全区落点检查

`artifacts/closeout-city-landings.json`使用真实地图navigation.mobile与NPC/传送入口排除规则核对全部9个启用安全区（7张城市地图），均存在候选落点。仅检查复活涉及的城市安全区，不展开707地图普查；不证明物理移动、画面或最近城市选择的全路线验收。脚本与日志同名前缀，退出0但资源释放警告仍存在。

### 专项临时数据库清理

controller_npc、dragon_attack、guild_log_ui、story_tracker补充退出清理，先校验本测试前缀及16位随机文件名，待app释放后删除该库及WAL/SHM/备份。四项headless重跑均退出0，独立Python检查确认本次文件不存在，见 `artifacts/closeout-test-store-cleanup.json`。story_tracker中途重启仍保留库用于恢复测试；未扫描删除任何历史数据库。异常崩溃或强杀仍可能保留诊断文件。

### 干净报告目录运行

五个专项测试原先直接写artifacts/world-story，干净源码没有该目录。现_initialize创建报告目录，失败明确退出。使用临时脚本副本只替换输出根，每个测试从不存在的嵌套目录运行，全部退出0且生成可解析、failures为空的JSON。`artifacts/closeout-fresh-report-directories.json`，临时副本及输出已自动清理；使用当前真实资源和工程，不冒充完整干净源码/三平台验收。

### 旧手柄任务页返回回调

代码测试复现旧页关闭后back仍按固定窗口名关闭新同名窗口。back及_input新增is_inside_tree/queued检查；新专项先关旧页再开同名页，旧back和B事件均不影响新窗口与存档。原选择身份、模态框与关闭事务保护仍通过，见 `artifacts/closeout-controller-back-lifecycle.log`，已纳入常规runner标记。本次是真实生命周期代码缺陷修复，不是前述旧测试步骤误判；尚未做实体手柄操作。

### 其余手柄入口生命周期

手柄操作、仓库、技能指引的_input同步增加已移出树/排队删除保护；修理与合成原已有同类保护。扩展controller_stale_item专项，正常setup后关闭旧页、建立同名新页，再向旧页发送B，均保留新窗口及存档。当前日志 `artifacts/closeout-controller-back-lifecycle.log` 全部PASS且无资源退出警告。初始未setup夹具造成孤立节点警告，已纠正夹具并重跑；不归因于生产修复。

### 手柄正常操作回归

近期输入存活保护后，原生macOS运行controller_panel、controller_skill_guide、story_warehouse_controller全部退出0且无脚本错误；技能指引72项、仓库14项通过，背包报告failures为空（未提供计数，不合并虚构总数）。覆盖三职业实际购买/使用技能书、条件不足/写入失败/重复使用、肩键切页及仓库存取。已查看warehouse-controller.png，800×600提示与结果可见。`artifacts/closeout-controller-normal-flows.json`。输入由Viewport注入，前置地图/资金为夹具，不构成实体手柄验收。

### 原生长测提前结束记录

本轮进程 41216（会话 70556）已返回退出码 0，RSS 采样会话 91213 也已结束。最后有效采样为 2695.422 秒，未达到 7200 秒，且未生成驱动完成报告。不能计为两小时通过；退出原因未确定，末尾输入法 mach port 提示仅为日志线索。原始采样、日志、隔离存档均保留，见 `artifacts/closeout-native-soak-session.json`。

### 物品输入状态保护补齐

确认框显示时阻止格子投放与拖拽起点；选角状态禁止旧格子发起拖拽。右键、双击、整理、取出与拆分入口补充死亡及模式保护，拆分确认拒绝隐藏弹窗与死亡/选角后的提交。保留死亡使用物品的明确提示。测试覆盖失败前后物品实例与数量不变、恢复后可重试；完整 24 组回归通过，见 `artifacts/ui-closeout-all/report.json`。这些是代码回归证据，不替代真实鼠标操作。

### 原生鼠标页签复核

隔离窗口通过 sky.click 依次点击装备、属性、技能页签，均显示对应内容；未学习技能显示条件及禁用状态，底部返回与技能商店入口可见。随后 sky.press_key Escape 关闭面板。已查看实际截图 `artifacts/closeout-live-skill-tab.png`。范围仅当前1280×800、女战士初始状态，不代表技能学习/施放、全尺寸或实体手柄通过。

### 小地图原生点击复核

同一隔离原生窗口中，sky点击右上“打开地图”显示世界地图操作面板，Escape关闭；随后点击小地图图像，标题由“比奇省 · 附近”切换为“比奇省 · 全图”，坐标保持289,618。已查看并保存 `artifacts/closeout-live-minimap-cycle.png`。仅验证本次入口与一次样式切换，不包含所有地图路线和跨进程样式恢复。

小地图追加实际点击验证：由全图再点图像收起为“比奇省 · 展开”标题条，再点标题条恢复附近样式；画面中未遗留全图背景或额外面板。至此当前比奇省场景完成附近→全图→收起→附近循环，未扩大为全地图验收。

### 新角色任务入口与寻路

原生隔离女战士经sky点击任务入口，默认仅显示初到边界村；点击“前往任务目标”关闭面板、角色由289,618移动到288,617附近，聊天记录新增正在前往任务目标。点击村长形象打开村庄委托，接任务按钮可见，截图 `artifacts/closeout-live-npc-entry.png`。此步骤未点击接取/交付，不计任务奖励闭环完成。

### 女角色首任务实际接取与交付

沿当前NPC窗口，用sky.click依次接取、交付初到边界村。窗口与聊天显示木剑×1、布衣(女)×1及经验30，并切至整装出发。只读隔离SQLite确认nv_arrival=done，wood_sword与ref:5各一件进入inventory；不是直接调用任务回调。尚未完成第二任务穿装备交付或六种角色全实测。

NPC已完成列表实际点击复核：查看已完成仅列初到边界村与整装出发，点击后显示各自实际奖励和禁用的“已完成”按钮；点击该按钮没有新增奖励，随后只读SQLite金币仍560、nv_equip仍done。仅覆盖这两个新手任务的历史入口。

### 仓库首次布局缺陷（未修复）

当前1280×800隔离窗口经NPC仓库入口打开背包与个人仓库，仓库首次默认位置覆盖背包物品格，妨碍直接拖拽存取。Escape仅关闭最上层仓库，背包和NPC窗口保留。代码定位：main.gd show_warehouse先show_bag再game_panel；windows.gd open对仓库仍使用通用阶梯默认位置，未避让背包。本次未完成物品存取，布局需修复后再验证。

### 仓库默认位置修复复核

首次打开个人仓库现在默认靠右，保留用户已保存的位置。`window_position_closeout_test.gd` 检查 1280×800、800×600 右侧对齐及关闭重开位置保留；19 项页面检查通过。已查看原生开发窗口截图 `artifacts/closeout-warehouse-layout-live.png` 与 `artifacts/closeout-warehouse-layout-small.png`：两种尺寸下背包物品格均可见，800×600 下仓库仍覆盖部分装备区域，多窗口并排空间有限。这两张为脚本打开窗口的图形复核，不替代 NPC 实际入口或物品拖拽验收；原先的拖拽未通过记录继续保留。

### 反向装备交换需求校验

修复将身上装备拖到已占用背包／仓库格时，被交换上身的装备绕过性别和装备需求检查的问题。现在统一检查交换中上身的物品；拒绝时不修改实例、耐久和存档。新增 `equipment_swap_requirements_test.gd` 覆盖男女限制、等级不足、空格脱装以及合法同类装备交换；已加入页面自动检查目录。专项通过，基础 inventory_test 25项检查通过，5项物品页面回归通过。日志分别为 `artifacts/equipment-swap-requirements.log`、`artifacts/inventory-swap-regression.log` 和 `artifacts/item-ui-closeout/report.json`。这是规则／回调测试，不代表实体鼠标拖拽已通过；headless仍报告macOS证书环境诊断。

### 材料包按选中实例消耗

修复背包多叠同类材料包时，使用指定实例却按总量扣除另一叠的问题。拆包先消耗指定 UID，再同步物品总量和添加材料；原事务继续检查容量、负重及写入失败。`bundle_instance_closeout_test.gd` 验证选中叠数量为1／2、另一叠不变、只读失败后重试和数据库实例一致，已加入物品自动回归。6项物品回归通过；药水捆扎71项、道士材料30项检查通过，见 `artifacts/item-ui-closeout/report.json`、`artifacts/bundle-regression-medicine_binding_test.log` 和 `artifacts/bundle-regression-fire_supplies_test.log`。这些是代码与事务证据，不包含实体鼠标、听感或完整战斗实机验收。

### 材料包回归用例纠正与满格验证

复核发现上一版实例用例选中数组末尾一叠，与旧 reconcile 的反向扣除顺序相同，不能独立检出“扣错叠”缺陷。现改为使用第一叠并断言末尾另一叠完全不变。新增48格背包场景：选中叠仅剩1个时拆包腾出的格子可容纳材料；选中叠剩2个时拒绝拆包且状态不变，移出一个物品后重试成功。更新后的专项退出0，见 `artifacts/bundle-instance-closeout.log`；上条6项汇总报告产生于用例加强之前，不能作为本次新增断言的证据。

### 手柄取消追踪状态一致性

手柄任务页 Y 取消追踪现在与 A 确认操作一致：暂停或死亡时不写入追踪状态，恢复后可正常取消并保存。切页和只读浏览保持可用。`controller_stale_item_closeout_test.gd` 新增暂停／死亡保留完整状态、恢复后数据库追踪字段清空的断言，日志含对应 PASS。此为合成手柄事件回调验证，实体手柄验收仍未完成。

### 存档初始化失败释放连接

EditionStore.open 在 schema 查询或初始化 SQL 失败后，现在关闭已打开连接，保留原 SQL 错误供界面显示。新增 store_open_failure_closeout_test：隔离数据库触发器注入初始化错误，断言 opened=false、db=null、原metadata保留；解除故障后同一store可重试成功。专项和原store_recovery_closeout_test均退出0，见 `artifacts/store-open-failure-closeout.log`、`artifacts/store-recovery-after-open-fix.log`。注入SQL错误与macOS证书诊断保留在日志；不代表断电或图形恢复流程已验收。

### 启动故障入口与孤立节点清理

使用真实场景加载及隔离SQLite触发器验证初始化错误进入“无法启动”状态，不创建worlds或operations记录。首次检查暴露提前返回留下未挂载地图、表现节点和入口canvas的问题；现由所有者在退出／销毁时释放尚无父节点的对象，正常场景子节点仍由场景树管理。store_entry_failure_closeout_test通过弱引用断言六个对象均释放；最终日志不再出现该用例原有的ObjectDB、CanvasItem和资源残留警告，仅保留注入SQL错误与macOS证书诊断。证据 `artifacts/store-entry-failure-closeout.log`。不据此宣称其它音频退出警告或整体长时内存问题已解决；未进行图形故障操作验收。

### 启动清理纳入自动回归

两项启动SQL故障测试已加入页面运行器；只放行各自精确的注入SQL错误，对这两项的ObjectDB、CanvasItem和资源残留诊断判为失败。检查器10项Python测试通过，含PASS不能掩盖泄漏、注入错误不能跨用例放行；22项页面回归通过，见 `artifacts/ui-closeout-pages/report.json`。其它用例的历史退出警告仍在报告中独立记录，不扩展本次无残留结论。

### 基础素材版本错误提示

资源manifest版本不兼容时，现在记录完整文件位置、所需2.0.1.11及实际版本；已有“文件缺失”或JSON错误不会被覆盖。resource_entry_failure_closeout_test使用独立错误版本目录触发真实启动失败，检查错误文案、不创建SQLite、地图／入口节点释放；随后移除manifest验证原缺文件原因保留。专项退出0且无节点残留诊断，见 `artifacts/resource-entry-failure-closeout.log`。已加入页面回归目录，但未重跑整套页面；最近22项报告仍对应此前源码。

### 地图目录结构错误定位

资源加载先检查maps数组、每条记录的非空字符串ID、重复ID及现有707条目录数量要求，再建立索引。错误写入完整maps.json路径，避免损坏记录直接触发脚本属性访问错误。map_catalog_failure_closeout_test覆盖7种损坏结构，专项退出0，见 `artifacts/map-catalog-failure-closeout.log`。这不是逐图视觉、通行或内容验收，也不改变代表场景抽查范围。

### 补充素材容器类型校验

基础manifest的supplements现要求字符串数组；补充manifest的frames/audio以及各图像库要求字典，错误定位对应manifest。supplement_shape_closeout_test覆盖7种错误类型，专项退出0，见 `artifacts/supplement-shape-closeout.log`。这只验证目录容器，不代表逐帧数据、贴图或音效内容全部通过。

### 图像包读取边界

frame读取PNG前验证六个索引字段为有限整数、读取偏移和长度在图像包内、尺寸为正；解码后要求PNG尺寸与索引一致。错误定位帧ID和包路径，不写贴图缓存。frame_pack_bounds_closeout_test用真实生成PNG覆盖6种错误及合法负偏移，专项退出0，见 `artifacts/frame-pack-bounds-closeout.log`。没有更改原始素材或逐图扫描；不代表所有资源引用和画面验收完成。

### 帧边界读取共用校验

将帧字段校验提前至frame_location，使frame_bounds和PNG读取共用规则；基础和补充记录的null、字符串、短数组、非数字偏移及零尺寸返回空边界并记录错误。空数组仍可按原流程寻找补充／替代帧。原图像包专项新增上述10组合并通过，见 `artifacts/frame-pack-bounds-closeout.log`。不把损坏索引误当人物合法负偏移，未调整人物布局。

### 独立素材故障回归入口

运行 `python3 tools/check_item_ui_closeout.py --suite resources` 可单独检查启动版本错误、地图目录结构、补充目录类型及PNG帧边界；均使用临时自建夹具，不需要客户端素材。4组通过，报告 `artifacts/ui-closeout-resources/report.json`。all仍包含这些检查并按名称去重；未移除原页面入口检查。检查器10项Python测试通过，登记脚本与PASS标记存在性检查现覆盖所有分组。该命令不验证完整客户端或实机渲染。

### 替代帧循环保护

frame_location记录当前解析链，遇到重复帧ID返回明确循环路径，避免自引用或跨库循环递归。frame_fallback_cycle_closeout_test验证自循环、双库循环与合法映射重复读取；已纳入resources分组。专项及5组资源故障回归通过，见 `artifacts/ui-closeout-resources/report.json`。未改写现有替代素材映射，不声称存在已确认的生产循环映射。

### 现有替代帧兼容检查

对当前外部转换缓存解析finish-fallbacks中的1833个引用，全部得到有效边界；这些引用实际共用3个目标帧，3个目标PNG均通过读取及尺寸校验。证据 `artifacts/closeout-fallback-catalog-current.json`、同名log及 `artifacts/closeout_fallback_catalog_probe.gd`。这证明新增保护没有拒绝当前替代引用，不证明1833种原始缺图已还原，也不证明建筑外观、遮挡或碰撞正确。

### 原生资源回归短测

M1 Max Compatibility默认1280×800隔离运行有效60.072秒，39次位置变化、未切图，resource_errors为空。12条间隔采样FPS最低60、中位70、最高74；不是逐帧统计或两小时验收。日志 `artifacts/closeout-native-resource-probe.log` 记录退出后性能记录器读取已释放host的脚本错误；已补is_instance_valid检查并停采，performance_recorder_test增加host先释放回归通过，日志 `artifacts/performance-recorder-host-exit.log`。短测原始错误保留；修复后的原生退出尚未复测。统计见 `artifacts/closeout-native-resource-probe-summary.json`。

### 性能记录器原生退出复测

修复后M1 Max原生隔离短测有效8.726秒，正常退出码0，无资源错误，未再出现记录器读取已释放host的SCRIPT ERROR。日志 `artifacts/closeout-native-recorder-exit.log` 仍保留macOS IMK mach-port消息；不得称为零诊断。该复测只关闭记录器退出缺陷，不替代两小时或实际操作验收；上一轮错误日志保留。

### 当前源码允许清单复核

允许清单检查通过859个本地文件，近期7个资源／启动回归脚本在清单内；artifacts、转换缓存和game/assets不在清单内。报告 `artifacts/closeout-source-allowlist-current.json`。仅为本地路径／扩展名允许清单检查，不代替素材许可、归档或远端历史审计；未暂存、提交、打包或发布。

### 缺失技能阶段参考代码复核

只读核对mirgo/main.go的效果声音索引计算及sound.go PlaySound：未登记索引直接跳过，未提供10101／10102／10451／10452的明确替代依据。记录行号与文件指纹见 `artifacts/closeout-skill-audio-reference-review.json`。这说明参考工程的静默行为，不能证明原版艺术设计要求静默；四项缺口继续保留，未修改声音映射。

### 当前源码整组回归（33 组）

重新执行 `python3 tools/check_item_ui_closeout.py --suite all`，33 组功能通过，运行前后源码指纹一致：`f39695a92821d9eb4656f79c80ae097229814dc8ed8383ff0c44a0cfcd45ae84`。报告为 `artifacts/ui-closeout-all/report.json`，完成时间 2026-09-13T16:49:46.722076+00:00。涵盖最新资源格式及替代循环、入口失败释放、装备互换条件与指定材料包实例修复。退出资源警告仍按用例记录，不表示资源释放问题已全部解决；不替代实际输入、声音和稳定性验收。

### 导入缓存图像库结构校验

修复 `validate_library` 将缺少 frames 当作空库、将 null/false/0/空字符串/空字典帧静默跳过的问题。现在要求库顶层为对象、frames 为数组，只有空数组帧按合法空帧跳过；错误包含库名或帧号。负数绘制偏移继续允许。项目 Python 环境运行 cache_integrity 12 项通过（`artifacts/cache-library-shape-regression.log`），导入器原有回归见 `artifacts/importer-library-shape-regression.log`。系统 Python 缺 numpy，未用该失败运行作为验收证据。仅修改 Python 校验器及测试，未改变正在长测的游戏运行时；不代表完整界面导入流程已通过。

同一校验边界补充检查十六周年清单：frames/audio 缺失或类型错误不再当作空目录放行；错误图像库、帧记录及声音记录报出具体名称。`artifacts/supplement-shape-import-regression.log` 记录 10 项通过，含可用 PNG、损坏包、尺寸/范围错误、重试状态及新结构用例。仍不代替完整导入界面中断实测。

### 导入修改后的工具整组回归

使用项目虚拟环境运行 `python -m unittest discover -s tests/release`：61 项通过，日志 `artifacts/closeout-release-regression.log`。末尾 sample: FAIL 来自测试运行器故意注入的进程启动权限失败，用例断言已通过；不是本轮真实导入失败。范围为本机发布工具及隔离测试，不包含界面导入、实体输入、实际三平台运行或长测验收。未生成发布产物。

### 缺少素材时的启动入口

`bootstrap_missing_resources_test.gd` 实例化真实 bootstrap 场景，使用独立 resources.cfg 指向不存在的客户端目录：资源设置提示和可编辑输入/重新选择按钮存在；没有导入 PID、缓存目录或临时目录内新增存档，原配置字节保持一致。headless 专项通过，日志 `artifacts/bootstrap-missing-resources.log`；已登记到页面回归，下次整组为 34 项。没有删除项目素材或改动用户配置；不证明无素材发布包的真实图形启动或整组34项已通过。

### 资源启动页最小窗口原生渲染

M1 Max / Godot 4.7.2 Compatibility，使用 --asset-setup 强制显示真实启动页，在 800×600 渲染并查看 `artifacts/bootstrap-layout-800.png`。目录输入、说明、导入/载入/退出按钮完整可见，按钮几何检查 outside_buttons=[]，日志同名前缀。初次受限环境启动失败，之后获自动审批运行现有引擎成功，退出0。未点击导入、未写用户配置或存档；强制设置页截图不等于无资源发布包及真实鼠标操作已验收。

### 新校验器与真实缓存兼容性

用当前 import_client.verify_cached 只读验证现有 frozen-import-test 完整缓存，该缓存声明并包含 supplement16。退出0，状态 ready，报告 `artifacts/import-real-cache-current.json` 保留校验器 SHA-256，日志同名前缀。校验状态写到缓存外的独立临时目录并在完成后清理；未修改客户端、缓存和存档。证明当前结构检查接受该套真实缓存，不代表重新转换、原始客户端全版本兼容或界面中断流程通过。

### 启动页与真实缓存检查子进程

当前校验器下再次执行 cache_startup_test：两个真实 Python 子进程分别验证正常完整缓存和不存在路径，状态目录独立、有效缓存到达加载回调、错误缓存显示失败并恢复重试按钮；工作中关闭请求保留进程。报告 `artifacts/closeout-cache-startup.json` failures=[]，日志 `artifacts/cache-startup-current.log`，退出0。缺少 manifest 的 traceback 为错误路径测试的预期输出。仅清理本次两个状态文件的临时目录，未改动缓存或用户设置。测试替换最终加载回调，且无真实鼠标，不代表界面全流程及强退恢复已通过。

## 手柄面板 Start 路由修复（2026-09-14）

背包/装备分类、仓库、技能指引、制作、修理及人物委托面板的普通输入分支不再吞掉Start，交给全局暂停处理；模态确认仍保持输入隔离。controller_stale_item_closeout_test通过Viewport.push_input验证分类面板打开时Start暂停、再按恢复，同时旧物品与窗口回调回归通过。证据artifacts/controller-start-pause-test.log。是引擎事件路由检查，不是实体手柄实测；其它面板已统一修复但尚未分别走完设备操作。

### 暂停后的分类面板操作保护

在上次Start路由用例中追加真实Viewport事件分发：暂停后按A使用、Y绑定，完整rules.state保持不变，再按Start可恢复。artifacts/controller-start-pause-test.log通过。代码审查仓库/修理/制作均调用near_reference_npc，NPC任务单独检查paused；这些路径的代码检查不能替代各设备输入验收。此次未改游戏规则，只补回归证据。

### 内挂面板暂停路由补齐

内挂面板同样曾吞掉Start；现放行到统一暂停入口，并忽略已退出场景或待删除面板的输入。实际Viewport事件注入验证内挂设置打开时Start暂停及恢复，controller_stale_item_closeout_test其它检查保持通过。证据artifacts/controller-start-pause-test.log。商店等通用窗口只拦截A/B/上下，未发现Start拦截，未为其改动输入逻辑。仍待实体手柄确认。
