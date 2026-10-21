# 13-INSTRUMENT-01-SQL-PRECHECK-报告：数据库初始化执行前集中核验

- 核验日期：2026-10-15
- 核验范围：`sql/lab/20261014_instrument_01_schema.sql`、`20261014_instrument_01_dict.sql`、`20261014_instrument_01_menu.sql` + 真实数据库 `labplatform`
- 合并任务：INSTRUMENT-01-G26-R1（G26 正式裁决核验）
- 授权边界：本任务全程**只读**。仅执行 SELECT / information_schema 查询；未执行任何 INSERT/UPDATE/DELETE/CREATE/ALTER/DROP/TRUNCATE；未执行三个 SQL 文件的任何写入语句；未修改任何代码与 SQL 文件。允许的文档更新仅限 G26 裁决状态（06/11/合并.md）。
- 数据库连接证据：`yudao-server/src/main/resources/application-local.yaml` L51/60-61 → `jdbc:mysql://127.0.0.1:3306/labplatform`，账号 `bencao`（application-dev.yaml 指向 `ruoyi-vue-pro` 库，非本环境实际使用配置；实际运行环境为 local）。

---

# 一、真实数据库查询证据（A 节，全部实测）

执行客户端：MySQL 8.4.11 mysql.exe，`--default-character-set=utf8mb4`，目标库 `labplatform`（服务端 MySQL 8.0.12）。

## 1.1 当前库与引擎

| 检查 | 实测结果 | 预期 | 结论 |
| --- | --- | --- | --- |
| `DATABASE()` | `labplatform` | labplatform | ✓ |
| `@@version` | `8.0.12` | MySQL 8.0.x | ✓ |
| 库默认字符集/排序规则 | `utf8` / `utf8_general_ci` | utf8mb4（建议） | ⚠ 提示，见 §九 P-2 |
| InnoDB `support` | `YES` | DEFAULT/YES | ✓ |

## 1.2 五张仪器表存在性（预期全部 0）

```
A1-lab_instrument_platform   0
A1-lab_instrument_device     0
A1-lab_instrument_room       0
A1-lab_instrument_manager    0
A1-lab_instrument_notice     0
```

→ 5 张表**均不存在**，schema SQL 首次执行为全新建表，无覆盖风险。✓

## 1.3 字典冲突（预期零冲突）

- `system_dict_type WHERE type IN (5 个仪器类型)` → **0 行**；
- `system_dict_type WHERE type LIKE 'lab_instrument%'`（含已删除）→ **0 行**；
- `system_dict_data WHERE dict_type LIKE 'lab_instrument%'` → **0 行**。

→ 5 个字典类型、18 个数据项均无任何现存冲突（含逻辑删除行）。✓

## 1.4 菜单 ID 段与权限串

| 检查 | 实测结果 | 结论 |
| --- | --- | --- |
| `COUNT(*) FROM system_menu WHERE id BETWEEN 13600 AND 13653` | **0** | ✓ 预留段完全空闲 |
| `MAX(id) FROM system_menu` | **13585** | ⚠ 见下方说明 |
| `permission LIKE 'lab:instrument:%'`（含 deleted） | **0 行** | ✓ 权限串零冲突 |
| 菜单 13478 | `实验室管理, type=1, parent_id=0, path=/lab, status=0, visible=1, deleted=0` | ✓ 存在且可用 |

**MAX(id)=13585 说明**：menu SQL 头部注释写"已用最大 id=13579"。实测 13580~13585 为 **2026-10-12 质粒模块新增**（与仪器无关）：

```
13580  用户恢复        system:user:restore          type=3 parent=4     deleted=0
13583  存放位置                                     type=2 parent=13530 deleted=0
13584  存放位置查询    lab:plasmid-storage:query    type=3 parent=13583 deleted=0
13585  存放位置修改    lab:plasmid-storage:update   type=3 parent=13583 deleted=0
```

→ 环境已变化但**不影响本脚本执行**：脚本按固定 ID `NOT EXISTS` 守卫，13600~13653 段实测空闲。执行时第 0.2 节检查会显示 13585（>13579），执行人应知悉该偏差来源为质粒模块，非仪器残留。详见 §九 P-1。

## 1.5 租户 / 套餐 / 角色

| 对象 | 实测 | 结论 |
| --- | --- | --- |
| 租户 162 | `成都中医药大学, status=0, package_id=114, deleted=0` | ✓ |
| 套餐 114 | `status=0, deleted=0, menu_ids 以 [ 开头 ] 结尾, LENGTH=1222` | ✓ 括号格式正确 |
| 套餐 114 含 136 段 ID | `,136` 出现次数 0；`REGEXP '\b13600\b'`=0、`'\b13653\b'`=0 | ✓ 未含本批任何 ID |
| 角色 904 | `普通用户, status=0, tenant_id=162, deleted=0` | ✓ |
| 角色 906 | `本草基因管理员/lab_admin, status=0, tenant_id=162, deleted=0` | ✓ |

## 1.6 现有授权关系（脚本预期比对）

- 906 已持有 `system_role_menu(906, 13478, tenant=162, deleted=0)` → 脚本 3.1 节该行 NOT EXISTS 跳过，幂等安全 ✓
- 904 已持有 `(904, 13478)` → 同理跳过 ✓
- 904 当前 lab 相关授权：仅质粒按钮（13533~13538 plasmid 5 个、13558~13560 borrow 3 个、13564/13565 return 2 个）+ 目录 13478，**无任何 lab:instrument 权限** → 与脚本预期基线一致 ✓
- 脚本对 903/905/907 不授权：设计如此（I3 待确认），实测无需变更 ✓

---

# 二、schema SQL 逐项检查（B 节）

文件：`20261014_instrument_01_schema.sql`（5 表 DDL，全部 `CREATE TABLE IF NOT EXISTS`）。

## 2.1 字段与索引核对

| 表 | 业务字段要点 | 唯一键 | 普通索引 | 六公共字段 |
| --- | --- | --- | --- | --- |
| lab_instrument_platform | code/name/description/sort/status/remark | `uk_platform_tenant_code(tenant_id,code)` | — | ✓ 齐全 |
| lab_instrument_device | device_no/name/model/spec/category/repair_scope/platform_id/room_id/asset_no/manufacturer/purchase_date/status/bookable/image_file_id/image_file_name/**image_url**/sort/remark | `uk_device_tenant_no(tenant_id,device_no)` | idx_platform_id / idx_room_id / idx_status / idx_category | ✓ 齐全 |
| lab_instrument_room | code/name/building/floor/location_desc/repair_manager_id(快照,不回填)/repair_manager_name(快照)/status/sort/remark | `uk_room_tenant_code(tenant_id,code)` | idx_repair_manager_id | ✓ 齐全 |
| lab_instrument_manager | scope/target_id/manager_type/manager_user_id/manager_name/status/effective_from/effective_to/assign_reason/release_reason/remark | **无**（设计如此，含历史行） | idx_scope_target(scope,target_id,status) / idx_manager_user | ✓ 齐全 |
| lab_instrument_notice | target_type/target_id/version/title/content/status/require_acknowledge/publish_time/publisher_id/publisher_name/remark | `uk_notice_target_ver(tenant_id,target_type,target_id,version)` | idx_target(target_type,target_id,status) | ✓ 齐全 |

- TenantBaseDO 六公共字段（creator/create_time/updater/update_time/deleted bit(1)/tenant_id）：5 表逐列核对全部齐全，类型与框架一致（`deleted bit(1) DEFAULT b'0'`、`tenant_id bigint DEFAULT 0`）。✓
- 状态默认值与 Java 枚举一致：device.status DEFAULT 'NORMAL'、manager.status DEFAULT 'ACTIVE'、notice.status DEFAULT 'DRAFT'、platform/room.status DEFAULT 'ENABLE'。✓
- `image_url varchar(500)` 为交付报告已声明的实现增补（infra 上传只回 URL），设计文档 02 已同步。✓

## 2.2 `IF NOT EXISTS` 掩盖风险分析

- 当前 5 表均不存在（§1.2 实测），首次执行即新建，**不存在掩盖**。
- 重复执行：IF NOT EXISTS 跳过，不产生变更。
- 残余风险：若未来有人手工改表结构后再跑本脚本，IF NOT EXISTS 不会校正差异 → 由脚本 §2.2 验收查询（information_schema.columns 逐列比对）兜底。**本期执行无此风险**。

## 2.3 约束与历史保留

- 同租户唯一约束：3 个 `uk_*(tenant_id, 业务编码)` 正确，租户隔离在唯一键内。✓
- 负责人历史：manager 表无唯一键、解除走 `status→RELEASED + effective_to`，不物理删除，历史完整保留。✓
- 须知版本唯一：`uk_notice_target_ver(tenant_id,target_type,target_id,version)` 正确；版本递增由 Redisson 锁（`instrument:notice:lock:{targetType}:{targetId}`）保证并发唯一。✓

## 2.4 危险语句扫描

全文件仅含：SELECT（information_schema 只读检查/验收）+ `CREATE TABLE IF NOT EXISTS` ×5。**无 DROP / TRUNCATE / ALTER / INSERT / UPDATE / DELETE**。✓

---

# 三、dict SQL 逐项检查（C 节）

文件：`20261014_instrument_01_dict.sql`。

## 3.1 数量与内容

5 个字典类型 + 18 个数据项：

| 字典类型 | 项数 | 值清单 | 三方一致性 |
| --- | --- | --- | --- |
| lab_instrument_category | 8 | NORMAL/SCIENCE/MICROPLATE_READER/CMC/FREEZE_DRYER/BLI/PROTEIN_PURIFY/BIOSAFETY_CABINET | 与 `DeviceCategoryEnum`（8 枚举）逐项一致 ✓；前端 dict.ts `LAB_INSTRUMENT_CATEGORY` 已注册 ✓ |
| lab_instrument_repair_scope | 2 | SCIENCE/GENERAL | 与 `InstrumentRepairScopeEnum` 一致 ✓；dict.ts `LAB_INSTRUMENT_REPAIR_SCOPE` 已注册 ✓ |
| lab_instrument_credit_reason | 4 | VIOLATION/OVERDUE/REWARD/MANUAL | **无 NO_SHOW**（C1 修订落实）✓；属信用模块预置（INSTRUMENT-04 才建对应 Java 枚举，本期无枚举可比对，设计如此） |
| lab_instrument_suspend_scope | 2 | SINGLE/ALL | 后续任务预置，本期无 Java 枚举（设计如此） |
| lab_instrument_maintenance_source | 2 | MANUAL/PLAN | 后续任务预置，本期无 Java 枚举（设计如此） |

- **不存在自动爽约扣分规则**：credit_reason 无 NO_SHOW；脚本 §3.4 自带 C1 回归验收（`value='NO_SHOW'` 预期 0 行）。✓

## 3.2 幂等性

- 类型守卫：`NOT EXISTS (type=?)`；数据守卫：`NOT EXISTS (dict_type=? AND value=? AND deleted=b'0')`；主键 id 不手工指定（AUTO_INCREMENT）→ 重复执行影响 0 行，不产生重复记录。✓
- 逻辑删除后重建场景：若某 value 被逻辑删除（deleted=1），守卫 `deleted=b'0'` 会允许重新插入一条新行——符合"复活"语义，不产生重复生效行。✓

## 3.3 对已有字典的影响

实测 `lab_instrument%` 前缀零存在（§1.3）；全部 INSERT 带 NOT EXISTS 且只写 5 个目标类型，不触碰任何已有字典。✓

---

# 四、menu SQL 逐项检查（D 节，11 项）

文件：`20261014_instrument_01_menu.sql`。

## 4.1 【D1】权限串数量核对：13 vs 18

**结论：三方实际为 18 个权限串完全一致；12 号报告 §8 标题"13 个"为计数笔误。**

| 来源 | 数量 | 明细 |
| --- | --- | --- |
| Controller `@PreAuthorize`（Grep 实证 35 个注解，去重） | **18** | platform: query/create/update/delete(4)；device: query/create/update/delete/manage(5)；room: query/create/update/delete(4)；manager: query/manage(2)；notice: query/create/update(3) |
| 菜单 SQL 按钮（13611~13653） | **18** | 同上 18 串，一一对应 |
| 12 号报告 §8 明细行 | 4+5+4+2+3=**18** | 明细本身为 18，仅标题"13 个"算错 |

→ SQL 与代码一致，无需修正 SQL；建议后续修订 12 号报告标题数字（文档勘误，不阻断）。

## 4.2 【D2】26 个菜单结构

- 1 目录：13600 仪器管理（type=1, parent=13478, path=instrument）
- 7 页面（type=2, parent=13600）：13601 大厅 / 13602 详情(visible=0 隐藏页) / 13610 平台 / 13620 设备 / 13630 房间 / 13640 负责人 / 13650 须知
- 18 按钮（type=3, parent=各自页面）：13611-13614 / 13621-13625 / 13631-13634 / 13641-13642 / 13651-13653
- 父子关系与 sort 合理；目录/页面 INSERT 带 `EXISTS(13478 可用)` 守卫，父目录缺失时拒绝写入（防孤儿菜单）。✓

## 4.3 【D3】ID 冲突

13600~13653 实测 0 占用（§1.4）。✓

## 4.4 【D4】component 路径存在性（前端实证 Glob）

| component | 文件 | 存在 |
| --- | --- | --- |
| lab/instrument/hall/index | `src/views/lab/instrument/hall/index.vue` | ✓ |
| lab/instrument/device-detail/index | `src/views/lab/instrument/device-detail/index.vue` | ✓ |
| lab/instrument/platform/index | `src/views/lab/instrument/platform/index.vue` | ✓ |
| lab/instrument/device/index | `src/views/lab/instrument/device/index.vue` | ✓ |
| lab/instrument/room/index | `src/views/lab/instrument/room/index.vue` | ✓ |
| lab/instrument/manager/index | `src/views/lab/instrument/manager/index.vue` | ✓ |
| lab/instrument/notice/index | `src/views/lab/instrument/notice/index.vue` | ✓ |

component_name（LabInstrumentHall 等）与各 vue 文件 `defineOptions({ name })` 一致。✓

## 4.5 【D5】按钮权限 ↔ Controller 注解

18 个按钮权限串与 5 个 Controller 的 35 个 `@PreAuthorize` 注解去重后逐一相等（§4.1 明细）；每个写接口（create/update/delete/manage/assign/release/publish）均有注解覆盖，无遗漏、无多余权限串。✓

## 4.6 【D6】904 普通用户授权范围

脚本 3.2 节：`13478, 13600, 13601, 13602, 13621` 共 5 个目标 = 实验室管理目录 + 仪器目录 + 大厅 + 详情（隐藏页）+ device:query。大厅/详情数据接口（device page/get）正由 `lab:instrument:device:query` 保护。**不含任何 create/update/delete/manage 权限**；脚本 §4.6 自带越权回归核对（预期 0 行）。✓

## 4.7 【D7】906 授权范围

脚本 3.1 节：13478 + 13600 + 24 个子节点 = 26 个授权目标，覆盖全部管理页面与按钮。与设计 04 §5.2 一致。✓

## 4.8 【D8】套餐 114 保留原权限

机制：`CONCAT(SUBSTRING(menu_ids,1,LENGTH(menu_ids)-1), ',136XX]')` —— 去掉尾 `]`、追加新 ID、补回 `]`，**原 menu_ids 内容完整保留**；逐 ID 一条 UPDATE（26 条），守卫含括号格式校验 + 词边界 NOT REGEXP + 菜单存在且启用。实测当前 menu_ids 括号格式正确、不含任何 136 段 ID（§1.5）。✓

## 4.9 【D9】不影响其他租户/角色

- 菜单写入全局 `system_menu`（该表无 tenant_id 列，可见性由套餐∩角色控制）——不会"进入"其他租户，因为其他租户套餐不含这些 ID。
- 套餐 UPDATE 仅 `id=114`。
- 角色授权显式 `role_id IN (904,906) AND tenant_id=162`，守卫含角色 `tenant_id=162` 校验 → 即使他租户存在同 id 角色也不会误授权。✓

## 4.10 【D10】部分写入风险

脚本本身**无显式事务包裹**（MySQL 单条 INSERT 各自隐式提交）。分析：

- 每条写入均独立幂等（NOT EXISTS 守卫），中途失败可安全重跑，已写入部分自动跳过 → **不会产生重复或半脏数据**。
- 但中途失败会产生"部分菜单已建、套餐/授权未跟上"的中间态，需人工续跑补齐。
- 脚本 §6 已明确要求：人工 `START TRANSACTION` → 第1/2/3节 → 第4节验收 → 全符 COMMIT / 否则 ROLLBACK；并要求执行前 mysqldump 备份三表。
- 结论：风险**可控**，依赖执行人遵守 §6 事务流程。已在 §七执行顺序中强制化。

## 4.11 【D11】跨租户授权风险

- `system_role_menu` 显式写 `tenant_id=162`；906/904 守卫校验 `sr.tenant_id=162`。
- 大厅/详情接口数据由 MyBatis 租户插件自动过滤（全部 DO 继承 TenantBaseDO）；负责人候选人经 `AdminUserApi` 同租户过滤。
- 未发现跨租户写入路径。✓

---

# 五、G26 业务规则影响分析（合并 INSTRUMENT-01-G26-R1 核验）

## 5.1 裁决状态

**G26：已裁决 A（2026-10-15 负责人正式裁决）**——同一实验室允许配置多名有效维修负责人。原"待确认"状态已废止，设计文档已同步（06 §4.3/§八/§九、合并.md 对应节、11 号新增 §八 R3 裁决记录）。

## 5.2 实现符合性核验（逐条对照裁决 8 项要求）

| # | 裁决要求 | 证据 | 结论 |
| --- | --- | --- | --- |
| 1 | 同实验室可多名 ROOM_REPAIR ACTIVE | schema：manager 表**无唯一键**，仅 `idx_scope_target(scope,target_id,status)` 普通索引；`InstrumentManagerServiceImpl.doAssign` L97 `if (scope == DEVICE \|\| scope == PLATFORM)` 才释放旧 ACTIVE，**ROOM_REPAIR 跳过替换逻辑** | ✓ 符合 |
| 2 | 不得限制单 ACTIVE | 同上；DB 层无约束、Service 层无计数校验 | ✓ 符合 |
| 3 | 新增第二名不得自动解除第一名 | ROOM_REPAIR 不进入旧关系 RELEASED 分支 | ✓ 符合 |
| 4 | 同用户同实验室同类型不得重复 | `doAssign` L89-93 `selectActive(scope,targetId,managerType,userId)` 命中即抛 `INSTRUMENT_MANAGER_USER_DUPLICATE_ACTIVE` | ✓ 符合 |
| 5 | 解除单人不影响其他人 | `releaseManager` L124-141 按**行 id** 单条更新 RELEASED+effectiveTo+releaseReason | ✓ 符合 |
| 6 | 历史完整保留 | 解除不物理删除；`selectListHistory` 返回全部记录；前端历史抽屉时间线展示 | ✓ 符合 |
| 7 | 权限校验识别全部有效负责人 | `InstrumentScopeSupport.canManageDevice` L66-75 用 `anyMatch` 遍历**全部** ACTIVE 列表；`getCurrentManagers`/`getCurrentManagerMap` 返回 `List`/`Map<Long,List>`；`RoomRespVO.repairManagers` 为 `List<ManagerBriefRespVO>`，房间详情/列表填充全部负责人 | ✓ 符合 |
| 8 | 不引入主/协同负责人等级 | 未为 ROOM_REPAIR 引入任何等级字段或优先级排序；`ManagerTypeEnum`(PRIMARY/REPAIR/BACKUP) 为 02 文档原有正交类型维度（DEVICE/PLATFORM 用），非多名房间负责人之间的等级 | ✓ 符合 |

## 5.3 锁与事务

- 锁 key = `instrument:manager:lock:{scope}:{targetId}:{managerType}`：ROOM_REPAIR 同房间同类型**串行化**（防并发重复分配同一用户），但**不限制人数**——语义正确。
- 锁内 `TransactionTemplate.execute` 包裹 doAssign（避免自调用事务失效），与质粒黑名单同范式。✓
- 未发现任何"ROOM_REPAIR 只能单 ACTIVE"的锁/事务/计数实现。✓

## 5.4 "只返回第一条负责人"接口排查

Grep 全模块：`selectActive`（selectOne）仅用于**同用户防重复**场景（同用户同 target 同 type 理论最多 1 条 ACTIVE，selectOne 安全）；所有面向展示/权限的查询均走 `selectActiveList`/`selectActiveListByTargets` 返回全集。**不存在只取第一条的业务接口**。✓

## 5.5 工单分配边界（INSTRUMENT-06）

Grep 全模块无 轮询/随机分配/抢单/默认第一 任何实现；本批次无工单模块代码。room 表 `repair_manager_id/name` 快照字段**不回填**（注释与 RoomRespVO 说明一致），权威来源为 manager 表多行 ACTIVE——避免了"快照只能存一人"与 G26=A 的冲突。✓

## 5.6 发现的冲突及修正建议

| 项 | 位置 | 性质 | 建议 |
| --- | --- | --- | --- |
| 注释文案过时 | `InstrumentManagerServiceImpl.java` L96 `// ROOM_REPAIR：允许多名维修负责人同时 ACTIVE（G26 待确认，默认方案A）` | 注释，不影响行为 | 列入下一次修正任务：改为"G26 已裁决方案A"（本任务不改代码） |

## 5.7 是否影响三个 SQL 文件的执行条件

**不影响。** schema manager 表结构天然兼容多 ACTIVE（无唯一键）；dict/menu 与 G26 无关。G26=A 反而确认了 schema 注释中"默认方案A"的落地正确性，三个 SQL 可按原样执行。

---

# 六、数据库对象冲突清单

| 对象 | 冲突检测 | 实测 | 结果 |
| --- | --- | --- | --- |
| 5 张 lab_instrument_* 表 | information_schema.tables | 全部 cnt=0 | 无冲突 |
| 5 个字典类型 | system_dict_type（含 deleted） | 0 行 | 无冲突 |
| 18 个字典项 | system_dict_data | 0 行 | 无冲突 |
| 菜单 ID 13600~13653 | system_menu（含 deleted） | 0 行 | 无冲突 |
| `lab:instrument:%` 权限串 | system_menu.permission（含 deleted） | 0 行 | 无冲突 |
| 套餐 114 已含本批 ID | 词边界 REGEXP ×26 | 全 0 | 无冲突 |
| 角色授权 (904/906, 136段) | system_role_menu | 0 行（仅已有 13478，幂等跳过） | 无冲突 |

---

# 七、SQL 幂等性与重复执行风险

| 文件 | 幂等机制 | 重复执行影响 |
| --- | --- | --- |
| schema | `CREATE TABLE IF NOT EXISTS` ×5 | 0 变更；不校正已被手工改动的结构（由 §2.2 验收列核对兜底） |
| dict | 类型 `NOT EXISTS(type)`；数据 `NOT EXISTS(dict_type,value,deleted=0)`；id 自增 | 0 行写入 |
| menu | 菜单 `NOT EXISTS(id)` + 父目录 13478 可用守卫；套餐 括号格式+词边界+菜单存在 三重守卫；角色授权 `NOT EXISTS(role_id,menu_id,tenant_id,deleted=0)` | 0 行写入/更新 |

注意：`system_role_menu` 无 (role_id,menu_id) 唯一索引，防重完全依赖 NOT EXISTS——并发重复执行同一脚本理论上可能产生重复授权行。**执行要求：单连接串行执行，禁止两个会话同时跑 menu 脚本**。

---

# 八、SQL 执行顺序与执行后验收

## 8.1 执行顺序（严格）

1. **备份**：`mysqldump labplatform system_menu system_tenant_package system_role_menu system_dict_type system_dict_data > 备份.sql`
2. `20261014_instrument_01_schema.sql`（DDL 自动提交，独立执行）
3. `20261014_instrument_01_dict.sql`
4. `20261014_instrument_01_menu.sql`：**同一连接** `START TRANSACTION;` → 第1/2/3节 → 第4节验收 → 全符 `COMMIT`，任一不符 `ROLLBACK`
5. 客户端连接必须 `utf8mb4`；menu 脚本单会话串行执行
6. 执行后由 906 账号重新登录做功能验收（菜单可见性、按钮权限、大厅访问），904 账号做越权回归

## 8.2 执行后验收 SQL（三个脚本自带，汇总）

- schema §2.1~2.4：5 表存在（InnoDB/utf8mb4）、列逐项核对、索引核对（3 uk + idx）、5 表空表基线
- dict §3.1~3.4：5 类型、数据项 8/2/4/2/2、18 行逐行核对、NO_SHOW 回归 0 行
- menu §4.1~4.6：26 行（type 1/7/18）、权限串 18 行、套餐 26 个 has_x 全 1、906=26 行/904=5 行/903·905·907=0 行、904 越权回归 0 行

---

# 九、问题严重程度与修正建议

| 编号 | 严重度 | 问题 | 修正建议 | 是否阻断执行 |
| --- | --- | --- | --- | --- |
| P-1 | 提示 | menu SQL 头部注释"已用最大 id=13579"与实测 13585 不符（2026-10-12 质粒模块新增 13580~13585） | 执行人知悉即可；13600~13653 段实测空闲，不影响写入安全。可在执行前把注释数字更新为 13585（纯注释勘误） | 否 |
| P-2 | 提示 | 库默认字符集为 `utf8/utf8_general_ci` 而非 utf8mb4 | schema 每张表**表级+列级显式指定 utf8mb4/utf8mb4_unicode_ci**，实际建表不受影响；客户端连接须 utf8mb4（dict/menu 含中文字面量） | 否 |
| P-3 | 文档勘误 | 12 号报告 §8 标题"13 个权限编码"与实际明细 18 个不符（4+5+4+2+3=18） | 后续修订 12 号报告标题数字为 18；Controller/菜单 SQL 三方 18 串实测一致，代码与 SQL 无需改动 | 否 |
| P-4 | 注释待办 | `InstrumentManagerServiceImpl` L96 注释"G26 待确认，默认方案A"已过时 | 列入下一次修正任务改注释文案（本任务授权范围内不改代码） | 否 |

**无 BLOCKER 级、无 MAJOR 级问题。**

---

# 十、最终结论

## **PASS：三个 SQL 文件均满足安全执行条件。**

- `20261014_instrument_01_schema.sql`：**可执行**。5 表不存在、DDL 幂等、六公共字段齐全、唯一约束正确、无危险语句。
- `20261014_instrument_01_dict.sql`：**可执行**。5 类型 18 项与 Java 枚举/前端常量一致、无 NO_SHOW（C1 落实）、幂等零冲突。
- `20261014_instrument_01_menu.sql`：**可执行**。26 菜单结构正确、18 权限串与 Controller 三方一致（12 号报告"13"为计数笔误）、ID 段空闲、套餐/角色授权守卫完备、904 最小授权、906 全量授权、无跨租户风险；部分写入风险由人工事务流程（§8.1 第 4 步）控制。

**G26 专项结论**：G26 已裁决 A；数据模型 ✓ 符合、Service ✓ 符合、前端 ✓ 符合、SQL ✓ 符合；无实现冲突；唯一残留为过时的注释文案（P-4，列入下次修正任务）；**G26=A 不改变三个 SQL 文件的执行条件**。

执行前提（一次性确认）：执行时按 §八 顺序与事务要求操作；执行人对 P-1 的 MAX(id)=13585 偏差知情。

---

## 附：本次任务文档更新记录（授权范围内）

| 文件 | 更新 |
| --- | --- |
| `06-维修工单与负责人分配设计.md` | §4.3 / §八异常场景 / §九待确认清单：G26 标记更新为"已裁决 A"，工单分配规则移交 INSTRUMENT-06 |
| `合并.md` | 对应 3 处同步 |
| `11-INSTRUMENT-01-设计修订记录.md` | 新增 §八 R3 裁决记录；Q5 行追加裁决索引 |
| 代码 / 三个 SQL 文件 | **未做任何修改**（P-3/P-4 列入后续任务） |
