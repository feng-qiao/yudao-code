<template>
  <Dialog :title="dialogTitle" v-model="dialogVisible">
    <el-form ref="formRef" :model="formData" :rules="formRules" label-width="90px" v-loading="formLoading">
      <el-form-item label="房间编码" prop="code">
        <el-input v-model="formData.code" placeholder="请输入房间编码" />
      </el-form-item>
      <el-form-item label="房间名称" prop="name">
        <el-input v-model="formData.name" placeholder="如 209室" />
      </el-form-item>
      <el-form-item label="楼栋" prop="building">
        <el-input v-model="formData.building" placeholder="请输入楼栋" />
      </el-form-item>
      <el-form-item label="楼层" prop="floor">
        <el-input v-model="formData.floor" placeholder="请输入楼层" />
      </el-form-item>
      <el-form-item label="位置描述" prop="locationDesc">
        <el-input v-model="formData.locationDesc" type="textarea" :rows="2" placeholder="请输入位置描述" />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-radio-group v-model="formData.status">
          <el-radio value="ENABLE">启用</el-radio>
          <el-radio value="DISABLE">停用</el-radio>
        </el-radio-group>
      </el-form-item>
      <el-form-item label="排序" prop="sort">
        <el-input-number v-model="formData.sort" :min="0" controls-position="right" />
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
import { InstrumentRoomApi, InstrumentRoomVO } from '@/api/lab/instrument/room'

defineOptions({ name: 'LabInstrumentRoomForm' })

const message = useMessage()
const { t } = useI18n()

const dialogVisible = ref(false)
const dialogTitle = ref('')
const formLoading = ref(false)
const formType = ref<'create' | 'update'>('create')
const formData = ref<InstrumentRoomVO>({
  code: '',
  name: '',
  status: 'ENABLE'
} as InstrumentRoomVO)
const formRef = ref()
const formRules = {
  code: [{ required: true, message: '房间编码不能为空', trigger: 'blur' }],
  name: [{ required: true, message: '房间名称不能为空', trigger: 'blur' }]
}

const resetForm = () => {
  formData.value = {
    id: undefined,
    code: '',
    name: '',
    building: '',
    floor: '',
    locationDesc: '',
    status: 'ENABLE',
    sort: 0,
    remark: ''
  } as InstrumentRoomVO
  formRef.value?.resetFields()
}

const open = async (type: 'create' | 'update', id?: number) => {
  resetForm()
  formType.value = type
  dialogVisible.value = true
  dialogTitle.value = type === 'create' ? '新增实验室/房间' : '修改实验室/房间'
  if (id) {
    formLoading.value = true
    try {
      formData.value = await InstrumentRoomApi.get(id)
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
      await InstrumentRoomApi.create(formData.value)
      message.success(t('common.createSuccess'))
    } else {
      await InstrumentRoomApi.update(formData.value)
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
