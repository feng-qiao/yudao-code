import request from '@/config/axios'

/** View model adapted from InstrumentReservationImpactDO. */
export interface ReservationImpactVO {
  id?: number
  deviceId?: number
  reservationId?: number
  faultReportId?: number
  repairOrderId?: number
  impactReason?: string
  impactTime?: string
  handleStatus?: 'PENDING' | 'AUTO_RESTORED' | 'PROCESSED' | string
  handleUserId?: number
  handleUserName?: string
  handleTime?: string
  handleNote?: string
}

export const InstrumentReservationImpactApi = {
  getPage: async (params: any) =>
    await request.get({
      url: '/lab/instrument/reservation-impact/page',
      params: { pageNo: params.pageNo, pageSize: params.pageSize, deviceId: params.deviceId, handleStatus: params.handleStatus }
    }),
  handle: async (id: number, handleNote: string) =>
    await request.post({ url: `/lab/instrument/reservation-impact/handle/${id}`, data: { handleNote } })
}
