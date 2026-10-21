<template>
  <ContentWrap>
    <div class="section-title">我的资质</div>
    <el-table v-loading="qualLoading" :data="qualificationList" stripe>
      <el-table-column label="设备" align="center" prop="deviceName" min-width="160px" show-overflow-tooltip />
      <el-table-column label="状态" align="center" width="100px">
        <template #default="scope">
          <el-tag :type="qualStatusMeta(scope.row.status).type">{{ qualStatusMeta(scope.row.status).label }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="授予时间" align="center" prop="grantedTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="到期时间" align="center" prop="expireTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="备注" align="center" prop="remark" min-width="120px" show-overflow-tooltip />
    </el-table>
    <el-empty v-if="!qualLoading && !qualificationList.length" description="暂无使用资质，可在设备详情页申请" :image-size="70" />
  </ContentWrap>

  <ContentWrap>
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="70px">
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择" clearable class="!w-140px">
          <el-option label="待审核" value="PENDING" />
          <el-option label="已通过" value="APPROVED" />
          <el-option label="已驳回" value="REJECTED" />
          <el-option label="已撤回" value="CANCELED" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <ContentWrap>
    <div class="section-title mb-10px">我的申请记录</div>
    <el-table v-loading="loading" :data="list" stripe>
      <el-table-column label="申请单号" align="center" prop="applyNo" width="200px" />
      <el-table-column label="设备" align="center" prop="deviceName" min-width="150px" show-overflow-tooltip />
      <el-table-column label="状态" align="center" width="100px">
        <template #default="scope">
          <el-tag :type="applyStatusMeta(scope.row.status).type">{{ applyStatusMeta(scope.row.status).label }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="申请理由" align="center" prop="reason" min-width="140px" show-overflow-tooltip />
      <el-table-column label="申请时间" align="center" prop="applyTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="审核意见" align="center" prop="auditOpinion" min-width="140px" show-overflow-tooltip />
      <el-table-column label="审核时间" align="center" prop="auditTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="操作" align="center" width="150px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openHistory(scope.row)">历史</el-button>
          <el-button
            v-if="scope.row.status === 'PENDING'"
            link
            type="danger"
            @click="handleCancel(scope.row)"
            v-hasPermi="['lab:instrument:qualification:apply']"
          >
            撤回
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </ContentWrap>

  <!-- 审核历史（只读，不可变） -->
  <el-drawer v-model="historyVisible" title="申请审核历史" size="480px">
    <el-descriptions :column="1" border class="mb-15px">
      <el-descriptions-item label="申请单号">{{ historyApply?.applyNo }}</el-descriptions-item>
      <el-descriptions-item label="设备">{{ historyApply?.deviceName }}</el-descriptions-item>
      <el-descriptions-item label="当前状态">
        <el-tag :type="applyStatusMeta(historyApply?.status).type">
          {{ applyStatusMeta(historyApply?.status).label }}
        </el-tag>
      </el-descriptions-item>
    </el-descriptions>
    <el-timeline>
      <el-timeline-item v-for="h in historyList" :key="h.id" :timestamp="h.actionTime || ''">
        {{ actionText(h.action) }}
        <span v-if="h.opinion" class="text-12px text-[var(--el-text-color-secondary)]">意见：{{ h.opinion }}</span>
        <div class="text-12px text-[var(--el-text-color-secondary)]">
          {{ h.operatorName }} · {{ h.fromStatus || '—' }} → {{ h.toStatus || '—' }}
        </div>
      </el-timeline-item>
    </el-timeline>
    <el-empty v-if="!historyList.length" description="暂无历史记录" :image-size="60" />
  </el-drawer>
</template>

<script setup lang="ts">
import { dateFormatter } from '@/utils/formatTime'
import {
  InstrumentQualificationApi,
  InstrumentQualificationVO,
  QualificationApplyVO,
  QualApplyHistoryVO
} from '@/api/lab/instrument/qualification'

defineOptions({ name: 'LabInstrumentMyQualification' })

const message = useMessage()
const loading = ref(true)
const list = ref<QualificationApplyVO[]>([])
const total = ref(0)
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  status: undefined as string | undefined
})
const queryFormRef = ref()

const qualLoading = ref(true)
const qualificationList = ref<InstrumentQualificationVO[]>([])

const qualStatusMeta = (status?: string) =>
  (
    {
      ACTIVE: { label: '生效中', type: 'success' },
      EXPIRED: { label: '已到期', type: 'info' },
      SUSPENDED: { label: '已暂停', type: 'warning' },
      REVOKED: { label: '已撤销', type: 'danger' }
    } as Record<string, any>
  )[status || ''] || { label: status || '-', type: 'info' }

const applyStatusMeta = (status?: string) =>
  (
    {
      PENDING: { label: '待审核', type: 'warning' },
      APPROVED: { label: '已通过', type: 'success' },
      REJECTED: { label: '已驳回', type: 'danger' },
      CANCELED: { label: '已撤回', type: 'info' }
    } as Record<string, any>
  )[status || ''] || { label: status || '-', type: 'info' }

const actionText = (action?: string) =>
  (
    {
      SUBMIT: '提交申请',
      APPROVE: '审核通过',
      REJECT: '审核驳回',
      CANCEL: '撤回申请',
      RESUBMIT: '重新提交'
    } as Record<string, string>
  )[action || ''] || action || ''

const getQualificationList = async () => {
  qualLoading.value = true
  try {
    qualificationList.value = (await InstrumentQualificationApi.getMyQualifications()) || []
  } finally {
    qualLoading.value = false
  }
}

const getList = async () => {
  loading.value = true
  try {
    const data = await InstrumentQualificationApi.getApplyPage(queryParams)
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

const handleCancel = async (row: QualificationApplyVO) => {
  await message.confirm(`确认撤回申请单 ${row.applyNo}？撤回后不可恢复。`)
  await InstrumentQualificationApi.cancel(row.id!)
  message.success('已撤回申请')
  await getList()
}

// 审核历史
const historyVisible = ref(false)
const historyApply = ref<QualificationApplyVO>()
const historyList = ref<QualApplyHistoryVO[]>([])
const openHistory = async (row: QualificationApplyVO) => {
  historyApply.value = row
  historyList.value = (await InstrumentQualificationApi.getApplyHistory(row.id!)) || []
  historyVisible.value = true
}

onMounted(() => {
  getQualificationList()
  getList()
})
</script>

<style scoped>
.section-title {
  font-weight: bold;
  font-size: 15px;
  margin-bottom: 12px;
}
</style>
