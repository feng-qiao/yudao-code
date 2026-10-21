# 49-INSTRUMENT-04 特殊预约规则核验报告

> 编制日期：2026-10-20
> 编制依据：后端 ReservationCreateExecutor.validateTimeParams / validateWindowScope / DeviceCategoryEnum
> 核验范围：酶标仪开放窗口、蛋白纯化仪最短时长、BLI 粒度、跨日预约
> 数据库 live 快照（2026-10-20）：设备 4（叫"酶标仪"）category=NORMAL 而非 MICROPLATE_READER，窗口规则不会对该设备生效

---

## 一、核验基线

### 1.1 相关后端代码位置

| 校验点 | 文件 | 方法 | 行号 |
|---|---|---|---|
| 预约粒度对齐（granularity） | ReservationCreateExecutor.java | validateTimeParams | ~P7 校验段 |
| 时长范围校验（minDuration/maxDuration） | ReservationCreateExecutor.java | validateTimeParams | ~P7 校验段 |
| 开放窗口校验 | ReservationCreateExecutor.java | validateWindowScope | 独立方法 |
| 跨日禁止 | ReservationCreateExecutor.java | validateTimeParams | allowCrossDay 字段判断 |
| 设备类别枚举 | DeviceCategoryEnum.java | — | MICROPLATE_READER / PROTEIN_PURIFY / BLI 等 |

### 1.2 数据库规则快照

| 字段 | 值 | 设备 4 | 说明 |
|---|---|---|---|
| category | **NORMAL**（非 MICROPLATE_READER） | — | 设备 4 名字叫"酶标仪"但 category 配置错误 |
| granularity | 30 | 分钟 | 规则表配置 |
| minDuration | 30 | 分钟 | 规则表配置 |
| maxDuration | 240 | 分钟（4h） | 规则表配置 |
| bookableDaysAhead | 7 | 天 | 规则表配置 |
| allowCrossDay | 0 | — | 禁止跨日 |
| 开放窗口 | ACTIVE, openDays=3,7 12:00-18:00 | targetDate 2026-11-16~30 | 窗口表配置 |

### 1.3 bookable 配置

4 台设备 bookable 全 0（INSTRUMENT-03 隔离环境初始配置，真实环境由 lab_admin 手动打开）。

---

## 二、D1 酶标仪开放窗口核验

### 2.1 后端实现状态

**已实现**：`validateWindowScope` 方法完整支持：
- 查询该设备的 ACTIVE 开放窗口（targetDate 覆盖请求日期）
- 请求时间范围必须被至少一个窗口完整覆盖（"窗口模型"而非"窗口内允许任意时长"）
- 窗口内粒度对齐校验
- 单自然日限制（U3 HOLD 分支：窗口设备预约不允许跨自然日）
- 开放日（openDays）校验

### 2.2 前端配置入口

INSTRUMENT-02 已实现预约规则和开放窗口的前端配置页面（`booking-config/` 目录）。

### 2.3 当前问题（配置错误）

数据库设备 4（叫"酶标仪"）的 `category` 字段值为 `NORMAL` 而非 `MICROPLATE_READER`。

**影响**：
- 后端 `validateWindowScope` 校验是独立的（不依赖 category 字段），只要该设备**在窗口表有记录**就会生效
- 但如果未来代码改为 `if (device.category == MICROPLATE_READER) validateWindowScope()`，设备 4 的窗口规则会静默失效
- 设备类别本身可用于前端不同展示、搜索过滤、权限策略等

**建议**：lab_admin 在真实环境将设备 4 的 category 修正为 MICROPLATE_READER。

### 2.4 开放窗口校验覆盖度

| 校验项 | 实现 | 代码位置 |
|---|---|---|
| 窗口 targetDate 覆盖请求日期 | ✅ | validateWindowScope line ~ |
| 至少一个窗口完整覆盖 | ✅ | validateWindowScope 遍历窗口 + 区间包含校验 |
| 粒度对齐 | ✅ | validateWindowScope 内部调用 granularity 校验 |
| 单自然日限制 | ✅ | validateWindowScope 检查 start.toLocalDate()==end.toLocalDate() |
| allowCrossDay 独立控制 | ✅ | validateTimeParams 独立判断 |

---

## 三、D2 蛋白纯化仪最短 6 小时规则

### 3.1 后端实现状态

**未实现**。ReservationCreateExecutor.validateTimeParams 只做通用规则校验：
- granularity 对齐（min/maxDuration 由规则表配置）
- minDuration / maxDuration 范围

**无任何代码**：
```java
// 不存在类似 switch(device.getCategory()) 的特殊校验
// 不存在 "if PROTEIN_PURIFY then minDuration = 360" 的硬编码
```

### 3.2 规则表配置能力

规则表 `lab_instrument_reservation_rule` 已有：
- `granularity`（分钟）= 预约粒度
- `min_duration`（分钟）= 最短时长
- `max_duration`（分钟）= 最长时长

**候选方案**（不自行开发，等裁决）：

| 方案 | 描述 | 改动范围 | 优势 | 风险 |
|---|---|---|---|---|
| **A. 后端硬编码** | ReservationCreateExecutor 加 `if PROTEIN_PURIFY then 强制 minDuration >= 360` | 1 处代码 | 简单直接 | 规则变更需改代码；多设备类别时 switch 膨胀 |
| **B. 规则表配置** | lab_admin 直接把 PROTEIN_PURIFY 设备的规则 min_duration 设为 360 | 0 代码 | 配置驱动，已支持 | 依赖正确配置；无服务端硬兜底（配置错了不会拦截） |
| **C. 规则表新增 category 特殊字段** | 规则表加 `special_min_by_category` JSON 字段，后端解析 | DO + VO + Mapper + Service + Controller + 前端 | 灵活但复杂 | 过度设计 |

**建议**：方案 B 零代码改动即可生效。如果需要服务端硬兜底（防止配置错误），可后期加方案 A。

---

## 四、D3 BLI 预约粒度

### 4.1 后端实现状态

**未实现**。与蛋白纯化仪相同，ReservationCreateExecutor 无 BLI 特殊校验。

### 4.2 规则表粒度能力

规则表已有 `granularity` 字段（分钟）。lab_admin 可直接把 BLI 设备的规则 granularity 设为指定值（如 15 分钟），零代码改动。

### 4.3 BLOCKED 原因

任务书明确："预约粒度尚未裁决时，不得自行设定固定值"。等负责人裁决 BLI 粒度后，lab_admin 在规则表配置 granularity 值即可。

---

## 五、D4 跨日预约核验

### 5.1 当前实现

| 控制项 | 实现 | 说明 |
|---|---|---|
| allowCrossDay 规则开关 | ✅ | 规则表字段，0 禁止 / 1 允许 |
| validateTimeParams 跨日拦截 | ✅ | `if (!allowCrossDay && start.toLocalDate() != end.toLocalDate()) throw 087` |
| 窗口设备单自然日限制 | ✅ | validateWindowScope 额外限制（U3 HOLD） |
| 跨日时长计算 | ✅ | validateTimeParams 正确计算跨日时长 |
| 跨日冲突检查 | ✅ | ReservationConflictChecker 正确处理跨日区间重叠 |
| 跨日开放日计算 | ✅ | validateTimeParams 检查每一天是否在 openDays 内 |

### 5.2 当前配置

设备 4（酶标仪）规则 `allowCrossDay=0` → 禁止跨日。

### 5.3 特殊规则冲突点

| 场景 | 行为 | 说明 |
|---|---|---|
| allowCrossDay=1 但设备有 ACTIVE 开放窗口 | validateWindowScope 单自然日限制拦截 | U3 HOLD 分支：窗口设备预约仅允许单自然日 |
| allowCrossDay=0 且请求跨自然日 | validateTimeParams 拦截（087 错误码） | 通用规则生效 |
| allowCrossDay=1 且请求不跨窗口 | 允许跨日 | 普通规则生效 |

---

## 六、完整特殊规则核验矩阵

| 设备类别 | 规则类型 | 后端特殊校验 | 规则表配置能力 | 前端配置入口 | 当前状态 | BLOCKED 原因 |
|---|---|---|---|---|---|---|
| MICROPLATE_READER（酶标仪） | 开放窗口 | ✅ validateWindowScope 完整 | ✅ 规则表 + 窗口表 | ✅ booking-config/ | **PARTIAL**（设备 category 配置错误，窗口校验独立生效中） | 无，已实现 |
| PROTEIN_PURIFY（蛋白纯化仪） | 最短 6h | ❌ 无特殊校验 | ✅ min_duration 字段 | ✅ booking-config/ | **BLOCKED**（规则表配置即可，无特殊代码） | 待裁决：方案 A（硬编码兜底）vs 方案 B（纯配置） |
| BLI | 预约粒度 | ❌ 无特殊校验 | ✅ granularity 字段 | ✅ booking-config/ | **BLOCKED**（规则表配置即可） | 待裁决：BLI 粒度未确定 |
| FREEZE_DRYER（冻干机） | 批次 | ❌ 无特殊校验 | ❌ 无批次字段 | ❌ 无批次配置 | **BLOCKED**（任务书未提及） | 未冻结 |
| BIOSAFETY_CABINET（生物安全柜） | — | ❌ | ✅ 普通规则 | ✅ | **DONE**（用通用规则） | 无特殊需求 |
| CMC | — | ❌ | ✅ 普通规则 | ✅ | **DONE**（用通用规则） | 无特殊需求 |

---

## 七、配置与规则隔离验证

### 7.1 设备 4 窗口规则是否生效

**是**。`validateWindowScope` 不依赖 `device.category` 字段，只要该设备在开放窗口表有 ACTIVE 记录（targetDate 覆盖请求日期），窗口校验就会生效。设备 4 虽然 category=NORMAL 但窗口表有记录 → 窗口校验对其生效。

### 7.2 规则表配置优先级

ReservationCreateExecutor 校验顺序：
1. P1：设备状态必须 NORMAL
2. P2：bookable=true
3. P3：设备有 ACTIVE 规则
4. **P7**：通用规则校验（粒度对齐、时长范围、跨日）
5. **P8**：开放窗口校验（如设备有 ACTIVE 窗口）

规则表 granularity/minDuration/maxDuration 对**所有**设备生效，不区分 category。特殊规则（最短时长、粒度）可直接配置规则表字段，零代码改动。

---

## 八、建议

| 编号 | 建议 | 优先级 | 依赖 |
|---|---|---|---|
| S1 | lab_admin 将设备 4 category 修正为 MICROPLATE_READER | 信息 | 无 |
| S2 | 裁决 PROTEIN_PURIFY 最短 6h 规则：方案 A（硬编码兜底）vs 方案 B（纯配置） | 等待裁决 | 负责人裁决 |
| S3 | 裁决 BLI 粒度确定值 | 等待裁决 | 负责人裁决 |
| S4 | 后续批次：如需服务端硬兜底，ReservationCreateExecutor 加 switch(device.category) 硬编码校验 | 低 | S2 裁决 |
| S5 | 后续批次：如需完整审计，DDL 新建 InstrumentDeviceStatusHistoryDO | 低 | 独立批准 DDL |
