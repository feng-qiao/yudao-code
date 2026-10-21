# 27-INSTRUMENT-03-A-DDL 执行前核验与 B1 锁方案报告

> 任务：TASK INSTRUMENT-03-A-DEPLOY-PRECHECK-01（2026-10-15）
> 性质：只读核验 + SQL 设计稿修正 + B1 锁方案审查（**不实施锁改造、不启动 03-B/03-C**）
> 数据库权限：**严格只读**。全程仅执行 `SELECT`（information_schema / 业务表只读查询）与一次 `USE labplatform`（会话上下文，非写入）。
> **全程真实数据库写入次数：0。**
> 前置：`26-INSTRUMENT-03-规则冻结与03-A实施报告.md`（03-A CONDITIONAL PASS）

---

## 一、真实数据库只读预检结果

### 1.1 执行环境与命令

| 项 | 值 |
| --- | --- |
| 客户端 | `D:\worktools\mysql-8.4.11-winx64\bin\mysql.exe`（仅作客户端，服务器为 8.0.12） |
| 连接 | `--host=127.0.0.1 --port=3306 --user=bencao`（连接配置取自 `application-local.yaml`，即项目本地开发真实库） |
| 预检脚本 | `C:\temp\instrument03_precheck.sql`（临时文件，仅含 SELECT，报告完成后已删除） |
| 命令 | `mysql.exe ... -e "source C:/temp/instrument03_precheck.sql"` 等 3 次只读会话 |

### 1.2 P0 当前库 / 版本 / 隔离级别（实测）

| 项 | 实测值 |
| --- | --- |
| cur_db | **labplatform** |
| mysql_version | **8.0.12** |
| tx_isolation | **REPEATABLE-READ** |

### 1.3 P1 既有表完整性：11 张全部在位

实测 `lab_instrument%` 共 **11 张**，与 INSTRUMENT-01（5 张）+ INSTRUMENT-02（6 张）完全一致：

| # | 表名 | 归属 |
| --- | --- | --- |
| 1 | lab_instrument_room | 01 |
| 2 | lab_instrument_platform | 01 |
| 3 | lab_instrument_device | 01 |
| 4 | lab_instrument_manager | 01 |
| 5 | lab_instrument_notice | 01 |
| 6 | lab_instrument_qualification_apply | 02 |
| 7 | lab_instrument_qualification_apply_history | 02 |
| 8 | lab_instrument_qualification | 02 |
| 9 | lab_instrument_credit_account | 02 |
| 10 | lab_instrument_credit_flow | 02 |
| 11 | lab_instrument_suspend | 02 |

全部 InnoDB / utf8mb4_unicode_ci，与设计稿一致。

### 1.4 P2 五张目标表存在性（实测）

`information_schema.tables` 显式 COUNT 计数，五张表**全部为 0（均不存在）**：

```
lab_instrument_reservation            → 0
lab_instrument_reservation_history    → 0
lab_instrument_booking_rule           → 0
lab_instrument_booking_window         → 0
lab_instrument_maintenance            → 0
```

**结论：不存在同名表 → 无需结构对比，无 HOLD 项；任务书二.4 的"存在差异则 HOLD"分支未触发。**

### 1.5 P3 `TenantBaseDO` 六列真实基线（以 lab_instrument_suspend 实测）

| column_name | 实测 column_type | is_nullable | default | 设计稿 DDL | 一致 |
| --- | --- | --- | --- | --- | --- |
| tenant_id | bigint(20) | NO | 0 | bigint(20) NOT NULL DEFAULT 0 | ✅ |
| deleted | bit(1) | NO | b'0' | bit(1) NOT NULL DEFAULT b'0' | ✅ |
| creator | varchar(64) | YES | '' | varchar(64) NULL DEFAULT '' | ✅ |
| create_time | datetime | NO | CURRENT_TIMESTAMP | 同 | ✅ |
| updater | varchar(64) | YES | '' | 同 | ✅ |
| update_time | datetime | NO | CURRENT_TIMESTAMP | 同 | ✅ |

### 1.6 P5 既有业务数据基线（执行后对比用）

| 表 | 实测行数 | 说明 |
| --- | --- | --- |
| lab_instrument_device | 2（id=1,2 均在） | 与"不得修改设备 id=1/2"基线一致 |
| lab_instrument_manager | 3 | 与"manager 3 行"基线一致 |

---

## 二、DDL 与 DO 对照结果

26 号报告 §六已完成逐字段对照（五表列数 24/21/20/20/15 与 DO 一致），本次以真实库复核公共列（§1.5），并复核目标 DDL 的关键设计点：

| 核验项（任务书二） | 结论 |
| --- | --- |
| 6. 预约单号唯一索引租户维度 | ✅ `uk_reservation_tenant_no(tenant_id, reservation_no)` —— 租户在首列，单号租户内唯一 |
| 7. 规则表一设备一规则唯一约束 | ✅ `uk_rule_tenant_device(tenant_id, device_id)` —— 租户内 1:1 |
| 8. 冲突查询索引适用性 | ✅ 预约/维护均建 `idx_device_time(device_id, start_time, end_time, status)`，覆盖冲突 SQL 的全部条件列（`device_id = ? AND start_time < ? AND end_time > ? AND status IN (...)`）；窗口表 `idx_device_status(device_id, status)` 覆盖 `selectListByDeviceAndStatus` |
| 9. `selectByIdForUpdate` 真实 SQL | ✅ `SELECT * FROM lab_instrument_device WHERE id = #{id} AND deleted = 0 FOR UPDATE`（含设备主键 + 逻辑删除条件）；租户隔离：`InstrumentDeviceDO extends TenantBaseDO`（已核实源码），生产环境由 `TenantDatabaseInterceptor` 自动追加 `tenant_id`，跨租户 id 锁内读取为 null → 走 P1 DEVICE_INVALID 拒绝 |
| 10. SQL 文件危险语句 | ✅ 全脚本仅 `CREATE TABLE IF NOT EXISTS` 与只读 `SELECT`；无 DROP / TRUNCATE / DELETE / UPDATE / INSERT / ALTER；无菜单/角色授权；不触碰既有表与 id=1/2、manager 3 行数据 |

> 注：五张目标表尚未创建，冲突 SQL 的 `EXPLAIN` 需 DDL 执行后方可在真实库验证；本次为设计级核验（索引列序对查询谓词的覆盖关系），已列入执行后核验建议。

---

## 三、SQL 设计稿检查与修改

文件：[20261015_instrument_03_schema.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_03_schema.sql)（**未执行，仅为设计稿**）

### 3.1 检查结论（任务书三逐项）

| 检查项 | 结论 |
| --- | --- |
| 五张表与 DO 完整一致 | ✅（26 号报告 §六对照表） |
| MySQL 8.0.12 兼容性 | ✅ 仅用 `CREATE TABLE IF NOT EXISTS`、`bigint(20)`/`int(11)` 显示宽度（8.0.17 起才弃用，8.0.12 正常）、`bit(1)`、`datetime`、`ROW_FORMAT=Dynamic`、`utf8mb4_unicode_ci`；未用 8.0.12 不支持的特性（函数索引/检查约束/表达式默认值均未使用） |
| `BIT(1)` ↔ Java Boolean | ✅ MyBatis-Plus/JDBC 原生映射；H2 单测已验证（`allow_cross_day`/`enabled` Boolean 读写） |
| `DATETIME` ↔ LocalDateTime | ✅ JDBC 原生映射；H2 单测已验证（`start_time`/`end_time` 等） |
| 状态/默认值/NULL 语义 | ✅ `status NOT NULL DEFAULT 'PENDING'` 等与 6 个枚举一致；`allow_cross_day bit(1) NULL DEFAULT NULL`（B7 不写库默认值）；`granularity/min_duration` 可空（B10） |
| 索引及唯一约束 | ✅ 见 §二.8 |
| 字符集/引擎/长度 | ✅ InnoDB / utf8mb4_unicode_ci；`reservation_no varchar(50)`（实际 14 字符，余量充足）；`creator varchar(64)` 与既有表实测一致 |
| 执行前/后检查与停止条件 | ✅ §0（0.0~0.4.4）/ §2（2.1~2.6）/ §4.3 停止条件完整 |
| 部分成功后再次执行风险 | ✅ 可控：`IF NOT EXISTS` 幂等，重跑时 §0.1 将显示已建表 cnt=1 → 引导走 §0.4 结构核对；结构一致=情况 2 继续验收，不一致=情况 3 停止并回报，**禁止自动 DROP/重建**（§0.4/§4.4 已明确） |

### 3.2 本次修改（1 处，未执行）

新增 **§0.0 目标库与版本确认**：执行 DDL 前必须先 `SELECT DATABASE(), VERSION()`，预期 `labplatform` / 8.0.x；为 NULL 或连错库即停止——防止"会话未选默认库导致 information_schema 查询失败"（本次预检实际踩到该现象）或"连错库建表"两类事故。

### 3.3 结论

# SQL 设计稿：**PASS** —— 可提交负责人审查并申请执行授权。

---

## 四、B1 锁安全方案分析（十问逐项）

### 4.0 现状事实（源码证据）

- [InstrumentLockRedisDAO.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/redis/InstrumentLockRedisDAO.java#L43-L57)：`lock.lock(LOCK_LEASE_MILLIS, MILLISECONDS)`，`LOCK_LEASE_MILLIS = 10_000`，**固定租约、watchdog 关闭**；finally 中 `isHeldByCurrentThread` 判断后解锁。
- [InstrumentSuspendServiceImpl.createSuspend](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentSuspendServiceImpl.java#L115-L117)：**已经是正确结构** —— `lockRedisDAO.lock(suspendKey, () -> transactionTemplate.execute(...))`，Redis 锁在外层、编程式事务在内层、**提交发生在锁回调内部（先 commit 后 unlock）**。
- `releaseSuspend`：**未取 Redis 锁**，仅 `transactionTemplate` + 条件更新 `updateReleaseIfActive`（affectedRows 防重复解除）。
- INSTRUMENT-03 已备：`InstrumentDeviceMapper.selectByIdForUpdate`（设备行锁）、`ReservationConflictChecker`、`ReservationNoRedisDAO`、条件更新 Mapper。

### 4.1 十问逐项结论

| # | 问题 | 结论 |
| --- | --- | --- |
| 1 | 固定 10 秒租约是否可能在事务提交前失效？ | **可能（低概率、真实存在）**。正常暂停创建事务为毫秒级 << 10s；但 GC 停顿、慢 SQL、锁等待累计超过 10s 时，租约先到期，另一线程可获同一把锁，原线程事务仍在执行并可继续提交 → 互斥窗口被破坏。**10s 告警/finally 解锁不构成覆盖提交的证明（26 号报告结论维持）。** |
| 2 | 用 watchdog 后，锁持有与事务提交是否仍可能时序错误？ | 提交/释放**顺序**由结构保证（锁外层 + 事务内层 → commit 必在 unlock 前）；残余风险来自 **watchdog 自身失效**：Redis 不可达导致续期失败、客户端进程假死（FGC/挂起）超过续期间隔、Redis 主从异步复制 failover 丢锁。所有权丢失对原持有者**不可感知**（Redisson 不会通知持锁人锁已易主），故 watchdog 不是充分条件，DB 层不变量仍是最终防线。 |
| 3 | `@Transactional` 代理是否会导致"业务方法返回后才提交、外层锁已释放"？ | **存在该反模式风险**：若 03-C 把 `@Transactional` 标在包含锁调用的外层 service 方法上，事务边界在代理层，**提交发生在方法返回之后，而锁已在方法体内 finally 释放** → 提交晚于解锁，互斥失效。另一反模式：锁回调内自调用（this 调用）`@Transactional` 方法 → 代理绕过，**根本没有事务**。**必须沿用 createSuspend 模式：锁回调内 `transactionTemplate.execute(...)`。** |
| 4 | 是否需要外层锁协调器？ | **需要（03-C 落地）**。固定结构：`suspendKey.tryLock(有界等待) → transactionTemplate.execute { ① selectByIdForUpdate(设备行锁，事务内第一条语句) ② P4 资质/P5 暂停/P8 冲突复核 ③ insert reservation + history } → finally unlock`。提交在锁内、释放 finally，且禁止反向获取。 |
| 5 | 暂停创建与预约创建是否使用同一用户暂停锁协议？ | `createSuspend` 使用 `instrument:suspend:{tenantId}:user:{userId}`（已核）。03-C 预约创建**必须复用同一 suspendKey** 作为外层第一把锁（B1 方案 A），同一用户"暂停创建 ↔ 预约创建"即被串行化。注意：`releaseSuspend` 未取锁（仅条件更新），方向是"解除限制"（弱化），与预约创建竞态不产生违规占用，可接受；记录在案。 |
| 6 | 是否存在设备锁与暂停锁反向获取路径？ | 现有代码无反向路径：`createSuspend` 只取 suspendKey、不取设备锁。03-C 约束：**固定顺序 suspendKey → 设备行锁**；预约只涉单用户，行锁内不得再获取其他用户的 suspendKey。 |
| 7 | Redis 锁失效/所有权丢失后，是否仍可能产生不符合暂停规则的预约？ | **设备维度不会重复预约**（DB 兜底有效，见问 8）。**暂停维度存在极小竞态窗口**：suspend 事务未提交且 suspendKey 已失锁时，预约路径读不到 in-flight 暂停 → 创建成功；B3 规定暂停不追溯取消 → 该预约存活。缓解：watchdog 续期 + 事务内 P5 复核 + 尽量缩短锁内事务。残余概率极低，如实记录，不宣称归零。 |
| 8 | 数据库行锁能否保证同设备同时段预约串行化？ | **能，且这是最终防线，条件有三**：(a) **所有**写入路径（创建/调整/维护创建）都先对同一设备执行 `selectByIdForUpdate`；(b) 它是**事务内第一条语句** —— labplatform 实测 REPEATABLE-READ，RR 快照在首个一致性读时建立，先 FOR UPDATE（当前读）再跑冲突 SELECT，快照必然包含其他事务已提交的占用，避免幻影漏检；(c) 冲突检查在行锁内执行。三条满足时，同设备并发创建被 InnoDB 行锁物理串行化，**与 Redis 锁是否失效无关**。 |
| 9 | 异常、超时、Redis 故障时如何安全拒绝或回滚？ | 锁获取失败（有界 tryLock 超时）→ **快速失败**拒绝创建（返回忙错误）；**Redis 不可达 → fail-closed**：预约创建直接拒绝，**禁止降级为无锁执行**；DB 异常 → 事务自动回滚 + finally 释放锁（`isHeldByCurrentThread` 已判空保护）；持锁进程崩溃 → watchdog 停止 → 租约到期自动释放，DB 事务随连接断开回滚，无脏数据。 |
| 10 | 多租户锁键是否隔离？ | ✅ suspendKey 含 tenantId（`instrument:suspend:{tenant}:user:{userId}`）；`ReservationNoRedisDAO.buildKey` 含 tenantId；设备行锁的租户隔离由 DB 拦截器保证（跨租户读取为 null）。03-C 若新增设备维 Redis 锁，键必须同样含 tenantId（`instrument:reservation:{tenant}:device:{deviceId}` 格式建议）。 |

### 4.2 Redisson watchdog 局限性（明确声明）

1. **仅在未指定 leaseTime 时启用**：`lock(10_000, MILLISECONDS)` 显式关闭了 watchdog；改用 `lock()` / `tryLock(waitTime, -1, unit)` 才有默认 30s watchdog（每 lockWatchdogTimeout/3≈10s 续期）。
2. 续期依赖**客户端存活 + Redis 可达**：FGC 停顿、网络抖动、Redis 故障均可导致续期失败 → 锁过期易主，且**原持有者无感知**。
3. Redis 主从异步复制下 failover 可能**整体丢锁**（RedLock 也无法完全消除该类风险）。
4. watchdog 无限续期 → **长事务/死循环会锁泄漏**：必须配合有界 tryLock、锁内事务尽量短、DB 层兜底。
5. **结论：Redis 锁（含 watchdog）只用于降低竞争与协调跨实体顺序（suspendKey 先于设备锁，解决问 7 的可见性竞态）；互斥正确性的最终保证是 DB 层三件套 —— 设备行锁串行化、条件更新（status='PENDING' 等 affectedRows 守卫）、`uk_reservation_tenant_no` 唯一索引。**

### 4.3 推荐技术结构（待负责人批准后 03-C 实施，**本任务未实施**）

```text
预约创建（03-C 目标结构）：
tryLock(suspendKey, 有界等待)                 ← B1 方案 A 第一层
  └─ transactionTemplate.execute {           ← 编程式事务（禁用外层 @Transactional）
        device = selectByIdForUpdate(deviceId) ← 事务第一条语句：设备行锁 + 建立快照时点
        P1/P2/P3 设备可预约校验（锁内）
        P4 资质复核（status=ACTIVE 且 expire_time NULL/>now，B2）
        P5 暂停复核（suspendKey 已持有 → 已提交暂停必然可见，B3）
        P8 冲突复核（ReservationConflictChecker，快照含全部已提交占用）
        reservationNo = ReservationNoRedisDAO.generate(tenantId)（B8）
        insert reservation（uk_reservation_tenant_no 兜底）+ insert history
     }                                        ← DB commit 在锁回调内
  finally: unlock（isHeldByCurrentThread 保护）
Redis 不可达/tryLock 超时 → fail-closed 拒绝创建
```

---

## 五、B1 修复范围（设计，本任务不改造代码）

| 项 | 设计结论 |
| --- | --- |
| 需要修改的文件 | ① `InstrumentLockRedisDAO`：**新增** watchdog/tryLock 方法（如 `tryLockWithWatchdog(key, waitTimeMs, callable)`，用 `tryLock(waitTime, -1, TimeUnit)`）；**不改**既有 `lock(key, callable)` 10s 方法签名与行为。② 03-C 预约 Service + 锁协调器（新类，按 §4.3 结构）。③ 测试类。 |
| 是否影响现有暂停创建/解除暂停 | **否**。`createSuspend`/`releaseSuspend` 代码路径零改动。 |
| 是否影响 INSTRUMENT-02 已通过并发测试 | **否**。仅在同一 DAO 增加新方法；旧方法与调用方不变。 |
| 是否需要新增锁协调器 | **是**（03-C），实现 suspendKey → 事务 → 设备行锁 → 复核 → 写入 → commit → 解锁的固定时序。 |
| 是否需要数据库事务内二次校验 | **是**。P4 资质 / P5 暂停 / P8 冲突必须在 `selectByIdForUpdate` 之后、insert 之前锁内复核（快照时点正确性见问 8）。 |
| 冻结规则 | 不修改 INSTRUMENT-02 已冻结的暂停业务语义（H1/G12/G13/R9）；协调器只编排顺序，不改规则。 |

### 5.1 测试计划（03-C 验收用）

| 用例 | 方法 |
| --- | --- |
| 锁失效 | 事务内注入延迟（> 租约时长）模拟长事务，验证：watchdog 路径下不发生易主提交；对照固定租约路径复现风险 |
| 长事务 | 慢 SQL/大延迟下确认 watchdog 续期生效、锁不提前释放 |
| 重复预约 | N 线程同设备同时段并发创建 → **恰好 1 条成功**，其余收到可识别冲突错误（09 号验收①） |
| 暂停与预约同时创建 | 线程 A 创建暂停 / 线程 B 同用户创建预约并发 → 验证锁序与 P5 复核后无"暂停生效期间新建预约" |
| Redis 故障 fail-closed | 停 Redis → 预约创建拒绝、暂停创建按既有路径行为记录，无降级无锁执行 |
| 边界 | 相邻时段不冲突（09 号验收②，H2 已过，真实库执行后回归） |

### 5.2 03-C HOLD 解除标准

同时满足以下四项，方可解除 26 号报告的 B1 HOLD：

1. 锁协调器按 §4.3 结构落地（suspendKey 有界 tryLock → 编程式事务 → 设备行锁为事务首语句 → 锁内复核 → commit 在锁内 → finally 解锁），并经代码评审确认无反向锁序、无 `@Transactional` 外层反模式。
2. 预约路径使用 watchdog 续期锁；fail-closed 策略实现（Redis 故障拒绝创建）。
3. §5.1 用例在真实 Redis + 真实 MySQL 环境全部通过（含重复预约恰好 1 条成功）。
4. 残余风险（问 7 竞态窗口）在报告中如实记录并获负责人接受。

---

## 六、总体结论

| 项 | 结论 |
| --- | --- |
| 真实库预检 | ✅ labplatform / MySQL 8.0.12 / RR；11 张既有表齐全；五张目标表均不存在（无同名冲突，无 HOLD）；公共六列与设计稿一致；设备 id=1/2、manager 3 行完好 |
| SQL 设计稿 | ✅ **PASS**（本次新增 §0.0 目标库确认，其余未改动） |
| `selectByIdForUpdate` / 租户隔离 | ✅ SQL 含主键 + deleted=0；租户隔离由拦截器保证（DO 继承 TenantBaseDO 已核实） |
| B1 锁方案 | 设计完成（§4/§5）：确认固定 10s 租约存在"提交前失效"可能；确认 `createSuspend` 已具备正确"锁外层 + 事务内层"结构，03-C 必须沿用并增加 watchdog + fail-closed + 事务内二次校验；DB 层设备行锁 + 条件更新 + 唯一索引为最终防线 |
| **03-A 是否满足提交执行授权条件** | ✅ **满足**。SQL 设计稿 PASS + 预检无阻断 + 文档冻结一致。**是否执行 DDL 由负责人另行授权（代码/审查通过 ≠ 执行授权）。** |
| 全程数据库写入次数 | **0**（仅 SELECT 与一次会话级 USE；命令清单见 §1.1） |

---

## 七、负责人下一步操作

1. **审查本报告与 SQL 设计稿**（[20261015_instrument_03_schema.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_03_schema.sql)，含新增 §0.0）。
2. **授权执行 DDL**：在 `labplatform` 库按脚本顺序执行——先跑 §0 全部预检（0.0~0.4.4，全部符合预期），再执行 §1 五表 DDL，然后执行 §2 验收 SELECT（2.1~2.6）。
3. **回传执行结果与执行后只读核验结果**（含 2.6 既有数据对比：device 仍 2 行且 id=1/2 在、manager 仍 3 行）。回传后 03-A 正式关闭、启动 03-B。
4. **批准 B1 修复设计**（§4.3/§5）：确认"锁协调器 + watchdog + fail-closed + 事务内二次校验"方案与 §5.2 四项 HOLD 解除标准，03-C 按此实施。
5. （执行 DDL 后建议）在真实库对冲突 SQL 补跑 `EXPLAIN`，确认 `idx_device_time` 生效。

---

## 后续状态（2026-10-15 追加，原始结论未改动）

第七节第 2、3、5 项已于同日完成（TASK INSTRUMENT-03-A-DDL-EXEC-01）：DDL 执行授权获批 → §0 预检全项通过 → 5/5 CREATE TABLE 成功 → §2 验收全项 PASS → 冲突 SQL EXPLAIN 实测 `idx_device_time`（type=range，ICP）。**03-A 正式关闭。** 执行明细见 28 号报告 A 部分。B1 修复（§4.3/§5）仍按原设计留待 03-C 实施；03-C HOLD 维持，解除标准见本报告 §5.2。
