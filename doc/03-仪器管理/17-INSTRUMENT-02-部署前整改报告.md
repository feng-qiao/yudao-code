# 17-INSTRUMENT-02-部署前整改报告

- 任务：TASK INSTRUMENT-02-DEPLOY-PRECHECK-FIX-01（部署前复核问题修订）
- 日期：2026-10-15
- 依据：[16-INSTRUMENT-02-部署前集中复核报告.md](file:///E:/lixin/dev/doc/03-仪器管理/16-INSTRUMENT-02-部署前集中复核报告.md)（结论 HOLD）
- 整改性质：**直接修正 M1/M2/B4**；**登记 H1/H2/B2/B3 裁决状态（均 PENDING）**；复核部署步骤。**未执行任何 DDL/INSERT/UPDATE/DELETE，未注册 Job，未切换 profile，未重启服务，未改 Java/Vue/配置。**

---

## 一、M1 / M2 / B4 修订内容与证据

### 1.1 M1：Menu SQL 菜单计数注释订正为 14

| 项 | 内容 |
| --- | --- |
| 问题 | 注释写"13 条"，实际为 14 条（执行者按 13 核对行数会误判） |
| 修订文件 | [20261015_instrument_02_menu.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_menu.sql) |
| 修订点 ① | §2 节标题注释：`共 13 条` → `共 14 条`（第 176 行附近） |
| 修订点 ② | §3.1 节注释：`全部 13 条新菜单/按钮` → `全部 14 条新菜单/按钮`（第 227 行附近） |
| 证据（实际行数） | §1 节 14 条 `INSERT`（13660~13673）；§2 节 14 条 `UPDATE`；§3.1 的 `UNION` 列 14 个 ID；§3.2 列 6 个 ID；§4.1 期望"14 行（type=2 五条、type=3 九条）"；§4.5 期望"906=14、904=6" |
| 其余计数复核 | 全文复核后确认**无其他计数不一致**：§1 头部"14 条（5 页面+9 按钮）"、§1"9 个权限串"、§4.3"预期 9 行"、§5"五个菜单"、§6.2"第 1 节 14 行/第 2 节最多 14 行/第 3.1 最多 14 行/第 3.2 最多 6 行"均与实际一致 |

**结论：M1 已修复，无遗留计数不一致。**

### 1.2 M2：预检 SQL 中 AND/OR 混用条件加括号

| 项 | 内容 |
| --- | --- |
| 问题 | `WHERE A AND X OR A AND Y OR A AND Z` 语义正确（AND 优先于 OR）但易误读，存在被误改风险 |
| 修订文件 | [20261015_instrument_02_menu.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_menu.sql) §0.3 |
| 修订前 | `WHERE deleted = b'0' AND permission LIKE '...qualification:%' OR deleted = b'0' AND permission LIKE '...credit:%' OR deleted = b'0' AND permission LIKE '...suspend:%'` |
| 修订后 | `WHERE deleted = b'0' AND (permission LIKE 'lab:instrument:qualification:%' OR permission LIKE 'lab:instrument:credit:%' OR permission LIKE 'lab:instrument:suspend:%')` |
| 证据（等价性） | 只读执行修订后谓词：`rows_returned = 0`（与修订前一致，确认本环境无权限串冲突） |
| schema 侧复核 | **schema 脚本预检无 AND/OR 混用**：§0.1 / §2.4 使用 `UNION ALL`，§0.2/§0.3/§2.1~§2.3 均为纯 AND → 无需改动 |

**结论：M2 已修复；schema 无同类问题。**

### 1.3 B4：补全六表列级结构预检（`CREATE TABLE IF NOT EXISTS` 掩盖风险）

| 项 | 内容 |
| --- | --- |
| 问题 | `CREATE TABLE IF NOT EXISTS` 在"表已存在"时**静默跳过**，若旧表结构不一致则被沿用；原验收仅核 `credit_account.score` 一列，覆盖不全 |
| 修订文件 | [20261015_instrument_02_schema.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_schema.sql) |
| 新增 | **§0.4「六表列级结构预检」**（4 个只读查询，全部仅查 `information_schema`） |
| 0.4.1 | 逐表**列数**核对；期望：qualification_apply=25 / apply_history=16 / qualification=17 / credit_account=14 / credit_flow=21 / suspend=22 |
| 0.4.2 | 六表**公共审计/租户/逻辑删除列**各 6 列（tenant_id/deleted/creator/create_time/updater/update_time）齐全 + 类型/可空/默认值符合期望 |
| 0.4.3 | **主键与唯一键**核对：`PRIMARY(id)` 六表齐全；apply 含 `uk_apply_tenant_no(tenant_id,apply_no)`、credit_account 含 `uk_account_tenant_user(tenant_id,user_id)` |
| 0.4.4 | **关键业务列**核对；期望命中列数：qualification_apply=8 / apply_history=6 / qualification=6 / credit_account=5 / credit_flow=9 / suspend=9 |
| 三种情形说明（写入 §0.4 注释） | **① 首次部署**（六表不存在）：§0.1 六行 cnt=0 且 §0.4 返回空集 → 正常执行 §1；**② 已存在且结构一致**：§0.4 各项符合期望 → 视为此前已部署，可跳过 §1（重跑 `IF NOT EXISTS` 亦无副作用），继续 §2 验收；**③ 已存在但结构不一致**：§0.4 任一不符 → **停止** |
| 停止条件 | §3 新增**停止条件 4**：0.4 列数/公共列/主键唯一键/关键业务列任一不符即停止，**禁止 DROP / 重建 / 自动 ALTER**，须回报负责人人工核实表归属与迁移方案 |
| 首次部署安全性 | 0.4 四个查询**只查 `information_schema`，不访问六张业务表**，故六表均不存在时**安全执行、返回空集、不报错、不中断** |
| 证据（已执行，只读） | 合并执行 0.4.1~0.4.4：**无报错、全部返回空集**（本环境六表尚未创建）→ 证明语法正确 + 首次部署安全 |
| 关联修订 | schema §2.4 增加前置说明：该节直接 `COUNT(*)` 六表，**必须在第 1 节 DDL 之后执行**；首次部署前结构预检以 §0.4 为准 |

**结论：B4 已修复（预检 SQL + 停止条件 + 三种情形均齐备）。**

---

## 二、H1 / H2 / B2 / B3 裁决状态

> **本任务只登记负责人明确给出的裁决。** 截至本报告（FIX-01，2026-10-15）撰写时，**H1/H2/B2/B3 均未收到任何裁决**，全部保持 **PENDING**。**Trae 不代替负责人作出决定，未擅自切换 profile、未注册 Job、未改菜单 SQL / 权限矩阵 / 代码。**
>
> ⚠️ **后续更新（2026-10-15，TASK INSTRUMENT-02-DECISION-IMPLEMENT-01）**：负责人已于 2026-10-15 对 H1/H2/B2/B3 作出**正式裁决**，并已落地实施。**下表 PENDING 记录作为历史保留（不抹除）**；最新裁决与落地证据见 [18-INSTRUMENT-02-裁决落地与部署准备报告.md](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md)。**H1/H2/B2/B3 裁决状态现已全部更新为"已裁决 + 已落地"。**

| 编号 | 须负责人明确的内容（裁决项） | 裁决 | 状态 |
| --- | --- | --- | --- |
| **H1** | ① **Quartz 运行环境**：采用哪个 profile 承载调度（`local` 放开 `QuartzAutoConfiguration` / 改用 `dev`（未排除 Quartz）/ 其他）；② **任务注册方式**：后台"定时任务"创建 vs 手写 `infra_job` 插入；③ **自动到期验收门槛**：本期是否必须验收"到期自动 EXPIRED" | — | **PENDING** |
| **H2** | **预约模块的暂停校验依赖**：是否接受"暂停生效期间新审核通过的 ACTIVE 资质，由 INSTRUMENT-03 预约侧读取生效暂停记录来拦截"，并在 INSTRUMENT-03 需求/设计中把"预约前校验暂停"列为强制项 | — | **PENDING** |
| **B2** | **资质审批主体及其角色/权限映射**：是否允许"非管理员设备负责人"自助审核；若允许 → 授权哪个角色、哪些权限串；若不允许 → 是否书面确认"审核仅 906 管理员" | — | **PENDING** |
| **B3** | **本人查询与管理查询的权限边界**：是否拆分共用权限串（如 `suspend:query` 拆为"本人"与"管理"两串），或书面确认"共用 + Service 数据兜底"为有意设计；服务端数据范围是否需进一步收紧 | — | **PENDING** |

**上述 PENDING 记录保留为历史。以下为 2026-10-15 正式裁决及落地状态（DECISION-IMPLEMENT-01）：**

| 编号 | 负责人 2026-10-15 正式裁决 | 落地动作（本任务） | 裁决后状态 |
| --- | --- | --- | --- |
| **H1** | **采用 B 方案：本期不启用自动到期**；不注册/不启用 Job、不调 Quartz profile、保留人工解除、暂停在人工解除前持续生效（`end_time` 到达不代表自动解除） | 修正 `selectActiveCovering` 去除 `end_time` 条件；三处生效判定口径统一；Job/Service/枚举 javadoc 加注"本期不启用"；前端文案改"计划结束时间/实际解除时间" | **已裁决 + 已落地** |
| **H2** | **接受 G13 转移依赖**：保持暂停期新资质审核通过为 ACTIVE，不强制改 REJECTED；在 INSTRUMENT-03 强制"预约前校验生效暂停" | 在 [03-预约规则与并发控制设计.md](file:///E:/lixin/dev/doc/03-仪器管理/03-预约规则与并发控制设计.md) 新增 §8.1.1（7 条 MUST）；本任务不开发预约模块 | **已裁决 + 已落地**（预约侧联动待 INSTRUMENT-03） |
| **B2** | **允许设备负责人审批其负责设备的资质申请，必须增加角色和权限** | 新建 [20261015_instrument_02_device_manager_role.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_device_manager_role.sql)（角色 908 `instrument_device_manager` + 8 条含完整祖先链授权）；`auditApply` 双重校验补说明；**未执行** | **已裁决 + 已落地**（SQL 待授权执行） |
| **B3** | **不拆分共用权限串**，强化服务端范围；越权以项目既有规范明确拒绝（不得以空分页替代） | 保留共用权限串未拆；修正 `getSuspendPage`（空分页→403）与 `getQualificationPage`（租户全量→403+恒过滤）两处越权缺陷 | **已裁决 + 已落地** |

**裁决后可能触发的修改清单（待裁决后另立任务，本任务不实施）**：

| 编号 | 可能触发的修改 | 涉及范围 |
| --- | --- | --- |
| H1 | 调整 profile 或被排除的自动配置；注册定时任务 | 配置（`application-local.yaml` / `application-dev.yaml`）、后台操作（不改代码） |
| H2 | 在 INSTRUMENT-03 需求/设计写入"预约前校验生效暂停记录"为强制项 | INSTRUMENT-03 文档/后续实现（本期不改 G13 代码） |
| B2 | 新增/授权角色与权限串；追加菜单 SQL | `system_role` / `system_role_menu` / menu SQL / 权限矩阵文档（跨 SQL + 文档） |
| B3 | 拆分权限串并同步后端 `@PreAuthorize` 与 Service 数据范围 | Controller(Java) + Service(Java) + 菜单 SQL + 权限矩阵文档（跨三层） |

---

## 三、SQL 是否执行、数据库是否写入

| 项 | 结论 |
| --- | --- |
| 是否执行两个 SQL 脚本（schema / menu 的写入语句） | **否**（未执行任何 DDL / INSERT / UPDATE / DELETE） |
| 数据库是否发生写入 | **否**。FIX-01 仅执行 **2 批只读 SELECT**（见下） |
| 已执行的只读 SELECT | ① schema §0.4 四条预检合并执行 → 无报错、返回空集；② 修订后 menu §0.3 → `rows_returned = 0` |
| 是否注册/启动定时任务 | 否 |
| 是否切换 profile / 重启服务 | 否 |
| 是否调用产生业务数据的接口 | 否 |
| 是否修改 Java / Vue / 配置文件 | 否 |
| 是否修改允许清单外的文件 | 否。仅按授权修订：`20261015_instrument_02_schema.sql`、`20261015_instrument_02_menu.sql`、`15-INSTRUMENT-02-开发交付报告.md`、`16-INSTRUMENT-02-部署前集中复核报告.md`；并新建本报告 |
| INSTRUMENT-01 测试数据 | 未清理、未触碰（仍为 10 条） |

**执行的命令（PowerShell 模板，均为只读）**：
```
& 'D:\worktools\phpstudy_pro\Extensions\MySQL8.0.12\bin\mysql.exe' --host=127.0.0.1 --port=3306 \
  --user=bencao --password=bencao2026 --default-character-set=utf8mb4 --table \
  --database=labplatform --execute="<只读 SELECT>"
```

---

## 四、剩余 HOLD 项

| 层级 | 编号 | 剩余 HOLD 说明 | 状态 |
| --- | --- | --- | --- |
| 停止条件命中 | **H1** | 目标运行 profile=`local` 排除 Quartz → `SchedulerManager(null)` → 暂停到期 Job 无执行承载；**仅注册 `infra_job` 行不会使其运行** | HOLD / 裁决 PENDING |
| 停止条件命中 | **H2** | G13（暂停期新资质=ACTIVE）与"后续预约拦截"的一致性依赖预约侧读取暂停记录，而预约模块（INSTRUMENT-03）当前不存在 → 一致性无法证明 | HOLD / 裁决 PENDING |
| 部署阻塞 | **B2** | 非管理员设备负责人审核路径无角色可达 | PENDING |
| 部署阻塞 | **B3** | 本人/管理查询权限串共用（服务端已数据兜底，无实际越权，但未拆分/未书面确认） | PENDING |
| 未验证（真实环境） | U1~U10 | 见 16 号报告 §十一：真实 Redis 并发首审 / 真实租户拦截器隔离 / 真实 HTTP 鉴权 / 导出范围 / Job 实际调度 / 两 SQL 真实执行 / INSTRUMENT-01 回归 —— **一律不记为 PASS** | 未验证 |

**已消除项**：M1、M2（文档/预检清晰度）、B4（列级结构预检缺失）——已由本任务修复。

**整体结论（FIX-01 撰写时）**：仍为 **HOLD**（H1、H2 为停止条件且裁决 PENDING；B2、B3 待裁决）。

### 4.1 后续更新（2026-10-15，DECISION-IMPLEMENT-01）

> 下表 HOLD 记录保留为历史；负责人已裁决并落地，**H1/H2 停止条件已解除，B2/B3 部署阻塞已解决**，
> 但**真实环境验证（U1~U10 中除"本期不适用"外）仍为未验证**，故部署状态仍为 **NOT DEPLOYED / 待授权**。

| 编号 | 原 HOLD/阻塞 | 裁决后状态 | 落地证据 |
| --- | --- | --- | --- |
| H1 | 停止条件：Job 无执行承载 | **解除**（B 方案：本期不启用自动到期，Job 不作为验收条件） | [18 号报告 §1.2](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md) |
| H2 | 停止条件：G13 依赖不可证 | **解除**（接受 G13 转移依赖 + 强制约束写入 §8.1.1） | 同上 §1.3 / §八 |
| B2 | 部署阻塞：负责人审核无角色可达 | **解决**（新增角色 908 + 8 授权 SQL；未执行） | 同上 §1.4 / §三 |
| B3 | 部署阻塞：权限串共用 | **解决**（共用保留 + 2 处越权修正为显式 403） | 同上 §1.5 |
| U1~U10 | 真实环境未验证 | **仍为未验证**（部署状态 NOT DEPLOYED / 待授权） | 同上 §七 |

---

## 五、后续部署任务的准确前置条件

**在启动任何部署任务之前，必须满足以下全部前置；任一不满足即不得进入部署阶段。**

> ⚠️ **后续更新（2026-10-15，DECISION-IMPLEMENT-01）**：下列前置 1/2/3 已由负责人正式裁决并落地（H1 B 方案不启用自动到期；H2 接受 G13 转移依赖；B2 新增设备负责人角色 908；B3 保留共用权限串强化服务端范围）。**原 PENDING 文字保留为历史**；详见 [18 号报告](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md)。**当前唯一剩余前置为：负责人单独授权执行三个 SQL（schema → menu → device_manager_role）。**

1. **H1 已裁决并落地**（**已满足**：B 方案，本期不启用自动到期）
   - ~~明确承载调度的运行 profile~~ → 裁决：本期不调整 profile、不启动 Scheduler；
   - ~~明确任务注册方式~~ → 裁决：本期不注册 Job；
   - ~~明确"到期自动 EXPIRED"是否纳入本期验收~~ → 裁决：**不纳入**；暂停仅人工解除（`end_time` 到达不自动解除）。
2. **H2 已裁决**（**已满足**）
   - 裁决：接受"暂停期新 ACTIVE 资质由 INSTRUMENT-03 预约侧拦截承接"，并已写入 INSTRUMENT-03 强制约束（[03-预约规则与并发控制设计.md](file:///E:/lixin/dev/doc/03-仪器管理/03-预约规则与并发控制设计.md) §8.1.1）。
3. **B2、B3 已裁决**（**已满足**）
   - B2：新增角色 908 `instrument_device_manager` + 8 条授权 SQL（**未执行**）；
   - B3：不拆分共用权限串，强化服务端范围（2 处越权修正为显式 403）。
4. **只读预检全部通过**（在 SQL 执行前）
   - schema §0.1（六表不存在）、§0.2（utf8mb4）、§0.3（字典预置）、**§0.4（列级结构，三种情形判定）**；
   - menu §0.1~§0.7（ID 段空闲、父菜单存在、权限串无冲突、角色/租户/套餐就绪）；
   - **device_manager_role §0.1~§0.8**（code/name 冲突、id 908/AUTO_INCREMENT、祖先链、目标菜单 ≥6 行、权限串、租户 162、现状留证）—— **须在 menu SQL 之后执行**；
   - 16 号报告 §9 SQL-1~SQL-5（含 **SQL-5b 使用 `information_schema` 的存在性核对**，首次部署安全）。
5. **授权边界确认**：SQL 生成与 SQL 执行为独立授权；执行具体 SQL 需负责人单独授权。
6. **数据边界确认**：INSTRUMENT-01 的 10 条测试数据**不得清理**；6 张新表验收数据仅限新表。
7. **验收环境确认**：真实 Redis + 真实租户拦截器 + Web Controller（缺一不得记为真实环境 PASS）。**注**：H1 裁决后本期**不要求**可执行 Scheduler。

**部署顺序（前置满足后，仍须负责人按 16 号报告 §十 执行）**：
备份三张 system_* 表 → schema §0（含 §0.4）→ schema §1 DDL → schema §2 验收（§2.4 在 DDL 后）→ menu §0 → menu §1/§2/§3（事务内）→ menu §4 验收 → **device_manager_role §0 → §1/§2（事务内）→ §3 验收** → 重启 + 前端重登 → 真实环境验收（16 号报告 §十一 U1~U10，**U1 本期不适用**）→ INSTRUMENT-01 回归。

> **H1 裁决后不再要求注册 Job**；原"→ H1 裁决后注册 Job →"步骤**取消**（本期不启用自动到期）。

---

## 六、修订文件与核验依据汇总

| 文件 | 修订内容 | 核验依据 |
| --- | --- | --- |
| [20261015_instrument_02_schema.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_schema.sql) | 新增 §0.4（0.4.1~0.4.4）；§2.4 增前置说明；§3 增停止条件 4 | 只读执行 §0.4 四条查询：无报错、返回空集（首次部署安全） |
| [20261015_instrument_02_menu.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_menu.sql) | §2/§3.1 注释 13→14；§0.3 加括号 | DDL/注释行数与 ID 清单逐条核对；只读执行修订后 §0.3 → 0 行 |
| [15-INSTRUMENT-02-开发交付报告.md](file:///E:/lixin/dev/doc/03-仪器管理/15-INSTRUMENT-02-开发交付报告.md) | §7 增 H1/H2/B2/B3；§8 增 B4 门槛与 H1 前置、负重"独立授权边界"；§9 增三件套与补充观测点 | 与 16 号报告 §八/§十/§十一 对齐 |
| [16-INSTRUMENT-02-部署前集中复核报告.md](file:///E:/lixin/dev/doc/03-仪器管理/16-INSTRUMENT-02-部署前集中复核报告.md) | §一 结论表更新；§八 8.1/8.2 标注修复、新增 8.4 决策记录；§九 SQL-1 指向 §0.4、SQL-5 安全化；§十二 增 12.4；§十三 停止声明 | 与 SQL 修订、决策状态一致 |
| [17-INSTRUMENT-02-部署前整改报告.md](file:///E:/lixin/dev/doc/03-仪器管理/17-INSTRUMENT-02-部署前整改报告.md) | 本报告（新建） | — |
| [20261015_instrument_02_device_manager_role.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261015_instrument_02_device_manager_role.sql) | **DECISION-IMPLEMENT-01 新建**：角色 908 + 8 条授权（**未执行**） | role §0 只读预检实测 |
| [03-预约规则与并发控制设计.md](file:///E:/lixin/dev/doc/03-仪器管理/03-预约规则与并发控制设计.md) | **DECISION-IMPLEMENT-01 新增**：§8.1.1 预约前暂停校验强制约束（H2） | — |
| [18-INSTRUMENT-02-裁决落地与部署准备报告.md](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md) | **DECISION-IMPLEMENT-01 新建**：四项裁决落地与部署准备 | — |

---

## 七、停止声明

本任务（INSTRUMENT-02-DEPLOY-PRECHECK-FIX-01）**已完成并立即停止**：
- 未执行任何 DDL / INSERT / UPDATE / DELETE（仅 2 批只读 SELECT）；
- 未注册或启动定时任务；未切换运行 profile；未重启服务；未调用产生业务数据的接口；
- 未修改任何 Java / Vue / 配置文件；仅在授权清单内修订 SQL 与文档，并新建本报告；
- 未清理 INSTRUMENT-01 的测试数据，未修改质粒管理模块；
- 未自行删除/重建任何数据表；未进入 INSTRUMENT-03。

**H1/H2/B2/B3 现已由负责人（2026-10-15）正式裁决并落地（见 §二 4.1 与 [18 号报告](file:///E:/lixin/dev/doc/03-仪器管理/18-INSTRUMENT-02-裁决落地与部署准备报告.md)）**；原 PENDING 记录保留为历史。静态验证结论为 **CODE/PRECHECK PASS**；**部署状态仍为 NOT DEPLOYED / 待授权**（三 SQL 未执行、角色未真实创建、HTTP/并发未实测）。完成本报告后即停止，等待负责人复核，不执行 SQL，不进入部署阶段。
