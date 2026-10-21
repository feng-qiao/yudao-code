import request from '@/config/axios'

/** 仪器负责人分配记录（INSTRUMENT-01） */
export interface InstrumentManagerVO {
  id?: number
  scope: string // DEVICE / PLATFORM / ROOM_REPAIR
  targetId: number
  targetName?: string
  managerType: string // PRIMARY / REPAIR / BACKUP
  managerUserId: number
  managerName?: string
  nickname?: string
  username?: string
  mobile?: string
  status?: string // ACTIVE / RELEASED
  effectiveFrom?: string
  effectiveTo?: string
  assignReason?: string
  releaseReason?: string
  remark?: string
  createTime?: string
}

export interface ManagerCandidate {
  id: number
  nickname: string
  username: string
  mobile?: string
}

export const InstrumentManagerApi = {
  getPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/manager/page`, params })
  },
  /** 当前生效负责人 */
  listByTarget: async (scope: string, targetId: number) => {
    return await request.get({
      url: `/lab/instrument/manager/list-by-target`,
      params: { scope, targetId }
    })
  },
  /** 变更历史（含已解除） */
  history: async (scope: string, targetId: number) => {
    return await request.get({
      url: `/lab/instrument/manager/history`,
      params: { scope, targetId }
    })
  },
  candidates: async (keyword?: string) => {
    return await request.get({
      url: `/lab/instrument/manager/candidates`,
      params: { keyword }
    })
  },
  assign: async (data: {
    scope: string
    targetId: number
    managerType: string
    managerUserId: number
    assignReason?: string
    remark?: string
  }) => {
    return await request.post({ url: `/lab/instrument/manager/assign`, data })
  },
  release: async (id: number, reason: string) => {
    return await request.post({
      url: `/lab/instrument/manager/release`,
      data: { id, reason }
    })
  }
}
