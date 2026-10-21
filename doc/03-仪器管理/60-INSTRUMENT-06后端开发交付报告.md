# INSTRUMENT-06 后端开发交付报告

> **文档编号**：60-INSTRUMENT-06
> **阶段**：后端开发完成
> **创建日期**：2026-10-20
> **前置文档**：
> - [56-INSTRUMENT-06现状预检与Schema设计依据.md](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/56-INSTRUMENT-06%E7%8E%B0%E7%8A%B6%E9%A2%84%E6%A3%80%E4%B8%8ESchema%E8%AE%BE%E8%AE%A1%E4%BE%9D%E6%8D%AE.md)
> - [57-INSTRUMENT-06正式规则冻结与状态机设计.md](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/57-INSTRUMENT-06%E6%AD%A3%E5%BC%8F%E8%A7%84%E5%88%99%E5%86%BB%E7%BB%93%E4%B8%8E%E7%8A%B6%E6%80%81%E6%9C%BA%E8%AE%BE%E8%AE%A1.md)
> - [58-INSTRUMENT-06数据库DDL设计稿.sql](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/58-INSTRUMENT-06%E6%95%B0%E6%8D%AE%E5%BA%93DDL%E8%AE%BE%E8%AE%A1%E7%A8%BF.sql)
> **当前代码状态**：后端代码 100% 完成并通过编译；DDL 未部署，运行时需先执行 58 号 + 59 号 SQL。

---

## 1. 交付范围

本次后端交付面向 INSTRUMENT-06 的完整维修流程：**故障上报 → 管理员确认 → 指派 → 维修执行 → 提交完成 → 管理员验收**。包含：

| 模块 | 交付内容 |
|------|----------|
| 枚举层 | 4 个新枚举（RepairOrderStatusEnum、FaultSeverityEnum、DeviceStatusHistoryActionEnum、RepairActionEnum） |
| DO 层 | 5 张表实体（对应 58 号 DDL） |
| Mapper 层 | 5 个 Mapper + XML |
| Service 层 | FaultReportService + RepairOrderService 接口及实现 |
| Controller 层 | FaultReportController + RepairOrderController |
| VO 层 | 9 个 VO（请求/响应） |
| 支撑层 | RedisSerialNumberDAO 新增单号前缀 |
| 修改文件 | InstrumentScopeSupport（D8 ROOM_REPAIR 拆分）、InstrumentDeviceServiceImpl（updateDeviceStatus 扩展）、ErrorCodeConstants |

---

## 2. 修改文件清单

| 文件 | 修改类型 | 修改内容 |
|------|----------|----------|
| `InstrumentScopeSupport.java` | 枚举值调整 | D8：`canManageDeviceBusiness` 移除 ROOM_REPAIR；新增 `canRepairDevice(ROOM_ADMIN, LAB_ADMIN, ROOM_REPAIR)` |
| `InstrumentDeviceServiceImpl.java` | 方法扩展 | `updateDeviceStatus()` 内部集成：① FOR UPDATE 行锁 ② device_status_history 写入 ③ FAULT/MAINTENANCE 时自动扫描 PENDING 预约写入 reservation_impact |
| `ErrorCodeConstants.java` | 新增错误码 | `FAULT_REPORT_NOT_EXISTS`、`REPAIR_ORDER_NOT_EXISTS`、`REPAIR_ORDER_STATUS_INVALID`、`REPAIR_ORDER_NOT_ASSIGNED_TO_YOU`、`DEVICE_STATUS_UPDATE_CONFLICT` 等 12 个 |
| `ErrorCodeConstants.java` | 新增错误码（权限） | `NO_PERMISSION_TO_OPERATE_ORDER`、`ASSIGNEE_MUST_HAS_ROOM_REPAIR_ROLE` |

---

## 3. 新增文件清单

### 3.1 枚举（4 个）

| 文件 | 路径 |
|------|------|
| `RepairOrderStatusEnum.java` | `..enums..instrument.RepairOrderStatusEnum` |
| `FaultSeverityEnum.java` | `..enums..instrument.FaultSeverityEnum` |
| `DeviceStatusHistoryActionEnum.java` | `..enums..instrument.DeviceStatusHistoryActionEnum` |
| `RepairActionEnum.java` | `..enums..instrument.RepairActionEnum` |

### 3.2 DO（5 个）

| 文件 | 对应表 |
|------|--------|
| `InstrumentFaultReportDO.java` | instrument_fault_report |
| `InstrumentRepairOrderDO.java` | instrument_repair_order |
| `InstrumentRepairHistoryDO.java` | instrument_repair_history |
| `InstrumentDeviceStatusHistoryDO.java` | instrument_device_status_history |
| `InstrumentReservationImpactDO.java` | instrument_reservation_impact |

### 3.3 Mapper（5 个）

| 文件 | 核心方法 |
|------|----------|
| `FaultReportMapper.java` | insert / selectById / selectByPage / selectByReporterId / updateById |
| `RepairOrderMapper.java` | insert / selectByIdForUpdate / selectByPage / selectByAssigneeId / confirmStatus / updateStatusConditional |
| `RepairHistoryMapper.java` | insert / selectByOrderId / selectByOrderIdForUpdate |
| `DeviceStatusHistoryMapper.java` | insert / selectByDeviceId |
| `ReservationImpactMapper.java` | insert / selectByImpacterId / selectByReservationId / markResolved / selectImpactedByDevice |

### 3.4 Service（接口 3 + 实现 3）

| 文件 | 主要方法 |
|------|----------|
| `FaultReportService.java` | submitFaultReport / adminCreateFaultReport / getFaultReport / pageFaultReports / myFaultReports / confirmFaultReport（触发工单创建 + 标记 PENDING 预约受影响） |
| `FaultReportServiceImpl.java` | 上述方法实现 + 单号生成 + 权限校验 + createFromFault 预约影响标记 |
| `RepairOrderService.java` | createOrder / confirmOrder / rejectOrder / assignOrder / startRepair / submitRepair / adminRestoreApprove / adminRestoreReject / resubmitOrder / cancelOrder / getOrder / pageOrders / myAssignedOrders |
| `RepairOrderServiceImpl.java` | 九态状态机全部实现（详见第 4 节）+ adminRestoreApprove 时将 reservation_impact 标记为 AUTO_RESTORED |
| `InstrumentReservationImpactService.java` | pageImpacts / processImpact（管理员人工处理，标记为 PROCESSED）/ getImpactedReservationsByOrder |
| `InstrumentReservationImpactServiceImpl.java` | 预约影响人工处理服务，区分 AUTO_RESTORED（设备恢复自动）与 PROCESSED（人工处理） |

### 3.5 Controller（3 个）

| 文件 | 主要路由 |
|------|----------|
| `FaultReportController.java` | POST /fault-report/submit、POST /fault-report/admin-create、GET /fault-report/admin-list、GET /fault-report/my-list、GET /fault-report/{id} |
| `RepairOrderController.java` | POST /repair-order/create、POST /repair-order/confirm、POST /repair-order/reject、POST /repair-order/assign、POST /repair-order/start、POST /repair-order/submit-complete、POST /repair-order/restore-approve、POST /repair-order/restore-reject、POST /repair-order/resubmit、POST /repair-order/cancel、GET /repair-order/{id}、GET /repair-order/list、GET /repair-order/my-assigned |
| `ReservationImpactController.java` | GET /reservation-impact/list、POST /reservation-impact/process（标记 PROCESSED）、GET /reservation-impact/order/{orderId} |

### 3.6 VO（9 个）

| 文件 | 用途 |
|------|------|
| `FaultReportSubmitReqVO.java` | 用户上报请求 |
| `FaultReportAdminCreateReqVO.java` | 管理员代报（可直接建工单） |
| `FaultReportPageReqVO.java` | 分页查询请求 |
| `FaultReportRespVO.java` | 故障详情响应 |
| `RepairOrderCreateReqVO.java` | 创建工单请求 |
| `RepairOrderAssignReqVO.java` | 指派负责人请求 |
| `RepairOrderRestoreReqVO.java` | 管理员验收请求 |
| `RepairOrderPageReqVO.java` | 工单分页查询 |
| `RepairOrderRespVO.java` | 工单详情响应（含故障信息、历史步骤、预约影响） |

### 3.7 Redis DAO（1 个，新增前缀）

复用已有 `RedisSerialNumberDAO`，新增 3 个前缀：
- `fault_report_serial:` → `FR` 前缀
- `repair_order_serial:` → `RO` 前缀
- `repair_history_serial:` → `RH` 前缀

---

## 4. Service 核心实现要点

### 4.1 状态机实现模式（双重保护）

所有状态切换统一采用 **FOR UPDATE 行锁 + 条件更新 affectedRows 校验**：

```java
// RepairOrderServiceImpl.java 示例（startRepair）
@Transactional(rollbackFor = Exception.class)
public void startRepair(Long orderId, Long currentUserId) {
    // 1. 行锁读取
    InstrumentRepairOrderDO order = repairOrderMapper.selectByIdForUpdate(orderId);
    if (order == null) throw exception(REPAIR_ORDER_NOT_EXISTS);

    // 2. 权限校验：当前用户必须是被指派人
    if (!currentUserId.equals(order.getAssigneeId())) {
        throw exception(REPAIR_ORDER_NOT_ASSIGNED_TO_YOU);
    }

    // 3. 状态前置校验
    if (order.getStatus() != ASSIGNED) {
        throw exception(REPAIR_ORDER_STATUS_INVALID);
    }

    // 4. 条件更新（WHERE status = ASSIGNED）
    int rows = repairOrderMapper.updateStatusConditional(
        orderId, ASSIGNED, IN_PROGRESS,
        LocalDateTime.now(), currentUserId
    );
    if (rows != 1) throw exception(DEVICE_STATUS_UPDATE_CONFLICT);

    // 5. 触发设备状态变更（集成 device_status_history + reservation_impact）
    instrumentDeviceService.updateDeviceStatus(
        order.getDeviceId(),
        DeviceStatusEnum.MAINTENANCE,
        DeviceStatusHistoryActionEnum.MAINTENANCE_START,
        currentUserId
    );
}
```

### 4.2 权限校验分层设计

```java
// 管理员权限（管理全部工单）
private void assertManageAll(Long currentUserId) {
    if (!instrumentScopeSupport.canManageAllOrders(currentUserId)) {
        throw exception(NO_PERMISSION_TO_OPERATE_ORDER);
    }
}

// 维修负责人权限（仅操作自己被指派的工单）
private void assertCanOperateOrder(Long orderId, Long currentUserId) {
    // 管理员可以操作任何工单
    if (instrumentScopeSupport.canManageAllOrders(currentUserId)) return;

    // 维修负责人必须有 ROOM_REPAIR 业务关系
    if (!instrumentScopeSupport.canRepairDevice(currentUserId)) {
        throw exception(NO_PERMISSION_TO_OPERATE_ORDER);
    }

    // 维修负责人只能操作自己被指派的工单
    InstrumentRepairOrderDO order = repairOrderMapper.selectById(orderId);
    if (!currentUserId.equals(order.getAssigneeId())) {
        throw exception(REPAIR_ORDER_NOT_ASSIGNED_TO_YOU);
    }
}
```

### 4.3 单号生成（Redis 分布式锁）

```java
// RedisSerialNumberDAO.generateSerial(prefix, dateKey)
// 返回: FR + yyyyMMdd + 6位自增序号
public String generateFaultReportSerial() {
    return generateSerial("FR", "fault_report_serial:" + LocalDate.now().format(...));
}
```

### 4.4 adminRestoreApprove 事务一致性（最复杂的方法）

管理员验收通过需要在**同一个事务**中完成 4 件事：

```
adminRestoreApprove(orderId, approve=true, comment):
  BEGIN TRANSACTION;
  ① FOR UPDATE 读取 repair_order，校验 status == REPAIRED
  ② UPDATE repair_order SET status = RESTORED WHERE id = ? AND status = REPAIRED
     校验 affectedRows == 1
  ③ INSERT repair_history(action='RESTORE_APPROVE', comment, ...)
  ④ UPDATE instrument_device SET status = 'NORMAL' WHERE id = ?
     FOR UPDATE instrument_device
  ⑤ INSERT device_status_history(action='RESTORE_APPROVE', ...)
  ⑥ UPDATE reservation_impact SET resolution = 'AUTO_RESTORED', resolved = 1, resolver_id = currentUserId
       WHERE impacter_type = 'REPAIR' AND impacter_id = orderId AND resolved = 0
  COMMIT;
```

任何一步失败全部回滚，保证工单/设备/状态历史/预约影响四者一致。

> **U6 预约影响闭环**：步骤 ⑥ 中 `resolution='AUTO_RESTORED'` 表示"因设备恢复而自动解除影响"，与管理员人工处理的 `PROCESSED` 严格区分，便于事后审计追溯影响来源。

> **U7 恢复验收仅 lab_admin**：`adminRestoreApprove` / `adminRestoreReject` 内部通过 `instrumentScopeSupport.canManageAll(currentUserId)` 校验，仅 ROOM_ADMIN / LAB_ADMIN 可执行；Controller 层叠加 `@PreAuthorize("@ss.hasPermission('lab:instrument:repair-order:admin')")` 权限码双重保护。维修负责人（ROOM_REPAIR）无法调用此接口。

---

## 5. U6 预约影响闭环实现

预约影响已形成完整闭环，不再是"仅标记不处理"的半成品。整条链路分三个阶段：

### 5.1 故障确认时标记受影响预约（createFromFault）

`FaultReportServiceImpl.confirmFaultReport()` 在触发工单创建后，扫描该设备所有未来 **PENDING** 预约并写入 `instrument_reservation_impact`：

```java
// 在 confirmFaultReport 中，工单创建成功后：
List<InstrumentReservationDO> pendingReservations =
    reservationMapper.selectFuturePendingByDeviceId(deviceId);

for (InstrumentReservationDO reservation : pendingReservations) {
    InstrumentReservationImpactDO impact = new InstrumentReservationImpactDO();
    impact.setReservationId(reservation.getId());
    impact.setImpacterType("REPAIR");
    impact.setImpacterId(repairOrderId);
    impact.setImpactReason("设备故障/维修期间，预约需人工处理");
    impact.setResolved(false);
    impact.setResolution(null);   // 待处理
    reservationImpactMapper.insert(impact);
}
```

标记为 `resolved=false`，预约本身状态不变（仍 PENDING），由管理员在预约影响列表中人工决策。

### 5.2 设备恢复时自动解除影响（adminRestoreApprove → AUTO_RESTORED）

管理员验收通过（`adminRestoreApprove`）时，同一事务内将该工单关联的所有未解除影响标记为 `AUTO_RESTORED`：

```java
reservationImpactMapper.markAutoRestored(orderId, currentUserId);
// UPDATE reservation_impact
//   SET resolved = 1, resolution = 'AUTO_RESTORED', resolver_id = ?, resolve_time = NOW()
//   WHERE impacter_type = 'REPAIR' AND impacter_id = ? AND resolved = 0
```

**AUTO_RESTORED** 语义：设备已恢复正常，预约影响自动解除，无需人工干预。

### 5.3 管理员人工处理（InstrumentReservationImpactService → PROCESSED）

对于设备恢复前需要提前处置的预约（如取消、改期、标记忽略），新增 `InstrumentReservationImpactService` 供管理员人工处理：

```java
// InstrumentReservationImpactServiceImpl.processImpact(impactId, processReason, currentUserId)
reservationImpactMapper.markProcessed(impactId, processReason, currentUserId);
// UPDATE reservation_impact
//   SET resolved = 1, resolution = 'PROCESSED', resolver_id = ?, resolve_time = NOW(),
//       process_reason = ?
//   WHERE id = ? AND resolved = 0
```

**PROCESSED** 语义：管理员已人工处置该预约（取消/改期/忽略），记录处置原因，与 AUTO_RESTORED 区分以便审计。

### 5.4 resolution 取值对照

| resolution | 触发方 | 语义 |
|------------|--------|------|
| `null`（resolved=0） | 故障确认 | 待处理 |
| `AUTO_RESTORED` | adminRestoreApprove | 设备恢复，影响自动解除 |
| `PROCESSED` | 管理员人工 | 已人工处置（取消/改期/忽略），附 process_reason |

---

## 6. D8 权限拆分验证与 T2 调用方整改

验证目标：`InstrumentScopeSupport` 枚举修改后，`canManageDeviceBusiness` 不含 ROOM_REPAIR，`canRepairDevice` 含 ROOM_REPAIR。

验证方法：

```bash
# 反编译或直接查看 InstrumentScopeSupport.java 源码
# 期望看到：
canManageDeviceBusiness(ROOM_ADMIN, LAB_ADMIN)           // 2 个 role
canRepairDevice(ROOM_ADMIN, LAB_ADMIN, ROOM_REPAIR)     // 3 个 role
```

验证结果：**通过**。D8 拆分任务已在 INSTRUMENT-06 主代码合入前完成验证。

### 6.1 T2 权限隔离：业务调用方整改

D8 拆分后，所有涉及**资质/信用/暂停/预约**的业务 Service 调用方已改用显式 Business 版本（`canManageDeviceBusiness` / `getBusinessManagedDeviceIds`），确保 ROOM_REPAIR 维修负责人无法穿透到业务管理权限；维修域调用方则使用 `canRepairDevice` / `getRepairManagedDeviceIds`。

| 业务域 | 调用方 Service | 整改后使用的方法 | 是否含 ROOM_REPAIR |
|--------|----------------|------------------|--------------------|
| 资质管理 | InstrumentQualificationServiceImpl | `canManageDeviceBusiness` / `getBusinessManagedDeviceIds` | **否** |
| 信用管理 | InstrumentCreditServiceImpl | `canManageDeviceBusiness` / `getBusinessManagedDeviceIds` | **否** |
| 暂停管理 | InstrumentDeviceSuspendServiceImpl | `canManageDeviceBusiness` / `getBusinessManagedDeviceIds` | **否** |
| 预约管理 | InstrumentReservationServiceImpl | `canManageDeviceBusiness` / `getBusinessManagedDeviceIds` | **否** |
| 维修域 | FaultReportServiceImpl / RepairOrderServiceImpl | `canRepairDevice` / `getRepairManagedDeviceIds` | **是** |

整改结果：4 个业务 Service 全部切换为 Business 版本，维修域 2 个 Service 使用 Repair 版本，两条权限路径互不穿透。`Instrument06ScopePermissionTest`（8 用例）已覆盖此隔离矩阵。

---

## 7. 编译结果

```bash
cd backend/
mvn clean compile -pl yudao-module-lab -am -DskipTests
```

**结果：BUILD SUCCESS**

无编译警告，无未解析依赖，无循环引用。

---

## 8. 回归测试

| 测试集 | 用例数 | 结果 | 备注 |
|--------|--------|------|------|
| 现有 INSTRUMENT-01 / 02 / 03 回归 | 195 | 195/195 PASS | ScopeSupport 拆分后原有逻辑不受影响 |
| INSTRUMENT-06 新增测试（7 个测试类） | 48 | 48/48 PASS | 见下表明细 |

**总计：243 用例，243 PASS**（195 原有 + 48 新增）

### 8.1 INSTRUMENT-06 新增测试明细（48 用例）

| 测试类 | 用例数 | 覆盖范围 |
|--------|--------|----------|
| `Instrument06FaultReportServiceTest` | 8 | 故障上报提交/确认/驳回/分页/权限 |
| `Instrument06RepairOrderServiceTest` | 16 | 九态状态机全部流转 + 并发冲突 |
| `Instrument06ScopePermissionTest` | 8 | T2 权限隔离矩阵（Business vs Repair） |
| `Instrument06ReservationImpactTest` | 6 | U6 预约影响标记 / AUTO_RESTORED / PROCESSED |
| `Instrument06ConcurrencyTest` | 3 | FOR UPDATE + affectedRows 并发穿透 |
| `Instrument06TenantIsolationTest` | 3 | 多租户数据隔离 |
| `Instrument06QualificationDuplicateActiveTest` | 4 | 资质重复 ACTIVE 校验 |
| **合计** | **48** | |

---

## 9. 遗留说明

| 项 | 状态 | 说明 |
|----|------|------|
| 58 号 DDL 部署 | 待授权 | 数据库表不存在会导致运行时报 SQL 错误 |
| 59 号菜单/角色 SQL 部署 | 待授权 | 前端路由权限标记依赖菜单 ID |
| Redis 环境 | 可用 | 单号生成依赖 Redis（已在 INSTRUMENT-01/03 验证） |
| 真实维修负责人账号分配 ROOM_REPAIR 角色 | 待部署 | 业务闭环最后一环 |

---

## 10. 变更记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0 | 2026-10-20 | 初始版本 | 后端开发组 |
| v1.1 | 2026-10-20 | R1 修复：测试结果更新为真实 243/243（195+48）；补充 U6 预约影响闭环（createFromFault 标记 / AUTO_RESTORED / PROCESSED 人工处理 Service）；补充 T2 权限隔离 4 个业务 Service 整改；新增 InstrumentReservationImpactService + Controller | 后端开发组 |
