# INSTRUMENT-06 现状预检与 Schema 设计依据

> **文档编号**：56-INSTRUMENT-06
> **阶段**：D0 现状核验
> **创建日期**：2026-10-20
> **关联文件**：
> - [58-INSTRUMENT-06数据库DDL设计稿.sql](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/58-INSTRUMENT-06%E6%95%B0%E6%8D%AE%E5%BA%93DDL%E8%AE%BE%E8%AE%A1%E7%A8%BF.sql)
> - [47-INSTRUMENT-04剩余功能盘点与开发计划.md](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/47-INSTRUMENT-04%E5%89%A9%E4%BD%99%E5%8A%9F%E8%83%BD%E7%9B%98%E7%82%B9%E4%B8%8E%E5%BC%80%E5%8F%91%E8%AE%A1%E5%88%92.md)
> - [48-INSTRUMENT-04仪器维修与日常管理实施报告.md](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/48-INSTRUMENT-04%E4%BB%AA%E5%99%A8%E7%BB%B4%E4%BF%AE%E4%B8%8E%E6%97%A5%E5%B8%B8%E7%AE%A1%E7%90%86%E5%AE%9E%E6%96%BD%E6%8A%A5%E5%91%8A.md)
> - [51-INSTRUMENT-04遗留Bug与待裁决问题清单.md](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/51-INSTRUMENT-04%E9%81%97%E7%95%99Bug%E4%B8%8E%E5%BE%85%E8%A3%81%E5%86%B3%E9%97%AE%E9%A2%98%E6%B8%85%E5%8D%95.md)
> **当前代码状态**：INSTRUMENT-06 全部代码已完成（后端 Java + 前端 Vue），DDL 与菜单 SQL 已编写完毕，等待授权部署。

---

## 1. 预检总览

本报告记录 INSTRUMENT-06（仪器维修与故障管理）在正式开发启动前对现有系统的 15 项现状核验，以确认：
1. 现有 `maintenance` 表是否可直接复用为维修工单主表
2. 现有枚举与服务是否覆盖维修流程所需语义
3. ScopeSupport 权限矩阵是否已从 INSTRUMENT-04 遗留的错误中修复
4. 数据库 live 快照中相关表的真实状态

预检于 D0 阶段完成，结论直接指导 D1 Schema 冻结与 D2-D6 开发任务拆分。

---

## 2. 15 项预检明细

| # | 预检项 | 检查对象 | 实际发现 | 结论 |
|---|--------|----------|----------|------|
| P1 | `InstrumentMaintenanceDO` 语义 | Java 实体类 | 字段包含 `startTime / endTime / maintenanceType / operatorId`，表注释为"仪器维护时段占用记录" | **维护时段占用表，不能当维修工单主表** |
| P2 | `maintenance` 表 DDL | MySQL | 物理表名 `instrument_maintenance`，用于阻断维护时段的预约创建，不携带故障描述、维修过程、验收结论 | 语义不匹配，不可复用 |
| P3 | `InstrumentMaintenanceMapper` | Mapper 接口 | 仅有 `checkConflict(startTime, endTime, instrumentId)` 和 `cancelById(id)` 两个方法 | 无工单流转、状态变更、负责人指派能力 |
| P4 | `MaintenanceStatusEnum` | 枚举类 | 仅定义 `ACTIVE(1) / CANCELED(0)` 两态 | 无法表达"待确认/处理中/已完成/待验收/已退回"等维修语义 |
| P5 | `ReservationStatusEnum` | 枚举类 | `PENDING / FINISHED / CANCELED / VOIDED`，**没有 STARTED** | 维修流程需要 STARTED 态来标记"已开始维修占用"；但预约状态机已在 INSTRUMENT-03 冻结，不能改 |
| P6 | `ScopeSupport` 权限矩阵 | `InstrumentScopeSupport` 枚举 | INSTRUMENT-04 曾错误将 `ROOM_REPAIR` 加入 `canManageDeviceBusiness`；D8 阶段已拆分修复 | 当前 `canManageDeviceBusiness` 不含 ROOM_REPAIR，`canRepairDevice` 含 ROOM_REPAIR，修复正确 |
| P7 | `DeviceStatusEnum` | 设备状态枚举 | 已有 `NORMAL / MAINTENANCE / FAULT / SCRAP` 四态 | 可复用，但 FAULT 与 MAINTENANCE 的进入/退出需由维修流程驱动 |
| P8 | `InstrumentDeviceServiceImpl` | 设备服务 | 有 `updateDeviceStatus()` 但仅做基础状态切换，不写入历史，不级联预约 | 需扩展：集成 DeviceStatusHistory + PENDING 预约自动标记 |
| P9 | 现有预约冲突机制 | INSTRUMENT-03 | `ReservationService.checkConflict` 已考虑 `maintenance` 表，但未考虑"故障期间禁止新预约" | 需在 INSTRUMENT-06 的设备故障状态下补充阻断逻辑 |
| P10 | 维修负责人角色 | 角色表 | 数据库已存在 `ROOM_REPAIR` 业务角色（维修负责人），但未分配任何真实账号 | 部署后需按真实维修负责人分配 |
| P11 | 现有维修痕迹 | 全库扫描 | 无 repair、fault、work_order、breakdown 关键词的表或字段 | 维修模块为全新域 |
| P12 | Redis 单号生成器 | `RedisSerialNumberDAO` | 已在 INSTRUMENT-01 仪器单号、INSTRUMENT-03 预约单号使用 | 可直接复用生成故障单号 `FR` / 工单 `RO` / 历史 `RH` |
| P13 | 菜单层级 | INSTRUMENT-03 已部署菜单 | `仪器管理 / 日常管理` 下无维修相关菜单入口 | 59 号菜单 SQL 需在此层级新增 |
| P14 | 前端现有页面 | Vue Router | 无 fault-report / repair-order 相关路由 | 全新目录与页面 |
| P15 | INSTRUMENT-04 ScopeSupport 错误遗留 | 代码检查 | 已在 D8 拆分任务中修正：`canManageDeviceBusiness` 不含 ROOM_REPAIR，独立出 `canRepairDevice` 矩阵 | 修复确认通过 |

---

## 3. 现有 maintenance 表与维修工单的语义差异

`instrument_maintenance` 表是 INSTRUMENT-03 预约冲突机制的一部分，其设计目标与维修工单存在本质差异：

| 维度 | maintenance（维护时段） | 维修工单（repair_order） |
|------|--------------------------|--------------------------|
| 业务目标 | 标记某时段设备被维护占用，阻断预约创建 | 记录一次完整的故障报修→派单→维修→验收流程 |
| 触发方式 | 管理员主动创建维护计划 | 用户报障或管理员发现故障 |
| 时间粒度 | `startTime` + `endTime`（时段） | 生命周期由多状态流转决定 |
| 状态模型 | 2 态：ACTIVE / CANCELED | 9 态（见 57 号文档状态机） |
| 执行人 | `operatorId`（维护人） | 提交人 / 确认人 / 指派人 / 维修负责人（多角色） |
| 过程记录 | 无 | 维修步骤、照片、更换零件、费用、结论 |
| 验收环节 | 无 | 管理员验收（通过 / 退回） |
| 与设备状态关系 | 不改变设备状态 | 驱动设备在 NORMAL / MAINTENANCE / FAULT 间切换 |
| 与预约关系 | 与 PENDING 预约做冲突检查 | 级联影响 PENDING 预约（保留 / 标记 / 人工处理） |

**结论**：maintenance 表是"时段占位符"，维修工单是"完整业务对象"，二者语义不可混同，必须新建独立表。

---

## 4. 关键枚举缺口说明

### 4.1 MaintenanceStatusEnum（仅两态，不可复用）

```java
// 现有
public enum MaintenanceStatusEnum {
    ACTIVE(1, "启用中"),
    CANCELED(0, "已取消");
}
```

维修工单需要的状态远不止两态，必须新建 `RepairOrderStatusEnum`（9 态，见 57 号）。

### 4.2 ReservationStatusEnum 无 STARTED（不可修复）

```java
// 现有 INSTRUMENT-03 冻结
public enum ReservationStatusEnum {
    PENDING, FINISHED, CANCELED, VOIDED;
    // 没有 STARTED
}
```

维修流程中我们希望标记"维修已开始，原 PENDING 预约被迫中断"，但 STARTED 态在 INSTRUMENT-03 已被裁决"不引入，实际开始时间以 FINISHED - duration 反推"。因此 INSTRUMENT-06 采取 **U6 裁决方案**：
- PENDING 预约：保留 + 标记受影响 + 管理员人工处理
- 不通过新增 STARTED 态解决（见 57 号 U6 裁决详述）

### 4.3 ScopeSupport ROOM_REPAIR 修复（已在 D8 完成）

INSTRUMENT-04 曾错误将 `ROOM_REPAIR` 加入 `canManageDeviceBusiness`，导致维修负责人意外获得"设备基础信息管理"权限。D8 拆分任务已修复：

```java
// 修复前（错误）
canManageDeviceBusiness: ROOM_ADMIN + LAB_ADMIN + ROOM_REPAIR

// 修复后（正确）
canManageDeviceBusiness: ROOM_ADMIN + LAB_ADMIN      // 基础信息、上下架、报废
canRepairDevice:          ROOM_ADMIN + LAB_ADMIN + ROOM_REPAIR  // 维修工单确认/指派/执行
```

验证命令：检查 `InstrumentScopeSupport` 枚举构造器参数，`canManageDeviceBusiness` 的 scopeList 中不再包含 ROOM_REPAIR，`canRepairDevice` 独立声明。

---

## 5. 数据库 live 快照参考

INSTRUMENT-04 已在 [47-INSTRUMENT-04剩余功能盘点与开发计划.md](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/47-INSTRUMENT-04%E5%89%A9%E4%BD%99%E5%8A%9F%E8%83%BD%E7%9B%98%E7%82%B9%E4%B8%8E%E5%BC%80%E5%8F%91%E8%AE%A1%E5%88%92.md) 中记录了 live 环境 `instrument_*` 相关表。INSTRUMENT-06 预检仅补充与维修域直接相关的结论：

| 表名 | 行数 | 结构 | 与 INSTRUMENT-06 关系 |
|------|------|------|------------------------|
| `instrument_device` | ≥1 | 在 INSTRUMENT-03 已建 | repair_order.device_id 外键 |
| `instrument_maintenance` | ≥0 | INSTRUMENT-03 已建 | 语义不可复用，仅作预约冲突参考 |
| `instrument_reservation` | ≥0 | INSTRUMENT-03 已建 | reservation_impact.reservation_id 外键 |
| `instrument_scope_support` | 枚举类 | Java 侧定义 | D8 修复 ROOM_REPAIR 后可用 |

**新增 5 张表均为全新，不会与现有表发生字段级冲突**。

---

## 6. Schema 冻结结论

基于以上 15 项预检，D0 阶段 Schema 冻结决策如下：

| # | 新建表 | 用途 | 关联文档 |
|---|--------|------|----------|
| T1 | `instrument_fault_report` | 故障上报单（用户主动/管理员代报） | 58 号 DDL 第 1 节 |
| T2 | `instrument_repair_order` | 维修工单主表（9 态状态机） | 58 号 DDL 第 2 节 |
| T3 | `instrument_repair_history` | 维修过程历史（步骤/照片/更换记录） | 58 号 DDL 第 3 节 |
| T4 | `instrument_device_status_history` | 设备状态变更流水（NORMAL↔MAINTENANCE↔FAULT） | 58 号 DDL 第 4 节 |
| T5 | `instrument_reservation_impact` | 维修影响的 PENDING 预约标记与跟踪 | 58 号 DDL 第 5 节 |

保留 `instrument_maintenance` 表原有语义与字段，不做任何修改。

所有 DDL 定义集中在 [58-INSTRUMENT-06数据库DDL设计稿.sql](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/58-INSTRUMENT-06%E6%95%B0%E6%8D%AE%E5%BA%93DDL%E8%AE%BE%E8%AE%A1%E7%A8%BF.sql)。

---

## 7. 后续阶段依赖

```
D0 现状预检（本报告） ──冻结 Schema──▶ D1 状态机设计（57号） ──冻结枚举──▶ D2-D6 开发（60/61号交付报告）
                                                                   │
                                                                   ▼
                                                        D7-D8 预约影响 + 权限拆分验证
                                                                   │
                                                                   ▼
                                                        部署就绪检查（63号） ──▶ 部署
                                                                                  │
                                                                                  ▼
                                                                           客户操作指南（64号）
```

---

## 8. 变更记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0 | 2026-10-20 | 初始版本，D0 预检 15 项 + Schema 冻结 | 开发组 |
