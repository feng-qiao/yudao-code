# 40 - INSTRUMENT-03 正式菜单部署前最终只读预检报告

- 任务号：`TASK INSTRUMENT-03-R5-PRECHECK-ONLY-01`
- 执行模式：**PRECHECK ONLY（仅阶段 P，未进入阶段 E）**
- 生成日期：2026-10-19
- 目标数据库：`labplatform`（真实库）
- 权威 SQL 设计稿：`E:\lixin\dev\ruoyi-vue-pro\sql\lab\20261016_instrument_03b_booking_config_menu_design.sql`
- 参考报告：37 号《INSTRUMENT-03 正式部署准备与业务验收报告》、39 号《INSTRUMENT-03 菜单闭环与正式部署授权前复核报告》
- 最终判定：**PASS / WAITING FOR MENU DEPLOY AUTHORIZATION**

> 本报告所有数据库结论均来自本轮（2026-10-19）现场只读查询，未复用 37/39 号报告的任何历史 PASS 结论。所有语句均为 SELECT / SHOW / information_schema，执行次数中的写入语句为 **0**。

---

## 0. 本轮操作边界与零写入证据

### 0.1 已执行（允许范围内）
- 只读 SELECT / SHOW / information_schema 查询（目标库 `labplatform`）；
- 源码只读核验（后端 Permission/Tenant/Menu 服务、前端组件与动态路由）；
- SQL 设计稿静态分析（全文件通读 + 危险关键字 grep）；
- 本地非破坏性探测（TCP 端口检查、HTTP 只读 GET 探活、`mysqldump --version`）；
- 生成本报告。

### 0.2 未执行（严格禁止项，逐条确认）
| 序号 | 禁止项 | 本轮状态 |
| --- | --- | --- |
| 1 | 正式库 INSERT / UPDATE / DELETE / DDL | 未执行（0 写入） |
| 2 | 执行 13674~13683 菜单 SQL | 未执行 |
| 3 | 修改 system_menu / system_role_menu / system_tenant_package | 未执行 |
| 4 | 正式 Redis 写入、DEL、FLUSHDB、FLUSHALL | 未执行（未连接） |
| 5 | 通过后台 UI 保存菜单 / 角色 / 套餐 | 未执行 |
| 6 | 开启 C7 | 未执行（`create-enabled` 仍为默认 false） |
| 7 | 创建 / 修改 / 取消任何正式预约 | 未执行 |
| 8 | 修改业务代码 / SQL 设计稿 / 配置 | 未执行（设计稿本轮未改动） |
| 9 | 重启后端或中断负责人 IDEA 进程 | 未执行（PID 41788 未触碰） |
| 10 | 创建 / 启动 / 删除 Docker 容器 | 未执行 |
| 11 | 执行备份 / 恢复 | 未执行（仅检查工具与目录） |
| 12 | 预检通过后自动进入部署 | 未执行（本报告生成后立即停止） |

### 0.3 零写入自证
- 所有 `labplatform` 连接均使用只读语句，无任何 `INSERT/UPDATE/DELETE/REPLACE/ALTER/DROP/TRUNCATE/CREATE`；
- 事务均未开启（无 `START TRANSACTION`、无 `COMMIT`）；
- Redis 未建立连接，未执行任何命令；
- SQL 设计稿文件在本轮未被写入或修改。

---

## 1. P1 正式库只读检查

### 1.1 环境与 ID 段
| 检查项 | 本轮实测结果 | 预期值 | 判定 |
| --- | --- | --- | --- |
| MySQL 版本 | **8.0.12** | 知晓版本以判定 JSON 兼容性 | PASS |
| `SELECT MAX(id) FROM system_menu` | **13673** | 13673（13674 起空闲） | PASS |
| 13674~13683 空闲性 | 逐 ID 查询 `id BETWEEN 13674 AND 13683 AND deleted=b'0'` = **0 行** | 全部空闲 | PASS |

### 1.2 结构冲突检查
| 检查项 | 本轮实测结果 | 预期值 | 判定 |
| --- | --- | --- | --- |
| 父菜单 13600 有效性 | `id=13600 AND type=1 AND status=0 AND deleted=b'0'` = **1 行** | 1 | PASS |
| path 冲突 | `booking-config` / `reservation-manage` / `my-reservation`（parent=13600）均 **0 行** | 0 | PASS |
| component 冲突 | `lab/instrument/booking-config/index`、`.../reservation-manage/index`、`.../my-reservation/index` 全库均 **0 行** | 0 | PASS |
| permission 冲突 | `lab:instrument:rule:%` **0 行**；`lab:instrument:reservation%` **0 行** | 0 | PASS |

### 1.3 角色有效性（租户 162）
| 角色 | 本轮实测 | 预期 | 判定 |
| --- | --- | --- | --- |
| 904 普通用户 | `tenant_id=162 AND status=0 AND deleted=b'0'` 存在 | 存在且有效 | PASS |
| 905 库管员 | 存在且有效；目标菜单授权 **0 行** | 存在、不新增授权 | PASS |
| 906 lab_admin | 存在且有效 | 存在且有效 | PASS |
| 908 仪器设备负责人 | 存在且有效 | 存在且有效 | PASS |

### 1.4 套餐 114
| 检查项 | 本轮实测结果 | 预期值 | 判定 |
| --- | --- | --- | --- |
| 存在性与状态 | `id=114 AND status=0 AND deleted=b'0'` = **1 行** | 1 | PASS |
| menu_ids JSON 合法性 | `JSON_VALID(menu_ids)=1`；首字符 `[`、末字符 `]`；长度 **1462** | 合法 JSON 数组 | PASS |
| 是否已含目标 10 个 ID | 13674~13683 逐个 `JSON_CONTAINS(CAST(menu_ids AS JSON),'NNNNN')` = **0** | 全部未含 | PASS |
| 引用租户数 | `tenants_using_114` = **1**（仅租户 162） | 单租户，无跨租户溢出 | PASS |
| 现有菜单数 | `JSON_LENGTH(menu_ids)` = **341** | 背景值 | PASS |

### 1.5 role_menu 残留与重复
| 检查项 | 本轮实测结果 | 预期值 | 判定 |
| --- | --- | --- | --- |
| 目标菜单残留授权 | `menu_id BETWEEN 13674 AND 13683 AND deleted=b'0'` = **0 行** | 0 | PASS |
| 905 目标行 | 905 对 13674~13683 授权 = **0 行** | 0 | PASS |
| (role_id,menu_id) 重复 | 全表分组查询无重复组合 | 无 | PASS |
| tenant_id 分组残留 | 无异常 tenant_id 分组 | 无 | PASS |
| 角色现有授权数 | 906=**113**、904=**27**、908=**8** | 背景值 | PASS |
| 授权 ⊆ 套餐 | `r906_not_in_pkg=0`、`r904_not_in_pkg=0`（现有授权均落在套餐 114 内） | 0 | PASS |

### 1.6 三张目标表结构（information_schema）
| 表 | 关键结构（本轮实测） | 与设计稿一致性 | 判定 |
| --- | --- | --- | --- |
| `system_menu` | PRIMARY KEY(`id`) 唯一；**无 tenant_id 列**（全局表）；`deleted` bit(1) default b'0'；`permission` varchar(100) NOT NULL；`component` varchar(255) | 一致 | PASS |
| `system_role_menu` | 有 `tenant_id` bigint NOT NULL default 0；索引仅 PRIMARY(`id`) + `idx_role_id`(`role_id`)；**无 (role_id,menu_id) 唯一索引** → 防重必须依赖 NOT EXISTS（设计稿已如此） | 一致 | PASS |
| `system_tenant_package` | `menu_ids` text NOT NULL（JSON 文本数组） | 一致（设计稿用 CAST AS JSON 兼容） | PASS |
| 引擎 | 三表均 InnoDB | 一致 | PASS |

**P1 小结：全部 11 项 PASS，无 HOLD 触发项。**

---

## 2. P2 SQL 设计稿最终核验

已完整通读设计稿（481 行）：§0~§4（13674~13676）、§5~§6（事务/回滚/执行顺序）、附录 A（13677~13682）、附录 B（13683）。

| 序号 | 核验点 | 实测结论 | 判定 |
| --- | --- | --- | --- |
| 1 | 附录 A `RIGHT()` 语法错误已修复 | A.0（第 306 行）与 A.2（第 339 行）均为 `RIGHT(menu_ids,1)=']'`；原 `']='` 颠倒写法已修正，并在注释中留痕 | PASS |
| 2 | `JSON_CONTAINS` 第二参数为字符串形式 | 全部 7 处（§2×3、A.2×2、B.2×1、B.4×1）均为 `'NNNNN'` 字符串；与 MySQL 8.0.12 兼容（整数直接量会报 ERROR 3146） | PASS |
| 3 | 目标菜单 ID 唯一 | 13674~13683 连续且互不重复；§/A/B 三段无 ID 交叉 | PASS |
| 4 | INSERT/UPDATE 幂等守卫 | 所有菜单 INSERT：`EXISTS(父菜单有效) AND NOT EXISTS(目标 id)`；所有套餐 UPDATE：`括号格式 AND NOT JSON_CONTAINS(...) AND EXISTS(菜单有效)`；所有 role_menu INSERT：`EXISTS(角色有效) AND EXISTS(菜单有效) AND NOT EXISTS(同角色同菜单同租户)` | PASS |
| 5 | 角色菜单写入显式 `tenant_id=162` | §3、A.3、B.3 三条 INSERT 均显式写入 `162` | PASS |
| 6 | 套餐 114 更新条件正确 | 每条 UPDATE 均含 `id=114 AND deleted=b'0' AND LEFT/ RIGHT 括号守卫` | PASS |
| 7 | 阶段二预检仅阶段一提交后成立 | A.0 断言 `MAX(id)=13676`，并显式注明依赖阶段一完成 | PASS |
| 8 | 阶段三预检仅阶段二提交后成立 | B.0 断言 `MAX(id)=13682`，并显式注明依赖阶段二完成 | PASS |
| 9 | 每阶段失败可停止、不自动继续 | §0/A.0/B.0 均注明「任一不符【停止】」；§6 第 9 条要求分阶段执行、禁止跳段/并行 | PASS |
| 10 | 跨阶段已提交事务不可靠最后一次 ROLLBACK 整体撤销 | §6 第 9 条明确「分阶段提交后任一阶段失败，已提交阶段无需回滚，凭幂等守卫可安全重跑失败阶段」 | PASS |
| 11 | 无意外 DDL / DELETE / TRUNCATE / 扩大范围 UPDATE | 危险关键字 grep 命中 56 行**全部为误报**（`deleted=b'0'` 条件、注释文本、§6 第 2 条历史说明引用）；全文仅 INSERT/UPDATE/SELECT | PASS |
| 12 | 权限矩阵符合 39 号报告 | 见第 4 节，逐角色逐权限比对一致 | PASS |

### 2.1 观察项（非阻断）
- **A.2 部分状态理论边界**：A.2 单条 UPDATE 同时追加 6 个 ID，守卫要求 13677 与 13682 **同时**不存在。由于该语句在单事务内原子执行，正常流程不会出现「部分写入」；若发生人工干预导致的半状态，重复执行会重新追加全部 6 个 ID 而可能产生 JSON 重复项。属理论边界，不影响本轮 PASS，建议在执行纪律中禁止手工拆分该语句。
- **§6 第 2 条历史 DDL 说明**：CAP-A 容量账本设计稿已整体废弃且「均不得执行」，本条为保留备查的历史文本，非可执行语句。

**P2 小结：12/12 PASS。**

---

## 3. P3 部署影响范围与权限矩阵

### 3.1 预期新增菜单（10 条，13674~13683）
| ID | 名称 | type | parent | sort | path | component / permission |
| --- | --- | --- | --- | --- | --- | --- |
| 13674 | 预约配置 | 2 | 13600 | 18 | booking-config | `lab/instrument/booking-config/index` |
| 13675 | 规则查询 | 3 | 13674 | 1 | — | `lab:instrument:rule:query` |
| 13676 | 规则配置 | 3 | 13674 | 2 | — | `lab:instrument:rule:update` |
| 13677 | 预约管理 | 2 | 13600 | 19 | reservation-manage | `lab/instrument/reservation-manage/index` |
| 13678 | 预约查询 | 3 | 13677 | 1 | — | `lab:instrument:reservation:query` |
| 13679 | 预约创建 | 3 | 13677 | 2 | — | `lab:instrument:reservation:create` |
| 13680 | 预约取消 | 3 | 13677 | 3 | — | `lab:instrument:reservation:cancel` |
| 13681 | 预约调整 | 3 | 13677 | 4 | — | `lab:instrument:reservation:adjust` |
| 13682 | 预约管理操作 | 3 | 13677 | 5 | — | `lab:instrument:reservation:manage` |
| 13683 | 我的预约 | 2 | 13600 | 20 | my-reservation | `lab/instrument/my-reservation/index` |

### 3.2 权限矩阵（设计稿 = 部署预期）
| 菜单 \ 角色 | 904 普通用户 | 905 库管员 | 906 lab_admin | 908 设备负责人 |
| --- | :-: | :-: | :-: | :-: |
| 13674~13676（预约配置/规则） | — | — | ✓ 3 | — |
| 13677 预约管理（页面） | ✓ | — | ✓ | ✓ |
| 13678 query | ✓ | — | ✓ | ✓ |
| 13679 create | ✓ | — | ✓ | ✓ |
| 13680 cancel | ✓ | — | ✓ | ✓ |
| 13681 adjust | ✓ | — | ✓ | ✓ |
| 13682 manage | **—** | - | ✓ | ✓ |
| 13683 我的预约 | ✓ | — | ✓ | ✓ |
| 合计新增 | 6 | 0 | 10 | 7 |

### 3.3 复核结论
| 复核点 | 结论 | 判定 |
| --- | --- | --- |
| 904 不具有 `reservation:manage`（13682） | A.3 授权集合中 904 仅含 13677~13681，无 13682 | PASS |
| 908 不具有 `rule:update`（13676） | §3 仅授权 906；A/B 段不含 13676；908 全程未获 rule 权限 | PASS |
| 906 保持管理员授权（13674~13683 全部） | 906 获得全部 10 个目标菜单 | PASS |
| 905 不新增预约相关授权 | 905 在 §3/A.3/B.3 中零出现；实测目标行 0 | PASS |
| 不影响其他租户 | **辨析见下** | PASS（附条件说明） |
| 不覆盖其他已有角色菜单关系 | 设计稿仅 INSERT 目标 (role,menu) 组合，不改动既有行；无 UPDATE/DELETE role_menu | PASS |
| 不改变历史业务数据 | 三表操作限定为菜单/套餐/角色授权，不触碰业务表 | PASS |

> **「不影响其他租户」重要辨析（如实披露）**：
> 租户 1 为**系统租户**（`package_id=0` = `TenantDO.PACKAGE_ID_SYSTEM`）。`TenantServiceImpl.handleTenantMenu` 对系统租户返回**全量菜单**（`menuService.getMenuList()` 不过滤套餐）。因此新增的 10 条菜单行会**出现在租户 1 的菜单树中**（可见性层面）。
> 但设计稿的 role_menu 写入**仅显式 `tenant_id=162`**，**不向租户 1 任何角色授予权限**；且租户 1 无 lab_admin 等业务角色。故：
> - **授权层面**：不影响/不扩权其他租户 —— 不影响结论成立；
> - **可见性层面**：系统租户菜单树会包含新菜单条目 —— 属平台既有设计（系统租户即全量菜单语义），非本次部署引入的越权。
> 结论：判定为 PASS，但负责人须知悉该「可见性 vs 授权」差异。

### 3.4 影响行数口径复核（对照 39 号报告的「最多 38 行」）
| 类别 | 明细 | 行数 |
| --- | --- | --- |
| 菜单 INSERT | 13674~13683 | **10** |
| 套餐 UPDATE 匹配行 | §2（3 条，13674/13675/13676）+ A.2（1 条，6 ID）+ B.2（1 条，13683） | **5** |
| role_menu INSERT | §3：906×3=3；A.3：904×5 + 906×6 + 908×6=17；B.3：904/906/908×1=3 | **23** |
| **合计** | | **38** |

**复核结论**：38 行口径**正确，无需修正**。区分为——「菜单新增行」10、「UPDATE 匹配行」5、「role_menu 新增行」23。未发现为凑 38 行而修改数据库的行为（本轮零写入）。

---

## 4. 904 / 906 / 908 / 905 权限矩阵与一致性

对照 39 号报告矩阵逐条比对，设计稿（§3 / A.3 / B.3）与之**完全一致**：

- 904：13674~13676（无）、13677~13681（有）、13682（无）、13683（有）→ 新增 **6**；
- 905：全部无 → 新增 **0**；
- 906：13674~13683 全有 → 新增 **10**；
- 908：13677~13682、13683 有，13674~13676 无 → 新增 **7**。

与 39 号报告 §3/§4 矩阵对齐，无偏差。

---

## 5. P4 备份与回滚可执行性检查（仅检查，未执行）

| 检查项 | 实测结果 | 判定 |
| --- | --- | --- |
| mysqldump 是否存在 | 存在 | PASS |
| 版本适配性 | **8.4.11**（服务端 8.0.12，客户端高于服务端一个次版本） | **注意项** |
| 备份参数正确性 | 需针对 8.4 客户端做兼容处理（见下） | 注意项 |
| 三表是否可备份 | `system_menu / system_tenant_package / system_role_menu` 均可被 mysqldump 导出（DML 表） | PASS |
| 备份目录是否存在且可写 | `E:\lixin\dev\backup` **不存在**；`E:\lixin\dev\ruoyi-vue-pro\sql\lab`、`C:\temp` 存在 | **注意项** |
| 命名是否防覆盖 | 需包含时间戳（见下建议） | 注意项 |
| 是否有恢复操作说明 | 设计稿 §6 第 5 条含兜底回滚说明（mysqldump 三表），恢复步骤需补充显式命令 | 部分（建议补充） |
| 跨阶段部分提交处理流程 | §6 第 9 条明确：已提交阶段无需回滚，凭幂等守卫重跑失败阶段 | PASS |

### 5.1 账号权限注意
连接账号 `bencao@localhost` 仅持有 `GRANT ALL PRIVILEGES ON labplatform.*` + `USAGE`，**无 PROCESS / RELOAD 等全局权限**。mysqldump 8.4 在默认参数下可能需要 `PROCESS`（用于 `--single-transaction` 一致性）或访问 tablespace 信息，**建议追加 `--no-tablespaces`、`--single-transaction`、`--skip-lock-tables` 以规避权限不足**。

### 5.2 部署阶段建议使用的备份命令（本轮【未运行】）
```
# 备份目录（部署前需先创建）
mkdir E:\lixin\dev\backup   # 或改用已存在的 E:\lixin\dev\ruoyi-vue-pro\sql\lab

# 建议命令（时间戳命名，防覆盖；--no-tablespaces 规避权限不足）
"C:\<mysql8.4路径>\bin\mysqldump" -h localhost -u bencao -p --no-tablespaces --single-transaction --skip-lock-tables --default-character-set=utf8mb4 --set-gtid-purged=OFF labplatform system_menu system_tenant_package system_role_menu > E:\lixin\dev\backup\instrument03_menu_backup_20261019_HHMMSS.sql
```
- 跨版本兼容建议：若 8.4 客户端产出与 8.0.12 服务端不兼容，可改用**服务端自带 8.0 版 mysqldump**，或使用 `SELECT ... INTO OUTFILE` / 逻辑导出替代（需另行评估权限）。
- 恢复流程（需负责人授权后执行）：
  1. 停止相关写入活动；
  2. 按阶段判断受损范围（菜单 / 套餐 / 角色授权）；
  3. 对受损表执行备份回灌（`source backup.sql`）或按幂等守卫重跑失败阶段；
  4. 重新登录验证权限（重新登录触发 permission 缓存重建）。

**P4 小结：工具与表可达性 PASS；存在「mysqldump 跨版本 + 备份目录缺失 + 账号全局权限不足」三项需在部署阶段规避的注意项（非 HOLD）。**

---

## 6. P5 Redis 权限缓存失效方案安全性复核

> 本节未连接正式 Redis、未执行任何 Redis 命令，仅源码核验。

### 6.1 缓存键与 TTL（源码证据）
- `permission_menu_ids:{permission}`：全局键，位于 `ignore-caches` 内；
- `menu_role_ids:{tenantId}:{menuId}`：**带租户后缀**，不在 `ignore-caches`；
- `user_role_ids:{userId}`、`role:{id}`；
- TTL = **1h**（`spring.cache.redis.time-to-live: 1h`）；
- `YudaoCacheAutoConfiguration` 开启 `setTransactionAware(true)`：`@Transactional` 内的 `@CacheEvict` 延迟至 afterCommit 执行。

### 6.2 @CacheEvict 触发点
| 触发方法 | evict 目标 |
| --- | --- |
| `MenuServiceImpl.updateMenu / deleteMenu` | `PERMISSION_MENU_ID_LIST` allEntries |
| `PermissionServiceImpl.assignRoleMenu` | `MENU_ROLE_ID_LIST` + `PERMISSION_MENU_ID_LIST` allEntries |
| `PermissionServiceImpl.processRoleDeleted` | `MENU_ROLE_ID_LIST` + `USER_ROLE_ID_LIST` allEntries |
| `PermissionServiceImpl.processMenuDeleted` | `MENU_ROLE_ID_LIST`，key=menuId |

### 6.3 核心问题：**直接通过后台保存 904/906/908 的菜单权限，是否可能意外删除原有授权？**

**答：存在真实删除风险。** 依据 `assignRoleMenu` 完整语义（非仅注解）：

```
dbMenuIds     = 该角色已有 role_menu
createMenuIds = 提交集合 - 已有     → insertBatch
deleteMenuIds = 已有 - 提交集合     → deleteListByRoleIdAndMenuIds   ← 删除既有授权
```

即**未包含在提交集合中的既有授权会被删除**。前端保存路径提交的是「套餐过滤后菜单树的 checkedKeys」，因此：
- 若管理员在保存时**勾选不全**（漏勾），会删除漏勾项的既有授权；
- 若**全树勾选**提交，则不删除（因 904/906/908 现有授权均 ⊆ 套餐 114，实测 `not_in_pkg=0`，套餐追加成功后树应覆盖全部既有 + 新增）。

结论：**该路径是否安全取决于管理员操作，A 方案不可无条件推荐。**

### 6.4 缓存失效方案（优先级明确）
| 方案 | 描述 | 风险 | 推荐度 |
| --- | --- | --- | --- |
| **B. TTL 自然到期** | 不触任何缓存操作，等待 ≤1h 自动重建 | 无写入、无授权变更风险；仅延迟生效 | **无条件安全首选** |
| A. 应用层失效 | 经「**菜单管理**」无变更保存（仅 evict `PERMISSION_MENU_ID_LIST`，**不触碰 role_menu**）或由授权保存触发 evict | 菜单管理保存低风险；但**角色授权保存会走 assignRoleMenu → 可能删除既有授权** | **条件性方案，须附前置条件，不作为无条件推荐** |
| C. 精确 Redis 清理 | 针对 `permission_menu_ids:*` / `menu_role_ids:162:*` 精确 DEL | 需**另行授权**；误删/误操作风险 | 需另行授权，作为 B 的加速替代 |

**A 方案前置条件（必须同时满足方可采用）**：① 通过「菜单管理」而非「角色管理」保存；② 保存前确认无变更；③ 若确需角色授权保存，必须保证提交集合 ⊇ 该角色全部既有授权。
**若 A 方案无法证明安全，则不得列为无条件推荐** —— 本报告据此将 B 列为无条件首选。

**P5 小结：源码证据充分，「后台保存角色菜单存在删除既有授权风险」结论成立；推荐优先级 B > C > A（附条件）。**

---

## 7. P6 前端菜单与页面只读核验

| 检查项 | 实测结果 | 判定 |
| --- | --- | --- |
| 13674 预约配置组件 | `lab/instrument/booking-config/index`；`defineOptions({ name:'LabInstrumentBookingConfig' })`（第 305 行） | PASS |
| 13677 预约管理组件 | `lab/instrument/reservation-manage/index`；`name:'LabInstrumentReservationManage'`（第 135 行） | PASS |
| 13683 我的预约组件 | `lab/instrument/my-reservation/index`；`name:'LabInstrumentMyReservation'`（第 97 行） | PASS |
| component_name 一致性 | 三个组件 name 与设计稿 component_name **逐字一致** | PASS |
| 动态路由解析 | `routerHelper.ts` glob `../views/**/*.{vue,tsx}` + registerComponent；菜单 component 字符串可匹配 | PASS |
| 904/906/908 权限与页面功能 | 我的预约：getMy 列表 + 详情 + 取消（canCancel 单闸）+ 调整（canAdjust + `v-hasPermi['lab:instrument:reservation:adjust']` 双闸）+ 历史入口；预约管理：分页筛选 + canFinish/canVoid 单闸 + adjust 双闸 | PASS |
| 我的预约四入口（列表/调整/取消/历史） | 均存在 | PASS |
| 前端代码修改 | **未修改** | PASS |

**P6 小结：全部 PASS，前端未改动。**

---

## 8. P7 C7 与后端运行状态

| 检查项 | 实测结果 | 判定 |
| --- | --- | --- |
| 后端监听 48080 | 端口 open = True | PASS |
| local profile 正常 | local 生效（application-local.yaml） | PASS |
| C7 配置来源 | `lab.instrument.reservation.create-enabled` 仅存在于 `application-instrument-03-test.yaml:61`（隔离测试 profile） | PASS |
| local 生效值 | `application.yaml` / `application-local.yaml` **均无该键** → 生效值 = 默认 **false** | PASS |
| 是否启用隔离测试 profile | 未启用（隔离 profile 未激活） | PASS |
| 后端只读响应 | `GET /admin-api/lab/instrument/reservation/my` 返回 **HTTP 200 + `{"code":401,"msg":"账号未登录"}`** → 进程存活、Security 正常拦截、只读链路可用 | PASS |
| 运行进程 | java PID **41788**（另见 34812/36188/46644，未触碰） | PASS |
| 是否重启后端 / 改配置 | **未重启、未修改 application-local.yaml** | PASS |
| 是否调用写接口 | **未调用**（create/adjust/cancel/finish/void 均未触发） | PASS |

**P7 小结：全部 PASS。C7 当前为关闭状态（create-enabled=false）。**

---

## 9. 预期数据库影响行数

| 类别 | 行数 |
| --- | --- |
| 菜单 INSERT | 10（13674~13683） |
| 套餐 UPDATE 匹配行 | 5（3+1+1） |
| role_menu INSERT | 23（906:3；904:5 / 906:6 / 908:6；904/906/908 各 1） |
| **合计** | **38** |

重复执行（幂等）全部为 **0 行**。

---

## 10. 未解决问题及阻断条件

### 10.1 未解决 / 需负责人知悉项（非阻断）
| 编号 | 事项 | 影响 | 建议 |
| --- | --- | --- | --- |
| N1 | 备份目录 `E:\lixin\dev\backup` 不存在 | 部署阶段无法直接落盘备份 | 部署前创建目录或改用 `sql\lab` / `C:\temp` |
| N2 | mysqldump **8.4.11** vs 服务端 **8.0.12**（跨次版本） | 备份/回滚兼容性不确定 | 建议加 `--no-tablespaces --single-transaction`，或改用 8.0 版客户端 |
| N3 | `bencao` 账号无 PROCESS/RELOAD 全局权限 | mysqldump 部分默认行为可能失败 | 加 `--no-tablespaces`；必要时由负责人授予最小全局权限 |
| N4 | 后台「角色菜单保存」可能删除既有授权（见 §6.3） | 部署后缓存刷新方式需谨慎选择 | 优先 B（TTL）；如用 A 须满足 §6.4 前置条件 |
| N5 | 租户 1（系统租户）菜单树将包含新菜单条目（可见性） | 非越权，但须负责人知悉 | 属平台既有语义，无需处理 |
| N6 | 设计稿 A.2 单语句追加 6 ID 的理论半状态边界（见 §2.1） | 理论，不阻断 | 禁止手工拆分该语句 |

### 10.2 阻断条件评估
**当前无未修复的阻断项。** 上述 N1~N6 均为「部署阶段需规避/知悉」的注意项，未构成必须先行修复才能进入部署的 HOLD 条件。

---

## 11. 最终判定

**PASS / WAITING FOR MENU DEPLOY AUTHORIZATION**

- P1（正式库只读检查）：11/11 PASS
- P2（SQL 设计稿核验）：12/12 PASS
- P3（影响范围与权限矩阵）：全部 PASS，38 行口径正确
- P4（备份与回滚检查）：工具/表可达 PASS，3 项注意项
- P5（缓存安全性）：结论成立，推荐 B > C > A（A 附条件）
- P6（前端核验）：全部 PASS
- P7（C7 与后端状态）：全部 PASS，C7 关闭

全部预检通过，**尚未获得正式菜单部署授权**。

> 本报告**不构成任何部署授权**；**不得**据此进入阶段 E（正式部署）。
> 完成报告后**立即停止**，等待负责人下一步裁决。

---

## 附：本轮只读查询清单（节选）

```sql
-- 环境
SELECT VERSION();
SELECT MAX(id) AS max_id FROM system_menu;
SELECT id,name,permission FROM system_menu WHERE id BETWEEN 13674 AND 13683 AND deleted=b'0';
SELECT COUNT(*) FROM system_menu WHERE id=13600 AND type=1 AND status=0 AND deleted=b'0';
SELECT id,name,permission FROM system_menu WHERE permission LIKE 'lab:instrument:rule%' AND deleted=b'0';
SELECT id,name,permission FROM system_menu WHERE permission LIKE 'lab:instrument:reservation%' AND deleted=b'0';
SELECT id,code,tenant_id,status FROM system_role WHERE id IN (904,905,906,908);
SELECT id,status,deleted,LEFT(menu_ids,1),RIGHT(menu_ids,1),JSON_VALID(menu_ids),JSON_LENGTH(menu_ids)
  FROM system_tenant_package WHERE id=114;
SELECT JSON_CONTAINS(CAST(menu_ids AS JSON),'13683') FROM system_tenant_package WHERE id=114;   -- 0
SELECT role_id,COUNT(*) FROM system_role_menu WHERE tenant_id=162 AND menu_id BETWEEN 13674 AND 13683 GROUP BY role_id;
-- 结构
SELECT TABLE_NAME,ENGINE FROM information_schema.TABLES
  WHERE TABLE_SCHEMA='labplatform' AND TABLE_NAME IN
  ('system_menu','system_role_menu','system_tenant_package');
SELECT TABLE_NAME,COLUMN_NAME,COLUMN_TYPE,IS_NULLABLE,COLUMN_DEFAULT FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA='labplatform' AND TABLE_NAME IN
  ('system_menu','system_role_menu','system_tenant_package');
SELECT TABLE_NAME,INDEX_NAME,NON_UNIQUE,COLUMN_NAME FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA='labplatform' AND TABLE_NAME IN
  ('system_menu','system_role_menu','system_tenant_package');
```

（以上均为只读语句；本轮对 `labplatform` 的写入语句执行次数 = 0。）
