# 65-INSTRUMENT-06-R1 部署阻断修复与专项测试报告

> 编制日期：2026-10-20
> 任务：INSTRUMENT-06-R1-DEPLOYMENT-BLOCKER-FIX-01
> 判定：CODE PASS + SQL READY + INTEGRATION HOLD + FUNCTIONAL HOLD

---

## 一、阶段一：真实代码与文档一致性核验结论

### 1.1 虚假声称纠正

| 原声称 | 真实情况 | R1 处置 |
|---|---|---|
| 60 号声称 243/243 PASS | 首轮实际只有 195/195，无任何维修测试 | R1 新增 48 测试，**真实 243/243 PASS** |
| 48 个维修测试 | 首轮 0 个 | R1 新增 7 个测试类共 48 用例 |
| U6 预约影响已实现 | createFromFault/adminRestoreApprove 直接改设备状态，绕过影响逻辑 | R1 修复：标记预约影响 + AUTO_RESTORED 区分 + 人工处理 Service |
| ROOM_ADMIN 可恢复验收 | 实际 Service 用 canManageAll，仅 lab_admin | 已正确，补测试验证 |
| 58 号 DDL 与代码一致 | repair_order 表字段与 DO 完全不一致 | R1 重写 58 号 DDL 与 DO 对齐 |
| 前端路由已配置 | 路由未配置（依赖动态菜单） | 已说明：动态菜单，59 号 SQL 执行后生效 |

### 1.2 接口完整性核验

| 接口 | 存在 | 方法 | 行号证据 |
|---|---|---|---|
| 故障上报 | ✅ | InstrumentFaultReportServiceImpl.submitFault | L79 |
| 管理员确认/驳回 | ✅ | adminConfirm | L115 |
| 手动派工 | ✅ | assignAssignee | L148 |
| 维修开始 | ✅ | startProcessing | L212 |
| 维修记录 | ✅ | recordProcess | L243 |
| 提交维修结果 | ✅ | submitRepairResult | L275 |
| 恢复验收通过 | ✅ | adminRestoreApprove | L309 |
| 恢复验收退回 | ✅ | adminRestoreReject | L365 |
| 预约影响人工处理 | ✅（R1 新增） | InstrumentReservationImpactService.handleImpact | 新建 |

---

## 二、P0 修复明细

### P0-1：U7 恢复验收权限（仅 lab_admin）

**实现**：
- `adminRestoreApprove` / `adminRestoreReject` 首行 `if (!scopeSupport.canManageAll(loginUserId))` → 抛 RESTORE_PERMISSION_DENIED
- Controller `@PreAuthorize("@ss.hasPermission('lab:instrument:repair-order:admin')")`
- 59 号 SQL 仅角色 906（lab_admin）拥有 repair-order:admin

**测试**：Instrument06RepairOrderServiceTest.testAdminRestoreApprove_onlyAdmin
**证据**：[InstrumentRepairOrderServiceImpl.java L311](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentRepairOrderServiceImpl.java#L311)

### P0-2：U6 预约影响闭环

**修复前**：createFromFault 和 adminRestoreApprove 直接 `device.setStatus()` + `deviceMapper.updateById()`，**绕过** updateDeviceStatus 的预约影响逻辑。

**修复后**：
1. **createFromFault**（设备→FAULT）：调用 `markPendingReservationsImpacted()` 写入 InstrumentReservationImpactDO（handleStatus=PENDING），关联 repairOrderId 和 faultReportId
2. **adminRestoreApprove**（设备→NORMAL）：调用 `autoMarkImpactsAsDeviceRestored()` 将 PENDING → **AUTO_RESTORED**
3. **人工处理**：新增 InstrumentReservationImpactService.handleImpact()，管理员将 AUTO_RESTORED/PENDING → **PROCESSED**

**关键区分**：AUTO_RESTORED ≠ PROCESSED
- AUTO_RESTORED = 设备已恢复（事实），预约影响仍需人工处理
- PROCESSED = 管理员已人工处理（通知改期/作废/直接使用）

**幂等**：markPendingReservationsImpacted 检查 `selectActiveByReservation`，已有 PENDING 则跳过。

**测试**：Instrument06ReservationImpactTest（6 用例）
**证据**：[InstrumentRepairOrderServiceImpl.java L590-L633](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentRepairOrderServiceImpl.java#L590-L633)

**FUNCTIONAL HOLD**：预约状态机无 STARTED（INSTRUMENT-03 冻结），"禁止实际开始使用"无入口。已提供 `isReservationCurrentlyImpacted()` 服务方法供未来 STARTED 端点调用。

### P0-3：T2 权限隔离

**修复**：所有资质/信用/暂停/预约 Service 调用方从废弃方法 `canManageDevice()`/`getManagedDeviceIds()` 改为显式 `canManageDeviceBusiness()`/`getBusinessManagedDeviceIds()`（不含 ROOM_REPAIR）。

| 文件 | 改动数 |
|---|---|
| InstrumentQualificationServiceImpl | 4 处 canManageDeviceBusiness + 2 处 getBusinessManagedDeviceIds |
| InstrumentSuspendServiceImpl | 2 处 + 1 处 |
| InstrumentCreditServiceImpl | 1 处 |
| InstrumentReservationServiceImpl | 7 处 + 1 处 |

**测试**：Instrument06ScopePermissionTest（8 用例）— 验证 ROOM_REPAIR 用户 canManageDeviceBusiness=false、不能审批资质/管理暂停/调整信用
**证据**：[InstrumentScopeSupport.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentScopeSupport.java)

### P0-4：U1 手动派工

**核验**：
- assignAssignee 首行 `canManageAll` 校验 ✅
- 校验目标用户是该房间 ROOM_REPAIR ACTIVE 负责人 ✅
- 重派工时旧负责人存入 lastAssigneeUserId，assigneeUserId 更新 ✅
- 旧负责人立即失权：canHandleByUser 检查 `order.getAssigneeUserId().equals(loginUserId)` ✅
- 无自动派工路径 ✅

**测试**：Instrument06RepairOrderServiceTest（assign/reassign/notRepairManager 用例）

---

## 三、测试结果（真实，已亲自运行）

```
mvn clean test -pl yudao-module-lab
Tests run: 243, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

| 测试类 | 用例数 | 覆盖 |
|---|---|---|
| Instrument06FaultReportServiceTest | 8 | 故障上报/重复/确认/驳回/权限 |
| Instrument06RepairOrderServiceTest | 16 | 派工/开始/记录/提交/恢复/退回/取消/重开 |
| Instrument06ScopePermissionTest | 8 | T2 权限隔离（Business vs Repair） |
| Instrument06ReservationImpactTest | 6 | U6 预约影响标记/去重/AUTO_RESTORED/PROCESSED |
| Instrument06ConcurrencyTest | 3 | 并发派工/恢复/状态更新 |
| Instrument06TenantIsolationTest | 3 | 跨租户拒绝 |
| Instrument06QualificationDuplicateActiveTest | 4 | 历史遗留资质重复 ACTIVE |
| **新增合计** | **48** | |
| INSTRUMENT-01/02/03 原有 | 195 | 零回归 |
| **总计** | **243** | **全部 PASS** |

---

## 四、前端修复

| 错误 | 修复 |
|---|---|
| submit.vue `device.code` 不存在 | → `device.deviceNo`（3 处） |
| detail.vue `idx` 未使用 | 移除 idx 参数 |
| detail.vue Tag type 类型不匹配 | historyItemType 返回类型改为联合类型 |

**TS 检查**：维修模块 0 错误（`vue-tsc --noEmit` 过滤 instrument 无输出）。
**路由**：动态菜单机制，59 号 SQL 执行后自动生效，未硬编码静态路由。

---

## 五、58/59 SQL 核验

### 58 号 DDL（R1 重写）

- 5 张表字段与 5 个 DO **完全对齐**（驼峰→下划线）
- 表名命名规范与现有 lab_instrument_* 一致
- 含 tenant_id + deleted（TenantBaseDO）
- 索引：repair_order uk(tenant_id,order_no)、repair_history uk(tenant_id,repair_order_id,history_no)
- MySQL 8.0 兼容

### 59 号菜单/角色 SQL

- 菜单 ID 13684~13688：真实库 max_menu_id=13683，**空闲** ✅
- 角色 909：真实库 max_role_id=908，**空闲** ✅
- 系统表名：system_menu/system_role/system_role_menu/system_tenant_package/system_user_role **全部正确** ✅
- 套餐 114 = 成都中医药大学 ✅

---

## 六、最终判定

| 维度 | 状态 |
|---|---|
| **CODE PASS** | ✅ 前后端接入完成，243/243 测试通过，U1/U4/U6/U7/T2 已实现 |
| **SQL READY** | ✅ 58/59 号设计稿与真实 Schema 一致，预检通过 |
| **INTEGRATION HOLD** | ⚠️ DDL/菜单/角色 SQL 未授权执行，无法真实端到端验证 |
| **FUNCTIONAL HOLD** | ⚠️ 预约状态机无 STARTED，"禁止实际开始使用"无入口（已提供服务层校验） |

**不 FAIL**：无越权恢复、无自动派工、无错误处理已有预约、无未经授权数据库写入。

## R4 最新裁决补充（2026-10-20）

本报告保留原 R1 测试和验收结论作为历史证据。R4 负责人已明确取消对实际使用拦截/签到入口的要求，因此原“FUNCTIONAL HOLD：没有 STARTED 入口”的 U6 阻断结论已被取代；R4 按预约记录和预约影响管理闭环重新验收。历史测试数字不作为 R4 测试结果。部署仍需单独确认 SQL、菜单权限、数据库和运行时状态。
