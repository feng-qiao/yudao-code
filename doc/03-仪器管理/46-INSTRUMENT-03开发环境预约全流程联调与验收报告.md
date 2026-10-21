# 46 - INSTRUMENT-03 开发环境预约全流程联调与验收报告

- 任务编号：TASK INSTRUMENT-03-R9-DEV-END-TO-END-01
- 执行日期：2026-10-20（Asia/Shanghai）
- 环境：负责人确认的本地开发环境（非生产）
- 最终判定：**FULL PASS**
- 报告范围：D0～D9 合并连续执行；测试数据全部保留，未做清理

---

## 一、环境、profile、C7 开启及回退证据

| 项 | 值 |
|---|---|
| 前端 | http://localhost（登录页 /login?redirect=/index） |
| 后端 | http://127.0.0.1:48080（context-path `/admin-api`） |
| 数据库 | MySQL 8.0.12 / `labplatform` / 127.0.0.1:3306 |
| Redis | 127.0.0.1:6379 |
| 租户 / 套餐 | 162（成都中医药大学） / 114 |
| 运行 profile | `local`（`application.yaml` 中 `spring.profiles.active: local`，启动命令行无 profile 覆盖） |

### C7 生命周期（关键证据）

| 阶段 | 动作 | 证据 |
|---|---|---|
| 开启前 | `create-enabled` 默认 false | 44 号报告基线状态 |
| D5.1 开启 | `application-local.yaml` 配置 `lab.instrument.reservation.create-enabled: true` | 配置文件实际内容 |
| 重启① | 负责人在 IDEA 重启后端 | 新进程 PID **18392**，启动日志 `Started YudaoServerApplication`（2026-10-20 08:29:34） |
| D5.3 生效确认 | T01 首次调用 `reservation/create` 返回 **code=0，data=1**（写入成功） | C7=true 在服务端确实生效（若未生效应返回 116） |
| D8.1 回退 | 配置改回 `lab.instrument.reservation.create-enabled: false` | 配置文件实际内容 |
| 重启② | 负责人在 IDEA 再次重启 | 新进程 PID **17792**，端口 48080 监听，启动日志 `Tomcat started on port(s): 48080`、`Started YudaoServerApplication`（2026-10-20 09:17:33，耗时 11.83s） |
| D8.4 回退验证 | 以 test906（具备 `reservation:create` 权限）调用 create | **code=1002004116「预约创建功能未启用，请联系管理员」** → C7 已确实关闭 |

- 说明：D0 阶段的旧 PID（44 号报告时期）未被沿用，全部结论以重启后的实时进程与行为为准。
- `include-freeze-batch`：配置文件中出现次数 **0**，未被误启用（符合 D5.1 要求）。

---

## 二、使用的账号及真实角色集合

账号均来自负责人提供清单，并以数据库真实 `username` + 实际登录成功结果为准（未修改任何既有用户名）：

| 账号 | user_id | tenant | 实际角色（单一） | 说明 |
|---|---|---|---|---|
| 189140001 | 265 | 162 | 普通用户（904） | 普通用户 B，合法预约/取消/调整/数据隔离 |
| 189140002 | 281 | 162 | 普通用户（904） | 普通用户 A，历史 SUSPENDED 资质 + ALL ACTIVE 暂停（风险复核对象，未参与合法预约） |
| test906 | 282 | 162 | lab_admin（906） | 完成/作废/暂停/资质审批链路 |
| test908 | 283 | 162 | instrument_device_manager（908） | 设备负责人，DEVICE/2 数据范围 |
| test905 | 284 | 162 | lab_keeper（905） | 无仪器预约权限（拒绝用例） |
| test904nq | 285 | 162 | 普通用户（904） | 无 dev2 有效资质（无资质拒绝用例） |

- 均属租户 162；`status=0`（启用）；`deleted=0`。
- **所有测试账号均为纯净单角色**，未使用联合角色账号（例如 908+904 联合账号）代替纯净角色做拒绝测试。
- 全程未新增/修改任何账号角色，未修改既有用户密码或资料（如 qinghy、bencao 角色未变）。

---

## 三、设备、规则、资质、信用账户及负责人关系

### 设备（`tenant_id=162`，全部 `deleted=0`）

| id | 名称 | 类别 | 状态 | bookable |
|---|---|---|---|---|
| 1 | 验收测试酶标仪01 | MICROPLATE_READER | SCRAPPED | 1 |
| 2 | Clean Device 02 | SCIENCE | NORMAL | 1 |
| 3 | R9验收并发测试设备03 | SCIENCE | NORMAL | 1 |

- 主测试设备 = device 2；跨设备并发测试使用 device 3（本次通过正式设备管理 API 新建的专用测试设备）。
- **未将任何 SCRAPPED 设备改成 NORMAL** 来充当测试条件（device 1 保持 SCRAPPED，作为 T04 拒绝用例）。

### 预约规则（`lab_instrument_booking_rule`）

| id | device | open_days | 开放时段 | 粒度 | 时长范围 | 可提前天数 | 跨日 | enabled |
|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 1,2,3,4,5（工作日） | 09:00–18:00 | 30 min | 30–240 min | 0–7 | 否（0） | 1 |
| 2 | 3 | 1,2,3,4,5（工作日） | 09:00–18:00 | 30 min | 30–240 min | 0–7 | 否（0） | 1 |

- `lab_instrument_booking_window` 行数 = **0**（SCIENCE 设备不使用微孔板窗口模型，未被误创建）。

### 资质（`lab_instrument_qualification`）

| id | user | target | 状态 | expire_time |
|---|---|---|---|---|
| 1 | 281 | DEVICE/2 | SUSPENDED | NULL |
| 2 | 281 | DEVICE/1 | ACTIVE | NULL |
| 3 | 265 | DEVICE/2 | ACTIVE | NULL |
| 4 | 265 | DEVICE/3 | ACTIVE | NULL |
| 5 | 282 | DEVICE/2 | ACTIVE | NULL |
| 6 | 285 | DEVICE/3 | ACTIVE | NULL |

- 申请单 `qualification_apply` id=3/4/5/6；申请+审批历史 `qualification_apply_history` = 12 行（SUBMIT/APPROVE 各 4，审批人 278）。
- 资质均通过**正式申请 + 正式审批 API** 产生，**未直接 UPDATE status 制造 ACTIVE**。
- 285 始终**无** dev2 有效资质（保持为无资质拒绝测试身份）；test905 未授予任何预约资质。

### 信用账户（首次资质审批副作用）

| 账号 | 初始分 | 备注 |
|---|---|---|
| 281 | 70 | 历史扣分（既有数据，未重置） |
| 265 | 100 | 首次审批通过初始化 100 |
| 282 | 100 | 首次审批通过初始化 100 |
| 285 | 100 | 首次审批通过初始化 100 |

- 信用流水 `credit_flow` 3 行，全部为 281 的历史 `DEDUCT` 记录；**初始化不写流水**（与既有行为一致）。未为通过资质而直接修改余额。

### 设备负责人关系（`lab_instrument_manager`）

| id | scope | target | role_type | user | 状态 | 备注 |
|---|---|---|---|---|---|---|
| 1 | ROOM_REPAIR | 1 | REPAIR | 265 | RELEASED | 既有记录，未改动 |
| 2 | ROOM_REPAIR | 1 | REPAIR | 281 | ACTIVE | 既有记录，未改动 |
| 3 | ROOM_REPAIR | 1 | REPAIR | 265 | ACTIVE | 既有记录，未改动 |
| **4** | **DEVICE** | **2** | **PRIMARY** | **283** | **ACTIVE** | **本次 R9 通过正式管理 API 建立** |

---

## 四、T01～T24 逐项结果

| 编号 | 场景 | 预期 | 实际（code / DB 影响） | 判定 |
|---|---|---|---|---|
| T01 | 有资质用户合法创建 | PENDING + 单号 + CREATE 历史 | code=0，id=1，`R2026102000001`，PENDING，duration=120，qualification_id=3；历史 CREATE(USER) | **PASS** |
| T02 | 无资质 904 创建 | 资质拒绝，无写入 | 1002004085「缺少有效使用资质」；reservation 仍 1 行 | **PASS** |
| T03 | 生效暂停用户创建 | 暂停拒绝，无写入 | 1002004086「账号存在生效的使用暂停」；无写入 | **PASS** |
| T04 | SCRAPPED 设备创建 | 设备状态拒绝 | 1002004082「设备当前状态不可预约」（P1 先于资质校验）；无写入 | **PASS** |
| T05 | 未开放时段创建 | 时间范围拒绝 | a) 今日 18:00–19:00 → 1002004087；b) 10-24（周六）→ 1002004087；c) 10-28（+8 天）→ 1002004087；均无写入 | **PASS** |
| T06 | 同设备重叠创建 | 冲突拒绝 | 1002004093「预约时段已被占用」（与 id=1 重叠）；无写入 | **PASS** |
| T07 | 相邻时间段创建 | 创建成功 | code=0，id=3，11:00–13:00（end=start 相邻）成功 | **PASS** |
| T08 | 不同设备并发创建 | 互不影响，无死锁 | 双 Job 并发：dev2 → id=4 成功；dev3 → id=5 成功；无异常/无死锁 | **PASS** |
| T09 | 同设备并发竞争 | 按锁与冲突规则仅允许合法结果 | B 与 906 同时抢 dev2 15:00–16:00：B → id=6 成功（code=0）；906 → 1002004093；DB 同时段仅 1 行 | **PASS** |
| T10 | 904 查询本人预约 | 仅本人数据 | `/my` 返回 4 条（id=1,4,5,6），全部 userId=265；`/page` 同范围 | **PASS** |
| T11 | 904 查询他人预约 | 不可见或拒绝 | B 查 id=3 → 1002004080「预约不存在」；A(281) 查 id=1 → 1002004080（不泄露存在性） | **PASS** |
| T12 | 908 查询授权设备 | 仅授权设备范围 | `/page` 返回 5 条，deviceId 全部 = 2，**不含 dev3 的 id=2、5** | **PASS** |
| T13 | 908 越权访问其他设备 | 拒绝 | `get?id=2`(dev3) → 1002004080；`finish id=5`(dev3) → 1002004097「当前状态不可登记完成」(FINISH_DENIED)；id=5 仍 PENDING 未变更 | **PASS** |
| T14 | 905 访问预约管理 | 权限拒绝 | `/page` → code=403「没有该操作权限」；`create` → code=403；无写入 | **PASS** |
| T15 | 904 取消本人预约 | CANCELED + CANCEL 历史 | code=0；id=1 → CANCELED，cancel_by=USER；历史新增 CANCEL(USER) | **PASS** |
| T16 | 904 调整本人预约 | 重走准入 + ADJUST 历史 | code=0；id=4 → 13:30–14:30；历史 ADJUST 记录 before=13:00–14:00 / after=13:30–14:30 | **PASS** |
| T17 | 908 管理授权设备预约 | 符合角色与设备范围 | code=0；908 取消 id=4（dev2，填 reason）→ CANCELED，cancel_by=MANAGER；历史 CANCEL(MANAGER) | **PASS** |
| T18 | 906 完成预约 | FINISHED + FINISH 历史 | code=0；id=3 → FINISHED，actual 11:00–12:30；历史 FINISH(ADMIN) before/after 完整 | **PASS** |
| T19 | 906 作废预约 | VOIDED + VOID 历史 | code=0；id=6 → VOIDED；历史 VOID(ADMIN) | **PASS** |
| T20 | 非法状态流转 | 拒绝，无异常写入 | a) 重复取消 id=1 → 1002004094(CANCEL_DENIED)；b) 完成 CANCELED 的 id=1 → 1002004097(FINISH_DENIED)；c) 作废 FINISHED 的 id=3 → 1002004098(VOID_DENIED)；状态未变、历史 0 新增 | **PASS** |
| T21 | 预约号唯一性 | tenant+no 无重复 | `GROUP BY tenant_id,reservation_no HAVING COUNT(*)>1` → **空**；7 个单号 `R2026102000001`～`R2026102000007` 唯一 | **PASS** |
| T22 | 历史事务一致性 | 主记录与历史一致 | 见第五节（逐条比对一致） | **PASS** |
| T23 | 资质/暂停/规则变更后准入 | 使用最新服务端状态 | a) 285 暂停解除后 create dev3 → 成功 id=2（证明暂停解除即时生效）；b) id=1 取消后其时段再约 → 成功 id=7（证明 CANCELED 不占时段） | **PASS** |
| T24 | 浏览器页面及按钮权限 | 与角色权限一致 | 见第六节 | **PASS** |

---

## 五、创建的预约 ID、状态及历史核验

### 预约主记录（`lab_instrument_reservation`，共 7 条，全部 tenant_id=162）

| id | 单号 | 设备 | 用户 | 时段 | 状态 |
|---|---|---|---|---|---|
| 1 | R2026102000001 | 2 | 265 | 2026-10-20 09:00–11:00 | CANCELED |
| 2 | R2026102000002 | 3 | 285 | 2026-10-20 10:00–11:00 | PENDING |
| 3 | R2026102000003 | 2 | 282 | 2026-10-20 11:00–13:00 | FINISHED |
| 4 | R2026102000004 | 2 | 265 | 2026-10-20 13:30–14:30（原 13:00–14:00） | CANCELED |
| 5 | R2026102000005 | 3 | 265 | 2026-10-20 09:00–10:00 | PENDING |
| 6 | R2026102000006 | 2 | 265 | 2026-10-20 15:00–16:00 | VOIDED |
| 7 | R2026102000007 | 2 | 282 | 2026-10-20 09:30–10:30 | PENDING |

### 历史记录（`lab_instrument_reservation_history`，共 12 条）与主记录一致性

| 预约 | 历史动作序列 | 一致性 |
|---|---|---|
| 1 | CREATE(USER→PENDING) → CANCEL(USER→CANCELED) | 一致 |
| 2 | CREATE(USER→PENDING) | 一致 |
| 3 | CREATE(USER→PENDING) → FINISH(ADMIN→FINISHED) | 一致 |
| 4 | CREATE(USER→PENDING) → ADJUST(USER, before/after 时段) → CANCEL(MANAGER→CANCELED) | 一致 |
| 5 | CREATE(USER→PENDING) | 一致 |
| 6 | CREATE(USER→PENDING) → VOID(ADMIN→VOIDED) | 一致 |
| 7 | CREATE(USER→PENDING) | 一致 |

- 时间轴与状态流转均可由历史完整复现（A9「只增不改」原则成立）。
- 每次操作均记录了操作者、操作者角色（USER / MANAGER / ADMIN）与动作时间。

---

## 六、权限与数据隔离证据

### 角色—菜单/权限真值（`system_role_menu` + `system_menu`）

| 角色 | 仪器相关菜单/权限（关键项） |
|---|---|
| 904 普通用户 | device:query、qualification:query/apply、credit:query、suspend:query、**reservation:query/create/cancel/adjust**、「预约管理」+「我的预约」菜单；**无** rule:update、**无** reservation:manage |
| 905 lab_keeper | 仪器类权限为空（无任何仪器菜单） |
| 906 lab_admin | 平台/设备/房间/负责人/公告全量、qualification:audit/manage、credit:adjust、suspend:manage、rule:query/update、reservation 全量 + manage |
| 908 instrument_device_manager | device:query、qualification:query/audit、reservation:query/create/cancel/adjust/manage；**无** rule:query/update；**无** platform/room/manager/notice 等 |

- test905 在浏览器中**完全看不到**仪器菜单，直接访问 `/lab/instrument/reservation-manage` 落到 **404**（无权限路由）。
- 905 直接调用后端接口返回业务码 403，未发生任何数据写入。

### 数据范围隔离

- 904 用户（265）：`/my` 与 `/page` 均只返回本人预约（4 条），无法读取他人预约（返回 080 且不泄露存在性）。
- 908（283）：`/page` 仅返回授权设备 device 2 的预约，dev3 数据完全不可见；对 dev3 的写操作被拒绝。
- 双用户（265 / 282）与双设备范围（dev2 / dev3）隔离均得到验证。

---

## 七、并发测试结果

| 用例 | 场景 | 结果 |
|---|---|---|
| T08 | 不同设备并发（dev2 + dev3，2 个可控并发请求） | 两请求均成功（id=4、id=5），无异常、无死锁 |
| T09 | 同设备并发竞争（dev2 同一时段，2 个可控并发请求） | 恰 1 个成功（id=6），另 1 个返回 1002004093；数据库同时段仅 1 行有效记录 |

- 并发规模为**可控请求数**（每场景 2 个并发请求），未做无界压力测试。
- 结果表明设备行锁 + P8 冲突检测在高并发下仍能保证「同设备同时段唯一有效预约」的互斥语义。

---

## 八、历史资质与暂停风险结论

**对象：账号 A（user_id=281，189140002）**

| 项 | 现状 |
|---|---|
| 资质 | id=1 DEVICE/2 **SUSPENDED**；id=2 DEVICE/1 ACTIVE |
| 暂停 | id=3 `ALL` **ACTIVE**，区间 2026-10-15 16:55:10 ～ 2026-10-22 16:55:10（另有 id=1、id=2 已 RELEASED） |
| 自动到期机制 | **不存在**自动到期 Job → 暂停仅在人工解除后失效，到期时间不会自行使其失效 |

**风险链（本轮已定位，未做任何操作）**：

1. 解除暂停（`suspend/release`）会触发 `resumeUncoveredQualifications`，将 id=1（SUSPENDED）恢复为 ACTIVE。
2. 资质申请校验（`doApply`）仅拦截 **ACTIVE / PENDING**，**不拦截 SUSPENDED** → 账号 A 可在暂停期间再次申请 dev2 资质。
3. 若再次申请并通过，将出现 **同设备两条 ACTIVE 资质**（id=1 与新增记录）。
4. 创建链路 P4 使用 `qualificationMapper.selectActive(userId, deviceId)` 单值查询，双 ACTIVE 存在 **`TooManyResultsException`** 风险。

**本轮处置**：遵守任务书裁决要求，**未为账号 A 创建第二条同设备 ACTIVE 资质**，A 未参与合法预约测试；暂停与资质现状保持原样，等待负责人裁决。

**建议**（后续另立任务）：① `doApply` 增加 SUSPENDED 拦截；② `selectActive` 改为确定序取一条或增加唯一约束保护；③ 明确暂停到期语义（补自动失效 Job 或明确「仅人工解除」并同步文档）。

---

## 九、发现并修复的代码缺陷

**未发现需要修复的代码缺陷**（T01～T24 全部按预期工作，权限、隔离、并发、生命周期语义均正确）。因此**未修改任何仪器模块代码**，也未改动冻结的业务规则。

记录 2 项**非阻断观察项**（不影响验收判定，建议后续改进）：

| # | 观察项 | 位置 | 说明与影响 |
|---|---|---|---|
| 1 | 创建 VO 的 `@Schema example` 使用 `"yyyy-MM-dd HH:mm:ss"` 字符串，但框架全局 Jackson 使用 `TimestampLocalDateTimeDeserializer`（要求 **EpochMillis 数字**）；`@DateTimeFormat` 仅对 GET 参数生效 | [ReservationCreateReqVO.java](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument/vo/reservation/ReservationCreateReqVO.java) | 首次以字符串提交时被反序列化为 0 → 误判为 `1002004089 预约时间参数非法`；前端按框架约定传时间戳即正常。**建议修正示例注释**以免误用 |
| 2 | `ADJUST` 历史的 `after_status` 为 NULL（CREATE / FINISH / VOID 均有值） | [ReservationCreateExecutor.java](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/ReservationCreateExecutor.java) / 历史写入路径 | 调整不改变状态，语义可自洽，但不利于历史一致性解读。**建议统一补记状态字段** |

---

## 十、编译与自动化测试结果

| 项 | 命令 | 结果 |
|---|---|---|
| 编译 | `mvn compile -pl yudao-module-lab -am -DskipTests` | 退出码 **0**（成功） |
| 自动化测试 | `mvn test -pl yudao-module-lab -Dtest='Instrument03*Test,Instrument02ServiceTest'` | 退出码 **0** |

测试用例明细（surefire 报告）：

| 测试类 | 用例数 | 失败 | 错误 | 跳过 |
|---|---|---|---|---|
| Instrument02ServiceTest | 26 | 0 | 0 | 0 |
| Instrument03BBookingRuleWindowTest | 18 | 0 | 0 | 0 |
| Instrument03ConcurrencyTest | 4 | 0 | 0 | 0 |
| Instrument03CReservationCreateTest | 32 | 0 | 0 | 0 |
| Instrument03DataLayerTest | 21 | 0 | 0 | 0 |
| Instrument03DLifecycleTest | 21 | 0 | 0 | 0 |
| Instrument03LockCoordinatorTest | 3 | 0 | 0 | 0 |
| Instrument03R2AdjustT1T2Test | 11 | 0 | 0 | 0 |
| Instrument03R2PermissionAnnotationTest | 4 | 0 | 0 | 0 |
| Instrument03IsolationGuardTest | 7 | 0 | 0 | 0 |
| （同批次一并执行的）PlasmidStorageServiceImplTest | 17 | 0 | 0 | 0 |
| RegisterApplyServiceImplTest | 31 | 0 | 0 | 0 |
| **合计** | **195** | **0** | **0** | **0** |

---

## 十一、执行前后数据库行数对比

基线值取自 R9 执行前备份文件（`instrument03-r9-pretest-baseline-20261020T081246.sql`）；终值取 C7 回退验证通过后。

| 表 | 基线 | 终值 | 变化 | 说明 |
|---|---|---|---|---|
| lab_instrument_booking_rule | 1 | 2 | +1 | 新增 dev3 规则（id=2） |
| lab_instrument_booking_window | 0 | 0 | 0 | 未误创建窗口 |
| lab_instrument_qualification | 2 | 6 | +4 | 新增 id=3/4/5/6 |
| lab_instrument_qualification_apply | 2 | 6 | +4 | 新增 apply 3/4/5/6 |
| lab_instrument_qualification_apply_history | 4 | 12 | +8 | SUBMIT/APPROVE 各 4 |
| lab_instrument_manager | 3 | 4 | +1 | 新增 id=4（DEVICE/2/283） |
| lab_instrument_suspend | 3 | 4 | +1 | 新增 id=4（285 SINGLE dev3，已 RELEASED） |
| lab_instrument_reservation | 0 | 7 | +7 | T01～T23 产生的预约 |
| lab_instrument_reservation_history | 0 | 12 | +12 | 对应 CREATE/CANCEL/ADJUST/FINISH/VOID |
| lab_instrument_credit_account | 1 | 4 | +3 | 首次审批初始化 100 分 |
| lab_instrument_credit_flow | 3 | 3 | 0 | 初始化不写流水 |
| lab_instrument_device | 2 | 3 | +1 | 新增 dev3 测试设备 |

- **C7 回退验证后行数未再变化**（reservation 仍 7、history 仍 12），证明回退过程中无意外写入。
- 未触碰其他租户数据，未对无关业务模块做任何改动，未执行任何 DDL。

---

## 十二、备份路径及 SHA-256

| 项 | 内容 |
|---|---|
| R9 执行前备份 | `E:\lixin\dev\backup\instrument03\instrument03-r9-pretest-baseline-20261020T081246.sql` |
| 大小 | 63,538 字节（非空，可检查） |
| SHA-256 | `892273195E977EB29A81416BE07A46AEC10FC95D2A7AD7AE522FEB175982A581` |
| 覆盖范围 | 14 张受影响业务表（含预约/历史、规则、窗口、设备、负责人、资质三表、暂停、信用账户与流水等） |
| 存储位置 | `E:\lixin\dev\backup\...` —— **非 Git 目录** |
| 同目录其他备份 | `instrument03-r8-stage1-baseline-20261020T001157.sql`（55,287 字节）、`instrument03_menu_backup_20261019_182236.sql` |

- 44 号报告基线备份在 D1 已核验存在且 SHA-256 与记录一致。
- 依据任务书要求：**未自动执行任何备份恢复**。

---

## 十三、最终 C7 状态

**已确认回退为 `false`**：

- 配置文件：`lab.instrument.reservation.create-enabled: false`
- 运行进程：PID 17792（2026-10-20 09:17:33 重启），profile `local`，端口 48080 正常监听
- 行为验证：以具备 create 权限的 test906 调用创建接口，返回 **1002004116「预约创建功能未启用，请联系管理员」**
- 数据完整性：7 条预约、12 条历史记录**全部保留未丢失**；只读查询接口（`/my`）返回 code=0，功能正常
- `include-freeze-batch` 保持未启用（出现次数 0）

> 回退状态：**ROLLBACK DONE**（非 PENDING/HOLD）。

---

## 十四、未解决问题与后续建议

### 未解决问题（均不阻断本次验收判定）

1. **账号 A（281）历史资质与暂停风险**（见第八节）：存在「解除暂停恢复旧资质 + 可再申请 → 双 ACTIVE → TooManyResultsException」链路。本轮按裁决未操作，等待负责人决定修复方案。
2. **观察项 1**：创建 VO 示例时间格式与框架 EpochMillis 约定不一致，易误用。
3. **观察项 2**：ADJUST 历史 `after_status` 为 NULL。
4. 浏览器验证中发现：设计上「新建预约」入口位于**仪器大厅/设备详情**（`device-detail` 的 `ReservationForm`），而非「我的预约」列表页；列表页不提供新建按钮。此为**设计事实，非缺陷**，已按实际入口完成核验。

### 后续建议

1. 针对账号 A 风险单独立任务，按第八节建议修复 `doApply` 的 SUSPENDED 拦截与 `selectActive` 的确定性取值。
2. 修正创建 VO 的时间格式示例注释，并在接口文档中明确「时间字段使用 EpochMillis」。
3. 统一历史表 `after_status` 补记策略（含 ADJUST）。
4. 本轮全部测试数据（账号、设备 3、规则 2、资质、负责人关系、暂停、7 条预约及 12 条历史）**按要求保留**，未做清理，请负责人决定后续处置。
5. 后续如需跨日预约、窗口设备（MICROPLATE_READER）等场景的完整验收，建议单独安排批次。

---

## 附：本轮实测错误码实录

| 错误码 | 含义 | 触发用例 |
|---|---|---|
| 1002004080 | 预约不存在 | T11、T13 |
| 1002004082 | 设备当前状态不可预约 | T04 |
| 1002004085 | 缺少有效使用资质 | T02 |
| 1002004086 | 账号存在生效的使用暂停 | T03 |
| 1002004087 | 预约时间不在开放日期/时段内 | T05 a/b/c |
| 1002004089 | 预约时间参数非法 | T01 早期字符串格式尝试 |
| 1002004093 | 预约时段已被占用 | T06、T09 |
| 1002004094 | 无权取消或当前状态不可取消 | T20a |
| 1002004097 | 当前状态不可登记完成 | T13、T20b |
| 1002004098 | 当前状态不可作废 | T20c |
| 1002004116 | 预约创建功能未启用（C7 关闭） | D8 回退验证 |
| 403（HTTP 内业务码） | 没有该操作权限 | T14 |

---

## 附：验收判定依据

| 判定项 | 结论 |
|---|---|
| 必需测试 | T01～T24 全部 **PASS** |
| 权限正确性 | 904/905/906/908 权限边界与菜单均符合设计，905 接口 403、页面 404 |
| 数据隔离 | 双用户（265/282）+ 双设备范围（dev2/dev3）隔离验证通过 |
| 预约生命周期 | 创建→调整→取消→完成→作废 全链路正确，历史完整 |
| 并发正确性 | 不同设备无干扰；同设备竞争仅 1 条合法写入，无死锁 |
| C7 回退 | 已确认 `false` 并经行为验证（116），数据未丢失 |
| 数据一致性 | 单号唯一、历史与主记录一致 |

**最终判定：FULL PASS**
