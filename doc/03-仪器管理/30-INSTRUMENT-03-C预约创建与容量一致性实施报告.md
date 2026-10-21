# 30-INSTRUMENT-03-C预约创建与容量一致性实施报告

> 任务：TASK INSTRUMENT-03-C-IMPL-01（U1～U5 规则冻结、CAP-A 容量一致性修复、03-C 预约创建与并发验收）
> 执行日期：2026-10-16
> 前置报告：26 / 27 / 28 / 29 号；冻结依据：22 / 23 / 24 号文档
> 边界声明：真实 `labplatform` 严格只读；本批真实库 DDL=0、DML=0、菜单写入=0、角色授权=0（详见 F 节）

---

## A. U1～U5 冻结

### A.1 文档版本与落地位置

| 裁决 | 冻结文档位置 | 代码落地位置 |
| --- | --- | --- |
| U1 跨日容量归属（半开区间 `[start,end)`，每自然日 1 单位，业务时区 Asia/Shanghai） | 22 号 §5.7（2026-10-16 负责人正式裁决写入） | `ReservationTimeUtils.computeUsageDates` |
| U2 容量单位（每计入日期恒 1 单位，不引入时长/人数倍数） | 22 号 §5.7 | 占用明细每 (reservation, window, usage_date) 至多一行 |
| U3 同日多窗口（不重叠、归属唯一、禁随机选；窗口模型无法表达跨日窗口 → 兼容方案：窗口设备预约仅允许单自然日，跨日以 087 拒绝，该分支 HOLD） | 22 号 §5.7 | `ReservationCreateExecutor.validateWindowScope`（087）；`Instrument03CReservationCreateTest.testCreate_windowCrossDay_087_hold` |
| U4 FINISHED 占用容量（PENDING/FINISHED 占用，CANCELED/VOIDED 释放；禁止重复释放） | 22 号 §5.7 | 占用明细状态机 OCCUPIED⇄RELEASED + `releaseIfOccupied` 受条件保护翻转 |
| U5 预约窗口关联（`lab_instrument_reservation.window_id BIGINT`，创建时确定唯一有效窗口） | 22 号 §5.7、23 号同步 | `ReservationCreateReqVO.windowId`；`ReservationRespVO.windowId`；DDL 见最终 SQL 设计稿 §3 |

23 号数据库与接口设计、24 号分批实施计划、29 号报告后续状态均已同步 U1～U5 为负责人正式裁决（A1 工作包完成）；29 号原始报告证据未改动。

### A.2 CAP-A 模型更新口径（文档已同步）

- 窗口主表 `capacity` 表示每日容量上限；旧 `used_count` 不再用于正式容量计算。
- 日期容量明细按 `(tenant_id, window_id, usage_date)` 唯一。
- 预约与唯一窗口通过 `window_id` 关联；预约状态变化与容量释放事务一致。

### A.3 新增未裁决事项

无。两处边界口径已在裁决框架内定案并写入代码注释：① U3 跨日窗口 HOLD 分支（不自行扩展未冻结开放规则）；② 24:00 边界（HH:mm 开放时段无法覆盖延伸至 24:00 的片段，按未覆盖 087 拒绝，与窗口模型同口径）。

---

## B. CAP-A 容量修复

### B.1 原实现风险

旧 `used_count > 0` 守卫只能防止计数变负，**不能证明某条预约尚未释放**：重复取消/作废、并发状态变更可对同一预约多次执行 `used_count - 1`，扣穿其他预约占用的容量，且无任何数据库级不变量可审计。

### B.2 最终数据模型

1. **日期容量明细** `lab_instrument_booking_window_daily_usage`：`uk_window_date (tenant_id, window_id, usage_date)` 唯一；`used_count` 由占用明细驱动。
2. **预约级容量占用明细** `lab_instrument_reservation_capacity_occupation`（新增）：`uk_occupation (tenant_id, reservation_id, window_id, usage_date)` 唯一；`occupation_status ∈ {OCCUPIED, RELEASED}`；**不逻辑删除**（避免 MySQL 唯一索引与逻辑删除组合导致历史记录阻止重建或重复有效占用）；含 create/update_time 与标准审计字段。
3. `lab_instrument_reservation.window_id BIGINT`（U5）。
4. 释放协议：仅当 `UPDATE ... SET occupation_status='RELEASED' WHERE id=? AND occupation_status='OCCUPIED'` 影响行数=1 时才允许递减日期用量；同事务完成预约状态、占用状态、日期用量三步，任一步失败整体回滚。

### B.3 SQL 设计稿

[20261016_instrument_03_capacity_u1_u5_final.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261016_instrument_03_capacity_u1_u5_final.sql)：含日期容量明细表、占用明细表、`window_id` 字段、索引与唯一约束、执行前只读预检、执行后只读验收、DO/Mapper 一致性检查、部分成功/重复执行停止条件、历史数据兼容策略、应用层完整性校验（不依赖外键）。**仅设计稿，未执行。**

### B.4 占用与释放幂等实现

- 写入：`recordOccupied`（预约创建逐计入日期写入 OCCUPIED，uk 兜底重复）。
- 释放：`releaseIfOccupied` 受条件保护状态翻转，`affectedRows=1` 才递减 `used_count`；重复释放第二次翻转影响 0 行 → 不再递减，不影响其他预约。
- 测试证据：[Instrument03CapacityOccupationTest](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument03CapacityOccupationTest.java) 8 用例（重复释放幂等、翻转守卫、uk 唯一）；[Instrument03CapacityDailyUsageTest](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument03CapacityDailyUsageTest.java) 8 用例。

### B.5 首次并发初始化

- 正式路径统一为：**设备行锁 → 窗口校验 → 日期容量校验 → 占用写入**——同设备全部容量写入在 `SELECT ... FOR UPDATE` 设备行锁内串行化，首次 INSERT 不存在并发竞争。
- 三步法（UPDATE → INSERT → DuplicateKey 后 UPDATE）保留为**脱离行锁协议路径**的兜底；DuplicateKeyException 抛出后事务已污染，不得在同一事务内继续写入，重试只能发生在新事务（本批正式路径经行锁规避该分支）。
- 容量不足与行不存在严格区分：行不存在→初始化后判定；行存在但额度不足→088 拒绝。

### B.6 日期容量一致性测试与审计 SQL

- 只读一致性审计 SQL（不自动修复真实数据）已含于 B.3 设计稿：日期用量 vs 有效占用明细核对、负数检测、超容量检测、重复有效占用检测、孤儿占用检测。
- 03-C 回滚证据：`testCreate_windowCapacityExceeded_088_rollback`（容量满拒绝且占用/预约/用量零残留）、`testCreate_reservationNoConflict_retryFail_099_rollback`（B8 单号重试仍冲突 → 099，已占用容量整体回滚）。

### B.7 窗口修改与删除（03-B 旧口径修正）

- 不再使用窗口主表累计 `used_count` 判断可删除；缩小容量检查所有相关日期有效占用；存在受影响预约时禁止不安全时间范围/日期/设备归属修改；删除窗口检查关联预约与占用明细；CLOSED 窗口不接收新预约。回归：[Instrument03BBookingRuleWindowTest](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument03BBookingRuleWindowTest.java) 17 用例通过。

---

## C. 03-C 功能

### C.1 后端文件清单

新增（[service/instrument](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument) / [controller](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument)）：

| 文件 | 职责 |
| --- | --- |
| InstrumentReservationService(Impl).java | 创建编排（C7 开关 + executeInDeviceLock）、calendar/free-slots/is-open/my/get |
| ReservationCreateExecutor.java | 锁内 P1~P9 校验链 + 落库（无事务无锁，由协调器回调） |
| ReservationTimeUtils.java | U1 计入日期（半开区间/业务时区）、开放日/HH:mm 解析 |
| InstrumentReservationController.java | 6 端点；create 带 @Idempotent(3s) + `lab:instrument:reservation:create` |
| vo/reservation/ReservationCreateReqVO.java | deviceId/windowId/startTime/endTime/purpose/remark |
| vo/reservation/ReservationRespVO.java | 全字段 + deviceName 展示字段 |
| vo/reservation/ReservationCalendarItemRespVO.java | date/reason/openRanges(windowId+windowName)/occupied/myReservationIds |
| vo/reservation/ReservationFreeSlotRespVO.java | 粒度槽位 + 逐槽不可用原因码 |
| vo/reservation/ReservationIsOpenRespVO.java | P1~P6 快速判定 |
| InstrumentReservationCapacityOccupationService(Impl).java + DO + Mapper | B1 占用明细（recordOccupied/releaseIfOccupied） |

修正：ErrorCodeConstants（080~093/099/100~109/116）、InstrumentBookingWindowDailyUsageServiceImpl（B2）、InstrumentBookingWindowServiceImpl（B5）、InstrumentReservationMapper（selectListByDeviceAndRange / selectListByUser）。

### C.2 前端文件清单（yudao-ui-admin-vue3）

| 文件 | 说明 |
| --- | --- |
| [src/api/lab/instrument/reservation/index.ts](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/api/lab/instrument/reservation/index.ts) | 6 端点 + VO + RESERVATION_STATUS |
| [src/views/lab/instrument/device-detail/ReservationForm.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/device-detail/ReservationForm.vue) | 预约对话框：日期选择、开放范围（含窗口名）、槽位点选开始/结束、占用明细、归属窗口自动判定（U3 反推唯一）、用途/备注、确认区、提交 loading 防重复、116 受控提示 |
| [src/views/lab/instrument/device-detail/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/device-detail/index.vue) | 「立即预约」入口（v-hasPermi create + bookable 才可用） |
| [src/views/lab/instrument/my-reservation/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/my-reservation/index.vue) | 我的预约列表 + 只读详情抽屉 |

vue-tsc 全量检查：新增 4 文件 **0 错误**（存量 15 个错误位于 announcement/fms/hrm/plasmid，与本批无关，未扩大处理）。

### C.3 校验链实现对照（任务书 C1 十五项 → 22 号 P1~P9）

| 任务书校验点 | 实现 | 错误码 |
| --- | --- | --- |
| 请求参数 / 用户身份及租户 | @Valid + 锁外登录用户/租户快照 | 116（未登录拒绝） |
| 设备存在、状态、可预约性 | P1/P2 | 081/082/083 |
| 有效资质（ACTIVE 且未过期，NULL=长期） | P4 | 085 |
| 生效暂停记录（selectActiveCovering） | P5 | 086 |
| 规则完整且启用（F15/B10 无默认值） | P3 | 084 |
| 开放窗口合法性（U3/U5 唯一归属复核） | P6 | 087 |
| 时间粒度/最短/最长/跨日限制 | P7 | 089/090/091/092 |
| 已有预约冲突 + 维护时段冲突 | P8（ReservationConflictChecker） | 093 |
| CAP-A 日期容量（逐计入日期 tryOccupy） | P9 落库步骤⑥ | 088 |
| Redis 预约单号（B8，uk 冲突重试一次） | P9 落库步骤⑦ | 099 |
| 预约 + 占用明细 + history(CREATE) 持久化 | P9 落库步骤⑧ | 事务整体回滚 |

全部校验在服务端完成；前端传入的窗口/容量/状态均不被信任（窗口归属锁内复核、容量以占用明细为准、状态由服务端初始化）。

### C.4 锁协议（C2，固定顺序）

`C7 开关 → 登录用户/租户 → suspendKey watchdog 锁 → TransactionTemplate → 设备行锁 → P1~P9 → 提交 → 释放 Redis 锁`。ServiceImpl 无外层 `@Transactional`（杜绝先解锁后提交）；未发现异步任务/事件回调独立事务破坏协议（创建链路无异步写入）。

### C.5 日历与空闲时段（C5）

- calendar：每日开放范围（容量满窗口剔除并以 WINDOW_FULL 占用项提示）+ 预约/维护占用明细（他人预约脱敏：仅单号+时段）+ 本人预约 id；范围 ≤31 天。
- free-slots：按规则粒度对齐切片，逐槽 available/原因码（087/089/091 等），被占用槽整个剔除；综合 bookable 日期窗口、过去时间、最短时长起步。
- 结果综合设备状态、规则、窗口、已有预约、维护、日期容量——不只按开放窗口生成"可预约"。

### C.6 预约状态、权限与租户隔离、功能开关

- 状态初始化 PENDING（冻结规则）；单号 B8（R+yyyyMMdd+5 位 Redis 自增）；`window_id` 落库；占用明细与预约一致；history CREATE 完整；无部分提交。
- 权限串：查询=`lab:instrument:reservation:query`，创建=`lab:instrument:reservation:create`；详情仅本人或授权负责人/管理员（他人按 080 不泄露存在性）；Mapper 全链路租户过滤。
- C7 开关：`lab.instrument.reservation.create-enabled` 默认 **false**，未满足部署条件时服务端 116 拒绝写入；前端不硬编码开关、不新增真实菜单/角色权限；开关不作为绕过权限或并发校验的手段。

### C.7 03-C 测试（27/27 通过）

[Instrument03CReservationCreateTest](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument03CReservationCreateTest.java)：① 116 开关；② P1~P8 逐码；③ 普通设备成功（PENDING/windowId=null/history/无占用行）；④ 窗口设备成功（window_id + 日用量=1 + OCCUPIED 明细）；⑤ 窗口跨日 087 HOLD；⑥ 088 容量满整体回滚；⑦ B8 单号重试成功/099 回滚；⑧ my/get/isOpen/calendar/freeSlots（含窗口 calendar 携带 windowId/windowName、deviceName 填充）。

---

## D. B1 与 MySQL 并发

### D.1 锁顺序与 watchdog

- 全写入路径固定锁顺序（B3）：创建预约为 `suspendKey watchdog → 事务 → 设备行锁`；多设备/多窗口场景按 deviceId 升序取锁（设计冻结，03-D 调整/取消路径沿用同一协议）。
- watchdog：`InstrumentLockRedisDAO` 自动续期语义；[Instrument03LockCoordinatorTest](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument03LockCoordinatorTest.java) 5 用例（Mock 层：顺序、直通、回滚传递）。

### D.2 并发测试矩阵（20 项）实际状态

**环境边界（任务书 D1）**：当前无独立 MySQL 测试 schema、无隔离 Redis 实例；建立隔离环境需额外授权，未擅自在 `labplatform` 创建测试表或写入。故真实 MySQL/Redis 依赖项**逐项 HOLD，不虚构结果**。

| # | 项目 | 状态 | 证据/说明 |
| --- | --- | --- | --- |
| 1 | 16 线程同设备同时段仅 1 成功 | **HOLD** | 依赖真实 MySQL 行锁 + Redis；设备行锁协议设计就绪 |
| 2 | 相邻时段可成功 | H2 已证（无冲突创建通过） | 03-C 成功用例 |
| 3 | 不同设备并发不被错误串行化 | **HOLD** | 锁粒度=deviceId 设计；真实并发未验 |
| 4 | 同用户暂停创建与预约创建交错 | **HOLD** | suspendKey 锁协议就绪 |
| 5 | watchdog 持有 >10s | **HOLD** | 依赖真实 Redis |
| 6 | Redis 不可达 fail-closed | **HOLD** | 依赖真实 Redis 故障注入 |
| 7 | Redis 锁所有权丢失 | **HOLD** | 同上 |
| 8 | 数据库事务异常回滚 | **H2 已证** | 088/099 回滚用例（预约/占用/用量零残留） |
| 9 | MySQL 8.0.12 RR 可见性 | **HOLD** | 需真实 MySQL |
| 10 | 日期容量首次并发初始化 | **HOLD** | 行锁串行化 + 三步法兜底设计就绪；H2 单线程已证初始化正确 |
| 11 | 同日容量不足拒绝 | **H2 已证** | 088 用例 |
| 12 | 不同日期容量独立 | **结构保证** | 占用明细 uk 含 usage_date、日用量按 (window,date) 独立行；多日独立扣减实证随 #13 一并 HOLD |
| 13 | 跨日预约正确扣减各日期 | **HOLD** | U1 计入日期由 computeUsageDates 实现（半开区间/业务时区），但窗口设备跨日按 U3 裁决以 087 拒绝（testCreate_windowDevice_crossDay_087_hold 已证拒绝路径），多日逐日扣减路径当前不可达，随 U3 跨日窗口 HOLD 分支一并 HOLD |
| 14 | 重复取消不得重复释放 | **H2 已证（协议层）** | releaseIfOccupied 翻转守卫幂等用例；03-D 业务路径未实施，不作正式验收 |
| 15 | 并发取消与作废不得重复释放 | **HOLD** | 同上，需真实并发 + 03-D 路径 |
| 16 | 容量缩小不得小于已占用 | **H2 已证** | 03-B 窗口测试 17 用例 |
| 17 | 预约创建与窗口关闭并发 | **HOLD** | 需真实并发 |
| 18 | 预约创建与维护创建并发 | **HOLD** | 需真实并发 |
| 19 | Redis 单号高并发唯一性 | **HOLD** | uk 兜底 + 重试逻辑 H2 已证；真实 Redis 高并发未验 |
| 20 | 跨租户数据和锁键隔离 | **H2 部分证**（租户过滤） | 锁键含租户设计；真实多租户并发未验 |

### D.3 MySQL 专项验证

事务提交与 Redis 解锁先后、设备行锁串行化、唯一键竞争、死锁检测、锁等待超时、首次初始化、RR 快照、容量明细一致性——**全部 HOLD**，依赖授权后的隔离 MySQL 8.0.12 + Redis 环境；未发现 H2 与 MySQL 行为不一致的证据（当前结论仅限 H2 可表达范围）。未通过扩大 Redis 锁等待时间掩盖任何数据库事务问题。

---

## E. 03-B 菜单

- 设计稿：[20261016_instrument_03b_booking_config_menu_design.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261016_instrument_03b_booking_config_menu_design.sql)（13674 预约配置 + 13675 rule:query + 13676 rule:update；套餐 114 追加；仅 906 lab_admin 授权，tenant 162；全程 NOT EXISTS 幂等守卫 + 执行前/后只读核验）。
- 只读核查事实（2026-10-16，纯 SELECT）：MAX(menu_id)=13673；13600 仪器管理树已存在；booking-config 未注册；906 已授权 115 菜单；908 存在（8 菜单）**未分配**；租户 1 package_id=0 无套餐不涉及；套餐 114 已含仪器菜单（追加格式守卫可行）。
- **真实菜单是否执行：否**（0 次 INSERT/UPDATE，等待负责人另行授权）。

---

## F. 数据库边界

| 项目 | 次数 | 说明 |
| --- | --- | --- |
| 真实 `labplatform` DDL | **0** | 全部 SQL 仅设计稿 |
| 真实 `labplatform` DML | **0** | 同上 |
| 真实菜单写入 | **0** | booking-config 菜单未注册（保持 29 号状态） |
| 真实角色授权 | **0** | 906/908 均未改动 |
| 真实库只读会话 | 2 次 | system_menu/role/tenant/package 核查（§E 事实），纯 SELECT |
| 隔离测试环境写入 | H2 内存库 | 162 用例随测试销毁；无独立 MySQL schema / Redis 实例写入（未获授权建立） |

---

## G. 下一阶段

1. **CAP-A DDL 执行前核验结论**：设计稿（B.3）含完整预检/验收/停止条件，达到待授权状态；窗口设备存量预约=0（功能未上线），`window_id` 迁移无历史数据风险，普通设备历史预约 window_id=NULL 兼容。
2. **预约 `window_id` 迁移准备**：字段与索引在设计稿 §3；DO/Mapper/VO 已对齐；无需回填。
3. **菜单 SQL 执行前核验结论**：设计稿（§E）含第 0 节人工预检门槛，达到待授权状态。
4. **03-C 是否达到部署候选条件**：代码与隔离测试就绪；**未达部署候选**——尚需：① CAP-A DDL 授权执行并验收；② 隔离 MySQL/Redis 20 项并发矩阵通过（D 节 HOLD 解除）；③ 预约菜单/角色权限另行设计授权；④ 负责人书面打开 C7 开关。
5. **03-D/03-E 启动条件**：03-C 达成部署候选后可启动；取消/调整/完成/作废的释放幂等协议（B1）与锁顺序（B3）已冻结，可直接实施。
6. **需负责人明确授权的 SQL 清单**：
   - `sql/lab/20261016_instrument_03_capacity_u1_u5_final.sql`（CAP-A 最终部署）
   - `sql/lab/20261016_instrument_03b_booking_config_menu_design.sql`（03-B 菜单收尾）
   - 另需授权：隔离 MySQL schema / Redis 实例（或等价隔离方案）用于 D 节并发验证。

---

## 附：本批编译与测试汇总

| 项目 | 命令/方式 | 结果 |
| --- | --- | --- |
| lab 模块全量单测 | `mvn -o -pl yudao-module-lab clean test` | **162 用例，0 失败，退出码 0**（instrument 7 类 114：02=26、03-A 数据层=23、03-B=17、容量日期=8、容量占用=8、B1 锁=5、03-C=27；非仪器 2 类 48） |
| 前端类型检查 | `npm run ts:check`（vue-tsc 全量） | 新增 4 文件 0 错误；存量 15 错误与本批无关 |
| 真实库写入 | — | 0（F 节） |

*真实数据库 DDL 次数：0 | DML 次数：0 | 菜单授权次数：0 | 角色授权次数：0*
