# 36-INSTRUMENT-03 真实 MySQL 并发与部署前验收报告

- 任务编号：TASK INSTRUMENT-03-R2-MYSQL-CONCURRENCY-VERIFY-01
- 执行日期：2026-10-19
- 执行人：Trae（青禾一 工作流）
- 依据文档：34 号（范围收敛与简化）、35 号（预约生命周期交付与验收）、22/23/24 号冻结规则、任务书 T1/T2 裁决原文
- 前置批次：34 号简化方案 = 「数据库事务 + 设备行锁 + 唯一约束」，无 Redis 分布式锁、无 CAP-A 容量账本

---

## 结论速览

| 项 | 结果 |
| --- | --- |
| T1 本人调整预约权限裁决落地 | ✅ 完成（独立权限 `lab:instrument:reservation:adjust`） |
| T2 windowId 边界裁决落地 | ✅ 完成（服务端重匹配，VO 不再接收 windowId） |
| 隔离 Docker MySQL/Redis | ✅ 启动并完成全部验证（端口偏差 3309/6381，经负责人裁决） |
| MySQL 8.0.12 并发创建（A/B/C 组） | ✅ 全部通过 |
| 暂停/预约交错（D1/D2/D-RAW） | ✅ 全部通过（含 P5 门直判 086 专项取证） |
| 生命周期竞态（L1~L6） | ✅ 全部通过，无 deadlock、无重复占用 |
| D2 预约编号唯一键精确重试 | ✅ 通过（errno 1062 + 约束名识别 + 换号重试成功） |
| Maven 全量测试 | ✅ 195/195（基线 180 + 新增 15，未删除任何既有测试） |
| 前端 TS | ✅ instrument 修改文件零新增 TS error（存量 15 个错误均在未触碰文件） |
| 正式 labplatform / 正式 Redis 写入 | ✅ 零写入（仅只读结构查询，未连接正式 Redis） |
| 正式菜单 SQL / 正式 DDL/DML | ✅ 未执行（仅设计稿） |
| C7 | ✅ 未开启（正式 profile 保持 false；隔离 profile 测试专用 true） |
| Docker 测试资源清理 | ✅ 已清理并有验证证据 |
| **最终判定** | **PASS / C7-READY**（正式开启 C7 仍须负责人下一次明确授权，本任务不开启） |

---

## 一、T1/T2 最终落地结果

### T1：本人调整预约权限（裁决 §二）

正式冻结并落地：

1. **独立权限串**：`lab:instrument:reservation:adjust`（核对现有命名体系 `lab:instrument:reservation:{query,create,cancel,manage}` 后沿用同前缀，仅末级能力定义为 `adjust`）。
2. **Controller**：[InstrumentReservationController.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument/InstrumentReservationController.java) 的 `PUT /lab/instrument/reservation/adjust` 改挂 `@PreAuthorize("@ss.hasPermission('lab:instrument:reservation:adjust')")`；`reservation:cancel` 不再兼作调整权限。
3. **普通用户**：可调整**本人 PENDING** 预约（开始前），原因免填；调整操作在设备行锁事务内**重走 P1~P8 全链路校验**（身份/租户、归属、设备状态、资格、有效暂停、规则、窗口、时间合法性/冲突、目标设备数据、当前状态），不因预约原本合法而跳过。
4. **管理侧**：设备负责人 / lab_admin 按既有数据范围规则（`InstrumentScopeSupport` 授权设备范围，不扩大）调整授权范围内预约，原因必填（Service 按身份条件校验）。
5. **回归测试**（[Instrument03R2AdjustT1T2Test.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument03R2AdjustT1T2Test.java) + [Instrument03R2PermissionAnnotationTest.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/test/java/cn/iocoder/yudao/module/lab/service/instrument/Instrument03R2PermissionAnnotationTest.java)）：本人 PENDING 可调整 / 本人不能调整他人（095）/ 无 adjust 权限 Controller 拒绝 / 负责人仅授权设备范围 / lab_admin 按既有规则 / 管理侧原因必填（095）/ cancel 权限不自动代表 adjust（反射注解测试校验注解字面值）。

### T2：windowId 边界（裁决 §三）

正式冻结并落地：

1. **客户端不要求传 windowId**：[ReservationAdjustReqVO.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument/vo/reservation/ReservationAdjustReqVO.java) **不再接收 windowId 字段**（同设备改时段仅传 id/时间；换设备加 `newDeviceId`）。
2. **服务端重匹配**：[InstrumentReservationServiceImpl.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentReservationServiceImpl.java) + [ReservationCreateExecutor.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/ReservationCreateExecutor.java) 以调整后 `deviceId + startTime + endTime` 为事实依据重新匹配校验目标设备有效开放窗口与预约规则（P1~P6 调整复核入口）；同设备重校验窗口，跨设备全量 P1~P8。
3. **旧 windowId 无法绕过**：VO 无该字段，客户端传入即校验失败（未知属性），不存在旧值旁路。
4. **不满足目标窗口即拒绝**（087 开放范围外），失败时原预约保持不变（锁内复核、异常整体回滚）。
5. **不复活 CAP-A**：窗口校验仅做"存在可完整覆盖的有效窗口"判定，无容量账本。
6. **回归测试**：同设备调整不传 windowId 成功 / 开放范围外 087 且原预约不变 / 关闭日 087 / 跨天 092（该设备禁跨天）/ 换到窗口型设备服务端重匹配成功 / 冲突仍 096。

## 二、修改文件

### 后端（yudao-module-lab / yudao-server）

| 文件 | 变更 |
| --- | --- |
| `controller/admin/instrument/InstrumentReservationController.java` | adjust 端点改挂独立权限 `lab:instrument:reservation:adjust`；权限注释更新 |
| `controller/admin/instrument/vo/reservation/ReservationAdjustReqVO.java` | 删除 windowId 接收字段（T2）；调整原因按身份条件必填说明（T1） |
| `controller/admin/instrument/vo/reservation/ReservationCancelReqVO.java` | 注释更新（cancel 与 adjust 职责边界） |
| `service/instrument/InstrumentReservationServiceImpl.java` | T2：调整链不读 windowId、按调整后事实重匹配；类注释记录 36 号裁决 |
| `service/instrument/ReservationCreateExecutor.java` | T2：P1~P6 调整复核入口（deviceId+时间重匹配窗口/规则） |
| `test/.../Instrument03R2AdjustT1T2Test.java` | 新增 T1/T2 H2 回归 11 用例 |
| `test/.../Instrument03R2PermissionAnnotationTest.java` | 新增权限注解反射单元测试（cancel 不兼作 adjust） |
| `yudao-server/src/main/resources/application-instrument-03-test.yaml` | 隔离 profile（3309/6381、C7=true 隔离专用、关闭验证码、dummy 微信配置、justauth 关闭） |

### 前端（yudao-ui-admin-vue3）

| 文件 | 变更 |
| --- | --- |
| `src/api/lab/instrument/reservation/index.ts` | AdjustReq 移除 windowId；adjust API 注释同步 T1/T2 |
| `src/views/lab/instrument/reservation-manage/index.vue` | 调整按钮 `canAdjust + v-hasPermi['lab:instrument:reservation:adjust']` 双闸（列表+详情） |
| `src/views/lab/instrument/my-reservation/index.vue` | 同上（我的预约页） |

### SQL 设计稿（未执行）

| 文件 | 变更 |
| --- | --- |
| [20261016_instrument_03b_booking_config_menu_design.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261016_instrument_03b_booking_config_menu_design.sql) | 新增附录 A：13677~13682 预约管理菜单树（含 13681 adjust）+ 角色/套餐授权设计 + 执行前预检/幂等写入/执行后验收守卫 |

### 隔离测试环境（instrument03-test-env/，新建）

`docker-compose.yml`、`.env`/`.env.example`、`init/00-schema-baseline.sql`（V2 修订）、`init/01-system-structure.sql`、`init/02-system-minimal-data.sql`、`init/03-fixture.sql`、`reset-business.sql`、`probe/Instrument03ConcurrencyProbe.java`

## 三、Docker Preflight（P1~P7）

| 门禁 | 结果 |
| --- | --- |
| P1 compose 目标 | ✅ 仅使用 `instrument03-test-env/docker-compose.yml`（专用隔离） |
| P2 MySQL | ⚠️ 任务书原定 `127.0.0.1:3307` **已被其他 Docker 项目 yd-admin-mysql 占用**（任务书禁止影响其他项目）；经负责人裁决改用 **127.0.0.1:3309**，隔离语义不变（仅 127.0.0.1 绑定/独立容器/独立库/独立 volume）；URL 无 `labplatform` 字样 |
| P3 Redis | ⚠️ 同上，原定 `6380` 被 yd-admin-redis 占用，经裁决改用 **127.0.0.1:6381** |
| P4 数据源配置 | ✅ 实际生效键为 `spring.datasource.dynamic.datasource.master.url`（dynamic-datasource 装配路径，非 `spring.datasource.url`） |
| P5 密码 | ✅ `.env` 使用占位密码（`lab03-pass-change-me` 等非仓库真实密码），不空、fail-closed 语义保持 |
| P6 C7 | ✅ 仅隔离 profile `lab.instrument.reservation.create-enabled: true`；local/dev/正式 profile 保持 false，未修改任何生产配置 |
| P7 Guard | ✅ `Instrument03IsolationGuardTest` 7/7 PASS 后方执行 `docker compose up` |

## 四、实际 Docker 资源

| 资源 | 值（销毁前采集） |
| --- | --- |
| MySQL 容器 | `instrument03-mysql`，镜像 `mysql:8.0.12`，端口 `127.0.0.1:3309->3306/tcp`，状态 Up (healthy) |
| Redis 容器 | `instrument03-redis`，镜像 `redis:7-alpine`，端口 `127.0.0.1:6381->6379/tcp`，状态 Up (healthy)，`--requirepass` 测试专用密码 |
| Volume | `instrument03-test-env_instrument03-mysql-data`、`instrument03-test-env_instrument03-redis-data` |
| Network | `instrument03-net`（独立 bridge） |
| 数据库 | `lab_instrument_03_test`（专用用户 t03） |

## 五、MySQL/Redis 实际隔离地址

- MySQL：`jdbc:mysql://127.0.0.1:3309/lab_instrument_03_test`（用户 t03，密码为 .env 占位值）
- Redis：`127.0.0.1:6381`，DB 0，测试专用密码（与隔离 yaml 一致）
- 应用实例：`yudao-server.jar --spring.profiles.active=instrument-03-test --server.port=6334`（隔离专用 profile，端到端验证载体）

## 六、MySQL 版本和事务隔离级别

```
VERSION() = 8.0.12
@@transaction_isolation = REPEATABLE-READ
@@log_bin = 1
InnoDB = 8.0.12
```

真实 InnoDB 行锁 + RR 隔离下验证；设备行锁为 `SELECT ... FOR UPDATE` 当前读，后获锁事务的一致性快照建立在行锁之后，必见对方已提交写入（无交错放行窗口）。

## 七、并发测试方法

**载体**：隔离 profile 启动的 yudao-server 实例（6334），探针程序 [Instrument03ConcurrencyProbe.java](file:///E:/lixin/dev/ruoyi-vue-pro/instrument03-test-env/probe/Instrument03ConcurrencyProbe.java)（纯 JDK HttpClient）端到端走 `Controller → Service → Mapper → MySQL 8.0.12 InnoDB` 真实事务/行锁，非 mock、非 H2。

- 并发同步：双 CountDownLatch（所有任务就绪后同时放行）。
- 幂等规避：create 端点 `@Idempotent` key 含方法参数+userId，故并发创建使用 4 个不同用户（stu01~stu04）。
- 时间字段：HTTP JSON 中 LocalDateTime 为毫秒时间戳（Jackson TimestampLocalDateTime 序列化）。
- 业务日：D = 2026-10-26（周一），规则全周开放 00:00-23:59，粒度 30 分钟，时长 30~480 分钟。
- 状态复位：探针重跑前执行 `reset-business.sql`（仅隔离库）。
- 占用口径：PENDING/FINISHED 占用时段，CANCELED/VOIDED 释放（C3）。
- 暂停语义注意（G12 联动）：暂停创建即把目标用户 ACTIVE 资质置 SUSPENDED；解除时恢复。因此"暂停赢"分支的拒绝可能落在 P4 资质门（085）或 P5 暂停门（086），两者均为读取到暂停方已提交写入后的合法拒绝；P5 门直判另行专项取证（见第八节 D-1')。

## 八、每组并发测试结果

最终运行（R2.2）：**20/20 检查全 PASS，FAIL=0，用时 2.3s**。

### A. 同设备同时段 4 并发创建（stu01~stu04，设备1，09:00-10:00）

```
[A] PASS 成功数=1（期望 1） 冲突093=3（期望 3）
    其余=[1002004093(160ms) 0(93ms) 1002004093(133ms) 1002004093(133ms)]
```

恰好 1 个成功，3 个得到合法冲突 1002004093（预约时段已被占用）。无 2 个以上成功、无静默吞异常、无重复占用（终态核对：设备1 09:00-10:00 仅 1 行 PENDING）。

### B. 相邻时段 [start,end)

```
[B] PASS 11:00-12:00=0 12:00-13:00=0（均期望 0）
```

左闭右开语义下相邻时段互不冲突，两笔均成功。

### C. 不同设备同时段

```
[C] PASS codes=[0(50ms) 0(53ms)] 耗时ms=[50,53] max=53 sum=103（并发判定 max<sum）
```

两请求耗时几乎相等（50/53ms，max < sum），证明设备 A 行锁未阻塞设备 B——设备间未串行化。

### D. 暂停 vs 创建预约

**D1 暂停先提交**：mgr01 为 stu03 创建设备1 SINGLE 暂停（成功）→ stu03 创建设备1 预约 → **拒绝**：

```
[D1] PASS 暂停后同设备预约=1002004085（P4资质门，G12联动吊销）缺少有效使用资质
[D1] PASS 暂停 SINGLE 范围外(设备2)预约=0
```

**D1' P5 暂停门直判（086）专项取证**：隔离库将 stu03@dev1 资质恢复 ACTIVE（暂停保持 ACTIVE）后再次创建：

```
{"code":1002004086,"msg":"账号存在生效的使用暂停","data":null}
```

证明"资质有效 + 暂停生效"组合下由 P5 暂停门直判拒绝——预约创建路径确实在设备行锁后读取到暂停方已提交写入。**当前暂停创建路径与预约创建共用同一设备行锁锚点**（`InstrumentSuspendServiceImpl.createSuspend`：事务内首步 `selectByIdForUpdate`，与 `ReservationLockCoordinator.executeInDeviceLock` 同锚点），**真实 MySQL 测试未暴露锁缺口，无需实施 T6 修复**（符合任务书"仅当测试证明缺口才修"的约束）。

**D2 预约先创建**：stu04 先在设备2 创建成功 → mgr01 随后创建同设备同用户暂停（成功）→ 预约保持 PENDING（不追溯取消）：

```
[D2] PASS 先创建=0 / 后暂停=0 / 预约后查询状态含 PENDING=true
```

**D-RAW 真并发交错（create ∥ suspend 同设备同用户，4 轮不变式）**：

```
[D-RAW] PASS 轮0 预约先赢: create=0 suspend=0 预约状态PENDING=true
[D-RAW] PASS 轮1 预约先赢: create=0 suspend=0 预约状态PENDING=true
[D-RAW] PASS 轮2 预约先赢: create=0 suspend=0 预约状态PENDING=true
[D-RAW] PASS 轮3 预约先赢: create=0 suspend=0 预约状态PENDING=true
```

4 轮全部"预约先赢"分支：create 与 suspend 均成功、预约保持 PENDING（不追溯取消）；轮间 release 恢复资质保证分支可达。每轮暂停记录 RELEASED ×1（历史全保留）。

### 探针首跑 6 FAIL 的说明（非产品缺陷）

首跑 6 个 FAIL 全部为**探针脚本适配问题**，非被测代码缺陷，均已修正后复跑：

1. 错误码比较用了裸码（1093），实际 HTTP 返回完整模块码 1002004xxx → 探针改后三位比对；
2. G12 联动使 D1/D-RAW 的拒绝落在资质门 085（合法拒绝）→ 探针接受 085/086 双门语义；
3. 探针依赖的 `suspend/page` 权限（`lab:instrument:suspend:query`）在隔离库补菜单时 role_menu 行缺 tenant_id=1，且 yudao 的 `menu_role_ids` Redis @Cacheable 缓存了空集（重启不清 Redis）→ 修正数据并清理隔离 Redis 缓存键后恢复。该问题同时验证了：**正式菜单 SQL 执行后必须失效对应 `menu_role_ids:{tenant}:{menuId}` 缓存**（已补入菜单设计稿注意事项）。

## 九、事务 A/B 时间线

以 D-RAW 轮（create T1 ∥ suspend T2，同设备行锁全序串行）为例：

```
T0  两事务并发提交，竞争设备2行锁
T1  获锁 → P1~P9 全链路校验（读到：无有效暂停、资质 ACTIVE）
    → INSERT 预约（单号 Redis INCR）→ COMMIT → 释放行锁     [create=0, 90ms]
T2  获锁 → 重复覆盖校验 → INSERT 暂停 + G12 资质联动
    → COMMIT（不触碰已存在预约）                            [suspend=0]
T3  验证：预约仍 PENDING（不追溯取消）                        ✓ 不变式成立
```

反向（暂停先赢）时间线同样成立：T2 获锁提交（暂停+资质吊销）→ T1 获锁后校验必见已提交写入 → P4（085）或 P5（086）拒绝。A 组 4 并发时间线：3 个失败事务在 P8 冲突检测处 093 回滚，唯一 INSERT 提交，锁释放后下一位才进入校验。

## 十、最终数据库状态（探针终态，21+2 行）

预约主表（20 行业务 + 1 行 D2 占号）：

| id | 单号 | 设备 | 用户 | 状态 | 时段 |
| --- | --- | --- | --- | --- | --- |
| 1 | R...0033 | 1 | stu02 | PENDING | 09:00-10:00（A 组唯一成功） |
| 2-3 | R...0034/35 | 1 | stu01/stu02 | PENDING | 11-12 / 12-13（B 组相邻） |
| 4-5 | R...0036/37 | 2/1 | stu03/stu04 | PENDING | 14-15（C 组跨设备并发） |
| 6 | R...0038 | 2 | stu03 | PENDING | 16-17（D1 范围外成功） |
| 7 | R...0039 | 2 | stu04 | PENDING | 17-18（D2 先创建，后暂停未追溯） |
| 8-11 | R...0040~043 | 2 | stu04 | PENDING | 18-19/19-20/20-21/21-22（D-RAW 4 轮） |
| 12-14 | R...0044~046 | 1 | stu01/02 | CANCELED | L1/L2/L3 各恰好一次取消 |
| 15 | R...0047 | 2 | stu02 | FINISHED | L4 完成赢 |
| 16 | R...0048 | 2 | stu01 | CANCELED | L5 取消赢（调整 095） |
| 17-18 | R...0049/50 | 1/2 | stu01/02 | PENDING | 13-14（L6a 原预约，双方 096） |
| 19-20 | R...0051/52 | 2/1 | stu01/02 | PENDING | 22:30-23:30（L6b 双调整成功，设备已互换） |
| 21 | R...0053 | 1 | stu01 | PENDING | D2 占号行（人工制造唯一键冲突） |
| 23 | R...0054 | 1 | stu02 | PENDING | 08:30-09:00（D2 重试成功行） |

暂停表：id1 stu03@dev1 ACTIVE（D1）；id2~6 stu04@dev2 RELEASED ×5（D2 + D-RAW 4 轮，历史全保留）。

**不变式核对**：同设备无任何重叠 PENDING/FINISHED 时段；单号 0033~0054 连续无缺口（0036 由 id5 使用，C 组两事务提交顺序与取号顺序差异属正常）。

## 十一、history 状态

| 预约 | 动作分布 | 结论 |
| --- | --- | --- |
| L1（id12） | CREATE×1 + **CANCEL×1**（before=PENDING, after=CANCELED, operator=stu01） | 双取消竞态仅 1 条有效取消记录 ✓ |
| L2（id13） | CREATE×1 + CANCEL×1 | 终态唯一 CANCELED，无 FINISHED ✓ |
| L3（id14） | CREATE×1 + CANCEL×1 | 终态唯一 CANCELED，无 VOIDED ✓ |
| L4（id15） | CREATE×1 + FINISH×1 | 终态唯一 FINISHED，无 CANCELED/VOIDED ✓ |
| L5（id16） | CREATE×1 + CANCEL×1 | 取消赢，终态 CANCELED，调整失败原时段未变 ✓ |
| L6b（id19/20） | CREATE×1 + ADJUST×1（跨设备，before=PENDING） | history 与主表一致（主表 PENDING、设备已互换、时段 22:30-23:30）✓ |

无任何"两条成功历史"、无状态与 history 不一致。

## 十二、deadlock / lock wait 结果

- **零 deadlock、零 lock wait timeout**。
- L6a（跨设备同时段互换 A→B / B→A）：双方 096 冲突，无 500/死锁/超时——deviceId 升序双锁避免了互等；
- L6b（跨设备错开时段调整）：双成功（设备互换 + 时段改至 22:30-23:30），无死锁；
- D-RAW 4 轮并发 create∥suspend：全部正常串行化，无锁等待异常；
- 判定依据：响应体不含 "Deadlock"、错误码非 500/-9999（超时）。

## 十三、D2 MySQL 异常证据

**正向（uk_reservation_tenant_no 冲突 → 限定重试换号成功）**：

方法：Redis 读当前序列（`instrument:reservation:no:1:20261019` = 52）→ 人工插入占号行 `R2026101900053`（占用唯一键）→ API 创建撞键。

server.log 证据（应用日志原样）：

```
### Error updating database.  Cause: java.sql.SQLIntegrityConstraintViolationException:
    Duplicate entry '1-R2026101900053' for key 'uk_reservation_tenant_no'
### Cause: java.sql.SQLIntegrityConstraintViolationException: Duplicate entry '1-R2026101900053'
    for key 'uk_reservation_tenant_no'
; nested exception is java.sql.SQLIntegrityConstraintViolationException:
    Duplicate entry '1-R2026101900053' for key 'uk_reservation_tenant_no'
[createReservation] 预约单号唯一键冲突, 第 2/2 次尝试将重走全链路校验 + 新单号, err=...
```

- MySQL errno：**1062**（SQLIntegrityConstraintViolationException）
- SQLState：**23000**
- constraint/index name：**uk_reservation_tenant_no**（异常 message 中完整可见）
- cause chain：MyBatis → java.sql.SQLIntegrityConstraintViolationException → Spring `DuplicateKeyException`（DataAccessException 翻译）→ Service 捕获 → `isReservationNoConflict`（cause chain 遍历 + message contains `uk_reservation_tenant_no`）→ 新事务重走全链路校验 + 新单号
- 结果：重试成功，新行 **R2026101900054**（id=23），HTTP code=0

**负向（其他唯一键冲突不得被吞）**：人工触发规则表唯一键冲突：

```
ERROR 1062 (23000): Duplicate entry '1-1' for key 'uk_rule_tenant_device'
```

`uk_rule_tenant_device` 与 `uk_reservation_tenant_no` 互不包含，`isReservationNoConflict` 返回 false → 原样抛出，不进入重试分支。

**识别逻辑可靠性结论**：真实 MySQL 8.0.12 驱动异常 message 稳定携带完整约束名（含 `for key '<name>'` 形态），contains 判别可靠；无需改为更复杂的 constraint 提取机制。

## 十四、window_id 核查（正式库只读）

对正式 `labplatform` 仅执行只读结构查询（`SHOW CREATE TABLE` / `information_schema.columns` / `information_schema.statistics`），七问结论：

| # | 问题 | 结论 |
| --- | --- | --- |
| 1 | 真实库是否有 window_id | **无**（lab_instrument_reservation 无该列；仅旧 baseline 设计稿包含，未在正式库执行） |
| 2 | 当前 DO 是否有 windowId | **无**（InstrumentReservationDO 无该字段） |
| 3 | Mapper 是否读写 | **否**（无相关映射/SQL） |
| 4 | 创建是否依赖 | **否**（T2 后 VO 亦不接收；服务端重匹配窗口） |
| 5 | 调整是否依赖 | **否**（T2 裁决核心：调整不携带 windowId） |
| 6 | 是否存在索引/FK | **无**（无 idx_window、无外键） |
| 7 | 建议 | **REMOVE-LATER** —— 该字段仅残留在旧 baseline 设计稿（34 号已废弃的 CAP-A 演进路径）；隔离 baseline 修订已整体删除（PART 2 两表 + ALTER window_id + idx_window）。正式库无此列，**未来无需 DDL**；唯一遗留动作 = 旧 baseline 文件归档时去除 CAP-A 段（非紧急，不影响任何运行时行为） |

本任务未对正式库执行任何 ALTER。

## 十五、Maven 测试总数

```
mvn clean test -pl yudao-module-lab -o
Tests run: 195, Failures: 0, Errors: 0, Skipped: 0 — BUILD SUCCESS
```

- 基线 35 号 = 180；本任务新增 15（T1/T2 回归 11 + 权限注解反射 4）→ **195 ≥ 180** ✓
- 带 `clean`（避免 ECJ/JDT 污染 target）；未删除任何既有有效测试
- 含 `Instrument03IsolationGuardTest` 7/7（P7 守卫）

## 十六、前端 TS 结果

`pnpm ts:check`（vue-tsc 全项目）：

- **instrument 本次涉及文件（src/api/lab/instrument/、src/views/lab/instrument/）零 TS error** ✓
- 存量错误 15 个，全部位于本次未触碰文件（git 确认）：
  - `src/api/lab/announcement/index.ts` ×1（TS6133）
  - `src/views/fms/report/components/FmsReportFormulaForm.vue` ×2（TS2345）
  - `src/views/hrm/employee/index.vue` ×1（TS2353）
  - `src/views/lab/v2/plasmid-audit/index.vue` ×5、`src/views/lab/v2/plasmid/index.vue` ×6（TS2322/TS2538/TS6133）
- 存量问题记档，不在本任务范围。

## 十七、菜单 SQL 设计稿变化

[20261016_instrument_03b_booking_config_menu_design.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261016_instrument_03b_booking_config_menu_design.sql) 新增附录 A（**设计稿，未执行**）：

- 菜单：13677 预约管理（type=2, parent=13600, component=lab/instrument/reservation-manage/index）+ 13678 query / 13679 create / 13680 cancel / **13681 adjust** / 13682 manage（type=3）
- 授权：**904 普通用户 = 13677~13681**（T1 裁决本人可调整；不授 13682）、**906 lab_admin = 13677~13682**、**908 仪器负责人 = 13677~13682**（管理侧操作经授权设备范围服务端校验，不扩大数据范围）、905 库管员不授权
- 依赖核对结论：13674~13676（booking-config，仅 906）维持 §1~§3 原设计；**13674/13675/13676 当前在正式库均未执行**（max(menu.id)=13673），附录 A 预检以"§1 已执行、max=13676"为前置；**package 114**（租户 162）menu_ids 追加 13677~13682；role 904/906/908 均属租户 162
- 附执行守卫：A.0 执行前只读预检（任一不符即停止）→ A.1/A.2/A.3 幂等写入（NOT EXISTS / JSON_CONTAINS 守卫，显式 tenant_id=162）→ A.4 执行后验收
- **执行前检查结果**：本任务仅在隔离库验证了同构授权链路（隔离库 13677~13682 + suspend 菜单按同模式插入并实测权限生效，含 Redis `menu_role_ids` 缓存失效要求），正式库未执行任何 SQL
- 经验补充：正式执行后须失效 Redis `menu_role_ids:{tenantId}:{menuId}` 缓存（或重启），否则权限延迟生效

## 十八、Docker 清理证据

```
docker compose down -v（instrument03-test-env）
  Container instrument03-redis Stopped/Removed
  Container instrument03-mysql Stopped/Removed
  Volume instrument03-test-env_instrument03-redis-data Removed
  Volume instrument03-test-env_instrument03-mysql-data Removed
  Network instrument03-net Removed

清理后验证：
  containers=[] volumes=[] networks=[]      ← instrument03 专用资源已不存在
其他 Docker 项目未受影响（清理后仍在运行）：
  admin3-frontend/admin3-backend/admin3-mysql、yd-admin-redis(6380)、
  yd-admin-nginx、yd-admin-php、yd-admin-mysql(3307) 等均完好
```

隔离应用实例（6334）已停止。

## 十九、正式 labplatform / 正式 Redis 零写入声明

1. 对正式 `labplatform` 仅执行只读结构查询（mysqldump --no-data 导出 system 表结构、SHOW CREATE TABLE、information_schema 查询），**零 DDL、零 DML、零业务数据变更**；
2. **正式 Redis 全程未连接**（仅对隔离 Redis 127.0.0.1:6381 执行读写与缓存清理）；
3. 正式菜单 SQL（含附录 A）**未执行**；正式 profile 的 C7 配置未被修改（保持 false）；
4. 未连接任何仪器硬件；未恢复 CAP-A；未恢复预约 Redis 分布式锁；未将 H2 结果冒充 MySQL 结果（H2 仅用于 T1/T2 单测回归，并发结论全部来自真实 MySQL）。

## 二十、C7 最终判定

**PASS / C7-READY**

- 简化方案（数据库事务 + 设备行锁 + 唯一约束 + 条件更新）在真实 MySQL 8.0.12 + InnoDB + REPEATABLE-READ 下经受住全部并发验证：同设备并发恰 1 成功、跨设备不串行、暂停/预约全序串行且不追溯取消、生命周期竞态无死锁无重复占用无状态不一致、唯一键精确重试有效；
- **未发现需要增加锁、容量账本、分布式协调器的缺陷**；唯一缺口场景（暂停路径行锁）经验证不存在，T6 修复未实施（符合"仅测试暴露缺陷才修"原则）；
- 隔离守卫有效（7/7）、测试基线提升至 195/195、前端零新增错误；
- **正式环境开启 C7 必须等待负责人下一次明确授权**，本任务未开启、不开启。开启时配套动作：执行菜单设计稿附录 A（含执行前预检与执行后 Redis 缓存失效）、按 34 号部署清单核对。

---

## 附：任务书约束逐条对照

| 任务书条目 | 状态 |
| --- | --- |
| §二 T1 裁决（独立 adjust 权限/本人调整/管理侧/权限串） | ✅ |
| §三 T2 裁决（不强制 windowId/服务端重匹配/六条规则/windowId 建议） | ✅（REMOVE-LATER） |
| §四 授权范围/禁止清单 | ✅ 全程未越界 |
| §五 P1~P7 门禁 | ✅（P2/P3 端口偏差经负责人裁决 3309/6381） |
| §六 隔离环境启动与资源记录 | ✅ |
| §七 隔离库初始化（CAP-A 修订删除：capacity 两表 + ALTER window_id + idx_window；不影响 34/35 号代码） | ✅ |
| §八 A/B/C/D 真实 MySQL 并发 | ✅ 20/20 |
| §九 L1~L6 生命周期竞态 | ✅ |
| §十 D2 唯一键精确重试 | ✅ |
| §十一 T1/T2 回归测试 | ✅（15 新增用例） |
| §十二 全量 mvn clean test ≥180 | ✅ 195/195 |
| §十三 前端验证 + TS | ✅（instrument 零新增） |
| §十四 菜单 SQL 只改设计稿 | ✅ |
| §十五 window_id 只读核查 | ✅ |
| §十六 C7 只判定 | ✅ C7-READY，未开启 |
| §十七 Docker 清理 | ✅ |
| §十八 PASS/HOLD | ✅ PASS |
| §十九 20 节报告 | ✅ 本文档 |
