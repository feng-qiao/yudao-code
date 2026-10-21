import request from '@/config/axios'

/** 质粒库存流水（V2，只读） */
export interface PlasmidInventoryFlowVO {
  id: number // 主键ID
  flowNo?: string // 流水单号
  plasmidId: number // 质粒ID
  flowType?: string // 流水类型
  quantity?: number // 本次变化数量 μL
  beforeQuantity?: number // 操作前库存 μL
  afterQuantity?: number // 操作后库存 μL
  relatedOrderType?: string // 关联业务类型
  relatedOrderId?: number // 关联业务ID
  relatedOrderNo?: string // 关联业务单号
  operatorId?: number // 操作人ID
  operatorName?: string // 操作人姓名
  flowTime?: string // 业务发生时间
  reason?: string // 操作原因
  remark?: string // 备注
  createTime?: string // 创建时间
}

// 质粒库存流水（V2） API
export const PlasmidInventoryFlowApi = {
  // 查询流水分页
  getInventoryFlowPage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid-inventory-flow/page`, params })
  },

  // 查询流水详情
  getInventoryFlow: async (id: number) => {
    return await request.get({ url: `/lab/v2/plasmid-inventory-flow/get?id=` + id })
  }
}
