# INSTRUMENT-06 R6 真实数据库只读预检报告

**任务**：TASK INSTRUMENT-06-R6：Navicat 只读预检自动化  
**日期**：2026-10-20  
**最终结论**：**PRECHECK INCOMPLETE**  
**SQL 58/59**：本轮未执行；没有进行任何数据库写操作。

## 1. 任务范围与安全边界

本轮目标是确认真实目标库身份并执行 SQL 58/59 前置条件的只读查询。未连接其他数据库客户端、未读取/修改 Navicat 连接配置、未检查或显示凭据；未执行 SQL 58/59；未执行 `INSERT/UPDATE/DELETE/REPLACE`、DDL、存储过程或其他写操作；未启动/停止服务或容器，未写 Redis，未修改 C7，也未清理或提交 Git 变更。

未执行任何实际业务数据查询，也未对目标数据库作部署通过或业务验收结论。

## 2. 环境与访问方式

| 检查项 | 本轮结果 | 证据 |
|---|---|---|
| Navicat 安装目录 | 存在 | `D:\worktools\Navicat Premium Lite 18` |
| 可执行程序 | 存在 | `D:\worktools\Navicat Premium Lite 18\navicat.exe` |
| Navicat 进程/窗口 | 运行中 | 通过已授权 Windows Computer Use 的 `sky.list_apps()` 发现 Navicat Premium Lite 18 窗口 |
| 连接器 | 未发现数据库专用 MCP/连接器 | 工具目录检索结果无 MySQL/数据库查询工具 |
| 实际使用方式 | Navicat UI 已打开，但未能完成本轮查询操作 | 当前窗口状态能读取；后续截图捕获连续超时，按桌面操作恢复规则停止后续 UI 输入 |
| 凭据 | 未查看、未导出、未记录 | 未访问 Navicat 连接属性或密码管理内容 |

### 界面观察（不作为目标库身份核验）

Navicat 当前窗口显示：

- 查询页数据库下拉框显示 `labplatform`；界面状态栏显示“只读”。
- 编辑器中打开了本项目只读预检 SQL。界面呈现一条 `information_schema.tables` 查询的已有结果，结果区可见 `lab_instrument_device`、`lab_instrument_manager`、`lab_instrument_reservation`、`system_menu`、`system_role`、`system_role_menu`、`system_tenant`、`system_tenant_package` 等 8 行；没有显示五张维修表。
- 该结果已存在于打开的 UI 状态中；本轮没有执行该语句，且没有取得本轮 `DATABASE()`、服务器主机/端口或账号身份结果。不能确认其结果是否对应目标实例，也不能确认其时效性。因此该界面内容仅记为“未验证的已有 UI 结果”，不作为部署判据。
- 截图捕获恢复后仍报错：`window capture timed out: timed out waiting on channel`。按 Windows Computer Use 恢复规则，停止继续点击、输入或运行查询。

结论：本轮无法证明当前 Navicat 会话连接到负责人指定的目标实例及 `labplatform` schema；也没有验证数据库账号实际权限。故目标库事实保持 **UNKNOWN**。

## 3. 文件检查

以下文件在 `E:\lixin\dev\doc\03-仪器管理` 下均存在：

- `58-INSTRUMENT-06数据库DDL设计稿.sql`
- `59-INSTRUMENT-06菜单与角色授权设计稿.sql`
- `70-INSTRUMENT-06-R5部署前最终预检与测试报告.md`
- `71-INSTRUMENT-06-SQL58-59正式部署执行与验收手册.md`
- `INSTRUMENT-06-SQL58-59目标库只读预检.sql`

本报告及其查询清单是新增文件。没有改写 SQL 58、SQL 59 设计稿。

## 4. 只读预检 SQL 分类

审查对象：[INSTRUMENT-06-SQL58-59目标库只读预检.sql](INSTRUMENT-06-SQL58-59目标库只读预检.sql)。文件包含 14 条 `SELECT` 和 1 条 `SHOW GRANTS`，静态语句扫描确认每条活动语句均以 SELECT/SHOW 开始；没有 DML、DDL、过程调用或事务控制语句。只读查询文件未在 Navicat 中执行。

| 类别 | 语句 | 安全判断与执行状态 |
|---|---|---|
| A：只读，可用于预检 | 1. `SELECT DATABASE(), VERSION(), @@hostname, @@port, CURRENT_USER(), USER(), @@read_only, @@super_read_only` | MySQL 连接/服务器元数据读取；静态确认只读；本轮未执行 |
| A：只读，可用于预检 | 1.1 `SHOW GRANTS` | 只读显示当前账号授权；静态确认不含写操作；本轮未执行 |
| A：只读，可用于预检 | 2. `information_schema.tables` 查询维修表、INSTRUMENT-03 依赖表及系统表存在情况 | 元数据读取；本轮未执行 |
| A：只读，可用于预检 | 3. `information_schema.columns` 查询五张维修表字段、字符集和排序规则 | 元数据读取；本轮未执行 |
| A：只读，可用于预检 | 4. `information_schema.statistics` 查询索引/唯一键 | 元数据读取；本轮未执行 |
| A：只读，可用于预检 | 5–7. 查询菜单/权限码、父菜单、角色/code 与角色 ID 余量 | 仅读取部署对象和授权元数据；本轮未执行 |
| A：只读，可用于预检 | 5.1 查询菜单 ID 占用、最大 ID、父菜单 sort 和 AUTO_INCREMENT | 只读 SELECT/子查询与 `information_schema`；本轮未执行 |
| A：只读，可用于预检 | 8. 查询租户套餐关联和套餐 `JSON_VALID/JSON_LENGTH/JSON_CONTAINS` | 只读表达式；本轮未执行 |
| A：只读，可用于预检 | 9. 查询角色菜单关联 | 只读 SELECT/LEFT JOIN；本轮未执行 |
| A：只读，可用于预检 | 10. 读取 `information_schema.tables.table_rows` 估算行数 | 只读统计估算，非精确业务行数；本轮未执行 |
| A：有条件只读 | 11. 五张维修表精确 `COUNT(*)` | 仅在第 2 项确认五表全部存在后执行；任一不存在时不得运行该语句；本轮未执行 |
| B：不执行 | 查询文件中的无活动语句 | 未发现 B 类活动 SQL |
| C：绝对禁止 | SQL 58/59 的部署语句 | 本轮未打开执行：SQL 58 `CREATE TABLE`；SQL 59 `INSERT/UPDATE` 等部署 DML；未执行 |

SQL 58/59 草稿中还包含 `SET NAMES`、事务控制示例和回退段。它们不属于本轮预检清单：`SET NAMES` 改变会话设置，归为 B 类不执行；`BEGIN/COMMIT/ROLLBACK` 不是只读核验，归为 B 类不执行；SQL 58 的建表及 SQL 59 的 DML/DELETE/UPDATE 回退均归为 C 类绝对禁止。本轮没有运行这些语句。

## 5. 真实数据库核验结果

**本轮新执行的数据库 SQL：0 条。** 由于无法安全继续 Navicat UI 操作，下表均为 UNKNOWN。UI 中已有的目录结果不满足目标身份和新鲜度要求。

| 编号 | 只读检查与判定条件 | 本轮执行结果 | 结论 |
|---|---|---|---|
| DB-01 | 当前 schema 为目标 `labplatform`，版本/服务器主机与端口记录完整 | 未取得身份查询结果；UI 下拉框仅显示 `labplatform` | UNKNOWN |
| DB-02 | 当前连接身份和授权范围已确认，账号仅拥有满足预检所需的只读权限 | 未执行 `SHOW GRANTS`；“只读”界面标记不等同数据库账号权限 | UNKNOWN |
| DB-03 | SQL 58 五张维修表逐表存在状态 | UI 已有目录结果未证实实例身份；本轮未查询 | UNKNOWN |
| DB-04 | 已存在维修表字段/类型/可空性/默认值 | 未查询 | UNKNOWN |
| DB-05 | 已存在维修表索引/唯一键，重点 `uk_tenant_impact_key(tenant_id, impact_key)` | 未查询 | UNKNOWN |
| DB-06 | 设备、设备负责人、预约等 SQL 58 前置依赖表存在 | UI 旧结果列出这三表，但实例和时效未核实 | UNKNOWN |
| DB-07 | 菜单 ID 13684–13688 空闲、无软删除残留 | 未查询 | UNKNOWN |
| DB-08 | 权限码无冲突 | 未查询 | UNKNOWN |
| DB-09 | 父菜单 13600、祖先目录 13478 的状态/层级/租户符合 SQL 59 | 未查询 | UNKNOWN |
| DB-10 | 角色 904/906/908/909 的状态、tenant_id，以及 909 固定 ID/code/AUTO_INCREMENT 前置条件 | 未查询 | UNKNOWN |
| DB-11 | 租户 162 和套餐 114 存在且状态符合预期 | 未查询 | UNKNOWN |
| DB-12 | 套餐 114 `menu_ids` 为合法 JSON，目标菜单 ID 现状明确 | 未查询 | UNKNOWN |
| DB-13 | 角色菜单授权现状、908 越权项及跨租户残留已核对 | 未查询 | UNKNOWN |
| DB-14 | 现存维修表的行数和业务数据影响已核对 | 未查询；`table_rows` 本身仅为估算 | UNKNOWN |

**不依据历史报告、源码、SQL 注释或旧 UI 结果推断真实库状态。**

## 6. SQL 58/59 静态复核

| 项目 | 静态判断 | 真实库结论 |
|---|---|---|
| SQL 58 五表字段/DO/Mapper 映射 | 参考 70 号 R5 静态复核结论；本轮未修改设计稿 | UNKNOWN，需以 DB-04/05 结果逐字段比对 |
| SQL 58 `CREATE TABLE IF NOT EXISTS` | 若表部分存在不会完成 schema 迁移 | UNKNOWN；任一表存在须停止并单独做 schema diff |
| SQL 58 事务/回退 | MySQL DDL 可能隐式提交；多表建表不可承诺整体事务回滚；DROP 回退有数据破坏风险 | 静态 HOLD；正式部署须独立备份与恢复审批 |
| SQL 58 唯一键 | 设计为 `(tenant_id, impact_key)` 唯一约束 | UNKNOWN；需 DB-05 实证 |
| SQL 59 ID、权限码、父节点 | 固定使用 13684–13688、13600/13478 及四个权限码 | UNKNOWN；需 DB-07/08/09 实证 |
| SQL 59 角色矩阵 | 设计稿授权 904/906/908/909，实际状态/归属尚未核对 | UNKNOWN；需 DB-10/13 实证 |
| SQL 59 套餐/租户 | 固定套餐 114、租户 162 | UNKNOWN；需 DB-11/12 实证 |
| SQL 59 前端组件 | 静态组件路径 `lab/instrument/repair-order/list` 与前端目录一致 | 静态 PASS，不表示数据库已部署 |
| SQL 59 JSON 自动回退 | §8.2.1 将 JSON 聚合结果用作 `JSON_REMOVE` 路径参数，表达式不可靠；数组长度、NULL、顺序及重复值也需关注 | 静态 HOLD；严禁执行该自动回退语句 |
| SQL 59 DML 事务 | 草稿建议事务包装，但客户端自动提交、表引擎和同连接执行方式未验证 | UNKNOWN/HOLD；须 DBA 核实 |

## 7. 缺少的证据与负责人下一步

请负责人在已经连接且能确认实例的 Navicat 会话中手工运行配套文件中的 SELECT 与 `SHOW GRANTS`，并保存去敏后的结果：

1. 先运行第 1 项身份查询。确认 schema 为 `labplatform`，确认服务器/端口属于预期环境；账号名称在报告中可打码。若目标不符或查询报错，立即停止其余查询。
2. 运行 `SHOW GRANTS`，确认该账号的实际读取权限；不得把 Navicat 界面“只读”标记单独视为数据库权限证明。
3. 再运行第 2–10 项。若某系统表不存在、列不存在或查询报错，记录错误并停止依赖该对象的检查，不要改表或改 SQL 58/59。
4. 提供 SQL 58 前的有效数据库备份及恢复验证证据。单有备份文件或未经恢复验证的声明不足以通过。
5. DBA 确认相关系统表使用的事务引擎、SQL 59 执行客户端不会自动提交、事务操作使用同一连接。该检查不得以 SQL 58 DDL 可回滚代替。
6. DBA/负责人审阅 SQL 59 §8.2.1 风险，形成经审查的恢复流程；不要运行当前自动套餐 JSON 回退。
7. 完成以上工作后，再更新本报告并逐项给出真实查询结果。即使结论达到 `PRECHECK PASS`，SQL 58/59 仍需另行书面授权才可执行。

## 8. 本轮变更和写操作声明

- 本轮仅新增/修改了预检文档和只读 SQL 文件，以补充连接身份及 `SHOW GRANTS` 查询项。
- 未修改后端、前端业务代码或 Git 状态；未修改 SQL 58/59 部署设计稿。
- 本轮未主动执行任何数据库语句，因此没有数据库写入；没有访问或写入 Redis。
- Navicat 查询内容和已有结果未更改；本轮只观察窗口状态，没有执行查询。没有暂存、提交、推送或清理工作区。

## 9. 最终结论

**PRECHECK INCOMPLETE**：Navicat 已存在并打开预检页，但本轮自动化在截图通道超时后按安全规则停止；无法取得目标库身份查询和逐项真实查询结果。目标数据库所有结构/菜单/角色/套餐事实均为 **UNKNOWN**。当前只完成静态 SQL 分类和供负责人安全运行的只读清单。

下一步由负责人在 Navicat 中完成身份核验与只读查询，提供脱敏结果后再出具 `PRECHECK PASS` 或 `PRECHECK HOLD`。本轮没有执行 SQL 58/59，也没有授予后续部署权限。
