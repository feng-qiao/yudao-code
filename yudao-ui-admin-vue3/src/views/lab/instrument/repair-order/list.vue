<template>
  <ContentWrap v-if="canManageRepairs">
    <div class="mb-12px flex flex-wrap gap-8px">
      <el-button v-if="canAdminFaults" @click="goTo('/lab/instrument/fault-report/admin-list')">故障上报管理</el-button>
      <el-button v-if="canHandleRepairs" @click="goTo('/lab/instrument/repair-order/my-assigned')">我的维修工单</el-button>
      <el-button v-if="canSubmitFault" type="danger" plain @click="goTo('/lab/instrument/fault-report/submit')">上报故障</el-button>
      <el-button v-if="canAdminRepairs" @click="goTo('/lab/instrument/reservation-impact/list')">预约影响处理</el-button>
    </div>
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="80px">
      <el-form-item label="工单状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择" clearable class="!w-140px">
          <el-option
            v-for="s in statusOptions"
            :key="s.value"
            :label="s.label"
            :value="s.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="设备" prop="deviceId">
        <el-select v-model="queryParams.deviceId" placeholder="请选择" clearable filterable class="!w-180px">
          <el-option v-for="d in deviceOptions" :key="d.id" :label="d.name" :value="d.id!" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <ContentWrap v-if="canManageRepairs">
    <el-table v-loading="loading" :data="list" stripe>
      <el-table-column label="工单号" align="center" prop="orderNo" width="170px" />
      <el-table-column label="来源故障 ID" align="center" prop="sourceFaultId" width="130px" />
      <el-table-column label="设备 ID" align="center" prop="deviceId" width="110px" />
      <el-table-column label="状态" align="center" width="100px">
        <template #default="scope">
          <el-tag :type="statusMeta(scope.row.status).type">
            {{ statusMeta(scope.row.status).label }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="负责人" align="center" prop="assigneeName" width="110px">
        <template #default="scope">
          <span v-if="scope.row.assigneeName">{{ scope.row.assigneeName }}</span>
          <span v-else class="text-[var(--el-text-color-secondary)]">未指派</span>
        </template>
      </el-table-column>
      <el-table-column label="实际完成" align="center" prop="finishTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="创建时间" align="center" prop="createTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="操作" align="center" width="240px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="goDetail(scope.row)">详情</el-button>
          <el-button
            v-if="!scope.row.assigneeUserId"
            link
            type="warning"
            @click="openAssignDialog(scope.row)"
          >
            指派
          </el-button>
          <el-button
            v-if="scope.row.status === 'REPAIRED'"
            link
            type="success"
            @click="openRestoreApproveDialog(scope.row)"
          >
            验收
          </el-button>
          <el-button
            v-if="['ASSIGNED', 'IN_PROGRESS'].includes(scope.row.status || '')"
            link
            type="danger"
            @click="openRejectDialog(scope.row)"
          >
            关闭
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </ContentWrap>

  <ContentWrap v-if="!canManageRepairs">
    <el-result icon="info" title="仪器维修工作台" sub-title="请按当前授权选择可用入口。">
      <template #extra>
        <div class="flex flex-wrap justify-center gap-10px">
          <el-button v-if="canSubmitFault" type="danger" @click="goTo('/lab/instrument/fault-report/submit')">上报故障</el-button>
          <el-button v-if="canSubmitFault" @click="goTo('/lab/instrument/fault-report/my-list')">我的故障上报</el-button>
          <el-button v-if="canHandleRepairs" type="primary" @click="goTo('/lab/instrument/repair-order/my-assigned')">我的维修工单</el-button>
          <el-button v-if="canAdminFaults" @click="goTo('/lab/instrument/fault-report/admin-list')">故障上报管理</el-button>
          <el-button v-if="canAdminRepairs" @click="goTo('/lab/instrument/reservation-impact/list')">预约影响处理</el-button>
        </div>
      </template>
    </el-result>
  </ContentWrap>

  <!-- 指派负责人（弹窗组件） -->
  <AssignDialog
    v-model:visible="assignVisible"
    :order-row="assignRow"
    @success="handleAssignSuccess"
  />

  <!-- 恢复验收通过/退回（弹窗组件） -->
  <RestoreApproveDialog
    v-model:visible="restoreVisible"
    :order-row="restoreRow"
    @success="handleRestoreSuccess"
  />

  <!-- 关闭工单对话框 -->
  <Dialog title="关闭维修工单" v-model="rejectVisible" width="480px">
    <el-form label-width="90px">
      <el-form-item label="工单号">{{ rejectRow?.orderNo }}</el-form-item>
      <el-form-item label="关闭原因" required>
        <el-input
          v-model="rejectReason"
          type="textarea"
          :rows="3"
          maxlength="300"
          show-word-limit
          placeholder="请填写关闭原因"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="rejectVisible = false">取 消</el-button>
      <el-button type="danger" :loading="submitLoading" @click="submitReject">确认关闭</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { checkPermi } from '@/utils/permission'
import { dateFormatter } from '@/utils/formatTime'
import { InstrumentDeviceApi, InstrumentDeviceVO } from '@/api/lab/instrument/device'
import { InstrumentRepairOrderApi, RepairOrderVO } from '@/api/lab/instrument/repair-order'
import AssignDialog from './assign.vue'
import RestoreApproveDialog from './restore-approve.vue'

defineOptions({ name: 'LabInstrumentRepairOrderList' })

const router = useRouter()
const canManageRepairs = computed(() => checkPermi(['lab:instrument:repair-order:admin']))
const canHandleRepairs = computed(() => checkPermi(['lab:instrument:repair-order:handle']))
const canSubmitFault = computed(() => checkPermi(['lab:instrument:fault-report:submit']))
const canAdminFaults = computed(() => checkPermi(['lab:instrument:fault-report:admin']))
const canAdminRepairs = canManageRepairs
const message = useMessage()
const loading = ref(true)
const submitLoading = ref(false)
const list = ref<RepairOrderVO[]>([])
const total = ref(0)
const queryFormRef = ref()

const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  status: undefined as string | undefined,
  deviceId: undefined as number | undefined,
  assigneeUserId: undefined as number | undefined
})

const deviceOptions = ref<InstrumentDeviceVO[]>([])
const loadDevices = async () => {
  deviceOptions.value = (await InstrumentDeviceApi.getPage({ pageNo: 1, pageSize: 200 })).list || []
}

const statusOptions = [
  { value: 'ASSIGNED', label: '已指派' },
  { value: 'IN_PROGRESS', label: '维修中' },
  { value: 'REPAIRED', label: '待验收' },
  { value: 'RESTORED', label: '已验收' },
  { value: 'REJECTED', label: '已关闭' },
  { value: 'CANCELED', label: '已取消' },
  { value: 'REOPENED', label: '已重开' }
]

const statusMeta = (s?: string) =>
  (
    {
      ASSIGNED: { label: '已指派', type: 'warning' },
      IN_PROGRESS: { label: '维修中', type: 'primary' },
      REPAIRED: { label: '待验收', type: 'primary' },
      RESTORED: { label: '已验收', type: 'success' },
      REJECTED: { label: '已关闭', type: 'danger' },
      CANCELED: { label: '已取消', type: 'info' },
      REOPENED: { label: '已重开', type: 'warning' }
    } as Record<string, any>
  )[s || ''] || { label: s || '-', type: 'info' }

const getList = async () => {
  loading.value = true
  try {
    const data = await InstrumentRepairOrderApi.getPage(queryParams)
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

const goDetail = (row: RepairOrderVO) => {
  router.push({ path: '/lab/instrument/repair-order/detail', query: { id: row.id } })
}

const goTo = (path: string) => router.push(path)

// 指派
const assignVisible = ref(false)
const assignRow = ref<RepairOrderVO | null>(null)
const openAssignDialog = (row: RepairOrderVO) => {
  assignRow.value = row
  assignVisible.value = true
}
const handleAssignSuccess = () => {
  getList()
}

// 恢复验收
const restoreVisible = ref(false)
const restoreRow = ref<RepairOrderVO | null>(null)
const openRestoreApproveDialog = (row: RepairOrderVO) => {
  restoreRow.value = row
  restoreVisible.value = true
}
const handleRestoreSuccess = () => {
  getList()
}

// 关闭
const rejectVisible = ref(false)
const rejectRow = ref<RepairOrderVO | null>(null)
const rejectReason = ref('')
const openRejectDialog = (row: RepairOrderVO) => {
  rejectRow.value = row
  rejectReason.value = ''
  rejectVisible.value = true
}
const submitReject = async () => {
  if (!rejectReason.value.trim()) {
    message.warning('关闭原因不能为空')
    return
  }
  submitLoading.value = true
  try {
    await InstrumentRepairOrderApi.cancel(rejectRow.value!.id!, rejectReason.value.trim())
    message.success('工单已关闭')
    rejectVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

onMounted(async () => {
  if (canManageRepairs.value) {
    await loadDevices()
    getList()
  }
})
</script>
