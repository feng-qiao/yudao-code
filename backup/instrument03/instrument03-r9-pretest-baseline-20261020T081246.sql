-- MySQL dump 10.13  Distrib 8.0.12, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: labplatform
-- ------------------------------------------------------
-- Server version	8.0.12

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
 SET NAMES utf8 ;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `lab_instrument_booking_rule`
--

DROP TABLE IF EXISTS `lab_instrument_booking_rule`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_booking_rule` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `device_id` bigint(20) NOT NULL COMMENT '设备 id（1:1），逻辑关联 lab_instrument_device.id',
  `granularity_minutes` int(11) DEFAULT NULL COMMENT '时间粒度（分钟）；与最短时长分开（F13）；NULL=未配置',
  `min_duration_minutes` int(11) DEFAULT NULL COMMENT '最短时长（分钟，如 360=6h）；NULL=未配置（B10：不预设）',
  `max_duration_minutes` int(11) DEFAULT NULL COMMENT '最长时长（分钟）',
  `bookable_days_before` int(11) DEFAULT NULL COMMENT '允许预约的起始偏移（可往前 N 天）',
  `bookable_days_ahead` int(11) DEFAULT NULL COMMENT '允许预约的日期范围（往后 N 天）',
  `open_days` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '每周开放日（1-7 逗号分隔，可空=不限）',
  `open_start_time` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '每日开放开始（HH:mm）',
  `open_end_time` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '每日开放结束（HH:mm）',
  `allow_cross_day` bit(1) DEFAULT NULL COMMENT '是否允许跨天预约（B7 已裁决 2026-10-15 保留列）：1 允许；0/NULL 均视为不允许。默认口径由业务层判定，不写库默认值',
  `allow_admin_adjust_after_start` bit(1) NOT NULL DEFAULT b'1' COMMENT '管理员是否可在开始后调整',
  `enabled` bit(1) NOT NULL DEFAULT b'0' COMMENT '规则启用（0=不可预约，F15：未配置不得采用默认粒度）',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_rule_tenant_device` (`tenant_id`,`device_id`) USING BTREE,
  KEY `idx_device_id` (`device_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='设备预约规则配置（1:1）';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_booking_rule`
--

LOCK TABLES `lab_instrument_booking_rule` WRITE;
/*!40000 ALTER TABLE `lab_instrument_booking_rule` DISABLE KEYS */;
INSERT INTO `lab_instrument_booking_rule` VALUES (1,2,30,30,240,0,7,'1,2,3,4,5','09:00','18:00',_binary '\0',_binary '\0',_binary '','INSTRUMENT-03 第一关验收规则 工作日09:00-18:00 粒度30min 时长30-240min','282','2026-10-20 00:25:42','282','2026-10-20 00:25:42',_binary '\0',162);
/*!40000 ALTER TABLE `lab_instrument_booking_rule` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_instrument_booking_window`
--

DROP TABLE IF EXISTS `lab_instrument_booking_window`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_booking_window` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `device_id` bigint(20) NOT NULL COMMENT '设备 id（1:N），逻辑关联 lab_instrument_device.id',
  `window_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '窗口/批次名称',
  `open_days` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '每周开放日（1-7 逗号分隔）',
  `open_start_time` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '开放时段开始（HH:mm）',
  `open_end_time` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '开放时段结束（HH:mm）',
  `target_date_start` date DEFAULT NULL COMMENT '开放目标日期范围开始',
  `target_date_end` date DEFAULT NULL COMMENT '开放目标日期范围结束',
  `target_week_mapping` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '开放日→目标日期映射说明（文本，F14：不写死业务规则）',
  `capacity` int(11) DEFAULT NULL COMMENT '窗口可预约能力（容量，可空=不限）',
  `used_count` int(11) NOT NULL DEFAULT '0' COMMENT '已使用量',
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/CLOSED',
  `sort` int(11) DEFAULT '0' COMMENT '排序',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_device_status` (`device_id`,`status`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='酶标仪开放窗口（1:N）';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_booking_window`
--

LOCK TABLES `lab_instrument_booking_window` WRITE;
/*!40000 ALTER TABLE `lab_instrument_booking_window` DISABLE KEYS */;
/*!40000 ALTER TABLE `lab_instrument_booking_window` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_instrument_qualification`
--

DROP TABLE IF EXISTS `lab_instrument_qualification`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_qualification` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint(20) NOT NULL COMMENT '用户 id，关联 system_users.id',
  `user_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '姓名快照',
  `target_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'DEVICE' COMMENT '目标类型：第一期固定 DEVICE（C4）',
  `target_id` bigint(20) NOT NULL COMMENT '目标设备 id，关联 lab_instrument_device.id',
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE 生效 / EXPIRED 已到期 / SUSPENDED 暂停中 / REVOKED 已撤销',
  `source_apply_id` bigint(20) NOT NULL COMMENT '来源申请单 id，关联 lab_instrument_qualification_apply.id',
  `granted_time` datetime NOT NULL COMMENT '生效时间',
  `expire_time` datetime DEFAULT NULL COMMENT '到期时间（空=长期有效）',
  `revoke_time` datetime DEFAULT NULL COMMENT '撤销时间',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_user_target` (`user_id`,`target_type`,`target_id`,`status`) USING BTREE,
  KEY `idx_target` (`target_type`,`target_id`,`status`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='用户当前有效仪器资质';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_qualification`
--

LOCK TABLES `lab_instrument_qualification` WRITE;
/*!40000 ALTER TABLE `lab_instrument_qualification` DISABLE KEYS */;
INSERT INTO `lab_instrument_qualification` VALUES (1,281,'189140002','DEVICE',2,'SUSPENDED',1,'2026-10-15 16:52:09',NULL,NULL,NULL,'278','2026-10-15 16:52:09','278','2026-10-15 16:55:09',_binary '\0',162),(2,281,'189140002','DEVICE',1,'ACTIVE',2,'2026-10-15 17:22:18',NULL,NULL,NULL,'278','2026-10-15 17:22:18','278','2026-10-15 17:22:18',_binary '\0',162);
/*!40000 ALTER TABLE `lab_instrument_qualification` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_instrument_qualification_apply`
--

DROP TABLE IF EXISTS `lab_instrument_qualification_apply`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_qualification_apply` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `apply_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '申请单号（QAP-时间戳-随机，租户内唯一）',
  `target_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'DEVICE' COMMENT '目标类型：第一期固定 DEVICE（C4），PLATFORM 为待确认扩展，不写入不判定',
  `target_id` bigint(20) NOT NULL COMMENT '目标设备 id，关联 lab_instrument_device.id',
  `applicant_user_id` bigint(20) NOT NULL COMMENT '申请人用户ID，关联 system_users.id',
  `applicant_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '申请人姓名快照',
  `applicant_identity_type` tinyint(4) DEFAULT NULL COMMENT '身份快照（来源 system_users.identity_type，第一期未回填，前向保留）',
  `supervisor` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '导师快照（来源 system_users.supervisor，第一期未回填，前向保留）',
  `reason` varchar(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '申请理由',
  `attachment_file_id` bigint(20) DEFAULT NULL COMMENT '附件文件ID（可选），关联 infra_file.id',
  `attachment_file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '附件名快照',
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING' COMMENT '状态：PENDING 待审核 / APPROVED 通过 / REJECTED 驳回 / CANCELED 已撤回',
  `apply_time` datetime NOT NULL COMMENT '申请时间',
  `auditor_user_id` bigint(20) DEFAULT NULL COMMENT '审核人用户ID',
  `auditor_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '审核人姓名快照',
  `audit_time` datetime DEFAULT NULL COMMENT '审核时间',
  `audit_result` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '审核结果：APPROVED / REJECTED',
  `audit_opinion` varchar(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '审核意见（驳回必填）',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_apply_tenant_no` (`tenant_id`,`apply_no`) USING BTREE,
  KEY `idx_target_status` (`target_type`,`target_id`,`status`) USING BTREE,
  KEY `idx_applicant` (`applicant_user_id`,`status`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='仪器使用资质申请单';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_qualification_apply`
--

LOCK TABLES `lab_instrument_qualification_apply` WRITE;
/*!40000 ALTER TABLE `lab_instrument_qualification_apply` DISABLE KEYS */;
INSERT INTO `lab_instrument_qualification_apply` VALUES (1,'QAP-20261015165208310-4055','DEVICE',2,281,'189140002',NULL,NULL,'acceptance test apply',NULL,NULL,'APPROVED','2026-10-15 16:52:08',278,'1','2026-10-15 16:52:09','APPROVED','approve',NULL,'281','2026-10-15 16:52:08','278','2026-10-15 16:52:08',_binary '\0',162),(2,'QAP-20261015165208439-6377','DEVICE',1,281,'189140002',NULL,NULL,'scrapped',NULL,NULL,'APPROVED','2026-10-15 16:52:08',278,'1','2026-10-15 17:22:18','APPROVED','approve under active suspend',NULL,'281','2026-10-15 16:52:08','278','2026-10-15 17:22:17',_binary '\0',162);
/*!40000 ALTER TABLE `lab_instrument_qualification_apply` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_instrument_qualification_apply_history`
--

DROP TABLE IF EXISTS `lab_instrument_qualification_apply_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_qualification_apply_history` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `apply_id` bigint(20) NOT NULL COMMENT '申请单 id，关联 lab_instrument_qualification_apply.id',
  `action` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '动作：SUBMIT 提交 / APPROVE 通过 / REJECT 驳回 / CANCEL 撤回 / RESUBMIT 重新提交',
  `from_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '变更前状态',
  `to_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '变更后状态',
  `operator_user_id` bigint(20) NOT NULL COMMENT '操作人用户ID',
  `operator_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '操作人姓名快照',
  `action_time` datetime NOT NULL COMMENT '操作时间',
  `opinion` varchar(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '意见/原因',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_apply_id` (`apply_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='仪器使用资质审核历史（只增不改）';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_qualification_apply_history`
--

LOCK TABLES `lab_instrument_qualification_apply_history` WRITE;
/*!40000 ALTER TABLE `lab_instrument_qualification_apply_history` DISABLE KEYS */;
INSERT INTO `lab_instrument_qualification_apply_history` VALUES (1,1,'SUBMIT',NULL,'PENDING',281,'189140002','2026-10-15 16:52:08',NULL,NULL,'281','2026-10-15 16:52:08','281','2026-10-15 16:52:08',_binary '\0',162),(2,2,'SUBMIT',NULL,'PENDING',281,'189140002','2026-10-15 16:52:08',NULL,NULL,'281','2026-10-15 16:52:08','281','2026-10-15 16:52:08',_binary '\0',162),(3,1,'APPROVE','PENDING','APPROVED',278,'1','2026-10-15 16:52:09','approve',NULL,'278','2026-10-15 16:52:09','278','2026-10-15 16:52:09',_binary '\0',162),(4,2,'APPROVE','PENDING','APPROVED',278,'1','2026-10-15 17:22:18','approve under active suspend',NULL,'278','2026-10-15 17:22:18','278','2026-10-15 17:22:18',_binary '\0',162);
/*!40000 ALTER TABLE `lab_instrument_qualification_apply_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_instrument_manager`
--

DROP TABLE IF EXISTS `lab_instrument_manager`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_manager` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `scope` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '范围：DEVICE 设备负责人 / PLATFORM 平台负责人 / ROOM_REPAIR 实验室维修负责人',
  `target_id` bigint(20) NOT NULL COMMENT '目标主体ID（scope 分别指向 device/platform/room 的 id）',
  `manager_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PRIMARY' COMMENT '负责人类型：PRIMARY 主负责人 / REPAIR 维修负责人 / BACKUP 备用',
  `manager_user_id` bigint(20) NOT NULL COMMENT '负责人用户ID，关联 system_users.id（正式业务关系，非字典，F19）',
  `manager_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '负责人姓名快照',
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE 生效 / RELEASED 已解除',
  `effective_from` datetime NOT NULL COMMENT '生效时间',
  `effective_to` datetime DEFAULT NULL COMMENT '失效时间（解除/变更时置值，不物理删除）',
  `assign_reason` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '分配/变更原因',
  `release_reason` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '解除原因',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_scope_target` (`scope`,`target_id`,`status`) USING BTREE,
  KEY `idx_manager_user` (`manager_user_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='仪器负责人分配与变更历史';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_manager`
--

LOCK TABLES `lab_instrument_manager` WRITE;
/*!40000 ALTER TABLE `lab_instrument_manager` DISABLE KEYS */;
INSERT INTO `lab_instrument_manager` VALUES (1,'ROOM_REPAIR',1,'REPAIR',265,'大风和','RELEASED','2026-10-15 08:04:38','2026-10-15 08:05:56','G26-first','G26-release-first',NULL,'278','2026-10-15 08:04:38','278','2026-10-15 08:05:56',_binary '\0',162),(2,'ROOM_REPAIR',1,'REPAIR',281,'189140002','ACTIVE','2026-10-15 08:04:38',NULL,'G26-second',NULL,NULL,'278','2026-10-15 08:04:38','278','2026-10-15 08:04:38',_binary '\0',162),(3,'ROOM_REPAIR',1,'REPAIR',265,'大风和','ACTIVE','2026-10-15 08:09:56',NULL,'restore',NULL,NULL,'278','2026-10-15 08:09:56','278','2026-10-15 08:09:56',_binary '\0',162);
/*!40000 ALTER TABLE `lab_instrument_manager` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_instrument_suspend`
--

DROP TABLE IF EXISTS `lab_instrument_suspend`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_suspend` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint(20) NOT NULL COMMENT '被暂停用户 id，关联 system_users.id',
  `user_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '姓名快照',
  `scope_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '暂停范围：SINGLE 单仪器 / ALL 全仪器，字典 lab_instrument_suspend_scope',
  `device_id` bigint(20) DEFAULT NULL COMMENT '单仪器暂停时的设备 id（scope_type=SINGLE 时必填）',
  `preset_days` int(11) DEFAULT NULL COMMENT '预设时长天数（1/3/7/14/30）；自定义截止时置 NULL',
  `start_time` datetime NOT NULL COMMENT '暂停开始时间',
  `end_time` datetime NOT NULL COMMENT '暂停截止时间',
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE 生效 / RELEASED 提前解除 / EXPIRED 已到期',
  `reason` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '暂停原因（必填）',
  `operator_user_id` bigint(20) NOT NULL COMMENT '创建操作人用户ID',
  `operator_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '创建操作人姓名快照',
  `release_time` datetime DEFAULT NULL COMMENT '提前解除时间',
  `release_operator_id` bigint(20) DEFAULT NULL COMMENT '解除操作人用户ID',
  `release_reason` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '提前解除原因',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_user_status` (`user_id`,`status`) USING BTREE,
  KEY `idx_user_device` (`user_id`,`device_id`,`status`) USING BTREE,
  KEY `idx_end_time` (`status`,`end_time`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='用户人工暂停记录（历史全保留）';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_suspend`
--

LOCK TABLES `lab_instrument_suspend` WRITE;
/*!40000 ALTER TABLE `lab_instrument_suspend` DISABLE KEYS */;
INSERT INTO `lab_instrument_suspend` VALUES (1,281,'189140002','SINGLE',2,7,'2026-10-15 16:52:09','2026-10-22 16:52:09','RELEASED','acceptance single suspend',278,'1','2026-10-15 16:52:10',278,'acceptance release',NULL,'278','2026-10-15 16:52:09','278','2026-10-15 16:52:09',_binary '\0',162),(2,281,'189140002','ALL',NULL,3,'2026-10-15 16:52:10','2026-10-18 16:52:10','RELEASED','acceptance all suspend',278,'1','2026-10-15 16:54:01',278,'pre-concurrency release',NULL,'278','2026-10-15 16:52:10','278','2026-10-15 16:54:01',_binary '\0',162),(3,281,'189140002','ALL',NULL,7,'2026-10-15 16:55:10','2026-10-22 16:55:10','ACTIVE','concurrency probe',278,'1',NULL,NULL,NULL,NULL,'278','2026-10-15 16:55:10','278','2026-10-15 16:55:10',_binary '\0',162);
/*!40000 ALTER TABLE `lab_instrument_suspend` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_instrument_reservation`
--

DROP TABLE IF EXISTS `lab_instrument_reservation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_reservation` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `reservation_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '预约单号（B8 已裁决 2026-10-15：R+yyyyMMdd+5位Redis自增）',
  `device_id` bigint(20) NOT NULL COMMENT '设备 id，逻辑关联 lab_instrument_device.id',
  `user_id` bigint(20) NOT NULL COMMENT '预约人 user id，逻辑关联 system_users.id',
  `user_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '预约人姓名快照',
  `qualification_id` bigint(20) DEFAULT NULL COMMENT '准入校验时使用的资质 id（审计快照，可空）',
  `start_time` datetime NOT NULL COMMENT '预约开始（左闭）',
  `end_time` datetime NOT NULL COMMENT '预约结束（右开）',
  `duration_minutes` int(11) NOT NULL COMMENT '时长（分钟）',
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING' COMMENT '状态：PENDING/FINISHED/CANCELED/VOIDED（IN_USE 预留不启用；NO_SHOW 已删除 C1）',
  `purpose` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '用途',
  `actual_start_time` datetime DEFAULT NULL COMMENT '实际开始（第一期不自动写入，仅手工登记）',
  `actual_end_time` datetime DEFAULT NULL COMMENT '实际结束（同上）',
  `finish_time` datetime DEFAULT NULL COMMENT '完成时间（手工登记完成时写入，B11-③）',
  `cancel_time` datetime DEFAULT NULL COMMENT '取消时间',
  `cancel_by` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '取消方：USER/MANAGER/ADMIN',
  `cancel_reason` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '取消原因',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_reservation_tenant_no` (`tenant_id`,`reservation_no`) USING BTREE,
  KEY `idx_device_time` (`device_id`,`start_time`,`end_time`,`status`) USING BTREE,
  KEY `idx_user_status` (`user_id`,`status`) USING BTREE,
  KEY `idx_start_time` (`start_time`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='普通仪器预约';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_reservation`
--

LOCK TABLES `lab_instrument_reservation` WRITE;
/*!40000 ALTER TABLE `lab_instrument_reservation` DISABLE KEYS */;
/*!40000 ALTER TABLE `lab_instrument_reservation` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_instrument_reservation_history`
--

DROP TABLE IF EXISTS `lab_instrument_reservation_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_reservation_history` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `reservation_id` bigint(20) NOT NULL COMMENT '预约 id，逻辑关联 lab_instrument_reservation.id',
  `action` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '动作：CREATE/ADJUST/CANCEL/FINISH/VOID（NO_SHOW 已删除 C1）',
  `operator_user_id` bigint(20) NOT NULL COMMENT '操作人用户 id',
  `operator_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '操作人姓名快照',
  `operator_role` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '操作角色：USER/MANAGER/ADMIN',
  `action_time` datetime NOT NULL COMMENT '操作时间',
  `before_start_time` datetime DEFAULT NULL COMMENT '变更前开始',
  `before_end_time` datetime DEFAULT NULL COMMENT '变更前结束',
  `after_start_time` datetime DEFAULT NULL COMMENT '变更后开始',
  `after_end_time` datetime DEFAULT NULL COMMENT '变更后结束',
  `before_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '变更前状态',
  `after_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '变更后状态',
  `reason` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '原因（管理员开始后调整必填）',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_reservation_id` (`reservation_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='预约变更及操作历史（只增不改）';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_reservation_history`
--

LOCK TABLES `lab_instrument_reservation_history` WRITE;
/*!40000 ALTER TABLE `lab_instrument_reservation_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `lab_instrument_reservation_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_instrument_credit_account`
--

DROP TABLE IF EXISTS `lab_instrument_credit_account`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_credit_account` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint(20) NOT NULL COMMENT '用户 id，关联 system_users.id',
  `user_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '姓名快照',
  `score` int(11) NOT NULL DEFAULT '100' COMMENT '当前信用分（初始 100；允许超过 100，允许负分，无上下限约束）',
  `initialized` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否已完成首次初始化（防重复赠送 100 分，F2）',
  `initialized_time` datetime DEFAULT NULL COMMENT '首次初始化时间',
  `last_change_time` datetime DEFAULT NULL COMMENT '最近一次分数变动时间',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_account_tenant_user` (`tenant_id`,`user_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='用户统一信用账户';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_credit_account`
--

LOCK TABLES `lab_instrument_credit_account` WRITE;
/*!40000 ALTER TABLE `lab_instrument_credit_account` DISABLE KEYS */;
INSERT INTO `lab_instrument_credit_account` VALUES (1,281,'189140002',70,_binary '','2026-10-15 16:52:09','2026-10-15 16:54:48',NULL,'278','2026-10-15 16:52:09','278','2026-10-15 16:54:48',_binary '\0',162);
/*!40000 ALTER TABLE `lab_instrument_credit_account` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_instrument_credit_flow`
--

DROP TABLE IF EXISTS `lab_instrument_credit_flow`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_credit_flow` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `account_id` bigint(20) NOT NULL COMMENT '信用账户 id，关联 lab_instrument_credit_account.id',
  `user_id` bigint(20) NOT NULL COMMENT '用户 id（冗余，便于按用户查询）',
  `change_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '变动类型：ADD 加分 / DEDUCT 扣分',
  `score_change` int(11) NOT NULL COMMENT '变动值（加分正数、扣分负数）',
  `score_before` int(11) NOT NULL COMMENT '变动前分数',
  `score_after` int(11) NOT NULL COMMENT '变动后分数',
  `reason_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '原因类型，字典 lab_instrument_credit_reason（VIOLATION/OVERDUE/REWARD/MANUAL，第一期仅人工登记，C1）',
  `biz_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '关联业务类型：RESERVATION/SUSPEND/FREEZE_BATCH/REPAIR/MANUAL',
  `biz_id` bigint(20) DEFAULT NULL COMMENT '关联业务 id',
  `reason` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '变动原因（必填，审计依据）',
  `operator_user_id` bigint(20) DEFAULT NULL COMMENT '操作人用户ID（人工调整时；系统自动为 NULL）',
  `operator_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '操作人姓名快照',
  `operate_time` datetime NOT NULL COMMENT '操作时间',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_user_time` (`user_id`,`operate_time`) USING BTREE,
  KEY `idx_biz` (`biz_type`,`biz_id`) USING BTREE,
  KEY `idx_account` (`account_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='信用积分流水（不可变，只增）';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_credit_flow`
--

LOCK TABLES `lab_instrument_credit_flow` WRITE;
/*!40000 ALTER TABLE `lab_instrument_credit_flow` DISABLE KEYS */;
INSERT INTO `lab_instrument_credit_flow` VALUES (1,1,281,'DEDUCT',-10,100,90,'VIOLATION',NULL,NULL,'acceptance deduct',278,'1','2026-10-15 16:52:09',NULL,'278','2026-10-15 16:52:09','278','2026-10-15 16:52:09',_binary '\0',162),(2,1,281,'DEDUCT',-10,90,80,'VIOLATION',NULL,NULL,'concurrency deduct',278,'1','2026-10-15 16:54:48',NULL,'278','2026-10-15 16:54:48','278','2026-10-15 16:54:48',_binary '\0',162),(3,1,281,'DEDUCT',-10,80,70,'VIOLATION',NULL,NULL,'concurrency deduct',278,'1','2026-10-15 16:54:48',NULL,'278','2026-10-15 16:54:48','278','2026-10-15 16:54:48',_binary '\0',162);
/*!40000 ALTER TABLE `lab_instrument_credit_flow` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_instrument_device`
--

DROP TABLE IF EXISTS `lab_instrument_device`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lab_instrument_device` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `device_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '设备编号（业务唯一）',
  `name` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '设备名称',
  `model` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '型号',
  `spec` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '规格',
  `category` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '设备类别，字典 lab_instrument_category',
  `repair_scope` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'SCIENCE' COMMENT '维修口径：SCIENCE 科研仪器 / GENERAL 通用仪器，字典 lab_instrument_repair_scope',
  `platform_id` bigint(20) DEFAULT NULL COMMENT '所属平台，关联 lab_instrument_platform.id',
  `room_id` bigint(20) DEFAULT NULL COMMENT '所属房间，关联 lab_instrument_room.id（空=未登记位置）',
  `asset_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '资产编号',
  `manufacturer` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '生产厂家',
  `purchase_date` date DEFAULT NULL COMMENT '购置日期',
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'NORMAL' COMMENT '状态：NORMAL 正常 / MAINTENANCE 维护 / FAULT 故障 / DISABLED 停用 / SCRAPPED 报废',
  `bookable` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否允许预约（第一期仅档案标记，预约能力属 INSTRUMENT-03）',
  `image_file_id` bigint(20) DEFAULT NULL COMMENT '设备图片文件ID，关联 infra_file.id（第一期可能为空，见文件头说明）',
  `image_file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '设备图片文件名快照',
  `image_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '设备图片访问URL（infra 上传返回值，第一期图片展示依据）',
  `sort` int(11) DEFAULT '0' COMMENT '排序',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_device_tenant_no` (`tenant_id`,`device_no`) USING BTREE,
  KEY `idx_platform_id` (`platform_id`) USING BTREE,
  KEY `idx_room_id` (`room_id`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE,
  KEY `idx_category` (`category`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='仪器设备档案';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_instrument_device`
--

LOCK TABLES `lab_instrument_device` WRITE;
/*!40000 ALTER TABLE `lab_instrument_device` DISABLE KEYS */;
INSERT INTO `lab_instrument_device` VALUES (1,'DEV-TEST01','验收测试酶标仪01','MK3',NULL,'MICROPLATE_READER','SCIENCE',1,1,'ZC-001','赛默飞',NULL,'SCRAPPED',_binary '',NULL,NULL,NULL,1,NULL,'278','2026-10-15 08:00:34','278','2026-10-15 08:09:56',_binary '\0',162),(2,'DEV-TEST02','Clean Device 02','M',NULL,'SCIENCE','GENERAL',1,1,NULL,NULL,NULL,'NORMAL',_binary '',NULL,NULL,NULL,2,NULL,'278','2026-10-15 08:10:29','278','2026-10-15 08:10:29',_binary '\0',162);
/*!40000 ALTER TABLE `lab_instrument_device` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `system_users`
--

DROP TABLE IF EXISTS `system_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `system_users` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  `username` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '用户账号',
  `password` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '密码',
  `nickname` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '用户昵称',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `dept_id` bigint(20) DEFAULT NULL COMMENT '部门ID',
  `post_ids` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '岗位编号数组',
  `email` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '用户邮箱',
  `mobile` varchar(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '手机号码',
  `sex` tinyint(4) DEFAULT '0' COMMENT '用户性别',
  `avatar` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '头像地址',
  `status` tinyint(4) NOT NULL DEFAULT '0' COMMENT '帐号状态（0正常 1停用）',
  `login_ip` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '最后登录IP',
  `login_date` datetime DEFAULT NULL COMMENT '最后登录时间',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  `identity_type` tinyint(4) DEFAULT NULL COMMENT '身份类别：1硕士 2博士 3博士后 4科研助理 5教师',
  `research_direction` tinyint(4) DEFAULT NULL COMMENT '研究方向：1-7 固定枚举',
  `supervisor` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '导师',
  `instructor` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '指导教师',
  `start_ymd` varchar(7) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '开始年月，格式 yyyy-MM',
  `end_ymd` varchar(7) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '结束年月，格式 yyyy-MM',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_username` (`username`) USING BTREE,
  KEY `idx_mobile` (`mobile`) USING BTREE,
  KEY `idx_email` (`email`) USING BTREE,
  KEY `idx_dept_id` (`dept_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=289 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户信息表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `system_users`
--

LOCK TABLES `system_users` WRITE;
/*!40000 ALTER TABLE `system_users` DISABLE KEYS */;
INSERT INTO `system_users` VALUES (1,'admin','$2a$04$.vd8nPeLwxt6hnSzmAoAyul8BOLX7Cib6QhcxRe30rfvrIPQHH1OG','系统管理员','管理员',103,'[1,2]','13aoteman@126.com','18818260272',1,'http://test.yudao.iocoder.cn/20260517/blob_1778998103688.png',0,'0:0:0:0:0:0:0:1','2026-10-16 00:31:04','admin','2021-01-05 17:03:47',NULL,'2026-10-16 00:31:04',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(100,'yudao','$2a$04$.vd8nPeLwxt6hnSzmAoAyul8BOLX7Cib6QhcxRe30rfvrIPQHH1OG','演示用户','不要吓我',104,'[1]','yudao@iocoder.cn','15601691300',1,NULL,0,'127.0.0.1','2026-10-12 16:11:57','','2021-01-07 09:07:17',NULL,'2026-10-12 16:11:57',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(103,'yuanma','$2a$04$k/d6mc0nySN0i2udwcI8Ee8V5aM5OHixBRbQfXmPuFTUl3Zf/DBs.','演示用户',NULL,106,NULL,'yuanma@iocoder.cn','15601701300',0,NULL,0,'0:0:0:0:0:0:0:1','2026-04-27 13:19:27','','2021-01-13 23:50:35',NULL,'2026-10-10 07:58:45',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(104,'test','$2a$04$.vd8nPeLwxt6hnSzmAoAyul8BOLX7Cib6QhcxRe30rfvrIPQHH1OG','测试号',NULL,107,'[1,2]','111@qq.com','15601691200',1,NULL,0,'127.0.0.1','2026-10-10 14:25:58','','2021-01-21 02:13:53',NULL,'2026-10-10 14:25:58',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(112,'newobject','$2a$04$dB0z8Q819fJWz0hbaLe6B.VfHCjYgWx6LFfET5lyz3JwcqlyCkQ4C','新对象',NULL,100,'[]','','15601691235',1,NULL,0,'127.0.0.1','2026-06-17 09:07:20','1','2022-02-23 19:08:03',NULL,'2026-06-17 09:07:20',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(114,'hrmgr','$2a$10$TR4eybBioGRhBmDBWkqWLO6NIh3mzYa8KBKDDB5woiGYFVlRAi.fu','hr 小姐姐',NULL,NULL,'[5]','','15601691236',1,NULL,0,'0:0:0:0:0:0:0:1','2026-01-04 18:16:01','1','2022-03-19 21:50:58',NULL,'2026-01-04 18:16:01',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(115,'aotemane','$2a$04$GcyP0Vyzb2F2Yni5PuIK9ueGxM0tkZGMtDwVRwrNbtMvorzbpNsV2','阿呆','11222',102,'[1,2]','7648@qq.com','15601691229',2,NULL,0,'',NULL,'1','2022-04-30 02:55:43','1','2025-04-21 14:23:08',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(117,'admin123','$2a$04$sEtimsHu9YCkYY4/oqElHem2Ijc9ld20eYO6lN.g/21NfLUTDLB9W','测试号02','1111',100,'[2]','','15601691234',1,NULL,0,'0:0:0:0:0:0:0:1','2024-10-02 10:16:20','1','2022-07-09 17:40:26','1','2025-05-14 09:56:04',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(118,'goudan','$2a$04$3suGZjnA6rM5bErf38u1felbgqbsPHGdRG3l9NkxPCEt2ah9Y6aJi','狗蛋',NULL,103,'[1]','','15601691239',1,NULL,0,'0:0:0:0:0:0:0:1','2025-11-23 15:28:25','1','2022-07-09 17:44:43',NULL,'2025-11-23 15:28:25',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(139,'wwbwwb','$2a$04$FJLIyg8lbPytP29pbZaiU.LesJvCsYfEaHqQfB0pGQhK3e9BeZmLy','小秃头','123',108,'[2,4]','','',1,NULL,0,'0:0:0:0:0:0:0:1','2024-09-10 21:03:58',NULL,'2024-09-10 21:03:58','1','2025-12-15 22:38:15',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(141,'admin1','$2a$04$oj6F6d7HrZ70kYVD3TNzEu.m3TPUzajOVuC66zdKna8KRerK1FmVa','新用户',NULL,NULL,NULL,'','',0,'',0,'127.0.0.1','2026-06-17 09:37:18','1','2025-04-08 13:09:07',NULL,'2026-06-17 09:37:18',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(142,'test01','$2a$04$4bCYWZkjxxOC4QE0LY2M9uEEKWeJbLfs489NFtQoyidL5I0FndRaO','test01','',NULL,'[]','','19021719925',1,'',0,'0:0:0:0:0:0:0:1','2026-06-17 10:44:58','1','2025-07-09 21:07:10',NULL,'2026-06-17 10:44:58',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(143,'a00001','$2a$04$GhVHFviOw/SsTmiQtifHJesDYFlHMeGK7OWh7aGCCjGGVCmbHVAwa','a00001',NULL,104,NULL,'','',0,'',0,'0:0:0:0:0:0:0:1','2025-12-01 16:10:13',NULL,'2025-12-01 16:10:13','1','2025-12-05 21:34:05',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(144,'aoteman001','$2a$04$omQOmhz8OyUFBKw77nr8KOtMp6xdvoQ1gWStjk9r8.OYT3Bv6oEYe','aoteman00112',NULL,104,NULL,'','',0,'',1,'0:0:0:0:0:0:0:1','2025-12-01 17:05:27','1','2025-12-01 17:05:27','1','2026-06-15 18:58:56',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(240,'hrmteam','$2a$04$JedFPcbQWaOf1OM4IrVbgeNnefdSuz4F.ktffitOu5ZGIA01fdZmm','HRM团队负责人','本地团队工作台演示账号',103,'[]','','',1,'',0,'0:0:0:0:0:0:0:1','2026-08-01 13:28:58','1','2026-08-01 11:56:19',NULL,'2026-08-01 13:28:58',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(249,'plsmtest02','$2a$04$jxoROtKJLnvHPrLnDlKEC.xmhyQrfFQ1CFHAta9KtZBmqevRARJvi','plsmtest02',NULL,100,NULL,'','',0,'',0,'0:0:0:0:0:0:0:1','2026-10-04 23:41:38','1','2026-10-04 23:37:16','1','2026-10-04 23:42:13',_binary '',1,NULL,NULL,NULL,NULL,NULL,NULL),(250,'mgr02','$2a$04$/JRXxfp4pH94YplCoB6CVOQmzmGE0fibrCcyvRv1mtVL4RbpICkUu','mgr02',NULL,100,NULL,'','',0,'',0,'',NULL,'1','2026-10-04 23:54:24','1','2026-10-04 23:54:24',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(257,'b3bnormal','$2a$04$FewDcw.1zODcqRgK6e48XuPvCNoV5Bo51Dr2NwBLCot.0ugtWsumC','B3B????',NULL,NULL,NULL,'','',0,'',0,'0:0:0:0:0:0:0:1','2026-10-07 09:16:22','1','2026-10-05 10:19:25',NULL,'2026-10-07 09:16:22',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(258,'b3bmgrA','$2a$04$.vd8nPeLwxt6hnSzmAoAyul8BOLX7Cib6QhcxRe30rfvrIPQHH1OG','B3B???A',NULL,NULL,NULL,'','',0,'',0,'0:0:0:0:0:0:0:1','2026-10-08 00:02:44','1','2026-10-05 10:19:25',NULL,'2026-10-08 00:02:44',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(259,'b3bmgrB','$2a$04$.vd8nPeLwxt6hnSzmAoAyul8BOLX7Cib6QhcxRe30rfvrIPQHH1OG','B3B???B',NULL,NULL,NULL,'','',0,'',0,'127.0.0.1','2026-10-05 23:09:45','1','2026-10-05 10:19:25',NULL,'2026-10-05 23:09:45',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(260,'qinghy','$2a$04$teD3iIHA5HaTilIVep1rceoDNJs5n0nve0DTt5EIu2bn1bdlsAJaG','青禾一',NULL,122,NULL,'972323177@qq.com','17640272194',1,'',0,'127.0.0.1','2026-10-20 08:09:25','1','2026-10-10 09:35:58',NULL,'2026-10-20 08:09:25',_binary '\0',162,NULL,NULL,NULL,NULL,NULL,NULL),(261,'regtest008','$2a$04$Lj7LSpASsgXqQeDrTgk3yel2d7tnRysYx1dhaelQBuHGmgXjaDRRm','集成测试008',NULL,NULL,NULL,'regtest008@example.com','15601691308',0,'',0,'127.0.0.1','2026-10-12 14:50:07','1','2026-10-11 15:53:39','261','2026-10-12 14:50:07',_binary '\0',1,3,5,'R3导师测试','R3指导教师测试','2023-09','2026-06'),(262,'regtest009','$2a$04$LQ2tEyvbwbbmrPUp6WmJjuGj8HlfwwVpCpZdd049XoqkajPyMizse','集成测试009改',NULL,NULL,NULL,'regtest009@example.com','15601691309',0,'',0,'',NULL,'1','2026-10-11 16:32:06','1','2026-10-11 16:32:06',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(263,'regtest010','$2a$04$OTa0DYKsUunuqN7FWLRVEOy8RKHrHid3kjZNL.UinjXqHedmrVSPS','集成测试010',NULL,NULL,NULL,'regtest010@example.com','15601691310',0,'',0,'',NULL,'1','2026-10-11 16:32:38','1','2026-10-11 16:32:38',_binary '\0',1,NULL,NULL,NULL,NULL,NULL,NULL),(264,'probenosuchuser9','$2a$04$mvGPWsIc2uL3hYwu2Zz62uTvwzcmRNKrPTwTWHCOJmM4YIKAouQyy','probe',NULL,NULL,NULL,'','',0,'',0,'127.0.0.1','2026-10-11 21:21:53',NULL,'2026-10-11 21:21:53',NULL,'2026-10-11 21:21:53',_binary '\0',162,NULL,NULL,NULL,NULL,NULL,NULL),(265,'189140001','$2a$04$gRLDMDH3GfRmQji5rfi4auEEpvsqeP08GqvO2jdEQmHq9GzDRZmQa','大风和',NULL,122,NULL,'11@qq.com','17611111111',0,'',0,'127.0.0.1','2026-10-20 08:10:07','260','2026-10-11 23:36:49',NULL,'2026-10-20 08:10:07',_binary '\0',162,NULL,NULL,NULL,NULL,NULL,NULL),(266,'189140003','$2a$04$0zyQJzuYuGug5IYr8Np.5.ZAVDbQLogiXD2MJ31aQFlFGI5gFfnvC','1',NULL,NULL,NULL,'1@qq.com','17611111112',0,'',0,'127.0.0.1','2026-10-13 00:05:27','260','2026-10-12 00:13:51',NULL,'2026-10-13 00:05:27',_binary '\0',162,NULL,NULL,NULL,NULL,NULL,NULL),(268,'r3imp001','$2a$04$.ZCyXbHJDFY20FMWDr6mFe/.M4CMPWMMictwP/jF4cS3CcPWybEju','R3管理新增测试改',NULL,103,NULL,'r3imp001@test.local','13900001001',1,'',0,'',NULL,'100','2026-10-12 15:04:33','100','2026-10-12 15:05:53',_binary '\0',1,4,7,'R3管理导师改','R3管理指导改','2021-09','2024-06'),(269,'r3imp002','$2a$04$/Y499XAIVF.uNUfrQkYMa.sdi7a8gOSIMAuMB54x5gtj.v5E5Bx06','R3无部门岗位测试',NULL,NULL,NULL,'r3imp002@test.local','13900001002',1,'',0,'',NULL,'100','2026-10-12 15:05:02','100','2026-10-12 15:05:02',_binary '\0',1,5,3,NULL,NULL,NULL,NULL),(270,'r3imp101','$2a$04$8FSRO.85JMyhcrsFksXDxe4TSAXrU1O9c71L8JxfuyuVhwivpuk3C','R3导入合法一',NULL,103,'[]','r3imp101@test.local','13900001101',1,'',0,'',NULL,'100','2026-10-12 15:07:37','100','2026-10-12 15:07:37',_binary '\0',1,1,1,'导入导师甲','导入指导甲','2023-09','2026-06'),(271,'r3imp102','$2a$04$GgrxYvjkSMj52uhBucaKj.13j/D1BoeHzrzstyU1RnY7scAO/bQD6','R3导入合法二',NULL,103,'[]','r3imp102@test.local','13900001102',2,'',0,'',NULL,'100','2026-10-12 15:07:37','100','2026-10-12 15:07:37',_binary '\0',1,4,2,NULL,NULL,'2024-03','2027-03'),(274,'189140004','$2a$04$UfkkGKyqbNgmLX8q3hRIZe.O.IEEJeso28kpDUWomE7.6dVKPjH1G','1',NULL,NULL,NULL,'111@qq.com','17611112111',0,'',0,'127.0.0.1','2026-10-13 00:05:01','260','2026-10-12 15:24:32',NULL,'2026-10-13 00:05:01',_binary '\0',162,NULL,NULL,NULL,NULL,NULL,NULL),(275,'u2cf420','$2a$04$hEd/mmnUCaMrWVLT5oW56./6tD9i4sMIEkXXQgTnGSjfrz8Vid8WW','???A420',NULL,NULL,NULL,'','',1,'',0,'',NULL,'100','2026-10-12 16:13:24','100','2026-10-12 16:13:24',_binary '',1,NULL,NULL,NULL,NULL,NULL,NULL),(276,'u2cf420','$2a$04$Cj4QWqVsRdQZerI7Y7Ta2eU13peez9O90jnpcUZEHkkUR341Gk5My','???B420',NULL,NULL,NULL,'','',1,'',0,'',NULL,'100','2026-10-12 16:13:24','100','2026-10-12 16:19:14',_binary '',1,NULL,NULL,NULL,NULL,NULL,NULL),(277,'u2rc869','$2a$04$nrD6idFYTc90lcPSKkQYD.lISLDpXWllIYKW5zQx7IK1wHefVyAAy','????????suffix',NULL,NULL,NULL,'u2rc869@test.com','13900000869',1,'',0,'',NULL,'100','2026-10-12 16:15:24','100','2026-10-12 16:19:15',_binary '',1,NULL,NULL,NULL,NULL,NULL,NULL),(278,'bencao','$2a$04$cFqQFSb2Pp2LeXfGKodUuuCZfdU7GU8jCotLuOXm5tQCaptWoFeie','1',NULL,NULL,NULL,'1112@qq.com','17611111115',0,'',0,'127.0.0.1','2026-10-20 08:10:08','260','2026-10-12 16:15:32',NULL,'2026-10-20 08:10:08',_binary '\0',162,4,1,NULL,NULL,'2026-10','2026-12'),(279,'shenpi','$2a$04$FmKlRnSdMkMUze2RNxo8G.LFdeYB9tXXvEIRD4i3pdWTJBQJkU7xC','1',NULL,NULL,NULL,'1114@qq.com','17611111116',0,'',0,'127.0.0.1','2026-10-20 08:10:08','260','2026-10-12 16:15:37',NULL,'2026-10-20 08:10:08',_binary '\0',162,4,1,NULL,NULL,'2026-10','2026-12'),(280,'u2nick451','$2a$04$R08HL/JTEIIbyz9scMBQy.ZvvDPNqY5kdjnU3E4DdlrjmiHsSj4EC','回收站中文451',NULL,NULL,NULL,'','',1,'',0,'',NULL,'100','2026-10-12 16:18:39','100','2026-10-12 16:18:39',_binary '',1,NULL,NULL,NULL,NULL,NULL,NULL),(281,'189140002','$2a$04$.KEX4zSO1uVLPvkVURRJZ..gdBt9omuSvIaVlqO9nJ3JK2CX9LsTW','189140002',NULL,NULL,NULL,'17611111112@qq.com','17611112212',0,'',0,'127.0.0.1','2026-10-20 08:10:07','279','2026-10-12 17:04:16',NULL,'2026-10-20 08:10:07',_binary '\0',162,1,1,'12','1222','2026-09','2026-12'),(282,'test906','$2a$04$u22.2Jzzi8n/I8L2bP/eGeHL6N2WYXfv4adVI6wALW3sQTe1FdDJW','test906-INSTRUMENT03验收','INSTRUMENT-03 第一关专用 仅906角色',NULL,NULL,'','',0,'',0,'127.0.0.1','2026-10-20 08:10:07','260','2026-10-20 00:23:02',NULL,'2026-10-20 08:10:07',_binary '\0',162,NULL,NULL,NULL,NULL,NULL,NULL),(283,'test908','$2a$04$bcSXMAkph7JkLVuBjeRZ/u0P27KPteZDeI6BI.O8Kgo3IjePAJwKu','test908-INSTRUMENT03验收','INSTRUMENT-03 第一关专用 仅908角色',NULL,NULL,'','',0,'',0,'127.0.0.1','2026-10-20 08:10:07','260','2026-10-20 00:23:26',NULL,'2026-10-20 08:10:07',_binary '\0',162,NULL,NULL,NULL,NULL,NULL,NULL),(284,'test905','$2a$04$RHyuQQv2uBfDBO8lSu4LfuzEm6Dw51ZteddqsLHLOucNl0FUNfCsm','test905-INSTRUMENT03验收','INSTRUMENT-03 第一关专用 仅905角色',NULL,NULL,'','',0,'',0,'127.0.0.1','2026-10-20 08:10:07','260','2026-10-20 00:23:27',NULL,'2026-10-20 08:10:07',_binary '\0',162,NULL,NULL,NULL,NULL,NULL,NULL),(285,'test904nq','$2a$04$9dS8RSxV.AE/NO515jBCxOP6xSAUG/ICTtEQJK7S/YjagFyZISt46','test904nq-INSTRUMENT03无资质','INSTRUMENT-03 第一关专用 仅904角色 不授device2资质',NULL,NULL,'','',0,'',0,'127.0.0.1','2026-10-20 08:10:07','260','2026-10-20 00:23:28',NULL,'2026-10-20 08:10:07',_binary '\0',162,NULL,NULL,NULL,NULL,NULL,NULL),(286,'18914005','$2a$04$faYlOySxv2cgfzPpheP0N.D1qUFDzkvNNfzJKFDE8r0MnuOdg8vDG','仪器管理员',NULL,NULL,NULL,'asd@qq.com','17623652365',0,'',0,'127.0.0.1','2026-10-20 08:10:08','278','2026-10-20 07:55:28',NULL,'2026-10-20 08:10:08',_binary '\0',162,4,5,NULL,NULL,'2026-12','2029-12'),(287,'u2verify01','$2a$04$v/kzYg/Pbgp7e811QD8r..j2yxjDbMtwTW/66fraTdKuoCHDiwKPq','验证U201',NULL,NULL,NULL,'u2verify01@test.com','13800001602',0,'',0,'',NULL,'278','2026-10-20 07:55:32','278','2026-10-20 07:55:32',_binary '\0',162,2,3,'张安U2','李宁U2','2026-09','2030-06'),(288,'r3user001','$2a$04$mRreRA/LE4CcZ4CMash8reIkDoKushqRWbxjAOvCgCb2Baq11aHXO','R3验收测试用户',NULL,NULL,NULL,'r3user001@test.local','13900001111',0,'',0,'',NULL,'278','2026-10-20 07:55:36','278','2026-10-20 07:55:36',_binary '\0',162,1,2,'验收导师A','验收教师B','2024-09','2027-06');
/*!40000 ALTER TABLE `system_users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `system_user_role`
--

DROP TABLE IF EXISTS `system_user_role`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `system_user_role` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编号',
  `user_id` bigint(20) NOT NULL COMMENT '用户ID',
  `role_id` bigint(20) NOT NULL COMMENT '角色ID',
  `creator` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '租户编号',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_user_id` (`user_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=128 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户和角色关联表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `system_user_role`
--

LOCK TABLES `system_user_role` WRITE;
/*!40000 ALTER TABLE `system_user_role` DISABLE KEYS */;
INSERT INTO `system_user_role` VALUES (1,1,1,'','2022-01-11 13:19:45','','2022-05-12 12:35:17',_binary '\0',1),(2,2,2,'','2022-01-11 13:19:45','','2022-05-12 12:35:13',_binary '\0',1),(5,100,1,'','2022-01-11 13:19:45','','2022-05-12 12:35:12',_binary '\0',1),(6,100,2,'','2022-01-11 13:19:45','','2022-05-12 12:35:11',_binary '\0',1),(10,103,1,'1','2022-01-11 13:19:45','1','2022-01-11 13:19:45',_binary '\0',1),(18,1,2,'1','2022-05-12 20:39:29','1','2022-05-12 20:39:29',_binary '\0',1),(22,115,2,'1','2022-07-21 22:08:30','1','2022-07-21 22:08:30',_binary '\0',1),(35,112,1,'1','2024-03-15 20:00:24','1','2024-03-15 20:00:24',_binary '\0',1),(36,118,1,'1','2024-03-17 09:12:08','1','2024-03-17 09:12:08',_binary '\0',1),(46,117,1,'1','2024-10-02 10:16:11','1','2024-10-02 10:16:11',_binary '\0',1),(47,104,2,'1','2025-01-04 10:40:33','1','2025-01-04 10:40:33',_binary '\0',1),(48,100,155,'1','2025-04-04 10:41:14','1','2025-04-04 10:41:14',_binary '\0',1),(49,142,1,'1','2025-07-23 09:11:42','1','2025-07-23 09:11:42',_binary '\0',1),(50,142,2,'1','2025-10-07 20:50:37','1','2025-10-07 20:50:37',_binary '\0',1),(51,139,1,'1','2025-12-05 22:36:57','1','2025-12-05 22:36:57',_binary '\0',1),(52,139,2,'1','2025-12-05 22:37:00','1','2025-12-05 22:37:00',_binary '\0',1),(53,114,2,'1','2026-01-04 18:15:40','1','2026-01-04 18:15:40',_binary '\0',1),(54,114,3,'1','2026-01-04 18:16:19','1','2026-01-04 18:16:19',_binary '\0',1),(82,104,162,'admin','2026-08-01 03:52:53','admin','2026-08-01 03:52:53',_binary '\0',1),(83,240,162,'1','2026-08-01 11:56:35','1','2026-08-01 11:56:35',_binary '\0',1),(94,249,169,'1','2026-10-04 23:40:07','1','2026-10-04 23:42:13',_binary '',1),(100,258,902,'1','2026-10-05 10:19:25','1','2026-10-05 10:19:25',_binary '\0',1),(101,259,902,'1','2026-10-05 10:19:25','1','2026-10-05 10:19:25',_binary '\0',1),(102,260,903,'1','2026-10-10 09:35:58','1','2026-10-10 09:35:58',_binary '\0',162),(103,265,904,'260','2026-10-11 23:36:49','260','2026-10-12 15:06:23',_binary '',162),(104,266,904,'260','2026-10-12 00:13:51','260','2026-10-12 15:07:02',_binary '',162),(106,274,904,'260','2026-10-12 15:24:32','260','2026-10-12 15:24:32',_binary '\0',162),(107,278,904,'260','2026-10-12 16:15:32','260','2026-10-12 16:15:32',_binary '\0',162),(108,279,904,'260','2026-10-12 16:15:37','260','2026-10-12 16:16:26',_binary '',162),(109,279,907,'260','2026-10-12 16:16:27','260','2026-10-12 16:16:27',_binary '\0',162),(110,278,905,'260','2026-10-12 16:16:40','260','2026-10-12 16:16:40',_binary '\0',162),(111,278,906,'260','2026-10-12 16:16:40','260','2026-10-12 16:16:40',_binary '\0',162),(112,274,905,'278','2026-10-12 16:23:45','278','2026-10-12 16:23:45',_binary '\0',162),(113,281,904,'279','2026-10-12 17:04:16','279','2026-10-12 17:04:16',_binary '\0',162),(114,266,904,'278','2026-10-12 17:05:38','278','2026-10-12 17:05:38',_binary '\0',162),(115,266,905,'278','2026-10-12 17:05:38','278','2026-10-12 17:05:38',_binary '\0',162),(116,265,904,'278','2026-10-12 17:12:16','278','2026-10-12 17:12:16',_binary '\0',162),(117,260,905,'260','2026-10-19 13:35:24','260','2026-10-19 13:35:24',_binary '\0',162),(118,260,906,'260','2026-10-19 13:35:24','260','2026-10-19 13:35:24',_binary '\0',162),(119,260,908,'260','2026-10-19 13:35:24','260','2026-10-19 13:35:24',_binary '\0',162),(120,282,906,'260','2026-10-20 00:23:54','260','2026-10-20 00:23:54',_binary '\0',162),(121,283,908,'260','2026-10-20 00:23:55','260','2026-10-20 00:23:55',_binary '\0',162),(122,284,905,'260','2026-10-20 00:23:56','260','2026-10-20 00:23:56',_binary '\0',162),(123,285,904,'260','2026-10-20 00:23:57','260','2026-10-20 00:23:57',_binary '\0',162),(124,286,904,'278','2026-10-20 07:55:28','278','2026-10-20 07:55:28',_binary '\0',162),(125,287,904,'278','2026-10-20 07:55:32','278','2026-10-20 07:55:32',_binary '\0',162),(126,288,904,'278','2026-10-20 07:55:36','278','2026-10-20 07:55:36',_binary '\0',162),(127,286,908,'278','2026-10-20 07:55:59','278','2026-10-20 07:55:59',_binary '\0',162);
/*!40000 ALTER TABLE `system_user_role` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 'labplatform'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-20  8:12:46
