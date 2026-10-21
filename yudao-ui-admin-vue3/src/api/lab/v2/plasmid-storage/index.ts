import request from '@/config/axios'

/** 质粒存放位置（PLASMID-STORAGE-MANAGEMENT-01） */
export interface PlasmidStoragePositionVO {
  id: number // 存储档案ID
  plasmidId: number // 质粒ID
  plasmidNo?: string // 质粒编号
  plasmidName?: string // 质粒名称
  plasmidTypeId?: number // 质粒类型ID
  plasmidTypeName?: string // 质粒类型名称
  // 正式质粒位置
  plasmidFridge?: string
  plasmidLayer?: string
  plasmidBox?: string
  plasmidPosition?: string
  // 正式甘油菌位置
  glycerinFridge?: string
  glycerinLayer?: string
  glycerinBox?: string
  glycerinPosition?: string
  // 原始申报位置（仅详情接口返回）
  originalPlasmidFridge?: string
  originalPlasmidLayer?: string
  originalPlasmidBox?: string
  originalPlasmidPosition?: string
  originalGlycerinFridge?: string
  originalGlycerinLayer?: string
  originalGlycerinBox?: string
  originalGlycerinPosition?: string
  // 状态与最后修改信息
  positionConfirmed?: boolean // true=已确认，false=未确认
  lastModifierName?: string // 最后修改人
  lastModifierTime?: string // 最后修改时间
  createTime?: string
}

/** 位置修改请求 VO（某组四段全填或不填） */
export interface PlasmidStoragePositionUpdateVO {
  plasmidId: number
  plasmidFridge?: string
  plasmidLayer?: string
  plasmidBox?: string
  plasmidPosition?: string
  glycerinFridge?: string
  glycerinLayer?: string
  glycerinBox?: string
  glycerinPosition?: string
  remark?: string
}

/** 位置修改历史 VO */
export interface PlasmidStorageHistoryVO {
  id: number
  plasmidId: number
  plasmidNo?: string
  plasmidName?: string
  changeTarget: string // PLASMID / GLYCERIN / BOTH
  beforePlasmidFridge?: string
  beforePlasmidLayer?: string
  beforePlasmidBox?: string
  beforePlasmidPosition?: string
  beforeGlycerinFridge?: string
  beforeGlycerinLayer?: string
  beforeGlycerinBox?: string
  beforeGlycerinPosition?: string
  afterPlasmidFridge?: string
  afterPlasmidLayer?: string
  afterPlasmidBox?: string
  afterPlasmidPosition?: string
  afterGlycerinFridge?: string
  afterGlycerinLayer?: string
  afterGlycerinBox?: string
  afterGlycerinPosition?: string
  operatorId?: number
  operatorName?: string
  source?: string
  remark?: string
  createTime?: string
}

/** 登记信息（编辑回填专用） */
export interface PlasmidStorageRegistrationVO {
  plasmidId: number
  storageForm?: string
  concentration?: number
  volume?: number
  glycerinSpec?: string
  glycerinAmount?: number
  // PLASMID-STORAGE-MANAGEMENT-02：普通用户不得读取任何位置值，
  // 回填只返回"是否已保存"标志；提交时整组留空 = 保持原值，整组有值 = 录入新值
  hasOriginalPlasmidPosition?: boolean
  hasOriginalGlycerinPosition?: boolean
  sequenceFileId?: number
  sequenceFileName?: string
  sequenceNoFileReason?: string
  sequencingReportFileId?: number
  sequencingReportFileName?: string
}

// 质粒存放位置（V2） API
export const PlasmidStorageApi = {
  // 查询存放位置分页
  getPositionPage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid-storage/page`, params })
  },

  // 按存储档案ID查询位置详情（含原始申报位置）
  getPosition: async (id: number) => {
    return await request.get({ url: `/lab/v2/plasmid-storage/get?id=` + id })
  },

  // 按质粒ID查询位置详情（含原始申报位置），供质粒档案/库存详情弹窗调用
  getPositionByPlasmid: async (plasmidId: number) => {
    return await request.get({ url: `/lab/v2/plasmid-storage/get-by-plasmid?plasmidId=` + plasmidId })
  },

  // 直接修改正式存放位置（免审核，立即生效）
  updatePosition: async (data: PlasmidStoragePositionUpdateVO) => {
    return await request.put({ url: `/lab/v2/plasmid-storage/update-position`, data })
  },

  // 查询位置修改历史（按时间倒序）
  getPositionHistoryPage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid-storage/history/page`, params })
  },

  // 获取登记信息（编辑回填专用，仅登记人本人 + 草稿/被驳回状态）
  getRegistrationForEdit: async (plasmidId: number) => {
    return await request.get({ url: `/lab/v2/plasmid-storage/registration?plasmidId=` + plasmidId })
  }
}
