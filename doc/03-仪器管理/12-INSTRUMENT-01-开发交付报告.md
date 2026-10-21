# 12 - INSTRUMENT-01 开发交付报告

- 任务：TASK INSTRUMENT-01 仪器基础档案与负责人管理开发
- 项目：本草基因组学团队实验室管理平台
- 日期：2026-10-14
- 执行方：Trae（青禾一）
- 关联文档：`11-INSTRUMENT-01-设计修订记录.md`

---

## 1. 最终结论：CONDITIONAL PASS（有条件通过）

| 维度 | 结论 | 说明 |
|---|---|---|
| 设计冲突修正（C1~C5） | PASS | 10 篇文档 + 合并文档已修订，修订记录见 11 号文档 |
| 数据库 SQL（只生成不执行） | PASS（待执行） | 3 个 SQL 文件，幂等、含执行前检查与执行后验收，**本任务未执行** |
| 后端开发 | PASS（静态） | 57 个新增 Java 文件，`mvn compile` EXIT=0；未做真实库联调 |
| 前端开发 | PASS（静态） | 15 个新增 TS/Vue 文件，新增代码 TS 检查 0 错误 |
| 真实数据库 / 接口联调 | **未执行（HOLD 项）** | 无数据库执行授权，需负责人执行 SQL 后联调验收 |

CONDITIONAL 的唯一原因：SQL 未执行、未写真实库、未做真实接口联调（任务明确禁止执行 SQL）。所有不依赖写库的工作均已完成并通过静态验证。

### 1.1 授权边界遵守声明（逐条）

- **是否修改了原有业务代码**：否。后端仅在 `ErrorCodeConstants.java` **追加**仪器错误码段（1_002_004_001~044），未改动任何既有方法；前端仅在 `src/utils/dict.ts` 枚举末尾**追加** 2 个字典常量，未改动既有项。质粒管理、注册审批、公告等既有模块代码零改动。
- **是否执行 SQL**：**否**。3 个 SQL 文件均未连接、未执行（含文件内的 SELECT 也未执行）。
- **是否写入数据库**：**否**。
- **是否修改菜单和角色授权**：**否**。菜单/套餐/角色授权仅以 SQL 文件形式生成（`20261014_instrument_01_menu.sql`），真实库未变更。
- **是否修改现有用户角色**：否。
- **是否完成真实接口联调**：否。后端编译通过、前端类型检查通过；接口联调待 SQL 执行后验收（见第 14 节）。
- **是否引入新依赖**：否。前后端均使用既有依赖（lab 模块 pom 已含 system/tenant/security/mybatis/redis 等）。
- **是否进入 INSTRUMENT-02**：否。预约提交、资质申请入口均已置灰且不发请求。

---

## 2. 修正的设计冲突（第一阶段，摘要）

完整修订记录与逐文档落点见 [11-INSTRUMENT-01-设计修订记录.md](./11-INSTRUMENT-01-设计修订记录.md)。

- **C1 取消自动爽约/自动扣分**：删除"预约开始未点击开始→自动 NO_SHOW→自动扣信用分"全链路；第一期无签到/签退/硬件检测；预约时间进入过去不等于实际使用；仅保留授权负责人凭证据**手动登记违规**。字典 `lab_credit_reason` 不含 NO_SHOW 项（4 项，可回归验收）。
- **C2 取消取消时间限制**：普通用户在预约开始时间之前均可取消，删除"提前 30 分钟"等未经确认限制；开始后仅授权负责人/管理员处理。
- **C3 历史与时间占用分离**：取消/作废释放原时段；FINISHED 保留完整历史，其历史区间不得被重叠正常预约复用；不得删历史记录释放时间；可预约性 = 时间范围 + 有效占用状态 + 设备状态联合判断。
- **C4 设备级资质**：资质按设备授权，通过平台内一台设备审核不赋予平台内其他设备资格；平台级资质标记为待确认扩展，不启用。
- **C5 一致性检查**：10 篇文档（00~09）及 `合并.md` 的状态机、字段、预约规则、资质、信用、验收矩阵已同步；未裁决规则以 Q1~Q5 / G26 等标记**待确认**，未自行定案。

---

## 3. 新增和修改的全部代码文件

### 3.1 后端（`E:\lixin\dev\ruoyi-vue-pro\yudao-module-lab`，新增 57 个，修改 1 个）

修改（仅追加，不改既有逻辑）：
- `src/main/java/cn/iocoder/yudao/module/lab/enums/ErrorCodeConstants.java`（追加 1_002_004_001~044 共 33 个错误码）

新增：

枚举（9）：`enums/instrument/` 下 `DeviceStatusEnum`、`DeviceCategoryEnum`、`InstrumentSimpleStatusEnum`、`InstrumentRepairScopeEnum`、`ManagerScopeEnum`、`ManagerTypeEnum`、`ManagerStatusEnum`、`NoticeTargetTypeEnum`、`NoticeStatusEnum`

DO（5）：`dal/dataobject/instrument/` 下 `InstrumentPlatformDO`、`InstrumentDeviceDO`、`InstrumentRoomDO`、`InstrumentManagerDO`、`InstrumentNoticeDO`（均 extends TenantBaseDO）

Mapper（5）：`dal/mysql/instrument/` 下 `InstrumentPlatformMapper`、`InstrumentDeviceMapper`、`InstrumentRoomMapper`、`InstrumentManagerMapper`、`InstrumentNoticeMapper`

Redis 锁（1）：`dal/redis/InstrumentLockRedisDAO.java`

Service（11）：`service/instrument/` 下 5 个接口 + 5 个实现（Platform/Device/Room/Manager/Notice）+ `InstrumentScopeSupport.java`（数据范围组件）

Controller（5）：`controller/admin/instrument/` 下 `InstrumentPlatformController`、`InstrumentDeviceController`、`InstrumentRoomController`、`InstrumentManagerController`、`InstrumentNoticeController`

VO（21）：`controller/admin/instrument/vo/` 下
- platform（4）：Save/Page/Resp/Status
- device（5）：Save/Page/Resp/Status/HallOptions
- room（3）：Save/Page/Resp
- manager（6）：Assign/Release/Page/Resp/Brief/UserCandidate
- notice（3）：Save/Page/Resp

### 3.2 前端（`E:\lixin\dev\yudao-ui-admin-vue3`，新增 15 个，修改 1 个）

修改（仅追加 2 个枚举常量）：
- `src/utils/dict.ts`：`LAB_INSTRUMENT_CATEGORY`、`LAB_INSTRUMENT_REPAIR_SCOPE`

新增 API（5）：`src/api/lab/instrument/` 下 `platform/index.ts`、`device/index.ts`（含 DEVICE_STATUS 代码枚举）、`room/index.ts`、`manager/index.ts`、`notice/index.ts`

新增页面/组件（10）：`src/views/lab/instrument/` 下
- `hall/index.vue`（仪器大厅，组件名 LabInstrumentHall）
- `device-detail/index.vue`（仪器详情，LabInstrumentDeviceDetail）
- `platform/index.vue` + `platform/PlatformForm.vue`（LabInstrumentPlatform）
- `device/index.vue` + `device/DeviceForm.vue`（LabInstrumentDevice）
- `room/index.vue` + `room/RoomForm.vue`（LabInstrumentRoom）
- `manager/index.vue`（LabInstrumentManager）
- `notice/index.vue`（LabInstrumentNotice）

### 3.3 设计文档（第一阶段修订）

修订：`00`~`09` 共 10 篇 + `合并.md`；新增：`11-INSTRUMENT-01-设计修订记录.md`、本报告 `12`。

---

## 4. 新增 SQL 文件及用途

目录：`E:\lixin\dev\ruoyi-vue-pro\sql\lab\`（**均未执行**）

| 文件 | 用途 | 幂等方式 |
|---|---|---|
| `20261014_instrument_01_schema.sql` | 5 张表 DDL + 执行前 information_schema 检查 + 执行后验收 SELECT | CREATE TABLE IF NOT EXISTS |
| `20261014_instrument_01_dict.sql` | 5 个字典类型、18 个字典项 | INSERT … WHERE NOT EXISTS，不指定 id |
| `20261014_instrument_01_menu.sql` | 26 个菜单/按钮（固定 ID 13600~13653）、租户套餐 114 追加、角色 906/904 授权 | NOT EXISTS 守卫 + 占用即停 |

字典：`lab_instrument_category`（8 项）、`lab_instrument_repair_scope`（2 项）、`lab_credit_reason`（4 项，**无 NO_SHOW**，C1 回归）、`lab_suspend_scope`（2 项）、`lab_maintenance_source`（2 项）。设备状态机取值（NORMAL/MAINTENANCE/FAULT/DISABLED/SCRAPPED）按 08 §2.3 双轨范式不建字典行，由后端枚举 + 前端常量双轨维护。

实现增补（已回写设计 02 §3.2 与 11 号文档）：
1. `lab_instrument_device.image_url varchar(500)`：框架 `/infra/file/upload` 仅返回 URL 不返回 file id，第一期图片展示依据；`image_file_id/name` 保留可空。
2. `lab_instrument_manager.release_reason varchar(300)`：解除负责人必填原因（07 接口要求）。

---

## 5. 数据库表结构清单（5 张，TenantBaseDO 六公共字段齐全）

| 表 | 要点 | 约束/索引 |
|---|---|---|
| `lab_instrument_platform` | code/name/description/sort/status(ENABLE/DISABLE)/remark | uk(tenant_id,code) |
| `lab_instrument_device` | device_no/name/model/spec/category/repair_scope/platform_id/room_id/asset_no/manufacturer/purchase_date/status(5 态)/bookable/image_file_id/image_file_name/**image_url**/sort/remark | uk(tenant_id,device_no)；idx platform_id/room_id/status/category |
| `lab_instrument_room` | code/name 分别存储、building/floor/location_desc、repair_manager_id/name 快照（一期不回填）、status | uk(tenant_id,code)；idx repair_manager_id |
| `lab_instrument_manager` | scope/target_id/manager_type/manager_user_id/manager_name 快照/status(ACTIVE/RELEASED)/effective_from/effective_to/assign_reason/**release_reason**/remark；只增不改，历史完整 | idx(scope,target_id,status)、idx(manager_user_id)；**无 DB 唯一键**，单 ACTIVE 由 Redisson 锁+事务保证 |
| `lab_instrument_notice` | target_type/target_id/version/title/content(text)/status(DRAFT/PUBLISHED/ARCHIVED)/require_acknowledge/publish_time/publisher_id/name | uk(tenant_id,target_type,target_id,version)；idx(target_type,target_id,status) |

公共字段：`creator/create_time/updater/update_time/deleted(bit)/tenant_id`，InnoDB / utf8mb4_unicode_ci，无物理外键（沿用 lab 模块规范，逻辑关联 + Service 校验）。

关键业务规则落库：
- 负责人：DEVICE/PLATFORM 同 target+manager_type 同时仅 1 个 ACTIVE（锁内旧关系置 RELEASED+effective_to，插新行，事务原子）；ROOM_REPAIR 允许多 ACTIVE（G26 待确认，默认方案 A）；同用户重复 ACTIVE 拒绝；解除必填原因。
- 须知：草稿版本号 max+1（锁内）；仅 DRAFT 可编辑/发布；发布时同 target 旧 PUBLISHED 置 ARCHIVED；无删除接口，历史版本永久保留。
- 设备删除：仅 DISABLED/SCRAPPED 可删；有 ACTIVE 负责人或有已发布/归档须知历史时拒绝；逻辑删除。预约/维修表后续任务建立后需追加引用校验（已在代码注释与报告中标注）。

---

## 6. 后端接口清单（基础路径 `/lab/instrument`）

### 6.1 平台 `/platform`
| 方法 | 路径 | 权限 |
|---|---|---|
| POST | /create | platform:create |
| PUT | /update | platform:update |
| PUT | /update-status | platform:update |
| DELETE | /delete?id= | platform:delete |
| GET | /get?id= | platform:query |
| GET | /page | platform:query |
| GET | /list?status= | platform:query |
| GET | /device-list?platformId=（平台关联设备） | platform:query |

### 6.2 设备 `/device`
| 方法 | 路径 | 权限 |
|---|---|---|
| POST | /create | device:create |
| PUT | /update（不含状态变更） | device:update |
| PUT | /update-status（状态机） | device:manage |
| DELETE | /delete?id= | device:delete |
| GET | /get?id=（详情：聚合平台/房间名、当前负责人含手机号、当前须知） | device:query |
| GET | /page（管理页与仪器大厅共用） | device:query |
| GET | /hall-options（仅有设备引用的平台/房间） | device:query |

### 6.3 房间 `/room`
| 方法 | 路径 | 权限 |
|---|---|---|
| POST | /create | room:create |
| PUT | /update | room:update |
| DELETE | /delete?id=（有设备引用拒绝） | room:delete |
| GET | /get?id=（含当前维修负责人） | room:query |
| GET | /page | room:query |
| GET | /list?status= | room:query |
| GET | /repair-manager?roomId= | room:query |

### 6.4 负责人 `/manager`
| 方法 | 路径 | 权限 |
|---|---|---|
| POST | /assign | manager:manage |
| POST | /release（body：id+reason，reason 必填） | manager:manage |
| GET | /page（含历史） | manager:query |
| GET | /list-by-target?scope&targetId（当前生效） | manager:query |
| GET | /history?scope&targetId（变更历史） | manager:query |
| GET | /candidates?keyword=（当前租户启用用户） | manager:query |

### 6.5 使用须知 `/notice`
| 方法 | 路径 | 权限 |
|---|---|---|
| POST | /create（草稿，自动版本号） | notice:create |
| PUT | /update（仅 DRAFT） | notice:update |
| PUT | /publish?id=（旧版自动归档） | notice:update |
| GET | /get?id= | notice:query |
| GET | /page（历史版本） | notice:query |
| GET | /get-by-target?targetType&targetId（当前生效） | notice:query |
| GET | /list-by-target（全部版本） | notice:query |

---

## 7. 前端页面清单

| 菜单ID | 页面 | 路由组件 | 组件名 | 可见性 |
|---|---|---|---|---|
| 13601 | 仪器大厅（平台 tabs/实验室筛选/分类/状态/关键词、图片卡片、负责人、须知入口） | lab/instrument/hall/index | LabInstrumentHall | 显示 |
| 13602 | 仪器详情（图片、基础信息、负责人表、当前须知；query.id） | lab/instrument/device-detail/index | LabInstrumentDeviceDetail | 隐藏 |
| 13610 | 仪器平台管理 | lab/instrument/platform/index | LabInstrumentPlatform | 显示 |
| 13620 | 仪器设备管理（图片上传、归属选择、状态管理、负责人抽屉/历史） | lab/instrument/device/index | LabInstrumentDevice | 显示 |
| 13630 | 实验室/房间管理（含维修负责人展示） | lab/instrument/room/index | LabInstrumentRoom | 显示 |
| 13640 | 仪器负责人管理（分配/调整/解除/历史/候选人搜索） | lab/instrument/manager/index | LabInstrumentManager | 显示 |
| 13650 | 使用须知管理（设备选择、版本列表、草稿编辑、发布、查看） | lab/instrument/notice/index | LabInstrumentNotice | 显示 |

预约/资质入口处理：大厅卡片与详情页的"申请资质""立即预约"按钮均为 **disabled + tooltip 提示尚未开放（INSTRUMENT-03/02）**，点击不产生任何业务请求。

---

## 8. 权限编码清单（18 个，与菜单 SQL、@PreAuthorize 三方一致）

- `lab:instrument:platform:query/create/update/delete`（4）
- `lab:instrument:device:query/create/update/delete/manage`（5）
- `lab:instrument:room:query/create/update/delete`（4）
- `lab:instrument:manager:query/manage`（2）
- `lab:instrument:notice:query/create/update`（3）

授权方案（菜单 SQL 内容，**尚未写入真实库**）：
- 906 lab_admin（本草基因管理员）：全部 26 个菜单/按钮（含父目录 13478、13600）。
- 904 普通用户：仅 13478、13600、13601 大厅、13602 详情、13621 device:query —— 只能看大厅/详情，无法调用任何写接口。
- 903 tenant_admin / 905 lab_keeper / 907 registration_approver：本批次不授权仪器菜单。
- 仪器负责人是 `lab_instrument_manager` **业务关系而非系统角色**（F19）；配置类接口功能权限由权限串控制，数据范围由 `InstrumentScopeSupport` 显式校验（为 INSTRUMENT-02 起负责人授权业务预置），不仅靠前端按钮隐藏。
- 租户隔离：全部 DO 继承 TenantBaseDO，MyBatis 租户插件自动追加 tenant_id；AdminUserApi 取用户同受租户过滤，负责人分配时校验用户存在 + 启用 + 同租户。

---

## 9. 后端编译结果

- 命令：`mvn.cmd -pl yudao-module-lab -am compile -DskipTests -B -q`（工作目录 `E:\lixin\dev\ruoyi-vue-pro`）
- 结果：**EXIT=0（BUILD SUCCESS）**；二次单模块编译 EXIT=0，`controller/admin/instrument` 下产出 28 个 .class。
- 环境如实说明：本机默认 JDK 为 Temurin JDK 21（未发现独立 JDK8 安装），项目 `java.version=1.8`；JDK21 javac 以 source/target 8 编译本模块通过。建议负责人在标准 JDK8 构建环境再跑一次全量打包以最终确认（静态编译已无 JDK 版本相关错误）。
- 静态检查：Controller 路径/权限串与菜单 SQL 逐一核对一致；DO 字段 ↔ SQL 列驼峰转换逐一对应；@PreAuthorize 全覆盖写接口；Service 内完成业务范围/引用/状态机校验；TenantBaseDO 全覆盖；负责人单 ACTIVE 与须知版本均为"Redisson 锁 + TransactionTemplate 事务"。

---

## 10. 前端检查结果

- 命令：`npm.cmd run ts:check`（vue-tsc --noEmit，Node v24.21.0 / pnpm 环境）
- 结果：**仪器模块新增代码 0 错误**（首轮 7 个 instrument 错误已全部修复：el-option 值 undefined 类型 5 处、el-tag type 字符串字面量 2 处）。
- 仓库存量历史错误 13 个（本次未触碰、不归因本任务）：
  - `src/api/lab/announcement/index.ts` 1（未使用导入）
  - `src/views/lab/v2/plasmid-audit/index.vue` 5、`src/views/lab/v2/plasmid/index.vue` 4
  - `src/views/fms/report/components/FmsReportFormulaForm.vue` 2
  - `src/views/hrm/employee/index.vue` 1
- 组件/路由：7 个页面组件路径与菜单 SQL component 字段完全一致；UploadImg 走框架 `/infra/file/upload`，未自定义上传接口；沿用 ContentWrap/Pagination/Dialog/dict-tag/v-hasPermi/useMessage，无新增依赖。

---

## 11. 未解决问题 / 待确认

1. **SQL 未执行、未真实联调（CONDITIONAL 主因）**：需负责人授权后按第 12~14 节执行验收。
2. **待负责人裁决项**（不得自行定案，详见 11 号文档）：Q1~Q5、G26（房间多维修负责人策略，当前默认方案 A 全保留）、U1~U6；平台级资质（C4 扩展）未启用。
3. **JDK8 全量打包**：建议在标准 JDK8 环境复跑 package。
4. **设备删除引用校验**：预约/维修/资质等后续表尚未建立，本批次仅校验 ACTIVE 负责人与已发布须知；后续任务建表后需追加引用检查（代码注释已标注）。
5. `repair_manager_id/name` 快照字段第一期不回填，权威取 manager 表 ROOM_REPAIR；是否回填待后续维护策略确认。
6. 设备图片 `image_file_id` 在 infra 上传不回 id 的前提下暂为空，仅存 image_url；infra 接口升级后可补关联。
7. 历史 TS 错误 13 个为既有问题，未在本任务授权范围内修改。

---

## 12. 需要负责人执行的 SQL（严格按顺序）

在租户 162 对应库，由具备权限的 DBA/负责人执行（Trae 不执行）：

1. `sql/lab/20261014_instrument_01_schema.sql`
2. `sql/lab/20261014_instrument_01_dict.sql`
3. `sql/lab/20261014_instrument_01_menu.sql`

建议逐文件执行、逐文件核对验收段后再执行下一个；菜单 SQL 内含套餐 114 与角色 906/904 授权，请勿拆分到无角色数据的环境执行。

## 13. SQL 执行前检查条件

- schema 文件第 0 节：5 张表 information_schema 计数必须全为 0；若任一为 1，**先核实归属、禁止覆盖**（第二阶段已静态核验当前无 `lab_instrument_*` 表，以执行时实时结果为准）。
- 数据库字符集 utf8mb4；InnoDB 为 DEFAULT/YES。
- 菜单 SQL 守卫条件：父菜单 13478 存在且 status=0 未删除；预留 ID 段 **13600~13653 全部未占用**（被占用则脚本自动不插入该 ID，需停止并人工核对，不得改号硬插）。
- 角色 906/904（tenant_id=162，status=0）、租户套餐 114 存在。
- 确认无 `lab:instrument:%` 权限串残留（文件 0.3 节预期 0 行）。
- 执行前备份相关库（至少 system_menu / system_role_menu / system_tenant_package / system_dict_*）。

## 14. SQL 执行后验收步骤

1. schema 第 2 节：5 表存在、引擎/排序集正确；列与 DO 逐列一致；3 个 uk_* 与 idx_* 索引齐全；空表行数为 0。
2. dict：5 类型 18 项齐全；`lab_credit_reason` 中**不存在** NO_SHOW（C1 回归）。
3. 菜单：验收 SELECT 返回 26 行；13478→13600→13601/13602/13610/13620/13630/13640/13650 层级正确；906 可见 7 页面、904 仅大厅/详情；套餐 114 menu_ids 含全部新菜单。
4. 接口联调（建议最小用例）：lab_admin 登录 → 新增平台 → 新增房间 → 新增设备（含图片上传）→ 分配设备负责人（再分配另一人，验证旧关系自动 RELEASED 且历史保留）→ 新建须知草稿→编辑→发布→再发新版（旧版归档）→ 设备状态 NORMAL→DISABLED→SCRAPPED（验证报废终态/仅停用可报废）→ 普通用户登录仅能打开大厅/详情、对写接口返回 403。
5. 越权回归：普通用户直接调用 `/lab/instrument/device/create`、`/manager/assign` 等必须被 @PreAuthorize 拦截。
6. 多租户回归：跨租户查询不应见到其他租户平台/设备/负责人关系。

## 15. 下一步开发建议

1. 负责人执行 3 个 SQL 并完成第 14 节联调后，INSTRUMENT-01 可转正式 PASS。
2. 裁决 Q1~Q5/G26 后再进入 INSTRUMENT-02（预约规则与冲突检测）；C3 的"有效占用状态集合 + 设备状态"联合判定可直接复用本批次状态机与 DeviceStatusEnum。
3. INSTRUMENT-02 落地时：为设备删除补预约/维修引用校验；启用 InstrumentScopeSupport 的负责人数据范围校验；将须知 require_acknowledge 接入预约确认环节。
4. INSTRUMENT-03 资质按 C4 设备级模型实施时，再开放大厅/详情的"申请资质"入口（当前已置灰预埋）。
5. 建议安排独立窗口清理 13 个历史 TS 错误（不属本任务范围）。
