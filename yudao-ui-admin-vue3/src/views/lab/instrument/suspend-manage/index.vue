<template>
  <ContentWrap>
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="70px">
      <el-form-item label="用户ID" prop="userId">
        <el-input v-model="queryParams.userId" placeholder="请输入用户ID" clearable class="!w-140px" />
      </el-form-item>
      <el-form-item label="范围" prop="scopeType">
        <el-select v-model="queryParams.scopeType" placeholder="请选择" clearable class="!w-120px">
          <el-option label="单仪器" value="SINGLE" />
          <el-option label="全部仪器" value="ALL" />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择" clearable class="!w-120px">
          <el-option label="暂停中" value="ACTIVE" />
          <el-option label="已解除" value="RELEASED" />
          <el-option label="已到期" value="EXPIRED" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
        <el-button type="danger" plain @click="openCreate" v-hasPermi="['lab:instrument:suspend:manage']">
          <Icon icon="ep:circle-close" class="mr-5px" />创建暂停
        </el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <ContentWrap>
    <el-table v-loading="loading" :data="list" stripe>
      <el-table-column label="用户" align="center" prop="userName" width="100px" />
      <el-table-column label="范围" align="center" width="90px">
        <template #default="scope">{{ scope.row.scopeType === 'ALL' ? '全部仪器' : '单仪器' }}</template>
      </el-table-column>
      <el-table-column label="设备" align="center" prop="deviceName" min-width="140px" show-overflow-tooltip />
      <el-table-column label="状态" align="center" width="90px">
        <template #default="scope">
          <el-tag :type="statusMeta(scope.row.status).type">{{ statusMeta(scope.row.status).label }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="暂停原因" align="center" prop="reason" min-width="150px" show-overflow-tooltip />
      <el-table-column label="开始时间" align="center" prop="startTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="计划结束时间" align="center" prop="endTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="操作人" align="center" prop="operatorName" width="100px" />
      <el-table-column label="实际解除时间" align="center" prop="releaseTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="解除人" align="center" prop="releaseOperatorName" width="100px" />
      <el-table-column label="解除原因" align="center" prop="releaseReason" min-width="130px" show-overflow-tooltip />
      <el-table-column label="操作" align="center" width="100px" fixed="right">
        <template #default="scope">
          <el-button
            v-if="scope.row.status === 'ACTIVE'"
            link
            type="primary"
            @click="openRelease(scope.row)"
            v-hasPermi="['lab:instrument:suspend:manage']"
          >
            解除
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </ContentWrap>

  <!-- 创建暂停 -->
  <Dialog title="创建人工暂停" v-model="createVisible" width="560px">
    <el-alert
      type="warning"
      :closable="false"
      title="暂停期间该用户不能使用对应范围内的仪器（预约拦截于 INSTRUMENT-03 生效）；暂停立即生效并联动资质状态，历史记录不可删除。到达『计划结束时间』不会自动解除，须由授权管理员在本页人工『解除』。"
      class="mb-15px"
    />
    <el-form ref="createFormRef" :model="createForm" :rules="createRules" label-width="90px">
      <el-form-item label="目标用户" prop="userId">
        <el-select
          v-model="createForm.userId"
          filterable
          remote
          reserve-keyword
          clearable
          placeholder="输入姓名搜索当前租户启用用户"
          :remote-method="searchCandidates"
          :loading="candidateLoading"
          class="!w-full"
        >
          <el-option v-for="u in candidates" :key="u.id" :label="u.nickname + '（' + u.username + '）'" :value="u.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="暂停范围" prop="scopeType">
        <el-radio-group v-model="createForm.scopeType" @change="onScopeChange">
          <el-radio value="SINGLE">单仪器</el-radio>
          <el-radio value="ALL">全部仪器</el-radio>
        </el-radio-group>
      </el-form-item>
      <el-form-item v-if="createForm.scopeType === 'SINGLE'" label="设备" prop="deviceId">
        <el-select v-model="createForm.deviceId" placeholder="请选择设备" filterable class="!w-full">
          <el-option v-for="d in deviceOptions" :key="d.id" :label="d.name" :value="d.id!" />
        </el-select>
      </el-form-item>
      <el-form-item label="暂停时长" prop="presetDays">
        <el-radio-group v-model="durationMode">
          <el-radio v-for="d in [1, 3, 7, 14, 30]" :key="d" :value="String(d)">{{ d }} 天</el-radio>
          <el-radio value="custom">自定义计划结束</el-radio>
        </el-radio-group>
      </el-form-item>
      <el-form-item v-if="durationMode === 'custom'" label="计划结束时间" prop="endTime">
        <el-date-picker
          v-model="createForm.endTime"
          type="datetime"
          value-format="YYYY-MM-DD HH:mm:ss"
          placeholder="必须晚于当前时间（到期不自动解除）"
          class="!w-full"
        />
      </el-form-item>
      <el-form-item label="暂停原因" prop="reason">
        <el-input
          v-model="createForm.reason"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          placeholder="必填，将记录到暂停历史"
        />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="createForm.remark" type="textarea" :rows="2" maxlength="500" placeholder="选填" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="createVisible = false">取 消</el-button>
      <el-button type="danger" :loading="createLoading" @click="submitCreate">确认暂停</el-button>
    </template>
  </Dialog>

  <!-- 解除暂停 -->
  <Dialog title="提前解除暂停" v-model="releaseVisible" width="480px">
    <el-descriptions :column="1" border class="mb-15px">
      <el-descriptions-item label="用户">{{ releaseRow?.userName }}</el-descriptions-item>
      <el-descriptions-item label="范围">
        {{ releaseRow?.scopeType === 'ALL' ? '全部仪器' : releaseRow?.deviceName }}
      </el-descriptions-item>
      <el-descriptions-item label="计划结束时间">{{ releaseRow?.endTime }}</el-descriptions-item>
    </el-descriptions>
    <el-form ref="releaseFormRef" :model="releaseForm" :rules="releaseRules" label-width="90px">
      <el-form-item label="解除原因" prop="reason">
        <el-input
          v-model="releaseForm.reason"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          placeholder="解除必须填写原因，将记录到暂停历史"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="releaseVisible = false">取 消</el-button>
      <el-button type="primary" :loading="releaseLoading" @click="submitRelease">确认解除</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { dateFormatter } from '@/utils/formatTime'
import { InstrumentDeviceApi, InstrumentDeviceVO } from '@/api/lab/instrument/device'
import { InstrumentSuspendApi, InstrumentSuspendVO } from '@/api/lab/instrument/suspend'
import { InstrumentManagerApi, ManagerCandidate } from '@/api/lab/instrument/manager'

defineOptions({ name: 'LabInstrumentSuspendManage' })

const message = useMessage()
const loading = ref(true)
const list = ref<InstrumentSuspendVO[]>([])
const total = ref(0)
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  userId: undefined as string | undefined,
  scopeType: undefined as string | undefined,
  status: undefined as string | undefined
})
const queryFormRef = ref()

const statusMeta = (status?: string) =>
  (
    {
      ACTIVE: { label: '暂停中', type: 'danger' },
      RELEASED: { label: '已解除', type: 'info' },
      EXPIRED: { label: '已到期', type: 'info' }
    } as Record<string, any>
  )[status || ''] || { label: status || '-', type: 'info' }

const getList = async () => {
  loading.value = true
  try {
    const params: any = {
      pageNo: queryParams.pageNo,
      pageSize: queryParams.pageSize,
      scopeType: queryParams.scopeType,
      status: queryParams.status
    }
    if (queryParams.userId) params.userId = Number(queryParams.userId)
    const data = await InstrumentSuspendApi.getPage(params)
    list.value = data.list
    total.value = data.total
  } finally {
    loading.value = false
  }
}
const handleQuery = () => {
  queryParams.pageNo = 1
  getList()
}
const resetQuery = () => {
  queryFormRef.value.resetFields()
  handleQuery()
}

// ========== 创建暂停 ==========
const createVisible = ref(false)
const createLoading = ref(false)
const createForm = reactive({
  userId: undefined as number | undefined,
  scopeType: 'SINGLE',
  deviceId: undefined as number | undefined,
  endTime: undefined as string | undefined,
  reason: '',
  remark: ''
})
const durationMode = ref('3')
const createRules = {
  userId: [{ required: true, message: '请选择目标用户', trigger: 'change' }],
  scopeType: [{ required: true, message: '请选择暂停范围', trigger: 'change' }],
  deviceId: [{ required: true, message: '单仪器暂停必须选择设备', trigger: 'change' }],
  endTime: [{ required: true, message: '请选择计划结束时间', trigger: 'change' }],
  reason: [{ required: true, message: '暂停原因不能为空', trigger: 'blur' }]
}
const createFormRef = ref()

const candidates = ref<ManagerCandidate[]>([])
const candidateLoading = ref(false)
const searchCandidates = async (keyword?: string) => {
  candidateLoading.value = true
  try {
    candidates.value = (await InstrumentManagerApi.candidates(keyword)) || []
  } finally {
    candidateLoading.value = false
  }
}

const deviceOptions = ref<InstrumentDeviceVO[]>([])
const loadDevices = async () => {
  deviceOptions.value = (await InstrumentDeviceApi.getPage({ pageNo: 1, pageSize: 200 })).list || []
}

const openCreate = () => {
  createForm.userId = undefined
  createForm.scopeType = 'SINGLE'
  createForm.deviceId = undefined
  createForm.endTime = undefined
  createForm.reason = ''
  createForm.remark = ''
  durationMode.value = '3'
  searchCandidates()
  createVisible.value = true
}
const onScopeChange = () => {
  createForm.deviceId = undefined
}
const submitCreate = async () => {
  await createFormRef.value?.validate()
  createLoading.value = true
  try {
    await InstrumentSuspendApi.create({
      userId: createForm.userId!,
      scopeType: createForm.scopeType,
      deviceId: createForm.scopeType === 'SINGLE' ? createForm.deviceId : undefined,
      presetDays: durationMode.value !== 'custom' ? Number(durationMode.value) : undefined,
      endTime: durationMode.value === 'custom' ? createForm.endTime : undefined,
      reason: createForm.reason,
      remark: createForm.remark || undefined
    })
    message.success('暂停已创建并立即生效')
    createVisible.value = false
    await getList()
  } finally {
    createLoading.value = false
  }
}

// ========== 解除暂停 ==========
const releaseVisible = ref(false)
const releaseLoading = ref(false)
const releaseRow = ref<InstrumentSuspendVO>()
const releaseForm = reactive({ reason: '' })
const releaseRules = {
  reason: [{ required: true, message: '解除原因不能为空', trigger: 'blur' }]
}
const releaseFormRef = ref()

const openRelease = (row: InstrumentSuspendVO) => {
  releaseRow.value = row
  releaseForm.reason = ''
  releaseVisible.value = true
}
const submitRelease = async () => {
  await releaseFormRef.value?.validate()
  releaseLoading.value = true
  try {
    await InstrumentSuspendApi.release({ id: releaseRow.value!.id!, reason: releaseForm.reason })
    message.success('暂停已解除，符合条件的资质将自动恢复')
    releaseVisible.value = false
    await getList()
  } finally {
    releaseLoading.value = false
  }
}

onMounted(async () => {
  loadDevices()
  getList()
})
</script>
