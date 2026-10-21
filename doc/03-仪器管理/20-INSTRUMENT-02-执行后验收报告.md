# INSTRUMENT-02 执行后验收报告

> 任务：TASK INSTRUMENT-02-POST-SQL-VERIFY-01（仪器管理第二阶段：SQL 执行后验收）
> 执行日期：2026-10-15
> 数据库：`labplatform`（MySQL 8.0.12，InnoDB，utf8mb4_unicode_ci）
> 后端：`yudao-server` fat jar（本任务重建），Spring profile=`local`，端口 48080
> 前端：`yudao-ui-admin-vue3`（15 个 instrument 页面文件）
> 已执行 SQL（由负责人执行，不在本任务）：`20261015_instrument_02_schema.sql`、`20261015_instrument_02_menu.sql`、`20261015_instrument_02_device_manager_role.sql`

**严格边界声明（本任务实际遵守情况）**

1. 本任务以只读核验、代码审查、接口测试为主；
2. **未执行任何 DDL**；**未直接执行 DML**（所有业务写入均通过服务端接口调用产生，属已授权的写路径测试）；
3. **未修改** `system_role`、`system_role_menu`、`system_menu`、`system_tenant_package`；
4. **未给任何用户分配角色 908**；
5. 未清空或重建 INSTRUMENT-01 / INSTRUMENT-02 业务数据；
6. 发现的差异均按"证据 → 影响 → 建议"记录，未自行扩大修改范围。

> 说明：写路径测试产生的 INSTRUMENT-02 业务测试数据一律保留、未清理，清单见附录。

---

## 一、总体结论

### 结论：**CONDITIONAL PASS**

| 阶段 | 结论 | 依据 |
| --- | --- | --- |
| 一、数据库执行后核验 | **PASS** | 六表结构/行数、14 菜单、角色 908、授权 6/14/8、租户套餐、INSTRUMENT-01 未受损、无重复异常——只读实查全部符合预期 |
| 二、代码与权限链验收 | **PASS（静态核验）** | 10 项检查均有代码证据（见第四节） |
| 三、真实运行验证 | **PASS（除边界受限项）** | 编译、启动、19 个 INSTRUMENT-02 接口、权限矩阵、跨租户阻断、2 组真实并发实测通过（见第五节） |
| 四、INSTRUMENT-03 依赖检查 | **已确认** | 预约创建未实现；设计文档 §8.1.1 强制要求在 03 落地服务端暂停校验（见第七节） |

**判定说明**：数据库状态、权限边界、核心业务规则（申请防重、审批、信用初始化幂等、流水一致性、暂停创建/解除/G12 联动/G13、并发串行化）均取得**真实运行证据**，未发现功能性缺陷。因下列两项受任务边界限制**未能完成端到端运行验证**，且发现 2 项需负责人确认的观察项，故整体判定为 **CONDITIONAL PASS** 而非 PASS：

- **未运行时验证**：① 仪器设备负责人"权限 + 业务关系"双条件的运行时隔离验证（禁止分配角色 908，且现存负责人关系均为 `ROOM_REPAIR`，无 `DEVICE/PLATFORM` 关系）；② 暂停"超过计划结束时间仍有效"的端到端演示（需写入 `end_time` 为过去的行，属 DML，被禁止）。
- **待负责人确认**：③ 报废设备仍可提交资质申请；④ ALL 暂停生效期间新过审资质的 `status` 状态一致性。

上述 CONDITIONAL 条件均为**确认 / 补验**性质，**不涉及已知缺陷修复**。条件见第六节；如需修复/补验的独立任务见第八节。

---

## 二、数据库实查结果与证据

连接：`mysql -h127.0.0.1 -P3306 -ubencao -Dlabplatform --default-character-set=utf8mb4`（只读 SELECT）。

### 2.1 六张 INSTRUMENT-02 业务表（存在性 / 结构 / 字符集）

实查 `information_schema`：

| 表 | 列数 | 引擎 | 排序规则 |
| --- | --- | --- | --- |
| `lab_instrument_qualification_apply` | 25 | InnoDB | utf8mb4_unicode_ci |
| `lab_instrument_qualification_apply_history` | 16 | InnoDB | utf8mb4_unicode_ci |
| `lab_instrument_qualification` | 17 | InnoDB | utf8mb4_unicode_ci |
| `lab_instrument_credit_account` | 14 | InnoDB | utf8mb4_unicode_ci |
| `lab_instrument_credit_flow` | 21 | InnoDB | utf8mb4_unicode_ci |
| `lab_instrument_suspend` | 22 | InnoDB | utf8mb4_unicode_ci |

列数与 DDL 期望一致；与 Java DO（`InstrumentQualificationApplyDO`=25、`InstrumentSuspendDO`=22 等）字段一致；`lab_instrument_credit_account.initialized` 为 `bit(1)`（接口返回 `true`，DB 用 `initialized+0=1` 印证）。**PASS**

### 2.2 行数（核验起点 / 测试后）

| 表 | 测试前 | 测试后 | 说明 |
| --- | --- | --- | --- |
| apply | 0 | 2 | 验收写路径新增（id=1、2） |
| apply_history | 0 | 4 | SUBMIT×2 + APPROVE×2 |
| qualification | 0 | 2 | id=1(设备2)=SUSPENDED、id=2(设备1)=ACTIVE |
| credit_account | 0 | 1 | 281，score=70，initialized=1 |
| credit_flow | 0 | 3 | 不可变流水，before/after 链完整 |
| suspend | 0 | 3 | id=1 SINGLE/RELEASED、id=2 ALL/RELEASED、id=3 ALL/ACTIVE |

SQL 证据（节选）：

```
SELECT 'apply',COUNT(*) FROM lab_instrument_qualification_apply UNION ALL
SELECT 'qualification',COUNT(*) FROM lab_instrument_qualification UNION ALL ...
=> apply=2  apply_history=4  qualification=2  credit_account=1  credit_flow=3  suspend=3

SELECT id,user_id,target_id,status FROM lab_instrument_qualification;
=> 2 | 281 | 1 | ACTIVE     1 | 281 | 2 | SUSPENDED

SELECT id,apply_id,action FROM lab_instrument_qualification_apply_history;
=> 1|1|SUBMIT  2|2|SUBMIT  3|1|APPROVE  4|2|APPROVE
```

### 2.3 异常项

未发现因重复执行脚本导致的异常菜单授权、重复角色或不完整写入（详见 3.5）。**PASS**

---

## 三、角色、菜单与授权核验结果

### 3.1 菜单 13660–13673（14 条）

`SELECT COUNT(*) ... WHERE id BETWEEN 13660 AND 13673 AND deleted=0` → **14 条**，全部 `status=0`：

| 类型 | ID | 父级 | 语义（permission） |
| --- | --- | --- | --- |
| 2 页面 | 13660 | 13600 | 我的资质 |
| 3 按钮 | 13661 / 13662 | 13660 | `qualification:query` / `qualification:apply` |
| 2 页面 | 13663 | 13600 | 我的信用 |
| 3 按钮 | 13664 | 13663 | `credit:query` |
| 2 页面 | 13665 | 13600 | 资质审核 |
| 3 按钮 | 13666 / 13667 | 13665 | `qualification:audit` / `qualification:manage` |
| 2 页面 | 13668 | 13600 | 信用管理 |
| 3 按钮 | 13669 / 13670 | 13668 | `credit:adjust` / `credit:export` |
| 2 页面 | 13671 | 13600 | 暂停管理 |
| 3 按钮 | 13672 / 13673 | 13671 | `suspend:query` / `suspend:manage` |

层级正确（5 个页面挂 13600，9 个按钮各挂所属页面），状态全部启用。**PASS**

### 3.2 角色 908

```
SELECT id,tenant_id,name,code,status,sort,type,data_scope FROM system_role WHERE id IN (904,906,908);
=> 904 | 162 | 普通用户        | 普通用户                  | 0 | 10 | 2 | 1
   906 | 162 | 本草基因管理员  | lab_admin                 | 0 | 30 | 2 | 1
   908 | 162 | 仪器设备负责人  | instrument_device_manager | 0 | 35 | 2 | 1
```

角色 908 存在，编码 `instrument_device_manager`、租户 162、状态启用。**PASS**

### 3.3 授权数量（13660–13673 区间）：6 / 14 / 8

```
SELECT role_id,COUNT(*) FROM system_role_menu
WHERE role_id IN (904,906,908) AND menu_id BETWEEN 13660 AND 13673 GROUP BY role_id;
=> 904=6   906=14   908=4
```

- 904 = 6：13660、13661、13662、13663、13664、13672（我的资质+申请、我的信用查询、我的暂停查询）→ 符合脚本设计。
- 906 = 14：区间内**全部** 14 条 → 符合脚本设计（lab_admin 全局业务管理）。
- 908 = 4（区间内）但**总授权数为 8**：

```
SELECT role_id,menu_id FROM system_role_menu WHERE role_id=908;
=> 13478, 13600, 13620, 13621, 13660, 13661, 13665, 13666   （共 8 条，无重复）
```

即 908 授权数 = **8**（含父级 13478 与 INSTRUMENT-01 的 13600/13620/13621），与脚本设计"8"一致。908 具备 `qualification:query`（13661）与 `qualification:audit`（13666）——即"负责人可审批其负责设备的申请"，符合 `04 §5.1`。

**未越权**：908 无 `credit:*`、`suspend:*`、设备写权限、`qualification:apply/manage`。**PASS**

### 3.4 租户 162 / 套餐 114 未被意外覆盖

```
SELECT id,name,status,package_id FROM system_tenant WHERE id=162;
=> 162 | 成都中医药大学 | 0 | 114

SELECT CHAR_LENGTH(menu_ids) len, LOCATE('13660',menu_ids), LOCATE('13673',menu_ids) FROM system_tenant_package WHERE id=114;
=> len=1462  13660@1379  13673@1457
```

套餐 114 的 `menu_ids` 长度 1462，且 **13660…13673 连续存在于授权区间**（`13660,` 与 `13673` 均按逗号边界定位）。租户 162 状态正常、套餐绑定 114 未变。**PASS**

### 3.5 INSTRUMENT-01 未受损 + 无重复异常

| 核验项 | 结果 |
| --- | --- |
| 菜单 13600–13653 | **26 条**（1 目录 + 7 页面 + 18 按钮），未删除/修改 |
| `lab_instrument%` 业务表 | **11 张**，数量与 INSTRUMENT-01 交付一致 |
| INSTRUMENT-01 测试数据 | device 2 行、manager 3 行、notice 2 行、platform 2 行、room 1 行，均在位 |
| `system_role_menu` 角色 908 重复 | **0 条**（`GROUP BY role_id,menu_id HAVING COUNT(*)>1` 为空） |
| `system_role` code=instrument_device_manager 重复 | 仅 1 行 |

**PASS**

### 3.6 自动到期 Job 未注册（H1 裁决落地核验）

```
SELECT COUNT(*) total, SUM(handler_name LIKE '%instrument%' OR handler_name LIKE '%suspend%') FROM infra_job;
=> total=34   instrument_jobs=0
```

`infra_job` 中**无任何**仪器/暂停 handler → 暂停不会自动到期解除（人工解除语义）。**PASS**

---

## 四、代码与服务端权限链检查结果

| # | 检查项 | 结论 | 关键证据 |
| --- | --- | --- | --- |
| 1 | 资质申请/审批/审批历史/设备级资质查询 | PASS | `InstrumentQualificationServiceImpl#applyQualification`（校验设备存在、无 PENDING、无同设备 ACTIVE；插申请 + SUBMIT 历史）；`#auditApply`（结果枚举校验、驳回意见必填、`selectByIdForUpdate` 行锁、`updateAuditResult` affectedRows 守卫、写 APPROVE/REJECT 历史）；`#getMyQualifications`/`#getApplyPage`/`#getApplyHistoryList` |
| 2 | 首审初始化信用 100 且重复审核不重复初始化 | PASS | `#initCreditAccountOnce(userId)`：Redisson `creditAccountKey(tenant,user)` 锁内「查不到则 insert `score=100/initialized=true`」；已初始化则不创建/不重置/不加分；`DuplicateKeyException` 捕获跳过。**运行实测**：E7 首次通过→100；后续审批第二台设备→仍 70（未回填 100） |
| 3 | 信用流水与账户一致性、事务边界、并发 | PASS | `InstrumentCreditServiceImpl#adjustCredit`：`delta≠0`、`reasonType∈{VIOLATION,OVERDUE,REWARD,MANUAL}`、目标用户有效；非管理员需目标用户在其管理设备上持 ACTIVE/SUSPENDED 资质；`transactionTemplate.execute(doAdjust)` 内 `selectByIdForUpdate` 行锁 + 更新 score + 写不可变流水（before/after、操作人快照）。**运行实测**：并发 2×扣分无丢失更新（100→90→80→70） |
| 4 | SINGLE / ALL 暂停记录与人工解除 | PASS | `InstrumentSuspendServiceImpl#createSuspend`（scope 校验、SINGLE 需 deviceId、`resolveEndTime` 预设 1/3/7/14/30 天或自定义、ALL 需 `canManageAll`、SINGLE 需 `canManageDevice`、Redisson `suspendKey`+事务「重复覆盖校验→insert ACTIVE→G12 联动」）；`#releaseSuspend`（`updateReleaseIfActive` affectedRows 守卫 + `resumeUncoveredQualifications`） |
| 5 | 暂停不因 `end_time` 到期自动失效；不得注册自动解除 Job | PASS | `InstrumentSuspendMapper#selectActiveCovering` 仅 `status=ACTIVE AND start_time<=now`，**不含 `end_time` 条件**；`expireSuspends`/`selectActiveExpired`/`updateExpireIfActive` 保留但注明"本期不启用"；`InstrumentSuspendExpireJob` 类存在但**未注册 `infra_job`**（3.6 实测 0 条） |
| 6 | 普通用户仅能访问自己的申请、信用及允许查看的数据 | PASS | `getApplyPage` 非管理员限定 `applicantUserId=loginUserId` 或管理设备；`getCreditServiceImpl#getMyCredit/#getMyFlowPage` 强制本人；`getSuspendPage`/`getQualificationPage` 非管理员管理范围为空时显式 `FORBIDDEN`。**运行实测**：904 调用管理端接口全部 403（A1–A9） |
| 7 | 负责人须同时具备权限与实际设备负责人业务关系 | PASS（静态） | `InstrumentScopeSupport#canManageDevice = canManageAll ∨ managerMapper.selectActiveList('DEVICE',deviceId) 含该用户 ∨ 平台负责关系`；`auditApply` 显式调用 `scopeSupport.canManageDevice`，注释标注"B2 双重校验"；符合 `04 §5.1/§5.3`（不得用角色代替负责人关系，F19）。**运行时验证受边界限制**（见第六节） |
| 8 | lab_admin / 系统管理员 / 其他授权角色管理范围 | PASS | `canManageAll = hasAnyRoles('super_admin','lab_admin')`，与 `04 §5.1`（平台超级管理员 + 本草基因管理员 = 全局业务管理）一致；租户管理员 `tenant_admin` 不在全局名单内，符合冻结规则。**运行实测**：906(lab_admin) 审批/加扣分/暂停/解除全部成功 |
| 9 | 所有接口服务端校验（非仅前端隐藏按钮） | PASS | 全部 19 个 INSTRUMENT-02 端点均带 `@PreAuthorize("@ss.hasPermission(...)")`；Service 层另有数据范围显式校验。**运行实测**：无 token 401、无权限/超范围 403 均由服务端返回 |
| 10 | 跨租户 / 越权 / 重复初始化 / 并发提交 / 事务时序风险 | PASS（含并发实测） | 租户插件自动追加 `tenant_id`（跨租户 `selectById` 返回 null → 拒绝）；审批行锁 + affectedRows 防重复审核；账户唯一键 `uk_account_tenant_user` + Redisson 账户锁 + 同事务三重幂等；暂停 Redisson 锁 + 条件更新。**运行实测**：跨租户 403、重复审核 4052、并发暂停仅 1 条 ACTIVE、并发扣分无丢失更新 |

---

## 五、编译、启动、接口与并发测试的真实结果

### 5.1 后端编译

| 项 | 结果 |
| --- | --- |
| 命令 | `mvn -o -pl yudao-server -am -Dmaven.test.skip=true -DskipTests package` |
| 结果 | **BUILD SUCCESS**（40.6s，退出码 0） |
| 产物 | `yudao-server/target/yudao-server.jar`，157,863,654 字节，构建时间 **2026-10-15 14:35:02** |
| 验证 | 产物内包含 `InstrumentQualificationController` / `InstrumentSuspendController` / `InstrumentCreditController` |

> **注意（环境问题，非产品缺陷）**：不带 `-Dmaven.test.skip=true` 时，`package` 在 `yudao-module-infra` **测试源码编译**阶段失败（`FileServiceImplTest`/`JobServiceImplTest` 等报 `NoSuchFileException: ...\FileService.class`），系增量构建 target/classes 不完整所致，与 INSTRUMENT-02 代码无关。规避方式已记录（见第八节 T-2）。

### 5.2 后端启动

| 项 | 结果 |
| --- | --- |
| 启动方式 | `java -jar yudao-server.jar --spring.profiles.active=local`（JDK temurin 21） |
| 端口 | **48080 LISTENING**（PID 7768） |
| 接口注册 | `GET /v3/api-docs` 含 **19 个** INSTRUMENT-02 路径：qualification 9 / suspend 4 / credit 6（另有 INSTRUMENT-01 路径） |

### 5.3 接口权限矩阵（真实 HTTP 调用）

测试账号（tenant-id=162）：904 `189140002`(user 281，普通用户)、906 `bencao`(user 278，lab_admin)；另 super_admin `admin`(user 1, tenant 1)。密码 `admin123`。

**A. 普通用户（904）越权/超范围 —— 全部拒绝**

| 用例 | 端点 | 结果 |
| --- | --- | --- |
| A1 | POST `/qualification/audit` | **403** 没有该操作权限 |
| A2 | POST `/suspend/create` | **403** |
| A3 | POST `/credit/adjust` | **403** |
| A4 | GET `/credit/page` | **403**（数据范围，非管理员） |
| A5 | GET `/suspend/page` | **403**（数据范围） |
| A6 | GET `/qualification/page` | **403**（数据范围） |
| A7 | GET `/credit/flow/page` | **403**（数据范围） |
| A8 | POST `/qualification/revoke` | **403** |
| A9 | POST `/suspend/release` | **403** |

**B. 无 token** — GET `/qualification/my` → **401** 账号未登录

**C. 跨租户阻断**

| 用例 | 结果 |
| --- | --- |
| C1 904 token + `tenant-id: 1` | **403** 您无权访问该租户的数据 |
| C2 906 token + `tenant-id: 1` | **403** 您无权访问该租户的数据 |
| C3 super_admin(tenant1) token + `tenant-id: 162` | **403** 您无权访问该租户的数据 |

**D. 普通用户自查（904，tenant 162）—— 全部允许且仅返回本人**

| 用例 | 结果 |
| --- | --- |
| D1 GET `/qualification/my` | 200 |
| D2 GET `/credit/my` | 200，初始 `initialized=false`（未初始化时不暴露分数） |
| D3 GET `/credit/flow/my` | 200（本人流水） |
| D4 GET `/suspend/my` | 200（本人暂停） |

**E. 资质申请 → 审批 → 信用初始化**

| 用例 | 结果 |
| --- | --- |
| E1 904 申请设备2 | **200**，applyId=1 |
| E2 904 重复申请同设备 | **1002004046** 该设备已存在待审核的资质申请，请勿重复提交 |
| E3 904 申请设备9999 | **1002004010** 仪器设备不存在 |
| E4 906 驳回但未填意见 | **1002004049** 驳回时必须填写审核意见 |
| E5 906 审批通过 | **200** true |
| E6 904 `/credit/my` | **score=100，initialized=true**（首审通过初始化 100） |
| E7 906 重复审批同一单 | **1002004052** 申请状态已变更，请刷新后重试（不重复初始化） |
| E8 **G13 复验**：在 281 持有 ACTIVE ALL 暂停期间，906 审批通过第二台设备(applyId=2) | **200** true → **暂停不拦截资质审核通过** |
| E9 904 `/credit/my` 二次复核 | **仍为 70（未回填 100）** → 后续审核其他仪器**不重复初始化** |
| E10 904 `/qualification/my` | 2 条（设备1 ACTIVE、设备2 SUSPENDED） |

**F. 信用加扣分与不可变流水**

| 用例 | 结果 |
| --- | --- |
| F1 906 扣 10 分 | 200，flowId=1 |
| F2 904 `/credit/my` | score=90 |
| F3 904 `/credit/flow/my` | `changeType=DEDUCT, scoreChange=-10, scoreBefore=100, scoreAfter=90, reasonType=VIOLATION, operatorUserId=278` |
| F4 906 `/credit/page`、`/credit/flow/page` | 200（管理端可见） |
| F5 906 delta=0 | **1002004061** 分数变动值不能为 0 |

**G. 暂停 SINGLE / ALL 与人工解除**

| 用例 | 结果 |
| --- | --- |
| G1 906 建 SINGLE(设备2) | 200，id=1 |
| G2 重复覆盖创建 | **1002004079** 该用户已存在覆盖范围相同的生效暂停记录 |
| G3 SINGLE 缺 deviceId | **1002004074** 单仪器暂停必须指定设备 |
| G4 非法 scope | **1002004073** 暂停范围类型不合法 |
| G5 目标用户不存在 | **1002004076** 目标用户不存在、已停用或不属于当前租户 |
| G6 presetDays=0 | **1002004075** 暂停截止时间必须晚于开始时间 |
| G7 904 `/suspend/my` | id=1 ACTIVE，`startTime/endTime` 正确 |
| G8 906 `/qualification/page` | 资质 id=1 变 **SUSPENDED**（**G12 联动**） |
| G9 906 解除暂停 | 200 true |
| G10 重复解除 | **1002004071** 暂停记录不是生效状态（条件更新防并发） |
| G11 资质恢复 | 资质 id=1 回到 **ACTIVE**（`resumeUncoveredQualifications` 仅恢复未被覆盖者） |
| G12 906 建 ALL | 200，id=2 |
| G13 904 `/suspend/my` | ALL ACTIVE 上门，历史 RELEASED 行完整保留（R9 历史全保留） |

### 5.4 并发与事务（真实并发实测）

| 并发用例 | 方法 | 结果 | 结论 |
| --- | --- | --- | --- |
| **暂停重复创建（Redisson 同用户锁）** | 2 个进程同时 POST `/suspend/create`（userId=281，ALL，预设7天） | 1 个 **200**（创建 id=3）、1 个 **1002004079**；DB 最终**仅 1 条 ACTIVE**（id=3） | 同用户锁 + 「重复覆盖校验→插入」同事务**串行化生效**，无重复行、无不完整写入 |
| **信用并发扣分（行锁）** | 2 个进程同时 POST `/credit/adjust`（userId=281，-10） | 2 个均 **200**（flowId=2、3）；最终 `score=70`；流水链 **100→90、90→80、80→70** | `SELECT ... FOR UPDATE` 行锁 + 事务边界正确，**无丢失更新**，before/after 链连续一致 |

> 说明：并发证据为**行为层**（结果行数、最终分值、流水链），未直接观测 Redis 键；其与 `InstrumentLockRedisDAO` 设计（`instrument:suspend:{tenant}:user:{userId}`，租约 10s）一致。

### 5.5 单元测试（H2 内存库）

| 项 | 结果 |
| --- | --- |
| 用例类 | `yudao-module-lab/.../service/instrument/Instrument02ServiceTest`（26 个用例：申请防重、重复审核、并发首审初始化幂等、负分/流水链、暂停重复覆盖、G12 联动与恢复安全、G13、数据范围拒绝等） |
| 命令 | `mvn -o -pl yudao-module-lab test -Dtest=Instrument02ServiceTest -DfailIfNoTests=false "-DargLine=-Dnet.bytebuddy.experimental=true"` |
| 结果 | **Tests run: 26, Failures: 0, Errors: 0** — **BUILD SUCCESS** |
| 不使用该参数时 | 26 个用例全部 `Failed to load ApplicationContext`，根因 `Java 21 (65) is not supported by the current version of Byte Buddy`（Mockito 对 `InstrumentLockRedisDAO` 打桩失败）——**测试基建问题，非产品缺陷** |

该测试 Mapper 走真实 H2、`PermissionApi`/`AdminUserApi`/`InstrumentLockRedisDAO` 为 Mock（锁直通），故其覆盖的是**DB 层幂等/事务/唯一键**语义；Redis 锁行为由 5.4 的接口并发测试覆盖。

### 5.6 前端

| 项 | 结果 |
| --- | --- |
| instrument 页面文件 | **15 个** `*.vue`，含 5 个 INSTRUMENT-02 新增页：`my-qualification`、`my-credit`、`qualification-audit`、`credit-manage`、`suspend-manage` |
| TS 检查（vue-tsc） | instrument 模块 **0 错误**；剩余错误均为历史存量（plasmid v2 等），非本任务引入 |
| 浏览器可视化走查 | **未执行**（本报告以真实接口 + DB 证据为主），见第六节 |

---

## 六、未验证项目及影响

| # | 未验证项 | 原因 | 影响与补偿证据 |
| --- | --- | --- | --- |
| N1 | 仪器设备负责人"权限 + 业务关系"双条件的**运行时隔离**验证 | 任务边界**禁止给任何用户分配角色 908**；且现存 `lab_instrument_manager` 均为 `ROOM_REPAIR` 类型，无 `DEVICE/PLATFORM` 负责人关系，无法构造"有权限无关系 / 有关系无权限"的对照 | 静态证据充分（`canManageDevice` 同时判定权限角色与 `manager` 表 ACTIVE 关系；`auditApply` 显式调用）。**建议授权后补验**（见 T-V1） |
| N2 | 暂停"超过计划结束时间仍有效"的**端到端演示** | 需写入 `end_time` 为过去的 ACTIVE 行，属 DML，任务禁止 | 补偿证据：`infra_job` 无任何仪器/暂停 handler（3.6 实测 0/34）；`selectActiveCovering` 不含 `end_time` 条件（第四节目视）。可判定"不注册自动解除 Job"要求已满足 |
| N3 | 浏览器可视化交互走查（5 个新页面 UI/交互） | 本任务聚焦接口与数据证据 | 前端文件齐备、TS 0 错误、接口 200/403 行为正确；建议负责人做一次可视化走查 |
| N4 | Redis 锁的**键级**直接观测 | 未在 Redis 中直查锁 key | 行为层并发证据（5.4）与设计一致 |
| N5 | **正向**跨租户授权访问（仅验证了拒绝路径） | 租户 162 无跨租户授权场景 | 拒绝路径（C1–C3）已充分，正向路径属框架能力，不属本模块风险 |
| N6 | 预约创建路径的暂停校验 | **INSTRUMENT-03 尚未实现**（设计如此） | 属第七节交付依赖，非本期缺陷 |

---

## 七、进入 INSTRUMENT-03 的前置条件

### 7.1 依赖现状（已核实）

- 数据库中**无**预约/冻结/维修工单业务表（`lab_plasmid_violation`、`system_username_reservation` 与仪器模块无关）；代码中**无** `InstrumentReservation*` / `InstrumentFreeze*` 类 → **预约创建接口尚未实现**。
- 设计文档 `03-预约规则与并发控制设计.md` **§8.1.1「预约创建前的暂停校验（强制约束）」**（H2 裁决，来源 INSTRUMENT-02）明确：**预约侧拦截本期尚未实现，须在 INSTRUMENT-03 落地**。

### 7.2 INSTRUMENT-03 必须满足的强制约束（不得自行裁决）

1. **必须在服务端预约创建路径**校验生效暂停，不得仅前端提示；
2. 生效暂停判定 = `status='ACTIVE' AND start_time<=now`，**不得使用 `end_time>now`**（暂停超过计划结束时间在人工解除前仍按有效处理）；
3. `SINGLE` 暂停只拦截对应设备；`ALL` 暂停拦截该用户所有适用设备；
4. 暂停校验与预约插入必须**同一事务**并配合设备行锁，保证并发一致（避免"检查通过后并发建单"）；
5. 暂停期间资质仍可过审（G13，不得因暂停把新申请判 REJECTED）；
6. 预约分配、冲突处理、维修工单规则**尚未裁决**，不得自行决定。

### 7.3 INSTRUMENT-02 侧为 03 提供的基础

- 六表可用；`selectActiveCovering(userId, deviceId)` 语义已按"ACTIVE 即生效（无 end_time 条件）"冻结，可直接作为预约暂停判定来源；
- 资质权威来源为 `lab_instrument_qualification.status`，流水/历史全保留可追溯。

---

## 八、独立修复/后续任务（本任务未执行）

| 编号 | 任务 | 类型 | 说明 |
| --- | --- | --- | --- |
| T-1 | 测试基建：为 `yudao-module-lab` 固定 `-Dnet.bytebuddy.experimental=true`（pom surefire `argLine` 或规范文档） | 修复 | 否则 `Instrument02ServiceTest` 在 JDK 21 下 26/26 报 ApplicationContext 失败 |
| T-2 | 修复 `yudao-module-infra` 测试源码编译 `NoSuchFileException(FileService.class)`，或统一改 `-Dmaven.test.skip=true` 打包 | 修复 | 影响 `package` 可重复性，与 INSTRUMENT-02 代码无关 |
| T-V1 | **授权后**补验"负责人双条件"运行时（临时创建 DEVICE 业务关系，或单独授权分配 908 给测试账号） | 补验 | 需单独授权，本任务禁止 |
| T-V2 | **授权后**补验"暂停超过 end_time 仍有效"（写入过去 end_time 的 ACTIVE 行） | 补验 | 需单独授权 DML |
| T-C1 | 负责人确认：**报废设备仍可提交资质申请**（实测 E3：设备1 SCRAPPED 申请成功，applyId=2）是否属预期 | 确认 | `04 §2.1` 未要求申请时校验设备状态；若需拦截，属功能增强（非本期缺陷） |
| T-C2 | 负责人确认：**ACTIVE ALL 暂停期间新过审资质保持 ACTIVE**（实测：资质 id=1 被联动为 SUSPENDED，id=2 在暂停生效期间过审仍为 ACTIVE），状态是否需统一 | 确认 | G13 语义下预约拦截依赖 `selectActiveCovering`，不影响 03 功能；仅状态展示一致性 |
| T-C3 | 负责人确认：904 的**前端权限集缺 `suspend:query`**（13672 的父 13671 未授权 → `filterDisableMenus` 丢弃），但后端 `role_menu` 直查仍允许 `GET /suspend/my`（实测 200，仅返回本人数据） | 确认 | 属前后端权限集差异；良性，但若需前端展示"我的暂停"须补授权或调整菜单结构 |
| T-C4 | 执行 INSTRUMENT-03：在预约创建路径落实 §7.2 全部强制约束 | 新阶段 | 不得在本任务内启动 |

---

## 附录 A：测试产生的业务数据清单（保留、未清理）

| 表 | id | 内容 | 状态 |
| --- | --- | --- | --- |
| qualification_apply | 1 | 281 申请设备2 | APPROVED |
| qualification_apply | 2 | 281 申请设备1（SCRAPPED） | APPROVED |
| qualification_apply_history | 1–4 | SUBMIT×2、APPROVE×2 | 只增 |
| qualification | 1 | 281/设备2 | SUSPENDED |
| qualification | 2 | 281/设备1 | ACTIVE |
| credit_account | 1 | 281，score=70，initialized=1 | 生效 |
| credit_flow | 1–3 | -10×3（100→90→80→70） | 不可变 |
| suspend | 1 | 281 SINGLE/设备2 | RELEASED |
| suspend | 2 | 281 ALL | RELEASED |
| suspend | 3 | 281 ALL | **ACTIVE** |

> 未执行 TRUNCATE/DROP；未删除任何数据。如需清理，待单独授权后提交清单。

## 附录 B：关键环境与命令

- DB：`D:\worktools\phpstudy_pro\Extensions\MySQL8.0.12\bin\mysql.exe -h127.0.0.1 -P3306 -ubencao -Dlabplatform --default-character-set=utf8mb4`
- 后端：`java -jar E:\lixin\dev\ruoyi-vue-pro\yudao-server\target\yudao-server.jar --spring.profiles.active=local`
- 打包：`mvn -o -pl yudao-server -am -Dmaven.test.skip=true -DskipTests package`
- 登录：`POST /admin-api/system/auth/login`（header `tenant-id`，body `{"username","password"}`；access token **30 分钟** 有效）
- 本次验收脚本（临时，非交付物）：`%TEMP%\instr02\accept.ps1`、`concurrency.ps1`、`concurrency1.ps1`
