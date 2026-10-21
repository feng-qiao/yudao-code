<template>
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
      <el-table-column label="上报时间" align="center" prop="createTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="操作" align="center" width="180px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openDetail(scope.row)">详情</el-button>
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
      <el-descriptions-item label="状态">
        <el-tag :type="statusMeta(detailRow.status).type">{{ statusMeta(detailRow.status).label }}</el-tag>
      </el-descriptions-item>
      <el-descriptions-item v-if="detailRow.rejectReason" label="驳回原因">
        {{ detailRow.rejectReason }}
      </el-descriptions-item>
      <el-descriptions-item v-if="detailRow.confirmName" label="确认人">
        {{ detailRow.confirmName }}（{{ detailRow.confirmTime }}）
      </el-descriptions-item>
    </el-descriptions>
  </el-drawer>

</template>

<script setup lang="ts">
import { dateFormatter } from '@/utils/formatTime'
import { InstrumentFaultReportApi, FaultReportVO } from '@/api/lab/instrument/fault-report'

defineOptions({ name: 'LabInstrumentFaultReportMyList' })

const loading = ref(true)
const list = ref<FaultReportVO[]>([])
const total = ref(0)
const queryParams = reactive({ pageNo: 1, pageSize: 10 })

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
    const data = await InstrumentFaultReportApi.getMyPage(queryParams)
    list.value = data.list
    total.value = data.total
  } finally {
    loading.value = false
  }
}
// 详情
const detailVisible = ref(false)
const detailRow = ref<FaultReportVO | null>(null)
const openDetail = async (row: FaultReportVO) => {
  detailRow.value = await InstrumentFaultReportApi.get(row.id!)
  detailVisible.value = true
}

onMounted(() => {
  getList()
})
</script>
