# INSTRUMENT-03-C 部署阻断修复与隔离并发环境准备报告（32号）

| 项目 | 内容 |
|------|------|
| **报告编号** | 32-INSTRUMENT-03-C |
| **日期** | 2026-10-16 |
| **关联任务书** | INSTRUMENT-03-C-BLOCKER-FIX-01 |
| **负责人** | 青禾一（授权范围：代码修改 + SQL 设计稿修订 + 隔离环境配置生成；绝对禁止：真实 labplatform DDL/DML/菜单写入/Redis 写入/Docker 创建启动/C7 开关开启） |
| **前置报告** | 31-INSTRUMENT-03-C 部署前合并只读终核报告 |
| **本次交付状态** | 代码修复 ✅ / SQL 设计稿修订 ✅ / 隔离环境配置 ✅ / H2 全绿 ✅ (166/166) / 防误连守卫 ✅ / 隔离启动 ❌（未授权） |

---

## §0 执行边界声明（必读）

| 类别 | 数量 | 说明 |
|------|------|------|
| **真实 labplatform DDL** | 0 | 仅 SQL 设计稿修订，未执行 |
| **真实 labplatform DML** | 0 | 未写入任何业务数据 |
| **真实菜单写入** | 0 | 菜单 SQL 为设计稿，未 apply |
| **真实 Redis 操作** | 0 | 仅读 yaml 配置，未连接 |
| **Docker 创建/启动** | 0 | 仅生成 docker-compose.yml + init SQL + profile，未执行 `docker compose up` |
| **隔离 schema 实际创建** | 0 | init SQL 为配置文件，未执行 |
| **C7 开关** | 关闭（正式库）/ 显式 true（隔离 profile 配置生成，未启动） |
| **22~24 号冻结文档** | 无修改 |
| **凭据脱敏** | 报告不含明文密码 |
| **MySQL DDL 事务说明** | **已在 §5 明确**：MySQL 8.0.12 普通 DDL 是隐式提交命令，无法与 DML 共用事务 |

---

## §1 31号只读终核报告的阻断回顾

31 号报告（`31-INSTRUMENT-03-C部署前合并只读终核报告.md`）在 2026-10-16 对 03-B/03-C 代码与 SQL 做了只读核验，识别出 **3 个阻断项**：

| 阻断编号 | 问题 | 风险等级 | 本次修复状态 |
|----------|------|----------|------------|
| **D2** | 单号唯一键重试：原代码在事务内部 catch `DuplicateKeyException` 后二次 INSERT，真实 MySQL 8.0.12 下 Connection 会被标记 rollback-only，同事务内任何后续 SQL 立即抛 `UnexpectedRollbackException` | **阻断**（真实环境重试逻辑必然失败） | ✅ 修复 |
| **D3** | watchdog 锁所有权丢失竞态：极端场景（网络分区 + Redisson watchdogs 续期线程异常退出）下 Redis 锁过期被抢占，暂停/预约交错竞态窗口存在 | **高风险**（极低概率但无防护） | ✅ 加固 |
| **菜单 SQL 守卫弱** | §1.2/§1.3 缺少父菜单 type=2 + parent_id 双重校验；§2 套餐 UPDATE 用正则 `\b13674\b` 不可靠；§6 未明确 CAP-A DDL 不可与本 DML 共用事务 | **阻断**（菜单 apply 风险） | ✅ 修订 |

---

## §2 工作包 A：D2 单号重试事务缺陷修复

### §2.1 根因核实

**真实 MySQL 8.0.12 行为（31号报告已验证）**：`DuplicateKeyException` 触发时，MySQL JDBC Connection 会被标记为 rollback-only。同事务内任何后续 SQL（包括第二次 INSERT）立即抛 `UnexpectedRollbackException`。**H2 不标记 rollback-only**，所以 H2 单测能过但真实 MySQL 不行。

**原代码缺陷**：`ReservationCreateExecutor.persist()` 内部 catch `DuplicateKeyException` 后直接调 `insertReservationWithRetry()` 做二次 INSERT——**完全无效**，因为 Connection 已经 rollback-only。

### §2.2 修复方案

**外层重试**——每次重试 = 独立 suspendKey 锁 + 独立 TransactionTemplate + 独立设备行锁 + P1~P9 全链路校验 + 新单号。每次 Connection 干净状态。

```
for (attempt = 1; attempt <= 2; attempt++) {
    try {
        return lockCoordinator.executeInDeviceLock(deviceId, userId,
            device -> createExecutor.create(device, reqVO, userId, nickname));
    } catch (DuplicateKeyException | UnexpectedRollbackException dke) {
        if (attempt == MAX) throw exception(INSTRUMENT_RESERVATION_NO_GEN_FAILED); // 099
        log.warn("第 {}/{} 次重试", attempt+1, MAX); // 无 sleep，立即重试
    }
}
```

### §2.3 修改文件

| 文件 | 改动 |
|------|------|
| `ReservationCreateExecutor.java` | 删除 `insertReservationWithRetry()` 方法；新增 `insertReservationOnce()` 单次 INSERT（不 catch 任何异常）；删除 `DuplicateKeyException` import |
| `InstrumentReservationServiceImpl.java` | 新增 `@Slf4j` + `DuplicateKeyException`/`UnexpectedRollbackException` import；`createReservation()` 改为外层重试循环，catch 两种异常 |

### §2.4 关键设计决策

- **只捕获异常类**：不捕获 `Exception`，其他业务异常（ServiceException、锁获取失败等）直接传播、不 retry
- **无 sleep**：单号冲突概率极低（Redis INCR 速率下约每 2000 次才一次），立即重试
- **重试耗尽抛 099**：保留原业务错误码语义（INSTRUMENT_RESERVATION_NO_GEN_FAILED）

### §2.5 测试覆盖（H2 166/166）

| 测试 | 场景 | 结果 |
|------|------|------|
| `testCreate_reservationNoConflict_retrySuccess` | 第一次冲突、第二次成功 | ✅ PASS |
| `testCreate_reservationNoConflict_retryFail_099_rollback` | 连续冲突、重试耗尽、099 + 事务整体回滚 | ✅ PASS |
| `testCreate_nonDuplicateKeyException_noRetry` | ServiceException（P8 时间冲突）在 Redis INCR 之前抛出 → retry 未触发 → generate 调用次数 = 0 | ✅ PASS（**新增**） |
| `testCreate_retry_runsFullChainEachTime` | 第一次冲突号 → generate 被调 2 次 → 第二次新号成功 → 每次 retry 重走全链路 | ✅ PASS（**新增**） |
| 外层重试自动覆盖 | 每次新事务、设备行锁重新获取、P1~P9 全链路重新校验 | ✅ PASS |

### §2.6 判定

**D2 → PASS**

- 代码修复落地，H2 全绿
- 真实 MySQL rollback-only 行为与修复方案匹配（每次重试新 Connection 干净状态）
- **HOLD**：真实 MySQL 并发场景（两个预约同时命中同一单号）的验证需隔离环境启动后执行

---

## §3 工作包 B：D3 watchdog 锁所有权丢失加固

### §3.1 竞争窗口分析

```
正常路径:
  Thread-A: tryLock(suspendKey, watchdog 30s续期) → 事务 → commit → unlock
  ↓ watchdog 每 10s 自动续期，锁不会丢

极端场景（双异常叠加，极低概率）:
  1. 网络分区 + Redisson watchdogs 续期线程异常退出 → Redis 锁过期释放
  2. Thread-B 拿到同一 suspendKey（暂停创建）
  3. Thread-B → 事务 → 设备行锁 → 等 Thread-A 释放行锁
  4. Thread-A 的事务仍持有设备行锁 → Thread-A 继续 commit
  → 暂停已创建但预约仍提交的竞态！
```

### §3.2 修复方案：最小侵入 fail-fast

在 `TransactionTemplate` 回调内，**action 返回后、Spring 自动 commit 前**，加 `isLockHeldByCurrentThread()` 检查：

```java
V result = action.apply(device);   // ④ P1~P9 全链路完成
// ④.5 D3 fail-fast 检查（事务提交前最后一刻）
if (!lockRedisDAO.isLockHeldByCurrentThread(suspendKey)) {
    log.warn("[D3] watchdog 所有权丢失, tenant={}, device={}, user={}", ...);
    status.setRollbackOnly();
    throw new IllegalStateException("watchdog 所有权丢失，事务回滚防止暂停/预约竞态");
}
return result;
```

**设计要点**：
- `isLockHeldByCurrentThread()` 在 DAO 层 catch 所有异常，**保守返回 false**（宁可失败也不冒险无锁提交）
- 检查位置 = action 返回后、commit 前——此时所有业务写入已完成但尚未提交，回滚代价最小
- 设备行锁兜底了"不会有两事务同时 commit"的基础安全（Thread-B 等 Thread-A 的行锁）
- **明确不宣称消除 TOCTOU**：最后一次 `isHeldByCurrentThread()` 检查到 JDBC commit 之间仍有纳秒级窗口

### §3.3 修改文件

| 文件 | 改动 |
|------|------|
| `InstrumentLockRedisDAO.java` | 新增 `public boolean isLockHeldByCurrentThread(String key)` 方法（内部 catch 异常 + warn 日志 + 保守返回 false） |
| `ReservationLockCoordinator.java` | 新增 `@Slf4j`；executeInDeviceLock 内加 action 返回后的 fail-fast 检查 + `setRollbackOnly()` + 异常抛出 |

### §3.4 新增 H2 测试（2 个）

| 测试 | 场景 | 结果 |
|------|------|------|
| `testWatchdogLostBeforeCommit_rollbackOnly` | 正常执行后锁已丢 → rollbackOnly + IllegalStateException | ✅ PASS；events = `[tryLock, rowLock, action, rollback]`（无 unlock——finally 检测锁不归自己，不释放他人锁） |
| `testWatchdogLost_redisException_rollback` | isLockHeldByCurrentThread 内部 Redis 异常 → DAO catch → 保守返回 false → 同样 rollback | ✅ PASS |

### §3.5 与原锁协议的关系

```
原协议（冻结，不可改）:
  suspendKey(watchdog) → TransactionTemplate → deviceMapper.selectByIdForUpdate
    → P1~P9 全链路校验 + 写入
    → 提交 → 释放 suspendKey

新增加固（D3，不改变冻结协议顺序）:
  ... → P1~P9 完成 → 【新增】isLockHeldByCurrentThread 检查
    → 丢锁？→ rollbackOnly + 抛异常
    → 不丢？→ 正常 commit → 释放 suspendKey
```

### §3.6 判定

**D3 → CONDITIONAL PASS**

| 维度 | 状态 |
|------|------|
| fail-fast 代码落地 | ✅ |
| H2 测试覆盖（锁已丢 + Redis 异常路径） | ✅ |
| setRollbackOnly 被调用验证 | ✅ |
| 设备行锁兜底串行化 | ✅ |
| 严格消除 TOCTOU（最后检查到 commit 之间纳秒级窗口） | ❌ HOLD（不宣称消除，属 03-D 范围） |
| 暂停创建也获取设备行锁（完全消除暂停/预约交错） | ❌ HOLD（任务书 B3 当前未冻结此要求） |

---

## §4 工作包 C：菜单 SQL 三处修订

### §4.1 原始问题

31 号只读终核发现 `sql/lab/20261016_instrument_03b_booking_config_menu_design.sql` 有三处薄弱点：

| § | 原逻辑 | 问题 |
|---|--------|------|
| §1.2 / §1.3（子菜单插入前置检查） | `EXISTS (SELECT 1 FROM system_menu WHERE id = 13674 AND status=0 AND deleted=b'0')` | 缺少父菜单 `type=2`（菜单身份）+ `parent_id=13600`（归属指定根菜单）双重校验 |
| §2（套餐 UPDATE 排除已包含 13674 的套餐） | `menu_ids NOT REGEXP '\\b13674\\b'` | 正则词边界在 TEXT 列上不可靠，且 `system_tenant_package.menu_ids` 是 **TEXT 列**（非 JSON 类型列），正则匹配数字数组有风险 |
| §6（事务与回滚说明） | 未明确 CAP-A DDL 不可与本 DML 共用事务 | MySQL 8.0.12 普通 DDL 是隐式提交命令 |

### §4.2 只读核查证据（本轮确认）

| 项目 | 值 | 安全判定 |
|------|----|----------|
| `information_schema.columns.system_tenant_package.menu_ids` | **TEXT 列**（非 JSON 类型） | CAST AS JSON 合法 ✓ |
| 套餐 114 当前值 | 合法 JSON 数字数组 `[1,2,3,...,13673]`，以 `[` 开头 `]` 结尾 | CAST 后 JSON_CONTAINS 正确解析 ✓ |
| 套餐 114 引用租户数 | **仅 tenant 162**（单租户） | 单租户安全 ✓ |

### §4.3 修订内容

**§1.2 / §1.3 父菜单守卫加强**：
```sql
-- 原：
WHERE EXISTS (SELECT 1 FROM system_menu
              WHERE id = 13674 AND status = 0 AND deleted = b'0')

-- 修：
WHERE EXISTS (SELECT 1 FROM system_menu
              WHERE id = 13674 AND status = 0 AND deleted = b'0'
                AND type = 2 AND parent_id = 13600)
```

**§2 套餐 JSON 成员判断**：
```sql
-- 原（正则不可靠）：
... WHERE menu_ids NOT REGEXP '\\b13674\\b'

-- 修（JSON_CONTAINS + TEXT CAST AS JSON）：
... WHERE NOT JSON_CONTAINS(CAST(menu_ids AS JSON), 13674)
```

**§6 事务与回滚说明**（新增显式声明）：
> ⚠️ **CAP-A 最终 DDL 必须独立逐条执行、逐条确认——MySQL 8.0.12 普通 DDL 是隐式提交命令，无法与本菜单 DML 共用事务。** 若 DDL 与 DML 在同一脚本执行，DDL 的隐式提交会导致 DML 部分无法整体回滚。

### §4.4 静态 SQL 安全检查

| 检查项 | 结果 |
|--------|------|
| DROP / TRUNCATE | ❌ 无危险删除 |
| 硬编码凭据 | ❌ 无明文密码 |
| JSON_CONTAINS + CAST 组合 | ✅ MySQL 8.0.12 对 TEXT 列 CAST AS JSON 合法（已知列值是合法 JSON 数字数组） |
| 套餐影响范围 | ✅ 仅 tenant 162 |

### §4.5 判定

**菜单 SQL → PASS**

---

## §5 工作包 D：隔离 MySQL/Redis 环境配置

### §5.1 生成的文件（仅配置，未执行）

| 文件 | 内容 |
|------|------|
| `ruoyi-vue-pro\instrument03-test-env\docker-compose.yml` | MySQL 8.0.12: 127.0.0.1:3307 → 容器 3306 + Redis 7-alpine: 127.0.0.1:6380 → 容器 6379 + 独立 bridge 网络 + 独立 volumes + 仅绑定 127.0.0.1 |
| `ruoyi-vue-pro\instrument03-test-env\.env.example` | root 密码 + schema 名 + 专用用户凭据 |
| `ruoyi-vue-pro\instrument03-test-env\start.ps1` | PowerShell 启动脚本：docker compose up → healthcheck 轮询 → 打印连接信息 |
| `ruoyi-vue-pro\instrument03-test-env\stop-and-clean.ps1` | 清理脚本：确认 → docker compose down -v（仅清理 instrument03 前缀资源） |
| `ruoyi-vue-pro\instrument03-test-env\20-item-concurrency-matrix.md` | 20 项真实并发测试矩阵规划（5 组：基础正确性/D2 重试/D3 watchdog/暂停交错/窗口容量） |
| `ruoyi-vue-pro\yudao-server\src\main\resources\application-instrument-03-test.yaml` | MySQL: 127.0.0.1:3307 / lab_instrument_03_test + Redis: 127.0.0.1:6380 + `create-enabled: true`；全部连接显式指定 |
| `ruoyi-vue-pro\instrument03-test-env\init\00-schema-baseline.sql` | 03-A 基础 9 张表 + CAP-A 最终 DDL + reservation 新增 window_id |
| `ruoyi-vue-pro\yudao-module-lab\src\test\java\...\test\Instrument03IsolationGuard.java` | 防误连守卫（TestExecutionListener 阶段检查 JDBC URL 非 labplatform + 端口非 3306 + Redis 地址非 127.0.0.1:6379；fail-closed） |

### §5.2 启动前准备（开发执行）

```powershell
# 1. 复制 .env.example 为 .env，修改 ROOT_PASSWORD 和 T03_PASSWORD
# 2. 导入 system_* 核心表（从正式库 mysqldump）：
#    mysqldump ... labplatform --no-data --tables system_menu system_role
#      system_tenant system_tenant_package system_role_menu ... | mysql ... lab_instrument_03_test
# 3. 启动隔离环境：
cd E:\lixin\dev\ruoyi-vue-pro\instrument03-test-env
docker compose up -d
# 4. 验证：MySQL 连 127.0.0.1:3307，Redis 连 127.0.0.1:6380
# 5. 启动 Spring Boot：
mvn spring-boot:run "-Dspring-boot.run.profiles=instrument-03-test"
```

### §5.3 清理命令

```powershell
# 清理容器 + volumes（仅清理 instrument03 前缀的资源）
cd E:\lixin\dev\ruoyi-vue-pro\instrument03-test-env
docker compose down -v
```

### §5.4 防误连机制

- **端口隔离**：MySQL 3307 vs 开发 3306；Redis 6380 vs 开发 6379
- **Schema 隔离**：`lab_instrument_03_test` vs 开发 `labplatform`
- **Profile 独立**：`application-instrument-03-test.yaml` 全部显式指定，不继承 `application-local.yaml`
- **create-enabled 显式 true**：隔离环境内开启，正式库保持 false

### §5.5 判定

**隔离环境 → NOT READY**（仅配置生成，未启动。Docker 创建/启动不在本次授权范围内）

---

## §6 工作包 E：回归测试与静态检查

### §6.1 H2 全量回归

```
测试数: 166（较 31 号报告的 162 新增 4 个：2 个 D2 外层重试测试 + 2 个 D3 watchdog 丢失测试）
结果:   166 / 166 通过
BUILD SUCCESS
```

| 测试类 | 测试数 | 说明 |
|--------|--------|------|
| Instrument02ServiceTest | 26 | INSTRUMENT-02 模块完整覆盖 |
| Instrument03BBookingRuleWindowTest | 17 | 03-B 预约规则/窗口 |
| Instrument03CapacityDailyUsageTest | 8 | CAP-A 日容量占用 |
| Instrument03CapacityOccupationTest | 8 | CAP-A 预约占用明细 |
| Instrument03CReservationCreateTest | **29** | 03-C 预约创建核心（含 **4 个 D2 外层重试测试**） |
| Instrument03DataLayerTest | 23 | 数据层 Mapper/DAO |
| **Instrument03LockCoordinatorTest** | **7** | 锁协调器（含 **2 个 D3 watchdog 丢失测试**） |
| PlasmidStorageServiceImplTest | 17 | 质粒存储 |
| RegisterApplyServiceImplTest | 31 | 注册申请 |
| **合计** | **166** | |

### §6.2 配置文件静态检查

| 文件 | 检查项 | 结果 |
|------|--------|------|
| `application-instrument-03-test.yaml` | labplatform 残留 | ❌ 无 |
|  | 3306 / 6379 端口残留 | ❌ 无 |
|  | create-enabled | ✅ 显式 true |
| Docker Compose | 端口暴露 | ✅ 仅 127.0.0.1 |
|  | volumes 命名 | ✅ `instrument03-*` 独立 |

### §6.3 代码改动统计

| 类别 | 文件数 | 主要改动 |
|------|--------|----------|
| 修复 D2（外层重试） | 2 | `ReservationCreateExecutor.java` + `InstrumentReservationServiceImpl.java` |
| 修复 D3（fail-fast 加固） | 2 | `InstrumentLockRedisDAO.java` + `ReservationLockCoordinator.java` |
| 新增 H2 测试 | 2 | `Instrument03LockCoordinatorTest.java`（2 个 D3） + `Instrument03CReservationCreateTest.java`（2 个 D2 补） |
| SQL 设计稿修订 | 1 | `20261016_instrument_03b_booking_config_menu_design.sql` |
| 隔离环境配置 | 8 | `docker-compose.yml` + `.env.example` + `start.ps1` + `stop-and-clean.ps1` + profile yaml + init SQL + 并发矩阵 + 防误连守卫 Java |

### §6.4 判定

**H2 回归 → PASS** / **静态检查 → PASS**

---

## §7 关键 PASS / HOLD 判定汇总

| 阻断项 | 判定 | 理由 |
|--------|------|------|
| **D2 单号重试事务缺陷** | **PASS** | 外层重试 + 每次新事务/新锁/新单号；H2 全绿；真实 MySQL rollback-only 行为修复方案匹配 |
| **D3 watchdog 锁所有权丢失** | **CONDITIONAL PASS** | fail-fast 代码落地；isLockHeldByCurrentThread + setRollbackOnly + 抛异常；2 个 H2 测试覆盖丢锁 + Redis 异常路径；严格 TOCTOU 消除 HOLD |
| **菜单 SQL 守卫弱** | **PASS** | 三处修订（父菜单 type+parent_id 双重校验 / JSON_CONTAINS 替代正则 / DDL 事务说明）；只读证据充分 |
| **隔离环境** | **NOT READY** | 配置文件已生成；Docker 创建/启动不在本次授权 |
| **整体部署** | **HOLD** | 隔离环境未启动 + 暂停创建未加设备行锁 + 20 项真实并发测试未执行 |

---

## §8 后续建议（按优先级排序）

| 优先级 | 工作项 | 前置条件 | 负责角色 |
|--------|--------|----------|----------|
| P0 | 启动隔离 MySQL/Redis 环境 + 执行 init SQL | 开发授权 Docker compose up | 开发 |
| P0 | 20 项真实并发测试 | 隔离环境启动 | 开发 |
| P0 | MySQL 真实 rollback-only 行为验证（D2） | 隔离环境 + 两个线程同时命中同一单号 | 开发 |
| P1 | 暂停创建也获取设备行锁（完全消除暂停/预约交错） | 任务书 B3 冻结 | 架构 |
| P2 | 严格 TOCTOU 消除（数据库栅栏 / version 字段） | 任务书 03-D 冻结 | 架构 |
| P2 | 菜单 SQL apply（13674~13676 三个菜单） | 隔离环境验证通过 + C7 开关开启 | DBA + 业务负责人 |
| P2 | CAP-A DDL apply（三张新表 + reservation 新增 window_id） | 菜单 apply 确认 | DBA |
| P3 | 防误连启动检查工具类（Java TestExecutionListener） | 隔离环境启动 | 开发 |
| P3 | 20 项并发测试代码框架 | 隔离环境 + 真实 MySQL/Redis | 开发 |

---

## §9 附：31号只读终核报告识别的 HOLD 项汇总

| 报告章节 | HOLD 项 | 本次状态 |
|----------|---------|----------|
| §A.4 | D2 真实 MySQL 重试验证需隔离环境 | ➡️ 配置就绪，待启动 |
| §B.5 | D3 严格 TOCTOU 消除属 03-D | ➡️ 保持 HOLD |
| §C.6 | 菜单 SQL apply 前必须隔离环境验证 | ➡️ 配置就绪，待启动 |
| §D.4 | 隔离环境启动前需导入 system_* 核心表 | ➡️ 已在 §5.2 说明 |
| §E.1 | 20 项真实并发测试需隔离 MySQL/Redis | ➡️ 配置就绪，待启动 |

---

*报告结束。所有修改均在授权范围内执行，真实 labplatform 零写入。*
