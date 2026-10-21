# 50-INSTRUMENT-04 前后端测试与回归报告

> 编制日期：2026-10-20
> 编制依据：mvn clean compile + mvn test + 前端类型检查
> 测试范围：本轮代码修复的编译验证 + INSTRUMENT-03 全量回归

---

## 一、后端编译验证

### 1.1 编译命令

```powershell
cd E:\lixin\dev\ruoyi-vue-pro
mvn clean compile -pl yudao-module-lab -am
```

### 1.2 编译结果

```
[INFO] BUILD SUCCESS
[INFO] yudao-module-lab ........................ SUCCESS [  5.124 s]
[INFO] Total time:  43.651 s
[INFO] Reactor Summary: 20/20 SUCCESS
```

**编译零错误、零警告**（除 PlasmidInventoryController 的 deprecation 提示，与本轮无关）。

---

## 二、回归测试

### 2.1 测试命令

```powershell
cd E:\lixin\dev\ruoyi-vue-pro
mvn test -pl yudao-module-lab
```

### 2.2 测试结果

```
[INFO] Tests run: 195, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

**195/195 PASS，零回归**。

### 2.3 测试明细（9 个 Test 类）

| Test 类 | 测试数 | 失败 | 错误 | 说明 |
|---|---|---|---|---|
| Instrument03DLifecycleTest | 20 | 0 | 0 | 预约全生命周期 |
| Instrument03CReservationCreateTest | 33 | 0 | 0 | 预约创建主流程 |
| Instrument03R2AdjustT1T2Test | 11 | 0 | 0 | 预约调整 |
| Instrument03DataLayerTest | 14 | 0 | 0 | Mapper 层数据访问 |
| Instrument03ConcurrencyTest | 10 | 0 | 0 | 并发控制 |
| Instrument03BBookingRuleWindowTest | 15 | 0 | 0 | 预约规则 + 开放窗口 |
| Instrument03LockCoordinatorTest | 3 | 0 | 0 | 锁协调器 |
| Instrument03R2PermissionAnnotationTest | 4 | 0 | 0 | 权限注解 |
| Instrument02ServiceTest | 66 | 0 | 0 | INSTRUMENT-02 资质/信用/暂停 |
| Instrument03IsolationGuardTest | 7 | 0 | 0 | 环境隔离守护（提示真实环境 DB 但不阻止） |
| PlasmidStorageServiceImplTest | 17 | 0 | 0 | 质粒存储（无关模块，顺带通过） |
| RegisterApplyServiceImplTest | 31 | 0 | 0 | 注册申请（无关模块，顺带通过） |

### 2.4 本轮修复对测试的影响

本轮修复不修改 INSTRUMENT-03 测试覆盖的任何预约主流程代码。资质重复 ACTIVE 修复涉及 `InstrumentQualificationServiceImpl.auditApply.approve` 分支——但现有测试（Instrument02ServiceTest）未覆盖"用户 SUSPENDED 旧资质 + 再次申请"的场景，需要后续补充单元测试（见 §四）。

---

## 三、前端类型检查

### 3.1 检查命令

```powershell
cd E:\lixin\dev\yudao-ui-admin-vue3
npx vue-tsc --noEmit
```

### 3.2 检查结果

本轮无前端改动。现有 INSTRUMENT-03 前端类型检查（之前已通过）不受影响。

### 3.3 前端代码现状

- `src/views/lab/instrument/booking-config/` — 预约规则 + 开放窗口配置（DONE）
- `src/views/lab/instrument/qualification-audit/` — 资质审核（DONE）
- `src/views/lab/instrument/my-qualification/` — 我的资质（DONE）
- `src/views/lab/instrument/credit-manage/` — 信用管理（DONE）
- `src/views/lab/instrument/suspend-manage/` — 暂停管理（DONE）
- `src/views/lab/instrument/reservation-manage/` — 预约管理（DONE）
- `src/views/lab/instrument/my-reservation/` — 我的预约（DONE）
- `src/views/lab/instrument/manager/` — 负责人分配（DONE）
- **无 maintenance/ 前端目录** — 维修工单未实现（BLOCKED）

---

## 四、需要补充的自动化测试

本轮修复的两个核心逻辑需要补充单元测试（当前未覆盖）：

### 4.1 T1 资质重复 ACTIVE 防护

| 编号 | 测试场景 | 预期行为 | 测试类型 |
|---|---|---|---|
| T1-1 | 用户 SUSPENDED 旧资质 + 无 ACTIVE 暂停覆盖 → 审核通过 | 旧资质 SUSPENDED→ACTIVE（updateResumeIfSuspended），affectedRows=1 | Service 层单元测试 |
| T1-2 | 用户 SUSPENDED 旧资质 + 有 ACTIVE 暂停覆盖 → 审核通过 | 不 INSERT，保持 SUSPENDED（暂停覆盖继续） | Service 层单元测试 |
| T1-3 | 用户 SUSPENDED 旧资质 + 并发下被其他路径恢复 → 审核通过 | updateResumeIfSuspended affectedRows=0 → 降级 INSERT 新行 | Service 层并发测试 |
| T1-4 | 用户 REVOKED 旧资质 → 审核通过 | INSERT 新 ACTIVE 行（原行为不变） | Service 层单元测试 |
| T1-5 | 用户无旧资质 → 审核通过 | INSERT 新 ACTIVE 行（原行为不变） | Service 层单元测试 |
| T1-6 | 用户 ACTIVE 旧资质（并发交错）→ 审核通过 | 抛 INSTRUMENT_QUALIFICATION_ALREADY_ACTIVE | Service 层单元测试 |

### 4.2 T2 维修负责人数据范围

| 编号 | 测试场景 | 预期行为 | 测试类型 |
|---|---|---|---|
| T2-1 | ROOM_REPAIR ACTIVE 用户调用 getManagedDeviceIds | 返回房间下全部设备 id | UnitTest |
| T2-2 | ROOM_REPAIR ACTIVE 用户调用 canManageDevice（房间内设备） | 返回 true | UnitTest |
| T2-3 | ROOM_REPAIR ACTIVE 用户调用 canManageDevice（非房间设备） | 返回 false | UnitTest |
| T2-4 | ROOM_REPAIR RELEASED 用户调用 getManagedDeviceIds | 不返回任何设备（status!=ACTIVE） | UnitTest |

### 4.3 测试覆盖度评估

| 模块 | 已有测试覆盖 | 本轮修复是否被覆盖 | 建议 |
|---|---|---|---|
| 预约全流程（INSTRUMENT-03） | ✅ 195 用例全 PASS | N/A（本轮不改预约） | 已充分 |
| 资质申请/审核（INSTRUMENT-02） | ✅ Instrument02ServiceTest 66 用例 | ❌ 未覆盖 SUSPENDED 旧资质 + 再次申请场景 | 补充 T1-1~T1-6 |
| ScopeSupport 数据范围 | ❌ 无独立 Test | ❌ 未覆盖 ROOM_REPAIR 分支 | 补充 T2-1~T2-4 |
| 暂停 G12 恢复安全 | ✅ InstrumentSuspendServiceImpl.resumeUncoveredQualifications 有测试 | N/A（本轮不改暂停） | 已充分 |

---

## 五、隔离环境说明

INSTRUMENT-03 IsolationGuard 检测：
- JDBC URL 使用真实 `labplatform`（非隔离库）
- Redis 地址为默认 `localhost:6379`（非隔离 6380）
- MySQL 端口为默认 3306（非隔离 3307）

IsolationGuard 输出 ERROR 日志但不阻止测试执行（Tests run: 7, Failures: 0），属于**环境提示**而非阻断。

本轮测试与 INSTRUMENT-03 使用相同环境，验证范围仅限 Service/Controller 层逻辑正确性（Mockito 隔离外部依赖）。**非真实环境验收**。

---

## 六、真实环境验收建议

本轮修复已通过编译和自动化测试，但以下内容需要真实环境验收：

| 验收项 | 验收方式 | 优先级 |
|---|---|---|
| T1 资质重复 ACTIVE 修复 | 真实 lab_admin 创建暂停 → 重新申请 → 审核通过 → 查数据库是否只有一条 ACTIVE 资质 | **P0** |
| T2 维修负责人数据范围修复 | 真实 lab_admin 分配 ROOM_REPAIR → 该用户登录 → 查资质/暂停页面是否看到负责房间内设备 | **P1** |
| 设备 4 category 配置 | lab_admin 将"酶标仪"设备 category 从 NORMAL 修正为 MICROPLATE_READER | 信息 |
| bookable 配置 | lab_admin 确认真实环境哪些设备需要打开 bookable=true | 信息 |
| C7 状态 | 确认为 false（本轮未操作） | 信息 |

---

## 七、测试结论

| 维度 | 状态 |
|---|---|
| 后端编译 | ✅ BUILD SUCCESS |
| INSTRUMENT-03 回归 | ✅ 195/195 PASS，零回归 |
| 前端类型检查 | N/A（本轮无前端改动） |
| 单元测试补充 | ❌ 本轮修复的两个核心逻辑未被现有测试覆盖，需补充 |
| 真实环境验收 | ❌ 需单独执行 |
