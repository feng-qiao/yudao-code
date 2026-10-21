import request from '@/config/axios'

/** View model adapted from InstrumentFaultReportDO. */
export interface FaultReportVO {
  id?: number
  deviceId?: number
  faultTime?: string
  phenomenon?: string
  description?: string
  severity?: string
  attachmentUrl?: string
  contactPhone?: string
  reporterUserId?: number
  reporterName?: string
  status?: string
  confirmTime?: string
  confirmUserId?: number
  confirmName?: string
  rejectReason?: string
  repairOrderId?: number
  createTime?: string
}

const toView = (row: any): FaultReportVO => ({
  id: row.id,
  deviceId: row.deviceId,
  faultTime: row.faultTime,
  phenomenon: row.faultPhenomenon,
  description: row.faultDescription,
  severity: ({ L: 'LOW', M: 'MEDIUM', H: 'HIGH', C: 'CRITICAL' } as Record<string, string>)[row.severity] || row.severity,
  attachmentUrl: row.attachmentUrl,
  contactPhone: row.contactPhone,
  reporterUserId: row.reporterUserId,
  reporterName: row.reporterUserName,
  status: row.confirmStatus,
  confirmTime: row.confirmTime,
  confirmUserId: row.confirmUserId,
  confirmName: row.confirmUserName,
  rejectReason: row.confirmStatus === 'REJECTED' ? row.confirmOpinion : undefined,
  repairOrderId: row.linkedRepairOrderId,
  createTime: row.createTime
})

const mapPage = (page: any) => ({ ...page, list: (page?.list || []).map(toView) })

export const InstrumentFaultReportApi = {
  submit: async (data: Partial<FaultReportVO>) =>
    await request.post({
      url: '/lab/instrument/fault-report/submit',
      data: {
        deviceId: data.deviceId,
        faultTime: data.faultTime,
        phenomenon: data.phenomenon,
        description: data.description,
        severity: ({ LOW: 'L', MEDIUM: 'M', HIGH: 'H', CRITICAL: 'C' } as Record<string, string>)[data.severity || ''] || data.severity,
        attachmentUrl: data.attachmentUrl,
        contactPhone: data.contactPhone
      }
    }),
  confirm: async (id: number, opinion?: string) =>
    await request.post({ url: `/lab/instrument/fault-report/confirm/${id}`, data: { confirm: true, opinion } }),
  reject: async (id: number, opinion: string) =>
    await request.post({ url: `/lab/instrument/fault-report/confirm/${id}`, data: { confirm: false, opinion } }),
  getPage: async (params: any) => {
    const page = await request.get({
      url: '/lab/instrument/fault-report/page',
      params: {
        pageNo: params.pageNo,
        pageSize: params.pageSize,
        deviceId: params.deviceId,
        confirmStatus: params.status,
        reporterUserId: params.reporterUserId,
        severity: ({ LOW: 'L', MEDIUM: 'M', HIGH: 'H', CRITICAL: 'C' } as Record<string, string>)[params.severity || ''] || params.severity
      }
    })
    return mapPage(page)
  },
  getMyPage: async (params: any) => mapPage(await request.get({
    url: '/lab/instrument/fault-report/my-page',
    params: {
      pageNo: params.pageNo,
      pageSize: params.pageSize,
      confirmStatus: params.status,
      severity: ({ LOW: 'L', MEDIUM: 'M', HIGH: 'H', CRITICAL: 'C' } as Record<string, string>)[params.severity || ''] || params.severity
    }
  })),
  get: async (id: number) => toView(await request.get({ url: '/lab/instrument/fault-report/get', params: { id } }))
}
