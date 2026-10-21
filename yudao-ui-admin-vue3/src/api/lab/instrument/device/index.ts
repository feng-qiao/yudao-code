import request from '@/config/axios'

/** 仪器设备状态（代码枚举，不建字典；与后端 DeviceStatusEnum 一致） */
export const DEVICE_STATUS = {
  NORMAL: { value: 'NORMAL', label: '正常', type: 'success' },
  MAINTENANCE: { value: 'MAINTENANCE', label: '维护', type: 'warning' },
  FAULT: { value: 'FAULT', label: '故障', type: 'danger' },
  DISABLED: { value: 'DISABLED', label: '停用', type: 'info' },
  SCRAPPED: { value: 'SCRAPPED', label: '报废', type: 'info' }
} as const

/** 设备负责人简要 */
export interface DeviceManagerBrief {
  id: number
  managerType: string
  userId: number
  nickname?: string
  username?: string
  mobile?: string
}

/** 仪器设备（INSTRUMENT-01） */
export interface InstrumentDeviceVO {
  id?: number
  deviceNo: string
  name: string
  model?: string
  spec?: string
  category: string
  repairScope?: string
  platformId?: number
  platformName?: string
  roomId?: number
  roomName?: string
  assetNo?: string
  manufacturer?: string
  purchaseDate?: string
  status?: string
  bookable?: boolean
  imageFileId?: number
  imageFileName?: string
  imageUrl?: string
  sort?: number
  remark?: string
  createTime?: string
  managers?: DeviceManagerBrief[]
  managerNames?: string
  currentNotice?: {
    id: number
    version: number
    title: string
    content: string
    requireAcknowledge?: boolean
    publishTime?: string
  } | null
}

export interface DeviceHallOptions {
  platforms: { id: number; name: string }[]
  rooms: { id: number; name: string }[]
}

export const InstrumentDeviceApi = {
  getPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/device/page`, params })
  },
  get: async (id: number) => {
    return await request.get({ url: `/lab/instrument/device/get?id=${id}` })
  },
  getHallOptions: async (): Promise<DeviceHallOptions> => {
    return await request.get({ url: `/lab/instrument/device/hall-options` })
  },
  create: async (data: InstrumentDeviceVO) => {
    return await request.post({ url: `/lab/instrument/device/create`, data })
  },
  update: async (data: InstrumentDeviceVO) => {
    return await request.put({ url: `/lab/instrument/device/update`, data })
  },
  updateStatus: async (id: number, status: string) => {
    return await request.put({ url: `/lab/instrument/device/update-status`, data: { id, status } })
  },
  delete: async (id: number) => {
    return await request.delete({ url: `/lab/instrument/device/delete?id=${id}` })
  }
}
