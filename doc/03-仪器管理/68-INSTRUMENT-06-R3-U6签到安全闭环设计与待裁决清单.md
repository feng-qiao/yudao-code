# INSTRUMENT-06 R3：U6 预约签到安全闭环设计与待裁决清单

**任务**：CODEX-INSTRUMENT-06-R3-U6-DESIGN-01  
**盘点日期**：2026-10-20  
**结论**：**DESIGN HOLD**  
**范围说明**：只读检查代码、测试、配置及文档；本报告是实施前建议，不构成规则冻结或实施授权。本轮未修改业务代码/SQL 58/59，未执行 SQL，未连接数据库/Redis，未启动服务或容器，未修改 C7。

## 1. 结论摘要

技术上可在不修改 `InstrumentReservationDO.status` 状态机的前提下，将“签到/实际开始使用事实”存入独立记录表，保留预约状态 `PENDING / FINISHED / CANCELED / VOIDED`。签到必须在服务端重验预约、用户、资质、暂停、设备状态、有效预约影响和同设备并发占用；前端显隐不能构成授权。

但实现前必须由负责人裁决第 9 节的业务规则，尤其是签到身份/时间窗口、管理员代办、开放签到的结束方式，以及活动签到期间既有取消/调整/作废的规则。现有预约生命周期允许管理侧任意时刻取消 `PENDING`，允许管理侧调整/作废 `PENDING`；单加签到接口而不协调这些既有写路径会产生使用中预约被取消、改期或释放占用的竞态。因此当前为 **DESIGN HOLD**。

R2 所见的预约影响逻辑仍只负责“保留预约、写影响记录、恢复时标记 `AUTO_RESTORED`”；`isReservationCurrentlyImpacted()` 仍没有调用点。影响状态 `PENDING` 与 `AUTO_RESTORED` 均应阻断签到，只有管理员人工处理后为 `PROCESSED` 才可继续评估其他条件。恢复设备不得自动解除这一人工门槛。

## 2. 资料和代码基线

### 2.1 实际读取的规则/报告

- `00-总体设计与业务模型.md`、`02-数据库模型设计.md`、`03-预约规则与并发控制设计.md`：C1 规定第一期无签到/签退/硬件检测/自动爽约；`IN_USE` 是未来预留，第一期不产生；预约时间到达不代表真实使用；信用处罚须有授权负责人依据实际证据手工登记。C3 规定 `PENDING/FINISHED` 占用时段，只有 `CANCELED/VOIDED` 释放。
- `23-INSTRUMENT-03-数据库与接口设计.md`、`34-INSTRUMENT-03预约管理版范围收敛与简化报告.md`、`35-INSTRUMENT-03预约生命周期交付与验收报告.md`、`36-INSTRUMENT-03真实MySQL并发与部署前验收报告.md`、`37-INSTRUMENT-03正式部署准备与业务验收报告.md`：生命周期、行锁、权限、隔离测试准备和既有部署边界。
- `57-INSTRUMENT-06正式规则冻结与状态机设计.md`、`67-CODEX-INSTRUMENT-06-R2维修模块部署前收口与U6安全修复报告.md`、当前 SQL 58/59。
- 两个仓库有 `README.md`；未发现仓库根 `AGENTS.md`。文档目录未发现 README。前端 README 说明使用 pnpm 的项目约定。

### 2.2 工作区状态

前端、后端均在 `master`；本次只读检查时分别相对 upstream ahead 6、ahead 7。R2 留下的已修改文件、既有 `.gitignore`/`.env.prod` 修改、未跟踪环境文件和 `node_modules` 均保持原状；未暂存、提交、清理或重置。目标环境当前数据库结构、菜单、角色、套餐、Redis、运行时 Profile 均 **UNKNOWN**。

## 3. 当前预约链路与状态机

### 3.1 状态及数据模型

代码 `ReservationStatusEnum` 只有 `PENDING`、`FINISHED`、`CANCELED`、`VOIDED`。`InstrumentReservationDO` 已含 `actualStartTime`、`actualEndTime`、`finishTime`，注释明确实际时间第一期不自动写入，仅手工登记时使用。预约查询、日历、冲突规则把 `PENDING` 与 `FINISHED` 作为占用；CANCELED/VOIDED 释放。

旧规则 C1 与用户本轮方向的边界：显式人工签到后写新的签到记录，可以作为新的产品能力；不得把预约开始时间到达自动解释为实际使用，也不得自动完成预约或自动扣信用分。若要允许签到时间早于 `start_time` 并据此认定实际使用，则会改变“预约外时间也属实际使用”的边界，需裁决。

### 3.2 创建

入口 `POST /lab/instrument/reservation/create`，由 Controller 权限 `lab:instrument:reservation:create`、幂等注解及 Service 的 C7 开关保护。Service 在事务中先取得设备 `FOR UPDATE` 行锁，再由 `ReservationCreateExecutor` 执行 P1–P9：设备存在/状态、bookable、规则、预约人 ACTIVE 且未过期资质、无 ACTIVE 暂停、开放时段、时间有效、预约/维护冲突、最后写预约和 history。设备行锁是 34 号收敛后的主要互斥锚点；Redis 仅保留预约号 INCR，不再作预约并发锁。

### 3.3 生命周期写操作

| 操作 | 当前规则/实现 | 并发方式与签到兼容影响 |
|---|---|---|
| 取消 `POST /cancel` | 仅 PENDING；本人限开始前；管理侧有范围且可任意时刻取消，管理侧原因必填；同事务记 history | 单预约条件更新 affectedRows；当前未检查活动签到记录。签到后仍是 PENDING 时，管理侧现有规则可取消。 |
| 完成 `POST /finish` | 管理范围内手工登记，PENDING→FINISHED；实际开始/结束必填，禁止非递增区间；同事务记 history | 条件更新；可作为活动签到关闭的自然入口，但目前只由管理范围角色操作，签到者无签退接口。 |
| 调整 `PUT /adjust` | PENDING；本人开始前可调，管理范围可调并须原因；全链重验设备、资质、暂停、规则、开放时间、冲突 | 先锁外读取预约取得设备 ID，再事务中设备行锁；跨设备按 ID 升序双锁，重读预约并条件更新。签到后依然 PENDING，管理侧调整未被当前规则阻止。 |
| 作废 `POST /void` | 管理范围内 PENDING 可作废，原因留痕 | 单预约条件更新；当前未检查活动签到。 |
| 历史 `GET /history-list` | 本人/授权负责人/管理员可读预约历史 | `instrument_reservation_history` 记录创建、取消、完成、调整、作废等；没有签到动作枚举/记录。 |

作废与取消/完成不同，要求 `reservation:manage`；调整使用独立 `reservation:adjust`。业务负责人是否有相关菜单/数据权限须随现有权限模型验收，不能只依据前端按钮。

### 3.4 资质、暂停、设备状态和信用

- 资质：预约创建 P4 查询预约人对设备的 ACTIVE 资质，`expire_time` 为空按长期有效，否则必须严格晚于当前时间。签到时应复查当前资格，而非信任创建时快照。资格审核、撤销、到期/状态迁移及其事务锁顺序须纳入竞态测试；签到与资格撤销能否并发放行需要锁定语义。
- 暂停：P5 以 `status=ACTIVE` 和开始时间生效，不因计划 `end_time` 到达自动失效；解除为人工操作。暂停创建和预约创建共用设备行锁协议。签到必须复查预约人和设备范围的有效暂停。
- 设备：预约准入要求设备状态 `NORMAL` 且 `bookable=true`。其余状态为 `MAINTENANCE/FAULT/DISABLED/SCRAPPED`；任何非 NORMAL 应拒绝签到。设备状态变更服务已有设备行锁；故障/维修影响表另行约束 U6。
- 信用：当前 P1–P9 创建链未使用信用分作为准入门槛；第一期违规信用由授权负责人手工登记。签到/拒绝签到/未签到不得新增自动信用流水、爽约状态或扣分 Job。
- 设备资质与暂停管理有独立业务范围；维修负责人角色不得因签到功能获得这些权限。

## 4. 签到机制可行性与建议

### 4.1 不改预约状态机的方案

建议新增独立 `instrument_reservation_checkin`（名称待 DBA/项目命名规范确认）记录。预约表状态仍为 PENDING；签到记录表达明确的、可审计的实际开始使用事件。签到成功时不自动将预约置为 FINISHED，不自动修改设备状态或信用；完成仍走原 `finish` 流程，且将签到记录的实际开始时间作为完成校验/审计依据。

建议表按“每个预约最多一条签到记录”保存当前使用事实与审计快照：记录租户、预约/设备/用户 ID、实际签到时间、记录状态（建议 `OPEN/CLOSED`）、结束时间/操作者/来源、审计字段。预约 ID 唯一；设备上 OPEN 使用中的记录必须互斥。旧预约无需批量回填，历史实际使用时间无签到凭据时不得伪造。

这不是给预约状态增加 `STARTED`/`IN_USE`，但会在签到记录域出现 OPEN 状态，它依然代表“已有实际使用会话”。这与 C1 的第一期不签到能力相比是新增业务能力，需负责人明确批准后才可实施。

### 4.2 API 与页面建议

复用已有预约模块，不变更 SQL 59 的维修菜单及菜单 ID。建议在“我的预约”页面增加操作，仅本人自己的 PENDING 预约按服务端状态返回 `canCheckIn/checkInStatus/disabledReason` 展示；页面按钮隐藏仅是 UX，绕过前端直接请求仍由服务端拒绝。

建议接口（仅草案）：

| 方法/路径 | 请求 | 响应建议 | 权限 |
|---|---|---|---|
| `POST /lab/instrument/reservation/check-in/{reservationId}` | 可无 body；若框架要求则仅可选客户端请求 ID，不信任用户/设备/时间字段 | `{reservationId, checkInId, deviceId, userId, checkedInAt, status, idempotent}` | Controller 可沿用 `lab:instrument:reservation:query` 作为登录入口；Service 强制当前用户=预约人。若负责人要求独立权限码，则需另外设计菜单/角色授权，不可静默扩写 SQL 59。 |
| `GET /lab/instrument/reservation/check-in?id={reservationId}`（可选） | 预约 ID | 当前租户下签到账户/状态；未签到返回显式空态 | `reservation:query` + 本人/既有授权管理范围服务端检查 |

请求中不得接受 `userId`、`deviceId`、签到时间、`status` 作为权威字段，均从锁定后的预约、登录上下文及服务端时钟生成。需要手机/扫码设备认证时应另行设计身份绑定，不在当前范围推断。

### 4.3 前端入口

- 入口位置：`yudao-ui-admin-vue3/src/views/lab/instrument/my-reservation/index.vue` 的预约行操作；详情面板可显示签到时间/处理中状态。
- 使用既有动态预约菜单，不增加 SQL 59 菜单 ID。按钮数据由后端响应辅助字段，但任何请求仍要求服务端校验。
- 预约主状态仍显示“待使用/PENDING”；另显示“已签到/使用中”子状态，避免将 `PENDING` 误读为可取消/可调整。设备详情/日历是否展示活动使用状态属于需裁决的 UX 范围。
- 签到失败应展示稳定业务错误与可操作提示；不把未处理影响隐藏为普通网络错误。

## 5. 签到安全校验矩阵（建议规则，未冻结）

建议服务端校验按下表顺序执行；`UNKNOWN/HOLD` 项需决策或补充实现设计。所有校验必须在受控事务/锁内使用最新数据库事实，不能只依赖前端 `canCheckIn`。

| 顺序 | 校验 | 建议通过条件 | 拒绝/待裁决 |
|---|---|---|---|
| 1 | 身份、租户 | 有登录用户；预约查询按当前租户；跨租户/无记录统一 not-exists | 不接收客户端 user/tenant；跨租户不泄漏是否存在 |
| 2 | 操作者身份 | 建议只允许 `reservation.user_id == currentUserId` 的预约人本人签到 | 管理员/设备负责人代签到是否允许：**待裁决**；维修负责人无特殊权限 |
| 3 | 当前预约状态 | 仅 PENDING 且未删除 | CANCELED/FINISHED/VOIDED 拒绝；不新增预约状态 |
| 4 | 时间窗口 | 建议只在服务端时间窗口开放后至预约结束前签到 | 提前窗口 X 分钟、超时容忍、跨午夜及边界时间：**待裁决**。不把到达开始时间自动当作签到，不自动认定未签到为爽约 |
| 5 | 设备准入 | 设备存在、NORMAL、bookable=true | MAINTENANCE/FAULT/DISABLED/SCRAPPED 或 `bookable=false` 拒绝 |
| 6 | 用户资质 | 签到时目标用户对设备有 ACTIVE 且未过期资质 | 资质被撤销/过期拒绝；资格审核并发按行锁规则保证不能过期/撤销竞态放行 |
| 7 | 用户暂停 | 预约人当前不存在覆盖该设备的 ACTIVE 暂停（含 ALL） | ACTIVE 暂停拒绝；`end_time` 到期未人工解除仍拒绝，符合 H1 |
| 8 | 预约影响 | 对该预约没有 `PENDING` 或 `AUTO_RESTORED` 影响记录 | 任一未人工处理记录均拒绝；只有 `PROCESSED` 才继续。恢复设备不改变此门槛 |
| 9 | 同设备活动签到 | 同租户/设备无其他 OPEN 签到 | 已有其他预约 OPEN 时拒绝；设备行锁与唯一约束双防线 |
| 10 | 幂等/重复 | 同一预约、同一所有者重复请求返回既有 OPEN 记录，不再插入；已 CLOSED 则返回已结束业务错误 | 是否允许人工撤销/重新签到：建议不允许，**待裁决** |
| 11 | 审计 | 用服务端时间，保存操作者/租户/预约快照 | 客户端伪造时间/用户/设备被忽略或拒绝 |

### 建议错误码（符号名，编号未分配）

- 复用既有错误：预约不存在、设备状态不可预约、设备不可预约、无有效资质、用户暂停、`reservation` 状态不可操作（具体既有 08x/09x 常量由实施前核验）。
- 需要新增符号码：`INSTRUMENT_RESERVATION_CHECKIN_TIME_DENIED`、`...CHECKIN_IMPACT_PENDING`、`...DEVICE_HAS_ACTIVE_CHECKIN`、`...CHECKIN_ALREADY_CLOSED`、`...CHECKIN_PERMISSION_DENIED`。数值编码与前端文案应检查 `ErrorCodeConstants` 全表后分配；本报告不分配号码。
- 唯一键冲突只可在确认约束名、当前预约和 OPEN 记录都匹配后转为幂等响应；不可把任意 `DuplicateKeyException` 吞掉。

## 6. 事务、并发与租户隔离设计

### 6.1 推荐锁序

1. 锁外仅可做必要的 ID/目标设备探测；不使用该快照授权。与当前调整模式类似，事务开始后第一条数据库读/写应为 `InstrumentDeviceMapper.selectByIdForUpdate(deviceId)`，保留 34 号“事务内首个一致性读之前先设备锁”的 RR 快照论证。
2. 同一事务内重读预约并锁预约行（`SELECT ... FOR UPDATE`）；核对 tenant、状态、用户、设备与请求 ID；读取资格、暂停、影响和活动签到。
3. 条件插入签到记录；处理 MySQL 唯一键竞态；提交时保持预约行 `PENDING`。
4. 签到、取消、完成、作废、调整须使用可论证的统一锁序 `device → reservation → checkin`，并对原设备/目标设备按设备 ID 升序加锁。禁止某路径先锁预约、再锁设备，避免与签到互锁或形成死锁环。

### 6.2 必须联动的现有路径

当前取消/完成/作废使用 `executeInTransaction` 与预约状态条件更新，不锁设备；签到后预约仍 PENDING，若保持原代码便存在操作穿透。实施时必须决定并验证：

- 所有生命周期写路径统一取得设备行锁并检查 OPEN 签到，或者设计等价的条件写入/强约束；不得只在签到 Service 内查询 OPEN 状态。
- 活动 OPEN 签到期间，建议拒绝取消、调整、更换设备、作废；完成操作负责关闭签到并将预约状态转 FINISHED。若管理侧现有“任意时刻可取消”规则要继续适用，须明确紧急终止使用的独立操作、授权、原因和审计，不能把 active use 直接作为普通取消。
- 确定资格撤销、到期、用户暂停创建/解除与签到并发的读取/锁语义。暂停创建当前共用设备行锁；设备状态更新锁设备；资格审核/撤销与签到是否共享设备或资格行锁需在实施前静态核对并改成可证明的协议。
- 工单影响创建和恢复由设备状态/维修路径驱动。签到查询影响表时要在同一事务内使用当前读；有效状态为 PENDING/AUTO_RESTORED。管理员人工处理与签到同时发生时，明确先提交的操作生效，并用条件更新验证状态。

### 6.3 唯一约束与租户

建议独立表至少有：

- `UNIQUE (tenant_id, reservation_id)`：同一预约最多一条签到会话，保证重复请求不会重复登记。
- 同设备最多一个 OPEN 使用：优先由设备行锁串行化并在锁内查询；另建议增加数据库级唯一防线。MySQL 设计候选是 `active_device_id` 可空列（OPEN 时等于 device_id，关闭时 NULL）并加 `UNIQUE (tenant_id, active_device_id)`，需先验证目标 MySQL 版本、H2 MySQL 模式兼容性、空值语义及是否允许跨租户同设备 ID；**不得直接套用/执行**。也可用独立活动占用表，但会增加第二张表及清理语义。
- 所有 DO 继承 `TenantBaseDO`、所有读写走租户拦截器；唯一键必须包含 `tenant_id`。唯一键本身不代替 service 记录级授权；跨租户 ID 返回 not-exists。
- 不做物理删除；关闭、纠错记录采用审计字段/明确的撤销动作（如经裁决允许）保留证据。

## 7. 与 INSTRUMENT-03 的兼容性

| 现有规则/路径 | 兼容要求 |
|---|---|
| `status` 四态与 C1 | 不增加/改变状态；不按预约时间自动签到、开始、完成或爽约；拒绝签到不写信用分。 |
| C3 时段占用 | PENDING 在签到前后都占用原计划时段；FINISHED 保留已使用历史；不通过签到记录释放/重占预约时间。 |
| P1–P9 创建/调整 | 创建流程不变；签到不开放 C7。若调整后目标预约已有 OPEN 签到，必须拒绝；调整服务链路仍须按设备 ID 升序锁。 |
| 取消/作废/完成 | 现有仅 PENDING 条件更新必须补活动签到约束，否则签到后仍可 cancel/void；finish 应在完成事务中关闭 OPEN 记录并将服务端签到时间纳入实际起止，规则待负责人裁决。 |
| 资质/暂停 | 签到重验 P4/P5；过期资质/ACTIVE 暂停拒绝。不得更改暂停的人工解除语义或资质状态机。 |
| 设备 FAULT/MAINTENANCE/DISABLED/SCRAPPED | 与设备 NORMAL/bookable 条件一起校验；不安全状态拒绝。设备恢复仅使设备可用，不清除 AUTO_RESTORED 影响。 |
| 信用及异常使用 | C1 无自动爽约/自动扣分；任何信用流水仍走现有授权人工流程。 |
| 前端与菜单 | 只在现有我的预约/预约管理中加入口及子状态；按钮不承担访问控制。推荐复用 `reservation:query` + Service 限本人，避免增设菜单 ID；若需专属 permission/menu，另行裁决。 |
| 时间与时区 | 代码使用 `LocalDateTime`；需确定业务时区、时钟来源、分钟精度、DST/跨日处理和边界统一规则。当前运行时 DB/session/app 时区未核实，UNKNOWN。 |

## 8. SQL 58/59 静态复核

### 8.1 SQL 58 五表字段/索引

| 表 | DO/Mapper 对应 | 当前索引及核对建议 |
|---|---|---|
| `lab_instrument_fault_report` | `InstrumentFaultReportDO` / `InstrumentFaultReportMapper` | 主键；`idx_device_id`、`idx_reporter_user_id`、`idx_confirm_status`。建议评估租户+设备/状态和租户+提交人分页查询索引。 |
| `lab_instrument_repair_order` | `InstrumentRepairOrderDO` / Mapper | 主键；`uk_repair_tenant_no(tenant_id,order_no)`；device/assignee/status/source fault 索引。评估租户维度组合分页索引。 |
| `lab_instrument_repair_history` | `InstrumentRepairHistoryDO` / Mapper | 主键；`uk_repair_history_no(tenant_id,repair_order_id,history_no)`、工单索引。只增不改历史。 |
| `lab_instrument_device_status_history` | `InstrumentDeviceStatusHistoryDO` / Mapper | 主键；device、related repair order 索引；评估 tenant+device/time 的查询组合。 |
| `lab_instrument_reservation_impact` | `InstrumentReservationImpactDO` / Mapper | 主键；`uk_tenant_impact_key(tenant_id,impact_key)`、reservation/device/handle_status 索引。R2 已将 impact_key 唯一键加入设计；其冲突异常恢复路径仍需集成验证。 |

五表字段与 Java 属性采取驼峰/下划线映射，审计和 `tenant_id/deleted` 继承 `TenantBaseDO`。SQL 58 是 `CREATE TABLE IF NOT EXISTS` 建表脚本，不能升级已有同名旧表；执行前须对比现存 schema。新签到表不应塞入 SQL 58 后直接执行，需单独迁移稿并与旧表版本兼容评审。

### 8.2 SQL 59 静态值、权限范围

- 既定菜单：13684 页面、13685 submit、13686 fault-report admin、13687 repair handle、13688 repair admin；父菜单 13600；目录祖先 13478。
- 维修角色 909；套餐 114；租户 162；存量角色 904/906/908。目标库中这些 ID 是否空闲、属于预期租户及套餐是否匹配：**UNKNOWN**。
- 页面组件已修订为 `lab/instrument/repair-order/list`，路径 `repair-manage`，与现有前端维修列表组件对应。R3 签到若复用预约页面不涉及上述维修组件。
- 当前脚本设计中 904 普通用户只获得页面+submit；906 `lab_admin` 获得全部 5 菜单；908 设备负责人不自动获得维修权限；909 维修负责人获得祖先、页面、submit、handle，不授予 fault admin/repair admin/恢复验收。目标库角色的实际名称、状态、租户归属尚待核验。不会因为签到功能扩展维修角色。
- 脚本计划对套餐 114 做 JSON 追加；全部写入要由执行人在同一事务中包裹，SQL 本身不含 BEGIN/COMMIT。SQL 直写绕开菜单/角色 `@CacheEvict`，文档要求通过应用保存刷新缓存；不得手工 Redis 清理。
- 回滚依赖固定 JSON 数组下标 0–374 的列表再用 `JSON_ARRAYAGG/JSON_REMOVE` 处理，脚本本身注明数组超长/NULL 可能失败；还可能改变 JSON 数组顺序。菜单/role_menu 固定范围 DELETE 有误删后来合法授权风险。应先备份和在隔离库实演回滚，不可视为生产自动回滚保证。
- 任何目标数据库表结构、菜单存在性、角色/套餐归属、SQL 已执行状态都 **UNKNOWN**；58/59 均未执行。

## 9. 测试依赖盘点及隔离方案

### 9.1 当前可见测试形态

- `application-unit-test.yaml` 配置 H2 `jdbc:h2:mem:testdb;MODE=MYSQL` 及 Redis `127.0.0.1:16379`。配置指向测试端口并不证明该 Redis 存在/隔离，也不授权本任务连接。
- INSTRUMENT-03 的 `Instrument03BBookingRuleWindowTest`、`Instrument03ConcurrencyTest`、`Instrument03CReservationCreateTest`、`Instrument03DataLayerTest`、`Instrument03DLifecycleTest`、`Instrument03R2AdjustT1T2Test` 多数继承 `BaseDbUnitTest`，用 H2；Redis 单号/锁在创建或生命周期测试中由 `@MockBean` 替代；DataLayer 测试对 Redis 单号使用内存 stub，未要求外部 Redis。`Instrument03ConcurrencyTest` 是 H2 多线程真实 Mapper/事务锁测试，不等同真实 MySQL InnoDB。
- `Instrument03LockCoordinatorTest`、`Instrument03R2PermissionAnnotationTest`、`Instrument03IsolationGuardTest` 是普通单测/反射测试，不需业务 DB/Redis。
- 模块其他业务测试及完整 Maven profile 是否有外部服务访问，未对每个调用链作穷尽运行证明：**UNKNOWN**。不得直接把整个 Maven 测试套件连同 `application-unit-test` Redis 配置运行。
- `Instrument03IsolationGuard` 代码会核对 JDBC URL/Redis 地址，但本次静态搜索只发现守卫类和它自身单测/文档注释，未发现其被全局 `@TestExecutionListeners` 或 `spring.factories` 注册。执行完整回归前必须核实/补齐测试 harness 注册；不得仅因守卫文件存在就认定当前 suite 自动 fail-closed。
- `application-instrument-03-test.yaml` 和 `instrument03-test-env/docker-compose.yml` 是隔离 MySQL/Redis 配置设计；文档记录其容器未启动。本轮没有读取环境凭据，也没有启动容器或连接隔离实例。

### 9.2 建议的测试分层（后续授权后）

1. **静态/单元层**：Mapper/Controller 权限字面值、错误码、规则边界、幂等服务纯 Mockito；没有网络或外部连接。
2. **H2 服务集成层**：`BaseDbUnitTest` + 测试 schema 增加独立签到表；模拟用户/权限/Redis DAO；确保 DataSource 明确为内存 H2，禁用/模拟所有 Redis 客户端。用 `Clock` 固定时间测窗口边界、资质过期、暂停、影响状态及错误行为。
3. **H2 并发层**：多线程分别验证同预约重复提交只生成一个记录、同设备不允许两个 OPEN、check-in 与 cancel/adjust/void/finish 竞争只有满足锁序的一方提交；确认 H2 行锁并发证据只用于代码阶段。
4. **隔离 MySQL 层**：负责人另行授权启动已准备的隔离环境后，检查 SQL 58/独立签到 DDL/SQL59 的预期脚本；以新测试库导入基线而非目标库；验证 MySQL RR、`FOR UPDATE` 首读、唯一键冲突名、事务回滚、DDL/JSON 回滚与租户拦截器。Redis 若非该用例必需应 Mock；如需验证单号，仅连明确隔离地址。不得连接真实 `labplatform`/生产 Redis。
5. **全量 Maven 回归前置门槛**：逐类检查外部 Client/Redis/HTTP/文件调用；使用 H2 与 Mock；注册并验证隔离守卫对 master/slave/Redis 所有生效属性 fail-closed；保存实际命令和结果。无法证明安全的测试标记 HOLD，不运行。

## 10. 必须由负责人裁决的问题

下列规则均未由本报告冻结。建议负责人逐项答复或认可推荐项后，另发实施授权。

| ID | 待裁决 | 推荐讨论起点 / 影响 |
|---|---|---|
| U6-R3-01 | 签到主体 | 推荐预约人本人；管理员/设备负责人是否可代签？代签需要原因、实际使用者身份字段和审计。维修负责人不能据其维修角色替用户签到。 |
| U6-R3-02 | 提前/迟到时间窗 | 建议默认仅 `[start_time, end_time)`，即不提前实际使用；若需提前签到，要决定是否允许预约时段外实际使用及最早提前量。超时是否拒绝或人工覆盖需裁决。 |
| U6-R3-03 | 已签到后生命周期 | 推荐 OPEN 时禁止取消、调整、更换设备和作废；现有管理侧任意时刻取消/管理调整的权限语义如何兼容？紧急终止是否另建动作？ |
| U6-R3-04 | 签退/结束 | 当前无用户签退入口，完成由管理范围角色手工登记。签到记录何时关闭？继续复用 finish 还是允许预约人主动结束？谁有权限和可否补录？ |
| U6-R3-05 | 重复及撤销 | 推荐 OPEN 重复请求返回原记录、CLOSED 后拒绝重签；是否允许管理员撤销错误签到，以及如何保留原记录？ |
| U6-R3-06 | 管理影响 | 建议 PENDING 与 AUTO_RESTORED 都阻断；仅 PROCESSED 放行。人工处理记录的“已通知/改期/取消/允许继续使用”是否需要不同处理结果字段？当前 `handleNote` 单字段不足以机器区分允许继续使用。 |
| U6-R3-07 | 资质/暂停并发 | 确认签到时实时要求 ACTIVE 且未过期，无 ACTIVE 暂停；签到与同时发生的撤销/暂停创建/解除由哪个串行顺序裁定。 |
| U6-R3-08 | 设备准入 | 确认只允许 `NORMAL && bookable`，其他状态一律拒绝；是否还需检查维修单状态，即使设备状态数据异常仍有未关闭工单时也拒绝。 |
| U6-R3-09 | 同设备活动会话 | 推荐一个 tenant+device 同时最多一个 OPEN check-in；如果上一个用户未结束，谁能强制收口以及是否通知？ |
| U6-R3-10 | 时间和租户 | 确认业务时区、时间戳精度、跨日和 DB session timezone；同设备/租户唯一键模型及共享设备跨租户情况需由 DBA 确认。 |
| U6-R3-11 | 权限码/菜单 | 推荐沿用 `reservation:query` 进入现有我的预约页、Service 限本人，不增菜单 ID；如果要求专属 `reservation:checkin`，需重新评估权限码、角色授权和菜单 SQL。 |
| U6-R3-12 | 兼容历史 | 旧 PENDING 预约可以在新功能发布后签到但不回填；旧手工 finish 是否继续允许无签到记录，并如何处理 actualStartTime 数据质量？ |
| U6-R3-13 | C7/发布闸门 | 再次确认签到功能本身不启用/修改预约创建开关，不把签到验收解释成开放预约创建。 |

## 11. 预计实施拆分与影响文件（非本轮修改）

仅在负责人完成规则裁决并另行授权后实施，顺序建议：

| 阶段 | 预计影响文件/范围 | 验收重点 |
|---|---|---|
| R3-01 规则冻结/错误码 | 新版 INSTRUMENT-03/06 规则与状态机文档；`ErrorCodeConstants` | 固定签到主体、窗口、管理影响、finish、活动会话规则；不改预约四态/C7。 |
| R3-02 DB/Mapper/DO | 新 `InstrumentReservationCheckInDO`、Mapper、独立测试 schema；单独签到 DDL 设计稿；必要时修订 SQL58/新 SQL69（编号另定） | tenant+reservation 幂等唯一键、活动 device 唯一防线、老数据无回填，MySQL/H2 兼容审查。 |
| R3-03 Service/Controller | 新 CheckIn Service/Controller/Req/Resp VO；`InstrumentReservationServiceImpl` lifecycle；`InstrumentDeviceServiceImpl`/资质/暂停读校验协作 | 全链安全校验、统一 device→reservation→checkin 锁序、错误码、记录级授权；无 STARTED 状态/C7 变化。 |
| R3-04 并发收口 | `InstrumentReservationMapper` 条件更新、`ReservationLockCoordinator` 协议（若扩展）、生命周期服务及 MySQL Mapper 测试 | checkin/cancel/adjust/void/finish 与设备/暂停/资格变更交错；死锁、重复键和事务回滚。 |
| R3-05 前端 | `src/api/lab/instrument/reservation`；`src/views/lab/instrument/my-reservation/index.vue`、可能的详情组件/VO | 本人预约入口、子状态、错误提示；按钮权限只做显示；不新增菜单 ID 除非另裁决。 |
| R3-06 测试与隔离 | 新 `Instrument03CheckIn*Test`；`Instrument03DLifecycleTest`、`Instrument03ConcurrencyTest`；测试隔离守卫注册/CI profile | H2 单测/服务/并发、全量安全回归，再单独批准隔离 MySQL 验证。 |
| R3-07 交付核验 | SQL/菜单/权限静态核对报告；部署计划与回滚步骤 | 数据库/菜单/角色/Redis/运行 Profile 仍需实际隔离或目标环境授权验收；不以代码测试代替生产部署验收。 |

## 12. 最终判定

**DESIGN HOLD**：独立签到记录且保持预约四态是可行候选，但 C1 的“第一期无签到”属于当前冻结规则，开放签到本身需要负责人确认；签到/活动使用与现有管理侧任意取消、调整、作废存在实质冲突，结束会话的操作主体和时间窗口也尚未明确。SQL 58/59 风险已静态列明但未执行；全量测试环境的隔离守卫尚未确认自动注册。

**停止于设计阶段，等待负责人裁决第 10 节，并单独授权后续代码/SQL 设计实施。**

## R4 裁决取代说明（2026-10-20）

本文件的签到机制设计方向及 DESIGN HOLD 是 R3 阶段建议，现由负责人正式裁决取代。第一期不新增签到、签退、开始使用、活动会话、STARTED/IN_USE/OPEN/CLOSED 状态、数据表、接口、菜单或硬件控制。不得按本文建议实施签到方案。U6 改按预约影响管理闭环验收，最新规则与实测结论见 57 号补充及 69 号报告。R3 内容保留为历史设计记录，不代表当前待裁决项。
