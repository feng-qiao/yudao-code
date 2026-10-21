import request from '@/config/axios'

/** 质粒黑名单（V2） */
export interface PlasmidBlacklistVO {
  id: number // 主键ID
  userId?: number // 用户ID
  userName?: string // 用户姓名
  reason?: string // 加入原因
  startTime?: string // 生效时间
  endTime?: string // 计划结束时间
  status?: string // 黑名单状态
  operatorId?: number // 操作人ID
  operatorName?: string // 操作人姓名
  operateTime?: string // 操作时间
  removerId?: number // 解除人ID
  removerName?: string // 解除人姓名
  removeTime?: string // 解除时间
  removeReason?: string // 解除原因
  violationId?: number // 关联违规ID
  violationNo?: string // 关联违规单号
  remark?: string // 备注
  createTime?: string // 创建时间
}

/** 添加黑名单请求 VO */
export interface PlasmidBlacklistAddVO {
  userId: number // 用户ID
  reason: string // 加入原因
  startTime?: string // 生效时间
  endTime?: string // 计划结束时间
  violationId?: number // 关联违规ID（库管员必填）
  remark?: string // 备注
}

/** 解除黑名单请求 VO */
export interface PlasmidBlacklistRemoveVO {
  id: number // 黑名单ID
  removeReason: string // 解除原因
}

// 质粒黑名单（V2） API
export const PlasmidBlacklistApi = {
  // 查询黑名单分页
  getBlacklistPage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid-blacklist/page`, params })
  },

  // 查询黑名单详情
  getBlacklist: async (id: number) => {
    return await request.get({ url: `/lab/v2/plasmid-blacklist/get?id=` + id })
  },

  // 添加黑名单
  addBlacklist: async (data: PlasmidBlacklistAddVO) => {
    return await request.post({ url: `/lab/v2/plasmid-blacklist/add`, data })
  },

  // 解除黑名单
  removeBlacklist: async (data: PlasmidBlacklistRemoveVO) => {
    return await request.post({ url: `/lab/v2/plasmid-blacklist/remove`, data })
  }
}
