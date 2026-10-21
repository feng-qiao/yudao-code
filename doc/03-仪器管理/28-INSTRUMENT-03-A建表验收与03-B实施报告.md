# 28-INSTRUMENT-03-A建表验收与03-B实施报告

- 任务：TASK INSTRUMENT-03-A-DDL-EXEC-01（五张表 DDL 授权执行、03-A 关闭及 03-B 连续开发）
- 日期：2026-10-15
- 关联报告：26-INSTRUMENT-03-规则冻结与03-A实施报告.md、27-INSTRUMENT-03-A-DDL执行前核验与B1锁方案报告.md
- 冻结基线：22/23/24 号文档 V2.0
- 授权范围（负责人原文）：仅执行 `20261015_instrument_03_schema.sql` §1 五张表建表 DDL；禁止其他数据库写入、菜单授权及测试数据插入

---

## A. DDL 执行记录（03-A）

### A.1 实际执行环境

| 项 | 值 |
| --- | --- |
| 数据库 | 本地开发库 `labplatform`（§0.0 `DATABASE()` 确认） |
| MySQL 版本 | 8.0.12（符合基线） |
| 实例 | 本地开发实例，host `WIM-20240904RKP:3306` |
| 执行账号 | `bencao`（应用开发账号） |
| 执行方式 | mysql CLI 逐条执行程序化提取的 DDL 文件（`C:\temp\extract_instrument03_ddl.ps1` 从 SQL 设计稿按章节切分，防转录偏差；每个 ddl 文件头部补 `USE labplatform;` 会话指令） |
| 执行文件 | `e:\lixin\dev\ruoyi-vue-pro\sql\lab\20261015_instrument_03_schema.sql`（与 27 号报告审查通过版本一致，§0.0 在位，§1 恰好 5 条 CREATE TABLE，无其他写入语句） |

### A.2 §0 预检结果（全部只读）

| 项 | 结果 |
| --- | --- |
| 0.1 目标库与版本 | PASS：`labplatform` / 8.0.12 |
| 0.2 字符集环境 | PASS（备注，不阻断）：库默认 utf8/utf8_general_ci，但 5 张新表 DDL 均为表级显式 `utf8mb4/utf8mb4_unicode_ci ROW_FORMAT=Dynamic`，与既有 INSTRUMENT-01/02 表一致，实际生效为表级定义 |
| 0.3 五张目标表不存在 | PASS：计数 0 |
| 0.4 依赖表齐全 | PASS：device/manager/platform/room 等 4 张依赖表在位 |
| 0.5 既有 11 张 INSTRUMENT-01/02 表完整 | PASS |
| 0.6 连接环境 | PASS：本地开发实例 |

任一不通过即 HOLD 的停止条件未触发，进入 §1 执行。

### A.3 五条 CREATE TABLE 执行记录（逐条，未批量忽略错误）

| 序 | 表 | 结果 | 执行时刻 | 耗时 |
| --- | --- | --- | --- | --- |
| 1 | `lab_instrument_reservation` | 成功（exit=0） | 2026-10-15 23:41:06 | 214ms |
| 2 | `lab_instrument_reservation_history` | 成功（exit=0） | 2026-10-15 23:41:06 | ~150ms |
| 3 | `lab_instrument_booking_rule` | 成功（exit=0） | 2026-10-15 23:41:07 | ~160ms |
| 4 | `lab_instrument_booking_window` | 成功（exit=0） | 2026-10-15 23:41:07 | ~170ms |
| 5 | `lab_instrument_maintenance` | 成功（exit=0） | 2026-10-15 23:41:07 | ~180ms |

异常处理条款未触发（5/5 一次成功，无部分成功、无失败重试、无 DROP/ALTER/回滚）。

### A.4 §2 执行后验收结果（全部 PASS）

| 项 | 结果 |
| --- | --- |
| 五张目标表存在，数量 5 | PASS（`lab_instrument%` 总数 16 = 11 既有 + 5 新建） |
| 既有 11 张表仍在位 | PASS |
| 列数 24/21/20/20/15 | PASS（reservation/history/rule/window/maintenance） |
| 字段名、类型、NULL 规则、默认值与 DDL 一致 | PASS（`SHOW CREATE TABLE` 逐表比对） |
| `tenant_id`/`deleted`/审计字段 | PASS |
| `uk_reservation_tenant_no(tenant_id, reservation_no)` | PASS，列顺序正确 |
| `uk_rule_tenant_device(tenant_id, device_id)` | PASS，列顺序正确 |
| 预约/维护/窗口查询索引（idx_device_time 等） | PASS |
| `allow_cross_day` bit(1) NULL 可空 | PASS（B7：无隐式默认值） |
| 五张新表均为空 | PASS（0 行） |
| 既有设备 2 行（id=1/2） | PASS，未变 |
| 既有 manager 3 行 | PASS，未变 |
| 其他业务表/菜单/角色未被修改 | PASS（写入范围核对见 D 部分） |

### A.5 EXPLAIN 实测（只读）

| 查询 | 执行计划 |
| --- | --- |
| 预约冲突查询（按 device_id + 时间区间） | `type=range, key=idx_device_time, key_len=13, Extra=Using index condition` |
| 维护冲突查询（同型） | `type=range, key=idx_device_time, key_len=13, Extra=Using index condition` |

两条冲突查询在真实表结构上均可命中 `idx_device_time`；空表下优化器选择与预期一致，无需记录偏离。

### A.6 03-A 关闭结论

- 预检全 PASS → 5/5 建表成功 → §2 全 PASS → EXPLAIN 证实索引可用 → 既有数据保护核验通过。
- 26 号报告第十一条 CONDITIONAL 项 1（SQL 未执行）闭环；26/27 号报告已追加"后续状态"段（原始审查证据未改动）。
- **03-A 于 2026-10-15 正式关闭（PASS）。**

---

## B. 03-B 开发记录（INSTRUMENT-03-B-BOOKING-RULE-WINDOW-01）

DDL 阶段 PASS 后按任务书连续推进，未再等待授权下发。

### B.1 后端代码文件清单

| 文件 | 说明 |
| --- | --- |
| `enums/ErrorCodeConstants.java`（修改） | 新增规则 1_002_004_100~104（23 §5.2 冻结分配）、窗口 105~109（见 B.2 说明） |
| `controller/admin/instrument/vo/rule/InstrumentBookingRuleRespVO.java` | 规则全量 14 字段 RespVO |
| `controller/admin/instrument/vo/rule/InstrumentBookingRuleSaveReqVO.java | deviceId/enabled @NotNull，其余可空（B10 草稿语义） |
| `controller/admin/instrument/vo/window/InstrumentBookingWindowPageReqVO.java` | extends PageParam，deviceId @NotNull |
| `controller/admin/instrument/vo/window/InstrumentBookingWindowSaveReqVO.java` | id（修改必填服务层校验）/deviceId/windowName @NotNull |
| `controller/admin/instrument/vo/window/InstrumentBookingWindowRespVO.java` | 窗口 RespVO（含 usedCount 只读） |
| `service/instrument/InstrumentBookingRuleService.java` | getRule（未配置返回 null）/saveRule（返回 id）/getEffectiveRule（03-C P3 判定口径） |
| `service/instrument/InstrumentBookingRuleServiceImpl.java` | 校验 + 设备行锁内 upsert |
| `service/instrument/InstrumentBookingWindowService.java` | getPage/create/update/delete |
| `service/instrument/InstrumentBookingWindowServiceImpl.java` | 校验 + 设备行锁内写操作 |
| `controller/admin/instrument/InstrumentBookingRuleController.java` | `/lab/instrument/booking-rule` get/save |
| `controller/admin/instrument/InstrumentBookingWindowController.java` | `/lab/instrument/booking-window` page/create/update/delete |
| `src/test/java/.../instrument/Instrument03BBookingRuleWindowTest.java` | 17 个用例（H2 隔离库） |

以上路径根：`e:\lixin\dev\ruoyi-vue-pro\yudao-module-lab\src\main\java\cn\iocoder\yudao\module\lab\`（测试在 `src/test/java` 同包）。

### B.2 错误码分配说明（设计补充，需负责人备案）

23 §5.2 冻结表显式分配了规则段（100~104）与维护段（110~119），未显式分配窗口段。本批取未占用的 **105~109** 作为窗口错误码（NOT_EXISTS/DEVICE_INVALID/CONFIG_INVALID/CAPACITY_BELOW_USED/USED_DELETE_DENIED），114、116~119 保留未动。该补充不改变任何已冻结分配，如负责人另有裁决可重映射（仅常量定义处一处改动）。

### B.3 关键业务实现与任务书要求对照

| 任务书要求 | 实现 |
| --- | --- |
| 6.1-① 一设备一条有效规则 | `uk_rule_tenant_device(tenant_id, device_id)` 唯一索引 + 服务层 selectByDeviceId upsert（单测 upsertSameRow 证实同设备仅一行且 id 不变） |
| 6.1-② 未启用/配置不完整不得开放预约 | `getEffectiveRule`：enabled=true 且 granularity/minDuration 非空才返回 DO；03-C 预约创建必须以该口径判定（F15/B10） |
| 6.1-③ 配置校验 | granularity/min/max、开放日 [1-7]、开放时段 HH:mm 成对且 start<end、可预约天数 >=0（102/103/104 分码） |
| 6.1-④ allow_cross_day | B7：列 bit(1) NULL，业务层 `Boolean.TRUE.equals` 判定，前端关闭或未设置均提交未设置 |
| 6.1-⑤ U1/U2/U3 未裁决参数 | granularity/minDuration 无默认值预填（B10），前端 placeholder 明示"启用预约时必填"，后端启用时缺失即拒 |
| 6.1-⑥ 设备行锁协议 | 规则 save 在 `transactionTemplate` 内 `selectByIdForUpdate(deviceId)` 行锁后 upsert，与 03-C 预约创建共享锁协议（23 §7.3） |
| 6.2 窗口 CRUD | page（按设备、sort asc/id desc）/create（默认 ACTIVE、usedCount=0）/update/delete 全落地 |
| 6.2-⑤ 窗口不绕过设备可预约状态 | 窗口接口不修改 device.bookable；可预约开关仍由设备接口管理（B5 状态分离） |
| 6.2-⑥ 容量语义 | capacity 为窗口累计可约能力；update 时 capacity < usedCount 拒绝（108）；容量扣减动作（P9 条件更新）留 03-C，本批未接入任何计数写入 |
| 6.2-⑦ 未来已有预约的窗口修改 | 当前安全限制：capacity<usedCount 拒绝（108）、usedCount>0 禁删（109）、状态可 CLOSED 不再放量；"有未来预约时禁改时段/日期"等进一步联动限制在 03-C 预约数据路径落地后按 24 号 03-D 批次补充（当前库中无预约数据，无静默破坏风险面） |
| 6.4 权限与数据范围 | Controller `@PreAuthorize lab:instrument:rule:query/update` + Service 层 `scopeSupport.canManageAll`（super_admin/lab_admin）独立校验；908 即便拥有菜单也不放行（B9-⑤，单测 permissionDenied 证实）；窗口与规则同权限面 |
| F14 target_week_mapping | 仅文本存储与展示，前后端均不做业务化推断 |

### B.4 前端代码文件清单

| 文件 | 说明 |
| --- | --- |
| `src/api/lab/instrument/booking-rule/index.ts` | 规则 get/save API + VO |
| `src/api/lab/instrument/booking-window/index.ts` | 窗口 page/create/update/delete API + VO |
| `src/views/lab/instrument/booking-config/index.vue` | 仪器规则配置页：设备下拉（InstrumentDeviceApi.getPage，可搜索）+ 预约规则 Tab（表单编辑、启用开关、开放日多选、时段、跨天开关）+ 开放窗口 Tab（表格/分页/新增/修改/删除 Dialog） |

前端规范沿用：Vue3 script setup、Element Plus、ContentWrap/Pagination/Dialog 组件、`v-hasPermi`（`lab:instrument:rule:update`）、`useMessage`。未新增菜单 SQL、未修改真实库菜单。

### B.5 编译与测试结果

| 项 | 结果 |
| --- | --- |
| 后端 test-compile | BUILD SUCCESS |
| 本批单测 `Instrument03BBookingRuleWindowTest` | 17/17 PASS（H2 隔离库，`@MockBean PermissionApi`，未触真实库） |
| lab 模块全量单测 | 114/114 PASS（含回归：Instrument02ServiceTest 26、Instrument03DataLayerTest 23 等） |
| 前端 TypeScript 检查 | 见 B.7 |

测试过程中发现并修复项（均在本批新增代码内，无既有代码改动）：
1. 测试 `selectListByMap` 不存在 → 改 `selectCount()`；测试内非 effectively-final 变量重构为独立命名。
2. 错误码分界修正：`minDuration <= 0` 属"时长配置非法"归 103；102 限定粒度非法与启用时最短时长缺失（B10 配置不完整）。测试预期与实现同步对齐。
3. 窗口 update 缺陷：新 DO 未回填 id 导致 `updateById` 0 行更新，已修复（`window.setId(updateReqVO.getId())`），由 testWindow_update 证实。
4. **既有环境问题（非本批引入）**：本机 JDK 21 运行单测时，项目内旧版 Byte Buddy 无法对 class 打桩，`Instrument02ServiceTest` 26 用例报 `Java 21 (65) is not supported`。已在 `yudao-module-lab/pom.xml` 的 surefire `argLine` 固化 `-Dnet.bytebuddy.experimental=true` 修复，仅影响测试 JVM 参数，不影响生产构建。

### B.6 权限与数据范围实现汇总

- 权限串仅两个：`lab:instrument:rule:query`（get/page）、`lab:instrument:rule:update`（save/create/update/delete），按 23 §4.5 仅授 906 lab_admin；904 不涉本批接口；908 无权（前后端一致，前端按钮 `v-hasPermi` 仅是显示层，后端双重校验为准）。
- 设备负责人有效性：本批接口为配置类，数据范围按"仅管理员"实施（与 04 §5.2 配置类矩阵一致），不涉及 908 授权范围判定；03-C 起的预约业务将复用 `canManageDevice`/`getManagedDeviceIds`。

### B.7 前端 TypeScript 检查

- **本批新增 3 个文件（booking-rule API、booking-window API、booking-config 页面）：0 错误，通过。**
- 全量 `npm run ts:check` 存在 14 个**既有存量错误**（`src/api/lab/announcement`、`src/views/fms/report`、`src/views/hrm/employee`、`src/views/lab/v2/plasmid*` 等），均为本批之前遗留，与本批改动无关，未纳入本批修复范围（避免越权改动其他模块）。

### B.8 页面验收情况与未解决问题

| 项 | 状态 |
| --- | --- |
| 代码交付 + 隔离单测 + 编译 + TS 检查 | 已完成 |
| 浏览器页面交互验证 | **待授权**：页面联调需运行 yudao-server（依赖真实库连接配置）与管理员登录；任务书规定浏览器端到端如依赖真实库写入/真实环境操作，标记待授权，不得伪报通过。本批未向真实库插入任何菜单或测试数据 |
| 菜单配置 | 未创建（无授权）。页面经开发调试方式访问（直连路由），正式可见性需负责人后续下发菜单 SQL 授权 |

### B.9 是否满足 03-B 关闭条件

- 6.1/6.2/6.3/6.4 全部实现项：已完成。
- 6.5 十项测试中：后端编译（1）、单元测试（2）、规则 1:1（3）、非法参数（4）、窗口 CRUD（5）、租户隔离（6，TenantBaseDO + H2 租户上下文，全用例在租户上下文内跑通）、未配置规则不可预约判定（7）、权限与数据范围（8）——通过；前端 TS（9）见 B.7；页面交互（10）待授权。
- **结论：满足"代码完成 + 隔离测试关闭"条件；页面浏览器验收一项待授权后补录。**

---

## C. B1 并发风险（只读分析补充，未实施）

| 项 | 状态 |
| --- | --- |
| `RLock.lock(10_000ms)` 固定租约无 watchdog | **仍存在**（26 号 CONDITIONAL 结论不变）。03-B 未触碰任何预约创建路径 |
| 修复方案 | 27 号 §7.3 方案（watchdog 续期 + 外层锁协调 + 内层 TransactionTemplate + 设备行锁 + fail-closed）维持为 03-C 技术实施候选，本批仅复核设计，未写代码 |
| createSuspend 固定 10s 锁与预约 watchdog 兼容性 | 27 号 §4 分析结论不变：暂停已是"外层 Redis 锁 → 内层 TransactionTemplate"结构，锁序 `suspendKey → 设备行锁`；03-C 预约若引入 watchdog 需保证锁序一致且不反向嵌套，实施时须做锁占用时长对比验证 |
| Redis 锁所有权丢失竞态 | 27 号 §4.3 fail-closed 条款覆盖；具体竞态注入测试留 03-C（见下） |
| REPEATABLE-READ 快照/当前读 | 03-A 事务首语句 `selectByIdForUpdate`（当前读）时点正确性已在 27 号论证；03-C 实施时以真实库并发验证 |
| 03-C 全部预约写入路径统一设备锁协议 | 03-B 规则/窗口写路径已按 `transactionTemplate + selectByIdForUpdate` 落地，为 03-C 提供了协议样板；03-C 必须同样收敛 |
| **03-C HOLD** | **维持**。不因 03-B 落地或"将采用 watchdog"而自动解除；解除标准见 27 号 §5.2 |
| 下一阶段测试计划 | 27 号 §5.1：真实 Redis+MySQL 并发预约/暂停交错、锁租约耗尽注入、锁所有权丢失注入、RR 当前读验证、同行锁串行化验证 |

---

## D. 数据库写入边界（正式声明）

**本任务在真实数据库 `labplatform` 中仅执行经负责人授权的 `20261015_instrument_03_schema.sql` §1 五条 CREATE TABLE DDL。**

| 写入类型 | 次数 |
| --- | --- |
| 授权范围内 CREATE TABLE | 5 |
| 其他 DDL（ALTER/DROP/CREATE 其他对象等） | 0 |
| DML（INSERT/UPDATE/DELETE 业务数据） | 0 |
| 菜单写入/授权 | 0 |
| 角色授权（904/908/906 相关） | 0 |
| 测试数据插入 | 0（03-B 单测全部在 H2 隔离库完成） |

既有业务数据保护核验：设备 2 行（id=1/2）、manager 3 行执行前后一致；11 张既有表结构与数据未变。

---

## 附：03-B 后端单测覆盖清单（17 用例）

规则：upsert 1:1、设备不存在 101、粒度缺失/非正 102、min>max 与 min<=0 与 max<=0 103、开放时段成对/格式/开放日越界/天数负值 104、草稿可存空粒度、getEffectiveRule 三态（未配置/未启用/完整启用）、权限拒绝 038；
窗口：create 默认值+分页、update 容量边界（108 拒绝、==usedCount 可过）、105/106、配置非法 107/104、删除（未使用可删、usedCount>0 拒绝 109、不存在 105）、窗口权限拒绝、DO 租户字段继承断言。

---

## 后续状态（2026-10-16 追加，原始结论未改动）

- **错误码 105~109 已正式备案**：负责人接受本批窗口错误码 105~109 作为设计补充，已于 2026-10-16 写入 23 号文档 §5.2（规则/维护段 100~119），与既有 080~104、110~119 无冲突（TASK INSTRUMENT-03-B-C-PREP-01）。
- **CAP-A 裁决（2026-10-16）**：负责人正式选择"开放窗口容量**按日期独立计算**"，**取代本报告 B.2 中"窗口整个周期共享累计容量"的设计口径**。本报告 B 部分描述的 `used_count` 累计口径及 `updateUsedCountIncrIfAvailable` 周期扣减方法自 CAP-A 起标记为**旧口径、待迁移**，不得接入正式预约扣减；新日期容量明细模型与 SQL 设计稿见 29 号报告 B 部分及 `sql/lab/20261016_instrument_03_capacity_daily_design.sql`（仅设计稿，未执行）。
- **03-B 验收收尾**：页面只读交互、隔离写入验证、菜单可见性状态、03-B 正式验收结论见 29 号报告 A 部分。
