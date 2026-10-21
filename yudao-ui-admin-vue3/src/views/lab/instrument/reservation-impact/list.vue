<template>
  <ContentWrap>
    <el-alert
      type="info"
      :closable="false"
      show-icon
      title="本页展示受设备状态影响的预约。管理员可记录人工处理说明；本接口不会自动取消或改期预约。"
      class="mb-15px"
    />
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="90px">
      <el-form-item label="处理状态" prop="handleStatus">
        <el-select v-model="queryParams.handleStatus" placeholder="请选择" clearable class="!w-140px">
          <el-option
            v-for="s in handleStatusOptions"
            :key="s.value"
            :label="s.label"
            :value="s.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <ContentWrap>
    <el-table v-loading="loading" :data="list" stripe>
      <el-table-column label="设备 ID" align="center" prop="deviceId" width="110px" />
      <el-table-column label="预约 ID" align="center" prop="reservationId" width="110px" />
      <el-table-column label="故障报告 ID" align="center" prop="faultReportId" width="130px" />
      <el-table-column label="维修工单 ID" align="center" prop="repairOrderId" width="130px" />
      <el-table-column label="影响原因" align="center" prop="impactReason" min-width="220px" show-overflow-tooltip />
      <el-table-column label="处理状态" align="center" width="100px">
        <template #default="scope">
          <el-tag :type="handleStatusMeta(scope.row.handleStatus).type">
            {{ handleStatusMeta(scope.row.handleStatus).label }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="处理时间" align="center" prop="handleTime" width="170px" />
      <el-table-column label="操作" align="center" width="140px" fixed="right">
        <template #default="scope">
          <el-button
            v-if="scope.row.handleStatus === 'PENDING' || scope.row.handleStatus === 'AUTO_RESTORED'"
            link
            type="primary"
            @click="openHandleDialog(scope.row)"
          >
            人工处理
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </ContentWrap>

  <!-- 人工处理对话框 -->
  <Dialog title="记录人工处理结果" v-model="handleVisible" width="520px">
    <el-form label-width="100px">
      <el-form-item label="设备 ID">{{ handleRow?.deviceId }}</el-form-item>
      <el-form-item label="预约 ID">{{ handleRow?.reservationId }}</el-form-item>
      <el-form-item label="影响原因">{{ handleRow?.impactReason }}</el-form-item>
      <el-form-item label="处理说明" required>
        <el-input
          v-model="handleRemark"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          placeholder="记录管理员实际采取的人工处理措施"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="handleVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitHandle">确认处理</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { InstrumentReservationImpactApi, ReservationImpactVO } from '@/api/lab/instrument/reservation-impact'

defineOptions({ name: 'LabInstrumentReservationImpact' })

const message = useMessage()
const loading = ref(true)
const submitLoading = ref(false)
const list = ref<ReservationImpactVO[]>([])
const total = ref(0)
const queryFormRef = ref()

const queryParams = reactive({ pageNo: 1, pageSize: 10, handleStatus: undefined as string | undefined })

const handleStatusOptions = [
  { value: 'PENDING', label: '待处理' },
  { value: 'AUTO_RESTORED', label: '设备已恢复，待人工处理' },
  { value: 'PROCESSED', label: '已人工处理' }
]

const handleStatusMeta = (s?: string) =>
  (
    {
      PENDING: { label: '待处理', type: 'warning' },
      AUTO_RESTORED: { label: '设备已恢复，待处理', type: 'info' },
      PROCESSED: { label: '已人工处理', type: 'success' }
    } as Record<string, any>
  )[s || ''] || { label: s || '-', type: 'info' }

const getList = async () => {
  loading.value = true
  try {
    const data = await InstrumentReservationImpactApi.getPage(queryParams)
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

// 人工处理
const handleVisible = ref(false)
const handleRow = ref<ReservationImpactVO | null>(null)
const handleRemark = ref('')
const openHandleDialog = (row: ReservationImpactVO) => {
  handleRow.value = row
  handleRemark.value = ''
  handleVisible.value = true
}
const submitHandle = async () => {
  submitLoading.value = true
  try {
    if (!handleRemark.value.trim()) {
      message.warning('处理说明不能为空')
      return
    }
    await InstrumentReservationImpactApi.handle(handleRow.value!.id!, handleRemark.value.trim())
    message.success('已处理')
    handleVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

onMounted(() => {
  getList()
})
</script>
