<template>
  <ContentWrap>
    <el-row :gutter="20" v-loading="accountLoading">
      <el-col :xs="24" :md="8">
        <el-card shadow="never">
          <div class="text-13px text-[var(--el-text-color-secondary)]">当前信用分</div>
          <div class="mt-8px">
            <span class="text-32px font-bold" :class="scoreClass">{{ credit?.initialized ? credit.score : '—' }}</span>
            <el-tag v-if="credit?.initialized" type="success" size="small" class="ml-10px">已激活</el-tag>
            <el-tag v-else type="info" size="small" class="ml-10px">未激活</el-tag>
          </div>
          <div class="text-12px text-[var(--el-text-color-secondary)] mt-8px">
            {{
              credit?.initialized
                ? `激活时间：${credit.initializedTime || '-'}`
                : '首次通过任意仪器资质审核后自动激活（初始 100 分）'
            }}
          </div>
        </el-card>
      </el-col>
      <el-col :xs="24" :md="16">
        <el-alert type="info" :closable="false" title="信用说明" class="h-full">
          <div class="text-12px leading-20px">
            信用分由授权管理员人工登记变动，每笔变动均记录不可变流水；允许超过 100 分、允许负分。
            信用分状态不自动限制仪器使用，人工暂停安排请见下方暂停记录。
          </div>
        </el-alert>
      </el-col>
    </el-row>
  </ContentWrap>

  <ContentWrap>
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="70px">
      <el-form-item label="变动类型" prop="changeType">
        <el-select v-model="queryParams.changeType" placeholder="请选择" clearable class="!w-120px">
          <el-option label="加分" value="ADD" />
          <el-option label="扣分" value="DEDUCT" />
        </el-select>
      </el-form-item>
      <el-form-item label="原因类型" prop="reasonType">
        <el-select v-model="queryParams.reasonType" placeholder="请选择" clearable class="!w-140px">
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
          v-model="queryParams.operateTimeRange"
          type="daterange"
          value-format="YYYY-MM-DD HH:mm:ss"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          class="!w-240px"
        />
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <ContentWrap>
    <div class="section-title mb-10px">积分流水（不可变记录）</div>
    <el-table v-loading="loading" :data="flowList" stripe>
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
      <el-table-column label="变动原因" align="center" prop="reason" min-width="160px" show-overflow-tooltip />
      <el-table-column label="操作人" align="center" prop="operatorName" width="100px" />
      <el-table-column label="操作时间" align="center" prop="operateTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="备注" align="center" prop="remark" min-width="120px" show-overflow-tooltip />
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getFlowList" />
  </ContentWrap>

  <ContentWrap>
    <div class="section-title mb-10px">我的暂停记录</div>
    <div class="text-12px text-[var(--el-text-color-secondary)] mb-10px">
      暂停须由授权管理员人工解除；到达『计划结束时间』不会自动解除。
    </div>
    <el-table v-loading="suspendLoading" :data="suspendList" stripe>
      <el-table-column label="范围" align="center" width="90px">
        <template #default="scope">{{ scope.row.scopeType === 'ALL' ? '全部仪器' : '单仪器' }}</template>
      </el-table-column>
      <el-table-column label="设备" align="center" prop="deviceName" min-width="140px" show-overflow-tooltip />
      <el-table-column label="状态" align="center" width="90px">
        <template #default="scope">
          <el-tag :type="suspendStatusMeta(scope.row.status).type">
            {{ suspendStatusMeta(scope.row.status).label }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="暂停原因" align="center" prop="reason" min-width="150px" show-overflow-tooltip />
      <el-table-column label="开始时间" align="center" prop="startTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="计划结束时间" align="center" prop="endTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="实际解除时间" align="center" prop="releaseTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="解除原因" align="center" prop="releaseReason" min-width="130px" show-overflow-tooltip />
    </el-table>
    <el-empty v-if="!suspendLoading && !suspendList.length" description="无暂停记录" :image-size="60" />
  </ContentWrap>
</template>

<script setup lang="ts">
import { dateFormatter } from '@/utils/formatTime'
import { DICT_TYPE, getDictOptions } from '@/utils/dict'
import { InstrumentCreditApi, InstrumentCreditVO, InstrumentCreditFlowVO } from '@/api/lab/instrument/credit'
import { InstrumentSuspendApi, InstrumentSuspendVO } from '@/api/lab/instrument/suspend'

defineOptions({ name: 'LabInstrumentMyCredit' })

const loading = ref(true)
const flowList = ref<InstrumentCreditFlowVO[]>([])
const total = ref(0)
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  changeType: undefined as string | undefined,
  reasonType: undefined as string | undefined,
  operateTimeRange: undefined as [string, string] | undefined
})
const queryFormRef = ref()

const accountLoading = ref(true)
const credit = ref<InstrumentCreditVO>()
const suspendLoading = ref(true)
const suspendList = ref<InstrumentSuspendVO[]>([])

const scoreClass = computed(() => {
  const score = credit.value?.score
  if (score == null) return 'text-[var(--el-text-color-secondary)]'
  if (score < 80) return 'text-[var(--el-color-danger)]'
  if (score < 100) return 'text-[var(--el-color-warning)]'
  return 'text-[var(--el-color-success)]'
})

const suspendStatusMeta = (status?: string) =>
  (
    {
      ACTIVE: { label: '暂停中', type: 'danger' },
      RELEASED: { label: '已解除', type: 'info' },
      EXPIRED: { label: '已到期', type: 'info' }
    } as Record<string, any>
  )[status || ''] || { label: status || '-', type: 'info' }

const getFlowList = async () => {
  loading.value = true
  try {
    const params: any = {
      pageNo: queryParams.pageNo,
      pageSize: queryParams.pageSize,
      changeType: queryParams.changeType,
      reasonType: queryParams.reasonType
    }
    if (queryParams.operateTimeRange && queryParams.operateTimeRange.length === 2) {
      params.operateTimeBegin = queryParams.operateTimeRange[0]
      params.operateTimeEnd = queryParams.operateTimeRange[1]
    }
    const data = await InstrumentCreditApi.getMyFlowPage(params)
    flowList.value = data.list
    total.value = data.total
  } finally {
    loading.value = false
  }
}
const handleQuery = () => {
  queryParams.pageNo = 1
  getFlowList()
}
const resetQuery = () => {
  queryFormRef.value.resetFields()
  queryParams.operateTimeRange = undefined
  handleQuery()
}

const getAccount = async () => {
  accountLoading.value = true
  try {
    credit.value = await InstrumentCreditApi.getMyCredit()
  } finally {
    accountLoading.value = false
  }
}
const getSuspends = async () => {
  suspendLoading.value = true
  try {
    suspendList.value = (await InstrumentSuspendApi.getMySuspends()) || []
  } finally {
    suspendLoading.value = false
  }
}

onMounted(() => {
  getAccount()
  getFlowList()
  getSuspends()
})
</script>

<style scoped>
.section-title {
  font-weight: bold;
  font-size: 15px;
  margin-bottom: 12px;
}
</style>
