import request from '@/config/axios'

/** 实验室公告信息 */
export interface Announcement {
          id: number; // 公告ID
          title?: string; // 公告标题
          content: string; // 公告内容
          status: number; // 状态（0正常 1关闭）
  }

// 实验室公告 API
export const AnnouncementApi = {
  // 查询实验室公告分页
  getAnnouncementPage: async (params: any) => {
    return await request.get({ url: `/lab/announcement/page`, params })
  },

  // 查询实验室公告详情
  getAnnouncement: async (id: number) => {
    return await request.get({ url: `/lab/announcement/get?id=` + id })
  },

  // 新增实验室公告
  createAnnouncement: async (data: Announcement) => {
    return await request.post({ url: `/lab/announcement/create`, data })
  },

  // 修改实验室公告
  updateAnnouncement: async (data: Announcement) => {
    return await request.put({ url: `/lab/announcement/update`, data })
  },

  // 删除实验室公告
  deleteAnnouncement: async (id: number) => {
    return await request.delete({ url: `/lab/announcement/delete?id=` + id })
  },

  /** 批量删除实验室公告 */
  deleteAnnouncementList: async (ids: number[]) => {
    return await request.delete({ url: `/lab/announcement/delete-list?ids=${ids.join(',')}` })
  },

  // 导出实验室公告 Excel
  exportAnnouncement: async (params) => {
    return await request.download({ url: `/lab/announcement/export-excel`, params })
  }
}