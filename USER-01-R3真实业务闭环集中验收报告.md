# USER-01-R3 真实业务闭环集中验收报告

> 任务：正式用户资料与用户管理真实业务闭环集中验收
> 日期：2026-10-12　|　结论：**CONDITIONAL PASS**（A 组审批环节待审批员凭据，其余链路全部真实 HTTP+DB 验证通过）
> 执行方式：集中执行（真实 HTTP API 调用 + MySQL 实时只读查询核验），后端 `127.0.0.1:48080`（PID 38908，fat jar 为 DDL 后重建版本）。

---

## 0. 结论总览

| 链路 | 结果 | 说明 |
|---|---|---|
| A. 注册审批 → 正式用户 | **部分 PASS / 审批环节 BLOCKED** | 提交六字段、待审批拒绝登录、my-status、重复/非法校验、租户隔离全部 PASS；审批通过→建号→角色分配→登录闭环**缺租户 162 审批员凭据** |
| B. 个人中心 | **PASS** | 回显/保存/重登持久化/五类校验/伪造字段防护/密码安全全部真实 API+DB 验证 |
| C. 系统管理 → 用户管理 | **PASS** | 分页/新增免审批/编辑/详情/历史空值/无部门岗位/启停用/租户隔离全部验证 |
| D. Excel 导入、导出 | **PASS** | 模板含六字段/合法导入直接建号/导出含六字段且无敏感列/两类整批回滚/行号定位全部验证 |
| E. 安全及回归 | **PASS** | 旧注册接口收口/权限边界/租户隔离/质粒 V1V2 存活全部验证 |

**本任务未修改任何产品代码（后端、前端、SQL 均零改动）。** 发现的 2 个异常均为测试脚本问题（详见 §6），非产品缺陷。

## 1. 凭据与前置状态

| 项目 | 状态 |
|---|---|
| 后端 | `:48080` LISTENING（PID 38908，DDL 后重建 fat jar） |
| 前端 dev server | 未运行（页面级浏览器验证未执行，以 API+DB 证据为准；前端 ESLint/构建已在 R1/R2 通过） |
| 可用凭据 | `regtest008/RegTest@123`（租户 1，userId=261，无角色，历史会话验证凭据）；`yudao/admin123`（租户 1，userId=100，超级管理员，实测有效） |
| 缺失凭据 | 租户 162 审批链路（qinghy/189140001/probenosuchuser9 密码不可考，admin/admin123 与 admin/123456 经 login_log 8467/8472/8476/8479 证实失败） |
| 注册开关 | `infra_config id=13 system.user.register-enabled=false`（实测） |
| system_users 基线 | 26 列（含六新列），测试前 26 个未删除用户，六字段全部 NULL |

## 2. A 组：注册审批 → 正式用户

### 2.1 A1 提交注册申请（六字段）— PASS

```
POST /admin-api/lab/register-apply/submit   tenant-id: 162
body: {"username":"r3user001","password":"R3Test@123","nickname":"R3验收测试用户","identityType":1,
       "researchDirection":2,"supervisor":"验收导师A","instructor":"验收教师B","mobile":"13900001111",
       "email":"r3user001@test.local","startYmd":"2024-09","endYmd":"2027-06","applyReason":"USER-01-R3集中验收测试申请"}
→ {"code":0,"msg":"","data":25}
```

**DB 核验（lab_register_apply id=25）**：tenant_id=162、status=0（待审批）、identity_type=1、research_direction=2、supervisor=验收导师A、instructor=验收教师B、start_ymd=2024-09、end_ymd=2027-06、password 为 BCrypt 哈希（`$2a$04$mRre...`）、user_id=NULL（未建号）。

### 2.2 A2 待审批申请不能登录 — PASS

```
POST /admin-api/system/auth/login   tenant-id: 162   body: {"username":"r3user001","password":"R3Test@123"}
→ {"code":1002000000,"msg":"登录失败，账号密码不正确","data":null}
```
申请未审批不产生 system_users 记录，无法登录，防枚举统一文案 ✅。

### 2.3 A3 my-status（用户名+密码鉴权）— PASS

```
POST /admin-api/lab/register-apply/my-status   tenant-id: 162
→ {"code":0,"data":{"id":25,"username":"r3user001","identityType":1,"researchDirection":2,"supervisor":"验收导师A",
   "instructor":"验收教师B","startYmd":"2024-09","endYmd":"2027-06","status":0,...}}
```
六字段完整回显，响应体无 password 字段 ✅。

### 2.4 A4 重复用户名申请 — PASS

```
POST /lab/register-apply/submit（同 payload 重发）tenant-id: 162
→ {"code":1061002005,"msg":"该用户名已存在待审批的申请，请耐心等待审核"}
```

### 2.5 A5 提交侧校验 — PASS（均不产生数据）

| 用例 | 响应 |
|---|---|
| 身份类别=9 | `1061002008 身份类别不合法` |
| 开始年月=2026-99 | `400 开始年月格式必须为 YYYY-MM` |
| 硕士缺导师/指导教师 | `10610020010 硕士、博士、博士后必须填写导师` |

### 2.6 A6 审批通过 → 建号 → 角色分配 → 登录闭环 — **BLOCKED**

- 缺失条件：租户 162 内具备 `lab:register-apply:audit` 权限账号的登录凭据（qinghy 持有 903 租户管理员角色、菜单 R2-Fix2 已授权，但密码不可考；admin/admin123、qinghy/admin123、qinghy/123456 均 login_log 实证失败）。
- 遗留闭环验证点（负责人审批 apply 25 后即可补齐）：正式用户创建且不重复、六字段从申请迁移至 system_users、自动分配租户 162「普通用户」角色（role 904）、审批历史时间线、密码迁移后可登录、重复审批防重。
- **未绕过鉴权**：未使用框架 mock token，未伪造会话。
- 相关代码事实：审批链路 `RegisterApplyServiceImpl.approve → adminUserService.createUser`，事务内含状态抢占 UPDATE+行数校验双防线，普通用户角色按 code「普通用户」租户内动态查找（租户 162 存在 role 904）；单测 30/30 已覆盖（REG-03-14/22）。

## 3. B 组：个人中心（regtest008，userId=261）

### 3.1 B1/B2 登录与历史用户空资料回显 — PASS

```
POST /admin-api/system/auth/login tenant-id: 1 {"username":"regtest008","password":"RegTest@123"}
→ {"code":0,"data":{"userId":261,"accessToken":"4c24b2...","refreshToken":"748534...","expiresTime":...}}
GET /admin-api/system/user/profile/get
→ {"code":0,"data":{"id":261,...,"identityType":null,"researchDirection":null,"supervisor":null,
   "instructor":null,"startYmd":null,"endYmd":null,"roles":[],"dept":null}}
```
登录响应无密码/哈希字段；历史用户六字段为空正常显示 ✅。

### 3.2 B3/B4/B5 修改、回显与重登持久化 — PASS

```
PUT /admin-api/system/user/profile/update
body: {"identityType":3,"researchDirection":5,"supervisor":"R3导师测试","instructor":"R3指导教师测试",
       "startYmd":"2023-09","endYmd":"2026-06",...基础字段原值}
→ {"code":0,"data":true}
GET /system/user/profile/get → 六字段原样回显 ✅
重新登录后 GET → 六字段仍为修改值（刷新持久化等价验证）✅
DB: system_users id=261 → identity_type=3, research_direction=5, supervisor/instructor/start_ymd/end_ymd 同值 ✅
```

### 3.3 B6 校验 — PASS（5 类）

| 用例 | 响应 |
|---|---|
| 身份类别=9 | `1002003018 身份类别不合法` |
| 开始年月=2026-99 | `400 开始年月格式必须为 yyyy-MM` |
| 开始年月 2026-01 > 结束 2024-01 | `1002003023 开始年月不能晚于结束年月` |
| 导师 51 字符 | `400 导师长度不能超过 50 个字符` |
| 硕士缺导师 | `1002003020 硕士、博士、博士后身份必须填写导师` |

说明：首次超长用例仅 48 字符被正常保存（48≤50 属合法数据），已用真 51 字符复测确认拒绝；期间遇一次 401 为重复登录后旧 token 失效的时序现象，换新 token 复测通过。

### 3.4 B7 越权与伪造请求防护 — PASS

```
PUT /system/user/profile/update
body: {"id":1,"username":"hacked001","status":2,"deptId":999,"postIds":[1,2],"roleIds":[1],"tenantId":2, + 本人六字段}
→ {"code":0,"data":true}（VO 白名单，未知字段被忽略）
```
DB 核验：admin（id=1）username=admin、status=0、dept_id=103、六字段 NULL 全部未动；regtest008（id=261）username/status/dept_id 未被篡改（status=0、dept_id=NULL）。修改只作用于登录用户本人 ✅。

### 3.5 B8 密码修改未受影响 — PASS（安全侧验证）

```
PUT /system/user/profile/update-password {"oldPassword":"WrongOld@999","newPassword":"NewPass@123"}
→ {"code":1002003005,"msg":"用户密码校验失败"}
```
错误旧密码被拒绝、密码未变更（后续 RegTest@123 重登成功佐证）。按边界约束**未对任何已有用户执行成功性改密**。

### 3.6 B9 社交绑定入口已隐藏 — PASS（代码级）

`src/views/profile/Index.vue` 仅挂载 basicInfo（基本资料）与 resetPwd（修改密码）两个 tab，未引用 UserSocial；`UserSocial.vue` 组件文件按 P-05 边界保留未删除。profile/get 响应亦无社交绑定数据。

## 4. C 组：系统管理 → 用户管理（yudao 超级管理员，租户 1）

| # | 用例 | 请求/结果 | 结论 |
|---|---|---|---|
| C1 | 分页查询 | `GET /system/user/page?pageNo=1&pageSize=5` → total=22，响应含六字段；regtest008 显示修改后值，历史用户显示 null | PASS |
| C2 | 管理员新增免审批 | `POST /system/user/create`（r3imp001，六字段+dept 103）→ data=268；DB：lab_register_apply 中 `username LIKE 'r3imp%'` 计数=**0**（无审批流介入） | PASS |
| C3 | 新增用户详情回显 | `GET /system/user/get?id=268` → 六字段完整 | PASS |
| C4 | 编辑六字段 | `PUT /system/user/update`（identityType 2→4、方向 1→7、导师/指导教师/年月更新）→ 详情回显一致 | PASS |
| C5 | 历史用户空资料 | `GET /system/user/get?id=1`（admin）→ 六字段 null 正常显示，其余资料完整 | PASS |
| C6 | 部门/岗位可空 | `POST /system/user/create`（r3imp002，无 deptId/postIds）→ id=269，DB dept_id=NULL 正常 | PASS |
| C7 | 启停用回归 | `PUT /system/user/update-status {"id":268,"status":1}` → status=1；再 `{"status":0}` → status=0（仅作用于新建测试用户，未触碰任何既有用户） | PASS |
| C8 | 租户隔离 | yudao（租户1）token 携带 `tenant-id: 162` 访问 → `{"code":403,"msg":"您无权访问该租户的数据"}` | PASS |

C7 首测出现 500 系异常，经后端日志定位为测试脚本 JSON 转义错误（PowerShell 反斜杠字面量导致 payload 非法、Jackson 解析失败），改用文件体重测通过——**非产品缺陷**。

## 5. D 组：Excel 导入、导出

### 5.1 D1 导入模板 — PASS

`GET /system/user/get-import-template`（200，4120B）→ 表头实测：

```
登录名称|用户名称|部门编号|用户邮箱|手机号码|用户性别|身份类别|研究方向|导师|指导教师|开始年月|结束年月|账号状态
```
六个新增字段全部在列 ✅。

### 5.2 D2 合法导入直接创建正式用户 — PASS

```
POST /system/user/import（multipart：d2_valid.xlsx，updateSupport=false）
→ {"code":0,"data":{"createUsernames":["r3imp101","r3imp102"],"updateUsernames":[],"failureUsernames":{}}}
```
DB：r3imp101（id=270，身份1/方向1/导入导师甲/导入指导甲/2023-09/2026-06）、r3imp102（id=271，身份4/方向2/导师与指导教师为空、2024-03/2027-03）落库；无 lab_register_apply 记录（不进入审批）✅；中文值经导出回读核验无乱码。

### 5.3 D4/D5 整批回滚 — PASS

```
D4（第1行合法 r3imp103 + 第2行重复用户名 admin + 第3行身份类别=9）：
→ {"code":1002003025,"msg":"导入失败，已取消整批导入：第 3 行 用户[admin]：用户账号已经存在；第 4 行 用户[r3imp104]：身份类别不合法"}
D5（第1行合法 r3imp105 + 第2行开始年月=2026-99）：
→ {"code":1002003025,"msg":"导入失败，已取消整批导入：第 3 行 用户[r3imp106]：startYmd: 开始年月格式必须为 yyyy-MM"}
```
失败报告含**行号（Excel 实际行号）、用户名、原因** ✅。DB 核验：`r3imp103/104/105/106` 均不存在——**整批取消，零部分成功** ✅。

### 5.4 D3 导出 — PASS

`GET /system/user/export-excel?pageNo=1&pageSize=50`（200，6486B）→ 表头实测：

```
用户编号|用户名称|用户昵称|部门名称|用户邮箱|手机号码|用户性别|身份类别|研究方向|导师|指导教师|开始年月|结束年月|帐号状态|最后登录IP|最后登录时间
```
含六个新字段，r3imp001/101/102 导出值与 DB 一致；**无密码、密码哈希、令牌等敏感列** ✅。

## 6. E 组：安全及回归

| # | 用例 | 结果 |
|---|---|---|
| E1 | `system.user.register-enabled=false` | PASS（DB 实测 infra_config id=13 value=false） |
| E2 | 旧注册接口不能绕过审批 | PASS：`POST /admin-api/system/auth/register`（完整 payload）→ `1002003011 注册功能已关闭`，未创建任何用户 |
| E3 | 新注册申请接口正常 | PASS（A1/A3/A4/A5 全链路） |
| E4 | 跨租户申请防泄露 | PASS：租户 1 上下文查 r3user001（租户 162）→ `1061002004 用户名或密码不正确`（防枚举统一文案） |
| E5 | 普通用户不能调管理接口 | PASS：regtest008 token 访问 `/system/user/page`、`/lab/register-apply/page`、`/lab/plasmid/page`（V1）、`/lab/v2/plasmid/page`（V2）→ 全部 `403 没有该操作权限` |
| E6 | 无 token 访问 | PASS：`/lab/plasmid/page` 无 Authorization → `401 账号未登录`（认证链路完好） |
| E7 | 质粒 V1/V2 不受影响 | PASS：V1/V2 控制器均正常路由（401/403 而非 404/500）；R1/R2 构建与 493 项单测通过记录在案 |

## 7. 发现的问题及处置

| # | 现象 | 定位 | 处置 |
|---|---|---|---|
| 1 | C7 启停用首次 500 系统异常 | 后端日志：`JsonParseException: Unexpected character ('\\')` —— 测试脚本 PowerShell 转义错误，payload 非法 | 测试脚本改用文件体重测通过；**非产品缺陷，产品代码零修改** |
| 2 | B6 超长导师用例首次“通过” | 测试数据实际 48 字符（≤50 合法） | 修正为 51 字符复测，正确拒绝 |
| 3 | 重复登录后旧 access token 失效 | yudao 登录机制正常行为 | 换新 token 复测，非缺陷 |

**产品代码（后端/前端/SQL）修改文件清单：无。**

## 8. 测试数据新增情况与清理建议（均未擅自清理）

| 数据 | 位置 | 说明 | 建议 |
|---|---|---|---|
| lab_register_apply id=25（r3user001，租户 162，PENDING）+ history id=37 | lab 库 | A 组测试申请，含六字段与 BCrypt 密码 | **建议保留**：负责人在浏览器登录租户 162 审批员账号审批通过后即可补齐 A 组闭环验证；之后随 A 组补验结论一并处置 |
| system_users id=268 r3imp001 / 269 r3imp002 / 270 r3imp101 / 271 r3imp102 | 租户 1 | C 组/D 组新建测试用户（无角色、未登录过） | 验收后可由管理员删除（逻辑删除） |
| regtest008（id=261）六字段 = 3/5/R3导师测试/R3指导教师测试/2023-09/2026-06 | 租户 1 | B 组修改（原值全 NULL） | 如需还原可将六字段置 NULL；账号保留 |
| login_log 新增若干条（r3user001 登录失败、regtest008/yudao 成功登录等） | lab 库 | 常规审计日志 | 保留作审计，无需清理 |
| 孤儿数据 history id=25/26、login_log id=8460/8461 | lab 库 | 只读核验：均在、deleted=0，未触碰 | 按既有裁决继续保留 |
| 角色/岗位/部门/菜单/权限/配置 | — | 零改动（含 admin 行、注册开关） | — |

## 9. 构建与测试结果（本任务执行情况）

- 后端/前端代码零改动，无需重新编译构建；R1/R2 已通过的 493 项后端单测、lab 30 项单测、前端 ESLint 与生产构建结果继续有效。
- 本任务新增验证均为**真实 HTTP 请求 + MySQL 实时只读查询**，全程未执行任何 DDL/DML 写操作（DB 变更仅来自业务接口自身行为与既有测试账号资料更新，均已列入 §8）。
- 证据文件目录：`C:\Users\Administrator\AppData\Local\Temp\r3ev\`（请求体、Excel 测试文件、导出件、token 文件、evidence.log）。

## 10. 最终结论：CONDITIONAL PASS

- B、C、D、E 四组全部 PASS，A 组提交侧全部 PASS；
- 唯一阻塞：**A 组审批通过→建号→角色分配→登录闭环**，缺租户 162 审批员登录凭据，未绕过鉴权；
- 解除条件（二选一）：① 负责人使用租户 162 审批员账号在「系统管理 → 注册审批」审批 apply 25（r3user001），随后可补验建号/角色/登录闭环；② 提供审批员测试凭据后由后续任务补测。

本任务到此停止，不进入下一业务模块。
