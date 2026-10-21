import request from '@/config/axios'

/** 质粒违规（V2） */
export interface PlasmidViolationVO {
  id: number // 主键ID
  violationNo?: string // 违规单号
  userId?: number // 违规用户ID
  userName?: string // 违规用户姓名
  plasmidId: number // 质粒ID
  borrowId?: number // 关联借用单ID
  borrowNo?: string // 关联借用单号
  returnId?: number // 关联归还单ID
  returnNo?: string // 关联归还单号
  violationType?: string // 违规类型
  description?: string // 违规描述
  occurredTime?: string // 发生时间
  status?: string // 违规状态
  handlerId?: number // 处理人ID
  handlerName?: string // 处理人姓名
  handleTime?: string // 处理时间
  handleResult?: string // 处理结果
  remark?: string // 备注
  createTime?: string // 创建时间
}

/** 违规登记请求 VO */
export interface PlasmidViolationCreateVO {
  userId: number // 违规用户ID
  violationType: string // 违规类型（仅限 RETURN_NONCOMPLIANCE / OTHER）
  description: string // 违规描述
  occurredTime: string // 发生时间
  borrowId?: number // 关联借用单ID
  plasmidId?: number // 关联质粒ID
  returnId?: number // 关联归还单ID
  remark?: string // 备注
}

/** 违规处理请求 VO */
export interface PlasmidViolationHandleVO {
  id: number // 违规单ID
  handleResult: string // 处理结果
}

// 质粒违规（V2） API
export const PlasmidViolationApi = {
  // 查询违规分页
  getViolationPage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid-violation/page`, params })
  },

  // 查询违规详情
  getViolation: async (id: number) => {
    return await request.get({ url: `/lab/v2/plasmid-violation/get?id=` + id })
  },

  // 登记违规
  createViolation: async (data: PlasmidViolationCreateVO) => {
    return await request.post({ url: `/lab/v2/plasmid-violation/create`, data })
  },

  // 处理违规
  handleViolation: async (data: PlasmidViolationHandleVO) => {
    return await request.post({ url: `/lab/v2/plasmid-violation/handle`, data })
  },

  // 导出违规记录（与分页查询条件一致）
  exportViolation: async (params: any) => {
    return await request.download({ url: `/lab/v2/plasmid-violation/export-excel`, params })
  }
}
