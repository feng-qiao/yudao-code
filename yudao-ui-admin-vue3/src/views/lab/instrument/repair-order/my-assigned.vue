<template>
  <ContentWrap>
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="80px">
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
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <ContentWrap>
    <el-table v-loading="loading" :data="list" stripe>
      <el-table-column label="工单号" align="center" prop="orderNo" width="170px" />
      <el-table-column label="设备 ID" align="center" prop="deviceId" width="110px" />
      <el-table-column label="状态" align="center" width="100px">
        <template #default="scope">
          <el-tag :type="statusMeta(scope.row.status).type">
            {{ statusMeta(scope.row.status).label }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="指派时间" align="center" prop="assignTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="操作" align="center" width="260px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="goDetail(scope.row)">详情</el-button>
          <el-button
            v-if="scope.row.status === 'ASSIGNED'"
            link
            type="primary"
            @click="openStartRepairDialog(scope.row)"
          >
            开始维修
          </el-button>
          <el-button
            v-if="scope.row.status === 'IN_PROGRESS'"
            link
            type="warning"
            @click="openAddProcessDialog(scope.row)"
          >
            记录过程
          </el-button>
          <el-button
            v-if="scope.row.status === 'IN_PROGRESS'"
            link
            type="success"
            @click="openSubmitRepairedDialog(scope.row)"
          >
            提交结果
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </ContentWrap>

  <!-- 开始维修对话框 -->
  <Dialog title="开始维修" v-model="startVisible" width="460px">
    <el-form label-width="100px">
      <el-form-item label="工单号">{{ startRow?.orderNo }}</el-form-item>
      <el-form-item label="设备 ID">{{ startRow?.deviceId }}</el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="startVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitStart">确认开始</el-button>
    </template>
  </Dialog>

  <!-- 记录维修过程对话框 -->
  <Dialog title="追加维修过程记录" v-model="processVisible" width="520px">
    <el-form label-width="100px">
      <el-form-item label="工单号">{{ processRow?.orderNo }}</el-form-item>
      <el-form-item label="过程记录" required>
        <el-input
          v-model="processContent"
          type="textarea"
          :rows="4"
          maxlength="1000"
          show-word-limit
          placeholder="记录本次维修的操作、发现、配件更换等"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="processVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitProcess">保存</el-button>
    </template>
  </Dialog>

  <!-- 提交维修结果对话框 -->
  <Dialog title="提交维修结果" v-model="submitVisible" width="560px">
    <el-form ref="submitFormRef" :model="submitForm" :rules="submitRules" label-width="110px">
      <el-form-item label="工单号">{{ submitRow?.orderNo }}</el-form-item>
      <el-form-item label="维修结果" prop="detail" required>
        <el-input
          v-model="submitForm.detail"
          type="textarea"
          :rows="3"
          maxlength="800"
          show-word-limit
          placeholder="描述维修操作、更换的配件等"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="submitVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitRepaired">提交</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { dateFormatter } from '@/utils/formatTime'
import { InstrumentRepairOrderApi, RepairOrderVO } from '@/api/lab/instrument/repair-order'

defineOptions({ name: 'LabInstrumentRepairOrderMyAssigned' })

const router = useRouter()
const message = useMessage()
const loading = ref(true)
const submitLoading = ref(false)
const list = ref<RepairOrderVO[]>([])
const total = ref(0)
const queryFormRef = ref()

const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  status: undefined as string | undefined
})

const statusOptions = [
  { value: 'ASSIGNED', label: '已指派' },
  { value: 'IN_PROGRESS', label: '维修中' },
  { value: 'REPAIRED', label: '待验收' },
  { value: 'RESTORED', label: '已验收' },
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
    const data = await InstrumentRepairOrderApi.getMyAssignedPage(queryParams)
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

// 开始维修
const startVisible = ref(false)
const startRow = ref<RepairOrderVO | null>(null)
const openStartRepairDialog = (row: RepairOrderVO) => {
  startRow.value = row
  startVisible.value = true
}
const submitStart = async () => {
  submitLoading.value = true
  try {
    await InstrumentRepairOrderApi.start(startRow.value!.id!)
    message.success('已开始维修')
    startVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

// 追加过程
const processVisible = ref(false)
const processRow = ref<RepairOrderVO | null>(null)
const processContent = ref('')
const openAddProcessDialog = (row: RepairOrderVO) => {
  processRow.value = row
  processContent.value = ''
  processVisible.value = true
}
const submitProcess = async () => {
  if (!processContent.value.trim()) {
    message.warning('过程记录不能为空')
    return
  }
  submitLoading.value = true
  try {
    await InstrumentRepairOrderApi.addProcess({
      id: processRow.value!.id!,
      content: processContent.value.trim()
    })
    message.success('已保存')
    processVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

// 提交维修结果
const submitVisible = ref(false)
const submitRow = ref<RepairOrderVO | null>(null)
const submitFormRef = ref()
const submitForm = reactive({
  detail: ''
})
const submitRules = {
  detail: [{ required: true, message: '请填写维修结果', trigger: 'blur' }]
}
const openSubmitRepairedDialog = (row: RepairOrderVO) => {
  submitRow.value = row
  submitForm.detail = ''
  submitVisible.value = true
}
const submitRepaired = async () => {
  await submitFormRef.value.validate()
  submitLoading.value = true
  try {
    await InstrumentRepairOrderApi.submitRepaired({
      id: submitRow.value!.id!,
      repairResult: submitForm.detail.trim()
    })
    message.success('维修结果已提交，等待管理员验收')
    submitVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

onMounted(() => {
  getList()
})
</script>
