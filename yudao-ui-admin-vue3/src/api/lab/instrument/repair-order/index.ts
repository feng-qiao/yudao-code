import request from '@/config/axios'

/** View model adapted from InstrumentRepairOrderDO. */
export interface RepairOrderVO {
  id?: number
  orderNo?: string
  deviceId?: number
  sourceFaultId?: number
  status?: string
  assigneeUserId?: number
  assigneeName?: string
  assignTime?: string
  startTime?: string
  finishTime?: string
  restoreTime?: string
  restoreUserId?: number
  restoreName?: string
  restoreOpinion?: string
  createTime?: string
  faultPhenomenon?: string
  faultDescription?: string
  severity?: string
  repairResult?: string
}

const toView = (row: any): RepairOrderVO => ({
  id: row.id,
  orderNo: row.orderNo,
  deviceId: row.deviceId,
  sourceFaultId: row.sourceFaultId,
  status: row.currentStatus,
  assigneeUserId: row.assigneeUserId,
  assigneeName: row.assigneeUserName,
  assignTime: row.assigneeAssignTime,
  startTime: row.startTime,
  finishTime: row.repairEndTime,
  restoreTime: row.restoreConfirmTime,
  restoreUserId: row.restoreConfirmUserId,
  restoreName: row.restoreConfirmUserName,
  restoreOpinion: row.restoreOpinion,
  createTime: row.createTime
})

const mapPage = (page: any) => ({ ...page, list: (page?.list || []).map(toView) })

export const InstrumentRepairOrderApi = {
  assign: async (data: { id: number; assigneeUserId: number }) =>
    await request.post({
      url: `/lab/instrument/repair-order/assign/${data.id}`,
      data: { assigneeUserId: data.assigneeUserId }
    }),
  start: async (id: number) => await request.post({ url: `/lab/instrument/repair-order/start/${id}` }),
  addProcess: async (data: { id: number; content: string }) =>
    await request.post({ url: `/lab/instrument/repair-order/record/${data.id}`, data: { detail: data.content } }),
  submitRepaired: async (data: { id: number; repairResult: string }) =>
    await request.post({
      url: `/lab/instrument/repair-order/submit/${data.id}`,
      data: { result: data.repairResult }
    }),
  restoreApprove: async (id: number, opinion: string) =>
    await request.post({ url: `/lab/instrument/repair-order/restore-approve/${id}`, data: { opinion } }),
  restoreReject: async (id: number, reason: string) =>
    await request.post({ url: `/lab/instrument/repair-order/restore-reject/${id}`, data: { reason } }),
  cancel: async (id: number, reason: string) =>
    await request.post({ url: `/lab/instrument/repair-order/cancel/${id}`, params: { reason } }),
  getPage: async (params: any) =>
    mapPage(await request.get({ url: '/lab/instrument/repair-order/page', params })),
  getMyAssignedPage: async (params: any) =>
    mapPage(await request.get({ url: '/lab/instrument/repair-order/my-assigned', params })),
  get: async (id: number) => toView(await request.get({ url: '/lab/instrument/repair-order/get', params: { id } }))
}
