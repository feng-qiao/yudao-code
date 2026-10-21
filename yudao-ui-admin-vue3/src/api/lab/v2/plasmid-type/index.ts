import request from '@/config/axios'

/** 质粒类型（V2） */
export interface PlasmidTypeVO {
  id: number // 主键ID
  code?: string // 类型编码
  name?: string // 类型名称
  managerId?: number // 库管员用户ID
  managerNickname?: string // 库管员昵称（后端填充；为空且 managerId 有值时表示已失效）
  status?: string // 状态
  sort?: number // 排序
  remark?: string // 管理备注
  createTime?: string // 创建时间
}

/** 库管员候选人（V2）：当前租户内启用且拥有 lab_keeper 角色的用户 */
export interface PlasmidTypeManagerCandidateVO {
  id: number // 用户ID
  nickname: string // 昵称
  username: string // 用户名
}

// 质粒类型（V2） API
export const PlasmidTypeApi = {
  // 查询质粒类型分页
  getPlasmidTypePage: async (params: any) => {
    return await request.get({ url: `/lab/v2/plasmid-type/page`, params })
  },

  // 查询质粒类型详情
  getPlasmidType: async (id: number) => {
    return await request.get({ url: `/lab/v2/plasmid-type/get?id=` + id })
  },

  // 新增质粒类型
  createPlasmidType: async (data: PlasmidTypeVO) => {
    return await request.post({ url: `/lab/v2/plasmid-type/create`, data })
  },

  // 修改质粒类型
  updatePlasmidType: async (data: PlasmidTypeVO) => {
    return await request.put({ url: `/lab/v2/plasmid-type/update`, data })
  },

  // 删除质粒类型
  deletePlasmidType: async (id: number) => {
    return await request.delete({ url: `/lab/v2/plasmid-type/delete?id=` + id })
  },

  // 查询库管员候选列表（当前租户内启用且拥有 lab_keeper 角色的用户）
  getManagerCandidates: async () => {
    return await request.get({ url: `/lab/v2/plasmid-type/manager-candidates` })
  }
}
