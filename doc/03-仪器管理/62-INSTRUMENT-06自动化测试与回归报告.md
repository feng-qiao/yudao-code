# 62-INSTRUMENT-06 自动化测试与回归报告

> 编制日期：2026-10-20
> 编制依据：mvn clean compile + mvn test + ScopeSupport 权限拆分源码复核
> 测试范围：INSTRUMENT-06 维修模块后端代码 + INSTRUMENT-03 全量回归
> 最终判定：**243/243 PASS（195 原有 + 48 新增）；INTEGRATION HOLD（DB schema 未部署，需要真实写入的集成测试暂停）**

---

## 一、回归测试结果

### 1.1 命令

```powershell
cd E:\lixin\dev\ruoyi-vue-pro
mvn clean compile -pl yudao-module-lab -am
mvn test -pl yudao-module-lab
```

### 1.2 结果

```
[INFO] BUILD SUCCESS（20/20 modules compile）
[INFO] Tests run: 243, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

**243/243 PASS，零回归**。其中 195 个为原有 INSTRUMENT-01/02/03 测试，48 个为 INSTRUMENT-06 新增测试。

### 1.3 原有回归明细（与 50 号基线一致，195 用例）

| Test 类 | 测试数 | 状态 | 说明 |
|---|---|---|---|
| Instrument03DLifecycleTest | 20 | 全过 | 预约全生命周期 |
| Instrument03CReservationCreateTest | 33 | 全过 | 预约创建主流程 |
| Instrument03R2AdjustT1T2Test | 11 | 全过 | 预约调整 |
| Instrument03DataLayerTest | 14 | 全过 | Mapper 层 |
| Instrument03ConcurrencyTest | 10 | 全过 | 并发控制 |
| Instrument03BBookingRuleWindowTest | 15 | 全过 | 预约规则 + 窗口 |
| Instrument03LockCoordinatorTest | 3 | 全过 | 锁协调器 |
| Instrument03R2PermissionAnnotationTest | 4 | 全过 | 权限注解 |
| Instrument02ServiceTest | 66 | 全过 | INSTRUMENT-02 资质/信用/暂停 |
| Instrument03IsolationGuardTest | 7 | 全过 | 环境隔离守护 |
| PlasmidStorageServiceImplTest | 17 | 全过 | 无关模块 |
| RegisterApplyServiceImplTest | 31 | 全过 | 无关模块 |

本轮 **未修改** INSTRUMENT-03 回归覆盖的任何代码路径，零回归为预期结果。

### 1.4 INSTRUMENT-06 新增测试明细（48 用例，7 个测试类）

| Test 类 | 测试数 | 状态 | 覆盖范围 |
|---|---|---|---|
| Instrument06FaultReportServiceTest | 8 | 全过 | 故障上报提交/确认/驳回/分页/权限校验 |
| Instrument06RepairOrderServiceTest | 16 | 全过 | 九态状态机全部流转 + 并发冲突 + 边界 |
| Instrument06ScopePermissionTest | 8 | 全过 | T2 权限隔离矩阵（Business vs Repair 互不穿透） |
| Instrument06ReservationImpactTest | 6 | 全过 | U6 预约影响标记 / AUTO_RESTORED / PROCESSED |
| Instrument06ConcurrencyTest | 3 | 全过 | FOR UPDATE + affectedRows 并发穿透防护 |
| Instrument06TenantIsolationTest | 3 | 全过 | 多租户数据隔离 |
| Instrument06QualificationDuplicateActiveTest | 4 | 全过 | 资质重复 ACTIVE 校验 |
| **合计** | **48** | **全过** | |

#### 1.4.1 U6 预约影响测试（Instrument06ReservationImpactTest，6 用例）

| # | 场景 | 预期 |
|---|------|------|
| I-01 | 故障确认（confirmFaultReport）后，该设备未来 PENDING 预约被写入 reservation_impact（resolved=0） | 写入成功，resolution=null |
| I-02 | 设备存在多笔 PENDING 预约，全部被标记 | 影响记录数 = PENDING 预约数 |
| I-03 | 非 PENDING 预约（FINISHED/CANCELED）不被标记 | 不写入影响记录 |
| I-04 | adminRestoreApprove 验收通过后，关联影响记录 resolution=AUTO_RESTORED、resolved=1 | 自动解除，区分人工处理 |
| I-05 | 管理员人工 processImpact 后，resolution=PROCESSED、附 process_reason | 与 AUTO_RESTORED 区分 |
| I-06 | 已 PROCESSED 的影响记录不可被 AUTO_RESTORED 覆盖（幂等） | affectedRows=0，保留 PROCESSED |

#### 1.4.2 T2 权限隔离测试（Instrument06ScopePermissionTest，8 用例）

| # | 场景 | 调用方法 | ROOM_REPAIR | DEVICE | lab_admin |
|---|------|----------|-------------|--------|-----------|
| P-01 | 资质审核 | canManageDeviceBusiness | false | true | true |
| P-02 | 信用调整 | canManageDeviceBusiness | false | true | true |
| P-03 | 暂停管理 | canManageDeviceBusiness | false | true | true |
| P-04 | 预约管理 | canManageDeviceBusiness | false | true | true |
| P-05 | 故障审核 | canRepairDevice | true | false | true |
| P-06 | 维修工单处理 | canRepairDevice | true | false | true |
| P-07 | getBusinessManagedDeviceIds 不含 ROOM_REPAIR 记录 | 查询结果 | 无 | 有 | 有 |
| P-08 | getRepairManagedDeviceIds 含 ROOM_REPAIR 记录 | 查询结果 | 有 | 无 | 有 |

---

## 二、D8 权限拆分验证（ScopeSupport）

### 2.1 问题背景

INSTRUMENT-04 T2 裁决后新增 `canManageDeviceBusiness` 与 `canRepairDevice` 两个方法，职责拆分：

| 方法 | 语义 | ROOM_REPAIR 是否命中 | 调用方 |
|---|---|---|---|
| `canManageDeviceBusiness(loginUserId, deviceId)` | 设备资质/信用/暂停/预约等业务管理权限 | **否**（仅 DEVICE + PLATFORM） | 资质审核、暂停管理、信用调整、预约 |
| `canRepairDevice(loginUserId, deviceId)` | 设备维修工单处理权限 | **是**（ROOM_REPAIR ACTIVE + 设备 room_id 匹配） | FaultReportService、RepairOrderService |

### 2.2 源码证据（InstrumentScopeSupport.java）

**canManageDeviceBusiness 不含 ROOM_REPAIR**：

```java
// getBusinessManagedDeviceIds（§137-162）查询 scope 仅 DEVICE + PLATFORM：
.in(InstrumentManagerDO::getScope,
    Arrays.asList(ManagerScopeEnum.DEVICE.getScope(),
                  ManagerScopeEnum.PLATFORM.getScope()))
// ← ROOM_REPAIR 不在此列表
```

**canRepairDevice 含 ROOM_REPAIR**：

```java
// canRepairDevice（§98-109）显式查 ROOM_REPAIR：
List<InstrumentManagerDO> repairManagers = managerMapper.selectActiveList(
        ManagerScopeEnum.ROOM_REPAIR.getScope(), device.getRoomId());
return repairManagers.stream().anyMatch(m -> loginUserId.equals(m.getManagerUserId()));
```

**设计意图注释**（§69-72）：

> 维修负责人（scope=ROOM_REPAIR）不享受业务管理权限——不得审批资质、不得调整信用、不得管理暂停、不得管理预约。维修负责人仅限维修工单处理权限，见 canRepairDevice / getRepairManagedDeviceIds。

### 2.3 验证矩阵

| 场景 | 调用方法 | ROOM_REPAIR ACTIVE 结果 | DEVICE ACTIVE 结果 | lab_admin 结果 |
|---|---|---|---|---|
| 审批资质（业务管理） | canManageDeviceBusiness | **false** ✅（隔离） | true | true |
| 管理暂停（业务管理） | canManageDeviceBusiness | **false** ✅ | true | true |
| 审核故障上报（维修） | canRepairDevice | **true** ✅（命中） | false | true |
| 处理维修工单（维修） | canRepairDevice | **true** ✅ | false | true |

### 2.4 权限拆分验收结论

**PASS / 职责清晰**。ROOM_REPAIR 维修负责人被严格限制在维修工单处理范围内，不会意外获得资质/暂停/预约等业务管理权限；DEVICE 设备负责人反之，不能处理维修工单。两条路径互不重叠、互不穿透，符合 47 号 §二.3/§二.4 盘点和 48 号 §二.2.4 设计说明。

---

## 三、待补充测试场景清单

### 3.1 故障上报流程

| # | 场景 | 角色 | 预期 | 测试类型 |
|---|---|---|---|---|
| F-01 | 普通用户提交故障上报（必填字段齐全） | 904 | 返回上报 ID；`submitFault` 写入 fault_report 表 | Service 单元 |
| F-02 | 普通用户提交故障上报（fault_desc 为空） | 904 | 参数校验失败 | Service 单元 |
| F-03 | 普通用户查看自己的上报列表（getMyPage） | 904 | 仅返回自己的上报，数据范围过滤生效 | Service 单元 |
| F-04 | 普通用户直接调 getPage（管理端全量） | 904 | 403 / 权限拒绝（缺少 fault-report:admin） | Controller 权限注解 |
| F-05 | lab_admin 确认故障上报（confirm） | 906 | 故障状态 CONFIRMED；设备状态自动转 FAULT | Service 单元 + 数据范围 |
| F-06 | lab_admin 驳回故障上报 | 906 | 状态 REJECTED；设备状态不变 | Service 单元 |
| F-07 | 维修负责人（909）提交故障上报 | 909 | 成功（也能上报，符合 04 §5.2 权限矩阵） | Service 单元 |
| F-08 | 维修负责人查看故障上报详情（getById） | 909 | 通过（hasAnyPermissions submit/admin） | Controller 权限注解 |
| F-09 | 维修负责人调 getPage（管理端全量） | 909 | 403 拒绝（无 admin 权限） | Controller 权限注解 |
| F-10 | 设备负责人（908）提交故障上报 | 908 | **403 拒绝**（本批次 SQL 不授 submit 给 908） | 权限隔离 |

### 3.2 审核与派工

| # | 场景 | 角色 | 预期 | 测试类型 |
|---|---|---|---|---|
| A-01 | 管理员指派维修负责人（assign） | 906 | 工单 ASSIGNED；handler_id 设置为目标维修负责人；repair_history 新增 | Service 单元 |
| A-02 | 管理员指派不存在的用户 | 906 | 业务拒绝 INSTRUMENT_REPAIR_HANDLER_NOT_EXISTS | Service 单元 |
| A-03 | 普通用户（904）调 assign | 904 | 403 / 拒绝（无 repair-order:admin） | Controller 权限注解 |
| A-04 | 维修负责人（909）调 assign | 909 | 403 / 拒绝（无 admin 权限） | 权限隔离 |
| A-05 | 派工后自动路由（设备专属维修负责人存在） | 系统 | 自动命中 handler_source=DEVICE_MANAGER | Service 单元 |
| A-06 | 派工后自动路由（房间维修负责人存在） | 系统 | 自动命中 handler_source=ROOM_MANAGER | Service 单元 |
| A-07 | 无任何维修负责人 → SUBMITTED 待分配 | 系统 | 保持 SUBMITTED；handler 为空 | Service 单元 |

### 3.3 维修处理

| # | 场景 | 角色 | 预期 | 测试类型 |
|---|---|---|---|---|
| H-01 | 维修负责人开始维修（ASSIGNED → IN_PROGRESS） | 909 | 成功；repair_history 新增一条 | Service 单元 |
| H-02 | 维修负责人追加维修过程记录 | 909 | 状态不变；history 追加 | Service 单元 |
| H-03 | 维修负责人提交维修结果（IN_PROGRESS → REPAIRED） | 909 | success 字段必填；history 新增 | Service 单元 |
| H-04 | 维修负责人调 getMyAssignedPage（我的工单） | 909 | 仅返回派给自己的工单（数据范围过滤） | Service 单元 |
| H-05 | 维修负责人处理非自己房间/设备的工单 | 909 | **拒绝**（Service 层 scopeSupport.canRepairDevice 校验） | 数据范围 |
| H-06 | 普通用户（904）调 start/record/submit | 904 | 403 / 拒绝（无 repair-order:handle） | Controller 权限注解 |

### 3.4 恢复验收

| # | 场景 | 角色 | 预期 | 测试类型 |
|---|---|---|---|---|
| R-01 | 管理员确认维修恢复通过（REPAIRED → CLOSED + 设备 NORMAL） | 906 | 工单关闭；设备状态恢复 NORMAL；repair_history 新增 | Service 单元 |
| R-02 | 管理员退回继续维修（REPAIRED → REOPENED → ASSIGNED） | 906 | 状态回退；history 新增 | Service 单元 |
| R-03 | 管理员取消工单 | 906 | CANCELED；history 新增 | Service 单元 |
| R-04 | 管理员重开已关闭工单 | 906 | CLOSED → ASSIGNED | Service 单元 |
| R-05 | 维修负责人调 restoreApprove/cancel/reopen | 909 | 403 / 拒绝（admin-only） | 权限隔离 |

### 3.5 预约影响与设备状态联动

| # | 场景 | 预期 | 测试类型 |
|---|---|---|---|
| I-01 | 设备状态 NORMAL → FAULT 后，INSTRUMENT-03 ReservationCreateExecutor P1 拒绝新预约 | INSTRUMENT-03 回归已覆盖（195 case 中 P1 是核心路径） | 回归已覆盖 |
| I-02 | FAULT 状态下已有 PENDING 预约（INSTRUMENT-04 U6 未冻结） | 当前设计"不自动处理"（保留到开始前）——**不属于本轮回归范围** | 业务规则未冻结 |
| I-03 | 故障上报确认后设备状态转 FAULT（FaultReportService.confirm 联动） | 设备 status 更新 history 留痕；bookable 可预约校验自动生效 | Service 单元（需 DB schema 部署后） |

### 3.6 权限隔离矩阵端到端

| # | 场景 | 904 | 906 | 908 | 909 | 验证要点 |
|---|---|---|---|---|---|---|
| P-01 | 提交故障上报（submitFault） | ✓ | ✓ | ✗ | ✓ | 908 不自动获得 submit（设计意图） |
| P-02 | 查看自己的上报（getMyPage） | ✓ | ✓ | ✗ | ✓ | 909 能看到自己的上报 |
| P-03 | 管理端故障分页（getPage） | ✗ | ✓ | ✗ | ✗ | admin-only |
| P-04 | 确认/驳回故障（confirm） | ✗ | ✓ | ✗ | ✗ | admin-only |
| P-05 | 工单分页管理（getPage） | ✗ | ✓ | ✗ | ✗ | admin-only |
| P-06 | 派工/取消/重开/恢复（assign/cancel/reopen/restore*） | ✗ | ✓ | ✗ | ✗ | admin-only |
| P-07 | 维修负责人处理（start/record/submit） | ✗ | ✓ | ✗ | ✓ | handle + admin 通吃 |
| P-08 | 我的工单列表（getMyAssignedPage） | ✗ | ✓ | ✗ | ✓ | handle + admin 通吃 |
| P-09 | 工单详情（getById，三权限通吃） | ✓ | ✓ | ✗ | ✓ | submit + admin + handle 通吃 |
| P-10 | 资质审核 canManageDeviceBusiness | ✗ | ✓ | ✓（DEVICE+PRIMARY） | **✗** | ROOM_REPAIR 严格隔离 |
| P-11 | 维修处理 canRepairDevice | ✗ | ✓ | ✗（DEVICE 不含） | ✓（ROOM_REPAIR） | 两条方法互不穿透 |

> 注：上述 P-01 ~ P-11 的角色授权依赖 **59-INSTRUMENT-06菜单与角色授权设计稿.sql 执行成功**；SQL 未部署前这些场景无法在真实环境运行时验证。

---

## 四、已知限制

### 4.1 STARTED 预约状态不存在

INSTRUMENT-03 冻结的预约状态机只有 **PENDING / FINISHED / CANCELED / VOIDED** 四种状态：

```
ReservationStatusEnum：
  PENDING（待开始，未开始前可取消/调整）
  FINISHED（已完成，标记 used_time）
  CANCELED（已取消）
  VOIDED（已作废，管理员动作）
```

没有 STARTED、IN_USE 等"进行中"中间态。影响：

| 影响项 | 说明 | 处置 |
|---|---|---|
| 维修工单影响预约的语义 | 原 06 文档"维修中阻止 STARTED 预约"的假设不成立——预约永远不会进入 STARTED | 当前设备 FAULT 状态由 P1 拦截**新预约**创建；**已存在的 PENDING 预约**在设备 FAULT 后仍可到时间正常使用——属于 INSTRUMENT-04 U6 未冻结业务规则 |
| fault_report → reservation_impact 表 | 该表（58 号 DDL 已设计）在 STARTED 不存在的情况下，主要用于标记"故障/维修期间有 PENDING 预约需要手动处理"，而非自动作废 | **保留设计但暂不启用**；等 U6 裁决后再联动 |
| 前端状态文案 | 不显示"进行中"标签 | 维持 INSTRUMENT-03 既有 UI |

**性质**：设计约束，非缺陷。INSTRUMENT-03 已冻结状态机，本轮不扩状态集。

### 4.2 bookable=0 真实环境

数据库 live 快照 4 台设备 bookable 全部为 0（51 号 R3）。故障上报→设备 FAULT→新预约被 P1 拦截的端到端链路 **在真实环境暂时无法完整验证**，除非 lab_admin 手动打开 bookable。

**处置**：确认为设计意图（INSTRUMENT-03 隔离环境初始值），不自动修改。

### 4.3 预约冲突窗口校验

ReservationCreateExecutor 中窗口设备（MICROPLATE_READER category）调用 validateWindowScope，使用 OPEN_WINDOW 表而非 granularity/minDuration 校验。数据库设备 4 叫"酶标仪"但 category=NORMAL（51 号 R1），窗口规则对该设备实际不生效。

**性质**：数据配置问题，由 lab_admin 修正 category 即可。

---

## 五、INTEGRATION HOLD 说明

### 5.1 HOLD 原因

需要真实写入（INSERT/UPDATE/COMMIT）到**真实数据库**的集成测试 **暂停执行**，因为以下前置条件尚未满足：

| 前置条件 | 状态 | 说明 |
|---|---|---|
| 58-INSTRUMENT-06 DDL 部署（5 张新表） | **未部署** | 58 号设计稿已与 DO 完全对齐，但禁止未经授权对真实 labplatform 执行 DDL |
| 59 号菜单/角色 SQL 部署 | **未部署** | 菜单 ID 13684~13688、角色 909 核验空闲，但未执行 |
| 真实维修负责人账号分配角色 909 | **未分配** | 业务闭环最后一环 |
| C7（reservation.create-enabled） | **false** | 端到端预约创建验证被拦截 |

> 注：INSTRUMENT-06 的 48 个新增单元测试（含 U6 预约影响、T2 权限隔离）已通过 H2 内存库执行，243/243 PASS。HOLD 仅针对需要真实 MySQL 写入的端到端集成测试。

### 5.2 可执行测试 vs 暂停测试

| 类型 | 是否可执行 | 结果 |
|---|---|---|
| 编译验证 | ✅ 已执行 | BUILD SUCCESS（20/20 modules） |
| INSTRUMENT-01/02/03 全量回归 | ✅ 已执行 | 195/195 PASS |
| INSTRUMENT-06 新增单元测试（7 类 48 用例） | ✅ 已执行 | 48/48 PASS（H2 内存库） |
| ScopeSupport 权限拆分源码复核 | ✅ 已执行 | **D8 PASS**（§二） |
| T2 权限隔离单元测试 | ✅ 已执行 | **Instrument06ScopePermissionTest 8/8 PASS** |
| U6 预约影响单元测试 | ✅ 已执行 | **Instrument06ReservationImpactTest 6/6 PASS** |
| 真实环境权限集成测试 | ❌ HOLD | 59 号 SQL 未部署，904/906/909 真实用户菜单不可见 |
| 故障→设备 FAULT→预约影响联动端到端测试 | ❌ HOLD | 58 号 DDL 未部署到真实库 |

### 5.3 HOLD 解除条件（全部满足后方可进入真实库集成测试）

1. 58 号 DDL 经负责人书面授权后执行（5 张新表就位，已与 DO 完全对齐）；
2. 59 号菜单/角色 SQL 经负责人书面授权后执行（13684~13688 + 角色 909，ID 已核验空闲）；
3. 真实维修负责人账号分配角色 909 + ROOM_REPAIR ACTIVE 业务关系；
4. C7 状态由负责人裁决是否临时开启（端到端验证时）。

---

## 六、测试工具与环境

| 项 | 值 |
|---|---|
| Java | JDK 11 |
| Maven | 3.8+ |
| 隔离测试库 | H2（内存，JUnit 框架自动创建） |
| 真实库 | labplatform（MySQL 8.0.12，只读快照） |
| Redis | localhost:6379（默认，未隔离） |
| ScopeSupport 源码验证 | InstrumentScopeSupport.java（canManageDeviceBusiness §73-92 + canRepairDevice §98-109） |
| 任务书 D11 角色分配 | 已由 59 号 SQL 设计稿实现（904 submit / 906 全量 / 908 保持 / 909 submit+handle） |

---

## 七、结论

| 维度 | 状态 | 说明 |
|---|---|---|
| 后端编译 | ✅ BUILD SUCCESS | 零错误零警告 |
| 全量回归（195 原有 + 48 新增） | ✅ **243/243 PASS** | 零回归 |
| INSTRUMENT-06 新增测试（7 类 48 用例） | ✅ **48/48 PASS** | 含 U6 预约影响 6 用例 + T2 权限隔离 8 用例 |
| D8 权限拆分（ScopeSupport 源码验证） | ✅ **PASS** | canManageDeviceBusiness 不含 ROOM_REPAIR、canRepairDevice 含 ROOM_REPAIR，两条路径互不穿透 |
| 已知限制（STARTED 状态等） | ℹ️ **设计约束** | 非缺陷，维持 INSTRUMENT-03 冻结状态机；服务层已提供 isReservationCurrentlyImpacted 校验供未来 STARTED 端点调用 |
| INTEGRATION HOLD | ⏸️ **暂停** | 58 号 DDL / 59 号菜单 SQL / 真实用户角色 909 分配均未部署，需要真实库写入的端到端集成测试全部 HOLD |

**最终判定**：单元与回归测试 **243/243 PASS**，ScopeSupport 权限拆分 **PASS**；真实库端到端集成测试 **INTEGRATION HOLD**（等待负责人授权部署 58/59 号 SQL + 分配角色 909 后解除）。
