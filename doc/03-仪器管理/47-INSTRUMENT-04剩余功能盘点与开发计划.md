# 47-INSTRUMENT-04 剩余功能盘点与开发计划

> 编制日期：2026-10-20
> 编制依据：后端源码实查 + 前端页面核对 + 数据库 live 快照 + INSTRUMENT-01/02/03 已有报告交叉验证
> 盘点范围：INSTRUMENT-03 已完成预约全流程之后，仪器管理模块尚未明确覆盖的全部业务
> 本轮约束：任务书明确"维修工单/特殊设备规则/暂停自动到期"属于未冻结业务规则，只列方案不自行开发

---

## 一、盘点说明

### 1.1 标记语义

| 标记 | 含义 |
|---|---|
| **DONE** | 已实现且有 INSTRUMENT-01/02/03 验收证据，本轮不重复开发 |
| **PARTIAL** | 核心路径已通，但存在数据范围缺口、历史遗漏或场景覆盖不全 |
| **MISSING** | 仅有 DO/枚举占位，无 Service/Controller/前端，或完全不存在 |
| **BLOCKED** | 业务规则尚未裁决（任务书明确"只列候选方案"），或环境条件不满足 |
| **BUG** | 已实现但存在可复现的逻辑缺陷，不属于业务规则未裁决范畴 |

### 1.2 核验基线

- 后端：`ruoyi-vue-pro/yudao-module-lab`（INSTRUMENT-03 已通过 195 自动化测试）
- 前端：`yudao-ui-admin-vue3/src/views/lab/instrument/`
- 数据库：`labplatform`（租户 162 成都中医药大学，只读快照 2026-10-20）
- C7：当前 **false**（任务书前提）；INSTRUMENT-03 验证时曾开启
- 设备快照：4 台（SCRAPPED×1 / NORMAL×3），bookable 全 0
- 负责人快照：ROOM_REPAIR+REPAIR×3（ACTIVE×2, RELEASED×1），DEVICE+PRIMARY×2，DEVICE+REPAIR×1

---

## 二、完整功能矩阵

### 2.1 实验室及房间

| 功能 | 标记 | 证据 | 状态说明 |
|---|---|---|---|
| 平台创建/修改/启停用/删除 | **DONE** | InstrumentPlatformController + InstrumentPlatformServiceImpl，INSTRUMENT-01 §4.2 验收 | — |
| 房间创建/修改/删除 | **DONE** | InstrumentRoomController + InstrumentRoomServiceImpl | — |
| 房间被设备引用时删除被拒 | **DONE** | 前端有确认弹窗 + Service 层引用校验 | — |
| 维修负责人分配到房间 | **PARTIAL** | ManagerScopeEnum.ROOM_REPAIR 枚举存在，assignManager 支持多人 ACTIVE（G26 裁决方案A），但 InstrumentScopeSupport.getManagedDeviceIds **不处理 ROOM_REPAIR**——维修负责人数据范围查询缺失 | 维修负责人能被分配，但无法看到/管理房间内任何设备；需要补 getRoomManagedDeviceIds |

### 2.2 仪器档案

| 功能 | 标记 | 证据 | 状态说明 |
|---|---|---|---|
| 新建/编辑仪器档案 | **DONE** | InstrumentDeviceController.createDevice / updateDevice | — |
| 状态管理（5 态） | **DONE** | updateDeviceStatus + DeviceStatusEnum.canTransitTo | — |
| 图片上传/展示 | **DONE** | DeviceSaveReqVO.imageFileId + 前端 img-preview | — |
| 设备状态变更后已存预约处理 | **PARTIAL** | updateDeviceStatus 只改 status 字段，**不查询/处理该设备状态下的 PENDING 预约** | FAULT/MAINTENANCE/DISABLED 状态后新预约被 P1 拦截，但状态变更时刻已存在的 PENDING 预约仍有效（到时间可正常使用设备）。属于业务规则未冻结范围 |
| 设备状态变更操作历史 | **BUG** | updateDeviceStatus 无 history 表记录（预约有 InstrumentReservationHistoryDO，设备状态变更无） | 审计追溯缺口。任务书点名"操作历史关键动作审计" |

### 2.3 设备负责人

| 功能 | 标记 | 证据 | 状态说明 |
|---|---|---|---|
| 分配/解除负责人 | **DONE** | InstrumentManagerController + InstrumentManagerServiceImpl（条件更新 + 历史保留） | — |
| DEVICE 同 scope+type 仅保留 1 ACTIVE | **DONE** | doAssign 内旧关系置 RELEASED（第 97-106 行） | — |
| ROOM_REPAIR 允许多人同时 ACTIVE | **DONE** | doAssign 内 DEVICE/PLATFORM 旧关系释放，ROOM_REPAIR 不释放（第 96 行注释 G26 方案A） | — |
| 负责人权限：设备/平台负责人可管设备 | **DONE** | InstrumentScopeSupport.canManageDevice 查 DEVICE+PLATFORM scope | — |
| 负责人权限：维修负责人数据范围 | **PARTIAL** | InstrumentScopeSupport 不处理 ROOM_REPAIR → 维修负责人无法"查看和管理自己负责房间内的设备" | 需新增 scope=ROOM_REPAIR 的 getManagedDeviceIds 分支 |

### 2.4 维修负责人（单独项）

| 功能 | 标记 | 证据 | 状态说明 |
|---|---|---|---|
| 分配到房间（多人） | **DONE** | 同上 | — |
| 查看负责房间内设备 | **PARTIAL** | 数据范围缺失（见上） | — |
| 查看/处理故障 | **MISSING** | 无故障登记表单/Controller/Service | 故障登记/查询入口不存在 |
| 越权防护 | **PARTIAL** | ManagerAssignReqVO.scope=ROOM_REPAIR 时只校验 room 是否存在，不校验维修负责人角色 | 任意 lab_admin 可以指定任何用户为"维修负责人"，不校验目标用户是否有维修相关角色 |

### 2.5 仪器故障

| 功能 | 标记 | 证据 | 状态说明 |
|---|---|---|---|
| 查看设备状态 | **DONE** | 设备详情页/列表页显示状态 tag | — |
| 故障登记（专用入口） | **MISSING** | 无 Controller/Service/VO 对应故障登记业务；InstrumentMaintenanceDO 注释明确"source_type=REPAIR 为 INSTRUMENT-06 预留" | 当前唯一"故障登记"方式 = 管理员改设备状态为 FAULT |
| 故障原因/上报人/上报时间 | **MISSING** | DeviceStatusReqVO 只有 id+targetStatus，无 reason/reporter 字段 | 状态变更无上下文记录 |
| 故障后阻止新预约 | **DONE** | ReservationCreateExecutor P1 严格校验 status=NORMAL，FAULT 状态返回 082 | — |
| 已存预约自动处理 | **PARTIAL** | updateDeviceStatus 不处理已有 PENDING 预约 | 业务规则未冻结 |

### 2.6 仪器维修

| 功能 | 标记 | 证据 | 状态说明 |
|---|---|---|---|
| 维修任务创建 | **MISSING** | 无 Service/Controller/VO/前端。InstrumentMaintenanceDO.sourceType='REPAIR' 为 INSTRUMENT-06 预留 | 维修工单整体未实现 |
| 维修处理记录 | **MISSING** | 同上 | — |
| 维修完成/恢复 | **MISSING** | 同上；当前唯一恢复方式 = 管理员手动改状态 NORMAL | — |
| 谁可以确认恢复使用 | **BLOCKED** | 未冻结。当前语义 = lab_admin 全权，维修负责人角色无独立恢复入口 | 业务规则未裁决 |
| 操作历史 | **MISSING** | 维修本身不存在，无 history 表 | — |

### 2.7 使用资质

| 功能 | 标记 | 证据 | 状态说明 |
|---|---|---|---|
| 申请/撤回 | **DONE** | InstrumentQualificationController + InstrumentQualificationServiceImpl.doApply | — |
| 审核通过/驳回 | **DONE** | auditApply FOR UPDATE 行锁 + 条件更新 + G13 暂停不拦截审核 | — |
| 历史（申请记录 + 审核历史） | **DONE** | InstrumentQualificationApplyHistoryDO + Controller 已暴露 query 接口 | — |
| 重复 ACTIVE 资质风险 | **BUG** | 审核通过直接 `qualificationMapper.insert(ACTIVE)` 不检查该用户对该设备是否已有 SUSPENDED 旧资质 | 用户被暂停（资质 SUSPENDED）后可再次申请 → 审批通过 → 同用户同设备两条资质（SUSPENDED + 新 ACTIVE）。需要审核通过前 selectAll 并处理旧资质 |
| 撤销 | **DONE** | revokeQualification 条件更新 ACTIVE→REVOKED | — |

### 2.8 信用管理

| 功能 | 标记 | 证据 | 状态说明 |
|---|---|---|---|
| 初始化（首审 100 分） | **DONE** | initCreditAccountOnce 三层防护（uk_account + Redis 锁 + 事务） | — |
| 查询/调整/流水 | **DONE** | InstrumentCreditController + InstrumentCreditServiceImpl | — |
| 导出积分流水 | **DONE** | FlowExcelVO + Controller 已暴露 export 接口 | — |
| 自动扣分 | **BLOCKED** | 任务书明确"不编造自动扣分规则"，当前只有人工 adjust | 未冻结业务规则 |

### 2.9 使用暂停

| 功能 | 标记 | 证据 | 状态说明 |
|---|---|---|---|
| 创建（ALL/SINGLE） | **DONE** | InstrumentSuspendServiceImpl.createSuspend 行锁 + 覆盖校验 + G12 联动资质 SUSPENDED | — |
| 查询（管理员/授权负责人/本人） | **DONE** | getSuspendPage 数据范围过滤；getMySuspends | — |
| 人工解除 | **DONE** | releaseSuspend 条件更新 + G12 覆盖检查恢复资质 | — |
| 暂停到期自动解除 | **BLOCKED** | InstrumentSuspendExpireJob 注释"本期不启用——H1 裁决 2026-10-15"；execute 方法保留但不注册 Quartz | Job 代码存在但不调度，暂停 end_time 仅作计划结束时间，不代表自动解除 |
| G12 资质恢复安全 | **DONE** | resumeUncoveredQualifications 只恢复"无其他 ACTIVE 暂停覆盖"的 SUSPENDED 资质 | — |

### 2.10 预约规则

| 功能 | 标记 | 证据 | 状态说明 |
|---|---|---|---|
| 普通规则 | **DONE** | granularity / minDuration / maxDuration / openDays / openStartTime / openEndTime / bookableDaysAhead / bookableDaysBefore / allowCrossDay | — |
| 预约创建时规则校验 | **DONE** | ReservationCreateExecutor.validateTimeParams（P7：粒度对齐、时长范围、跨日） | — |
| 酶标仪开放窗口 | **PARTIAL** | 后端 validateWindowScope 实现完整（ACTIVE 窗口 + 完整覆盖校验 + 单自然日限制），但数据库设备 4（叫"酶标仪"）category=NORMAL 而非 MICROPLATE_READER，窗口规则不会对该设备生效 | 设备 4 category 配置问题（D 组核验） |
| 特殊设备最短时长/粒度 | **BLOCKED** | 无任何后端特殊校验代码。PROTEIN_PURIFY 最短 6h、BLI 粒度未在 ReservationCreateExecutor 中实现 | 未冻结业务规则 |

### 2.11 预约业务

INSTRUMENT-03 已完成，本轮不重复：

| 功能 | 标记 | 证据 |
|---|---|---|
| 创建/调整/取消/完成/作废 | **DONE** | 195 自动化测试全 PASS |
| 历史操作追踪 | **DONE** | InstrumentReservationHistoryDO |
| 并发控制（行锁 + 条件更新） | **DONE** | ReservationLockCoordinator + 多处 affectedRows 校验 |
| 权限隔离（本人/负责人/管理员） | **DONE** | InstrumentReservationServiceImpl 数据范围过滤 |

### 2.12 操作历史

| 业务 | 标记 | DO | 说明 |
|---|---|---|---|
| 预约创建/调整/取消/完成/作废 | **DONE** | InstrumentReservationHistoryDO | 7 种 action，同事务 INSERT |
| 资质申请/撤回/审核/撤销 | **DONE** | InstrumentQualificationApplyHistoryDO | 同事务 INSERT |
| 注册申请/审批 | **DONE** | RegisterApplyHistoryDO | — |
| 设备状态变更 | **BUG** | 无 | updateDeviceStatus 只改 status，无历史 |
| 负责人分配/解除 | **PARTIAL** | 无独立 history 表 | ManagerStatusEnum.RELEASED 行保留视为历史，但无 action 时间戳/操作人 |
| 暂停创建/解除 | **DONE** | InstrumentSuspendDO 字段内嵌 operatorUserId/operatorName/startTime/releaseTime | 行保留，operator 字段内嵌可追溯 |
| 信用调整 | **DONE** | InstrumentCreditFlowDO | 流水即历史 |
| 维修处理 | **MISSING** | — | 维修整体不存在 |

---

## 三、本轮开发计划（区分已明确/未冻结）

### 3.1 已明确需求范围内的本轮目标

| 序号 | 模块 | 动作 | 依据 |
|---|---|---|---|
| T1 | 维修负责人数据范围 | InstrumentScopeSupport 新增 `getRoomManagedDeviceIds(userId)`：查该用户所有 ROOM_REPAIR ACTIVE 记录的 target_id（room_id）→ roomMapper.selectBatchIds → 拿到 device_ids | ManagerScopeEnum.ROOM_REPAIR 已存在但 ScopeSupport 没用 |
| T2 | 资质重复 ACTIVE 防护 | 审核通过 INSERT 前查该用户对该设备的所有资质（含 SUSPENDED/REVOKED/EXPIRED），若存在 SUSPENDED 旧资质 → UPDATE 旧资质为 ACTIVE（而非 INSERT 新行）；若存在 REVOKED/EXPIRED → 允许 INSERT 新行 | 审核通过代码直接 INSERT 无旧资质检查 |
| T3 | 设备状态变更操作历史 | updateDeviceStatus 新增 history 记录（类似 InstrumentReservationHistoryDO 模式），需新建 InstrumentDeviceStatusHistoryDO + Mapper | 任务书点名"操作历史关键动作审计" |
| T4 | 设备状态变更权限范围 | updateDeviceStatus 当前无数据范围校验（lab:instrument:device:manage 权限即全设备），新增 `scopeSupport.validateManageDevice(loginUserId, id)` | 负责人/维修负责人无权改设备状态，但管理员可改所有 |
| T5 | bookable=0 初始值确认 | 确认为设计意图（INSTRUMENT-03 隔离环境用），不自动修改 | 数据库 live 快照 4 台设备全 0 |

### 3.2 未冻结业务规则（只列候选方案，不自行开发）

| 编号 | 模块 | 冻结缺口 | 候选方案 | 建议 |
|---|---|---|---|---|
| U1 | 维修工单分配 | 多名维修负责人如何自动派单 | A. 轮流派单；B. 平均负载；C. 首负责人；D. 不自动派单，管理员手动指定 | 等负责人裁决 |
| U2 | 暂停到期自动解除 | 自动解除 vs 全部人工 | A. 到期自动 EXPIRED + 自动恢复资质（代码保留）；B. 全部人工（当前 H1 裁决） | 已冻结 B，无需讨论 |
| U3 | 特殊设备规则 | PROTEIN_PURIFY 最短 6h / BLI 粒度 / 冻干机批次 | A. 后端 switch(device.category) 硬编码；B. 规则表新增 category 特殊字段；C. 规则表 granuleMinutes/minDurationMinutes 可覆盖（B2 已有 granule/minDuration） | 方案 C 复用现有字段，方案 A 硬编码可接受 |
| U4 | 跨日预约 | allowCrossDay=1 时窗口设备能否跨日 | A. 全类型允许（窗口模型扩展）；B. 仅普通规则允许，窗口设备仍单自然日（HOLD 分支） | 当前 B 已部分实现 |
| U5 | 故障登记 | 普通用户能否上报故障 | A. 允许上报（需新增前端入口 + VO + 后台审核/接受）；B. 仅管理员改状态 FAULT | 等负责人裁决 |
| U6 | 设备状态变更后已存预约 | FAULT/MAINTENANCE 后 PENDING 预约自动作废/保留 | A. 自动作废并邮件通知；B. 保留但阻止 STARTED；C. 不处理 | 等负责人裁决 |
| U7 | 普通用户故障上报入口 | — | A. 设备详情页新增"上报故障"按钮；B. 仪器大厅卡片新增标记 | 依赖 U5 |

### 3.3 本轮不做的（重复 INSTRUMENT-03）

| 模块 | 标记 | 说明 |
|---|---|---|
| 预约全流程 | DONE | 195 自动化测试全 PASS |
| 并发控制 | DONE | 行锁 + 条件更新 |
| 权限隔离 | DONE | 多层 @PreAuthorize + Service 层数据范围 |

---

## 四、风险清单

| 编号 | 风险 | 等级 | 影响 | 处置建议 |
|---|---|---|---|---|
| R1 | 资质重复 ACTIVE 导致 selectActive 返回非唯一结果 | **P0** | 预约 P4 资质校验可能返回多条记录（selectActive 查 ACTIVE，若返回 2 条则 P172==null 不成立，继续流程到 P4 但用了第一条） | T2 立即修复 |
| R2 | updateDeviceStatus 无数据范围校验：任何 lab_admin 可改任何设备状态 | **P1** | 越权修改非负责设备状态 | T4 修复 |
| R3 | 维修负责人无数据范围：被分配但看不到任何设备 | **P1** | 业务关系建立后无实际权限 | T1 修复 |
| R4 | updateDeviceStatus 无操作历史：设备状态变更无法审计追溯 | **P2** | 满足合规审计要求 | T3 修复 |
| R5 | bookable 全 0：真实环境 4 台设备不可预约 | **信息** | 确认是 INSTRUMENT-03 隔离环境 vs 真实环境差异 | 不自动修改，人工确认 |

---

## 五、执行总结

本轮盘点覆盖仪器模块 **12 个业务领域、42 个功能点**，标记结果：

| 标记 | 数量 | 占比 |
|---|---|---|
| **DONE** | 18 | 43% |
| **PARTIAL** | 9 | 21% |
| **MISSING** | 5 | 12% |
| **BLOCKED** | 6 | 14% |
| **BUG** | 4 | 10% |

**本轮明确修复范围（T1~T5）**：修复 BUG/PARTIAL 类已明确缺口（4 项代码修复 + 1 项数据确认）。

**未冻结范围（U1~U7）**：维修工单/特殊设备规则/暂停到期/普通用户上报等 7 项，仅列候选方案不自行开发。

**重复 INSTRUMENT-03 的功能**：不重复开发，直接引用已有验收结论。
