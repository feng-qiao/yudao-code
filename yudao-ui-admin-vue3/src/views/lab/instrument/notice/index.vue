<template>
  <ContentWrap>
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="90px">
      <el-form-item label="设备" prop="targetId">
        <el-select
          v-model="queryParams.targetId"
          placeholder="请选择设备"
          clearable
          filterable
          class="!w-260px"
          @change="handleQuery"
        >
          <el-option v-for="d in deviceOptions" :key="d.id" :label="d.name + '（' + d.deviceNo + '）'" :value="d.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择" clearable class="!w-130px">
          <el-option label="草稿" value="DRAFT" />
          <el-option label="已发布" value="PUBLISHED" />
          <el-option label="已归档" value="ARCHIVED" />
        </el-select>
      </el-form-item>
      <el-form-item label="标题" prop="title">
        <el-input v-model="queryParams.title" placeholder="标题关键词" clearable @keyup.enter="handleQuery" class="!w-180px" />
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
        <el-button
          type="primary"
          plain
          :disabled="!queryParams.targetId"
          @click="openForm('create')"
          v-hasPermi="['lab:instrument:notice:create']"
        >
          <Icon icon="ep:plus" class="mr-5px" />为该设备新建草稿
        </el-button>
      </el-form-item>
    </el-form>
    <el-alert
      v-if="!queryParams.targetId"
      type="info"
      :closable="false"
      title="使用须知按设备版本化管理：请先选择设备。发布新版本时，该设备旧版本自动归档；历史版本永久保留，不提供删除。"
    />
  </ContentWrap>

  <ContentWrap>
    <el-table v-loading="loading" :data="list" stripe>
      <el-table-column label="设备" align="center" prop="targetId" width="120px">
        <template #default="scope">{{ deviceName(scope.row.targetId) }}</template>
      </el-table-column>
      <el-table-column label="版本" align="center" prop="version" width="70px" />
      <el-table-column label="标题" align="center" prop="title" min-width="180px" show-overflow-tooltip />
      <el-table-column label="状态" align="center" width="90px">
        <template #default="scope">
          <el-tag :type="noticeStatusMeta(scope.row.status).type">
            {{ noticeStatusMeta(scope.row.status).label }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="需确认" align="center" width="80px">
        <template #default="scope">{{ scope.row.requireAcknowledge ? '是' : '否' }}</template>
      </el-table-column>
      <el-table-column label="发布人" align="center" prop="publisherName" width="100px" />
      <el-table-column label="发布时间" align="center" prop="publishTime" :formatter="dateFormatter" width="170px" />
      <el-table-column label="创建时间" align="center" prop="createTime" :formatter="dateFormatter" width="170px" />
      <el-table-column label="操作" align="center" width="200px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openView(scope.row)">查看</el-button>
          <el-button
            link
            type="primary"
            v-if="scope.row.status === 'DRAFT'"
            @click="openForm('update', scope.row.id)"
            v-hasPermi="['lab:instrument:notice:update']"
          >
            编辑
          </el-button>
          <el-button
            link
            type="success"
            v-if="scope.row.status === 'DRAFT'"
            @click="handlePublish(scope.row)"
            v-hasPermi="['lab:instrument:notice:update']"
          >
            发布
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </ContentWrap>

  <!-- 新建/编辑草稿 -->
  <Dialog :title="dialogTitle" v-model="formVisible" width="720px">
    <el-form ref="formRef" :model="formData" :rules="formRules" label-width="100px">
      <el-form-item label="设备">
        <el-select :model-value="formData.targetId" disabled class="!w-full">
          <el-option :label="deviceName(formData.targetId)" :value="formData.targetId" />
        </el-select>
      </el-form-item>
      <el-form-item label="标题" prop="title">
        <el-input v-model="formData.title" placeholder="请输入标题" />
      </el-form-item>
      <el-form-item label="须知内容" prop="content">
        <el-input v-model="formData.content" type="textarea" :rows="10" placeholder="请输入使用须知正文" />
      </el-form-item>
      <el-form-item label="要求确认" prop="requireAcknowledge">
        <el-switch v-model="formData.requireAcknowledge" />
        <span class="ml-8px text-12px text-[var(--el-text-color-secondary)]">第一期仅存档，预约环节确认功能在后续任务开放</span>
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="formData.remark" type="textarea" :rows="2" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="formVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitForm">确 定</el-button>
    </template>
  </Dialog>

  <!-- 查看 -->
  <Dialog title="使用须知详情" v-model="viewVisible" width="720px">
    <el-descriptions :column="2" border class="mb-12px">
      <el-descriptions-item label="版本">V{{ viewData.version }}</el-descriptions-item>
      <el-descriptions-item label="状态">
        <el-tag :type="noticeStatusMeta(viewData.status).type">{{ noticeStatusMeta(viewData.status).label }}</el-tag>
      </el-descriptions-item>
      <el-descriptions-item label="标题" :span="2">{{ viewData.title }}</el-descriptions-item>
      <el-descriptions-item label="发布人">{{ viewData.publisherName || '-' }}</el-descriptions-item>
      <el-descriptions-item label="发布时间">{{ viewData.publishTime || '-' }}</el-descriptions-item>
    </el-descriptions>
    <div class="whitespace-pre-wrap bg-[var(--el-fill-color-light)] p-12px rounded">{{ viewData.content }}</div>
  </Dialog>
</template>

<script setup lang="ts">
import { dateFormatter } from '@/utils/formatTime'
import { InstrumentNoticeApi, InstrumentNoticeVO } from '@/api/lab/instrument/notice'
import { InstrumentDeviceApi } from '@/api/lab/instrument/device'

defineOptions({ name: 'LabInstrumentNotice' })

type TagType = 'success' | 'info' | 'warning' | 'danger' | 'primary'

const message = useMessage()
const { t } = useI18n()
const loading = ref(true)
const list = ref<InstrumentNoticeVO[]>([])
const total = ref(0)
const deviceOptions = ref<{ id: number; name: string; deviceNo?: string }[]>([])
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  targetType: 'DEVICE',
  targetId: undefined as number | undefined,
  status: undefined as string | undefined,
  title: undefined as string | undefined
})
const queryFormRef = ref()

const noticeStatusMeta = (s?: string): { label: string; type: TagType } =>
  ({
    DRAFT: { label: '草稿', type: 'info' },
    PUBLISHED: { label: '已发布', type: 'success' },
    ARCHIVED: { label: '已归档', type: 'warning' }
  } as Record<string, { label: string; type: TagType }>)[s || ''] || { label: s || '', type: 'info' }

const deviceName = (id?: number) => deviceOptions.value.find((d) => d.id === id)?.name || (id ? `#${id}` : '-')

const getList = async () => {
  loading.value = true
  try {
    const data = await InstrumentNoticeApi.getPage(queryParams)
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
  queryParams.targetId = undefined
  handleQuery()
}

// 新建/编辑
const formVisible = ref(false)
const dialogTitle = ref('')
const submitLoading = ref(false)
const formType = ref<'create' | 'update'>('create')
const formRef = ref()
const formData = ref<InstrumentNoticeVO>({} as InstrumentNoticeVO)
const formRules = {
  title: [{ required: true, message: '标题不能为空', trigger: 'blur' }],
  content: [{ required: true, message: '须知内容不能为空', trigger: 'blur' }]
}
const openForm = async (type: 'create' | 'update', id?: number) => {
  formType.value = type
  if (type === 'create') {
    if (!queryParams.targetId) {
      message.warning('请先选择设备')
      return
    }
    formData.value = {
      targetType: 'DEVICE',
      targetId: queryParams.targetId,
      title: '',
      content: '',
      requireAcknowledge: false,
      remark: ''
    } as InstrumentNoticeVO
  } else {
    formData.value = await InstrumentNoticeApi.get(id!)
  }
  dialogTitle.value = type === 'create' ? '新建使用须知草稿（自动生成新版本号）' : '编辑使用须知草稿'
  formVisible.value = true
}
const submitForm = async () => {
  await formRef.value.validate()
  submitLoading.value = true
  try {
    if (formType.value === 'create') {
      await InstrumentNoticeApi.create(formData.value)
      message.success(t('common.createSuccess'))
    } else {
      await InstrumentNoticeApi.update(formData.value)
      message.success(t('common.updateSuccess'))
    }
    formVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

const handlePublish = async (row: InstrumentNoticeVO) => {
  await message.confirm(`确认发布「${row.title}」V${row.version}？发布后该设备旧版本将自动归档。`)
  await InstrumentNoticeApi.publish(row.id!)
  message.success('发布成功')
  await getList()
}

// 查看
const viewVisible = ref(false)
const viewData = ref<InstrumentNoticeVO>({} as InstrumentNoticeVO)
const openView = (row: InstrumentNoticeVO) => {
  viewData.value = row
  viewVisible.value = true
}

onMounted(async () => {
  const page = await InstrumentDeviceApi.getPage({ pageNo: 1, pageSize: 500 })
  deviceOptions.value = (page.list || []).map((d: any) => ({
    id: d.id,
    name: d.name,
    deviceNo: d.deviceNo
  }))
  await getList()
})
</script>
