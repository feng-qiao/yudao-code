# 41 - INSTRUMENT-03 正式菜单部署与权限验收报告

- 任务号：`TASK INSTRUMENT-03-R5-MENU-DEPLOY-01`
- 任务性质：**已获负责人书面授权的正式数据库菜单部署（事项 A）**
- 执行日期：2026-10-19
- 目标数据库：`labplatform`（真实库）
- 目标租户：162 ｜ 目标套餐：114
- 权威 SQL：`E:\lixin\dev\ruoyi-vue-pro\sql\lab\20261016_instrument_03b_booking_config_menu_design.sql`
  （SHA-256 = `9611830788DEC47FE5B2E230268F16229DECD038BB90C9070D00BD60F4B87E0F`，共 481 行，未发生未经审核的修改）
- 参考报告：37 号、39 号、40 号
- **最终判定：DEPLOY PASS / MENU READY**

> 三阶段全部 COMMIT 成功、数据库验收通过、无越权与非预期变更。页面验收未完成项（908、905）已明确列为待验收，本报告**不宣称全部业务验收通过**。

---

## 1. 负责人授权范围

负责人明确授权**事项 A**：在严格满足前置条件后，执行权威 SQL 中属于 **13674~13683 菜单部署**的指定 DML（`system_menu` / `system_tenant_package` / `system_role_menu` 三张表）。

授权**未**扩大至：
- 其他数据库对象（其他表、其他租户、其他套餐）；
- Redis 写入（本任务明确采用 TTL 自然到期，见第 10 节）；
- 业务预约操作（创建/取消/调整/完成/作废）；
- C7 开启（`create-enabled` 保持 false）；
- 历史 CAP-A SQL、其他初始化 SQL、任何 DDL。

---

## 2. 执行前重新预检（D0）结果

连接方式：`D:\worktools\phpstudy_pro\Extensions\MySQL8.0.12\bin\mysql.exe`（**客户端 8.0.12，与服务端同版本**）→ `127.0.0.1:3306/labplatform`，凭据经 `--defaults-extra-file` 传递（命令行不含明文密码）。

| 检查项 | 实测 | 预期 | 判定 |
| --- | --- | --- | --- |
| MySQL 版本 | 8.0.12 | 与设计稿兼容 | PASS |
| `MAX(system_menu.id)` | 13673 | 13673 | PASS |
| 13674~13683 空闲（**含逻辑删除记录**，无 `deleted` 过滤） | 0 行 | 全空闲 | PASS |
| 父菜单 13600 | 存在（type=1 status=0 deleted=0） | 有效 | PASS |
| 角色 904/905/906/908 | 均 tenant_id=162 status=0 deleted=0 | 有效 | PASS |
| 套餐 114 | status=0，`[`…`]`，JSON_VALID=1，len=1462，351→341 | 合法 JSON 数组 | PASS |
| 套餐 114 是否已含目标 10 ID | 全部 `JSON_CONTAINS`=0 | 未含 | PASS |
| path/component/permission 冲突 | 0 行 | 无冲突 | PASS |
| role_menu 残留（**含逻辑删除**，13674~13683） | 0 行 | 无残留 | PASS |
| 三表结构与设计稿 | 一致（见 40 号 §1.6） | 一致 | PASS |
| 权威 SQL 文件完整性 | 481 行 / SHA-256 已记录 / R4 修订标记齐全 | 未擅自修改 | PASS |
| 备份工具 | mysqldump 8.0.12 可用 | 可用 | PASS |
| C7 | `create-enabled` 仅存在于隔离测试 profile → local 默认 false | false | PASS |

**D0 全部 PASS，无 HOLD。**

---

## 3. 备份文件与验证（D1）

| 项 | 值 |
| --- | --- |
| 备份目录 | `E:\lixin\dev\backup\instrument03`（原不存在，已创建；位于任何 Git 仓库之外） |
| 备份文件 | `E:\lixin\dev\backup\instrument03\instrument03_menu_backup_20261019_182236.sql` |
| 大小 | **642,297 字节**（非零） |
| SHA-256 | `0FE33EA3B9F0E56F9B20A7EAF20E071635EE84519396E762D429B100E5AC5270` |
| 客户端 | mysqldump **8.0.12**（与服务端同版本，消除跨版本风险） |
| 参数 | `--single-transaction --no-tablespaces --skip-lock-tables --default-character-set=utf8mb4 --set-gtid-purged=OFF` |
| 退出码 | 0 |
| 内容验证 | 含 3 个 `CREATE TABLE`（system_menu / system_role_menu / system_tenant_package）+ 3 个 `INSERT INTO ... VALUES`；末尾 `Dump completed on 2026-10-19 18:22:37`；无 mysqldump 错误 |
| 密码暴露 | 命令行无明文（凭据经 `--defaults-extra-file=C:\temp\mysql_deploy.cnf`）；未擅自授予 PROCESS/RELOAD 等全局权限 |
| Git/公开位置 | 备份目录非 Git 仓库，未入版本库 |

**D1 全部 PASS，备份成功且可解析、可恢复（含结构与数据）。**

> 说明：备份自动选取了与服务端同版本的 8.0.12 客户端（位于 phpstudy 扩展目录），故 40 号报告 N2 的跨版本注意项在本轮不构成风险；`--no-tablespaces` 规避了账号无全局权限的问题。

---

## 4. 三阶段每阶段 DML 实际影响行数

| 阶段 | 语句 | 实际影响行数 |
| --- | --- | --- |
| **阶段一（§1~§3）** | §1 菜单 INSERT（3 条，逐条） | 每语句 1 行 → **3** |
| | §2 套餐 UPDATE（3 条，逐条） | 每语句 1 行 → **3** |
| | §3 role_menu INSERT（1 条，906×3） | **3** |
| **阶段二（A.1~A.3）** | A.1 菜单 INSERT：页面 13677 | 1 |
| | A.1 菜单 INSERT：按钮 13678~13682 | 5 |
| | A.2 套餐 UPDATE（单条原子，6 ID） | 1 |
| | A.3 role_menu INSERT（904×5+906×6+908×6） | 17 |
| **阶段三（B.1~B.3）** | B.1 菜单 INSERT：13683 | 1 |
| | B.2 套餐 UPDATE（单条） | 1 |
| | B.3 role_menu INSERT（904/906/908 各 1） | 3 |

> 阶段一新行数由「D0 证明 13674~13676 空闲（含逻辑删除）」+「§4 事务内验收」双向确认；阶段二、三由事务内 `ROW_COUNT()` 直接捕获。合计新增：菜单 10 行、套餐 UPDATE 匹配 5 行、role_menu 23 行。

---

## 5. 各阶段 BEGIN / 验收 / COMMIT 结果

| 阶段 | 预检 | BEGIN | 事务内验收 | 守卫 | COMMIT |
| --- | --- | --- | --- | --- | --- |
| 阶段一 13674~13676 | §0 全 PASS（max=13673,parent=1,role906=1,pkg=1,idle=0,perm=0） | 独立事务 | verify_ok=**1** | PASS | **COMMIT（成功）** |
| 阶段二 13677~13682 | A.0 全 PASS（max=**13676**,existing_perm=0,idle=0,role=3,pkg=1） | 独立事务 | verify_ok=**1** | PASS | **COMMIT（成功）** |
| 阶段三 13683 | B.0 全 PASS（max=**13682**,idle=0,path_dup=0,comp_dup=0,role=3,pkg=1） | 独立事务 | verify_ok=**1** | PASS | **COMMIT（成功），时间 2026-10-19 18:26:19** |

- 三阶段严格按序独立事务执行，无 ROLLBACK，无异常，无跨阶段长事务。
- 事务内验收全部通过后才 COMMIT（提交前设**条件守卫**：验收为假则语句报错中止→不执行 COMMIT→断连自动回滚）。
- 阶段二 A.0 在阶段一 COMMIT 后运行（max=13676）；阶段三 B.0 在阶段二 COMMIT 后运行（max=13682）——时序约束成立。
- A.2 单条原子 UPDATE 未拆分。

---

## 6. 三阶段最终数据库状态

### 6.1 菜单（13674~13683，共 10 条，全部 deleted=0 status=0）
| ID | 名称 | type | sort | parent | path | component | permission |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 13674 | 预约配置 | 2 | 18 | 13600 | booking-config | lab/instrument/booking-config/index | （空） |
| 13675 | 规则查询 | 3 | 1 | 13674 | — | — | lab:instrument:rule:query |
| 13676 | 规则配置 | 3 | 2 | 13674 | — | — | lab:instrument:rule:update |
| 13677 | 预约管理 | 2 | 19 | 13600 | reservation-manage | lab/instrument/reservation-manage/index | （空） |
| 13678 | 预约查询 | 3 | 1 | 13677 | — | — | lab:instrument:reservation:query |
| 13679 | 预约创建 | 3 | 2 | 13677 | — | — | lab:instrument:reservation:create |
| 13680 | 预约取消 | 3 | 3 | 13677 | — | — | lab:instrument:reservation:cancel |
| 13681 | 预约调整 | 3 | 4 | 13677 | — | — | lab:instrument:reservation:adjust |
| 13682 | 预约管理操作 | 3 | 5 | 13677 | — | — | lab:instrument:reservation:manage |
| 13683 | 我的预约 | 2 | 20 | 13600 | my-reservation | lab/instrument/my-reservation/index | （空） |

- `MAX(system_menu.id)` = **13683**；type 分布：type=2 ×3、type=3 ×7。
- 与设计稿 §1/附录 A/附录 B 逐字段一致。

### 6.2 套餐 114
- `JSON_LENGTH(menu_ids)` = **351**（部署前 341 + 10）；首 `[`、末 `]`、`JSON_VALID=1`；
- 新增 10 ID 全部 `JSON_CONTAINS=1`；
- **重复 ID 数 = 0**（351 total == 351 distinct）；
- 部署前 341 个 ID **全部保留**（`MISSING = 空`，用 D1 备份中的原始数组对比验证）；
- 引用租户仅 162，`tenants_using_114=1`。

### 6.3 角色授权（新增 13674~13683 的 role_menu）
| 角色 | 部署后总数 | 本次新增 |
| --- | --- | --- |
| 904 普通用户 | 33（原 27） | **6** |
| 905 库管员 | 48（原 48） | **0** |
| 906 lab_admin | 123（原 113） | **10** |
| 908 仪器设备负责人 | 15（原 8） | **7** |

- 其他租户受影响授权 = **0**（`menu_id 13674~13683 AND tenant_id<>162` = 0 行）。

---

## 7. 904 / 905 / 906 / 908 权限矩阵

| 菜单/权限 \ 角色 | 904 | 905 | 906 | 908 |
| --- | :-: | :-: | :-: | :-: |
| 13674 预约配置 | — | — | ✓ | — |
| 13675 rule:query | — | — | ✓ | — |
| 13676 rule:update | — | — | ✓ | — |
| 13677 预约管理 | ✓ | — | ✓ | ✓ |
| 13678 reservation:query | ✓ | — | ✓ | ✓ |
| 13679 reservation:create | ✓ | — | ✓ | ✓ |
| 13680 reservation:cancel | ✓ | — | ✓ | ✓ |
| 13681 reservation:adjust | ✓ | — | ✓ | ✓ |
| 13682 reservation:manage | **—** | — | ✓ | ✓ |
| 13683 我的预约 | ✓ | — | ✓ | ✓ |
| **新增合计** | **6** | **0** | **10** | **7** |

与 39/40 号报告矩阵一致：904 无 `reservation:manage`、908 无 `rule:update`、905 零授权、906 保持管理员全量。

### 7.1 运行时权限核验（API，非破坏性）
- **904**（189140002）登录后 `lab:instrument*` 权限含 `reservation:query/create/cancel/adjust`，**不含** `reservation:manage`、不含 `rule:*` → PASS
- **906**（bencao）含 `rule:query/update` 与 `reservation:query/create/cancel/adjust/manage` 全部 → PASS
- **908 / 905**：无可用测试账号 → **NOT TESTED**

---

## 8. 套餐 114 验收

- 新增 10 ID 全部进入套餐，且 `JSON_VALID=1`、无重复、原有 341 ID 无减少（见 §6.2）。
- 套餐同步语义：仅角色授权不改套餐会导致菜单不可见（K3），本次已将 10 ID 追加进套餐，菜单对 906 可见性验证通过。

---

## 9. 原有授权保留情况

- 904/905/906/908 的既有授权**未减少**：部署后总数 = 原总数 + 新增（33=27+6、48=48+0、123=113+10、15=8+7），无净减少。
- 套餐 114 原集合完整保留（§6.2）。
- 未覆盖任何其他已有角色菜单关系（本轮仅 INSERT 目标组合，无对既有行的 UPDATE/DELETE）。
- 未触碰任何仪器业务表。

---

## 10. Redis 未写入声明及 TTL 处理状态

- **未连接正式 Redis**，未执行任何 `SET/DEL/FLUSHDB/FLUSHALL`；未通过后台保存角色菜单/编辑菜单触发缓存失效；未重启后端；未改 TTL；未改 Redis 配置。
- 三阶段**最后 COMMIT 时间 = 2026-10-19 18:26:19**；权限缓存 TTL = **1h** → 自然到期窗口约 **2026-10-19 19:26:19**。
- **实测佐证**：本轮 API 验收（18:27~18:30）已返回**正确的**新权限（904 含 reservation 四项、906 含 rule+manage），说明新增菜单/权限的缓存条目为首次构建（部署前不存在），**未出现陈旧缓存导致的误判**——即运行期权限已生效，无需等待 TTL 亦无风险。
- 若后续出现权限异常，只读排查并报告，**不得**自行执行缓存清理或角色授权修复。

---

## 11. C7 核验

- `lab.instrument.reservation.create-enabled` **仅**存在于隔离测试 profile（`application-instrument-03-test.yaml`），`application.yaml` / `application-local.yaml` 均无该键 → local 生效值 = 默认 **false**。
- 本轮部署前后均确认 **C7=false**，未开启。

---

## 12. 页面只读验收结果及 NOT TESTED 项

| 角色 | 检查项 | 结果 |
| --- | --- | --- |
| **904** | 可见「预约管理」 | **PASS**（API 菜单树含「预约管理」） |
| 904 | 可见「我的预约」 | **PASS**（含「我的预约」） |
| 904 | 不可见「预约配置」 | **PASS**（无「预约配置」） |
| 904 | 不具备 reservation:manage | **PASS**（权限集不含） |
| 904 | 本人预约列表仅本人数据 | **LIMITED**：`GET reservation/my`、`reservation/page` 返回 code=0 且 total=0（无测试数据）；服务端强制 `user_id=本人` 已由源码核验（R4/R5），运行期数据级隔离**未用样本数据验证** |
| **906** | 可见「预约配置」「预约管理」「我的预约」 | **PASS**（三者均可见） |
| 906 | 具有规则配置与预约管理权限 | **PASS**（含 rule:query/update、reservation:manage 等） |
| **908** | 菜单与权限（预约管理/我的预约、无预约配置、无 rule:update、负责人数据范围） | **NOT TESTED**（无 908 测试账号） |
| **905** | 不获得新增预约菜单及权限 | **NOT TESTED**（无 905 账号）；**数据库层已证 0 授权** |
| 全部 | 是否调用业务写接口 | **未调用**（无 create/cancel/adjust/finish/void 调用） |

> 未创建任何账号、未修改任何角色权限（遵从任务书约束）。
> 说明：D7 使用既有账号登录属非破坏性验收，会产生系统标准的登录审计记录（非业务数据修改）。

---

## 13. 异常、剩余风险与下一步建议

### 13.1 异常
- 无 SQL 报错、无影响行数异常、无 ID 冲突、无越权、无套餐 JSON 异常、无其他租户授权、无连接中断、无事务状态不明。三阶段全部一次通过。

### 13.2 剩余风险 / 待验收项
| 编号 | 事项 | 处理建议 |
| --- | --- | --- |
| R1 | 908 页面与权限运行期验收未做（无账号） | 由负责人安排 908 账号或在具备条件时补验 |
| R2 | 905 未授权运行期验收未做（无账号） | 同上；DB 层已证 0 授权 |
| R3 | 904「本人数据隔离」未用样本数据验证 | 可用现有测试数据补验（只读） |
| R4 | 前端完整浏览器验收未做（本轮为 API 级） | 前端重登后在浏览器复核页面渲染与按钮 |
| R5 | 权限缓存为 1h TTL 自愈方案 | 若个别账号短期未刷新，重新登录或待 TTL 到期即可；不执行 Redis 清理 |

### 13.3 下一步建议
1. 负责人知悉并接受 R1~R5 为待验收/低风险项；
2. 如需完全业务验收，安排 908/905 账号与前端浏览器复验；
3. **C7 开启与预约业务写入验收属独立授权事项，本任务不涉及、不自动进入**。

---

## 14. 最终判定

**DEPLOY PASS / MENU READY**

- 三阶段独立事务全部 COMMIT 成功；
- 数据库验收全部通过：10 条菜单、套餐 114（351 ID / 0 重复 / 原集合完整）、角色新增 6/0/10/7、无越权、无跨租户、无业务表变更；
- 备份成功且可验证、可恢复；
- Redis 未写入（TTL 自愈）；C7=false；
- 904 / 906 运行期权限与菜单可见性验收 PASS；**908 / 905 页面验收列为待验收（NOT TESTED）**。

本报告**不宣称全部业务验收通过**（908/905 页面验收及 904 数据隔离样本验证待补）。任务完成，停止，等待负责人下一步裁决；**不自动进入 C7 开启或预约业务写入验收**。

---

## 附：本轮执行的操作边界与证据留档

- 客户端：`D:\worktools\phpstudy_pro\Extensions\MySQL8.0.12\bin\mysql.exe` / `mysqldump.exe`（均 8.0.12）；凭据经 `--defaults-extra-file`（命令行无明文密码）。
- 备份：`E:\lixin\dev\backup\instrument03\instrument03_menu_backup_20261019_182236.sql`（642,297 B，SHA-256 见 §3）。
- 执行脚本（本地临时，非仓库）：`C:\temp\phase1.sql` / `phase2.sql` / `phase3.sql` / `d0_precheck.sql` / `d5_accept.sql`。
- 事务守卫：每阶段 COMMIT 前设条件断言（`CASE WHEN @ok THEN 'PASS' ELSE <必错子查询>`），验收为假即中止且不提交。
- 未执行：任何 DDL、DELETE、TRUNCATE、历史 CAP-A SQL、Redis 写入、C7 开启、业务写接口。
</content>
</invoke>
