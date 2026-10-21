<template>
  <Dialog :title="dialogTitle" v-model="dialogVisible">
    <el-form
      ref="formRef"
      :model="formData"
      :rules="formRules"
      label-width="90px"
      v-loading="formLoading"
    >
      <el-form-item label="平台编码" prop="code">
        <el-input v-model="formData.code" placeholder="请输入平台编码" />
      </el-form-item>
      <el-form-item label="平台名称" prop="name">
        <el-input v-model="formData.name" placeholder="请输入平台名称" />
      </el-form-item>
      <el-form-item label="平台描述" prop="description">
        <el-input v-model="formData.description" type="textarea" :rows="3" placeholder="请输入平台描述" />
      </el-form-item>
      <el-form-item label="排序" prop="sort">
        <el-input-number v-model="formData.sort" :min="0" controls-position="right" />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-radio-group v-model="formData.status">
          <el-radio value="ENABLE">启用</el-radio>
          <el-radio value="DISABLE">停用</el-radio>
        </el-radio-group>
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="formData.remark" type="textarea" :rows="2" placeholder="请输入备注" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="dialogVisible = false">取 消</el-button>
      <el-button type="primary" :loading="formLoading" @click="submitForm">确 定</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { InstrumentPlatformApi, InstrumentPlatformVO } from '@/api/lab/instrument/platform'

defineOptions({ name: 'LabInstrumentPlatformForm' })

const message = useMessage()
const { t } = useI18n()

const dialogVisible = ref(false)
const dialogTitle = ref('')
const formLoading = ref(false)
const formType = ref<'create' | 'update'>('create')
const formData = ref<InstrumentPlatformVO>({
  code: '',
  name: '',
  status: 'ENABLE'
} as InstrumentPlatformVO)
const formRef = ref()
const formRules = {
  code: [{ required: true, message: '平台编码不能为空', trigger: 'blur' }],
  name: [{ required: true, message: '平台名称不能为空', trigger: 'blur' }]
}

const resetForm = () => {
  formData.value = {
    id: undefined,
    code: '',
    name: '',
    description: '',
    sort: 0,
    status: 'ENABLE',
    remark: ''
  } as InstrumentPlatformVO
  formRef.value?.resetFields()
}

const open = async (type: 'create' | 'update', id?: number) => {
  resetForm()
  formType.value = type
  dialogVisible.value = true
  dialogTitle.value = type === 'create' ? '新增仪器平台' : '修改仪器平台'
  if (id) {
    formLoading.value = true
    try {
      formData.value = await InstrumentPlatformApi.get(id)
    } finally {
      formLoading.value = false
    }
  }
}

const submitForm = async () => {
  await formRef.value.validate()
  formLoading.value = true
  try {
    if (formType.value === 'create') {
      await InstrumentPlatformApi.create(formData.value)
      message.success(t('common.createSuccess'))
    } else {
      await InstrumentPlatformApi.update(formData.value)
      message.success(t('common.updateSuccess'))
    }
    dialogVisible.value = false
    emit('success')
  } finally {
    formLoading.value = false
  }
}

const emit = defineEmits(['success'])
defineExpose({ open })
</script>
