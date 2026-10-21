# 48-INSTRUMENT-04 仪器维修与日常管理实施报告

> 编制日期：2026-10-20
> 编制依据：INSTRUMENT-04 代码修复 + 数据库 live 快照 + INSTRUMENT-01/02/03 已有验收
> 修复范围：资质重复 ACTIVE（P0）、维修负责人数据范围（P1）、设备状态变更权限范围（设计意图确认）
> 本轮修复后编译：BUILD SUCCESS（20/20 modules）
> 回归测试：195/195 PASS，零回归

---

## 一、本轮开始时已完成的功能（INSTRUMENT-01/02/03 覆盖）

### 1.1 日常管理闭环（已具备）

| 角色 | 已具备能力 | 标记 |
|---|---|---|
| 本草基因管理员（lab_admin） | 创建实验室/房间 → 创建仪器档案 → 配置预约规则 → 指定设备负责人 → 指定维修负责人 → 审批资质 → 管理信用和暂停 → 管理预约 | **DONE** |
| 普通用户 | 查询设备 → 查看详情 → 申请资质 → 查询资质状态 → 查看信用 → 查询暂停 → 查/调/取消本人预约 | **DONE** |
| 设备负责人 | 设备范围授权 → 资质审批 → 预约管理 → 设备查询 | **DONE** |
| 维修负责人（ROOM_REPAIR） | 被分配到房间（多人 ACTIVE） → 无实际数据范围权限（47 号 PARTIAL，本轮修复） | **PARTIAL→DONE** |
| 库管员 | 仪器权限与质粒权限正确隔离 | **DONE** |

### 1.2 故障与维修闭环（未实现）

| 功能 | 标记 | 说明 |
|---|---|---|
| 故障登记 | **MISSING** | 无 Controller/Service/前端入口；InstrumentMaintenanceDO 注释 "source_type=REPAIR 为 INSTRUMENT-06 预留" |
| 维修任务创建/处理/完成 | **MISSING** | 同上 |
| 故障原因/上报人/上报时间 | **MISSING** | DeviceStatusReqVO 只有 id+targetStatus，无 reason/reporter |
| 维修后设备恢复 NORMAL | **PARTIAL** | 管理员可手动改状态，但无恢复确认人权限矩阵 |

---

## 二、本轮新增/修改的功能

### 2.1 T1 修复：资质重复 ACTIVE 防护（P0）

#### 2.1.1 问题描述

InstrumentQualificationServiceImpl.auditApply 的 approve 分支原代码直接：

```java
qualificationMapper.insert(qualification); // INSERT 新 ACTIVE 行
```

不检查该用户对该设备是否已有 SUSPENDED 旧资质。导致：
- 用户被暂停（资质 SUSPENDED）→ 再次申请 → 审批通过 → **同用户同设备两条资质（SUSPENDED + 新 ACTIVE）**
- ReservationCreateExecutor P4 selectActive 查 ACTIVE 资质时可能返回多条（selectActive 有 `last("LIMIT 1")`，取第一条，但返回非唯一结果本身是数据一致性破坏）
- 暂停覆盖期间新 INSERT 的 ACTIVE 会被预约 P5 拦截（"该用户在此设备上有 ACTIVE 暂停覆盖"），但数据层面仍保留了不该存在的 ACTIVE 行

#### 2.1.2 修复方案

**涉及文件**：
- `InstrumentQualificationMapper.java`（新增 1 个方法）
- `InstrumentQualificationServiceImpl.java`（approve 分支重写 + 新增 suspendMapper 注入 + 新增 1 个私有辅助方法）

**修复逻辑**（auditApply approve 分支，`FOR UPDATE` 行锁内）：

1. 查该用户对该设备的**全部**资质（含所有状态）：`qualificationMapper.selectAllByUserAndTarget(userId, deviceId)`
2. 双保险：如果存在 ACTIVE 旧资质 → 拒绝（理论上申请防重已拦截，但行锁内再查一次防并发交错）
3. 如果存在 SUSPENDED 旧资质：
   - 查暂停覆盖：`suspendMapper.selectActiveCovering(userId, deviceId)`
   - **无覆盖** → 条件恢复旧资质（updateResumeIfSuspended，affectedRows=1 则成功），**不 INSERT 新行**
   - **有覆盖** → 旧资质保持 SUSPENDED，不 INSERT 新行（暂停覆盖 G13 继续生效）
4. 如果旧资质全是 REVOKED/EXPIRED 或完全没有 → 正常 INSERT 新 ACTIVE 行

**并发防护**：条件恢复 `updateResumeIfSuspended` 带 `WHERE status='SUSPENDED'` 条件，affectedRows=0 时降级为 INSERT 新行（幂等，此时旧资质已不是 SUSPENDED 状态）。

#### 2.1.3 修复后行为矩阵

| 场景 | 修复前 | 修复后 |
|---|---|---|
| 用户 SUSPENDED 旧资质 + 无 ACTIVE 暂停覆盖 | INSERT 新行 → 两条资质 | 条件恢复旧行 SUSPENDED→ACTIVE |
| 用户 SUSPENDED 旧资质 + 有 ACTIVE 暂停覆盖 | INSERT 新行 → 新 ACTIVE 被 P5 拦截但数据脏 | 不 INSERT，保持 SUSPENDED（暂停覆盖继续） |
| 用户 REVOKED 旧资质 | INSERT 新行 ✅ | INSERT 新行 ✅ |
| 用户 EXPIRED 旧资质 | INSERT 新行 ✅ | INSERT 新行 ✅ |
| 无旧资质 | INSERT 新行 ✅ | INSERT 新行 ✅ |
| ACTIVE 旧资质（并发） | 可能 INSERT 新行 → 两条 ACTIVE | 拒绝，抛 INSTRUMENT_QUALIFICATION_ALREADY_ACTIVE |

---

### 2.2 T2 修复：维修负责人数据范围（P1）

#### 2.2.1 问题描述

InstrumentScopeSupport 原 `getManagedDeviceIds` 和 `canManageDevice` 只处理 DEVICE 和 PLATFORM scope，不处理 ROOM_REPAIR：

```java
// getManagedDeviceIds 原代码
.in(InstrumentManagerDO::getScope,
    Arrays.asList(ManagerScopeEnum.DEVICE.getScope(),
                  ManagerScopeEnum.PLATFORM.getScope()))
// ← ROOM_REPAIR 不在列表中！
```

ManagerScopeEnum.ROOM_REPAIR 枚举存在（值 `"ROOM_REPAIR"`），InstrumentManagerServiceImpl.doAssign 支持分配，数据库已有 3 条 ROOM_REPAIR+REPAIR 记录（ACTIVE×2, RELEASED×1，target_id=room_id=1），但 ScopeSupport 不处理 → 维修负责人被分配后看不到任何设备。

#### 2.2.2 修复方案

**涉及文件**：
- `InstrumentScopeSupport.java`（新增 roomMapper 注入 + canManageDevice 加 ROOM_REPAIR 分支 + getManagedDeviceIds 加 ROOM_REPAIR 分支）

**修复逻辑**：

1. `canManageDevice`：新增 `if (device.getRoomId() != null)` → 查 `managerMapper.selectActiveList(ROOM_REPAIR, roomId)` → 检查当前用户是否在其中
2. `getManagedDeviceIds`：查询 scope 列表加入 ROOM_REPAIR → 新增 roomIds 收集 → 查 `deviceMapper.selectList` WHERE room_id IN (roomIds) → 收集 deviceIds

#### 2.2.3 修复后效果

| 场景 | 修复前 | 修复后 |
|---|---|---|
| ROOM_REPAIR+REPAIR+ACTIVE 用户查资质/暂停页面 | 数据范围过滤返回空 | 返回房间内全部设备的资质/暂停记录 |
| ROOM_REPAIR+REPAIR+ACTIVE 用户审核自己负责设备的资质 | canManageDevice 返回 false → 无权限 | canManageDevice 返回 true → 可审核 |
| 暂停查询 getSuspendPage（数据范围） | managedDeviceIds 不含 ROOM_REPAIR 设备 | 正确返回负责房间内设备的暂停 |

#### 2.2.4 设计说明

维修负责人的数据范围修复后，维修负责人可以审核自己负责房间内设备的资质、查看暂停等（通过 service 层数据范围）。但**不修复**"维修负责人修改设备状态"权限——当前 lab:instrument:device:manage 功能权限只给 lab_admin 和 super_admin，维修负责人角色未授权该功能权限，这是任务书允许的权限边界。

---

### 2.3 T3 设备状态变更操作历史（放弃）

**放弃原因**：本轮禁止 DDL（任务书 §二 禁止项："对真实 labplatform 执行未经单独授权的 DDL"）。设备状态变更操作历史需要新建 `InstrumentDeviceStatusHistoryDO` + Mapper + INSERT 调用，属于需要 DDL 的改动。

**临时处置**：updateDeviceStatus 方法内嵌了 `InstrumentDeviceDO.updater / update_time` 自动字段（框架 @TableField(fill=...)），可通过 DO 自身字段追踪最后修改人/时间，但无法保留完整历史。

**后续建议**：如需设备状态变更审计完整历史，需要单独批次批准 DDL。

### 2.4 T4 设备状态变更权限范围（确认无需修复）

**原担心**：updateDeviceStatus 无 scopeSupport.validateManageDevice 调用 → 任何 lab_admin 可改任何设备状态。

**实际验证**：lab_admin 和 super_admin 设计上就是管全部设备（canManageAll 返回 true），无需额外数据范围校验。设备负责人（DEVICE+PRIMARY ACTIVE）没有 lab:instrument:device:manage 功能权限（Controller 层 @PreAuthorize 已拦截），因此不可能调用 updateDeviceStatus。

**结论**：设计意图，非 BUG。

### 2.5 T5 bookable=0 确认

数据库 live 快照（2026-10-20）：4 台设备 bookable 字段全为 0。确认为 INSTRUMENT-03 隔离环境初始配置意图（INSTRUMENT-03 测试时临时开启），真实环境由 lab_admin 手动配置。本轮不自动修改。

---

## 三、本轮前后端文件修改清单

### 3.1 修改文件

| 文件 | 修改类型 | 改动内容 |
|---|---|---|
| `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/mysql/instrument/InstrumentQualificationMapper.java` | **追加方法** | 新增 `selectAllByUserAndTarget(Long userId, Long deviceId)` — 查某用户某设备的**全部**资质（含所有状态） |
| `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentQualificationServiceImpl.java` | **重写 approve 分支** + **新增注入** + **新增辅助方法** | 1) 新增 `suspendMapper` 注入；2) approve 分支从"直接 INSERT"改为"查旧资质→按 SUSPENDED/ACTIVE 旧资质状态决策恢复或拒绝"；3) 新增 `insertNewQualification` 私有方法 |
| `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentScopeSupport.java` | **新增注入** + **追加分支** | 1) 新增 `InstrumentRoomMapper` import；2) 新增 `roomMapper` 注入；3) `canManageDevice` 追加 ROOM_REPAIR 分支；4) `getManagedDeviceIds` 查询 scope 加入 ROOM_REPAIR + 追加 roomIds → deviceIds 映射 |

### 3.2 未修改文件

- 前端：无改动（本轮修复均为后端数据范围和业务逻辑，不涉及页面/API 签名变更）
- 数据库：无 DDL/DML（禁止）
- DO / VO / Controller：无改动

### 3.3 编译验证

```
mvn clean compile -pl yudao-module-lab -am
[INFO] BUILD SUCCESS
[INFO] yudao-module-lab ........................ SUCCESS [  5.124 s]
[INFO] Total time:  43.651 s
```

### 3.4 回归测试

```
mvn test -pl yudao-module-lab
[INFO] Tests run: 195, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

覆盖 INSTRUMENT-03 全部测试文件（9 个 Test 类），零回归。

---

## 四、维修工单模块状态

### 4.1 当前实现现状

| 层次 | 是否存在 | 说明 |
|---|---|---|
| DO | ✅ | InstrumentMaintenanceDO（instrument_maintenance 表），含 source_type（MANUAL/PLAN/REPAIR）、status（ACTIVE/CANCELED）、maintenance_type、start_time、end_time、result、cause、operator_id/operator_name 等字段 |
| Mapper | ✅ | InstrumentMaintenanceMapper |
| Service | ❌ | 无 InstrumentMaintenanceService |
| Controller | ❌ | 无 InstrumentMaintenanceController |
| 枚举 | ✅ | MaintenanceStatusEnum / MaintenanceSourceEnum / MaintenanceTypeEnum |
| 前端 | ❌ | 无 maintenance 目录 |
| 数据库 | ❌ | 0 行记录（live 快照） |

InstrumentMaintenanceDO 注释明确："source_type=REPAIR 为 INSTRUMENT-06 预留"。维修工单属于未冻结业务规则范围（维修负责人自动派单、谁可以确认恢复使用等均未裁决），本轮不开发。

### 4.2 故障登记入口

当前唯一"故障登记"方式 = 管理员改设备状态为 FAULT。DeviceStatusReqVO 只有 id+targetStatus，无 reason/reporter 字段——状态变更无上下文记录（47 号 PARTIAL）。普通用户故障上报入口（U5/U7）未冻结，不自行开发。

### 4.3 设备恢复 NORMAL 路径

当前合法路径：
1. lab_admin 或 super_admin（有 lab:instrument:device:manage 权限）→ 调用 updateDeviceStatus(id, 'NORMAL')
2. DeviceStatusEnum.canTransitTo 校验：MAINTENANCE / FAULT / DISABLED 均可直接转 NORMAL

**无独立"维修负责人恢复设备"入口**——维修负责人角色无 lab:instrument:device:manage 功能权限。是否赋予维修负责人恢复设备权限属于未冻结业务规则（BLOCKED）。

---

## 五、日常管理角色权限矩阵（修复后）

| 角色 | 可操作设备范围 | 资质审批 | 暂停管理 | 信用调整 | 设备状态变更 | 预约管理 |
|---|---|---|---|---|---|---|
| super_admin | 全部（canManageAll） | ✅ 全部 | ✅ 全部 | ✅ 全部 | ✅ 全部 | ✅ 全部 |
| lab_admin | 全部（canManageAll） | ✅ 全部 | ✅ 全部 | ✅ 全部 | ✅ 全部 | ✅ 全部 |
| 设备负责人（DEVICE+PRIMARY ACTIVE） | 分配的设备 | ✅ 负责设备 | ✅ 负责设备 | ✅ 负责设备 | ❌（无功能权限） | ✅ 负责设备 |
| 平台负责人（PLATFORM ACTIVE） | 平台下全部设备 | ✅ 平台设备 | ✅ 平台设备 | ✅ 平台设备 | ❌（无功能权限） | ✅ 平台设备 |
| 维修负责人（ROOM_REPAIR ACTIVE） | **负责房间下全部设备（本轮修复）** | ✅ 房间设备（本轮修复） | ✅ 房间设备（本轮修复） | ❌（功能权限未授权） | ❌（无功能权限） | ❌（功能权限未授权） |
| 库管员 | 无（仪器功能权限未授权） | ❌ | ❌ | ❌ | ❌ | ❌ |
| 普通用户 | 本人资质/暂停/预约 | ❌ | 仅本人查询 | 仅本人查询 | ❌ | 仅本人 |

---

## 六、C7 状态

本轮无 C7 操作。C7 最终状态：**false**（INSTRUMENT-03 验证时曾开启，已回退）。

---

## 七、交付状态

| 项目 | 状态 |
|---|---|
| 修复 T1 资质重复 ACTIVE（P0） | ✅ DONE |
| 修复 T2 维修负责人数据范围（P1） | ✅ DONE |
| T3 设备状态变更历史（禁止 DDL） | ❌ SKIP（报告中说明） |
| T4 设备状态变更权限范围 | ✅ 确认设计意图，无需改动 |
| T5 bookable=0 确认 | ✅ DONE（信息） |
| 编译通过 | ✅ BUILD SUCCESS |
| 回归测试 | ✅ 195/195 PASS |
| 维修工单模块 | ❌ BLOCKED（未冻结业务规则） |
| 故障登记入口 | ❌ BLOCKED（未冻结业务规则） |
| 设备状态变更历史 | ❌ BLOCKED（禁止 DDL） |
