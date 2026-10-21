# 29-INSTRUMENT-03-B验收收尾-CAP-A容量设计与03-C准备报告

**项目**：本草基因组学团队实验室管理平台（yudao-module-lab）  
**任务**：TASK INSTRUMENT-03-B-C-PREP-01  
**执行日期**：2026-10-16  
**前置报告**：26、27、28 号 INSTRUMENT-03 报告  
**规则基线**：22、23、24 号文档 V2.0（V2.1 CAP-A 追加）  
**数据库权限**：真实 `labplatform` 只读，禁止任何未经另行授权的写入  

---

## A. 03-B 验收收尾

### A.1 现有成果核对

核对范围与结论：

| 文档/代码 | 路径 | 结论 |
|---|---|---|
| 22 号规则冻结草案 | `doc/03-仪器管理/22-INSTRUMENT-03-预约业务规则冻结草案.md` | V2.1（CAP-A 追加）已同步 |
| 23 号数据库与接口设计 | `doc/03-仪器管理/23-INSTRUMENT-03-数据库与接口设计.md` | CAP-A 修订已写入 §2.5 |
| 24 号分批实施计划 | `doc/03-仪器管理/24-INSTRUMENT-03-开发实施任务分批方案.md` | 03-C 依赖已更新 |
| 28 号报告 | `doc/03-仪器管理/28-INSTRUMENT-03-A建表验收与03-B实施报告.md` | 后续状态（2026-10-16）已追加 |
| 后端 Controller/Service/Mapper/DO | `yudao-module-lab/src/main/java/...instrument` | 代码已 freeze |
| 前端 booking-config | `yudao-ui-admin-vue3/src/views/lab/instrument/booking-config/index.vue` | 代码已 freeze |
| 对应 API/测试类 | `src/test/java/...Instrument03BBookingRuleWindowTest` 等 | 17 用例全部通过 |

### A.2 错误码 105～109 备案

**备案结论**：已完成，无冲突，未重编号。

写入 23 号文档 §5.2 后的完整仪器错误码段：

| 码段 | 用途 |
|---|---|
| 080～084 | 设备基础（编号重复、名称重复等） |
| 085～089 | 设备分类/制造商/规格（预留） |
| 090～099 | 设备状态/负责人/通知/资质/信用分（INSTRUMENT-01/02） |
| 100～104 | 预约规则（校验、时段、粒度等） |
| **105～109** | **开放窗口（窗口不存在、时间冲突、非法配置、容量超限等）** |
| 110～119 | 维护/维修（预留） |

窗口具体映射：

| 错误码 | 含义 | 来源 |
|---|---|---|
| 105 | `INSTRUMENT_WINDOW_NOT_EXISTS` | 窗口不存在 |
| 106 | `INSTRUMENT_WINDOW_TIME_CONFLICT` | 窗口时间重叠 |
| 107 | `INSTRUMENT_WINDOW_INVALID_CONFIG` | 窗口配置非法 |
| 108 | `INSTRUMENT_WINDOW_CAPACITY_EXCEEDED` | 容量缩小时低于已占用 |
| 109 | `INSTRUMENT_WINDOW_IN_USE` | 窗口已被使用，不可删除 |

### A.3 浏览器页面验收（只读）

验证方式：后端 jar 启动后，通过浏览器访问已注册管理员页面 + 直连未注册动态路由观察回退行为。

| 验证项 | 结果 | 证据 |
|---|---|---|
| 后端正常启动 | PASS | `yudao-server.jar --spring.profiles.active=local` 端口 48080 Started |
| 管理员访问仪器管理模块 | PASS | 设备列表正常加载 |
| booking-config 页面渲染 | 待授权（直连路由回退） | `/#/lab/instrument/booking-config` 因未注册菜单而静默回首页（yudao 动态路由保护），不 404 |
| 设备下拉加载 | 待授权（同页面路径未注册） | 与上同理 |
| 表单字段与校验 | 未在真实菜单环境验证 | 待授权 |
| API 路径一致性 | PASS | 后端接口与前端 API 文件路径一致 |
| 权限按钮一致性 | PASS | 后端权限矩阵与前端按钮 v-hasPermi 声明一致 |
| 未配置规则时页面显示 | 待授权 | 需在菜单环境验证 |

**结论**：页面代码与静态分析通过；因 `booking-config` 未注册菜单（yudao 动态路由回退），无法通过正式菜单环境验证表单交互。**页面完整交互验收需菜单授权后方可进行。**

### A.4 写入交互隔离验证

| 操作 | 环境 | 结果 |
|---|---|---|
| 规则 upsert | H2 隔离单测 | 17 用例全部通过 |
| 窗口 CRUD + 容量边界 | H2 隔离单测 | 包含 105/106/107/108/109 |
| 真实库保存规则/窗口 | 禁止执行 | 未授权，未执行 |

### A.5 03-B 验收结论

| 维度 | 状态 | 说明 |
|---|---|---|
| 后端代码与测试 | **PASS** | Instrument03BBookingRuleWindowTest 17/17 绿 |
| 前端代码与 TypeScript | **PASS（本任务范围）** | 全量 vue-tsc 检出的 10 处错误均为既有模块（git 证实未改动）；本任务新增文件 0 错误（见 E.3） |
| 页面只读交互 | 部分通过 | jar 启动正常、API 可达；菜单未注册致页面无法正式渲染 |
| 保存及修改等写入交互 | 隔离通过 | H2 全量通过；真实库未写入 |
| 正式菜单可见性 | **待授权** | 禁止插菜单 SQL |
| 错误码 105～109 | **PASS** | 已备案，无冲突 |

**整体结论**：03-B 后端代码与隔离测试验收通过；前端页面与菜单可见性待授权后最终确认。**不得标记 03-B 整体 PASS。**

---

## B. CAP-A 日期独立容量模型

### B.1 裁决记录

**负责人正式裁决（2026-10-16，写入 22 号文档 §5.6）**：

> 开放窗口容量按日期独立计算。一个开放窗口可以覆盖多个日期；每个自然日期独立拥有容量额度；某日容量使用完毕，不影响同一窗口的其他日期。不得把整个窗口周期的累计 `used_count` 作为所有日期共享的容量消耗。

本裁决取代 28 号报告中“窗口整个周期共享累计容量”的设计口径。自裁决日起，旧 `used_count` 口径标记为废弃。

### B.2 现有容量模型问题

`InstrumentBookingWindowDO` / Mapper / ServiceImpl 中仍保留旧口径：

| 代码点 | 旧口径行为 | 状态 |
|---|---|---|
| `lab_instrument_booking_window.capacity` | 窗口主表字段保留，语义转为“每日容量上限”（NULL=不限） | 列不改，语义已更新 |
| `lab_instrument_booking_window.used_count` | 曾作为窗口全周期累计消耗 | **废弃写入**，保留历史列 |
| `InstrumentBookingWindowMapper.updateUsedCountIncrIfAvailable` | 周期扣减：条件 UPDATE `used_count+1` | **旧口径，待迁移**，不得接入预约 |
| `InstrumentBookingWindowMapper.updateUsedCountDecr` | 周期释放：条件 UPDATE `used_count-1` | **旧口径，待迁移** |
| `InstrumentBookingWindowServiceImpl` 中 usedCount 边界校验 | 以窗口级累计值判断容量 | **旧口径，已标记废弃** |

### B.3 新数据模型设计

采用新增日期容量明细表方案。

**表名**：`lab_instrument_booking_window_daily_usage`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | BIGINT PK AUTO_INCREMENT | |
| `tenant_id` | BIGINT NOT NULL | 多租户 |
| `window_id` | BIGINT NOT NULL | 关联窗口 |
| `usage_date` | DATE NOT NULL | 占用日期（业务时区） |
| `used_count` | INT NOT NULL DEFAULT 0 | 当日已用容量 |
| `create_time` / `update_time` / `deleted` | 标准审计/逻辑删除 | |

**唯一约束**：`uk_window_date (tenant_id, window_id, usage_date)` —— 解决首次并发 INSERT 竞争，保证单日单窗口只有一行。

**SQL 设计稿路径**：
`ruoyi-vue-pro/sql/lab/20261016_instrument_03_capacity_daily_design.sql`

设计稿特征：
- 仅设计稿，未执行。
- 含执行前只读预检（§0）、DDL（§1）、执行后只读验收（§2）。
- 不含 ALTER 既有五张表；不含物理外键；不含数据删除或回填。
- 含与现有五张表的兼容性说明及重复执行风险分析。

### B.4 同日期并发容量控制（三步法）

在事务内执行：

1. **条件 UPDATE**：`UPDATE daily_usage SET used_count = used_count + 1 WHERE tenant_id=? AND window_id=? AND usage_date=? AND used_count < (窗口.capacity)`。
   - `affectedRows > 0`：占用成功。
2. **INSERT 初始化**：若 UPDATE 0 行且窗口 capacity ≥ 1（或 NULL=不限），INSERT 新行 `used_count = 1`。
   - 因 `uk_window_date`，并发 INSERT 同一日期的另一线程会抛 `DuplicateKeyException`。
3. **重试 UPDATE**：捕获 DuplicateKeyException 后重试条件 UPDATE。
   - 若仍 0 行，说明容量已满，拒绝预约。

**防负守卫**：释放时执行 `UPDATE ... SET used_count = used_count - 1 WHERE used_count > 0`，保证不会负数。

**关键修复**：INSERT 时显式 `row.setTenantId(tenantId)`，避免测试环境无租户拦截器导致列默认 0 与条件 UPDATE 过滤不匹配。

### B.5 取消、调整和作废的容量处理

- **取消/作废**：遍历预约覆盖的每个日期，调用 `decrIfPositive(windowId, date)` 原子减 1；`used_count > 0` 守卫防止重复释放。
- **调整**：按“先释放旧日期 → 再占用新日期”顺序执行；若新日期容量不足则整体回滚。
- **窗口修改/关闭/删除**：
  - 缩小 capacity：需校验各日期 `used_count <= 新 capacity`，否则拒绝（错误码 108）。
  - 删除窗口：若存在任何日期 `used_count > 0`，拒绝删除（错误码 109）。

### B.6 已实施技术组件

| 文件 | 角色 |
|---|---|
| `InstrumentBookingWindowDailyUsageDO` | 日期容量实体 |
| `InstrumentBookingWindowDailyUsageMapper` | 条件更新/查询/递减 |
| `InstrumentBookingWindowDailyUsageService` | `tryOccupy`、`release`、`getUsedCount` |
| `InstrumentBookingWindowDailyUsageServiceImpl` | 三步法 + 显式 tenantId |
| `Instrument03CapacityDailyUsageTest` | H2 隔离测试（8 用例） |

H2 隔离测试结论：
- 8/8 通过（含 16 线程同日并发不超订验证）。
- 不同日期容量独立验证通过。
- 释放幂等（重复释放不触发异常）验证通过。

### B.7 未裁决业务语义清单（不得固化到正式 Service）

| 序号 | 未裁决项 | 影响 |
|---|---|---|
| U1 | 跨日预约容量归属：扣开始日期 / 结束日期 / 所有覆盖日期？ | 跨日接入容量前必须裁决 |
| U2 | 容量单位数：一条预约默认消耗 1 个容量单位，还是可配置？ | 影响三步法增量步长 |
| U3 | 同日多窗口优先级：同一设备同一日期多个窗口时，扣哪个窗口的容量？ | 影响 Mapper 查询条件 |
| U4 | FINISHED 状态是否继续占用容量？ | 影响释放时机 |
| U5 | `reservation` 表缺少 `window_id` 关联字段 | 目前凭设备 ID+日期反查窗口，无法精确关联；需裁决是否新增字段 |

以上语义在裁决前，**不得接入正式预约创建 Service**。

### B.8 CAP-A 验收结论

- 设计、SQL 设计稿、技术组件、H2 隔离测试：**设计 PASS**。
- 真实数据库部署新表 DDL：**待负责人授权执行**。
- 未裁决语义（U1～U5）**保持 HOLD**。

---

## C. B1 锁安全

### C.1 watchdog 锁基础设施

**代码位置**：`InstrumentLockRedisDAO.java`

新增方法：

- `lockWithWatchdog(String key, Callable<V> callable)` —— 第 85 行
- `lockWithWatchdog(String key, Runnable runnable)` —— 第 116 行

安全语义实现：

| 要求 | 实现 | 代码点 |
|---|---|---|
| 有界等待 | `tryLock(WATCHDOG_WAIT_MILLIS=10s)`，false → 抛异常 | L89, L99-101 |
| 中断恢复 | `catch InterruptedException` → `Thread.currentThread().interrupt()` 后抛异常 | L90-93 |
| Redis 不可达 | `catch RuntimeException` → fail-closed 上抛 | L94-97 |
| finally 安全释放 | `if (lock.isHeldByCurrentThread()) unlock()` | L110-112 |
| 诊断日志 | 只记录 key 与等待时长，不输出凭据 | L92, L96, L100 |
| 租户隔离 | 调用方通过 `suspendKey(tenantId, userId)` 等构造含 tenantId 的 key | L142-144 |

### C.2 createSuspend 固定租约迁移

**迁移结论**：已迁移。

`InstrumentSuspendServiceImpl.createSuspend`（L117）已改用 `lockWithWatchdog`。

迁移理由（注释 L114-115）：固定 10s 租约在长事务下可能在提交前失锁，导致校验失效；watchdog 续期保证锁覆盖完整事务生命周期。锁内编排不变，业务语义不变（重复覆盖校验、插入、联动规则不变）。

### C.3 其余旧锁调用影响面

`InstrumentLockRedisDAO.lock()`（固定租约）仍有 4 处未迁移：

| 调用方 | 次数 | 未迁移理由 |
|---|---|---|
| `InstrumentNoticeServiceImpl` | 2 | 通知版本递增操作简短（读→version+1→写），10s 租约足够；迁移非本次阻塞项 |
| `InstrumentQualificationServiceImpl` | 1 | 资质申请/审批链路较短；如后续出现长事务需再评估 |
| `InstrumentManagerServiceImpl` | 1 | 负责人分配操作简短 |

**本次未迁移的 4 处不影响 03-C 阻塞**：03-C 预约创建使用 `lockWithWatchdog`（suspendKey）+ 设备行锁，与上述 4 处 key 不同，不存在锁顺序反转风险。

### C.4 锁协调器与事务边界

**代码位置**：`ReservationLockCoordinator.java`

编排顺序（B1 裁决）：

```
① 外层：lockWithWatchdog(suspendKey)          —— Redis，watchdog 续期
  ② 内层：TransactionTemplate.execute(...)    —— 编程式事务，无 @Transactional
    ③ 事务首步：selectByIdForUpdate(deviceId)  —— 设备行锁（当前读）
    ④ 回调：P4/P5/P8/P9 复核 + 数据写入
  ⑤ 事务 commit/rollback 闭合
⑥ finally：释放 suspendKey（一定晚于 commit）
```

### C.5 事务提交早于解锁的证据（单元测试）

`Instrument03LockCoordinatorTest`（5 用例全部通过）：

| 用例 | 验证点 |
|---|---|
| `testLockOrderAndCommitBeforeUnlock` | Mock 验证：tryLock → rowLock → action → commit → unlock 顺序 |
| `testTryLockFalse_failClosed` | tryLock 返回 false → 不进入事务，直接抛异常 |
| `testRedisUnavailable_failClosed` | Redis 异常 → 包装为 IllegalStateException，事务未开启 |
| `testInterrupted_restoreFlag` | 中断时恢复 `Thread.interrupted()` 标志后抛异常 |
| `testCallbackException_rollbackThenUnlock` | 回调异常 → rollback → 最终仍 unlock（finally） |

以上 5 用例为纯 Mockito 逻辑验证；**真实 MySQL RR 隔离级别下的并发互斥尚未通过真实数据库证明**。

### C.6 INSTRUMENT-02 回归结果

本次修改了 `InstrumentSuspendServiceImpl`（迁移 watchdog）和 `InstrumentLockRedisDAO`（新增方法），需通过 02 回归：

`Instrument02ServiceTest` 26/26 全部通过，其中 5 个暂停相关用例在补 Mock `lockWithWatchdog` 直通后恢复通过。**INSTRUMENT-02 业务语义未变。**

### C.7 尚未证明的并发场景（HOLD）

| 编号 | 场景 | 状态 | 原因 |
|---|---|---|---|
| C6-1 | 16 线程同设备同时间段并发预约，仅一条成功 | HOLD | 需真实 MySQL + Redis 环境 |
| C6-2 | 相邻时间段不冲突 | HOLD | 同上 |
| C6-3 | 不同设备之间不应被错误串行化 | HOLD | 同上 |
| C6-4 | 暂停创建与预约创建交错 | HOLD | 同上 |
| C6-5 | 长事务超过旧 10s 租约 | PASS（逻辑） | watchdog 续期已解决；待真实环境验证 |
| C6-6 | watchdog 续期 | HOLD | 需真实 Redis 与长事务压测 |
| C6-7 | Redis 不可达时 fail-closed | PASS（Mock） | 单元测试已覆盖；真实网络分区待验证 |
| C6-8 | 锁所有权丢失 | PASS（Mock） | `isHeldByCurrentThread` 已覆盖 |
| C6-9 | 数据库事务回滚 | PASS（Mock） | TransactionTemplate 回滚已覆盖 |
| C6-10 | REPEATABLE-READ 下冲突查询的可见性 | HOLD | 需真实 MySQL 隔离测试 |
| C6-11 | 不同租户相同业务编号的隔离 | HOLD | 需真实环境 |
| C6-12 | 容量同日期并发扣减不超额 | PASS（H2） | 16 线程 H2 验证通过 |
| C6-13 | 不同日期容量独立 | PASS（H2） | H2 验证通过 |
| C6-14 | 重复取消或作废不得重复释放容量 | PASS（H2） | 幂等释放验证通过 |

---

## D. 03-C 开发准备

### D.1 已完成技术基础

| 组件 | 文件 | 说明 |
|---|---|---|
| 锁协调器 | `ReservationLockCoordinator` | suspendKey → TransactionTemplate → selectByIdForUpdate → 回调 → commit → unlock |
| watchdog 锁 | `InstrumentLockRedisDAO.lockWithWatchdog` | 有界等待、fail-closed、finally 安全释放 |
| 日期容量 Service | `InstrumentBookingWindowDailyUsageServiceImpl` | 三步法占用 + 幂等释放 |
| 预约创建 VO | `ReservationCreateReqVO` | 请求字段设计（含 P1～P11 校验链注释） |
| 预约响应 VO | `ReservationRespVO` | 响应字段设计 |
| 预约 Service 接口 | `InstrumentReservationService` | `createReservation(...)` 接口签名 + 校验链设计（HOLD 声明） |
| 单号生成 | `ReservationNoRedisDAO`（B8 既有） | 已存在 |

### D.2 未完成依赖

| 依赖 | 阻塞项 | 解除条件 |
|---|---|---|
| CAP-A 新表 DDL | 真实容量扣减无法部署 | 负责人授权执行 `20261016_instrument_03_capacity_daily_design.sql` |
| U1 跨日归属 | 跨日预约容量规则未知 | 负责人裁决 |
| U5 reservation 缺 window_id | 无法精确扣减容量 | 负责人裁决是否新增字段或采用设备+日期反查方案 |
| 真实 MySQL + Redis 环境 | C6 并发互斥未经验证 | 提供独立可写 schema + 独立 Redis db index |

### D.3 测试环境要求

- **独立 MySQL schema**：可写，隔离于真实 `labplatform`；用于并发压测、RR 隔离验证、watchdog 续期观察。
- **独立 Redis db index**：用于锁压测，避免影响生产/开发环境锁 key。
- **禁止使用真实 `labplatform`** 进行写入压测。

### D.4 03-C HOLD 解除条件

1. CAP-A 新表 DDL 已授权并执行，且执行后只读验收通过。
2. U1（跨日归属）及 U3/U4/U5 中至少影响容量扣减的语义已裁决。
3. 真实 MySQL + Redis 环境中 C6-1/4/6/10 至少 4 项并发验证通过。
4. `InstrumentReservationServiceImpl` 完整实现并经过隔离/真实环境测试。

### D.5 下一份正式开发任务建议

- **任务代号**：INSTRUMENT-03-C-IMPL-01
- **内容**：`InstrumentReservationServiceImpl.createReservation` 完整实现（P1～P11 校验链）。
- **前置条件**：D.4 的 HOLD 解除条件 1～3。
- **建议分批**：
  1. 基础校验层（P1 参数/P2 设备存在/P3 用户身份/P4 资质/P5 暂停）。
  2. 时间冲突层（P6 时段合法/P7 跨天限制/P8 冲突检测）。
  3. 容量扣减层（CAP-A 接入，需裁决后）。
  4. 数据持久层（预约记录插入、单号生成、状态机初始化）。
  5. 并发验收层（真实环境 C6 全项）。

---

## E. 执行边界与诚实声明

### E.1 真实数据库操作统计

| 操作类型 | 次数 | 说明 |
|---|---|---|
| 真实库 DDL | **0** | 未执行任何 CREATE/ALTER/DROP |
| 真实库 DML（INSERT/UPDATE/DELETE） | **0** | 未写入任何预约、规则、窗口、暂停数据 |
| 菜单授权 | **0** | 未插入 sys_menu 或修改权限 |
| 角色分配 | **0** | 未分配 908 等角色 |

### E.2 隔离测试环境写入

| 环境 | 写入内容 | 清理方式 |
|---|---|---|
| H2 内存数据库 | `lab_instrument_booking_window_daily_usage` 等测试表 | JVM 退出自动销毁 |
| 后端 jar 本地进程 | 无写入（只读 API 调用） | 进程终止 |

### E.3 编译与回归证据

**命令 1**：`mvn -o -pl yudao-module-lab test`（`E:\lixin\dev\ruoyi-vue-pro`）  
**结果**：`BUILD SUCCESS`，`Tests run: 127, Failures: 0, Errors: 0, Skipped: 0`

分测试类明细：

| 测试类 | 用例数 | 失败 | 说明 |
|---|---|---|---|
| `Instrument02ServiceTest` | 26 | 0 | INSTRUMENT-02 回归（暂停/信用/资质） |
| `Instrument03BBookingRuleWindowTest` | 17 | 0 | 03-B 规则+窗口 |
| `Instrument03CapacityDailyUsageTest` | 8 | 0 | CAP-A 日期容量 |
| `Instrument03DataLayerTest` | 23 | 0 | 03-A 数据层 |
| `Instrument03LockCoordinatorTest` | 5 | 0 | B1 锁协调器 |
| `PlasmidStorageServiceImplTest` | 17 | 0 | 质粒模块回归 |
| `RegisterApplyServiceImplTest` | 31 | 0 | 注册模块回归 |
| **合计** | **127** | **0** | |

**命令 2**：前端 TypeScript 检查  
`$env:NODE_OPTIONS='--max-old-space-size=8192'; npx vue-tsc --noEmit -p tsconfig.json`（`E:\lixin\dev\yudao-ui-admin-vue3`）  
**结果**：退出码 2，检出 10 处错误（注：首次默认堆内存运行 exit 134 为 Node OOM，加大内存后正常完成检查）。

错误分布与归因（经 `git status --short` 证实，下列文件本任务**均未改动**，错误为仓库既有遗留）：

| 文件 | 错误数 | 错误类型 | 是否本任务文件 |
|---|---|---|---|
| `src/api/lab/announcement/index.ts` | 1 | TS6133 未使用变量 | 否 |
| `src/views/fms/report/components/FmsReportFormulaForm.vue` | 2 | TS2345 字面量类型 | 否 |
| `src/views/hrm/employee/index.vue` | 1 | TS2353 多余属性 | 否 |
| `src/views/lab/v2/plasmid-audit/index.vue` | 4 | TS2322/TS2538/TS6133 | 否 |
| `src/views/lab/v2/plasmid/index.vue` | 4 | TS2322/TS2538 | 否 |

本任务新增文件（`src/api/lab/instrument/`、`src/views/lab/instrument/booking-config/index.vue`）**未出现任何 TS 错误**。既有 10 处错误是否修复不属本任务范围，需负责人另行派单。

### E.4 登录与 Token

- 未执行新的管理员登录。
- 复用既有 token：`Bearer 9df2f2f68ec542a098f91bd67fa11b96`，Header `tenant-id=1`。
- 该 token 属租户 1（本草），跨租户访问返回 403 属正确隔离。

### E.5 备注

- `booking-config` 页面未注册菜单，通过直连路由访问被 yudao 动态路由机制回退至首页，不暴露 404。**此行为证明前端路由文件已加载，但正式菜单可见性仍需 sys_menu 授权。**
- 后端 jar 进程（`job-a050ac25c0f541e0bb86b746239aa309`）用于只读 API 验证，未产生写入。

---

## 附件清单

| 文件 | 路径 | 说明 |
|---|---|---|
| 本报告 | `doc/03-仪器管理/29-INSTRUMENT-03-B验收收尾-CAP-A容量设计与03-C准备报告.md` | 29 号报告 |
| CAP-A SQL 设计稿 | `ruoyi-vue-pro/sql/lab/20261016_instrument_03_capacity_daily_design.sql` | 未执行，待授权 |
| 日期容量 Service | `...service/instrument/InstrumentBookingWindowDailyUsageServiceImpl.java` | 三步法实现 |
| 锁协调器 | `...service/instrument/ReservationLockCoordinator.java` | B1 编排基座 |
| watchdog 锁 | `...dal/redis/InstrumentLockRedisDAO.java` | lockWithWatchdog |
| 预约 VO/接口 | `...vo/reservation/ReservationCreateReqVO.java` 等 | 03-C 技术准备 |

---

## 后续状态（2026-10-16 第二批：U1~U5 正式裁决）

> 本节为 29 号报告交付后的状态追加，**不改动原报告任何结论与证据**。

### 1. U1~U5 已由负责人正式裁决（2026-10-16）

裁决原文见 22 号文档 §5.7，设计落实索引见 23 号文档 §十、24 号文档 §七。本报告 D.2「未完成依赖」中 **U1 跨日归属、U5 window_id 两项依赖已解除**（按裁决结论实施，不再 HOLD）：

| 裁决 | 结论 | 对本报告的影响 |
| --- | --- | --- |
| U1 跨日容量归属 | 每个实际覆盖自然日期各占 1 单位，半开区间 `[start,end)`，实验室业务时区 | 跨日容量规则确定，可接入正式容量扣减 |
| U2 容量单位 | 恒为 1，不引入倍数 | 维持 CAP-A 设计不变 |
| U3 同日多窗口 | 允许多个互不重叠窗口；预约归属唯一窗口禁随机选；重叠窗口配置拒绝；无法表达合法跨日窗口的分支 HOLD | 窗口校验链需补重叠校验 |
| U4 FINISHED 容量 | PENDING/FINISHED 占用，CANCELED/VOIDED 释放；不得重复释放 | 释放幂等需升级为预约级占用明细（本报告三步法 `used_count>0` 口径被 30 号任务 B1 取代） |
| U5 window_id | `reservation` 新增 `window_id BIGINT`（仅 ALTER 设计稿） | 容量扣减可按窗口精确归属 |

### 2. 被取代/升级的设计点（以 30 号报告为准）

1. 本报告 B 部分「三步法 tryOccupy」在 30 号任务 B2 中被重审：正式预约路径统一为**设备行锁内 窗口校验 → 日期容量校验 → 占用写入**，三步法退化为兜底/兼容层。
2. 本报告的释放幂等实现（`used_count > 0` 防负）在 30 号任务 B1 中升级为**预约级容量占用明细**（`lab_instrument_reservation_capacity_occupation`，`OCCUPIED→RELEASED` 条件变更为唯一释放依据）。
3. CAP-A SQL 设计稿合并升级为 `sql/lab/20261016_instrument_03_capacity_u1_u5_final.sql`（含占用明细表 + `reservation.window_id` ALTER + 预检/验收/兼容策略），本报告附件中的阶段设计稿被其覆盖。
4. 窗口修改/删除的旧 `used_count` 累计口径（28 号报告 §B 实现）在 30 号任务 B5 中改为按占用明细判断（错误码 108/109 语义不变）。

### 3. 仍保持 HOLD 的事项

- CAP-A 新表 DDL 执行授权（含合并后的最终设计稿）。
- 真实 MySQL + Redis 隔离环境并发验证（C6 矩阵中 HOLD 项）。
- `reservation.window_id` 历史数据迁移策略（随最终 SQL 设计稿一并提交负责人审查）。

---

*报告生成：2026-10-16*  
*任务：INSTRUMENT-03-B-C-PREP-01*  
*真实数据库 DDL 次数：0 | DML 次数：0 | 菜单授权次数：0 | 角色授权次数：0*
