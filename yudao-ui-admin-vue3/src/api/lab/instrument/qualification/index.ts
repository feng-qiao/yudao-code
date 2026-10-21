import request from '@/config/axios'

/** 仪器使用资质申请单（INSTRUMENT-02） */
export interface QualificationApplyVO {
  id?: number
  applyNo?: string
  targetType?: string // DEVICE（第一期固定）
  targetId?: number
  deviceName?: string
  applicantUserId?: number
  applicantName?: string
  reason?: string
  attachmentFileId?: number
  attachmentFileName?: string
  status?: string // PENDING / APPROVED / REJECTED / CANCELED
  applyTime?: string
  auditorUserId?: number
  auditorName?: string
  auditTime?: string
  auditResult?: string
  auditOpinion?: string
  expireTime?: string
  remark?: string
}

/** 仪器资质（用户-设备维度） */
export interface InstrumentQualificationVO {
  id?: number
  userId?: number
  userName?: string
  targetType?: string
  targetId?: number
  deviceName?: string
  status?: string // ACTIVE / EXPIRED / SUSPENDED / REVOKED
  sourceApplyId?: number
  grantedTime?: string
  expireTime?: string
  revokeTime?: string
  remark?: string
}

/** 申请审核历史（只增不改） */
export interface QualApplyHistoryVO {
  id?: number
  applyId?: number
  action?: string // SUBMIT / APPROVE / REJECT / CANCEL
  fromStatus?: string
  toStatus?: string
  operatorUserId?: number
  operatorName?: string
  actionTime?: string
  opinion?: string
}

export const InstrumentQualificationApi = {
  /** 提交资质申请（本人） */
  apply: async (data: { deviceId: number; reason?: string; attachmentFileId?: number; attachmentFileName?: string; remark?: string }) => {
    return await request.post({ url: `/lab/instrument/qualification/apply`, data })
  },
  /** 撤回本人待审核申请 */
  cancel: async (id: number) => {
    return await request.post({ url: `/lab/instrument/qualification/cancel`, params: { id } })
  },
  /** 审核申请（通过/驳回） */
  audit: async (data: { id: number; result: string; opinion?: string; expireTime?: string; remark?: string }) => {
    return await request.post({ url: `/lab/instrument/qualification/audit`, data })
  },
  /** 申请分页（本人/授权范围） */
  getApplyPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/qualification/apply/page`, params })
  },
  /** 申请详情 */
  getApply: async (id: number) => {
    return await request.get({ url: `/lab/instrument/qualification/apply/get`, params: { id } })
  },
  /** 申请审核历史 */
  getApplyHistory: async (id: number) => {
    return await request.get({ url: `/lab/instrument/qualification/apply/history-list`, params: { id } })
  },
  /** 我的资质列表 */
  getMyQualifications: async () => {
    return await request.get({ url: `/lab/instrument/qualification/my` })
  },
  /** 资质分页（管理/授权范围） */
  getQualificationPage: async (params: any) => {
    return await request.get({ url: `/lab/instrument/qualification/page`, params })
  },
  /** 撤销资质（管理员） */
  revoke: async (data: { id: number; reason: string }) => {
    return await request.post({ url: `/lab/instrument/qualification/revoke`, data })
  }
}
