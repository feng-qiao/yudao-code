# INSTRUMENT-03 预约管理版范围收敛与简化报告（34号）

| 项目 | 内容 |
|------|------|
| **报告编号** | 34-INSTRUMENT-03-SCOPE-SIMPLIFY |
| **日期** | 2026-10-16 |
| **关联任务书** | TASK INSTRUMENT-03-SCOPE-SIMPLIFY-01（预约管理版范围收敛、并发简化与实施计划） |
| **负责人** | 青禾一（授权范围：代码修改 + H2 测试 + SQL 设计稿标注；绝对禁止：真实 labplatform DDL/DML/菜单写入/Redis 写入/Docker 创建启动/C7 开关开启） |
| **前置报告** | 32-INSTRUMENT-03-C 部署阻断修复与并发环境准备报告 |
| **本次交付状态** | 范围收敛 ✅ / 代码简化 ✅ / H2 全绿 ✅ (152/152) / 并发互斥 H2 证明 ✅ / SQL 设计稿标注 ✅ / 真实 MySQL 并发验证 ❌（未做） / 预约生命周期 ❌（未交付） |
| **总体结论** | **CONDITIONAL PASS**（详见 §9） |

---

## §0 执行边界声明（必读）

| 类别 | 数量 | 说明 |
|------|------|------|
| **真实 labplatform DDL** | 0 | CAP-A 两份 DDL 设计稿标注废弃，未执行；本批次无任何真实库结构变更 |
| **真实 labplatform DML** | 0 | 未写入任何业务数据 |
| **真实菜单写入** | 0 | 菜单 SQL 设计稿仅修订注释，未 apply |
| **真实 Redis 操作** | 0 | 未连接、未写入 |
| **Docker 创建/启动** | 0 | 未执行 |
| **C7 开关** | 保持关闭 | `lab.instrument.reservation.create-enabled` 默认 false，未开启 |
| **22~24 号冻结文档** | 无修改 | 收敛决策以本报告为准，冻结文档原文未动 |
| **H2 ≠ MySQL 声明** | **已在 §4.4 明确**：H2 并发证明通过不等同于真实 MySQL InnoDB 并发通过 |

---

## §1 真实实现状态

### §1.1 任务书定位

INSTRUMENT-03 收敛为**不连接硬件的预约管理功能**，保留：资格审核、人工暂停、开放预约时段、角色权限、预约生命周期。减少容量账本、Redis 锁、看门狗等复杂度。

### §1.2 三项收敛决策（负责人裁决，本批次全部落地）

| 决策 | 内容 | 落地状态 |
|------|------|----------|
| **① 容量 = 1 独占** | 彻底移除 CAP-A 容量账本（`daily_usage` / `capacity_occupation` 两表及全部 Service/Mapper/DO）；窗口仅定义"可预约时间范围"，无共享名额 | ✅ 已落地（代码零残留，SQL 设计稿标注废弃） |
| **② 仅数据库设备行锁** | 移除 Redis suspendKey 锁 / watchdog / D3 fail-fast；预约创建与暂停创建共用事务内首步 `SELECT ... FOR UPDATE` 设备行锁作为**唯一互斥锚点** | ✅ 已落地 + H2 并发互斥证明（§4.3） |
| **③ 单号兜底保留** | 保留 Redis INCR 单号生成 + `uk_reservation_tenant_no` 唯一索引兜底；D2 重试精确识别（cause 链小写匹配 `uk_reservation_tenant_no` 才重试，其他冲突原样抛出） | ✅ 已落地（含精确识别测试） |

### §1.3 保留功能的真实交付状态

| 功能 | 状态 | 说明 |
|------|------|------|
| 资格审核（INSTRUMENT-02） | ✅ 已交付 | 资质申请/审核/吊销/过期，P4 校验在创建链路内复核 |
| 人工暂停 | ✅ 已交付（本批改造） | SINGLE 单行 / ALL 全设备 id 升序行锁，与预约共用同一互斥锚点（§5.1） |
| 开放预约时段（规则 + 窗口） | ✅ 已交付 | booking-rule 粒度/时长/跨日 + booking-window 开放日/时段/目标日期段；窗口仅定义时间范围 |
| 角色权限 | ✅ 已交付 | 设备/平台 scope 数据权限（InstrumentScopeSupport）+ 菜单/按钮权限串 |
| 预约创建 | ✅ 已交付 | C7 开关 → 行锁 → P1~P9 全链路 + D2 单号重试 |
| 预约查询 | ✅ 已交付 | calendar / freeSlots / isOpen / my / get（他人 080 不泄露存在性） |
| **预约生命周期（取消/调整/完成/作废）** | ❌ **未交付** | Service 接口仅 create + 4 个查询；状态机 PENDING/FINISHED/CANCELED/VOIDED 的流转端点不存在（§6.2） |

---

## §2 保留 / 简化 / 删除 / 待裁决组件清单

### §2.1 保留（原样）

| 组件 | 说明 |
|------|------|
| 资格域全部（02） | 申请/审核/吊销/历史/信用账户流水 |
| 暂停域 | 业务校验不变；仅并发协议改为行锁（见 §2.2） |
| 规则 + 窗口域 | 窗口表 `capacity` / `used_count` 列保留**仅作历史展示**，不参与任何容量计算（零 DDL） |
| 角色权限 / 数据 scope | 不变 |
| 预约创建 P1~P9 校验链 | 校验语义不变 |
| 查询四接口 + my/get | 不变 |
| `ReservationNoRedisDAO`（INCR 单号） | 决策③保留 |
| `uk_reservation_tenant_no` 唯一索引 | 决策③保留（H2 `create_tables.sql` L401） |
| `InstrumentLockRedisDAO` | 仅服务 INSTRUMENT-01/02 的 manager/notice/qual/credit 四把锁，与预约链路无关，保留 |

### §2.2 简化（改造）

| 组件 | 改造前 | 改造后 |
|------|--------|--------|
| 预约互斥协议 | suspendKey Redis 锁(watchdog) → 事务 → 设备行锁（双层） | 事务 → 设备行锁（单层，唯一锚点） |
| 暂停创建并发协议 | 同上（Redis 锁 + 行锁） | 事务内首步行锁：SINGLE 锁目标设备；ALL 锁全部设备 id 升序 |
| 容量语义 | 窗口容量名额 + CAP-A 账本条件扣减 | 容量恒 1 独占，由 P8 时间冲突检测保证 |
| D2 单号重试 | catch `DuplicateKeyException` 即重试（识别过宽） | cause 链逐层小写匹配 `uk_reservation_tenant_no`，仅命中才重试；其他唯一键冲突原样抛出 |
| reservation 表 | 含 `window_id` 归属冗余列 | 移除该列（窗口 id 仅作创建时校验入参，不落行） |

### §2.3 删除（代码零残留）

| 删除项 | 范围 |
|--------|------|
| CAP-A `lab_instrument_booking_window_daily_usage` 表 | DO / Mapper / Service / H2 建表 / 真实库 DDL 设计稿（标注废弃）全部移除 |
| CAP-A `lab_instrument_reservation_capacity_occupation` 表 | 同上 |
| 窗口 `used_count` 条件扣减/回退 Mapper 方法 | 随 CAP-A 一并移除（列保留仅展示） |
| Redis suspendKey 锁 | `ReservationLockCoordinator` 内 Redis 编排、key 定义、`SUSPEND_LOCK_KEY` 前缀全部移除 |
| watchdog 续期 | `lockWithWatchdog` 方法及全部调用移除 |
| D3 fail-fast | `isLockHeldByCurrentThread` 提交前检查移除（锚点单一化后无锁可丢） |

### §2.4 待裁决

| 项 | 说明 |
|----|------|
| 真实 MySQL 并发验证方式 | 隔离环境（32 号已备配置，未启动）或其他负责人指定环境；启动需授权 |
| 生命周期批次拆分 | 取消/调整/完成/作废的优先级与批次划分（§10 建议） |

---

## §3 修改文件明细

### §3.1 主代码（service/dal）

| 文件 | 改动 |
|------|------|
| [ReservationLockCoordinator.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/ReservationLockCoordinator.java) | 收敛为仅 DB 行锁：TransactionTemplate → `selectByIdForUpdate` → 回调；类注释明确"事务内首步行锁、当前读不建快照"的唯一锚点语义 |
| [InstrumentReservationServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentReservationServiceImpl.java) | D2 精确识别（L101/L113/L468~476：cause 链小写匹配 `uk_reservation_tenant_no`）；接口注释改"事务 → 设备行锁，唯一互斥锚点"；上线边界声明更新 |
| [InstrumentSuspendServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentSuspendServiceImpl.java) | 创建改事务内首步行锁：ALL → `selectListForUpdate()`（id 升序）；SINGLE → `selectByIdForUpdate`，设备不存在显式拒绝（L110~119） |
| [InstrumentBookingRuleServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentBookingRuleServiceImpl.java) | 注释修订：设备行锁为唯一互斥锚点，本接口与预约/暂停共用同一行锁协议，不产生反向获取 |
| [InstrumentBookingWindowServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentBookingWindowServiceImpl.java) | L136：`used_count` 仅历史展示、不参与容量计算、保持原值不回写 |
| [InstrumentBookingWindowMapper.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/mysql/instrument/InstrumentBookingWindowMapper.java) | 删除 `updateUsedCount*` 条件扣减/回退方法；注释说明 |
| [InstrumentDeviceMapper.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/mysql/instrument/InstrumentDeviceMapper.java) | `selectByIdForUpdate`（FOR UPDATE 单行）/ `selectListForUpdate`（全设备 id 升序）（前序批次已备，本批未改） |
| [InstrumentReservationService.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentReservationService.java) | 接口注释锁协议与上线边界修订 |
| CAP-A 两表 DO/Mapper/Service | **整体删除**（文件级移除，git 工作区已无残留） |
| `ErrorCodeConstants.java` | 088 容量相关错误码随 CAP-A 清理（093 时间冲突承接独占语义） |

### §3.2 测试代码

| 文件 | 改动 |
|------|------|
| [Instrument03ConcurrencyTest.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument03ConcurrencyTest.java) | **新建**：4 个并发互斥证明用例（§4.3）；真实 `ReservationLockCoordinator` + H2 MVStore 行锁 + CountDownLatch 确定性编排 |
| [Instrument03CReservationCreateTest.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument03CReservationCreateTest.java) | 锁协调器 Mock 直通复刻"事务内行锁 → 回调"语义；新增 D2 精确识别两用例（`doAnswer().when()` 规避 Mockito 重 stub 陷阱） |
| [Instrument03DataLayerTest.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument03DataLayerTest.java) | 删除 `testWindowUsedCountConditionalUpdate`（CAP-A 方法已删）与 `testLockKeyFormat_and_tenantIsolation`（suspendKey 已删）；锁键前缀数组移除 `SUSPEND_LOCK_KEY`（剩 4 个） |
| [Instrument02ServiceTest.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument02ServiceTest.java) | 删除 `lockWithWatchdog` mock（方法已移除） |
| [create_tables.sql](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/resources/sql/create_tables.sql)（H2） | reservation 表移除 `window_id` 列；CAP-A 两表不再建；`uk_reservation_tenant_no` 保留（L373~401、L502~503 注释） |

### §3.3 SQL 设计稿（仅标注/注释修订，未执行）

| 文件 | 改动 |
|------|------|
| `sql/lab/20261016_instrument_03_capacity_u1_u5_final.sql` | 头部加【已废弃 · 2026-10-16 34 号收敛批次】块：两容量表 + window_id 均不得执行；真实库核验零交集无需回退 DDL；仅历史留档 |
| `sql/lab/20261016_instrument_03_capacity_daily_design.sql` | 同上废弃头 |
| `sql/lab/20261016_instrument_03b_booking_config_menu_design.sql` | §6 第 2 条改写：声明 CAP-A 已废弃、两份 DDL 设计稿不得执行；菜单 13674/13675/13676 + 套餐 114 授权设计内容不受影响 |

---

## §4 测试用例结果

### §4.1 全量结果（`mvn clean test -pl yudao-module-lab -o`）

```
Tests run: 152, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

| 测试类 | 用例数 | 结果 |
|--------|--------|------|
| Instrument02ServiceTest | 26 | ✅ |
| Instrument03BBookingRuleWindowTest | 18 | ✅ |
| **Instrument03ConcurrencyTest** | **4** | ✅ |
| Instrument03CReservationCreateTest | 32 | ✅ |
| Instrument03DataLayerTest | 21 | ✅ |
| Instrument03LockCoordinatorTest | 3 | ✅ |
| PlasmidStorageServiceImplTest | 17 | ✅ |
| RegisterApplyServiceImplTest | 31 | ✅ |

### §4.2 D2 精确识别用例（03C 内）

| 用例 | 场景 | 结果 |
|------|------|------|
| 单号 uk 冲突重试 | 第一次 `uk_reservation_tenant_no` 冲突 → 外层重试新号成功 | ✅ |
| 非单号唯一键冲突不重试 | cause 链不含 `uk_reservation_tenant_no` 的 `DuplicateKeyException` → 原样抛出、重试未触发 | ✅ |

### §4.3 并发互斥 H2 证明（Instrument03ConcurrencyTest，决策②的强制证据）

| 用例 | 场景 | 断言 | 结果 |
|------|------|------|------|
| `testSuspendVsReservation_serialized_noFalsePass` | 主线程持锁写 ACTIVE 暂停 → 子线程解锁后走 P5 | 子线程必见暂停 → 086，**不误放行** | ✅ |
| `testSameSlot_concurrent_exactlyOneSuccess` | 4 线程同设备同时段并发创建 | 恰 1 成功，其余 093 时间冲突 | ✅ |
| `testAdjacentSlots_concurrent_bothSuccess` | 相邻时段并发 | 都成功（无误伤） | ✅ |
| `testDifferentDevices_parallel_noMutualBlocking` | 不同设备闩锁确定性并行 | 互不阻塞 | ✅ |

技术要点：真实 `ReservationLockCoordinator` Bean + H2（`MODE=MYSQL`、MVStore 行锁、READ COMMITTED）+ CountDownLatch 编排（主线程 `mainInLock` 闩锁保证先获锁，规避用例自身竞态）。

### §4.4 边界声明（任务书强制）

> **H2 并发证明通过 ≠ 真实 MySQL 并发通过。** H2 MVStore 行锁语义与 MySQL 8.0.12 InnoDB（RR 隔离、next-key lock）存在差异；真实 MySQL 并发验证（含暂停/预约交错、同时段独占、D2 重试命中）为后续部署前门槛，本批次未执行。

### §4.5 过程事件记录：ECJ 编译污染

本批次排查中发现 IDE（Eclipse JDT 语言服务器）会将含 "Unresolved compilation problems" 的损坏 `.class` 写入 `target/classes`；Maven 增量编译因 class 新于 source 而跳过，表现为全量测试 124/152 错误（含未改动类，`NoClassDefFoundError` 仅简单名）。根因经脱离 Maven 复现 + `javap` 字节码确认。**对策：每次复跑前必须 `mvn clean`**；最终全绿结果即在 clean 环境下取得。该污染会随 IDE 持续再产生，不改变源码正确性。

---

## §5 Redis 锁与容量账本存废证据

### §5.1 Redis suspendKey 锁废除证据（决策②）

**任务书依据**："优先数据库事务+设备行锁，只有现有数据库方案无法满足实际并发要求时才保留 Redis 锁；不得直接删除锁后宣称安全，需并发测试证明。"

**单一锚点串行化论证**（已写入 [ReservationLockCoordinator.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/ReservationLockCoordinator.java) 类注释）：

1. 预约创建与暂停创建均在**事务内首步**获取同一设备行锁（`SELECT ... FOR UPDATE`）；
2. 行锁是当前读（locking read），**不建立 RR 一致性快照**——事务内后续 P3/P4/P5/P8 一致性读的快照必然建立在行锁获得**之后**；
3. 因此两条路径在设备行上**全序串行**：先获锁者先提交，后获锁者的校验快照必见前者已提交的暂停/预约写入；
4. ALL 范围暂停按 id 升序锁全部设备行，与单设备路径锁序一致，无死锁环；
5. "暂停已生效但预约被错误放行"的交错窗口不存在。

**并发测试证据**：§4.3 用例①直接证明"持锁写暂停 → 后发预约必见暂停 → 086 拒绝"；用例②证明同时段独占。H2 层面互斥成立，满足"不得未证删锁"的前置条件；真实 MySQL 层面验证留作部署前门槛（§4.4）。

**D3/watchdog 自然消解**：锚点单一化后不存在"Redis 锁丢失但事务仍提交"的所有权竞态，watchdog 续期与 D3 fail-fast 检查随之无对象，一并移除。

### §5.2 CAP-A 容量账本废除证据（决策①）

**业务定性**：窗口业务为"仅定义可预约时间范围"，非"共享名额"——任务书要求不得擅自假定容量为 1 或引入额外容量表，负责人裁决容量恒为 1 独占。

**独占充分性论证**：容量 1 独占下，同一设备同一时段只允许一条有效预约。P8 时间冲突检测（[ReservationConflictChecker.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/ReservationConflictChecker.java) L26~27）已覆盖：

- reservation：`status IN (PENDING, FINISHED)` 占用；`CANCELED / VOIDED` 释放；
- maintenance：`status = ACTIVE` 占用。

设备行锁保证 P8 检测与写入之间无并发插入（§5.1），条件扣减账本（`daily_usage` / `capacity_occupation`）在容量 1 语义下为纯冗余。

**零回退成本**：真实库核验两份 CAP-A DDL 设计稿**执行次数为 0**、与真实库零交集，废弃仅需标注，无需回退 DDL。

### §5.3 单号兜底保留依据（决策③）

Redis INCR 单号生成 + `uk_reservation_tenant_no` 唯一索引兜底不属复杂度削减对象：INCR 冲突概率极低但存在，唯一索引是最后防线；D2 外层重试（每次重试 = 新事务 + 新行锁 + 新单号）仅在 cause 链精确命中该索引名时触发，避免对其他唯一键冲突的误重试。

---

## §6 FINISHED 占用规则说明 + 后续缺失预约功能

### §6.1 FINISHED 占用规则

现行冲突检测规则（22 号冻结 C3，本批次未改）：`status IN (PENDING, FINISHED)` 的预约**占用**其时段，`CANCELED / VOIDED` 释放。

语义：FINISHED（已完成）预约是**已发生的历史占用事实**——其时段不可被新预约覆盖写入，否则日历/空闲槽将显示"该时段空闲"并允许回溯性重叠，破坏占用历史的可信性。PENDING（待使用）同理占用。只有 CANCELED（取消）/ VOIDED（作废）才是"未发生/已释放"的时段。

**当前缺口**：由于生命周期端点未交付，预约创建后停留在 PENDING，没有任何代码路径将其推进到 FINISHED/CANCELED/VOIDED——即当前所有已建预约将**永久占用**其时段。这是上线前必须补齐的阻断项，而非规则缺陷。

### §6.2 后续缺失预约功能（合并自 22/23/24 号冻结范围）

| 缺失项 | 说明 | 优先级建议 |
|--------|------|-----------|
| **取消（cancel）** | 本人/负责人取消 PENDING → CANCELED，释放时段；需时限规则（开始前可取消） | 高（没有取消则时段永久占用） |
| **完成（complete/finish）** | 到点或手动 PENDING → FINISHED；可与审核/签核联动 | 高 |
| **调整（adjust）** | 改期/改时长 = 行锁内复核 P1~P9 + 时段释放与再占用 | 中 |
| **作废（void）** | 管理侧作废（违规/爽约），VOIDED 释放时段，可联动信用 | 中 |
| 状态机约束 | 四状态流转合法迁移表 + history 记录（`InstrumentReservationHistoryDO` 已备 CREATE 动作） | 随各端点同步 |
| 生命周期并发协议 | 复用同一设备行锁锚点（事务内首步行锁 → 状态校验 → 写入） | 设计已前置 |

---

## §7 SQL 设计稿清单

| 文件 | 性质 | 状态 |
|------|------|------|
| `sql/lab/20261016_instrument_03_capacity_u1_u5_final.sql` | CAP-A 最终 DDL 设计稿 | **已废弃**（34 号标注，禁止执行，仅历史留档） |
| `sql/lab/20261016_instrument_03_capacity_daily_design.sql` | CAP-A 日用量设计稿 | **已废弃**（同上） |
| `sql/lab/20261016_instrument_03b_booking_config_menu_design.sql` | booking-config 菜单 13674/13675/13676 + 套餐 114 授权设计稿 | 有效（CAP-A 关联段已修订声明）；未执行，待授权 |
| `sql/lab/20261015_instrument_03_schema.sql` | 03 主 schema（前序批次） | 真实库已建部分以 28 号验收为准；reservation 表 `window_id` 列收敛后的差异为**预留裁决项**（H2 已移除该列；真实库是否回补 DDL 由负责人在部署前裁决，本报告不发起） |

---

## §8 正式库 / Redis / Docker 操作记录

| 类别 | 操作次数 | 明细 |
|------|----------|------|
| 真实 labplatform DDL | 0 | 无 |
| 真实 labplatform DML | 0 | 无 |
| 真实菜单写入 | 0 | 无 |
| 真实 Redis 读/写 | 0 | 无 |
| Docker 创建/启动 | 0 | 无 |
| C7 开关变更 | 0 | 保持 false |
| 本批次全部验证环境 | — | H2 内存库（`jdbc:h2:mem:testdb;MODE=MYSQL`），Maven 离线，未触任何外部服务 |

---

## §9 结论：CONDITIONAL PASS

| 维度 | 判定 | 依据 |
|------|------|------|
| 范围收敛（不连硬件，保留五功能） | ✅ PASS | §1.3 |
| CAP-A 容量账本移除 | ✅ PASS | 代码零残留 + 独占充分性论证 + 真实库零交集（§5.2） |
| Redis 锁/watchdog/D3 移除 | ✅ PASS（H2 层面） | 单一锚点论证 + H2 并发互斥 4 用例（§4.3/§5.1） |
| D2 单号重试精确识别 | ✅ PASS | 代码 + 双向用例（§4.2） |
| H2 全量测试 | ✅ PASS | 152/152（§4.1） |
| SQL 设计稿处置 | ✅ PASS | 废弃标注 + 菜单稿修订（§7） |
| **真实 MySQL 并发验证** | ❌ **未做（条件项）** | H2 MVStore READ COMMITTED ≠ MySQL InnoDB RR/next-key lock（§4.4） |
| **预约生命周期（取消/调整/完成/作废）** | ❌ **未交付（条件项）** | 缺失则已建预约永久占用时段（§6.1） |
| C7 上线开关 | 保持关闭 | 两项条件满足前必须保持 false |

**结论**：范围收敛与简化本身成立、H2 层面全部证据齐备，判定 **CONDITIONAL PASS**。两项条件——①真实 MySQL 并发验证通过；②预约生命周期端点交付——均未满足前，C7 开关不得开启，预约创建端点不得对外放行。H2 通过不得等同于真实 MySQL 并发通过。

---

## §10 合并剩余工作清单

| # | 事项 | 类型 | 依赖/门槛 | 来源 |
|---|------|------|-----------|------|
| R1 | **预约生命周期交付**：取消（优先）/ 完成 / 调整 / 作废 + 状态机 + history 动作 | 开发 | 复用设备行锁锚点协议（§6.2）；取消不交付则时段永久占用 | 34 §6.2 |
| R2 | **真实 MySQL 并发验证**：暂停/预约交错、同时段独占、D2 重试命中、ALL 暂停与多设备预约交织 | 验证 | 隔离环境启动需授权（32 号已备 docker-compose + 20 项矩阵，未启动）或负责人指定环境 | 34 §4.4 / 32 §5 |
| R3 | C7 开关开启评估 | 裁决 | R1 + R2 均通过后 | 34 §9 |
| R4 | reservation 表真实库 schema 对齐裁决：H2 已移除 `window_id`，真实库是否回补 DDL | 裁决 + DDL | 部署前；若回补需独立逐条执行（MySQL DDL 隐式提交） | 34 §7 |
| R5 | booking-config 菜单 SQL（13674/13675/13676 + 套餐 114）apply | DML | 负责人书面授权；§0 预检全绿方可执行 | 32 §4 / 34 §7 |
| R6 | ECJ 编译污染防护：团队约定 lab 模块测试一律 `mvn clean test`，或 IDE 关闭自动构建输出到 target | 流程 | 无（立即可做） | 34 §4.5 |
| R7 | 冻结文档（22/23/24）与 34 号收敛口径的合并修订：锁协议双层→单层、CAP-A 章节标废弃 | 文档 | 负责人确认后可批量修订 | 34 全文 |
| R8 | 前端预约页面对齐：容量名额相关 UI 文案去除（容量恒 1）、生命周期操作入口（随 R1） | 前端 | R1 接口定型后 | 34 §6 |

---

**报告完毕。**
