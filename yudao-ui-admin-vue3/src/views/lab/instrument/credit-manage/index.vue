<template>
  <ContentWrap>
    <el-tabs v-model="activeTab" @tab-change="onTabChange">
      <el-tab-pane label="信用账户" name="account" />
      <el-tab-pane label="积分流水" name="flow" />
    </el-tabs>

    <!-- 账户管理 -->
    <template v-if="activeTab === 'account'">
      <el-form class="-mb-15px" :model="accountQuery" ref="accountQueryFormRef" :inline="true" label-width="80px">
        <el-form-item label="用户ID" prop="userId">
          <el-input v-model="accountQuery.userId" placeholder="请输入用户ID" clearable class="!w-160px" />
        </el-form-item>
        <el-form-item label="激活状态" prop="initialized">
          <el-select v-model="accountQuery.initialized" placeholder="请选择" clearable class="!w-140px">
            <el-option label="已激活" :value="true" />
            <el-option label="未激活" :value="false" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button @click="handleAccountQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
          <el-button @click="resetAccountQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
          <el-button
            type="primary"
            plain
            @click="openAdjust()"
            v-hasPermi="['lab:instrument:credit:adjust']"
          >
            <Icon icon="ep:edit" class="mr-5px" />人工加扣分
          </el-button>
        </el-form-item>
      </el-form>
      <div class="mt-15px">
        <el-table v-loading="accountLoading" :data="accountList" stripe>
          <el-table-column label="用户ID" align="center" prop="userId" width="90px" />
          <el-table-column label="用户" align="center" prop="userName" width="120px" />
          <el-table-column label="当前信用分" align="center" width="120px">
            <template #default="scope">
              <span :class="scoreTextClass(scope.row.score)" class="font-bold">
                {{ scope.row.initialized ? scope.row.score : '—' }}
              </span>
            </template>
          </el-table-column>
          <el-table-column label="激活状态" align="center" width="100px">
            <template #default="scope">
              <el-tag :type="scope.row.initialized ? 'success' : 'info'">
                {{ scope.row.initialized ? '已激活' : '未激活' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="激活时间" align="center" prop="initializedTime" width="170px" :formatter="dateFormatter" />
          <el-table-column label="最近变动" align="center" prop="lastChangeTime" width="170px" :formatter="dateFormatter" />
          <el-table-column label="操作" align="center" width="110px" fixed="right">
            <template #default="scope">
              <el-button
                link
                type="primary"
                :disabled="!scope.row.initialized"
                @click="openAdjust(scope.row)"
                v-hasPermi="['lab:instrument:credit:adjust']"
              >
                加扣分
              </el-button>
            </template>
          </el-table-column>
        </el-table>
        <Pagination
          :total="accountTotal"
          v-model:page="accountQuery.pageNo"
          v-model:limit="accountQuery.pageSize"
          @pagination="getAccountList"
        />
      </div>
    </template>

    <!-- 积分流水 -->
    <template v-else>
      <el-form class="-mb-15px" :model="flowQuery" ref="flowQueryFormRef" :inline="true" label-width="80px">
        <el-form-item label="用户ID" prop="userId">
          <el-input v-model="flowQuery.userId" placeholder="请输入用户ID" clearable class="!w-140px" />
        </el-form-item>
        <el-form-item label="变动类型" prop="changeType">
          <el-select v-model="flowQuery.changeType" placeholder="请选择" clearable class="!w-120px">
            <el-option label="加分" value="ADD" />
            <el-option label="扣分" value="DEDUCT" />
          </el-select>
        </el-form-item>
        <el-form-item label="原因类型" prop="reasonType">
          <el-select v-model="flowQuery.reasonType" placeholder="请选择" clearable class="!w-140px">
            <el-option
              v-for="d in getDictOptions(DICT_TYPE.LAB_INSTRUMENT_CREDIT_REASON)"
              :key="d.value"
              :label="d.label"
              :value="d.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="操作时间" prop="operateTimeRange">
          <el-date-picker
            v-model="flowQuery.operateTimeRange"
            type="daterange"
            value-format="YYYY-MM-DD HH:mm:ss"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            class="!w-240px"
          />
        </el-form-item>
        <el-form-item>
          <el-button @click="handleFlowQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
          <el-button @click="resetFlowQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
          <el-button
            type="success"
            plain
            @click="handleExport"
            :loading="exportLoading"
            v-hasPermi="['lab:instrument:credit:export']"
          >
            <Icon icon="ep:download" class="mr-5px" />导出
          </el-button>
        </el-form-item>
      </el-form>
      <div class="mt-15px">
        <el-table v-loading="flowLoading" :data="flowList" stripe>
          <el-table-column label="用户" align="center" prop="userName" width="100px" />
          <el-table-column label="变动" align="center" width="90px">
            <template #default="scope">
              <el-tag :type="scope.row.changeType === 'ADD' ? 'success' : 'danger'">
                {{ scope.row.changeType === 'ADD' ? '+' : '' }}{{ scope.row.scoreChange }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="变动前/后" align="center" width="110px">
            <template #default="scope">{{ scope.row.scoreBefore }} → {{ scope.row.scoreAfter }}</template>
          </el-table-column>
          <el-table-column label="原因类型" align="center" width="110px">
            <template #default="scope">
              <dict-tag :type="DICT_TYPE.LAB_INSTRUMENT_CREDIT_REASON" :value="scope.row.reasonType" />
            </template>
          </el-table-column>
          <el-table-column label="变动原因" align="center" prop="reason" min-width="150px" show-overflow-tooltip />
          <el-table-column label="操作人" align="center" prop="operatorName" width="100px" />
          <el-table-column label="操作时间" align="center" prop="operateTime" width="170px" :formatter="dateFormatter" />
          <el-table-column label="备注" align="center" prop="remark" min-width="110px" show-overflow-tooltip />
        </el-table>
        <Pagination
          :total="flowTotal"
          v-model:page="flowQuery.pageNo"
          v-model:limit="flowQuery.pageSize"
          @pagination="getFlowList"
        />
      </div>
    </template>
  </ContentWrap>

  <!-- 人工加扣分 -->
  <Dialog :title="adjustForm.userId ? `人工加扣分 - ${adjustForm.userName || ''}` : '人工加扣分'" v-model="adjustVisible" width="520px">
    <el-alert
      type="warning"
      :closable="false"
      title="变动值正数为加分、负数为扣分；不设上下限。每笔变动都会写入不可变流水，请谨慎操作。"
      class="mb-15px"
    />
    <el-form ref="adjustFormRef" :model="adjustForm" :rules="adjustRules" label-width="90px">
      <el-form-item label="目标用户" prop="userId">
        <el-select
          v-model="adjustForm.userId"
          filterable
          remote
          reserve-keyword
          clearable
          :disabled="!!adjustLocked"
          placeholder="输入姓名搜索当前租户启用用户"
          :remote-method="searchCandidates"
          :loading="candidateLoading"
          class="!w-full"
        >
          <el-option v-for="u in candidates" :key="u.id" :label="u.nickname + '（' + u.username + '）'" :value="u.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="变动值" prop="delta">
        <el-input-number v-model="adjustForm.delta" class="!w-full" placeholder="正数加分、负数扣分，不能为 0" />
      </el-form-item>
      <el-form-item label="原因类型" prop="reasonType">
        <el-select v-model="adjustForm.reasonType" placeholder="请选择" class="!w-full">
          <el-option
            v-for="d in getDictOptions(DICT_TYPE.LAB_INSTRUMENT_CREDIT_REASON)"
            :key="d.value"
            :label="d.label"
            :value="d.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="变动原因" prop="reason">
        <el-input
          v-model="adjustForm.reason"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          placeholder="必填，将记录到积分流水作为审计依据"
        />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="adjustForm.remark" type="textarea" :rows="2" maxlength="500" placeholder="选填" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="adjustVisible = false">取 消</el-button>
      <el-button type="primary" :loading="adjustLoading" @click="submitAdjust">确认登记</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { dateFormatter } from '@/utils/formatTime'
import { DICT_TYPE, getDictOptions } from '@/utils/dict'
import download from '@/utils/download'
import { InstrumentCreditApi, InstrumentCreditVO, InstrumentCreditFlowVO } from '@/api/lab/instrument/credit'
import { InstrumentManagerApi, ManagerCandidate } from '@/api/lab/instrument/manager'

defineOptions({ name: 'LabInstrumentCreditManage' })

const message = useMessage()
const activeTab = ref('account')

// ========== 账户管理 ==========
const accountLoading = ref(true)
const accountList = ref<InstrumentCreditVO[]>([])
const accountTotal = ref(0)
const accountQuery = reactive({
  pageNo: 1,
  pageSize: 10,
  userId: undefined as string | undefined,
  initialized: undefined as boolean | undefined
})
const accountQueryFormRef = ref()

const scoreTextClass = (score?: number | null) => {
  if (score == null) return 'text-[var(--el-text-color-secondary)]'
  if (score < 80) return 'text-[var(--el-color-danger)]'
  if (score < 100) return 'text-[var(--el-color-warning)]'
  return 'text-[var(--el-color-success)]'
}

const getAccountList = async () => {
  accountLoading.value = true
  try {
    const params: any = { ...accountQuery }
    if (params.userId) params.userId = Number(params.userId)
    const data = await InstrumentCreditApi.getPage(params)
    accountList.value = data.list
    accountTotal.value = data.total
  } finally {
    accountLoading.value = false
  }
}
const handleAccountQuery = () => {
  accountQuery.pageNo = 1
  getAccountList()
}
const resetAccountQuery = () => {
  accountQueryFormRef.value.resetFields()
  handleAccountQuery()
}

// 加扣分
const adjustVisible = ref(false)
const adjustLoading = ref(false)
const adjustLocked = ref(false)
const adjustForm = reactive({
  userId: undefined as number | undefined,
  userName: '',
  delta: undefined as number | undefined,
  reasonType: 'MANUAL',
  reason: '',
  remark: ''
})
const adjustRules = {
  userId: [{ required: true, message: '请选择目标用户', trigger: 'change' }],
  delta: [
    { required: true, message: '请输入变动值', trigger: 'blur' },
    {
      validator: (_rule: any, value: any, callback: any) => {
        if (value === 0) callback(new Error('变动值不能为 0'))
        else callback()
      },
      trigger: 'blur'
    }
  ],
  reasonType: [{ required: true, message: '请选择原因类型', trigger: 'change' }],
  reason: [{ required: true, message: '变动原因不能为空', trigger: 'blur' }]
}
const adjustFormRef = ref()

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

const openAdjust = (row?: InstrumentCreditVO) => {
  adjustLocked.value = !!row
  adjustForm.userId = row?.userId
  adjustForm.userName = row?.userName || ''
  adjustForm.delta = undefined
  adjustForm.reasonType = 'MANUAL'
  adjustForm.reason = ''
  adjustForm.remark = ''
  if (!row) {
    adjustForm.userId = undefined
    searchCandidates()
  }
  adjustVisible.value = true
}
const submitAdjust = async () => {
  await adjustFormRef.value?.validate()
  if (!adjustForm.delta) {
    message.error('变动值不能为空')
    return
  }
  adjustLoading.value = true
  try {
    await InstrumentCreditApi.adjust({
      userId: adjustForm.userId!,
      delta: adjustForm.delta,
      reasonType: adjustForm.reasonType,
      reason: adjustForm.reason,
      remark: adjustForm.remark || undefined
    })
    message.success('积分变动已登记')
    adjustVisible.value = false
    await getAccountList()
  } finally {
    adjustLoading.value = false
  }
}

// ========== 积分流水 ==========
const flowLoading = ref(false)
const flowList = ref<InstrumentCreditFlowVO[]>([])
const flowTotal = ref(0)
const flowQuery = reactive({
  pageNo: 1,
  pageSize: 10,
  userId: undefined as string | undefined,
  changeType: undefined as string | undefined,
  reasonType: undefined as string | undefined,
  operateTimeRange: undefined as [string, string] | undefined
})
const flowQueryFormRef = ref()

const buildFlowParams = () => {
  const params: any = {
    pageNo: flowQuery.pageNo,
    pageSize: flowQuery.pageSize,
    changeType: flowQuery.changeType,
    reasonType: flowQuery.reasonType
  }
  if (flowQuery.userId) params.userId = Number(flowQuery.userId)
  if (flowQuery.operateTimeRange && flowQuery.operateTimeRange.length === 2) {
    params.operateTimeBegin = flowQuery.operateTimeRange[0]
    params.operateTimeEnd = flowQuery.operateTimeRange[1]
  }
  return params
}
const getFlowList = async () => {
  flowLoading.value = true
  try {
    const data = await InstrumentCreditApi.getFlowPage(buildFlowParams())
    flowList.value = data.list
    flowTotal.value = data.total
  } finally {
    flowLoading.value = false
  }
}
const handleFlowQuery = () => {
  flowQuery.pageNo = 1
  getFlowList()
}
const resetFlowQuery = () => {
  flowQueryFormRef.value.resetFields()
  flowQuery.operateTimeRange = undefined
  handleFlowQuery()
}

const exportLoading = ref(false)
const handleExport = async () => {
  exportLoading.value = true
  try {
    const data = await InstrumentCreditApi.exportFlow(buildFlowParams())
    download.excel(data, '信用积分流水.xls')
  } finally {
    exportLoading.value = false
  }
}

const onTabChange = (tab: string) => {
  if (tab === 'account') getAccountList()
  else getFlowList()
}

onMounted(() => {
  getAccountList()
})
</script>
