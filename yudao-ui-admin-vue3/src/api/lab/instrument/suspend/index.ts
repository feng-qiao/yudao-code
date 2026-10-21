import request from '@/config/axios'

/** 人工暂停记录（历史全保留） */
export interface InstrumentSuspendVO {
  id?: number
  userId?: number
  userName?: string
  scopeType?: string // SINGLE / ALL
  deviceId?: number
  deviceName?: string
  presetDays?: number | null
  startTime?: string
  endTime?: string
  status?: string // ACTIVE / RELEASED / EXPIRED
  reason?: string
  operatorUserId?: number
  operatorName?: string
  releaseTime?: string
  releaseOperatorId?: number
  releaseOperatorName?: string
  releaseReason?: string
  remark?: string
}

export const InstrumentSuspendApi = {
  /** 暂停记录分页（管理/授权范围） */
  getPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/suspend/page`, params })
  },
  /** 创建暂停（SINGLE / ALL） */
  create: async (data: {
    userId: number
    scopeType: string
    deviceId?: number
    presetDays?: number
    endTime?: string
    reason: string
    remark?: string
  }) => {
    return await request.post({ url: `/lab/instrument/suspend/create`, data })
  },
  /** 提前解除（原因必填） */
  release: async (data: { id: number; reason: string }) => {
    return await request.post({ url: `/lab/instrument/suspend/release`, data })
  },
  /** 我的暂停记录 */
  getMySuspends: async () => {
    return await request.get({ url: `/lab/instrument/suspend/my` })
  }
}
