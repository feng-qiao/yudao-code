# 39-INSTRUMENT-03 菜单闭环与正式部署授权前复核报告

> 任务：TASK INSTRUMENT-03-R4-MENU-CLOSURE-01
> 日期：2026-10-19
> 最终判定：**PASS / READY-FOR-MENU-AUTHORIZATION**
> 说明：本任务只完成菜单部署包的设计、核验与文档化；**未执行任何菜单 SQL、未写正式库、未写正式 Redis、未开启 C7**。菜单部署授权与 C7 开启授权是两个相互独立的待批准事项（§11）。

---

## 1. B1 根因与修复结果

### 1.1 根因

「我的预约」页面组件 [index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/my-reservation/index.vue) 已随 03-C 批次交付且功能完整，但 `system_menu` 表中从未注册对应菜单行。本系统动态路由由菜单数据驱动（[routerHelper.ts:13](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/utils/routerHelper.ts#L13) `import.meta.glob('../views/**/*.{vue,tsx}')`，按菜单 `component` 字符串匹配），无菜单行即无路由入口，页面不可达——即 37 号报告唯一阻断项 B1。属纯数据缺失，非代码缺陷。

### 1.2 修复结果

在既有设计稿中新增**附录 B**（菜单 ID 13683），与设计稿 §1~§3（13674~13676）、附录 A（13677~13682）合并为单一权威版本，杜绝多份冲突 SQL：

- 菜单字段值经与前端实际组件逐项核对（非机械复制）：
  - 组件文件存在：`src/views/lab/instrument/my-reservation/index.vue`；
  - 组件名一致：`defineOptions({ name: 'LabInstrumentMyReservation' })`（[index.vue:97](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/my-reservation/index.vue#L97)），与菜单 `component_name` 匹配（keep-alive 依赖该名）；
  - `component=lab/instrument/my-reservation/index` 命中动态路由 glob（`../views/lab/instrument/my-reservation/index.vue`），与 13674 booking-config、13677 reservation-manage 同一命名范式；
  - `parent_id=13600`（仪器管理，实测 type=1 status=0）、`type=2`、`sort=20`（顺延 13674=18、13677=19）、`path=my-reservation`、`permission=''`（页面菜单同范式）、`icon=ep:tickets`。
- 正式库只读核验（2026-10-19，纯 SELECT）：`id=13683` 0 行（空闲）；`parent_id=13600 AND path='my-reservation'` 0 行；`component='lab/instrument/my-reservation/index'` 0 行。
- **13684 按钮菜单裁决：不新增**。我的预约页全部操作按钮复用附录 A 已授权限串（取消 `reservation:cancel`、调整 `reservation:adjust`，均挂 13677 下），页面查询接口挂 `reservation:query`（13678），服务端 `@PreAuthorize` 为最终安全边界；经代码核验不存在只有 13683 场景才需要的独立按钮权限，故无技术必要，不予扩权。
- 授权：904 / 906 / 908 各授 13683（显式 `tenant_id=162`）；905 不授；其他角色不自动扩权；套餐 114 以 JSON_CONTAINS 幂等守卫追加 13683。

## 2. 修改文件清单

| 文件 | 变更 | 性质 |
| --- | --- | --- |
| [20261016_instrument_03b_booking_config_menu_design.sql](file:///E:/lixin/dev/ruoyi-vue-pro/sql/lab/20261016_instrument_03b_booking_config_menu_design.sql) | 见 §6.1 六项修订 | 设计稿修订（未执行） |
| 本报告（39 号，新增） | 新建 | 交付文档 |

**前端代码 0 变更**（页面完整，未发现 B1 相关的真实前端缺陷）；**后端业务代码 0 变更**；正式库 / 正式 Redis **0 写入**（全部核验为 SELECT / SHOW / 本地命令）。

## 3. 13674～13683 菜单矩阵（设计终稿）

| ID | 名称 | type | parent | sort | path | component（component_name） | permission | 授权（tenant 162） |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 13674 | 预约配置 | 2 | 13600 | 18 | booking-config | lab/instrument/booking-config/index（LabInstrumentBookingConfig） | （空） | 906 |
| 13675 | 规则查询 | 3 | 13674 | 1 | — | — | lab:instrument:rule:query | 906 |
| 13676 | 规则配置 | 3 | 13674 | 2 | — | — | lab:instrument:rule:update | 906 |
| 13677 | 预约管理 | 2 | 13600 | 19 | reservation-manage | lab/instrument/reservation-manage/index（LabInstrumentReservationManage） | （空） | 904/906/908 |
| 13678 | 预约查询 | 3 | 13677 | 1 | — | — | lab:instrument:reservation:query | 904/906/908 |
| 13679 | 预约创建 | 3 | 13677 | 2 | — | — | lab:instrument:reservation:create | 904/906/908 |
| 13680 | 预约取消 | 3 | 13677 | 3 | — | — | lab:instrument:reservation:cancel | 904/906/908 |
| 13681 | 预约调整 | 3 | 13677 | 4 | — | — | lab:instrument:reservation:adjust | 904/906/908 |
| 13682 | 预约管理操作 | 3 | 13677 | 5 | — | — | lab:instrument:reservation:manage | 906/908（904 不授） |
| 13683 | 我的预约 | 2 | 13600 | 20 | my-reservation | lab/instrument/my-reservation/index（LabInstrumentMyReservation） | （空） | 904/906/908 |

套餐 114 追加 13674~13683 全部 10 项（逐 ID JSON_CONTAINS 幂等守卫）；905 全不授；租户 1 无套餐无业务角色不涉及。

## 4. 904 / 906 / 908 权限矩阵（R4-B 职责复核）

### 4.1 矩阵

| 能力（菜单） | 904 普通用户 | 906 lab_admin | 908 设备负责人 | 905 库管员 |
| --- | --- | --- | --- | --- |
| 预约配置页 + 规则 query/update（13674~13676） | ✗ | ✓ | ✗ | ✗ |
| 预约管理页（13677） | ✓（仅本人数据） | ✓（全部设备） | ✓（授权设备范围） | ✗ |
| reservation:query（13678） | ✓ | ✓ | ✓ | ✗ |
| reservation:create（13679） | ✓（受 C7 约束） | ✓（同） | ✓（同） | ✗ |
| reservation:cancel（13680） | ✓（本人+开始前） | ✓ | ✓（范围内） | ✗ |
| reservation:adjust（13681） | ✓（本人 PENDING） | ✓ | ✓（范围内，换设备须双端可管） | ✗ |
| reservation:manage（13682） | **✗** | ✓ | ✓ | ✗ |
| 我的预约页（13683） | ✓ | ✓ | ✓ | ✗ |

### 4.2 R4-B 五项复核结论（源码证据）

1. **904 进入 13677 只见本人数据** ✅。[InstrumentReservationServiceImpl.java:337-344](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentReservationServiceImpl.java#L337-L344)：`dataScopeAll=scopeSupport.canManageAll(userId)`（仅 super_admin / lab_admin，[InstrumentScopeSupport.java:58-60](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentScopeSupport.java#L58-L60)）→ SQL 层裁剪：[InstrumentReservationMapper.java:187-190](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/mysql/instrument/InstrumentReservationMapper.java#L187-L190) `AND (user_id=本人 OR device_id IN 授权设备集合)`；904 无 `lab_instrument_manager` ACTIVE 关系 → 集合为空 → 退化为仅本人。
2. **13677 对 904 无误导性管理操作** ✅。完成/作废按钮由服务端 `canFinish/canVoid = PENDING && 管理侧`（ServiceImpl fillOperateFlags）控制，904 恒 false → 不渲染；页头明示「数据范围：本人预约或本人负责/管理设备下的预约；可操作项按服务端标记显示，真实权限由后端再次校验」（[index.vue:32](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/reservation-manage/index.vue#L32)）；该页无「创建」按钮（创建入口在设备详情页）。
3. **13683 独立满足本人预约闭环** ✅。列表（getMy，全部状态按 id 倒序，Mapper:163-167 强制 `user_id=本人`）、详情抽屉、取消（`canCancel` 单闸）、调整（`canAdjust` + `v-hasPermi['lab:instrument:reservation:adjust']` 双闸）、操作历史入口齐备（[index.vue:25-36,72-84](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/lab/instrument/my-reservation/index.vue#L25-L84)）。本次未重复开发。
4. **906/908 可同时访问两页** ✅。附录 A 授 13677~13682，附录 B 授 13683；两页数据范围由服务端按角色自适应。
5. **服务端为最终安全边界** ✅。全端点 `@PreAuthorize` + Service 内角色判定（resolveRoleForCancel/Adjust）+ 条件更新（affectedRows=0 即拒绝）+ SQL 数据范围裁剪；前端按钮仅是 UX 层。**未发现普通用户访问 13677 的实际安全风险，无阻断问题**。

## 5. 正式库只读预检证据（2026-10-19，全部 SELECT，0 写入）

| 检查项 | 实测值 | 对应预检 |
| --- | --- | --- |
| `VERSION()` | **8.0.12** | 设计稿 §6.8 兼容性结论的事实基础 |
| `MAX(system_menu.id)` | **13673** | §0「<13674」✓；A.0「=13676」/B.0「=13682」当前**不成立属预期**——证明预检在阶段一/二完成前会正确拦截（§6.9 时序约束） |
| 13674~13683 现有行 | 各 0 行（13683 本轮实测，其余 37 号已测本轮复核一致） | 各段 idle 预检 ✓ |
| `permission LIKE 'lab:instrument:reservation%'` | 0 行 | A.0 existing_perm=0 ✓ |
| `parent_id=13600 AND path='my-reservation'` | 0 行 | B.0 path_dup=0 ✓ |
| `component='lab/instrument/my-reservation/index'` | 0 行 | B.0 comp_dup=0 ✓ |
| 904/906/908 角色（tenant 162, status=0） | role_ok=3 | A.0/B.0 ✓ |
| 套餐 114（status=0，括号 JSON 文本） | pkg_ok=1（**含修正后 RIGHT() 写法实测通过**） | §0/A.0/B.0 ✓ |
| 905 库管员 | 存在，tenant 162 | 不授权对象确认 ✓ |
| 906 已授权菜单数 | **113**（设计稿旧注释 115 已标注为 2026-10-16 历史值，见 §10 N1） | 背景值，幂等守卫不依赖 |
| 904 / 908 已授权菜单数 | 27 / 8 | 背景值 |

**JSON_CONTAINS 写法实证**（8.0.12）：

- `JSON_CONTAINS(CAST(menu_ids AS JSON), 13683)`（整数）→ **ERROR 3146 (22032)** "Invalid data type for JSON data in argument 2"；
- 字符串形式 `'13683'`/`'13677'` → 0（未命中，正确）；`'13600'`/`'13671'` → 1（命中已在套餐内的 ID，正确）。
- 结论：设计稿全部 7 处整数写法已修正为字符串形式（§6.1 第 3 项），否则§2/A.2/B.2/B.4 执行即报错。

## 6. SQL 幂等性与执行顺序核验

### 6.1 设计稿本轮修订（R4-C）

1. 新增附录 B（13683，B.0 预检 / B.1 菜单 / B.2 套餐 / B.3 授权 / B.4 验收，范式同附录 A）；
2. **修复附录 A 两处 SQL 语法错误**：`RIGHT(menu_ids,1)']=']'` → `RIGHT(menu_ids,1)=']'`（原等号与右括号颠倒，执行即语法错误；修正后已对正式库实测通过）；
3. **修复全部 7 处 JSON_CONTAINS 整数第二参数**（§2×3、A.2×2、B.2×1、B.4×1）→ 字符串形式（依据 §5 实证）；
4. §6 新增第 9 条：合并执行顺序与分阶段预检/事务关系；
5. 头部及附录 A 头部「906 已授权 115」标注为 2026-10-16 历史值（当日实测 113；授权数仅为背景，幂等不依赖该值，未将 113 固化为恒真断言）；
6. §6 第 7 条「不含 reservation 权限串」的旧说明标注为已被附录 A 取代的历史说明。

### 6.2 执行顺序（强制）

**阶段一**（§0→§1→§2→§3→§4）：13674~13676 → **阶段二**（A.0→A.1→A.2→A.3→A.4）：13677~13682 → **阶段三**（B.0→B.1→B.2→B.3→B.4）：13683。

- 每阶段独立显式事务：预检人工核对 → 本阶段 DML → 本阶段验收 SELECT 核对 → COMMIT；任一不符 ROLLBACK。
- A.0 断言 `MAX(id)=13676`、B.0 断言 `MAX(id)=13682`，**只能在其前置阶段提交后运行**，否则必然误报（设计稿 §6.9 已明示，合并包不存在"先跑后段预检"的误判风险）。
- 全部语句为 DML（InnoDB），无 DDL，无隐式提交；连接须 utf8mb4。
- 执行前：`mysqldump` 备份 `system_menu` / `system_tenant_package` / `system_role_menu`。

### 6.3 幂等性与预期影响行数

| 阶段 | 语句 | 首执行预期影响行数 | 重复执行 |
| --- | --- | --- | --- |
| 一 | §1 菜单 INSERT ×3 | 3 | 0（NOT EXISTS 守卫） |
| 一 | §2 套餐 UPDATE ×3 | 0~3（已含则 0） | 0（JSON_CONTAINS 守卫） |
| 一 | §3 角色授权 INSERT（906×3） | 0~3 | 0（NOT EXISTS 守卫） |
| 二 | A.1 菜单 INSERT ×2 条语句（1+5 行） | 6 | 0 |
| 二 | A.2 套餐 UPDATE ×1 | 0~1 | 0 |
| 二 | A.3 角色授权 INSERT（904×5 + 906×6 + 908×6） | 0~17 | 0 |
| 三 | B.1 菜单 INSERT ×1 | 1 | 0 |
| 三 | B.2 套餐 UPDATE ×1 | 0~1 | 0 |
| 三 | B.3 角色授权 INSERT（904/906/908×1） | 0~3 | 0 |

**首执行合计最多 38 行**（3+3+3+6+1+17+1+1+3）；计算依据：菜单 10 行 + 套餐守卫各至多 1 行/ID + 角色授权按 §4.1 矩阵计数（906: 3+6+1=10；904: 5+1=6；908: 6+1=7，共 23 行）。守卫仅使异常环境影响 0 行，执行人仍须逐段人工核对。

### 6.4 执行后只读验收 SQL

已内置于设计稿：§4（13674~13676 层级/逐行/权限串/套餐包含/906 授权/908 越权回归 0 行）、A.4（13677~13682 数量与授权分布）、B.4（13683 逐行 + 904/906/908 各 1 行 + 套餐 `JSON_CONTAINS(...,'13683')=1`）。全部符合方可 COMMIT。

## 7. 缓存失效机制（源码证据）与方案（R4-D）

### 7.1 四层缓存事实

| 层 | 机制 | 源码证据 | SQL 直插后的行为 |
| --- | --- | --- | --- |
| JVM 本地缓存 | **不存在**——`spring.cache.type: REDIS`（application.yaml:27-30），权限缓存全部经 Spring Cache 抽象落 Redis | application.yaml | 重启 JVM 不影响 Redis 内容 |
| Redis 权限缓存 | 键：`permission_menu_ids:{perm}`（**全局**，application.yaml:337-346 ignore-caches 含此项）、`menu_role_ids:{tenantId}:{menuId}`（**租户后缀**，不在 ignore-caches，[TenantRedisCacheManager.java:43](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-framework/yudao-spring-boot-starter-biz-tenant/src/main/java/cn/iocoder/yudao/framework/tenant/core/redis/TenantRedisCacheManager.java#L43)）、`user_role_ids:{userId}`（全局）、`role:{id}`；**TTL=1h**（application.yaml:30 `time-to-live: 1h`） | [MenuServiceImpl.java:191](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/permission/MenuServiceImpl.java#L191)、[PermissionServiceImpl.java:198,242](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/permission/PermissionServiceImpl.java#L198) 均 `@Cacheable`；`@CacheEvict` 仅在应用层菜单 CRUD / `assignRoleMenu` / `processRoleDeleted` 触发 | **SQL 直插绕过全部 @CacheEvict**：①`permission_menu_ids:lab:instrument:reservation:*` 若在执行前已被 403 路径缓存过**空列表**（无 unless 条件，空结果同样缓存），执行后最长 1 小时内仍返回空 → 已授权用户短暂 403；②`menu_role_ids:162:13674~13683` 为新增键，执行前无人查询、不存在脏值；③`user_role_ids`/`role` 内容未变，无需处理。**≤1h TTL 到期全部自愈** |
| 用户登录菜单树 | 前端登录后 `GET /system/auth/get-permission-info`（[api/login/index.ts:46-51](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/api/login/index.ts#L46-L51)）；后端菜单实时查库（[MenuServiceImpl.java:126-128](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/permission/MenuServiceImpl.java#L126-L128) `getMenuList` 无缓存注解），按套餐过滤（`getMenuListByTenant` → `tenantService.handleTenantMenu`，[TenantServiceImpl.java:247-249](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/tenant/TenantServiceImpl.java#L247-L249) `getTenant` 直读库无缓存）；前端 pinia 内存态，刷新页面即重拉 | 同上 | **菜单可见性无服务端缓存阻碍**：SQL 生效后用户刷新/重新登录即可见新菜单 |
| 套餐 114 菜单同步 | UI 保存套餐 → `updateTenantRoleMenu`（[TenantServiceImpl.java:192-215](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/tenant/TenantServiceImpl.java#L192-L215)）：非租户管理员角色的菜单与套餐**求交集**后 `assignRoleMenu`（触发 @CacheEvict） | 同上 | SQL 直改 `menu_ids` 不触发同步，故设计稿直接插入 role_menu 行。**关键顺序保障**：设计稿在每阶段内先写菜单 → 再追加套餐 → 最后授权角色，保证 role_menu 所含菜单均在套餐内，日后任何人经 UI 保存套餐 114 时交集裁剪不会误删本次授权 |

### 7.2 对 37 号报告结论的修正

37 号 §4.1「菜单 SQL 执行后须重启后端重建权限缓存」**不成立，本报告正式修正**：重启后端 JVM 不会清除 Redis 中持久化的权限缓存（Redis 为独立进程，键有 1h TTL）。正确认知 = **1h TTL 自愈 + 应用层触发即时失效**，而非重启。

### 7.3 可执行缓存失效方案（本任务仅出方案，未执行任何 Redis 操作）

菜单 SQL 三阶段全部 COMMIT 后，按序执行：

1. **应用层即时失效（推荐，负责人 2 分钟内可完成，不触碰 Redis）**：
   a. 【系统管理 → 菜单管理】任选一条菜单做无影响编辑保存 → `updateMenu` → `@CacheEvict(value=PERMISSION_MENU_ID_LIST, allEntries=true)`（[MenuServiceImpl.java:69-70](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/permission/MenuServiceImpl.java#L69-L70)）；
   b. 【系统管理 → 角色管理】对 904、906、908 分别打开「菜单权限」直接保存 → `assignRoleMenu` → `@CacheEvict` MENU_ROLE_ID_LIST + PERMISSION_MENU_ID_LIST（allEntries，[PermissionServiceImpl.java:135-140](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/permission/PermissionServiceImpl.java#L135-L140)）。（保存内容不变，仅借用应用层缓存失效副作用；role_menu 数据经 UI 重写为相同值，无业务影响。）
2. **TTL 兜底**：不做任何操作时，全部脏缓存 ≤1 小时自然过期。
3. **用户侧**：相关用户刷新页面或重新登录即可看到「预约配置/预约管理/我的预约」（菜单树实时查库，无缓存阻碍）。
4. **运维备选（需另行授权，本报告不建议首选）**：redis-cli 删除 `permission_menu_ids:*`、`menu_role_ids:*` 键。本任务未连接正式 Redis。

## 8. 前端页面可达性核验（R4-E）

| 项 | 结论 | 证据 |
| --- | --- | --- |
| 动态路由解析 `lab/instrument/my-reservation/index` | ✅ | [routerHelper.ts:13,18-26,149-150](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/utils/routerHelper.ts#L13)：glob 覆盖 `../views/**/*.{vue,tsx}`，`includes` 匹配命中 `../views/lab/instrument/my-reservation/index.vue`（文件存在）；路由 name 取菜单 `component_name`，与组件 `defineOptions` 名一致，keep-alive 兼容 |
| 页面功能完整性 | ✅ 无需补开发 | 列表/详情/取消/调整/历史齐备；can* 服务端标记 + adjust 独立 v-hasPermi 双闸均在（§4.2-3） |
| 本次前端缺陷修复 | 无 | B1 为纯菜单数据缺失，代码无缺陷 |
| 类型检查 | ✅ 无本次引入问题 | `pnpm run ts:check`（vue-tsc 全量）：13 条 error，**全部位于无关模块**（lab/v2/plasmid×4、lab/v2/plasmid-audit×5、lab/announcement×1、fms/report×2、hrm/employee×1），属仓库预存错误；`src/views/lab/instrument/**` 与 `src/api/lab/instrument/**` **0 错误** |

## 9. 测试结果

| 项 | 结果 |
| --- | --- |
| 后端自动化（沿用 37 号基线，本轮源码零变更） | `mvn test -pl yudao-module-lab -o`：Tests run 195, Failures 0, Errors 0（含 IsolationGuard 7/7、T1/T2 回归） |
| 前端 vue-tsc | 见 §8（13 条预存错误，instrument 模块 0） |
| 正式库只读核验 | §5 全部通过；修正后的 RIGHT()/JSON_CONTAINS 写法已对 8.0.12 实测通过 |
| 设计稿 SQL 执行 | **未执行**（任务边界）；全部 DML 语句为设计态，执行次数 0 |

## 10. 未解决问题

| # | 问题 | 性质 | 处置 |
| --- | --- | --- | --- |
| N1 | 906 已授权菜单数：设计稿 2026-10-16 注释 115 vs 当日实测 113 | 事实差异（期间授权有变动） | 已在设计稿两处标注为历史值；授权数仅背景信息，幂等守卫不依赖；非阻断 |
| N2 | 37 号报告「重启即可重建缓存」结论不充分 | 结论修正 | 本报告 §7.2 正式修正（TTL 1h + 应用层触发）；非阻断 |
| N3 | 前端仓库 13 条预存 ts 错误（plasmid-v2/fms/hrm/announcement 模块） | 预存，与本次无关 | 记录在案，不在本任务范围；非阻断 |

无其他未解决问题；无新增阻断缺陷。

## 11. 部署授权时负责人需批准的具体动作

**事项 A：菜单部署授权（本报告申请批准的对象）**

1. 执行前：`mysqldump` 备份 `system_menu`、`system_tenant_package`、`system_role_menu` 三表；
2. 按 §6.2 阶段一 → 二 → 三顺序执行设计稿（每阶段：预检核对 → 单事务 DML → 验收 SELECT 核对 → COMMIT）；
3. 按 §7.3-1 做应用层缓存失效（菜单保存 ×1 + 904/906/908 角色菜单保存 ×3）；
4. 通知相关用户刷新/重新登录，按 §12 清单验收。

**事项 B：C7 开启授权（独立事项，不在本次申请范围，可另行决定）**

- 前置：事项 A 完成且 §12 验收通过。
- 动作（仅文档方案，本次未改任何配置）：在 `application-local.yaml` 增加 `lab.instrument.reservation.create-enabled: true`（当前生效值 false，[InstrumentReservationServiceImpl.java:57-60](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentReservationServiceImpl.java#L57-L60) `@Value` 默认 false；仅隔离 profile `application-instrument-03-test.yaml` 为 true）→ 重启后端生效 → 904 冒烟创建预约 → 观察冲突拒绝与幂等行为。
- 回退：配置改回 false 并重启；已创建预约数据保留，无结构依赖。
- 注意：事项 A 部署后、事项 B 开启前，`reservation:create` 接口仍被 C7 拦截（业务异常 INSTRUMENT_RESERVATION_CREATE_DISABLED），**菜单部署本身不会产生任何预约数据写入**。

**故障停止条件（任一命中即停止并报告）**：预检任一不符；任一 SQL 执行报错；验收行数/内容不符；发现菜单 ID 或权限串冲突。**回滚首选备份恢复**（三表 mysqldump）；仅在备份不可用时由负责人决定按口径手工删除：`system_role_menu WHERE menu_id BETWEEN 13674 AND 13683 AND tenant_id=162`、`system_menu WHERE id BETWEEN 13674 AND 13683`、套餐 114 的 menu_ids 回退为备份值。

## 12. 手工验收清单（菜单部署后执行；37 号 §8 全 15 项沿用，此处为增量与状态更新）

前置说明：事项 A 完成后以下全部可测；**创建类操作为事项 B（C7）专属，A 阶段预期业务拒绝**。

### 普通用户（904）

| # | 步骤 | 预期 | 实际 | 证据 |
| --- | --- | --- | --- | --- |
| U1 | 重新登录，展开「仪器管理」 | 可见「我的预约」（13683）与「预约管理」（13677），**不可见**「预约配置」 | | |
| U2 | 进入「我的预约」 | 页面正常渲染（不回退首页），列表仅本人预约 | | |
| U3 | 本人 PENDING 预约行 | 显示「取消」「调整」「历史」；无「完成/作废」 | | |
| U4 | 进入「预约管理」 | 列表仅本人数据（页头有数据范围说明），无创建按钮，无完成/作废按钮 | | |
| U5 | 取消本人未开始预约 | 成功，历史记录新增 CANCEL | | |
| U6 | 调整本人 PENDING 预约（改时间） | 成功，历史记录新增 ADJUST | | |
| U7 | （C7 开启后）设备详情创建预约 | 成功；（C7 开启前）报「预约创建未开放」业务拒绝 | | |
| U8 | 直接访问他人预约详情 ID | 080 不存在口径拒绝，不泄露存在性 | | |

### 设备负责人（908）

| # | 步骤 | 预期 | 实际 | 证据 |
| --- | --- | --- | --- | --- |
| M1 | 重新登录 | 可见 13677 与 13683，不可见 13674 | | |
| M2 | 13677 列表 | 本人 ∪ 授权设备范围预约 | | |
| M3 | 范围内 PENDING 预约执行完成（填实际使用时间） | 成功，历史记录 FINISH | | |
| M4 | 范围外设备预约（如有）操作 | 无操作按钮；直接调接口 403/业务拒绝 | | |
| M5 | 调整范围内预约（不填原因） | 拒绝（管理侧调整必填原因） | | |

### 实验室管理员（906）

| # | 步骤 | 预期 | 实际 | 证据 |
| --- | --- | --- | --- | --- |
| A1 | 重新登录 | 可见 13674/13677/13683 全部三页 | | |
| A2 | 预约配置页维护规则与开放时段 | 保存成功 | | |
| A3 | 预约管理页全量数据、完成/作废/取消/调整 | 成功，历史留痕完整 | | |
| A4 | 905 库管员账号 | 三个页面菜单均不可见，接口 403 | | |

## 13. 数据库与 Redis 零写入声明

本任务全部数据库操作为 SELECT（含 §5 各项与 JSON_CONTAINS 实证）；未执行任何 INSERT/UPDATE/DELETE/DDL；未执行菜单 SQL；未连接正式 Redis 进行任何读写；未创建真实预约；未开启 C7；未重启/停止负责人运行中的后端（48080）；未使用 Docker。git status 复核：本任务仅修改设计稿 1 个文件（§2）。

---

**最终判定：PASS / READY-FOR-MENU-AUTHORIZATION**

完成标准逐项核对：① B1 菜单设计完整（§1）✓；② 设计稿与 8.0.12 正式库结构/语法实测匹配（§5、§6.1）✓；③ 904/906/908 权限设计明确无越权（§4）✓；④ 前端动态路由组件匹配（§8）✓；⑤ 执行顺序/预检/幂等/回滚完整（§6、§11）✓；⑥ 缓存失效方案有源码证据（§7）✓；⑦ C7 保持 false（§11-B，未改配置）✓；⑧ 正式库与正式 Redis 零写入（§13）✓；⑨ 未发现新的阻断缺陷（§10）✓。

本任务到此结束，等待负责人对事项 A 的书面授权；未获授权前不执行任何部署操作。
