<template>
  <ContentWrap>
    <el-page-header @back="goBack" :content="isEdit ? '编辑故障上报' : '故障上报'">
      <template #content>
        <span v-if="deviceInfo" class="text-14px text-[var(--el-text-color-secondary)]">
          设备：{{ deviceInfo.name }}（{{ deviceInfo.deviceNo || '无编号' }}）
        </span>
      </template>
    </el-page-header>
  </ContentWrap>

  <ContentWrap>
    <el-form
      ref="formRef"
      :model="form"
      :rules="rules"
      label-width="110px"
      class="max-w-700px"
      @submit.prevent
    >
      <el-form-item label="故障设备" required>
        <el-select
          v-if="!deviceIdFromQuery"
          v-model="form.deviceId"
          filterable
          placeholder="请选择故障设备"
          class="!w-full"
        >
          <el-option v-for="d in deviceOptions" :key="d.id" :label="d.name + '（' + (d.deviceNo || d.id) + '）'" :value="d.id!" />
        </el-select>
        <span v-else class="text-[var(--el-text-color-primary)]">{{ deviceInfo?.name }}（{{ deviceInfo?.deviceNo || '-' }}）</span>
      </el-form-item>

      <el-form-item label="故障时间" prop="faultTime">
        <el-date-picker
          v-model="form.faultTime"
          type="datetime"
          value-format="YYYY-MM-DD HH:mm:ss"
          placeholder="选择故障发生时间"
          class="!w-full"
        />
      </el-form-item>

      <el-form-item label="故障现象" prop="phenomenon">
        <el-input
          v-model="form.phenomenon"
          type="textarea"
          :rows="2"
          maxlength="200"
          show-word-limit
          placeholder="简要描述故障现象，如：开机无反应、显示异常等"
        />
      </el-form-item>

      <el-form-item label="详细描述" prop="description">
        <el-input
          v-model="form.description"
          type="textarea"
          :rows="4"
          maxlength="1000"
          show-word-limit
          placeholder="详细描述故障发生的场景、操作步骤、异常提示等"
        />
      </el-form-item>

      <el-form-item label="严重程度" prop="severity">
        <el-radio-group v-model="form.severity">
          <el-radio value="LOW">轻微（不影响使用）</el-radio>
          <el-radio value="MEDIUM">一般（部分功能异常）</el-radio>
          <el-radio value="HIGH">严重（无法正常使用）</el-radio>
          <el-radio value="CRITICAL">紧急（安全隐患）</el-radio>
        </el-radio-group>
      </el-form-item>

      <el-form-item label="附件">
        <el-input v-model="form.attachmentUrl" placeholder="选填：已有附件链接" />
      </el-form-item>

      <el-divider content-position="left">联系方式</el-divider>

      <el-form-item label="联系电话" prop="contactPhone">
        <el-input v-model="form.contactPhone" placeholder="手机号，便于工程师联系" />
      </el-form-item>

      <el-form-item>
        <el-button type="primary" :loading="submitLoading" @click="handleSubmit">
          <Icon icon="ep:check" class="mr-5px" />提交上报
        </el-button>
        <el-button @click="goBack">取消</el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>
</template>

<script setup lang="ts">
import { useRoute } from 'vue-router'
import { InstrumentDeviceApi, InstrumentDeviceVO } from '@/api/lab/instrument/device'
import { InstrumentFaultReportApi } from '@/api/lab/instrument/fault-report'

defineOptions({ name: 'LabInstrumentFaultReportSubmit' })

const route = useRoute()
const message = useMessage()
const formRef = ref()
const submitLoading = ref(false)

// 从 query 获取设备 ID
const deviceIdFromQuery = computed(() => {
  const id = Number(route.query.deviceId)
  return Number.isSafeInteger(id) && id > 0 ? id : undefined
})
const hasDeviceQuery = computed(() => route.query.deviceId !== undefined)

const deviceInfo = ref<InstrumentDeviceVO | null>(null)
const deviceOptions = ref<InstrumentDeviceVO[]>([])

const loadDevice = async () => {
  if (deviceIdFromQuery.value) {
    const found = await InstrumentDeviceApi.get(deviceIdFromQuery.value)
    if (!found?.id) throw new Error('Device unavailable')
    deviceInfo.value = found
    form.deviceId = deviceIdFromQuery.value
  } else {
    deviceOptions.value = (await InstrumentDeviceApi.getPage({ pageNo: 1, pageSize: 200 })).list || []
  }
}

const isEdit = computed(() => false) // 当前仅支持新建

const form = reactive({
  deviceId: undefined as number | undefined,
  faultTime: undefined as string | undefined,
  phenomenon: '',
  description: '',
  severity: 'MEDIUM',
  contactPhone: '',
  attachmentUrl: ''
})

const rules = {
  deviceId: [{ required: true, message: '请选择故障设备', trigger: 'change' }],
  faultTime: [{ required: true, message: '请选择故障时间', trigger: 'change' }],
  phenomenon: [{ required: true, message: '请填写故障现象', trigger: 'blur' }],
  description: [{ required: true, message: '请填写详细描述', trigger: 'blur' }],
  severity: [{ required: true, message: '请选择严重程度', trigger: 'change' }],
  contactPhone: [{ required: true, message: '请填写联系电话', trigger: 'blur' }]
}

const goBack = () => {
  if (window.history.length > 1) window.history.back()
  else message.info('已在首页')
}

const handleSubmit = async () => {
  await formRef.value.validate()
  submitLoading.value = true
  try {
    await InstrumentFaultReportApi.submit({
      deviceId: form.deviceId,
      faultTime: form.faultTime,
      phenomenon: form.phenomenon,
      description: form.description,
      severity: form.severity,
      contactPhone: form.contactPhone,
      attachmentUrl: form.attachmentUrl || undefined
    })
    message.success('故障上报已提交，等待管理员确认')
    // 提交后返回设备详情页或列表
    if (route.query.from === 'deviceDetail') {
      window.history.back()
    } else {
      window.history.back()
    }
  } finally {
    submitLoading.value = false
  }
}

onMounted(async () => {
  if (hasDeviceQuery.value && !deviceIdFromQuery.value) {
    message.error('设备 ID 无效，无法提交故障上报')
    return
  }
  try {
    await loadDevice()
  } catch {
    message.error('设备不存在或当前账号无权访问')
    return
  }
  // 默认故障时间为当前时间
  if (!form.faultTime) {
    const now = new Date()
    const pad = (n: number) => String(n).padStart(2, '0')
    form.faultTime = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`
  }
})
</script>
