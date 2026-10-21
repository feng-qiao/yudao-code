import request from '@/config/axios'

/** 质粒借用（V2） */
export interface PlasmidBorrowVO {
  id: number // 主键ID
  borrowNo?: string // 借用单号
  plasmidId: number // 质粒ID
  borrowerId?: number // 借用人ID
  borrowerName?: string // 借用人姓名
  requestedQuantity?: number // 申请借用数量 μL
  approvedQuantity?: number // 审核批准数量 μL
  borrowReason?: string // 借用原因
  dueTime?: string // 应归还时间
  applyTime?: string // 申请时间
  actualBorrowTime?: string // 实际借出时间
  returnType?: string // 归还类型
  otherReturnType?: string // 其他归还类型说明
  returnRequirement?: string // 归还要求
  returnQuantity?: number // 当前已归还数量 μL
  reviewerId?: number // 审核人ID
  reviewerName?: string // 审核人姓名
  reviewTime?: string // 审核时间
  reviewResult?: string // 审核结果
  reviewOpinion?: string // 审核意见
  status?: string // 借用状态
  remark?: string // 备注
  createTime?: string // 创建时间
}

/** 借用申请请求 VO */
export interface PlasmidBorrowApplyVO {
  plasmidId: number // 质粒ID
  requestedQuantity: number // 申请借用数量 μL（> 0）
  borrowReason: string // 借用原因
  dueTime: string // 应归还时间
  returnType: string // 归还类型
  otherReturnType?: string // 其他归还类型说明
  returnRequirement?: string // 归还要求
  remark?: string // 备注
}

/** 借用审核请求 VO */
export interface PlasmidBorrowAuditVO {
  id: number // 借用单ID
  reviewResult: string // 审核结果 APPROVED / REJECTED
  reviewOpinion?: string // 审核意见（驳回必填）
  approvedQuantity?: number // 审核批准数量 μL（通过时可填）
}

/** 借用取消请求 VO */
export interface PlasmidBorrowCancelVO {
  id: number // 借用单ID
}

// 质粒借用（V2） API
export const PlasmidBorrowApi = {
  // 查询借用分页
  getBorrowPage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid-borrow/page`, params })
  },

  // 查询借用详情
  getBorrow: async (id: number) => {
    return await request.get({ url: `/lab/v2/plasmid-borrow/get?id=` + id })
  },

  // 申请借用
  applyBorrow: async (data: PlasmidBorrowApplyVO) => {
    return await request.post({ url: `/lab/v2/plasmid-borrow/apply`, data })
  },

  // 取消借用
  cancelBorrow: async (data: PlasmidBorrowCancelVO) => {
    return await request.post({ url: `/lab/v2/plasmid-borrow/cancel`, data })
  },

  // 审核借用
  auditBorrow: async (data: PlasmidBorrowAuditVO) => {
    return await request.post({ url: `/lab/v2/plasmid-borrow/audit`, data })
  },

  // 导出借用记录（与分页查询条件一致）
  exportBorrow: async (params: any) => {
    return await request.download({ url: `/lab/v2/plasmid-borrow/export-excel`, params })
  }
}
