<template>
  <ContentWrap>
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="80px">
      <el-form-item label="设备" prop="deviceId">
        <el-select v-model="queryParams.deviceId" placeholder="请选择" clearable filterable class="!w-180px">
          <el-option v-for="d in deviceOptions" :key="d.id" :label="d.name" :value="d.id!" />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择" clearable class="!w-140px">
          <el-option
            v-for="s in statusOptions"
            :key="s.value"
            :label="s.label"
            :value="s.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="严重程度" prop="severity">
        <el-select v-model="queryParams.severity" placeholder="请选择" clearable class="!w-140px">
          <el-option label="轻微" value="LOW" />
          <el-option label="一般" value="MEDIUM" />
          <el-option label="严重" value="HIGH" />
          <el-option label="紧急" value="CRITICAL" />
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
      <el-table-column label="上报编号" align="center" width="110px"><template #default="scope">#{{ scope.row.id }}</template></el-table-column>
      <el-table-column label="设备 ID" align="center" prop="deviceId" width="110px" />
      <el-table-column label="故障时间" align="center" prop="faultTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="严重程度" align="center" width="100px">
        <template #default="scope">
          <el-tag :type="severityMeta(scope.row.severity).type">
            {{ severityMeta(scope.row.severity).label }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" width="100px">
        <template #default="scope">
          <el-tag :type="statusMeta(scope.row.status).type">
            {{ statusMeta(scope.row.status).label }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="上报人" align="center" prop="reporterName" width="110px" />
      <el-table-column label="上报时间" align="center" prop="createTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="维修工单" align="center" width="160px">
        <template #default="scope">
          <el-link
            v-if="scope.row.repairOrderId"
            type="primary"
            :underline="false"
            @click="goRepairOrder(scope.row)"
          >
            #{{ scope.row.repairOrderId }}
          </el-link>
          <span v-else class="text-[var(--el-text-color-secondary)]">—</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="260px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openDetail(scope.row)">详情</el-button>
          <el-button
            v-if="scope.row.status === 'SUBMITTED'"
            link
            type="success"
            @click="openConfirmDialog(scope.row)"
          >
            确认
          </el-button>
          <el-button
            v-if="scope.row.status === 'SUBMITTED'"
            link
            type="danger"
            @click="openRejectDialog(scope.row)"
          >
            驳回
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </ContentWrap>

  <!-- 详情抽屉 -->
  <el-drawer v-model="detailVisible" title="故障上报详情" size="600px">
    <el-descriptions v-if="detailRow" :column="1" border>
      <el-descriptions-item label="上报编号">#{{ detailRow.id }}</el-descriptions-item>
      <el-descriptions-item label="设备 ID">{{ detailRow.deviceId }}</el-descriptions-item>
      <el-descriptions-item label="故障时间">{{ detailRow.faultTime }}</el-descriptions-item>
      <el-descriptions-item label="严重程度">
        <el-tag :type="severityMeta(detailRow.severity).type">{{ severityMeta(detailRow.severity).label }}</el-tag>
      </el-descriptions-item>
      <el-descriptions-item label="故障现象">{{ detailRow.phenomenon }}</el-descriptions-item>
      <el-descriptions-item label="详细描述">{{ detailRow.description || '—' }}</el-descriptions-item>
      <el-descriptions-item label="上报人">{{ detailRow.reporterName }}</el-descriptions-item>
      <el-descriptions-item label="联系电话">{{ detailRow.contactPhone || '—' }}</el-descriptions-item>
      <el-descriptions-item label="状态">
        <el-tag :type="statusMeta(detailRow.status).type">{{ statusMeta(detailRow.status).label }}</el-tag>
      </el-descriptions-item>
      <el-descriptions-item v-if="detailRow.rejectReason" label="驳回原因">
        {{ detailRow.rejectReason }}
      </el-descriptions-item>
      <el-descriptions-item v-if="detailRow.repairOrderId" label="关联工单 ID">
        <el-link type="primary" @click="goRepairOrder(detailRow)">#{{ detailRow.repairOrderId }}</el-link>
      </el-descriptions-item>
    </el-descriptions>
    <el-alert v-if="detailRow?.repairOrderId" type="success" :closable="false" title="已由管理员确认并自动创建维修工单。" />
  </el-drawer>

  <!-- 确认对话框 -->
  <Dialog title="确认故障上报" v-model="confirmVisible" width="480px">
    <el-form label-width="90px">
      <el-form-item label="上报编号">#{{ confirmRow?.id }}</el-form-item>
      <el-form-item label="设备 ID">{{ confirmRow?.deviceId }}</el-form-item>
      <el-form-item label="备注">
        <el-input v-model="confirmRemark" type="textarea" :rows="2" placeholder="选填" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="confirmVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitConfirm">确认</el-button>
    </template>
  </Dialog>

  <!-- 驳回对话框 -->
  <Dialog title="驳回故障上报" v-model="rejectVisible" width="480px">
    <el-form label-width="90px">
      <el-form-item label="上报编号">#{{ rejectRow?.id }}</el-form-item>
      <el-form-item label="驳回原因" required>
        <el-input v-model="rejectReason" type="textarea" :rows="3" maxlength="300" show-word-limit placeholder="请填写驳回原因" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="rejectVisible = false">取 消</el-button>
      <el-button type="danger" :loading="submitLoading" @click="submitReject">确认驳回</el-button>
    </template>
  </Dialog>

</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { dateFormatter } from '@/utils/formatTime'
import { InstrumentDeviceApi, InstrumentDeviceVO } from '@/api/lab/instrument/device'
import { InstrumentFaultReportApi, FaultReportVO } from '@/api/lab/instrument/fault-report'

defineOptions({ name: 'LabInstrumentFaultReportAdminList' })

const router = useRouter()
const message = useMessage()
const loading = ref(true)
const submitLoading = ref(false)
const list = ref<FaultReportVO[]>([])
const total = ref(0)
const queryFormRef = ref()

const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  deviceId: undefined as number | undefined,
  status: undefined as string | undefined,
  severity: undefined as string | undefined
})

const deviceOptions = ref<InstrumentDeviceVO[]>([])
const loadDevices = async () => {
  deviceOptions.value = (await InstrumentDeviceApi.getPage({ pageNo: 1, pageSize: 200 })).list || []
}

const statusOptions = [
  { value: 'SUBMITTED', label: '待确认' },
  { value: 'CONFIRMED', label: '已确认' },
  { value: 'REJECTED', label: '已驳回' },
]

const statusMeta = (s?: string) =>
  (
    {
      SUBMITTED: { label: '待确认', type: 'warning' },
      CONFIRMED: { label: '已确认', type: 'info' },
      REJECTED: { label: '已驳回', type: 'danger' },
    } as Record<string, any>
  )[s || ''] || { label: s || '-', type: 'info' }

const severityMeta = (s?: string) =>
  (
    {
      LOW: { label: '轻微', type: 'info' },
      MEDIUM: { label: '一般', type: 'warning' },
      HIGH: { label: '严重', type: 'danger' },
      CRITICAL: { label: '紧急', type: 'danger' }
    } as Record<string, any>
  )[s || ''] || { label: s || '-', type: 'info' }

const getList = async () => {
  loading.value = true
  try {
    const data = await InstrumentFaultReportApi.getPage(queryParams)
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

// 详情
const detailVisible = ref(false)
const detailRow = ref<FaultReportVO | null>(null)
const openDetail = async (row: FaultReportVO) => {
  detailRow.value = await InstrumentFaultReportApi.get(row.id!)
  detailVisible.value = true
}

// 确认
const confirmVisible = ref(false)
const confirmRow = ref<FaultReportVO | null>(null)
const confirmRemark = ref('')
const openConfirmDialog = (row: FaultReportVO) => {
  confirmRow.value = row
  confirmRemark.value = ''
  confirmVisible.value = true
}
const submitConfirm = async () => {
  submitLoading.value = true
  try {
    await InstrumentFaultReportApi.confirm(confirmRow.value!.id!, confirmRemark.value || undefined)
    message.success('已确认')
    confirmVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

// 驳回
const rejectVisible = ref(false)
const rejectRow = ref<FaultReportVO | null>(null)
const rejectReason = ref('')
const openRejectDialog = (row: FaultReportVO) => {
  rejectRow.value = row
  rejectReason.value = ''
  rejectVisible.value = true
}
const submitReject = async () => {
  if (!rejectReason.value.trim()) {
    message.warning('驳回原因不能为空')
    return
  }
  submitLoading.value = true
  try {
    await InstrumentFaultReportApi.reject(rejectRow.value!.id!, rejectReason.value.trim())
    message.success('已驳回')
    rejectVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

const goRepairOrder = (row: FaultReportVO) => {
  router.push({ path: '/lab/instrument/repair-order/detail', query: { id: row.repairOrderId } })
}

onMounted(async () => {
  await loadDevices()
  getList()
})
</script>
