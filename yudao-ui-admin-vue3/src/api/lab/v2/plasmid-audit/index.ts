import request from '@/config/axios'

/** 质粒审核（V2）—— 审核视角质粒信息 */
export interface PlasmidAuditViewVO {
  id: number // 主键ID
  plasmidNo?: string // 质粒编号
  seqNo?: number // 系统顺序号
  name?: string // 质粒名称
  recipient?: string // 受体
  species?: string // 种类
  resistance?: string // 抗性
  vectorName?: string // 载体名称
  createDate?: string // 业务创建日期
  fluorescentTag?: string // 荧光/蛋白标签（多选逗号分隔）
  mutation?: string // 突变信息
  modification?: string // 改造信息
  tag?: string // 标签
  plasmidTypeId?: number // 质粒类型ID
  auditStatus?: string // 审核状态
  remark?: string // 业务备注
  createTime?: string // 创建时间
  // ========== 登记信息（只读） ==========
  storageForm?: string // 保存形式（多选逗号分隔）
  concentration?: number // 质粒浓度 ng/μL
  volume?: number // 质粒体积 μL
  glycerinSpec?: string // 甘油菌规格
  glycerinAmount?: number // 甘油菌量 μL
  originalPlasmidFridge?: string // 登记时原始质粒冰箱
  originalPlasmidLayer?: string // 登记时原始质粒层
  originalPlasmidBox?: string // 登记时原始质粒盒
  originalPlasmidPosition?: string // 登记时原始质粒位置
  originalGlycerinFridge?: string // 登记时原始甘油菌冰箱
  originalGlycerinLayer?: string // 登记时原始甘油菌层
  originalGlycerinBox?: string // 登记时原始甘油菌盒
  originalGlycerinPosition?: string // 登记时原始甘油菌位置
  sequenceFileId?: number // 序列图谱文件ID
  sequenceFileName?: string // 序列图谱文件名快照
  sequenceNoFileReason?: string // 无序列图谱原因
  sequencingReportFileId?: number // 测序/检测报告文件ID
  sequencingReportFileName?: string // 测序/检测报告文件名快照
  initialQuantityDeclared?: number // 申报初始库存数量 μL
}

/** 审核通过/驳回请求 */
export interface PlasmidAuditReqVO {
  id: number // 质粒ID
  opinion?: string // 审核意见（驳回时必填）
  initialQuantityConfirmed?: number // 库管员确认的初始库存 μL（通过时必填）
  lowStockThreshold?: number // 低库存阈值 μL（可选）
  storageConfirm?: StorageConfirmVO // Storage 现场核查确认信息（通过时必填）
}

/** Storage 现场核查确认信息（27 字段，与后端 PlasmidAuditReqVO.StorageConfirm 一一对应） */
export interface StorageConfirmVO {
  // ---- 登记事实（只读展示，提交时原样回传；后端已有 Storage 记录时强制使用 DB 原值） ----
  storageForm?: string // 保存形式（多选逗号分隔）
  concentration?: number // 质粒浓度 ng/μL
  volume?: number // 质粒体积 μL
  glycerinSpec?: string // 甘油菌规格
  glycerinAmount?: number // 甘油菌量 μL
  originalPlasmidFridge?: string
  originalPlasmidLayer?: string
  originalPlasmidBox?: string
  originalPlasmidPosition?: string
  originalGlycerinFridge?: string
  originalGlycerinLayer?: string
  originalGlycerinBox?: string
  originalGlycerinPosition?: string
  sequenceFileId?: number
  sequenceFileName?: string
  sequenceNoFileReason?: string
  sequencingReportFileId?: number
  sequencingReportFileName?: string
  // ---- 库管员填写 ----
  plasmidFridge?: string // 质粒存放冰箱（正式位置）
  plasmidLayer?: string // 质粒存放层数（正式位置）
  plasmidBox?: string // 质粒存放盒（正式位置）
  plasmidPosition?: string // 质粒盒内位置（正式位置）
  glycerinFridge?: string // 甘油菌存放冰箱（正式位置）
  glycerinLayer?: string // 甘油菌存放层数（正式位置）
  glycerinBox?: string // 甘油菌存放盒（正式位置）
  glycerinPosition?: string // 甘油菌盒内位置（正式位置）
  remark?: string // 管理员备注
}

/** 审核历史记录 */
export interface PlasmidAuditHistoryVO {
  id: number // 主键ID
  plasmidId?: number // 质粒ID
  submitterId?: number // 提交人ID
  submitterName?: string // 提交人姓名
  submitTime?: string // 提交时间
  submitCount?: number // 提交次数（审核轮次）
  auditorId?: number // 审核人ID
  auditorName?: string // 审核人姓名
  auditTime?: string // 审核时间
  auditResult?: string // 审核结果
  auditOpinion?: string // 审核文字意见
  remark?: string // 备注
  createTime?: string // 创建时间
}

// 质粒审核（V2） API
export const PlasmidAuditApi = {
  // 查询审核列表（默认 auditStatus=PENDING，数据范围由后端 validateAuditPermission 控制）
  getPlasmidAuditPage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid/audit/page`, params })
  },

  // 查询审核视角质粒详情（含登记信息）
  getPlasmidAuditView: async (id: number) => {
    return await request.get({ url: `/lab/v2/plasmid/audit/get?id=` + id })
  },

  // 审核通过
  approvePlasmid: async (data: PlasmidAuditReqVO) => {
    return await request.post({ url: `/lab/v2/plasmid/audit/approve`, data })
  },

  // 审核驳回
  rejectPlasmid: async (data: PlasmidAuditReqVO) => {
    return await request.post({ url: `/lab/v2/plasmid/audit/reject`, data })
  },

  // 查询审核历史分页（按 plasmidId 过滤）
  getPlasmidAuditHistoryPage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid-audit/page`, params })
  }
}
