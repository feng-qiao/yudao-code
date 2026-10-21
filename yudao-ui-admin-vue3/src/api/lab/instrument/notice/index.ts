import request from '@/config/axios'

/** 仪器使用须知（INSTRUMENT-01，版本化） */
export interface InstrumentNoticeVO {
  id?: number
  targetType: string // DEVICE / PLATFORM（第一期仅 DEVICE）
  targetId: number
  version?: number
  title: string
  content: string
  status?: string // DRAFT / PUBLISHED / ARCHIVED
  requireAcknowledge?: boolean
  publishTime?: string
  publisherId?: number
  publisherName?: string
  remark?: string
  createTime?: string
}

export const InstrumentNoticeApi = {
  getPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/notice/page`, params })
  },
  get: async (id: number) => {
    return await request.get({ url: `/lab/instrument/notice/get?id=${id}` })
  },
  /** 当前生效版本 */
  getPublishedByTarget: async (targetType: string, targetId: number) => {
    return await request.get({
      url: `/lab/instrument/notice/get-by-target`,
      params: { targetType, targetId }
    })
  },
  /** 全部版本 */
  listByTarget: async (targetType: string, targetId: number) => {
    return await request.get({
      url: `/lab/instrument/notice/list-by-target`,
      params: { targetType, targetId }
    })
  },
  create: async (data: InstrumentNoticeVO) => {
    return await request.post({ url: `/lab/instrument/notice/create`, data })
  },
  update: async (data: InstrumentNoticeVO) => {
    return await request.put({ url: `/lab/instrument/notice/update`, data })
  },
  publish: async (id: number) => {
    return await request.put({ url: `/lab/instrument/notice/publish?id=${id}` })
  }
}
