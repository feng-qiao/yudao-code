# 23-INSTRUMENT-03-数据库与接口设计

> 版本：V2.0（2026-10-15 修订，B1~B11 正式裁决落地）
> 任务：TASK INSTRUMENT-03-DECISION-FREEZE-01-R1（设计修订，**不含任何已执行的 DDL/DML**）
> 结论基线：B1~B11 已由负责人正式裁决（裁决原文见 `22-INSTRUMENT-03-预约业务规则冻结草案.md` 第五章）；V1.0 草案中的【待裁决】表述已更新为已裁决落地，原文证据保留可追溯。
> 数据库权限：本文档全程只读核验；`sql/lab/` 下 03 系列脚本仅为**设计稿**，须由负责人审查后另行授权执行。

---

## 一、文档定位与输入依据

| 输入 | 用途 |
| --- | --- |
| `02-数据库模型设计.md` §3.12/3.13/3.14/3.19/3.20 | 五张表字段**权威定义**（本文不擅自增删业务字段） |
| `03-预约规则与并发控制设计.md` §7.1/7.2/8.1/8.1.1/8.2/8.3 | 冲突口径、创建/取消事务、暂停校验 7 条强制约束（H2） |
| `07-接口页面菜单权限设计.md` §2.7/2.8/2.9/2.10 | 接口清单**权威定义**；§4.2 权限编码 |
| `00-总体设计与业务模型.md` §4.4 | 预约状态机与占用口径（C3） |
| `20-INSTRUMENT-02-执行后验收报告.md` | 错误码现状（已用到 079）、T-C1/C2/C3 遗留观察 |
| `21-INSTRUMENT-03-预约模块开发前核验报告.md` | H-B1 竞态阻断项、R-1~R-8 风险清单 |
| `22-INSTRUMENT-03-预约业务规则冻结草案.md` | A 类已冻结规则、B1~B11 待裁决清单 |

**现状基线（21 号实测）**：`lab_instrument_reservation / _reservation_history / _booking_rule / _booking_window / _maintenance` 五表**均不存在**；instrument 包内 reservation/booking-rule/booking-window/maintenance 的 Controller/Service/Mapper/DO/VO **均为 0 个**；`InstrumentDeviceMapper` 无 `selectByIdForUpdate`；错误码已用至 `1_002_004_079`。

---

## 二、数据库设计（DDL 设计稿，不执行）

### 2.1 总览与实施约定

| 表 | 用途 | 体量 | 唯一约束 |
| --- | --- | --- | --- |
| `lab_instrument_reservation` | 普通仪器预约 | 高（十万级） | `uk_reservation_tenant_no(tenant_id, reservation_no)` |
| `lab_instrument_reservation_history` | 预约变更及操作历史（只增不改） | 高（十万级） | — |
| `lab_instrument_booking_rule` | 设备预约规则配置（1:1） | 低（百级） | `uk_rule_tenant_device(tenant_id, device_id)` |
| `lab_instrument_booking_window` | 酶标仪开放窗口（1:N） | 低（百级） | — |
| `lab_instrument_maintenance` | 仪器维护占用时段 | 中（千级） | — |

继承 `20261015_instrument_02_schema.sql` 既定风格：

1. `CREATE TABLE IF NOT EXISTS`，可重复执行；**不使用物理外键**（lab 模块既有规范，逻辑关联 + Service 校验）。
2. 每表含 yudao 公共列：`creator / create_time / updater / update_time / deleted / tenant_id`（`TenantBaseDO` 对应）。
3. MySQL 8.0.x，InnoDB，utf8mb4 / utf8mb4_unicode_ci。
4. 全部字段为 `bigint(20)` 主键自增；DO 侧标注 `@KeySequence("lab_instrument_xxx_seq")` 保持既有惯例。
5. **SQL 生成与执行分离**：设计稿另行落为 `sql/lab/202610XX_instrument_03_schema.sql`（24 号批次 03-A），由负责人审查后另行授权执行；本文档的 DDL 仅表达结构与索引意图。
6. 附带执行前预检（information_schema 表存在性/列数核对）与执行后验收 SELECT，参照 02 号 schema 脚本三段式结构。

### 2.2 lab_instrument_reservation（预约主表）

字段完全继承 02 §3.12（此处列 DDL 表达，语义见 02 号）：

```sql
CREATE TABLE IF NOT EXISTS `lab_instrument_reservation` (
  `id`                bigint(20)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `reservation_no`    varchar(50)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '预约单号（B8 待裁决：R+yyyyMMdd+5位Redis自增）',
  `device_id`         bigint(20)   NOT NULL COMMENT '设备 id，逻辑关联 lab_instrument_device.id',
  `user_id`           bigint(20)   NOT NULL COMMENT '预约人 user id',
  `user_name`         varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '预约人姓名快照',
  `qualification_id`  bigint(20)   NULL DEFAULT NULL COMMENT '准入校验时使用的资质 id（审计快照，可空）',
  `start_time`        datetime     NOT NULL COMMENT '预约开始（左闭）',
  `end_time`          datetime     NOT NULL COMMENT '预约结束（右开）',
  `duration_minutes`  int(11)      NOT NULL COMMENT '时长（分钟）',
  `status`            varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING' COMMENT '状态：PENDING/FINISHED/CANCELED/VOIDED（IN_USE 预留不启用；NO_SHOW 已删除 C1）',
  `purpose`           varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '用途',
  `actual_start_time` datetime     NULL DEFAULT NULL COMMENT '实际开始（第一期不自动写入，仅手工登记）',
  `actual_end_time`   datetime     NULL DEFAULT NULL COMMENT '实际结束（同上）',
  `finish_time`       datetime     NULL DEFAULT NULL COMMENT '完成时间（手工登记完成时写入）',
  `cancel_time`       datetime     NULL DEFAULT NULL COMMENT '取消时间',
  `cancel_by`         varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '取消方：USER/MANAGER/ADMIN',
  `cancel_reason`     varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '取消原因',
  `remark`            varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '备注',
  `creator`  varchar(64)  NULL DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`  varchar(64)  NULL DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`  bit(1)  NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT 0 COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_reservation_tenant_no`(`tenant_id`, `reservation_no`) USING BTREE,
  INDEX `idx_device_time`(`device_id`, `start_time`, `end_time`, `status`) USING BTREE,
  INDEX `idx_user_status`(`user_id`, `status`) USING BTREE,
  INDEX `idx_start_time`(`start_time`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '普通仪器预约' ROW_FORMAT = Dynamic;
```

要点：

- `idx_device_time` 为 **P8 冲突查询专用索引**（02 §3.12），查询谓词顺序 `device_id 等值 + start_time < reqEnd + end_time > reqStart + status IN(...)` 与索引匹配。
- `qualification_id` 记录准入时点使用的资质，仅审计用途；**后续资质状态变化不回写本表**（与暂停/资质解耦，20 号 T-C2 分析的落点之一）。
- `deleted` 仅保留框架字段；**Service 层不提供任何物理删除/逻辑删除入口**（C3：禁止删除历史释放时间）。
- 不新增 `freeze_batch_id` 等无业务依据字段。

### 2.3 lab_instrument_reservation_history（操作历史，只增不改）

继承 02 §3.13：

```sql
CREATE TABLE IF NOT EXISTS `lab_instrument_reservation_history` (
  `id`               bigint(20)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `reservation_id`   bigint(20)   NOT NULL COMMENT '预约 id',
  `action`           varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '动作：CREATE/ADJUST/CANCEL/FINISH/VOID（NO_SHOW 已删除 C1）',
  `operator_user_id` bigint(20)   NOT NULL COMMENT '操作人用户 id',
  `operator_name`    varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '操作人姓名快照',
  `operator_role`    varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '操作角色：USER/MANAGER/ADMIN',
  `action_time`      datetime     NOT NULL COMMENT '操作时间',
  `before_start_time` datetime    NULL DEFAULT NULL COMMENT '变更前开始',
  `before_end_time`  datetime     NULL DEFAULT NULL COMMENT '变更前结束',
  `after_start_time` datetime     NULL DEFAULT NULL COMMENT '变更后开始',
  `after_end_time`   datetime     NULL DEFAULT NULL COMMENT '变更后结束',
  `before_status`    varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '变更前状态',
  `after_status`     varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '变更后状态',
  `reason`           varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '原因（管理员开始后调整必填）',
  `remark`           varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '备注',
  `creator`  varchar(64)  NULL DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`  varchar(64)  NULL DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`  bit(1)  NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT 0 COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_reservation_id`(`reservation_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '预约变更及操作历史（只增不改）' ROW_FORMAT = Dynamic;
```

要点：与预约主表**同一事务**写入；无 UPDATE 入口（Mapper 不提供 update 方法）。

### 2.4 lab_instrument_booking_rule（设备预约规则，1:1）

继承 02 §3.19，含 **B7 已裁决（2026-10-15）保留列** `allow_cross_day`：

```sql
CREATE TABLE IF NOT EXISTS `lab_instrument_booking_rule` (
  `id`                   bigint(20)  NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `device_id`            bigint(20)  NOT NULL COMMENT '设备 id（1:1）',
  `granularity_minutes`  int(11)     NULL DEFAULT NULL COMMENT '时间粒度（分钟）；与最短时长分开（F13）；NULL=未配置',
  `min_duration_minutes` int(11)     NULL DEFAULT NULL COMMENT '最短时长（分钟，如 360=6h）；NULL=未配置',
  `max_duration_minutes` int(11)     NULL DEFAULT NULL COMMENT '最长时长（分钟）',
  `bookable_days_before` int(11)     NULL DEFAULT NULL COMMENT '允许预约的起始偏移（可往前 N 天）',
  `bookable_days_ahead`  int(11)     NULL DEFAULT NULL COMMENT '允许预约的日期范围（往后 N 天）',
  `open_days`            varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '每周开放日（1-7 逗号分隔，可空=不限）',
  `open_start_time`      varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '每日开放开始（HH:mm）',
  `open_end_time`        varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '每日开放结束（HH:mm）',
  `allow_cross_day`      bit(1)      NULL DEFAULT NULL COMMENT '是否允许跨天预约（B7 裁决保留列）：1 允许；0/NULL 均视为不允许。默认口径由业务层判定，不写库默认值',
  `allow_admin_adjust_after_start` bit(1) NOT NULL DEFAULT b'1' COMMENT '管理员是否可在开始后调整',
  `enabled`              bit(1)      NOT NULL DEFAULT b'0' COMMENT '规则启用（0=不可预约，F15：未配置不得采用默认粒度）',
  `remark`               varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '备注',
  `creator`  varchar(64)  NULL DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`  varchar(64)  NULL DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`  bit(1)  NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT 0 COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_rule_tenant_device`(`tenant_id`, `device_id`) USING BTREE,
  INDEX `idx_device_id`(`device_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '设备预约规则配置（1:1）' ROW_FORMAT = Dynamic;
```

要点：

- `allow_cross_day` **B7 已裁决（2026-10-15）：保留字段**。列定义遵守 B7 补充约束——**不写库默认值**（`NULL DEFAULT NULL`，非 `NOT NULL DEFAULT b'0'`），默认规则"不允许跨天"由业务层判定（`Boolean.TRUE.equals(allowCrossDay)` 才允许），**不得擅自将默认值写入真实数据库**。**DDL 与 DO 必须一致**：DO 字段类型 `Boolean`，DDL 列可空，两者均不引入隐式默认。
- `granularity_minutes / min_duration_minutes` 保持可空：NULL + `enabled=0` 共同表达"未配置不可预约"（P3、F15、B10）。
- 保存接口（07 §2.9 `booking-rule/save`）校验：`min<=max`、granularity>0、HH:mm 格式合法（错误码段 100~）。

### 2.5 lab_instrument_booking_window（酶标仪开放窗口，1:N）

继承 02 §3.20，无新增列：

```sql
CREATE TABLE IF NOT EXISTS `lab_instrument_booking_window` (
  `id`                  bigint(20)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `device_id`           bigint(20)   NOT NULL COMMENT '设备 id（1:N）',
  `window_name`         varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '窗口/批次名称',
  `open_days`           varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '每周开放日（1-7 逗号分隔）',
  `open_start_time`     varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '开放时段开始（HH:mm）',
  `open_end_time`       varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '开放时段结束（HH:mm）',
  `target_date_start`   date         NULL DEFAULT NULL COMMENT '开放目标日期范围开始',
  `target_date_end`     date         NULL DEFAULT NULL COMMENT '开放目标日期范围结束',
  `target_week_mapping` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '开放日→目标日期映射说明（文本，F14：不写死业务规则）',
  `capacity`            int(11)      NULL DEFAULT NULL COMMENT '窗口可预约能力（容量，可空=不限）',
  `used_count`          int(11)      NOT NULL DEFAULT 0 COMMENT '已使用量',
  `status`              varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/CLOSED',
  `sort`                int(11)      NULL DEFAULT 0 COMMENT '排序',
  `remark`              varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '备注',
  `creator`  varchar(64)  NULL DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`  varchar(64)  NULL DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`  bit(1)  NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT 0 COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_device_status`(`device_id`, `status`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '酶标仪开放窗口（1:N）' ROW_FORMAT = Dynamic;
```

要点：

- 窗口与具体日期的映射完全由 `target_date_* + target_week_mapping` 配置表达（F14），服务端**不做**"周三/周日→日期"的硬编码推断；日期归属判定 = `target_date_start <= 请求日期 <= target_date_end` 且（配置了 open_days 时）周几命中。
- **U2 未裁决影响**：窗口模型与酶标仪真实排班的映射规则（具体日期如何对应）待负责人提供；在此之前窗口仅可维护数据，`free-slots`/`is-open` 对窗口设备的日期匹配逻辑按上述通用规则实现，**不预设 U2 的业务口径**（见 22 号 B10）。
- **【CAP-A 修订，2026-10-16】容量按日期独立计算**：本表 `used_count` 字段**自 CAP-A 起不再作为"窗口整个周期共享"的累计消耗口径使用**。开放窗口容量按**自然日期独立**：每个窗口覆盖的每个自然日期独立拥有 `capacity` 额度，某日用尽不影响同窗口其他日期；同日期并发预约不得超额；取消/调整/作废按冻结规则正确释放或转移对应日期容量。
  - **日期容量明细模型**（SQL 设计稿 `20261016_instrument_03_capacity_daily_design.sql`，待授权执行）：新增独立明细表（候选名 `lab_instrument_booking_window_daily_usage`），`(tenant_id, window_id, usage_date)` 唯一约束，承载按日期的已用量原子增减；`capacity` 继续留在窗口主表作为"每日容量上限"。
  - **兼容性**：本表既有 DDL 不改；`used_count` 字段保留但**废弃业务写入**（历史口径字段，迁移说明见设计稿），不得再被预约扣减路径更新；真实库部署前预约扣减逻辑按旧口径处于 HOLD，不接入正式预约。
  - 容量扣减（新口径）：预约创建成功后按**预约覆盖的每个自然日期**在明细表 `used_count + 1`（同事务条件更新 `WHERE used_count < 窗口capacity`），取消/作废时按日期回退；`capacity IS NULL` 视为不限（不限日期亦不写明细行）。
  - **未裁决**（留待负责人，不得硬编码）：跨日预约的容量归属（只扣开始日 / 所有覆盖日 / 结束日）、一条预约消耗的容量单位数（默认按单数 1，若为时段数需裁决）、同设备同日多窗口的选择优先级、FINISHED 是否继续占用当日容量。

### 2.6 lab_instrument_maintenance（维护占用时段）

继承 02 §3.14：

```sql
CREATE TABLE IF NOT EXISTS `lab_instrument_maintenance` (
  `id`          bigint(20)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `device_id`   bigint(20)   NOT NULL COMMENT '设备 id',
  `start_time`  datetime     NOT NULL COMMENT '维护开始（左闭）',
  `end_time`    datetime     NOT NULL COMMENT '维护结束（右开）',
  `reason`      varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '维护原因（必填）',
  `source_type` varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'MANUAL' COMMENT '来源：MANUAL 手工 / PLAN 计划 / REPAIR 维修产生',
  `source_id`   bigint(20)   NULL DEFAULT NULL COMMENT '来源单据 id（如维修工单，第一期不填）',
  `status`      varchar(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE 占用 / CANCELED 取消',
  `remark`      varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '备注',
  `creator`  varchar(64)  NULL DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`  varchar(64)  NULL DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`  bit(1)  NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT 0 COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_device_time`(`device_id`, `start_time`, `end_time`, `status`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '仪器维护占用时段' ROW_FORMAT = Dynamic;
```

要点：维护时段计入 P8 冲突（`status='ACTIVE'`）；`source_type='REPAIR'` 为 INSTRUMENT-06 预留，第一期维护创建接口仅写 MANUAL。

### 2.7 不在本期 DDL 范围的关联表

- `lab_instrument_freeze_batch / _freeze_participant`：属 INSTRUMENT-05（05 号文档）。本期 P8 三方冲突中的"冻干批次"来源按 §5.4 的容错开关处理（R-8）。
- `lab_instrument_repair_order`：属 INSTRUMENT-06。本期 maintenance.`source_id` 不填。

---

## 三、DO / Mapper 设计

### 3.1 新增 DO（`dal.dataobject.instrument`，均继承 `TenantBaseDO`）

| DO | 表 | 关键点 |
| --- | --- | --- |
| `InstrumentReservationDO` | reservation | 枚举校验用 String status；`@KeySequence("lab_instrument_reservation_seq")` |
| `InstrumentReservationHistoryDO` | reservation_history | 只增不改 |
| `InstrumentBookingRuleDO` | booking_rule | `allowCrossDay` Boolean（**B7 已裁决保留**，DDL 与 DO 一致、不引入隐式默认） |
| `InstrumentBookingWindowDO` | booking_window | — |
| `InstrumentMaintenanceDO` | maintenance | — |

状态/动作枚举新增于 `enums.instrument`：`ReservationStatusEnum(PENDING/FINISHED/CANCELED/VOIDED)`、`ReservationActionEnum(CREATE/ADJUST/CANCEL/FINISH/VOID)`、`OperatorRoleEnum(USER/MANAGER/ADMIN)`、`MaintenanceStatusEnum(ACTIVE/CANCELED)`、`MaintenanceSourceEnum(MANUAL/PLAN/REPAIR)`、`WindowStatusEnum(ACTIVE/CLOSED)`。字典 SQL（如需前端下拉）随 03-F 批次另行设计稿，本文不展开。

### 3.2 Mapper 清单

| Mapper | 方法 | 说明 |
| --- | --- | --- |
| `InstrumentDeviceMapper`（**改造现有**） | `selectByIdForUpdate(Long id)` | `SELECT ... WHERE id=#{id} AND deleted=0 FOR UPDATE`；**03 新增，03 §8.1 串行化锚点**；现有文件无任何 FOR UPDATE 方法（21 号实测） |
| `InstrumentReservationMapper`（新增） | `selectConflictCount(deviceId, reqStart, reqEnd)` | 03 §7.1 SQL，`status IN ('PENDING','FINISHED')` |
| | `selectConflictList(deviceId, reqStart, reqEnd)` | 冲突摘要返回（占用类型+时段，7.3 前端提示） |
| | `selectPage / selectMyPage / selectById` | 常规查询（LambdaQueryWrapperX 惯例） |
| | `updateCancelIfPending(...)` | §6.3 条件更新 |
| | `updateFinishIfPending(...)` | §6.4 条件更新 |
| | `updateVoidIfPending(...)` | §6.5 条件更新 |
| | `updateAdjustTime(...)` | adjust 同事务改时间（§6.6） |
| `InstrumentReservationHistoryMapper`（新增） | `insertBatch / selectListByReservationId` | 只增不改，无 update/delete |
| `InstrumentBookingRuleMapper`（新增） | `selectByDeviceId` | 1:1 读取 |
| `InstrumentBookingWindowMapper`（新增） | `selectListByDeviceAndStatus` | 窗口读取 |
| | `updateUsedCountIncrIfAvailable(id, capacity)` | 条件扣减：`UPDATE ... SET used_count=used_count+1 WHERE id=? AND status='ACTIVE' AND (capacity IS NULL OR used_count < capacity)` |
| | `updateUsedCountDecr(id)` | 取消/作废回退（仅 PENDING→CANCELED/VOIDED 同事务调用） |
| `InstrumentMaintenanceMapper`（新增） | `selectConflictList(deviceId, start, end)` | `status='ACTIVE'` |
| | `selectPage` | 常规 |
| | `updateCancelIfActive(id)` | 条件更新取消维护 |

### 3.3 冲突查询封装与 freeze_batch 容错（R-8）

新增 `service.instrument.ReservationConflictChecker`（组件，非接口滥用）：

```text
conflict(deviceId, reqStart, reqEnd) -> List<ConflictItem(type, start, end, brief)>
  1. reservation:   必查（表在本期 DDL 中）
  2. maintenance:   必查（表在本期 DDL 中）
  3. freeze_batch:  仅当配置 lab.instrument.conflict.include-freeze-batch=true 时查询
```

- `lab.instrument.conflict.include-freeze-batch` 默认 **false**（21 号 R-8：本期 freeze_batch 表不存在，INSTRUMENT-05 建表后开启）。配置为 true 而表缺失时直接 SQL 报错暴露问题（不做静默吞异常）。
- 冲突返回包含占用来源类型，供 7.3 的友好提示（"该时段已被占用：预约 09:30-10:30"）。

### 3.4 VO 设计要点（`controller.admin.instrument.vo.*`）

| VO 组 | 内容要点 |
| --- | --- |
| `reservation.ReservationCreateReqVO` | `deviceId`（必填）、`startTime`/`endTime`（必填，秒级截断到分钟）、`purpose`（≤500）、`remark`；**不含 status/cancel 类字段** |
| `reservation.ReservationRespVO` | 主表全量 + `deviceName/deviceNo` 快照关联 + 剩余可取消/可调整标记（服务端计算，前端只做展示） |
| `reservation.ReservationPageReqVO` | deviceId、userId、status、时间范围、分页；数据范围在 Service 裁剪（本人/授权负责人/管理） |
| `reservation.ReservationCancelReqVO` | `id` + `reason`（MANAGER/ADMIN 必填；USER 选填） |
| `reservation.ReservationAdjustReqVO` | `id` + 新 `startTime/endTime` + `reason`（必填） |
| `reservation.CalendarItemVO / SlotVO / OpenResultVO` | 见 §8 |
| `rule.BookingRuleSaveReqVO` | deviceId + 规则字段（含 **B7 已裁决保留的 allowCrossDay**），保存校验 min<=max、granularity>0 |
| `window.BookingWindowCreateReqVO / UpdateReqVO / RespVO` | 02 §3.20 字段 |
| `maintenance.MaintenanceCreateReqVO / PageReqVO / RespVO` | 02 §3.14 字段（source_type 服务端固定 MANUAL） |

---

## 四、接口设计（以 07 §2.7/2.8/2.9/2.10 为权威）

### 4.1 预约日历与空闲时段（07 §2.7，只读、无事务）

| 方法 | URL | 权限 | 说明 |
| --- | --- | --- | --- |
| GET | `/lab/instrument/reservation/calendar` | `lab:instrument:reservation:query` | deviceId + 日期范围 → 占用明细 + 开放范围（§8.1） |
| GET | `/lab/instrument/reservation/free-slots` | 同上 | deviceId + 日期 → 粒度切片空闲槽（§8.2） |
| GET | `/lab/instrument/reservation/is-open` | 同上 | deviceId + 时段 → P1-P6 快速判定（不含冲突） |

### 4.2 预约 CRUD（07 §2.8）

| 方法 | URL | 权限 | 事务 | 核心逻辑 |
| --- | --- | --- | --- | --- |
| POST | `/reservation/create` | `lab:instrument:reservation:create` | 是 | P1-P9 全链 + 方案 A 双层锁（§7）+ `@Idempotent` |
| POST | `/reservation/cancel` | `lab:instrument:reservation:cancel` | 是 | §6.3 条件更新，affectedRows 校验 |
| POST | `/reservation/finish`【补充】 | `lab:instrument:reservation:manage` | 是 | §6.4 手工登记完成；**07 §2.8 未列此接口，本设计依据 02 §3.13 action=FINISH（"第一期为负责人手工登记"）补充，待负责人确认** |
| PUT | `/reservation/adjust` | `lab:instrument:reservation:adjust` | 是 | §6.6 全链复核 + 写 history |
| POST | `/reservation/void` | `lab:instrument:reservation:manage` | 是 | §6.5 作废（第一期仅 PENDING 可作废） |
| GET | `/reservation/page` | `lab:instrument:reservation:query` | 否 | 数据范围：本人 / 授权负责人 / 管理（复用 `InstrumentScopeSupport`） |
| GET | `/reservation/my` | 同上 | 否 | 本人 |
| GET | `/reservation/get?id` | 同上 | 否 | 详情 |
| GET | `/reservation/history-list?id` | 同上 | 否 | 操作历史 |
| GET | `/reservation/export-excel` | `lab:instrument:reservation:export` | 否 | 同分页条件 |

**设计决策（B11 已于 2026-10-15 正式裁决）**：

1. **finish 接口（已确认）**：02 §3.13 定义了 action=FINISH 且注明"负责人手工登记"，07 §2.8 未列接口。本设计补充 `POST /reservation/finish`（权限沿用 `reservation:manage`，不新增权限串）。按 **B11-①~③** 落实：**显式操作、不实现自动完成**；仅允许符合状态条件（`status='PENDING'`）的预约执行，成功后写入实际使用信息与完成时间；**重复操作必须明确拒绝**（`INSTRUMENT_RESERVATION_FINISH_DENIED`）；**手工完成必须填写实际使用时间并保留操作证据**（`actual_start_time/actual_end_time/finish_time` 均为必填，写入 `reservation_history(action=FINISH, reason/remark)` 留证）。
2. **void 范围**：第一期仅允许作废 PENDING（FINISHED 为已实际使用历史，纠错场景不在本期范围）。
3. cancel 的权限/时间条件矩阵见 §6.3，与 03 §8.2 SQL 一致，**无"提前 N 分钟"条件**（C2）。

### 4.3 预约规则 / 开放窗口（07 §2.9）

| 方法 | URL | 权限 |
| --- | --- | --- |
| GET | `/booking-rule/get?deviceId` | `lab:instrument:rule:query` |
| POST | `/booking-rule/save` | `lab:instrument:rule:update` |
| GET | `/booking-window/page?deviceId` | `lab:instrument:rule:query` |
| POST | `/booking-window/create` | `lab:instrument:rule:update` |
| PUT | `/booking-window/update` | `lab:instrument:rule:update` |
| DELETE | `/booking-window/delete?id` | `lab:instrument:rule:update` |

数据范围：rule/window 维护仅管理员（22 号 B9：rule 权限仅授 lab_admin）。

### 4.4 维护时段（07 §2.10）

| 方法 | URL | 权限 | 核心逻辑 |
| --- | --- | --- | --- |
| GET | `/maintenance/page` | `lab:instrument:maintenance:query` | — |
| POST | `/maintenance/create` | `lab:instrument:maintenance:manage` | 设备行锁 + 冲突查询（§4.4.1） |
| POST | `/maintenance/cancel` | `lab:instrument:maintenance:manage` | 条件更新 `ACTIVE→CANCELED` |

**维护创建与既有预约重叠的处理（B11-④⑤ 已裁决，2026-10-15）**：维护时段**不得静默覆盖**已有占用预约；对重叠 `PENDING` 预约**拒绝创建维护时段**（错误码 `INSTRUMENT_MAINTENANCE_CONFLICT_RESERVATION`），返回**可识别的冲突信息**（冲突预约单号/时段摘要），提示先由负责人处理预约。理由：维护静默压过用户预约会造成"预约成功却不可用"且第一期无自动通知路径；拒绝语义清晰、无数据副作用。备选（允许创建、已有预约保留）会在冲突查询中同时命中维护，用户预约依旧无法使用，但缺乏用户感知路径，**已否决**。

### 4.5 权限编码汇总（B9 已裁决，2026-10-15）

| 权限串 | 904 普通用户 | 908 仪器设备负责人 | 906 lab_admin |
| --- | --- | --- | --- |
| `lab:instrument:reservation:query` | ✔ | ✔ | ✔ |
| `lab:instrument:reservation:create` | ✔ | ✔ | ✔ |
| `lab:instrument:reservation:cancel` | ✔ | ✔ | ✔ |
| `lab:instrument:reservation:adjust` | ✔（本人 PENDING 开始前，T1 裁决 2026-10-19） | ✔ | ✔ |
| `lab:instrument:reservation:manage` | ✘ | ✔ | ✔ |
| `lab:instrument:reservation:export` | ✘ | ✔ | ✔ |
| `lab:instrument:rule:query` | ✘ | ✘ | ✔ |
| `lab:instrument:rule:update` | ✘ | ✘ | ✔ |
| `lab:instrument:maintenance:query` | ✘ | ✔ | ✔ |
| `lab:instrument:maintenance:manage` | ✘ | ✘ | ✔ |

**T1/T2 裁决修订（TASK INSTRUMENT-03-R2-MYSQL-CONCURRENCY-VERIFY-01，2026-10-19）**：

1. **T1 调整权限独立化**：`/reservation/adjust` 正式启用独立权限 `lab:instrument:reservation:adjust`（Controller `@PreAuthorize` 已同步）；**禁止继续以 `reservation:cancel` 兼作调整权限**。普通用户（904）可调整本人 PENDING 预约（开始前），服务端必须重走全部准入校验（身份/租户/归属/设备状态/资质/暂停/规则/开放窗口/时间/冲突/目标设备/当前状态），不得因预约原本合法而跳过；管理侧按既有数据范围（908 仅授权设备，906 全部）。菜单/授权设计见 `sql/lab/20261016_instrument_03b_booking_config_menu_design.sql` 附录 A（仅设计稿，未执行）。
2. **T2 调整不要求客户端提交 windowId**：服务端以调整后 deviceId + startTime + endTime 为事实依据重新匹配并校验目标设备有效开放窗口（窗口设备 = 存在可完整覆盖新时段的 ACTIVE 窗口，复用 is-open 同款服务端匹配）；同设备调整重执行该设备开放窗口校验，跨设备调整重执行目标设备全部 P1~P8；匹配不到有效窗口拒绝调整（087）；客户端旧 windowId 不进入调整链路、无法绕过重新匹配（ReqVO 已删除 windowId 字段）。
3. **`lab_instrument_reservation.window_id` 结论（REMOVE-LATER）**：2026-10-19 只读核查正式库 `labplatform`——该表无 `window_id` 列、无相关索引/外键；DO/Mapper/H2 DDL/隔离 baseline 预约表均无该列；创建/调整不依赖 reservation 级 window_id（34 号收敛后窗口仅用于 P6 时间范围校验）。无存量数据需要兼容，**无需任何 DDL**；后续若出现该列的旧设计稿（CAP-A 配套 ALTER）一律不执行。

**角色标识（B9 裁决，严禁混用）**：`904`=普通用户；`908`=仪器设备负责人（角色编码 `instrument_device_manager`）；`906`=`lab_admin`。**908 必须同时满足权限串与 `lab_instrument_manager` ACTIVE 业务关系（DEVICE/PLATFORM）**，且**不授予全局设备管理范围**（数据范围由 `InstrumentScopeSupport.canManageDevice` 判定：DEVICE 直接负责 + PLATFORM 平台下设备）。

**菜单可见 ≠ 后端授权成功**（B9-⑤）：本节权限串仅约束准入，数据范围必须在 Service 层独立校验；导出、管理列表等接口不得仅依赖前端按钮隐藏。

菜单/授权 SQL 设计稿在 24 号批次 03-F 产出（**成组授权教训**：按权限串逐条核对本表，禁止整目录授权）；**本任务不生成、不执行任何菜单/角色授权 SQL**（B9-⑥）。

---

## 五、P1-P9 校验顺序与错误码分配

### 5.1 服务端准入校验顺序（Service 层，03 §8.1 + §8.1.1）

```text
[锁外] 0. 参数与身份快校验：登录用户、租户、VO 基本校验（@Valid）
[锁内·suspendKey 用户锁 → 事务 → 设备行锁]
  P1 设备存在与状态：selectByIdForUpdate(deviceId)
       不存在/跨租户（租户插件过滤后为 null）→ DEVICE_INVALID
       status != NORMAL（含 MAINTENANCE/FAULT/DISABLED/SCRAPPED）→ DEVICE_STATUS_DENIED（SCRAPPED 终态同码，R13 語义）
  P2 bookable 标记：bookable != true → DEVICE_NOT_BOOKABLE
  P3 规则：rule 不存在 / enabled=0 / granularity 或 min_duration 为 NULL → RULE_NOT_ENABLED（F15：不得采用默认粒度）
  P4 资质：qualification 存在 ACTIVE 记录
       且（**B2 已裁决，2026-10-15**）(expire_time IS NULL OR expire_time > now)
       ——NULL 视为长期有效；该空值语义已与实际 DO / DDL / 02 资质状态定义核对，结论见 §5.3（禁止臆造）
       不满足 → NO_VALID_QUALIFICATION；qualification_id 写入审计快照
  P5 暂停：selectActiveCovering(userId, deviceId) 非空 → USER_SUSPENDED
       （判定 status='ACTIVE' AND start_time<=now，【不含 end_time】，H1/H2；SINGLE 与 ALL 共用本查询，
         selectActiveCovering 已实现于 InstrumentSuspendMapper，直接复用）
  P6 开放范围：
       普通设备：open_days 命中周几 / open_start~open_end 覆盖请求时段 / 请求日期在 bookable_days_before~ahead 窗口内
       窗口设备（MICROPLATE_READER）：存在 ACTIVE 窗口覆盖请求日期时段，capacity 校验
       不满足 → OUT_OF_OPEN_SCOPE / WINDOW_CAPACITY_EXCEEDED
  P7 时间参数：
       end > start；duration = 分钟差
       duration 对齐 granularity（start 与 duration 均按粒度对齐，03 §4.2）→ TIME_NOT_ALIGNED
       min_duration <= duration <= max_duration → DURATION_OUT_OF_RANGE
       （B7 已裁决，2026-10-15）跨天：allow_cross_day 为 1 才允许；0 或 NULL 均视为**不允许**（默认口径在业务层判定，库列不设默认值）→ CROSS_DAY_DENIED
       非法时间（过去时间等，按 bookable_days_before 语义）→ TIME_INVALID
  P8 冲突：ReservationConflictChecker 三方查询（§3.3）→ TIME_CONFLICT（附冲突摘要）
  P9 落库：INSERT reservation(status=PENDING, reservation_no=B8 规则) + INSERT history(action=CREATE)
       窗口设备：updateUsedCountIncrIfAvailable 条件扣减，affectedRows=0 → WINDOW_CAPACITY_EXCEEDED
[锁内事务提交 → 外层锁释放]
```

顺序固定为 P1→P9，错误码首触即返回；P5 位于 P4 之后、P8 之前（03 §8.1.1 强制约束 1）。

### 5.2 错误码分配（`ErrorCodeConstants`，续 1_002_004_079 之后）

**预约段 080~099**：

| 码 | 常量 | 文案要点 |
| --- | --- | --- |
| 080 | `INSTRUMENT_RESERVATION_NOT_EXISTS` | 预约不存在 |
| 081 | `INSTRUMENT_RESERVATION_DEVICE_INVALID` | 设备不存在 |
| 082 | `INSTRUMENT_RESERVATION_DEVICE_STATUS_DENIED` | 设备当前状态不可预约（含 SCRAPPED） |
| 083 | `INSTRUMENT_RESERVATION_DEVICE_NOT_BOOKABLE` | 设备未开放预约 |
| 084 | `INSTRUMENT_RESERVATION_RULE_NOT_ENABLED` | 预约规则未配置或未启用 |
| 085 | `INSTRUMENT_RESERVATION_NO_VALID_QUALIFICATION` | 缺少有效使用资质 |
| 086 | `INSTRUMENT_RESERVATION_USER_SUSPENDED` | 账号存在生效的使用暂停 |
| 087 | `INSTRUMENT_RESERVATION_OUT_OF_OPEN_SCOPE` | 不在开放日期/时段内 |
| 088 | `INSTRUMENT_RESERVATION_WINDOW_CAPACITY_EXCEEDED` | 开放窗口可预约能力已用完 |
| 089 | `INSTRUMENT_RESERVATION_TIME_INVALID` | 预约时间参数非法 |
| 090 | `INSTRUMENT_RESERVATION_TIME_NOT_ALIGNED` | 时间未按设备粒度对齐 |
| 091 | `INSTRUMENT_RESERVATION_DURATION_OUT_OF_RANGE` | 时长超出设备允许范围 |
| 092 | `INSTRUMENT_RESERVATION_CROSS_DAY_DENIED` | 该设备不允许跨天预约（B7 裁决后启用） |
| 093 | `INSTRUMENT_RESERVATION_TIME_CONFLICT` | 时段已被占用（附冲突摘要） |
| 094 | `INSTRUMENT_RESERVATION_CANCEL_DENIED` | 无权取消或当前状态不可取消 |
| 095 | `INSTRUMENT_RESERVATION_ADJUST_DENIED` | 无权调整 |
| 096 | `INSTRUMENT_RESERVATION_ADJUST_CONFLICT` | 调整后时段冲突 |
| 097 | `INSTRUMENT_RESERVATION_FINISH_DENIED` | 当前状态不可登记完成 |
| 098 | `INSTRUMENT_RESERVATION_VOID_DENIED` | 当前状态不可作废 |
| 099 | `INSTRUMENT_RESERVATION_NO_GEN_FAILED` | 预约单号生成失败（B8 序列超限/Redis 异常；03-A 已实现） |

**规则/维护段 100~119**：

| 码 | 常量 | 文案要点 |
| --- | --- | --- |
| 100 | `INSTRUMENT_RULE_NOT_EXISTS` | 预约规则不存在 |
| 101 | `INSTRUMENT_RULE_DEVICE_INVALID` | 设备不存在，无法配置规则 |
| 102 | `INSTRUMENT_RULE_GRANULARITY_INVALID` | 粒度配置非法 |
| 103 | `INSTRUMENT_RULE_DURATION_CONFIG_INVALID` | 最短/最长时长配置非法 |
| 104 | `INSTRUMENT_RULE_OPEN_TIME_INVALID` | 开放时间/开放日配置非法 |
| 105 | `INSTRUMENT_WINDOW_NOT_EXISTS` | 开放窗口不存在（2026-10-16 CAP-A 任务备案，28 号报告 B.2） |
| 106 | `INSTRUMENT_WINDOW_DEVICE_INVALID` | 设备不存在，无法配置窗口（2026-10-16 备案） |
| 107 | `INSTRUMENT_WINDOW_CONFIG_INVALID` | 窗口时间/日期范围/状态/容量配置非法（2026-10-16 备案） |
| 108 | `INSTRUMENT_WINDOW_CAPACITY_BELOW_USED` | 窗口容量不得低于已使用量（2026-10-16 备案） |
| 109 | `INSTRUMENT_WINDOW_USED_DELETE_DENIED` | 已有使用记录的窗口禁止删除（2026-10-16 备案） |
| 110 | `INSTRUMENT_MAINTENANCE_NOT_EXISTS` | 维护时段不存在 |
| 111 | `INSTRUMENT_MAINTENANCE_TIME_INVALID` | 维护时间参数非法 |
| 112 | `INSTRUMENT_MAINTENANCE_DEVICE_INVALID` | 设备不存在 |
| 113 | `INSTRUMENT_MAINTENANCE_PERMISSION_DENIED` | 无权维护该设备 |
| 114 | 保留 | — |
| 115 | `INSTRUMENT_MAINTENANCE_CONFLICT_RESERVATION` | 存在重叠预约，请先处理（§4.4 设计推荐） |
| 116~119 | 保留 | — |

（080 前的既有段：001-005 平台 / 010-019 设备 / 020-023 房间 / 030-038 负责人 / 040-044 须知 / 045-059 资质 / 060-066 信用 / 070-079 暂停。）

### 5.3 B2 资质 expire_time 空值语义核实（禁止臆造，2026-10-15）

| 核对对象 | 实测结论 | 来源 |
| --- | --- | --- |
| DO 字段 | `InstrumentQualificationDO.expireTime` 为 `LocalDateTime`，**可为 null** | `yudao-module-lab/.../dal/dataobject/instrument/InstrumentQualificationDO.java` |
| 正式 DDL | `expire_time datetime NULL DEFAULT NULL COMMENT '到期时间（空=长期有效）'` | `sql/lab/20261015_instrument_02_schema.sql` |
| H2 测试表 | `"expire_time" timestamp DEFAULT NULL` | `src/test/resources/sql/create_tables.sql` |
| INSTRUMENT-02 资质状态定义 | 有效资质 = `status='ACTIVE'`；`expire_time` 空表示长期有效 | 02 号 §3.19 资质状态语义 |

**结论**：`expire_time` 的空值语义为"**空 = 长期有效**"，因此 P4 叠加条件 `(expire_time IS NULL OR expire_time > now)` 与实际 DO / DDL / 02 定义**一致**，非臆造。判定时点阈值统一为 `now`（业务当前时间），与 P5（`start_time <= now`，不含 `end_time`）时间基准一致。

---


## 六、状态流转与条件更新 SQL

### 6.1 状态机（00 §4.4，第一期）

```text
            用户取消(开始前) / 负责人·管理员取消(任意时刻,原因必填)
  PENDING ────────────────────────────────────────→ CANCELED
     │  负责人·管理员手工登记完成（写 actual_* + finish_time）
     ├────────────────────────────────────────────→ FINISHED
     │  管理员作废（第一期仅 PENDING）
     └────────────────────────────────────────────→ VOIDED
  IN_USE：预留不启用；NO_SHOW：已删除（C1）
```

- 占用口径：`PENDING / FINISHED` 占用时段，`CANCELED / VOIDED` 释放（C3），禁止物理删除。
- 所有状态迁移均为**条件更新 + affectedRows 校验**，与 `reservation_history` 同事务。

### 6.2 创建（P9）

`INSERT ... status='PENDING'`；单号生成（**B8 已裁决，2026-10-15**）：`R` + `yyyyMMdd` + 5 位 Redis 自增，由**独立单号工具类**生成（03-A 落地并附单测，03-C 接入本事务）；**不依赖** `@KeySequence`（MySQL 下框架不启用）。
**B8 必须核对的四项（裁决原文要求，03-A 逐项给出证据）**：① 现有 Redis 工具类与项目依赖（复用 `dal.redis` 下 `StringRedisTemplate` 脚本式 DAO 范式）；② 序列**原子性**（Lua `INCR` 单命令原子）、**日期切换**（key 含 `yyyyMMdd`，跨日新 key 自然重置）、**并发唯一性**（原子 INCR 保证同日不重号）；③ 单号**最大容量**（5 位自增 = 99,999/日）、**补零规则**（`%05d` 左补零）、**溢出处理**（超限抛 `INSTRUMENT_RESERVATION_NO_GEN_FAILED`，不静默回绕）；④ **唯一索引** `uk_reservation_tenant_no(tenant_id, reservation_no)` 存在，冲突时**重试一次**后仍失败则抛错（不得声称"天然不重复"）。
**诚实声明**：Redis 序列**不构成绝对唯一性证明**（Redis 数据丢失/回档会导致序列落后）；唯一性由**数据库唯一索引 + 重试**兜底，Redis 仅提供顺序与可读性。

### 6.3 取消（03 §8.2 原文 SQL 语义）

```sql
UPDATE lab_instrument_reservation
   SET status='CANCELED', cancel_time=NOW(), cancel_by=#{by}, cancel_reason=#{reason},
       updater=#{updater}, update_time=NOW()
 WHERE id=#{id} AND deleted=0
   AND status='PENDING'
   AND ( (#{by}='USER'    AND user_id=#{userId} AND NOW() < start_time)
      OR (#{by}='MANAGER')
      OR (#{by}='ADMIN') )
```

`affectedRows=0` → `RESERVATION_CANCEL_DENIED`（不区分具体原因细节，避免泄露他人预约信息；日志记录实际差异）。取消不校验暂停（释放资源方向不受暂停拦截）。取消同事务：history(action=CANCEL) + 窗口设备 used_count 回退。

### 6.4 手工登记完成（finish，B11 已裁决）

```sql
UPDATE lab_instrument_reservation
   SET status='FINISHED', actual_start_time=#{actualStart}, actual_end_time=#{actualEnd},
       finish_time=#{finishTime}, updater=#{updater}, update_time=NOW()
 WHERE id=#{id} AND deleted=0 AND status='PENDING'
```

**B11 已裁决语义（2026-10-15）**：

- ① `finish` 为**显式操作**，**不实现自动完成**（无 Job、无按 end_time 自动流转）；
- ② 仅允许 `status='PENDING'` 的预约执行；成功后写入实际使用信息与完成时间；**重复操作必须明确拒绝**——`affectedRows=0` → `INSTRUMENT_RESERVATION_FINISH_DENIED`（与"状态已变更"合并为同一明确错误，不得静默成功）；
- ③ **手工完成必须填写实际使用时间并保留操作证据**：`actual_start_time / actual_end_time` 为**必填**（VO 层 `@NotNull`），校验 `actual_end > actual_start`；同事务写入 `reservation_history(action=FINISH, operator_role, remark/reason)` 作为操作证据。

权限 `reservation:manage`（908 限授权设备 + 906 lab_admin）；对已过开始时间的 PENDING 由负责人/管理员处理（C1：无自动流转）。FINISHED 后**不可再取消/调整**（历史占用不可释放，C3）。

### 6.5 作废（void）

```sql
UPDATE lab_instrument_reservation
   SET status='VOIDED', cancel_time=NOW(), cancel_by='ADMIN', cancel_reason=#{reason}, ...
 WHERE id=#{id} AND deleted=0 AND status='PENDING'
```

作废释放时段（C3）；同事务 history(action=VOID) + 窗口容量回退。

### 6.6 调整（adjust，03 §8.3）

同一事务内：**suspendKey 用户锁 → 设备行锁 → 对新时段全链复核（P4/P5/P6/P7/P8）** → 原地 `UPDATE start_time/end_time/duration_minutes` → history(action=ADJUST, reason 必填)。

- 调整对象仅 PENDING（含已过开始时间未登记完成的预约，C1）。
- **B3 已裁决（2026-10-15）：调整属重新准入动作，必须重新执行适用的暂停校验（P5），不得利用调整接口绕过暂停限制**；暂停"不追溯"仅指不自动作废既有预约（存量预约保留）。调整路径同样遵守 B1 锁顺序 `suspendKey → 设备行锁`。
- 窗口设备：原窗口回退、新窗口扣减（两次条件更新，任一失败回滚）。

---

## 七、事务与锁设计（B1 方案 A **已裁决**，2026-10-15）

### 7.1 设计结论

21 号已完成竞态审查（H-B1 阻断项）：暂停写入侧 `InstrumentSuspendServiceImpl#createSuspend` 仅持有 Redisson 锁 `suspendKey(tenantId, userId)`（`InstrumentLockRedisDAO.suspendKey`），事务内**无任何 DB 行锁、不接触设备行**；预约侧仅有设备行锁无法阻止"P5 检查通过后、提交前"并发插入 ACTIVE 暂停。**该竞态经 21 号审查确认存在；B1 已裁决（2026-10-15）批准方案 A，本骨架为 03-C 实施依据。03-A 仅完成锁协议静态核验与可测部分，不得宣称完成 03-C 并发保证（详见 §7.4 与 §7.2）。**

按方案 A（预约侧共用 suspendKey 用户锁）落地的创建事务骨架（[方案 A·已裁决 2026-10-15]，03-C 实施）：

```java
// Controller: @Idempotent（防连点）
// Service:
Long createReservation(ReservationCreateReqVO reqVO) {
    Long tenantId = TenantContextHolder.getRequiredTenantId();
    Long userId = SecurityFrameworkUtils.getLoginUserId();
    // [锁外] VO 校验、设备/规则存在性预读（仅用于快速失败，锁内复核）
    // [方案 A·已裁决] 外层用户锁：与暂停创建/解除同 key，串行化「暂停写入 vs 预约准入」
    return lockRedisDAO.lock(InstrumentLockRedisDAO.suspendKey(tenantId, userId),
        () -> transactionTemplate.execute(status -> {
            // 1. 设备行锁（03 §8.1 串行化锚点，同设备并发创建排队）
            InstrumentDeviceDO device = deviceMapper.selectByIdForUpdate(reqVO.getDeviceId());
            // 2. P1→P8 顺序校验（§5.1；P5 复用 InstrumentSuspendMapper.selectActiveCovering）
            // 3. P8 三方冲突查询（ReservationConflictChecker）
            // 4. INSERT reservation + history（+窗口容量条件扣减）
        }));
}
```

关键性质（21 号 §四.3 论证）：

1. **串行化成立**：预约创建与暂停创建/解除竞争同一 `suspendKey`；若暂停先获锁并提交，预约在锁内执行 P5 必可见；若预约先获锁，暂停创建在预约**事务提交后**（外层锁在 callable 返回后才释放）才开始，不可能插入"早于 P5 检查"的暂停。
2. **锁顺序无环**：预约侧固定顺序 `suspendKey → device 行锁`；暂停侧仅 `suspendKey`；信用侧仅 `creditAccountKey`；资质侧仅 `qualApplyKey`——资源集两两不交或单向包含，无死锁环。**代码规范：预约/调整路径严禁先取设备行锁再取 suspendKey**（顺序反转检查纳入 Code Review 清单与 03-C 验收）。
3. **同设备不同用户并发**：suspendKey 不同无竞争，由设备行锁排队，P8 冲突查询在锁内有效（03 §8.1 原设计成立）。

### 7.2 锁租约约束（开发硬性规则）

`InstrumentLockRedisDAO.lock()` 固定租约 **10 秒、无 watchdog 续期**。因此：

1. 锁内（= 事务内）**禁止**：外部 HTTP 调用、文件 IO、批量报表查询、发送通知；仅允许 §5.1 列出的 ≤10 次索引查询 + 2~3 次写。
2. `transactionTemplate.execute` 必须在锁回调**内部**（事务提交先于锁释放），禁止锁外开事务。
3. 锁内耗时监控：日志埋点 `reservation.create.lock.elapsed`，超 2s 告警（10s 租约的 20% 预算）。
4. 残余风险（21 号已声明）：极端慢查询耗尽 10s 租约 → 锁提前释放 → 保护退化为仅设备行锁。开发期以 ① 锁内操作白名单 ② 慢查询治理 ③ 监控兜底；若 B1 裁决认为该残余不可接受，备选方案见 22 号 B1 备选（暂停侧补锁 / 延迟重验），由负责人选定。

### 7.3 其他并发点

| 场景 | 机制 |
| --- | --- |
| 连点重复提交 | `@Idempotent`（Controller 入口，Redis 短窗口） |
| 并发取消 vs 取消 / 取消 vs 调整 / 作废 | 条件更新 affectedRows（§6.3~6.5），0 行即拒绝 |
| 并发调整同一预约 | adjust 事务内先 `selectById` 复核 status=PENDING + 设备行锁内改时间（同设备串行） |
| 维护创建 vs 预约创建 | 双方均在设备行锁内做冲突查询（预约查 maintenance，维护查 reservation），互相可见 |
| 规则变更 vs 预约创建 | 规则变更在设备行锁内进行（booking-rule/save 锁设备行），保证 P3/P7 读到一致规则 |
| 窗口容量并发扣减 | `updateUsedCountIncrIfAvailable` 条件更新 |

### 7.4 锁安全性证据、修复方案与 HOLD 条件（B1-③④⑤，2026-10-15 裁决要求）

> 本节按 B1 正式裁决要求，对"锁是否覆盖数据库事务直至提交"给出**可核验证据**，而非以"finally 释放"或"有 10 秒告警"作为安全性证明。03-A 阶段交付**静态核验 + 可测部分**；端到端并发验收属 03-C（见 §7.5）。

#### 7.4.1 现状证据（基于实际代码，非推断）

| 项 | 实测结论 | 证据 |
| --- | --- | --- |
| 锁实现 | Redisson `RLock.lock(10_000, MILLISECONDS)` **固定租约、无 watchdog 续期** | `InstrumentLockRedisDAO#lock(key, callable)` |
| 释放方式 | `finally` 内 `if (lock.isHeldByCurrentThread()) lock.unlock()` | 同上 |
| 释放时机 | `callable`（含 `transactionTemplate.execute`）**返回后**才进入 finally → 正常路径下事务提交先于锁释放 | 同上 + §7.1 骨架 |
| 续租机制 | **无**。Redisson watchdog 仅在 `lock()` 无参/`tryLock(时间)` 无 leaseTime 时启用；本类显式传入 10s leaseTime 后**不再续期** | Redisson API 语义 |

#### 7.4.2 核心风险（必须承认，不得美化）

1. **若锁回调（含事务）执行时长 > 10s**：Redisson 在 10s 后自动释放锁 → 另一线程可获取同一 `suspendKey` 并开始其事务；而原线程仍在执行、并可能在**已失去锁之后**继续 `commit`。此时方案 A 的互斥保证**失效**，暂停"插入 vs P5 检查"竞态可能重新出现。
2. `finally` 中释放、日志埋点 `reservation.create.lock.elapsed` 超 2s 告警、`lock.isHeldByCurrentThread()` 判断——**均不构成"锁覆盖事务提交"的安全性证明**（B1-④ 明确要求）。
3. 因此：**"方案 A 已实施即并发安全"是不成立的结论**。必须补齐以下二者之一，方可宣称覆盖事务提交。

#### 7.4.3 修复方案（03-C 实施，待负责人确认后落地）

**方案 A+（推荐）：预约路径专用 watchdog 续期锁方法**

- 在 `InstrumentLockRedisDAO` **新增**独立方法（不改动既有 5 处调用点语义，避免波及 INSTRUMENT-02）：`lockWithWatchdog(key, callable)`，内部使用 Redisson `lock.lock()`（无 leaseTime）或 `lock.tryLock(waitTime, -1, unit)`（leaseTime = -1 触发 watchdog 续期），finally 释放。
- 影响面：仅新增方法与常量，既有 `lock(key, callable)` 与 INSTRUMENT-02 的 5 个锁点**零改动**；03-C 预约/调整路径改用新方法；暂停侧 `createSuspend` 保持既有方法（其事务短、且与预约侧共用 key 仍可串行化），**是否同步切换需负责人确认**（涉及 INSTRUMENT-02 语义，不得擅改）。
- 可测方法（03-C 执行）：在锁回调内 `Thread.sleep(>leaseTime)` 后断言另一线程无法获取同一 key；并断言原线程 commit 后锁才释放（mutex 持续到提交）。

**方案 B（备选）：暂停侧补设备行锁 + 预约侧延迟重验**（22 号 B1 备选）。涉及 INSTRUMENT-02，风险面更大，仅作兜底。

#### 7.4.4 HOLD 判定（必须写入验收）

| 项 | 状态 | 理由 |
| --- | --- | --- |
| 03-A 锁协议**静态核验** | **PASS** | 锁顺序、释放时机、key 复用、无续租均已实测（§7.4.1） |
| 03-A 可测逻辑单测（锁键格式、租户隔离、顺序无环） | **PASS/PARTIAL** | 见 §7.5 单测清单 |
| **03-C 并发验收（互斥覆盖事务提交）** | **HOLD** | 现有固定租约锁**无法证明**覆盖提交；须先落地方案 A+ 并取得可测证据 |

**结论**：03-A 不宣称完成任何"并发保证"；**03-C 的并发相关验收在方案 A+ 落地并取得 watchdog 续期证据之前，一律标记 HOLD**（对应 B1-⑤）。

### 7.5 03-A 锁协议单测范围（可测部分）

| 用例 | 断言 |
| --- | --- |
| `suspendKey(tenantId,userId)` 格式与租户隔离 | 不同 tenantId / userId 生成不同 key；同参稳定 |
| 锁顺序无环（静态） | 预约路径仅 `suspendKey → deviceLock`；无反向调用（以常量清单 + 单测锁键解析校验） |
| 锁键常量唯一性 | 5 个锁键前缀互不为子串（避免误串行） |

> 说明：Redisson 锁回调的**端到端互斥/续期**需真实 Redis 或嵌入式 Redisson 环境，归 03-C 用例，03-A 明确列为 `03-C 待验收项`，不得在本批伪造"已通过"。

---

## 八、日历与空闲时段计算

### 8.1 calendar（日历）

输入 `deviceId + 日期范围（≤31 天）`；输出每日：

```text
CalendarItemVO { date, openRanges[{start,end}], occupied[{type: RESERVATION|MAINTENANCE|WINDOW_FULL, start, end, brief}], myReservationIds }
```

- 占用来源：本人在该设备的预约（全状态）+ 他人预约仅返回占用区间摘要（**不泄露他人预约详情**，brief 脱敏）+ ACTIVE 维护。
- 无规则/未启用 → `openRanges` 空 + reasonCode（前端展示"未开放预约"）。
- 只读无事务，允许弱一致（页面刷新即可见）。

### 8.2 free-slots（空闲槽）

输入 `deviceId + date`：

```text
1. 读 rule（P3 未配置 → 空槽列表 + reasonCode）
2. 开放范围：
   普通设备：open_days ∩ date 周几 → [open_start, open_end]（可空=全天）
   窗口设备：匹配覆盖该日期的 ACTIVE 窗口（§2.5 归属判定；特殊设备参数按 B10 裁决由负责人逐设备确认，未确认部分不得硬编码）
3. 排除占用：PENDING/FINISHED 预约 + ACTIVE 维护（+ freeze_batch 按配置开关）
4. 空闲区间按 granularity_minutes 切片；每片标注 available：
   - 片长满足 min_duration 起步、可连续拼接到 max_duration
   - bookable_days_before/ahead 窗口外 → available=false + reason
SlotVO { start, end, available, reasonCode }
```

- is-open：P1-P6 快速判定（不做冲突查询），返回 `{open, reasonCode}`。

---

## 九、裁决落实对照（B1~B11 已于 2026-10-15 正式裁决）

> 22 号第五章为正式裁决原文。本节逐项落到本文档的具体位置，作为实现与验收索引。

| 裁决项 | 本文档落实位置 | 落实要点 |
| --- | --- | --- |
| **B1** 方案 A 双层锁（阻断级） | §5.1（P5/P8）、§7.1 骨架、§7.2 租约约束、**§7.4 安全性证据/HOLD**、§7.5 单测 | 锁顺序固定 `suspendKey → 设备行锁`；03-A 仅静态核验，**03-C 并发验收 HOLD**（须先落地方案 A+ 上 watchdog） |
| **B2** P4 叠加 expire_time | §5.1 P4、§5.3 空值语义核实 | P4=`status='ACTIVE' AND (expire_time IS NULL OR expire_time > now)`；NULL=长期有效，已与实际 DO/DDL 核对 |
| **B3** 暂停不追溯、调整须复核 | §6.6（adjust） | 调整属重新准入，必须重新执行 P5；不自动作废存量；锁顺序同 B1 |
| **B4** 报废设备资质申请限制 | 归 INSTRUMENT-02 最小修复（见 26 号报告），本文档不扩范围 | 不得为 SCRAPPED 设备开放新有效资质申请；不顺手重构 02 模块 |
| **B5** 资质/暂停状态分离 | §5.1（P4 与 P5 独立）、§6.6 | 暂停不改写资质状态、审批不解除暂停；准入由二者共同决定 |
| **B6** 普通用户本人查询 | §4.5 权限表（"我的信用"仅限本人） | 不开放他人暂停记录/管理端范围/管理操作 |
| **B7** 保留 allow_cross_day | §2.4（列已保留 `NULL DEFAULT NULL`）、§5.1 P7 | DDL 与 DO 一致；默认"不允许跨天"由业务层判定；**不写库默认值** |
| **B8** Redis 单号 | §6.2 | 日期+Redis 序列；四项核对（工具类/原子性/容量/唯一索引兜底）；诚实声明非绝对唯一 |
| **B9** 角色 904/908/906 | §4.5 | 908=instrument_device_manager；906=lab_admin，严禁混用；后端独立权限+数据范围校验；不生成/执行授权 SQL |
| **B10** 特殊设备参数 | §2.4/§2.5、§8.2 | 不擅自默认；由负责人逐设备确认；未配置=不可预约且不影响他设备 |
| **B11** finish/维护语义 | §4.2（finish）、§4.4（维护重叠）、§6.4 | finish 显式、重复拒绝、必填实际时间；维护不静默覆盖、重叠 PENDING 拒绝创建 |

**声明**：本文档为设计稿，不构成数据库执行授权；`sql/lab/` 下任何 03 系列脚本须由负责人审查后另行授权执行（24 号 03-A/03-F 批次）。03-A 关闭须以负责人授权执行 DDL 并回执行结果 + 执行后只读核验为条件。

---

## 十、U1~U5 正式裁决落实（负责人裁决，2026-10-16）

> 裁决原文见 22 号文档 §5.7。本节为 U1~U5 对本文档设计的落实索引；U1~U5 自 2026-10-16 起为**冻结基线**，不再作为待裁决问题。

| 裁决项 | 本文档落实位置 | 落实要点 |
| --- | --- | --- |
| **U1** 跨日容量归属 | §2.5（CAP-A 段）、§5.1 P9、§8.2 | 每条预约对实际覆盖的每个自然日期分别占用 1 个容量单位；半开区间 `[startTime, endTime)`；日期按实验室统一业务时区计算，禁止直接用服务器默认时区 |
| **U2** 容量单位 | §2.5 | 一条预约对每个计入日期恒消耗 1 个容量单位；本期不引入时长/人数/配置倍数 |
| **U3** 同日多窗口 | §2.5、§5.1 P6、§8.2 | 允许同设备同日多个互不重叠窗口；每条预约归属**唯一**窗口（服务端校验，禁止随机选择）；同设备同日窗口实际开放时间重叠属非法配置须拒绝；跨日预约必须验证归属窗口合法覆盖全部区间；现有窗口模型无法表达合法跨日窗口的分支标记 **HOLD**，不擅自扩展开放规则 |
| **U4** FINISHED 容量 | §2.5、§6.3~6.5 | 占用状态集：PENDING、FINISHED 占用；CANCELED、VOIDED 释放；FINISHED **不自动释放**；重复取消/作废/并发状态变更不得重复释放（以预约级占用明细条件状态变更为准，见 §10.1） |
| **U5** 预约窗口关联 | §2.2、§2.5、§5.1 | `lab_instrument_reservation` 新增 `window_id BIGINT`；正式预约创建时必须能确定唯一有效窗口；NOT NULL/历史兼容/索引结构以真实表只读预检结论为准；**仅生成 ALTER 设计稿，未授权不执行** |

### 10.1 容量一致性模型（U1~U5 落地，2026-10-16 修订）

1. 窗口主表 `capacity` 表示**每日容量上限**；窗口主表旧 `used_count` **不再用于正式容量计算**（保留列仅作历史兼容，删除/缩容校验口径改按占用明细，见 30 号报告 B.5）。
2. 日期容量明细按 `(tenant_id, window_id, usage_date)` 唯一（沿用 CAP-A 设计稿表 `lab_instrument_booking_window_daily_usage`）。
3. 新增**预约级容量占用明细**（候选表 `lab_instrument_reservation_capacity_occupation`）：每条预约每个计入日期最多一条有效占用；占用状态 `OCCUPIED → RELEASED` 条件变更成功才允许减少日期容量计数；释放幂等由占用明细唯一性 + 条件更新保证，而非仅凭 `used_count > 0`。
4. 预约与唯一窗口通过 `window_id` 关联；预约状态变更、占用状态变更、日期容量递减必须在**同一数据库事务**内完成，任一步失败整体回滚。
5. 正式容量计算：`剩余容量 = 每日容量上限 - 当日有效占用数量`；`capacity = NULL` 不限容量但仍记录预约级占用依据；`capacity <= 0` 为非法值按冻结规则拒绝。
6. 全部容量写入路径（创建/调整/取消/作废/改容量/删窗口/维护创建）遵守统一固定锁顺序 `suspendKey → 设备行锁 →（设备行锁内）窗口校验 → 日期容量校验 → 占用写入`（详见 30 号报告 B.3 锁顺序表）。
7. 最终 SQL 设计稿：`sql/lab/20261016_instrument_03_capacity_u1_u5_final.sql`（合并/取代 29 号任务的阶段设计稿，仅设计稿不执行）。
