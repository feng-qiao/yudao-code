import request from '@/config/axios'

/**
 * 仪器预约（INSTRUMENT-03，23 §4.1/§4.2；34 号批次收敛）
 *
 * 上线边界（任务书 C7）：预约生命周期（取消/调整/完成/作废）未交付、真实 MySQL 并发
 * 验证未通过前，创建接口由服务端功能开关（lab.instrument.reservation.create-enabled，
 * 默认 false）拒绝写入（116）。前端不硬编码开关：创建请求的业务错误码统一由后端返回并提示。
 *
 * 34 号收敛：容量恒为 1（独占），预约记录 + 时间冲突检测保证；RespVO 不再返回
 * windowId 归属列（归属由 openRanges 的 windowId 按区间反推）。
 */

/** 预约创建 ReqVO */
export interface ReservationCreateReqVO {
  deviceId: number
  /** 归属开放窗口ID（U5：窗口设备必填；普通无窗口设备留空，禁止随机选窗口） */
  windowId?: number
  /** 预约开始时间（左闭，Epoch 毫秒；服务端全局 Jackson 约定 LocalDateTime 收数字） */
  startTime: number
  /** 预约结束时间（右开，Epoch 毫秒） */
  endTime: number
  purpose?: string
  remark?: string
}

/** 预约 RespVO（我的预约/详情共用） */
export interface ReservationRespVO {
  id: number
  /** 预约单号（B8：R+yyyyMMdd+5位Redis自增） */
  reservationNo: string
  deviceId: number
  /** 设备名称（展示字段，我的预约/详情时填充） */
  deviceName?: string
  userId: number
  userName?: string
  qualificationId?: number
  startTime: string
  endTime: string
  durationMinutes?: number
  /** PENDING / FINISHED / CANCELED / VOIDED */
  status: string
  purpose?: string
  actualStartTime?: string
  actualEndTime?: string
  finishTime?: string
  cancelTime?: string
  cancelBy?: string
  cancelReason?: string
  remark?: string
  createTime?: string
  /** 服务端计算的可操作标记（仅展示用；真实权限由后端再次校验） */
  canCancel?: boolean
  canAdjust?: boolean
  canFinish?: boolean
  canVoid?: boolean
}

/** 预约取消 ReqVO */
export interface ReservationCancelReqVO {
  id: number
  /** 取消原因（负责人/管理员必填；本人开始前取消选填） */
  reason?: string
}

/** 预约调整 ReqVO（T1 裁决：独立权限 reservation:adjust；T2 裁决：不传 windowId，服务端按新时间重匹配窗口） */
export interface ReservationAdjustReqVO {
  id: number
  /** 新设备ID（不传=同设备改时段；换设备须对新设备有资质且在授权范围） */
  newDeviceId?: number
  startTime: string
  endTime: string
  /** 调整原因（负责人/管理员必填；本人开始前调整免填） */
  reason?: string
}

/** 预约手工登记完成 ReqVO */
export interface ReservationFinishReqVO {
  id: number
  actualStartTime: string
  actualEndTime: string
  remark?: string
}

/** 预约作废 ReqVO */
export interface ReservationVoidReqVO {
  id: number
  reason: string
}

/** 预约分页 ReqVO（管理侧，23 §4.1 page） */
export interface ReservationPageReqVO {
  pageNo: number
  pageSize: number
  deviceId?: number
  userId?: number
  reservationNo?: string
  status?: string
  startTimeBegin?: string
  startTimeEnd?: string
}

/** 预约操作历史 RespVO */
export interface ReservationHistoryRespVO {
  id: number
  reservationId: number
  /** CREATE / ADJUST / CANCEL / FINISH / VOID */
  action: string
  operatorUserId?: number
  operatorName?: string
  /** USER / MANAGER / ADMIN */
  operatorRole?: string
  actionTime?: string
  beforeStartTime?: string
  beforeEndTime?: string
  afterStartTime?: string
  afterEndTime?: string
  beforeStatus?: string
  afterStatus?: string
  reason?: string
  remark?: string
}

/** 预约日历每日项 */
export interface ReservationCalendarItemVO {
  date: string
  /** 未开放原因码（null=正常） */
  reasonCode?: number
  reasonMsg?: string
  /** 当日开放时段（空=未开放） */
  openRanges: {
    start: string
    end: string
    /** 归属窗口ID（U3/U5：窗口设备开放范围必属唯一窗口；普通设备为 null） */
    windowId?: number
    windowName?: string
  }[]
  /** 当日占用明细（RESERVATION 预约 / MAINTENANCE 维护） */
  occupied: { type: string; start: string; end: string; brief: string }[]
  /** 本人当日预约 id 列表（全状态） */
  myReservationIds: number[]
}

/** 可预约空闲槽 */
export interface ReservationFreeSlotVO {
  deviceId: number
  date: string
  /** 整体原因码（此时 slots 为空；null=正常） */
  reasonCode?: number
  reasonMsg?: string
  slots: {
    /** 开始（左闭，按设备粒度对齐） */
    start: string
    /** 结束（右开） */
    end: string
    available: boolean
    reasonCode?: number
    reasonMsg?: string
  }[]
}

/** is-open 快速判定（P1~P6，不含冲突查询） */
export interface ReservationIsOpenVO {
  open: boolean
  reasonCode?: number
  reasonMsg?: string
}

/** 预约状态元数据（与后端 ReservationStatusEnum 一致；U4：PENDING/FINISHED 占用时段） */
export const RESERVATION_STATUS = {
  PENDING: { value: 'PENDING', label: '待使用', type: 'warning' },
  FINISHED: { value: 'FINISHED', label: '已完成', type: 'success' },
  CANCELED: { value: 'CANCELED', label: '已取消', type: 'info' },
  VOIDED: { value: 'VOIDED', label: '已作废', type: 'danger' }
} as const

export const InstrumentReservationApi = {
  /** 创建预约（C7 功能开关默认关闭时服务端以 116 拒绝；@Idempotent 3 秒防重复提交） */
  create: async (data: ReservationCreateReqVO): Promise<number> => {
    return await request.post({ url: `/lab/instrument/reservation/create`, data })
  },
  /** 预约日历（每日开放范围 + 占用明细 + 本人预约 id，范围≤31天） */
  getCalendar: async (deviceId: number, startDate: string, endDate: string) => {
    return await request.get<ReservationCalendarItemVO[]>({
      url: `/lab/instrument/reservation/calendar`,
      params: { deviceId, startDate, endDate }
    })
  },
  /** 可预约空闲槽（按规则粒度切片，含不可用原因码） */
  getFreeSlots: async (deviceId: number, date: string) => {
    return await request.get<ReservationFreeSlotVO>({
      url: `/lab/instrument/reservation/free-slots`,
      params: { deviceId, date }
    })
  },
  /** 预约开放快速判定（P1~P6，不含冲突查询；窗口设备 windowId 可不传） */
  isOpen: async (deviceId: number, startTime: string, endTime: string, windowId?: number) => {
    return await request.get<ReservationIsOpenVO>({
      url: `/lab/instrument/reservation/is-open`,
      params: { deviceId, windowId, startTime, endTime }
    })
  },
  /** 我的预约列表（本人，全部状态，按 id 倒序） */
  getMy: async () => {
    return await request.get<ReservationRespVO[]>({ url: `/lab/instrument/reservation/my` })
  },
  /** 预约分页（reservation:query；数据范围=本人 OR 授权设备，23 §4.1 page） */
  getPage: async (params: ReservationPageReqVO) => {
    return await request.get({ url: `/lab/instrument/reservation/page`, params })
  },
  /** 预约详情（本人或授权负责人/管理员） */
  get: async (id: number) => {
    return await request.get<ReservationRespVO>({ url: `/lab/instrument/reservation/get?id=${id}` })
  },
  /** 取消预约（本人开始前/管理侧任意时刻，管理侧原因必填，23 §6.3） */
  cancel: async (data: ReservationCancelReqVO) => {
    return await request.post({ url: `/lab/instrument/reservation/cancel`, data })
  },
  /** 手工登记完成（reservation:manage 授权范围；仅 PENDING；实际起止必填，23 §6.4） */
  finish: async (data: ReservationFinishReqVO) => {
    return await request.post({ url: `/lab/instrument/reservation/finish`, data })
  },
  /** 调整预约（reservation:adjust 独立权限；仅 PENDING；锁内 P1~P8 复核，服务端重匹配窗口；23 §6.6 + T1/T2 裁决） */
  adjust: async (data: ReservationAdjustReqVO) => {
    return await request.put({ url: `/lab/instrument/reservation/adjust`, data })
  },
  /** 作废预约（reservation:manage 授权范围；仅 PENDING；原因必填，23 §6.5） */
  void: async (data: ReservationVoidReqVO) => {
    return await request.post({ url: `/lab/instrument/reservation/void`, data })
  },
  /** 预约操作历史（本人或授权负责人/管理员） */
  getHistoryList: async (id: number) => {
    return await request.get<ReservationHistoryRespVO[]>({
      url: `/lab/instrument/reservation/history-list?id=${id}`
    })
  }
}
