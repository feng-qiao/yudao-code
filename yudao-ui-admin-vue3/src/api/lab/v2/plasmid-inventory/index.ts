import request from '@/config/axios'

/** 质粒库存账户（V2） */
export interface PlasmidInventoryVO {
  id: number // 主键ID
  plasmidId: number // 质粒ID
  plasmidNo?: string // 质粒编号
  plasmidName?: string // 质粒名称
  plasmidTypeId?: number // 质粒类型ID
  plasmidTypeName?: string // 质粒类型名称
  initialQuantityDeclared?: number // 申报初始库存数量 μL
  initialQuantityConfirmed?: number // 确认初始库存数量 μL
  currentQuantity?: number // 当前库存 μL
  lowStockThreshold?: number // 低库存阈值 μL
  inventoryStatus?: string // 库存状态
  lastFlowTime?: string // 最后库存变化时间
  remark?: string // 备注
  createTime?: string // 创建时间
}

/** 入库 / 出库 请求 VO */
export interface PlasmidInventoryInOutVO {
  requestNo: string // 幂等请求号（前端生成 UUID）
  plasmidId: number // 质粒ID
  quantity: number // 数量 μL（> 0）
  reason: string // 操作原因（必填）
  remark?: string // 备注
}

/** 盘点 / 调整 请求 VO */
export interface PlasmidInventoryStocktakeVO {
  requestNo: string // 幂等请求号（前端生成 UUID）
  plasmidId: number // 质粒ID
  actualQuantity: number // 实盘库存 μL（>= 0，强制覆盖）
  reason: string // 操作原因（必填）
  remark?: string // 备注
}

/** 低库存阈值 请求 VO */
export interface PlasmidInventoryThresholdVO {
  plasmidId: number // 质粒ID
  threshold: number // 低库存阈值 μL（>= 0）
}

// 质粒库存账户（V2） API
export const PlasmidInventoryApi = {
  // 查询库存分页
  getInventoryPage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid-inventory/page`, params })
  },

  // 查询库存详情
  getInventory: async (id: number) => {
    return await request.get({ url: `/lab/v2/plasmid-inventory/get?id=` + id })
  },

  // 导出库存（与分页查询条件一致）
  exportInventory: async (params: any) => {
    return await request.download({ url: `/lab/v2/plasmid-inventory/export-excel`, params })
  },

  // 日常入库
  inInventory: async (data: PlasmidInventoryInOutVO) => {
    return await request.post({ url: `/lab/v2/plasmid-inventory/in`, data })
  },

  // 日常出库
  outInventory: async (data: PlasmidInventoryInOutVO) => {
    return await request.post({ url: `/lab/v2/plasmid-inventory/out`, data })
  },

  // 库存盘点
  stocktakeInventory: async (data: PlasmidInventoryStocktakeVO) => {
    return await request.post({ url: `/lab/v2/plasmid-inventory/stocktake`, data })
  },

  // 库存调整
  adjustInventory: async (data: PlasmidInventoryStocktakeVO) => {
    return await request.post({ url: `/lab/v2/plasmid-inventory/adjust`, data })
  },

  // 设置低库存阈值
  updateThreshold: async (data: PlasmidInventoryThresholdVO) => {
    return await request.put({ url: `/lab/v2/plasmid-inventory/threshold`, data })
  }
}
