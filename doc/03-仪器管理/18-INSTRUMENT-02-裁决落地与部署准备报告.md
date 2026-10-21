# 18-INSTRUMENT-02-裁决落地与部署准备报告

- 任务：TASK INSTRUMENT-02-DECISION-IMPLEMENT-01（依据负责人 2026-10-15 正式裁决，落地 H1/H2/B2/B3）
- 日期：2026-10-15
- 依据：[15-INSTRUMENT-02-开发交付报告.md](file:///E:/lixin/dev/doc/03-仪器管理/15-INSTRUMENT-02-开发交付报告.md)、[16-INSTRUMENT-02-部署前集中复核报告.md](file:///E:/lixin/dev/doc/03-仪器管理/16-INSTRUMENT-02-部署前集中复核报告.md)、[17-INSTRUMENT-02-部署前整改报告.md](file:///E:/lixin/dev/doc/03-仪器管理/17-INSTRUMENT-02-部署前整改报告.md)
- 任务性质：**允许代码修改、SQL 文件生成与只读验证**；**未执行任何数据库写入或 DDL**（仅执行只读 `SELECT`）
- 前置保留：M1、M2、B4（FIX-01 已完成的修复）**全部保留，未回退**

---

## 〇、结论摘要（先说结论）

| 维度 | 结论 |
| --- | --- |
| 静态验证结论 | **CODE/PRECHECK PASS** |
| 部署状态 | **NOT DEPLOYED / 待授权**（数据库尚未执行、角色尚未真实创建、HTTP 权限与并发尚未实测） |
| H1（本期不启用自动到期） | **已落地**：暂停"人工解除"语义已贯穿 Mapper/Service/Job/枚举/前端文案，无自相矛盾到期判断 |
| H2（接受 G13 转移依赖） | **已落地**：强制约束已写入 [03-预约规则与并发控制设计.md](file:///E:/lixin/dev/doc/03-仪器管理/03-预约规则与并发控制设计.md) §8.1.1；预约侧联动验证待 INSTRUMENT-03 |
| B2（设备负责人审批权限） | **已落地**：新增角色 `instrument_device_manager`（脚本固定 id=908）与 8 条含完整祖先链的菜单授权 SQL；后端设备范围审批由既有 `canManageDevice` 双重校验承担（本次仅补注释与边界说明） |
| B3（保留共用权限串，强化服务端范围） | **已落地**：共用权限串**保留未拆**；两处服务端越权路径已修正为显式 403（`getSuspendPage` 空分页缺陷、`getQualificationPage` 租户全量越权缺陷） |
| 数据库是否写入 / DDL | **否**。本任务仅生成/修订 SQL 文件与执行只读 `SELECT`，**未执行任何 CREATE/ALTER/DROP/INSERT/UPDATE/DELETE** |
| 数据库是否执行 SQL 脚本 | **否**。三个 SQL 脚本（schema / menu / device_manager_role）均**未执行** |
| 是否注册/启动定时任务 | **否** |
| 是否清理 INSTRUMENT-01 的 10 条测试数据 | **否**（未触碰） |
| 是否修改质粒模块 | **否** |

> **本报告不得解读为 DEPLOY PASS。** 数据库迁移、角色真实创建、菜单授权、HTTP 权限校验、真实 Redis 并发一致性均**尚未在真实环境发生**，部署状态一律为 **NOT DEPLOYED / 待授权**。

---

## 一、四项裁决的最终状态

### 1.1 H1：本期不启用自动到期（采用 B 方案）

| 裁决要求 | 落地动作 | 证据 | 状态 |
| --- | --- | --- | --- |
| ① 本期不注册、不启用暂停自动到期 Job | 未向 `infra_job` 注册任何任务；`InstrumentSuspendExpireJob` 仅保留实现并加注"本期不启用" | [InstrumentSuspendExpireJob.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/job/InstrumentSuspendExpireJob.java) javadoc【本期不启用 —— H1 裁决 2026-10-15】；未执行任何 INSERT | ✅ |
| ② 不调整 Quartz profile、不启动 Scheduler | 未修改 `application-local.yaml` 的 `QuartzAutoConfiguration` 排除项；未切换 profile、未重启服务 | 配置文件零改动 | ✅ |
| ③ 保留授权管理员人工解除暂停能力 | `releaseSuspend(SuspendReleaseReqVO)` 路径完整保留，前端"解除"按钮与弹窗保留 | [InstrumentSuspendServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentSuspendServiceImpl.java)；[suspend-manage/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/suspend-manage/index.vue) | ✅ |
| ④ 暂停生效判定、人工解除接口、前端状态文案与提示一致 | Mapper 生效判定 = `status=ACTIVE` 且 `start_time<=now`（**去 `end_time`**）；Service javadoc 同步；前端文案统一为"计划结束时间""实际解除时间" | 见下 1.2 冲突修正 | ✅ |
| ⑤ 保守规则：暂停在人工解除前持续限制使用，预设结束时间到达不代表自动解除 | `selectActiveCovering` / `selectActiveListByUser` / `selectActiveSingleByDevice` 均**仅以 status=ACTIVE 判定**，不含 `end_time` 条件 | [InstrumentSuspendMapper.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/mysql/instrument/InstrumentSuspendMapper.java#L48-L56) | ✅ |
| ⑥ **冲突报告**：若代码按 `end_time` 自动判定暂停失效，必须报告并修正 | **发现真实冲突**（见 1.2），已修正 | 见 1.2 | ✅（已修正） |
| ⑦ 保留起止时间及历史，区分"计划结束时间"与"实际解除时间" | 数据库保留 `start_time`/`end_time`/`release_time` 三列，历史不删；前端列名区分二者 | suspend-manage / my-credit 文案 | ✅ |
| ⑧ 不删除既有 Job 实现，仅明确本期不启用、不作为验收条件 | Job 与 `expireSuspends` / `selectActiveExpired` / `updateExpireIfActive` 全部保留实现，加注"本期不启用" | 同 ① | ✅ |

#### 1.2 H1 冲突报告与修正（关键）

**冲突确证**：`InstrumentSuspendMapper.selectActiveCovering(Long userId, Long deviceId)` 原实现为
`.le(startTime, now).gt(endTime, now)`，即**以 `end_time` 自动判定暂停失效**。这与 H1 裁决 ⑤
"预设结束时间到达不代表自动解除"**直接矛盾**——到达 `end_time` 后该方法会返回空集，导致 G12 的
"资质恢复"判定（`resumeUncoveredQualifications` 以 `selectActiveCovering` 是否为空为准）在**未人工解除**时
就可能把 SUSPENDED 资质恢复，属于"隐形自动解除"。

**修正内容**（[InstrumentSuspendMapper.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/mysql/instrument/InstrumentSuspendMapper.java#L40-L56)）：

```java
default List<InstrumentSuspendDO> selectActiveCovering(Long userId, Long deviceId) {
    return selectList(new LambdaQueryWrapperX<InstrumentSuspendDO>()
            .eq(InstrumentSuspendDO::getUserId, userId)
            .eq(InstrumentSuspendDO::getStatus, SuspendStatusEnum.ACTIVE.getStatus())
            .le(InstrumentSuspendDO::getStartTime, LocalDateTime.now())
            .and(w -> w.eq(InstrumentSuspendDO::getScopeType, "ALL")
                    .or(w2 -> w2.eq(InstrumentSuspendDO::getScopeType, "SINGLE")
                            .eq(InstrumentSuspendDO::getDeviceId, deviceId))));
}
```

**修正影响面核查**（`selectActiveCovering` 的全部调用点）：

| 调用点 | 语义变化 | 结论 |
| --- | --- | --- |
| `InstrumentSuspendServiceImpl.createSuspend`（重复覆盖校验） | 原本已用 `selectActiveListByUser`/`selectActiveSingleByDevice`（无 end_time 条件），不受影响 | 无影响（语义一致） |
| `InstrumentSuspendServiceImpl.releaseSuspend` / `expireSuspends`（`resumeUncoveredQualifications`） | 由"end_time 到期即视为无覆盖 → 可能被恢复"改为"仅人工解除/到期未撤销的 ACTIVE 才视为覆盖" | **符合 H1 保守规则**；本期 Job 不启用，`end_time` 不再触发任何自动恢复 |
| 其他 | 无 | — |

> 语义收敛后，`selectActiveCovering` 与 `selectActiveListByUser`、`selectActiveSingleByDevice` 三者的
> "ACTIVE 即生效"判定**完全一致**，消除了此前"同一概念三种判定口径"的自相矛盾。

**保留但本期不启用**（`InstrumentSuspendMapper` 内加注 H1）：
`selectActiveExpired(now)`（`.le(endTime, now)`）与 `updateExpireIfActive`（ACTIVE→EXPIRED 条件更新）
仅服务于暂停自动到期 Job；**本期 Job 不注册、不调度**，二者保留实现但**不作为本期验收条件**。
`end_time` 列语义被明确限定为"**计划结束时间**"，不代表自动解除。

**前端文案一致性修正**：

| 文件 | 修正 |
| --- | --- |
| [suspend-manage/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/suspend-manage/index.vue) | 列 `截止时间`→`计划结束时间`、`解除/到期`→`实际解除时间`；创建弹窗 warning alert 追加"到达『计划结束时间』不会自动解除，须由授权管理员在本页人工『解除』。"；`自定义截止`→`自定义计划结束`；校验 message 同步 |
| [my-credit/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/my-credit/index.vue) | 列 `截止时间`→`计划结束时间`、`解除/到期`→`实际解除时间`；"我的暂停记录"标题下新增提示"暂停须由授权管理员人工解除；到达『计划结束时间』不会自动解除。" |
| [SuspendStatusEnum.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/enums/instrument/SuspendStatusEnum.java) | `RELEASED` 显示名 `已提前解除`→`已解除`（`getName()` 全项目未被引用，无输出影响）；javadoc 增 H1 说明 |

### 1.3 H2：接受 G13 转移依赖

| 裁决要求 | 落地动作 | 证据 | 状态 |
| --- | --- | --- | --- |
| ① 保持现有 G13：暂停期间仍允许新的资质申请审批通过 | 未改 `auditApply` 的审核逻辑，审核侧无暂停拦截 | [InstrumentQualificationServiceImpl.java#L151-L219](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentQualificationServiceImpl.java#L151-L219) 未改 | ✅ |
| ② 不因存在暂停记录而强制把新审批资质改为 REJECTED | 未引入任何"存在暂停即拒绝/改状态"逻辑 | 同上 | ✅ |
| ③ 在 INSTRUMENT-03 需求/交接文档中新增**强制约束**（7 条） | 已写入 [03-预约规则与并发控制设计.md](file:///E:/lixin/dev/doc/03-仪器管理/03-预约规则与并发控制设计.md) **新增 §8.1.1** | 见第八节 | ✅ |
| ④ 本任务不开发预约模块 | 未新增任何预约（reservation）代码；lab 模块无预约实现 | 未新增文件 | ✅ |
| ⑤ 报告中标明：H2 裁决已完成、预约侧联动验证仍待 INSTRUMENT-03 | 见本报告 §八、§九 | — | ✅ |

### 1.4 B2：设备负责人也需要审批权限

| 裁决要求 | 落地动作 | 状态 |
| --- | --- | --- |
| ① 增加专用角色 `instrument_device_manager`（先查冲突） | 只读核查确认 code/name 无冲突；脚本固定 `id=908`（实测 MAX(id)=907、AUTO_INCREMENT=908） | ✅ |
| ② 角色 ID 不硬编码猜测，只读 SQL 确认可用 ID，含冲突检查与停止条件 | role 脚本 §0.1~§0.8 为只读预检，含 code 冲突、name 冲突、id 占用、AUTO_INCREMENT 期望与【停止】说明 | ✅ |
| ③ 仅授予必要的仪器查询、申请审核入口及审核操作权限 | 授权 8 条：`13478,13600`（祖先）+ `13620,13621`（仪器查询 `device:query`）+ `13660,13661`（资质查询）+ `13665,13666`（审核页+`qualification:audit`）；**不授任何写/信用/暂停权限** | ✅ |
| ④ 设备负责人只能查看、审批其**实际负责设备**的申请 | 后端 `canManageDevice(loginUserId, targetId)` 在 Service 层强制（设备/平台生效负责人） | ✅ |
| ⑤ 906 本草基因管理员继续保留管理审批权限 | 未改 menu SQL §3.1（906 授 14 条）；role 脚本不触碰 906 | ✅ |
| ⑥ 普通用户 904 不得因共享查询权限获得管理审批能力 | 904 仍无 `qualification:audit`；且 `getQualificationPage` 无管理范围时显式 403（见 B3） | ✅ |
| ⑦ 不能仅依赖 `@PreAuthorize`/前端按钮隐藏，Service 必须检查负责人关系、租户、申请归属、申请状态 | `auditApply`：`@PreAuthorize`（功能权限）∩ `canManageDevice`（业务关系）+ 行锁 + `updateAuditResult` affectedRows 状态守卫 | ✅ |
| ⑧ 必须检查负责人解除、设备停用、跨租户、并发重复审批等边界 | `selectActiveList` 仅取 ACTIVE（解除即失效）；`deviceMapper` 受租户插件过滤（跨租户 → null → 拒绝）；行锁 + 条件更新 affectedRows=0 → `STATUS_CHANGED` | ✅ |
| ⑨ 角色授权与设备负责人业务关系必须**同时**满足 | 同 ⑦；角色仅提供"功能权限入口"，`canManageDevice` 提供"设备范围"，缺一不可 | ✅ |
| ⑩ 若负责人模型无法可靠表达审批设备范围，不得擅自扩大权限，应提交冲突与最小改造方案 | **核查结论**：现有模型（`lab_instrument_manager` DEVICE/PLATFORM + `InstrumentScopeSupport.canManageDevice`）**可可靠表达**设备范围，无架构阻塞，故直接实施，无冲突上报 | ✅ |

### 1.5 B3：保留共用权限串，强化服务端范围

| 裁决要求 | 落地动作 | 状态 |
| --- | --- | --- |
| ① 不为本人查询和管理查询额外拆分权限字符串 | **未拆分**任何权限串（`qualification:query`/`credit:query`/`suspend:query` 保持共用）；未改 menu SQL 权限串定义 | ✅ |
| ② 检查资质、信用、暂停三领域 Controller 与 Service | 三 Controller 权限串与 Service 数据范围逐项核查（见阶段 C） | ✅ |
| ③ 本人查询只能返回本人数据 | `getMyCredit`/`getMyFlowPage`/`getMySuspends`/`getMyQualifications` 强制 `loginUserId` | ✅ |
| ④ 管理查询必须具备相应管理权限，并受租户和业务范围约束 | 管理端点 `@PreAuthorize` + Service `requireManageAll` / `canManageDevice` / `getManagedDeviceIds` | ✅ |
| ⑤ 设备负责人不得通过共用 `query` 权限获取无关设备申请、其他用户信用明细或暂停管理数据 | 资质/暂停列表恒按 `managedDeviceIds` 过滤；信用域 `requireManageAll` 直接 403 | ✅ |
| ⑥ 不得通过伪造 `userId`/`deviceId`/分页/导出绕过数据范围 | 资质/申请列表 `and(本人 OR 授权设备)` 恒成立；导出复用 `requireManageAll`；`getMyFlowPage` 忽略传入 userId | ✅ |
| ⑦ 优先通过服务端操作级授权与数据范围解决，不擅改冻结权限串设计 | 未改权限串；改用显式 403 与恒过滤 | ✅ |
| ⑧ 对越权采用项目既有规范明确拒绝，不得以空分页替代未授权拒绝 | `getSuspendPage` 空分页 → 显式 `FORBIDDEN`；`getQualificationPage` 全量越权 → 显式 `FORBIDDEN` | ✅ |
| ⑨ 保留现有合法的本人查询能力 | 本人路径（`/my`、`getMySuspends`、`getApplyPage` 本人分支）全部保留 | ✅ |

---

## 二、逐文件修改清单

### 2.1 后端 Java（yudao-module-lab）

| # | 文件 | 修改类型 | 修改要点 |
| --- | --- | --- | --- |
| 1 | [InstrumentSuspendMapper.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/mysql/instrument/InstrumentSuspendMapper.java) | 逻辑修正（**H1 核心**） | `selectActiveCovering` 移除 `.gt(endTime, now)`；`selectActiveExpired`/`updateExpireIfActive` 加注"本期不启用" |
| 2 | [InstrumentSuspendServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentSuspendServiceImpl.java) | 说明 + **B3 修正** | 类 javadoc 加 H1 段；`expireSuspends` 加注"本期不启用"；`getSuspendPage` 非管理范围由"空分页"改为显式 `FORBIDDEN` |
| 3 | [InstrumentSuspendExpireJob.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/job/InstrumentSuspendExpireJob.java) | 说明（H1） | javadoc 增补"本期不启用"三点；`execute` 逻辑未改（保留实现） |
| 4 | [SuspendStatusEnum.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/enums/instrument/SuspendStatusEnum.java) | 文案/说明（H1） | `RELEASED` 显示名改"已解除"；javadoc 加 H1 说明 |
| 5 | [InstrumentQualificationServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentQualificationServiceImpl.java) | 说明（B2）+ **B3 修正** | `auditApply` 第 3 步注释扩为 B2 双重校验说明；`getQualificationPage` 非管理范围由"租户全量"改为显式 `FORBIDDEN` + 恒过滤 |

> **未改动**：`InstrumentCreditServiceImpl`（`requireManageAll` 已为 B3 正例，无需修改）、`InstrumentScopeSupport`、`InstrumentSuspendController`、`InstrumentQualificationController`、`ErrorCodeConstants`、全部 DO/Mapper（除 #1）/VO。

### 2.2 前端（yudao-ui-admin-vue3）

| # | 文件 | 修改类型 | 修改要点（均纯文案） |
| --- | --- | --- | --- |
| 6 | [suspend-manage/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/suspend-manage/index.vue) | 文案（H1） | 见 §1.2；新增"到达计划结束时间不会自动解除"提示 |
| 7 | [my-credit/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/my-credit/index.vue) | 文案（H1） | 见 §1.2；"我的暂停记录"标题下新增人工解除提示 |

### 2.3 SQL

| # | 文件 | 修改类型 | 修改要点 |
| --- | --- | --- | --- |
| 8 | [20261015_instrument_02_device_manager_role.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_device_manager_role.sql) | **新建**（B2） | 角色 `instrument_device_manager`（id=908）+ 8 条含完整祖先链授权；预检/写入/验收分段；未执行 |
| 9 | [20261015_instrument_02_menu.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_menu.sql) | 注释修订（B2 兼容） | **仅头部注释**第 6 项执行顺序追加 role 脚本与 B2 说明；§0~§6 可执行 SQL **零改动** |

### 2.4 文档

| # | 文件 | 修改类型 | 修改要点 |
| --- | --- | --- | --- |
| 10 | [03-预约规则与并发控制设计.md](file:///E:/lixin/dev/doc/03-仪器管理/03-预约规则与并发控制设计.md) | 新增章节（H2） | **新增 §8.1.1 预约创建前的暂停校验（强制约束）**，7 条 MUST + 生效语义 + 跨模块依赖 |
| 11 | [15-INSTRUMENT-02-开发交付报告.md](file:///E:/lixin/dev/doc/03-仪器管理/15-INSTRUMENT-02-开发交付报告.md) | 修订（裁决落地） | §7 未决项更新为已裁决；§8 增 role 脚本执行顺序；末尾增修订说明（保留下方历史 PENDING 记录） |
| 12 | [16-INSTRUMENT-02-部署前集中复核报告.md](file:///E:/lixin/dev/doc/03-仪器管理/16-INSTRUMENT-02-部署前集中复核报告.md) | 修订（裁决落地） | §8.4 决策记录表由"PENDING"更新为"已裁决 + 落地证据"；§一/§8.1/§八 结论同步；保留历史 PENDING 文字 |
| 13 | [17-INSTRUMENT-02-部署前整改报告.md](file:///E:/lixin/dev/doc/03-仪器管理/17-INSTRUMENT-02-部署前整改报告.md) | 修订（裁决落地） | §二 裁决状态表由"PENDING"更新为"已裁决"；§四/§五 剩余 HOLD 同步；保留历史 PENDING 记录 |
| 14 | [18-INSTRUMENT-02-裁决落地与部署准备报告.md](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md) | **本报告（新建）** | — |

> **未改动**：`20261015_instrument_02_schema.sql`（除 FIX-01 已含的 §0.4 外未再改）、质粒模块、其他无关模块。

---

## 三、设备负责人角色设计、权限矩阵与设备范围判定依据

### 3.1 角色设计

| 项 | 值 | 依据 |
| --- | --- | --- |
| 角色 ID | **908** | 2026-10-15 只读实测 `system_role` MAX(id)=907、AUTO_INCREMENT=908；role 脚本 §0.3 期望 `id_908_used=0 且 next_auto_increment=908`，不符即【停止】 |
| code | `instrument_device_manager` | 建议标识；§0.1 实测冲突 0 行 |
| name | `仪器设备负责人` | §0.2 实测无同名角色 |
| sort | 35 | 位于 lab_admin(30) 与 registration_approver(40) 之间 |
| data_scope | 1 | 对无部门列的仪器业务表无影响；设备范围由 Service 业务关系判定，不依赖部门数据权限 |
| status / type | 0（启用）/ 2（自定义） | 与既有 906（type=2）一致 |
| tenant_id | **162**（显式） | 避免依赖列默认值 0；§0.7 实测租户 162 存在（status=0, package_id=114） |

### 3.2 权限矩阵（该角色获得的菜单/权限串）

| menu_id | 名称 | type | permission | 用途 | 授予理由 |
| --- | --- | --- | --- | --- | --- |
| 13478 | 实验室管理 | 1 | — | **祖先目录** | 框架 `filterDisableMenus` 要求父链齐全（见 3.3） |
| 13600 | 仪器管理 | 1 | — | **祖先目录** | 同上 |
| 13620 | 仪器设备 | 2 | — | **祖先页面** | 使 13621 权限串可达 |
| 13621 | 查询 | 3 | `lab:instrument:device:query` | 审核页设备下拉 | 设备查询（只读） |
| 13660 | 我的使用资质 | 2 | — | **祖先页面** | 使 13661 权限串可达 |
| 13661 | 资质查询 | 3 | `lab:instrument:qualification:query` | 资质/申请列表查询 | 审核前置查询 |
| 13665 | 资质审核 | 2 | — | **审核页面入口** | 管理审核页 |
| 13666 | 资质审核 | 3 | `lab:instrument:qualification:audit` | **审核操作** | 核心审批权限 |

**明确不授予**（防越权，role 脚本 §3.4 回归核对预期 0 行）：
`lab:instrument:device:create/update/delete/manage`、`lab:instrument:qualification:apply`、
`lab:instrument:qualification:manage`（撤销=管理员动作）、`lab:instrument:credit:*`（3 个）、
`lab:instrument:suspend:*`（2 个）。**不授予 13663/13664/13668~13673 任何页面/按钮。**

### 3.3 设备范围判定依据（为何"拥有角色 ≠ 负责所有设备"）

- **功能权限**（`@PreAuthorize("@ss.hasPermission('lab:instrument:qualification:audit')")`）由**角色授权**提供，
  即 role 908 的 13666 授权。
- **数据范围**（业务关系）由 [InstrumentScopeSupport](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentScopeSupport.java) 提供：
  - `canManageAll(userId)` = 拥有 `super_admin` / `lab_admin` 角色；
  - `canManageDevice(userId, deviceId)` = `canManageAll` ∨ 该设备 `DEVICE` ACTIVE 负责人 ∨ 该设备所属平台 `PLATFORM` ACTIVE 负责人；
  - `getManagedDeviceIds(userId)` = DEVICE 直接负责设备 + PLATFORM 平台下全部设备。
- `auditApply` 同时校验二者：**功能权限通过 ≠ 可审批**；只有 `canManageDevice(loginUserId, apply.getTargetId())=true` 才放行，
  因此设备负责人**仅能审批自己负责设备**的申请。

**框架约束（决定授权集合采用"完整祖先链"）**：
yudao 前端权限集合来自 `AuthController#getPermissionInfo` → `MenuServiceImpl#filterDisableMenus`
（[MenuServiceImpl.java#L158-L183](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/permission/MenuServiceImpl.java#L158-L183)，第 178 行 `parent == null` 即判定禁用并整体丢弃，按钮亦适用）；
后端 `@PreAuthorize` 走 `PermissionServiceImpl#hasAnyPermission` 直查 `system_role_menu`，**不受此限制**。
若只授按钮（13666）而不授其父链（13665→13600→13478），会出现**前后端不一致**（后端放行、前端 `v-hasPermi` 拿不到串）。
故 role 脚本按完整祖先链授权 8 条。

### 3.4 B2 现状核查证据（阶段 A）

| 核查项 | 实测结果 |
| --- | --- |
| `system_role` 结构 | `id bigint AUTO_INCREMENT PK`、`name varchar(30)`、`code varchar(100)`、`sort int`、`data_scope tinyint DEFAULT 1`、`status tinyint`、`type tinyint`、`tenant_id bigint DEFAULT 0` + 审计列；MAX(id)=907 |
| `system_role_menu` 结构 | 仅 `PRIMARY(id)` + `idx_role_id(role_id)`，**无 (role_id,menu_id) 唯一索引**（防重靠 `NOT EXISTS`） |
| 既有角色授权 | 903 tenant_admin(327 菜单) / 904 普通用户(21) / 905 lab_keeper(48) / 906 lab_admin(99) / 907 registration_approver(4)；904 含 13621，906 含 13620/13621 |
| 角色名/code 冲突 | **无**任何角色名或 code 含"设备负责人"/"instrument"冲突 |
| 仪器负责人模型 | `lab_instrument_manager`（DEVICE/PLATFORM scope，`selectActiveList` 仅 ACTIVE） |
| `InstrumentScopeSupport` | 见 3.3 |
| 资质审批链 | `InstrumentQualificationController#/audit`（`qualification:audit`）→ `InstrumentQualificationServiceImpl#auditApply` |
| 现有 13660~13673 菜单与权限串 | 由 menu SQL 创建（**尚未执行**）；只读实测仅 13620/13621 已存在（INSTRUMENT-01） |
| 租户 162 / 套餐 114 | 租户 162 存在（status=0, package_id=114）；套餐 114 存在 |

---

## 四、新增或修改的 SQL 文件及执行顺序

### 4.1 文件清单

| 文件 | 性质 | 是否执行 |
| --- | --- | --- |
| [20261015_instrument_02_schema.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_schema.sql) | 6 表 DDL + 预检 + 验收（含 FIX-01 §0.4） | **未执行** |
| [20261015_instrument_02_menu.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_menu.sql) | 菜单 13660~13673 + 套餐 114 + 904/906 授权 | **未执行** |
| [20261015_instrument_02_device_manager_role.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_device_manager_role.sql) | 角色 908 + 8 条授权（**本任务新建**） | **未执行** |

### 4.2 强制执行顺序

```text
(a) 20261015_instrument_02_schema.sql        —— 建 6 张业务表
(b) 20261015_instrument_02_menu.sql          —— 建 INSTRUMENT-02 菜单段 13660~13673（含 13660/13661/13665/13666）
(c) 20261015_instrument_02_device_manager_role.sql
                                             —— 角色 908 与授权（依赖 (b) 创建的菜单）
```

> **为何 (c) 必须在 (b) 之后**：role 脚本授予的 13660/13661/13665/13666 由 (b) 创建，
> 必须已存在方可授权（role 脚本 §0.5 为人工前置门槛）。**不得颠倒顺序，也不得整文件一次性执行做只读验证**。

### 4.3 SQL 分段结构（预检/写入/验收严格分离）

三个脚本**统一**采用同一分段结构，**禁止整文件执行**：

| 段 | 性质 | 说明 |
| --- | --- | --- |
| §0 | **只读预检** | 全部 `SELECT`；含期望值与【停止】条件；**人工执行门槛，无自动中止能力** |
| §1~§3 | **写入** | 幂等（`NOT EXISTS` 守卫）；建议包在显式事务内 |
| §4（role/menu）/§2（schema） | **只读验收** | 全部 `SELECT`；全符合才 `COMMIT`，任一不符 `ROLLBACK` |
| 尾段 | 事务与回滚说明 | 含 `mysqldump` 兜底、utf8mb4 要求、撤销说明、"Trae 未执行"声明 |

### 4.4 幂等与防覆盖保证

- role 脚本**不覆盖已有角色、不删除旧授权、不批量重建角色关系**：
  第 1 节 INSERT 带 `NOT EXISTS(id=908)` + `NOT EXISTS(code=...)`；
  第 2 节授权带角色存在启用 + 菜单存在启用 + `NOT EXISTS(role_id,menu_id)` 三重守卫；
  仅作用于 `role_id=908 / tenant_id=162`，**不触碰 904/906 的任何授权**。
- menu SQL §3.1/§3.2 对 904/906 的授权**保持原样**（本次仅改头部注释）。

---

## 五、全部只读预检 SQL 与实际返回结果

> 以下预检**均已实际执行**（只读 `SELECT`）。**未执行**任何写入段、任何 DDL。
> 连接：`MySQL 8.0.12 / labplatform / --default-character-set=utf8mb4`。

### 5.1 role 脚本 §0 预检（实际返回）

| 编号 | 查询要点 | 期望 | **实际返回** | 判定 |
| --- | --- | --- | --- | --- |
| 0.1 | `code='instrument_device_manager'` 冲突计数 | 0 | **0** | ✅ |
| 0.2 | `name='仪器设备负责人'` 冲突行 | 0 行 | **0 行** | ✅ |
| 0.3 | id=908 是否被占用 + `AUTO_INCREMENT` | 0 / 908 | **id_908_used=0；next_auto_increment=908** | ✅ |
| 0.4 | 祖先目录 13478 / 13600 存在且启用 | 2 行 | **2 行**（均 type=1、status=0；13478 parent_id=0、13600 parent_id=13478） | ✅ |
| 0.5 | 目标授权菜单 `13620,13621,13660,13661,13665,13666` 存在且启用 | 6 行 | **仅 2 行**（13620 仪器设备 type=2、13621 查询 `device:query` type=3）；**13660/13661/13665/13666 尚不存在** | ⚠️ **预期前置状态**（见 5.2） |
| 0.6 | 权限串归属核对 | 3 行 | **仅 1 行**：13621=`device:query`；13661/13666 不存在 | ⚠️ **预期前置状态** |
| 0.7 | 租户 162 存在且启用 | 1 行 | **1 行**（status=0, package_id=114） | ✅ |
| 0.8 | role 908 现状授权数（留证） | 无 / 0 | **无输出**（角色不存在 → 0 行） | ✅ |

**0.5 / 0.6 的实际返回如何解读**：这两项返回少于期望**并非缺陷**，而是**正确的部署前状态**——
INSTRUMENT-02 菜单（13660~13673）由 `20261015_instrument_02_menu.sql` 创建，**该脚本尚未执行**，
故 13660/13661/13665/13666 尚不存在。这正是 role 脚本 §0.5 设计的**停止条件**：**必须先执行 menu SQL，再执行 role 脚本**。
本任务**未执行任何脚本**，因此该状态为**部署前应有的前置状态**，**非阻塞性冲突**。

### 5.2 与 B4（FIX-01）相关的只读预检

| 编号 | 查询 | 实际返回 | 判定 |
| --- | --- | --- | --- |
| schema §0.1 | 6 张 INSTRUMENT-02 表存在性 | 6 行 cnt 全为 0（表不存在） | ✅ 首次部署正常 |
| schema §0.4 | 6 表列级结构预检（4 组只读 `information_schema` 查询） | 无报错、全部返回空集（表未创建） | ✅ 语法正确 + 首次部署安全 |
| menu §0.1/§0.2 | 13660~13673 空闲、MAX(id) | 空闲；MAX(id)=13653 | ✅ |
| menu §0.3 | 权限串冲突 | 0 行（无 qualification/credit/suspend 权限串） | ✅ |

> 上述结果与 16/17 号报告（FIX-01）一致，**本次复核未发现新增阻塞性预检冲突**。

---

## 六、编译、静态检查、单元测试结果

### 6.1 后端模块编译

| 项 | 命令 | 结果 |
| --- | --- | --- |
| 后端编译 | `mvn -o -pl yudao-module-lab -DskipTests compile`（Yudao 主工程根目录） | **BUILD SUCCESS**；238 个源文件，**本任务 5 个改动文件全部编译通过** |
| 历史告警（与本任务无关，**单独隔离报告**） | — | 仅 `PlasmidInventoryController.java` 历史 deprecation 警告，**非本任务引入** |

**历史编译错误与本任务新增错误分离报告**：本次编译**无任何错误**；唯一告警为既有
`PlasmidInventoryController` deprecation，**与本任务改动无关，未修复、未扩大范围**。

### 6.2 前端类型检查

| 项 | 命令 | 结果 |
| --- | --- | --- |
| 全量 `vue-tsc` | `node --max_old_space_size=16384 ./node_modules/vue-tsc/bin/vue-tsc.js --noEmit` | **13 个 TS 错误，全部在无关模块** |
| 错误分布（**历史存量，与本任务无关**） | — | `src/api/lab/announcement/index.ts`、`src/views/fms/report/components/FmsReportFormulaForm.vue`、`src/views/hrm/employee/index.vue`、`src/views/lab/v2/plasmid/index.vue`、`src/views/lab/v2/plasmid-audit/index.vue` |
| `lab/instrument` 模块 | — | **0 错误**（本任务改动的 2 个 `.vue` 文件全部通过） |

> 说明：`pnpm ts:check` 首次执行因环境堆内存上限（`NewSpace::EnsureCurrentCapacity`）OOM（exit 134），
> 属**环境问题非代码错误**；改用 16GB 堆后成功产出结果。

### 6.3 前端 ESLint

| 文件 | 结果 |
| --- | --- |
| [suspend-manage/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/suspend-manage/index.vue) | **exit 0** |
| [my-credit/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/my-credit/index.vue) | **exit 0** |

### 6.4 角色及菜单 SQL 静态核对

| 核对项 | 结果 |
| --- | --- |
| role 脚本分段（§0 只读 / §1~§2 写入 / §3 验收 / §4 人工 / §5 事务） | ✅ 清楚分离，无"整文件执行"风险 |
| 写入语句守卫（`NOT EXISTS` / 角色+菜单存在启用 / 租户匹配） | ✅ 齐备；重复执行影响 0 行 |
| 授权集合与祖先链 | ✅ 8 条 `13478,13600,13620,13621,13660,13661,13665,13666` 完整覆盖 13621/13661/13666 的父链 |
| 停止条件 | ✅ §0.1（code 冲突）、§0.3（id/AUTO_INCREMENT）、§0.5（目标菜单 <6 行）、§0.7（租户不符）均有明确【停止】说明 |
| 越权回归（§3.4） | ✅ 预期 0 行（不含任何写/信用/暂停权限） |
| 既有授权回归（§3.5） | ✅ 预期 904=6、906=14 未被改动 |
| menu SQL 兼容性 | ✅ 仅头部注释改动；§0~§6 可执行 SQL 零改动，904/906 授权不变 |

### 6.5 服务端权限调用链检查

| 链路 | 核对结论 |
| --- | --- |
| `@PreAuthorize` 解析链 | `PermissionServiceImpl#hasAnyPermission` → `system_role_menu` 直查（menu → role 缓存），**不受菜单树完整性限制** |
| 前端权限集合链 | `AuthController#getPermissionInfo` → `filterDisableMenus`（父链缺失即丢弃）→ `AuthConvert.buildMenuTree`（先移除 BUTTON）→ `v-hasPermi`；**故授权须含完整祖先链** |
| 资质审批链 | Controller `/audit`（`qualification:audit`）→ `auditApply` 的 `canManageDevice`（业务关系）∩ 行锁 ∩ affectedRows 守卫 |
| 资质列表链 | Controller `/page`（`qualification:query`）→ `getQualificationPage`：`canManageAll` ∨ `managedDeviceIds` 恒过滤（空 → 403） |
| 暂停列表链 | Controller `/page`（`suspend:query`）→ `getSuspendPage`：`canManageAll` ∨ `managedDeviceIds` 恒过滤（空 → 403） |
| 信用链 | Controller `/page`、`/flow/page`、`/flow/export-excel` → `requireManageAll`（非管理员 403） |
| 本人链 | `/my`、`getMyCredit`、`getMyFlowPage`、`getMySuspends`、`getMyQualifications` 全部强制 `loginUserId` |

### 6.6 单元测试

| 项 | 结果 |
| --- | --- |
| 本任务是否新增/修改单元测试 | **否**（H1/B2/B3 的改动为语义收敛、文案、SQL 与注释；未新增测试用例） |
| 既有 `Instrument02ServiceTest`（26 用例） | **未在本任务重跑**；本任务未改其覆盖逻辑（H1 只影响 `selectActiveCovering` 的 end_time 条件，既有 `testSuspendExpire_andIdempotent` 语义不受影响） |
| 测试数据边界 | **未向真实数据库创建任何申请、调整信用、解除暂停或新增角色** |

> 说明：任务单允许"不产生业务数据的单元测试/Mock/静态测试"，本任务主要以**编译 + 类型检查 + 静态核对 + 只读预检**完成验证，未额外引入测试；
> 遵循"不得为了验证而向真实数据库创建申请、调整信用、解除暂停或新增角色"的强制约束。

---

## 七、尚未完成的真实数据库部署与 HTTP 验收项目

> 以下项目**一律不记为 PASS**；在完成前部署状态为 **NOT DEPLOYED / 待授权**。

| # | 未完成项 | 为何未完成 | 结论取值 |
| --- | --- | --- | --- |
| 1 | `20261015_instrument_02_schema.sql` 真实执行（6 表 DDL） | 需负责人单独授权；本任务只读 | **未执行** |
| 2 | `20261015_instrument_02_menu.sql` 真实执行（菜单+套餐+904/906 授权） | 同上 | **未执行** |
| 3 | `20261015_instrument_02_device_manager_role.sql` 真实执行（角色 908 + 8 授权） | 同上；且必须在 menu SQL 之后 | **未执行** |
| 4 | 角色 908 真实创建、设备负责人用户分配角色 | 需用户角色分配人工操作；未执行 | **未执行** |
| 5 | HTTP 层 904/906/908 权限校验（`@PreAuthorize` 真实请求生效） | 仅静态比对该权限链 | **未验证** |
| 6 | 真实租户拦截器下的跨租户不可见 / 唯一键按租户独立 | 静态 + H2 未加载租户插件 | **未验证** |
| 7 | 真实 Redis 下并发首审"仅初始化一次" | 既有单测锁为 mock | **未验证** |
| 8 | 设备负责人**边界实测**：负责人解除后审批被拒、设备停用、跨租户、并发重复审批 | 无真实用户/数据；未执行 | **未验证** |
| 9 | 暂停"人工解除"语义真实库行为（`end_time` 到期不自动解除、人工解除才 RELEASED） | 需真实库数据；未执行 | **未验证** |
| 10 | 暂停自动到期 Job 实际调度（**本期不启用，不作为验收条件**） | H1 裁决 B 方案：不注册、不调度 | **不适用（本期）** |
| 11 | INSTRUMENT-01 回归（5 页面 + 10 条测试数据完好） | 未执行任何真实操作 | **未执行** |

---

## 八、INSTRUMENT-03 必须继承的暂停校验约束

已写入 [03-预约规则与并发控制设计.md](file:///E:/lixin/dev/doc/03-仪器管理/03-预约规则与并发控制设计.md) **§8.1.1**（新增），全文强制约束（**MUST**）：

1. **创建预约前必须检查用户是否存在生效暂停**：在 8.1 事务步骤 2「复核 P1–P7」中插入 P5 校验，或在提交前独立执行等价校验。
2. **ALL 范围暂停拦截该用户所有适用设备的预约**：存在 `scope_type='ALL'` 的生效暂停时，该用户对任意适用设备的预约创建一律拒绝。
3. **SINGLE 范围暂停仅拦截指定设备**：存在 `scope_type='SINGLE' AND device_id=目标设备` 的生效暂停时，拒绝该设备上的预约创建；不影响该用户其他设备的预约。
4. **校验必须在服务端执行**：判定逻辑位于 Service 层（与 8.1 设备行锁同一事务内），不得仅在 Controller 做形式校验后放行。
5. **不得仅依赖前端禁用按钮**：前端置灰只作体验提示，未授权的直接 API 调用必须同样被服务端拦截并返回明确业务错误。
6. **必须保证预约创建时的并发与事务一致性**：暂停校验与预约插入须处于同一事务，并借助 8.1 的设备行锁串行化；避免"校验通过后、插入前"期间并发创建暂停或反之产生不一致窗口。
7. **人工解除后按当前有效资质及其他预约规则重新判定**：暂停被人工解除后，该用户的预约能力回到既有规则（P4 资质 ACTIVE、P6 冲突、P7 其他），不得缓存"已拦截"结论。

**生效暂停判定语义（与 INSTRUMENT-02 H1 一致，须继承）**：

- 生效暂停 = `lab_instrument_suspend.status='ACTIVE'` 且 `start_time <= now`；**仅以 status 判定，不以 `end_time` 自动失效**——计划结束时间到达不代表自动解除（H1 裁决 B 方案，本期不启用自动到期 Job）。**预约侧不得自行用 `end_time > now` 作为"是否生效"的条件**。
- 用户带生效暂停期间仍可通过资质审核（G13，H2 裁决接受）：暂停不改变资质状态判定本身，而是由预约侧 P5 统一拦截。故 INSTRUMENT-03 **不得**因存在暂停记录而把新审批资质强制判为 REJECTED。

**跨模块依赖**：预约模块需读取 INSTRUMENT-02 的暂停数据（`lab_instrument_suspend`）与资质数据（`lab_instrument_qualification`），并按租户隔离校验。**本期不开发预约模块**；**H2 裁决已完成，预约侧联动验证仍待 INSTRUMENT-03**。

---

## 九、PASS / HOLD 结论及具体原因

### 9.1 验收标准逐项核对

| 验收标准 | 结论 | 证据 |
| --- | --- | --- |
| H1 人工解除语义已落实且**无自相矛盾的到期判断** | ✅ PASS | `selectActiveCovering` 去 `end_time` 条件；三个"生效判定"方法口径统一；冲突已报告并修正（§1.2） |
| H2 强制依赖已写入 INSTRUMENT-03 文档 | ✅ PASS | `03-预约规则与并发控制设计.md` §8.1.1（7 条 MUST） |
| B2 角色、授权 SQL、后端设备范围审批均已完成 | ✅ PASS | role 脚本（id=908 + 8 授权）+ `auditApply` 双重校验（既有 + 补注释） |
| B3 共用权限串保留，服务端越权路径得到控制 | ✅ PASS | 未拆权限串；2 处越权缺陷修正为显式 403 + 恒过滤 |
| 编译及相关静态检查通过，或历史问题被清楚隔离 | ✅ PASS | 后端 BUILD SUCCESS；前端 13 个历史错误全在无关模块、instrument 零错误；ESLint exit 0 |
| 只读预检没有阻塞性冲突 | ✅ PASS | §5 全部预检；0.5/0.6 为**预期前置状态**（menu SQL 未执行），非阻塞 |
| 所有变更有可核验的文件与测试证据 | ✅ PASS | §2 逐文件清单 + §5/§6 证据 |

### 9.2 最终结论

**=> CODE/PRECHECK PASS**

**部署状态：NOT DEPLOYED / 待授权。**

**不得把 CODE/PRECHECK PASS 写成 DEPLOY PASS**：数据库尚未执行、角色尚未真实创建、HTTP 权限及并发尚未实测，
故部署状态一律为 **NOT DEPLOYED / 待授权**，需负责人按 §4.2 执行顺序单独授权执行 SQL 后方可转 PASS。

**尚需负责人裁决/授权的事项**（不在本任务范围内）：
1. 授权执行三个 SQL（顺序：schema → menu → device_manager_role）；
2. 设备负责人用户的实际角色分配（在【系统管理 → 用户管理】人工完成）与业务关系（【仪器管理 → 仪器负责人】）确认，二者需同时满足；
3. 真实环境 HTTP 权限、真实 Redis 并发、租户隔离验收（§七 1~11）。

---

## 十、明确声明

> **本任务（TASK INSTRUMENT-02-DECISION-IMPLEMENT-01）明确声明：**

1. **未执行任何数据库写入或 DDL**：未执行 `CREATE` / `ALTER` / `DROP` / `INSERT` / `UPDATE` / `DELETE` / `TRUNCATE`；仅执行只读 `SELECT`（role 脚本 §0 预检、schema §0.4、menu §0.1~§0.3 等）。
2. **未执行任何 SQL 脚本**：schema / menu / device_manager_role 三个脚本**均未执行**，文件中预检、写入、验收段已清楚分离，**未通过整文件执行做只读验证**。
3. **未注册或启动任何定时任务**：未写入 `infra_job`，未切换运行 profile，未重启服务。
4. **未修改线上角色或权限**：未 `INSERT/UPDATE/DELETE` 任何 `system_role` / `system_role_menu` / `system_menu` / `system_tenant_package` 行。
5. **未清理 INSTRUMENT-01 的 10 条测试数据**，未修改质粒模块，未进入 INSTRUMENT-03 代码开发。
6. **未修改** `20261015_instrument_02_schema.sql` 的可执行 SQL（FIX-01 §0.4 保留）；`menu.sql` 仅改头部注释；对 904/906 授权**保持原样**。
7. 本任务**未将任何未执行项标记为 PASS**；`lab/instrument` 前端模块零错误，前端其余 13 个 TS 错误与本任务无关（历史存量）。

**本报告完成后立即停止，等待负责人审核；不自行执行 SQL、不重启服务、不开始 INSTRUMENT-03。**

---

*报告结束。修订对象：[15](file:///E:/lixin/dev/doc/03-仪器管理/15-INSTRUMENT-02-开发交付报告.md) / [16](file:///E:/lixin/dev/doc/03-仪器管理/16-INSTRUMENT-02-部署前集中复核报告.md) / [17](file:///E:/lixin/dev/doc/03-仪器管理/17-INSTRUMENT-02-部署前整改报告.md) 号报告已同步更新 H1/H2/B2/B3 裁决状态（保留历史 PENDING 记录）。*
