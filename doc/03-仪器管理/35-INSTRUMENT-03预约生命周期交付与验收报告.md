# INSTRUMENT-03 预约生命周期交付与验收报告（35号）

| 项目 | 内容 |
|------|------|
| **报告编号** | 35-INSTRUMENT-03-R1-LIFECYCLE-01 |
| **日期** | 2026-10-19 |
| **关联任务书** | TASK INSTRUMENT-03-R1-LIFECYCLE-01（预约生命周期与前端闭环合并实施） |
| **负责人** | 青禾一（授权范围：代码修改 + 前端页面 + 隔离守卫修复；绝对禁止：真实 labplatform DDL/DML/菜单写入/Redis 写入/Docker 创建启动/C7 开关开启/连接硬件） |
| **前置报告** | 34-INSTRUMENT-03 预约管理版范围收敛与简化报告（代码基线）；32-INSTRUMENT-03-C 部署阻断修复与并发环境准备报告（隔离环境配置） |
| **本次交付状态** | 生命周期后端 ✅ / 前端闭环 ✅ / H2 全绿 ✅ (180/180) / 隔离守卫加固 ✅ / 真实 MySQL 并发验证 ❌（隔离环境未启动，Docker 未授权） |

---

## §0 执行边界声明（必读）

| 类别 | 数量 | 说明 |
|------|------|------|
| **真实 labplatform DDL** | 0 | 未执行任何 DDL |
| **真实 labplatform DML** | 0 | 未写入任何业务数据 |
| **真实菜单写入** | 0 | 预约管理页菜单 SQL 为 07 号设计稿，未 apply |
| **真实 Redis 操作** | 0 | 未连接正式 Redis |
| **Docker 创建/启动** | 0 | 隔离环境容器未启动（未授权） |
| **C7 开关** | 正式库保持 false | 仅隔离 profile 配置显式 true（未启动） |
| **22~24 号冻结文档** | 无修改 | 所有规则以 22/23/24 冻结内容为准 |
| **硬件连接** | 0 | 任务书明确不连接硬件 |
| **CAP-A 容量账本** | 未恢复 | 遵循 34 号收敛 |
| **预约 Redis 分布式锁** | 未恢复 | 遵循 34 号收敛（互斥锚点=设备行锁+条件更新） |

---

## §1 交付范围总览

任务书五大实施范围全部落地：

| 范围 | 交付 | 说明 |
|------|------|------|
| 取消预约 | ✅ | 本人（开始前）/ 管理侧（任意时刻，原因必填）；条件更新防重复取消 |
| 完成预约 | ✅ | `reservation:manage` 授权范围手动登记；仅 PENDING；实际起止必填；历史保留 |
| 调整预约 | ✅ | 设备行锁内 P1~P8 全链复核；跨设备 id 升序双锁防死锁；失败不破坏原预约 |
| 作废预约 | ✅ | `reservation:manage` 授权范围；原因必填并记录操作人 |
| 预约历史 | ✅ | 复用 34 号历史表；业务状态变更与 history 写入同事务 |

---

## §2 实际修改文件清单

### §2.1 后端（yudao-module-lab）

| 文件 | 改动 | 批次 |
|------|------|------|
| `controller/admin/instrument/InstrumentReservationController.java` | 新增 cancel/finish/adjust/void/page 端点（history-list 34 号已有） | r3 + 本批 |
| `service/instrument/InstrumentReservationService.java` / `InstrumentReservationServiceImpl.java` | 新增 cancelReservation/finishReservation/adjustReservation/voidReservation/getReservationPage + fillOperateFlags（can* 标记） | r3 + 本批 |
| `controller/admin/instrument/vo/reservation/ReservationCancelReqVO.java` 等 4 个 ReqVO | cancel/adjust/finish/void 请求体（含校验注解） | r3 |
| `controller/admin/instrument/vo/reservation/ReservationPageReqVO.java` | 分页请求（deviceId/userId/reservationNo/status/startTimeBegin/End + PageParam） | 本批新增 |
| `dal/mysql/instrument/InstrumentReservationMapper.java` | 生命周期条件更新（affectedRows 兜底）+ selectPage（数据范围 SQL 裁剪：本人 OR deviceId IN 授权集合） | r3 + 本批 |
| `enums/ErrorCodeConstants.java` | 094 CANCEL_DENIED / 095 ADJUST_DENIED / 096 ADJUST_CONFLICT / 097 FINISH_DENIED / 098 VOID_DENIED | r3 |
| `test/.../Instrument03DLifecycleTest.java` | 21 个生命周期用例（状态机/并发/权限/同事务回滚） | r4 |
| `test/.../Instrument03IsolationGuard.java` | **加固**：覆盖 dynamic-datasource 实际键（见 §6.1） | 本批 |
| `test/.../Instrument03IsolationGuardTest.java` | **新增** 7 个守卫单测 | 本批 |
| `yudao-server/.../application-instrument-03-test.yaml` | **结构纠错**：datasource 对齐 `spring.datasource.dynamic.*`（见 §6.2） | 本批 |

### §2.2 前端（yudao-ui-admin-vue3）

| 文件 | 改动 |
|------|------|
| `src/api/lab/instrument/reservation/index.ts` | 新增 cancel/finish/adjust/void/getHistoryList/getPage 6 个方法 + ReservationPageReqVO 等类型 + RespVO 4 个 can* 字段 |
| `src/views/lab/instrument/components/ReservationActionDialogs.vue` | **新建**共享组件：取消/调整/完成/作废四对话框 + 操作历史抽屉，expose openCancel/openAdjust/openFinish/openVoid/openHistory |
| `src/views/lab/instrument/my-reservation/index.vue` | **改写**：操作列按服务端 can* 标记显隐（取消/调整/历史）；详情抽屉加操作区与操作历史入口 |
| `src/views/lab/instrument/reservation-manage/index.vue` | **新建**管理端预约管理页（组件名 LabInstrumentReservationManage，对应 07 号菜单设计路径 `lab/instrument/reservation-manage/index`）：分页 + 单号/设备/状态筛选 + 详情/取消/调整/完成/作废/历史 |
| `src/views/lab/instrument/device/components/ReservationForm.vue` | 移除废弃容量名额文案（WINDOW_FULL 映射与容量注释） |

---

## §3 已交付的生命周期接口与前端入口

### §3.1 后端接口

| 接口 | 方法/路径 | 权限串 | 规则摘要 |
|------|-----------|--------|----------|
| 取消 | PUT `/lab/instrument/reservation/cancel` | `reservation:cancel` | 本人开始前；管理侧任意时刻且原因必填；仅 PENDING |
| 完成 | POST `/lab/instrument/reservation/finish` | `reservation:manage` | 授权范围内；仅 PENDING；实际起止必填 |
| 调整 | PUT `/lab/instrument/reservation/adjust` | `reservation:cancel`（**待裁决 T1**，见 §7） | 仅 PENDING；设备行锁内 P1~P8 复核；可换设备 |
| 作废 | POST `/lab/instrument/reservation/void` | `reservation:manage` | 授权范围内；仅 PENDING；原因必填 |
| 历史 | GET `/lab/instrument/reservation/history-list` | `reservation:query` | 本人或授权负责人/管理员 |
| 分页 | GET `/lab/instrument/reservation/page` | `reservation:query` | 数据范围=本人 OR 授权设备（SQL 裁剪） |

错误码（23 §5.2 冻结）：094 无权取消或当前状态不可取消 / 095 无权调整或当前状态不可调整 / 096 调整后时段冲突 / 097 当前状态不可登记完成 / 098 当前状态不可作废。

### §3.2 前端入口

| 页面 | 入口 | 操作 |
|------|------|------|
| 我的预约 | 既有页面 | 查询、详情、取消、调整、操作历史（按 can* 显隐） |
| 预约管理 | 新建页面（菜单 SQL 未执行，见 §8） | 分页查询、详情、取消、调整、完成、作废、操作历史 |
| 预约日历/详情 | 既有页面 | 状态展示（can* 标记由 my/get/page 接口返回） |

**权限声明**：前端按钮显隐仅按服务端 can* 标记做展示控制，**不等于权限保护**；所有操作由后端 `@PreAuthorize` + Service 数据范围/状态机再次校验。

---

## §4 状态迁移规则（冻结核查后确认）

### §4.1 状态机

```
PENDING ──取消──> CANCELED（终态）
PENDING ──完成──> FINISHED（终态，保留历史占用记录）
PENDING ──作废──> VOIDED（终态）
PENDING ──调整──> PENDING'（时段/设备变更，同状态内迁移）
FINISHED/CANCELED/VOIDED ──任何写操作──> 拒绝（094/095/097/098）
```

### §4.2 占用规则（U4 冻结）

| 状态 | 是否占用可预约时段 |
|------|---------------------|
| PENDING | ✅ 占用 |
| FINISHED | ✅ 保留历史占用记录（不被取消/作废接口覆盖） |
| CANCELED | ❌ 释放 |
| VOIDED | ❌ 释放 |

### §4.3 取消时限核查（任务书强制项）

22 号 C2 冻结规则：**本人预约开始前可取消，无提前量要求**；管理侧（负责人/管理员）任意时刻可取消且原因必填。已逐字核查 22/23/24 号文档，**未发现"开始前 N 小时才能取消"类规定**，本次实现未擅自新增任何时限门槛。

### §4.4 幂等与并发兜底

- 取消/完成/作废 = 事务内**条件更新**（`WHERE id=? AND status='PENDING'`），affectedRows=0 即抛对应 09x 错误码——两人同时取消同一预约只有一笔生效，不重复释放、不产生重复历史。
- 调整 = 设备行锁（`selectByIdForUpdate`）内全链复核；跨设备调整按设备 id 升序加双锁防死锁；校验失败整体回滚，原预约不变。
- 业务状态变更与 history INSERT 处于**同一事务**：任一失败两者均回滚，无部分提交。

---

## §5 测试用例与结果

### §5.1 执行命令与结果

```
命令：mvn clean test -pl yudao-module-lab -o
结果：Tests run: 180, Failures: 0, Errors: 0, Skipped: 0 —— BUILD SUCCESS
```

### §5.2 测试分布

| 测试类 | 用例数 | 说明 |
|--------|--------|------|
| Instrument03DLifecycleTest | **21** | 本次生命周期核心：取消/完成/调整/作废/历史/并发 |
| Instrument03CReservationCreateTest | 32 | 创建链路回归（D2 外层重试含其中）——**未因本次改造回归** |
| Instrument03ConcurrencyTest | 4 | 并发基线 |
| Instrument03BBookingRuleWindowTest | 18 | 预约规则/窗口 |
| Instrument03DataLayerTest | 21 | 数据层 |
| Instrument03LockCoordinatorTest | 3 | 锁协调器 |
| Instrument02ServiceTest | 26 | INSTRUMENT-02 回归 |
| PlasmidStorageServiceImplTest | 17 | 质粒存储回归 |
| RegisterApplyServiceImplTest | 31 | 注册申请回归 |
| **Instrument03IsolationGuardTest** | **7** | **本批新增**：守卫覆盖验证（见 §6.1） |
| **合计** | **180** | |

### §5.3 生命周期 21 用例覆盖点（摘要）

- 状态机：非法迁移全拒（FINISHED 再取消/再作废、CANCELED 再完成、VOIDED 再调整）
- 取消：本人开始前成功、开始后拒绝、管理侧任意时刻成功、管理侧原因必填、重复取消第二笔 094
- 完成：仅 PENDING、实际起止必填、完成记录保留、历史同事务
- 调整：锁内复核失败原预约不变、调整后时段冲突 096、新旧时段占用一致、跨设备双锁顺序
- 作废：原因必填、操作人记录、作废后释放占用
- 并发：双取消仅一笔生效、完成/作废与取消竞态仅合法迁移落地、事务失败状态与历史均回滚
- 租户隔离与数据范围：越租户/越授权范围访问拒绝

### §5.4 证据边界声明（任务书 §六.5）

> **H2 180/180 全绿仅作为代码阶段证据。** H2 MVStore 行锁语义与 MySQL 8.0.12 InnoDB（RR 隔离、next-key lock）存在差异；**不得将本结果解读为真实 MySQL 并发已通过**。真实并发验证（同时段独占、暂停/预约交错、D2 重试命中、生命周期竞态）为部署前门槛，待隔离环境授权启动后执行。

---

## §6 隔离环境准备状态（任务书 §七）

### §6.1 隔离守卫覆盖核查 —— 发现真实缺口并已修复

**核查结论：初版守卫（32 号交付）未覆盖实际 DataSource 客户端。**

| 检查项 | 初版状态 | 证据 | 本批处置 |
|--------|----------|------|----------|
| DataSource 键覆盖 | ❌ **真空放行**：仅查 `spring.datasource.url` | 项目由 dynamic-datasource 装配，实际生效键为 `spring.datasource.dynamic.datasource.master.url`（application-local.yaml L48-51）；初版读到空值后按"无配置"跳过 | 已加固：枚举全部 `spring.datasource.dynamic.datasource.*.url`（master/slave 直查 + EnumerablePropertySource 全枚举）+ 保留单源兜底键 |
| Redis 键覆盖 | ✅ 有效 | 项目 Spring Boot **2.7.18**，标准键即 `spring.redis.host/port`（application-local.yaml L85-87），与守卫一致 | 无需修改 |
| 守卫自验证 | ❌ 无测试 | — | 新增 Instrument03IsolationGuardTest 7 用例：dynamic 主键含 labplatform 拒绝 / dynamic 主键 3306 拒绝 / dynamic 从键 3306 拒绝 / 单源键 3306 拒绝 / Redis 6379 拒绝 / 隔离配置放行 / 无配置放行 |

### §6.2 隔离 profile 结构核查 —— 发现真实缺陷并已修复

**核查结论：初版 `application-instrument-03-test.yaml` 数据源层级错误，隔离环境按此配置无法获得有效 master 数据源。**

| 缺陷 | 初版 | 修复后 |
|------|------|--------|
| primary/datasource 挂载点 | `spring.datasource.druid.*`（dynamic 装配器读不到） | `spring.datasource.dynamic.*`（与 application-local.yaml 对齐） |
| 连接池参数挂载点 | `spring.datasource` 直下（无效位置） | `spring.datasource.dynamic.druid.*` |
| Redis 键 | `spring.redis.*` | 不变（Boot 2.7 标准键，正确） |
| C7 开关 | `create-enabled: true` | 不变（隔离环境显式开启，正式库保持 false） |

### §6.3 其余配置只读复核（未改动）

| 文件 | 复核结果 |
|------|----------|
| `instrument03-test-env/docker-compose.yml` | ✅ MySQL 8.0.12 @ 127.0.0.1:3307、Redis 7 @ 127.0.0.1:6380、仅绑回环、instrument03- 前缀资源、独立 volume/网络 |
| `instrument03-test-env/init/00-schema-baseline.sql` | ✅ 03-A 基础表 + CAP-A DDL（system_* 核心表按 32 §5.2 由 mysqldump 单独导入） |
| `start.ps1` / `stop-and-clean.ps1` / `.env.example` / `20-item-concurrency-matrix.md` | ✅ 齐备 |

### §6.4 启动门禁判定

| 门禁项 | 状态 |
|--------|------|
| 守卫覆盖实际 DataSource/Redis | ✅ 本批修复 + 7 单测全绿 |
| 隔离 profile 可装配 | ✅ 本批修复 |
| Docker 容器启动 | ❌ **未执行（未授权）** |
| 真实并发 20 项矩阵 | ❌ 未执行（依赖容器启动） |
| **隔离环境整体** | **READY-PENDING-AUTH**（配置与守卫就绪，等待 Docker 授权） |

按任务书要求：门禁修复先于报告完成；**未为赶进度绕过任何隔离保护**（未启动容器、未连接任何真实实例）。

---

## §7 未完成项与待裁决业务规则

| 编号 | 事项 | 现状 | 处置要求 |
|------|------|------|----------|
| **T1** | **本人调整预约的权限串缺口**：23 §4.2 定义 `:adjust` 仅限负责人/管理员；本人是否有权调整自己的预约，冻结文档未明确 | Controller adjust 端点暂挂 `reservation:cancel` 权限串（与取消同门槛），Service 内按本人/管理侧分别校验数据范围 | **待负责人裁决**：确认 `:adjust` 权限串归属与本人调整权限后，再调整 Controller 注解与菜单授权 |
| **T2** | **窗口设备调整的 windowId 边界**：窗口设备调整是否必须重传 windowId 归属、换窗口是否视为换设备同协议，23 §6.6 未逐字定义 | 现实现：同设备改时段不重传；换设备时按目标设备类型重新校验开放时段（窗口设备须在授权窗口内） | **待裁决**：是否冻结"窗口设备调整必须显式传 windowId" |
| **T3** | export-excel 预约导出 | 24 号 §03-D 范围，本任务书未列入 | 转下一阶段 |
| **T4** | 预约管理页菜单 SQL（07 号设计：`lab/instrument/reservation-manage/index`） | 页面组件已交付，菜单 SQL 未执行 | 待授权后与 13674~13676 一并 apply |
| **T5** | 真实 MySQL 并发验证 | 隔离环境 READY-PENDING-AUTH | 待 Docker 授权后执行 20 项矩阵 + 生命周期竞态项 |
| **T6** | 暂停创建获取设备行锁（完全消除暂停/预约交错） | 32 §3.6 HOLD，任务书 B3 当前未冻结 | 待任务书冻结后实施 |
| **T7** | TOCTOU 严格消除（数据库栅栏/version 字段） | 32 §3.6 HOLD | 待 03-D 冻结 |

**说明**：取消时限已核查（§4.3），22 C2 冻结为"本人开始前，无提前量"，**不构成待裁决项**；本次未新增任何未冻结的业务规定。

---

## §8 正式数据库 / 正式 Redis / Docker / C7 操作记录

| 对象 | 操作记录 |
|------|----------|
| 正式 labplatform（DDL/DML/菜单） | **均未操作**（0 次连接、0 条 SQL） |
| 正式 Redis | **均未操作**（0 次连接、0 次读写） |
| Docker | **均未操作**（0 次 create/start/down；compose 文件仅复核未执行） |
| C7 创建开关 | **正式库保持 false，未开启**；隔离 profile 配置 true 但对应环境未启动 |

---

## §9 结论

| 维度 | 判定 |
|------|------|
| 生命周期后端（取消/完成/调整/作废/历史） | ✅ 交付，21 用例覆盖 |
| 前端闭环（我的预约 + 预约管理 + 共享操作组件 + 容量文案清理） | ✅ 交付，vue-tsc 无本模块错误（存量错误均位于 fms/hrm/plasmid 等非本任务模块） |
| 状态机/幂等/同事务/租户与数据范围 | ✅ H2 证据完备 |
| 创建链路回归 | ✅ 32 创建用例全绿 |
| 隔离守卫与 profile | ✅ 两处真实缺口修复 + 7 用例全绿 |
| 真实 MySQL 并发验证 | ❌ 未执行（Docker 未授权） |
| 菜单 SQL / export-excel / 硬件 | ❌ 不在本批或待授权 |

**整体判定：CONDITIONAL PASS（代码阶段）**

- 本报告所述全部"完成"仅指**代码实现 + H2 单元测试证据**；
- **正式上线判定为 HOLD**：须待 ① 隔离环境 Docker 授权启动并完成真实 MySQL 并发验证（含生命周期竞态）；② T1/T2 业务裁决落地；③ 菜单 SQL 授权执行；三项齐备后方可转 PASS。
- **禁止**将"代码实现完成"或"H2 180/180 全绿"直接解读为"正式可上线"。

---

## §10 下一阶段剩余事项（按优先级）

| 优先级 | 工作项 | 前置条件 |
|--------|--------|----------|
| P0 | T1 本人调整权限串裁决 + T2 窗口设备调整 windowId 边界裁决 | 负责人书面裁决 |
| P0 | 隔离环境启动（Docker 授权）+ 20 项真实并发矩阵 + 生命周期竞态验证 | Docker 授权 |
| P1 | 预约管理页菜单 SQL apply（07 号设计） | 隔离验证通过 + 授权 |
| P1 | export-excel 预约导出（T3） | 另立任务 |
| P2 | 暂停创建设备行锁（T6）/ TOCTOU 严格消除（T7） | 任务书冻结 |

---

*报告结束。所有修改均在授权范围内执行，真实 labplatform / 正式 Redis / Docker / C7 零操作。*
