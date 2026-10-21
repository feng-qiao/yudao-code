# USER-01-R2 集中验收报告

> 任务：用户资料改造质量收口与 DDL 执行前验收
> 日期：2026-10-12　|　结论：**PASS**（DDL 未执行，等待负责人裁决）
> 边界遵守：未执行任何真实数据库 DDL/DML；未重启后端；未重复执行 REG-03 已完成 SQL；未修改 `system.user.register-enabled`（实测仍为 `false`）；未清理历史审批/登录日志；未修改质粒 V1/V2 等无关模块；未为通过测试削弱生产校验（反而补强）。

---

## 1. 六字段最终映射与约束表

| 业务字段 | Java 字段 | system_users 列（DDL 待执行） | 类型/长度 | 可空 | 服务端校验（AdminUserServiceImpl.validateProfileFields） | VO 层校验 | 取值 |
|---|---|---|---|---|---|---|---|
| 身份类别 | identityType (Integer) | identity_type | tinyint(4) | 是（历史用户为空） | 非空时必须为合法枚举（018） | —（服务层校验） | 1硕士 2博士 3博士后 4科研助理 5教师 |
| 研究方向 | researchDirection (Integer) | research_direction | tinyint(4) | 是 | 非空时必须为合法枚举（019） | —（服务层校验） | 1-7 固定平台 |
| 导师 | supervisor (String) | supervisor | varchar(50) | 是 | 硕/博/博后必填（020）；长度≤50（024） | @Size(max=50) | 文本 |
| 指导教师 | instructor (String) | instructor | varchar(50) | 是 | 硕/博/博后必填（021，R2 新增）；长度≤50（024） | @Size(max=50) | 文本 |
| 开始年月 | startYmd (String) | start_ymd | varchar(7) | 是 | 格式 yyyy-MM 且月份 01-12（022）；≤结束年月（023） | @Pattern `^\d{4}-(0[1-9]\|1[0-2])$`（收紧） | yyyy-MM |
| 结束年月 | endYmd (String) | end_ymd | varchar(7) | 是 | 同上 | 同上 | yyyy-MM |

校验接入点（服务层统一，四条入口全覆盖）：`createUser`、`updateUser`、`updateUserProfile`（个人中心）、`importUserList`（Excel 导入逐行）。所有字段可空——历史用户资料为空正常显示与保存。

## 2. R1 遗留问题修复情况

| # | R1 遗留问题 | 状态 |
|---|---|---|
| 1 | `createUser`/`updateUser` 完全未校验六字段（仅个人中心有） | ✅ 已修复：服务层 `validateProfileFields` 扩展为六参数版并接入四条入口 |
| 2 | 硕/博/博后「指导教师」必填缺失（仅校验导师） | ✅ 已修复（错误码 1_002_003_021） |
| 3 | 年月格式校验缺失；VO 正则 `\d{4}-\d{2}` 放行 `2026-99` | ✅ 已修复：服务层 022 + 两个 VO 正则收紧为月份 01-12 |
| 4 | 开始年月晚于结束年月未校验 | ✅ 已修复（023） |
| 5 | 导师/指导教师长度仅靠 VO @Size，服务层无防御（lab 审批直调 Service 绕过 Bean 校验） | ✅ 已修复（024） |
| 6 | Excel 导入逐行失败吞掉继续处理，存在部分成功（违反整批冻结规则） | ✅ 已修复：改为收集全部失败后抛 025 触发 `@Transactional` 整体回滚，报告含行号/用户名/原因 |
| 7 | Excel 导入更新路径手机/邮箱唯一性误判（不改手机号也报"已被使用"） | ✅ 已修复：更新场景唯一性校验排除自身 id |
| 8 | 随机测试数据不符合生产约束导致校验被取消 | ✅ 已按任务要求改为合法数据（枚举 4/1、王老师/李老师、2024-09/2027-06），并新增非法数据专项用例 |

system 模块保持不依赖 lab 模块 ✅（枚举权威来源在 system，lab 反向引用）。

## 3. Excel 整批回滚测试证据

| 用例 | 场景 | 断言结果 |
|---|---|---|
| `testImportUserList_batchRollback`（新增） | 第 1 行合法新增 + 第 2 行用户名冲突 | 抛 `USER_IMPORT_BATCH_FAILED`，消息为「第 3 行 用户[xxx]：用户账号已经存在」；**第 1 行合法数据未落库**（`selectByUsername` 为 null），已存在用户未被更新 |
| `testImportUserList_01` | 部门校验失败 | 整批取消，失败报告=「第 2 行 用户[xxx]：当前部门不存在」，无任何写入 |
| `testImportUserList_03` | 用户名冲突且不强制更新 | 整批取消，报告含行号/用户名/原因 |
| `testImportUserList_adminCannotDisable` | 禁用租户管理员 | 整批取消，原用户状态保持 ENABLE |
| `testImportUserList_02/04` | 新增/更新成功路径 | 正常返回，六字段随行落库 |
| 语义说明 | — | 行号按 Excel 实际行号（首行表头，数据行从第 2 行计）；`ConstraintViolationException` 与 `ServiceException` 均计入失败报告；非预期异常直接穿透触发回滚 |

## 4. 修改文件清单（R2）

后端（yudao-module-system，6 个文件）：
- `service/user/AdminUserServiceImpl.java` — validateProfileFields 重写（六参数）、createUser/updateUser 接入、importUserList 整批事务改造 + 行号报告 + 更新路径唯一性修正
- `controller/admin/user/vo/user/UserSaveReqVO.java` — startYmd/endYmd 补 @Pattern（月份 01-12）
- `controller/admin/user/vo/profile/UserProfileUpdateReqVO.java` — 年月正则收紧（`2026-99` 漏洞）
- `enums/ErrorCodeConstants.java` — 新增 1_002_003_021~025
- `test/.../AdminUserServiceImplTest.java` — 测试数据合法化、导入用例重写、新增 `testImportUserList_batchRollback`、`testCreateUser_profileFieldsInvalid`（覆盖身份/方向/指导教师必填/年月格式/年月顺序/导师超长 6 类非法输入）

SQL（1 个文件）：`sql/lab/20261012_system_users_profile_fields.sql` — 补执行前/后验证 SQL、回滚参考与风险说明（可执行语句未改动）

前端：**零改动**（ESLint 与生产构建为回归确认）

## 5. 测试结果

| 项目 | 结果 |
|---|---|
| system 模块全量单测（clean 重建） | **493 tests, 0 failures, 0 errors, 8 skipped**（R1 基线 491 + R2 新增 2） |
| AdminUserServiceImplTest | 48/48 通过（R1 为 46，+2） |
| lab RegisterApplyServiceImplTest | 30/30 通过（adminUserService 为 Mock，审批链路不受新校验影响；apply 数据在提交侧已校验） |
| 后端编译 | system `clean install` BUILD SUCCESS（jar 已更新至 m2）；lab test-compile BUILD SUCCESS |
| 前端 ESLint | 0 error（仅 auto-imports.d.ts 生成文件 1 个固有 warning） |
| 前端生产构建（build:local） | ✓ built in 32.89s |

过程说明：首次全量 `mvn install` 因 target 目录残留孤儿测试类导致 `junit-jupiter failed to discover tests`，`mvn clean` 后重建解决，非代码问题。

## 6. DDL 执行前检查结果（全部只读实测）

| 检查项 | 结果 |
|---|---|
| 真实库现状 | MySQL 8.0.12；`labplatform.system_users` 实测 20 列，六个新列均不存在；27 行（未删除 26 行） |
| 六列类型与 Java DO 一致性 | ✅ tinyint(4)↔Integer、varchar(50)↔String(@Size50)、varchar(7)↔yyyy-MM；MySQL 8.0.12 接受该语法（显示宽度废弃始于 8.0.17） |
| 幂等/重复执行 | ✅ 逐列 information_schema 检查 + PREPARE/EXECUTE，重复执行输出 "already exists" 跳过 |
| 历史用户兼容 | ✅ 六列均 DEFAULT NULL，27 行存量数据不受影响 |
| 执行前后验证 SQL | ✅ 已补充至脚本（执行前期望 0 行、执行后期望 6 行及精确类型清单、行数核对） |
| 回滚方案 | ✅ 已补充逆序 DROP COLUMN 参考并注明：仅丢失六个新字段自身数据，需负责人确认 |
| 对现有功能影响 | ✅ 无：可空列追加，旧运行 jar 不感知新列，登录/注册审批/用户管理不受影响；存量待审批申请资料数据实测合法（4-8 号历史测试申请六字段为 NULL，走可选路径） |
| 旧注册开关 | ✅ `infra_config id=13 system.user.register-enabled` 实测仍为 `false` |
| 敏感信息 | ✅ `UserRespVO` 为 `@ExcelIgnoreUnannotated`，无 password/token 列，导出不含密码、哈希、令牌 |
| 遗留测试数据 | ✅ 孤儿数据原样保留：apply_history id=25/26、login_log id=8460/8461 均在且未删除 |

## 7. SQL 文件准确路径

`E:\lixin\dev\ruoyi-vue-pro\sql\lab\20261012_system_users_profile_fields.sql`

## 8. 结论：PASS

**DDL 已通过执行前审核，但尚未执行；可以交由负责人决定是否执行。**

### 负责人后续动作（本任务不执行）
1. 审阅并执行上述 DDL（按脚本内【执行前验证】→ 执行 → 【执行后验证】流程，建议连接层使用 utf8mb4）；
2. DDL 执行后重建后端 fat jar（先删除 `yudao-server/target/*.jar` 再 `mvn package -pl yudao-server -DskipTests`）并重启，补做运行时验证（注册审批通过→六字段入库、个人中心回显/修改、用户管理、Excel 导入导出）；
3. 裁决孤儿数据处置（history id=25/26 建议确认来源后决定；login_log id=8460/8461 建议保留作审计）。

---

## 9. 执行记录（2026-10-12，负责人授权后执行）

负责人确认"执行"后，按上述清单完成了第 1、2 项；第 3 项孤儿数据按建议继续保留未动。

**执行前复核（全部通过）**：六新列 0 行不存在；system_users 20 列、27 行（26 未删除）；`system.user.register-enabled=false`；27 条用户主键清单留档为基线；确认原后端进程 PID 26820（`java -jar yudao-server.jar --spring.profiles.active=local`）。

**备份**：`system_users` 全表 27 行导出为 INSERT 语句备份（20 列完整、中文编码校验通过）：
`C:\Users\Administrator\AppData\Local\Temp\reg16\system_users_backup_20261012.sql`

**DDL 执行**：脚本 6 个幂等块共 30 条语句（utf8mb4 连接字符集）全部执行成功，六列均为实际新增（无跳过）。

**执行后验证（全部通过）**：
| 验证项 | 结果 |
|---|---|
| 六列类型/可空性/默认值/中文注释 | ✅ 与预期完全一致（tinyint(4)×2、varchar(50)×2、varchar(7)×2，均 YES NULL，注释无乱码） |
| 总列数 | ✅ 26（20+6） |
| 行数 | ✅ 27 / 26 未删除，用户主键清单与执行前基线逐条一致 |
| 幂等重复执行 | ✅ 第二次执行六列全部 `already exists` 跳过，无报错 |

**fat jar 重建与重启**：停止 PID 26820（其占用旧 jar 文件锁）→ 删除旧 jar → `mvn package -pl yudao-server -DskipTests` 重建（157.5 MB）→ 以原参数重启，新进程 PID 38908。

**启动与运行时冒烟（全部通过）**：
| 验证项 | 结果 |
|---|---|
| 启动日志 | ✅ `Started YudaoServerApplication in 12.037 seconds`，无 ERROR、无 BeanDefinitionOverrideException 等指定异常 |
| 无 token 访问受保护接口 | ✅ 返回 401「账号未登录」，认证链路正常 |
| 错误凭据登录（触发 system_users 含新列的真实查询） | ✅ 返回业务错误 1002000000「登录失败，账号密码不正确」，证明 AdminUserDO 与新增六列的 SELECT 映射在运行时兼容 |

**遗留（需负责人交互验证）**：注册审批通过→六字段入库、个人中心回显/修改、用户管理表单、Excel 导入导出的完整业务闭环需有效登录凭据后人工/浏览器验证；本执行记录中的冒烟仅覆盖应用存活、鉴权与数据访问链路。
