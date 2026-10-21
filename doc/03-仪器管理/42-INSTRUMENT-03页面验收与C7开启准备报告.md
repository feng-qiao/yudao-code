# 42 - INSTRUMENT-03 页面验收与 C7 开启准备报告

- 任务号：`TASK INSTRUMENT-03-R6-ACCEPTANCE-AND-C7-READINESS-01`
- 生成日期：2026-10-19
- 目标库：`labplatform` ｜ 目标租户：162 ｜ 目标套餐：114
- 基线：36 号（并发 PASS）、39 号（菜单闭环 PASS）、40 号（部署前预检 PASS）、41 号（菜单部署 DEPLOY PASS / MENU READY）
- 本轮**不重复执行菜单 SQL**，无数据库写入、无 Redis 写入、未开启 C7、未重启后端、未改任何配置
- **最终判定：CONDITIONAL PASS**

> 本报告严格区分「运行时证据 / 仅源码验证 / 无账号未测 / 无样本未测 / 需开 C7 才能测」，未将源码验证写成真实业务验收 PASS。

---

## 0. 本轮操作边界

**允许并已执行**：正式库 SELECT/SHOW/information_schema；前后端源码只读；已有账号（904 `189140002`、906 `bencao`）登录 + 只读 API 验收；检查现有预约/设备/资质/暂停/配置数据；生成 C7 开启计划、回退方案、测试清单与本报告。

**禁止且未执行**：任何 DML/DDL；改菜单/角色/套餐/账号；建测试账号或改密码；创建/取消/调整/完成/作废真实预约；改预约规则/开放时段/设备资质/暂停；改 Redis；开 C7；重启后端；Docker；自动进入下一阶段。

---

## 1. R6-A 菜单与页面验收（运行时证据）

### 1.1 账号与角色现状（只读查询）
| user_id | username | roles | 用途 | 可用作纯净测试账号？ |
| --- | --- | --- | --- | --- |
| 281 | 189140002 | **904**（普通用户） | 904 验收 | ✅ 纯净 904 |
| 278 | bencao | **906**（lab_admin） | 906 验收 | ✅ 纯净 906 |
| 260 | qinghy | **903+905+906+908**（联合） | 908/905 候选 | ❌ 非纯净（union 授权会放大权限） |

> 无「仅 908」或「仅 905」的纯净账号。`qinghy` 持 903 tenant_admin + 905 + 906 + 908，不能用于 908/905 的「无权限/数据范围」验收（会得出假阳性）。**遵任务书：不新建账号、不改权限。**

### 1.2 904 普通用户（运行时证据 PASS）
| 检查项 | 结果 | 证据 |
| --- | --- | --- |
| 预约管理菜单可见 | PASS | `get-permission-info.menus` 含「预约管理」 |
| 我的预约菜单可见 | PASS | 菜单树含「我的预约」 |
| 预约配置不可见 | PASS | 菜单树**无**「预约配置」 |
| 我的预约查询 | PASS | `GET reservation/my` → `code=0` |
| 预约管理查询 | PASS | `GET reservation/page` → `code=0` |
| 不越权规则配置（读） | PASS | `GET booking-rule/get?deviceId=2` → `code=403 没有该操作权限` |
| 不越权开放时段（读） | PASS | `GET booking-window/page?deviceId=2` → `code=403` |
| 不越权规则配置（写） | PASS | `POST booking-rule/save`（真实 body）→ `code=403 没有该操作权限`，**未落库** |
| 权限集 | PASS | 含 `reservation:query/create/cancel/adjust`，**不含** `reservation:manage`、不含 `rule:*` |

### 1.3 906 实验室管理员（运行时证据 PASS）
| 检查项 | 结果 | 证据 |
| --- | --- | --- |
| 预约配置可见 | PASS | 菜单树含「预约配置」 |
| 预约管理可见 | PASS | 含「预约管理」 |
| 我的预约可见 | PASS | 含「我的预约」 |
| 规则列表只读查询 | PASS | `GET booking-rule/get?deviceId=2` → `code=0` |
| 开放时段只读查询 | PASS | `GET booking-window/page?deviceId=2` → `code=0`（total=0，未配置窗口） |
| 预约管理列表 | PASS | `GET reservation/page` → `code=0` |
| 权限集 | PASS | 含 `rule:query/update` 与 `reservation:query/create/cancel/adjust/manage` 全部 |

### 1.4 908 设备负责人 / 905 库管员 — **NOT TESTED（无纯净账号）**
- 908、905 页面/权限/数据范围验收**无法在本轮用运行时证据完成**（唯一候选 `qinghy` 为 903+905+906+908 联合账号，不能代表纯净 908/905）。
- **数据库层结论（已证）**：908 新增授权 = 7（13677~13682、13683），**无** 13674~13676（rule）；905 新增授权 = **0**。见 41 号报告 §6/§7。
- 运行时验收留待负责人提供纯净账号后补验（见 §6 R1/R2）。

---

## 2. R6-B 数据隔离与越权核验

### 2.1 样本现状
- `lab_instrument_reservation`：**0 行**（0 用户 / 0 设备）。
- `lab_instrument_reservation_history`：0 行。
- `lab_instrument_device`：2 台（id=1 SCRAPPED，id=2 NORMAL/bookable）。
- `lab_instrument_manager`（数据范围来源）：仅 ROOM_REPAIR 范围记录，**无 DEVICE 范围 ACTIVE 关系**。
- `lab_instrument_booking_rule` / `booking_window`：均 0 行（未配置）。

### 2.2 结论：**DATA-SAMPLE-BLOCKED**
预约表为空，无法用「不同用户 × 不同设备」的真实样本验证运行期数据隔离。遵任务书：**未 INSERT、未伪造数据**，标记 `DATA-SAMPLE-BLOCKED`，待获授权的隔离测试或正式业务验收阶段补测。

### 2.3 已核验（仅源码验证，非运行期样本验收）
以下为 R4/R5 已完成的源码核验，**不作为真实业务验收 PASS**：
| 检查项 | 验证方式 | 结论 |
| --- | --- | --- |
| 904 我的预约仅本人 | 源码 | `InstrumentReservationMapper.selectListByUser` 强制 `eq(userId)`（L163-167） |
| 904 预约管理仅本人 | 源码 | `canManageAll=false` → `selectPage` 裁剪 `user_id=本人 OR device_id IN 授权设备`，无 DEVICE 关系时退化为仅本人 |
| 908 设备范围裁剪 | 源码 | `getManagedDeviceIds` 取 DEVICE+PLATFORM ACTIVE 关系；服务端最终边界 |
| 906 管理查询范围 | 源码 | `canManageAll=true`（lab_admin）→ 全量 |
| 越权详情拒绝口径 | 源码 | 操作按角色判定 + 条件更新（affected=0 → 拒绝） |
| 服务端角色/范围/条件更新校验 | 源码 | cancel/finish/adjust/void 均在锁内重读 + 条件更新（见 §3.5） |

---

## 3. R6-C C7 开启前检查（只读，未修改）

### 3.1 配置与 Profile
| 项 | 现状 | 判定 |
| --- | --- | --- |
| 生效 profile | `application.yaml: active: local` → `application-local.yaml` | PASS |
| `application-local.yaml` 是否含 create-enabled | **无**（默认 false 生效） | PASS（C7=false） |
| `application.yaml` 是否含 create-enabled | 无 | PASS |
| `application-instrument-03-test.yaml` | 唯一含 `create-enabled: true`（隔离 profile，**未激活**） | PASS |
| `include-freeze-batch` | 所有 yaml 均**无** → 默认 false | PASS |
| MySQL 连接 | `jdbc:mysql://127.0.0.1:3306/labplatform`（8.0.12） | PASS |
| Redis 连接 | `127.0.0.1:6379` db=0（无密码，本地） | PASS（连接正常；单号生成依赖 Redis） |

### 3.2 C7 @Value 读取逻辑
- `InstrumentReservationServiceImpl.java:57-60`：`@Value("${lab.instrument.reservation.create-enabled:false}") private boolean createEnabled;` —— **默认 false**。
- 同文件 `:88-92`：`createReservation` 首步 `if (!createEnabled) throw exception(INSTRUMENT_RESERVATION_CREATE_DISABLED);` —— 未开则拒绝写入。
- `ReservationConflictChecker.java:48-51`：`include-freeze-batch` 默认 false，开启会显式暴露未实现问题（不静默吞异常）。

### 3.3 预约号生成与唯一约束
- 生成：`ReservationNoRedisDAO.generate(tenantId)`，Lua `INCR` 原子、key 含 `yyyyMMdd`（跨日重置），格式 `R + yyyyMMdd + %05d`。
- 唯一约束：`uk_reservation_tenant_no(tenant_id, reservation_no)`（实测 NON_UNIQUE=0 存在）→ DB 兜底防重。
- 冲突重试：仅在精确识别 `uk_reservation_tenant_no` 冲突时，由 Service 层「新事务 + 新设备行锁 + 新单号」外层有限重试（MAX 2 次），耗尽抛 099。

### 3.4 MySQL 设备行锁与并发
- `ReservationLockCoordinator.executeInDeviceLock`：编程式事务（TransactionTemplate）→ 事务内首步 `SELECT ... FOR UPDATE`（`selectByIdForUpdate`）→ 设备维度串行化；换仪器用 `executeInTwoDeviceLocks`（按设备 id 升序双锁，规避死锁）。
- 暂停/预约同协议串行，无「暂停生效但预约放行」交错窗口。
- 冲突口径：左闭右开 `[start,end)`，`existing.start < reqEnd AND existing.end > reqStart`；相邻时段不冲突（`ReservationConflictChecker.java:21-23`）。

### 3.5 准入校验与生命周期（P1~P9 + 取消/调整/完成/作废）
- **创建准入 P1~P9**：P1 设备存在且 `status=NORMAL`（SCRAPPED 拒绝）→ P2 `bookable=1` → P3 规则启用且完整 → P4 资质 ACTIVE 且未过期 → P5 无生效暂停 → P6 开放范围（普通设备按规则 open_days/open_time/前后偏移；MICROPLATE_READER 按窗口，创建必须归属唯一 ACTIVE 窗口，跨日 HOLD 拒绝）→ P7 时间参数（end>start、粒度对齐、时长范围、跨日限制）→ P8 冲突（reservation PENDING/FINISHED + maintenance ACTIVE，调整时排除自身）→ P9 落库（单号 + 预约 INSERT + history CREATE，同事务）。
- **生命周期**：cancel/finish/adjust/void 均在事务锁内重读预约行 → 角色判定（`resolveRoleForCancel`/`resolveManageRole`，数据范围服务端显式校验不靠前端）→ 条件更新（`updateCancelIfPending`/`updateFinishIfPending` 等，`affected=0` → 拒绝）→ 插入 history。操作历史只增不改。
- **事务一致性**：预约 + history 同事务；冲突重试为事务边界外新事务（保证 Connection 干净）；事务感知缓存（`setTransactionAware(true)`）避免脏读。

**R6-C 结论**：C7 开启所需的配置项、读取逻辑、单号唯一、行锁并发、准入校验、生命周期、事务一致性均只读核验通过，无明确安全缺陷。

---

## 4. R6-D 真实预约验收计划（仅计划，不执行）

> 全部 16 项均**产生正式业务写入**（除标注外），需 C7 开启 + 负责人单独授权后方可执行。前置数据缺口：**当前无 booking_rule / booking_window / 资质 / 样本预约**，需先在授权下准备最小前置数据。

| # | 用例 | 所需角色 | 前置数据 | 预期结果 | 正式写入 | 数据保留/清理 | 失败停止条件 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 904 合法创建 | 904 | device NORMAL+bookable、有效规则、904 有效资质、开放窗口 | 创建成功，状态 PENDING，生成唯一单号，history CREATE | 是 | 保留供后续用例；授权后清理 | 非预期错误码 / 重复单号 |
| 2 | 无资质用户创建被拒 | 904(临时无资质)或专门无资质账号 | 同1但用户无 ACTIVE 资质 | 084 NO_VALID_QUALIFICATION 拒绝，无落库 | 否（拒绝） | — | 误放行 |
| 3 | 生效暂停用户创建被拒 | 904 + 生效暂停记录 | 覆盖 device 的 ACTIVE 暂停 | 086 USER_SUSPENDED 拒绝 | 否 | 授权后清理暂停 | 误放行 |
| 4 | 非 NORMAL 设备创建被拒 | 904 | device 1（SCRAPPED） | 083 DEVICE_STATUS_DENIED 拒绝 | 否 | — | 误放行 |
| 5 | 未开放时段创建被拒 | 904 | 规则开放时段之外的时间 | 087 OUT_OF_OPEN_SCOPE 拒绝 | 否 | — | 误放行 |
| 6 | 同设备时间重叠创建被拒 | 904×2 或 904+906 | 设备已有 PENDING 重叠时段 | 093 TIME_CONFLICT 拒绝 | 否 | — | 误放行/误报 |
| 7 | 相邻时间段创建成功 | 904 | 与已有预约首尾相接 [09-10),[10-11) | 成功（相邻不冲突） | 是 | 保留/清理 | 误判冲突 |
| 8 | 不同设备并发预约正常 | 904×2 不同 device | 两台 NORMAL 设备 | 各自成功，互不影响 | 是 | 保留/清理 | 死锁/串号 |
| 9 | 904 取消本人预约 | 904 | 本人 PENDING 预约 | 取消成功，状态 CANCELED，history CANCEL | 是 | 保留 | 越权取消成功 / 条件更新异常 |
| 10 | 904 调整本人 PENDING 预约 | 904 | 本人 PENDING 预约 | 调整成功，重走 P1~P8，history ADJUST | 是 | 保留/清理 | 校验未重走 / 误放行 |
| 11 | 908 管理授权设备预约 | 908 | 908 对目标 device 有 DEVICE 范围 ACTIVE 关系 | 可按设备范围管理，无 rule:update | 是 | 保留/清理 | 越权 / 范围裁剪失效 |
| 12 | 906 完成和作废预约 | 906 | 906 管理范围内 PENDING 预约 | finish→FINISHED、void→VOIDED，history 完整 | 是 | 保留 | 越权 / 状态机异常 |
| 13 | 操作历史正确 | 任意操作后 | 已产生若干操作 | history 只增不改、字段完整、操作人/时间正确 | 是（只读核验） | 保留 | history 缺失/错乱 |
| 14 | 无权限访问被拒绝 | 904 | 他人/管理端点 | 403/对应拒绝码，无落库 | 否 | — | 误放行 |
| 15 | 预约号唯一性 | 904 并发/多笔 | 多笔创建 | 单号全局唯一（tenant+no），无重复 | 是 | 保留/清理 | 重复单号 |
| 16 | C7 回退 false | 906/系统 | 先开 C7 创建成功，再回退 false | 回退后新建被拒（CREATE_DISABLED），既有记录不受影响 | 是（配置+重启） | 既有记录保留 | 回退后仍可创建 / 数据损坏 |

---

## 5. C7 开启方案（计划，未执行）

### 5.1 实际操作步骤
1. 负责人书面授权 C7 开启；
2. 编辑 `application-local.yaml`，在 `lab.instrument.reservation` 下新增 `create-enabled: true`；
3. **重启后端**（PID 41788）—— `@Value` 为启动期注入，改配置必须重启生效；
4. 重启后只读探活确认 48080 正常；
5. 按 §4 计划执行真实预约验收。

### 5.2 重启要求
- 必需。当前后端以 local profile 运行（PID 41788），`createEnabled` 在 Bean 初始化时注入，**不支持热更新**。

### 5.3 预计影响
- 开启后 `POST /lab/instrument/reservation/create` 放行写入（经 P1~P9 全链校验）；
- 其他生命周期端点（cancel/finish/adjust/void）**不受 C7 控制**（源码仅 create 受 createEnabled 闸门），但当前因无数据而无实际调用；
- 不影响菜单/权限/套餐（已于 41 号部署完成）。

### 5.4 验证方式
- 创建前置探针：`GET reservation/is-open`（若提供）或直接按 §4.1 合法创建；
- 验收按 §4 表逐项执行并记录实际结果与错误码。

### 5.5 回退方案
1. 将 `application-local.yaml` 的 `create-enabled` 改回 `false`（或删除该键）；
2. 重启后端；
3. 验证：`POST create` 返回 `INSTRUMENT_RESERVATION_CREATE_DISABLED`，既有预约记录不受影响（回退不删数据）；
4. 若开启期间产生异常数据，凭 41 号备份 + 业务口径人工评估处理（不自动执行补偿 SQL）。

---

## 6. 异常、剩余风险与待确认项

### 6.1 异常
- 本轮未发现明确权限、数据隔离、配置或业务逻辑**安全缺陷**。

### 6.2 待负责人确认（CONDITIONAL PASS 依据）
| 编号 | 事项 | 类型 | 建议 |
| --- | --- | --- | --- |
| R1 | 908 页面/权限/数据范围运行期验收未做 | 无账号 | 提供纯净 908 账号后补验 |
| R2 | 905 无授权运行期验收未做 | 无账号 | 提供纯净 905 账号后补验（DB 层已证 0 授权） |
| R3 | 904/908/906 数据隔离运行期样本验证未做 | 无样本数据（预约表空） | 授权隔离测试造样本后补测 |
| R4 | 前端浏览器渲染验收未做（本轮为 API 级） | 浏览器环境 | 前端重登后浏览器复核页面与按钮 |
| R5 | 创建/取消/调整/完成/作废等写链路全部未测 | 需开 C7 + 授权 | 按 §4 计划在授权后执行 |
| R6 | 前置数据缺失（无 booking_rule/window/资质/暂停） | 前置准备 | 开 C7 验收前需先在授权下准备最小前置数据 |

### 6.3 下一步建议
1. 负责人确认接受 R1~R6 未测项（CONDITIONAL PASS 口径）；
2. 提供纯净 908/905 账号以补齐页面验收；
3. 就 C7 开启单独授权（含配置修改 + 后端重启 + §4 真实预约验收）；
4. 验收前准备最小前置数据（规则/窗口/资质）。

---

## 7. 最终判定

**CONDITIONAL PASS**

- 本轮所有**可执行**检查均通过：904/906 菜单与权限运行时验收 PASS（含越权 403 拒绝）、C7 开启前源码/配置只读核验通过（无安全缺陷）、C7 开启方案与回退方案完整、16 项需业务写入的验收计划已列明。
- 存在**账号（908/905）、样本数据（预约表空）、浏览器环境**导致的未测项目，需负责人确认是否接受（R1~R6）。
- 本报告**不构成 C7 开启授权**，不自动进入下一阶段。

任务完成，停止，等待负责人对 C7 的独立授权。

---

## 附：关键证据索引
- 菜单部署验收：41 号报告（DEPLOY PASS / MENU READY）
- 904 越权拒绝：`POST /lab/instrument/booking-rule/save` → `403 没有该操作权限`（2026-10-19，未落库）
- 906 规则/窗口只读：`GET booking-rule/get?deviceId=2` / `booking-window/page?deviceId=2` → `code=0`
- C7 闸门：`InstrumentReservationServiceImpl.java:57-60,88-92`（默认 false）
- 单号唯一：`uk_reservation_tenant_no(tenant_id, reservation_no)`（实测存在）
- 设备行锁：`ReservationLockCoordinator.executeInDeviceLock`（SELECT ... FOR UPDATE）
- 数据现状：reservation 0 行；device 2 台（1 SCRAPPED/1 NORMAL）；booking_rule/window 0 行；无纯净 908/905 账号
</content>
</invoke>
