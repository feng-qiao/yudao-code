# 51-INSTRUMENT-04 遗留 Bug 与待裁决问题清单

> 编制日期：2026-10-20
> 编制依据：47 号盘点 + 48 号实施 + 49 号规则核验
> 标记说明：FIXED=本轮已修复 / PENDING=已知 Bug 暂不修 / BLOCKED=业务规则未裁决 / DESIGN=设计意图

---

## 一、已知 Bug

| 编号 | 模块 | 描述 | 严重程度 | 是否阻断主流程 | 状态 | 本轮处置 |
|---|---|---|---|---|---|---|
| **BUG-01** | 资质 | 审核通过 INSERT 不检查旧资质 → 同用户同设备两条资质（SUSPENDED+ACTIVE） | **P0 数据一致性** | 是（预约 P4 selectActive 可能返回非唯一） | **FIXED** | T1 修复：auditApproval approve 分支重写 |
| **BUG-02** | ScopeSupport | getManagedDeviceIds 不处理 ROOM_REPAIR → 维修负责人无数据范围 | **P1 权限缺失** | 否（维修负责人无任何功能权限入口暴露） | **FIXED** | T2 修复：ScopeSupport 加 ROOM_REPAIR 分支 |
| **BUG-03** | 设备状态变更 | 无操作历史记录 | **P2 审计追溯** | 否 | **PENDING** | 禁止 DDL（本轮约束），需单独批次批准 DDL 后新建 InstrumentDeviceStatusHistoryDO |
| **BUG-04** | DeviceStatusReqVO | 只有 id+targetStatus，无 reason/reporter 字段 | **P2 审计追溯** | 否（当前唯一"故障登记"方式 = 改状态 FAULT，无上下文） | **PENDING** | 依赖故障登记入口裁决（U5） |
| **BUG-05** | ADJUST 历史 | 预约调整的 InstrumentReservationHistoryDO after_status 可能为 NULL | **P2 数据完整性** | 否 | **PENDING** | 小 Bug 暂缓修复（任务书裁决："不阻断主要业务流程的小 Bug 暂缓修复"） |
| **BUG-06** | ManagerAssignReqVO | scope=ROOM_REPAIR 时不校验目标用户是否有维修角色 | **P2 权限边界** | 否（任意 lab_admin 可指定任意用户为维修负责人，但该用户无功能权限入口） | **DESIGN** | 设计意图：lab_admin 全权指定，维修负责人角色仅作数据范围标记 |
| **BUG-07** | 前端 | 创建 VO 时间格式示例不一致 | **信息** | 否 | **PENDING** | 小 Bug 暂缓修复 |

---

## 二、未冻结业务规则（需负责人裁决）

| 编号 | 模块 | 规则缺口 | 候选方案 | 建议 | 优先级 |
|---|---|---|---|---|---|
| **U1** | 维修工单 | 多名维修负责人如何自动派单 | A. 轮流派单；B. 平均负载；C. 首负责人；D. 不自动派单，管理员手动指定 | 方案 D 最简单（当前 G26 方案A 允许多人同时 ACTIVE） | 高 |
| **U2** | 暂停到期自动解除 | — | — | H1 裁决 **2026-10-15**：全部人工解除，InstrumentSuspendExpireJob 不注册 Quartz | **已冻结** |
| **U3** | 跨日预约 | allowCrossDay=1 时窗口设备能否跨日 | A. 全类型允许；B. 仅普通规则允许，窗口设备仍单自然日 | 当前 B 已部分实现（validateWindowScope 限制单自然日） | 中 |
| **U4** | 故障登记 | 普通用户能否上报故障 | A. 允许（需新增前端入口 + VO + 后台审核）；B. 仅管理员改状态 FAULT | 方案 A 需新增完整流程，方案 B 零改动 | 中 |
| **U5** | 故障登记入口类型 | — | A. 设备详情页"上报故障"按钮；B. 仪器大厅卡片标记 | 依赖 U4 裁决 | 中 |
| **U6** | 设备状态变更后已存预约 | FAULT/MAINTENANCE 后 PENDING 预约自动作废/保留 | A. 自动作废 + 通知；B. 保留但阻止 STARTED；C. 不处理 | 方案 C 当前行为（updateDeviceStatus 不处理已有 PENDING 预约） | 中 |
| **U7** | 维修负责人恢复设备权限 | 谁可以确认恢复使用 | A. 仅 lab_admin；B. lab_admin + 维修负责人；C. 仅维修负责人 | 当前 A（lab_admin 全权），维修负责人无 lab:instrument:device:manage 权限 | 高 |
| **U8** | PROTEIN_PURIFY 最短 6h | 服务端硬编码兜底 vs 纯配置 | A. ReservationCreateExecutor 加 switch(category) 硬编码；B. lab_admin 直接配置规则 min_duration=360 | 方案 B 零代码改动即可生效。如需硬兜底选 A | 低 |
| **U9** | BLI 预约粒度 | 粒度值未确定 | A. 15 分钟；B. 30 分钟；C. 60 分钟；D. 其他 | 规则表 granularity 字段已支持，裁决后 lab_admin 配置即可 | 中 |
| **U10** | 冻干机批次 | 是否需要批次预约 | A. 批次一次性预约；B. 普通预约 | 任务书未提及，未冻结 | 低 |
| **U11** | bookable 真实环境值 | 哪些设备需要打开 bookable=true | 人工配置 | 4 台设备全 0，INSTRUMENT-03 隔离环境初始值 | 信息 |

---

## 三、功能缺失（整体未实现，有 DO/枚举占位）

| 编号 | 功能 | DO | Mapper | Service | Controller | 前端 | 状态说明 |
|---|---|---|---|---|---|---|---|
| **M1** | 故障登记 | ❌ 无独立 DO（InstrumentMaintenanceDO.sourceType=REPAIR 为 INSTRUMENT-06 预留） | ❌ | ❌ | ❌ | ❌ | 整体未实现，含故障原因/上报人/上报时间 |
| **M2** | 维修工单 | ✅ InstrumentMaintenanceDO | ✅ InstrumentMaintenanceMapper | ❌ | ❌ | ❌ | 仅 DO + Mapper + 枚举存在 |
| **M3** | 维修处理记录 | — | — | — | — | — | 依赖 M2 |
| **M4** | 维修完成/恢复确认 | — | — | — | — | — | 依赖 M2 |
| **M5** | 维修操作历史 | — | — | — | — | — | 依赖 M2 |

---

## 四、配置与数据一致性风险

| 编号 | 风险 | 等级 | 场景 | 建议 |
|---|---|---|---|---|
| **R1** | 设备 4 category 配置错误 | P2 | 叫"酶标仪"但 category=NORMAL 而非 MICROPLATE_READER | lab_admin 修正 |
| **R2** | 暂停覆盖 G12 期间新申请通过 | P1（已安全处理） | 用户有 ACTIVE 暂停覆盖 + 再次申请 → 审批通过 | **本轮已修复**：审核侧检测暂停覆盖后不 INSERT 新 ACTIVE（保持 SUSPENDED） |
| **R3** | bookable 全 0 | 信息 | 4 台设备全不可预约 | lab_admin 手动配置 |
| **R4** | 设备状态变更后已存 PENDING 预约 | P1 | FAULT/MAINTENANCE 后 PENDING 预约仍有效 | 业务规则未冻结（U6），当前设计为"到时间可正常使用设备" |

---

## 五、C7 与数据库变更记录

| 项 | 值 |
|---|---|
| C7 最终状态 | **false** |
| 本轮对真实 labplatform 执行 DDL | ❌ 无 |
| 本轮对真实 labplatform 执行 DML（INSERT/UPDATE/DELETE） | ❌ 无（禁止） |
| 本轮代码改动涉及数据库 schema 变更 | ❌ 无 |
| 本轮代码改动涉及菜单 SQL | ❌ 无（禁止） |

---

## 六、任务书原 Bug 项处置

| 原 Bug 描述 | 本报告编号 | 本轮处置 |
|---|---|---|
| 历史资质与暂停解除可能产生重复 ACTIVE | BUG-01 | **FIXED**（T1 修复） |
| 创建 VO 时间格式示例 | BUG-07 | **PENDING**（小 Bug） |
| ADJUST 历史 after_status 为 NULL | BUG-05 | **PENDING**（小 Bug） |

---

## 七、修复优先级建议

| 优先级 | 项 | 依赖 |
|---|---|---|
| **立即修复（已完成）** | BUG-01 资质重复 ACTIVE | — |
| **立即修复（已完成）** | BUG-02 维修负责人数据范围 | — |
| **真实环境验收** | T1+T2 修复验证 | lab_admin 配合 |
| **批次批准后修复** | BUG-03 设备状态变更历史（DDL） | DDL 批准 |
| **批次批准后修复** | M1~M5 维修工单整体 | U1/U7 裁决 |
| **批次批准后修复** | BUG-04 DeviceStatusReqVO 增强 | U4 裁决 |
| **小 Bug 暂缓** | BUG-05 / BUG-07 | — |
| **待裁决** | U1 / U3~U11 | 负责人 |
