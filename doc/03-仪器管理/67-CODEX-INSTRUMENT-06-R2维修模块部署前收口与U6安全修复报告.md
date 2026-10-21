# INSTRUMENT-06 R2 维修模块部署前收口与 U6 安全修复报告

检查日期：2026-10-20  
范围：本地源码、测试、SQL 设计稿与历史交付文件静态核对；本轮未连接目标数据库或 Redis，未启动服务/容器。

## 1. 执行结论

| 级别 | 结论 | 说明 |
|---|---|---|
| CODE | **CODE PASS（有边界）** | 已按当前冻结规则修复记录级详情授权、前后端契约、详情上报入口及预约影响幂等设计。历史/过程读取与故障撤回没有后端契约，已从前端移除，不伪造成功。 |
| TEST | **TEST HOLD** | 8 个 I06 定向类共 60 项通过；前端全量 TypeScript 检查仍因仓库其他模块错误失败；未运行可能连接 Redis/H2 的整个 lab 模块测试。 |
| U6 | **U6 HOLD / FUNCTIONAL HOLD** | 预约影响标记及管理员人工处理已覆盖，但没有实际预约签到/开始使用入口可调用影响检查和设备状态检查。未增加 STARTED 或新接口。 |
| SQL | **SQL HOLD** | SQL 58/59 仅静态检查/设计修订，均未执行；目标环境、表结构、菜单 ID/角色 ID 状态均 UNKNOWN。 |
| 部署 | **DEPLOYMENT HOLD** | 代码及部分定向测试结果不能证明数据库、菜单、权限、运行时配置或生产部署完成。 |

## 2. 保护性预检与改动保护

### 2.1 仓库状态（开始时）

| 仓库 | 分支及远端差异 | 开始前已有本地状态 |
|---|---|---|
| `ruoyi-vue-pro` | `master`，相对 `origin/master` ahead 7 | `.gitignore` 已修改；`instrument03-test-env/.env`、`.env.example` 和 `yudao-ui/yudao-ui-admin-vue3/node_modules/` 未跟踪。未读取或披露 `.env` 内容。 |
| `yudao-ui-admin-vue3` | `master`，相对 `origin/master` ahead 6 | `.env.prod` 已修改（10 行差异），本轮未读取其中值或修改该文件。 |

差异统计命令：`git status --short`、`git diff --stat`、`git diff --check`。`git diff --check` 无空白错误；Git 显示若干 LF→CRLF 提示。提交领先量为预检时观测值，本轮未 fetch。

前后端 I06 文件在预检时没有已存在的改动；开始时存在的 `.gitignore`、`.env.prod`、未跟踪环境文件和 `node_modules` 均保留。没有暂存、提交、推送、重置或清理文件。

### 2.2 保护配置与运行环境

- `application-local.yaml` 中 `reservation.create-enabled` 为 `false`；`application-instrument-03-test.yaml` 中该配置为 `true`。本轮未修改。运行时实际激活 Profile：**UNKNOWN**。
- 测试配置 `yudao-module-lab/src/test/resources/application-unit-test.yaml` 配置 H2 内存库及 Redis `localhost:16379`。本轮选取的 8 个 I06 定向类使用 Mockito，没有 Spring 上下文、数据库或 Redis访问。整个模块测试中存在 `@Import` 集成/上下文测试，因无法将其 Redis 和外部副作用风险证明为零，未运行。
- 没有连接 `labplatform`、数据库或 Redis；没有运行 SQL 58/59；没有启动、停止或重启服务/容器。

## 3. 规则、已有实现、缺陷与待裁决清单

### 3.1 已冻结规则

依据 `57-INSTRUMENT-06正式规则冻结与状态机设计.md`：普通用户可上报，管理员确认/驳回；由管理员手动指定维修负责人；维修负责人只承担分配到的维修工作，不因此获得资质、信用、暂停或预约管理权限；预约保持原状并标记受影响，不自动取消；设备恢复后的预约后续处理由管理员负责；最终恢复验收限全局管理员；预约状态机没有 STARTED，本轮不改变状态机或 C7。

菜单 ID 13684–13688、角色 ID 909 作为 SQL 设计稿中的既定值保留，未另行分配或变更。

### 3.2 已有实现（经源码核对）

- `InstrumentFaultReportController`：`/submit`、`/confirm/{id}`、`/page`、`/my-page`、`/get`。
- `InstrumentRepairOrderController`：`/assign/{id}`、`/start/{id}`、`/record/{id}`、`/submit/{id}`、`/restore-approve/{id}`、`/restore-reject/{id}`、`/cancel/{id}`、`/reopen/{id}`、`/page`、`/my-assigned`、`/get`。
- `InstrumentReservationImpactController`：`/page`、`/handle/{id}`、`/get`。后端处理状态为 `PENDING`、`AUTO_RESTORED`、`PROCESSED`。
- `InstrumentReservationServiceImpl` 中已有预约取消、完成路径；状态枚举为 `PENDING / CANCELED / FINISHED / VOIDED`。未发现实际签到或预约开始使用 API；维修工单 `/start/{id}` 是“开始维修”，不是预约设备使用。

### 3.3 实际缺陷与本轮处理

- 详情接口原本只依赖 Controller 权限/租户隔离，缺少记录级服务授权；已在故障报告、维修单 Service 中增加访问规则和无效/不存在记录处理，并保留租户查询隔离。
- 前端严重度向后端发送 `LOW/MEDIUM/HIGH/CRITICAL`，而 DO/服务约定 `L/M/H/C`；现已转换映射。我的故障分页此前未按请求参数过滤；已补后端状态、严重度筛选及前端分页参数。
- 前端曾调用后端不存在的撤回、历史/过程读取、创建等接口或展示不存在的字段；已移除相关假调用和 UI。维修详情明确告知历史读取 API 尚未提供。
- SQL 59 菜单组件原指向不存在的 `lab/instrument/repair-manage/index`；已修订为现有 `lab/instrument/repair-order/list`。菜单及权限是否部署仍 UNKNOWN。
- 预约影响 SQL 原无幂等键；SQL 58 加入 `impact_key` 及租户内唯一索引。服务只标记未来且状态为 `PENDING` 的预约；过去但遗留 `PENDING` 与其他状态不会被标记。`AUTO_RESTORED` 仍视为需人工处理/有效影响，处理后转为 `PROCESSED`。

### 3.4 待裁决

U6 “设备不能在不安全状态下实际开始使用”没有系统内开始使用/签到入口可承载服务端拦截。需要产品/负责人选择：

1. 明确预约外部人工签到/物理管控流程，并确认软件只负责留存受影响预约；或
2. 单独授权设计一个预约开始使用入口，确定状态与角色、错误语义、影响/设备状态检查和迁移方案，再评估是否需要调整冻结状态机。

在作出选择前，保持 **FUNCTIONAL HOLD**。不因未被调用的 `isReservationCurrentlyImpacted(reservationId)` 辅助方法而判定闭环完成。

## 4. R2-01 API 契约对照表

| 功能 | 后端契约 | 前端处理 | 结论 |
|---|---|---|---|
| 故障上报 | `POST /fault-report/submit`；`deviceId/faultTime/phenomenon/description/severity/attachmentUrl/contactPhone` | 仅发送后端字段，严重度转换为 L/M/H/C；详情设备 ID 可预填 | PASS |
| 故障确认/驳回 | `POST /fault-report/confirm/{id}`；body `{confirm, opinion}` | 两种动作同路径，确认 true/驳回 false | PASS |
| 故障分页/我的分页 | `GET /fault-report/page`、`/my-page`；`pageNo/pageSize/deviceId/confirmStatus/reporterUserId/severity` | 参数映射一致；补全 my-page 服务端过滤 | PASS |
| 故障详情 | `GET /fault-report/get?id=` | 按 ID 读取并映射 DO 字段 | PASS（另见权限矩阵） |
| 故障撤回、历史 | 当前后端无撤回、历史读取 API | 移除入口/调用 | HOLD（如业务仍需要，需另行定义接口与权限） |
| 工单派工 | `POST /repair-order/assign/{id}`；body `{assigneeUserId, reason?}` | 发送 `assigneeUserId`；移除备注输入，因为 Service 不保存 reason | PASS |
| 开始维修/过程记录/提交结果 | `POST /start/{id}`；`/record/{id}` body含`detail`等；`/submit/{id}` body含`result` | 路径及必要字段对齐，不再发送未支持字段 | PASS |
| 恢复验收/驳回验收 | `POST /restore-approve/{id}` body `{opinion}`；`/restore-reject/{id}` body `{reason}` | 字段、路径对齐；两种意见均要求非空 | PASS |
| 工单取消 | `POST /cancel/{id}?reason=` | query 参数 reason | PASS |
| 工单分页/我的维修单/详情 | `GET /page`、`/my-assigned`、`/get?id=` | 当前 API 一致 | PASS |
| 工单历史/过程列表、手工创建 | 当前无对应读取/创建 API | 详情页删除虚构时间线，显示能力提示；移除不存在的创建入口 | HOLD（保留明确功能边界） |
| 预约影响分页/处理 | `GET /reservation-impact/page`；`POST /handle/{id}` body `{handleNote}` | 参数名、路径、状态处理一致 | PASS |

## 5. R2-02 记录级权限矩阵

服务层在 Controller 权限注解之后再次校验记录范围。Controller 查询详情允许相应权限进入服务层；前端按钮可见性不作为安全边界。

| 角色/关系 | 故障报告详情 | 工单详情 | 结果/覆盖测试 |
|---|---|---|---|
| 提交人本人 | 可读自己的报告 | 可读该报告关联工单 | PASS |
| 普通用户读取他人报告 | 拒绝 | 不适用 | PASS |
| 普通用户改 ID 读取他人工单 | 拒绝 | 拒绝 | PASS |
| 被分配维修负责人 | 按工单分配关系可读工单 | 可读分配给自己的工单 | PASS |
| 对应设备的业务管理员 | 仅其设备范围可读 | 仅其设备范围可读 | PASS；范围外拒绝 |
| `lab_admin` / `super_admin` | 按全局管理范围可读 | 按全局管理范围可读 | PASS |
| 跨租户记录 | 拒绝；租户 Mapper 查询不返回记录 | 同左 | PASS |
| 无效 ID、无记录 | 统一按无记录/非法 ID错误拒绝 | 同左 | PASS |

测试文件：`Instrument06DetailAuthorizationTest.java`；运行命令及执行结果见第 8 节。角色的服务级范围依据现有 `InstrumentScopeSupport` 判断；没有测试或新增范围授权。

## 6. R2-03 前端故障上报入口

仪器设备详情页已增加“上报故障”入口，只有现有故障提交或管理员权限之一可见；打开页面时携带 `deviceId`，提交页校验正整数 ID 并加载对应设备，缺失或设备不可访问时不允许正常提交。后端 `/submit` 保留独立权限注解和设备有效性校验。

前端静态隐藏路由添加到 `src/router/modules/remaining.ts`，包括提交、我的上报、故障管理、维修负责人列表、工单详情及预约影响列表。SQL 59 组件静态路径现对应已存在的 `repair-order/list.vue`。动态菜单/角色授权 SQL 未执行，菜单入口部署状态 UNKNOWN。

## 7. R2-04/R2-05 U6 与影响状态

- 已对全仓预约控制器/服务/状态枚举和设备预约页面入口进行搜索；可见预约状态为 `PENDING / FINISHED / CANCELED / VOIDED`。未发现“签到/开始实际使用”入口。维修工单状态 `IN_PROGRESS` 仅代表维修开始。
- `isReservationCurrentlyImpacted` 当前定义于预约影响服务，搜索未发现其调用点。该方法不构成安全拦截。
- 受影响预约生成只包含未来 `PENDING` 且带有效开始时间的预约；历史残留 `PENDING` 因开始时间已过去而跳过。其他状态不进入影响表。
- 维修确认/设备状态变更路径使用锁定设备和状态事件生成影响记录；`impact_key` 唯一索引为 `(tenant_id, impact_key)`，用于阻止同一事件重复生成有效影响记录。恢复时 `PENDING → AUTO_RESTORED`；该状态保留给管理员后续处理，只有人工处理后 `→ PROCESSED`。AUTO_RESTORED 仍参与重复有效影响查询。
- 影响时间使用服务端 `LocalDateTime.now()` 与预约 `LocalDateTime` 比较。数据库/应用时区统一性未在本轮运行时核实：**UNKNOWN**。
- R2-05 的“不能实际开始使用”缺口仍是 **FUNCTIONAL HOLD**；未增加 STARTED、接口或状态转换。

## 8. 测试与验证结果

### 8.1 后端定向测试

安全性依据：所选 I06 测试类使用 Mockito，不启动 Spring 容器，不访问真实数据库/Redis。

命令：

```powershell
mvn -pl yudao-module-lab '-Dtest=Instrument06ConcurrencyTest,Instrument06DetailAuthorizationTest,Instrument06FaultReportServiceTest,Instrument06QualificationDuplicateActiveTest,Instrument06RepairOrderServiceTest,Instrument06ReservationImpactTest,Instrument06ScopePermissionTest,Instrument06TenantIsolationTest' test
```

结果：**BUILD SUCCESS；Tests run: 60, Failures: 0, Errors: 0, Skipped: 0**。包含详情授权矩阵和未来/过去/非 PENDING、AUTO_RESTORED、重复影响行为测试。

本轮更早的尝试有一次测试编译错误（测试未同步新 `getMyPage` 参数），一次 mock 数据未模拟 mapper 状态过滤导致影响测试失败，及一次并发 mapper mock 未串行造成竞争测试不稳定；已修正调用、显式状态过滤和测试锁后，上述最终定向命令通过。第一次 Maven 命令在 PowerShell 参数解析阶段失败，未运行测试。

这些已被后续运行覆盖/替代的中间尝试，其逐字控制台错误文本未保存在当前可读取日志中；上文仅记录可核实的失败类别，不补写猜测的“原文”。最终命令的 Surefire 汇总为本节所列结果。

### 8.2 前端 TypeScript

命令：`pnpm run ts:check`。

最终复跑结果：退出码 1；I06 文件没有 TypeScript 错误。全量检查仍因以下非 I06 错误失败，错误输出原文包含：`error TS6133: 'Dayjs' is declared but its value is never read.`、`error TS2345: Argument of type 'number' is not assignable to parameter of type '0 | 1 | 2'.`、`error TS2345: Argument of type 'number' is not assignable to parameter of type '5 | 6 | 7'.`、`error TS2353: Object literal may only specify known properties, and 'surveyType' does not exist in type 'PageParam'.`，以及 Plasmid 页面的 `Type 'string | undefined' is not assignable...`、`Type 'undefined' cannot be used as an index type`、未使用 `t`。全量 TS 状态 **HOLD**，未修改无关模块。

脚本使用 `node_modules/.cache/vue-tsc/tsconfig.tsbuildinfo` 作为增量检查缓存。`node_modules` 在预检时已是未跟踪目录且保留未清理；由于没有该缓存文件的预检快照，缓存文件是否在本轮被新建或更新无法确认，标记 **UNKNOWN**。未手动覆盖、恢复或清理该目录内容。

未运行全量 lint 或 production build；没有修复无关模块错误。

### 8.3 模块完整 Maven 测试

未运行。`yudao-module-lab` 的集成测试包含 Spring 测试上下文；测试配置可尝试访问 `localhost:16379` Redis，无法证明全模块测试不触及外部状态。因此只执行安全的 Mockito 定向类。全模块回归状态：**HOLD / 未执行**。

## 9. SQL 58/59 静态核对

### 9.1 五表到 DO/Mapper/DDL 映射

| 表 | DO / Mapper | 核对要点 |
|---|---|---|
| `lab_instrument_fault_report` | `InstrumentFaultReportDO` / `InstrumentFaultReportMapper` | `device_id`、`reporter_user_id`、时间、现象/描述、严重度 L/M/H/C、附件/电话、确认字段、关联工单及 TenantBaseDO 审计列；DDL 严重度注释已修订为 L/M/H/C。 |
| `lab_instrument_repair_order` | `InstrumentRepairOrderDO` / `InstrumentRepairOrderMapper` | 工单号、设备/房间、来源故障、状态、负责人及指派/维修/验收时间、恢复信息和租户审计字段；租户+工单号唯一索引。 |
| `lab_instrument_repair_history` | `InstrumentRepairHistoryDO` / `InstrumentRepairHistoryMapper` | 工单、工单内流水号、动作/状态前后值、操作者、时间、detail、维修原因/措施/备件/附件；租户+工单+流水号唯一。 |
| `lab_instrument_device_status_history` | `InstrumentDeviceStatusHistoryDO` / `InstrumentDeviceStatusHistoryMapper` | 设备、状态前后值、动作、操作者、时间、原因、维修/故障关联及租户审计列。 |
| `lab_instrument_reservation_impact` | `InstrumentReservationImpactDO` / `InstrumentReservationImpactMapper` | 预约/设备/故障/工单关联、`impact_key`、原因和时间、PENDING/AUTO_RESTORED/PROCESSED、人工处理字段及租户审计列。 |

`impact_key` 新增非空列与唯一键 `(tenant_id, impact_key)`，设计上防同一事件重复插入。执行前必须核实已有表/数据；若同名表存在但缺该列，`CREATE TABLE IF NOT EXISTS` 不会升级现存表，需另行设计迁移与冲突处理。唯一约束可能使并发重复插入返回唯一键异常，调用方是否将冲突降级为成功语义需在真实 Mapper 集成环境验证。

### 9.2 SQL 59 菜单/角色映射与风险

- 设计稿固定菜单 ID `13684–13688`、维修角色 ID `909`，套餐 ID `114`，涉及角色 `904/906/908/909`，租户 `162`；以上仅为 SQL 文件设计常量，目标环境值均 UNKNOWN。
- 前端组件路径已从不存在的 `lab/instrument/repair-manage/index` 调整为 `lab/instrument/repair-order/list`；其余菜单权限码需与控制器 `@PreAuthorize` 逐条核验并在真实权限树上验收。真实角色授权范围/动态菜单缓存未知。
- 执行前风险：固定菜单/角色/套餐 ID 可能冲突；现存表/菜单或租户数据可能不符合预检假设；DDL 的 `IF NOT EXISTS` 不能验证既有表结构；套餐 JSON 追加依赖 `JSON_VALID` 和字段非 NULL；脚本需保持同一事务执行，否则菜单、角色、套餐关联可能部分完成；DDL 自动提交行为需按实际数据库版本确认。
- 回滚风险：脚本通过 JSON 数组位置重建/移除套餐菜单项，注释已说明数组超长或 NULL 时可能失败；固定范围角色菜单回退也可能误删后续合法授权。必须先备份并在隔离环境演练，不能把当前设计稿视为可直接生产执行。
- SQL 58、59 **未执行**。数据库表结构、SQL 执行记录、菜单、角色、套餐和 Redis 菜单缓存状态全部 **UNKNOWN**。

## 10. 历史 60–66 号交付报告核对

实际存在文件：`60-INSTRUMENT-06后端开发交付报告.md`、`61-INSTRUMENT-06前端开发交付报告.md`、`62-INSTRUMENT-06自动化测试与回归报告.md`、`63-INSTRUMENT-06部署前预检与阻断项报告.md`、`64-INSTRUMENT-06客户维修流程操作指南.md`、`65-INSTRUMENT-06-R1部署阻断修复与专项测试报告.md`、`66-INSTRUMENT-06-R1-SQL执行前最终核验报告.md`。

- 60/61 对“100% 完成”描述过宽：实际 API 缺项、前端假调用/字段不匹配和设备详情入口待办已由本轮对照确认；本轮完成的前端入口也不代表菜单已经部署。
- 62 的 243/243 是历史报告记载，本轮没有复跑全部 243 项。它不作为本轮测试证据；本轮只重新跑了 60 个 I06 定向测试。
- 63 已明确记录 DEPLOYMENT HOLD 和无 STARTED 入口的 U6 功能阻塞，与本轮静态检查一致。
- 64 的操作说明假设菜单/运行环境部署完成后方可使用，不能作为已部署证明。
- 65 的 R1 专项测试/状态结论为历史记录；其 U6 影响记录已实现部分不等于实际开始使用拦截已经接入。
- 66 对数据库的历史核验描述不能证明本轮或当前目标环境状态；本轮未连接目标库，数据库及 SQL 执行状态标记 UNKNOWN。

## 11. 本轮文件变更清单

### 后端仓库 `E:\lixin\dev\ruoyi-vue-pro`

- `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument/InstrumentFaultReportController.java`
- `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument/InstrumentRepairOrderController.java`
- `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument/vo/repair/FaultReportPageReqVO.java`
- `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/dataobject/instrument/InstrumentReservationImpactDO.java`
- `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/mysql/instrument/InstrumentReservationImpactMapper.java`
- `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentDeviceServiceImpl.java`
- `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentFaultReportService.java`
- `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentFaultReportServiceImpl.java`
- `yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentRepairOrderServiceImpl.java`
- I06 测试：新增 `Instrument06DetailAuthorizationTest.java`；修改 `Instrument06ConcurrencyTest.java`、`Instrument06FaultReportServiceTest.java`、`Instrument06RepairOrderServiceTest.java`、`Instrument06ReservationImpactTest.java`、`Instrument06TenantIsolationTest.java`。

### 前端仓库 `E:\lixin\dev\yudao-ui-admin-vue3`

- `src/api/lab/instrument/fault-report/index.ts`
- `src/api/lab/instrument/repair-order/index.ts`
- `src/api/lab/instrument/reservation-impact/index.ts`
- `src/router/modules/remaining.ts`
- `src/views/lab/instrument/device-detail/index.vue`
- `src/views/lab/instrument/fault-report/admin-list.vue`、`my-list.vue`、`submit.vue`
- `src/views/lab/instrument/repair-order/assign.vue`、`detail.vue`、`list.vue`、`my-assigned.vue`、`restore-approve.vue`
- `src/views/lab/instrument/reservation-impact/list.vue`

### 文档/SQL

- 修改 `58-INSTRUMENT-06数据库DDL设计稿.sql`：严重度注释改为与枚举一致的 L/M/H/C。
- 修改 `59-INSTRUMENT-06菜单与角色授权设计稿.sql`：组件路径指向现有工单列表页面，未修改菜单 ID/角色 ID。
- 新增本报告。

开始前既有 `.gitignore`、`.env.prod`、未跟踪 `.env`/`.env.example` 和 `node_modules` 均没有被本轮修改/覆盖/清理。没有对它们的敏感内容进行输出。

## 12. 下一步

1. 负责人先裁决第 3.4 节 U6 最小待定事项。
2. 在隔离数据库验证 SQL 58/59、字段映射、唯一键冲突语义、菜单组件解析、角色范围及回滚流程；取得单独授权前不得执行目标数据库 SQL。
3. 修复或单独排期处理前端全量 TypeScript 检查中的非 I06 模块错误，再重跑全量检查；运行安全审查后的 lab 模块集成回归。
4. 在确认 runtime Profile、数据库结构、菜单、角色、Redis 缓存和 C7 状态后，进行独立部署计划与验收；这不属于本轮完成事项。

**停止点：本报告完成后等待负责人对 U6 入口/状态设计及后续代码修改作出明确指令。**

## R4 最新裁决补充（2026-10-20）

本报告 R2 时的 U6 FUNCTIONAL HOLD 结论为历史记录。负责人 R4 已正式明确第一期不管理真实使用，不要求签到/开始使用入口；该旧阻断不再适用。R4 的 U6 只检查预约创建对非正常设备状态的拒绝，以及故障影响预约留存、恢复状态和管理员人工处理。R4 实际测试结果见 69 号报告。SQL、菜单及目标运行环境仍未执行或验证。
