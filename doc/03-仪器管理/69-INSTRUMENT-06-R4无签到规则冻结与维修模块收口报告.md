# INSTRUMENT-06 R4 无签到规则冻结与维修模块收口报告

**任务**：CODEX-INSTRUMENT-06-R4-NO-CHECKIN-01  
**日期**：2026-10-20  
**范围**：规则冻结、故障报修权限、预约影响闭环、SQL 58/59 静态复核、本地安全测试  
**结论**：**CODE PASS / TEST HOLD / U6 PASS / SQL HOLD / DEPLOYMENT HOLD**

## 1. 最新负责人裁决

本报告按本轮正式裁决执行，覆盖 57 号冻结文档旧文本中与之冲突的内容，也取代 68 号 R3 签到设计：

1. 预约只记录预约时段和管理过程，不代表真实使用。预约到时不自动改变状态。
2. 不开发签到、签退、开始使用、活动使用会话、硬件控制或实际使用检测；不新增 `STARTED`、`IN_USE`、`OPEN`、`CLOSED` 状态、表、接口或菜单。
3. 预约状态仍为 `PENDING / FINISHED / CANCELED / VOIDED`；不改变 INSTRUMENT-03 生命周期和时段占用规则。原有完成流程要求的实际开始/结束时间仍由授权管理人员手工登记。
4. 有设备查询/访问权限的普通登录用户可以报修，不需要预约、设备使用资质、设备负责人身份、维修负责人身份或维修管理权限。
5. 后端从登录上下文取报修人，按当前租户读取设备；不得接受客户端指定报修人或跨租户/不存在设备。
6. 本草基因管理员确认/驳回、手动派工和最终恢复验收。维修负责人仅处理授权维修任务；不因此获得设备业务管理、资质、信用、暂停或预约权限。
7. 故障影响的预约保留并标记，由管理员人工处理；不自动取消、调整、改期、扣信用、爽约或变更预约状态。
8. 不修改 C7 预约创建开关。软件不能确保设备物理上未被使用，现场停用、标识和安全由实验室线下流程负责。

## 2. 旧规则冲突及文档更新

| 文档 | 原冲突 | 本次处理 |
|---|---|---|
| 57 正式规则 | 原文侧重“不新增 STARTED”，未完整明确不管理实际使用的范围 | 末尾追加 R4 正式裁决补充，冻结预约纯管理记录及无签到范围 |
| 63 部署前阻断报告 | 将无签到/开始使用入口列为 U6 FUNCTIONAL HOLD | 追加补充：该 U6 阻断已由负责人取代；SQL/菜单/运行时部署仍 HOLD |
| 64 客户操作指南 | 示例暗示用户正在设备上工作；物理安全边界不清 | 追加软件不控制实际使用、故障设备线下物理停用及人工处理要求 |
| 65 R1 测试报告 | 历史结论中将无 STARTED 入口列为 FUNCTIONAL HOLD | 保留历史数据，追加 R4 取代说明，不把历史测试数当成本轮结果 |
| 67 R2 收口报告 | R2 U6 FUNCTIONAL HOLD 要求产品决定签到入口 | 保留历史结论并追加 R4 取代说明；本轮测试结果见此报告 |
| 68 R3 签到设计 | 建议签到记录表/接口并标记 DESIGN HOLD | 保留历史设计，明确不得实施，改由 R4 U6 验收边界取代 |

对应文件：`57-INSTRUMENT-06正式规则冻结与状态机设计.md`、`63-INSTRUMENT-06部署前预检与阻断项报告.md`、`64-INSTRUMENT-06客户维修流程操作指南.md`、`65-INSTRUMENT-06-R1部署阻断修复与专项测试报告.md`、`67-CODEX-INSTRUMENT-06-R2维修模块部署前收口与U6安全修复报告.md`、`68-INSTRUMENT-06-R3-U6签到安全闭环设计与待裁决清单.md`。

## 3. 保护性预检与 Git 状态

两个仓库均为 `master` 分支。检查时后端相对上游领先 7 个提交，前端领先 6 个提交；本地均有此前 R2 的未提交修改。后端还存在既有未跟踪测试环境文件及 `Instrument06DetailAuthorizationTest.java`，前端还存在既有 `.env.prod` 修改。以上均保留，未重置、覆盖、暂存或清理；环境文件内容未读取或复制。

R4 本轮主要后端变更集中在 `yudao-module-lab` 的报修 Controller、预约影响 Mapper/DO/Service、设备状态服务、维修工单服务及单元测试。前端已有 R2 的维修页面/API/路由变更，本轮只读核验，没有覆盖前端文件。没有改动 SQL 58/59 或 C7 配置。

## 4. 普通用户报修权限验证

### 4.1 前后端行为

- 后端 `InstrumentFaultReportController.submitFault` 要求 `lab:instrument:device:query` 与 `lab:instrument:fault-report:submit` 同时具备；`lab:instrument:fault-report:admin` 可供管理员提交。表达式使用项目现有 `hasPermission`，没有引入不存在的权限表达式方法。
- `InstrumentFaultReportServiceImpl.submitFault` 从 `SecurityFrameworkUtils.getLoginUserId()` 取当前报修人；设备通过租户拦截下的 `deviceMapper.selectById` 读取。设备不存在或跨租户不可见时返回设备不存在，不写报修记录。
- 服务不查询预约、资质、设备负责人或维修负责人关系；普通用户即使没有这些记录/资格仍可提交。仍保留同设备存在未关闭报修/工单时拒绝重复上报的业务限制。
- 普通用户查看“我的报修”由 Controller 传登录用户 ID，并按 reporter ID 查询。单条详情由 Service 限制为提交人或有对应设备业务管理范围者；维修负责人身份本身不会扩张为设备业务管理权限。确认/驳回、派工、恢复验收仍受后端权限注解及服务层管理员角色校验。
- R4 对管理写操作按字面落实“本草基因管理员”：Service 新增 `isLabAdmin`，故障确认/驳回、指派、恢复验收通过/驳回、维修管理员取消/重开、预约影响人工处理均校验 `lab_admin`。仅有 `super_admin` 但没有 `lab_admin` 不足以执行这些写操作；已有权限查询和设备业务管理范围不变。
- 前端设备详情的报修入口按 `fault-report:submit` / 管理权限显隐，跳转时传 `deviceId`；提交页从 query 取设备 ID 并调用设备详情确认设备可读，API 请求体只提交故障字段及设备 ID，不接受报修人 ID。手工进入不带设备 ID 时走设备选择；query 存在但非法时不自动改绑其他设备。

### 4.2 测试

本轮单元测试覆盖普通用户直接提交（测试没有配置预约、资格或负责人数据）、设备不可见时拒绝并且不插入报修记录。前者实际证明 Service 不要求预约/资质/负责人关系；后者模拟租户隔离后的查询无记录。目标数据库中的真实租户拦截仍需部署环境验证。

## 5. 维修流程与 U6 验收矩阵

| 流程/要求 | 代码核对结论 | 本轮判断 |
|---|---|---|
| 普通用户提交故障 | 登录用户身份由服务端取值；设备存在/租户范围校验；无预约、资质和负责人前置要求 | PASS |
| 管理员确认/驳回 | Service `isLabAdmin` + 故障报告行锁和状态校验；确认创建工单，驳回不创建 | PASS |
| 故障设备及预约影响 | 确认工单事务锁定设备，更新 FAULT 并扫描未来 `PENDING` 预约；保留预约，仅写影响记录 | PASS |
| 管理员手动派工 | 权限由 `isLabAdmin` 校验；目标维修负责人按设备房间有效 `ROOM_REPAIR` 关系校验 | PASS |
| 维修负责人开始/过程/结果 | 仅被分配人或管理员可操作对应工单；过程追加维修历史 | PASS（服务层单测） |
| 管理员恢复验收 | 仅 `lab_admin`；验收事务更新设备 NORMAL 和工单状态，写设备历史 | PASS（服务层单测） |
| 恢复后的预约影响 | `PENDING → AUTO_RESTORED` 表示设备恢复事实，仍待管理员处理；不会自动改预约 | PASS |
| 管理员人工处理预约影响 | 仅 `lab_admin`；`PENDING/AUTO_RESTORED → PROCESSED`，写处理人、时间、说明；使用带租户及旧状态条件的单行 CAS | PASS（服务层及静态 SQL 核对） |
| 非正常设备新预约准入 | `ReservationCreateExecutor.validateAdmission` 对任何非 NORMAL 状态拒绝；无 C7 配置变更 | PASS（H2 定向用例覆盖四状态） |
| 取消、调整、完成、作废、信用 | 未新增签到关联、自动处罚或状态转换；沿用 INSTRUMENT-03 规则 | PASS（静态检查；未跑完整 INSTRUMENT-03 回归） |
| 现场实际停用 | 软件不控制实际设备 | 由操作指南要求实验室线下物理停用、警示和安全管理 |

### 5.1 本轮修复的实际缺陷

1. **人工处理并发覆盖**：原逻辑先读后 `updateById`，两个管理员可能均通过旧状态检查，后写覆盖前写。本轮改为 `updateProcessedIfPending`，单条 SQL 只接受当前租户且状态仍为 `PENDING/AUTO_RESTORED` 的行；只有 affected rows 为 1 才成功，其他请求收到状态无效错误。
2. **恢复状态与人工处理竞态**：设备恢复扫描记录后，旧的按对象更新可能把已处理的 `PROCESSED` 改回 `AUTO_RESTORED`。设备状态服务和维修验收服务统一使用 `updateAutoRestoredIfPending`，只允许 `PENDING → AUTO_RESTORED`，不能覆盖已完成人工处理的记录。
3. **已处理影响键重放**：原重复检查只看活动状态，已为 `PROCESSED` 的记录会被忽略，重放可能再次插入同一 `impact_key` 并触发唯一键异常。本轮在插入前查完整 `impact_key`（包含历史/已处理记录），已存在就跳过；同一设备事件路径还受设备行锁串行化，数据库租户唯一索引作为最终约束。
4. **普通报修访问边界**：报修 Controller 原来只检查 submit/admin 权限，没有显式要求设备查询权限。本轮改为普通报修必须同时具有设备查询与报修权限；管理员报修仍由 fault admin 权限进入。服务继续独立校验当前租户内设备存在并从登录上下文确定身份。

## 6. 前端页面、入口与权限

静态核对文件：

- 页面：`src/views/lab/instrument/device-detail/index.vue`、`fault-report/submit.vue`、`fault-report/my-list.vue`、`fault-report/admin-list.vue`、`repair-order/list.vue`、`my-assigned.vue`、`detail.vue`、`assign.vue`、`restore-approve.vue`、`reservation-impact/list.vue`。
- API：`src/api/lab/instrument/fault-report/index.ts`、`repair-order/index.ts`、`reservation-impact/index.ts`。
- 路由：`src/router/modules/remaining.ts`。
- 设备详情报修按钮权限与后端独立校验相呼应；设备 ID query 参数和提交 API 字段一致。动态菜单 13684 组件路径 `lab/instrument/repair-order/list` 对应 `src/views/lab/instrument/repair-order/list.vue`。
- 普通用户拥有 submit 时展示上报和我的报修入口；管理员管理、派工、恢复验收和预约影响处理按钮分别按 admin/handle 权限显示。按钮隐藏仅为 UI，不替代后端鉴权。
- 没有签到、签退、开始使用或硬件控制页面/API。

## 7. SQL 58/59 静态一致性复核

**执行状态：未执行。** 未连接 `labplatform`，没有运行任何 SQL。数据库表、菜单、角色、租户、套餐的目标环境状态为 **UNKNOWN**。

### 7.1 SQL 58 五表映射与索引

| 表 | Java DO / Mapper | 静态映射结论 |
|---|---|---|
| `lab_instrument_fault_report` | `InstrumentFaultReportDO` / `InstrumentFaultReportMapper` | 故障、提交人、确认人、状态和租户审计列与 DO 属性采用驼峰转下划线映射 |
| `lab_instrument_repair_order` | `InstrumentRepairOrderDO` / `InstrumentRepairOrderMapper` | 工单号、指派、维修/验收时间及状态字段匹配；租户内工单号唯一 |
| `lab_instrument_repair_history` | `InstrumentRepairHistoryDO` / `InstrumentRepairHistoryMapper` | 工单动作、前后状态、操作者及维修记录字段匹配；租户内工单历史序号唯一 |
| `lab_instrument_device_status_history` | `InstrumentDeviceStatusHistoryDO` / `InstrumentDeviceStatusHistoryMapper` | 设备状态、操作人、动作及故障/工单关联字段匹配 |
| `lab_instrument_reservation_impact` | `InstrumentReservationImpactDO` / `InstrumentReservationImpactMapper` | 预约/设备/来源、`impact_key`、三种处理状态及人工处理字段匹配 |

五表均包括 `tenant_id` 和逻辑删除/审计字段；DDL 为设计稿中新增表用 `CREATE TABLE IF NOT EXISTS`。若目标表已经存在，该语句不会补齐新列或索引，必须先对照实际 schema，不能视作迁移脚本。影响表 `UNIQUE (tenant_id, impact_key)` 与 Mapper 生成键相匹配；`impact_key` 查重与设备行锁串行化降低重复异常，唯一索引兜底。管理员处理和设备恢复均用条件更新避免状态竞态。代码没有吞掉 `DuplicateKeyException`：协议内同设备写入由设备行锁串行化，键查重包含已处理记录；若唯一键仍冲突则事务失败并显式报错，不能错误返回成功。静态测试未模拟真实 MySQL 唯一键并发异常。

### 7.2 SQL 59 菜单与授权矩阵

| 对象 | SQL 静态值 | 与源码核验 |
|---|---|---|
| 菜单 | 13684 页面；13685 submit；13686 fault admin；13687 repair handle；13688 repair admin | 权限码与 Controller 注解一致；13684 组件路径匹配前端维修列表 |
| 普通用户角色 | 904 页面 + 13685 submit | 有普通报修权限；不是确认、派工或验收权限 |
| 本草基因管理员 | 906 全五项 | 覆盖故障管理、维修管理、人工影响处理、恢复验收 |
| 设备负责人 | 908 不新增维修授权 | 保持业务管理/维修管理边界分离 |
| 维修负责人 | 909 祖先链、页面、submit、handle；不含 admin | 可报修及处理获派工单，不含全局管理/验收 |
| 套餐/租户 | 套餐 114；租户 162 | 仅脚本常量，目标数据库当前值 UNKNOWN |

SQL 59 的前置核验必须重新确认菜单 ID 空闲、父菜单、角色 904/906/908、角色 909、权限码冲突、套餐 JSON 有效和目标租户。SQL 直写不触发缓存失效；脚本要求通过应用 UI 失效菜单/角色缓存，不能直接清 Redis。回滚包含菜单/角色关系删除及套餐 JSON 更新；执行前需要保存当前授权和套餐快照，确认事务边界与回滚对象范围。SQL 58 的 DROP 回退仅能在确认没有业务数据后使用。上述均未执行。

**静态结论**：代码、DO/Mapper、SQL 列名/索引、菜单权限码和组件路径未发现本轮规则冲突；由于生产/目标环境前置值未知，SQL 分级仍为 HOLD，不能宣称已可直接投产。

## 8. 测试与验证结果

| 命令 | 实际结果 | 说明 |
|---|---|---|
| `mvn --% -pl yudao-module-lab -Dtest=Instrument06*Test -Dsurefire.failIfNoSpecifiedTests=false test` | **BUILD SUCCESS；64 tests，0 failures / 0 errors / 0 skipped** | INSTRUMENT-06 纯 Mockito 测试；包含普通用户报修、super_admin 与 lab_admin 边界、权限/租户、影响幂等、恢复及并发 CAS 的服务层测试；未连真实 DB/Redis |
| `mvn --% -pl yudao-module-lab -Dtest=Instrument03CReservationCreateTest#testCreate_deviceStatusDenied_082 test` | **BUILD SUCCESS；1 test，0 failures / 0 errors** | `unit-test` profile，H2 内存数据库；设备状态拒绝用例覆盖 `FAULT / MAINTENANCE / DISABLED / SCRAPPED`；编号 Redis DAO 与预约锁协调器均为 mock |
| `pnpm run ts:check` | **失败，退出码 1** | 全前端检查报 13 个 TypeScript 错误，均位于非本维修页面/API文件：`src/api/lab/announcement/index.ts`（Dayjs 未使用）；`src/views/fms/report/components/FmsReportFormulaForm.vue`（2）；`src/views/hrm/employee/index.vue`（1）；`src/views/lab/v2/plasmid-audit/index.vue`（5）；`src/views/lab/v2/plasmid/index.vue`（4）。没有报告 R4/I06 文件错误；因此全仓类型检查不能标 PASS。 |

未运行完整 `yudao-module-lab` Maven 回归或 MySQL 集成测试；真实 MySQL 并发、SQL 执行和数据库唯一索引行为留待隔离部署前验证。未启动任何服务/容器，未访问真实数据库/Redis。历史 `243/243`、`60/60` 不作为本轮结果。

## 9. C7、运行时与 Git 摘要

- 本轮没有改动 C7。静态文件中 `application-local.yaml` 配置为 `false`，`application-instrument-03-test.yaml` 为隔离测试专用 `true`；本轮预约准入用例运行在 `unit-test` profile，未启用前述 `instrument-03-test` profile。实际部署运行 Profile 为 UNKNOWN。
- Git 工作树包含 R2 期间的既有未提交代码及环境文件。本轮没有暂存、提交、推送、清理或重置。后端本轮 R4 增量涉及 Controller、影响 DO/Mapper、设备/维修/影响 Service 和测试；前端本轮未改文件。文档目录追加了 57/63/64/65/67/68 补充及本报告。
- 文档目录不是此次代码测试的一部分；Git 提交状态不代表其已部署。

## 10. 未解决事项与最终分级

### 仍需在独立部署授权/隔离环境解决

1. SQL 58/59 尚未执行。需另行授权并重新核实实际数据库版本、五张表是否已存在、索引/字段差异、菜单 ID、角色、租户和套餐现状。
2. 真实菜单缓存刷新、角色分配和菜单可见性尚未验证；不得据此宣称菜单已部署。
3. 完整 Maven 回归和真实 MySQL 并发唯一键验证未运行。
4. 前端 `ts:check` 被 13 个非 I06 TypeScript 错误阻断。应修复这些错误后再获得全仓类型检查 PASS。
5. 真实运行时 Profile/C7 生效值和现场物理停用执行情况 UNKNOWN。

| 分级项 | 结论 | 依据 |
|---|---|---|
| **CODE** | **PASS** | R4 规则已冻结；修复了报修权限入口和影响状态并发/幂等问题；后端成功编译，接口/页面权限静态核对一致 |
| **TEST** | **HOLD** | 后端定向 64 项和 H2 状态准入用例通过；全前端类型检查失败于非 I06 错误；完整回归未执行 |
| **U6** | **PASS** | 按新定义的软件预约记录/影响管理闭环验收；无签到要求不再阻断；四种非正常设备状态均拒绝新预约 |
| **SQL** | **HOLD** | SQL 58/59 静态字段/权限/路径一致，但目标环境前置检查、现存 schema 和事务/回滚条件 UNKNOWN，且未获 SQL 执行授权 |
| **DEPLOYMENT** | **HOLD** | SQL、菜单缓存、角色分配、真实数据库与运行时 Profile 未部署或独立验证；不得表述为生产部署通过 |

**停止点**：R4 规则冻结、代码收口和本地验证已完成。本报告不构成 SQL 执行授权；等待负责人另行批准 SQL 部署步骤。
