import request from '@/config/axios'

/** 仪器开放窗口（INSTRUMENT-03-B，lab_instrument_booking_window，一设备多窗口） */
export interface InstrumentBookingWindowVO {
  id?: number
  deviceId: number
  windowName: string
  /** 每周开放日（1-7 逗号分隔，空=不限） */
  openDays?: string
  openStartTime?: string
  openEndTime?: string
  /** 开放目标日期范围开始（yyyy-MM-dd） */
  targetDateStart?: string
  /** 开放目标日期范围结束（yyyy-MM-dd） */
  targetDateEnd?: string
  /** 开放日→目标日期映射说明（F14：仅文本，不做业务推断） */
  targetWeekMapping?: string
  /** 窗口容量（空=不限） */
  capacity?: number
  /** 已使用量（后端维护，前端只读展示） */
  usedCount?: number
  /** ACTIVE / CLOSED */
  status?: string
  sort?: number
  remark?: string
  createTime?: string
}

export const InstrumentBookingWindowApi = {
  /** 按设备分页查询开放窗口 */
  getPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/booking-window/page`, params })
  },
  /** 创建窗口（默认 ACTIVE，usedCount=0，返回窗口 id） */
  create: async (data: InstrumentBookingWindowVO): Promise<number> => {
    return await request.post({ url: `/lab/instrument/booking-window/create`, data })
  },
  /** 修改窗口（容量不得小于已使用量） */
  update: async (data: InstrumentBookingWindowVO) => {
    return await request.put({ url: `/lab/instrument/booking-window/update`, data })
  },
  /** 删除窗口（已有使用记录禁止删除） */
  delete: async (id: number) => {
    return await request.delete({ url: `/lab/instrument/booking-window/delete?id=${id}` })
  }
}
