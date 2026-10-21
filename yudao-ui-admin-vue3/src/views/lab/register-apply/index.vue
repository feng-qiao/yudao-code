<template>
  <div class="register-apply-page">
    <el-card
      class="register-apply-card !border-none !rounded-3xl shadow-lg animate__animated animate__bounceInRight"
      shadow="never"
    >
      <!-- Logo + 系统名（与登录页同源：brand/logo-hd.png + appStore.title） -->
      <div class="mb-10px flex items-center justify-center">
        <img alt="" class="mr-10px h-48px w-auto" src="@/assets/brand/logo-hd.png" />
        <span class="text-20px font-bold" style="color: var(--el-text-color-primary)">
          {{ underlineToHump(appStore.getTitle) }}
        </span>
      </div>
      <div class="mb-15px text-center">
        <h2 class="text-20px font-bold m-0" style="color: var(--el-text-color-primary)">
          注册申请
        </h2>
        <p class="text-13px mt-5px mb-0" style="color: var(--el-text-color-secondary)">
          提交申请后由管理员审批，通过后即可登录
        </p>
      </div>

      <!-- 租户上下文（复用登录页已证实的租户名→租户ID机制，仅当租户开关开启时显示） -->
      <el-form v-if="tenantEnable === 'true'" class="mb-5px" label-position="top" size="large">
        <el-form-item label="所属租户" class="!mb-10px">
          <el-input
            v-model="tenantName"
            placeholder="请输入您所属的租户名称"
            :prefix-icon="iconHouse"
          />
        </el-form-item>
      </el-form>

      <el-tabs v-model="activeTab" stretch>
        <!-- ============ Tab 1：提交注册申请 ============ -->
        <el-tab-pane label="提交申请" name="submit">
          <el-form
            ref="submitFormRef"
            :model="submitForm"
            :rules="submitRules"
            label-position="top"
            size="large"
            scroll-to-error
          >
            <!-- 分组 1：账号信息 -->
            <div class="form-section">
              <h3 class="form-section__title">账号信息</h3>
              <div class="form-grid">
                <el-form-item prop="username" label="学号 / 工号（登录账号）" class="span-2">
                  <el-input
                    v-model="submitForm.username"
                    placeholder="4-30 位字母或数字"
                    :prefix-icon="iconAvatar"
                    auto-complete="off"
                  />
                </el-form-item>
                <el-form-item prop="password" label="密码">
                  <el-input
                    v-model="submitForm.password"
                    type="password"
                    placeholder="4-16 位"
                    :prefix-icon="iconLock"
                    show-password
                    auto-complete="new-password"
                  />
                </el-form-item>
                <el-form-item prop="confirmPassword" label="确认密码">
                  <el-input
                    v-model="submitForm.confirmPassword"
                    type="password"
                    placeholder="请再次输入密码"
                    :prefix-icon="iconLock"
                    show-password
                    auto-complete="new-password"
                  />
                </el-form-item>
              </div>
            </div>

            <!-- 分组 2：基本信息 -->
            <div class="form-section">
              <h3 class="form-section__title">基本信息</h3>
              <div class="form-grid">
                <el-form-item prop="nickname" label="姓名">
                  <el-input
                    v-model="submitForm.nickname"
                    placeholder="请输入真实姓名，30 字以内"
                    :prefix-icon="iconAvatar"
                  />
                </el-form-item>
                <el-form-item prop="mobile" label="手机号">
                  <el-input v-model="submitForm.mobile" placeholder="11 位手机号" />
                </el-form-item>
                <el-form-item prop="email" label="邮箱">
                  <el-input v-model="submitForm.email" placeholder="50 字以内" />
                </el-form-item>
                <el-form-item prop="identityType" label="身份类别">
                  <el-select
                    v-model="submitForm.identityType"
                    placeholder="请选择身份类别"
                    class="!w-full"
                  >
                    <el-option
                      v-for="opt in RegisterApplyIdentityTypeOptions"
                      :key="opt.value"
                      :label="opt.label"
                      :value="opt.value"
                    />
                  </el-select>
                </el-form-item>
              </div>
            </div>

            <!-- 分组 3：学习或工作信息 -->
            <div class="form-section">
              <h3 class="form-section__title">学习或工作信息</h3>
              <div class="form-grid">
                <el-form-item prop="researchDirection" label="研究方向" class="span-2">
                  <el-select
                    v-model="submitForm.researchDirection"
                    placeholder="请选择研究方向"
                    class="!w-full"
                    filterable
                  >
                    <el-option
                      v-for="opt in RegisterApplyResearchDirectionOptions"
                      :key="opt.value"
                      :label="opt.label"
                      :value="opt.value"
                    />
                  </el-select>
                </el-form-item>
                <el-form-item prop="supervisor" label="导师">
                  <el-input
                    v-model="submitForm.supervisor"
                    :placeholder="supervisorPlaceholder"
                    :prefix-icon="iconAvatar"
                  />
                </el-form-item>
                <el-form-item prop="instructor" label="指导教师">
                  <el-input
                    v-model="submitForm.instructor"
                    :placeholder="supervisorPlaceholder"
                    :prefix-icon="iconAvatar"
                  />
                </el-form-item>
                <el-form-item prop="startYmd" label="入学 / 入职开始年月">
                  <el-date-picker
                    v-model="submitForm.startYmd"
                    type="month"
                    placeholder="选择年月"
                    format="YYYY-MM"
                    value-format="YYYY-MM"
                    class="!w-full"
                  />
                </el-form-item>
                <el-form-item prop="endYmd" label="入学 / 聘用结束年月">
                  <el-date-picker
                    v-model="submitForm.endYmd"
                    type="month"
                    placeholder="选择年月"
                    format="YYYY-MM"
                    value-format="YYYY-MM"
                    class="!w-full"
                  />
                </el-form-item>
              </div>
            </div>

            <!-- 分组 4：申请信息 -->
            <div class="form-section">
              <h3 class="form-section__title">申请信息</h3>
              <div class="form-grid">
                <el-form-item prop="applyReason" label="申请理由" class="span-2">
                  <el-input
                    v-model="submitForm.applyReason"
                    type="textarea"
                    :rows="3"
                    maxlength="500"
                    show-word-limit
                    placeholder="选填，请说明申请原因，便于审批人了解"
                  />
                </el-form-item>
              </div>
            </div>

            <!-- 吸底操作区：随表单滚动、到达底部时始终可见 -->
            <div class="form-action-bar">
              <el-button
                :loading="submitLoading"
                class="w-full"
                type="primary"
                @click="handleSubmit"
              >
                提交注册申请
              </el-button>
            </div>
          </el-form>
        </el-tab-pane>

        <!-- ============ Tab 2：查询申请状态（用户名+密码鉴权） ============ -->
        <el-tab-pane label="查询状态" name="status">
          <!-- 查询表单 -->
          <el-form
            v-if="!statusResult"
            ref="statusFormRef"
            :model="statusForm"
            :rules="statusRules"
            label-position="top"
            size="large"
            scroll-to-error
          >
            <el-form-item prop="username" label="用户名">
              <el-input
                v-model="statusForm.username"
                placeholder="请输入申请时的用户名"
                :prefix-icon="iconAvatar"
                auto-complete="off"
              />
            </el-form-item>
            <el-form-item prop="password" label="密码">
              <el-input
                v-model="statusForm.password"
                type="password"
                placeholder="请输入申请时的密码"
                :prefix-icon="iconLock"
                show-password
                auto-complete="new-password"
              />
            </el-form-item>
            <div class="form-action-bar form-action-bar--static">
              <el-button
                :loading="statusLoading"
                class="w-full"
                type="primary"
                @click="handleQueryStatus"
              >
                查询申请状态
              </el-button>
            </div>
          </el-form>

          <!-- 查询结果 -->
          <div v-else>
            <el-descriptions :column="1" border class="mb-15px">
              <el-descriptions-item label="学号 / 工号">{{
                statusResult.username
              }}</el-descriptions-item>
              <el-descriptions-item label="姓名">{{
                statusResult.nickname || '-'
              }}</el-descriptions-item>
              <el-descriptions-item label="身份类别">{{
                identityLabel(statusResult.identityType)
              }}</el-descriptions-item>
              <el-descriptions-item label="研究方向">{{
                directionLabel(statusResult.researchDirection)
              }}</el-descriptions-item>
              <el-descriptions-item label="导师">{{
                statusResult.supervisor || '-'
              }}</el-descriptions-item>
              <el-descriptions-item label="指导教师">{{
                statusResult.instructor || '-'
              }}</el-descriptions-item>
              <el-descriptions-item label="开始年月">{{
                statusResult.startYmd || '-'
              }}</el-descriptions-item>
              <el-descriptions-item label="结束年月">{{
                statusResult.endYmd || '-'
              }}</el-descriptions-item>
              <el-descriptions-item label="手机号">{{
                statusResult.mobile || '-'
              }}</el-descriptions-item>
              <el-descriptions-item label="邮箱">{{
                statusResult.email || '-'
              }}</el-descriptions-item>
              <el-descriptions-item label="当前状态">
                <el-tag :type="statusTagType(statusResult.status)">
                  {{ statusLabel(statusResult.status) }}
                </el-tag>
              </el-descriptions-item>
              <el-descriptions-item label="重提次数">{{
                statusResult.resubmitCount ?? 0
              }}</el-descriptions-item>
              <el-descriptions-item label="申请时间">{{
                formatDate(statusResult.createTime)
              }}</el-descriptions-item>
              <el-descriptions-item v-if="statusResult.auditTime" label="审批时间">
                {{ formatDate(statusResult.auditTime) }}
              </el-descriptions-item>
              <el-descriptions-item v-if="statusResult.auditRemark" label="审批意见">
                {{ statusResult.auditRemark }}
              </el-descriptions-item>
            </el-descriptions>

            <!-- 待审批 -->
            <el-alert
              v-if="statusResult.status === RegisterApplyStatusEnum.PENDING"
              title="申请正在等待审批，请耐心等待"
              type="info"
              :closable="false"
              class="mb-10px"
            />
            <!-- 已通过 -->
            <template v-if="statusResult.status === RegisterApplyStatusEnum.APPROVED">
              <el-alert
                title="申请已通过，请使用该用户名和密码登录系统"
                type="success"
                :closable="false"
                class="mb-10px"
              />
              <el-button class="w-full" type="primary" size="large" @click="goLogin">
                去登录
              </el-button>
            </template>
            <!-- 已驳回：提供修改重提入口 -->
            <template v-if="statusResult.status === RegisterApplyStatusEnum.REJECTED">
              <el-alert
                title="申请已被驳回，请根据审批意见修改后重新提交"
                type="error"
                :closable="false"
                class="mb-10px"
              />
              <el-button class="w-full" type="warning" size="large" @click="showResubmit">
                修改并重新提交
              </el-button>
            </template>
            <el-button class="w-full mt-10px" @click="backToStatusQuery">返回重新查询</el-button>
          </div>
        </el-tab-pane>

        <!-- ============ Tab 3：驳回后修改重提（仅从查询结果进入） ============ -->
        <el-tab-pane v-if="resubmitVisible" label="重新提交" name="resubmit">
          <el-alert
            title="原密码用于身份校验；如需更换密码请填写新密码，否则沿用原密码"
            type="info"
            :closable="false"
            class="mb-10px"
          />
          <el-form
            ref="resubmitFormRef"
            :model="resubmitForm"
            :rules="resubmitRules"
            label-position="top"
            size="large"
            scroll-to-error
          >
            <!-- 分组 1：账号信息 -->
            <div class="form-section">
              <h3 class="form-section__title">账号信息</h3>
              <div class="form-grid">
                <el-form-item prop="username" label="用户名" class="span-2">
                  <el-input v-model="resubmitForm.username" disabled />
                </el-form-item>
                <el-form-item prop="password" label="原密码">
                  <el-input
                    v-model="resubmitForm.password"
                    type="password"
                    placeholder="请输入原密码"
                    :prefix-icon="iconLock"
                    show-password
                    auto-complete="new-password"
                  />
                </el-form-item>
                <el-form-item prop="newPassword" label="新密码（可选）">
                  <el-input
                    v-model="resubmitForm.newPassword"
                    type="password"
                    placeholder="不修改密码则留空；填写时为 4-16 位"
                    :prefix-icon="iconLock"
                    show-password
                    auto-complete="new-password"
                  />
                </el-form-item>
              </div>
            </div>

            <!-- 分组 2：基本信息 -->
            <div class="form-section">
              <h3 class="form-section__title">基本信息</h3>
              <div class="form-grid">
                <el-form-item prop="nickname" label="姓名">
                  <el-input
                    v-model="resubmitForm.nickname"
                    placeholder="请输入真实姓名，30 字以内"
                    :prefix-icon="iconAvatar"
                  />
                </el-form-item>
                <el-form-item prop="mobile" label="手机号">
                  <el-input v-model="resubmitForm.mobile" placeholder="11 位手机号" />
                </el-form-item>
                <el-form-item prop="email" label="邮箱">
                  <el-input v-model="resubmitForm.email" placeholder="50 字以内" />
                </el-form-item>
                <el-form-item prop="identityType" label="身份类别">
                  <el-select
                    v-model="resubmitForm.identityType"
                    placeholder="请选择身份类别"
                    class="!w-full"
                  >
                    <el-option
                      v-for="opt in RegisterApplyIdentityTypeOptions"
                      :key="opt.value"
                      :label="opt.label"
                      :value="opt.value"
                    />
                  </el-select>
                </el-form-item>
              </div>
            </div>

            <!-- 分组 3：学习或工作信息 -->
            <div class="form-section">
              <h3 class="form-section__title">学习或工作信息</h3>
              <div class="form-grid">
                <el-form-item prop="researchDirection" label="研究方向" class="span-2">
                  <el-select
                    v-model="resubmitForm.researchDirection"
                    placeholder="请选择研究方向"
                    class="!w-full"
                    filterable
                  >
                    <el-option
                      v-for="opt in RegisterApplyResearchDirectionOptions"
                      :key="opt.value"
                      :label="opt.label"
                      :value="opt.value"
                    />
                  </el-select>
                </el-form-item>
                <el-form-item prop="supervisor" label="导师">
                  <el-input
                    v-model="resubmitForm.supervisor"
                    :placeholder="supervisorPlaceholder"
                    :prefix-icon="iconAvatar"
                  />
                </el-form-item>
                <el-form-item prop="instructor" label="指导教师">
                  <el-input
                    v-model="resubmitForm.instructor"
                    :placeholder="supervisorPlaceholder"
                    :prefix-icon="iconAvatar"
                  />
                </el-form-item>
                <el-form-item prop="startYmd" label="入学 / 入职开始年月">
                  <el-date-picker
                    v-model="resubmitForm.startYmd"
                    type="month"
                    placeholder="选择年月"
                    format="YYYY-MM"
                    value-format="YYYY-MM"
                    class="!w-full"
                  />
                </el-form-item>
                <el-form-item prop="endYmd" label="入学 / 聘用结束年月">
                  <el-date-picker
                    v-model="resubmitForm.endYmd"
                    type="month"
                    placeholder="选择年月"
                    format="YYYY-MM"
                    value-format="YYYY-MM"
                    class="!w-full"
                  />
                </el-form-item>
              </div>
            </div>

            <!-- 分组 4：申请信息 -->
            <div class="form-section">
              <h3 class="form-section__title">申请信息</h3>
              <div class="form-grid">
                <el-form-item prop="applyReason" label="申请理由" class="span-2">
                  <el-input
                    v-model="resubmitForm.applyReason"
                    type="textarea"
                    :rows="3"
                    maxlength="500"
                    show-word-limit
                    placeholder="建议根据驳回意见补充说明"
                  />
                </el-form-item>
              </div>
            </div>

            <!-- 吸底操作区：随表单滚动、到达底部时始终可见 -->
            <div class="form-action-bar">
              <el-button
                :loading="resubmitLoading"
                class="w-full"
                type="primary"
                @click="handleResubmit"
              >
                重新提交
              </el-button>
            </div>
          </el-form>
        </el-tab-pane>
      </el-tabs>

      <div class="mt-10px text-center">
        <el-button link type="primary" @click="goLogin">已有账号？去登录</el-button>
      </div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { underlineToHump } from '@/utils'
import { useAppStore } from '@/store/modules/app'
import { useIcon } from '@/hooks/web/useIcon'
import * as authUtil from '@/utils/auth'
import * as LoginApi from '@/api/login'
import { formatDate } from '@/utils/formatTime'
import {
  RegisterApplyApi,
  RegisterApplyVO,
  RegisterApplyStatusEnum,
  RegisterApplyStatusLabels,
  RegisterApplyIdentityTypeLabels,
  RegisterApplyIdentityTypeOptions,
  RegisterApplyResearchDirectionLabels,
  RegisterApplyResearchDirectionOptions,
  requireSupervisor
} from '@/api/lab/register-apply'

/** 注册申请页（匿名访问，路由 /register 已在全局路由守卫白名单中） */
defineOptions({ name: 'RegisterApply' })

const message = useMessage()
const { push } = useRouter()
const appStore = useAppStore()
const iconHouse = useIcon({ icon: 'ep:house' })
const iconAvatar = useIcon({ icon: 'ep:avatar' })
const iconLock = useIcon({ icon: 'ep:lock' })

// ========== 租户上下文 ==========
// 复用登录页 RegisterForm 的既有机制：租户名 → /system/tenant/get-id-by-name → 本地缓存
// axios 拦截器从缓存读取 tenant-id 请求头；本页不发明新的域名映射规则，不硬编码租户 ID
const tenantEnable = import.meta.env.VITE_APP_TENANT_ENABLE
const tenantName = ref<string>(import.meta.env.VITE_APP_DEFAULT_LOGIN_TENANT || '')

/** 提交前确保租户上下文就绪（与 RegisterForm.handleRegister 一致：按租户名解析并写入缓存） */
const ensureTenantId = async () => {
  if (tenantEnable !== 'true') {
    return
  }
  if (!tenantName.value) {
    message.error('请输入您所属的租户名称')
    throw new Error('tenant name required')
  }
  const tenantId = await LoginApi.getTenantIdByName(tenantName.value)
  authUtil.setTenantId(tenantId)
}

/** 根据域名获得租户信息（复用 RegisterForm 的既有入口，失败时静默忽略） */
const getTenantByWebsite = async () => {
  if (tenantEnable === 'true') {
    try {
      const res = await LoginApi.getTenantByWebsite(location.host)
      if (res) {
        tenantName.value = res.name
        authUtil.setTenantId(res.id)
      }
    } catch {
      // 域名未配置租户时忽略，由用户手动填写租户名
    }
  }
}

// ========== Tab 切换 ==========
const activeTab = ref('submit')

// ========== 提交申请 ==========
const submitFormRef = ref()
const submitLoading = ref(false)
const submitForm = ref({
  username: '',
  password: '',
  confirmPassword: '',
  nickname: '',
  identityType: undefined as number | undefined,
  researchDirection: undefined as number | undefined,
  supervisor: '',
  instructor: '',
  startYmd: '',
  endYmd: '',
  mobile: '',
  email: '',
  applyReason: ''
})

/** 导师/指导教师占位文案：按身份类别提示是否必填（需求规格 4.3） */
const supervisorPlaceholder = computed(() => '硕士、博士、博士后必填；科研助理、教师可选')

/** 身份类别 / 研究方向展示文案（查询结果使用） */
const identityLabel = (value?: number) =>
  value !== undefined ? (RegisterApplyIdentityTypeLabels[value] ?? String(value)) : '-'
const directionLabel = (value?: number) =>
  value !== undefined ? (RegisterApplyResearchDirectionLabels[value] ?? String(value)) : '-'

const equalToPassword = (_rule, value) => {
  if (submitForm.value.password !== value) {
    return Promise.reject(new Error('两次输入的密码不一致'))
  }
  return Promise.resolve()
}

/** 导师/指导教师条件必填：硕士、博士、博士后必填（与后端服务端校验同规则） */
const supervisorRequired = (_rule, value) => {
  if (requireSupervisor(submitForm.value.identityType) && !String(value || '').trim()) {
    return Promise.reject(new Error('硕士、博士、博士后必须填写导师'))
  }
  return Promise.resolve()
}
const instructorRequired = (_rule, value) => {
  if (requireSupervisor(submitForm.value.identityType) && !String(value || '').trim()) {
    return Promise.reject(new Error('硕士、博士、博士后必须填写指导教师'))
  }
  return Promise.resolve()
}

// 校验规则与后端 VO 契约一致（RegisterApplySubmitReqVO + Service 业务校验）
const usernamePattern = /^[a-zA-Z0-9]{4,30}$/
const ymPattern = /^\d{4}-(0[1-9]|1[0-2])$/
const submitRules = {
  username: [
    { required: true, message: '请输入学号或工号', trigger: 'blur' },
    { pattern: usernamePattern, message: '学号或工号由 4-30 位字母或数字组成', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 4, max: 16, message: '密码长度为 4-16 位', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: '请再次输入密码', trigger: 'blur' },
    { required: true, validator: equalToPassword, trigger: 'blur' }
  ],
  nickname: [
    { required: true, message: '请输入姓名', trigger: 'blur' },
    { max: 30, message: '姓名长度不能超过 30 个字符', trigger: 'blur' }
  ],
  identityType: [{ required: true, message: '请选择身份类别', trigger: 'change' }],
  researchDirection: [{ required: true, message: '请选择研究方向', trigger: 'change' }],
  supervisor: [{ validator: supervisorRequired, trigger: 'blur' }],
  instructor: [{ validator: instructorRequired, trigger: 'blur' }],
  startYmd: [
    { required: true, message: '请选择入学或入职开始年月', trigger: 'change' },
    { pattern: ymPattern, message: '开始年月格式必须为 YYYY-MM', trigger: 'change' }
  ],
  endYmd: [
    { required: true, message: '请选择入学或聘用结束年月', trigger: 'change' },
    { pattern: ymPattern, message: '结束年月格式必须为 YYYY-MM', trigger: 'change' }
  ],
  mobile: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '手机号格式不正确', trigger: 'blur' }
  ],
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email', message: '邮箱格式不正确', trigger: 'blur' },
    { max: 50, message: '邮箱长度不能超过 50 个字符', trigger: 'blur' }
  ],
  applyReason: [{ max: 500, message: '申请理由长度不能超过 500 个字符', trigger: 'blur' }]
}

const handleSubmit = async () => {
  const valid = await submitFormRef.value?.validate().catch(() => false)
  if (!valid) return
  submitLoading.value = true
  try {
    await ensureTenantId()
    await RegisterApplyApi.submitApply({
      username: submitForm.value.username,
      password: submitForm.value.password,
      nickname: submitForm.value.nickname,
      identityType: submitForm.value.identityType!,
      researchDirection: submitForm.value.researchDirection!,
      supervisor: submitForm.value.supervisor || undefined,
      instructor: submitForm.value.instructor || undefined,
      startYmd: submitForm.value.startYmd,
      endYmd: submitForm.value.endYmd,
      mobile: submitForm.value.mobile,
      email: submitForm.value.email,
      applyReason: submitForm.value.applyReason || undefined
    })
    message.success('注册申请已提交，请等待管理员审批')
    // 清空表单中的密码，避免停留在内存界面
    submitForm.value.password = ''
    submitForm.value.confirmPassword = ''
    // 引导用户查询状态
    statusForm.value.username = submitForm.value.username
    activeTab.value = 'status'
  } finally {
    submitLoading.value = false
  }
}

// ========== 查询申请状态 ==========
const statusFormRef = ref()
const statusLoading = ref(false)
const statusResult = ref<RegisterApplyVO | null>(null)
const statusForm = ref({
  username: '',
  password: ''
})

const statusRules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
}

const statusLabel = (status?: number) => {
  return status !== undefined ? (RegisterApplyStatusLabels[status] ?? String(status)) : '-'
}

const statusTagType = (status?: number) => {
  switch (status) {
    case RegisterApplyStatusEnum.APPROVED:
      return 'success'
    case RegisterApplyStatusEnum.REJECTED:
      return 'danger'
    default:
      return 'warning'
  }
}

const handleQueryStatus = async () => {
  const valid = await statusFormRef.value?.validate().catch(() => false)
  if (!valid) return
  statusLoading.value = true
  try {
    await ensureTenantId()
    // 响应 VO 不含任何密码字段，仅渲染已知字段，密码不显示、不持久化
    statusResult.value = await RegisterApplyApi.getMyStatus({
      username: statusForm.value.username,
      password: statusForm.value.password
    })
  } catch {
    // 业务错误（用户名不存在或密码错误，后端统一文案防枚举）已由 axios 拦截器统一提示
  } finally {
    statusLoading.value = false
  }
}

const backToStatusQuery = () => {
  statusResult.value = null
  statusForm.value.password = ''
}

// ========== 驳回后修改重提 ==========
const resubmitVisible = ref(false)
const resubmitFormRef = ref()
const resubmitLoading = ref(false)
const resubmitForm = ref({
  username: '',
  password: '',
  newPassword: '',
  nickname: '',
  identityType: undefined as number | undefined,
  researchDirection: undefined as number | undefined,
  supervisor: '',
  instructor: '',
  startYmd: '',
  endYmd: '',
  mobile: '',
  email: '',
  applyReason: ''
})

/** 重提条件必填校验（与提交同规则：硕士、博士、博士后必填导师与指导教师） */
const resubmitSupervisorRequired = (_rule, value) => {
  if (requireSupervisor(resubmitForm.value.identityType) && !String(value || '').trim()) {
    return Promise.reject(new Error('硕士、博士、博士后必须填写导师'))
  }
  return Promise.resolve()
}
const resubmitInstructorRequired = (_rule, value) => {
  if (requireSupervisor(resubmitForm.value.identityType) && !String(value || '').trim()) {
    return Promise.reject(new Error('硕士、博士、博士后必须填写指导教师'))
  }
  return Promise.resolve()
}

const resubmitRules = {
  username: [{ required: true, message: '用户名不能为空', trigger: 'blur' }],
  password: [{ required: true, message: '请输入原密码', trigger: 'blur' }],
  newPassword: [{ min: 4, max: 16, message: '新密码长度为 4-16 位', trigger: 'blur' }],
  nickname: [
    { required: true, message: '请输入姓名', trigger: 'blur' },
    { max: 30, message: '姓名长度不能超过 30 个字符', trigger: 'blur' }
  ],
  identityType: [{ required: true, message: '请选择身份类别', trigger: 'change' }],
  researchDirection: [{ required: true, message: '请选择研究方向', trigger: 'change' }],
  supervisor: [{ validator: resubmitSupervisorRequired, trigger: 'blur' }],
  instructor: [{ validator: resubmitInstructorRequired, trigger: 'blur' }],
  startYmd: [
    { required: true, message: '请选择入学或入职开始年月', trigger: 'change' },
    { pattern: ymPattern, message: '开始年月格式必须为 YYYY-MM', trigger: 'change' }
  ],
  endYmd: [
    { required: true, message: '请选择入学或聘用结束年月', trigger: 'change' },
    { pattern: ymPattern, message: '结束年月格式必须为 YYYY-MM', trigger: 'change' }
  ],
  mobile: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '手机号格式不正确', trigger: 'blur' }
  ],
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email', message: '邮箱格式不正确', trigger: 'blur' },
    { max: 50, message: '邮箱长度不能超过 50 个字符', trigger: 'blur' }
  ],
  applyReason: [{ max: 500, message: '申请理由长度不能超过 500 个字符', trigger: 'blur' }]
}

/** 从查询结果进入重提表单：预填身份凭证（仅内存）与原申请资料（含全部业务字段） */
const showResubmit = () => {
  if (!statusResult.value) return
  resubmitVisible.value = true
  resubmitForm.value = {
    username: statusResult.value.username || '',
    password: statusForm.value.password, // 原密码仅内存传递，用于后端身份校验
    newPassword: '',
    nickname: statusResult.value.nickname || '',
    identityType: statusResult.value.identityType,
    researchDirection: statusResult.value.researchDirection,
    supervisor: statusResult.value.supervisor || '',
    instructor: statusResult.value.instructor || '',
    startYmd: statusResult.value.startYmd || '',
    endYmd: statusResult.value.endYmd || '',
    mobile: statusResult.value.mobile || '',
    email: statusResult.value.email || '',
    applyReason: statusResult.value.applyReason || ''
  }
  activeTab.value = 'resubmit'
}

const handleResubmit = async () => {
  const valid = await resubmitFormRef.value?.validate().catch(() => false)
  if (!valid) return
  resubmitLoading.value = true
  try {
    await ensureTenantId()
    await RegisterApplyApi.resubmitApply({
      username: resubmitForm.value.username,
      password: resubmitForm.value.password,
      newPassword: resubmitForm.value.newPassword || undefined,
      nickname: resubmitForm.value.nickname,
      identityType: resubmitForm.value.identityType!,
      researchDirection: resubmitForm.value.researchDirection!,
      supervisor: resubmitForm.value.supervisor || undefined,
      instructor: resubmitForm.value.instructor || undefined,
      startYmd: resubmitForm.value.startYmd,
      endYmd: resubmitForm.value.endYmd,
      mobile: resubmitForm.value.mobile,
      email: resubmitForm.value.email,
      applyReason: resubmitForm.value.applyReason || undefined
    })
    message.success('重新提交成功，请等待管理员审批')
    // 重提成功后刷新状态；密码仅保留在内存中用于状态刷新
    statusResult.value = await RegisterApplyApi.getMyStatus({
      username: resubmitForm.value.username,
      password: resubmitForm.value.password
    })
    statusForm.value.username = resubmitForm.value.username
    resubmitVisible.value = false
    activeTab.value = 'status'
  } catch {
    // 业务错误（原密码错误、状态非驳回等）已由 axios 拦截器统一提示
  } finally {
    resubmitLoading.value = false
  }
}

// ========== 其他 ==========
const goLogin = () => {
  push({ path: '/login' })
}

onMounted(() => {
  getTenantByWebsite()
})
</script>

<style lang="scss" scoped>
// 视觉风格与登录页（Login.vue）统一：同一背景 login-bg.svg、同一圆角卡片与入场动画、
// 同一颜色变量（el-card 自动适配明暗主题）。
// REG-03-21：卡片加宽并按视口限高，表单主体在卡片内部滚动，提交操作区吸底始终可达；
// 全部样式仅作用于本页（scoped），不修改公共布局与登录页样式。
.register-apply-page {
  position: relative;
  display: flex;
  justify-content: center;
  min-height: 100vh;
  min-height: 100dvh;
  padding: 12px 0 max(12px, env(safe-area-inset-bottom));

  &::before {
    position: absolute;
    top: 0;
    left: 0;
    z-index: -1;
    width: 100%;
    height: 100%;
    background-image: url('@/assets/svgs/login-bg.svg');
    background-position: center;
    background-repeat: no-repeat;
    background-size: cover;
    content: '';
  }
}

// 卡片：桌面 720px 双列，窄屏 94vw；高度不超过视口，内容改由内部标签页区域滚动。
// margin:auto —— 内容短时居中，内容长（超出）时自动退化为 0，不会出现顶部被裁切。
.register-apply-card {
  width: min(720px, 94vw);
  max-height: calc(100dvh - 24px);
  margin: auto;
  display: flex;
  flex-direction: column;

  :deep(.el-card__body) {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    padding: 20px 20px 14px;
  }
}

// 标签页占满卡片剩余高度，仅标签内容区滚动，页头/页脚保持不动
:deep(.el-tabs) {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;

  .el-tabs__header {
    flex: none;
    margin-bottom: 10px;
  }

  .el-tabs__content {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    overflow-x: hidden;
  }

  .el-tab-pane {
    padding-right: 4px;
  }
}

// ========== 表单分组与双列网格 ==========
.form-section__title {
  display: flex;
  align-items: center;
  margin: 14px 0 10px;
  font-size: 14px;
  font-weight: 600;
  color: var(--el-text-color-primary);

  &::before {
    display: inline-block;
    width: 3px;
    height: 14px;
    margin-right: 8px;
    border-radius: 2px;
    background: var(--el-color-primary);
    content: '';
  }
}

.form-section:first-child .form-section__title {
  margin-top: 2px;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  column-gap: 16px;
}

// 长字段（用户名、研究方向、申请理由）独占整行
.span-2 {
  grid-column: 1 / -1;
}

// 窄屏与移动端：单列，不产生横向溢出
@media (max-width: 640px) {
  .form-grid {
    grid-template-columns: minmax(0, 1fr);
    column-gap: 0;
  }
}

// ========== 吸底操作区 ==========
// sticky 相对标签内容滚动区：滚动时吸附在内容区底部（不遮挡视口外内容），
// 到自然位置时随表单结束；不使用 fixed，故不遮挡输入框、错误提示或任何弹层。
.form-action-bar {
  position: sticky;
  bottom: 0;
  z-index: 5;
  margin: 6px -20px 0;
  padding: 10px 20px;
  background: var(--el-card-bg-color, var(--el-bg-color));
  border-top: 1px solid var(--el-border-color-lighter);
}

// 内容很短的查询表单：无需吸底，保持普通文档流，避免大面积空白与分隔线
.form-action-bar--static {
  position: static;
  margin-top: 2px;
  padding: 0;
  background: transparent;
  border-top: none;
}
</style>
