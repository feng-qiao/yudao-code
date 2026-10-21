# 16-INSTRUMENT-02-部署前集中复核报告

- 任务：TASK INSTRUMENT-02-DEPLOY-PRECHECK-01（仪器资质、信用与暂停管理：部署前集中复核）
- 复核日期：2026-10-15
- 复核对象：`20261015_instrument_02_schema.sql`、`20261015_instrument_02_menu.sql`、`InstrumentSuspendExpireJob.java`、yudao-module-lab `instrument` 包（DO/Mapper/Service/Controller）、前端 5 页面
- 目标环境：MySQL 8.0.12 / labplatform（实测）、后端运行 profile = `local`、前端 `yudao-ui-admin-vue3`
- 复核性质：**只读**。本任务未执行任何 DDL/DML，未注册或启动定时任务，未重启服务，未调用产生业务数据的接口，未修改任何 Java/Vue/SQL/配置/文档，未触碰 INSTRUMENT-01 测试数据。

> 术语：HOLD 项依据任务单第五节"停止条件"判定；B 项为部署阻塞但非停止条件；M 项为必须修复；R 项为建议/风险提示。

---

## 一、最终结论

**结论（FIX-01 撰写时）：HOLD（H1/H2 为停止条件；B2/B3 待负责人裁决；M1/M2/B4 已在 FIX-01 修复）**

> ⚠️ **后续更新（2026-10-15，TASK INSTRUMENT-02-DECISION-IMPLEMENT-01）**：负责人已对 H1/H2/B2/B3 作出**正式裁决并落地**（H1 B 方案不启用自动到期；H2 接受 G13 转移依赖；B2 新增设备负责人角色 908；B3 保留共用权限串强化服务端范围）。**H1/H2 停止条件解除，B2/B3 部署阻塞解决**。静态验证结论为 **CODE/PRECHECK PASS**；**部署状态仍为 NOT DEPLOYED / 待授权**（三 SQL 未执行、角色未真实创建、HTTP/并发未实测）。**下表 PENDING 记录保留为历史（不抹除）**；详见 [18-INSTRUMENT-02-裁决落地与部署准备报告.md](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md)。

| 层级 | 编号 | 结论 | 一句话依据 |
| --- | --- | --- | --- |
| 停止条件命中 | **H1** | HOLD → **已解除** | 目标运行 profile 为 `local`，Quartz 自动配置被排除 → `SchedulerManager(null)`。**裁决状态 PENDING（FIX-01 撰写时）**→ **已裁决（2026-10-15，B 方案：本期不启用自动到期）**，停止条件解除；U1 本期不适用（见 8.4 落地表） |
| 停止条件命中 | **H2** | HOLD → **已解除** | G13 一致性依赖"预约侧读取暂停记录拦截"。**裁决状态 PENDING（FIX-01 撰写时）**→ **已裁决（2026-10-15，接受 G13 转移依赖）**，强制约束已写入 INSTRUMENT-03 文档；U2 待 INSTRUMENT-03（见 8.4 落地表） |
| 部署阻塞 | B1 | 需解决 → **已解除** | 同 H1；B 方案下无需切换 profile / 注册 Job |
| 部署阻塞 | B2 | 待裁决（PENDING）→ **已裁决 + 已落地** | 新增角色 908 `instrument_device_manager` + 8 条授权 SQL（**未执行**）（见 8.4 落地表） |
| 部署阻塞 | B3 | 待裁决（PENDING）→ **已裁决 + 已落地** | 保留共用权限串不拆分；服务端 2 处越权修正为显式 403（见 8.4 落地表） |
| 已修复（FIX-01） | M1/M2/B4 | PASS | FIX-01 已把 Menu SQL 两处计数注释订正为 14、为预检 AND/OR 条件加括号、并在 schema 新增 §0.4 六表列级结构预检（三种判定情形 + 停止条件）。详见 [17-INSTRUMENT-02-部署前整改报告.md](file:///E:/lixin/dev/doc/03-仪器管理/17-INSTRUMENT-02-部署前整改报告.md) |
| 已核查通过 | — | PASS | Schema SQL 6 表列定义与 DO/Mapper 逐列一致；Menu SQL 14 条 ID/父菜单/权限串/角色/套餐追加格式与本环境实测一致且幂等；两个脚本预检/验收 SQL 均为只读且兼容 MySQL 8.0.12 |

**关键判断**：Schema SQL 与 Menu SQL **本身具备执行条件**（见第三、四节），因此"SQL 能否执行"层面为 PASS；整体结论仍取 HOLD，因为**定时任务无执行承载（H1）**、**G13 一致性依赖不可证（H2）**这两项为任务单明列的停止条件，且其裁决状态为 PENDING。M1/M2/B4 属可直接修正项，已由 FIX-01 修复。**本次复核不授权执行任何 SQL；SQL 生成与 SQL 执行为独立授权边界。**

---

## 二、核查范围、方法与只读边界

**方法**：
1. 逐行精读两个 SQL 脚本原文；
2. 逐列比对 6 张表 DDL 与 6 个 `*DO`、6 个 `*Mapper`；
3. 精读 `instrument` 包 Service/Controller/枚举/错误码/锁 DAO；
4. 对框架层（`BaseDO`/`TenantBaseDO`/`TenantLineHandler`/`MybatisPlusInterceptor`/`JobHandler`/`SchedulerManager`/`TenantJobAspect`/`YudaoQuartzAutoConfiguration`）精读确认机制；
5. **真实数据库只读 SELECT**（`mysql.exe`，仅 SELECT）核对菜单段、角色、租户套餐、字典、`infra_job` 现状；
6. 前端页面/组件名/`v-hasPermi`/API 路径核对。

**只读边界（已遵守）**：见第十二节"实际执行过的命令"，全部为 `SELECT`/`SHOW` 级或文件读取；无 `INSERT/UPDATE/DELETE/DDL`。

---

## 三、A. Schema SQL 核查表

被核查文件：[20261015_instrument_02_schema.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_schema.sql)

| 编号 | 核查项 | 证据 | 结论 | 风险 |
| --- | --- | --- | --- | --- |
| A1 | 6 张表是否已存在；`CREATE TABLE IF NOT EXISTS` 掩盖风险 | §0.1 走 `information_schema.tables` 计数；2026-10-15 实测 6 行 cnt 全为 0。§3 停止条件 1 要求 cnt=1 即停止 | 通过（预检可识别同名表存在） | 预检只给"表存在/不存在"，**不比较列结构**；若操作者跳过停止条件直接执行，`IF NOT EXISTS` 会静默跳过，旧结构被沿用 → 见 B4 |
| A2 | 6 表字段/类型/长度/默认值/NULL 与 DO 一致性 | `lab_instrument_qualification_apply`(25 列) / `..._apply_history`(16) / `lab_instrument_qualification`(17) / `lab_instrument_credit_account`(14) / `lab_instrument_credit_flow`(21) / `lab_instrument_suspend`(22)。逐一比对 6 个 DO（`extends TenantBaseDO` + `@TableName` + `@Builder`）：列名、varchar 长度、`bit(1)`↔`Boolean`、`int`↔`Integer`、`datetime`↔`LocalDateTime`、可空性、默认值全部吻合 | **通过（逐列一致）** | 无 |
| A3 | `TenantBaseDO` 租户/审计字段与框架约定 | `BaseDO` 定义 `createTime/updateTime`（`INSERT`/`INSERT_UPDATE` 自动填充）+ `creator/updater` + `@TableLogic Boolean deleted`；`TenantBaseDO` 声明 `tenantId`。DDL 六表均含 `creator/create_time/updater/update_time/deleted bit(1) NOT NULL DEFAULT b'0'/tenant_id bigint NOT NULL DEFAULT 0`，`update_time ON UPDATE CURRENT_TIMESTAMP` | 通过 | DDL 的 `create_time/update_time` 有 DB 默认值，而框架走 `FieldFill` 显式赋值——两者并存不冲突。无 |
| A4 | `uk_account_tenant_user` 语义 | `UNIQUE INDEX uk_account_tenant_user(tenant_id, user_id)`。因 `tenant_id` 为键首列：同租户同用户仅一账户；不同租户相同 `user_id` 因 `tenant_id` 不同可分列存在 | **通过（语义正确）** | 唯一键**不含 `deleted`**：账户若被逻辑删除后重建会撞唯一键。代码无账户删除路径（见 A6），风险低，仅登记 |
| A5 | 申请编号唯一键、状态字段、金额/积分字段、暂停时间字段及索引 | `uk_apply_tenant_no(tenant_id, apply_no)`（租户内唯一，正确）；`idx_target_status(target_type,target_id,status)`、`idx_applicant(applicant_user_id,status)`；`credit_account.score int(11) NOT NULL DEFAULT 100` **无 CHECK/无上下限**（合 G14）；`credit_flow.score_change/score_before/score_after int NOT NULL`；`suspend.start_time/end_time datetime NOT NULL`、`idx_end_time(status,end_time)`（支撑到期扫描）、`idx_user_status`、`idx_user_device` | 通过 | `lab_instrument_qualification` **无 DB 唯一键**（同 user+device 单 ACTIVE 仅靠应用层 + Redisson 锁）——见 A6/D1 |
| A6 | 不可变表的意外更新/删除路径 | `InstrumentQualificationApplyHistoryMapper` 仅有 `selectListByApplyId`；`InstrumentCreditFlowMapper` 仅有 `selectPage/selectPageByUser/selectCountByBiz/selectExportList/selectListByAccountId`。业务代码无 update/delete 调用 | 通过（无业务更新/删除路径） | 两个 Mapper 继承框架 `BaseMapper`，`updateById/deleteById` 在**接口层面**可用但**未被任何业务代码调用**；框架软删 `@TableLogic` 亦无调用点。属"API 表面存在、实际不可达"，登记为提示，不阻塞 |
| A7 | 预检 / 验收 SQL 是否适用 MySQL 8.0.12 且不产生写入 | 全部为 `SELECT`（`information_schema.tables/schemata/columns/statistics`、`system_dict_data`、表 `COUNT(*)`）。MySQL 8.0.12 支持 `b'0'` 位字面量与 ICU 正则 | **通过（只读、兼容）** | §0.3 的 `WHERE deleted=b'0' AND permission LIKE '...' OR ...` 依赖 AND 优先于 OR，语义正确但不加括号易误读；建议补括号（文档级） |
| A8 | 每项检查的预期结果 / 语句 / 停止条件是否明确 | §0 三组预检均标注预期；§2.1~2.4 验收均标注预期；§3 列 4 条停止条件；DDL 为幂等 `IF NOT EXISTS` | 通过 | 停止条件为**人工门槛**，脚本无自动中止；需负责人逐条核对（已在脚本内注明） |

**A 节结论：Schema SQL 具备执行条件（PASS）**，唯一遗留为 B4（列级结构不一致的只读预检缺失）。

---

## 四、B. Menu SQL 核查表

被核查文件：[20261015_instrument_02_menu.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_menu.sql)

### 4.1 菜单逐条（ID 13660~13673，共 14 条 = 5 页面 + 9 按钮）

| id | 名称 | type | parent_id | path | component | component_name | permission | 与前端一致 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 13660 | 我的使用资质 | 2 | 13600 | my-qualification | lab/instrument/my-qualification/index | LabInstrumentMyQualification | （空） | ✔ 页面存在，`defineOptions name` 一致 |
| 13661 | 资质查询 | 3 | 13660 | — | — | — | lab:instrument:qualification:query | ✔ |
| 13662 | 资质申请 | 3 | 13660 | — | — | — | lab:instrument:qualification:apply | ✔ |
| 13663 | 我的信用 | 2 | 13600 | my-credit | lab/instrument/my-credit/index | LabInstrumentMyCredit | （空） | ✔ |
| 13664 | 信用查询 | 3 | 13663 | — | — | — | lab:instrument:credit:query | ✔ |
| 13665 | 资质审核 | 2 | 13600 | qualification-audit | lab/instrument/qualification-audit/index | LabInstrumentQualificationAudit | （空） | ✔ |
| 13666 | 资质审核 | 3 | 13665 | — | — | — | lab:instrument:qualification:audit | ✔ |
| 13667 | 撤销资质 | 3 | 13665 | — | — | — | lab:instrument:qualification:manage | ✔ |
| 13668 | 信用管理 | 2 | 13600 | credit-manage | lab/instrument/credit-manage/index | LabInstrumentCreditManage | （空） | ✔ |
| 13669 | 加扣分 | 3 | 13668 | — | — | — | lab:instrument:credit:adjust | ✔ |
| 13670 | 流水导出 | 3 | 13668 | — | — | — | lab:instrument:credit:export | ✔ |
| 13671 | 暂停管理 | 2 | 13600 | suspend-manage | lab/instrument/suspend-manage/index | LabInstrumentSuspendManage | （空） | ✔ |
| 13672 | 暂停查询 | 3 | 13671 | — | — | — | lab:instrument:suspend:query | ✔ |
| 13673 | 创建解除 | 3 | 13671 | — | — | — | lab:instrument:suspend:manage | ✔ |

- 全部 `status=0`（启用）、`visible=b'1'`、`keep_alive=b'1'`、`always_show=b'1'`、`creator/updater='1'`。
- 9 个权限串与后端 `@PreAuthorize` **一一对应**（见第六节 D6）。
- 5 个页面 `component_name` 与前端 SFC `defineOptions({ name })` **一致**（影响 keep-alive）。

### 4.2 环境事实核对（真实 DB 只读实测，2026-10-15）

| 核查项 | 实测证据 | 结论 |
| --- | --- | --- |
| ID 段空闲 | `system_menu` MAX(id)=**13653**；13600~13653 为 INSTRUMENT-01 段；13660~13673 **完全空闲** | ✔ §0.1/§0.2 通过 |
| 父菜单 13600 | 存在：name=仪器管理、type=1、parent_id=**13478**、status=0、path=instrument | ✔ 新页面挂 13600 下不会孤儿 |
| 权限串冲突 | 现存 `lab:instrument:%` 仅 platform/device/room/manager/notice 五组，无 qualification/credit/suspend | ✔ §0.3 返回 0 行 |
| 角色 904/906 | 均存在、tenant_id=162、status=0（903 普通/905 lab_keeper/907 registration_approver 亦存在） | ✔ §0.5 通过；903/905/907 本脚本不授权 |
| 租户/套餐 | 租户 162 package_id=**114**、status=0；套餐 114 存在、status=0，`menu_ids` 长度 **1378**、head `[1,2,3,...`、tail `...,13651,13652,13653]` | ✔ §0.6 通过 |
| 套餐追加格式 | 实测为**逗号无空格** JSON 数组 `[...,13653]` → `CONCAT(SUBSTRING(menu_ids,1,LENGTH(menu_ids)-1),',13660]')` **可直接追加**；14 条 UPDATE 顺序执行逐 ID 追加结果正确 | ✔ §2 可正确追加 |
| 套餐含本批 ID | §0.7 预期 14 个 `has_x=0` | ✔ |
| 幂等基础 | `system_role_menu` 索引仅 `PRIMARY(id)` + `idx_role_id(role_id)`，**无 (role_id,menu_id) 唯一索引** → 防重完全依赖 `NOT EXISTS`（脚本已用） | ✔ 幂等成立 |
| 租户隔离面 | `system_menu` **无 tenant_id 列**（菜单全局共享） | ✔ 新增不影响其他租户 |
| INSTRUMENT-01 现状 | `system_menu` 13600~13653 为仪器段；`lab_instrument%` 5 张表存在；测试数据 10 条（device=2/manager=3/notice=2/room=1/platform=2） | ✔ 本脚本不触碰 |

### 4.3 角色 / 套餐 / 越权结论

| 核查项 | 证据 | 结论 |
| --- | --- | --- |
| 906 授权 | §3.1 授 13660~13673 **14 条**（注释写"13 条"，实际 `UNION` 列 14 个 ID）→ 覆盖审核/撤销/加扣分/导出/暂停管理 | ✔ 906 权限完整 |
| 904 授权 | §3.2 授 **13660,13661,13662,13663,13664,13672**（6 条）→ 仅"我的使用资质/我的信用"两页面 + 3 按钮 + `suspend:query`；**不授** 13665/13668/13671（三个管理页）与全部写按钮 | ✔ 904 无管理页/写权限 |
| 903/905/907 | 本脚本不授权（I3 待负责人确认） | 与设计一致，但见 B2 |
| 套餐 114 | §2 逐 ID 追加 14 条，守卫含括号格式 + 词边界不含 + 菜单存在且启用 | ✔ 重复执行影响 0 行 |
| 幂等/事务 | 全部 INSERT 带 `NOT EXISTS` + 父菜单/角色存在守卫；§6 建议显式事务 + `mysqldump` 兜底 | ✔ 重复执行安全（写入均 DML，可事务） |
| §4.5 期望 vs 实际 | §4.5 期望 906=14 行、904=6 行，与 §3.1/§3.2 实际一致 | ✔ 验收期望正确 |

### 4.4 越权/权限串问题（B3）

| 端点 | 权限串 | 904 是否持有 | 904 实际结果 | 证据 |
| --- | --- | --- | --- | --- |
| `GET /suspend/page`（管理端分页） | `lab:instrument:suspend:query` | **持有** | 权限通过，但 Service `getSuspendPage` 对无授权设备者返回空分页 | [InstrumentSuspendServiceImpl](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentSuspendServiceImpl.java) |
| `GET /suspend/my`（本人） | 同上 | 持有 | 本人数据（`getMySuspends` 强制本人） | 同上 |
| `GET /qualification/page`、`/apply/page`（管理/授权范围） | `lab:instrument:qualification:query` | 持有 | 904 非负责人 → 仅本人申请/空资质分页 | [InstrumentQualificationServiceImpl](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentQualificationServiceImpl.java#L255-L317) |
| `GET /credit/page`、`/flow/page`（管理端） | `lab:instrument:credit:query` | 持有 | **抛 403**（`requireManageAll`） | [InstrumentCreditServiceImpl](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentCreditServiceImpl.java#L100-L106) |

**结论**：904 **无法通过任何写端点**（`audit/manage/adjust/export/suspend:manage` 均未授权）；读端点在 Service 层均有数据范围兜底（本人/授权设备/或 403），**未发现可实际绕过并读到非本人数据的路径**。但 `suspend:query` / `qualification:query` / `credit:query` 三个串被"管理端点"与"本人端点"共用，属**设计表述与权限串一一隔离原则不符**（B3），建议拆分（如 `suspend:query` 仅本人、管理分页另用 `suspend:page` 或复用 `suspend:manage`），或在文档中明确书面确认此共用为有意设计。

### 4.5 B 节次要问题（文档级，不阻塞）

1. §2 注释"逐 ID 一条 UPDATE，共 **13** 条"与 §3.1"全部 **13** 条新菜单/按钮"与实际 **14** 条不符（§3.1 `UNION` 实列 14 个 ID）。§1 头部与 §4.5 均为 14，**仅这两处注释计数写错**，无功能影响，建议订正为 14 以免误导执行者核对行数。
2. §6.2 已正确写明"第 1 节 14 行、第 2 节最多 14 行、第 3.1 最多 14 行、第 3.2 最多 6 行"，与 §2/§3.1 注释自相矛盾，以 §6.2 为准。

**B 节结论：Menu SQL 具备执行条件（PASS）**，ID/父菜单/权限串/角色/套餐均无冲突；遗留 B2（负责人角色）、B3（权限串共用）两项需负责人决策，另 2 处注释计数需订正。

---

## 五、C. 定时任务注册方案与依据

被核查文件：[InstrumentSuspendExpireJob.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/job/InstrumentSuspendExpireJob.java)

### 5.1 机制核查

| 核查项 | 证据 | 结论 |
| --- | --- | --- |
| `@Component("instrumentSuspendExpireJob")` + `JobHandler` | `@Component("instrumentSuspendExpireJob")`，`implements JobHandler`，`execute(String)` 返回 `"到期暂停处理数量：" + suspendService.expireSuspends()`（`expireSuspends()` 返回 `int`，见 [InstrumentSuspendService](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentSuspendService.java#L34)） | ✔ 与项目范式一致 |
| 同模块先例 | [PlasmidBorrowOverdueJob](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/job/PlasmidBorrowOverdueJob.java)：`@Component("plasmidBorrowOverdueJob")` + `implements JobHandler` + `@TenantJob`，Cron `/5` | ✔ 完全同模式先例 |
| `@TenantJob` 语义 | [TenantJobAspect](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-framework/yudao-spring-boot-starter-biz-tenant/src/main/java/cn/iocoder/yudao/framework/tenant/core/job/TenantJobAspect.java)：`@Around("@annotation(tenantJob)")` → `tenantFrameworkService.getTenantIds()` → `parallelStream` 逐租户 `TenantUtils.execute(tenantId, ...)` | ✔ 逐租户上下文执行；**要求 handler 幂等**（失败重试会重复执行已成功租户） |
| 调度触发 | `JobHandlerInvoker extends QuartzJobBean` 带 `@DisallowConcurrentExecution`，按 `jobHandlerName` 取 Bean 执行；`SchedulerManager.addJob` 以 `jobHandlerName` 为 JobDetail/Trigger 唯一标识 | ✔ 同名任务不会并发重入 |
| 并发/重复触发 | `@DisallowConcurrentExecution` + `expireSuspends` 内条件更新 `updateExpireIfActive`（affectedRows 守卫）→ 幂等 | ✔ Cron `0 0/5 * * * ?` 与 5 分钟耗时/重复触发兼容（任务为轻量扫描） |
| `infra_job` 表结构 | 无 `tenant_id` 列；字段 id/name(varchar32)/status(tinyint)/handler_name(varchar64)/handler_param(varchar255)/cron_expression(varchar32)/retry_count(int def 0)/retry_interval(int def 0)/monitor_timeout(int def 0)/creator/create_time/updater/update_time/deleted(bit(1))；**无 `handler_name` 唯一索引**（唯一性由应用层 `selectByHandlerName` 保证） | ✔ 结构明确 |
| 现行 `infra_job` 状态 | 实测 34 行**全部 status=2（STOP）**；MAX(id)=**12914**；**无** `handler_name='instrumentSuspendExpireJob'`；`plasmidBorrowOverdueJob` 已注册为 id=12914、status=2、cron `0 0/5 * * * ?`、retry_count=0/retry_interval=0/monitor_timeout=0、creator/updater='1' | ✔ 需新增注册；12914 为**同模式可信模板** |
| **执行承载（H1）** | `application.yaml: spring.profiles.active: local`；`application-local.yaml:10` `exclude: - org.springframework.boot.autoconfigure.quartz.QuartzAutoConfiguration`；[YudaoQuartzAutoConfiguration](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-framework/yudao-spring-boot-starter-job/src/main/java/cn/iocoder/yudao/framework/quartz/config/YudaoQuartzAutoConfiguration.java) 用 `Optional<Scheduler>`，缺失时 `new SchedulerManager(null)`；`SchedulerManager.validateScheduler()` 空则抛 `NOT_IMPLEMENTED`（"定时任务 - 已禁用"） | **HOLD（H1）**：local 下 Quartz 禁用 → Job 无法运行；仅插 `infra_job` 行**不会**使其执行 |

### 5.2 建议注册方案（**仅建议，未执行**）

**取值依据**：以同模块已存在、可信的 `plasmidBorrowOverdueJob`（`infra_job` id=12914）为模板，字段值对齐；`handler_name` 必须与 `@Component("instrumentSuspendExpireJob")` 及 `JobHandler` Bean 名一致；Cron 取文件注释冻结值 `0 0/5 * * * ?`。

| 字段 | 建议值 | 依据 |
| --- | --- | --- |
| name | `仪器暂停到期处理 Job` | 命名风格对齐现有任务 |
| status | `1`（NORMAL） | 令任务启用；**注意 local 下 Scheduler 缺失时该行不会被调度（H1）** |
| handler_name | `instrumentSuspendExpireJob` | 与 `@Component` 名一致 |
| handler_param | `NULL` / `''` | 该 handler 未使用 param |
| cron_expression | `0 0/5 * * * ?` | 文件注释冻结值，与先例一致 |
| retry_count | `0` | 对齐先例 |
| retry_interval | `0` | 对齐先例 |
| monitor_timeout | `0` | 对齐先例 |
| creator / updater | `'1'` | 对齐先例 |
| deleted | `b'0'` | 未删除 |

> **推荐路径（不手写 INSERT）**：在**具备 Scheduler 的运行环境**下，经管理后台"定时任务"新建任务（`JobServiceImpl.createJob` 会校验 Cron + handler Bean 存在 + `handlerName` 唯一，插入后自动由 `INIT(0)` 置 `NORMAL(1)` 并 `schedulerManager.addJob`），避免字段遗漏。手写 INSERT 仅在确认 `infra_job` 各列 NOT NULL/默认值后使用；**本任务不执行任何 INSERT**。

### 5.3 幂等 / 重试 / 恢复逻辑

- `expireSuspends()`：`selectActiveExpired(now)` → **逐条事务**：`updateExpireIfActive`（affectedRows=0 → 跳过）→ `resumeUncoveredQualifications`（仅恢复 `selectActiveCovering` 为空的 SUSPENDED 资质）。重复执行安全；`@TenantJob` 重试已成功租户时同样幂等。
- 人工解除不受 Job 影响（`releaseSuspend` 独立路径）。
- **前提**：Job 能被执行（H1）。

---

## 六、D. 核心业务一致性核查结果

| 编号 | 核查项 | 证据 | 结论 |
| --- | --- | --- | --- |
| D1 | **首审初始化 100 分**（并发双设备只初始化一次；唯一键冲突是否吞异常；同事务） | [auditApply](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentQualificationServiceImpl.java#L151-L212) 全程在 `transactionTemplate.execute` 内：`selectByIdForUpdate`（申请行锁）→ `canManageDevice` → `updateAuditResult`（affectedRows=0 → `STATUS_CHANGED`）→ approve 时 `insert` 资质 + `initCreditAccountOnce` + `insertHistory`。[initCreditAccountOnce](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentQualificationServiceImpl.java#L221-L252) 三层防护：①`uk_account_tenant_user`；②Redisson 账户锁内"查不到才插入"；③同事务。`catch (DuplicateKeyException)` **仅捕唯一键**，非唯一键异常不外抛也不吞（不捕获其他异常） | **通过（设计自洽）** | 
| D1-a | 并发可行性与真实兜底 | 两台不同设备并发审核时，应用层校验（`selectPending`/`selectActive` 按 device 维度）不构成互斥；实际"只初始化一次"由 ①`uk_account_tenant_user` 唯一键 + ②Redisson 账户锁 共同保证 | 通过（逻辑成立），**须真实 Redis 复验**（H2 单测为 mock 锁，不构成证据） |
| D2 | **Redis 锁**（key/维度/释放/等待/租约/异常） | [InstrumentLockRedisDAO](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/redis/InstrumentLockRedisDAO.java)：`lock(key, callable)` → `redissonClient.getLock(key)`，`lock.lock(10_000, MILLISECONDS)`（**租约固定 10s**，无 watchdog 续租；**等待=无限阻塞**直到获取），`finally` 中 `isHeldByCurrentThread()` 才 `unlock`；`RuntimeException` 原样抛，其余包 `RuntimeException`。key 全部含 `tenantId`：`qualApplyKey(tenant,device,user)`、`creditAccountKey(tenant,user)`、`suspendKey(tenant,user)` | 通过（维度含租户/用户/设备，释放有守卫） |
| D2-a | 锁与事务边界 | `initCreditAccountOnce` 的 Redisson 锁在 `transactionTemplate.execute` **内部**获取 → **锁释放在事务提交之前**，锁保护范围**短于**事务范围；`doCreate`（暂停）同理 | **风险登记（不阻塞）**：首审最终安全性依赖 DB 唯一键 + InnoDB 索引锁兜底。若业务耗时 >10s 租约到期亦可能失效（当前各操作均远低于 10s）。**mock 锁测试结果不得作为真实锁已验证之证据** |
| D3 | **积分流水**（余额与流水同事务；before/after 链；防重是否误拒） | [doAdjust](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentCreditServiceImpl.java#L137-L180) 在 `transactionTemplate.execute` 内：`selectByUserId` → `selectByIdForUpdate`（账户行锁）→ 防重（**仅当 `bizType && bizId 均非空**才 `selectCountByBiz`）→ `updateById(score,lastChangeTime)` → `insert` 不可变流水（before/after/原因/操作人快照） | **通过**：余额与流水同事务，行锁保证 before/after 链正确；第一期人工登记 `bizType/bizId` 可空 → 防重不误拒合法操作 |
| D4 | **暂停与资质联动** | SINGLE/ALL：`createSuspend` 校验范围（073/074）+ 数据范围（ALL 仅 `canManageAll`；SINGLE 需 `canManageDevice`）+ 重复覆盖校验（079）→ `doCreate` insert + G12 `updateSuspendIfActive`（不碰 REVOKED/EXPIRED）。提前解除：`updateReleaseIfActive`（affectedRows 守卫）+ `resumeUncoveredQualifications`（仅恢复无其他生效暂停覆盖者）。多条并存：SINGLE+ALL 并存时解除 SINGLE 仍被 ALL 覆盖→不恢复；到期：`expireSuspends` 逐条事务 + 恢复 | **通过**（与单测 testSuspendRelease_resumeOnlyUncovered / testSuspendExpire_andIdempotent 语义一致） |
| D5 | **G13 复核（重点）** | `applyQualification`/`auditApply` **均无暂停校验**；代码注释明示"暂停不拦截资质申请/审核，拦截在预约侧（INSTRUMENT-03）"。lab 模块内**不存在仪器预约（reservation）实现** — 相关匹配仅出现于注释、`credit_flow.biz_type` 枚举值（RESERVATION/SUSPEND/FREEZE_BATCH/REPAIR/MANUAL）与 register/plasmid 模块 | **HOLD（H2）**：G13 行为=暂停期间新审核通过资质为 ACTIVE（方案 A，已冻结、未擅改）。该行为与"后续预约拦截"的一致性**依赖预约侧读取暂停记录才能阻止预约**；**预约侧当前尚不存在，一致性无法证明**。**依赖关系已明确标出**：在 INSTRUMENT-03 实现预约前，暂停仅能阻止"资质联动为 SUSPENDED 的既有资质"，无法阻止"暂停期间新获 ACTIVE 资质"的预约——属**已知且需在下游显式承接**的依赖，非本任务可修复 |
| D6 | **服务端鉴权**（Controller `@PreAuthorize` vs 菜单权限串；Service 数据范围/本人过滤） | 三 Controller 权限串与 9 个按钮**完全一致**（见第四节 4.1/4.4）。Service：`getMyCredit`/`getMyFlowPage`（强制 `loginUserId`）/`getMySuspends`（强制本人）/`getMyQualifications`（强制本人）；`getCreditPage`/`getFlowPage`/`getFlowExportList`/`adjust` 非管理员 → 403（`requireManageAll`）；`getApplyPage`/`getQualificationPage`/`getSuspendPage` 非管理员 → 本人 OR 授权设备（无授权设备则空/本人） | **通过（静态检查）**；**真实 HTTP 验证未做**（不得将静态检查记为 HTTP 已验证） |
| D7 | **租户隔离** | 6 个 DO 全部 `extends TenantBaseDO`；`application.yaml` `yudao.tenant.ignore-tables` 为空 → 6 表**不在忽略名单**；`TenantLineInnerInterceptor`（`TenantDatabaseInterceptor`）对继承 `TenantBaseDO` 的实体与手写 `@Select`（如 `SELECT ... WHERE id=#{id} AND deleted=0 FOR UPDATE`）自动追加 `tenant_id`；唯一键均含 `tenant_id`；`AdminUserApi` 查询受租户过滤 | **通过（静态）**；**H2 单测未加载租户拦截器** → **不得作为真实隔离通过证据**（须真实拦截器复验） |
| D8 | **导出** | `getFlowExportList` 复用 `requireManageAll` + `selectExportList`；导出权限 `lab:instrument:credit:export` 仅授 906；列表 `getFlowPage` 同为 `requireManageAll` | **通过**：导出与列表同权限同数据范围，**不能绕过分页授权**（904 无 `credit:export`，且即便有也会被 `requireManageAll` 拦为 403） |
| D9 | 错误码一致性 | `INSTRUMENT_` 段 045~079 全部存在（资质 045~059 / 信用 060~066 / 暂停 070~079） | 通过 |

**D 节结论**：审计/加扣分/解除/到期的事务与条件更新设计**自洽**；主要未决为 **H2（G13 依赖不可证）**、**D2-a（锁短于事务，须真实 Redis 复验）**、**D6/D7（静态通过、真实 HTTP/真实租户拦截器未验证）**。

---

## 七、E. 部署前真实环境验收准备

报告 §9 六步（[15-INSTRUMENT-02-开发交付报告.md](file:///E:/lixin/dev/doc/03-仪器管理/15-INSTRUMENT-02-开发交付报告.md#L260-L267)）：覆盖度评估与逐项执行要求如下（**本次不执行**）。

| 步 | §9 原文要点 | 前置条件 | 操作角色 | 预期结果 | 失败判据 | 证据采集 | 真实环境必需项 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 904 登录：首页见两卡片，菜单仅两页；设备详情可见"申请资质"；不见三个管理页 | Schema+Menu SQL 已执行；后端重启；前端重登拉菜单 | 904 | 首页 2 卡片；菜单仅 2 页；`v-hasPermi` 生效 | 出现管理页卡片/菜单，或申请入口缺失 | 前端截图 + `GET /system/menu/get-routers` 返回 | **Web Controller + 真实菜单** |
| 2 | 申请→906 审核通过→得资质 + 信用账户 100 分；第二台设备再通过→仍 100 | 步 1 完成 | 904 申请 / 906 审核 | 资质 ACTIVE；账户首次 =100 分且仅一次；第二台设备不重复发分 | 第二台设备后账户 ≠100 或出现第二条"发分"流水 | `lab_instrument_credit_account`、`credit_flow`、`qualification` 只读查询 + 接口响应 | **真实 Redis 锁 + 真实租户拦截器**（D1/D2-a） |
| 3 | 906 加/扣分（正/负 delta）→ before/after 链正确；导出 Excel 生成 | 步 2 有账户 | 906 | 分值正确变化；`score_after = score_before + delta` 链连续；xls 下载 | 链断裂、导出 403/失败、无权限用户可导出 | 流水表 + 下载文件 + 响应头 | Web Controller |
| 4 | 906 创建 SINGLE/ALL 暂停→资质联动 SUSPENDED；提前解除→符合条件恢复；到期由 Job 自动 EXPIRED | **Job 已注册且可执行**（H1 解） | 906 | 创建即 SUSPENDED；解除仅恢复无覆盖者；到期自动 EXPIRED + 恢复 | 资质误恢复/误置 EXPIRED；到期未处理 | 暂停表 + 资质表 + Job 执行日志 | **Job 可执行 + 真实 Redis** |
| 5 | 负向：904 直调 `adjust/createSuspend` 应 403；跨租户不可见 | 步 1 完成 | 904 / 他租户用户 | 写端点 403；跨租户数据不可见 | 写端点成功；跨租户可见 | 接口状态码 + 跨租户查询结果 | **真实租户拦截器 + Web** |
| 6 | INSTRUMENT-01 回归：设备/平台/房间/负责人/须知正常，10 条测试数据完好 | 全部前置完成 | 906 | 五页面正常；10 条数据齐全 | 数据缺失/页面异常 | 五表 `COUNT(*)` 前后对比 | Web + DB |

**§9 覆盖度结论**：六步覆盖了 904/906 权限、本人数据边界、首审 100 分、第二台设备不重复发分、加扣分流水、暂停联动、到期恢复、跨租户隔离与 INSTRUMENT-01 回归。**缺口**：
- §9 未显式列出"**导出 Excel 复用列表数据范围**"的负向验证（建议在步 3 加分：904 调 `flow/export-excel` 预期 403）；
- §9 未显式列出"**暂停期间审核通过的新资质为 ACTIVE**（G13）"的现场观测点（建议在步 4 加：暂停中让另一设备审核通过，观察资质 ACTIVE 且暂停仍 ACTIVE）；
- §9 未强调"**必须在真实 Redis + 真实租户拦截器 + Web Controller**"三件套下执行（H2 单测为 mock 锁且未加载租户拦截器）。

**测试数据边界**：本批 6 张表为空表上线；验收产生的申请/资质/账户/流水/暂停数据**新增于 6 张新表**，与 INSTRUMENT-01 的 10 条测试数据（`lab_instrument_platform/room/device/manager/notice`）**物理隔离**。**验收不得清理 INSTRUMENT-01 现存 10 条数据**；新表验收数据如需清理，单独按 id 范围处理并由负责人授权。

---

## 八、必须修复的问题与建议修复顺序

### 8.1 HOLD / 部署阻塞（必须先决策/解决）

| 序 | 编号 | 问题 | 位置 | 证据 | 建议 |
| --- | --- | --- | --- | --- | --- |
| 1 | H1/B1 | local 运行 profile 排除 Quartz → Job 无执行承载 | [application.yaml](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-server/src/main/resources/application.yaml#L5-L6) `profiles.active: local`；`application-local.yaml:10` exclude `QuartzAutoConfiguration` | `SchedulerManager(null)` → `validateScheduler` 抛 NOT_IMPLEMENTED；34 行 `infra_job` 全 status=2 | **负责人决策**：改用不排除 Quartz 的 profile（如 dev）并实测 Scheduler 存在→经后台创建任务；或明确"本期不启用自动到期，暂停仅人工解除"并书面说明。**未决策前，暂停到期 Job 验收无法通过** |
| 2 | H2 | G13 一致性依赖预约侧拦截，而预约模块不存在 | [InstrumentQualificationServiceImpl](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentQualificationServiceImpl.java#L186-L203) 注释；lab 模块无 reservation 实现 | 暂停期间新资质=ACTIVE（方案 A 冻结）；预约侧尚未实现 | **负责人确认**：接受"暂停期新资质 ACTIVE 由 INSTRUMENT-03 预约侧拦截承接"为**明确转移依赖**，并在 INSTRUMENT-03 需求中强制"预约前校验生效暂停记录"。不擅改 G13 |
| 3 | B4 | `CREATE TABLE IF NOT EXISTS` 掩盖结构不一致；验收仅核 `score` 一列 | schema §0.1/§2.3 | 预检仅"表存在性/字符集/字典"；`IF NOT EXISTS` 静默跳过旧结构 | **已修复（FIX-01）**：schema 新增 §0.4「六表列级结构预检」（0.4.1 列数 / 0.4.2 公共审计列 / 0.4.3 主键唯一键 / 0.4.4 关键业务列），全部只查 `information_schema`（六表不存在时安全、返回空集）；§3 增列停止条件 4。详见 17 号整改报告 §1.3 |
| 4 | B2 | 非管理员"设备负责人"审核路径无角色可达（I3） | menu §3.1/§3.2 仅授 906/904 | 后端 `canManageDevice` 分支存在，但无角色被授权 `qualification:audit` | ~~裁决状态 PENDING~~ → **已裁决（2026-10-15）**：新增角色 908 `instrument_device_manager` + 8 条授权 SQL（见 8.4 落地表 / [18 号报告](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md)），**未执行** |
| 5 | B3 | `:query` 权限串在管理与本人端点共用 | menu §3.2 授 904 `suspend:query`；Controller 三处 `:query` 端点 | 904 持 `suspend:query` 可调 `/suspend/page`（Service 返回空兜底）；`credit:query` 共用 4 端点 | ~~裁决状态 PENDING~~ → **已裁决（2026-10-15）**：**保留共用权限串不拆分**，强化服务端范围（`getSuspendPage`/`getQualificationPage` 空兜底改为显式 403，见 8.4 落地表） |

### 8.2 已修复（FIX-01，2026-10-15）

| 序 | 编号 | 问题 | 位置 | 修复结果 |
| --- | --- | --- | --- | --- |
| 6 | M1 | Menu SQL 两处注释计数写错（13 vs 14） | menu §2 注释、§3.1 注释 | **已订正为 14**；经全文复核，其余注释计数（"14 条""9 个权限串""5 页面+9 按钮""906=14/904=6"）均与实际一致，无其他不一致 |
| 7 | M2 | 预检 SQL 中 `AND`/`OR` 混用缺括号（语义正确但易误读） | menu §0.3 | **已加括号**：改为 `WHERE deleted=b'0' AND (permission LIKE '...qualification:%' OR permission LIKE '...credit:%' OR permission LIKE '...suspend:%')`。经复核，**schema 脚本预检无 AND/OR 混用**（§0.1/§2.4 用 `UNION ALL`），无需改动 |

### 8.3 建议（风险登记）

| 序 | 编号 | 问题 | 建议 |
| --- | --- | --- | --- |
| 8 | R1 | Redisson 锁释放在事务提交前（锁范围 < 事务范围）；租约固定 10s 无续租 | 真实 Redis 复验并发首审；如后续操作可能 >10s，评估改为 watchdog 续租或缩短事务 |
| 9 | R2 | `uk_account_tenant_user` 不含 `deleted` | 无账户删除路径，风险低；如未来引入账户删除需重新评估 |
| 10 | R3 | 不可变表 Mapper 继承 `BaseMapper` 暴露 `updateById/deleteById` | 当前无调用点；如需强约束可加代码评审规约（不新增删除接口） |

### 8.4 决策记录（仅记录负责人已明确给出的裁决；未裁决者保持 PENDING）

> 本节**只登记负责人明确裁决**；截至本报告（PRECHECK-01 / FIX-01）撰写时，H1/H2/B2/B3 **均未收到裁决**，故全部为 PENDING。**Trae 不代替负责人作出决定。**
>
> ⚠️ **后续更新（2026-10-15，TASK INSTRUMENT-02-DECISION-IMPLEMENT-01）**：负责人已对 H1/H2/B2/B3 作出**正式裁决**并落地（H1 B 方案不启用自动到期；H2 接受 G13 转移依赖；B2 允许设备负责人审批并新增角色 908；B3 保留共用权限串强化服务端范围）。**下表 PENDING 记录保留为历史（不抹除）**；裁决与落地证据见 [18-INSTRUMENT-02-裁决落地与部署准备报告.md](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md)。

| 编号 | 待裁决事项（负责人须明确的内容） | 裁决 | 状态 | 裁决人/日期 | 裁决后可能触发的修改清单（待裁决后另立任务，本任务不实施） |
| --- | --- | --- | --- | --- | --- |
| H1 | ① Quartz 运行环境（采用哪个 profile：`local` 放开 Quartz / 改用 `dev` / 其他）；② 任务注册方式（后台创建 vs 手写 `infra_job`）；③ 暂停自动到期的验收门槛（是否本期必须验收自动到期） | — | **PENDING** | — | 可能需：切换/调整 profile（`application-local.yaml` / `application-dev.yaml`）；或在后台注册 Job；或调整验收范围（§九 / §九 U1） |
| H2 | 预约侧暂停校验依赖如何承接：是否接受"暂停期新资质 ACTIVE 由 INSTRUMENT-03 预约侧拦截承接"，并在 INSTRUMENT-03 强制"预约前校验生效暂停记录" | — | **PENDING** | — | 可能需：在 INSTRUMENT-03 需求/设计文档写入"预约前校验暂停"为强制项；本任务不改 G13 代码 |
| B2 | 资质审批主体及其角色/权限映射：是否允许"非管理员设备负责人"自助审核；若允许，需授权哪个角色、哪些权限串；若不允许，是否书面确认"审核仅 906 管理员" | — | **PENDING** | — | 可能需：新增/授权角色（`system_role`/`system_role_menu`）并追加菜单 SQL；或更新权限矩阵文档说明。**本任务不改菜单 SQL / 权限矩阵** |
| B3 | 本人查询与管理查询的权限边界：是否拆分共用权限串（如 `suspend:query` 拆为本人/管理两个串），还是书面确认"共用 + Service 数据兜底"为有意设计；服务端数据范围是否需进一步收紧 | — | **PENDING** | — | 可能需：调整菜单权限串 + Controller `@PreAuthorize` + Service 数据范围（跨 Java/SQL/菜单三层，须另立任务）。**本任务不改代码** |

**上述 PENDING 记录保留为历史。以下为负责人 2026-10-15 正式裁决及落地（DECISION-IMPLEMENT-01）：**

| 编号 | 负责人 2026-10-15 正式裁决 | 落地动作 | 裁决后状态 |
| --- | --- | --- | --- |
| H1 | 采用 **B 方案：本期不启用自动到期**；不注册/不启用 Job、不调 Quartz profile、保留人工解除、暂停在人工解除前持续生效（`end_time` 到达不自动解除） | `selectActiveCovering` 去 `end_time` 条件；Job/Service/枚举 javadoc 加注"本期不启用"；前端文案改"计划结束时间/实际解除时间" | **已裁决 + 已落地**；**U1（Job 实际调度）本期不适用** |
| H2 | **接受 G13 转移依赖**：暂停期新资质审核通过为 ACTIVE 保持、不强制改 REJECTED；在 INSTRUMENT-03 强制"预约前校验生效暂停" | [03-预约规则与并发控制设计.md](file:///E:/lixin/dev/doc/03-仪器管理/03-预约规则与并发控制设计.md) §8.1.1（7 条 MUST）；本任务不开发预约模块 | **已裁决 + 已落地**；**U2 待 INSTRUMENT-03** |
| B2 | **允许设备负责人审批其负责设备的资质申请，必须增加角色和权限** | 新建 [20261015_instrument_02_device_manager_role.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_device_manager_role.sql)（角色 908 + 8 授权，**未执行**）；`auditApply` 双重校验补说明 | **已裁决 + 已落地**（SQL 待授权执行） |
| B3 | **不拆分共用权限串**，强化服务端范围；越权以项目既有规范明确拒绝 | 保留共用权限串；修正 `getSuspendPage`（空分页→403）、`getQualificationPage`（租户全量→403+恒过滤） | **已裁决 + 已落地** |

---

## 九、可由负责人执行的只读预检 SQL

以下 SQL **全部为只读 SELECT**，可在执行两个脚本前运行（数据库 `labplatform`，客户端 `--default-character-set=utf8mb4`）。**本任务未执行这些 SQL 之外无写入语句**。

### SQL-1：六表列级结构一致性预检（补 B4）——**权威版本已并入 schema §0.4**

FIX-01 已把列级预检正式写入 [20261015_instrument_02_schema.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_schema.sql) 的 **§0.4（0.4.1 逐表列数 / 0.4.2 公共审计列 / 0.4.3 主键与唯一键 / 0.4.4 关键业务列）**，并配套三种判定情形说明（首次部署 / 已存在且一致 / 已存在但不一致）与 §3 停止条件 4（禁止 DROP/重建）。**以脚本内 §0.4 为准。** 下列为等价速查（列数核对，仅查 `information_schema`，六表不存在时安全返回空集）：

```sql
-- 列数期望核对（仅已存在的表返回行；未列出=表不存在=首次部署正常，不报错）
SELECT c.table_name, COUNT(*) AS actual_cols
FROM information_schema.columns c
WHERE c.table_schema = DATABASE()
  AND c.table_name IN ('lab_instrument_qualification_apply',
                       'lab_instrument_qualification_apply_history',
                       'lab_instrument_qualification', 'lab_instrument_credit_account',
                       'lab_instrument_credit_flow', 'lab_instrument_suspend')
GROUP BY c.table_name ORDER BY c.table_name;
-- 期望列数：qualification_apply=25, apply_history=16, qualification=17, credit_account=14, credit_flow=21, suspend=22
```

### SQL-2：关键列定义核对（覆盖 A3/A4/A5，补 §2.3 仅核 score 的不足）

```sql
-- 2a. 租户/审计/逻辑删除列（六表须全部具备，类型/默认值一致）
SELECT table_name, column_name, column_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema=DATABASE()
  AND table_name IN ('lab_instrument_qualification_apply','lab_instrument_qualification_apply_history',
                     'lab_instrument_qualification','lab_instrument_credit_account',
                     'lab_instrument_credit_flow','lab_instrument_suspend')
  AND column_name IN ('tenant_id','deleted','creator','create_time','updater','update_time')
ORDER BY table_name, column_name;

-- 2b. 唯一键核对（须存在 uk_apply_tenant_no、uk_account_tenant_user）
SELECT table_name, index_name, non_unique, GROUP_CONCAT(column_name ORDER BY seq_in_index) AS cols
FROM information_schema.statistics
WHERE table_schema=DATABASE()
  AND table_name IN ('lab_instrument_qualification_apply','lab_instrument_credit_account')
GROUP BY table_name, index_name, non_unique
ORDER BY table_name, index_name;
```

### SQL-3：菜单段占用 / 权限串冲突 / 角色 / 套餐预检（等价 menu §0.1~0.7，汇总一处）

```sql
SELECT COUNT(*) AS cnt_13660_13673 FROM system_menu WHERE id BETWEEN 13660 AND 13673;   -- 期望 0
SELECT MAX(id) AS max_id FROM system_menu;                                              -- 期望 13653
SELECT id, permission FROM system_menu
WHERE deleted=b'0' AND (permission LIKE 'lab:instrument:qualification:%'
   OR permission LIKE 'lab:instrument:credit:%' OR permission LIKE 'lab:instrument:suspend:%'); -- 期望 0 行
SELECT id, name, type, parent_id, status, visible FROM system_menu WHERE id=13600;       -- 期望 1 行
SELECT id, name, code, status, tenant_id FROM system_role WHERE id IN (904,906);         -- 期望 2 行
SELECT id, status, package_id FROM system_tenant WHERE id=162;                            -- 期望 package_id=114
SELECT id, LEFT(menu_ids,1) AS b1, RIGHT(menu_ids,1) AS b2, LENGTH(menu_ids) AS len
FROM system_tenant_package WHERE id=114 AND deleted=b'0';                                 -- 期望 b1='[', b2=']'
SELECT id, name, handler_name, cron_expression, status FROM system_job;                   -- 若表名 infra_job，见 SQL-4
```

### SQL-4：`infra_job` 现状与注册模板核对（等价 C 节）

```sql
-- 4a. 确认目标 handler 尚未注册；并查看同模式模板行
SELECT id, name, status, handler_name, handler_param, cron_expression, retry_count, retry_interval, monitor_timeout
FROM infra_job WHERE handler_name='instrumentSuspendExpireJob';                            -- 期望 0 行
SELECT id, name, status, handler_name, cron_expression, creator, updater, deleted
FROM infra_job WHERE handler_name='plasmidBorrowOverdueJob';                               -- 期望 1 行（模板）
-- 4b. 注册前确认各列可空性/默认值（避免手写 INSERT 缺字段）
SELECT column_name, column_type, is_nullable, column_default, extra
FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='infra_job';
SELECT COUNT(*) AS total, SUM(status=2) AS stopped FROM infra_job;                         -- 现状：34 / 34
```

### SQL-5：INSTRUMENT-01 测试数据基线（禁止清理）+ 六表存在性（**首次部署安全**）

**5a. INSTRUMENT-01 现存表计数**（这 5 张表一定存在，安全执行；期望 platform=2、device=2、manager=3、notice=2、room=1，合计 **10 条**）：

```sql
SELECT 'platform' t, COUNT(*) c FROM lab_instrument_platform
UNION ALL SELECT 'device', COUNT(*) FROM lab_instrument_device
UNION ALL SELECT 'manager', COUNT(*) FROM lab_instrument_manager
UNION ALL SELECT 'notice', COUNT(*) FROM lab_instrument_notice
UNION ALL SELECT 'room', COUNT(*) FROM lab_instrument_room;
```

**5b. 六张 INSTRUMENT-02 新表「存在性」核对**（用 `information_schema`，六表不存在时安全返回空集，**不会因查询不存在的表而中断整组 SQL**）：

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('lab_instrument_qualification_apply',
                     'lab_instrument_qualification_apply_history',
                     'lab_instrument_qualification', 'lab_instrument_credit_account',
                     'lab_instrument_credit_flow', 'lab_instrument_suspend')
ORDER BY table_name;
-- 期望：首次部署前（DDL 前）返回 0 行；DDL 后返回 6 行。
```

> 六表**空表行数基线**（`COUNT(*)`）须**在 DDL 之后**执行，见 schema §2.4（该节直接 COUNT 六张业务表，前置条件=表已存在）；切勿在 DDL 前执行，否则会报"表不存在"。

---

## 十、复核通过后才允许考虑的部署步骤

**前置**：H1 裁决完成（**已满足**：B 方案，本期不启用自动到期，无需 Scheduler）、H2 依赖书面确认（**已满足**：接受转移依赖并写入 INSTRUMENT-03 强制约束）、B2/B3 裁决（**已满足**）与 B4 处理结论明确（**已修复**）、M1/M2 订正完成（**已修复**）、SQL-1~SQL-5（只读预检）全部通过（**已通过，无阻塞冲突**）、**device_manager_role §0 只读预检通过**（须在 menu SQL 之后）。**当前唯一剩余前置：负责人单独授权执行三个 SQL（schema → menu → device_manager_role）。**

> ⚠️ **裁决后调整（2026-10-15，DECISION-IMPLEMENT-01）**：
> ① 部署顺序中**新增第三步 role 脚本**（`20261015_instrument_02_device_manager_role.sql`，须在 menu SQL 之后）；
> ② 原"第 4 步 Job 注册"**取消**（H1 B 方案：本期不注册 Job、不作为验收条件）；
> ③ §十一 **U1 本期不适用**，其余真实环境验收项仍须执行。

1. **备份**：`mysqldump` 备份 `system_menu` / `system_tenant_package` / `system_role_menu` 三表（menu 变更兜底）；6 张新表为空表无需备份数据。
2. **Schema**：先在显式只读门槛下执行 schema §0（含 SQL-1/SQL-2）→ 执行 §1 DDL → §2 验收（含 SQL-1/SQL-2）→ 核对 6 表空表基线。
3. **Menu**：先在只读门槛下执行 menu §0（含 SQL-3）→ `START TRANSACTION;` §1（14 行）→ §2（≤14 行）→ §3.1（≤14 行）/§3.2（≤6 行）→ §4 验收核对 → 全符合 `COMMIT`，任一不符 `ROLLBACK`。
4. **Device Manager Role（新增，须在 menu 之后）**：只读门槛执行 `20261015_instrument_02_device_manager_role.sql` §0（0.1~0.8，预期 code/name 无冲突、id 908 空闲、目标菜单 6 行）→ `START TRANSACTION;` §1（1 行角色）+ §2（≤8 行授权）→ §3 验收核对 → 全符合 `COMMIT`，任一不符 `ROLLBACK`。
5. ~~**Job 注册**~~ **【已取消，H1 裁决 2026-10-15】**：本期不注册 `instrumentSuspendExpireJob`、不启用自动到期，Job 不作为验收条件。
6. **重启与重登**：重启后端；前端用户重新登录以拉取新菜单、刷新套餐（必要时在"租户管理"编辑保存套餐 114 触发同步）。
7. **真实环境验收**：按第七节六步（含三件套要求与两处补充观测点）逐项执行并留证；**验收数据仅限 6 张新表**，不得清理 INSTRUMENT-01 的 10 条数据。
8. **回归**：INSTRUMENT-01 五页面 + 10 条数据完好确认。

> 以上**仅为通过复核后的候选步骤**，本任务**不执行**其中任何一步。

---

## 十一、尚未完成的真实环境验证清单（不得虚报 PASS）

| 编号 | 未完成项 | 为何未完成 | 结论取值 |
| --- | --- | --- | --- |
| U1 | Job 实际被调度执行（暂停自动到期） | local profile 下 Quartz 禁用（H1）；未注册也无法执行 | **HOLD** → **本期不适用**（H1 裁决 2026-10-15：B 方案，本期不启用自动到期，不作为验收条件） |
| U2 | G13 与预约侧拦截一致性 | 预约模块不存在（INSTRUMENT-03） | **HOLD** → **待 INSTRUMENT-03**（H2 裁决 2026-10-15：接受转移依赖，强制约束已写入 §8.1.1；本任务不开发预约模块） |
| U3 | 并发双设备首审"仅初始化一次"在**真实 Redis** 下成立 | 既有 H2 单测锁为 mock，不构成证明 | 未验证 |
| U4 | 真实**租户拦截器**下跨租户不可见 + 唯一键按租户独立 | H2 测试未加载租户拦截器 | 未验证 |
| U5 | Controller `@PreAuthorize` 在**真实 HTTP** 下对 904/906 生效 | 仅静态比对，未发真实请求 | 未验证 |
| U6 | 904 数据边界（本人/空分页/403）真实响应 | 静态分析推断，未真实调用 | 未验证 |
| U7 | 导出 Excel 与列表同范围（含 904 导出 403） | 静态分析，未真实下载 | 未验证 |
| U8 | 暂停联动（SINGLE/ALL/并存/提前解除/到期）真实库行为 | 静态 + 单测，未真实库 | 未验证 |
| U9 | 两个 SQL 脚本本身**在真实库执行**且验收通过 | 本任务只读，未执行 | 未执行 |
| U10 | INSTRUMENT-01 回归 | 未执行任何真实操作 | 未执行 |

> 上述未完成项**一律不记为 PASS**。

---

## 十二、文件清单、实际执行过的命令及其结果

### 12.1 只读读取的文件（未修改）

| 文件 | 用途 |
| --- | --- |
| [20261015_instrument_02_schema.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_schema.sql) | DDL 与预检/验收核查 |
| [20261015_instrument_02_menu.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_menu.sql) | 菜单/授权/套餐核查 |
| [InstrumentSuspendExpireJob.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/job/InstrumentSuspendExpireJob.java) | 定时任务核查 |
| [PlasmidBorrowOverdueJob.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/job/PlasmidBorrowOverdueJob.java) | 同模式先例 |
| [InstrumentQualificationServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentQualificationServiceImpl.java) | 首审/G13/鉴权核查 |
| [InstrumentCreditServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentCreditServiceImpl.java) | 积分流水核查 |
| [InstrumentSuspendServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentSuspendServiceImpl.java) | 暂停联动核查 |
| [InstrumentLockRedisDAO.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/redis/InstrumentLockRedisDAO.java) | Redis 锁核查 |
| [InstrumentSuspendController.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument/InstrumentSuspendController.java) / [InstrumentCreditController.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument/InstrumentCreditController.java) / [InstrumentQualificationController.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument/InstrumentQualificationController.java) | @PreAuthorize vs 菜单权限串核查 |
| [YudaoQuartzAutoConfiguration.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-framework/yudao-spring-boot-starter-job/src/main/java/cn/iocoder/yudao/framework/quartz/config/YudaoQuartzAutoConfiguration.java) / [TenantJobAspect.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-framework/yudao-spring-boot-starter-biz-tenant/src/main/java/cn/iocoder/yudao/framework/tenant/core/job/TenantJobAspect.java) | 调度/多租户 Job 机制核查 |
| [application.yaml](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-server/src/main/resources/application.yaml) / application-local.yaml / application-dev.yaml | 运行 profile 与 Quartz 开关核查 |
| 6 个 `*DO`、6 个 `*Mapper`、`ErrorCodeConstants.java`、`InstrumentScopeSupport.java`、前端 5 页面与 `Home/Index.vue`、API `index.ts` | 逐列/逐串一致性核查 |
| [15-INSTRUMENT-02-开发交付报告.md](file:///E:/lixin/dev/doc/03-仪器管理/15-INSTRUMENT-02-开发交付报告.md) | §8/§9 部署与验收步骤核查 |

### 12.2 实际执行的数据库命令（**仅 SELECT**）

命令模板（PowerShell）：
```
& 'D:\worktools\phpstudy_pro\Extensions\MySQL8.0.12\bin\mysql.exe' --host=127.0.0.1 --port=3306 \
  --user=bencao --password=bencao2026 --default-character-set=utf8mb4 --table \
  --database=labplatform --execute="<SELECT>"
```

| # | 查询（摘要） | 结果（摘要） |
| --- | --- | --- |
| 1 | `SELECT VERSION();` | 8.0.12 |
| 2 | `SHOW TABLES LIKE 'lab_instrument%';` | 5 张（platform/room/device/manager/notice）；INSTRUMENT-02 的 6 表**不存在** |
| 3 | `SELECT MAX(id) FROM system_menu;` | 13653（13660~13673 空闲） |
| 4 | `SELECT id,name,type,parent_id,path,status,visible,deleted FROM system_menu WHERE id=13600;` | 1 行：仪器管理/type1/parent 13478/status0 |
| 5 | `SELECT id,permission FROM system_menu WHERE permission LIKE 'lab:instrument:%';` | 仅 platform/device/room/manager/notice 五组 → 无冲突 |
| 6 | `SELECT id,name,code,status,tenant_id FROM system_role WHERE id IN (903,904,905,906,907);` | 5 行，tenant_id=162，status=0 |
| 7 | `SELECT id,name,package_id,status FROM system_tenant WHERE id=162;` | package_id=114，status=0 |
| 8 | `SELECT id,LENGTH(menu_ids),LEFT(menu_ids,10),RIGHT(menu_ids,12) FROM system_tenant_package WHERE id=114;` | len=1378；head `[1,2,3,...`；tail `...,13651,13652,13653]` |
| 9 | `SELECT role_id,COUNT(*) FROM system_role_menu WHERE tenant_id=162 AND menu_id BETWEEN 13600 AND 13653 GROUP BY role_id;` | 906=26、903=26、904=4（13600/13601/13602/13621） |
| 10 | `SHOW INDEX FROM system_role_menu;` | 仅 PRIMARY(id) + idx_role_id(role_id)，**无 (role_id,menu_id) 唯一键** |
| 11 | `SELECT dict_type,COUNT(*) FROM system_dict_data WHERE dict_type LIKE 'lab_instrument%' GROUP BY dict_type;` | credit_reason=4、suspend_scope=2 |
| 12 | `SELECT COUNT(*) FROM lab_instrument_device/manager/notice/room/platform;` | 2/3/2/1/2（合计 10 条） |
| 13 | `SELECT COUNT(*),SUM(status=2) FROM infra_job;` | 34 / 34（全 STOP） |
| 14 | `SELECT id,name,status,handler_name,cron_expression,creator,updater FROM infra_job WHERE handler_name='plasmidBorrowOverdueJob';` | 1 行：id=12914、status=2、cron `0 0/5 * * * ?`、creator/updater='1' |
| 15 | `SELECT COUNT(*) FROM infra_job WHERE handler_name='instrumentSuspendExpireJob';` | 0（尚未注册） |
| 16 | `SELECT column_name,column_type,is_nullable,column_default FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name IN ('system_menu','system_role_menu');` | 确认 `system_menu` **无 tenant_id 列** |

**未执行的命令**：任何 `INSERT/UPDATE/DELETE`、任何 DDL、任何 Job 注册、任何服务重启、任何业务接口调用。

### 12.3 本次交付物

- 本报告（复核 + FIX-01 修订）：[16-INSTRUMENT-02-部署前集中复核报告.md](file:///E:/lixin/dev/doc/03-仪器管理/16-INSTRUMENT-02-部署前集中复核报告.md)
- 修订后的 schema / menu SQL：[20261015_instrument_02_schema.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_schema.sql)、[20261015_instrument_02_menu.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_menu.sql)
- 新建整改报告：[17-INSTRUMENT-02-部署前整改报告.md](file:///E:/lixin/dev/doc/03-仪器管理/17-INSTRUMENT-02-部署前整改报告.md)
- **（DECISION-IMPLEMENT-01 追加，2026-10-15）** 新建角色授权 SQL：[20261015_instrument_02_device_manager_role.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_device_manager_role.sql)；新增 H2 强制约束：[03-预约规则与并发控制设计.md](file:///E:/lixin/dev/doc/03-仪器管理/03-预约规则与并发控制设计.md) §8.1.1；新建裁决落地报告：[18-INSTRUMENT-02-裁决落地与部署准备报告.md](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md)

### 12.4 FIX-01 实际执行过的命令（**仅只读 SELECT，无任何写入**）

| # | 查询（摘要） | 结果（摘要） |
| --- | --- | --- |
| 17 | schema §0.4 四条预检（0.4.1 列数 / 0.4.2 公共列+`FIELD()` 排序 / 0.4.3 主键唯一键 / 0.4.4 关键业务列）合并执行 | **无报错、全部返回空集**（六表尚未创建）→ 证明 §0.4 语法正确、且首次部署（表不存在）时安全、不中断 |
| 18 | 修订后 menu §0.3（`deleted=b'0' AND (permission LIKE 'qualification:%' OR 'credit:%' OR 'suspend:%')`） | `rows_returned = 0` → 与修订前语义一致，无权限串冲突 |

> 以上两条为 FIX-01 唯一执行的命令，均为只读 SELECT，未产生任何数据库写入。**未执行**：任何 DDL/INSERT/UPDATE/DELETE、Job 注册、profile 切换、服务重启、业务接口调用。

---

## 十三、停止声明

本报告经 **两个任务** 叠加：①`INSTRUMENT-02-DEPLOY-PRECHECK-01`（只读复核）；②`INSTRUMENT-02-DEPLOY-PRECHECK-FIX-01`（修订 M1/M2/B4、登记 H1/H2/B2/B3 决策状态）。

两任务**共同遵守的只读边界（均未违反）**：
- 未执行任何 DDL / INSERT / UPDATE / DELETE（FIX-01 仅执行只读 SELECT，见 12.4）；
- 未注册或启动定时任务；
- 未切换运行 profile，未重启服务，未调用产生业务数据的接口；
- 未修改任何 Java / Vue / 配置文件；仅按 FIX-01 授权修订了 `20261015_instrument_02_schema.sql`、`20261015_instrument_02_menu.sql`、本报告、15 号交付报告，并新建 17 号整改报告；
- 未清理 INSTRUMENT-01 的任何测试数据，未修改质粒管理模块；
- 未执行部署步骤，未启动 INSTRUMENT-03。

**最终结论（FIX-01 撰写时）：HOLD**。解除条件为：H1 运行 profile/Job 承载裁决（PENDING）；H2（G13→预约侧拦截）依赖书面确认（PENDING）；B2/B3 裁决（PENDING）；随后按第十节在真实环境（真实 Redis + 真实租户拦截器 + Web Controller + 可执行 Scheduler）完成第十一节 U1~U10 全部验证后方可转 PASS。M1/M2/B4 已修复（见 8.2 / 8.1 行 3）。

> ⚠️ **后续更新（2026-10-15，TASK INSTRUMENT-02-DECISION-IMPLEMENT-01）**：负责人已正式裁决 H1/H2/B2/B3 并落地（见 8.4 落地表 / [18 号报告](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md)）。**H1/H2 停止条件解除，B2/B3 部署阻塞解决**；**U1 本期不适用**（H1 B 方案），**U2 待 INSTRUMENT-03**。静态验证结论为 **CODE/PRECHECK PASS**；**部署状态仍为 NOT DEPLOYED / 待授权**（三 SQL 未执行、角色未真实创建、HTTP/并发未实测、U3~U10 仍为未验证）。
