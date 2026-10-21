-- ================================================================
-- INSTRUMENT-06 仪器维修：菜单 + 角色授权 SQL【设计稿，未执行】
-- 生成日期：2026-10-20
-- 任务：TASK INSTRUMENT-06 维修模块菜单与角色授权
-- 目标库：labplatform（MySQL 8.0.12，phpStudy）
-- 目标租户：162  ｜  目标套餐：114
--
-- 依据：
--   后端 Controller 权限串（已实现）：
--     InstrumentFaultReportController → lab:instrument:fault-report:submit / :admin
--     InstrumentRepairOrderController → lab:instrument:repair-order:handle / :admin
--   47 号盘点 / 48 号实施 / 51 号遗留清单（D11 角色权限分配）
--   39/41 号 INSTRUMENT-03 菜单部署（SQL 风格、幂等守卫、阶段化执行）
--   20261015_instrument_02_device_manager_role.sql（角色 908 创建范式）
--   58-INSTRUMENT-06数据库DDL设计稿.sql（菜单/角色/套餐三表边界，本脚本不含 DDL）
--
-- 【授权边界 / 诚实声明】（务必先读）
--   1. 本脚本由 Trae 生成，Trae【未执行】本脚本中的任何语句（含只读 SELECT），
--      未连接真实 labplatform 库执行写入；实际最大值/ID/sort/角色状态需执行人
--      在 §0 预检中逐条核对（本脚本头部常量来自 2026-10-20 快照，环境变化须改写）。
--   2. 本脚本仅为【设计稿】：须由负责人审查后【另行授权执行】。
--   3. 本脚本包含：
--        (a) 菜单 INSERT ×5（13684 页面 + 13685~13688 四个按钮）
--        (b) 新角色 INSERT ×1（909 维修负责人）
--        (c) system_role_menu 角色授权（904/906/908/909 四个角色）
--        (d) system_tenant_package 套餐 114 菜单追加（JSON_CONTAINS 幂等）
--        (e) 执行前预检（全部 SELECT）
--        (f) 执行后验收（全部 SELECT）
--        (g) 回退脚本（纯 DELETE + UPDATE）
--   4. 不含 DDL；不含 Redis 写入；不含 C7 配置；不含 system_user_role（用户分配在
--      【系统管理 → 用户管理】人工完成，脚本注释明确不自动给任何用户加角色 909）。
--   5. 幂等：所有写入均带 NOT EXISTS / JSON_CONTAINS 守卫，重复执行影响 0 行。
--   6. 环境常量（执行人须以 §0 实测核对，环境变化须改写本脚本）：
--        tenant_id = 162
--        菜单 ID 段 = 13684~13688（§0.1 实测 MAX(system_menu.id)=13683）
--        父菜单 = 13600（仪器管理，type=1，§0.4 实测存在）
--        父菜单下当前最大 sort = 20 → 新页面 sort = 21
--        目标套餐 = 114（menu_ids 当前 JSON_LENGTH=351）
--        新角色 ID = 909（§0.3 实测 system_role AUTO_INCREMENT=909）
--        已有角色 ID = 904/905/906/907/908（tenant 162，status=0）
--   7. 框架约束（决定授权集合）：yudao 前端权限集合来自
--        MenuServiceImpl#filterDisableMenus，父节点未授权的按钮会被整体丢弃。
--        因此授予 13685~13688 按钮必须同时授予父链 13600（祖先目录） + 13684（页面）。
--        后端 @PreAuthorize 走 role_menu 直查不受此限制，但必须保持前后端一致。
--   8. 缓存失效：SQL 直插绕过 @CacheEvict，执行后按 39 号 §7.3 的应用层方案触发
--        （菜单保存×1 + 904/906/908/909 角色菜单保存×4），不执行 Redis 原生清理。
-- ================================================================

SET NAMES utf8mb4;

-- ================================================================
-- 0. 执行前预检（只读 SELECT；全部符合预期方可写入；异常环境写入影响 0 行不报错，
--    必须人工逐条核对，任一不符【停止执行】）
-- ================================================================

-- 0.1 最大菜单 ID 核对（预期 cur_max=13683；若 < 13683 说明 INSTRUMENT-03 未完整部署，
--     若 >= 13684 说明 ID 段被占用，须重新评估并改写本脚本；停止执行）
SELECT MAX(id) AS cur_max FROM system_menu WHERE deleted = b'0';

-- 0.2 目标菜单段全部空闲（预期 idle_cnt=5；若任一 < 1 说明已存在，停止）
SELECT COUNT(*) AS idle_cnt FROM system_menu WHERE id BETWEEN 13684 AND 13688;

-- 0.3 新角色 ID 909 空闲 + AUTO_INCREMENT 核对
--     预期：id_909_used=0 且 next_ai=909
SELECT (SELECT COUNT(*) FROM system_role WHERE id = 909) AS id_909_used,
       (SELECT AUTO_INCREMENT FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'system_role') AS next_role_ai;

-- 0.4 父菜单 13600 存在且启用（预期 1 行：type=1, status=0, deleted=0）
SELECT id, name, type, parent_id, path, status, deleted FROM system_menu WHERE id = 13600;

-- 0.5 父菜单下 sort 最大值（预期 20；若 >=21 须重新分配 sort）
SELECT MAX(sort) AS parent_max_sort FROM system_menu WHERE parent_id = 13600 AND deleted = b'0';

-- 0.6 权限串冲突（预期 0 行；若已存在须核实归属，停止）
SELECT id, name, permission, parent_id FROM system_menu
WHERE permission IN (
  'lab:instrument:fault-report:submit',
  'lab:instrument:fault-report:admin',
  'lab:instrument:repair-order:handle',
  'lab:instrument:repair-order:admin'
);

-- 0.7 角色矩阵核对（预期 4 行：904/906/908，tenant 162，status 0）
--     维修负责人 909 不存在属正常（将在 §1 创建）
SELECT id, name, code, status, tenant_id FROM system_role
WHERE id IN (904, 906, 908, 909) ORDER BY id;

-- 0.8 套餐 114 核对（预期 1 行：status=0, JSON_VALID(menu_ids)=1）
SELECT id, name, status, JSON_VALID(menu_ids) AS json_valid, JSON_LENGTH(menu_ids) AS menu_cnt
FROM system_tenant_package WHERE id = 114;

-- 0.9 祖先目录 13478 + 父菜单 13600 的 role_menu 现状（904/906/908 须已有授权）
SELECT rm.role_id, rm.menu_id FROM system_role_menu rm
WHERE rm.tenant_id = 162 AND rm.deleted = b'0'
  AND rm.role_id IN (904, 906, 908)
  AND rm.menu_id IN (13478, 13600)
ORDER BY rm.role_id, rm.menu_id;

-- 0.10 套餐 114 是否已含本批目标 ID（预期 4 个 JSON_CONTAINS 全 0）
SELECT
  JSON_CONTAINS(CAST(menu_ids AS JSON), '13684') AS has_13684,
  JSON_CONTAINS(CAST(menu_ids AS JSON), '13685') AS has_13685,
  JSON_CONTAINS(CAST(menu_ids AS JSON), '13686') AS has_13686,
  JSON_CONTAINS(CAST(menu_ids AS JSON), '13687') AS has_13687,
  JSON_CONTAINS(CAST(menu_ids AS JSON), '13688') AS has_13688
FROM system_tenant_package WHERE id = 114;

-- 0.11 现状留证：904/906/908 当前授权数量（用于执行后对比，不修改）
SELECT role_id, COUNT(*) AS menu_cnt FROM system_role_menu
WHERE tenant_id = 162 AND deleted = b'0' AND role_id IN (904, 906, 908)
GROUP BY role_id ORDER BY role_id;


-- ================================================================
-- §1. 创建维修负责人角色（909，幂等）
--     列序：id, name, code, sort, data_scope, status, type, remark,
--           creator, create_time, updater, update_time, deleted, tenant_id
--     说明：
--       type=2 自定义角色；status=0 启用；data_scope=1（部门 ALL，对仪器业务表无影响；
--             维修数据范围由 Service 层 scopeSupport.canRepairDevice 强制校验
--             ROOM_REPAIR 业务关系，不依赖部门数据权限）；
--       sort=38（位于 instrument_device_manager=35 与 registration_approver=40 之间，
--             与既有角色排序风格一致）；
--       tenant_id 显式 162；
--       幂等：NOT EXISTS 按 id 和 code 双重守卫。
-- ================================================================

INSERT INTO system_role
    (id, name, code, sort, data_scope, status, type, remark,
     creator, create_time, updater, update_time, deleted, tenant_id)
SELECT 909, '仪器维修负责人', 'instrument_repair_manager', 38, 1, 0, 2,
       'INSTRUMENT-06 维修负责人角色：处理自己负责房间内的维修工单；也可上报故障。'
       '数据范围由 ROOM_REPAIR 业务关系判定（InstrumentScopeSupport.canRepairDevice）。',
       '1', NOW(), '1', NOW(), b'0', 162
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM system_role WHERE id = 909)
  AND NOT EXISTS (SELECT 1 FROM system_role
                  WHERE code = 'instrument_repair_manager' AND deleted = b'0');


-- ================================================================
-- §2. 菜单创建（幂等；5 行：1 页面 + 4 按钮）
--     menu 层级说明（与 INSTRUMENT-03 风格一致）：
--       13600 仪器管理 (type=1 目录)
--         └─ 13684 维修工单管理 (type=2 页面, sort=21)
--              ├─ 13685 故障上报提交 (type=3, submit, sort=1)
--              ├─ 13686 故障上报管理 (type=3, admin, sort=2)
--              ├─ 13687 维修工单处理 (type=3, handle, sort=3)
--              └─ 13688 维修工单管理 (type=3, admin, sort=4)
--     列序：id, name, permission, type, sort, parent_id, path, icon,
--           component, component_name, status, visible, keep_alive, always_show,
--           creator, create_time, updater, update_time, deleted
-- ================================================================

-- 2.1 维修工单管理（页面，type=2）
INSERT INTO system_menu
    (id, name, permission, type, sort, parent_id, path, icon,
     component, component_name, status, visible, keep_alive, always_show,
     creator, create_time, updater, update_time, deleted, tenant_id)
SELECT 13684, '维修工单管理', '', 2, 21, 13600, 'repair-manage', 'ep:tools',
       'lab/instrument/repair-order/list', 'LabInstrumentRepairOrderList',
       0, b'1', b'1', b'1',
       '1', NOW(), '1', NOW(), b'0', 162
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM system_menu WHERE id = 13684)
  AND NOT EXISTS (SELECT 1 FROM system_menu
                  WHERE parent_id = 13600 AND path = 'repair-manage' AND deleted = b'0');

-- 2.2 四个按钮菜单（type=3；批量 INSERT）
INSERT INTO system_menu
    (id, name, permission, type, sort, parent_id, path, icon,
     component, component_name, status, visible, keep_alive, always_show,
     creator, create_time, updater, update_time, deleted, tenant_id)
SELECT 13685, '故障上报提交', 'lab:instrument:fault-report:submit', 3, 1, 13684,
       NULL, NULL, NULL, NULL, 0, b'1', b'1', b'1',
       '1', NOW(), '1', NOW(), b'0', 162
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM system_menu WHERE id = 13685)
AND NOT EXISTS (SELECT 1 FROM system_menu
                WHERE permission = 'lab:instrument:fault-report:submit' AND deleted = b'0')

UNION ALL
SELECT 13686, '故障上报管理', 'lab:instrument:fault-report:admin', 3, 2, 13684,
       NULL, NULL, NULL, NULL, 0, b'1', b'1', b'1',
       '1', NOW(), '1', NOW(), b'0', 162
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM system_menu WHERE id = 13686)
AND NOT EXISTS (SELECT 1 FROM system_menu
                WHERE permission = 'lab:instrument:fault-report:admin' AND deleted = b'0')

UNION ALL
SELECT 13687, '维修工单处理', 'lab:instrument:repair-order:handle', 3, 3, 13684,
       NULL, NULL, NULL, NULL, 0, b'1', b'1', b'1',
       '1', NOW(), '1', NOW(), b'0', 162
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM system_menu WHERE id = 13687)
AND NOT EXISTS (SELECT 1 FROM system_menu
                WHERE permission = 'lab:instrument:repair-order:handle' AND deleted = b'0')

UNION ALL
SELECT 13688, '维修工单管理', 'lab:instrument:repair-order:admin', 3, 4, 13684,
       NULL, NULL, NULL, NULL, 0, b'1', b'1', b'1',
       '1', NOW(), '1', NOW(), b'0', 162
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM system_menu WHERE id = 13688)
AND NOT EXISTS (SELECT 1 FROM system_menu
                WHERE permission = 'lab:instrument:repair-order:admin' AND deleted = b'0');


-- ================================================================
-- §3. 套餐 114 追加菜单 ID（JSON 幂等守卫；114 是 tenant 162 的唯一套餐）
--     每 ID 一条原子 UPDATE（JSON_CONTAINS 命中=1 则跳过，未命中=0 则追加）；
--     全部 5 条写在同一事务内，确保"要么都追加、要么都没动"。
-- ================================================================

UPDATE system_tenant_package
SET menu_ids = JSON_ARRAY_APPEND(CAST(menu_ids AS JSON), '$', CAST(13684 AS JSON))
WHERE id = 114
  AND JSON_VALID(menu_ids) = 1
  AND JSON_CONTAINS(CAST(menu_ids AS JSON), '13684', '$') = 0;

UPDATE system_tenant_package
SET menu_ids = JSON_ARRAY_APPEND(CAST(menu_ids AS JSON), '$', CAST(13685 AS JSON))
WHERE id = 114
  AND JSON_VALID(menu_ids) = 1
  AND JSON_CONTAINS(CAST(menu_ids AS JSON), '13685', '$') = 0;

UPDATE system_tenant_package
SET menu_ids = JSON_ARRAY_APPEND(CAST(menu_ids AS JSON), '$', CAST(13686 AS JSON))
WHERE id = 114
  AND JSON_VALID(menu_ids) = 1
  AND JSON_CONTAINS(CAST(menu_ids AS JSON), '13686', '$') = 0;

UPDATE system_tenant_package
SET menu_ids = JSON_ARRAY_APPEND(CAST(menu_ids AS JSON), '$', CAST(13687 AS JSON))
WHERE id = 114
  AND JSON_VALID(menu_ids) = 1
  AND JSON_CONTAINS(CAST(menu_ids AS JSON), '13687', '$') = 0;

UPDATE system_tenant_package
SET menu_ids = JSON_ARRAY_APPEND(CAST(menu_ids AS JSON), '$', CAST(13688 AS JSON))
WHERE id = 114
  AND JSON_VALID(menu_ids) = 1
  AND JSON_CONTAINS(CAST(menu_ids AS JSON), '13688', '$') = 0;


-- ================================================================
-- §4. 角色菜单授权（幂等；显式 tenant_id=162，creator/updater='1'）
--     权限矩阵（依据 D11）：
--
--       菜单 / 角色            | 904 普通用户 | 906 lab_admin | 908 设备负责人 | 909 维修负责人
--       ----------------------|:----------:|:------------:|:-------------:|:-------------:
--       13478 实验室管理（祖先）| 已有        | 已有          | 已有            | 须补
--       13600 仪器管理（祖先） | 已有        | 已有          | 已有            | 须补
--       13684 维修工单管理页面  | ✓           | ✓             | —               | ✓
--       13685 fault-report:submit | ✓      | ✓             | —               | ✓
--       13686 fault-report:admin   | —      | ✓             | —               | —
--       13687 repair-order:handle  | —      | ✓             | —               | ✓
--       13688 repair-order:admin   | —      | ✓             | —               | —
--
--     重要说明：
--       * 904 只授 submit + 页面 → 可上报故障、看自己的上报、不可确认/派工；
--       * 906 全量 → 覆盖维修所有管理操作；
--       * 908 设备负责人【不自动获得】维修权限 → 保持原有边界；
--       * 909 新角色授 submit + handle（也能上报，符合 04 §5.2 权限矩阵）；
--       * 13478/13600 祖先链对 904/906/908 是【已有】（INSTRUMENT-01/02 部署时已授），
--         对 909 是【必须补上】（新角色，否则前端权限集合因父节点禁用而全部丢弃）。
--       * 所有 INSERT 带 EXISTS role + EXISTS menu + NOT EXISTS role_menu 三重守卫，
--         异常环境写入 0 行不报错，由执行人人工核对验收。
-- ================================================================

-- ---------- 4.1 904 普通用户：submit + 页面 ----------
INSERT INTO system_role_menu (role_id, menu_id, creator, updater, deleted, tenant_id)
SELECT 904, m.target_menu, '1', '1', b'0', 162
FROM (
  SELECT 13684 AS target_menu UNION SELECT 13685
) m
WHERE EXISTS (SELECT 1 FROM system_role sr
              WHERE sr.id = 904 AND sr.tenant_id = 162 AND sr.status = 0 AND sr.deleted = b'0')
  AND EXISTS (SELECT 1 FROM system_menu sm
              WHERE sm.id = m.target_menu AND sm.status = 0 AND sm.deleted = b'0')
  AND NOT EXISTS (SELECT 1 FROM system_role_menu rm
                  WHERE rm.role_id = 904 AND rm.menu_id = m.target_menu
                    AND rm.tenant_id = 162 AND rm.deleted = b'0');

-- ---------- 4.2 906 lab_admin：全部 5 个 ----------
INSERT INTO system_role_menu (role_id, menu_id, creator, updater, deleted, tenant_id)
SELECT 906, m.target_menu, '1', '1', b'0', 162
FROM (
  SELECT 13684 AS target_menu
  UNION SELECT 13685 UNION SELECT 13686
  UNION SELECT 13687 UNION SELECT 13688
) m
WHERE EXISTS (SELECT 1 FROM system_role sr
              WHERE sr.id = 906 AND sr.tenant_id = 162 AND sr.status = 0 AND sr.deleted = b'0')
  AND EXISTS (SELECT 1 FROM system_menu sm
              WHERE sm.id = m.target_menu AND sm.status = 0 AND sm.deleted = b'0')
  AND NOT EXISTS (SELECT 1 FROM system_role_menu rm
                  WHERE rm.role_id = 906 AND rm.menu_id = m.target_menu
                    AND rm.tenant_id = 162 AND rm.deleted = b'0');

-- ---------- 4.3 908 设备负责人：不自动获得维修权限（显式写 0 行守卫语句作声明） ----------
-- 说明：不执行任何 INSERT。908 的维修能力由"管理员人工 UI 授权"或"后续独立批次"决定。
--       若执行人确认要给 908 维修权限，取消下方注释并按矩阵授权。
-- INSERT INTO system_role_menu (role_id, menu_id, creator, updater, deleted, tenant_id)
-- SELECT 908, m.target_menu, '1', '1', b'0', 162 FROM (...) m WHERE ... ;

-- ---------- 4.4 909 维修负责人：祖先链 + 页面 + submit + handle ----------
INSERT INTO system_role_menu (role_id, menu_id, creator, updater, deleted, tenant_id)
SELECT 909, m.target_menu, '1', '1', b'0', 162
FROM (
  SELECT 13478 AS target_menu              -- 祖先目录
  UNION SELECT 13600                        -- 仪器管理祖先
  UNION SELECT 13684                        -- 维修工单管理页面
  UNION SELECT 13685                        -- 故障上报提交（维修负责人也能上报）
  UNION SELECT 13687                        -- 维修工单处理
) m
WHERE EXISTS (SELECT 1 FROM system_role sr
              WHERE sr.id = 909 AND sr.tenant_id = 162 AND sr.status = 0 AND sr.deleted = b'0')
  AND EXISTS (SELECT 1 FROM system_menu sm
              WHERE sm.id = m.target_menu AND sm.status = 0 AND sm.deleted = b'0')
  AND NOT EXISTS (SELECT 1 FROM system_role_menu rm
                  WHERE rm.role_id = 909 AND rm.menu_id = m.target_menu
                    AND rm.tenant_id = 162 AND rm.deleted = b'0');


-- ================================================================
-- §5. 执行后验收（只读 SELECT；全部符合预期方可 COMMIT）
-- ================================================================

-- 5.1 角色 909 已创建（预期 1 行：id=909, code=instrument_repair_manager, status=0）
SELECT id, name, code, sort, data_scope, status, type, tenant_id, remark
FROM system_role WHERE id = 909;

-- 5.2 菜单全部就位（预期 5 行：13684~13688，status=0, deleted=0）
SELECT id, name, permission, type, parent_id, sort, path, component
FROM system_menu WHERE id BETWEEN 13684 AND 13688 ORDER BY id;

-- 5.3 层级与 parent_id 正确（预期 1 行 13684.parent_id=13600；4 行 13685~13688.parent_id=13684）
SELECT parent_id, COUNT(*) AS child_cnt FROM system_menu
WHERE id IN (13684, 13685, 13686, 13687, 13688)
GROUP BY parent_id ORDER BY parent_id;

-- 5.4 套餐 114 包含新菜单（预期 5 个 JSON_CONTAINS 全 = 1）
SELECT
  JSON_CONTAINS(CAST(menu_ids AS JSON), '13684') AS has_13684,
  JSON_CONTAINS(CAST(menu_ids AS JSON), '13685') AS has_13685,
  JSON_CONTAINS(CAST(menu_ids AS JSON), '13686') AS has_13686,
  JSON_CONTAINS(CAST(menu_ids AS JSON), '13687') AS has_13687,
  JSON_CONTAINS(CAST(menu_ids AS JSON), '13688') AS has_13688,
  JSON_LENGTH(menu_ids) AS new_total
FROM system_tenant_package WHERE id = 114;

-- 5.5 套餐 JSON 完整性（预期 1 行 JSON_VALID=1）
SELECT JSON_VALID(menu_ids) AS json_valid FROM system_tenant_package WHERE id = 114;

-- 5.6 角色授权数量对比（新增 = 执行后 - 执行前）
SELECT role_id, COUNT(*) AS new_total FROM system_role_menu
WHERE tenant_id = 162 AND deleted = b'0'
  AND role_id IN (904, 906, 908, 909)
GROUP BY role_id ORDER BY role_id;

-- 5.7 角色授权明细逐行核对（含祖先链；预期矩阵见 §4 注释）
SELECT rm.role_id, m.id AS menu_id, m.name, m.type, m.permission, m.parent_id
FROM system_role_menu rm JOIN system_menu m ON m.id = rm.menu_id
WHERE rm.tenant_id = 162 AND rm.deleted = b'0'
  AND rm.role_id IN (904, 906, 908, 909)
  AND rm.menu_id IN (13478, 13600, 13684, 13685, 13686, 13687, 13688)
ORDER BY rm.role_id, m.parent_id, m.sort;

-- 5.8 908 越权回归（预期 0 行：908 不应获得 13684~13688 任何一条）
SELECT COUNT(*) AS leak_cnt FROM system_role_menu
WHERE tenant_id = 162 AND deleted = b'0'
  AND role_id = 908 AND menu_id BETWEEN 13684 AND 13688;

-- 5.9 跨租户回归（预期 0 行：非 162 租户不应有本批授权）
SELECT tenant_id, role_id, COUNT(*) AS cnt FROM system_role_menu
WHERE role_id IN (904, 906, 908, 909) AND menu_id BETWEEN 13684 AND 13688
GROUP BY tenant_id, role_id HAVING tenant_id <> 162;

-- 5.10 菜单 ID 段唯一（预期 0 行逻辑删除残留）
SELECT COUNT(*) AS soft_deleted FROM system_menu
WHERE id BETWEEN 13684 AND 13688 AND deleted = b'1';


-- ================================================================
-- §6. 执行事务包装（执行人须将 §1~§4 整体包在一个事务内执行）
--     说明：本脚本未显式写 BEGIN/COMMIT，由执行人在 MySQL 客户端手动控制。
--     推荐执行模式：
--
--       source d0_precheck.sql;           -- §0 预检
--       BEGIN;
--         source d1_create_role.sql;       -- §1
--         source d2_create_menu.sql;       -- §2
--         source d3_update_package.sql;    -- §3
--         source d4_assign_role_menu.sql;  -- §4
--         source d5_accept.sql;            -- §5 验收（SELECT）
--       COMMIT;                            -- 验收全 PASS 才提交
--
--     任一验收不符 → ROLLBACK 并报告。
--     不允许拆分事务分段执行，避免"部分菜单已建但套餐/角色未跟上"的不一致状态。
-- ================================================================


-- ================================================================
-- §7. 缓存失效方案（文档，不执行）
--     SQL 直插绕过 Spring @CacheEvict。COMMIT 后按序执行：
--       1) 【系统管理 → 菜单管理】任选一条菜单做无影响编辑保存 → 全菜单缓存失效；
--       2) 【系统管理 → 角色管理】分别打开 904/906/908/909 的"菜单权限"直接保存
--          → 对应角色缓存失效；
--     兜底：不做任何操作时，全部脏缓存 ≤1h TTL 自然过期。
--     用户侧：刷新页面或重新登录，新菜单立即可见（菜单树实时查库无缓存）。
-- ================================================================


-- ================================================================
-- §8. 回退脚本（纯 DELETE + UPDATE；回退首选 mysqldump 恢复三表；
--     本脚本仅作备份不可用时的手工回退；执行前务必二次确认）
-- ================================================================

-- 8.1 回退前留证（只读；确认影响范围）
SELECT '--- 即将删除的 role_menu ---' AS info;
SELECT COUNT(*) AS affected_role_menu FROM system_role_menu
WHERE tenant_id = 162 AND role_id IN (904, 906, 908, 909) AND menu_id BETWEEN 13684 AND 13688;

SELECT '--- 即将删除的 menus ---' AS info;
SELECT COUNT(*) AS affected_menus FROM system_menu WHERE id BETWEEN 13684 AND 13688;

SELECT '--- 套餐当前 menu_ids 长度 ---' AS info;
SELECT JSON_LENGTH(menu_ids) AS pkg_len FROM system_tenant_package WHERE id = 114;

-- 8.2 回退（执行前二次确认；按顺序：先拆套餐 → 再拆 role_menu → 最后删菜单/删角色）

-- 8.2.1 从套餐 114 移除本批 5 个 ID（JSON 数组按值过滤保留其余）
UPDATE system_tenant_package
SET menu_ids = JSON_REMOVE(
  (SELECT @tmp := (SELECT JSON_ARRAYAGG(JSON_UNQUOTE(JSON_EXTRACT(CAST(menu_ids AS JSON), CONCAT('$[', n.n, ']'))))
    FROM system_tenant_package
    CROSS JOIN (
      SELECT 0 AS n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
      UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9
      UNION SELECT 10 UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14
      UNION SELECT 15 UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19
      UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23 UNION SELECT 24
      UNION SELECT 25 UNION SELECT 26 UNION SELECT 27 UNION SELECT 28 UNION SELECT 29
      UNION SELECT 30 UNION SELECT 31 UNION SELECT 32 UNION SELECT 33 UNION SELECT 34
      UNION SELECT 35 UNION SELECT 36 UNION SELECT 37 UNION SELECT 38 UNION SELECT 39
      UNION SELECT 40 UNION SELECT 41 UNION SELECT 42 UNION SELECT 43 UNION SELECT 44
      UNION SELECT 45 UNION SELECT 46 UNION SELECT 47 UNION SELECT 48 UNION SELECT 49
      UNION SELECT 50 UNION SELECT 51 UNION SELECT 52 UNION SELECT 53 UNION SELECT 54
      UNION SELECT 55 UNION SELECT 56 UNION SELECT 57 UNION SELECT 58 UNION SELECT 59
      UNION SELECT 60 UNION SELECT 61 UNION SELECT 62 UNION SELECT 63 UNION SELECT 64
      UNION SELECT 65 UNION SELECT 66 UNION SELECT 67 UNION SELECT 68 UNION SELECT 69
      UNION SELECT 70 UNION SELECT 71 UNION SELECT 72 UNION SELECT 73 UNION SELECT 74
      UNION SELECT 75 UNION SELECT 76 UNION SELECT 77 UNION SELECT 78 UNION SELECT 79
      UNION SELECT 80 UNION SELECT 81 UNION SELECT 82 UNION SELECT 83 UNION SELECT 84
      UNION SELECT 85 UNION SELECT 86 UNION SELECT 87 UNION SELECT 88 UNION SELECT 89
      UNION SELECT 90 UNION SELECT 91 UNION SELECT 92 UNION SELECT 93 UNION SELECT 94
      UNION SELECT 95 UNION SELECT 96 UNION SELECT 97 UNION SELECT 98 UNION SELECT 99
      UNION SELECT 100 UNION SELECT 101 UNION SELECT 102 UNION SELECT 103 UNION SELECT 104
      UNION SELECT 105 UNION SELECT 106 UNION SELECT 107 UNION SELECT 108 UNION SELECT 109
      UNION SELECT 110 UNION SELECT 111 UNION SELECT 112 UNION SELECT 113 UNION SELECT 114
      UNION SELECT 115 UNION SELECT 116 UNION SELECT 117 UNION SELECT 118 UNION SELECT 119
      UNION SELECT 120 UNION SELECT 121 UNION SELECT 122 UNION SELECT 123 UNION SELECT 124
      UNION SELECT 125 UNION SELECT 126 UNION SELECT 127 UNION SELECT 128 UNION SELECT 129
      UNION SELECT 130 UNION SELECT 131 UNION SELECT 132 UNION SELECT 133 UNION SELECT 134
      UNION SELECT 135 UNION SELECT 136 UNION SELECT 137 UNION SELECT 138 UNION SELECT 139
      UNION SELECT 140 UNION SELECT 141 UNION SELECT 142 UNION SELECT 143 UNION SELECT 144
      UNION SELECT 145 UNION SELECT 146 UNION SELECT 147 UNION SELECT 148 UNION SELECT 149
      UNION SELECT 150 UNION SELECT 151 UNION SELECT 152 UNION SELECT 153 UNION SELECT 154
      UNION SELECT 155 UNION SELECT 156 UNION SELECT 157 UNION SELECT 158 UNION SELECT 159
      UNION SELECT 160 UNION SELECT 161 UNION SELECT 162 UNION SELECT 163 UNION SELECT 164
      UNION SELECT 165 UNION SELECT 166 UNION SELECT 167 UNION SELECT 168 UNION SELECT 169
      UNION SELECT 170 UNION SELECT 171 UNION SELECT 172 UNION SELECT 173 UNION SELECT 174
      UNION SELECT 175 UNION SELECT 176 UNION SELECT 177 UNION SELECT 178 UNION SELECT 179
      UNION SELECT 180 UNION SELECT 181 UNION SELECT 182 UNION SELECT 183 UNION SELECT 184
      UNION SELECT 185 UNION SELECT 186 UNION SELECT 187 UNION SELECT 188 UNION SELECT 189
      UNION SELECT 190 UNION SELECT 191 UNION SELECT 192 UNION SELECT 193 UNION SELECT 194
      UNION SELECT 195 UNION SELECT 196 UNION SELECT 197 UNION SELECT 198 UNION SELECT 199
      UNION SELECT 200 UNION SELECT 201 UNION SELECT 202 UNION SELECT 203 UNION SELECT 204
      UNION SELECT 205 UNION SELECT 206 UNION SELECT 207 UNION SELECT 208 UNION SELECT 209
      UNION SELECT 210 UNION SELECT 211 UNION SELECT 212 UNION SELECT 213 UNION SELECT 214
      UNION SELECT 215 UNION SELECT 216 UNION SELECT 217 UNION SELECT 218 UNION SELECT 219
      UNION SELECT 220 UNION SELECT 221 UNION SELECT 222 UNION SELECT 223 UNION SELECT 224
      UNION SELECT 225 UNION SELECT 226 UNION SELECT 227 UNION SELECT 228 UNION SELECT 229
      UNION SELECT 230 UNION SELECT 231 UNION SELECT 232 UNION SELECT 233 UNION SELECT 234
      UNION SELECT 235 UNION SELECT 236 UNION SELECT 237 UNION SELECT 238 UNION SELECT 239
      UNION SELECT 240 UNION SELECT 241 UNION SELECT 242 UNION SELECT 243 UNION SELECT 244
      UNION SELECT 245 UNION SELECT 246 UNION SELECT 247 UNION SELECT 248 UNION SELECT 249
      UNION SELECT 250 UNION SELECT 251 UNION SELECT 252 UNION SELECT 253 UNION SELECT 254
      UNION SELECT 255 UNION SELECT 256 UNION SELECT 257 UNION SELECT 258 UNION SELECT 259
      UNION SELECT 260 UNION SELECT 261 UNION SELECT 262 UNION SELECT 263 UNION SELECT 264
      UNION SELECT 265 UNION SELECT 266 UNION SELECT 267 UNION SELECT 268 UNION SELECT 269
      UNION SELECT 270 UNION SELECT 271 UNION SELECT 272 UNION SELECT 273 UNION SELECT 274
      UNION SELECT 275 UNION SELECT 276 UNION SELECT 277 UNION SELECT 278 UNION SELECT 279
      UNION SELECT 280 UNION SELECT 281 UNION SELECT 282 UNION SELECT 283 UNION SELECT 284
      UNION SELECT 285 UNION SELECT 286 UNION SELECT 287 UNION SELECT 288 UNION SELECT 289
      UNION SELECT 290 UNION SELECT 291 UNION SELECT 292 UNION SELECT 293 UNION SELECT 294
      UNION SELECT 295 UNION SELECT 296 UNION SELECT 297 UNION SELECT 298 UNION SELECT 299
      UNION SELECT 300 UNION SELECT 301 UNION SELECT 302 UNION SELECT 303 UNION SELECT 304
      UNION SELECT 305 UNION SELECT 306 UNION SELECT 307 UNION SELECT 308 UNION SELECT 309
      UNION SELECT 310 UNION SELECT 311 UNION SELECT 312 UNION SELECT 313 UNION SELECT 314
      UNION SELECT 315 UNION SELECT 316 UNION SELECT 317 UNION SELECT 318 UNION SELECT 319
      UNION SELECT 320 UNION SELECT 321 UNION SELECT 322 UNION SELECT 323 UNION SELECT 324
      UNION SELECT 325 UNION SELECT 326 UNION SELECT 327 UNION SELECT 328 UNION SELECT 329
      UNION SELECT 330 UNION SELECT 331 UNION SELECT 332 UNION SELECT 333 UNION SELECT 334
      UNION SELECT 335 UNION SELECT 336 UNION SELECT 337 UNION SELECT 338 UNION SELECT 339
      UNION SELECT 340 UNION SELECT 341 UNION SELECT 342 UNION SELECT 343 UNION SELECT 344
      UNION SELECT 345 UNION SELECT 346 UNION SELECT 347 UNION SELECT 348 UNION SELECT 349
      UNION SELECT 350 UNION SELECT 351 UNION SELECT 352 UNION SELECT 353 UNION SELECT 354
      UNION SELECT 355 UNION SELECT 356 UNION SELECT 357 UNION SELECT 358 UNION SELECT 359
      UNION SELECT 360 UNION SELECT 361 UNION SELECT 362 UNION SELECT 363 UNION SELECT 364
      UNION SELECT 365 UNION SELECT 366 UNION SELECT 367 UNION SELECT 368 UNION SELECT 369
      UNION SELECT 370 UNION SELECT 371 UNION SELECT 372 UNION SELECT 373 UNION SELECT 374
    ) n
    WHERE JSON_UNQUOTE(JSON_EXTRACT(CAST((SELECT menu_ids FROM system_tenant_package WHERE id=114) AS JSON), CONCAT('$[', n.n, ']'))) NOT IN ('13684','13685','13686','13687','13688')
  )), '$', (SELECT @tmp))
WHERE id = 114;

-- 说明：上面这一条 JSON_REMOVE 在 menu_ids 超长或 NULL 时可能失败。
-- 若该 UPDATE 报错，改走 mysqldump 恢复套餐表或手工拼接旧数组——
-- 本脚本不承诺在所有边界下自动回退套餐。

-- 8.2.2 删除本批 role_menu
DELETE FROM system_role_menu
WHERE tenant_id = 162
  AND role_id IN (904, 906, 908, 909)
  AND menu_id BETWEEN 13684 AND 13688;

-- 8.2.3 删除本批菜单
DELETE FROM system_menu WHERE id BETWEEN 13684 AND 13688;

-- 8.2.4 删除新角色（仅回退本脚本创建的 909，不动任何既有角色）
DELETE FROM system_role WHERE id = 909;

-- 8.3 回退后验收（全部预期 0 行）
SELECT '--- 回退后验收 ---' AS info;
SELECT COUNT(*) AS remain_role_menu FROM system_role_menu
WHERE tenant_id = 162 AND role_id IN (904, 906, 908, 909) AND menu_id BETWEEN 13684 AND 13688;
SELECT COUNT(*) AS remain_menus FROM system_menu WHERE id BETWEEN 13684 AND 13688;
SELECT COUNT(*) AS remain_role FROM system_role WHERE id = 909;


-- ================================================================
-- §9. 最终验收后角色分配（设计稿，不执行）
--     脚本【不含】system_user_role 的任何写入。
--     执行完毕后，负责人在【系统管理 → 用户管理】人工操作：
--       1) 找到实际要担任"维修负责人"的用户账号（须先在 lab_instrument_manager
--          表分配 ROOM_REPAIR ACTIVE 业务关系，见 47 号 §2.4）；
--       2) 打开【角色】选项 → 勾选"仪器维修负责人"（909）→ 保存；
--       3) 用户刷新或重新登录，新菜单立即可见。
--     为何不自动分配？
--       a) 脚本不知道哪些用户实际是维修负责人（manager 表与 user 表需业务判断）；
--       b) 可能存在 0~N 个维修负责人，自动分配无法安全覆盖；
--       c) 负责人角色可随时增删，人工分配灵活；
--       d) 保持 908 角色设计范式（role SQL 同样不含 user_role 写入）。
-- ================================================================
