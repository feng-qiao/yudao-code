# INSTRUMENT-06 R5 部署前最终预检与测试报告

**任务**：TASK CODEX-INSTRUMENT-06-R5-PREDEPLOY-01  
**日期**：2026-10-20  
**范围**：前端全量 TypeScript 修复、SQL 58/59 静态复核、目标库只读预检准备、安全定向回归  
**最终结论**：本轮真实数据库预检 **PRECHECK INCOMPLETE**；SQL 执行状态仍为 **SQL EXECUTION HOLD**

## 1. 结论摘要

- `pnpm run ts:check`：**PASS**，全量检查无 TypeScript 诊断。
- INSTRUMENT-06 定向 Maven：**PASS，64 tests / 0 failures / 0 errors / 0 skipped**。
- INSTRUMENT-03 预约创建、生命周期、调整和 H2 并发定向回归：**PASS，68 tests / 0 failures / 0 errors / 0 skipped**。
- 测试配置使用 H2 内存数据库；涉及预约锁/编号的测试依赖均为 Mock，或使用注释说明的 H2 行锁路径。未启动服务或容器，未执行数据库/Redis写入。
- SQL 58/59 未执行。当前环境未发现 MySQL/MariaDB CLI 或数据库专用连接工具，且本任务不允许改连线/凭据，因此目标库所有实时状态保持 **UNKNOWN**。已生成 Navicat 只读查询文件：[INSTRUMENT-06-SQL58-59目标库只读预检.sql](INSTRUMENT-06-SQL58-59目标库只读预检.sql)。
- SQL 59 静态发现：其自动回退段的套餐 JSON 更新表达式不可靠，不能作为自动回退步骤；另有设计稿把 SQL DML 描述为整体事务可回滚，但实际部署应逐项验证事务引擎与客户端行为。手册要求使用预先留存的备份恢复套餐/授权，禁止执行该自动回退段。
- 当前菜单、角色、租户、套餐和维修表结构的真实部署状态未核实。因此即使代码与本地测试通过，仍不能批准 SQL 执行或宣称部署完成。

## 2. TypeScript 原始问题及修复

首轮 `pnpm run ts:check` 发现 13 条诊断，均限定在任务列出的五个文件中：

| 文件 / 原始位置 | 原因 | 最小修复 | 结果 |
|---|---|---|---|
| `src/api/lab/announcement/index.ts:2` | 未使用的 `Dayjs` 类型导入 | 删除无引用导入 | PASS |
| `src/views/fms/report/components/FmsReportFormulaForm.vue:136,143` | `includes` 数组被推断为数值字面量联合类型，字典值为 `number` | 将两个允许规则列表显式声明为 `number[]`，过滤行为不变 | PASS |
| `src/views/hrm/employee/index.vue:507` | 状态统计 API 参数声明为 `PageParam`，调用还传入后端查询 VO 支持的 `surveyType` | 在 API 层新增 `HrmEmployeeStatusCountReqVO extends PageParam`，列明 `statusCategory?`、`surveyType?`；后端 `HrmEmployeePageReqVO` 具有对应字段 | PASS |
| `src/views/lab/v2/plasmid-audit/index.vue:229,232,251` | 可选字符串传入不接受 `undefined` 的字典标签值 | 展示值用 `?? ''` 明确空值 | PASS |
| `src/views/lab/v2/plasmid-audit/index.vue:248` | 可选 `plasmidTypeId` 直接用于索引对象 | 先判断 `null/undefined`，无值时显示空字符串 | PASS |
| `src/views/lab/v2/plasmid-audit/index.vue:511` | `useI18n()` 解构出的 `t` 未使用 | 删除未使用变量 | PASS |
| `src/views/lab/v2/plasmid/index.vue:246,249,268` | 可选字符串传入字典标签值 | 展示值用 `?? ''` 明确空值 | PASS |
| `src/views/lab/v2/plasmid/index.vue:265` | 可选 `plasmidTypeId` 直接用于索引对象 | 增加空值分支 | PASS |

未使用 `any`、忽略指令或关闭类型检查；没有改变公告、财务、人事或质粒业务规则。修复后执行 `pnpm run ts:check`，命令正常退出且没有诊断输出。没有因此引入额外类型错误。

## 3. 实际测试命令与结果

### 3.1 前端

```text
pnpm run ts:check
结果：退出码 0；0 条 TypeScript 错误
```

全量前端 lint/build 未执行，本任务指定的 TypeScript 检查已通过。前端页面运行时和菜单权限仍需部署后验收。

### 3.2 INSTRUMENT-06 定向测试

```text
mvn --% -pl yudao-module-lab -Dtest=Instrument06*Test -Dsurefire.failIfNoSpecifiedTests=false test
结果：BUILD SUCCESS；64 tests，0 failures，0 errors，0 skipped
```

覆盖故障报修、管理员确认/驳回、工单、预约影响、范围权限、跨租户、详情授权及并发状态更新等 R4 定向用例。测试资源 `yudao-module-lab/src/test/resources/application-unit-test.yaml` 指向 `jdbc:h2:mem:testdb`；非并发服务测试使用 Mockito。未访问目标 `labplatform`。

### 3.3 INSTRUMENT-03 定向回归

```text
mvn --% -pl yudao-module-lab -Dtest=Instrument03CReservationCreateTest,Instrument03DLifecycleTest,Instrument03R2AdjustT1T2Test,Instrument03ConcurrencyTest test
结果：BUILD SUCCESS；68 tests，0 failures，0 errors，0 skipped
```

覆盖设备状态准入、预约创建、取消、调整、完成、作废、历史和 H2 并发路径。四类测试均采用 `unit-test` Profile/H2 内存库。创建/生命周期/调整用例 Mock 预约锁、预约编号 DAO 等外部依赖；并发测试明确使用 H2 行锁路径。测试配置虽然声明了单测 Redis 地址，但本次所选测试没有调用 Redis DAO 的真实实现；没有启动或连接 Redis。未运行其余完整模块测试，也未验证真实 MySQL 隔离级别下的并发。

## 4. SQL 58/59 静态核验

### 4.1 前置条件矩阵

| 核验项 | 结论 | 依据 / 后续动作 |
|---|---|---|
| 当前数据库名与 MySQL 版本 | UNKNOWN | 未取得只读连接；Navicat 脚本第 1 节查询 |
| 五张维修表是否存在 | UNKNOWN | Navicat 脚本第 2 节；不存在才考虑执行 SQL 58；部分存在须逐表对照 |
| 已有字段、索引、唯一约束 | UNKNOWN | 脚本第 3–4 节；目标表若已存在，`CREATE TABLE IF NOT EXISTS` 不会做结构迁移 |
| SQL 58 五张表 DO/Mapper 字段映射 | 静态 PASS | 依照 R4 69 号逐表对照与当前源码；包含租户、审计和软删除列 |
| `impact_key` 唯一索引 | 静态 PASS / 运行时 UNKNOWN | DDL 定义 `UNIQUE (tenant_id, impact_key)`；真实索引状态及 MySQL 并发行为未核实 |
| 菜单 13684–13688 是否空闲 | UNKNOWN | 脚本第 5 节；任一 ID 已占用或软删除残留，立即 HOLD，不得自动换 ID |
| 父菜单 13600、祖先目录 13478 | UNKNOWN | 脚本第 6 节；核对租户、状态、层级与组件 |
| 角色 904/906/908/909 状态和租户归属 | UNKNOWN | 脚本第 7 节；909 的 ID 和 code 均不得与现存记录冲突 |
| 套餐 114 存在及菜单 JSON | UNKNOWN | 脚本第 8 节；不存在、无效 JSON 或现有菜单项冲突时 HOLD |
| 租户 162 存在及状态 | UNKNOWN | 脚本第 8 节 |
| 维修权限码冲突 | UNKNOWN | 脚本第 5 节；必须确认无既有同权限码菜单 |
| SQL 59 组件路径 | 静态 PASS | `lab/instrument/repair-order/list` 对应 `src/views/lab/instrument/repair-order/list.vue` |
| 菜单角色授权边界 | 静态 PASS | 904：页面及提交；906：五项；908：不新增维修授权；909：祖先、页面、提交、处理，不含 admin |
| 目标业务行数据、潜在 SQL/回滚影响 | UNKNOWN | 未查询目标库；脚本里的 `information_schema.tables.table_rows` 只能作估算，不可当精确行数 |
| 菜单与角色真实授权 | UNKNOWN | 未连接目标库；SQL 59 未执行 |
| SQL 58/59 执行状态 | 未执行 | 未运行任何设计稿语句，也未执行真实数据库写入 |

### 4.2 静态风险和注意项

1. SQL 58 五表无外键；其建表之间无 DDL 依赖，依赖现有设备、设备负责人和预约表。若五表中任一已存在，须逐表比较字段和索引后作单独迁移设计；不得重放 `CREATE TABLE IF NOT EXISTS` 后把它视作升级成功。
2. SQL 58 使用 MySQL DDL。`CREATE TABLE` 会造成隐式提交，不得承诺五表整体事务回滚。任何失败都应停止后续表，保存错误和已完成表清单，由 DBA 评估继续迁移或从备份恢复。
3. `UNIQUE (tenant_id, impact_key)` 是预约影响幂等的最终约束；服务查重与设备级并发串行用于降低碰撞。真实目标库若缺该唯一键、字段长度不同或字符集/排序规则不一致，不得部署。
4. SQL 59 有固定菜单/角色 ID、权限字符串和套餐 ID。其 INSERT 的幂等守卫不会自动修复同 ID 的错误现存记录。任何现存菜单、角色 code、角色租户归属或套餐 JSON 与预期不符时停止。
5. SQL 59 的菜单/授权/套餐 DML 脚本注释建议事务包装，但必须先验证相关表为事务引擎、同一连接执行、DDL 已另行完成；不得把 SQL 58 的 DDL 并入该事务承诺整体回滚。
6. SQL 59 §8.2.1 的套餐回退表达式把 JSON 数组值作为 `JSON_REMOVE` 路径参数，语义不可靠；且复杂数组聚合有长度、NULL、重复值和顺序风险。不得运行该自动套餐回退段。部署前应保存套餐 114 的原始 `menu_ids`、本批新增授权行和菜单/角色快照；回退由负责人/DBA 基于备份单独审批执行。
7. SQL 58 的注释 DROP 回退会删除维修数据表；只有在证明表内无需保留数据、且有经验证的备份后才能由 DBA另行评估。绝不在本轮执行。
8. SQL 59 直写绕过应用层缓存失效。按其设计稿通过菜单/角色管理 UI 保存以触发缓存失效；不直接清 Redis。缓存刷新后的角色菜单和真实按钮显隐必须在部署后验收。

## 5. SQL 执行准备与独立部署手册

详细步骤见：[71-INSTRUMENT-06-SQL58-59正式部署执行与验收手册.md](71-INSTRUMENT-06-SQL58-59正式部署执行与验收手册.md)。只读核验文件为：[INSTRUMENT-06-SQL58-59目标库只读预检.sql](INSTRUMENT-06-SQL58-59目标库只读预检.sql)。

SQL 58/59 前置条件均应先在目标库由负责人/DBA 手工预检。由于本轮实时状态全部 UNKNOWN，目前结论为 **SQL EXECUTION HOLD**。即使后续全部预检通过，也必须由负责人另行明确授权，才可执行任何 DDL/DML。

## 6. Git 和变更清单

### 本任务实际修改

- 前端类型修复：
  - `yudao-ui-admin-vue3/src/api/hrm/employee/index.ts`
  - `yudao-ui-admin-vue3/src/api/lab/announcement/index.ts`
  - `yudao-ui-admin-vue3/src/views/fms/report/components/FmsReportFormulaForm.vue`
  - `yudao-ui-admin-vue3/src/views/lab/v2/plasmid-audit/index.vue`
  - `yudao-ui-admin-vue3/src/views/lab/v2/plasmid/index.vue`
- 文档：本报告、部署与验收手册、Navicat 只读预检 SQL。

### 本任务未修改

- 后端 Java、测试、生产/本地配置、SQL 58/59 源设计稿、C7 配置。
- 任何数据库、Redis、菜单、角色或套餐数据。

前端 `master` 相对上游领先 6 个提交；后端 `master` 相对上游领先 7 个提交。两个仓库开始前已含未提交 R2/R4 变更；另有环境文件、测试文件和依赖目录未跟踪项。本任务只在上述五个前端类型错误文件和文档目录新增/改动，保留所有原有未提交项；未暂存、提交、推送、删除或清理任何文件。`.env.prod` 及未跟踪环境文件内容未读取、未输出。

## 7. 运行时未验证项与剩余阻断

- 目标库真实版本、表结构、现有业务行、菜单、角色、套餐、租户状态：**UNKNOWN**。
- SQL 58/59 执行结果与菜单缓存状态：**UNKNOWN / 未执行**。
- 正式配置文件、目标运行 Profile、真实 MySQL 事务/唯一约束并发行为：未在本轮验证。
- 真实 HTTP 联调、用户角色菜单显示、业务操作验收：未启动服务，待部署后按手册执行。
- 预约创建开关 C7 未读取/修改，不作为测试条件；测试沿用当前 unit-test Profile。
- 软件不控制仪器物理可用状态；故障设备的物理停用、现场标识由实验室线下操作保障。

| 分类 | 结论 |
|---|---|
| TypeScript | **PASS** |
| INSTRUMENT-06 定向代码测试 | **PASS** |
| INSTRUMENT-03 所选定向回归 | **PASS** |
| 目标库只读预检 | **HOLD / UNKNOWN**（本地无安全连接工具） |
| SQL 58/59 | **SQL EXECUTION HOLD** |
| 生产/真实业务部署验收 | **HOLD** |

**下一步**：负责人/DBA 在隔离的 Navicat 只读连接中运行查询脚本并回传脱敏结果；按 71 号手册逐项确认备份、表结构、菜单/角色/套餐、回退方案后，再另行批准 SQL 执行。
