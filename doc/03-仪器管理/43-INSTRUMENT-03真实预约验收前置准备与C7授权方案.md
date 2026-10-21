# 43 - INSTRUMENT-03 真实预约验收前置准备与 C7 授权方案

- 任务号：`TASK INSTRUMENT-03-R7-ACCEPTANCE-PREP-01`
- 生成日期：2026-10-19
- 目标库：`labplatform` ｜ 租户：162 ｜ 套餐：114 ｜ C7：false
- 基线：41 号 DEPLOY PASS / MENU READY；42 号 CONDITIONAL PASS
- 本轮**仅**：只读检查 + 生成验收文档/SQL 设计稿/配置变更方案。**未**写库、未改运行配置、未重启后端、未开 C7
- **最终判定：READY FOR AUTHORIZATION**

> 本报告全部为「方案与设计稿」，无任何已执行业务写入。所有 SQL 仅为设计稿，未执行。报告不含明文密码。

---

## 1. 实际环境与数据缺口

### 1.1 环境
- 后端：IDEA 托管 `YudaoServerApplication`（PID 41788，2026-10-19 12:37 启动），`active: local` → `application-local.yaml`。
- DB：MySQL 8.0.12 `127.0.0.1:3306/labplatform`；Redis：`127.0.0.1:6379` db=0（本地，单号生成依赖）。
- C7：`create-enabled` 默认 **false**（local yaml 无该键）。

### 1.2 可预约设备
| id | name | device_no | category | status | bookable | tenant |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 验收测试酶标仪01 | DEV-TEST01 | MICROPLATE_READER | SCRAPPED | 1 | 162 |
| **2** | Clean Device 02 | DEV-TEST02 | **SCIENCE** | **NORMAL** | **1** | 162 |

**设备 id=2 为本轮唯一可预约设备**：SCIENCE 类别（非 MICROPLATE_READER）→ 按服务端规则使用 **booking_rule 规则时段**，**不需要 booking_window**（窗口仅 MICROPLATE_READER 需要）。状态 NORMAL、bookable=1，满足 P1/P2。

### 1.3 数据缺口（全部待准备，见 §3）
| 数据 | 现状 | 缺口 |
| --- | --- | --- |
| `lab_instrument_booking_rule`（device 2） | 0 行 | 需创建（P3 校验依赖） |
| `lab_instrument_booking_window` | 0 行 | **SCIENCE 不需要** |
| `lab_instrument_qualification` | 0 行 | 需为测试用户创建有效资质（P4） |
| `lab_instrument_manager`（DEVICE ACTIVE） | 0 行（仅 ROOM_REPAIR 范围） | 908 设备范围测试需 DEVICE ACTIVE 关系 |
| `lab_instrument_suspend` | 0 行 | 暂停拒绝用例需 1 条生效暂停 |
| `lab_instrument_reservation` / `history` | 0 行 | 由业务 API 在验收中产生（不直接 INSERT 冒充） |
| 纯净 908/905 账号 | 缺失 | 需新建或复用方案（见 §2） |

---

## 2. R7-B 测试账号与角色方案

### 2.1 现有账号盘点（只读）
| id | username | 角色 | 可作纯净账号？ |
| --- | --- | --- | --- |
| 281 | 189140002 | 904 | ✅ 纯净 904（账号A） |
| 265 | 189140001 | 904 | ✅ 纯净 904（账号B，跨用户隔离用） |
| 260 | qinghy | 903+905+906+908 | ❌ 联合（不动，遵约束） |
| 278 | bencao | 904+905+906 | ⚠️ 联合（含 906，但非纯净） |
| 266 / 274 | 189140003 / 189140004 | 904+905 | ⚠️ 联合 |
| 279 | shenpi | 907 | ✗ 无关角色 |
| 264 | probenosuchuser9 | 无 | ✗ 无角色 |

### 2.2 账号方案（优先复用，新建需授权）
| 用途 | 方案 | 说明 |
| --- | --- | --- |
| 纯净 904（账号A） | **复用 281 `189140002`** | 主测试普通用户 |
| 第二个独立 904（账号B，跨用户隔离） | **复用 265 `189140001`** | 用于「904 看不到他人预约」 |
| 纯净 906 | **方案一（推荐）**：新建 `test906`（仅 906，租户 162）<br>**方案二（复用）**：用 `bencao`（904+905+906）——但 906 验收会被 904/905 联合授权污染，不推荐用于「906 具备/不具备」边界判定 | 需授权 |
| 纯净 908 | **新建 `test908`**（仅 908，租户 162）+ DEVICE ACTIVE 关系 | 需授权 |
| 纯净 905 | **新建 `test905`**（仅 905，租户 162） | 需授权 |

**新建账号设计（待授权，不含密码）**
| username | nickname | tenant | role | 数据范围 | 清理方式 |
| --- | --- | --- | --- | --- | --- |
| test906 | 测试-管理员 | 162 | 906 | 全量（lab_admin） | 验收后禁用或删除账号 |
| test908 | 测试-设备负责人 | 162 | 908 | device_id=2（DEVICE ACTIVE） | 验收后删除 DEVICE 关系 + 禁用/删除账号 |
| test905 | 测试-库管员 | 162 | 905 | 无预约范围 | 验收后禁用/删除账号 |

> 不修改 `qinghy` 的 903/905/906/908 联合关系。新建账号密码由负责人在授权时单独设定，本报告不记录。

---

## 3. R7-C 最小业务数据设计稿（仅设计，未执行）

> 全部优先经**正式业务 API** 创建；预约记录**绝不**绕过 API 直接 INSERT 冒充。每类注明表/创建方式/依赖/所有者/影响行数/清理/防污染。

### 3.1 booking_rule（device 2，规则时段）
| 项 | 内容 |
| --- | --- |
| 表 | `lab_instrument_booking_rule` |
| 创建方式 | `POST /lab/instrument/booking-rule/save`（906，rule:update） |
| 依赖 | device 2 存在且 NORMAL+bookable |
| 所有者/租户 | creator=906 测试管理员 / tenant 162 |
| 字段设计 | `device_id=2, granularity_minutes=60, min_duration_minutes=60, max_duration_minutes=240, bookable_days_before=0, bookable_days_ahead=7, open_days="1,2,3,4,5,6,0"（全周）, open_start_time="00:00", open_end_time="23:59", allow_cross_day=0, allow_admin_adjust_after_start=1, enabled=1, remark="R7验收规则"` |
| 影响行数 | INSERT 1（或 UPDATE 1，save 为幂等 upsert） |
| 清理 | 验收后 `enabled=0` 或删除（授权后） |
| 防污染 | 仅 device 2；全时段开放避免误挡真实时段 |

### 3.2 booking_window
**SCIENCE 设备不需要**（窗口仅 MICROPLATE_READER 用）。不创建。

### 3.3 仪器使用资质（device 2，有效）
| 项 | 内容 |
| --- | --- |
| 表 | `lab_instrument_qualification`（+ `_apply` / `_apply_history` 流程表） |
| 创建方式 | `POST /lab/instrument/qualification/apply`（用户提交）→ `POST /lab/instrument/qualification/audit`（审批通过） |
| 依赖 | 用户存在；device 2 |
| 所有者/租户 | 各测试用户本人申请 / tenant 162 |
| 字段设计 | `target_type=DEVICE, target_id=2, status=ACTIVE, granted_time=NOW, expire_time=NOW+1年` |
| 需建 | 账号A(281)、账号B(265)、test906、test908 各 1 条（test905 不建，用于「无资质/无权限」验证） |
| 影响行数 | 每用户 apply 1 + audit 后 qualification 1（4 用户 ≈ 4 条 ACTIVE） |
| 清理 | 验收后 `status=REVOKED`（授权后） |
| 防污染 | 仅 device 2 资质；不影响其他设备 |

### 3.4 设备负责人 DEVICE ACTIVE 关系（908 数据范围）
| 项 | 内容 |
| --- | --- |
| 表 | `lab_instrument_manager` |
| 创建方式 | `POST /lab/instrument/manager/assign`（管理端） |
| 依赖 | test908 存在；device 2 |
| 所有者/租户 | tenant 162 |
| 字段设计 | `device_id=2, user_id=<test908>, scope_type=DEVICE, status=ACTIVE` |
| 影响行数 | INSERT 1 |
| 清理 | `POST /lab/instrument/manager/release` 或 status=RELEASED（授权后） |
| 防污染 | 仅绑定 test908↔device 2 |

### 3.5 人工暂停记录（暂停拒绝用例）
| 项 | 内容 |
| --- | --- |
| 表 | `lab_instrument_suspend` |
| 创建方式 | 管理端暂停 API（如无专用 API 则由负责人在授权下创建，**不**用 INSERT 冒充审批结果） |
| 依赖 | device 2；目标用户（对账号A 生效） |
| 字段设计 | 覆盖 device 2、时间范围覆盖测试预约时段、`status=ACTIVE` |
| 影响行数 | INSERT 1 |
| 清理 | 用例 3 验证后立即解除（授权后） |
| 防污染 | 用例专用、限时生效，验证后即解除 |

### 3.6 预约记录（冲突/隔离/生命周期）
**一律经 `POST /lab/instrument/reservation/create` 业务 API 产生**（C7 开启后），不直接 INSERT。用于用例 1/6/7/8/9/10/11/12/13/15 的样本由验收流程按需创建，验收后按授权保留或清理。

---

## 4. R7-D C7 开启及回退方案

### 4.1 配置修改位置
- 文件：`E:\lixin\dev\ruoyi-vue-pro\yudao-server\src\main\resources\application-local.yaml`
- 在 `lab.instrument.reservation` 节点下新增 `create-enabled: true`（正确层级，与 `application-instrument-03-test.yaml:61` 结构一致）。
- **注意**：修改的是 `src/main/resources` 源文件；运行中进程加载的是 `yudao-server/target/classes` 下的副本。需确保修改同步到 `target/classes`（IDEA 重启自动重拷）或改后重新构建。

### 4.2 重启前置条件
- 当前 PID 41788 为 IDEA 托管（`YudaoServerApplication`）。**重启须由负责人在 IDEA 内操作**（本任务不代重启）。
- 前置：配置已改、DB/Redis 正常、无进行中的事务。

### 4.3 生效确认
- 重启后只读探活 48080 正常；
- 用合法账号 `POST /lab/instrument/reservation/create`（合法 body）→ 不再返回 `INSTRUMENT_RESERVATION_CREATE_DISABLED`（应进入 P1~P9 校验或成功）。

### 4.4 回退 create-enabled=false
- 将 `application-local.yaml` 的 `create-enabled` 改回 `false`（或删除该键）→ 同步 target/classes → IDEA 重启。

### 4.5 回退确认
- 重启后 `POST create` 返回 `INSTRUMENT_RESERVATION_CREATE_DISABLED`。

### 4.6 回退影响
- **仅 create 端点受 createEnabled 闸门**（源码确认）；cancel/finish/adjust/void 不受 C7 控制，回退后既有预约仍可正常走生命周期。
- 回退**不删除**已创建预约（数据保留）。

### 4.7 业务数据备份与恢复范围
- 备份表：`lab_instrument_booking_rule / booking_window / qualification / qualification_apply / manager / suspend / reservation / reservation_history`（用 8.0.12 mysqldump，同 41 号方法，`--single-transaction --no-tablespaces`）。
- 恢复：按需回灌受损表（授权后）；不自动执行补偿 SQL。

### 4.8 异常停止与人工裁决条件
- 重启失败/端口异常/配置未生效/误放行/数据错乱 → 立即停止，保留现场，报负责人裁决；不自动重试或补偿。

---

## 5. R7-E 整合验收执行计划（16 项，连续可执行）

> 标注：✍️=需负责人单独授权（建账号/配置/重启/写库）；预期错误码基于源码冻结口径。**全部为计划，未执行。**

| 步 | 用例 | 前置 | 实际 API | 预期结果/错误码 | DB 影响 | 可继续？ | 失败停止条件 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 前置数据+账号验证 ✍️ | 备份完成；§2 账号就绪；§3 数据就绪 | 只读 SELECT | 规则/资质/负责人/暂停就位 | 0 | 是 | 任一缺失→停 |
| 1 | C7 开启 ✍️ | 步0 过 | 改配置+IDEA 重启 | create 不再 DISABLED | 0 | 是 | 未生效→停 |
| 2 | 904 合法创建 | 步1；账号A 有效资质 | `POST reservation/create`（账号A, device2, 合法时段） | code=0，PENDING，唯一单号，history CREATE | +1 预约+1 history | 是 | 非预期码/重复单号→停 |
| 3 | 无资质用户创建被拒 ✍️ | test905 或临时无资质用户 | `POST create` | 084 NO_VALID_QUALIFICATION | 0 | 是 | 误放行→停 |
| 4 | 生效暂停用户创建被拒 ✍️ | §3.5 暂停对账号A 生效 | `POST create`（账号A） | 086 USER_SUSPENDED | 0 | 是 | 误放行→停；验后解除暂停 |
| 5 | 非 NORMAL 设备被拒 | device 1 SCRAPPED | `POST create`（device 1） | 083 DEVICE_STATUS_DENIED | 0 | 是 | 误放行→停 |
| 6 | 未开放时段被拒 | 规则外时段（临时收窄规则或选非法时段） | `POST create` | 087 OUT_OF_OPEN_SCOPE | 0 | 是 | 误放行→停 |
| 7 | 同设备时间重叠被拒 | 步2 已有 PENDING | `POST create`（账号A，重叠时段） | 093 TIME_CONFLICT | 0 | 是 | 误放行/误报→停 |
| 8 | 相邻时间段成功 | 与步2 首尾相接 | `POST create`（账号A，相邻） | code=0，相邻不冲突 | +1+1 | 是 | 误判冲突→停 |
| 9 | 不同设备并发正常 | 需第二台 NORMAL 设备（缺→标记 SKIP） | `POST create`（不同 device） | 各自成功 | +1+1 | 是 | 死锁/串号→停 |
| 10 | 904 取消本人预约 | 步2 PENDING | `POST reservation/cancel`（账号A） | code=0，CANCELED，history CANCEL | 状态改+1 history | 是 | 越权/条件更新异常→停 |
| 11 | 904 调整本人 PENDING | 账号A 另一 PENDING | `POST reservation/adjust`（账号A） | code=0，重走 P1~P8，history ADJUST | +1 history | 是 | 校验未重走→停 |
| 12 | 904 跨用户数据隔离 | 账号A/账号B 各有预约 | `GET reservation/my` `page`（账号A vs B） | A 仅见 A，不见 B | 0 | 是 | 越权可见→停 |
| 13 | 908 设备范围隔离 ✍️ | test908 DEVICE(device2) 关系 | `GET page`（test908）+ 越权详情 | 仅见 device2 范围；超范围拒绝 | 0 | 是 | 范围裁剪失效→停 |
| 14 | 905 越权拒绝 ✍️ | test905 无预约权限 | `GET page`/`POST create`（test905） | 403 / 对应拒绝码 | 0 | 是 | 误放行→停 |
| 15 | 908 管理授权设备预约 ✍️ | test908 对 device2 授权 | `POST finish/void`（test908） | 按设备范围可管理，无 rule:update | 状态改+history | 是 | 越权→停 |
| 16 | 906 完成/作废 ✍️ | test906 管理范围 PENDING | `POST finish` `void`（test906） | FINISHED/VOIDED，history 完整 | 状态改+history | 是 | 状态机异常→停 |
| 17 | 历史一致性+单号唯一 | 多笔操作后 | 只读 SELECT history/reservation | history 只增不改；单号全局唯一 | 0 | 是 | 缺失/重复→停 |
| 18 | C7 回退+复核 ✍️ | 验收完成 | 改回 false+重启；`POST create` | CREATE_DISABLED；既有预约不受影响；生命周期仍可 | 0 | 结束 | 回退后仍可创建→停 |

---

## 6. 业务数据备份方案
- 工具：8.0.12 mysqldump（同 41 号）。
- 范围：`lab_instrument_booking_rule, booking_window, qualification, qualification_apply, qualification_apply_history, manager, suspend, reservation, reservation_history`。
- 时机：步0 前置数据创建**前**（基线备份）+ 全部验收**后**（结果留存）。
- 命名：`instrument03_biz_backup_<yyyyMMdd_HHmmss>.sql`，存 `E:\lixin\dev\backup\instrument03`（非 Git），记录 SHA-256。

---

## 7. 需负责人单独授权的操作清单
| 序 | 操作 | 说明 |
| --- | --- | --- |
| A1 | 新建 test906 / test908 / test905 账号并设密码 | 纯净角色，验收后禁用/删除 |
| A2 | 创建 §3 最小业务数据（规则/资质/负责人/暂停） | 经业务 API |
| A3 | 修改 `application-local.yaml` 开 C7 + IDEA 重启 | 含同步 target/classes |
| A4 | 执行 §5 全部真实预约写操作 | 产生正式业务数据 |
| A5 | C7 回退 false + 重启 | 含复核 |
| A6 | 业务数据备份/恢复 | mysqldump |
| A7 | 验收后测试数据与测试账号清理 | 禁用/删除 |

---

## 8. 最终判定

**READY FOR AUTHORIZATION**

- 前置数据方案（§3）、账号方案（§2）、C7 操作方案（§4）、16 项验收执行计划（§5）、备份方案（§6）均完整，可提交负责人一次性授权（A1~A7）。
- 无「无法确定的业务规则」：设备 2 为 SCIENCE，明确使用 booking_rule（非 booking_window），规则字段已按服务端 P3 校验要求设计。
- 无「缺失的关键依赖」：DB/Redis/后端/菜单均已就绪，仅缺授权后的前置数据与纯净账号。

任务完成，立即停止，不自动进入正式业务写入阶段。等待负责人对 A1~A7 的授权裁决。
</content>
</invoke>
