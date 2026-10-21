import request from '@/config/axios'

/** 设备预约规则（INSTRUMENT-03-B，lab_instrument_booking_rule，一设备一规则） */
export interface InstrumentBookingRuleVO {
  id?: number
  deviceId: number
  /** 时间粒度（分钟）；NULL=未配置（B10：不预设默认值） */
  granularityMinutes?: number
  /** 最短时长（分钟）；NULL=未配置 */
  minDurationMinutes?: number
  /** 最长时长（分钟） */
  maxDurationMinutes?: number
  /** 允许预约的起始偏移（可往前 N 天） */
  bookableDaysBefore?: number
  /** 允许预约的日期范围（往后 N 天） */
  bookableDaysAhead?: number
  /** 每周开放日（1-7 逗号分隔，空=不限） */
  openDays?: string
  /** 每日开放开始（HH:mm） */
  openStartTime?: string
  /** 每日开放结束（HH:mm） */
  openEndTime?: string
  /** 是否允许跨天（B7：false/NULL 均按不允许处理） */
  allowCrossDay?: boolean
  /** 管理员是否可在开始后调整 */
  allowAdminAdjustAfterStart?: boolean
  /** 规则启用（false=不可预约，F15） */
  enabled?: boolean
  remark?: string
}

export const InstrumentBookingRuleApi = {
  /** 获取设备预约规则（未配置返回 null） */
  get: async (deviceId: number): Promise<InstrumentBookingRuleVO | null> => {
    return await request.get({ url: `/lab/instrument/booking-rule/get`, params: { deviceId } })
  },
  /** 保存设备预约规则（一设备一规则，设备行锁内 upsert，返回规则 id） */
  save: async (data: InstrumentBookingRuleVO): Promise<number> => {
    return await request.post({ url: `/lab/instrument/booking-rule/save`, data })
  }
}
