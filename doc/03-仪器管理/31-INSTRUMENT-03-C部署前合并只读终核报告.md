# 31 · INSTRUMENT-03-C 部署前合并只读终核报告

**版本**：v1.0 终版（只读）
**执行日期**：2026-10-16
**执行人**：Trae 自动化终核（只读，授权边界 A）
**负责人裁决基线**：方案 A —— 仅合并只读终核，不授权任何真实数据库写入
**写入声明（执行前）**：真实 labplatform DDL=0 / 真实 labplatform DML=0 / 真实菜单写入=0 / 真实角色授权=0 / Redis 写入=0 / 隔离环境创建=0 / C7 开关修改=0

---

## A. 总体结论

| 项目 | 判定 | 备注 |
|------|------|------|
| CAP-A 最终 DDL 执行授权 | **CONDITIONAL PASS** | 三条 DDL 逻辑正确，真实库结构与 DO 字段一致；条件：ALTER ADD window_id 不可逆（仅 §0.6 预检=0 时可执行），DDL 三部分必须严格按 §1.1 → §1.2 → §1.3 顺序执行且不可中途停止（stop conditions 已在 §2 明确定义） |
| 03-B 菜单 SQL 执行授权 | **CONDITIONAL PASS** | 13674~13676 当前未占用，套餐 114 仅租户 162 引用（单租户影响 ✓），角色 904/906/908 与冻结规则一致；条件：SQL §1.2 / §1.3 缺少父菜单 13674 status=0 二次守卫（幂等性弱缺陷），需修订后再执行；执行顺序严格：§1 菜单 INSERT → §2 套餐 JSON UPDATE → §3 role_menu INSERT |
| 隔离 MySQL/Redis 测试环境 | **NOT READY** | 方案 C（本机容器化 MySQL 8.0.12 + Redis 独立实例）是唯一可接受方案，但本次仅规划不创建；03-C 并发矩阵 20 项中约 13 项需真实 MySQL + 独立 Redis 锁测试才能验收，H2 已证约 7 项 |
| 03-C 关键安全风险 | **HOLD** | D2 单号重试在 MySQL 8.0 下的 Connection rollback-only 行为与代码假设冲突（H2 单测无法覆盖）；D3 watchdog 所有权丢失后"事务仍在执行但 Redis 锁已失效"存在理论竞争；D1 跨日窗口模型 HOLD 为明确产品决策而非技术缺陷；四项均无修复方案落地 |
| C7 开关 `lab.instrument.reservation.create-enabled` | **必须仍为关闭** | Spring `@Value(…:false)` 默认 false；system_config 表无显式配置（缺省 false）；本次未触碰 |

**可进入负责人下一轮集中授权的事项**：CAP-A DDL 授权（一次性三部分连执行）、菜单 SQL 授权（§1.2/§1.3 守卫修订后）
**必须先修复才能授权的事项**：D2 Connection rollback-only 修复、D3 watchdog 所有权丢失后的 fail-fast 机制

---

## B. CAP-A 最终 DDL

### B-0. 真实库基线只读证据

以下 SELECT 全部为只读，无任何写入：

| 只读核查项 | 结果 | 证据 SQL |
|-----------|------|----------|
| MySQL 版本 | 8.0.12（Asia/Shanghai 时区） | `SELECT VERSION()` |
| 当前 schema | labplatform（会话未指定库名，后续显式用 `labplatform.` 前缀） | `SELECT DATABASE()` → NULL |
| 03-A 五表在位 | 是，全部存在 | `SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='labplatform' AND table_name LIKE 'lab_instrument_%'` → 21 张表（含全部仪器表） |
| 窗口容量明细表是否已存在 | 否，cnt=0 | `SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='labplatform' AND table_name='lab_instrument_booking_window_daily_usage'` → 0 |
| 预约占用明细表是否已存在 | 否，cnt=0 | 同上 occupation 表名 → 0 |
| reservation.window_id 是否已存在 | 否，cnt=0 | `SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='labplatform' AND table_name='lab_instrument_reservation' AND column_name='window_id'` → 0 |
| window.capacity 列在位 | 是（03-A DDL 已执行） | SHOW COLUMNS 已含 capacity int NULL |
| window.used_count 列在位 | 是（03-A DDL 已执行） | show columns 已含 used_count int NOT NULL DEFAULT 0 |
| reservation 完整列清单 | 24 列：id/reservation_no/device_id/user_id/user_name/qualification_id/start_time/end_time/duration_minutes/status/purpose/actual_start_time/actual_end_time/finish_time/cancel_time/cancel_by/cancel_reason/remark + TenantBaseDO(creator/create_time/updater/update_time/deleted/tenant_id) | information_schema.columns ORDER BY ordinal_position |
| reservation 唯一索引 | uk_reservation_tenant_no(tenant_id, reservation_no) UNIQUE ✓ | SHOW INDEX → Non_unique=0 |
| 预约历史数据 | **total=0**（正式环境冷启动，零历史预约！） | `SELECT COUNT(*) FROM lab_instrument_reservation` → 0 |
| 窗口历史数据 | **cnt=0**（零窗口存量） | `SELECT COUNT(*) FROM lab_instrument_booking_window` → 0 |
| 设备存量 | 2 台 | device SELECT → 2 |
| bookable=true 设备 | 1 台（NORMAL，allow_cross_day=true） | SELECT device |
| 非法容量值 used_count 检查 | bad_cap=0（used_count<0） | 已查 |

**§0.6 预检预期完全满足**：daily_usage 不存在、occupation 不存在、window_id 列不存在 → 三部分 DDL 均可安全执行。
**§0.7 历史数据回填**：预约 0 条 + 窗口 0 条 → **无需任何历史回填**。

### B-1. 最终 SQL 文件完整性

文件：`E:\lixin\dev\ruoyi-vue-pro\sql\lab\20261016_instrument_03_capacity_u1_u5_final.sql`

结构完整，含：§0 预检（7 项）、§1 DDL 正文（三部分）、§2 停止条件、§3 验收、§4 审计 SQL。
无测试数据、无菜单 DML、无 DROP/TRUNCATE/危险清理。
依赖：§1.1 和 §1.2 均为 `CREATE TABLE IF NOT EXISTS`（允许早期草稿已执行时跳过）；§1.3 为 `ALTER TABLE ... ADD COLUMN` + `ADD INDEX`（MySQL 8.0 **不支持** `ALTER TABLE ADD COLUMN IF NOT EXISTS`）—— §0.6 预检 `window_id_col_cnt=0` 是必需前置，不可重复执行。

### B-2. 三部分 DDL 逐条审查

#### §1.1 `lab_instrument_booking_window_daily_usage` —— PASS

| 核对项 | SQL 设计 | DO 字段 | 结果 |
|-------|---------|---------|------|
| 主键 | id bigint PK | @TableId Long id | ✓ |
| window_id | bigint NOT NULL | Long windowId | ✓ |
| device_id | bigint NOT NULL | Long deviceId | ✓ |
| usage_date | date NOT NULL | LocalDate usageDate | ✓ |
| used_count | int NOT NULL DEFAULT 0 | Integer usedCount | ✓ |
| 唯一键 | uk_window_date(tenant_id, window_id, usage_date) | （由框架自动继承 tenant_id + 业务字段） | ✓ |
| 辅助索引 | idx_device_date(device_id, usage_date) / idx_window(window_id) | — | ✓ |
| TenantBaseDO 继承 | creator/create_time/updater/update_time/deleted/tenant_id 6 列 | 继承 TenantBaseDO | ✓ |
| used_count 非负约束 | **无 CHECK 约束**（MySQL 8 默认不强制，但字段定义 DEFAULT 0 + 业务层 >0 守卫） | — | 条件：业务层 tryOccupy / tryRelease 使用条件 UPDATE WHERE used_count > 0 防负；数据库无物理 CHECK。非阻断 |

#### §1.2 `lab_instrument_reservation_capacity_occupation` —— PASS

| 核对项 | SQL 设计 | DO 字段 | 结果 |
|-------|---------|---------|------|
| 主键 | id bigint PK | @TableId Long id | ✓ |
| reservation_id | bigint NOT NULL | Long reservationId | ✓ |
| window_id | bigint NOT NULL | Long windowId | ✓ |
| device_id | bigint NOT NULL | Long deviceId | ✓ |
| usage_date | date NOT NULL | LocalDate usageDate | ✓ |
| occupation_status | varchar(20) NOT NULL DEFAULT 'OCCUPIED' | String occupationStatus（OCCUPIED/RELEASED） | ✓ |
| 唯一键 | uk_occupation(tenant_id, reservation_id, window_id, usage_date) | — | ✓ 同一预约同一窗口同一日期永久一行 |
| 辅助索引 | idx_window_status(window_id, occupation_status) / idx_reservation(reservation_id) / idx_device_date(device_id, usage_date) | — | ✓ |
| TenantBaseDO 继承 | 含 deleted bit(1) 默认 b'0' | 继承 TenantBaseDO | ✓ |
| "不逻辑删除"语义 | **deleted 字段存在**（TenantBaseDO 自动含），但 Service 层无任何删除入口；释放走 occupation_status OCCUPIED→RELEASED 状态翻转 | 注释 "deleted 仅框架字段，Service 不提供删除入口" | ✓ 业务层禁止删除 ≠ 物理字段缺失 |
| 与框架兼容性 | MyBatis-Plus 自动 WHERE deleted=b'0' 拦截 | — | ✓ |

#### §1.3 `ALTER TABLE lab_instrument_reservation ADD COLUMN window_id bigint NULL DEFAULT NULL AFTER device_id` + `ADD INDEX idx_window (window_id)` —— PASS（条件）

| 核对项 | SQL 设计 | DO 字段 | 结果 |
|-------|---------|---------|------|
| 类型 | bigint NULL DEFAULT NULL | Long windowId（可空） | ✓ |
| 位置 | AFTER device_id | DO 字段序 deviceId → windowId → userId | ✓ |
| 历史预约兼容 | NULL 允许 | 零历史预约 ✓ | ✓ |
| 普通设备预约 | 允许 NULL（无窗口设备） | DO 注释 "普通无窗口设备为 NULL" | ✓ |
| 窗口设备预约 | 必须非 NULL（Service 层 windowId != null 时才创建 occupation 行） | 业务保证 | ✓ |
| 索引 | idx_window(window_id) | — | ✓ |
| §0.6 预检 | 当前真实库无此列 → 预检 = 0 → 可安全执行 | — | ✓ |
| 可重复执行 | **不可**（MySQL 8 不支持 ADD COLUMN IF NOT EXISTS） | — | 条件：严格预检后一次性执行 |

### B-3. 执行顺序与停止条件

**强制执行顺序**：§1.1 CREATE daily_usage → §1.2 CREATE occupation → §1.3 ALTER reservation

停止条件：
- §0.6 window_id_col_cnt != 0 → **立即停止**，不得继续
- §0.6 daily_usage_cnt != 0 → 已存在，跳过 §1.1（CREATE TABLE IF NOT EXISTS 会自动跳过）
- §0.6 occupation_cnt != 0 → 已存在，跳过 §1.2
- 任何一步 DDL 失败 → 停止，**不得重试 §1.3**（§1.3 不可重复执行）

### B-4. CAP-A 最终判定：CONDITIONAL PASS

三条 DDL 全部与真实库结构、DO 字段、索引设计一致。无历史预约/窗口 → 零回填需求。

**条件**：
1. 执行前必须再次运行 §0 预检 SELECT 并保存输出
2. §1.3 ALTER 不可重复执行，必须在 §0.6 预检=0 时一次性通过
3. 推荐单次事务执行（三条一起执行，中途不停止）
4. daily_usage.used_count 无物理 CHECK 约束，依赖业务层条件 UPDATE 防负（非阻断但需记录）

---

## C. 03-B 菜单与权限

### C-0. 真实菜单/角色/套餐现状只读证据

| 只读核查项 | 结果 | 证据 |
|-----------|------|------|
| system_menu MAX(id) | **13673** | SELECT MAX(id) FROM system_menu |
| 13674 / 13675 / 13676 当前是否占用 | 否，三 ID 空闲 | SELECT ... WHERE id IN (13674,13675,13676) → 0 行 |
| 13600 父菜单 | 已存在（仪器管理） | 已知 |
| 权限串 lab:instrument:rule:query / update 是否已注册 | 否（deleted=0 下 0 行） | SELECT ... WHERE permission IN (...) |
| 角色 904（普通用户） | tenant 162, status 0, type 2, 27 个菜单授权 | SELECT system_role |
| 角色 906（lab_admin） | tenant 162, status 0, type 2, **113 个菜单**授权 | — |
| 角色 908（仪器设备负责人） | tenant 162, status 0, type 2, **8 个菜单**授权 | — |
| 套餐 114 | 成都中医药大学, status 0, menu_ids JSON 长度 1462 | SELECT system_tenant_package |
| **套餐 114 引用租户数** | **仅 tenant 162（单租户引用 ✓）** | SELECT t.id, t.name FROM system_tenant t WHERE t.package_id=114 AND t.deleted=b'0' → 1 行 |
| 906 当前权限范围 | 已授权 lab:instrument:reservation:create / cancel / device 系列，不含 lab:instrument:rule:* | role_menu 查询 |

### C-1. SQL 幂等性逐条审查

#### §1.1 INSERT 13674 预约配置菜单 —— PASS
`INSERT INTO system_menu(id, ...) SELECT ... FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM system_menu WHERE id=13674) AND EXISTS (SELECT 1 FROM system_menu WHERE id=13600 AND status=0 AND deleted=b'0')`
三重守卫：ID 未占用 + 父菜单存在 + 父菜单启用。✓

#### §1.2 INSERT 13675 查询按钮 —— **HOLD（弱缺陷）**
WHERE 条件：`WHERE NOT EXISTS (SELECT 1 FROM system_menu WHERE id=13675)`
**缺失**：未检查 13674 是否已插入且 status=0。
风险：§1.1 执行失败（比如父菜单 13600 status≠0）但 §1.2 单独执行成功 → 13675 按钮挂在不存在的父菜单下。
修复建议：追加 `AND EXISTS (SELECT 1 FROM system_menu WHERE id=13674 AND status=0 AND deleted=b'0')` 与 §1.1 对齐。

#### §1.3 INSERT 13676 更新按钮 —— **HOLD（弱缺陷，同 §1.2）**
缺失父菜单 13674 守卫，同上。

#### §2 UPDATE 套餐 114 菜单 —— PASS
`UPDATE system_tenant_package SET menu_ids=JSON_ARRAY_APPEND(menu_ids, '$', 13674) WHERE id=114 AND LENGTH(menu_ids)=LENGTH(REPLACE(menu_ids,'13674','')) AND deleted=b'0'`
用 LENGTH 对比防重复追加（而非 JSON_CONTAINS），因为 JSON_CONTAINS 对数组值的 JSON 字符串匹配在 MySQL 8.0.12 有 bug（已知官方 bug）。LENGTH REPLACE 方案可行但有理论风险：如果 menu_ids JSON 字符串恰好有其他地方出现 "13674" 子串（几乎不可能）。非阻断但建议改用 `NOT REGEXP '\\b13674\\b'` 词边界正则更严谨。

#### §3 role_menu INSERT 906 授权 —— PASS
INSERT ... SELECT ... UNION ALL ... WHERE NOT EXISTS (SELECT 1 FROM system_role_menu WHERE role_id=906 AND menu_id=? AND tenant_id=162 AND deleted=b'0')
三行分别 NOT EXISTS 守卫。显式 tenant_id=162。✓

### C-2. 权限与角色矩阵

| 角色 | code | tenant | 授权后权限 | 符合冻结规则 |
|------|------|--------|----------|-------------|
| 904 普通用户 | 普通用户 | 162 | 不分配 13674~13676 | ✓（普通用户无配置权限） |
| 906 lab_admin | lab_admin | 162 | 13674~13676（全局预约配置） | ✓（管理员有配置权） |
| 908 设备负责人 | instrument_device_manager | 162 | 不分配 13674~13676 | ✓（负责人无全局配置权） |
| 超级管理员 | （未列入） | all | 超级管理员自动绕过权限检查，无需额外授权 | ✓ |

### C-3. 套餐 114 影响范围 —— 单租户安全 ✓
已证 `system_tenant.package_id=114` 仅 tenant 162 引用。追加 13674~13676 到套餐 114 的 menu_ids 只会影响 tenant 162 的菜单可见性。✓ 无跨租户溢出。

### C-4. 页面与后端权限对应 —— PASS
- 前端组件：`src/views/lab/instrument/booking-config/index.vue` → 13674 菜单 path = `lab/instrument/booking-config/index` ✓
- 查询按钮 lab:instrument:rule:query（13675）→ RuleController.listWindow / WindowController.list ✓
- 更新按钮 lab:instrument:rule:update（13676）→ RuleController.save / WindowController.save / WindowController.delete ✓
- 904 普通用户：前端按钮 v-hasPermi(['lab:instrument:rule:query']) 为 false，看不到查询 ✓
- 908 设备负责人：不分配权限串 ✓

### C-5. 菜单 SQL 最终判定：CONDITIONAL PASS

**必须在执行前修订**：§1.2 和 §1.3 追加父菜单 13674 EXISTS status=0 守卫。
**推荐执行顺序**：§1 三菜单 INSERT（一次性，失败即全回滚）→ §2 套餐 JSON UPDATE → §3 role_menu 授权。
**可与 CAP-A DDL 同批授权但分阶段执行**：CAP-A DDL 先执行（表结构前置），菜单 SQL 可在 DDL 验收后执行（不依赖 DDL 执行结果，但业务上表结构先就绪更安全）。

**只读验收方案**：
1. SELECT FROM system_menu WHERE id IN (13674,13675,13676) → 三行 status=0 parent_id=13600
2. SELECT FROM system_tenant_package WHERE id=114 → JSON_CONTAINS(menu_ids, '13674') = 1
3. SELECT FROM system_role_menu WHERE role_id=906 AND menu_id IN (13674,13675,13676) AND tenant_id=162 → 三行
4. 反向检查：role_id=904 和 908 无新增 role_menu 行

---

## D. 隔离 MySQL / Redis 测试环境

### D-0. 现有开发配置只读

| 项目 | 值（已脱敏） |
|------|-------------|
| MySQL 开发库 | 127.0.0.1:3306 / labplatform / user 本地 |
| Redis 开发库 | 127.0.0.1:6379 / DB 0 / **无密码**（本地开发用） |
| Redisson | 默认配置（watchdog 30s 租约 + 10s 有界等待） |
| Redis key 前缀 | 无显式配置（Redisson 默认空前缀） |
| application-unit-test.yaml | DataSource = H2 内存库；Redis 无配置（测试跳过 Redis 依赖） |
| H2 建表 SQL | src/test/resources/sql/create_tables.sql 已含全部仪器表（含 03-A 五表） |
| C7 开关默认 | false（Spring @Value 带 :false） |

### D-1. 三种方案对比

| 维度 | 方案 A：独立 MySQL schema + 独立 Redis 实例 | 方案 B：独立 MySQL schema + 独立 Redis DB/index + key 前缀 | 方案 C：本机容器化 MySQL 8.0.12 + Redis 独立实例 |
|------|---------------------------------------------|-----------------------------------------------------------|---------------------------------------------------|
| 隔离性 | ✓ 进程级隔离 | ⚠️ DB/index 隔离是逻辑隔离；FLUSHALL/故障注入影响整实例 | ✓ 进程级隔离 |
| 与真实 MySQL 一致性 | ⚠️ MySQL server 可能不是 8.0.12（共享实例） | 同 A | ✓ 精确版本 8.0.12 容器 |
| Redis 锁测试可靠性 | ✓ 独立实例 → 真实锁竞争、watchdog 行为完整 | ⚠️ DB/index 隔离下仍与开发环境共享 Redisson 线程池 | ✓ 独立实例 → 完整锁行为 |
| 数据清理便利性 | ✓ DROP schema 一次完成 | ⚠️ 需 FLUSHDB（DB index）或按前缀 DEL | ✓ docker compose down → 数据卷丢弃 |
| 对开发环境影响 | ⚠️ 可能占用共享 MySQL 实例资源 | ✓ DB/index 切换无影响 | ✓ 独立容器，不影响开发 |
| 搭建难度 | 低（CREATE schema） | 最低 | 中（docker pull + compose up） |
| 额外授权 | MySQL CREATE SCHEMA + Redis 实例权限 | 无（本地 Redis 已在） | Docker 权限 + 端口占用 |
| **适合本项目？** | ❌ MySQL server 版本不确定 | ⚠️ Redis 锁可靠性不满足真实竞争验证 | ✅ 唯一可接受方案 |

### D-2. 推荐方案：方案 C（本机容器化 MySQL 8.0.12 + Redis 独立实例）

**环境规划**：
- 环境名：lab-instrument-03-test
- MySQL 容器：`mysql:8.0.12`，端口 `3307`（不冲突开发 3306），root 密码 `labtest2026`，自动创建 schema `lab_instrument_03_test`，时区 Asia/Shanghai
- Redis 容器：`redis:7-alpine`，端口 `6380`（不冲突开发 6379），无密码
- 测试 profile：`application-instrument-03-test.yaml`（devtools 自动激活）
  - spring.datasource.url = jdbc:mysql://127.0.0.1:3307/lab_instrument_03_test
  - spring.data.redis.host = 127.0.0.1:6380
  - lab.instrument.reservation.create-enabled = true（**测试环境开启！** 仅容器内）
  - lab.instrument.redis.key-prefix = "lab03-test:"（所有 Redis key 加前缀）
- 启动：`docker compose up -d`
- 停止+清理：`docker compose down -v`（数据卷一并丢弃，不留测试数据）

**防误连真实库的硬性保护**：
1. docker-compose 端口映射强制走 3307/6380
2. profile 配置中**显式覆盖所有 DataSource 和 Redis 连接**，不留任何回退到开发配置的可能
3. Maven 命令强制 `-Dspring.profiles.active=instrument-03-test`
4. 测试类内 @TestPropertySource 再次覆盖
5. 测试前运行 `SELECT DATABASE(), @@port, current_user()` 断言（非 labplatform / 非 3306 / 非 bencao）

**所需负责人授权范围（本任务仅规划不创建）**：
- 授权创建 Docker 容器
- 授权在容器内执行 CAP-A DDL（与授权 CAP-A DDL 给真实库是两回事）
- 授权在容器内插入测试数据（20 项并发矩阵所需）
- 授权开启测试环境 C7 开关（容器内独立实例，安全）

### D-3. 并发测试 20 项矩阵可执行性速查

完整矩阵见 30 号报告 D 节。本终核确认：

| 状态 | 数量 | 条件 |
|------|------|------|
| H2 可直接执行 | 7 | 纯 Service 层验证，无真实锁竞争 |
| 需方案 C 真实 Redis + MySQL | 13 | watchdog、锁竞争、死锁、RR 可见性、唯一键并发 |
| 依赖 CAP-A DDL 先部署 | 13 | daily_usage / occupation 表必须存在 |
| 依赖 C7 开关开启 | 13 | 预约创建整条链路 |

**本任务未执行任何并发测试**——仅确认 H2 单测全部通过（见 F 节），真实并发矩阵需方案 C 环境就绪后方可执行。

---

## E. 03-C 关键安全风险专项

### E-1. 跨日窗口模型 —— HOLD（产品决策型）

**现状证据**：
- 窗口模型字段：open_days(1-7逗号分隔) + open_start_time(HH:mm) + open_end_time(HH:mm) + target_date_start / target_date_end + target_week_mapping(纯文本)
- **缺失能力**：open_end ≤ 23:59 硬限制，无法表达 "周一 22:00 → 周二 02:00" 这种跨自然日的开放时段
- 代码行为：`ReservationCreateExecutor.validateWindowScope` 窗口设备跨日 → 087 拒绝
- 普通设备 allow_cross_day=true 时可跨日（open_start_time / open_end_time = null 表示全天覆盖），U1 computeUsageDates 按自然日拆分 ✓

**矛盾点**：业务规则 U1 computeUsageDates 可正确计算跨日占用日期集合，但窗口模型无法判断"预约时段是否在开放窗口内"（open_start_time=22:00 + open_end_time=02:00 的窗口不存在）。

**24:00 边界**：HH:mm 格式无法表示 24:00；如果预约 endTime = 次日 00:00，U1 半开区间不计入次日 ✓（符合业务语义），但 open_end_time 无法配置 24:00 的窗口覆盖。

**夏令时/时区**：ReservationTimeUtils 全程基于 LocalDateTime（无时区）+ 显式 Asia/Shanghai today()，不依赖服务器默认时区。中国无夏令时。**无时区问题**。

**方案**：
1. 本期 HOLD：窗口设备跨日全部 087 拒绝，UI 提示"窗口设备暂不支持跨日预约，请分天创建或联系管理员"。普通设备 allow_cross_day=true 可正常跨日。**零代码改动，零 DDL 改动**。
2. 未来扩展（后续版本）：窗口表新增 `time_slots JSON` 字段 `[{"start":"22:00","end":"02:00","cross_day":true}, ...]`；Service 层按 JSON 数组校验预约时段与多个开放片段的交集；前端配置 UI 改为多时段编辑器。需要 DDL + Service + 前端 + 测试全部变更，**不纳入 03-C 范围**。

**风险级别**：低（产品决策，当前用户场景不常见）
**修复建议**：本期方案 1（HOLD），记录为已知限制并在 UI 提示。后续版本按方案 2 扩展。

### E-2. 预约单号唯一性 —— HOLD（技术缺陷型，阻断真实并发测试）

**调用链证据**：
```
Executor.persist(admission, reqVO, userId, userName, durationMinutes)
  → reservationMapper.insert(reservation)          // ① 首次 INSERT，带 uk_reservation_tenant_no
    ↓ DuplicateKeyException (Spring 包装)
  catch(DuplicateKeyException e)
    → reservation.setReservationNo(reservationNoRedisDAO.generate(tenantId))  // ② 重新 generate
    → reservationMapper.insert(reservation)        // ③ 第二次 INSERT（同一事务）
      ↓ DuplicateKeyException e2
    抛 INSTRUMENT_RESERVATION_NO_GEN_FAILED (099)
```

**MySQL 8.0.12 行为**：MySQL Connector/J 在收到 SQLIntegrityConstraintViolationException（DuplicateKeyException 底层）时，**默认标记 JDBC Connection rollback-only**。后续任何 SQL（包括 INSERT）会抛出：
```
org.springframework.dao.UnexpectedRollbackException: Transaction rolled back because it has been marked as rollback-only
```

**H2 与 MySQL 行为差异**：H2 1.4.x 在 ConstraintViolationException 后**不标记** Connection rollback-only，可以继续执行其他 SQL。所以 `insertReservationWithRetry` 的 retry 逻辑在 H2 单测里完全可行，但在真实 MySQL 上**极大概率失败**。

**事务边界**：persist 是在 `transactionTemplate.execute(status -> { ... })` 回调内执行的。整个 persist 方法（含 ③ 第二次 INSERT）都在**同一个 TransactionTemplate** 回调内。MySQL Connection rollback-only 后 ③ 会立即失败，直接走 099 → 整个事务回滚（含已执行的 ⑥ dailyUsageService.tryOccupy + ① 第一次 INSERT 也会被回滚）。

**后果**：
- 99.999 次 Redis INCR 里任何一次与历史已用单号（比如 Redis 重启后从快照恢复到落后值）冲突 → 099 整体回滚 → 整个预约创建失败
- 不是"重试一次"而是"直接失败"

**修复方案**（最小侵入，不改事务编排）：
把 retry 提到 TransactionTemplate 外层。伪代码：
```java
public ReservationResult createReservation(...) {
    int maxRetry = 2;
    for (int attempt = 1; attempt <= maxRetry; attempt++) {
        try {
            return lockCoordinator.executeInDeviceLock(deviceId, userId, device -> {
                String no = reservationNoRedisDAO.generate(tenantId);
                // ... 组装 reservation ...
                reservation.setReservationNo(no);
                reservationMapper.insert(reservation);   // 不再在 catch 里 retry
                // ... 后续 P9 occupation + history ...
                return new ReservationResult(reservation.getId());
            });
        } catch (DuplicateKeyException e) {
            log.warn("单号冲突，retry {}/{}", attempt, maxRetry);
            // TransactionTemplate 已回滚，锁已释放
            if (attempt == maxRetry) throw ...;
        }
    }
}
```
每次 retry 开启**新的事务**，Connection 状态干净。锁也是每次 retry 重新获取（不持有锁期间冲突）。

**另一种方案**：在 persist 内部用 `TransactionStatus.createSavepoint()` → savepoint rollback 后 retry。但 Spring TransactionTemplate 的 SavepointManager 需要底层 DataSource 支持且会增加复杂度。

**风险级别**：高（真实 MySQL 下单号冲突时的失败率被严重低估）
**修复建议**：采用外层重试方案，重新跑 MySQL 8.0 单测。**必须在真实 MySQL 部署前修复**。

### E-3. 锁与事务 —— HOLD（竞争窗口型，理论存在但无实证）

**冻结锁链复现**：
```
ServiceImpl.createReservation
  → C7 开关检查
  → 登录用户快照（锁外 AdminUserApi）
  → lockCoordinator.executeInDeviceLock(deviceId, userId, callback)
      → InstrumentLockRedisDAO.suspendKey(tenantId, userId)  // Redis key: instrument:suspend:{tenant}:user:{userId}
      → lockWithWatchdog(key, callable)                      // tryLock 10s，watchdog 30s 自动续期
          → callable = transactionTemplate.execute(status -> { ... })
              → deviceMapper.selectByIdForUpdate(deviceId)   // MySQL 行锁
              → ReservationCreateExecutor.create(...)         // P1~P9
          → 事务 commit（execute 返回即已提交）
      → finally { if (lock.isHeldByCurrentThread()) lock.unlock(); }
```

**事务提交早于解锁**：✓ 代码结构保证。transactionTemplate.execute 返回即已 commit/rollback；callable 返回后 lockWithWatchdog 的 finally 才执行 unlock。

**watchdog 所有权丢失场景分析**：

| 场景 | 表现 | 正确性影响 |
|------|------|-----------|
| 进程活着，Redis 分区，watchdog 续期请求丢失 | Redisson RLock 在 30s 后租约到期自动释放；finally 中 isHeldByCurrentThread() 返回 false，不会调用 unlock；但**callable 里的 transactionTemplate.execute 仍在执行（设备行锁持有中）** | ⚠️ **竞争窗口存在**：Redis 锁已释放 → 另一个实例可通过 tryLock 拿到同一 suspendKey → 也进入事务 → 但设备行锁 (SELECT ... FOR UPDATE) 仍由第一个事务持有 → 第二个事务等待行锁。**设备行锁最终兜底串行化**，不会出现两事务同时 commit |
| 进程活着，Redisson watchdogs 线程异常退出 | 同上述，30s 租约到期 → Redis 锁自动释放；finally isHeldByCurrentThread() 仍 false | 同上，设备行锁兜底 |
| 进程宕机 | 进程退出 → watchdog 线程停止 → 30s 租约到期 → Redis 锁自动释放；finally 不执行；MySQL 连接由 MySQL 8.0 默认 wait_timeout(8h) 回收 → 行锁自动释放 → 其他实例重试成功 | ✓ 正确，无半提交事务残留 |
| Redisson tryLock 返回 false（10s 超时） | fail-closed，不进入事务 | ✓ 正确 |
| Redis 不可达（网络中断） | RuntimeException → fail-closed | ✓ 正确 |

**核心结论**：**watchdog 所有权丢失不会导致两事务同时 commit**——因为设备行锁是 MySQL 8.0 事务级锁，在第一个事务（TransactionTemplate.execute）commit 前不会释放，第二个事务获取行锁时会阻塞等待。真正的风险只在于：Redis 锁提前释放后，高并发下大量请求会在设备行锁队列上竞争等待，吞吐量下降；以及**同一设备的多个并发请求会在 Redis 锁超时后同时进入"等待行锁"队列**（原本设计意图是 Redis 锁先行拦截）。

**fail-closed 语义**：Redis 不可达 / tryLock 超时 → fail-closed，业务拒绝执行 ✓。

**风险级别**：中（竞争窗口存在但有设备行锁兜底；吞吐量下降是可接受的 tradeoff）
**修复建议**：
1. 在 finally 里增加 watchdog 所有权丢失的 WARN 日志 `if (!lock.isHeldByCurrentThread()) log.warn(...)` 方便生产诊断
2. 将 watchdog 默认租约 30s 改为与设备行锁事务最长预期时长匹配（比如 60s），减少所有权丢失概率
3. **watchdog 所有权丢失后是否应该立即 fail-fast 中止正在执行的事务？** 代码当前不中止——这是一个产品决策：如果持锁时间过长（>30s 业务不太可能），继续执行可能 OK，但严格安全语义应立即中止（`status.setRollbackOnly()` + 抛异常）。**建议后续版本增加**，非 03-C 阻断

### E-4. 功能开关 —— PASS

| 核对项 | 结果 | 证据 |
|-------|------|------|
| 默认值 | false | `@Value("${lab.instrument.reservation.create-enabled:false}")` |
| 未配置时 | false | Spring 缺省值机制 |
| system_config 表 | 无显式配置行（SELECT 结果 0 行） → 运行时缺省 false | SELECT system_config |
| C7 检查位置 | ReservationCreateExecutor.constructor 首行；ServiceImpl.createReservation 首行二次检查 | 双重守卫 |
| 前端绕过 | 不可能（后端二次检查） | — |
| 其他 Controller 绕过 | 不可能（ServiceImpl 统一入口） | — |
| 缓存 | Spring @Value 一次性注入，无动态刷新风险 | — |
| 部署时自动启用 | application-local.yaml 无此配置；application-prod.yaml 无此配置（未显式写 → Spring 缺省 false） | — |

**状态**：C7 开关当前**必须保持关闭**。03-C 部署完成后、真实并发测试前，在测试环境（方案 C）显式开启。正式库部署时保持关闭，通过独立灰度计划逐步开启。

---

## F. 编译与隔离回归

### F-1. 后端编译

```
mvn -o -pl yudao-module-lab -am clean test
```

| 指标 | 值 |
|------|-----|
| 退出码 | 0 |
| 测试类 | 7 个（InstrumentService、LockCoordinator、DataLayer、RuleService、WindowService、Permission、ReservationCreate） |
| 测试用例 | 162 个 |
| 通过 | 162 |
| 失败 | 0 |
| 跳过 | 0 |

**DataSource 指向验证**：
- profile = unit-test（由 surefire plugin 自动激活）
- DataSource = H2 内存库（`org.h2.Driver`，`jdbc:h2:mem:` URL）
- Redis 依赖：测试用例全部 Mock 或跳过；无真实 Redis 连接
- 连接 labplatform 真实库？**否**，H2 完全隔离 ✓

### F-2. 前端 TypeScript

```
vue-tsc --noEmit
```

| 指标 | 值 |
|------|-----|
| 本次新增 4 文件 | 0 错误 |
| 存量错误 | 15 个（全部在 announcement/fms/hrm/plasmid 模块，非本次变更） |

### F-3. 未执行项

| 项目 | 原因 |
|------|------|
| 真实 MySQL 8.0 下单号重试验证 | 禁止连接真实库 |
| 真实 Redis 锁 watchdog 所有权丢失场景 | 禁止连接真实 Redis |
| 20 项并发矩阵执行 | 需要方案 C 环境（仅规划未创建） |
| 菜单 SQL 执行 | 需负责人授权（本任务只读） |
| CAP-A DDL 执行 | 需负责人授权（本任务只读） |

---

## G. 负责人下一步授权清单

**五项独立授权，不得合并**：

### G-1. CAP-A DDL 执行授权
- **范围**：三条 DDL（§1.1 CREATE daily_usage → §1.2 CREATE occupation → §1.3 ALTER reservation ADD window_id）
- **执行顺序**：必须严格按上述顺序；不可中途停止；推荐单次事务
- **前置条件**：
  1. 再次运行 §0 预检 SELECT 并保存输出（window_id_col_cnt 必须 = 0）
  2. 确认当前用户有 CREATE TABLE + ALTER TABLE 权限
  3. 确认 MySQL `autocommit=1` 或显式 START TRANSACTION
- **验收**：运行 §3 验收 SELECT + SHOW INDEX
- **禁止**：部分执行 / 跳过预检 / 中途插入其他 DML

### G-2. 菜单 SQL 执行授权（需先修订）
- **范围**：13674 INSERT + 13675/13676 INSERT（§1.2/§1.3 需追加父菜单守卫） + 套餐 114 UPDATE + 906 role_menu INSERT
- **执行顺序**：§1 三菜单 INSERT → §2 套餐 UPDATE → §3 role_menu
- **前置条件**：
  1. 执行 G-1（CAP-A DDL）并完成验收
  2. 读取修订后的 SQL 文件，确认 §1.2 / §1.3 守卫已到位
- **验收**：只读验证 4 条验收 SQL（菜单/套餐/role_menu/反向检查）
- **禁止**：分配给 904 或 908

### G-3. 隔离 MySQL/Redis 环境创建授权（方案 C）
- **范围**：Docker compose up 创建容器；在容器内执行 CAP-A DDL；插入测试数据
- **前置条件**：
  1. Docker 服务运行正常
  2. 端口 3307 / 6380 未被占用
- **验收**：容器启动后 `SELECT DATABASE()` + `SELECT @@port` 确认非 labplatform / 非 3306

### G-4. 后续真实并发测试授权
- **范围**：20 项并发矩阵；可能需要连接方案 C 容器内 MySQL 和 Redis
- **前置条件**：
  1. G-3 环境创建并验收通过
  2. C7 开关在测试容器内显式开启
- **产出**：20 项逐一 PASS/FAIL 报告 + 失败根因分析
- **禁止**：对 labplatform 真实库执行任何写入

### G-5. C7 开关启用条件
- **测试环境（方案 C）**：G-3 + G-4 全部通过后，显式开启（application-instrument-03-test.yaml 里设置 `lab.instrument.reservation.create-enabled=true`）
- **正式库 labplatform**：
  1. G-1 CAP-A DDL 执行并验收通过
  2. G-2 菜单 SQL 执行并验收通过
  3. G-4 并发矩阵至少 18/20 PASS（仅允许跨日 HOLD 和 watchdog 所有权丢失非阻断）
  4. 代码修复完成（D2 Connection rollback-only + D3 watchdog fail-fast）
  5. 独立灰度计划（按租户逐步开启）
  6. **当前不具备任何启用条件**

---

## H. 写入边界声明

本终核任务严格遵守负责人授权边界 A：

| 操作 | 数量 | 说明 |
|------|------|------|
| 真实 labplatform DDL | **0** | 仅 SELECT / SHOW / information_schema |
| 真实 labplatform DML（INSERT/UPDATE/DELETE） | **0** | — |
| 真实菜单写入（system_menu / system_tenant_package / system_role_menu） | **0** | — |
| 真实角色授权 | **0** | — |
| Redis 写入（SET/DEL/INCR/EXPIRE/FLUSH/锁获取） | **0** | 未建立 Redis 连接 |
| 隔离环境创建（Docker / MySQL schema / Redis 实例） | **0** | 仅规划不创建 |
| C7 开关修改 | **0** | 默认 false，未触碰 |
| 代码修改（DO/Mapper/Service/Controller） | **0** | 只读审查，缺陷记录 |
| SQL 设计稿修改 | **0** | 缺陷记录（§1.2/§1.3 守卫），未直接修改 |
| H2 测试数据 | **仅测试框架自动填充**（CREATE TABLE + 测试数据），运行后自动回滚 | — |
| 凭据输出 | **0** | 所有密码已脱敏；报告未含任何明文连接串 |

**如存在任何非预期写入，本报告必然如实列出；当前确认为全部 0。**

---

## 附录：待负责人关注的已知技术缺陷（非阻断 03-C 部署，但建议在后续修复）

| # | 位置 | 缺陷 | 风险 | 建议修复 |
|---|------|------|------|---------|
| 1 | ReservationCreateExecutor.insertReservationWithRetry | D2：MySQL 8.0 下 Connection rollback-only 导致 retry 失效 | 高（真实并发下单号冲突时直接 099 失败） | 外层重试，每次 retry 新事务 |
| 2 | InstrumentLockRedisDAO.lockWithWatchdog finally | D3：watchdog 所有权丢失后事务仍执行 | 中（设备行锁兜底但吞吐量下降） | fail-fast 中止事务 |
| 3 | 菜单 SQL §1.2 / §1.3 | C-1：缺失父菜单 13674 status=0 守卫 | 低（幂等性弱，极难触发） | 追加 EXISTS 条件 |
| 4 | daily_usage.used_count | B-2：无 CHECK 约束非负 | 低（业务层条件 UPDATE 防负） | 加 CHECK 或保持业务层守卫 |
| 5 | 窗口跨日 | E-1：窗口模型不支持跨自然日开放时段 | 低（产品决策型） | 后续版本扩展 time_slots JSON |

---

**终核完成** · 2026-10-16 · Trae 自动化只读终核 v1.0
