<template>
  <ContentWrap>
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="80px">
      <el-form-item label="授权范围" prop="scope">
        <el-select v-model="queryParams.scope" placeholder="请选择" clearable class="!w-160px" @change="onScopeChange">
          <el-option label="设备负责人" value="DEVICE" />
          <el-option label="平台负责人" value="PLATFORM" />
          <el-option label="实验室维修负责人" value="ROOM_REPAIR" />
        </el-select>
      </el-form-item>
      <el-form-item label="目标" prop="targetId">
        <el-select
          v-model="queryParams.targetId"
          placeholder="请先选择范围"
          clearable
          filterable
          class="!w-200px"
        >
          <el-option v-for="t in targetOptions" :key="t.id" :label="t.name" :value="t.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="负责人类型" prop="managerType">
        <el-select v-model="queryParams.managerType" placeholder="请选择" clearable class="!w-140px">
          <el-option label="主负责人" value="PRIMARY" />
          <el-option label="维修负责人" value="REPAIR" />
          <el-option label="备用负责人" value="BACKUP" />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择" clearable class="!w-120px">
          <el-option label="生效中" value="ACTIVE" />
          <el-option label="已解除" value="RELEASED" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
        <el-button type="primary" plain @click="openAssignDialog" v-hasPermi="['lab:instrument:manager:manage']">
          <Icon icon="ep:plus" class="mr-5px" />分配负责人
        </el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <ContentWrap>
    <el-table v-loading="loading" :data="list" stripe>
      <el-table-column label="范围" align="center" width="140px">
        <template #default="scope">{{ scopeText(scope.row.scope) }}</template>
      </el-table-column>
      <el-table-column label="目标" align="center" prop="targetName" min-width="150px" show-overflow-tooltip />
      <el-table-column label="类型" align="center" width="100px">
        <template #default="scope">{{ managerTypeText(scope.row.managerType) }}</template>
      </el-table-column>
      <el-table-column label="负责人" align="center" width="100px">
        <template #default="scope">
          {{ scope.row.nickname || scope.row.managerName }}
          <span v-if="!scope.row.nickname && scope.row.managerName" class="text-[var(--el-color-danger)]">（用户失效）</span>
        </template>
      </el-table-column>
      <el-table-column label="联系方式" align="center" prop="mobile" width="130px" />
      <el-table-column label="状态" align="center" width="90px">
        <template #default="scope">
          <el-tag :type="scope.row.status === 'ACTIVE' ? 'success' : 'info'">
            {{ scope.row.status === 'ACTIVE' ? '生效中' : '已解除' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="生效时间" align="center" prop="effectiveFrom" :formatter="dateFormatter" width="170px" />
      <el-table-column label="失效时间" align="center" prop="effectiveTo" :formatter="dateFormatter" width="170px" />
      <el-table-column label="操作" align="center" width="170px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openHistory(scope.row)">历史</el-button>
          <el-button
            link
            type="danger"
            :disabled="scope.row.status !== 'ACTIVE'"
            @click="openReleaseDialog(scope.row)"
            v-hasPermi="['lab:instrument:manager:manage']"
          >
            解除
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </ContentWrap>

  <!-- 分配负责人 -->
  <Dialog title="分配/调整仪器负责人" v-model="assignVisible" width="560px">
    <el-form ref="assignFormRef" :model="assignForm" :rules="assignRules" label-width="100px">
      <el-form-item label="授权范围" prop="scope">
        <el-select v-model="assignForm.scope" placeholder="请选择" class="!w-full" @change="onAssignScopeChange">
          <el-option label="设备负责人" value="DEVICE" />
          <el-option label="平台负责人" value="PLATFORM" />
          <el-option label="实验室维修负责人" value="ROOM_REPAIR" />
        </el-select>
      </el-form-item>
      <el-form-item label="授权目标" prop="targetId">
        <el-select v-model="assignForm.targetId" placeholder="请选择目标" filterable class="!w-full">
          <el-option v-for="t in assignTargetOptions" :key="t.id" :label="t.name" :value="t.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="负责人类型" prop="managerType">
        <el-radio-group v-model="assignForm.managerType">
          <el-radio value="PRIMARY">主负责人</el-radio>
          <el-radio value="REPAIR">维修负责人</el-radio>
          <el-radio value="BACKUP">备用负责人</el-radio>
        </el-radio-group>
      </el-form-item>
      <el-form-item label="负责人" prop="managerUserId">
        <el-select
          v-model="assignForm.managerUserId"
          filterable
          remote
          reserve-keyword
          clearable
          placeholder="输入姓名搜索当前租户启用用户"
          :remote-method="searchCandidates"
          :loading="candidateLoading"
          class="!w-full"
          @visible-change="onCandidateVisible"
        >
          <el-option
            v-for="u in candidates"
            :key="u.id"
            :label="u.nickname + '（' + u.username + '）'"
            :value="u.id"
          >
            {{ u.nickname }}（{{ u.username }}<span v-if="u.mobile">，{{ u.mobile }}</span>）
          </el-option>
        </el-select>
      </el-form-item>
      <el-alert
        v-if="assignForm.scope === 'ROOM_REPAIR'"
        type="warning"
        :closable="false"
        title="实验室维修负责人允许同时存在多名生效人员；设备/平台同类型负责人再次分配将自动解除原负责人并保留历史。"
        class="mb-10px"
      />
      <el-form-item label="变更原因" prop="assignReason">
        <el-input v-model="assignForm.assignReason" type="textarea" :rows="2" placeholder="请输入分配/调整原因（可选）" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="assignVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitAssign">确 定</el-button>
    </template>
  </Dialog>

  <!-- 解除负责人 -->
  <Dialog title="解除仪器负责人" v-model="releaseVisible" width="480px">
    <el-form label-width="90px">
      <el-form-item label="负责人">
        <span>{{ releaseRecord?.nickname || releaseRecord?.managerName }}（{{ scopeText(releaseRecord?.scope) }} / {{ releaseRecord?.targetName }}）</span>
      </el-form-item>
      <el-form-item label="解除原因" required>
        <el-input v-model="releaseReason" type="textarea" :rows="3" placeholder="解除必须填写原因，将记录到变更历史" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="releaseVisible = false">取 消</el-button>
      <el-button type="danger" :loading="submitLoading" @click="submitRelease">确认解除</el-button>
    </template>
  </Dialog>

  <!-- 变更历史 -->
  <el-drawer v-model="historyVisible" title="负责人变更历史" size="520px">
    <el-descriptions :column="1" border class="mb-15px">
      <el-descriptions-item label="目标">{{ historyTargetName }}</el-descriptions-item>
    </el-descriptions>
    <el-timeline>
      <el-timeline-item
        v-for="h in historyList"
        :key="h.id"
        :type="h.status === 'ACTIVE' ? 'success' : 'info'"
        :timestamp="(h.status === 'ACTIVE' ? h.effectiveFrom : h.effectiveTo) || ''"
      >
        {{ h.nickname || h.managerName }}（{{ managerTypeText(h.managerType) }}）-
        {{ h.status === 'ACTIVE' ? '生效中' : '已解除' }}
        <div v-if="h.assignReason" class="text-12px text-[var(--el-text-color-secondary)]">分配原因：{{ h.assignReason }}</div>
        <div v-if="h.releaseReason" class="text-12px text-[var(--el-text-color-secondary)]">解除原因：{{ h.releaseReason }}</div>
      </el-timeline-item>
    </el-timeline>
  </el-drawer>
</template>

<script setup lang="ts">
import { dateFormatter } from '@/utils/formatTime'
import { InstrumentManagerApi, InstrumentManagerVO, ManagerCandidate } from '@/api/lab/instrument/manager'
import { InstrumentDeviceApi } from '@/api/lab/instrument/device'
import { InstrumentPlatformApi } from '@/api/lab/instrument/platform'
import { InstrumentRoomApi } from '@/api/lab/instrument/room'

defineOptions({ name: 'LabInstrumentManager' })

const message = useMessage()
const loading = ref(true)
const list = ref<InstrumentManagerVO[]>([])
const total = ref(0)
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  scope: undefined as string | undefined,
  targetId: undefined as number | undefined,
  managerType: undefined as string | undefined,
  status: undefined as string | undefined
})
const queryFormRef = ref()

const scopeText = (s?: string) =>
  ({ DEVICE: '设备负责人', PLATFORM: '平台负责人', ROOM_REPAIR: '实验室维修负责人' } as Record<string, string>)[
    s || ''
  ] || s || ''
const managerTypeText = (t?: string) =>
  ({ PRIMARY: '主负责人', REPAIR: '维修负责人', BACKUP: '备用负责人' } as Record<string, string>)[t || ''] || t || ''

// 目标下拉（按 scope 加载）
const targetOptions = ref<{ id: number; name: string }[]>([])
const loadTargets = async (scope?: string) => {
  if (!scope) {
    targetOptions.value = []
    return
  }
  if (scope === 'DEVICE') targetOptions.value = (await InstrumentDeviceApi.getPage({ pageNo: 1, pageSize: 200 })).list
  else if (scope === 'PLATFORM') targetOptions.value = (await InstrumentPlatformApi.getList()) || []
  else targetOptions.value = (await InstrumentRoomApi.getList()) || []
}
const onScopeChange = (scope: string) => {
  queryParams.targetId = undefined
  loadTargets(scope)
}

const getList = async () => {
  loading.value = true
  try {
    const data = await InstrumentManagerApi.getPage(queryParams)
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
  targetOptions.value = []
  handleQuery()
}

// 分配
const assignVisible = ref(false)
const submitLoading = ref(false)
const assignFormRef = ref()
const assignForm = reactive({
  scope: 'DEVICE',
  targetId: undefined as number | undefined,
  managerType: 'PRIMARY',
  managerUserId: undefined as number | undefined,
  assignReason: ''
})
const assignRules = {
  scope: [{ required: true, message: '请选择授权范围', trigger: 'change' }],
  targetId: [{ required: true, message: '请选择授权目标', trigger: 'change' }],
  managerType: [{ required: true, message: '请选择负责人类型', trigger: 'change' }],
  managerUserId: [{ required: true, message: '请选择负责人', trigger: 'change' }]
}
const assignTargetOptions = ref<{ id: number; name: string }[]>([])
const candidates = ref<ManagerCandidate[]>([])
const candidateLoading = ref(false)

const openAssignDialog = async () => {
  assignForm.scope = 'DEVICE'
  assignForm.targetId = undefined
  assignForm.managerType = 'PRIMARY'
  assignForm.managerUserId = undefined
  assignForm.assignReason = ''
  assignTargetOptions.value = (await InstrumentDeviceApi.getPage({ pageNo: 1, pageSize: 200 })).list
  await searchCandidates('')
  assignVisible.value = true
}
const onAssignScopeChange = async (scope: string) => {
  assignForm.targetId = undefined
  await loadAssignTargets(scope)
}
const loadAssignTargets = async (scope: string) => {
  if (scope === 'DEVICE') assignTargetOptions.value = (await InstrumentDeviceApi.getPage({ pageNo: 1, pageSize: 200 })).list
  else if (scope === 'PLATFORM') assignTargetOptions.value = (await InstrumentPlatformApi.getList()) || []
  else assignTargetOptions.value = (await InstrumentRoomApi.getList()) || []
}
const searchCandidates = async (keyword: string) => {
  candidateLoading.value = true
  try {
    candidates.value = (await InstrumentManagerApi.candidates(keyword)) || []
  } finally {
    candidateLoading.value = false
  }
}
const onCandidateVisible = (visible: boolean) => {
  if (visible && candidates.value.length === 0) searchCandidates('')
}
const submitAssign = async () => {
  await assignFormRef.value.validate()
  submitLoading.value = true
  try {
    await InstrumentManagerApi.assign({
      scope: assignForm.scope,
      targetId: assignForm.targetId!,
      managerType: assignForm.managerType,
      managerUserId: assignForm.managerUserId!,
      assignReason: assignForm.assignReason
    })
    message.success('分配成功')
    assignVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

// 解除
const releaseVisible = ref(false)
const releaseRecord = ref<InstrumentManagerVO | null>(null)
const releaseReason = ref('')
const openReleaseDialog = (row: InstrumentManagerVO) => {
  releaseRecord.value = row
  releaseReason.value = ''
  releaseVisible.value = true
}
const submitRelease = async () => {
  if (!releaseReason.value.trim()) {
    message.warning('解除原因不能为空')
    return
  }
  submitLoading.value = true
  try {
    await InstrumentManagerApi.release(releaseRecord.value!.id!, releaseReason.value.trim())
    message.success('已解除')
    releaseVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

// 历史
const historyVisible = ref(false)
const historyList = ref<InstrumentManagerVO[]>([])
const historyTargetName = ref('')
const openHistory = async (row: InstrumentManagerVO) => {
  historyTargetName.value = `${scopeText(row.scope)} / ${row.targetName || row.targetId}`
  historyList.value = (await InstrumentManagerApi.history(row.scope, row.targetId)) || []
  historyVisible.value = true
}

onMounted(() => {
  getList()
})
</script>
