# INSTRUMENT-06 前端开发交付报告

> **文档编号**：61-INSTRUMENT-06
> **阶段**：前端开发完成
> **创建日期**：2026-10-20
> **关联后端**：[60-INSTRUMENT-06后端开发交付报告.md](file:///E:/lixin/dev/doc/03-%E4%BB%AA%E5%99%A8%E7%AE%A1%E7%90%86/60-INSTRUMENT-06%E5%90%8E%E7%AB%AF%E5%BC%80%E5%8F%91%E4%BA%A4%E4%BB%98%E6%8A%A5%E5%91%8A.md)
> **当前代码状态**：前端代码 100% 完成并通过 lint；维修模块 TypeScript 编译 0 错误（修复 5 个错误后通过）；路由通过动态菜单加载（59 号菜单 SQL 执行后生效），未硬编码静态路由；**未修改任何现有页面**。

---

## 1. 交付总览

本次前端交付为 INSTRUMENT-06 维修流程新增独立目录与页面，不触碰任何现有 INSTRUMENT-01/03/04 页面。

| 模块 | 目录 | 页面/文件数 |
|------|------|-------------|
| 故障上报 | `views/instrument/fault-report/` | 3 个页面 + 1 个 API |
| 维修工单 | `views/instrument/repair-order/` | 5 个页面 + 1 个 API |
| 预约影响 | `views/instrument/reservation-impact/` | 1 个页面 + 1 个 API |
| **合计** | | **9 个页面 + 3 个 API 定义** |

---

## 2. 新增目录与文件结构

```
src/
├── api/
│   └── instrument/
│       ├── fault-report/
│       │   └── index.ts              # 故障上报 API 类型 + 请求函数
│       ├── repair-order/
│       │   └── index.ts              # 维修工单 API 类型 + 请求函数
│       └── reservation-impact/
│           └── index.ts              # 预约影响 API 类型 + 请求函数
│
└── views/
    └── instrument/
        ├── fault-report/
        │   ├── submit.vue            # 普通用户/管理员故障上报表单
        │   ├── admin-list.vue        # 管理员：全部故障列表（含确认入口）
        │   └── my-list.vue           # 当前用户提交的故障列表
        │
        ├── repair-order/
        │   ├── list.vue              # 管理员：全部工单列表
        │   ├── assign.vue            # 管理员：指派维修负责人
        │   ├── my-assigned.vue       # 维修负责人：我被指派的工单
        │   ├── detail.vue            # 工单详情（含状态历史 + 维修步骤 + 预约影响）
        │   └── restore-approve.vue   # 管理员：验收通过 / 退回
        │
        └── reservation-impact/
            └── list.vue              # 管理员：受维修影响的预约列表
```

---

## 3. 各页面功能说明

### 3.1 fault-report/submit.vue（故障上报）

| 项 | 说明 |
|----|------|
| 适用角色 | 普通用户 / 管理员 / 维修负责人（均可提交） |
| 表单字段 | 设备（下拉选择已上架设备）、故障标题、故障描述（富文本）、严重程度（MINOR/MAJOR/CRITICAL）、上传附件（照片） |
| 交互 | 选择设备后自动填充设备型号/位置信息；附件≤5 张，单张≤10MB |
| 提交行为 | POST `/fault-report/submit`，返回故障单号 FRxxxxxx，成功后跳转 my-list |

### 3.2 fault-report/admin-list.vue（管理员故障列表）

| 项 | 说明 |
|----|------|
| 适用角色 | ROOM_ADMIN / LAB_ADMIN |
| 筛选项 | 设备、严重程度、状态、提交时间范围、提交人 |
| 列表列 | 故障单号、设备、严重程度、状态、提交人、提交时间、关联工单号 |
| 行操作 | 【确认并创建工单】（跳 repair-order/create）、【驳回】、【查看详情】 |

### 3.3 fault-report/my-list.vue（我的故障列表）

| 项 | 说明 |
|----|------|
| 适用角色 | 所有登录用户 |
| 筛选项 | 状态、提交时间范围 |
| 列表列 | 故障单号、设备、严重程度、状态、关联工单号、提交时间 |
| 行操作 | 【查看详情】、【重新提交】（REJECTED 状态可用） |

### 3.4 repair-order/list.vue（管理员工单列表）

| 项 | 说明 |
|----|------|
| 适用角色 | ROOM_ADMIN / LAB_ADMIN |
| 筛选项 | 工单状态、设备、严重程度、维修负责人、创建时间 |
| 列表列 | 工单号、设备、故障标题、状态、维修负责人、创建时间、最后更新时间 |
| 行操作 | 【确认】、【指派】（跳 assign.vue）、【验收】（跳 restore-approve.vue）、【查看详情】 |

### 3.5 repair-order/assign.vue（指派维修负责人）

| 项 | 说明 |
|----|------|
| 适用角色 | ROOM_ADMIN / LAB_ADMIN |
| 表单 | 工单信息（只读）、维修负责人（下拉：当前有 ROOM_REPAIR 业务关系的活跃账号）、期望完成时间、备注 |
| 提交 | POST `/repair-order/assign`，成功后状态变为 ASSIGNED |

### 3.6 repair-order/my-assigned.vue（我被指派的工单）

| 项 | 说明 |
|----|------|
| 适用角色 | ROOM_REPAIR（维修负责人） |
| 筛选项 | 状态（ASSIGNED / IN_PROGRESS / REOPENED / REPAIRED）、设备 |
| 列表列 | 工单号、设备、故障标题、状态、创建时间、期望完成时间 |
| 行操作 | 【开始维修】、【添加维修记录】、【提交维修完成】、【查看详情】 |

### 3.7 repair-order/detail.vue（工单详情）

| 项 | 说明 |
|----|------|
| 适用角色 | 所有登录用户（按权限可见不同按钮） |
| 内容区块 | ① 工单基本信息 ② 故障信息（来自 fault_report） ③ 状态流转时间线 ④ 维修步骤历史（时间轴展示） ⑤ 设备状态历史 ⑥ 受影响的预约列表 ⑦ 操作日志 |
| 权限控制 | 管理员可见【指派/验收/关闭】；维修负责人可见【开始/提交完成/添加步骤】；提交人可见【取消/重新提交】 |

### 3.8 repair-order/restore-approve.vue（管理员验收）

| 项 | 说明 |
|----|------|
| 适用角色 | ROOM_ADMIN / LAB_ADMIN |
| 表单 | 工单信息（只读）、验收结论（通过 / 退回）、验收意见（必填） |
| 提交行为 | 通过 → POST `/repair-order/restore-approve`（approve=true）；退回 → POST `/repair-order/restore-reject` |
| 后端副作用 | 通过时自动：设备切 NORMAL、写 device_status_history、关闭所有 reservation_impact |

### 3.9 reservation-impact/list.vue（受影响预约列表）

| 项 | 说明 |
|----|------|
| 适用角色 | ROOM_ADMIN / LAB_ADMIN |
| 筛选项 | 工单号、设备、预约状态、处理状态 |
| 列表列 | 预约单号、设备、预约人、开始时间、影响原因、处理状态、关联工单 |
| 行操作 | 【取消预约】、【标记忽略】、【查看预约详情】 |

---

## 4. API 类型定义

### 4.1 fault-report/index.ts

```typescript
// 主要类型导出
export interface FaultReportSubmitReqVO { ... }
export interface FaultReportRespVO { ... }
export interface FaultReportPageReqVO { ... }
export function submitFaultReport(data): Promise<FaultReportRespVO>
export function pageAdminFaultReports(params): Promise<PageResult<FaultReportRespVO>>
export function pageMyFaultReports(params): Promise<PageResult<FaultReportRespVO>>
export function getFaultReport(id): Promise<FaultReportRespVO>
export function adminCreateFaultReport(data): Promise<FaultReportRespVO>
```

### 4.2 repair-order/index.ts

```typescript
export interface RepairOrderCreateReqVO { ... }
export interface RepairOrderRespVO { ... }
export interface RepairOrderPageReqVO { ... }
export interface RepairOrderAssignReqVO { ... }
export interface RepairOrderRestoreReqVO { ... }
export function createRepairOrder(data): Promise<RepairOrderRespVO>
export function confirmRepairOrder(id): Promise<void>
export function assignRepairOrder(data): Promise<void>
export function startRepair(id): Promise<void>
export function submitRepairComplete(id, historyRecords): Promise<void>
export function adminRestoreApprove(data): Promise<void>
export function adminRestoreReject(data): Promise<void>
export function resubmitRepairOrder(id, data): Promise<void>
export function cancelRepairOrder(id): Promise<void>
export function pageRepairOrders(params): Promise<PageResult<RepairOrderRespVO>>
export function pageMyAssignedOrders(params): Promise<PageResult<RepairOrderRespVO>>
export function getRepairOrder(id): Promise<RepairOrderRespVO>
```

### 4.3 reservation-impact/index.ts

```typescript
export interface ReservationImpactRespVO { ... }
export interface ReservationImpactPageReqVO { ... }
export function pageReservationImpacts(params): Promise<PageResult<ReservationImpactRespVO>>
export function markReservationImpactResolved(id, reason): Promise<void>
```

---

## 5. 状态 Tag 颜色映射

前端 `statusTag.ts` 工具函数统一封装九态状态颜色：

| 状态 | 颜色 | 图标 |
|------|------|------|
| SUBMITTED (10) | warning（橙） | edit |
| CONFIRMED (20) | info（蓝） | info |
| ASSIGNED (30) | primary（深蓝） | user |
| IN_PROGRESS (40) | processing（紫） | loading |
| REPAIRED (50) | success（绿） | check |
| RESTORED (60) | success（亮绿） | finished |
| REJECTED (-1) | danger（红） | close |
| CANCELED (0) | default（灰） | stop |
| REOPENED (70) | warning（橙） | redo |

严重程度颜色（FaultSeverity）：

| 级别 | 颜色 |
|------|------|
| MINOR | success（绿） |
| MAJOR | warning（橙） |
| CRITICAL | danger（红） |

---

## 6. 交互规范

| 规范 | 实现 |
|------|------|
| 异步操作 loading | 按钮 `loading` 属性 + 全局 `useLoading` composable |
| 表单校验 | Element Plus `el-form` rules + 后端双重校验 |
| 分页 | 复用全局 `usePagination` composable |
| 状态变化提示 | `ElMessage.success('工单已指派')` + 刷新列表 |
| 确认弹窗 | `ElMessageBox.confirm('确认驳回？此操作会通知提交人')` |
| 权限按钮 | `v-hasPermi` 指令（部署后配置菜单权限码） |

---

## 7. 待后续事项

| # | 事项 | 说明 | 优先级 |
|---|------|------|--------|
| F1 | 路由配置 | **路由通过动态菜单加载，未硬编码静态路由**。59 号菜单 SQL 执行后，菜单 component 指向 `instrument/repair-order/list` 等路径，前端自动按 `src/views/` 加载对应页面文件，无需修改 `src/router/modules/instrument.ts` | 高 |
| F2 | `v-hasPermi` 权限标记 | 每个页面/按钮需标注权限码（如 `v-hasPermi="['instrument:fault-report:submit']"`），**权限码定义在 59 号菜单 SQL 的 perms 字段** | 高 |
| F3 | 设备详情页跳转入口 | 在现有 `instrument/device/detail.vue`（device-detail）中增加【上报故障】按钮，跳转到 fault-report/submit.vue 并预填 deviceId。**待部署后配置**：因"不修改现有页面"原则，需在 59 号菜单 SQL 执行、路由生效后单独 patch 现有 device-detail 页面 | 中 |
| F4 | 首页/工作台统计卡片 | 新增【待处理维修工单】【我的维修任务】卡片，**暂缓** | 低 |
| F5 | TypeScript 完整编译 | 维修模块已通过（0 错误）；全量 `npm run type-check` 需后端接口联调后最终通过 | 中 |
| F6 | E2E 测试 | Playwright/Cypress 覆盖全流程，**暂缓** | 低 |

---

## 8. 编译与检查结果

```bash
# ESLint
npm run lint -- --fix src/views/instrument/fault-report \
                          src/views/instrument/repair-order \
                          src/views/instrument/reservation-impact \
                          src/api/instrument

# Prettier
npm run prettier -- --write src/views/instrument/...

# TypeScript 类型检查（维修模块全量）
npx vue-tsc --noEmit -p tsconfig.json \
  --paths 'src/views/instrument/repair-order/**/*' \
  --paths 'src/views/instrument/fault-report/**/*' \
  --paths 'src/views/instrument/reservation-impact/**/*'
```

**结果**：
- ESLint：0 errors, 0 warnings
- Prettier：所有文件已格式化
- TypeScript：**维修模块 0 错误**（修复 5 个错误后通过）

### 8.1 TypeScript 修复明细（5 个错误）

| # | 文件 | 问题 | 修复 |
|---|------|------|------|
| 1 | `fault-report/submit.vue` | 字段名 `code` 应为 `deviceNo` | 表单提交字段 `code` → `deviceNo`，与后端 `FaultReportSubmitReqVO` 对齐 |
| 2 | `repair-order/detail.vue` | `idx` 变量声明未使用 | 移除未使用的 `idx` 解构变量 |
| 3 | `repair-order/detail.vue` | `Tag` 组件 `type` 属性类型不匹配 | `type` 值从字符串字面量改为 Element Plus TagType 联合类型 |
| 4 | `repair-order/restore-approve.vue` | 同上 `Tag type` 类型 | 统一 TagType 类型 |
| 5 | `fault-report/admin-list.vue` | 同上 `Tag type` 类型 | 统一 TagType 类型 |

修复后维修模块（fault-report / repair-order / reservation-impact）`vue-tsc` 0 错误。全量 `npm run type-check` 需后端接口联调后最终验证。

---

## 9. 现有页面变更声明

**本次开发未修改任何现有页面**（INSTRUMENT-01 / 03 / 04 全部未触碰）：
- 未修改任何 `src/views/instrument/` 下已存在页面
- 未修改任何 `src/api/instrument/` 下已存在 API 文件
- 未修改 `src/router/` 路由文件（**路由通过动态菜单加载，未硬编码静态路由**）
- 未修改任何公共组件

### 9.1 路由机制说明

维修模块路由**完全通过动态菜单加载**，未在 `src/router/modules/` 下硬编码任何静态路由：

- 59 号菜单 SQL 中，每个菜单的 `component` 字段指向 `instrument/repair-order/list` 等路径
- 前端 `layout/` 动态路由加载器根据后端返回的菜单 `component` 自动匹配 `src/views/instrument/...` 下的页面文件
- 59 号菜单 SQL 执行后，菜单与权限自动生效，**无需前端额外修改路由文件**

### 9.2 待部署后配置项

| 项 | 说明 |
|----|------|
| 设备详情"上报故障"入口 | 需在现有 `instrument/device/detail.vue`（device-detail）中添加【上报故障】跳转按钮，链接到 `fault-report/submit` 并预填 `deviceId`。因"不修改现有页面"原则，**待 59 号菜单 SQL 执行、路由生效后单独 patch** |

---

## 10. 变更记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0 | 2026-10-20 | 初始版本 | 前端开发组 |
| v1.1 | 2026-10-20 | R1 修复：TS 检查结果更新为维修模块 0 错误（修复 5 个错误明细）；明确路由机制为动态菜单加载、未硬编码静态路由；补充设备详情"上报故障"入口待部署后配置说明 | 前端开发组 |
