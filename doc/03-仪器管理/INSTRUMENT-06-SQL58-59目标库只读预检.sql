-- INSTRUMENT-06 R6 目标库只读预检（Navicat 手工执行）
-- 安全边界：本文件仅含 SELECT 与 SHOW GRANTS。不得在本文件追加或执行写入语句。
-- 结果用于核对 SQL 58/59 的部署前置条件；任一冲突或未知项应停止部署并提交负责人复核。

-- 1. 当前连接信息（先确认当前数据库为 labplatform）
SELECT DATABASE() AS current_database, VERSION() AS mysql_version,
       @@hostname AS server_hostname, @@port AS server_port,
       CURRENT_USER() AS authenticated_account, USER() AS client_identity,
       @@read_only AS server_read_only, @@super_read_only AS server_super_read_only;

-- 1.1 当前账号授权（只读元数据；执行前请确认当前查询仍连接到正确实例）
SHOW GRANTS;

-- 2. 五张维修表、INSTRUMENT-03 依赖表及关键系统表的存在情况
SELECT table_name, table_type, engine, table_rows
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN (
    'lab_instrument_fault_report',
    'lab_instrument_repair_order',
    'lab_instrument_repair_history',
    'lab_instrument_device_status_history',
    'lab_instrument_reservation_impact',
    'lab_instrument_device',
    'lab_instrument_manager',
    'lab_instrument_reservation',
    'system_menu', 'system_role', 'system_role_menu', 'system_tenant_package', 'system_tenant'
  )
ORDER BY table_name;

-- 3. 已存在维修表的真实字段。结果为空表示目标表不存在。
SELECT table_name, ordinal_position, column_name, column_type, is_nullable,
       column_default, extra, character_set_name, collation_name, column_comment
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name IN (
    'lab_instrument_fault_report',
    'lab_instrument_repair_order',
    'lab_instrument_repair_history',
    'lab_instrument_device_status_history',
    'lab_instrument_reservation_impact'
  )
ORDER BY table_name, ordinal_position;

-- 4. 已存在维修表的索引与唯一约束
SELECT table_name, index_name, non_unique, seq_in_index, column_name, sub_part, index_type
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name IN (
    'lab_instrument_fault_report',
    'lab_instrument_repair_order',
    'lab_instrument_repair_history',
    'lab_instrument_device_status_history',
    'lab_instrument_reservation_impact'
  )
ORDER BY table_name, index_name, seq_in_index;

-- 5. SQL 59 菜单 ID、组件路径及权限码冲突
SELECT id, name, permission, type, parent_id, sort, path, component, status, deleted, tenant_id
FROM system_menu
WHERE id BETWEEN 13684 AND 13688
   OR permission IN (
     'lab:instrument:fault-report:submit',
     'lab:instrument:fault-report:admin',
     'lab:instrument:repair-order:handle',
     'lab:instrument:repair-order:admin'
   )
ORDER BY id;

-- 5.1 SQL 59 固定 ID 段、父菜单 sort 与 AUTO_INCREMENT 余量
SELECT (SELECT MAX(id) FROM system_menu WHERE deleted = b'0') AS active_max_menu_id,
       (SELECT COUNT(*) FROM system_menu WHERE id BETWEEN 13684 AND 13688) AS occupied_target_ids,
       (SELECT MAX(sort) FROM system_menu WHERE parent_id = 13600 AND deleted = b'0') AS parent_max_sort,
       (SELECT AUTO_INCREMENT FROM information_schema.tables
         WHERE table_schema = DATABASE() AND table_name = 'system_menu') AS next_menu_auto_increment;

-- 6. SQL 59 父节点及祖先节点
SELECT id, name, type, parent_id, path, component, status, deleted, tenant_id
FROM system_menu
WHERE id IN (13478, 13600)
ORDER BY id;

-- 7. 目标角色及租户归属/状态（角色 909 若不存在属于待创建状态；须核对现存 code 冲突）
SELECT id, name, code, status, type, data_scope, tenant_id, deleted
FROM system_role
WHERE id IN (904, 906, 908, 909)
   OR code = 'instrument_repair_manager'
ORDER BY id;

-- 7.1 核对角色 909 的固定 ID、code 与 AUTO_INCREMENT（预期 id/code 均空闲；next_role_ai=909）
SELECT (SELECT COUNT(*) FROM system_role WHERE id = 909) AS id_909_used,
       (SELECT COUNT(*) FROM system_role
         WHERE code = 'instrument_repair_manager' AND deleted = b'0') AS code_used,
       (SELECT AUTO_INCREMENT FROM information_schema.tables
         WHERE table_schema = DATABASE() AND table_name = 'system_role') AS next_role_auto_increment;

-- 8. 目标租户 162 与套餐 114 状态、JSON 合法性和目标菜单关联
SELECT id, name, package_id, status, deleted
FROM system_tenant
WHERE id = 162;

SELECT id, name, status, JSON_VALID(menu_ids) AS menu_json_valid,
       JSON_LENGTH(menu_ids) AS menu_count,
       JSON_CONTAINS(CAST(menu_ids AS JSON), '13684') AS has_13684,
       JSON_CONTAINS(CAST(menu_ids AS JSON), '13685') AS has_13685,
       JSON_CONTAINS(CAST(menu_ids AS JSON), '13686') AS has_13686,
       JSON_CONTAINS(CAST(menu_ids AS JSON), '13687') AS has_13687,
       JSON_CONTAINS(CAST(menu_ids AS JSON), '13688') AS has_13688
FROM system_tenant_package
WHERE id = 114;

-- 9. 当前角色菜单授权现状（保留执行前证据；908 应不因本批自动获得维修菜单）
SELECT rm.tenant_id, rm.role_id, r.name AS role_name, rm.menu_id,
       m.name AS menu_name, m.permission, m.parent_id, rm.deleted
FROM system_role_menu rm
LEFT JOIN system_role r ON r.id = rm.role_id
LEFT JOIN system_menu m ON m.id = rm.menu_id
WHERE rm.role_id IN (904, 906, 908, 909)
  AND (rm.menu_id IN (13478, 13600, 13684, 13685, 13686, 13687, 13688)
       OR rm.menu_id BETWEEN 13684 AND 13688)
ORDER BY rm.tenant_id, rm.role_id, rm.menu_id;

-- 10. 现存表的行数为 information_schema 估算，仅用于提示可能的数据影响；不是精确计数。
SELECT table_name, table_rows, engine
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN (
    'lab_instrument_fault_report',
    'lab_instrument_repair_order',
    'lab_instrument_repair_history',
    'lab_instrument_device_status_history',
    'lab_instrument_reservation_impact',
    'system_menu', 'system_role', 'system_role_menu', 'system_tenant_package'
  )
ORDER BY table_name;

-- 11. 仅当第 2 项确认五张维修表全部存在时，才运行本查询（精确计数）。
--     若任何一表不存在，不运行本语句；不要用 table_rows 估算代替。
SELECT 'lab_instrument_fault_report' AS table_name, COUNT(*) AS exact_rows FROM lab_instrument_fault_report
UNION ALL SELECT 'lab_instrument_repair_order', COUNT(*) FROM lab_instrument_repair_order
UNION ALL SELECT 'lab_instrument_repair_history', COUNT(*) FROM lab_instrument_repair_history
UNION ALL SELECT 'lab_instrument_device_status_history', COUNT(*) FROM lab_instrument_device_status_history
UNION ALL SELECT 'lab_instrument_reservation_impact', COUNT(*) FROM lab_instrument_reservation_impact;

-- 注意：SQL 58/59 均不在此预检文件中。仅复制/运行以上 SELECT，不执行设计稿。
