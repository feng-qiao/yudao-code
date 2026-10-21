# 37-INSTRUMENT-03 正式部署准备与业务验收报告

> 任务：TASK INSTRUMENT-03-R3-DEPLOY-ACCEPTANCE-01（启动修复后执行版）
> 日期：2026-10-19
> 最终判定：**HOLD / BLOCKED**（唯一阻断项 B1：「我的预约」菜单 SQL 设计稿缺失；其余全部核验项 PASS）
> 报告位置说明：任务书指定目录 `E:\lixin\dev\ruoyi-vue-pro\doc\03-仪器管理` 在磁盘上不存在；既有 22~36、38 号报告实际均保存于 `E:\lixin\dev\doc\03-仪器管理`，本报告沿用该实际位置。

---

## 1. 后端启动修复复核

| 核验点 | 结果 | 证据 |
| --- | --- | --- |
| `TenantServiceImpl.java` 两个 setter 编译错误已真正修复 | ✅ | 根因是 IDEA ECJ 编译器忽略根目录 [lombok.config](file:///E:/lixin/dev/ruoyi-vue-pro/lombok.config) 的 `lombok.accessors.chain=true`，生成 void setter 错误桩；修复为 [.idea/compiler.xml](file:///E:/lixin/dev/ruoyi-vue-pro/.idea/compiler.xml) 新增 `DEFAULT_COMPILER=Javac`（当前文件第 4 行仍在）。**未修改任何 Java 源码**（`TenantServiceImpl.java` mtime 2026-10-02，未动） |
| 非关闭 Bean / 跳过编译 / 禁用安全检查 | ✅ | 仅 IDE 编译器配置一项变更；安全拦截实测有效（见下 401 证据） |
| IDEA（Java 21 + local）持续运行 | ✅ | 48080 监听进程 PID 41788，命令行含 `-javaagent:...IntelliJ IDEA 2024.1.2\lib\idea_rt.jar` + `temurin-21.0.6`，classpath 为各模块 `target\classes`，主类 `YudaoServerApplication`，12:37:45 启动，截至本报告查询时（13:40+）持续运行约 1 小时 |
| Tomcat 监听 48080 | ✅ | 日志：`Tomcat started on port(s): 48080 (http)`（12:37:58）；`Test-NetConnection 127.0.0.1:48080 = True`；HTTP 实测 `GET /admin-api/lab/instrument/reservation/my` → `{"code":401,"msg":"账号未登录"}`（Spring Security 正常拦截、业务路由可达） |
| profile=local | ✅ | 日志 `The following 1 profile is active: "local"`（12:25:56、12:37:46 两次启动均 local） |
| 无 `Unresolved compilation problems` / Bean 创建失败 | ✅ | 日志全文检索：仅 12:21:37、12:23:05 两条 `APPLICATION FAILED TO START`（修复前历史）；其后 12:25:56、12:37:46 两次 `Started YudaoServerApplication in 10.158s / 12.376s`，无任何异常；日志滚动至 13:32:05 仍在输出 http-nio-48080 工作线程日志 |
| 字节码抽查 | ✅ | `javap` 验证 target/classes 中 `TenantServiceImpl`：`RoleSaveReqVO.setCode` 与 `TenantDO.setContactUserId` 均返回自身类型（链式）；class mtime 2026-10-19 12:17（38 号 clean compile 产物）晚于源码 mtime，产物覆盖当前源码 |

## 2. Maven 编译和测试结果

| 项 | 结果 | 说明 |
| --- | --- | --- |
| `mvn clean compile -pl yudao-server -am -DskipTests` | ✅ BUILD SUCCESS | 38 号报告已执行并记录（2026-10-19 12:17 产物）；此后源码零变更（git status 与 38 号任务时一致，最后一笔 commit 2555bb58b1 为 10-15），结论仍然有效。本任务**未重跑 clean**，原因：负责人从 IDEA 启动的后端正以 `target\classes` 为 classpath 持续运行，clean 删除 target 会给运行中 JVM 的懒加载带来不必要的风险 |
| `mvn test -pl yudao-module-lab -o`（本任务重跑） | ✅ **Tests run: 195, Failures: 0, Errors: 0, Skipped: 0 / BUILD SUCCESS** | 含编译阶段成功（增量编译验证当前源码可编译）；含 `Instrument03IsolationGuardTest` 7/7、T1/T2 回归测试（见 §6.3） |
| 框架模块预存问题 | 记录在案 | `yudao-spring-boot-starter-protection` 的 `ApiSignatureTest` 因 Mockito inline + Java 21 兼容性失败，为预存环境缺陷，与 lab 业务及启动修复无关（38 号报告 §6.2） |

## 3. 正式数据库只读核验结果

全部查询为 SELECT（mysql 8.4.11 客户端，127.0.0.1:3306/labplatform），0 写入。

### 3.1 预约相关 7 表结构与代码映射（information_schema.columns 实测）

| 表 | 核验结论 |
| --- | --- |
| `lab_instrument_reservation` | 与 `InstrumentReservationDO` 一致：id / reservation_no / device_id / user_id / user_name / qualification_id / start_time / end_time / duration_minutes / status / purpose / actual_start_time / actual_end_time / finish_time / cancel_time / cancel_by / cancel_reason / remark + 五基础列 + tenant_id。**无 `window_id` 列**，代码亦无该字段（T2 裁决 REMOVE-LATER 已落地：「不要求数据库新增 window_id 字段」✓） |
| `lab_instrument_reservation_history` | 与 `InstrumentReservationHistoryDO` 一致：reservation_id / action / operator_user_id / operator_name / operator_role / action_time / before·after_start/end_time / before·after_status / reason / remark 等 |
| `lab_instrument_device` | 与 `InstrumentDeviceDO` 一致（含 bookable bit、status varchar(20) 等） |
| `lab_instrument_booking_rule` | 与 `InstrumentBookingRuleDO` 一致（granularity/min·max_duration/bookable_days_before·ahead/open_days/open_start·end_time/allow_cross_day/allow_admin_adjust_after_start/enabled） |
| `lab_instrument_booking_window` | 与 `InstrumentBookingWindowDO` 一致；`capacity`、`used_count` 两列**保留作历史展示，代码不参与容量计算**（[InstrumentBookingWindowServiceImpl.java:136](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentBookingWindowServiceImpl.java#L136) 注释「used_count 保留列仅作历史展示，不参与容量计算」；Mapper 注释「条件扣减/回退方法随 CAP-A 一并移除」）——**不依赖废弃的 CAP-A 容量账本** ✓ |
| `lab_instrument_qualification` | 与 `InstrumentQualificationDO` 一致 |
| `lab_instrument_suspend` | 与 `InstrumentSuspendDO` 一致（scope_type/device_id/preset_days/start·end_time/status/release_* 等） |

### 3.2 索引（information_schema.statistics 实测）

| 表 | 索引 | 结论 |
| --- | --- | --- |
| lab_instrument_reservation | PRIMARY(id)；**uk_reservation_tenant_no UNIQUE(tenant_id, reservation_no)**；idx_device_time(device_id,start_time,end_time,status)；idx_user_status(user_id,status)；idx_start_time(start_time) | D2 重试依赖的唯一键真实存在 ✓；冲突查询索引与 23 号设计一致 ✓ |
| lab_instrument_reservation_history | PRIMARY(id)；idx_reservation_id(reservation_id) | ✓ |
| lab_instrument_booking_window | PRIMARY(id)；idx_device_status(device_id,status) | ✓ |

### 3.3 调整预约服务端复核要点

[InstrumentReservationServiceImpl.java:441-481](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentReservationServiceImpl.java#L441-L481)：锁内重读预约行 → `resolveRoleForAdjust` 数据范围判定（本人 或 可管理原设备；换设备须同时可管理目标设备）→ P1~P8 全链复核（含设备状态、资格、有效暂停 B3、规则、开放窗口重匹配、时间冲突）→ 条件更新（仅 PENDING）→ 同事务 history。**不读客户端 windowId**（`ReservationAdjustReqVO` 已无该字段），与 R2 设计一致 ✓。

## 4. 菜单、角色和权限核验结果

### 4.1 设计稿核对（[20261016_instrument_03b_booking_config_menu_design.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261016_instrument_03b_booking_config_menu_design.sql)）

| 项 | 结论 |
| --- | --- |
| 预约配置菜单 13674~13676（§1~§3） | 设计完整：13674 预约配置 type=2 parent=13600 sort=18 path=booking-config（component=lab/instrument/booking-config/index）；13675 rule:query、13676 rule:update 按钮；仅授权 906（tenant_id=162 显式）；套餐 114 JSON_CONTAINS 守卫追加；幂等 INSERT（NOT EXISTS）可重复执行 0 行；§0 预检 + §4 验收 + §6 事务/回滚/备份说明齐备 ✓ |
| 预约管理菜单 13677~13682（**附录 A**，36 号批次 T1 裁决 2026-10-19 增补） | 设计完整：13677 预约管理 type=2 parent=13600 sort=19 path=reservation-manage（component_name=LabInstrumentReservationManage）；13678 query / 13679 create / 13680 cancel / 13681 **adjust** / 13682 manage 五个按钮；授权 904=13677~13681（不授 manage）、906=全 6 项、908=全 6 项、905 不授；套餐 114 追加 13677~13682；显式 tenant_id=162；幂等守卫、预检（要求届时 max_id=13676、existing_perm=0）、执行后验收齐备；`lab:instrument:reservation:adjust` 独立权限与后端注解一致 ✓ |
| 菜单父级 / 路由 / 组件 / 权限标识 | 父级 13600 实测存在（仪器管理 type=1 status=0）；path/component/component_name 与前端页面组件名逐一相符；权限串与后端 @PreAuthorize 完全一致（§6）✓ |
| system_role_menu 租户字段 | 设计稿所有 INSERT 显式 `tenant_id=162`（R2 隔离环境教训已吸收）✓ |
| 前置条件 / 重复执行风险 / 回滚方案 | 预检不符合即停；守卫使重复执行影响 0 行；全部 DML 可单事务执行；§6 要求执行前 mysqldump 备份三表 ✓ |
| 菜单权限缓存失效方案 | ⚠️ 设计稿 §5.d 仅写「套餐未刷新时由负责人在【租户管理】编辑保存套餐 114 触发同步」。直接 SQL INSERT 绕过应用层 `@CacheEvict`，Redis 缓存键 `menu_role_ids:{tenantId}:{menuId}` 不会自动失效（R2 隔离环境实测教训）。已列入 §9 执行前检查项：菜单 SQL 执行后须重启后端重建权限缓存 |

### 4.2 正式库当前实际状态（只读实测）

| 查询 | 实测值 | 与设计稿预检比对 |
| --- | --- | --- |
| MAX(system_menu.id) | **13673** | §1 预检「< 13674」✓；附录 A 预检「届时 13676」为 §1 执行后预期，当前未执行属正常 |
| 13674~13682 现有行 | **0 行**（空闲） | 「idle 各 0 行」✓ |
| permission LIKE 'lab:instrument:reservation%' | **0 行** | 附录 A 预检「existing_perm=0」✓ |
| 任意预约相关菜单（name/path/component 模糊查） | **0 行** | 设计稿从未执行 ✓（不得假定已执行——实测确认未执行） |
| 父菜单 13600 | 仪器管理 type=1 status=0 deleted=0 | ✓ |
| 角色 904 / 906 / 908 | 普通用户 / 本草基因管理员(lab_admin) / 仪器设备负责人，均 tenant_id=162、status=0 | 附录 A 预检「role_ok=3」✓ |
| 906 已授权菜单数 | **113**（tenant_id=162, deleted=0） | ⚠️ 设计稿头部注释写 115（2026-10-16 核查值），实测 113，差 2。属事实差异（期间授权有变动），**不影响设计稿幂等执行**（INSERT 依赖 NOT EXISTS 守卫而非授权数），记录在 §7 |
| 904 / 908 已授权菜单数 | 27 / 8 | 与设计稿注释一致 ✓ |
| 套餐 114 | status=0，menu_ids 括号 JSON 文本、长度 1462；JSON_CONTAINS(13674)=0、JSON_CONTAINS(13677)=0 | 格式守卫 ✓，无悬空预约菜单 ID ✓ |
| ID 冲突 / 父菜单不匹配 / 权限标识不一致 / 租户字段错误 | **未发现** | 无需因此 HOLD |

## 5. C7 当前状态及配置来源

| 项 | 实测 / 代码证据 |
| --- | --- |
| 配置键 | `lab.instrument.reservation.create-enabled`（[InstrumentReservationServiceImpl.java:57](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentReservationServiceImpl.java#L57) 常量 `CREATE_ENABLED_PROPERTY`） |
| 代码读取方式 | `@Value("${lab.instrument.reservation.create-enabled:false}")` → `private boolean createEnabled`；**默认 false**；`createReservation` 首行 `if (!createEnabled) throw exception(INSTRUMENT_RESERVATION_CREATE_DISABLED)`（116） |
| 当前生效值 | **false**。全仓库（yudao-server resources）检索：仅 `application-instrument-03-test.yaml:61` 配置 `create-enabled: true`（R2 隔离测试专用 profile，当前未激活）；`application.yaml`、`application-local.yaml` 均无该键 → 当前 local 运行实例取默认值 false |
| profile 覆盖关系 | 默认 false（代码注解）← application*.yaml 可覆盖 ← 隔离 profile 显式 true（仅 instrument-03-test）；本任务**未修改任何配置**，未执行任何开启 C7 的操作 ✓ |

## 6. 前后端接口一致性检查

### 6.1 API 路径 × HTTP 方法 × 权限串（后端 [InstrumentReservationController.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument/InstrumentReservationController.java) vs 前端 [api/lab/instrument/reservation/index.ts](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/api/lab/instrument/reservation/index.ts)）

| 功能 | 后端 | 前端 | 权限串（双端一致） |
| --- | --- | --- | --- |
| 预约创建 | POST /lab/instrument/reservation/create（@Idempotent 3s） | create() POST 同路径 | `reservation:create` ✓ |
| 预约日历 | GET /calendar | getCalendar() | `reservation:query` ✓ |
| 可预约空闲槽 | GET /free-slots | getFreeSlots() | `reservation:query` ✓ |
| 开放快速判定 | GET /is-open（windowId 可选） | isOpen() | `reservation:query` ✓ |
| 我的预约列表 | GET /my | getMy() | `reservation:query` ✓ |
| 预约分页（管理端） | GET /page（数据范围：本人 ∪ 授权负责人设备 / 管理员全部） | getPage() | `reservation:query` ✓ |
| 预约详情 | GET /get | get() | `reservation:query` ✓ |
| 预约取消 | POST /cancel | cancel() | `reservation:cancel` ✓ |
| 预约完成 | POST /finish | finish() | `reservation:manage` ✓ |
| **预约调整** | **PUT /adjust** | adjust() PUT 同路径 | **`reservation:adjust`（T1 独立权限，双端一致）** ✓ |
| 预约作废 | POST /void | void() | `reservation:manage` ✓ |
| 预约历史 | GET /history-list | getHistoryList() | `reservation:query` ✓ |
| 设备/开放时段查询 | booking-rule/get、booking-window/page = `rule:query`；写操作 = `rule:update`；设备查询 = `device:query` | 与 03b 设计稿 13674~13676 权限串一致 | ✓ |

### 6.2 前端按钮权限（[reservation-manage/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/reservation-manage/index.vue)、[my-reservation/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/my-reservation/index.vue)）

- 调整按钮（两页面 4 处）：`v-if="canAdjust"` + `v-hasPermi="['lab:instrument:reservation:adjust']"` **双闸** ✓；
- 取消/完成/作废按钮：仅 `v-if="can*"` 服务端单闸（无 v-hasPermi）。**判定非缺陷**：能访问页面的角色（904/906/908）按设计均持 cancel 权限；finish/void 由后端 `@PreAuthorize('reservation:manage')` 强制拦截（904 无 manage，即使按钮误显调用也 403）；can* 全部服务端计算——[ServiceImpl:687-690](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentReservationServiceImpl.java#L687-L690)：`canCancel/canAdjust = PENDING && ((本人 && 开始前) || 管理侧)`、`canFinish/canVoid = PENDING && 管理侧`，与冻结规则一致 ✓。
- device-detail 页创建预约按钮：`v-hasPermi="['lab:instrument:reservation:create']"` ✓。

### 6.3 权限/数据范围自动化测试证据（195/195 内）

`Instrument03R2PermissionAnnotationTest`：adjust 端点挂独立 adjust 权限 ✓、cancel 权限不隐含 adjust ✓、AdjustReqVO 无 windowId 字段 ✓；`Instrument03R2AdjustT1T2Test`：本人 PENDING 可调整 ✓、本人不能调他人（095）✓、管理员可调整（原因必填）✓、窗口设备调整不要求 windowId 且冲突仍拦截（096）✓；`Instrument03DLifecycleTest`：本人开始前调整 ✓ / 开始后 095 ✓ / 排除自冲突 ✓ / 暂停不被绕过（086）✓ / 跨设备调整 ✓。普通用户仅本人数据、负责人仅授权设备范围、管理员全量——由 `resolveRoleForAdjust` + `InstrumentScopeSupport` + 上述测试共同证明 ✓。

### 6.4 本阶段代码修复

**无**。未发现需要修复的代码缺陷；未改变任何冻结规则；未开发新功能。

## 7. 未解决问题及证据

### B1【阻断项】「我的预约」菜单 SQL 设计稿缺失

| 项 | 内容 |
| --- | --- |
| 事实 | ① 页面组件已交付：[my-reservation/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/my-reservation/index.vue)（`LabInstrumentMyReservation`，35 号报告 §3 称「既有页面」）；② 正式库**无任何预约相关菜单**（`system_menu` 按 name/path/component 模糊查 0 行）；③ 03b 设计稿（13674~13676）与附录 A（13677~13682）**均不含** my-reservation 菜单；④ 07 号设计 §4.1 菜单层级含「我的预约（普通用户）」但明确「不分配真实 ID、不写 SQL」，此后无任何任务将其落成 SQL 设计稿；⑤ 仪器大厅、设备详情页均无该页面入口（grep 全 src 无 router-link/push 指向 my-reservation） |
| 影响 | yudao 前端为菜单驱动动态路由：无菜单 = 无路由 = 页面不可达（手动输 URL 亦回退）。即使授权执行 03b+附录 A 并开启 C7，普通用户验收第 4/5/6/7 项（查看本人预约、调整、取消、预约历史）仍**无 UI 入口可开展** → 业务验收不完整，部署目标未达成 |
| 证据 | 本报告 §4.2 查询结果；35 号报告 L68/L93；07 号文档 L269 |
| 最小修复方案 | 补编「我的预约」菜单 SQL **设计稿**（仅设计、不执行，范式同附录 A）：建议 `13683 我的预约 type=2 parent=13600 sort=20 path=my-reservation component=lab/instrument/my-reservation/index component_name=LabInstrumentMyReservation`；按钮权限沿用 `lab:instrument:reservation:query`（13684，可选）；授权 904（906/908 是否同授由负责人裁决——二者作为可预约用户同样需要本人入口）；套餐 114 JSON_CONTAINS 守卫追加；显式 tenant_id=162；幂等 INSERT。与 03b、附录 A 一并提交负责人授权 |

### N1【非阻断·事实差异】906 菜单授权数 113 ≠ 设计稿注释 115

设计稿头部注释（2026-10-16 核查）与附录 A 注释（2026-10-19）均写 906 已授 115 菜单，本任务实测 113（tenant_id=162, deleted=0）。期间授权发生过变动（-2）。不影响设计稿幂等执行与验收预期（验收按 13674~13682 段内行数核对）。建议执行菜单 SQL 前以实测值为准更新设计稿注释，非必须。

### N2【非阻断·提示】menu_role_ids 缓存失效

见 §4.1 末行与 §9 检查项。设计稿未把「重启后端/清缓存」写入执行步骤，仅提示套餐同步；执行时须人工补充重启步骤。

## 8. 负责人手工验收清单

> 总前置（全部 15 项共用）：
> ① 菜单 SQL（03b §1 + 附录 A + B1 修复稿）已在正式库执行并验收；
> ② 后端已重启（menu_role_ids 缓存重建）；
> ③ C7 已按负责人书面授权开启（`lab.instrument.reservation.create-enabled: true`）；
> ④ 验收账号已就绪：904 普通用户 ×2（用户 A、用户 B）、908 设备负责人、906 实验室管理员，均属租户 162，且用户 A 持有效设备资质、无有效暂停。
> **当前状态（菜单未执行、C7=false）：全部 15 项暂无法开展**（无菜单、无 reservation 权限，创建接口固定返回 116）。勾选列在对应前置满足后方可执行。
> 若 B1 未修复即执行菜单 SQL：普通用户第 4/5/6/7 项**仍无法开展**（页面无入口），其余可开展。

### 8.1 普通用户（904，用户 A）

| # | 验收项 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 截图/日志证据 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 查看仪器及可预约时段 | 总前置①②③；用户 A 已登录 | 菜单「仪器管理→仪器大厅」→ 任选一可预约设备进详情页 → 查看预约日历与空闲槽 | 日历正常渲染每日开放范围与占用明细；空闲槽按规则粒度切片且含不可用原因 | ______ | ______ |
| 2 | 查看资质状态和暂停状态 | 用户 A 已有资质申请记录 | 「我的使用资质」页查看资质；「我的信用」页查看暂停记录 | 资质状态（有效/待审/过期）正确展示；有暂停时展示期限与原因，无暂停时为空 | ______ | ______ |
| 3 | 创建预约 | 用户 A 持有效资质；目标时段空闲 | 设备详情页选空闲时段 → 填写用途 → 提交 | 提示创建成功；生成唯一预约单号；状态=PENDING；重复快速点击被幂等拦截（"重复提交"提示） | ______ | 单号：______ |
| 4 | 查看本人预约 | 依赖 B1 修复；第 3 项已完成 | 菜单「仪器管理→我的预约」 | 列表含第 3 项预约，状态/时间/设备正确，按 id 倒序 | ______ | ______ |
| 5 | 调整本人待预约记录 | 第 3 项预约仍为 PENDING 且未开始 | 「我的预约」→ 该记录「调整」→ 改到另一空闲时段 → 填原因提交 | 调整成功；时段更新；历史出现 ADJUST 记录（含 before/after）；改到冲突/暂停/窗口外时段被分别拒绝（096/086/窗口原因码） | ______ | ______ |
| 6 | 取消本人预约 | 另建一笔 PENDING 预约 | 「我的预约」→「取消」→ 确认 | 状态=CANCELED；历史出现 CANCEL 记录；该记录按钮消失 | ______ | ______ |
| 7 | 查看预约历史 | 第 5/6 项已完成 | 「我的预约」→ 任一记录「历史」 | 按时间倒序展示 CREATE/ADJUST/CANCEL 全链记录，含操作人/角色/原因 | ______ | ______ |
| 8 | 越权访问其他用户预约 | 用户 B 已建一笔预约（记录其 id） | 用户 A 浏览器直接调 `GET /admin-api/lab/instrument/reservation/get?id={B的id}`（或详情页改 URL id） | 返回 403/权限错误（095 类拒绝），不展示用户 B 数据 | ______ | 响应码：______ |

### 8.2 设备负责人（908）

| # | 验收项 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 截图/日志证据 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 查看授权范围内预约 | 908 已被分配为设备 D1 负责人（lab_instrument_manager 有记录）；D1 上存在他人预约 | 「预约管理」页 → 分页查询 | 列表可见 D1 的预约（含他人）；不显示未授权设备的预约 | ______ | ______ |
| 2 | 按规则执行允许的管理操作 | D1 上有一笔 PENDING 预约 | 对该预约执行「完成」（填实际起止）→ 再对另一笔执行「作废」（填原因） | 完成：状态=FINISHED、历史 FINISH；作废：状态=VOIDED、历史 VOID；仅 PENDING 可操作，终态记录无操作按钮 | ______ | ______ |
| 3 | 范围外设备不能越权 | 存在 908 未负责的设备 D2 及其预约 | 直接调分页接口按 D2 过滤 / 对 D2 预约调 finish | 分页不含 D2 数据；finish 返回拒绝（数据范围外） | ______ | 响应码：______ |
| 4 | 调整权限与原因校验 | D1 上一笔 PENDING 预约 | 908 执行「调整」：① 不填原因提交；② 填原因改到合法时段 | ① 管理侧调整无原因被拒绝（095）；② 成功，历史 ADJUST 记录含操作人角色=负责人；按钮同时具备 canAdjust + adjust 权限双闸 | ______ | ______ |

### 8.3 实验室管理员（906）

| # | 验收项 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 截图/日志证据 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 查看预约管理页面 | 总前置①② | 菜单「仪器管理→预约管理」 | 页面正常渲染（不回退首页）；分页可查租户内全部设备预约 | ______ | ______ |
| 2 | 核验管理范围和操作权限 | — | 对比 906 与 908 视图；检查 906 可见「预约配置」菜单而 904/908 不可见 | 906 数据范围=全部设备；「预约配置」（13674）仅 906 可见可用；904 无「预约管理」manage 按钮功能（finish/void 调用 403） | ______ | ______ |
| 3 | 完成/作废等生命周期操作及历史 | 各状态预约若干 | 对 PENDING 执行完成、作废；对终态记录尝试二次操作 | 完成/作废成功且历史链完整（操作人/角色/原因/前后状态）；对已 CANCELED/FINISHED/VOIDED 记录再操作被拒（094），历史仅一条有效终态记录 | ______ | ______ |

## 9. 正式菜单 SQL 执行前检查项（届时逐条核对）

1. **B1 已修复**：「我的预约」菜单设计稿已补编并通过评审，与 03b §1、附录 A 合并为一次授权执行包；
2. 执行顺序：03b §1（13674~13676）→ 附录 A（13677~13682，其预检要求 max_id=13676）→ B1 稿（13683+，预检要求 max_id=13682）；
3. 执行前 `mysqldump` 备份 `system_menu`、`system_tenant_package`、`system_role_menu` 三表；
4. 单显式事务执行；§0/A.0/B1 预检任一不符立即 ROLLBACK 停止；连接字符集 utf8mb4；
5. 执行后按 §4/A.4/B1 验收段逐条核对（菜单层级、权限串、套餐包含、角色授权行数：904=5+B1、906=3+6(+B1)、908=6(+B1)、其他角色=0；906 越权回归 908 不含 rule 权限）；
6. **缓存失效**：SQL 直插不触发 `@CacheEvict`——执行完成后**重启后端**（重建 Redis `menu_role_ids:{tenantId}:{menuId}` 及本地权限缓存），再让验收账号**重新登录**验证菜单可见性；如需同步套餐菜单树，由负责人在【租户管理】编辑保存套餐 114 触发；
7. C7 开启为**独立授权动作**：在 `application-local.yaml`（或对应部署 profile）增加 `lab.instrument.reservation.create-enabled: true` 并重启；本报告不构成对 C7 的开启授权；
8. 全部通过后按 §8 清单开展手工业务验收。

## 10. 数据库和 Redis 未发生写入的证据

| 项 | 证据 |
| --- | --- |
| 正式 MySQL（labplatform） | 本任务对正式库共执行 5 批 mysql 客户端命令，**全部为 SELECT**（system_menu / system_role / system_role_menu / system_tenant_package / information_schema.columns / information_schema.statistics）；无任何 INSERT/UPDATE/DELETE/DDL；无菜单 SQL 执行；无测试预约创建 |
| 正式 Redis（127.0.0.1:6379） | **全程未连接、未执行任何命令**；无缓存删除/刷新操作（缓存失效仅写入 §9 检查项供届时执行） |
| C7 配置 | 未修改任何 yaml；未开启 create-enabled |
| Docker | 未创建/启动任何容器（R2 隔离环境此前已清理） |
| 文件变更 | 仅新增本报告 1 个 md 文件；未修改任何源码/配置/SQL 设计稿 |
| 运行中的后端 | 负责人 IDEA 实例（PID 41788）全程未中断；本任务仅对其进行只读 HTTP GET 探测（未登录 401） |

---

## 最终判定

**HOLD / BLOCKED**

全部核验项中：阶段一（启动修复复核）、阶段二（正式库只读核验、C7 状态）、阶段三（前后端一致性）均 **PASS**；唯一阻断项为 **B1「我的预约」菜单 SQL 设计稿缺失**（§7），其导致授权执行现有菜单 SQL 并开启 C7 后，普通用户 8 项手工验收中仍有 4 项（查看本人预约/调整/取消/预约历史）无 UI 入口可开展，业务验收无法完整闭环。

**最小修复路径**：补编「我的预约」菜单 SQL 设计稿（建议 ID 13683 起，范式同附录 A，仅设计不执行）→ 与 03b §1 + 附录 A 合并提交负责人书面授权 → 按 §9 检查项执行 → 按 §8 清单验收。

本任务到此停止，未执行任何正式部署操作。
