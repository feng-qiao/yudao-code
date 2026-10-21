# 19-INSTRUMENT-02 SQL 执行前最终核验报告

- 任务单：**TASK INSTRUMENT-02-FINAL-SQL-REVIEW-01**
- 日期：2026-10-15
- 性质：**只读最终核验**。本任务未执行任何 DDL / DML / 角色授权 / 服务重启 / 业务接口写操作。
- 核验对象：
  1. `ruoyi-vue-pro/sql/lab/20261015_instrument_02_schema.sql`
  2. `ruoyi-vue-pro/sql/lab/20261015_instrument_02_menu.sql`
  3. `ruoyi-vue-pro/sql/lab/20261015_instrument_02_device_manager_role.sql`
  4. 相关 Java 权限调用链与前端权限渲染路径
- 关联既有交付物：`15/16/17/18-INSTRUMENT-02-*.md`（阶段 D 修订已完成）

> **声明**：本报告结论「READY FOR AUTHORIZATION」仅表示**准备申请执行授权**，**不代表允许执行**。实际执行须由负责人另行裁决授权。
>
> 本任务只执行了**只读预检**（`information_schema` 查询与 `SELECT`），**严禁执行三个 SQL 文件中的任何写入语句**——本任务严格遵守，未执行任何写入。

---

## 0. 环境与工具

| 项 | 值 |
|---|---|
| MySQL 客户端 | `D:\worktools\phpstudy_pro\Extensions\MySQL8.0.12\bin\mysql.exe` |
| 连接 | `--host=127.0.0.1 --port=3306 --user=bencao --database=labplatform --default-character-set=utf8mb4` |
| 服务端版本 | MySQL 8.0.12 |
| 目标库 | `labplatform` |
| 执行方式 | 全部为只读 `SELECT` / `information_schema` 查询，无任何写入 |

---

## 一、三个 SQL 文件的逐项检查结果

### 1.1 schema.sql（六张新表）

| # | 检查项 | 预期 | 结论 |
|---|---|---|---|
| 1 | 六张新表存在性 | `information_schema.tables` 命中 0 行 | **PASS**（实测 `schema:6tables = 0`，即六表均不存在，对应 §0.4「情况 1 首次部署」） |
| 2 | 建表语句幂等 | 全部 `CREATE TABLE IF NOT EXISTS` | **PASS**（1.1~1.6 六条均含 `IF NOT EXISTS`） |
| 3 | 字符集/排序规则 | 显式 `CHARACTER SET=utf8mb4 COLLATE=utf8mb4_unicode_ci` | **PASS**（DDL 逐列/逐表显式声明，不依赖库默认字符集） |
| 4 | 物理外键 | 不建物理外键 | **PASS**（仅逻辑关联 + 应用层校验，符合 lab 模块既有规范） |
| 5 | 唯一键 | `uk_apply_tenant_no(tenant_id,apply_no)`、`uk_account_tenant_user(tenant_id,user_id)` | **PASS**（1.1/1.4 均含；其它表按设计不设 DB 唯一键，由应用层 + Redisson 锁保证） |
| 6 | 前置检查段 | §0 全为只读 `information_schema` 查询，表不存在时返回空集不报错 | **PASS** |
| 7 | 写入段 | §1（六条 DDL） | **PASS** |
| 8 | 验收段 | §2（其中 §2.4 空表基线**必须在 §1 之后**执行，脚本已显式注明） | **PASS** |
| 9 | 停止条件 | §3 五条（表已存在 / 字符集 / 字典缺失 / 结构不一致 / 执行错误） | **PASS** |
| 10 | 分段可独立执行 | §0 只读门槛、§1 写入、§2 验收、§3 停止条件分段清晰 | **PASS** |
| 11 | 是否改动 INSTRUMENT-01 数据 | 无 DROP / DELETE / ALTER 现有表 | **PASS**（全脚本仅 6 条 `CREATE TABLE IF NOT EXISTS`，不触碰任何既有表） |

### 1.2 menu.sql（菜单 13660~13673 + 套餐 + 角色授权）

| # | 检查项 | 预期 | 结论 |
|---|---|---|---|
| 1 | 预留段 13660~13673 空闲 | `cnt=0` | **PASS**（实测 `menu:13660-13673 = 0`） |
| 2 | `MAX(id) < 13660` | `13653` | **PASS**（实测 `menu:maxid = 13653`，段未被占用） |
| 3 | 权限串无冲突 | 0 行 | **PASS**（实测 `perm:conflict = 0`） |
| 4 | 父目录 13600 存在且启用 | 1 行 `type=1,parent=13478,status=0` | **PASS**（实测 13600 `type=1,parent=13478`；13478 为根目录 `type=1,parent=0`） |
| 5 | 目标角色 904/906 存在且启用 | 2 行，`tenant_id=162,status=0` | **PASS**（实测 904「普通用户」/906「本草基因管理员」均 `status=0,tenant_id=162`） |
| 6 | 租户 162 + 套餐 114 | 各 1 行，`package_id=114`，括号格式 ok | **PASS**（实测 162 `status=0,package_id=114`；套餐 114 `lb='[',rb=']'`，`len=1378`） |
| 7 | 套餐不含本批 ID | 14 个 `has_x` 全 0 | **PASS**（前序实测 14 个 `has_x` 全 0；菜单未建，故本条为当前基线记录，执行后由 §4.4 复核） |
| 8 | 菜单写入幂等 | 14 条 INSERT 均带 `NOT EXISTS(id)` / `EXISTS(父目录)` 守卫 | **PASS** |
| 9 | 套餐追加幂等 | 14 条 UPDATE 均带「括号格式 + `NOT REGEXP` 词边界 + 菜单存在」守卫 | **PASS** |
| 10 | 角色授权幂等 | §3.1/§3.2 `NOT EXISTS(role_id,menu_id,tenant_id)` 守卫 | **PASS**（`system_role_menu` 无 `(role_id,menu_id)` 唯一索引，防重完全依赖 `NOT EXISTS`，脚本头部第 19 行已声明） |
| 11 | 授权范围 | 906=14 条全部；904=6 条（13660/13661/13662/13663/13664/13672）；903/905/907 不授权 | **PASS**（与冻结设计 04 §5.2 + 14 号报告 §4.4 一致） |
| 12 | 是否误授信用/暂停管理写权限 | 904 不含 `credit:*`、`suspend:manage`、`qualification:audit/manage` | **PASS**（§4.6 越权回归核对项预期 0 行；904 仅含查询类） |
| 13 | 是否改动 INSTRUMENT-01 数据 | 无 DROP / DELETE；仅 `INSERT`/`UPDATE`（限 13660~13673 段与套餐 114 追加） | **PASS**（不覆盖、不删除既有菜单/授权；§3 对 904/906 授权「保持原样，不覆盖、不删除、不重建」） |
| 14 | 分段可独立执行 | §0 只读门槛、§1 菜单、§2 套餐、§3 授权、§4 验收、§5 人工验收、§6 事务回滚 | **PASS** |

### 1.3 device_manager_role.sql（角色 908 + 8 条授权）

| # | 检查项 | 预期 | 结论 |
|---|---|---|---|
| 1 | 角色 code 冲突 | 0 | **PASS**（实测 `role:code_conflict = 0`） |
| 2 | 角色 name 冲突 | 0 行 | **PASS**（实测 `role:name_conflict = 0`，「仪器设备负责人」无同名） |
| 3 | 角色 ID 908 空闲 | `id_908_used=0` | **PASS**（实测 `= 0`） |
| 4 | `AUTO_INCREMENT` 允许显式插入 908 | `next_auto_increment=908` | **PASS**（实测 `= 908`，即当前已用最大 id=907，显式插入 908 不冲突，插入后 AUTO_INCREMENT 顺延至 909） |
| 5 | 祖先链完整准确 | `13478→13600→13620→13621`、`13660→13661`、`13665→13666` | **PASS**（§2 授权集合 8 条含完整父链；§0.4/0.5 门槛核对） |
| 6 | 8 条授权仅含设备负责人所需 | 8 条：13478/13600/13620/13621/13660/13661/13665/13666 | **PASS**（§2 集合一致；§3.4 越权回归预期 0 行） |
| 7 | 是否误授信用/暂停管理/设备写权限 | 全部不含 | **PASS**（头部第 6 条明确排除 `device:create/update/delete/manage`、`qualification:apply/manage`、`credit:*`、`suspend:*`） |
| 8 | 租户处理 | 角色与授权均显式 `tenant_id=162`（不依赖列默认值 0） | **PASS**（§1 INSERT 显式 162；§2 授权显式 162） |
| 9 | 幂等 | 角色 INSERT 带「id 未用 + code 未冲突」双守卫；授权带「角色启用 + 菜单启用 + 未授权」三守卫 | **PASS** |
| 10 | 是否含 `system_user_role` 写入 | 否 | **PASS**（头部第 8 条明确声明不含；§4 说明由用户管理页人工分配） |
| 11 | 是否改动 INSTRUMENT-01 数据 | 无 DROP / DELETE / 改动既有角色 | **PASS**（仅新建角色 908 与新增授权；不覆盖 904/906） |
| 12 | 分段可独立执行 | §0 只读门槛、§1 角色、§2 授权、§3 验收、§4 人工验收、§5 事务回滚 | **PASS** |

**三脚本共性问题（均 PASS）**：

- **可重复执行/部分执行后重试**：三者写入均带幂等守卫，重复执行影响 0 行；部分执行后重跑可收敛补齐，无唯一键冲突（schema 用 `IF NOT EXISTS`；menu 用 `NOT EXISTS`/`NOT REGEXP`；role 用 `NOT EXISTS`）。
- **写入影响行数可核对**：各脚本均在说明中标注预期影响行数（menu：§1=14、§2≤14、§3.1≤14、§3.2≤6；role：§1=1、§2≤8），便于人工核对。
- **无降级/破坏性语句**：三脚本合计**无任何 `DROP` / `TRUNCATE` / `DELETE` / `ALTER`**，不改动 INSTRUMENT-01 既有数据。

---

## 二、当前数据库只读预检结果（2026-10-15 实测）

> 均在只读模式下执行，未做任何写入。

| 检查 | 实测值 | 判定 |
|---|---|---|
| 六目标表存在数 | **0** | 首次部署，对应 schema §0.4「情况 1」；可安全执行 §1 DDL |
| 菜单 13660~13673 占用数 | **0** | 预留段完全空闲 |
| 菜单 `MAX(id)` | **13653** | `< 13660`，段未占用 |
| 权限串冲突（qualification/credit/suspend:%） | **0 行** | 无冲突 |
| 父目录 13600 | 存在：`type=1, parent_id=13478` | 可用 |
| 根目录 13478 | 存在：`type=1, parent_id=0` | 可用 |
| 角色 904 | 「普通用户」`code=普通用户`，`status=0`，`tenant_id=162` | 与脚本常量一致 |
| 角色 906 | 「本草基因管理员」`code=lab_admin`，`status=0`，`tenant_id=162` | 与脚本常量一致 |
| 角色 code 冲突 `instrument_device_manager` | **0** | 无冲突 |
| 角色 name 冲突「仪器设备负责人」 | **0 行** | 无同名 |
| 角色 id 908 已占用 | **0** | 空闲 |
| `system_role` AUTO_INCREMENT | **908** | 允许显式插入 908 |
| 租户 162 | 「成都中医药大学」`status=0`，`package_id=114` | 与常量一致 |
| 套餐 114 | 存在，`status=0`，`lb='['`, `rb=']'`，`len=1378` | 括号格式正常，可追加 |
| 套餐 114 中 13660~13673 命中 | 全部 0 | 尚未追加 |
| `role_menu` role 908 授权数 | **0** | 现状留证 |
| `role_menu` 13660~13673 各角色授权 | **0 行** | 尚未授权 |
| INSTRUMENT-01 菜单段 13600~13653 | **26 行** | 既有段完好 |
| 数据库默认字符集 | **`utf8 / utf8_general_ci`** | **偏离脚本 §0.2 预期 utf8mb4（见 §五 风险评估）** |
| 既有表 `lab_instrument_*` / `system_menu/role/role_menu/tenant/tenant_package` 排序规则 | `utf8mb4_unicode_ci` | 新表 DDL 亦显式 utf8mb4，与既有表一致 |

**结论**：除「库默认字符集为 utf8」这一已评估的非阻塞偏离外，所有前置条件均满足脚本预期，**写入段具备执行前提**。

---

## 三、角色 908 的权限明细

角色 908 创建后授予 8 条菜单授权（`system_role_menu`，`tenant_id=162`）：

| menu_id | 名称 | type | 权限串 | 用途 |
|---|---|---|---|---|
| 13478 | 实验室管理 | 1 目录 | - | 祖先链 |
| 13600 | 仪器管理 | 1 目录 | - | 祖先链 |
| 13620 | 仪器设备 | 2 页面 | - | 祖先链（设备查询页） |
| 13621 | 设备查询 | 3 按钮 | `lab:instrument:device:query` | 审核页设备下拉 |
| 13660 | 我的使用资质 | 2 页面 | - | 祖先链（资质查询页） |
| 13661 | 资质查询 | 3 按钮 | `lab:instrument:qualification:query` | 审核/列表查询 |
| 13665 | 资质审核 | 2 页面 | - | 审核入口页 |
| 13666 | 资质审核 | 3 按钮 | `lab:instrument:qualification:audit` | 审核操作 |

**权限最小化核对（结论：无越权）**：

- **不含**任何信用权限（`credit:query/adjust/export`）；
- **不含**任何暂停权限（`suspend:query/manage`）；
- **不含**设备写权限（`device:create/update/delete/manage`）；
- **不含**资质申请（`qualification:apply`）与撤销资质（`qualification:manage`）；
- 仅含：1 个功能查询串（`device:query`）+ 1 个资质查询串（`qualification:query`）+ 1 个审批串（`qualification:audit`）及必要祖先链。

> 该集合与「设备负责人只能查看/审批其实际负责设备的申请」的业务约束一致；设备级数据范围由后端 `InstrumentScopeSupport#canManageDevice` 在 Service 层强制（见 §四）。

---

## 四、关键 Java 权限调用链证据

### 4.1 暂停到期不自动解除（H1）——全路径一致

- **Mapper**（[InstrumentSuspendMapper.java](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/mysql/instrument/InstrumentSuspendMapper.java)）：
  - `selectActiveCovering(userId, deviceId)`：仅 `.eq(status, ACTIVE).le(startTime, now)`（ALL 或 SINGLE=deviceId），**已移除 `.gt(endTime, now)`**；
  - `selectActiveListByUser` / `selectActiveSingleByDevice`：均不含 `end_time` 条件；
  - `selectActiveExpired` / `updateExpireIfActive`：保留并注明「本期不启用」。
- **Service**（[InstrumentSuspendServiceImpl.java](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentSuspendServiceImpl.java)）：`expireSuspends()` 保留，但**仅由未注册的 Job 调用**；全项目无其它自动置 `EXPIRED` 路径。实测 `infra_job` 无 `handler_name` 含 `instrument` / `SuspendExpire` 的记录 → 到期 Job 未注册，与 18 号报告一致。
- **前端**（[my-credit/index.vue](file:///e:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/my-credit/index.vue)）：列含「计划结束时间」`endTime` 与「实际解除时间」`releaseTime`，提示文案「暂停须由授权管理员人工解除；到达『计划结束时间』不会自动解除」。

**结论：H1（人工解除）在所有调用路径、Mapping、前端文案一致。PASS。**

### 4.2 设备负责人审批：角色权限 ∩ 负责设备关系（B2）

- **Controller**（[InstrumentQualificationController.java](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/controller/admin/instrument/InstrumentQualificationController.java)）：`audit` 标注 `@PreAuthorize("@ss.hasPermission('lab:instrument:qualification:audit')")`（role_menu 直查）。
- **Service**（[InstrumentQualificationServiceImpl.java](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentQualificationServiceImpl.java)）`auditApply`：`applyMapper.selectByIdForUpdate(id)` 行锁 → `scopeSupport.canManageDevice(loginUserId, apply.getTargetId())`，否则抛 `INSTRUMENT_QUALIFICATION_AUDIT_PERMISSION_DENIED`（051）→ `updateAuditResult` 返回 0 行抛状态变更异常。
- **范围判定**（[InstrumentScopeSupport.java](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentScopeSupport.java)）：`canManageDevice` = `canManageAll`（`super_admin`/`lab_admin`）∨（DEVICE 直接负责）∨（PLATFORM 平台下负责）；跨租户 `device=null` → `false`。

**结论：**

- **角色权限**：`@PreAuthorize` 走 `system_role_menu` 直查（不受菜单树完整性影响）；
- **负责设备关系**：Service 层 `canManageDevice` 二次强制；
- **两者必须同时满足**。仅具 908 角色但非该设备负责人 → 审批被拒（051）；仅设备负责人但无 908 角色 → `@PreAuthorize` 拒绝（403）。**PASS。**

### 4.3 普通用户不能借共用 query 权限获取他人数据（B3）

- `getQualificationPage`：非管理员时 `managedDeviceIds` 为空 → 显式 `throw exception(FORBIDDEN)`；否则**恒** `.in(targetId, managedDeviceIds)`（B3 修正，替换原租户全量越权）。
- `getSuspendPage`：同规则——非管理员 `managedDeviceIds` 空 → `FORBIDDEN`；否则**恒** `.in(deviceId, managedDeviceIds)`。
- `getApplyPage`：非管理员 `.and(w -> w.eq(applicantUserId, loginUserId).or(managedDeviceIds 非空 → w.in(targetId, managedDeviceIds)))`，空范围仅见本人。
- 信用域：`getCreditPage` / `getFlowPage` / `getFlowExportList` 经 `requireManageAll(loginUserId)`（非 `canManageAll` → `FORBIDDEN`）；`getMyFlowPage` 强制 `selectPageByUser(reqVO, loginUserId)`；`adjustCredit` 非管理员需目标用户在其管理范围内的有效/暂停资质。
- `getMySuspends` = `selectListByUser(loginUserId)`（强制本人）。

**结论：** 共用 query 权限（`qualification:query` / `suspend:query` / `credit:query`）的**管理接口均追加了"管理范围非空"与"范围内过滤"的双重约束**；空范围显式 403。普通用户无法借共用 query 权限读取他人数据。**PASS。**

### 4.4 跨租户访问必须拒绝

- 框架 `TenantDatabaseInterceptor` 对 `TenantBaseDO` 自动追加 `tenant_id` 过滤，跨租户 `selectById` 返回 `null`；
- `InstrumentScopeSupport#canManageDevice` 中 `deviceMapper.selectById(deviceId)` 跨租户返回 `null` → `false` → 审批被拒；
- 目标用户有效性经 `AdminUserApi`（带租户过滤）校验。

**结论：跨租户访问被框架租户插件 + Service 范围校验双重拒绝。PASS。**

### 4.5 前端权限渲染路径（关键框架行为）

- 后端 `@PreAuthorize` → `PermissionServiceImpl` → `system_role_menu` 直查（**不受菜单树完整度影响**）。
- 前端 `permissions` 集合来自 [AuthController#getPermissionInfo](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/controller/admin/auth/AuthController.java#L93-L118)：`menuIds = getRoleMenuListByRoleId(roleIds)` → `menuService.getMenuList(menuIds)`（仅已授权菜单）→ `menuService.filterDisableMenus(menuList)` → [AuthConvert.INSTANCE.convert](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/convert/auth/AuthConvert.java#L31-L79)。`.permissions(convertSet(menuList, MenuDO::getPermission))` **先于** `.menus(buildMenuTree(menuList))` 求值，故按钮权限串在 `buildMenuTree` 移除按钮前已采集。
- `isMenuDisabled` 逻辑（[MenuServiceImpl.java#L158-L183](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/permission/MenuServiceImpl.java#L158-L183)）：`status` 禁用 → 丢弃；`parentId==ID_ROOT` → 保留；否则 `parent = menuMap.get(parentId)`，**`parent == null`（父节点未被授权）→ 丢弃该节点**。
- **推论**：前端 `v-hasPermi` 要用到某按钮权限串，**必须授予其完整祖先链**；后端不受此限（但会造成前后端不一致）。这正是 role 脚本 §2 按完整祖先链授予的框架依据。

---

## 五、数据安全及幂等性风险

### 5.1 风险评估（逐项）

| 风险 | 说明 | 等级 | 处置 |
|---|---|---|---|
| **DB 默认字符集 utf8 ≠ 脚本 §0.2 预期 utf8mb4** | 实测 `utf8/utf8_general_ci`。但**新表 DDL 逐列/逐表显式 `CHARACTER SET=utf8mb4 COLLATE=utf8mb4_unicode_ci`**，且既有 `lab_instrument_*` 与 `system_menu/role/role_menu/tenant/tenant_package` 实测均为 `utf8mb4_unicode_ci`（INSTRUMENT-01 同库先例）。新建表将按显式声明落为 utf8mb4，不继承库默认。 | **非阻塞（低）** | 执行前**人工确认**：接受"库默认字符集保持 utf8，新表按显式 utf8mb4 创建"。若负责人要求库级统一，须另行评估转换风险，**不得在本批脚本中顺带改库字符集**。 |
| **904 授权 13672（suspend:query）缺祖先 13671** | menu SQL §3.2 授 904 `13672`，但其父 `13671`（暂停管理页面）未授 904。按 `filterDisableMenus` 规则，`13672` 的权限串会从前端 `permissions` 数组被丢弃。**但经全局 grep 确认前端无任何 `v-hasPermi` 使用 `suspend:query`**；且 `my-credit/index.vue` 暂停区块未做权限门控、直接调用 `/suspend/my`（后端 @PreAuthorize 走 role_menu 直查，904 已具备该权限串）→ **不构成功能缺陷**。 | **良性观察项（无缺陷）** | 知悉即可；无需修改脚本。若后续前端对暂停区块加 `v-hasPermi="'lab:instrument:suspend:query'"`，则须同步补授 13671。 |
| **904 授权 13621（device:query）缺祖先 13620** | 属 INSTRUMENT-01 既有状态（非本批引入）。同样按 `filterDisableMenus` 规则前端权限串会被丢弃，但**前端无任何 `v-hasPermi` 使用 `device:query`** → 无功能影响。 | **良性观察项（无缺陷）** | 知悉即可；不属本批改动范围。 |
| **role SQL 先于 menu SQL 执行的顺序风险** | role 脚本 §2 守卫要求目标菜单 `EXISTS 且 status=0`；若无视 §0.5 先跑 role SQL，角色会创建但仅授已存在的 `13620/13621`，其余 4 条（13660/13661/13665/13666）因菜单不存在而影响 0 行；重跑后自动补齐。 | **中等（可恢复）** | **强制顺序**：schema → menu → role（见 §六）。执行前逐条核对 §0.5 是否返回 6 行。 |
| **并发占用 id 908 / 菜单段** | 若并发有他方占用 id 908 或 13660~13673，幂等守卫会**静默使写入影响 0 行**，不报错。 | **中等** | 由 §3.1（角色 1 行）与 §4.1/§4.2（菜单 14 行）验收捕获；执行须在**无并发 DDL/DML** 窗口内进行。 |
| **重复执行 / 部分执行后重试** | 三脚本写入均带幂等守卫，重跑影响 0 行或自动补齐，无唯一键冲突。 | **低** | 无需额外处置；按脚本 §6/§5 事务说明执行。 |
| **错误执行导致难以回滚** | 菜单/套餐/授权为数据写入，需事务 + 备份兜底。 | **低（有兜底）** | 执行前 `mysqldump` 备份 `system_menu` / `system_tenant_package` / `system_role_menu` / `system_role`；同连接 `START TRANSACTION` → 写入 → 核对 → `COMMIT`；异常 `ROLLBACK` 或备份恢复。 |

### 5.2 数据安全结论

- 三脚本**不含** `DROP` / `TRUNCATE` / `DELETE` / `ALTER`，**不改动 INSTRUMENT-01 既有数据**；
- 所有新增写入均限定在预留段（菜单 13660~13673）、套餐 114 的 ID 追加、角色 908 及其 8 条授权，作用域封闭；
- 幂等守卫完整，部分执行后重试可收敛，无数据冲突。

---

## 六、推荐 SQL 执行顺序与每步停止条件

**强制执行顺序**（顺序不可调换：role 脚本依赖 menu 脚本创建的菜单）：

### 步骤 1：`20261015_instrument_02_schema.sql`

- 执行前：运行 §0（§0.1 六表、§0.2 字符集、§0.3 字典、§0.4 列级结构）。
- 停止条件：§0.1 任一 `cnt=1`；§0.2 字符集非 utf8mb4（**本环境为偏离项，需负责人先行确认**，见 §五）；§0.3 字典缺失；§0.4 结构不一致（**禁止 DROP/重建/自动 ALTER，回报负责人**）。
- 执行：§1 六条 `CREATE TABLE IF NOT EXISTS`。
- 验收：§2.1~§2.4（§2.4 空表基线须在此步之后）。
- 下一步前提：§2.1 返回 6 行、§2.4 六表 `tbl_rows=0`。

### 步骤 2：`20261015_instrument_02_menu.sql`

- 执行前：运行 §0（§0.1 段空闲、§0.2 MAX(id)、§0.3 权限串、§0.4 父目录、§0.5 角色、§0.6 租户/套餐、§0.7 套餐 has_x）。
- 停止条件：§0.1 `cnt≠0`；§0.2 `MAX(id)≥13660`；§0.3 权限串冲突；§0.4 父目录缺失；§0.5 目标角色缺失/禁用；§0.6 租户/套餐异常。**当前实测全部满足。**
- 执行：§1 菜单 → §2 套餐追加 → §3.1 授 906 → §3.2 授 904。
- 验收：§4.1（14 行）、§4.2、§4.3（9 权限串）、§4.4（套餐含 13660/13665/13673）、§4.5（906=14、904=6）、§4.6（越权回归 0 行）。
- 下一步前提：§4.1 五页面九按钮齐全、§4.5 授权条数符合预期、§4.6 为 0 行。

### 步骤 3：`20261015_instrument_02_device_manager_role.sql`

- 执行前：运行 §0（§0.1 code、§0.2 name、§0.3 id 908+AUTO_INCREMENT、§0.4 祖先 13478/13600、§0.5 目标菜单 6 行、§0.6 权限串归属、§0.7 租户 162、§0.8 现状留证）。
- 停止条件：§0.1 code 冲突；§0.3 `id_908_used≠0` 或 `AUTO_INCREMENT≠908`；§0.4 祖先缺失；**§0.5 返回 < 6 行（说明菜单 SQL 尚未执行）→ 停止，先执行步骤 2**；§0.7 租户异常。
- 执行：§1 角色 → §2 授权。
- 验收：§3.1（角色 1 行）、§3.2（8 行）、§3.3（明细）、§3.4（越权回归 0 行）、§3.5（904=6、906=14 未被改动）。
- 完成前提：§3.1~§3.5 全部符合预期后 `COMMIT`。

### 每条命令的通用停止规则

- 任一阶段出现 SQL 错误、影响行数与脚本标注不符、验收查询与预期不符 → **立即停止**，报告负责人；
- `CREATE TABLE` 不受事务保护，schema 部分成功时已建表保留、重跑幂等补齐；
- menu/role 建议同一连接事务执行，异常即 `ROLLBACK`，并可用备份恢复。

---

## 七、尚需在前一步 SQL 执行后才能完成的条件性预检

以下检查**当前无法判定**（依赖前置写入），**必须在对应前一步 SQL 执行后立即执行**。在此之前**不得记为 PASS**：

| # | 条件性预检 | 依赖 | 归属步骤 |
|---|---|---|---|
| 1 | 六表实际列数 / 公共 6 列 / 主键与唯一键 / 关键业务列与 DDL 完全匹配（`information_schema`） | 步骤 1 完成后表才存在 | 步骤 1 §2 / schema §0.4 的「情况 2」核对 |
| 2 | 六表 `tbl_rows` 空表基线 = 0 | 步骤 1 完成后 | 步骤 1 §2.4 |
| 3 | 菜单 13660~13673 落库 14 行（5×type=2 + 9×type=3） | 步骤 2 §1 写入后 | 步骤 2 §4.1/§4.2 |
| 4 | 9 个权限串与后端 `@PreAuthorize` 一一对应 | 步骤 2 §1 写入后 | 步骤 2 §4.3 |
| 5 | 套餐 114 已包含 13660/13665/13673 | 步骤 2 §2 写入后 | 步骤 2 §4.4 |
| 6 | 906=14 行、904=6 行授权 | 步骤 2 §3 写入后 | 步骤 2 §4.5 |
| 7 | 904 越权回归 = 0 行 | 步骤 2 §3.2 写入后 | 步骤 2 §4.6 |
| 8 | role 脚本 §0.5「目标菜单 6 行存在且启用」 | **必须步骤 2 完成后** | 步骤 3 §0.5（执行前门槛） |
| 9 | role 脚本 §0.6「权限串归属：13621=device:query、13661=qualification:query、13666=qualification:audit」 | 步骤 2 完成后 | 步骤 3 §0.6 |
| 10 | 角色 908 落库 1 行 + 8 条授权明细 + 越权回归 0 行 | 步骤 3 §1/§2 写入后 | 步骤 3 §3.1~§3.4 |
| 11 | 既有 904/906 授权未被改动（904=6、906=14） | 步骤 3 写入后回归核对 | 步骤 3 §3.5 |

> 说明：role 脚本头部第 5/6 条与 §0.5/§0.6 已就上述依赖设计了人工门槛；当前因菜单未建，**§0.5 只会返回 2 行（13620/13621），据任务要求"菜单尚未创建时，不得将依赖新菜单的检查记为 PASS"，故本报告将 §0.5/§0.6 及其后续项列为条件性预检，不计 PASS。**

---

## 八、角色分配流程核验回答

**问 1：新角色 908 创建后，是否自动分配给设备负责人？**

- **不会自动分配。** role 脚本头部第 8 条明确声明「本脚本【不含】把用户分配给该角色的语句（`system_user_role` 写入）」；代码层全项目**无 `instrument_device_manager` 的引用**，无任何自动分配逻辑。
- 框架内唯一自动分配场景为 `TenantServiceImpl#assignUserRole` 为新租户管理员分配 `tenant_admin`，与本角色无关。
- 实测 `system_user_role` 中 role 908 授权数 = 0。

**问 2：如果不自动分配，负责人应通过哪个现有管理页面或后续授权流程分配？**

- 通过现有 **【系统管理 → 用户管理】** 页面人工分配：编辑用户时选择角色（`UserForm.vue` 角色多选）/ 使用 `UserAssignRoleForm.vue`；后端落到 `PermissionServiceImpl#assignUserRole(userId, roleIds)`（[PermissionServiceImpl.java#L208](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/permission/PermissionServiceImpl.java#L208)）。
- 另需在 **【仪器管理 → 仪器负责人】** 确认该用户已是目标设备的生效负责人（业务关系），两道手续缺一不可。
- **本任务未也不得批量给现有用户分配角色。**

**问 3：角色分配与设备负责人业务关系如何共同生效？**

- **角色分配** → 提供"功能权限入口"：后端 `@PreAuthorize`（`role_menu` 直查）放行接口；前端凭 `permissions` 集合显示菜单/按钮。
- **业务关系**（`lab_instrument_manager` 中 `ACTIVE` 的 `DEVICE` 或 `PLATFORM` 负责人）→ 决定"数据范围与审批资格"：`InstrumentScopeSupport#canManageDevice` 在 Service 层强制。
- **两者必须同时满足**：仅角色无关系 → 审批回 051；仅关系无角色 → 接口回 403。

**问 4：负责人被解除后，旧角色仍保留时能否访问或审批其他设备？**

- **不能。** 解除设备负责人关系后（`lab_instrument_manager` 置非生效）：
  - `canManageDevice(userId, deviceId)` → `canManageAll=false`，DEVICE/PLATFORM 关系均不命中 → **false**；
  - `auditApply` → 抛 `INSTRUMENT_QUALIFICATION_AUDIT_PERMISSION_DENIED`（051）；
  - `getQualificationPage` / `getSuspendPage`：`managedDeviceIds` 为空 → **403**；
  - 暂停域：SINGLE 暂停创建/解除被拒；ALL 需 `canManageAll` → 被拒。
- 即旧角色仅保留"功能入口外壳"，**因业务关系消失而无法访问/审批任何设备**；同时不会因角色残留而越权到其它设备。

---

## 九、最终结论

# READY FOR AUTHORIZATION（准备申请执行授权）

> 「READY FOR AUTHORIZATION」仅表示**准备申请执行授权**，**不代表允许执行**。实际执行须由负责人另行裁决授权。

**判定依据**：

1. 三个 SQL 文件逐项检查**全部 PASS**：无越权授权、无破坏性语句、无 INSTRUMENT-01 数据改动、幂等守卫完整、前置/写入/验收分段清晰；
2. 当前数据库只读预检**满足执行前提**：六表不存在、菜单段空闲、角色 908 与 AUTO_INCREMENT 就绪、租户 162/套餐 114 正常；
3. 关键 Java 权限调用链**一致且安全**：H1 人工解除语义全路径一致；B2 角色权限 ∩ 负责设备关系双重强制；B3 共用 query 权限已加管理范围约束；跨租户拒绝；
4. 角色分配流程**清晰无隐患**：不自动分配，须经用户管理页人工分配，并与业务关系共同生效。

**执行前必须由负责人确认/知悉的事项（前置条件）**：

| # | 事项 | 要求 |
|---|---|---|
| A | **执行顺序强制** | 必须为 `schema.sql` → `menu.sql` → `device_manager_role.sql`；**role 脚本必须在 menu 脚本之后**（§0.5 返回 6 行方可执行）。 |
| B | **DB 默认字符集偏离** | 库默认 `utf8` ≠ 脚本 §0.2 预期 `utf8mb4`。新表按 DDL 显式 `utf8mb4` 创建（与既有表一致），判定为**非阻塞**；须人工确认接受，且**不得在本批脚本顺带修改库级字符集**。 |
| C | **良性观察项知悉** | menu §3.2 授 904 的 `13672`（父 13671 未授）与既有 `13621`（父 13620 未授），按框架规则其前端权限串被丢弃；但**前端无 `v-hasPermi` 使用这两个串**，无功能影响。知悉即可，无需改脚本。 |
| D | **备份与事务** | 执行前 `mysqldump` 备份 `system_menu` / `system_tenant_package` / `system_role_menu` / `system_role`；menu/role 建议同一连接 `START TRANSACTION` → 写入 → 验收 → `COMMIT`。 |
| E | **与 INSTRUMENT-03 解耦** | 本核验不启动 INSTRUMENT-03；执行本批 SQL 后须先完成 §七 条件性预检。 |
| F | **角色分配另行人工执行** | 角色 908 不自动分配；执行 SQL 后由负责人经【系统管理 → 用户管理】人工分配，并确认【仪器管理 → 仪器负责人】业务关系，**不得批量分配**。 |

**未发现阻塞性缺陷，故不判定 HOLD。**

---

## 十、边界与诚实声明

- 本报告为**只读核验**产物：未执行三个 SQL 文件中的任何写入语句，未执行 DDL/DML、角色授权、服务重启或业务接口写操作；仅执行了 `information_schema` 查询与只读 `SELECT`。
- 报告中的数据库实测值均为 2026-10-15 只读查询所得；执行时环境可能变化，须以执行前的即时 §0 预检为准。
- 本任务未修改任何业务代码（未发现阻塞性缺陷，无需改造）。
- 本任务未批量给任何用户分配角色。

**完成后停止，等待负责人裁决。**
