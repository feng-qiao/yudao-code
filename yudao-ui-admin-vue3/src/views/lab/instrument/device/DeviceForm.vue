<template>
  <Dialog :title="dialogTitle" v-model="dialogVisible" width="720px">
    <el-form ref="formRef" :model="formData" :rules="formRules" label-width="100px" v-loading="formLoading">
      <el-row :gutter="16">
        <el-col :span="12">
          <el-form-item label="设备编号" prop="deviceNo">
            <el-input v-model="formData.deviceNo" placeholder="请输入设备编号" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="设备名称" prop="name">
            <el-input v-model="formData.name" placeholder="请输入设备名称" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="设备类别" prop="category">
            <el-select v-model="formData.category" placeholder="请选择设备类别" class="!w-full">
              <el-option
                v-for="dict in getStrDictOptions(DICT_TYPE.LAB_INSTRUMENT_CATEGORY)"
                :key="dict.value"
                :label="dict.label"
                :value="dict.value"
              />
            </el-select>
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="维修口径" prop="repairScope">
            <el-select v-model="formData.repairScope" placeholder="请选择维修口径" class="!w-full">
              <el-option
                v-for="dict in getStrDictOptions(DICT_TYPE.LAB_INSTRUMENT_REPAIR_SCOPE)"
                :key="dict.value"
                :label="dict.label"
                :value="dict.value"
              />
            </el-select>
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="所属平台" prop="platformId">
            <el-select v-model="formData.platformId" placeholder="请选择平台" clearable class="!w-full">
              <el-option v-for="p in platformList" :key="p.id" :label="p.name" :value="p.id" />
            </el-select>
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="所属房间" prop="roomId">
            <el-select v-model="formData.roomId" placeholder="请选择房间" clearable filterable class="!w-full">
              <el-option v-for="r in roomList" :key="r.id" :label="r.name" :value="r.id" />
            </el-select>
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="型号" prop="model">
            <el-input v-model="formData.model" placeholder="请输入型号" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="规格" prop="spec">
            <el-input v-model="formData.spec" placeholder="请输入规格" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="资产编号" prop="assetNo">
            <el-input v-model="formData.assetNo" placeholder="请输入资产编号" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="生产厂家" prop="manufacturer">
            <el-input v-model="formData.manufacturer" placeholder="请输入生产厂家" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="购置日期" prop="purchaseDate">
            <el-date-picker
              v-model="formData.purchaseDate"
              type="date"
              value-format="YYYY-MM-DD"
              placeholder="请选择购置日期"
              class="!w-full"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="允许预约" prop="bookable">
            <el-switch v-model="formData.bookable" />
            <span class="ml-8px text-[var(--el-text-color-secondary)] text-12px">第一期仅档案标记</span>
          </el-form-item>
        </el-col>
      </el-row>
      <el-form-item label="设备图片" prop="imageUrl">
        <UploadImg v-model="formData.imageUrl" />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="formData.remark" type="textarea" :rows="2" placeholder="请输入备注" />
      </el-form-item>
      <el-alert
        v-if="formType === 'update'"
        type="info"
        :closable="false"
        title="设备状态（正常/维护/故障/停用/报废）请通过列表「状态管理」操作，负责人请在「仪器负责人」页面分配。"
        class="mb-10px"
      />
    </el-form>
    <template #footer>
      <el-button @click="dialogVisible = false">取 消</el-button>
      <el-button type="primary" :loading="formLoading" @click="submitForm">确 定</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { getStrDictOptions, DICT_TYPE } from '@/utils/dict'
import { UploadImg } from '@/components/UploadFile'
import { InstrumentDeviceApi, InstrumentDeviceVO } from '@/api/lab/instrument/device'
import { InstrumentPlatformApi } from '@/api/lab/instrument/platform'
import { InstrumentRoomApi } from '@/api/lab/instrument/room'

defineOptions({ name: 'LabInstrumentDeviceForm' })

const message = useMessage()
const { t } = useI18n()

const dialogVisible = ref(false)
const dialogTitle = ref('')
const formLoading = ref(false)
const formType = ref<'create' | 'update'>('create')
const platformList = ref<{ id: number; name: string }[]>([])
const roomList = ref<{ id: number; name: string }[]>([])
const formData = ref<InstrumentDeviceVO>({
  deviceNo: '',
  name: '',
  category: '',
  repairScope: 'SCIENCE',
  bookable: false
} as InstrumentDeviceVO)
const formRef = ref()
const formRules = {
  deviceNo: [{ required: true, message: '设备编号不能为空', trigger: 'blur' }],
  name: [{ required: true, message: '设备名称不能为空', trigger: 'blur' }],
  category: [{ required: true, message: '设备类别不能为空', trigger: 'change' }]
}

const resetForm = () => {
  formData.value = {
    id: undefined,
    deviceNo: '',
    name: '',
    model: '',
    spec: '',
    category: '',
    repairScope: 'SCIENCE',
    platformId: undefined,
    roomId: undefined,
    assetNo: '',
    manufacturer: '',
    purchaseDate: undefined,
    bookable: false,
    imageUrl: '',
    sort: 0,
    remark: ''
  } as InstrumentDeviceVO
  formRef.value?.resetFields()
}

const open = async (type: 'create' | 'update', id?: number) => {
  resetForm()
  formType.value = type
  dialogVisible.value = true
  dialogTitle.value = type === 'create' ? '新增仪器设备' : '修改仪器设备'
  const [platforms, rooms] = await Promise.all([
    InstrumentPlatformApi.getList('ENABLE'),
    InstrumentRoomApi.getList('ENABLE')
  ])
  platformList.value = (platforms || []).map((p: any) => ({ id: p.id, name: p.name }))
  roomList.value = (rooms || []).map((r: any) => ({ id: r.id, name: r.name }))
  if (id) {
    formLoading.value = true
    try {
      formData.value = await InstrumentDeviceApi.get(id)
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
      await InstrumentDeviceApi.create(formData.value)
      message.success(t('common.createSuccess'))
    } else {
      await InstrumentDeviceApi.update(formData.value)
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
