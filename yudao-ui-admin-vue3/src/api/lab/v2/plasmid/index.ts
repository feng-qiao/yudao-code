import request from '@/config/axios'

/** 质粒档案（V2） */
export interface PlasmidVO {
  id: number // 主键ID
  plasmidNo?: string // 质粒编号
  seqNo?: number // 系统顺序号
  name?: string // 质粒名称
  recipient?: string // 受体
  species?: string // 种类
  resistance?: string // 抗性
  vectorName?: string // 载体名称
  createDate?: string // 业务创建日期
  fluorescentTag?: string // 荧光/蛋白标签（多选逗号分隔）
  mutation?: string // 突变信息
  modification?: string // 改造信息
  tag?: string // 标签
  plasmidTypeId?: number // 质粒类型ID
  auditStatus?: string // 审核状态
  remark?: string // 业务备注
  createTime?: string // 创建时间
  // ========== 保存登记信息（新增/编辑时提交） ==========
  storageForm?: string // 保存形式（多选逗号分隔）
  concentration?: number // 质粒浓度 ng/μL
  volume?: number // 质粒体积 μL
  glycerinSpec?: string // 甘油菌规格
  glycerinAmount?: number // 甘油菌量 μL
  originalPlasmidFridge?: string // 原始质粒冰箱
  originalPlasmidLayer?: string // 原始质粒层
  originalPlasmidBox?: string // 原始质粒盒
  originalPlasmidPosition?: string // 原始质粒位置
  originalGlycerinFridge?: string // 原始甘油菌冰箱
  originalGlycerinLayer?: string // 原始甘油菌层
  originalGlycerinBox?: string // 原始甘油菌盒
  originalGlycerinPosition?: string // 原始甘油菌位置
  sequenceFileId?: number // 序列图谱文件ID
  sequenceFileName?: string // 序列图谱文件名快照
  sequenceNoFileReason?: string // 无序列图谱原因
  sequencingReportFileId?: number // 测序/检测报告文件ID
  sequencingReportFileName?: string // 测序/检测报告文件名快照
  initialQuantityDeclared?: number // 申报初始库存数量 μL
}

// 质粒档案（V2） API
export const PlasmidApi = {
  // 查询质粒档案分页
  getPlasmidPage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid/page`, params })
  },

  // 查询质粒档案详情
  getPlasmid: async (id: number) => {
    return await request.get({ url: `/lab/v2/plasmid/get?id=` + id })
  },

  // 新增质粒档案
  createPlasmid: async (data: PlasmidVO) => {
    return await request.post({ url: `/lab/v2/plasmid/create`, data })
  },

  // 修改质粒档案
  updatePlasmid: async (data: PlasmidVO) => {
    return await request.put({ url: `/lab/v2/plasmid/update`, data })
  },

  // 删除质粒档案
  deletePlasmid: async (id: number) => {
    return await request.delete({ url: `/lab/v2/plasmid/delete?id=` + id })
  },

  // 提交质粒审核
  submitPlasmid: async (id: number) => {
    return await request.post({ url: `/lab/v2/plasmid/submit`, data: { id } })
  }
}
