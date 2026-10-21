# INSTRUMENT-02 实施前核查报告

> 任务：TASK INSTRUMENT-02-PRECHECK-01（仪器使用资质与统一信用账户：需求核对、代码审查及实施准备）
> 执行日期：2026-10-15
> 性质：**只读核查**（未执行 DDL/DML/初始化 SQL，未修改代码，未清理 INSTRUMENT-01 的 10 条测试记录）
> 结论：**PASS**——可直接进入实施；G12~G17 待裁决项均有默认方案且不阻塞开发（见 §8）

---

## 1. 已确认需求与待确认需求

### 1.1 已确认规则（任务单三 + 文档裁决，实施必须遵守）

| # | 规则 | 文档落点 | 状态 |
| --- | --- | --- | --- |
| R1 | 使用资质按设备逐台申请和审核（target 固定 DEVICE，无平台覆盖） | 04 §2.1、11 号修订 C4 | **已裁决（C4）** |
| R2 | 首次通过任意一台设备资质审核 → 激活统一信用账户，初始 100 分 | 04 §3.2、02 §4.2 | 已确认（F2/F3） |
| R3 | 后续其他仪器审核通过不重复发放 100 分 | 04 §3.2/3.3 | 已确认 |
| R4 | 积分允许超过 100，无上限约束/CHECK | 04 §3.1（F1） | 已确认 |
| R5 | 低于 80 分不自动禁用/暂停，仅授权管理员人工暂停 | 04 §3.6（F10） | 已确认 |
| R6 | 积分变动必有流水，历史流水不可覆盖/删除 | 04 §3.4（F4） | 已确认 |
| R7 | 无自动爽约扣分、自动签到/签退（扣分全部人工凭证据登记） | 04 §3.5、11 号 C1 | **已裁决（C1）** |
| R8 | 违规通报默认仅本人和授权管理员可见 | 04 §5.2 权限矩阵 | 已确认 |
| R9 | 暂停维度 SINGLE/ALL、时长档位 1/3/7/14/30 天或自定义截止、支持提前解除、历史全保留 | 04 §4.1（F9） | 已确认 |
| R10 | 审批历史（apply+history 只增不改）与当前资质（qualification）必须分离 | 04 §2.2、02 §3.6-3.8 | 已确认 |
| R11 | 状态机枚举随 Java 发布，不建字典行（双轨范式） | 08 §2.3 | 已确认 |
| R12 | 信用原因 4 项字典（VIOLATION/OVERDUE/REWARD/MANUAL）已随 INSTRUMENT-01 预置 | 08 §2.2、DB 实测 | 已落地 |
| R13 | 后端鉴权强制（@PreAuthorize + Service 数据范围校验，前端 v-hasPermi 仅辅助） | 04 §5.3（F18） | 已确认 |

### 1.2 待确认需求（G12~G17，来自 04 §八）

| 编号 | 事项 | 影响范围 | 是否阻塞 |
| --- | --- | --- | --- |
| G12 | 暂停是否强制联动资质状态（SUSPENDED） | suspend create/release/到期 Job 是否同步 UPDATE qualification | 否（默认方案 A'，见 §8） |
| G13 | 申请人被暂停时能否审核通过 | audit 通过路径一个分支 | 否（默认方案，见 §8） |
| G14 | 信用分是否允许负分 | 是否加下界校验 | 否（默认允许负分，与 04 §七一致） |
| G15 | 各扣分场景具体分值 | 前端默认值/提示文案 | 否（adjust 由操作人手填 delta，分值表可后补） |
| G16 | "首次通过任意仪器"是否含平台资质 | 账户初始化触发条件 | **自动消解**（C4 后第一期全设备级） |
| G17 | 维修奖励积分启用与分值 | 属 INSTRUMENT-06 | 否（本期仅预留，不实现） |

---

## 2. 当前代码和数据库的真实状态及证据

### 2.1 后端（yudao-module-lab，全部实际文件枚举）

| 位置 | 现有文件 | 涉及资质/信用/暂停？ |
| --- | --- | --- |
| enums/instrument | 9 个：DeviceCategory/DeviceStatus/InstrumentRepairScope/InstrumentSimpleStatus/ManagerScope/ManagerStatus/ManagerType/NoticeStatus/NoticeTargetTypeEnum | **无** QualApplyStatus/QualificationStatus/CreditReasonType/SuspendStatus |
| dal/dataobject/instrument | 5 DO：Platform/Device/Room/Manager/Notice | **无** |
| dal/mysql/instrument | 5 Mapper：同名 5 个 | **无** |
| service/instrument | 11 个：5 接口+5 实现+InstrumentScopeSupport | **无** |
| controller/admin/instrument | 5 Controller + vo/{device,manager,notice,platform,room} | **无** |
| ErrorCodeConstants | INSTRUMENT 段 1_002_004_001~044（33 个） | 无 qualification/credit/suspend 错误码，**045 起可用** |
| 全源码 grep `qualification|CreditAccount|suspend`（忽略大小写） | **0 命中** | — |

**结论：后端零实现，全部缺失，需从零新建。**

### 2.2 前端（yudao-ui-admin-vue3）

| 位置 | 现有 | 缺失 |
| --- | --- | --- |
| src/api/lab/instrument | 5 目录：device/manager/notice/platform/room | qualification/credit/suspend |
| src/views/lab/instrument | 7 目录：hall/device-detail/device/platform/room/manager/notice | my-qualification/my-credit/qualification-audit/credit-manage/suspend-manage |
| 全源码 grep `qualification|my-credit|credit-manage|suspend-manage` | **0 命中** | — |

**结论：前端零实现。**

### 2.3 数据库（labplatform 实测）

| 检查项 | 结果 | 证据 |
| --- | --- | --- |
| INSTRUMENT-02 六表（qualification_apply/apply_history/qualification/credit_account/credit_flow/suspend） | **全部不存在**（cnt=0） | information_schema.tables |
| `lab:instrument:qualification:%` / `credit:%` / `suspend:%` 权限串 | **0 占用** | system_menu |
| 菜单 MAX(id) | **13653**（INSTRUMENT-01 段用尽） | system_menu；新段建议从 13660 起（08 号 I4：探测 MAX 后分配，不硬编码） |
| 含"资质/信用/暂停"字样菜单 | 仅 id=1772"采集暂停"（cms:collection:pause，CMS 模块） | 无冲突 |
| 字典 lab_instrument_credit_reason | **已预置，4 项有效**（VIOLATION/OVERDUE/REWARD/MANUAL） | system_dict_data |
| 字典 lab_instrument_suspend_scope | **已预置，2 项有效**（SINGLE/ALL） | system_dict_data |
| TenantBaseDO 规范 | 5 张既有仪器表均含六公共字段+tenant_id | 与新 6 表兼容 |

### 2.4 可直接复用的既有基础设施（不重做）

| 设施 | 位置 | 复用方式 |
| --- | --- | --- |
| Redisson 锁封装 | dal/redis/InstrumentLockRedisDAO | 扩展 qual/credit 锁 key（沿用 `lock(key, supplier)` + TransactionTemplate 范式） |
| 锁内事务范式 | InstrumentManagerServiceImpl.doAssign | `lockRedisDAO.lock(key, () -> transactionTemplate.execute(...))`，规避自调用事务失效 |
| 授权范围校验 | InstrumentScopeSupport.canManageDevice | 资质审核（负责人仅授权设备）、信用 adjust、suspend create/release 的数据范围判定直接复用 |
| 租户隔离 | TenantBaseDO + MyBatis 租户插件 | 新 6 DO 继承 TenantBaseDO 即可 |
| 双轨范式 | INSTRUMENT-01 已落地 | 状态机枚举（PENDING/APPROVED/...、ACTIVE/EXPIRED/...）不建字典 |
| 逻辑删除规范 | deleted bit(1) | 全部沿用 |

---

## 3. 已存在功能、缺失功能和冲突

### 3.1 已存在（可直接复用）
- 信用原因/暂停维度两组字典（已入库）
- 授权范围校验、锁+事务范式、租户隔离、错误码段
- 设备/用户基础数据（含 INSTRUMENT-01 测试记录，可作联调数据）
- 906/904 角色授权机制（新菜单沿用同一授权模式）

### 3.2 完全缺失（本批全部新建）
- 6 张表 DDL；6 枚举 + 2 字典映射；6 DO + 6 Mapper
- 资质申请/审核/撤回/撤销服务链路；信用账户初始化/加扣分/流水；暂停创建/解除/到期
- 19 个接口（07 号 §2.6/2.11/2.12）；5 个页面；3 组权限串；菜单与角色授权 SQL
- 约 15+ 个错误码（1_002_004_045 起）

### 3.3 冲突
- **无冲突**：权限串 0 占用、表名 0 冲突、菜单段 13660+ 空闲（MAX=13653）、字典已预置无需重跑、CMS"采集暂停"仅同名异义。
- 唯一注意点：菜单 SQL 生成时须实测 MAX(id)（当前 13653），注释中不得写死 INSTRUMENT-01 时的 13585。

---

## 4. 建议的数据模型、接口、页面及权限设计

### 4.1 数据模型（严格按 02 号 §3.6~3.11，仅设备级 C4）

| 表 | 关键字段/约束 | 说明 |
| --- | --- | --- |
| lab_instrument_qualification_apply | UNIQUE(tenant_id, apply_no)；status PENDING/APPROVED/REJECTED/CANCELED；device_id；applicant_user_id | 申请单 |
| lab_instrument_qualification_apply_history | apply_id + action(SUBMIT/APPROVE/REJECT/CANCEL/RESUBMIT) + 快照 | 只增不改 |
| lab_instrument_qualification | target_type 固定 'DEVICE'；user_id+device_id；status ACTIVE/EXPIRED/SUSPENDED/REVOKED；source_apply_id | 当前资质，应用层保证单 ACTIVE |
| lab_instrument_credit_account | **UNIQUE uk_account_tenant_user(tenant_id, user_id)**；score 默认 100 无上限无 CHECK；initialized 标记 | 统一账户 |
| lab_instrument_credit_flow | account_id；score_change/score_before/score_after；reason_type（字典 4 项）；biz_type/biz_id；reason 必填 | 只增不可变，无删改接口 |
| lab_instrument_suspend | user_id；scope_type（SINGLE/ALL，字典）+ device_id；start/end_time；reason 必填；status ACTIVE/RELEASED/EXPIRED；release_reason/release_user | 历史全保留 |

全部含 TenantBaseDO 六公共字段；全部 CREATE TABLE IF NOT EXISTS + 无物理外键（沿用 lab 规范）。

### 4.2 接口（07 号已冻结设计，19 个）

| 组 | 端点（/admin-api/lab/instrument 前缀省略） | 权限串 |
| --- | --- | --- |
| 资质（9） | POST apply / POST cancel / POST audit / GET apply/page / GET apply/get / GET apply/history-list / GET my / GET page / POST revoke | qualification:apply（apply/cancel）、qualification:audit（audit）、qualification:query（查询类）、qualification:manage（revoke） |
| 信用（6） | GET my / GET page / GET flow/my / GET flow/page / POST adjust / GET flow/export-excel | credit:query、credit:adjust、credit:export |
| 暂停（4） | GET page / POST create / POST release / GET my | suspend:query、suspend:manage |

### 4.3 页面（07 号 §3，5 个新页面 + 2 处入口）

| 页面 | component | 用户 |
| --- | --- | --- |
| 我的仪器资质 | lab/instrument/my-qualification/index | 普通用户（申请、状态、审核结果） |
| 我的信用 | lab/instrument/my-credit/index | 普通用户（分数、流水、暂停记录） |
| 资质审核 | lab/instrument/qualification-audit/index | 负责人/管理员（审核队列、通过/驳回必填意见） |
| 信用管理 | lab/instrument/credit-manage/index | 管理员（账户分页、加扣分） |
| 暂停管理 | lab/instrument/suspend-manage/index | 管理员（创建/解除，原因必填） |

入口：设备详情页（device-detail）"我的资质"区块；**首页模块按权限展示**——参考图"我的使用资质/我的信用"卡片仅对持有对应菜单/权限的用户渲染（v-hasPermi + 菜单权限双控），"仪器预约/我的预约"卡片属 INSTRUMENT-03 不在本期出现。

### 4.4 权限与角色授权（沿用 07 号 §4 + INSTRUMENT-01 模式）

- 新权限串 10 个：qualification:query/apply/audit/manage、credit:query/adjust/export、suspend:query/manage
- 菜单：普通端 2 页面（13660+ 段）+ 管理端 3 页面 + 约 10~12 个按钮
- 906 本草基因管理员：全量；904 普通用户：仅"我的仪器资质/我的信用"两页面 + qualification:apply/query + credit:query（本人数据由 Service 强制 user_id=当前用户）
- 审核权限的数据范围（负责人仅授权设备）由 Service 层 InstrumentScopeSupport 校验，不建独立系统角色（F19）

---

## 5. 并发、事务、租户隔离及审计方案

### 5.1 首审初始化 100 分——三层防护（最高风险，02 号 §4.2 / 04 §3.3）

1. **DB 唯一键** `uk_account_tenant_user(tenant_id, user_id)`：并发插入仅一个成功，其余 DuplicateKey 捕获后降级为"已存在→跳过"；
2. **Redisson 锁** `instrument:credit:account:{tenant}:{user}`：锁内"查不到才插入"；
3. **与审核同一事务**：审核通过（条件更新 apply）→ 创建 qualification → 尝试初始化账户 → 写 history，任一步失败全部回滚。

账户已存在但 initialized=0（异常数据）：视为未初始化，允许补一次，记 warn 日志（04 §七）。

### 5.2 审核防重

事务内 `SELECT ... FOR UPDATE` 锁 apply 行 → 条件更新 `UPDATE ... SET status='APPROVED' WHERE id=? AND status='PENDING'` → affectedRows=0 抛"申请状态已变更"（防双人同时审核、防重复提交）。

### 5.3 加扣分一致性（02 号 §4.3）

```
事务: FOR UPDATE 锁账户行 → scoreAfter = before + delta（正负均可，无上下限）
      → UPDATE account → INSERT flow(before/after/reason/biz) → commit
```
重复防护：同一 biz_type+biz_id 是否已产生同类型流水由 Service 校验（违规登记场景）；接口层沿用框架 @Idempotent。

### 5.4 申请防重

Service 校验：同 (tenant, device, applicant) 无 PENDING、无该设备 ACTIVE 资质 → 拒绝；Redisson 锁 `instrument:qual:{tenant}:device:{deviceId}:{user}` 拦并发双击。

### 5.5 租户隔离与数据范围（服务端强制）

- 六 DO 继承 TenantBaseDO，租户插件自动过滤；跨租户请求头篡改由框架 403 拦截（INSTRUMENT-01 已实测）。
- 本人数据：my/flow/my/suspend my 接口 Service 强制 `user_id = SecurityFrameworkUtils.getLoginUserId()`。
- 管理端数据范围：审核/adjust/suspend 操作前 `canManageDevice`（或管理员全量）校验，越权返回明确错误码（F18）。

### 5.6 审计

- 业务语义：apply_history（申请时间线）、credit_flow（before/after）、suspend（release_* 字段）——三表只增不改。
- 接口审计：@OperateLog 注解覆盖 audit/adjust/suspend create/release/revoke。
- 违规通报可见性：credit_flow 无"公开列表"接口；仅 my（本人）与管理端 page（授权范围）可见（R8）。

---

## 6. 需要新增或修改的文件清单

### 6.1 SQL（生成，执行需负责人授权）

| 文件 | 内容 |
| --- | --- |
| sql/lab/20261015_instrument_02_schema.sql | 6 表 DDL（IF NOT EXISTS，含执行前检查/执行后验收节） |
| sql/lab/20261015_instrument_02_menu.sql | 菜单 13660+ 段（实测 MAX(id) 后定段）、10 权限串按钮、套餐 114 追加、906 全量/904 本人页授权 |

（字典无需新 SQL——credit_reason/suspend_scope 已预置。）

### 6.2 后端（yudao-module-lab，全部新增；仅 1 处修改）

| 类型 | 文件 |
| --- | --- |
| 枚举 ×4~5 | QualApplyStatusEnum、QualificationStatusEnum、SuspendStatusEnum、SuspendScopeEnum（引用字典）、CreditReasonTypeEnum（引用字典） |
| DO ×6 | InstrumentQualificationApplyDO / ApplyHistoryDO / QualificationDO / CreditAccountDO / CreditFlowDO / SuspendDO |
| Mapper ×6 | 同名 6 个（含 selectPage/条件更新/activeCount 等 default 方法） |
| Service ×6 | QualificationService(+Impl)、CreditService(+Impl)、SuspendService(+Impl) |
| Controller ×3 | QualificationController、CreditController、SuspendController |
| VO ×3 目录 | vo/qualification、vo/credit、vo/suspend（约 15 个） |
| **修改** | ErrorCodeConstants（追加 1_002_004_045 起 ~15 个）；InstrumentLockRedisDAO（追加 qual/credit 锁 key 常量，不改既有方法） |

### 6.3 前端（全部新增）

| 类型 | 文件 |
| --- | --- |
| API ×3 | api/lab/instrument/{qualification,credit,suspend}/index.ts |
| 页面 ×5+表单 | views/lab/instrument/{my-qualification,my-credit,qualification-audit,credit-manage,suspend-manage}/index.vue（管理页含表单子组件） |
| 入口修改 | device-detail/index.vue 增加"我的资质/申请资质"区块（INSTRUMENT-01 已有页面内增量，不改其他模块） |

---

## 7. 后端和前端测试矩阵（实施任务单的验收基线）

### 7.1 后端功能矩阵

| 用例 | 预期 |
| --- | --- |
| 申请资质（无 PENDING/无 ACTIVE） | 成功，apply= PENDING，写 history(SUBMIT) |
| 重复申请（已有 PENDING） | 拒绝（明确错误码） |
| 已持 ACTIVE 再申请同设备 | 拒绝 |
| 负责人审核本人授权设备（通过/驳回） | 通过→qualification ACTIVE→首审初始化账户 100→history(APPROVE)；驳回必填意见 |
| 非授权设备审核 | 拒绝（数据范围） |
| 904 审核接口 | 403 |
| 第二台仪器审核通过 | **账户不重复初始化，score 仍 100** |
| 并发双审同一申请 | 一成功一 affectedRows=0 |
| 并发两设备同时首审（不同锁） | 账户仅一条、score=100（uk 兜底） |
| adjust 加分/扣分 | score before/after 与流水一致；reason 必填；越权拒绝 |
| 并发同账户多笔 adjust | 余额=初始+Σ流水，无丢失更新 |
| 暂停创建（SINGLE/ALL、原因必填） | 成功；904 拒绝 |
| 提前解除 | RELEASED+release_reason+操作人；历史保留 |
| my/flow/my 仅本人数据 | 越权他人数据 0 行 |
| 跨租户 | 403 |

### 7.2 前端矩阵

| 页面 | 用例 |
| --- | --- |
| 我的资质 | 列表/申请/撤回/历史时间线；v-hasPermi 按钮显隐 |
| 我的信用 | 分数、流水分页、暂停记录；无删除/修改入口 |
| 资质审核 | 队列、通过/驳回（意见必填校验）、非法状态提示 |
| 信用管理 | 账户分页、加扣分表单（reasonType/reason 必填） |
| 暂停管理 | 创建（scope/时长/截止/原因）、解除 |
| 权限展示 | 904 无管理菜单；首页"我的使用资质/我的信用"卡片按权限渲染 |
| TS 检查 | instrument 模块 0 新增错误 |

---

## 8. 需负责人裁决的阻塞项

**无阻塞项。** G12~G17 默认方案如下，实施按默认执行；若负责人另有裁决，改动点已隔离：

| 编号 | 默认方案 | 依据与改动点 |
| --- | --- | --- |
| G12 | **联动**：暂停生效→qualification 置 SUSPENDED；解除/到期→恢复 ACTIVE（仅恢复未被其他原因改变的） | 00 §4.3 已定义；改动限于 SuspendServiceImpl 两处 + 到期 Job；若裁决不联动，删除该联动即可 |
| G13 | **允许审核通过**（资质与暂停独立，暂停照常生效） | 04 §七建议；audit 单分支，无结构影响 |
| G14 | **允许负分**（无下界，前端展示警示色） | 04 §七；无 CHECK 约束 |
| G15 | adjust 的 delta 由操作人输入；VIOLATION/OVERDUE 常用分值不预设 | 分值表后续独立确认，仅影响前端提示文案 |
| G16 | C4 后第一期全设备级，**自动消解** | 11 号修订 |
| G17 | 本期不实现维修奖励 | 属 INSTRUMENT-06 |

**可直接开发项**（无需再拆任务、无结构风险）：六表 DDL、全部后端链路、5 页面、菜单/授权 SQL 生成——均基于已冻结的 02/04/07 号设计。

---

## 9. 最终状态

**PASS**

- 需求已确认规则完整（R1~R13），文档基线一致（02/04/07/08/11 号交叉核对无冲突）。
- 代码与数据库均为"零实现"状态，无历史包袱、无命名/权限/表名冲突，字典已预置。
- 最高风险（并发首审初始化）已有冻结的三层防护设计与可复用锁/事务范式。
- G12~G17 均有默认方案且不阻塞；特殊预约规则（日历、BLI/蛋白纯化粒度）已隔离至 INSTRUMENT-03+。

**建议实施任务单**：TASK INSTRUMENT-02-IMPL（阶段1 SQL 生成→阶段2 后端→阶段3 前端→阶段4 编译/TS/并发自查→阶段5 交付报告；SQL 执行与真实联调另列 DEPLOY 任务，沿用 INSTRUMENT-01 的 PRECHECK→授权→DEPLOY 流程）。

本任务未执行任何数据库写入，未修改任何代码，未进入 INSTRUMENT-03。
