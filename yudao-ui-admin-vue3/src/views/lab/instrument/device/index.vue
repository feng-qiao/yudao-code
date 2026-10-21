<template>
  <ContentWrap>
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="80px">
      <el-form-item label="设备编号" prop="deviceNo">
        <el-input v-model="queryParams.deviceNo" placeholder="请输入编号" clearable @keyup.enter="handleQuery" class="!w-150px" />
      </el-form-item>
      <el-form-item label="设备名称" prop="name">
        <el-input v-model="queryParams.name" placeholder="请输入名称" clearable @keyup.enter="handleQuery" class="!w-150px" />
      </el-form-item>
      <el-form-item label="设备类别" prop="category">
        <el-select v-model="queryParams.category" placeholder="请选择" clearable class="!w-150px">
          <el-option
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_INSTRUMENT_CATEGORY)"
            :key="dict.value"
            :label="dict.label"
            :value="dict.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择" clearable class="!w-120px">
          <el-option v-for="s in statusOptions" :key="s.value" :label="s.label" :value="s.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="平台" prop="platformId">
        <el-select v-model="queryParams.platformId" placeholder="请选择" clearable filterable class="!w-150px">
          <el-option v-for="p in platformOptions" :key="p.id" :label="p.name" :value="p.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="房间" prop="roomId">
        <el-select v-model="queryParams.roomId" placeholder="请选择" clearable filterable class="!w-150px">
          <el-option v-for="r in roomOptions" :key="r.id" :label="r.name" :value="r.id" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
        <el-button type="primary" plain @click="openForm('create')" v-hasPermi="['lab:instrument:device:create']">
          <Icon icon="ep:plus" class="mr-5px" />新增
        </el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <ContentWrap>
    <el-table v-loading="loading" :data="list" stripe>
      <el-table-column label="图片" align="center" width="80px">
        <template #default="scope">
          <el-image
            v-if="scope.row.imageUrl"
            :src="scope.row.imageUrl"
            style="width: 48px; height: 48px"
            fit="cover"
            :preview-src-list="[scope.row.imageUrl]"
            preview-teleported
          />
          <span v-else class="text-[var(--el-text-color-secondary)]">-</span>
        </template>
      </el-table-column>
      <el-table-column label="设备编号" align="center" prop="deviceNo" width="140px" />
      <el-table-column label="设备名称" align="center" prop="name" min-width="160px" show-overflow-tooltip>
        <template #default="scope">
          <el-link type="primary" @click="goDetail(scope.row.id)">{{ scope.row.name }}</el-link>
        </template>
      </el-table-column>
      <el-table-column label="类别" align="center" prop="category" width="100px">
        <template #default="scope">
          <dict-tag :type="DICT_TYPE.LAB_INSTRUMENT_CATEGORY" :value="scope.row.category" />
        </template>
      </el-table-column>
      <el-table-column label="所属平台" align="center" prop="platformName" width="130px" show-overflow-tooltip />
      <el-table-column label="房间" align="center" prop="roomName" width="100px" />
      <el-table-column label="负责人" align="center" prop="managerNames" min-width="130px" show-overflow-tooltip>
        <template #default="scope">
          <el-link type="primary" @click="openManagerDrawer(scope.row)">{{ scope.row.managerNames || '未分配' }}</el-link>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" prop="status" width="90px">
        <template #default="scope">
          <el-tag :type="statusMeta(scope.row.status).type">{{ statusMeta(scope.row.status).label }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="260px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="goDetail(scope.row.id)">详情</el-button>
          <el-button link type="primary" @click="openForm('update', scope.row.id)" v-hasPermi="['lab:instrument:device:update']">编辑</el-button>
          <el-button link type="warning" @click="openStatusDialog(scope.row)" v-hasPermi="['lab:instrument:device:manage']">状态</el-button>
          <el-button link type="danger" @click="handleDelete(scope.row)" v-hasPermi="['lab:instrument:device:delete']">删除</el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </ContentWrap>

  <DeviceForm ref="formRef" @success="getList" />

  <!-- 状态管理 -->
  <Dialog title="设备状态管理" v-model="statusDialogVisible" width="460px">
    <el-descriptions :column="1" border class="mb-15px">
      <el-descriptions-item label="设备">{{ statusForm.deviceName }}（{{ statusForm.currentLabel }}）</el-descriptions-item>
    </el-descriptions>
    <el-radio-group v-model="statusForm.target" class="!flex !flex-col">
      <el-radio v-for="s in transitableStatuses" :key="s.value" :value="s.value" class="!mb-8px">
        {{ s.label }}<span v-if="s.value === 'SCRAPPED'" class="text-[var(--el-color-danger)]">（终态，仅停用设备可报废）</span>
      </el-radio>
    </el-radio-group>
    <template #footer>
      <el-button @click="statusDialogVisible = false">取 消</el-button>
      <el-button type="primary" @click="submitStatus">确 定</el-button>
    </template>
  </Dialog>

  <!-- 负责人查看抽屉 -->
  <el-drawer v-model="managerDrawerVisible" title="设备当前负责人" size="480px">
    <el-descriptions :column="1" border class="mb-15px">
      <el-descriptions-item label="设备">{{ managerDrawerDevice?.name }}</el-descriptions-item>
    </el-descriptions>
    <el-table :data="currentManagers" border size="small">
      <el-table-column label="类型" align="center" width="90px">
        <template #default="scope">{{ managerTypeText(scope.row.managerType) }}</template>
      </el-table-column>
      <el-table-column label="姓名" align="center" prop="nickname" width="100px" />
      <el-table-column label="联系方式" align="center" prop="mobile" />
    </el-table>
    <div class="mt-20px mb-10px font-bold">变更历史</div>
    <el-timeline>
      <el-timeline-item
        v-for="h in managerHistory"
        :key="h.id"
        :type="h.status === 'ACTIVE' ? 'success' : 'info'"
        :timestamp="(h.status === 'ACTIVE' ? h.effectiveFrom : h.effectiveTo) || ''"
      >
        {{ h.nickname }}（{{ managerTypeText(h.managerType) }}）-
        {{ h.status === 'ACTIVE' ? '生效中' : '已解除' }}
        <span v-if="h.status === 'RELEASED' && h.releaseReason">：{{ h.releaseReason }}</span>
      </el-timeline-item>
    </el-timeline>
    <div class="text-[var(--el-text-color-secondary)] text-12px">
      分配、调整与解除请在「仪器负责人」管理页面操作。
    </div>
  </el-drawer>
</template>

<script setup lang="ts">
import { getStrDictOptions, DICT_TYPE } from '@/utils/dict'
import { InstrumentDeviceApi, InstrumentDeviceVO, DEVICE_STATUS } from '@/api/lab/instrument/device'
import { InstrumentPlatformApi } from '@/api/lab/instrument/platform'
import { InstrumentRoomApi } from '@/api/lab/instrument/room'
import { InstrumentManagerApi, InstrumentManagerVO } from '@/api/lab/instrument/manager'
import DeviceForm from './DeviceForm.vue'

defineOptions({ name: 'LabInstrumentDevice' })

type TagType = 'success' | 'info' | 'warning' | 'danger' | 'primary'

const message = useMessage()
const router = useRouter()
const loading = ref(true)
const list = ref<InstrumentDeviceVO[]>([])
const total = ref(0)
const platformOptions = ref<{ id: number; name: string }[]>([])
const roomOptions = ref<{ id: number; name: string }[]>([])
const statusOptions = Object.values(DEVICE_STATUS)
const statusMeta = (status: string): { value: string; label: string; type: TagType } =>
  Object.values(DEVICE_STATUS).find((s) => s.value === status) || {
    value: status,
    label: status,
    type: 'info'
  }
const managerTypeText = (t: string) =>
  ({ PRIMARY: '主负责人', REPAIR: '维修负责人', BACKUP: '备用负责人' } as Record<string, string>)[t] || t

const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  deviceNo: undefined,
  name: undefined,
  category: undefined,
  status: undefined,
  platformId: undefined,
  roomId: undefined
})
const queryFormRef = ref()
const formRef = ref()

const getList = async () => {
  loading.value = true
  try {
    const data = await InstrumentDeviceApi.getPage(queryParams)
    list.value = data.list
    total.value = data.total
  } finally {
    loading.value = false
  }
}
const loadOptions = async () => {
  const [platforms, rooms] = await Promise.all([
    InstrumentPlatformApi.getList(),
    InstrumentRoomApi.getList()
  ])
  platformOptions.value = (platforms || []).map((p: any) => ({ id: p.id, name: p.name }))
  roomOptions.value = (rooms || []).map((r: any) => ({ id: r.id, name: r.name }))
}
const handleQuery = () => {
  queryParams.pageNo = 1
  getList()
}
const resetQuery = () => {
  queryFormRef.value.resetFields()
  handleQuery()
}
const openForm = (type: 'create' | 'update', id?: number) => formRef.value.open(type, id)
const goDetail = (id: number) => {
  router.push({ path: '/lab/instrument/device-detail', query: { id } })
}

// 状态管理
const statusDialogVisible = ref(false)
const statusForm = reactive<{ id?: number; deviceName: string; current: string; currentLabel: string; target: string }>({
  id: undefined,
  deviceName: '',
  current: '',
  currentLabel: '',
  target: ''
})
const transitableStatuses = computed(() => {
  const current = DEVICE_STATUS[statusForm.current as keyof typeof DEVICE_STATUS]
  if (!current) return statusOptions
  // 报废为终态；仅停用可报废；同状态幂等允许（后端会跳过）
  return statusOptions.filter((s) => {
    if (s.value === statusForm.current) return true
    if (s.value === 'SCRAPPED') return statusForm.current === 'DISABLED'
    return statusForm.current !== 'SCRAPPED'
  })
})
const openStatusDialog = (row: InstrumentDeviceVO) => {
  const meta = statusMeta(row.status!)
  statusForm.id = row.id
  statusForm.deviceName = row.name
  statusForm.current = row.status!
  statusForm.currentLabel = meta.label
  statusForm.target = row.status!
  statusDialogVisible.value = true
}
const submitStatus = async () => {
  await InstrumentDeviceApi.updateStatus(statusForm.id!, statusForm.target)
  message.success('状态变更成功')
  statusDialogVisible.value = false
  await getList()
}

const handleDelete = async (row: InstrumentDeviceVO) => {
  try {
    await message.delConfirm(`确认删除设备「${row.name}」？仅停用/报废状态允许删除，且删除后不可在页面恢复。`)
    await InstrumentDeviceApi.delete(row.id!)
    message.success('删除成功')
    await getList()
  } catch {}
}

// 负责人抽屉
const managerDrawerVisible = ref(false)
const managerDrawerDevice = ref<InstrumentDeviceVO | null>(null)
const currentManagers = ref<any[]>([])
const managerHistory = ref<InstrumentManagerVO[]>([])
const openManagerDrawer = async (row: InstrumentDeviceVO) => {
  managerDrawerDevice.value = row
  managerDrawerVisible.value = true
  const [curr, hist] = await Promise.all([
    InstrumentManagerApi.listByTarget('DEVICE', row.id!),
    InstrumentManagerApi.history('DEVICE', row.id!)
  ])
  currentManagers.value = curr || []
  managerHistory.value = hist || []
}

onMounted(() => {
  loadOptions()
  getList()
})
</script>
