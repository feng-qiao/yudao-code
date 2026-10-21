# USER-02 集中修复与验收报告

**任务**：注册资料迁移、部门归属与已删除用户恢复
**执行日期**：2026-10-12
**执行方式**：先只读取证定位根因 → 代码修复 → 自动化测试 → 真实 HTTP 验证
**结论**：**CONDITIONAL PASS**（三项待负责人裁决/执行事项见第 8 节）

---

## 1. 问题一：六项资料审批后丢失 —— 根因与修复

### 1.1 根因（已坐实，非源码缺陷）

**根因：USER-01 实施期间部署的 fat jar 打包时未先安装 module-lab 到本地仓库，导致运行的是 08:10 的陈旧 module-lab jar，其中 `approve()` 尚不含六字段复制代码。**

证据时间线：

| 时间 (10-12) | 事件 | 证据 |
|---|---|---|
| 08:10:05 | 本地仓库 yudao-module-lab jar 最后更新（陈旧版） | 本地仓库文件时间戳 |
| 12:12:36 | RegisterApplyServiceImpl.java 六字段复制代码保存（USER-01 源码层已正确） | 源文件时间戳 |
| 13:42:59 | fat jar 以 `mvn package -pl yudao-server`（无 `-am`）打包，从本地仓库解析到**陈旧** lab jar | yudao-server.jar 时间戳 |
| 13:43 | 旧后端（PID 38908）启动，运行陈旧代码 | 进程启动时间 |
| 15:24:32 | 用户 274 经真实审批创建，`system_users` 六字段全部 NULL，而申请表 27 原值完整（1/1/1/1/2026-09/2026-12） | 数据库实查 |

同样受影响的历史用户：**265**（对应申请 16）、**266**（对应申请 21，其申请 supervisor/instructor 本身为 NULL）。

结论：`approve()` 源码自 USER-01 起即正确（[RegisterApplyServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/register/RegisterApplyServiceImpl.java) 第 207-219 行复制六字段至 `UserSaveReqVO`），个人中心与用户管理查询/前端绑定链路均无缺陷。**本次不修改任何审批源码**。

### 1.2 修复动作

1. 终止持锁旧后端（PID 38908）→ `mvn install`（module-lab 16:04:00、module-system 16:03:54 入本地仓库）→ `mvn package -pl yudao-server`（fat jar 16:05:51）→ 重启（PID 33812，16:10，启动 12.4s 无异常）。
2. **字节级验证部署产物**：对本地仓库 module-lab jar 内 `RegisterApplyServiceImpl.class` 执行 `javap -c`，确认 approve 流程含 `UserSaveReqVO.setIdentityType / setResearchDirection / setSupervisor / setInstructor / setStartYmd / setEndYmd` 全部调用指令。
3. 新增回归单测 `testApprove_profileFieldsMigrated`（申请含六字段 2/5/导师A/教师B/2024-09/2027-06，verify `createUser` 入参六字段全部映射），lab 模块 31/31 通过。
4. **历史数据补齐**（待授权，见第 6 节 SQL-B）：274←申请 27、265←申请 16、266←申请 21，全部 `JOIN lab_register_apply 且 status=1` 取原值，`COALESCE(u.xxx, a.xxx)` 保护不覆盖任何已填资料，不含批量猜测。

> 说明：为何本轮 HTTP 验证不做"审批通过后六字段入库"的端到端实测 —— 该验证需在租户 162 执行（租户 1 无「普通用户」角色，approve 必抛错），而 162 审批员凭据不可考（与 USER-01-R3 相同 BLOCKER）。已提交申请 30（见 7.4）留 PENDING，供负责人在新后端上一次审批即可闭环验证。

---

## 2. 问题二：新用户部门归属为空 —— 根因与候选方案（待裁决）

### 2.1 根因（已坐实）

- `RegisterApplyServiceImpl.approve()` 构造 `UserSaveReqVO` 时**从未赋值 deptId**；
- `lab_register_apply` 表无部门列，申请页/审批页前端均无部门选择控件；
- `system_tenant` 无默认部门配置，代码库无 `defaultDept` 相关痕迹。

**即：从未存在既定的部门归属业务规则，属于规则缺失而非实现缺陷。按任务要求不硬编码部门 ID，输出候选方案待裁决。**

### 2.2 候选方案（三选一或组合，均需负责人确认后另行实施）

| 方案 | 内容 | 影响面 |
|---|---|---|
| A. 审批页指定 | 审批通过弹窗增加部门选择（必填），审批员归属新用户部门 | 后端 approve VO+Service、管理端审批页；最贴合管理实际 |
| B. 申请页收集 | 注册申请页增加部门选择（可选/必填），随申请入库并迁移 | 申请表加列（DDL）、申请/审批页、公开端校验 |
| C. 默认部门 | 审批通过时自动挂租户根部门（如租户 162 → 部门 122） | 仅后端 approve；最简单但语义粗放 |

**部门赋值部分已按任务要求暂停，其余修复已全部继续实施完毕。**

---

## 3. 问题三：已删除用户查询与恢复 —— 新功能实现

### 3.1 后端（yudao-module-system）

| 文件 | 改动 |
|---|---|
| [AdminUserMapper.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/dal/mysql/user/AdminUserMapper.java) | `selectPage` 增加 nickname 模糊；新增 `selectDeletedPage/selectDeletedList`（自定义 `@Select`，显式 `WHERE deleted = TRUE`，支持 username/nickname/mobile/status/createTime 过滤，`@TableLogic` 逻辑删除不干扰，租户拦截器仍自动追加 tenant_id 跨租户保护）、`selectByIdIncludeDeleted`（含已删除）、`restoreById`（条件 UPDATE：`WHERE id=? AND deleted=TRUE`，返回影响行数） |
| [AdminUserServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/user/AdminUserServiceImpl.java) | `getDeletedUserPage`；`restoreUser`（`@Transactional` + `@LogRecord`）校验链：用户存在 → 确实已删除 → 用户名未被占用 → 手机号唯一 → 邮箱唯一 → 部门存在且有效 → 条件 UPDATE 行数=1（否则抛错回滚）。**角色/岗位关联不随恢复还原**（删除时已逻辑删除 user_role、删除 user_post，恢复后需管理员重新分配，前端恢复按钮二次确认中已明示） |
| [UserController.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/controller/admin/user/UserController.java) | `GET /system/user/deleted-page`（`@PreAuthorize("system:user:query")`，查询语义复用既有权限串）；`PUT /system/user/restore`（`@PreAuthorize("system:user:restore")`，**新增权限串，服务端强制鉴权，非仅前端隐藏按钮**） |
| [ErrorCodeConstants.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/enums/ErrorCodeConstants.java) | `1_002_003_026` 用户未处于已删除状态，无法恢复；`1_002_003_027` 用户名已被其他用户使用，无法恢复 |
| [LogRecordConstants.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/enums/LogRecordConstants.java) | 恢复用户操作日志（记录昵称） |
| UserPageReqVO / UserRespVO / AdminUserService | nickname 查询字段、updateTime 响应字段（回收站显示删除时间，无 `@ExcelProperty` 不影响导出）、接口方法签名 |

### 3.2 前端（yudao-ui-admin-vue3）

- 新增 [UserRecycleBinDialog.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/system/user/UserRecycleBinDialog.vue)：搜索（username/nickname/mobile）+ 表格（含部门、状态、删除时间）+ 分页 + 恢复按钮（`v-hasPermi=['system:user:restore']`，二次确认提示"恢复后需重新分配角色与岗位"）。
- [index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/system/user/index.vue)：工具栏新增「回收站」按钮（`v-hasPermi=['system:user:query']`），恢复成功后刷新列表。
- [api/system/user/index.ts](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/api/system/user/index.ts)：`getDeletedUserPage` / `restoreUser`。

### 3.3 权限设计说明

- 查询回收站复用 `system:user:query`（查询语义，不新增权限串）；
- 恢复为写操作，按既有命名模式新增 `system:user:restore`，配套菜单/套餐/角色授权 SQL 见第 6 节 SQL-A（菜单 13580，按钮 type=3 挂用户管理 4，套餐 114 追加，角色 903 授权）。**SQL 未执行前仅超级管理员可调用恢复接口——此为预期安全姿态。**

---

## 4. 修改文件清单（全部）

**后端 8 改 0 增**（不含测试）：
1. `yudao-module-system/.../dal/mysql/user/AdminUserMapper.java`
2. `yudao-module-system/.../service/user/AdminUserServiceImpl.java`
3. `yudao-module-system/.../service/user/AdminUserService.java`
4. `yudao-module-system/.../controller/admin/user/UserController.java`
5. `yudao-module-system/.../enums/ErrorCodeConstants.java`
6. `yudao-module-system/.../enums/LogRecordConstants.java`
7. `yudao-module-system/.../vo/user/UserPageReqVO.java`
8. `yudao-module-system/.../vo/user/UserRespVO.java`

**测试 2 改**：`AdminUserServiceImplTest.java`（+8 用例）、`RegisterApplyServiceImplTest.java`（+1 用例）

**前端 2 改 1 增**：`api/system/user/index.ts`、`views/system/user/index.vue`、新增 `views/system/user/UserRecycleBinDialog.vue`

**SQL 2 增（均未执行，待授权）**：见第 6 节。

未触碰：质粒 V1/V2、旧注册接口与开关、菜单数据库数据、R3 遗留数据（268-271、apply 25、history 25/26、login_log 8460/8461）、任何已冻结表结构。

---

## 5. 自动化测试结果

| 项 | 结果 |
|---|---|
| system 模块单测（JDK8） | **56/56 通过**（含回收站 8 新用例：正常用户不出现/已删除出现/用户名与昵称模糊/不混入正常列表/恢复成功/未删除拒绝/用户名冲突拒绝且删除状态不变/手机冲突/部门校验/部门失效拒绝） |
| lab 模块单测 | **31/31 通过**（含 `testApprove_profileFieldsMigrated` 六字段迁移回归） |
| 后端编译 | 通过（fat jar 16:05:51） |
| 前端 ESLint / Prettier / TS | 通过 |
| 前端生产构建 `build:local` | 通过（28.23s） |

---

## 6. 数据库变更（两个 SQL 均已生成、未执行、待授权）

| # | 文件 | 用途 | 前置状态 |
|---|---|---|---|
| SQL-A | [20261012_system_user_restore_menu.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261012_system_user_restore_menu.sql) | 菜单 13580「用户恢复」`system:user:restore`（字段逐项对齐既有按钮菜单 29）+ 套餐 114 menu_ids 幂等追加（防重守卫）+ role_menu(903,13580,162)；含 0 节前置检查、4 节验证（计数按 `,13580,` 7 字符）、5 节回滚方案 | 待负责人执行 |
| SQL-B | [20261012_system_users_profile_backfill.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261012_system_users_profile_backfill.sql) | 历史资料补齐：274←申请27、265←申请16、266←申请21；`JOIN apply 且 status=1`，`COALESCE` 保护已填值，updater 标记 `trae-user02`，含核对/验证/回滚（仅允许同标记行回退） | 待负责人确认后执行 |

---

## 7. 实际 HTTP 验证（后端 PID 33812，新 jar，:48080）

### 7.1 回收站全生命周期（租户 1，yudao 超管）—— 14 项断言 13 通过，2 项修正后复测通过

| 步骤 | 结果 |
|---|---|
| 创建用户 277 → 正常列表可见 | PASS |
| 删除 277 → 回收站 `deleted-page` 出现（返回删除时间 updateTime） | PASS |
| 回收站昵称模糊查询命中 | PASS（中文，UTF-8 修正后复测，见 7.3） |
| 正常列表不再出现 277 | PASS |
| 恢复 277 → 正常列表复现、回收站消失 | PASS |
| 重复恢复 277 → 拒绝 `1_002_003_026` 用户未处于已删除状态，无法恢复 | PASS |
| 恢复不存在 id=999999999 → 拒绝 `1_002_003_003` 用户不存在 | PASS（首轮断言号段猜错，实际错误码正确） |

### 7.2 用户名冲突场景

删除用户 A（275）→ 新建同名用户 B（276，证明已删除用户名可复用）→ 恢复 A：
**拒绝 `1_002_003_027` 用户名已被其他用户使用，无法恢复；A 仍处回收站（deleted=1 不变），B 正常列表不受影响。** DB 复核确认。不自动改用户名，符合任务要求。

### 7.3 中文昵称（测试脚本编码问题澄清）

首轮 PowerShell 脚本以默认编码发送请求体，致 275/276/277 昵称存为 `???`（**测试脚本缺陷，非产品缺陷**）；改用 UTF-8 字节体重测：创建 280「回收站中文451」→ 删除 → 回收站 `nickname=回收站` 模糊命中，存储与查询全链路中文正常。

### 7.4 租户 162 审批链验证样本（已备妥，待负责人操作）

已通过匿名接口提交申请 **id=30（u2verify01，PENDING）**，六字段齐全：identityType=2、researchDirection=3、supervisor=张安U2、instructor=李宁U2、startYmd=2026-09、endYmd=2030-06。负责人在新后端执行一次审批通过，即可验证六字段审批迁移 + 登录闭环。

### 7.5 遗留测试数据（均逻辑删除于回收站，待负责人裁决清理）

租户 1：275、276、277、280（275/276/277 昵称为首轮脚本乱码）。均可通过新回收站功能查看，不可用 API 物理删除。

---

## 8. 待负责人裁决/执行事项

1. **执行 SQL-A**（菜单授权）：执行后非超管角色方可用恢复功能；
2. **确认并执行 SQL-B**（历史资料补齐 274/265/266）；
3. **裁决部门归属规则**（第 2.2 节方案 A/B/C），裁决前部门赋值维持暂停；
4. **完成 162 审批闭环**：审批申请 30（或提供 162 审批员测试凭据），验证六字段端到端迁移与登录；此后可复核非超管恢复权限；
5. **裁决测试数据清理**（275/276/277/280 及申请 30 的后续处置）。

---

## 9. 结论

- 问题一：根因为陈旧 jar 部署事故，源码无缺陷；正确重建+重启完成，字节码与单测双重验证；历史数据补齐 SQL 待授权。
- 问题二：规则缺失已坐实，候选方案待裁决，未硬编码。
- 问题三：回收站功能全链路实现并经真实 HTTP 验证（含冲突拒绝、事务行数校验、中文模糊、操作日志、服务端鉴权）。

**CONDITIONAL PASS**：核心修复与验证全部完成；第 8 节 1/2/4 项解除后转正式 PASS。

任务到此停止，不进入其他模块。
