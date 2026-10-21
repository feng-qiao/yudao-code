import request from '@/config/axios'

/** 质粒归还（V2） */
export interface PlasmidReturnVO {
  id: number // 主键ID
  returnNo?: string // 归还单号
  borrowId?: number // 关联借用单ID
  borrowNo?: string // 关联借用单号
  plasmidId: number // 质粒ID
  returnerId?: number // 归还人ID
  returnerName?: string // 归还人姓名
  returnType?: string // 归还类型
  otherReturnType?: string // 其他归还类型说明
  plannedQuantity?: number // 计划归还数量 μL
  actualQuantity?: number // 实际归还数量 μL
  applyTime?: string // 申请时间
  actualReturnTime?: string // 实际归还时间
  reviewerId?: number // 审核人ID
  reviewerName?: string // 审核人姓名
  reviewTime?: string // 审核时间
  reviewResult?: string // 审核结果
  reviewOpinion?: string // 审核意见
  status?: string // 归还状态
  remark?: string // 备注
  createTime?: string // 创建时间
}

/** 归还申请请求 VO */
export interface PlasmidReturnApplyVO {
  borrowId: number // 关联借用单ID
  returnType: string // 归还类型
  otherReturnType?: string // 其他归还类型说明
  plannedQuantity: number // 计划归还数量 μL（> 0）
  remark?: string // 备注
}

/** 归还审核请求 VO */
export interface PlasmidReturnAuditVO {
  id: number // 归还单ID
  reviewResult: string // 审核结果 APPROVED / REJECTED
  reviewOpinion?: string // 审核意见（驳回必填）
  actualQuantity?: number // 实际归还数量 μL（通过时必填）
}

// 质粒归还（V2） API
export const PlasmidReturnApi = {
  // 查询归还分页
  getReturnPage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid-return/page`, params })
  },

  // 查询归还详情
  getReturn: async (id: number) => {
    return await request.get({ url: `/lab/v2/plasmid-return/get?id=` + id })
  },

  // 申请归还
  applyReturn: async (data: PlasmidReturnApplyVO) => {
    return await request.post({ url: `/lab/v2/plasmid-return/apply`, data })
  },

  // 审核归还
  auditReturn: async (data: PlasmidReturnAuditVO) => {
    return await request.post({ url: `/lab/v2/plasmid-return/audit`, data })
  },

  // 导出归还记录（与分页查询条件一致）
  exportReturn: async (params: any) => {
    return await request.download({ url: `/lab/v2/plasmid-return/export-excel`, params })
  }
}
