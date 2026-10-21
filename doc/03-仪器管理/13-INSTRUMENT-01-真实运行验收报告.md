# INSTRUMENT-01 真实运行验收报告

> 任务：TASK INSTRUMENT-01-RUNTIME-VERIFY-01（仪器管理基础档案真实运行验收）
> 执行日期：2026-10-15
> 执行人：Trae（青禾一协助）
> 数据库：`labplatform`（MySQL 8.0.12，utf8mb4）
> 前置：三个初始化 SQL 已由负责人在 Navicat 执行；后端已启动、前端可见仪器管理菜单
> 边界：本任务未执行任何 DDL、未重跑初始化 SQL、未删除/重置业务数据、未改动质粒/注册审批等模块

---

## 一、环境与数据库核验结果

### 1.1 运行环境

| 项 | 实测值 | 证据 |
| --- | --- | --- |
| 后端端口 | 48080 | `Get-NetTCPConnection` LISTENING，进程 java PID=35012 |
| 后端启动方式 | IDEA（temurin-21.0.6） | 进程命令行 `-classpath ...\target\classes` |
| Spring profile | `local` | target/classes/application.yaml `active: local` |
| 实际数据库 | `labplatform` | application-local.yaml url=`jdbc:mysql://127.0.0.1:3306/labplatform`（非 dev 的 ruoyi-vue-pro） |
| 前端 | node（80 端口） | 进程 PID=19952 |

### 1.2 五张仪器业务表

只读查询 `information_schema.tables`（schema=labplatform）：

| 表 | 存在 | 业务数据 |
| --- | --- | --- |
| lab_instrument_platform | ✓ | 测试后 2 行 |
| lab_instrument_device | ✓ | 测试后 2 行 |
| lab_instrument_room | ✓ | 测试后 1 行 |
| lab_instrument_manager | ✓ | 测试后 3 行 |
| lab_instrument_notice | ✓ | 测试后 2 行 |

（测试前均为 0 行，干净起点）

### 1.3 字典

| 字典类型 | 状态 | 有效项数 | 缺失/重复 |
| --- | --- | --- | --- |
| lab_instrument_category | 0 启用 | 8 | 无 |
| lab_instrument_repair_scope | 0 启用 | 2 | 无 |
| lab_instrument_credit_reason | 0 启用 | 4（无 NO_SHOW，符合 C1） | 无 |
| lab_instrument_suspend_scope | 0 启用 | 2 | 无 |
| lab_instrument_maintenance_source | 0 启用 | 2 | 无 |

### 1.4 菜单 13600–13653

- 共 26 条：1 目录 + 7 页面 + 18 按钮；全部 status=0 启用、deleted=0
- 父子关系正确：13600 挂 13478（实验室管理）；7 页面挂 13600；18 按钮各挂所属页面
- component 路径：hall/device-detail/platform/device/room/manager/notice 七页，前端文件全部存在
- 权限串去重后 **18 个**（lab:instrument:platform/device/room/manager/notice 各 query/create/update/delete/manage 等）

### 1.5 套餐与角色授权

| 项 | 实测 | 结论 |
| --- | --- | --- |
| 套餐 114 | menu_ids 含 13600~13653（len=1378） | ✓ 含仪器菜单 |
| 角色 906（本草基因管理员） | 持 13478~13653 段菜单共 86 个（含仪器 26） | ✓ 全部管理权限 |
| 角色 904（普通用户） | 仪器仅 13600/13601/13602/13621/13478 | ✓ 大厅+详情+device:query，符合设计 |

### 1.6 接口权限标识/前端路由/菜单组件/API 匹配

- 后端 Controller @PreAuthorize 权限串与菜单 18 个权限串逐一对应（沿用 PRECHECK 三方一致结论）
- 前端 7 个 component 文件全部存在，API 封装路径（`/lab/instrument/device/page`、`/hall-options` 等）与后端 @RequestMapping 一致

**阶段1 结论：全部 PASS，无异常。**

---

## 二、页面/接口/权限/租户隔离测试清单

测试账号：906 管理员 `bencao`（user_id=278）；904 普通用户 `189140002`（user_id=281）。

### 2.1 平台管理

| 用例 | 接口 | 结果 | 证据 |
| --- | --- | --- | --- |
| 分页查询 | GET /lab/instrument/platform/page | PASS | code=0，total/list 正确 |
| 新增 | POST /platform/create | PASS | id=1、id=2 创建成功 |
| 编辑 | PUT /platform/update | PASS | 中文名称修正成功 |
| 启停 | PUT /platform/update-status | PASS | ENABLE↔DISABLE 切换成功 |
| 重复编码 | POST 重复 code=PF-TEST01 | PASS | code=1002004002"平台编码已存在" |

### 2.2 房间管理

| 用例 | 接口 | 结果 | 证据 |
| --- | --- | --- | --- |
| 分页查询 | GET /room/page | PASS | code=0 |
| 新增 | POST /room/create | PASS | id=1 创建成功 |
| 编辑 | PUT /room/update | PASS | 中文名修正成功 |

### 2.3 设备档案

| 用例 | 接口 | 结果 | 证据 |
| --- | --- | --- | --- |
| 分页查询 | GET /device/page | PASS | 返回含 platformName/roomName/managers/currentNotice |
| 新增 | POST /device/create | PASS | id=1、id=2 创建成功（关联平台/房间） |
| 详情 | GET /device/get?id=1 | PASS | 含内嵌 currentNotice |
| 编辑 | PUT /device/update | PASS | 成功 |
| 重复编号 | POST 重复 device_no | PASS | code=1002004011"设备编号已存在" |
| 缺类别 | POST 无 category | PASS | code=400"设备类别不能为空" |
| 非法类别 | POST category=NOT_EXIST | PASS | code=1002004012"设备类别不合法" |
| 非法平台 | POST platformId=9999 | PASS | code=1002004001"仪器平台不存在" |
| 大厅筛选项 | GET /device/hall-options | PASS | 仅返回有设备的平台/房间（设计如此，空数据时为空属预期） |

**设备状态机**（DISABLED→SCRAPPED 已实测，设备1 当前 SCRAPPED）：

| 转换 | 结果 | 证据 |
| --- | --- | --- |
| NORMAL→MAINTENANCE | PASS | code=0 |
| MAINTENANCE→SCRAPPED | PASS（拒绝） | code=1002004016"仅停用设备可报废" |
| MAINTENANCE→NORMAL | PASS | code=0 |
| NORMAL→DISABLED | PASS | code=0 |
| DISABLED→SCRAPPED | PASS | code=0 |
| SCRAPPED→NORMAL | PASS（拒绝） | code=1002004016"报废为终态" |

### 2.4 负责人管理（G26 专项，方案 A 多负责人）

| 用例 | 结果 | 证据 |
| --- | --- | --- |
| 房间1 分配维修负责人 265 | PASS | id=1 ACTIVE |
| 房间1 再分配第二名 281 | PASS | id=2 ACTIVE，**未踢掉第一人** |
| 重复分配 265 | PASS（拒绝） | code=1002004035"已是此目标同类型生效负责人" |
| list-by-target 房间1 | PASS | 返回全部 2 名 ACTIVE（非仅第一条） |
| 解除第一人 265 | PASS | id=1→RELEASED，保留 release_reason；id=2 仍 ACTIVE 不受影响 |
| history 房间1 | PASS | 历史完整（含 RELEASED 行） |
| 恢复 265 再分配 | PASS | id=3 ACTIVE，现 265/281 双 ACTIVE |

### 2.5 使用须知

| 用例 | 接口 | 结果 | 证据 |
| --- | --- | --- | --- |
| 创建草稿 V1 | POST /notice/create | PASS | id=1 DRAFT version=1 |
| 发布 V1 | PUT /notice/publish?id=1 | PASS | 发布成功 |
| 创建 V2 草稿 | POST /notice/create | PASS | id=2 version=2 |
| 发布 V2 | PUT /notice/publish?id=2 | PASS | **V1 自动归档**，V2 PUBLISHED |
| 当前版本查询 | get-by-target device1 | PASS | 返回 V2（version=2 PUBLISHED） |
| 全部版本 | list-by-target | PASS | V1 ARCHIVED + V2 PUBLISHED，历史保留 |

### 2.6 仪器大厅与详情（904 视角）

| 用例 | 结果 | 证据 |
| --- | --- | --- |
| 大厅列表（device/page） | PASS | code=0 |
| 设备详情（device/get） | PASS | 含内嵌 currentNotice（已发布 V2） |

申请资质/立即预约入口属 INSTRUMENT-03，本期未开放，前端无对应按钮（符合设计）。

---

## 三、权限及业务边界验证（阶段3）

| 场景 | 结果 | 证据 |
| --- | --- | --- |
| 906 进入授权范围内页面并执行管理操作 | PASS | 平台/房间/设备/负责人/须知全部 CRUD 成功 |
| 904 大厅/详情只读 | PASS | device/page、device/get 均 code=0 |
| 904 创建设备（无权限） | PASS（拒绝） | code=403"没有该操作权限" |
| 904 创建平台（无权限） | PASS（拒绝） | code=403 |
| 904 分配负责人（无 manage 权限） | PASS（拒绝） | code=403 |
| 904 平台分页（无 platform:query） | PASS（拒绝） | code=403 |
| 904 notice/get-by-target（管理端接口） | PASS（拒绝） | code=403（904 通过 device/get 内嵌须知获取，属正确隔离） |
| 无 token 访问 device/page | PASS（拒绝） | code=401"账号未登录" |
| 服务端鉴权（非仅前端按钮隐藏） | PASS | 以上 403/401 均为服务端返回 |
| 租户隔离：906 token 用 tenant-id=1 头 | PASS（拒绝） | code=403"您无权访问该租户的数据" |
| G26 同房间多名维修负责人 | PASS | 见 2.4，不限制单人、不互踢、解除互不影响 |
| 负责人/房间/设备关联校验 | PASS | 见 2.3 非法平台拒绝、激活负责人阻止删除等 |

**阶段3 结论：全部 PASS。**

---

## 四、已修复问题及涉及文件

本任务联调过程中**未发现需要新修复的功能缺陷**。唯一在验收前置阶段修复的问题：

| 问题 | 根因 | 修复 | 文件 | 回归 |
| --- | --- | --- | --- | --- |
| 后端启动失败 BeanNotOfRequiredTypeException: noticeMapper | InstrumentNoticeServiceImpl/DeviceServiceImpl 字段名 `noticeMapper` 与 system 模块 NoticeMapper 的 bean 名冲突，@Resource 按名注入错型 | 字段名改为 `instrumentNoticeMapper`（与 MyBatis 实际注册的唯一 bean 名一致），调用点同步 | [InstrumentNoticeServiceImpl.java](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentNoticeServiceImpl.java)、[InstrumentDeviceServiceImpl.java](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/service/instrument/InstrumentDeviceServiceImpl.java)、[InstrumentNoticeMapper.java](file:///e:/lixin/dev/ruoyi-vue-pro/yudao-module-lab/src/main/java/cn/iocoder/yudao/module/lab/dal/mysql/instrument/InstrumentNoticeMapper.java)（仅注释） | 后端编译 SUCCESS，`Started YudaoServerApplication in 9.497s`，Tomcat 48080 正常 |

**说明**：测试初期曾出现 3 条中文乱码数据（平台1/房间1/设备1），根因是 PowerShell 5 `Invoke-RestMethod` 默认非 UTF8 编码 request body 导致中文传输破坏——属**测试工具问题，非后端缺陷**；用 UTF8 字节重发验证后端中文存储正常（HEX 证实），并已通过 API 修正这 3 条数据。

---

## 五、编译 / 前端检查 / 回归测试

| 项 | 结果 |
| --- | --- |
| 后端编译 | `mvn -pl yudao-module-lab compile` **BUILD SUCCESS（EXIT=0）** |
| 前端 TS 检查 | `vue-tsc --noEmit`（8G 堆）：**instrument 模块 0 错误**；全项目 13 个错误均为历史存量（announcement 1 / fms 2 / hrm 1 / plasmid-audit 5 / plasmid 4），非本任务引入，未改动 |
| 回归 | 未改动其他模块代码；权限/租户隔离实测未影响质粒/注册审批（未触碰其菜单与角色） |

注：vue-tsc 默认堆（4G）全量检查 OOM（exit 134），加 `--max-old-space-size=8192` 后通过——环境内存配置问题，非代码问题。

---

## 六、数据库测试数据清单（新增并保留）

| 表 | id | 内容 | 保留状态 |
| --- | --- | --- | --- |
| lab_instrument_platform | 1 | PF-TEST01 验收测试平台01（ENABLE） | 保留 |
| lab_instrument_platform | 2 | PF-TEST02 验收测试平台02-中文（ENABLE） | 保留 |
| lab_instrument_room | 1 | RM-TEST01 验收测试房间209（ENABLE） | 保留 |
| lab_instrument_device | 1 | DEV-TEST01 验收测试酶标仪01（SCRAPPED，状态机测试后） | 保留 |
| lab_instrument_device | 2 | DEV-TEST02 Clean Device 02（NORMAL） | 保留 |
| lab_instrument_manager | 1 | ROOM_REPAIR/房间1/REPAIR/265（RELEASED，G26 解除测试） | 保留（历史） |
| lab_instrument_manager | 2 | ROOM_REPAIR/房间1/REPAIR/281（ACTIVE） | 保留 |
| lab_instrument_manager | 3 | ROOM_REPAIR/房间1/REPAIR/265（ACTIVE） | 保留 |
| lab_instrument_notice | 1 | DEVICE/设备1/V1（ARCHIVED，发布 V2 后自动归档） | 保留（历史） |
| lab_instrument_notice | 2 | DEVICE/设备1/V2（PUBLISHED） | 保留 |

所有测试记录可通过 device_no/code（PF-TEST/RM-TEST/DEV-TEST 前缀）识别追踪。**未执行 TRUNCATE/DROP，未删除任何正式数据。** 如需清理，待单独授权后提交清理清单。

---

## 七、尚未完成的功能 / 阻塞原因 / 所需操作

| 项 | 状态 | 说明 |
| --- | --- | --- |
| 申请资质、立即预约 | 未开放（设计如此） | 属 INSTRUMENT-03，本期仅档案标记 bookable |
| 前端页面 UI 人工走查 | 建议补充 | 本报告以真实接口+DB 证据为主；建议负责人在浏览器对 7 个页面做一次可视化走查确认交互 |
| 测试数据清理 | 待授权 | 如需清理第六节数据，提交清单后单独授权 |

---

## 八、最终结论

**PASS**

理由：
1. 环境/五表/字典/菜单/套餐/角色授权只读核验全部符合设计。
2. 六个页面后端接口 CRUD、设备状态机、使用须知版本化发布/归档全部实测通过。
3. 权限边界（906 全权 / 904 只读 / 写操作 403 / 无 token 401）、服务端鉴权、租户隔离全部实测通过。
4. G26 方案 A（同房间多名有效维修负责人）全项实测通过：多人 ACTIVE、不互踢、重复拒绝、解除互不影响、历史完整、权限识别全部负责人（非仅第一条）。
5. 后端编译 SUCCESS，前端 instrument 模块 TS 0 错误。
6. 唯一前置缺陷（noticeMapper bean 冲突）已修复并验证启动成功；联调未暴露新缺陷。

**INSTRUMENT-01 仪器基础档案已达到进入下一阶段的条件。** 未自动开始 INSTRUMENT-02。
