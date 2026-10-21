import request from '@/config/axios'

/** 仪器平台（INSTRUMENT-01） */
export interface InstrumentPlatformVO {
  id?: number
  code: string
  name: string
  description?: string
  sort?: number
  status?: string // ENABLE / DISABLE
  remark?: string
  createTime?: string
}

export const InstrumentPlatformApi = {
  getPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/platform/page`, params })
  },
  get: async (id: number) => {
    return await request.get({ url: `/lab/instrument/platform/get?id=${id}` })
  },
  getList: async (status?: string) => {
    return await request.get({ url: `/lab/instrument/platform/list`, params: { status } })
  },
  getDeviceList: async (platformId: number) => {
    return await request.get({
      url: `/lab/instrument/platform/device-list`,
      params: { platformId }
    })
  },
  create: async (data: InstrumentPlatformVO) => {
    return await request.post({ url: `/lab/instrument/platform/create`, data })
  },
  update: async (data: InstrumentPlatformVO) => {
    return await request.put({ url: `/lab/instrument/platform/update`, data })
  },
  updateStatus: async (id: number, status: string) => {
    return await request.put({
      url: `/lab/instrument/platform/update-status`,
      data: { id, status }
    })
  },
  delete: async (id: number) => {
    return await request.delete({ url: `/lab/instrument/platform/delete?id=${id}` })
  }
}
