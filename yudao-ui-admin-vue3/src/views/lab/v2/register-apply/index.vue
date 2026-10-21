<template>
  <ContentWrap>
    <!-- 搜索工作栏 -->
    <el-form
      class="-mb-15px"
      :model="queryParams"
      ref="queryFormRef"
      :inline="true"
      label-width="80px"
    >
      <el-form-item label="用户名" prop="username">
        <el-input
          v-model="queryParams.username"
          placeholder="请输入申请用户名（模糊）"
          clearable
          @keyup.enter="handleQuery"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="申请状态" prop="status">
        <el-select
          v-model="queryParams.status"
          placeholder="请选择申请状态"
          clearable
          class="!w-200px"
        >
          <el-option
            v-for="(label, value) in RegisterApplyStatusLabels"
            :key="value"
            :label="label"
            :value="Number(value)"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="申请时间" prop="createTime">
        <el-date-picker
          v-model="queryParams.createTime"
          value-format="YYYY-MM-DD HH:mm:ss"
          type="daterange"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          :default-time="[new Date('1 00:00:00'), new Date('1 23:59:59')]"
          class="!w-240px"
        />
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" /> 搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" /> 重置</el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <!-- 申请列表 -->
  <ContentWrap>
    <el-table v-loading="loading" :data="list" :stripe="true" :show-overflow-tooltip="true">
      <el-table-column label="申请编号" align="center" prop="id" width="90px" />
      <el-table-column label="用户名" align="center" prop="username" />
      <el-table-column label="姓名" align="center" prop="nickname" />
      <el-table-column label="身份类别" align="center" width="100px">
        <template #default="{ row }">{{ identityLabel(row.identityType) }}</template>
      </el-table-column>
      <el-table-column label="研究方向" align="center" width="180px" show-overflow-tooltip>
        <template #default="{ row }">{{ directionLabel(row.researchDirection) }}</template>
      </el-table-column>
      <el-table-column label="手机号" align="center" prop="mobile" width="130px" />
      <el-table-column label="申请状态" align="center" prop="status" width="100px">
        <template #default="scope">
          <el-tag :type="statusTagType(scope.row.status)">
            {{ RegisterApplyStatusLabels[scope.row.status] ?? scope.row.status }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="重提次数" align="center" prop="resubmitCount" width="90px" />
      <el-table-column
        label="申请时间"
        align="center"
        prop="createTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column
        label="审批时间"
        align="center"
        prop="auditTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="审批意见" align="center" prop="auditRemark" />
      <el-table-column label="操作" align="center" width="220px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openDetail(scope.row.id)">详情</el-button>
          <el-button
            link
            type="success"
            @click="openApprove(scope.row)"
            v-hasPermi="['lab:register-apply:audit']"
            v-if="scope.row.status === RegisterApplyStatusEnum.PENDING"
          >
            通过
          </el-button>
          <el-button
            link
            type="danger"
            @click="openReject(scope.row)"
            v-hasPermi="['lab:register-apply:audit']"
            v-if="scope.row.status === RegisterApplyStatusEnum.PENDING"
          >
            驳回
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <!-- 分页 -->
    <Pagination
      :total="total"
      v-model:page="queryParams.pageNo"
      v-model:limit="queryParams.pageSize"
      @pagination="getList"
    />
  </ContentWrap>

  <!-- ==================== 申请详情 Dialog ==================== -->
  <Dialog title="申请详情" v-model="detailVisible" width="800px">
    <div v-loading="detailLoading">
      <el-descriptions :column="2" border>
        <el-descriptions-item label="申请编号">{{ detailData.id }}</el-descriptions-item>
        <el-descriptions-item label="用户名">{{ detailData.username }}</el-descriptions-item>
        <el-descriptions-item label="姓名">{{ detailData.nickname || '-' }}</el-descriptions-item>
        <el-descriptions-item label="身份类别">{{
          identityLabel(detailData.identityType)
        }}</el-descriptions-item>
        <el-descriptions-item label="研究方向">{{
          directionLabel(detailData.researchDirection)
        }}</el-descriptions-item>
        <el-descriptions-item label="导师">{{ detailData.supervisor || '-' }}</el-descriptions-item>
        <el-descriptions-item label="指导教师">{{
          detailData.instructor || '-'
        }}</el-descriptions-item>
        <el-descriptions-item label="开始年月">{{
          detailData.startYmd || '-'
        }}</el-descriptions-item>
        <el-descriptions-item label="结束年月">{{
          detailData.endYmd || '-'
        }}</el-descriptions-item>
        <el-descriptions-item label="手机号">{{ detailData.mobile || '-' }}</el-descriptions-item>
        <el-descriptions-item label="邮箱">{{ detailData.email || '-' }}</el-descriptions-item>
        <el-descriptions-item label="申请状态">
          <el-tag :type="statusTagType(detailData.status)">
            {{ RegisterApplyStatusLabels[detailData.status ?? -1] ?? detailData.status }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="重提次数">{{
          detailData.resubmitCount ?? 0
        }}</el-descriptions-item>
        <el-descriptions-item label="关联正式用户ID">{{
          detailData.userId || '-'
        }}</el-descriptions-item>
        <el-descriptions-item label="申请时间">{{
          formatDate(detailData.createTime)
        }}</el-descriptions-item>
        <el-descriptions-item label="审批时间">{{
          formatDate(detailData.auditTime)
        }}</el-descriptions-item>
        <el-descriptions-item label="审批人ID">{{
          detailData.auditUser || '-'
        }}</el-descriptions-item>
        <el-descriptions-item label="审批意见">{{
          detailData.auditRemark || '-'
        }}</el-descriptions-item>
        <el-descriptions-item label="申请理由" :span="2">{{
          detailData.applyReason || '-'
        }}</el-descriptions-item>
      </el-descriptions>

      <!-- 审批历史时间线 -->
      <el-divider content-position="left">审批历史</el-divider>
      <el-table :data="historyList" :stripe="true" size="small" v-loading="historyLoading">
        <el-table-column label="动作" align="center" prop="action" width="110px">
          <template #default="scope">
            {{ RegisterApplyHistoryActionLabels[scope.row.action] ?? scope.row.action }}
          </template>
        </el-table-column>
        <el-table-column label="操作人ID" align="center" prop="operatorId" width="100px">
          <template #default="scope">{{ scope.row.operatorId ?? '申请人（匿名）' }}</template>
        </el-table-column>
        <el-table-column label="备注" align="center" prop="remark" :show-overflow-tooltip="true" />
        <el-table-column
          label="操作时间"
          align="center"
          prop="createTime"
          :formatter="dateFormatter"
          width="180px"
        />
      </el-table>
    </div>
    <template #footer>
      <el-button @click="detailVisible = false">关 闭</el-button>
    </template>
  </Dialog>

  <!-- ==================== 审批通过 Dialog ==================== -->
  <Dialog title="审批通过" v-model="approveVisible" width="500px">
    <el-form ref="approveFormRef" :model="approveForm" :rules="approveFormRules" label-width="90px">
      <el-form-item label="用户名">
        <span>{{ approveForm.username }}</span>
      </el-form-item>
      <el-form-item label="审批意见" prop="auditRemark">
        <el-input
          v-model="approveForm.auditRemark"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          placeholder="审批通过意见（可选）"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="approveVisible = false">取 消</el-button>
      <el-button type="primary" @click="submitApprove" :disabled="approveSubmitLoading"
        >确 定</el-button
      >
    </template>
  </Dialog>

  <!-- ==================== 审批驳回 Dialog ==================== -->
  <Dialog title="审批驳回" v-model="rejectVisible" width="500px">
    <el-form ref="rejectFormRef" :model="rejectForm" :rules="rejectFormRules" label-width="90px">
      <el-form-item label="用户名">
        <span>{{ rejectForm.username }}</span>
      </el-form-item>
      <el-form-item label="驳回意见" prop="auditRemark">
        <el-input
          v-model="rejectForm.auditRemark"
          type="textarea"
          :rows="4"
          maxlength="500"
          show-word-limit
          placeholder="请输入驳回意见（必填，申请人可见并据此修改后重提）"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="rejectVisible = false">取 消</el-button>
      <el-button type="danger" @click="submitReject" :disabled="rejectSubmitLoading"
        >确 定</el-button
      >
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { ElMessageBox } from 'element-plus'
import { dateFormatter, formatDate } from '@/utils/formatTime'
import {
  RegisterApplyApi,
  RegisterApplyVO,
  RegisterApplyHistoryVO,
  RegisterApplyStatusEnum,
  RegisterApplyStatusLabels,
  RegisterApplyHistoryActionLabels,
  RegisterApplyIdentityTypeLabels,
  RegisterApplyResearchDirectionLabels
} from '@/api/lab/register-apply'

/** 注册申请与审批（管理端） */
defineOptions({ name: 'LabRegisterApply' })

const message = useMessage() // 消息弹窗

/** 身份类别 / 研究方向展示文案（与后端枚举值一致） */
const identityLabel = (value?: number) =>
  value !== undefined ? (RegisterApplyIdentityTypeLabels[value] ?? String(value)) : '-'
const directionLabel = (value?: number) =>
  value !== undefined ? (RegisterApplyResearchDirectionLabels[value] ?? String(value)) : '-'

// ========== 申请列表 ==========
const loading = ref(true) // 列表的加载中
const list = ref<RegisterApplyVO[]>([]) // 列表的数据
const total = ref(0) // 列表的总页数
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  username: undefined as string | undefined,
  status: RegisterApplyStatusEnum.PENDING as number | undefined, // 默认展示待审批
  createTime: []
})
const queryFormRef = ref() // 搜索的表单

/** 状态标签颜色 */
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

/** 查询列表 */
const getList = async () => {
  loading.value = true
  try {
    const data = await RegisterApplyApi.getApplyPage(queryParams)
    list.value = data.list
    total.value = data.total
  } finally {
    loading.value = false
  }
}

/** 搜索按钮操作 */
const handleQuery = () => {
  queryParams.pageNo = 1
  getList()
}

/** 重置按钮操作 */
const resetQuery = () => {
  queryFormRef.value.resetFields()
  // 重置后仍保持默认展示待审批
  queryParams.status = RegisterApplyStatusEnum.PENDING
  handleQuery()
}

// ========== 申请详情 ==========
const detailVisible = ref(false)
const detailLoading = ref(false)
const detailData = ref<RegisterApplyVO>({} as RegisterApplyVO)
const historyList = ref<RegisterApplyHistoryVO[]>([])
const historyLoading = ref(false)

const openDetail = async (id: number) => {
  detailVisible.value = true
  detailLoading.value = true
  try {
    detailData.value = await RegisterApplyApi.getApply(id)
    await getHistoryList(id)
  } finally {
    detailLoading.value = false
  }
}

const getHistoryList = async (applyId: number) => {
  historyLoading.value = true
  try {
    historyList.value = await RegisterApplyApi.getApplyHistoryList(applyId)
  } finally {
    historyLoading.value = false
  }
}

// ========== 审批通过 ==========
const approveVisible = ref(false)
const approveSubmitLoading = ref(false)
const approveFormRef = ref()
const approveForm = ref({
  id: undefined as number | undefined,
  username: '',
  auditRemark: undefined as string | undefined
})
const approveFormRules = reactive({
  auditRemark: [{ max: 500, message: '审批意见长度不能超过 500 个字符', trigger: 'blur' }]
})

const openApprove = (row: RegisterApplyVO) => {
  approveVisible.value = true
  approveForm.value = {
    id: row.id,
    username: row.username || '',
    auditRemark: undefined
  }
}

const submitApprove = async () => {
  const valid = await approveFormRef.value?.validate().catch(() => false)
  if (!valid) return
  // 二次确认：通过后将创建正式用户
  await ElMessageBox.confirm(
    `确认通过用户「${approveForm.value.username}」的注册申请？通过后将创建正式用户并转移用户名占用。`,
    '审批通过确认',
    { confirmButtonText: '确认通过', cancelButtonText: '取消', type: 'warning' }
  )
  approveSubmitLoading.value = true
  try {
    await RegisterApplyApi.approveApply({
      id: approveForm.value.id!,
      auditRemark: approveForm.value.auditRemark
    })
    message.success('审批通过成功')
    approveVisible.value = false
    await getList()
  } finally {
    approveSubmitLoading.value = false
  }
}

// ========== 审批驳回 ==========
const rejectVisible = ref(false)
const rejectSubmitLoading = ref(false)
const rejectFormRef = ref()
const rejectForm = ref({
  id: undefined as number | undefined,
  username: '',
  auditRemark: undefined as string | undefined
})
const rejectFormRules = reactive({
  auditRemark: [
    { required: true, message: '驳回意见不能为空', trigger: 'blur' },
    { max: 500, message: '驳回意见长度不能超过 500 个字符', trigger: 'blur' }
  ]
})

const openReject = (row: RegisterApplyVO) => {
  rejectVisible.value = true
  rejectForm.value = {
    id: row.id,
    username: row.username || '',
    auditRemark: undefined
  }
}

const submitReject = async () => {
  const valid = await rejectFormRef.value?.validate().catch(() => false)
  if (!valid) return
  rejectSubmitLoading.value = true
  try {
    await RegisterApplyApi.rejectApply({
      id: rejectForm.value.id!,
      auditRemark: rejectForm.value.auditRemark
    })
    message.success('审批驳回成功')
    rejectVisible.value = false
    await getList()
  } finally {
    rejectSubmitLoading.value = false
  }
}

/** 初始化 **/
onMounted(() => {
  getList()
})
</script>
