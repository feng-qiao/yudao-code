# INSTRUMENT-03 规则冻结与 03-A 数据层实施报告

> 任务：TASK INSTRUMENT-03-DECISION-FREEZE-01-R1（V1.1，2026-10-15）
> 执行日期：2026-10-15
> 阶段：INSTRUMENT-03 启动阶段（规则冻结 + 03-A 数据层）
> 数据库权限：**只读核验；未执行任何真实数据库写入（DDL/DML/授权均未执行）**

---

## 一、任务范围与执行边界

### 1.1 本任务实际完成范围

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 第一阶段 | 21/22/23/24/09 号文档 + 现有 INSTRUMENT-01/02 代码只读核验 | 完成 |
| 第二阶段 | 将 B1~B11 正式裁决写入 22 号文档（冻结基线），同步修订 23/24 号文档 | 完成 |
| 第三阶段 | 实施 03-A：SQL 设计稿 + 5 DO + 6 枚举 + Mapper + 冲突检查器 + 部分条件更新 | 完成 |
| 第四阶段 | 后端编译 + 隔离测试（H2 内存库） | 完成（测试全绿） |
| 第五阶段 | SQL 设计稿 12 项审查 | 完成（见 §六） |
| 交付 | 本报告 | 完成 |

### 1.2 边界遵守情况

- **未执行**真实 `labplatform` 库的 DDL / DML；**未执行** 菜单或角色授权 SQL；**未**自动分配 908 角色。
- **未**修改或删除既有设备 id=1/2、manager 3 行及 INSTRUMENT-01/02 业务数据。
- **未**创建真实业务测试数据；测试全部运行于 H2 内存库。
- **未**启动 03-B/03-C/03-D/03-E/03-F 功能开发；**未**创建 `freeze_batch` 表或维修工单功能。
- **未**实现自动完成、自动爽约、自动扣分、自动签到/签退、暂停自动到期任务。
- SQL 脚本仅为**设计稿**，未执行。

---

## 二、B1~B11 正式裁决落实矩阵

| 编号 | 裁决要点 | 落实位置 | 03-A 落实状态 |
| --- | --- | --- | --- |
| **B1** | 双层锁 `suspendKey → 设备行锁`；不得反向获取；须覆盖事务至提交；10s 租约+埋点不构成证明；不能证明则 HOLD | 23 §7.4/§7.5；`InstrumentDeviceMapper.selectByIdForUpdate`；`InstrumentLockRedisDAO` 现状 | **部分落实 + HOLD**：锁键格式/`selectByIdForUpdate` 已备；**并发互斥覆盖提交无法证明 → 03-C 并发验收 HOLD**（§七） |
| **B2** | P4 叠加 `status='ACTIVE'` 且 `expire_time IS NULL OR expire_time > now`（NULL=长期有效） | 02 §3.7 字段；23 §5.3 空值核实表 | **文档落实**；P4 编码属 03-C（本批未提前实现） |
| **B3** | 暂停不追溯取消既有预约；调整必须重跑暂停校验；仍遵 B1 锁序 | 22 §五；23 §6.6 注释 | **文档落实**（调整复核属 03-C） |
| **B4** | 资质申请不得绕过设备状态限制（报废设备不开新资质路径） | 22 §五 | **文档落实**（INSTRUMENT-02 若不一致按最小修复，属后续核对项） |
| **B5** | 资质状态与暂停状态分离，互不自动改写 | 22 §五 | **文档落实** |
| **B6** | 保留“我的信用”本人查询；不向普通用户开放他人暂停记录/管理端范围 | 22 §五 | **文档落实** |
| **B7** | `allow_cross_day` 保留；DDL/DO 一致；默认不允许跨天但不写库默认值 | SQL §1.3 + §2.4；`InstrumentBookingRuleDO.allowCrossDay`（`Boolean` 可空无默认）；单测 `testAllowCrossDay_modelMapping` | **代码 + SQL 落实**；H2 与 DDL 一致（`bit DEFAULT NULL`），业务层 `Boolean.TRUE.equals()` 判定 |
| **B8** | 单号 `R+yyyyMMdd+5位序列`；核对依赖/原子性/容量/唯一索引兜底；不得宣称“天然不重复” | `ReservationNoRedisDAO`（Lua INCR + TTL、`%05d` 补零、上限 99,999 抛错）；SQL `uk_reservation_tenant_no`；单测 4 项 | **代码 + SQL 落实**；唯一性由 DB 唯一索引 + 03-C 重试兜底，**真实 Redis 并发原子性 → 03-C 待验收** |
| **B9** | `904`=普通用户 / `908`=instrument_device_manager / `906`=lab_admin，严禁混用；后端独立权限+数据范围；本任务不生成授权 SQL | 22/23/24 号文档角色定义统一 | **文档落实**；代码仅在 `OperatorRoleEnum` 使用 USER/MANAGER/ADMIN（运行时角色 ID 判定属 03-D/03-F） |
| **B10** | 不为 U1/U2/U3 擅自设参；未配置=不可预约；不得硬编码 | SQL §1.3（`granularity_minutes`/`min_duration_minutes` 保持 NULL 无默认）+ §4 说明；`InstrumentBookingRuleDO` 对应字段可空 | **SQL/代码落实**（不插入任何 DML） |
| **B11** | finish 显式无自动完成、重复拒绝；维护不静默覆盖、重叠 PENDING 拒绝创建 | SQL §1.5 注释；`InstrumentReservationMapper.updateFinishIfPending`（仅 PENDING、0 行拒绝）；`InstrumentMaintenanceMapper`；单测 `testFinishIfPending`/`testOccupied_maintenanceActive...` | **Mapper 条件更新落实**；维护重叠拒绝创建属 03-E，finish 编排属 03-D |

---

## 三、21~24、09 号文档核验与修订记录

### 3.1 文件真实路径核验（以实际文件为准）

| 编号 | 实际文件名 | 版本（本次） |
| --- | --- | --- |
| 21 | `21-INSTRUMENT-03-预约模块开发前核验报告.md` | V1.0（未修订，作为输入核验） |
| 22 | `22-INSTRUMENT-03-预约业务规则冻结草案.md` | **V2.0（冻结基线，新增第五章 B1~B11 正式裁决记录）** |
| 23 | `23-INSTRUMENT-03-数据库与接口设计.md` | **V2.0（B1~B11 落地）** |
| 24 | `24-INSTRUMENT-03-开发实施任务分批方案.md` | **V2.0（裁决依赖更新）** |
| 09 | `09-开发计划与验收设计.md` | 未修订（作为验收基线引用） |

目录：`E:\lixin\dev\doc\03-仪器管理\`。

### 3.2 核验结论（重点章节）

- **22 号**：第一章~第四章为 V1.0 草案原文（保留追溯），**第五章为 2026-10-15 负责人正式裁决记录**；B1~B11 均标注“负责人已裁决”并记录裁决日期。
- **23 号**：§2.2~2.6（DDL）、§3.2（Mapper 清单）、§3.3（冲突检查器）、§5.2（错误码）、§5.3（B2 空值核实）、§6.2~6.6（条件更新 SQL）、§7.4/§7.5（锁安全性证据 / 单测范围）、§九（裁决落实对照）已按裁决修订。
- **24 号**：批次总览、03-A~03-F 详表、裁决清单已修订；明确 **03-A 关闭条件 = 负责人授权执行 DDL + 回执行结果 + 执行后只读核验**；03-C 并发验收 HOLD 条件写入。
- **09 号**：INSTRUMENT-03 六条验收标准（①并发仅 1 条成功 ②相邻不冲突 ③维护不可预约 ④取消/调整 ⑤未配置不可预约 ⑥无自动 NO_SHOW/扣分）**未改动**，作为 03-C/03-D/03-E 验收基线引用。

### 3.3 修订原则遵守

- B1~B11 标记“负责人已裁决”并记录裁决日期（2026-10-15）。
- 保留 V1.0 原始表述（第一~四章），裁决结论单列第五章，可双向追溯。
- 未删除原有证据、未覆盖既有报告、未创建易混淆的重复版本。

---

## 四、角色 ID 统一结果

| 角色 ID | 业务含义 | 角色编码 | 说明 |
| --- | --- | --- | --- |
| `904` | 普通用户 | ——（普通用户） | 仅操作自身授权范围内预约 |
| `908` | 仪器设备负责人 | `instrument_device_manager` | 须同时满足权限要求 + 有效设备管理关系；**本身不授予全局设备管理范围** |
| `906` | 平台管理员 | `lab_admin` | 按既定管理员权限执行管理操作 |

- **906 与 908 严禁混用**，已在 22/23/24 号文档统一。
- 权限判定：普通用户限自身授权范围；908 需叠加有效设备管理关系；菜单可见 ≠ 后端授权成功（后端独立数据范围校验）。
- 本任务**未**生成、未执行任何菜单/角色授权 SQL。

---

## 五、03-A 新增和修改文件清单

### 5.1 新增（Java 主代码）

| 类型 | 文件（相对 `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/`） |
| --- | --- |
| DO（5） | `dal/dataobject/instrument/InstrumentReservationDO.java`、`InstrumentReservationHistoryDO.java`、`InstrumentBookingRuleDO.java`、`InstrumentBookingWindowDO.java`、`InstrumentMaintenanceDO.java` |
| 枚举（6） | `enums/instrument/ReservationStatusEnum.java`、`ReservationActionEnum.java`、`OperatorRoleEnum.java`、`MaintenanceStatusEnum.java`、`MaintenanceSourceEnum.java`、`WindowStatusEnum.java` |
| Mapper（5） | `dal/mysql/instrument/InstrumentReservationMapper.java`、`InstrumentReservationHistoryMapper.java`、`InstrumentBookingRuleMapper.java`、`InstrumentBookingWindowMapper.java`、`InstrumentMaintenanceMapper.java` |
| Service（1） | `service/instrument/ReservationConflictChecker.java` |
| Redis DAO（1） | `dal/redis/ReservationNoRedisDAO.java`（B8 单号，Lua INCR + TTL） |

### 5.2 修改（Java 主代码）

| 文件 | 变更 |
| --- | --- |
| `dal/mysql/instrument/InstrumentDeviceMapper.java` | 新增 `selectByIdForUpdate(Long id)`（`... AND deleted = 0 FOR UPDATE`，B1 设备行锁） |
| `enums/ErrorCodeConstants.java` | 新增 `INSTRUMENT_RESERVATION_NO_GEN_FAILED`（`1_002_004_099`），位于已用最大 079 之后，无冲突 |

### 5.3 新增（SQL 设计稿，未执行）

| 文件 | 内容 |
| --- | --- |
| `sql/lab/20261015_instrument_03_schema.sql` | 三段式（§0 只读预检 / §1 五表 DDL `CREATE TABLE IF NOT EXISTS` / §2 执行后验收）+ §3 字段↔DO 对照 + §4 执行顺序/前置/失败停止/回滚风险 |

### 5.4 新增/修改（测试）

| 文件 | 变更 |
| --- | --- |
| `src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument03DataLayerTest.java` | 新增，23 个测试方法 |
| `src/test/resources/sql/create_tables.sql` | 追加 5 张 03 表（H2 语法，含 `uk_reservation_tenant_no`/`uk_rule_tenant_device` 唯一约束） |
| `src/test/resources/sql/clean.sql` | 追加 5 行 DELETE |

### 5.5 文档（修订）

见 §三（22/23/24 号 V2.0）。

---

## 六、SQL 设计稿字段对照表及风险清单

脚本：`sql/lab/20261015_instrument_03_schema.sql`（**设计稿，未执行**）。

### 6.1 五表字段↔DO 对照（逐表结论）

| 表 | 期望列数 | DDL 实际列数 | 关键字段 ↔ DO | 结论 |
| --- | --- | --- | --- | --- |
| `lab_instrument_reservation` | 24 | 24 ✅ | `reservation_no→reservationNo` / `device_id→deviceId` / `start_time/end_time→startTime/endTime(LocalDateTime)` / `duration_minutes→durationMinutes(Integer)` / `status→status(String)` / `qualification_id→qualificationId` + 6 公共列 | 一致 |
| `lab_instrument_reservation_history` | 21 | 21 ✅ | `reservation_id→reservationId` / `action→action` / `operator_role→operatorRole` / `after_status→afterStatus` + 6 公共列 | 一致 |
| `lab_instrument_booking_rule` | 20 | 20 ✅ | `granularity_minutes/min_duration_minutes→Integer(可空)` / **`allow_cross_day→Boolean(bit(1) NULL)`** / `enabled→Boolean` + 6 公共列 | 一致（B7/B10） |
| `lab_instrument_booking_window` | 20 | 20 ✅ | `target_date_start/end→LocalDate` / `capacity/used_count→Integer` / `status→status` + 6 公共列 | 一致 |
| `lab_instrument_maintenance` | 15 | 15 ✅ | `start_time/end_time→LocalDateTime` / `source_type→sourceType` / `source_id→sourceId(Long)` / `status→status` + 6 公共列 | 一致 |

五表均含 `TenantBaseDO` 六列（`tenant_id/deleted/creator/create_time/updater/update_time`）；`deleted bit(1) NOT NULL DEFAULT b'0'`。DDL 列数、类型、可空性与 DO 完全一致（H2 测试表 `create_tables.sql` 亦与正式 DDL 逐列对齐）。

### 6.2 关键冲突 SQL 逐项审查结论

| 审查项 | 结论 | 证据 |
| --- | --- | --- |
| 相邻边界 `[a,b)` 与 `[b,c)` 不冲突 | PASS | 条件为 `start_time < reqEnd AND end_time > reqStart`（严格不等），`testConflict_adjacent_noConflict` 通过 |
| 交叉 / 包含 / 被包含 冲突 | PASS | 同一不等式对三种几何关系均成立，3 个用例通过 |
| `FINISHED` 继续占用 | PASS | `OCCUPIED_STATUS_SQL = 'PENDING','FINISHED'`，`testOccupied_finishedOccupies` 通过 |
| `CANCELED` / `VOIDED` 释放 | PASS | 不在 IN 列表内，`testReleased_canceled_and_voided` 通过 |
| 维护 `ACTIVE` 占用 / `CANCELED` 释放 | PASS | `maintenance` 冲突 SQL `status='ACTIVE'`，`testOccupied_maintenanceActive...` 通过 |
| 条件更新 affectedRows=0 拒绝 | PASS | finish/cancel/void/adjust/window 五组条件更新均有 0 行断言 |
| `device_id` 条件参与冲突查询 | PASS | `testConflict_deviceScoped`（不同设备不冲突）通过 |
| 索引支持冲突查询 | PASS | `idx_device_time(device_id,start_time,end_time,status)` 覆盖冲突 SQL 全部条件列 |
| 状态字段与枚举一致 | PASS | reservation/history/window/maintenance 状态取值与 6 个枚举一一对应 |
| MySQL 版本兼容 | PASS | MySQL 8.0.x；仅用 `CREATE TABLE IF NOT EXISTS`、`bit(1)`、`datetime`、`utf8mb4` 等 8.0 兼容语法 |
| 脚本含执行前后 SELECT | PASS | §0 预检（0.1~0.4.4）+ §2 验收（2.1~2.6） |
| 无危险 DROP/TRUNCATE/清理语句 | PASS | 全脚本仅 `CREATE TABLE IF NOT EXISTS` 与只读 `SELECT`，无 DROP/TRUNCATE/DELETE/UPDATE |
| 全流程未执行真实库写入 | PASS | 见 §十 |

### 6.3 风险清单

| 风险 | 等级 | 处理 |
| --- | --- | --- |
| 脚本为设计稿，尚未执行 → DDL 实际列数/索引待执行后核验 | 中 | 脚本 §2 已内置执行后 SELECT，回填即可闭环 |
| 06/05 表未建（`freeze_batch`/`repair_order`）→ `source_type='REPAIR'`、freeze 开关为预留 | 低 | 已声明为 03/05/06 分阶段，脚本不含相关表 |
| B1 并发互斥无法证明 | **高（阻断）** | 见 §七，03-C HOLD |

---

## 七、锁安全性分析、证据、结论及未解决项

### 7.1 现状证据

- 现有分布式锁工具类 `dal/redis/InstrumentLockRedisDAO.java`（INSTRUMENT-01/02 在用）：
  - [InstrumentLockRedisDAO.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/redis/InstrumentLockRedisDAO.java#L43-L57) 使用 `RLock lock = redissonClient.getLock(key); lock.lock(LOCK_LEASE_MILLIS, TimeUnit.MILLISECONDS);`，`LOCK_LEASE_MILLIS = 10_000L`。
  - 10.1 该写法为**固定租约**：显式传入 leaseTime 会**关闭 Redisson 看门狗（watchdog）自动续期**。
  - 10.2 锁释放写在 `finally`，但 **`finally` 仅保证调用路径释放，不保证“锁在 DB 事务提交前仍有效”**。
  - 10.3 租约 10 秒到期后，**另一线程可获取同一 key 锁**；若原持锁线程此时仍在执行 DB 事务，则可能“失锁后继续提交”，**互斥不覆盖至提交**。
- 设备行锁：`InstrumentDeviceMapper.selectByIdForUpdate`（`FOR UPDATE`），事务边界依赖调用方的 `@Transactional`（**03-C 才编排**）。
- 暂停锁键：`InstrumentLockRedisDAO.suspendKey(tenantId, userId)`（`instrument:suspend:{tenant}:user:{userId}`），租户隔离，键格式与 22/23 §7.5 一致。
- **综合：现有 `RLock.lock(leaseTime)` 无法证明互斥持续到数据库提交。**

### 7.2 结论

| 项 | 结论 |
| --- | --- |
| 锁键协议（键格式/租户隔离/前缀唯一） | PASS（`testLockKeyFormat_and_tenantIsolation`、`testLockKeyPrefixes_mutuallyDistinct` 通过） |
| 锁顺序 `suspendKey → 设备行锁` 固定、不反向 | PASS（文档 + 键设计落实；端到端代码属 03-C） |
| 互斥覆盖至 DB 事务提交 | **无法证明 → HOLD** |
| `10s 租约 / 有告警` 作为安全性证明 | **不成立，已明确拒绝** |

### 7.3 未解决项（03-C 才能闭环）

1. 将固定租约改为**看门狗续期**（不传 leaseTime，或按事务最长耗时配置并配套续期），确保锁持有覆盖事务提交。
2. 建议在**锁内提交事务**、锁释放晚于 `commit`，避免“事务外执行 / 提前提交”路径；需固化提交与释放的先后顺序。
3. 需真实多线程并发测试（互斥、锁顺序、异常路径释放）——H2 环境无法验证，属 03-C。
4. 不得为实现方案 A 擅自修改 INSTRUMENT-02 已冻结的资质/信用/暂停业务语义。

> **B1 为 03-C 预约创建核心的阻断项。03-A 已完成静态核验与证据收集；03-A 不得提前实现或宣称完成 03-C 的并发保证。**

---

## 八、编译命令、退出码和结果

| 项 | 值 |
| --- | --- |
| 命令 | `mvn -o -pl yudao-module-lab test-compile` |
| 工作目录 | `e:\lixin\dev\ruoyi-vue-pro` |
| 结果 | **BUILD SUCCESS** |
| 退出码 | **0** |
| 本批引入错误 | 无（首次编译即通过） |
| 既有错误 / 环境问题 | 无 |

---

## 九、单测命令、实际执行结果及未覆盖项

### 9.1 执行记录

| 项 | 值 |
| --- | --- |
| 命令 | `mvn -o -pl yudao-module-lab test -Dtest=Instrument03DataLayerTest -DfailIfNoTests=false` |
| 测试基座 | `BaseDbUnitTest`（H2 内存库，`MODE=MYSQL`）+ `application-unit-test.yaml`；`@Import({ReservationConflictChecker.class})` |
| 结果 | **Tests run: 23, Failures: 0, Errors: 0, Skipped: 0** |
| 结果 | **BUILD SUCCESS** |

### 9.2 覆盖矩阵（对应任务书 §6.2 七项）

| 任务书要求 | 用例 | 状态 |
| --- | --- | --- |
| ① 冲突区间边界 | 相邻不冲突 / 交叉 / 包含 / 被包含 / 设备维度 | 通过 |
| ② 状态占用规则 | FINISHED 占用、CANCELED/VOIDED 释放、维护 ACTIVE/CANCELED | 通过 |
| ③ 条件更新 affectedRows | finish/cancel/void/adjust/window 共 5 组 0 行断言 | 通过 |
| ④ `allow_cross_day` 映射与边界 | null/false 均不允许；1:1 唯一约束 | 通过 |
| ⑤ B8 单号格式/补零/溢出/日期切换 | `testBuildNo_*`、`testBuildKey_dateSwitch_resets`、`testGenerate_assemblyChain_withStubTemplate` | 通过 |
| ⑥ Mapper 租户与查询条件 | 租户基类断言 + device 维度条件 + history 查询 | 通过（**租户拦截器未加载，租户语义待集成验证**） |
| ⑦ 锁协议可测逻辑 | 锁键格式 / 前缀互斥 | 通过 |

### 9.3 未覆盖项（明确标记，**不得视为已通过**）

| 未覆盖项 | 归属 |
| --- | --- |
| 真实 Redis 原子 INCR 的并发唯一性、跨日重置 | **03-C 待验收** |
| Redisson 锁端到端互斥 / watchdog 续期（覆盖事务提交） | **03-C 待验收** |
| `TenantDatabaseInterceptor` 自动追加 `tenant_id` 的租户隔离语义 | **集成环境（DDL 执行后）验证** |
| 双层锁顺序 `suspendKey → 设备行锁` 的端到端事务链 | **03-C 待验收** |

---

## 十、是否执行真实数据库写入

**未执行。**

核验依据：

1. 本任务全程**未连接**真实 `labplatform` 库执行任何语句（含只读 SELECT）。
2. `sql/lab/20261015_instrument_03_schema.sql` 为**设计稿**，文件头与 §4 明确声明“未执行”，且仅含 `CREATE TABLE IF NOT EXISTS` 与只读 `SELECT`。
3. 全部编译与测试运行于 **H2 内存库**（`jdbc:h2:mem:testdb`），与真实库物理隔离。
4. 未生成/未执行菜单授权或角色授权 SQL；未创建真实业务测试数据。
5. 未修改或删除既有设备 id=1/2、manager 3 行及 INSTRUMENT-01/02 业务数据。

---

## 十一、结论

# **CONDITIONAL PASS**

理由：

- **PASS 项**：22/23/24 号文档规则已冻结且互相一致；03-A 代码实现完整；本批新增代码编译通过；隔离单测 23/23 通过；SQL 设计稿与 DO/Mapper 字段逐项核对通过（§六）；未执行任何真实数据库写入（§十）。
- **CONDITIONAL 项（非阻断、待闭环）**：
  1. SQL 设计稿尚未执行 → 需负责人授权执行 + 回执行后只读核验（03-A 关闭条件）。
  2. 真实 Redis 并发唯一性、租户隔离集成语义、锁端到端互斥需在后续阶段验证。
- **HOLD 项（阻断，仅影响 03-C，不影响 03-A 数据层交付）**：
  - **B1 并发互斥覆盖至 DB 提交无法证明**。现有 `RLock.lock(10_000ms)` 为固定租约、无 watchdog；租约到期后可能失锁后继续提交。**03-C 预约创建的并发验收标记 HOLD**，须先落地方案 A + 看门狗续期锁 + 锁内提交的时序固化，并补充真实多线程并发测试。
- **03-A 本身不阻塞**：03-A 仅做静态核验与数据层交付，不实现 03-C 并发保证，故不因 B1 HOLD 而整体 HOLD。

---

## 十二、负责人下一步操作

1. **审查 SQL 设计稿**：审阅 `sql/lab/20261015_instrument_03_schema.sql`（五表 DDL、唯一约束、索引、B7/B10/B11 落实情况）。
2. **另行授权执行 DDL**：由负责人授权在真实 `labplatform` 库执行 §1 五表 DDL（先跑 §0 只读预检，全部符合预期再执行）。
3. **回传执行结果 + 执行后只读核验**：执行 §2 验收 SELECT（2.1~2.6），回填结果。**代码完成/编译通过/SQL 审查通过均不等于 DDL 执行授权。**
4. **03-A 关闭 / 启动 03-B**：仅在负责人回传“执行成功 + 执行后只读核验全部符合预期”后，03-A 正式关闭并启动 03-B。
5. **B1 决策**：为 03-C 批准“方案 A + 看门狗续期锁 + 锁内提交时序”的具体修复方案与影响面，否则 03-C 并发验收保持 HOLD。
6. **B2/B10 参数确认**：B2 的 `expire_time` 语义（NULL=长期有效，已核实）在 03-C 编码时沿用；B10 的 U1/U2/U3 设备参数须由负责人按设备分别确认录入后方可预约。

---

## 附录：本次涉及文件

- 文档：`22-...冻结草案.md`(V2.0)、`23-...数据库与接口设计.md`(V2.0)、`24-...分批方案.md`(V2.0)、本报告
- SQL 设计稿：`sql/lab/20261015_instrument_03_schema.sql`（未执行）
- 代码：见 §五文件清单
- 测试：`Instrument03DataLayerTest`（23 用例）、`create_tables.sql`、`clean.sql`

---

## 后续状态（2026-10-15 追加，原始结论未改动）

负责人已授权执行 `20261015_instrument_03_schema.sql` §1 五表 DDL（TASK INSTRUMENT-03-A-DDL-EXEC-01）。执行结果：§0 预检全项通过 → 5/5 CREATE TABLE 成功 → §2 验收全项 PASS（列数 24/21/20/20/15、索引与设计一致、五表为空、device=2/manager=3 未变、EXPLAIN 走 idx_device_time）。**本报告第十一条的 CONDITIONAL 项 1（SQL 未执行）已闭环；03-A 于 2026-10-15 正式关闭。** 详见 27 号报告与 28 号报告 A 部分（执行后验收记录）。
