import request from '@/config/axios'

/** 统一信用账户（INSTRUMENT-02） */
export interface InstrumentCreditVO {
  id?: number
  userId?: number
  userName?: string
  score?: number | null // 初始 100，可超 100，可为负；未激活时 null
  initialized?: boolean
  initializedTime?: string
  lastChangeTime?: string
}

/** 信用积分流水（不可变，无删除/编辑） */
export interface InstrumentCreditFlowVO {
  id?: number
  accountId?: number
  userId?: number
  userName?: string
  changeType?: string // ADD / DEDUCT
  scoreChange?: number
  scoreBefore?: number
  scoreAfter?: number
  reasonType?: string // VIOLATION / OVERDUE / REWARD / MANUAL
  bizType?: string
  bizId?: number
  reason?: string
  operatorUserId?: number
  operatorName?: string
  operateTime?: string
  remark?: string
}

export const InstrumentCreditApi = {
  /** 我的信用账户 */
  getMyCredit: async () => {
    return await request.get({ url: `/lab/instrument/credit/my` })
  },
  /** 账户分页（管理端） */
  getPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/credit/page`, params })
  },
  /** 我的流水分页 */
  getMyFlowPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/credit/flow/my`, params })
  },
  /** 流水分页（管理端） */
  getFlowPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/credit/flow/page`, params })
  },
  /** 人工加扣分（delta 正加负扣） */
  adjust: async (data: {
    userId: number
    delta: number
    reasonType: string
    reason: string
    bizType?: string
    bizId?: number
    remark?: string
  }) => {
    return await request.post({ url: `/lab/instrument/credit/adjust`, data })
  },
  /** 流水导出 */
  exportFlow: async (params: any) => {
    return await request.download({ url: `/lab/instrument/credit/flow/export-excel`, params })
  }
}
