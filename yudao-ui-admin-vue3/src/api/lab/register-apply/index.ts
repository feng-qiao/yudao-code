import request from '@/config/axios'

/** 注册申请状态：0=待审批 / 1=已通过 / 2=已驳回（与后端 RegisterApplyStatusEnum 一致） */
export const RegisterApplyStatusEnum = {
  PENDING: 0,
  APPROVED: 1,
  REJECTED: 2
} as const

/** 注册申请状态展示文案（无字典项，使用本地常量；状态值以后端为准） */
export const RegisterApplyStatusLabels: Record<number, string> = {
  0: '待审批',
  1: '已通过',
  2: '已驳回'
}

/** 注册申请历史动作：1=提交 / 2=重新提交 / 3=审批通过 / 4=审批驳回（与后端枚举一致） */
export const RegisterApplyHistoryActionEnum = {
  SUBMIT: 1,
  RESUBMIT: 2,
  APPROVE: 3,
  REJECT: 4
} as const

/** 注册申请历史动作展示文案 */
export const RegisterApplyHistoryActionLabels: Record<number, string> = {
  1: '提交申请',
  2: '重新提交',
  3: '审批通过',
  4: '审批驳回'
}

/** 注册申请身份类别：1=硕士 2=博士 3=博士后 4=科研助理 5=教师（与后端 RegisterApplyIdentityTypeEnum 一致，需求规格 4.2） */
export const RegisterApplyIdentityTypeLabels: Record<number, string> = {
  1: '硕士',
  2: '博士',
  3: '博士后',
  4: '科研助理',
  5: '教师'
}

/** 身份类别下拉选项（硕士/博士/博士后：导师与指导教师必填） */
export const RegisterApplyIdentityTypeOptions = Object.entries(
  RegisterApplyIdentityTypeLabels
).map(([value, label]) => ({ value: Number(value), label }))

/** 研究方向：1-7 固定选项（与后端 RegisterApplyResearchDirectionEnum 一致，需求规格 4.4） */
export const RegisterApplyResearchDirectionLabels: Record<number, string> = {
  1: '中药新药开发与转化平台',
  2: '中药药效物质及合成生物学创制平台',
  3: '中医药人工智能平台',
  4: '生物信息学与GPCR多组学研究平台',
  5: '药物化学与递送系统开发平台',
  6: '中药活性成分筛选与分子育种平台',
  7: '中药受体药理学与靶标发现平台'
}

/** 研究方向下拉选项（服务端固定选项，不接受任意方向名称） */
export const RegisterApplyResearchDirectionOptions = Object.entries(
  RegisterApplyResearchDirectionLabels
).map(([value, label]) => ({ value: Number(value), label }))

/** 需要导师与指导教师必填的身份类别（硕士、博士、博士后，需求规格 4.3） */
export const requireSupervisor = (identityType?: number) =>
  identityType === 1 || identityType === 2 || identityType === 3

/** 注册申请信息（响应 VO，后端保证不含任何密码字段） */
export interface RegisterApplyVO {
  id: number // 申请编号
  username?: string // 申请用户名（学号或工号）
  nickname?: string // 姓名
  identityType?: number // 身份类别：1=硕士 2=博士 3=博士后 4=科研助理 5=教师
  researchDirection?: number // 研究方向：1-7 固定选项
  supervisor?: string // 导师
  instructor?: string // 指导教师
  startYmd?: string // 入学或入职开始年月（YYYY-MM）
  endYmd?: string // 入学或聘用结束年月（YYYY-MM）
  mobile?: string // 手机号
  email?: string // 邮箱
  applyReason?: string // 申请理由
  status?: number // 申请状态：0=待审批 / 1=已通过 / 2=已驳回
  resubmitCount?: number // 重新提交次数
  userId?: number // 审批通过后关联的正式用户ID
  auditUser?: number // 审核人用户ID
  auditTime?: string // 审核时间
  auditRemark?: string // 审核意见
  createTime?: string // 创建时间
}

/** 注册申请历史记录 */
export interface RegisterApplyHistoryVO {
  id: number // 历史记录编号
  applyId?: number // 关联的注册申请ID
  action?: number // 动作：1=提交 / 2=重新提交 / 3=审批通过 / 4=审批驳回
  operatorId?: number // 操作人用户ID；匿名提交/重新提交时为空
  remark?: string // 备注（审批意见或申请理由快照）
  createTime?: string // 创建时间
}

/** 提交注册申请请求（密码仅明文提交给后端，由服务端 BCrypt 哈希后存储，前端不落任何缓存） */
export interface RegisterApplySubmitReqVO {
  username: string // 登录账号：学号或工号，4-30 位字母数字
  password: string // 密码：4-16 位
  nickname: string // 姓名：必填，≤30 字符
  identityType: number // 身份类别：1-5，必填
  researchDirection: number // 研究方向：1-7 固定选项，必填
  supervisor?: string // 导师：硕士/博士/博士后必填（服务端按身份类别校验）
  instructor?: string // 指导教师：硕士/博士/博士后必填（服务端按身份类别校验）
  startYmd: string // 入学或入职开始年月：YYYY-MM，必填
  endYmd: string // 入学或聘用结束年月：YYYY-MM，必填
  mobile: string // 手机号：必填，1[3-9]开头的 11 位数字
  email: string // 邮箱：必填，≤50 字符
  applyReason?: string // 申请理由：可选，≤500 字符
}

/** 查询本人申请状态请求（用户名+密码鉴权，防枚举：不存在与密码错误返回同一文案） */
export interface RegisterApplyMyStatusReqVO {
  username: string
  password: string
}

/** 驳回后重新提交请求（用户名+原密码鉴权；newPassword 可选，不填沿用原密码） */
export interface RegisterApplyResubmitReqVO {
  username: string
  password: string // 原密码（身份校验）
  newPassword?: string // 新密码：可选，4-16 位
  nickname: string // 姓名：必填
  identityType: number // 身份类别：1-5，必填
  researchDirection: number // 研究方向：1-7 固定选项，必填
  supervisor?: string // 导师：硕士/博士/博士后必填
  instructor?: string // 指导教师：硕士/博士/博士后必填
  startYmd: string // 入学或入职开始年月：YYYY-MM
  endYmd: string // 入学或聘用结束年月：YYYY-MM
  mobile: string // 手机号：必填
  email: string // 邮箱：必填
  applyReason?: string
}

/** 管理端审批请求（驳回时 auditRemark 后端必填；≤500 字符） */
export interface RegisterApplyAuditReqVO {
  id: number // 申请编号
  auditRemark?: string // 审批意见
}

// 注册申请与审批 API（路径与后端 RegisterApplyController 一一对应，不自行改动）
export const RegisterApplyApi = {
  // 提交注册申请（匿名 @PermitAll）→ 返回申请编号
  submitApply: async (data: RegisterApplySubmitReqVO) => {
    return await request.post({ url: `/lab/register-apply/submit`, data })
  },

  // 查询本人申请最新状态（匿名，用户名+密码鉴权）→ 返回申请信息（不含密码）
  getMyStatus: async (data: RegisterApplyMyStatusReqVO) => {
    return await request.post({ url: `/lab/register-apply/my-status`, data })
  },

  // 驳回后修改资料并重新提交（匿名，用户名+原密码鉴权）
  resubmitApply: async (data: RegisterApplyResubmitReqVO) => {
    return await request.post({ url: `/lab/register-apply/resubmit`, data })
  },

  // 管理端：获得注册申请分页（权限 lab:register-apply:query）
  getApplyPage: async (params: any) => {
    return await request.get({ url: `/lab/register-apply/page`, params })
  },

  // 管理端：获得注册申请详情（权限 lab:register-apply:query）
  getApply: async (id: number) => {
    return await request.get({ url: `/lab/register-apply/get?id=` + id })
  },

  // 管理端：获得注册申请历史时间线（权限 lab:register-apply:query）
  getApplyHistoryList: async (applyId: number) => {
    return await request.get({ url: `/lab/register-apply/history-list?applyId=` + applyId })
  },

  // 管理端：审批通过（权限 lab:register-apply:audit）
  approveApply: async (data: RegisterApplyAuditReqVO) => {
    return await request.put({ url: `/lab/register-apply/approve`, data })
  },

  // 管理端：审批驳回，auditRemark 必填（权限 lab:register-apply:audit）
  rejectApply: async (data: RegisterApplyAuditReqVO) => {
    return await request.put({ url: `/lab/register-apply/reject`, data })
  }
}
