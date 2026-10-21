# 仪器管理——INSTRUMENT-03 预约模块开发前核验报告

> 任务：TASK INSTRUMENT-03-PRECHECK-01（预约模块开发前集中核验与规则冻结）
> 执行日期：2026-10-15
> 上游：`20-INSTRUMENT-02-执行后验收报告.md`（结论 CONDITIONAL PASS）、`00`~`09` 设计文档、`11-设计修订记录.md`（G26=R3 裁决）
> 下游：`22-INSTRUMENT-03-预约业务规则冻结草案.md`、`23-INSTRUMENT-03-数据库与接口设计.md`、`24-INSTRUMENT-03-开发实施任务分批方案.md`

**边界声明（本任务实际遵守情况）**

1. 本任务只读核验 + 设计文档产出；**未执行任何 DDL/DML**，未生成待执行 SQL 的执行动作（23 号文档仅表结构设计定义，不落库）；
2. 未分配角色 908、未修改 `system_role` / `system_role_menu` / `system_menu` / `system_tenant_package`；
3. 未删除或重置任何测试数据；未修改 INSTRUMENT-02 资质/信用/暂停业务语义；
4. 未裁决事项（预约时间粒度、特殊设备规则、维修工单分配规则）一律列入 22 号文档待裁决清单，未擅自固定默认值；
5. 设计完成 ≠ 获得数据库执行授权，菜单/授权/DDL 均待负责人单独批准。

---

## 一、结论

### 总体结论：**CONDITIONAL PASS**

| 核验面 | 结论 | 说明 |
| --- | --- | --- |
| 现状与依赖 | **PASS** | INSTRUMENT-01/02 交付能力可支撑预约模块；预约相关 5 张表与全部代码均未实现（符合批次规划，属 INSTRUMENT-03 交付） |
| 并发竞态审查 | **发现阻断项 H-B1（附消除方案）** | 暂停写入侧无 DB 行锁，预约侧仅靠设备行锁**无法证明**消除竞态；给出方案 A（共用用户级 Redisson 锁）待裁决 |
| 规则冻结条件 | **具备** | 已冻结规则可完整覆盖预约准入主链路；未裁决参数（U1/U2/U3 等）已有安全行为（规则未配置=不可预约） |
| 遗留观察影响 | **已分析，不阻塞** | T-C1/C2/C3/T-V1/V2 均给出影响分析与建议方案（22 号文档 B 类清单），不在本任务执行修复 |

**进入开发的前置条件**（全部满足后方可启动 24 号文档批次 03-A）：

1. **B1 裁决通过**：竞态消除方案 A（预约创建共用暂停用户级 Redisson 锁）获负责人批准——不批准则并发正确性无法承诺，必须改用其他经裁决的方案；
2. **B2 裁决**：P4 资质校验是否叠加 `expire_time` 判定（补偿资质到期 Job 缺失）；
3. 22 号文档 B 类清单逐项裁决完成（可一次性集中裁决）；
4. 数据库执行授权另行申请（DDL / 菜单 / 授权 SQL 均不在本任务执行）。

---

## 二、现状核验证据（只读实查）

### 2.1 数据库现状（`labplatform`，2026-10-15 实查）

`SHOW TABLES LIKE 'lab_instrument%'` → **11 张表**：

| 归属 | 表 |
| --- | --- |
| INSTRUMENT-01（5） | `lab_instrument_platform`、`lab_instrument_device`、`lab_instrument_room`、`lab_instrument_manager`、`lab_instrument_notice` |
| INSTRUMENT-02（6） | `lab_instrument_qualification_apply`、`lab_instrument_qualification_apply_history`、`lab_instrument_qualification`、`lab_instrument_credit_account`、`lab_instrument_credit_flow`、`lab_instrument_suspend` |

**预约相关表全部不存在**：`lab_instrument_reservation`、`lab_instrument_reservation_history`、`lab_instrument_booking_rule`、`lab_instrument_booking_window`、`lab_instrument_maintenance` 均需 INSTRUMENT-03 新建（与 09 计划一致）。`lab_instrument_freeze_batch` / `_participant`、`_repair_order` / `_repair_history` 属 INSTRUMENT-05/06，本期不建。

**设备与负责人现状**（影响预约准入测试设计）：

| 项 | 实查结果 |
| --- | --- |
| 设备 | 2 台：id=1 `DEV-TEST01` 酶标仪（MICROPLATE_READER，**SCRAPPED**）、id=2 `DEV-TEST02` 科研仪器（SCIENCE，NORMAL） |
| `bookable` | **两台均为 0**（无任何设备开放预约） |
| `booking_rule` | 无表 → 无任何设备配置规则 → 按 F15/P3 语义，**当前全部设备不可预约**（安全默认） |
| 负责人 | 仅 3 行 `ROOM_REPAIR`（2 ACTIVE + 1 RELEASED），**无 DEVICE/PLATFORM 负责人**（与 20 号报告 N1 一致） |

> 影响：INSTRUMENT-03 联调与验收需负责人先配置设备 `bookable=1` + 规则数据（属业务配置操作，非代码）；测试用设备数据方案见 24 号文档批次 03-F。

### 2.2 代码现状

`yudao-module-lab` instrument 包全部 Java 文件清点（93 个）：

| 模块 | Controller | Service | Mapper | DO | VO | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| platform/device/room/manager/notice | 5 | 5 | 5 | 5 | 齐 | INSTRUMENT-01 已交付 |
| qualification/credit/suspend | 3 | 3+ScopeSupport | 6 | 6 | 齐 | INSTRUMENT-02 已交付 |
| **reservation / booking-rule / booking-window / maintenance** | **0** | **0** | **0** | **0** | **0** | **未实现**（INSTRUMENT-03 交付） |

前端 `yudao-ui-admin-vue3/src/views/lab/instrument/` 现有 15 个页面，**无预约日历、我的预约、预约管理、规则配置、维护时段页面**（07 §3 规划的 03 页面全部待建）。

### 2.3 错误码与基建现状

| 项 | 现状 | 对 03 的约束 |
| --- | --- | --- |
| 错误码段 | `1_002_004_001~079` 已用（平台 001-005 / 设备 010-019 / 房间 020-023 / 负责人 030-038 / 须知 040-044 / 资质 045-059 / 信用 060-066 / 暂停 070-079） | 03 预约段建议 `080~099`、规则/维护段 `100~119`（见 23 号文档） |
| 分布式锁 | `InstrumentLockRedisDAO`：固定租约 **10 秒**（`lock(10_000, MILLISECONDS)`），**无 watchdog 自动续期** | 预约事务必须短小（秒级完成），不得在锁内做慢操作（导出、文件、远程调用） |
| 设备 Mapper | `InstrumentDeviceMapper` **无 `selectByIdForUpdate`** | 预约侧设备行锁（03 §8.1）需新增 `FOR UPDATE` 查询方法（23 号文档已列） |
| 暂停判定 | `selectActiveCovering(userId, deviceId)`：`status='ACTIVE' AND start_time<=now AND (ALL 或 SINGLE=deviceId)`，**不含 end_time 条件**（H1 裁决落地） | 03 的 P5 校验必须复用该方法语义，**不得**自行引入 `end_time>now` |
| 单号生成 | 资质申请单号由 Service 层生成（`apply_no`，错误码 055 兜底）；质粒模块有 Redis 序列范式 | 03 `reservation_no` 沿用 Service 层生成（G11） |

### 2.4 资质到期 Job 缺失（影响 P4 语义，需裁决）

00 §4.3 资质状态机定义 `ACTIVE → EXPIRED（系统 Job）`，但 INSTRUMENT-02 实际实现中：

- `InstrumentQualificationServiceImpl` **无到期处理方法**（仅审批时写入 `expire_time`）；
- `infra_job` 共 34 条，0 条仪器相关 handler（20 号报告 3.6 实查）。

即：`expire_time` 到期后资质 `status` 仍为 ACTIVE。预约侧 P4 若只判 `status='ACTIVE'`，将放过已过期的资质。处理建议见 22 号文档 B2（推荐：P4 判定 = `status='ACTIVE' AND (expire_time IS NULL OR expire_time > now)`，服务端强校验不依赖 Job）。

---

## 三、依赖检查（INSTRUMENT-01/02 提供的能力与缺口）

### 3.1 可直接复用的能力

| 能力 | 载体 | 供 03 使用方式 |
| --- | --- | --- |
| 设备档案与状态 | `InstrumentDeviceDO`（status/bookable/category）、`DeviceStatusEnum` | P1 设备状态校验（仅 NORMAL）、P2 bookable 开关；设备状态机含"非 NORMAL 预约一律拒绝"（00 §4.1） |
| 设备类别 | `DeviceCategoryEnum`（8 类：NORMAL/SCIENCE/MICROPLATE_READER/CMC/FREEZE_DRYER/BLI/PROTEIN_PURIFY/BIOSAFETY_CABINET） | 特殊设备规则按类别路由（P6/P7，INSTRUMENT-04 叠加） |
| 资质权威来源 | `lab_instrument_qualification.status`（第一期仅 DEVICE 级，C4） | P4 校验：本人 + 该设备 + ACTIVE |
| 暂停覆盖判定 | `InstrumentSuspendMapper.selectActiveCovering(userId, deviceId)` | P5 校验（SINGLE 命中本设备 / ALL 全部拦截），语义已按 H1 冻结 |
| 数据范围 | `InstrumentScopeSupport.canManageAll / canManageDevice / getManagedDeviceIds` | 管理端预约列表、开始后调整/作废的授权判定（F19：权限+业务关系双条件） |
| 目标用户有效性 | `AdminUserApi.getUser`（租户过滤） | 创建/取消时操作人与目标用户校验范式 |
| 租户隔离 | `TenantBaseDO` + 租户插件 | 全部新表继承，跨租户由框架拦截（20 号报告 C 组实测 403） |
| 幂等注解 | `@Idempotent` | 防预约连点重复提交 |

### 3.2 缺口（INSTRUMENT-03 需补齐）

| # | 缺口 | 处理 |
| --- | --- | --- |
| G-1 | 预约 5 张表不存在 | 23 号文档 DDL 设计，负责人批准后执行 |
| G-2 | `selectByIdForUpdate`（设备行锁）不存在 | 新增 Mapper 方法（23 §5.2） |
| G-3 | 预约规则引擎（P1-P9）、冲突查询、日历/空闲时段计算 | 23 号文档接口与算法设计 |
| G-4 | 资质到期 Job 未实现 | 短期：P4 叠加 `expire_time` 判定（B2 裁决）；资质状态展示转换是否补 Job 属 INSTRUMENT-02 遗留任务（不阻塞 03，因 P4 强校验后功能正确性不受影响） |
| G-5 | 冻干批次（05）与维护时段维护人尚无写入方 | maintenance 本期由管理端手工录入（07 §2.10）；freeze_batch 属 05，P8 冲突查询先按"表存在即查"设计，05 落地前该表不存在 → 冲突查询需容错（23 §6.4） |

---

## 四、并发竞态审查（核心，阻断项判定）

任务单要求："预约侧设备行锁"不能仅停留在设计文字中，必须审查暂停写入侧是否使用兼容的锁或同步机制；若无法证明无竞态，列为阻断项。

### 4.1 暂停写入侧现状（代码证据）

`InstrumentSuspendServiceImpl#createSuspend`（INSTRUMENT-02 已上线代码）：

```text
1. Redisson 锁：instrument:suspend:{tenantId}:user:{userId}   ← 锁键 = 被暂停用户维度
2. 锁内事务 doCreate：
   a. selectActiveListByUser(userId) 重复覆盖校验
   b. suspendMapper.insert(ACTIVE)          ← 插入新行，不锁任何既有行
   c. G12 联动 qualification ACTIVE→SUSPENDED（条件更新）
3. 事务提交，释放锁
```

**关键事实**：暂停写入侧**没有任何数据库行锁**（无 `SELECT ... FOR UPDATE`）；它锁定的共享资源只有 Redisson 键 `suspendKey(tenantId, userId)`。它**不接触** `lab_instrument_device` 任何行。

### 4.2 竞态场景推演（若预约侧仅用设备行锁）

设 T1 = 预约创建（用户 A 预约设备 D），T2 = 暂停创建（对用户 A 下 ALL 暂停）：

```text
T1: BEGIN
T1:   SELECT device D FOR UPDATE            ← 拿到设备行锁
T1:   P5 查暂停（selectActiveCovering）→ 无  ← 此刻 T2 尚未提交
T2:   Redisson suspendKey(A) 获取成功        ← 暂停侧不需要设备行锁，不被 T1 阻塞
T2:   事务内插入 ACTIVE ALL + G12 联动
T2: COMMIT                                 ← 暂停已生效
T1:   冲突查询 → 无冲突
T1:   INSERT reservation (PENDING)
T1: COMMIT                                  ← 用户 A 带着生效中的 ALL 暂停成功创建预约
```

**结论：竞态窗口真实存在。** 设备行锁对 T2 无任何约束力（T2 不获取设备行锁），03 §8.1.1 强制约束 6 所述"借助设备行锁串行化"对"暂停创建 vs 预约创建"这一对并发**不成立**。依据任务单要求，此点**不得声称已解决**，列为阻断项 H-B1。

### 4.3 阻断项 H-B1 与消除方案 A（推荐，待裁决 B1）

**方案 A：预约创建共用暂停侧的用户级 Redisson 锁**

预约创建事务外层先获取与暂停创建**完全相同**的锁键 `instrument:suspend:{tenantId}:{预约发起人userId}`，锁内再开事务执行设备行锁 → P5 → 冲突 → 插入：

```text
T1: lock(suspendKey(tenant, A))            ← 与 T2 同键互斥
T1:   BEGIN
T1:     SELECT device D FOR UPDATE
T1:     P5 查暂停 → 此时不可能有并发暂停在途（T2 被本锁阻塞）
T1:     冲突查询 → INSERT → COMMIT
T1: unlock
T2: （等待 suspendKey(A)）→ 获取 → 插入暂停 → COMMIT → unlock
```

串行化性质证明：

| 交错 | 结果 |
| --- | --- |
| T2 先获取锁并提交 | T1 的 P5 读到 ACTIVE 暂停 → 预约被拒（正确） |
| T1 先获取锁并提交 | T2 后插入暂停 → 预约成立于"暂停登记之前"，属存量预约（是否追溯处理见 B3 裁决，与技术竞态无关） |
| 同锁内交错（检查后、提交前暂停生效） | **不可能**：暂停事务必须持同一把锁，而锁在预约事务提交后才释放 |

**锁顺序与死锁分析**：

| 并发对 | 锁资源 | 环 |
| --- | --- | --- |
| 预约(A,设备D) vs 预约(A,设备E) | 同一用户锁串行 | 无 |
| 预约(A,设备D) vs 预约(B,设备D) | 不同用户锁 + 同一设备行锁（DB 排队，单锁） | 无环 |
| 预约(A) vs 暂停创建(A) | 同一用户锁串行 | 无 |
| 预约(A) vs 暂停创建(B) | 不同用户锁；暂停侧无 DB 锁 | 无环 |
| 预约(A) vs 信用调整(A) | 用户锁 + 账户行锁（信用侧不获取用户锁）；信用侧资源仅账户行，预约侧不碰账户行 | 无环 |
| 预约(A) vs 资质审批(A 设备D) | 用户锁 + apply 行锁（审批侧）；互不获取对方资源 | 无环 |

**方案 A 的约束与残余风险**（须写入 23 号文档开发约束）：

1. **锁租约 10 秒固定、无续期**：预约创建全流程（取锁+事务+提交）必须在 10 秒内完成，否则锁先释放、保护退化。约束：事务内禁止调用文件上传、Excel、外部 API 等慢操作；验收时须做超时场景观察（24 批次 03-F）。
2. **锁等待无超时**：`lock()` 为无限等待，极端情况下请求堆积；第一期并发量低，可接受，记录为观察项。
3. **释放锁与事务提交顺序**：`transactionTemplate.execute` 返回后再释放锁（`lock(key, callable)` 已保证 callable 含事务执行完毕），提交先于解锁，无"解锁后事务未提交"窗口。
4. **冻干批次（05）**：批次创建同样要求"发起人有资质、未被暂停"（05 §4.1），05 实施时必须同样共用 `suspendKey` 锁，否则同类竞态在批次侧复现——列入 05 的前置约束（22 号文档 A 类记录）。

**备选方案（若 B1 否决方案 A）**：

| 方案 | 做法 | 不推荐原因 |
| --- | --- | --- |
| B：暂停侧补设备行锁 | SINGLE 暂停事务内 `SELECT device FOR UPDATE`；ALL 暂停锁用户全部 ACTIVE 资质设备行 | ALL 无法穷举锁（暂停后新过审资质不受锁保护），锁集合动态变化，正确性不可证 |
| C：预约侧轮询重验 | 插入后延迟重查暂停 | 引入不可靠的时间窗，非确定性 |
| D：暂停登记后作废该用户在途 PENDING 预约 | 暂停事务内条件更新预约表 | **改变暂停业务语义**（追溯既有预约），属 B3 业务裁决而非技术方案；若 B3 裁决"追溯"，可作为方案 A 的补充，不能替代 |

### 4.4 次级竞态（记录，不阻断）

| 并发对 | 分析 | 处置 |
| --- | --- | --- |
| 预约创建 vs 资质撤销（revoke） | P4 检查通过后、提交前资质被撤销 → 存量预约。撤销为低频管理操作，且撤销语义不含"追溯取消预约" | 接受窗口；若负责人要求强一致，可把撤销也纳入用户锁（独立裁决项，非本期必须） |
| 预约创建 vs 设备状态变更（置 FAULT/MAINTENANCE/DISABLED） | P1 检查后设备被置非 NORMAL → 存量预约。00 §十已定义"设备故障不自动取消既有预约，由负责人协商改期" | 已有冻结语义，无需额外锁 |
| 预约取消 vs 管理员调整/作废 | 条件更新 `WHERE status='PENDING'` + affectedRows（00 §8.2/8.3 冻结方案） | 沿用，无新增风险 |
| 预约创建 vs 维护时段创建 | 维护创建需冲突校验（07 §2.10）；双方均锁同一设备行 → 串行 | 无新增风险 |
| 预约创建 vs 规则变更（粒度调整/停用） | 00 §十：仅影响新建预约，既有预约不变 | 无需锁 |

---

## 五、INSTRUMENT-02 遗留观察影响分析（T-C1/C2/C3、T-V1/V2）

> 本节仅分析影响与建议，**不在本任务执行任何修复/授权**。集中裁决项与推荐方案见 22 号文档 B4~B7。

### 5.1 T-C1：报废设备可提交资质申请

- 现状证据：20 号报告 E3（设备1 SCRAPPED 申请成功，applyId=2）；`applyQualification` 仅校验设备存在，未校验设备状态。
- 对 03 的影响：预约准入 P1 会拦截 SCRAPPED 设备的预约（设备状态机 + 任务单规则 13），因此**报废设备无法通过预约暴露问题**；但"资质申请成功 → 永远无法预约"对用户是无效闭环，且资质数据存在语义噪音。
- 建议：资质申请侧补设备状态校验（非 NORMAL 拒绝申请，错误码新增），与预约 P1 对齐。属 INSTRUMENT-02 小增强，独立任务，待 B4 裁决后实施。

### 5.2 T-C2：ACTIVE ALL 暫停期间新过审资质保持 ACTIVE

- 现状证据：20 号报告（资质 id=1 联动 SUSPENDED、id=2 暂停期间过审仍 ACTIVE）；G13 裁决明确"暂停不拦截资质审核通过"，预约侧由 P5 拦截。
- 对 03 的影响：**无功能影响**——预约拦截依据是 `selectActiveCovering`（暂停表），与资质 status 无关；即使资质为 ACTIVE，P5 仍拦截。
- 建议：维持 G12 仅作为"当时生效资质的展示联动"（登记时点快照），不追求资质状态与暂停限制实时一致；03 设计文档明确"预约暂停判定唯一依据 = 暂停表覆盖判定，不得以资质 status=SUSPENDED 替代"（避免双重语义）。待 B5 确认。

### 5.3 T-C3：904 缺 `suspend:query` 前端有效权限

- 现状证据：菜单 13672（suspend:query）父级 13671 未授权 904 → `filterDisableMenus` 丢弃 → 前端权限集无该串；后端 `role_menu` 直查仍放行 `GET /suspend/my`（实测 200，仅本人数据）；前端"我的信用"页（`my-credit/index.vue`）内嵌暂停记录 Tab 并调用 `InstrumentSuspendApi`，实际可用。
- 对 03 的影响：无直接影响；但 03 的预约权限（`reservation:*`）部署时必须吸取教训——**授权按钮权限时必须连同父页面菜单一起授权**（03 SQL 设计稿中按"页面+按钮"成组授权，见 24 批次 03-F）。
- 建议：若维持现状（后端已放行、前端有入口），可不修；若要求前后端权限集严格一致，补授权 13671+13672 给 904（授权 SQL 需负责人批准）。待 B6 裁决。

### 5.4 T-V1：负责人双条件运行时补验方案（供后续授权后执行）

- 静态证据已充分（`canManageDevice` = 权限角色 ∨ manager 表 ACTIVE 业务关系；`auditApply`/`createSuspend` 显式调用）。
- 对 03 的影响：预约管理端（调整/作废/手工完成）与维护录入同样依赖 `canManageDevice`，INSTRUMENT-03 验收需构造"有权限无关系 / 有关系无权限"对照。
- 补验方案（两选一，需授权）：
  1. **推荐**：不动角色授权，直接在 `lab_instrument_manager` 插入一条测试用 `scope=DEVICE, target_id=2, manager_user_id=281, status=ACTIVE` 业务关系（授权 DML），验证 281 无 908 角色时对设备 2 的负责人操作被拒/被允；测后置 RELEASED 保留历史；
  2. 或临时给测试账号分配 908（需明确授权，违反任务边界 4 的默认禁止）。
- 03 验收矩阵将把该场景列为必测项（24 批次 03-F）。

### 5.5 T-V2：暂停超过 end_time 仍生效的隔离补验方案

- 需写入 `end_time` 为过去的 ACTIVE 行（DML，任务禁止）。
- 对 03 的影响：P5 判定语义直接继承 `selectActiveCovering`（无 end_time 条件），03 验收应包含该场景——**推荐方案**：通过已授权的写路径接口构造：暂停创建用**自定义 endTime**（合法接口参数）无法构造过去时间（`resolveEndTime` 校验 endTime>now），故仍需 DML 或新增测试后门（后者不推荐）。**授权后**用一条 `UPDATE lab_instrument_suspend SET end_time=过去 WHERE id=X` 即可，随后验证预约被 P5 拦截。列入 24 批次 03-F 可选验收项（需单独授权 DML）。

---

## 六、风险清单（进入开发前已知）

| # | 风险 | 等级 | 缓解 |
| --- | --- | --- | --- |
| R-1 | H-B1 竞态方案未裁决即开发 | **高（阻断）** | B1 裁决通过为开发前置条件 |
| R-2 | Redisson 锁 10s 固定租约，事务超时保护退化 | 中 | 事务短小约束 + 并发验收含超时观察 |
| R-3 | 资质到期 Job 缺失导致 status 失真 | 中 | B2 裁决 P4 叠加 expire_time；Job 缺口列入 02 遗留任务 |
| R-4 | 无任何设备开启 bookable/规则，联调缺数据 | 低 | 24 批次 03-F 明确测试数据准备清单（业务配置操作） |
| R-5 | 预约日历/时段选择前端无现成组件（01 §3.10） | 中 | 自研，排期见 24 批次 03-C/03-D |
| R-6 | 菜单授权重蹈 T-C3（按钮授权漏父页面） | 中 | 03 SQL 设计稿按"页面+按钮"成组授权并静态自查 |
| R-7 | U1/U2/U3 未裁决参数被误设默认值 | 高（合规） | P3 拦截（未配置不可预约）；04 批次前再次核对 |
| R-8 | maintenance 表本期新建但 freeze_batch（05）不存在，P8 三方冲突查询需容错 | 低 | 23 §6.4：表不存在时跳过该来源（逐表 try/存在性判断） |

---

## 七、进入 INSTRUMENT-03 的前置条件汇总

1. **B1**（阻断项 H-B1 消除方案 A）裁决通过；
2. **B2~B11**（22 号文档 B 类清单）一次性集中裁决完成；
3. DDL / 菜单 / 授权 SQL 执行授权另行申请（23 号文档仅设计，不执行）；
4. 测试数据准备授权（设备 bookable、规则配置属业务配置操作）。

**本任务到此为止：不启动预约业务代码开发，不执行数据库写入。**
