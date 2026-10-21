# 66-INSTRUMENT-06-R1 SQL 执行前最终核验报告

> 编制日期：2026-10-20
> 结论：58/59 号 SQL 达到可执行审批条件，等待负责人授权

---

## 一、58 号 DDL 核验（逐项）

### 1.1 表名与现有规范一致

| 新表名 | 命名规范 | 核验 |
|---|---|---|
| lab_instrument_fault_report | lab_instrument_* 前缀 | ✅ |
| lab_instrument_repair_order | 同上 | ✅ |
| lab_instrument_repair_history | 同上 | ✅ |
| lab_instrument_device_status_history | 同上 | ✅ |
| lab_instrument_reservation_impact | 同上 | ✅ |

现有 16 张 lab_instrument_* 表确认存在。

### 1.2 DO 字段与 DDL 字段逐一对应

**InstrumentRepairOrderDO ↔ lab_instrument_repair_order**（19 业务字段 + 6 TenantBaseDO 字段）：

| DO 字段 | DDL 列 | 核验 |
|---|---|---|
| orderNo | order_no | ✅ |
| deviceId | device_id | ✅ |
| roomId | room_id | ✅ |
| sourceFaultId | source_fault_id | ✅ |
| currentStatus | current_status | ✅ |
| assigneeUserId | assignee_user_id | ✅ |
| assigneeUserName | assignee_user_name | ✅ |
| assigneeAssignUserId | assignee_assign_user_id | ✅ |
| assigneeAssignUserName | assignee_assign_user_name | ✅ |
| assigneeAssignTime | assignee_assign_time | ✅ |
| startTime | start_time | ✅ |
| repairEndTime | repair_end_time | ✅ |
| restoreConfirmUserId | restore_confirm_user_id | ✅ |
| restoreConfirmUserName | restore_confirm_user_name | ✅ |
| restoreConfirmTime | restore_confirm_time | ✅ |
| restoreOpinion | restore_opinion | ✅ |
| closeTime | close_time | ✅ |
| lastAssigneeUserId | last_assignee_user_id | ✅ |

其余 4 表（fault_report / repair_history / device_status_history / reservation_impact）同样逐一对应，无遗漏。

### 1.3 索引设计

| 表 | 唯一索引 | 普通索引 |
|---|---|---|
| repair_order | uk_repair_tenant_no(tenant_id, order_no) | idx_device_id, idx_assignee_user_id, idx_current_status, idx_source_fault_id |
| repair_history | uk_repair_history_no(tenant_id, repair_order_id, history_no) | idx_repair_order_id |
| fault_report | — | idx_device_id, idx_reporter_user_id, idx_confirm_status |
| device_status_history | — | idx_device_id, idx_related_repair_order_id |
| reservation_impact | — | idx_reservation_id, idx_device_id, idx_handle_status |

### 1.4 MySQL 8.0.12 兼容性

- 字符集 utf8mb4 / utf8mb4_unicode_ci ✅
- InnoDB / ROW_FORMAT=Dynamic ✅
- 无物理外键（lab 既有规范）✅
- bit(1) 逻辑删除 ✅
- datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ✅
- 无 MySQL 保留字冲突 ✅

### 1.5 事务与回退

- 全部 CREATE TABLE IF NOT EXISTS，可重复执行 ✅
- 回退脚本按依赖逆序 DROP ✅
- 不修改/删除既有表 ✅

---

## 二、59 号菜单/角色 SQL 核验

### 2.1 菜单 ID

真实库 `SELECT MAX(id) FROM system_menu` = **13683**

| 计划菜单 ID | 名称 | 类型 | 真实状态 |
|---|---|---|---|
| 13684 | 维修管理 | 目录 | 空闲 ✅ |
| 13685 | 故障上报 | 菜单 | 空闲 ✅ |
| 13686 | 维修工单 | 菜单 | 空闲 ✅ |
| 13687 | 预约影响 | 菜单 | 空闲 ✅ |
| 13688 | 故障上报按钮 | 按钮 | 空闲 ✅ |

### 2.2 角色 ID

真实库 `SELECT MAX(id) FROM system_role` = **908**

| 角色 ID | code | 真实状态 |
|---|---|---|
| 909 | instrument_repair_manager | 空闲 ✅ |

### 2.3 系统表名

| SQL 引用 | 真实表名 | 核验 |
|---|---|---|
| system_menu | system_menu | ✅ |
| system_role | system_role | ✅ |
| system_role_menu | system_role_menu | ✅ |
| system_tenant_package | system_tenant_package | ✅ |
| system_user_role | system_user_role | ✅ |

### 2.4 套餐 114

`SELECT id, name FROM system_tenant_package WHERE id=114` = **114 成都中医药大学** ✅

### 2.5 权限码与 Controller 对齐

| 权限码 | Controller @PreAuthorize | 核验 |
|---|---|---|
| lab:instrument:fault-report:submit | InstrumentFaultReportController.submit | ✅ |
| lab:instrument:fault-report:admin | InstrumentFaultReportController.confirm/page | ✅ |
| lab:instrument:repair-order:admin | InstrumentRepairOrderController 管理端端点 | ✅ |
| lab:instrument:repair-order:handle | InstrumentRepairOrderController 处理端端点 | ✅ |

### 2.6 角色权限矩阵

| 角色 | 故障上报 | 故障审核 | 工单派工/恢复 | 工单处理 | 预约影响 |
|---|---|---|---|---|---|
| 904 普通用户 | ✅ submit | ❌ | ❌ | ❌ | ❌ |
| 906 lab_admin | ✅ | ✅ | ✅ | ✅ | ✅ |
| 908 设备负责人 | ✅ submit | ❌ | ❌ | ❌ | ❌ |
| 909 维修负责人 | ✅ submit | ❌ | ❌ | ✅ handle | ❌ |

维修负责人与设备负责人业务关系**分离**：
- 维修负责人靠 ROOM_REPAIR ACTIVE 业务关系获得工单处理权限
- 设备负责人靠 DEVICE/PLATFORM ACTIVE 业务关系获得资质/预约管理权限
- 角色授权与业务关系表分离，不交叉

---

## 三、预检 SELECT 结果（真实只读执行）

| 检查项 | 预期 | 实际 | 结论 |
|---|---|---|---|
| 5 张新表不存在 | cnt=0 | 5 张均不存在 | ✅ |
| 前置依赖表存在 | cnt=1 | device/manager/reservation 均存在 | ✅ |
| 数据库字符集 | utf8mb4 | utf8mb4 | ✅ |
| 菜单 ID 13684~13688 空闲 | 不存在 | 不存在 | ✅ |
| 角色 909 空闲 | 不存在 | 不存在 | ✅ |
| 套餐 114 存在 | 成都中医药大学 | 成都中医药大学 | ✅ |

---

## 四、执行顺序建议

1. **58 号 DDL**：创建 5 张表
2. **验收**：`SHOW TABLES LIKE 'lab_instrument_%'` 确认 5 表存在
3. **59 号菜单/角色**：菜单 + 角色 909 + 套餐关联 + 角色菜单授权
4. **验收**：`SELECT * FROM system_menu WHERE id BETWEEN 13684 AND 13688`
5. **分配用户**：系统管理 → 用户管理 → 真实维修负责人账号分配角色 909
6. **业务关系**：仪器管理 → 负责人分配 → 为维修负责人创建 ROOM_REPAIR ACTIVE 关系
7. **缓存失效**：菜单/角色 Redis 缓存

---

## 五、最终结论

**58/59 号 SQL 达到可执行审批条件。**

- 58 号 DDL 字段与 5 个 DO 完全对齐
- 59 号菜单/角色 ID 真实库确认空闲
- 系统表名、套餐、权限码全部核验通过
- MySQL 8.0.12 兼容性确认

**等待负责人授权执行。** 本轮未执行任何 SQL。
