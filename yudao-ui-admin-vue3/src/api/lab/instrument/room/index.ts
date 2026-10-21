import request from '@/config/axios'

/** 实验室/房间（INSTRUMENT-01） */
export interface InstrumentRoomVO {
  id?: number
  code: string
  name: string
  building?: string
  floor?: string
  locationDesc?: string
  repairManagerId?: number
  repairManagerName?: string
  status?: string // ENABLE / DISABLE
  sort?: number
  remark?: string
  createTime?: string
  repairManagers?: {
    id: number
    managerType: string
    userId: number
    nickname?: string
    username?: string
    mobile?: string
  }[]
}

export const InstrumentRoomApi = {
  getPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/room/page`, params })
  },
  get: async (id: number) => {
    return await request.get({ url: `/lab/instrument/room/get?id=${id}` })
  },
  getList: async (status?: string) => {
    return await request.get({ url: `/lab/instrument/room/list`, params: { status } })
  },
  getRepairManagers: async (roomId: number) => {
    return await request.get({
      url: `/lab/instrument/room/repair-manager`,
      params: { roomId }
    })
  },
  create: async (data: InstrumentRoomVO) => {
    return await request.post({ url: `/lab/instrument/room/create`, data })
  },
  update: async (data: InstrumentRoomVO) => {
    return await request.put({ url: `/lab/instrument/room/update`, data })
  },
  delete: async (id: number) => {
    return await request.delete({ url: `/lab/instrument/room/delete?id=${id}` })
  }
}
