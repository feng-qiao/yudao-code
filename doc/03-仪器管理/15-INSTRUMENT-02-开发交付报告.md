# 15-INSTRUMENT-02-开发交付报告

> 任务：INSTRUMENT-02 仪器使用资质、统一信用账户与人工暂停管理
> 交付日期：2026-10-15
> 交付人：Trae（AI 辅助开发）
> 依据：14-INSTRUMENT-02-实施前核查报告.md（R1~R13 基线、G12~G17 默认方案）、07-接口页面菜单权限设计.md（§2.6/2.11/2.12 冻结权限矩阵）、02/04/08/11 号文档
> 前置状态：INSTRUMENT-01 已验收 PASS，其代码、菜单、基础表与 10 条测试数据全部保留，未清理、未重跑

---

## 结论：CONDITIONAL PASS

| 项 | 状态 | 说明 |
| --- | --- | --- |
| SQL 生成（schema + menu） | DONE | 仅生成，**未执行**任何 DDL/DML，PRECHECK 报告见 §2 |
| 后端开发（资质/信用/暂停 + Job） | DONE | 编译通过，单元测试 26/26 通过（见 §4/§5） |
| 前端开发（5 页面 + 入口 + 首页卡片） | DONE | TypeScript 检查 0 新增错误（见 §6） |
| 数据库部署 | **NOT DONE** | 需负责人授权后执行两个 SQL（见 §8） |
| 真实环境联调 | **NOT DONE** | 依赖 SQL 部署，验收步骤见 §9 |

PASS 范围：代码、编译、类型检查、H2 单元测试（含并发首审、流水一致性、暂停联动）。
CONDITIONAL 原因：数据库迁移与真实环境联调尚未发生，本报告不将其标记为完成；部署与验收条件在 §8/§9 明确列出。

---

## 1. 实际新增和修改的文件清单

### 1.1 SQL（生成，未执行）

| 文件 | 内容 |
| --- | --- |
| `ruoyi-vue-pro/sql/lab/20261015_instrument_02_schema.sql` | 6 张业务表 DDL（幂等 CREATE TABLE IF NOT EXISTS）+ 执行前检查 + 执行后验收 + 停止条件 |
| `ruoyi-vue-pro/sql/lab/20261015_instrument_02_menu.sql` | 菜单/按钮 14 条（ID 13660~13673）+ 套餐 114 追加 + 角色 904/906 授权（幂等 NOT EXISTS 守卫）+ 执行前检查 + 停止条件 |

### 1.2 后端 `yudao-module-lab`（main）

**新增 — 枚举（`enums/instrument/`，6 个）**
- `QualApplyStatusEnum`（PENDING/APPROVED/REJECTED/CANCELED，状态机随 Java 发布 R11）
- `QualApplyActionEnum`（SUBMIT/APPROVE/REJECT/CANCEL）
- `QualificationStatusEnum`（ACTIVE/EXPIRED/SUSPENDED/REVOKED）
- `CreditFlowChangeTypeEnum`（ADD/DEDUCT）
- `SuspendScopeEnum`（SINGLE/ALL）
- `SuspendStatusEnum`（ACTIVE/RELEASED/EXPIRED）

**新增 — DO（`dal/dataobject/instrument/`，6 个）**
- `InstrumentQualificationApplyDO`、`InstrumentQualificationApplyHistoryDO`、`InstrumentQualificationDO`、`InstrumentCreditAccountDO`、`InstrumentCreditFlowDO`、`InstrumentSuspendDO`
- 均继承 TenantBaseDO（tenant_id/creator/updater 等公共字段），无物理外键

**新增 — Mapper（`dal/mysql/instrument/`，6 个）**
- `InstrumentQualificationApplyMapper`（selectPending、selectByIdForUpdate、updateAuditResult、updateCancelIfPending 条件更新）
- `InstrumentQualificationApplyHistoryMapper`（selectListByApplyId，只增不改）
- `InstrumentQualificationMapper`（selectActive/selectListByUser/selectActiveByUserAndTargets/selectSuspendedByUserAndTargets/updateRevokeIfActive/updateSuspendIfActive/updateResumeIfSuspended）
- `InstrumentCreditAccountMapper`（selectByUserId、selectByIdForUpdate 行锁）
- `InstrumentCreditFlowMapper`（selectPageByUser 本人强制过滤、selectCountByBiz、selectExportList）
- `InstrumentSuspendMapper`（selectActiveCovering/selectActiveListByUser/selectActiveExpired/updateReleaseIfActive/updateExpireIfActive 条件更新）

**新增 — Service（`service/instrument/`，3 组接口+实现）**
- `InstrumentQualificationService(+Impl)`：申请/撤回/审核/历史/我的资质/资质分页/撤销
- `InstrumentCreditService(+Impl)`：我的信用/账户分页/我的流水/流水分页/加扣分/导出
- `InstrumentSuspendService(+Impl)`：创建/解除/分页/我的暂停/到期处理（expireSuspends）

**新增 — Controller（`controller/admin/instrument/`，3 个）+ VO（18 个）**
- `InstrumentQualificationController`（`/lab/instrument/qualification`）
- `InstrumentCreditController`（`/lab/instrument/credit`，含 Excel 导出，FastExcel）
- `InstrumentSuspendController`（`/lab/instrument/suspend`）
- VO：`vo/qualification/`（QualApplyReqVO、QualAuditReqVO、QualRevokeReqVO、QualApplyPageReqVO、QualPageReqVO、QualApplyRespVO、QualApplyHistoryRespVO、QualRespVO）；`vo/credit/`（CreditAdjustReqVO、CreditPageReqVO、CreditRespVO、FlowPageReqVO、FlowRespVO、FlowExcelVO）；`vo/suspend/`（SuspendCreateReqVO、SuspendReleaseReqVO、SuspendPageReqVO、SuspendRespVO）

**新增 — Job**
- `job/InstrumentSuspendExpireJob.java`：`@Component("instrumentSuspendExpireJob")` + JobHandler + `@TenantJob`，到期暂停处理并恢复资质；冻结 Cron `0 0/5 * * * ?`（部署时在 infra_job 注册，见 §8）

**修改**
- `enums/ErrorCodeConstants.java`：新增错误码 1_002_004_045 ~ 1_002_004_079（资质 045~059、信用 060~066、暂停 070~079）
- `dal/redis/InstrumentLockRedisDAO.java`：新增 qualApplyKey / creditAccountKey / suspendKey 三个锁 key
- `service/instrument/InstrumentScopeSupport.java`：上移公共方法 `getManagedDeviceIds(userId)`（DEVICE 直接负责 + PLATFORM 平台下设备，F19），供资质/信用/暂停三处数据范围复用
- `service/instrument/InstrumentQualificationServiceImpl.java`：getManagedDeviceIds 改为委托 ScopeSupport（去重复实现）
- `service/instrument/InstrumentCreditServiceImpl.java`：导出查询复用同 selectPage 条件（不分页）

### 1.3 后端（test）

| 文件 | 变更 |
| --- | --- |
| `src/test/resources/sql/create_tables.sql` | 追加 8 张 H2 表（instrument 6 表 + device/manager 2 表）；credit_account 带 `uk_account_tenant_user` 唯一键（并发首审用例依赖） |
| `src/test/resources/sql/clean.sql` | 追加 8 张表 DELETE |
| `src/test/java/.../service/instrument/Instrument02ServiceTest.java` | 新增，26 个用例（见 §4/§5） |

### 1.4 前端 `yudao-ui-admin-vue3`

**新增**
- `src/api/lab/instrument/qualification/index.ts`（InstrumentQualificationApi）
- `src/api/lab/instrument/credit/index.ts`（InstrumentCreditApi，导出用 request.download）
- `src/api/lab/instrument/suspend/index.ts`（InstrumentSuspendApi）
- `src/views/lab/instrument/my-qualification/index.vue`（我的使用资质：上半资质列表 + 下半申请记录、撤回、历史抽屉 el-timeline）
- `src/views/lab/instrument/my-credit/index.vue`（我的信用：账户卡分档配色、积分流水分页、我的暂停记录）
- `src/views/lab/instrument/qualification-audit/index.vue`（资质审核：申请审核/资质列表双 Tab，审核与撤销弹窗，历史抽屉）
- `src/views/lab/instrument/credit-manage/index.vue`（信用管理：账户/流水双 Tab，加扣分弹窗用户远程搜索，流水导出）
- `src/views/lab/instrument/suspend-manage/index.vue`（暂停管理：SINGLE/ALL、预设 1/3/7/14/30 天或自定义截止、解除弹窗）

**修改**
- `src/views/lab/instrument/device-detail/index.vue`：启用"申请资质"按钮（替换 INSTRUMENT-03 占位）；新增"我的使用资质"区块（资质/待审核可撤回/空态三态，按 `lab:instrument:qualification:query` 权限显示）
- `src/views/Home/Index.vue`：workbench 追加"我的使用资质""我的信用"卡片（借现有 filteredWorkbench 动态路由过滤，按菜单授权自动显示）
- `src/utils/dict.ts`：DICT_TYPE 补 `LAB_INSTRUMENT_CREDIT_REASON`、`LAB_INSTRUMENT_SUSPEND_SCOPE`

未引入任何新依赖；未修改无关模块。

---

## 2. SQL 文件与 PRECHECK 结论

### 2.1 schema SQL（6 表）

| 表 | 关键设计 |
| --- | --- |
| `lab_instrument_qualification_apply` | `uk_apply_tenant_no(tenant_id, apply_no)`；status 状态机 |
| `lab_instrument_qualification_apply_history` | 只增不改（无删除/修改接口），时间线快照 |
| `lab_instrument_qualification` | 无 DB 唯一键（撤销后可重申），单 ACTIVE 由应用层校验 + Redisson 锁 |
| `lab_instrument_credit_account` | `uk_account_tenant_user(tenant_id, user_id)` 唯一键（并发首审兜底）；score 无 CHECK、无上下限（G14）；初始 100 |
| `lab_instrument_credit_flow` | 不可变流水，只增；before/after 链 + 操作人快照 |
| `lab_instrument_suspend` | 历史全保留（解除/到期只置状态不删行）；preset_days/end_time 二选一 |

脚本自带：第 0 节执行前检查（同名表存在性、字符集 utf8mb4、字典预置核对）、第 2 节执行后验收（表/索引/约束/空表基线）、第 3 节停止条件。

### 2.2 menu SQL（14 条菜单，ID 13660~13673）

| ID | 名称 | 权限串 | 授权角色 |
| --- | --- | --- | --- |
| 13660/13661/13662 | 我的使用资质 + 资质查询/申请 | qualification:query / apply | 904 + 906 |
| 13663/13664 | 我的信用 + 信用查询 | credit:query | 904 + 906 |
| 13665/13666/13667 | 资质审核 + 审核/撤销 | qualification:audit / manage | 906 |
| 13668/13669/13670 | 信用管理 + 加扣分/导出 | credit:adjust / export | 906 |
| 13671/13672/13673 | 暂停管理 + 查询/创建解除 | suspend:query / manage | 906（13672 亦授 904，供我的信用页展示本人暂停） |

环境常量（2026-10-15 实测）：父目录"仪器管理"=13600、租户 162、套餐 114、角色 904/906、菜单已用最大 ID=13653、预留段 13660~13673 空闲。903/905/907 角色本批不授权（I3 待确认，见 11 号修订记录）。

### 2.3 PRECHECK 结论

- 6 张目标表在 labplatform 库中不存在（实测 cnt=0）
- 字典 `lab_instrument_credit_reason`（4 值）、`lab_instrument_suspend_scope`（2 值）已随 INSTRUMENT-01 预置，脚本不重复插入
- 菜单最大 ID=13653，预留段空闲，权限串无冲突
- **两个 SQL 均未执行（0 行 DDL/DML），等负责人授权**（执行步骤见 §8）

---

## 3. 接口、页面、权限和租户隔离测试结果

### 3.1 已验证（代码级 + H2 单测）

| 验证项 | 方式 | 结果 |
| --- | --- | --- |
| 申请防重（同设备 PENDING） | 单测 testApply_duplicatePending → 046 | PASS |
| 已持 ACTIVE 再申请拦截 | testApply_alreadyActive → 047 | PASS |
| 撤回权限（仅本人）/状态守卫 | testCancel_notApplicant(050) / testCancel_notPending(048) | PASS |
| 审核驳回意见必填 | testAudit_rejectOpinionRequired → 049 | PASS |
| 审核数据范围（服务端） | testAudit_permissionDenied → 051（非授权人被拒，不依赖前端隐藏） | PASS |
| 重复审核/并发双审防护 | testAudit_duplicateAudit → 052（条件更新 affectedRows=0） | PASS |
| 撤销资质：管理员限定 + 仅 ACTIVE | testRevoke_adminOnly_andConditionUpdate → 059/054 | PASS |
| 加扣分校验链 | delta=0→061、原因类型→063、用户无效→065、账户缺失→060 | PASS |
| 加扣分授权范围 | testAdjust_scope_byQualification → 064（负责人仅可调在授权设备持资质用户） | PASS |
| 管理查询 403 | testFlowPage_dataScope → 非管理员 getFlowPage/getCreditPage 抛 FORBIDDEN | PASS |
| 我的流水强制本人 | testFlowPage_dataScope：reqVO 携带他人 userId 不生效，仍返回本人数据 | PASS |
| biz 防重 | testAdjust_bizFlowDedup → 066 | PASS |
| 暂停创建校验链 | 范围非法→073、SINGLE 无设备→074、时长二选一/档位→075、非管理员 ALL/非授权 SINGLE→077 | PASS |
| 暂停重复覆盖 | testSuspendCreate_duplicateCoverage → 079（ALL 存在拒一切；SINGLE 同设备重复拒） | PASS |
| 解除防护 | testSuspendRelease_resumeOnlyUncovered（重复解除→071）；testSuspendRelease_permissionDenied（077） | PASS |
| 到期幂等 | testSuspendExpire_andIdempotent（重复扫描不再处理） | PASS |

### 3.2 待真实环境验证（SQL 部署后）

- 租户插件真实隔离（单测环境未加载租户拦截器，与 PlasmidStorageServiceImplTest 同一声明）：跨租户查询返回空、uk 按 (tenant_id, user_id) 独立
- Controller 层 `@PreAuthorize("@ss.hasPermission(...)")` 功能权限（单测不经过 Web 层）
- 页面渲染、按钮显隐（v-hasPermi）、首页卡片（动态路由过滤）、Excel 导出文件生成

---

## 4. 并发首审与积分流水一致性证据

### 4.1 并发首审（三层防护）

用例 `testAudit_concurrentFirstAudit_singleInit`：双线程（CountDownLatch 同时放行）分别审核同一用户两台设备的 PENDING 申请，H2 真实事务 + 真实 uk 唯一键 + FOR UPDATE 行锁（Redisson 锁 mock 为直通）。

运行日志证据（target/surefire-reports）：

```
WARN l.s.i.InstrumentQualificationServiceImpl : [initCreditAccountOnce] 并发初始化命中唯一键，跳过。userId=281
```

第二线程真实触发 `uk_account_tenant_user` 唯一键冲突，`DuplicateKeyException` 被捕获降级为"跳过"。断言结果：

- 账户表仅 1 行，score=100，initialized=true（不重复发放，F2/F3）
- 两台设备资质均 ACTIVE，申请单均 APPROVED

顺序双设备场景（`testAudit_firstApproveInitCredit100_andSecondDeviceNoDuplication`）另验证：第二台设备审核通过后账户仍为 100、账户仅 1 行、**不产生积分流水**（初始 100 分不落 credit_flow，流水仅记录人工/业务变动）。

### 4.2 积分并发行锁与流水一致性

- `adjustCredit` 事务内先 `selectByUserId` 后 `selectByIdForUpdate`（SELECT ... FOR UPDATE 行锁），余额更新与流水插入同一事务（`doAdjust`）
- 用例 `testAdjust_flowChainConsistency_andNegativeAllowed`：连续 +30 / -50 / -100 后：

| 流水 | changeType | score_change | before | after |
| --- | --- | --- | --- | --- |
| 1 | ADD | +30 | 100 | 130 |
| 2 | DEDUCT | -50 | 130 | 80 |
| 3 | DEDUCT | -100 | 80 | **-20（G14 负分允许）** |

- 链一致性：每条 after = 上一条 after；最终余额 = Σdelta = -20；changeType 与 delta 符号一致；操作人快照（operatorUserId=278）落流水
- 用例 `testAudit_accountExistsNotInitialized_noRegrant`：异常数据兜底（账户存在但 initialized=false）→ 补记标记、score 仍为 0，不补发 100 分（运行日志：`[initCreditAccountOnce] 账户存在但未标记初始化（异常数据），补记标记`）

---

## 5. 编译、TypeScript 与回归结果

| 项 | 命令/方式 | 结果 |
| --- | --- | --- |
| 后端编译 | `mvn -pl yudao-module-lab compile -q -o -DskipTests` | PASS |
| 后端单测（本任务） | `mvn -pl yudao-module-lab test -Dtest=Instrument02ServiceTest -o` | **26/26 PASS**（注：JDK 21 运行需 `-DargLine=-Dnet.bytebuddy.experimental=true`，JDK 8/11 环境无需） |
| 后端单测（存量回归） | `mvn -pl yudao-module-lab test -Dtest=PlasmidStorageServiceImplTest -o` | PASS（H2 DDL 追加不影响存量表） |
| 前端 TypeScript | vue-tsc 全量检查 | 13 个历史存量错误（announcement 1、fms 2、hrm 1、plasmid-audit 5、plasmid 4，与本任务前基线一致）；**instrument 模块 0 新增** |
| 数据安全 | — | 未清理 INSTRUMENT-01 测试数据、未重跑旧 SQL、未自动执行本任务 SQL、未修改无关模块 |

---

## 6. G12~G17 默认方案实施记录（逐项）

| 项 | 基线 | 本任务实现 | 验证 |
| --- | --- | --- | --- |
| G12 | 暂停联动资质 SUSPENDED；解除/到期仅恢复符合条件的资质 | 创建暂停时当时 ACTIVE 资质→SUSPENDED（updateSuspendIfActive，不碰 REVOKED/EXPIRED）；解除/到期仅恢复 `selectActiveCovering` 为空的 SUSPENDED 资质（resumeUncoveredQualifications） | testSuspendCreate_singleScopeLinkage、testSuspendRelease_resumeOnlyUncovered（SINGLE+ALL 并存：解除 SINGLE 后仍被 ALL 覆盖不恢复；解除 ALL 后恢复）、testSuspendExpire_andIdempotent |
| G13 | 允许已暂停用户资质审核通过，暂停继续生效 | 审核侧无暂停拦截；**实现选择（方案 A）**：暂停期间新审核通过的资质状态为 ACTIVE（暂停不追溯覆盖新资质），既有暂停记录保持生效（供 INSTRUMENT-03 预约侧拦截使用） | testAudit_g13_suspendDoesNotBlockAudit |
| G14 | 允许负分，无上下限 | score 无 CHECK 约束；仅校验 delta≠0；测试扣至 -20 | testAdjust_flowChainConsistency_andNegativeAllowed |
| G15 | 积分变化量由授权操作人填写 | delta 为必填入参，无预设违规分值；原因类型枚举校验（VIOLATION/OVERDUE/REWARD/MANUAL） | testAdjust_validation |
| G16 | 第一期仅设备级资质 | target_type 固定 "DEVICE"，无 PLATFORM 写入与判定 | 代码常量 TARGET_TYPE_DEVICE |
| G17 | 本期不实现维修奖励积分 | 未实现任何自动加分逻辑，credit_flow 仅人工登记产生（changeType 均来自人工 adjust） | 代码走查 |

另：初始 100 分为账户创建时字面值（不写流水、无"赠送流水"行）；低于 80 分无任何自动禁用/暂停逻辑（F10，代码无触发点）。

---

## 7. 已知缺陷与未决事项

> ⚠️ **后续更新（2026-10-15，TASK INSTRUMENT-02-DECISION-IMPLEMENT-01）**：下述第 3/7/8/9 项原为 PENDING 的 H1/H2/B2/B3 已由负责人**正式裁决并落地**（H1 第 3 项、H2 第 7 项、B2 第 8 项、B3 第 9 项）。**原 PENDING 文字保留为历史**；详见 [18-INSTRUMENT-02-裁决落地与部署准备报告.md](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md)。

1. **单测环境未加载租户拦截器**：tenant_id 隔离语义（跨租户不可见、uk 按租户独立）需真实环境验证。代码层面已具备：全部查询经 MyBatis 租户插件、AdminUserApi 受租户过滤、唯一键均含 tenant_id。
2. **Controller 层鉴权未经单测**：@PreAuthorize 权限串与菜单 SQL 的 9 个按钮一一对应（07 §4.2 冻结清单），需真实环境以 904/906 角色登录验证。
3. **暂停到期依赖 Job 注册 + 运行 profile**（~~待裁决~~ → **已裁决 2026-10-15：H1 B 方案，本期不启用自动到期**）：`instrumentSuspendExpireJob` 未在 `infra_job` 表注册、且目标 profile 为 `local`（`application-local.yaml` 排除 `QuartzAutoConfiguration` → `SchedulerManager(null)`）。**裁决结论：本期不注册、不启用该 Job，不作为验收条件**；`InstrumentSuspendExpireJob` 仅保留实现（已加注"本期不启用"）。暂停解除唯一途径为**授权管理员人工解除**；`end_time` 到达**不自动解除**（`selectActiveCovering` 已去除 `end_time` 条件）。详见 [18 号报告](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md) §1.1/§1.2。
4. **设备详情页管理员视角**：管理员打开设备详情时"待审核申请"区块过滤条件为 `applicantUserId === 当前用户`，即管理员在此区块只看到本人申请，待他人申请列表在"资质审核"页查看（设计如此，避免数据范围越权渲染）。
5. **applicant_identity_type / supervisor 快照列**：本期未回填（框架 AdminUserApi 未暴露字段），列已预留，前向兼容。
6. **H2 并发首审测试的稳定性**：并发时序受 H2 锁等待影响，唯一键兜底路径（日志可证）与"已存在跳过"路径均符合预期语义；该测试在 CI 中如偶发失败，可单独重跑确认。
7. **H2（G13→预约侧拦截依赖）**（~~待裁决~~ → **已裁决 2026-10-15：接受 G13 转移依赖**）：暂停期间新审核通过的资质为 ACTIVE（方案 A，已冻结，裁决维持）；该行为与"后续预约拦截"的一致性**依赖预约侧读取生效暂停记录**，属**明确接受的转移依赖**。**强制约束已写入** [03-预约规则与并发控制设计.md](file:///E:/lixin/dev/doc/03-仪器管理/03-预约规则与并发控制设计.md) §8.1.1（预约前必须校验生效暂停：ALL 拦截全部适用设备、SINGLE 拦截指定设备、服务端执行、不得仅依赖前端、并发与事务一致性、人工解除后重判定）。**预约侧联动验证待 INSTRUMENT-03**；本任务不开发预约模块。详见 [18 号报告](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md) §八。
8. **B2（资质审批主体）**（~~待裁决~~ → **已裁决 + 已落地 2026-10-15：允许设备负责人审批其负责设备**）：新建 [20261015_instrument_02_device_manager_role.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_device_manager_role.sql)（角色 908 `instrument_device_manager` + 8 条含完整祖先链授权，**未执行**）；后端 `auditApply` 由既有 `canManageDevice`（设备/所属平台生效负责人）∩ `@PreAuthorize`（功能权限）**双重校验**，拥有角色 ≠ 负责所有设备；906 lab_admin 管理审批权保留；904 无管理审批能力。详见 [18 号报告](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md) §三。
9. **B3（本人/管理查询权限串共用）**（~~待裁决~~ → **已裁决 + 已落地 2026-10-15：保留共用权限串不拆分**）：`qualification:query` / `credit:query` / `suspend:query` 在"管理端点"与"本人端点"共用**予以保留**；服务端强化数据范围——`getSuspendPage`/`getQualificationPage` 在无授权设备管理范围时**由"空分页"改为显式 403**（原 `getQualificationPage` 空集合时跳过过滤会退化为租户全量，属越权缺陷，已修正为恒过滤 + 403）；信用域 `requireManageAll` 已为 403。详见 [18 号报告](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md) §1.5。

---

## 8. 负责人需要执行的数据库部署步骤

按顺序执行；每步有预检，任一停止条件命中即停止并回报。**SQL 生成与 SQL 执行为独立授权边界**（本报告仅生成 SQL，未执行）：

1. **表结构**：执行 `ruoyi-vue-pro/sql/lab/20261015_instrument_02_schema.sql`
   - 先人工执行第 0 节 **4 组**只读检查（0.1 六表不存在、0.2 utf8mb4、0.3 字典预置、**0.4 六表列级结构预检**），全部符合预期再执行第 1 节 DDL，最后第 2 节验收（§2.4 空表基线须在 DDL 后执行）
   - **0.4（FIX-01 新增，B4）**：区分"首次部署 / 已存在且结构一致 / 已存在但结构不一致"三种情形；任一不一致即命中 §3 停止条件 4，**禁止 DROP / 重建 / 自动 ALTER**，回报负责人
2. **菜单与授权**：执行 `ruoyi-vue-pro/sql/lab/20261015_instrument_02_menu.sql`
   - 先执行第 0 节检查（ID 段空闲、角色/租户/套餐存在），再按节执行；可包在显式事务中
   - 本脚本对 904/906 的授权保持原样（**未改动**）
3. **设备负责人角色与授权（新增，2026-10-15 裁决 B2）**：执行 `ruoyi-vue-pro/sql/lab/20261015_instrument_02_device_manager_role.sql`
   - **必须在第 2 步（menu SQL）之后执行**（本脚本授予的 13660/13661/13665/13666 由 menu SQL 创建）
   - 先执行第 0 节只读预检（0.1 code 冲突 / 0.2 name 冲突 / 0.3 id 908 与 AUTO_INCREMENT / 0.4 祖先链 / 0.5 目标菜单 6 行 / 0.6 权限串 / 0.7 租户 162 / 0.8 现状留证），全部符合预期再执行第 1 节（角色 1 行）+ 第 2 节（授权 ≤8 行），最后第 3 节验收
   - 角色 ID 固定 908；**本脚本不覆盖已有角色、不删除旧授权、不批量重建角色关系**；**用户角色分配**须由负责人在【系统管理 → 用户管理】人工完成
4. ~~**注册到期 Job**~~ **【已取消，2026-10-15 裁决 H1】**：本期不注册 `instrumentSuspendExpireJob`、不启用暂停自动到期，Job 不作为验收条件（详情见 §7 第 3 项）
5. **重启后端服务**，前端用户重新登录以拉取新菜单
6. 数据不迁移：6 张新表均为空表上线，INSTRUMENT-01 的 10 条测试数据（platform=2/device=2/manager=3/notice=2/room=1）不受影响，**不得清理**

## 9. 真实环境验收步骤（SQL 部署后）

> 前置：以下各项**必须在真实环境**执行——**真实 Redis**（非 mock 锁）、**真实租户拦截器**（非 H2 未加载租户插件）、**Web Controller**（真实 HTTP 鉴权）；静态检查 / 单元测试 / 模拟 Redis 结果**不得**记为真实环境 PASS。

1. 904 普通用户登录：首页可见"我的使用资质/我的信用"两卡片，菜单仅此两页；设备详情可见"申请资质"；不可见三个管理页
2. 申请→906 审核通过→普通用户获得资质、信用账户出现 100 分；第二台设备再通过→账户仍 100（须在真实 Redis 下观察并发/幂等）
3. 906 加扣分（正/负 delta）→ 流水 before/after 链正确；导出 Excel 生成；**补充负向**：904 调 `flow/export-excel` 应 403
4. 906 创建 SINGLE/ALL 暂停→用户资质联动 SUSPENDED；**授权管理员人工解除**→符合条件资质恢复
   - **本期不适用自动到期（H1 B 方案，2026-10-15 裁决）**：`end_time` 到达**不自动解除**（无 EXPIRED 自动流转、无 Job 调度）。验收时**不将"到期自动 EXPIRED"作为观测项**；若需验证，仅验证"预设结束时间到达后暂停仍为 ACTIVE、仍限制使用"，直到人工解除才置 RELEASED
   - **补充观测点（G13）**：暂停生效期间让另一设备审核通过，观察新资质为 ACTIVE 且既有暂停仍 ACTIVE（该行为属方案 A 冻结，其被拦截依赖 INSTRUMENT-03 预约侧）
5. 负向：904 直接调管理接口（adjust/createSuspend 等）应得 403/权限错误；跨租户用户查询不可见
6. INSTRUMENT-01 回归：设备/平台/房间/负责人/须知页面功能正常，10 条测试数据完好

---

*报告结束。本报告未将任何未执行的数据库部署或真实联调标记为 PASS；最终结论 CONDITIONAL PASS，部署完成并通过 §9 验收后可转 PASS。修订说明（FIX-01，2026-10-15）：§7 增记 H1/H2/B2/B3 未决项；§8 增列 schema §0.4 列级预检门槛（B4）与 Job 注册的 H1 前置；§9 增注真实环境三件套与两处补充观测点。详见 [16-INSTRUMENT-02-部署前集中复核报告.md](file:///E:/lixin/dev/doc/03-仪器管理/16-INSTRUMENT-02-部署前集中复核报告.md) 与 [17-INSTRUMENT-02-部署前整改报告.md](file:///E:/lixin/dev/doc/03-仪器管理/17-INSTRUMENT-02-部署前整改报告.md)。*

*后续更新（TASK INSTRUMENT-02-DECISION-IMPLEMENT-01，2026-10-15）：负责人对 H1/H2/B2/B3 四项作出正式裁决并落地——§7 上述四项标记由 ~~PENDING~~ 更新为「已裁决 + 已落地」（原 PENDING 文字保留为历史）；§8 部署步骤新增「设备负责人角色与授权」（第 3 步）、原「注册到期 Job」步骤标注【已取消】并重编号；§9 第 4 项验收由「到期由 Job 自动 EXPIRED」改为「授权管理员人工解除」语义（本期不适用自动到期）。落地证据、只读预检与实际返回、逐文件修改清单及 PASS/HOLD 结论见 [18-INSTRUMENT-02-裁决落地与部署准备报告.md](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md)。本次更新未执行任何 DDL/DML，租户测试数据与已冻结菜单保留原样。*
