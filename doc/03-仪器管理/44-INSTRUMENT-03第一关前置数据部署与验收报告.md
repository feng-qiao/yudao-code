# 44 - INSTRUMENT-03 第一关前置数据部署与验收报告

- 任务编号：TASK INSTRUMENT-03-R8-STAGE1-PREP-DEPLOY-01
- 任务名称：INSTRUMENT-03 真实预约验收第一关：正式业务备份、测试账号及最小前置数据部署与验收
- 报告日期：2026-10-20
- 数据库：labplatform（MySQL 8.0.12，127.0.0.1:3306）
- 租户 / 套餐：162 / 114
- 目标设备：device_id=2（Clean Device 02，SCIENCE）

---

## 一、最终判定

**PARTIAL PASS / HOLD**

D0 预检、D1 基线备份、D2 测试账号、D3 预约规则四个阶段全部完成并验收通过；D4（资质申请/审批/信用核验）与 D5（设备负责人关系）因**后端进程意外中断**未执行。依据任务书第十章失败停止规则第 14 条（后端进程意外重启/停止）与第 16 条（无法确认是否成功的连接中断），已停止全部后续写入，保留现状，等待负责人裁决。

本判定经负责人确认：按 PARTIAL PASS 收尾并生成本报告。

---

## 二、负责人授权范围

负责人正式授权第一关，仅覆盖真实预约验收前置准备：只读预检、九张业务表及受影响系统表基线备份、经正式业务 API 创建测试账号/分配单一角色/配置 device 2 最小预约规则/准备资质/建立 test908 设备负责人关系，并验证与出报告。**不含** C7 开启、预约创建、预约生命周期写入。授权边界与 16 项禁止事项按任务书第二章执行，全程未越界。

---

## 三、D0 预检结果（全部 PASS）

### 3.1 环境

- MySQL 8.0.12；库 labplatform；租户 162；套餐 114。
- 后端进程 PID 41788 = `YudaoServerApplication`，2026-10-19 12:37:45 启动，classpath 为 `E:\lixin\dev\ruoyi-vue-pro\yudao-server\target\classes` 源码编译输出，非 43 号报告旧 PID，命令行无 `-Dspring.profiles.active`，即非 instrument-03-test profile。
- C7 证据：`create-enabled: true` 仅存在于 `application-instrument-03-test.yaml`；正式 yaml 无覆盖；源码默认 false；运行进程非 test profile。综合判定 **C7=false**（未通过实际创建预约验证）。

### 3.2 设备

- device 2：tenant_id=162、category=SCIENCE（使用 booking_rule，不依赖 booking_window）、status=NORMAL、bookable=1、未逻辑删除。

### 3.3 角色与账号

- 角色权限集（system_role_menu + menu 实查，均 status=0 启用、tenant 162）：
  - 904 普通用户 = 33 菜单（含 lab:instrument: reservation:create/adjust/cancel/query、qualification:apply/query 等）；
  - 905 库管员 = 48 菜单，**lab:instrument 权限为空**（天然"无预约权限"验收素材）；
  - 906 本草基因管理员 = 123 菜单全量（含 rule:update、manager:manage、qualification:audit 等）；
  - 908 仪器设备负责人 = 15 菜单（含 qualification:audit、reservation:* 管理组）。
- 既有账号：260 qinghy = 903,905,906,908；278 bencao = 904,905,906；281（账号A，189140002）= 纯 904；265（账号B，189140001）= 纯 904。
- test906 / test908 / test905 / test904nq 均不存在，无同名、逻辑删除或预留冲突。

### 3.4 业务数据基线（与 43 号"空表"结论的差异已评估可控）

- booking_rule / booking_window / reservation / reservation_history：全空。
- qualification 2 行（均 281：id=1 DEVICE2 **SUSPENDED**、id=2 DEVICE1 ACTIVE）；apply 2 行（281，APPROVED）；apply_history 4 行。
- credit_account 1 行（user 281，score=70，已初始化）；credit_flow 3 行。
- manager 3 行（均 ROOM_REPAIR 房间 1：id=1 265 RELEASED、id=2 281 ACTIVE、id=3 265 ACTIVE），无 DEVICE/PLATFORM scope。
- suspend 3 行（均 281：id=1 SINGLE dev2 RELEASED、id=2 ALL RELEASED、id=3 **ALL ACTIVE**，2026-10-15 16:55:10 ~ 2026-10-22 16:55:10）。
- 以上全部为 2026-10-15 测试产物，与本轮 device 2 配置无冲突。
- **账号 A 评估**：其 device 2 资质为 SUSPENDED（非 ACTIVE），doApply 仅拦截 PENDING 申请与 ACTIVE 资质，可重新申请；G13 暂停不拦截申请。A 信用已初始化，"首审初始化 100 分"验证点改用 B / test906 / test908。

### 3.5 API 核实（均以当前源码为准）

- `POST /system/user/create`（@PreAuthorize system:user:create；必填 username/nickname/password）
- `POST /system/permission/assign-user-role`（userId + roleIds）
- `PUT /system/user/update`（本轮仅用于修复新账号 nickname/remark 中文编码，不动角色/密码）
- `POST /lab/instrument/booking-rule/save`（rule:update + Service 层 canManageAll；一设备一规则 upsert；启用时 granularity>0 且 minDuration 必填）
- `GET /lab/instrument/booking-rule/get`
- `POST /lab/instrument/qualification/apply`（申请人 = 登录者本人；doApply 拦截 PENDING 申请与 ACTIVE 资质）
- `POST /lab/instrument/qualification/audit`（功能权限 + canManageDevice 数据范围双校验；result=APPROVED/REJECTED）
- `POST /lab/instrument/manager/assign`（manager:manage；ManagerAssignReqVO；selectActive 防重）

---

## 四、D1 基线备份（PASS）

- 备份时间：2026-10-20 00:11:57（文件时间戳 20261020T001157，唯一，不覆盖）。
- 备份文件：`E:\lixin\dev\backup\instrument03\instrument03-r8-stage1-baseline-20261020T001157.sql`
- 文件大小：55,287 字节。
- **SHA-256：`C35517EBB0C1DF7EF06C5879C7ED9C6BB7A386DC169952C08AA4B03BF43F93DB`**
- 覆盖表清单（13 张）：九张业务表（lab_instrument_booking_rule、lab_instrument_booking_window、lab_instrument_qualification、lab_instrument_qualification_apply、lab_instrument_qualification_apply_history、lab_instrument_manager、lab_instrument_suspend、lab_instrument_reservation、lab_instrument_reservation_history）+ 受账号/角色/信用副作用影响的系统表（lab_instrument_credit_account、lab_instrument_credit_flow、system_users、system_user_role）。
- 验收：mysqldump 退出码 0；13 个 CREATE TABLE 完整；9 张表含 INSERT（4 张空表 rule/window/reservation/reservation_history 无 INSERT，与实测一致）；无 CREATE DATABASE/USE（未含无关数据库）；位于非 Git 目录；凭据经 MYSQL_PWD 环境变量传递，命令行未明文暴露。
- 未执行任何恢复操作。

---

## 五、D2 测试账号（PASS）

### 5.1 创建结果（经正式 user/create + assign-user-role API）

| userId | username | 角色集合（实查） | 用途 |
|---|---|---|---|
| 282 | test906 | 仅 906 | 纯净管理员验收 |
| 283 | test908 | 仅 908 | 设备负责人及数据范围验收 |
| 284 | test905 | 仅 905 | 无预约权限验收 |
| 285 | test904nq | 仅 904 | 无 device 2 资质的 904 拒绝测试（不授予 device 2 资质） |

- 初始密码由负责人经安全方式提供，本报告不记录；未赋予 tenant_admin；未修改任何已有用户；四个账号 tenant_id=162、status=0 启用、无跨租户授权（新账号 tenant_id<>162 行数为 0）。
- 账号命名 test904nq 为本轮新建可追踪专用名（D0 已确认无冲突）。

### 5.2 账号验收（数据库实查）

- 角色集合严格等于预期单角色，无其他角色残留。
- 既有账号角色未变：260 = 903,905,906,908；265 = 904；278 = 904,905,906；281 = 904（与 D0 基线逐组一致）。
- 菜单与权限集合由角色定义继承，角色定义本轮未触碰（未执行菜单 SQL，未修改 role_menu）。

---

## 六、D3 预约规则（PASS）

### 6.1 配置内容（test906 经 booking-rule/save 写入，id=1）

| 字段 | 值 |
|---|---|
| device_id | 2 |
| tenant_id | 162 |
| granularity_minutes | 30 |
| min_duration_minutes | 30 |
| max_duration_minutes | 240 |
| bookable_days_before | 0 |
| bookable_days_ahead | 7 |
| open_days | 1,2,3,4,5（工作日） |
| open_start_time / open_end_time | 09:00 / 18:00 |
| allow_cross_day | false（不跨日） |
| allow_admin_adjust_after_start | false |
| enabled | true |
| remark | INSTRUMENT-03 第一关验收规则 工作日09:00-18:00 粒度30min 时长30-240min |

### 6.2 设计依据与覆盖

- 有限可测：工作日 09:00-18:00、粒度 30 分钟、时长 30~240 分钟、仅未来 0~7 天，未采用全周全时段配置。
- 覆盖验收场景：合法预约（工作日内 30 分钟倍数时段）、未开放时段拒绝（周末/09:00 前/18:00 后）、重叠冲突与相邻时段（由预约服务 P6 边界处理，规则不阻碍）、取消与调整（规则不限制）、不跨日（allow_cross_day=false）。
- 写入前确认 booking_rule 全空，device 2 无既有正式规则，upsert 为纯插入，未覆盖任何非本轮数据。

### 6.3 规则验收（只读 API + SELECT 双验）

- 仅 device 2 一条规则（全表 1 行），enabled=1，未删除；字段与提交值逐项一致（remark CHAR_LENGTH=56 / LENGTH=84，14 个中文字符按 UTF-8 三字节正确存储）。
- booking_window 表 0 行，未误创建。
- 无其他设备/其他租户规则（tenant_id<>162 行数为 0）。

---

## 七、D4 资质准备（未执行，BLOCKED）

- 计划：账号 A(281)、B(265)、test906(282)、test908(283) 各自经 qualification/apply 申请 device 2 → lab_admin 账号经 qualification/audit 审批 APPROVED → 核验 ACTIVE 资质、申请/审批历史、信用账户（B/test906/test908 首审初始化 100 分；A 已初始化 70 分不重置不加分）。test904nq 与 test905 不授予 device 2 资质。
- 实际：2026-10-20 07:02 起，四个账号的 login 调用均连接拒绝（后端进程已停止），**未产生任何数据库写入**。
- 终态证据：qualification 仍 2 行（281 dev2 SUSPENDED、281 dev1 ACTIVE）、apply 仍 2 行、apply_history 仍 4 行、credit_account 仍 1 行（user 281，70 分）、credit_flow 仍 3 行，全部与 D0 基线一致。
- 审批资格预案（供续作参考）：audit 需功能权限 + canManageDevice 数据范围双校验，D4 审批应使用 qinghy 或 bencao（lab_admin）；test908 的 DEVICE 关系在 D5 才建立，不能用于 D4 审批。

---

## 八、D5 设备负责人关系（未执行，BLOCKED）

- 计划：经 manager/assign 为 test908(283) 建立 scope=DEVICE、target(device_id)=2、status=ACTIVE、tenant_id=162 的负责人关系。
- 实际：因同一后端中断未执行。终态 manager 表仍 3 行 ROOM_REPAIR（与 D0 基线一致），无 DEVICE/PLATFORM scope，既有维修负责人记录未变。

---

## 九、本轮业务 API 调用清单及实际影响

| # | API | 结果 | 实际影响 |
|---|---|---|---|
| 1 | POST /system/auth/login（qinghy、test906 等） | code=0 | 获取访问凭据（不记录于本报告） |
| 2 | POST /system/user/create ×4 | code=0，返回 282/283/284/285 | system_users 新增 4 行（tenant 162） |
| 3 | POST /system/permission/assign-user-role ×4 | code=0 | system_user_role 新增 4 行（严格单角色） |
| 4 | PUT /system/user/update ×4 | code=0 | 仅修复 4 个新账号 nickname/remark 中文编码，不动角色/密码/既有用户 |
| 5 | POST /lab/instrument/booking-rule/save ×2 | code=0，均返回 id=1 | 第 1 次插入规则；第 2 次 upsert 同一行修复 remark 中文，未新增行、未覆盖他方数据 |
| 6 | GET /lab/instrument/booking-rule/get?deviceId=2 | code=0 | 只读回查，无写入 |
| 7 | POST /system/auth/login（189140002 / 189140001 / test906 / test908，D4 阶段） | 连接拒绝 ×4 | **无写入**（后端已停止） |

影响表集合：system_users、system_user_role、lab_instrument_booking_rule，均在 D1 备份覆盖清单内。

---

## 十、D6 只读综合验收证据（当前终态）

### 10.1 预约表与历史表未新增

- lab_instrument_reservation = 0 行；lab_instrument_reservation_history = 0 行。本轮未调用任何预约创建/cancel/adjust/finish/void 接口。

### 10.2 C7=false

- 源码默认 false；`create-enabled: true` 仅存在于 `application-instrument-03-test.yaml`；正式 yaml 无覆盖；D0 时进程非 test profile；当前后端进程已停止且未重启。未通过实际创建预约验证。

### 10.3 既有用户与其他租户未受影响

- 既有账号角色与 D0 基线逐组一致（§5.2）；未修改既有用户密码；未执行菜单 SQL 或 role_menu 变更。
- 本轮写入全部 tenant_id=162；booking_rule 无 tenant_id<>162 行；新账号无跨租户行。
- 未执行任何 DDL；未直接 DML 仪器业务表（全部经业务 API）；未触碰 Redis；未重启/替换后端进程。

---

## 十一、异常与停止原因

### 11.1 异常一：PowerShell 中文编码（已闭环）

- 现象：首批 user/create 与 booking-rule/save 的中文 nickname/remark 落库变为 `?`（Invoke-RestMethod 默认按 Latin-1 编码请求体）。
- 处理：改用 UTF-8 字节体重提（user/update ×4；booking-rule/save upsert 同一 id=1），复核 CHAR_LENGTH/LENGTH 确认中文按 UTF-8 正确存储。功能字段（角色、规则数值/时间/enabled）自始至终未受影响。
- 教训：本环境后续 API 调用一律采用 UTF-8 字节体 + `charset=utf-8`。

### 11.2 异常二：后端进程意外中断（触发停止规则）

- 时间线：D0 确认 PID 41788 于 2026-10-19 12:37:45 启动；D2/D3 于 2026-10-20 00:2x~00:5x 正常完成；2026-10-20 07:02 D4 login 全部连接拒绝，诊断确认 PID 41788 已消失、48080 端口无监听、仅存 IDE 语言服务器 Java 进程。
- 影响面：中断点位于 D4 login 阶段，无半截写入（apply/qualification/credit 等表与基线一致）；D2/D3 已提交数据完整保留于 MySQL。
- 处置：依据失败停止规则第 14/16 条立即停止后续写入，不重启进程、不补偿、不重试；记录已写入对象（§12）；经负责人裁决按 PARTIAL PASS / HOLD 收尾。

---

## 十二、已创建记录清单（保留现状，未清理）

按任务书"已成功完成的合法阶段可以保留"，以下对象保留，等待负责人决定后续处理：

| 对象 | ID | 说明 |
|---|---|---|
| system_users | 282 test906 / 283 test908 / 284 test905 / 285 test904nq | tenant 162，启用，初始密码由负责人掌握 |
| system_user_role | 282→906 / 283→908 / 284→905 / 285→904 | 严格单角色 |
| lab_instrument_booking_rule | id=1 | device 2，工作日 09:00-18:00，30min 粒度，30-240min，0-7 天，enabled |

未完成项目：D4 资质申请/审批/信用核验（四目标用户）；D5 test908 DEVICE ACTIVE 负责人关系；D6 中依赖 D4/D5 的资质与负责人验收项。

---

## 十三、第二关 C7 开启前的剩余条件

1. 负责人在 IDEA 中检查并重新启动后端，确认进程、48080 端口与启动日志正常（本次中断原因建议一并排查）。
2. 重启后只读复核 D2/D3 数据仍在（四账号、四角色关系、规则 id=1 enabled）。
3. 补做 D4：A/B/test906/test908 各自 apply device 2 → lab_admin 账号 audit APPROVED → 核验 ACTIVE 资质、申请/审批历史、信用账户（B/test906/test908 首审初始化 100 分；A 不重复初始化）。
4. 补做 D5：manager/assign 建立 test908 DEVICE(device 2) ACTIVE 关系，核验范围不越界。
5. 补做 D6 剩余验收（含 C7=false 复核、预约表仍空复核）。
6. **账号 A 远期风险规避顺序**：本轮为 A 新批 device 2 ACTIVE 资质后，若未来需人工解除 A 的 ALL 暂停（id=3），必须先经 revoke API 撤销新批 ACTIVE 资质再解除暂停，使旧 SUSPENDED 行（id=1）恢复为唯一 ACTIVE；否则 resumeUncoveredQualifications 会造成同设备双 ACTIVE 并使 selectOne 抛 TooManyResultsException。
7. 负责人对第一关 PARTIAL PASS 正式签认后，方可申请第二关 C7 授权。

---

## 十四、执行结束边界声明

任务已停止。未执行：C7 开启、IDEA 后端重启、真实预约创建、预约生命周期写入、测试数据清理、备份恢复。等待负责人下一次明确授权。

（本报告不含密码、Token、Cookie 或数据库连接凭据。）
