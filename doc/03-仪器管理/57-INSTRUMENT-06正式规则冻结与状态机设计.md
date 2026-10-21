# INSTRUMENT-06 正式规则冻结与状态机设计

> **文档编号**：57-INSTRUMENT-06
> **阶段**：D1 规则冻结
> **创建日期**：2026-10-20
> **前置文档**：[56-INSTRUMENT-06现状预检与Schema设计依据.md](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/56-INSTRUMENT-06%E7%8E%B0%E7%8A%B6%E9%A2%84%E6%A3%80%E4%B8%8ESchema%E8%AE%BE%E8%AE%A1%E4%BE%9D%E6%8D%AE.md)
> **当前代码状态**：INSTRUMENT-06 全部代码已完成，本报告为状态机与规则冻结依据。

---

## 1. 裁决汇总（U1/U4/U6/U7/T2/G26/H1）

D1 阶段对以下关键问题做了正式裁决，所有后续开发以此为冻结基线。

| 裁决编号 | 问题 | 裁决结论 | 影响范围 |
|----------|------|----------|----------|
| **U1** | 故障上报入口 | 普通用户可提交 `instrument_fault_report`，管理员可代报并直接创建维修工单 | 前端 fault-report/submit.vue + 后端 FaultReportController |
| **U4** | 故障报告与维修工单关系 | 故障报告可独立存在（管理员暂不创建工单）；创建工单后 `fault_report.repair_order_id` 外键关联 | T1/T2 表结构 + FaultReportService |
| **U6** | 维修中已有 PENDING 预约如何处理 | **保留 + 标记受影响 + 管理员人工处理**。不自动取消，不新增 STARTED 预约状态。维修开始时自动扫描未来 PENDING 预约写入 `reservation_impact` 表并置为 IMPACTED | D7 预约影响逻辑 + ReservationImpactService |
| **U7** | 退回后重新提交 | REJECTED 状态的工单可由提交人重新提交，状态回到 SUBMITTED | RepairOrderService.resubmit() |
| **T2** | 权限如何拆分 | 维修负责人（ROOM_REPAIR）只能操作自己被指派的工单；管理员（ROOM_ADMIN/LAB_ADMIN）可管理所有工单（确认/指派/验收/关闭），但不自动拥有设备基础信息管理权限 | InstrumentScopeSupport 枚举（D8 已验证） |
| **G26** | 维修完成后的设备状态变更 | `REPAIRED → RESTORED` 验收通过后自动将设备状态切回 NORMAL，并写入 `device_status_history` | RepairOrderServiceImpl.adminRestoreApprove() |
| **H1** | 严重程度定义 | 三级：MINOR（轻微/不影响使用）、MAJOR（主要影响/需尽快处理）、CRITICAL（严重/禁止使用） | FaultSeverityEnum |

---

## 2. RepairOrderStatusEnum 九态状态机

### 2.1 状态定义

| 状态 | 枚举值 | 含义 | 可流转到 |
|------|--------|------|----------|
| SUBMITTED | 10 | 已提交，等待管理员确认 | CONFIRMED, REJECTED, CANCELED |
| CONFIRMED | 20 | 管理员已确认，等待指派 | ASSIGNED |
| ASSIGNED | 30 | 已指派维修负责人，等待开始 | IN_PROGRESS |
| IN_PROGRESS | 40 | 维修进行中 | REPAIRED |
| REPAIRED | 50 | 维修完成，等待管理员验收 | RESTORED, REOPENED |
| RESTORED | 60 | 管理员验收通过，设备已恢复 | —（终态） |
| REJECTED | -1 | 管理员驳回（无效报修/重复） | SUBMITTED（重新提交） |
| CANCELED | 0 | 取消（提交人/管理员） | —（终态） |
| REOPENED | 70 | 管理员验收退回，需继续维修 | IN_PROGRESS |

### 2.2 状态流转图

```
     ┌────────────┐  管理员确认   ┌──────────┐  指派负责人  ┌──────────┐
     │ SUBMITTED  │──────────────▶│ CONFIRMED │────────────▶│ ASSIGNED │
     │  (10)      │               │  (20)     │             │  (30)    │
     └────────────┘               └──────────┘             └──────────┘
          │  │  │                                                    │
          │  │  │ 管理员驳回/无效                                       │ 负责人开始维修
          │  │  ▼                                                    ▼
          │  │  ┌──────────┐                                    ┌──────────┐
          │  │  │ REJECTED │                                    │IN_PROGRESS│
          │  │  │  (-1)    │                                    │  (40)    │
          │  │  └──────────┘                                    └──────────┘
          │  │       │ 重新提交                                          │
          │  └───────┘                                                   │ 负责人提交完成
          │                                                              ▼
          │ 取消                                                    ┌──────────┐
          ▼                                                         │ REPAIRED │
     ┌──────────┐                                                   │  (50)    │
     │ CANCELED │                                                   └──────────┘
     │   (0)    │                                                        │  │
     └──────────┘                           管理员验收通过 / 验收退回    │  │
                                                                          ▼  ▼
                                                                     ┌──────────┐
                                                                     │ RESTORED │
                                                                     │  (60)    │
                                                                     └──────────┘
                                                                     
                                                                     退回: REPAIRED → REOPENED(70) → IN_PROGRESS
```

### 2.3 各状态流转条件与操作角色

| 流转 | 触发动作 | 操作角色 | 校验点 |
|------|----------|----------|--------|
| SUBMITTED → CONFIRMED | 管理员确认工单 | ROOM_ADMIN / LAB_ADMIN | 工单当前必须是 SUBMITTED；设备必须存在；FOR UPDATE 行锁 |
| SUBMITTED → REJECTED | 管理员驳回工单 | ROOM_ADMIN / LAB_ADMIN | 工单当前必须是 SUBMITTED；必须填写驳回原因 |
| SUBMITTED → CANCELED | 取消工单 | 提交人本人 / ROOM_ADMIN | 工单当前必须是 SUBMITTED |
| REJECTED → SUBMITTED | 重新提交 | 提交人本人 | 工单当前必须是 REJECTED；可修改故障描述 |
| CONFIRMED → ASSIGNED | 指派维修负责人 | ROOM_ADMIN / LAB_ADMIN | 工单必须 CONFIRMED；被指派人必须有 ROOM_REPAIR 业务关系；FOR UPDATE |
| ASSIGNED → IN_PROGRESS | 开始维修 | 被指派的维修负责人 | 工单必须 ASSIGNED；当前登录用户 == assigneeId；FOR UPDATE |
| IN_PROGRESS → REPAIRED | 提交维修完成 | 被指派的维修负责人 | 工单必须 IN_PROGRESS；必须至少有一条 repair_history 记录；FOR UPDATE |
| REPAIRED → RESTORED | 管理员验收通过 | ROOM_ADMIN / LAB_ADMIN | 工单必须 REPAIRED；事务内同时：工单状态→RESTORED + 设备状态→NORMAL + 写 device_status_history + 关闭所有 reservation_impact |
| REPAIRED → REOPENED | 管理员验收退回 | ROOM_ADMIN / LAB_ADMIN | 工单必须 REPAIRED；必须填写退回原因；状态回退到 IN_PROGRESS（实际是 REOPENED → IN_PROGRESS 两步，或直接 REPAIRED → REOPENED） |
| REOPENED → IN_PROGRESS | 负责人重新开始 | 被指派的维修负责人 | 工单必须 REOPENED；当前用户 == assigneeId |

所有状态变更均使用 **`SELECT ... FOR UPDATE` 行锁** + **条件更新 affectedRows == 1 校验** 双重保护，防止并发下的状态穿透。

---

## 3. 核心枚举设计

### 3.1 DeviceStatusHistoryActionEnum

| 枚举值 | 含义 | 触发场景 |
|--------|------|----------|
| FAULT_REPORTED | 故障上报，设备切 FAULT | 管理员确认故障并触发 updateDeviceStatus(FAULT) |
| MAINTENANCE_START | 维修开始，设备切 MAINTENANCE | 工单进入 IN_PROGRESS（可选，视故障严重度） |
| REPAIR_COMPLETE | 维修完成，设备临时 MAINTENANCE | 工单进入 REPAIRED |
| RESTORE_APPROVE | 验收通过，设备切 NORMAL | 工单进入 RESTORED |
| ADMIN_FORCE | 管理员强制变更 | 管理员手动修改设备状态 |

### 3.2 RepairActionEnum（repair_history.action 字段）

| 枚举值 | 含义 | 操作者 |
|--------|------|--------|
| DIAGNOSIS | 诊断记录 | 维修负责人 |
| REPAIR_STEP | 维修步骤 | 维修负责人 |
| PART_REPLACED | 零件更换 | 维修负责人 |
| PHOTO_UPLOADED | 照片上传 | 维修负责人 |
| NOTE_ADDED | 备注补充 | 维修负责人 / 管理员 |
| ROLLBACK | 退回处理 | 维修负责人（被退回后补记录） |

### 3.3 FaultSeverityEnum（H1 裁决）

| 枚举值 | 级别 | 说明 | 默认设备状态变更 |
|--------|------|------|------------------|
| MINOR | 轻微 | 不影响正常使用，可暂缓 | 不自动切 FAULT，由管理员决定 |
| MAJOR | 主要 | 主要功能受影响，需尽快处理 | 确认工单后切 MAINTENANCE |
| CRITICAL | 严重 | 禁止使用，存在安全/数据风险 | 确认工单后立即切 FAULT，并阻断新预约 |

---

## 4. 权限拆分矩阵（T2 裁决）

### 4.1 InstrumentScopeSupport 枚举（D8 已验证）

```
┌───────────────────────────┬──────────────┬──────────────┬──────────────┬──────────────┐
│  能力 / 角色               │ ROOM_ADMIN   │ LAB_ADMIN    │ ROOM_REPAIR  │ NORMAL_USER  │
├───────────────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ canManageDeviceBusiness   │      ✅      │      ✅      │      ❌      │      ❌      │
│ canRepairDevice           │      ✅      │      ✅      │      ✅      │      ❌      │
│ canSubmitFaultReport      │      ✅      │      ✅      │      ✅      │      ✅      │
│ canManageAllOrders        │      ✅      │      ✅      │      ❌      │      ❌      │
│ canOperateAssignedOrder   │      ✅      │      ✅      │      ✅(自己)│      ❌      │
└───────────────────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────────────────────┘
```

- `canManageDeviceBusiness`：不含 ROOM_REPAIR（D8 拆分修复后确认），管设备基础信息、上下架、报废
- `canRepairDevice`：含 ROOM_REPAIR，管维修工单确认、指派、执行、验收
- `canManageAllOrders`：仅管理员，看所有工单、指派、验收
- `canOperateAssignedOrder`：维修负责人只能操作自己被指派的工单（通过 `repair_order.assignee_id = currentUserId` 校验）

### 4.2 关键权限校验点

| 接口 | 权限校验逻辑 |
|------|-------------|
| POST /fault-report/submit | 登录即可 |
| POST /fault-report/admin-create | canManageAllOrders |
| GET /fault-report/admin-list | canManageAllOrders |
| GET /fault-report/my-list | 当前用户 == reporterId 或 canManageAllOrders |
| POST /repair-order/confirm | canManageAllOrders + 工单当前 SUBMITTED |
| POST /repair-order/reject | canManageAllOrders + 工单当前 SUBMITTED |
| POST /repair-order/assign | canManageAllOrders + 工单当前 CONFIRMED |
| POST /repair-order/start | canRepairDevice + 工单 ASSIGNED + 当前用户 == assigneeId |
| POST /repair-order/submit-complete | canRepairDevice + 工单 IN_PROGRESS + 当前用户 == assigneeId |
| POST /repair-order/restore-approve | canManageAllOrders + 工单 REPAIRED |
| POST /repair-order/restore-reject | canManageAllOrders + 工单 REPAIRED/REOPENED |
| POST /repair-order/resubmit | 当前用户 == submitterId + 工单 REJECTED |

---

## 5. 预约影响处理规则（U6 裁决详述）

### 5.1 规则原文

> 设备因维修进入 FAULT 或 MAINTENANCE 状态后，已有 PENDING 预约 **不自动取消**，保留原值并在 `instrument_reservation_impact` 表中记录关联关系与影响原因，由管理员人工处理（手动取消 / 改期 / 继续使用视严重程度）。

### 5.2 自动触发时机

在 `RepairOrderServiceImpl.startRepair()`（工单进入 IN_PROGRESS）或 `adminConfirmFault()`（CRITICAL 确认）中，调用：

```
updateDeviceStatus(deviceId, FAULT/MAINTENANCE, action, operatorId)
    ↓
在 InstrumentDeviceServiceImpl.updateDeviceStatus() 内部：
    1. FOR UPDATE instrument_device，更新状态
    2. INSERT INTO device_status_history
    3. SELECT * FROM instrument_reservation
         WHERE device_id = ?
           AND status = 'PENDING'
           AND start_time > NOW()
       → 对每条 INSERT INTO reservation_impact(impacter_type='REPAIR', impacter_id=orderId, reservation_id, impact_reason)
```

### 5.3 管理员可执行的后续操作

| 操作 | 效果 |
|------|------|
| 手动取消该预约 | reservation.status → CANCELED，reservation_impact.resolved = 1 |
| 改期 | 管理员操作 reservation 更新时间，reservation_impact.resolved = 1 |
| 标记忽略（维修不影响） | reservation_impact.resolved = 1，reservation 不变 |
| 设备快速修复后恢复 | adminRestoreApprove 自动关闭所有关联 reservation_impact |

### 5.4 为什么不新增 STARTED 状态？

INSTRUMENT-03 在 [34-INSTRUMENT-03预约管理版范围收敛与简化报告.md](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/34-INSTRUMENT-03%E9%A2%84%E7%BA%A6%E7%AE%A1%E7%90%86%E7%89%88%E8%8C%83%E5%9B%B4%E6%94%B6%E6%95%9B%E4%B8%8E%E7%AE%80%E5%8C%96%E6%8A%A5%E5%91%8A.md) 冻结时，裁决：
- 预约无 STARTED 态，实际使用以 PENDING → FINISHED（正常完成）或 CANCELED/VOIDED 处理
- 原因：STARTED 态需要定时任务扫描实际开始时间、增加状态机复杂度、真实使用中 PENDING 到 FINISHED 的跳跃足够覆盖业务

INSTRUMENT-06 不在预约状态机域内，不修改 INSTRUMENT-03 裁决，采用 **保留 + 标记 + 人工处理** 的替代方案。

---

## 6. 状态机实现要点

### 6.1 事务边界

```
adminRestoreApprove(repairOrderId, approve, comment):
  BEGIN TRANSACTION;
  1. SELECT * FROM repair_order WHERE id = ? FOR UPDATE;
     校验 status == REPAIRED
  2. UPDATE repair_order SET status = RESTORED/REOPENED WHERE id = ? AND status = REPAIRED;
     校验 affectedRows == 1
  3. INSERT INTO repair_history(order_id, action='RESTORE_APPROVE/RESTORE_REJECT', ...)
  4. IF approve:
       UPDATE instrument_device SET status = 'NORMAL' WHERE id = ?;
       INSERT INTO device_status_history(action='RESTORE_APPROVE', ...);
       UPDATE reservation_impact SET resolved = 1 WHERE impacter_id = orderId;
  COMMIT;
```

### 6.2 单号生成

复用 `RedisSerialNumberDAO`：
- 故障单号：`FR` + `yyyyMMdd` + 6 位 Redis 自增序号（每日重置）
- 维修工单：`RO` + `yyyyMMdd` + 6 位 Redis 自增序号
- 历史记录：`RH` + 时间戳 + Redis 序列

### 6.3 条件更新双重保护

所有状态切换 SQL 形式：
```sql
UPDATE instrument_repair_order
SET status = #{newStatus}, ...
WHERE id = #{id} AND status = #{expectedOldStatus};
```
Java 侧检查 `affectedRows == 1`，否则抛出 `BusinessException("状态已变更，请刷新")`。

---

## 7. 变更记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0 | 2026-10-20 | 初始版本，冻结九态状态机 + 枚举 + 权限矩阵 + 预约影响规则 | 开发组 |

## R4 最新负责人裁决补充（2026-10-20）

本节取代本文件中任何与之冲突的历史表述：预约只作为时段和管理记录；第一期不管理真实使用过程，不提供签到、签退或开始使用入口，不新增签到表或实际使用状态。预约到时不自动改变状态。预约仍仅使用 `PENDING / FINISHED / CANCELED / VOIDED`，不改变 INSTRUMENT-03 生命周期和时段占用规则。预约开始/结束时间仍由原授权管理人员在既有完成流程中手工登记，不得自动生成。

普通登录用户在有仪器查询/访问权限时可报修，无需预约、设备使用资质、设备负责人或维修负责人身份。后端以当前登录用户作为报修人，验证租户内设备存在；确认、驳回、派工及恢复验收仍由本草基因管理员按现有权限完成。受影响预约保留，管理员人工处理；不得自动取消、改期、扣分或改变预约状态。

U6 的验收范围是“故障设备预约记录与预约影响管理闭环”，缺少签到功能不构成阻断。系统不能控制设备实际使用；故障设备现场物理停用、警示标识及安全管理由实验室线下流程负责。C7 预约创建开关保持原值。
