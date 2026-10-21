# INSTRUMENT-06 部署前预检与阻断项报告

> **文档编号**：63-INSTRUMENT-06
> **阶段**：部署就绪检查
> **创建日期**：2026-10-20
> **关联文件**：
> - [58-INSTRUMENT-06数据库DDL设计稿.sql](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/58-INSTRUMENT-06%E6%95%B0%E6%8D%AE%E5%BA%93DDL%E8%AE%BE%E8%AE%A1%E7%A8%BF.sql)
> - [59-INSTRUMENT-06菜单与角色授权设计稿.sql](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/59-INSTRUMENT-06%E8%8F%9C%E5%8D%95%E4%B8%8E%E8%A7%92%E8%89%B2%E6%8E%88%E6%9D%83%E8%AE%BE%E8%AE%A1%E7%A8%BF.sql)
> - [60-INSTRUMENT-06后端开发交付报告.md](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/60-INSTRUMENT-06%E5%90%8E%E7%AB%AF%E5%BC%80%E5%8F%91%E4%BA%A4%E4%BB%98%E6%8A%A5%E5%91%8A.md)
> - [61-INSTRUMENT-06前端开发交付报告.md](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/61-INSTRUMENT-06%E5%89%8D%E7%AB%AF%E5%BC%80%E5%8F%91%E4%BA%A4%E4%BB%98%E6%8A%A5%E5%91%8A.md)
> **当前状态**：**DEPLOYMENT HOLD** — 代码 100% 完成，58 号 DDL 已与 DO 完全对齐、59 号菜单 ID（13684~13688）/角色 909 已核验空闲；但 DDL / 菜单 SQL / 真实维修负责人角色分配均未在生产/准生产环境部署，运行时会立即报 SQL 错误。另含 FUNCTIONAL HOLD：预约状态机无 STARTED，"禁止实际开始使用"无入口可拦截。

---

## 1. 总体状态

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DEPLOYMENT HOLD                               │
│                      ⛔ 部署阻断中 — 当前禁止上线                      │
│                                                                     │
│                    代码完成度: 100% ✓                                 │
│                    DDL 就绪度: 100% ✓ (58号已与DO完全对齐,未执行)      │
│                    菜单SQL:   100% ✓ (59号菜单ID/角色ID已核验空闲)     │
│                    数据预载:   0%  ✗ (无真实维修负责人账号)            │
│                    Redis缓存:  N/A (部署后需刷新)                    │
└─────────────────────────────────────────────────────────────────────┘
```

部署阻断的唯一原因：**生产环境数据库尚未执行 58 号 DDL + 59 号菜单 SQL**。代码合入后如果启动后端，所有涉及 `instrument_fault_report` / `instrument_repair_order` 等 5 张表的接口会立即抛 `Table 'xxx.instrument_fault_report' doesn't exist`。

### 1.1 预检已确认项

| 项 | 核验结果 | 说明 |
|----|----------|------|
| 58 号 DDL 与 DO 对齐 | ✅ 已确认 | 5 张表字段、类型、索引与 DO 实体完全一致（之前字段不一致已修复） |
| 59 号菜单 ID 13684~13688 | ✅ 空闲 | 目标库 `sys_menu` 中无冲突 |
| 59 号角色 ID 909 | ✅ 空闲 | 目标库 `sys_role` 中无冲突 |
| 系统表名 | ✅ 正确 | `sys_menu` / `sys_role` / `sys_role_menu` 表名与实际一致 |

---

## 2. 部署前置条件清单（按执行顺序）

### 2.1 前置条件 P1：58 号 DDL 授权执行 + 真实执行

| 项 | 内容 |
|----|------|
| SQL 文件 | [58-INSTRUMENT-06数据库DDL设计稿.sql](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/58-INSTRUMENT-06%E6%95%B0%E6%8D%AE%E5%BA%93DDL%E8%AE%BE%E8%AE%A1%E7%A8%BF.sql) |
| 执行对象 | 生产 / 准生产 MySQL 实例 |
| 执行账号 | `yudao_admin`（有 CREATE TABLE 权限） |
| 预检状态 | ✅ **DDL 已与 DO 完全对齐**（5 张表字段/类型/索引与实体一致，之前字段不一致问题已修复） |
| 操作步骤 | 1. 确认目标库已存在 2. source / 手动粘贴执行 3. 逐表验证行数 = 0、结构与设计稿一致 |
| 验证命令 | `SHOW CREATE TABLE instrument_fault_report;`（对 5 张表逐一执行） |
| 风险 | 低：全部是 `CREATE TABLE IF NOT EXISTS`，不会覆盖已有表 |
| 优先级 | **最高（阻断项）** |

### 2.2 前置条件 P2：59 号菜单/角色 SQL 授权执行 + 真实执行

| 项 | 内容 |
|----|------|
| SQL 文件 | [59-INSTRUMENT-06菜单与角色授权设计稿.sql](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/59-INSTRUMENT-06%E8%8F%9C%E5%8D%95%E4%B8%8E%E8%A7%92%E8%89%B2%E6%8E%88%E6%9D%83%E8%AE%BE%E8%AE%A1%E7%A8%BF.sql) |
| 执行对象 | 生产 / 准生产 MySQL 实例（同 P1） |
| 执行账号 | `yudao_admin`（有 INSERT sys_menu / sys_role_menu 权限） |
| 预检状态 | ✅ **菜单 ID 13684~13688 空闲、角色 909 空闲、系统表名正确**（已核验目标库无冲突） |
| 操作步骤 | 1. 执行菜单 INSERT 2. 记录新生成的 menu_id 3. 执行角色菜单关联 INSERT 4. 确认 ROOM_ADMIN / LAB_ADMIN / ROOM_REPAIR 三个业务角色已关联新菜单 |
| 验证命令 | `SELECT menu_id, name, perms FROM sys_menu WHERE name LIKE '%维修%' OR name LIKE '%故障%';` |
| 风险 | 中：需要注意 parent_id 是否正确挂载到"仪器管理 / 日常管理"下 |
| 优先级 | **最高（阻断项）** |

### 2.3 前置条件 P3：真实维修负责人账号分配 ROOM_REPAIR 角色

| 项 | 内容 |
|----|------|
| 操作对象 | 业务部门指定的维修负责人真实账号（如 zhang_san、li_si） |
| 操作方式 | ① 后台用户管理 → 角色分配 → 勾选 ROOM_REPAIR 业务角色；或 ② SQL `INSERT INTO sys_user_role(user_id, role_id) VALUES (...);` |
| 验证命令 | `SELECT u.username, r.role_name FROM sys_user_role ur JOIN sys_user u ON ur.user_id = u.id JOIN sys_role r ON ur.role_id = r.id WHERE r.role_name = 'ROOM_REPAIR';` |
| 风险 | 低 |
| 优先级 | 高（不阻断启动，但影响功能可用性） |

### 2.4 前置条件 P4：真实维修负责人账号分配 ROOM_REPAIR ACTIVE 业务关系

| 项 | 内容 |
|----|------|
| 操作对象 | `instrument_scope_support` 业务关系表 |
| 操作方式 | 后台权限管理 → 业务关系 → 为维修负责人账号新增 ROOM_REPAIR / ACTIVE 记录 |
| 验证命令 | `SELECT * FROM instrument_scope_support WHERE user_id = ? AND scope = 'ROOM_REPAIR' AND status = 1;` |
| 风险 | 低 |
| 优先级 | 高（后端 `canRepairDevice()` 校验依赖） |

### 2.5 前置条件 P5：Redis 缓存失效

| 项 | 内容 |
|----|------|
| 缓存类型 | 角色缓存、菜单缓存、scope_support 缓存 |
| 操作方式 | 后端管理后台 → 系统监控 → 缓存监控 → 按 pattern `*role*` / `*menu*` / `*scope*` 批量删除；或重启后端服务 |
| 风险 | 低 |
| 优先级 | 中（不失效会导致新角色/菜单不生效） |

---

## 3. 数据库连接信息（只读参考，用于部署后验收）

> 以下信息为开发环境快照，生产环境连接信息由运维维护，本报告仅作参考。

| 项 | 值（开发环境） |
|----|----------------|
| Host | `localhost` |
| Port | `3306` |
| Database | `yudao_lab` |
| Read-only 账号 | `yudao_reader` / 密码见运维文档 |
| Charset | `utf8mb4` |
| Collation | `utf8mb4_unicode_ci` |

**注意**：部署执行（P1/P2）必须由运维使用 **读写账号** 操作。应用连接池使用的也是读写账号，但 DDL 执行需要显式授权，不能通过应用自动执行。

---

## 4. 执行顺序与风险矩阵

```
执行顺序:
  P1 DDL ──▶ P2 菜单SQL ──▶ P3 角色分配 ──▶ P4 业务关系 ──▶ P5 Redis失效

并行可能:
  P3 / P4 可在 P1 完成后、P2 并行执行（因为不依赖 menu_id）
  P5 必须在 P1-P4 全部完成后执行
```

| 步骤 | 失败后果 | 回滚方式 |
|------|----------|----------|
| P1 DDL 执行失败 | 应用启动后 SQL 异常、全部维修接口不可用 | 检查 SQL 错误信息；DDL 为 `CREATE TABLE IF NOT EXISTS`，不会部分成功；可重复执行 |
| P2 菜单 SQL 执行失败 | 前端看不到维修菜单入口 | 删除已插入的 menu_id，修复 SQL 后重新执行 |
| P3 角色分配遗漏 | 维修负责人看不到工单 | 补分配即可，热生效 |
| P4 业务关系遗漏 | 维修负责人点击【开始维修】报 403 | 补业务关系即可，热生效 |
| P5 Redis 未失效 | 新角色/菜单不生效 | 手动删缓存或重启服务 |

---

## 5. 验收 SQL 清单

部署完成后，运维与开发共同执行以下 SQL 逐项验证：

### 5.1 数据库表验证

```sql
-- 5 张维修域表必须存在
SHOW TABLES LIKE 'instrument_fault_report';
SHOW TABLES LIKE 'instrument_repair_order';
SHOW TABLES LIKE 'instrument_repair_history';
SHOW TABLES LIKE 'instrument_device_status_history';
SHOW TABLES LIKE 'instrument_reservation_impact';

-- 每张表 DDL 与 58 号设计稿一致
SHOW CREATE TABLE instrument_fault_report;
```

### 5.2 菜单验证

```sql
-- 新菜单已插入 sys_menu
SELECT menu_id, name, parent_id, perms, path, component
FROM sys_menu
WHERE name LIKE '%维修%' OR name LIKE '%故障%' OR name LIKE '%预约影响%';

-- 业务角色已关联新菜单
SELECT r.role_name, m.name AS menu_name
FROM sys_role_menu rm
JOIN sys_role r ON rm.role_id = r.id
JOIN sys_menu m ON rm.menu_id = m.menu_id
WHERE r.role_name IN ('ROOM_ADMIN', 'LAB_ADMIN', 'ROOM_REPAIR')
  AND (m.name LIKE '%维修%' OR m.name LIKE '%故障%');
```

### 5.3 角色与业务关系验证

```sql
-- 有维修负责人账号已分配 ROOM_REPAIR 角色
SELECT u.username, r.role_name
FROM sys_user_role ur
JOIN sys_user u ON ur.user_id = u.id
JOIN sys_role r ON ur.role_id = r.id
WHERE r.role_name = 'ROOM_REPAIR';

-- 有维修负责人账号已分配 ROOM_REPAIR / ACTIVE 业务关系
SELECT u.username, iss.scope, iss.status
FROM instrument_scope_support iss
JOIN sys_user u ON iss.user_id = u.id
WHERE iss.scope = 'ROOM_REPAIR' AND iss.status = 1;
```

### 5.4 空数据安全验证

```sql
-- 所有新表初始行数 = 0
SELECT 'fault_report' AS tbl, COUNT(*) AS cnt FROM instrument_fault_report
UNION ALL
SELECT 'repair_order', COUNT(*) FROM instrument_repair_order
UNION ALL
SELECT 'repair_history', COUNT(*) FROM instrument_repair_history
UNION ALL
SELECT 'device_status_history', COUNT(*) FROM instrument_device_status_history
UNION ALL
SELECT 'reservation_impact', COUNT(*) FROM instrument_reservation_impact;
-- 期望：全部 cnt = 0
```

### 5.5 应用接口冒烟测试

```bash
# 1. 登录普通用户，提交故障（期望 200 + FRxxxxxx 单号）
curl -X POST /fault-report/submit \
  -H "Authorization: Bearer <token>" \
  -d '{"deviceId": 1, "title": "测试故障", "description": "预检冒烟", "severity": "MINOR"}'

# 2. 登录管理员，确认工单（期望 200 + ROxxxxxx 单号）
curl -X POST /repair-order/create \
  -H "Authorization: Bearer <admin_token>" \
  -d '{"faultReportId": <上一步id>, "severity": "MINOR"}'

# 3. 登录维修负责人，开始维修（期望 200 + IN_PROGRESS）
curl -X POST /repair-order/start \
  -H "Authorization: Bearer <repair_token>" \
  -d '{"orderId": <上一步id>}'

# 4. 登录管理员，验收通过（期望 200 + RESTORED + 设备切 NORMAL）
curl -X POST /repair-order/restore-approve \
  -H "Authorization: Bearer <admin_token>" \
  -d '{"orderId": <上一步id>, "approve": true, "comment": "冒烟通过"}'
```

---

## 6. 阻断项摘要

> 预检已确认：58 号 DDL 与 DO 完全对齐、59 号菜单 ID 13684~13688 / 角色 909 空闲、系统表名正确。以下为**部署执行层面**的阻断项。

| 阻断项 | 类型 | 影响范围 | 解除条件 | 优先级 |
|--------|------|----------|----------|--------|
| **DDL 未执行（58号SQL）** | 启动阻断 | 所有维修相关 SQL 立即报错 | DBA / DBA 授权人执行 | **P0 - 最高** |
| **菜单 SQL 未执行（59号SQL）** | 功能阻断 | 前端无法看到维修相关页面入口，动态路由不生效 | 执行 59 号 SQL | **P0 - 最高** |
| **真实维修负责人账号未分配角色 909** | 功能阻断 | 维修负责人无法操作工单（无 ROOM_REPAIR 角色） | 按 P3 执行 | **P1** |
| **维修负责人账号未分配 ROOM_REPAIR / ACTIVE 业务关系** | 功能阻断 | `canRepairDevice()` 返回 false | 按 P4 执行 | P1 |
| **Redis 缓存未失效** | 可用性风险 | 新角色/菜单延迟生效 | 按 P5 执行 | P2 |

---

## 6.1 FUNCTIONAL HOLD：预约状态机 STARTED 状态缺口

| 项 | 说明 |
|----|------|
| 问题 | INSTRUMENT-03 已冻结预约状态机（PENDING / FINISHED / CANCELED / VOIDED），**无 STARTED 状态**。原设计"维修中禁止实际开始使用预约"无入口可拦截 |
| 现状 | 设备 FAULT 状态仅能拦截**新预约创建**（P1 校验）；已存在的 PENDING 预约到时间后仍可正常使用 |
| 已提供支撑 | 服务层已提供 `isReservationCurrentlyImpacted(reservationId)` 校验方法，供未来新增 STARTED 端点调用时拦截受影响预约 |
| 处置 | 维持 INSTRUMENT-03 冻结状态机，不扩状态集；若业务要求"维修中禁止使用"，需在 INSTRUMENT-03 框架下新增 STARTED 状态并接入该校验 |
| 性质 | **设计约束，非缺陷**，不阻断本轮部署 |

---

## 7. 部署 Checklist（复制到部署执行时逐项勾选）

- [ ] P1：58 号 DDL 在目标库执行完毕
- [ ] P1 验证：`SHOW TABLES LIKE 'instrument_fault_report'` → 有结果
- [ ] P1 验证：`SHOW CREATE TABLE` × 5 张表，结构与设计稿一致
- [ ] P2：59 号菜单 SQL 在目标库执行完毕
- [ ] P2 验证：`SELECT menu_id, name FROM sys_menu WHERE name LIKE '%维修%'` → 有结果
- [ ] P2 验证：`sys_role_menu` 中 ROOM_ADMIN / LAB_ADMIN / ROOM_REPAIR 均已关联
- [ ] P3：维修负责人真实账号已分配 ROOM_REPAIR 角色
- [ ] P4：维修负责人真实账号已分配 ROOM_REPAIR / ACTIVE 业务关系
- [ ] P5：角色 / 菜单 / scope 缓存已全部清除
- [ ] 应用重启或热加载完成
- [ ] 冒烟测试：故障提交 200 ✓
- [ ] 冒烟测试：工单创建 200 ✓
- [ ] 冒烟测试：开始维修 200 ✓
- [ ] 冒烟测试：验收通过 200 ✓ + 设备状态正确
- [ ] 前端页面：普通用户看到【上报故障】入口
- [ ] 前端页面：管理员看到【维修管理】完整菜单
- [ ] 前端页面：维修负责人看到【我的维修任务】

---

## 8. 变更记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0 | 2026-10-20 | 初始版本，DEPLOYMENT HOLD 状态 | 部署组 |
| v1.1 | 2026-10-20 | R1 修复：确认 58 号 DDL 与 DO 对齐、59 号菜单 ID/角色 ID 空闲；明确部署阻断项为 DDL 未执行 + 菜单 SQL 未执行 + 角色 909 未分配真实用户；新增 FUNCTIONAL HOLD（STARTED 状态缺口）说明 | 部署组 |

## R4 最新裁决补充（2026-10-20）

本报告中“缺少预约签到/开始使用入口导致 U6 FUNCTIONAL HOLD”的结论为历史结论，自 R4 正式裁决起不再适用。第一期明确不开发实际使用过程；U6 改按故障设备状态、受影响预约留存、影响状态恢复及管理员人工处理闭环验收。该补充不代表数据库、菜单、套餐或生产运行时已经部署：SQL 58/59 未执行，目标环境状态仍待另行授权核验，DEPLOYMENT HOLD 继续有效。
