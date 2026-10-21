-- ================================================================
-- INSTRUMENT-06 维修模块 DDL 设计稿（R1 修复版）
--
-- 本设计稿与以下 Java DO 完全对齐（字段名驼峰→下划线）：
--   InstrumentFaultReportDO
--   InstrumentRepairOrderDO
--   InstrumentRepairHistoryDO
--   InstrumentDeviceStatusHistoryDO
--   InstrumentReservationImpactDO
--
-- 仅生成，不执行。执行需负责人单独授权。
-- ================================================================

SET NAMES utf8mb4;

-- ================================================================
-- 0. 执行前预检（只读 SELECT，全部通过方可执行第 1 节）
-- ================================================================
SELECT DATABASE() AS cur_db, VERSION() AS mysql_version;

-- 0.1 五表不存在性确认
SELECT 'lab_instrument_fault_report' AS t, COUNT(*) AS cnt FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name='lab_instrument_fault_report'
UNION ALL SELECT 'lab_instrument_repair_order', COUNT(*) FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name='lab_instrument_repair_order'
UNION ALL SELECT 'lab_instrument_repair_history', COUNT(*) FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name='lab_instrument_repair_history'
UNION ALL SELECT 'lab_instrument_device_status_history', COUNT(*) FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name='lab_instrument_device_status_history'
UNION ALL SELECT 'lab_instrument_reservation_impact', COUNT(*) FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name='lab_instrument_reservation_impact';
-- 预期：全部 cnt=0

-- 0.2 前置依赖表
SELECT 'lab_instrument_device' AS dep, COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='lab_instrument_device'
UNION ALL SELECT 'lab_instrument_manager', COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='lab_instrument_manager'
UNION ALL SELECT 'lab_instrument_reservation', COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='lab_instrument_reservation';
-- 预期：全部 cnt=1

-- ================================================================
-- 1. DDL
-- ================================================================

-- 1.1 故障上报
CREATE TABLE IF NOT EXISTS `lab_instrument_fault_report` (
  `id`                    bigint(20)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `device_id`             bigint(20)   NOT NULL COMMENT '设备 id',
  `reporter_user_id`      bigint(20)   NOT NULL COMMENT '上报人 user id',
  `reporter_user_name`    varchar(100) DEFAULT NULL COMMENT '上报人姓名快照',
  `fault_time`            datetime     NOT NULL COMMENT '故障发生时间',
  `fault_phenomenon`      varchar(500) DEFAULT NULL COMMENT '故障现象',
  `fault_description`     varchar(1000) NOT NULL COMMENT '故障描述',
  `severity`              varchar(20)  NOT NULL COMMENT '严重程度：L/M/H/C（与 InstrumentFaultSeverityEnum 一致）',
  `attachment_url`        varchar(500) DEFAULT NULL COMMENT '附件 URL',
  `contact_phone`         varchar(20)  DEFAULT NULL COMMENT '联系电话',
  `confirm_status`        varchar(30)  NOT NULL DEFAULT 'SUBMITTED' COMMENT '确认状态：SUBMITTED/CONFIRMED/REJECTED',
  `confirm_user_id`       bigint(20)   DEFAULT NULL COMMENT '确认人 user id',
  `confirm_user_name`     varchar(100) DEFAULT NULL COMMENT '确认人姓名快照',
  `confirm_time`          datetime     DEFAULT NULL COMMENT '确认时间',
  `confirm_opinion`       varchar(500) DEFAULT NULL COMMENT '确认意见',
  `linked_repair_order_id` bigint(20)  DEFAULT NULL COMMENT '关联维修工单 id',
  `creator`               varchar(64)  DEFAULT '' COMMENT '创建者',
  `create_time`           datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`               varchar(64)  DEFAULT '' COMMENT '更新者',
  `update_time`           datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`               bit(1)       NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id`             bigint(20)   NOT NULL DEFAULT 0 COMMENT '租户编号',
  PRIMARY KEY (`id`),
  KEY `idx_device_id` (`device_id`),
  KEY `idx_reporter_user_id` (`reporter_user_id`),
  KEY `idx_confirm_status` (`confirm_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=Dynamic COMMENT='仪器故障上报';

-- 1.2 维修工单主表
CREATE TABLE IF NOT EXISTS `lab_instrument_repair_order` (
  `id`                         bigint(20)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `order_no`                   varchar(50)  NOT NULL COMMENT '维修工单号（租户内唯一）',
  `device_id`                  bigint(20)   NOT NULL COMMENT '设备 id',
  `room_id`                    bigint(20)   DEFAULT NULL COMMENT '房间 id',
  `source_fault_id`            bigint(20)   DEFAULT NULL COMMENT '来源故障上报 id',
  `current_status`             varchar(30)  NOT NULL DEFAULT 'CONFIRMED' COMMENT '当前状态：SUBMITTED/CONFIRMED/ASSIGNED/IN_PROGRESS/REPAIRED/RESTORED/REJECTED/CANCELED/REOPENED',
  `assignee_user_id`           bigint(20)   DEFAULT NULL COMMENT '被指派维修负责人 user id',
  `assignee_user_name`         varchar(100) DEFAULT NULL COMMENT '被指派人姓名快照',
  `assignee_assign_user_id`    bigint(20)   DEFAULT NULL COMMENT '指派人 user id',
  `assignee_assign_user_name`  varchar(100) DEFAULT NULL COMMENT '指派人姓名快照',
  `assignee_assign_time`       datetime     DEFAULT NULL COMMENT '指派时间',
  `start_time`                 datetime     DEFAULT NULL COMMENT '维修开始时间（IN_PROGRESS）',
  `repair_end_time`            datetime     DEFAULT NULL COMMENT '维修完成时间（REPAIRED）',
  `restore_confirm_user_id`    bigint(20)   DEFAULT NULL COMMENT '恢复确认人 user id',
  `restore_confirm_user_name`  varchar(100) DEFAULT NULL COMMENT '恢复确认人姓名快照',
  `restore_confirm_time`       datetime     DEFAULT NULL COMMENT '恢复确认时间',
  `restore_opinion`            varchar(500) DEFAULT NULL COMMENT '恢复验收意见',
  `close_time`                 datetime     DEFAULT NULL COMMENT '关闭时间（RESTORED/CANCELED）',
  `last_assignee_user_id`      bigint(20)   DEFAULT NULL COMMENT '上一任被指派人（重派工时记录）',
  `creator`                    varchar(64)  DEFAULT '' COMMENT '创建者',
  `create_time`                datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`                    varchar(64)  DEFAULT '' COMMENT '更新者',
  `update_time`                datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`                    bit(1)       NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id`                  bigint(20)   NOT NULL DEFAULT 0 COMMENT '租户编号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_repair_tenant_no` (`tenant_id`, `order_no`),
  KEY `idx_device_id` (`device_id`),
  KEY `idx_assignee_user_id` (`assignee_user_id`),
  KEY `idx_current_status` (`current_status`),
  KEY `idx_source_fault_id` (`source_fault_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=Dynamic COMMENT='仪器维修工单';

-- 1.3 维修操作历史（只增不改）
CREATE TABLE IF NOT EXISTS `lab_instrument_repair_history` (
  `id`                 bigint(20)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `repair_order_id`    bigint(20)   NOT NULL COMMENT '维修工单 id',
  `history_no`         int(11)      NOT NULL COMMENT '工单号内流水号',
  `action`             varchar(50)  NOT NULL COMMENT '操作动作（RepairActionEnum）',
  `from_status`        varchar(30)  DEFAULT NULL COMMENT '变更前状态',
  `to_status`          varchar(30)  DEFAULT NULL COMMENT '变更后状态',
  `operator_user_id`   bigint(20)   NOT NULL COMMENT '操作人 user id',
  `operator_user_name` varchar(100) DEFAULT NULL COMMENT '操作人姓名快照',
  `operate_time`       datetime     NOT NULL COMMENT '操作时间',
  `detail`             varchar(1000) DEFAULT NULL COMMENT '操作说明',
  `repair_cause`       varchar(500) DEFAULT NULL COMMENT '故障原因',
  `repair_measures`    varchar(500) DEFAULT NULL COMMENT '维修措施',
  `parts_used`         varchar(500) DEFAULT NULL COMMENT '使用备件',
  `attachment_url`     varchar(500) DEFAULT NULL COMMENT '附件 URL',
  `creator`            varchar(64)  DEFAULT '' COMMENT '创建者',
  `create_time`        datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`            varchar(64)  DEFAULT '' COMMENT '更新者',
  `update_time`        datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`            bit(1)       NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id`          bigint(20)   NOT NULL DEFAULT 0 COMMENT '租户编号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_repair_history_no` (`tenant_id`, `repair_order_id`, `history_no`),
  KEY `idx_repair_order_id` (`repair_order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=Dynamic COMMENT='仪器维修操作历史';

-- 1.4 设备状态变更历史（只增不改）
CREATE TABLE IF NOT EXISTS `lab_instrument_device_status_history` (
  `id`                       bigint(20)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `device_id`                bigint(20)   NOT NULL COMMENT '设备 id',
  `prev_status`              varchar(30)  DEFAULT NULL COMMENT '变更前状态',
  `new_status`               varchar(30)  NOT NULL COMMENT '变更后状态',
  `action`                   varchar(50)  NOT NULL COMMENT '变更动作（DeviceStatusHistoryActionEnum）',
  `operator_user_id`         bigint(20)   DEFAULT NULL COMMENT '操作人 user id',
  `operator_user_name`       varchar(100) DEFAULT NULL COMMENT '操作人姓名快照',
  `operate_time`             datetime     NOT NULL COMMENT '操作时间',
  `reason`                   varchar(500) DEFAULT NULL COMMENT '变更原因',
  `related_repair_order_id`  bigint(20)   DEFAULT NULL COMMENT '关联维修工单 id',
  `related_fault_report_id`  bigint(20)   DEFAULT NULL COMMENT '关联故障上报 id',
  `creator`                  varchar(64)  DEFAULT '' COMMENT '创建者',
  `create_time`              datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`                  varchar(64)  DEFAULT '' COMMENT '更新者',
  `update_time`              datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`                  bit(1)       NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id`                bigint(20)   NOT NULL DEFAULT 0 COMMENT '租户编号',
  PRIMARY KEY (`id`),
  KEY `idx_device_id` (`device_id`),
  KEY `idx_related_repair_order_id` (`related_repair_order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=Dynamic COMMENT='仪器设备状态变更历史';

-- 1.5 预约影响标记
CREATE TABLE IF NOT EXISTS `lab_instrument_reservation_impact` (
  `id`                bigint(20)   NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `reservation_id`    bigint(20)   NOT NULL COMMENT '预约 id',
  `device_id`         bigint(20)   NOT NULL COMMENT '设备 id',
  `fault_report_id`   bigint(20)   DEFAULT NULL COMMENT '关联故障上报 id',
  `repair_order_id`   bigint(20)   DEFAULT NULL COMMENT '关联维修工单 id',
  `impact_key`        varchar(160) NOT NULL COMMENT '幂等来源键（状态事件 + 预约）',
  `impact_reason`     varchar(500) NOT NULL COMMENT '影响原因',
  `impact_time`       datetime     NOT NULL COMMENT '影响时间',
  `handle_status`     varchar(30)  NOT NULL DEFAULT 'PENDING' COMMENT '处理状态：PENDING 待处理 / AUTO_RESTORED 设备已恢复 / PROCESSED 已人工处理',
  `handle_user_id`    bigint(20)   DEFAULT NULL COMMENT '处理人 user id',
  `handle_user_name`  varchar(100) DEFAULT NULL COMMENT '处理人姓名快照',
  `handle_time`       datetime     DEFAULT NULL COMMENT '处理时间',
  `handle_note`       varchar(500) DEFAULT NULL COMMENT '处理说明',
  `creator`           varchar(64)  DEFAULT '' COMMENT '创建者',
  `create_time`       datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`           varchar(64)  DEFAULT '' COMMENT '更新者',
  `update_time`       datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`           bit(1)       NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id`         bigint(20)   NOT NULL DEFAULT 0 COMMENT '租户编号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_impact_key` (`tenant_id`, `impact_key`),
  KEY `idx_reservation_id` (`reservation_id`),
  KEY `idx_device_id` (`device_id`),
  KEY `idx_handle_status` (`handle_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=Dynamic COMMENT='仪器预约影响标记';

-- ================================================================
-- 2. 执行后验收（只读 SELECT）
-- ================================================================
SELECT table_name, table_rows FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name IN (
  'lab_instrument_fault_report','lab_instrument_repair_order',
  'lab_instrument_repair_history','lab_instrument_device_status_history',
  'lab_instrument_reservation_impact'
) ORDER BY table_name;

-- ================================================================
-- 3. 回退脚本（执行前确认无业务数据）
-- ================================================================
-- DROP TABLE IF EXISTS `lab_instrument_reservation_impact`;
-- DROP TABLE IF EXISTS `lab_instrument_device_status_history`;
-- DROP TABLE IF EXISTS `lab_instrument_repair_history`;
-- DROP TABLE IF EXISTS `lab_instrument_repair_order`;
-- DROP TABLE IF EXISTS `lab_instrument_fault_report`;
