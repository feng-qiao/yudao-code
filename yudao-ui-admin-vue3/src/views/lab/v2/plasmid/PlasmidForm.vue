<template>
  <Dialog :title="dialogTitle" v-model="dialogVisible" width="800px">
    <el-form
      ref="formRef"
      :model="formData"
      :rules="formRules"
      label-width="130px"
      v-loading="formLoading"
    >
      <el-row :gutter="20">
        <el-col :span="12">
          <el-form-item label="质粒编号" prop="plasmidNo">
            <el-input
              v-model="formData.plasmidNo"
              placeholder="请输入质粒编号"
              :disabled="formType === 'update'"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="质粒名称" prop="name">
            <el-input v-model="formData.name" placeholder="请输入质粒名称" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="受体名称" prop="recipient">
            <el-input v-model="formData.recipient" placeholder="请输入受体名称" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="物种" prop="species">
            <el-select v-model="formData.species" placeholder="请选择物种" class="!w-full">
              <el-option
                v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_SPECIES)"
                :key="dict.value"
                :label="dict.label"
                :value="dict.value"
              />
            </el-select>
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="抗性" prop="resistance">
            <el-select v-model="formData.resistance" placeholder="请选择抗性" class="!w-full">
              <el-option
                v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_RESISTANCE)"
                :key="dict.value"
                :label="dict.label"
                :value="dict.value"
              />
            </el-select>
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="载体名称" prop="vectorName">
            <el-input v-model="formData.vectorName" placeholder="请输入载体名称" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="荧光标签" prop="fluorescentTag">
            <el-select
              v-model="formData.fluorescentTag"
              placeholder="请选择荧光标签"
              multiple
              class="!w-full"
              @change="handleFluorescentTagChange"
            >
              <el-option
                v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_FLUORESCENT_TAG)"
                :key="dict.value"
                :label="dict.label"
                :value="dict.value"
              />
            </el-select>
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="突变信息" prop="mutation">
            <el-input v-model="formData.mutation" placeholder="请输入突变信息" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="改造信息" prop="modification">
            <el-input v-model="formData.modification" placeholder="请输入改造信息" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="标签" prop="tag">
            <el-input v-model="formData.tag" placeholder="请输入标签" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="质粒类型" prop="plasmidTypeId">
            <el-select
              v-model="formData.plasmidTypeId"
              placeholder="请选择质粒类型"
              filterable
              class="!w-full"
            >
              <el-option
                v-for="item in typeList"
                :key="item.id"
                :label="item.name"
                :value="item.id"
              />
            </el-select>
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="保存形式" prop="storageForm">
            <el-select
              v-model="formData.storageForm"
              placeholder="请选择保存形式"
              multiple
              class="!w-full"
            >
              <el-option
                v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_STORAGE_FORM)"
                :key="dict.value"
                :label="dict.label"
                :value="dict.value"
              />
            </el-select>
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="质粒浓度 ng/μL" prop="concentration">
            <el-input-number
              v-model="formData.concentration"
              :min="0"
              :precision="2"
              placeholder="请输入质粒浓度"
              class="!w-full"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="质粒体积 μL" prop="volume">
            <el-input-number
              v-model="formData.volume"
              :min="0"
              :precision="2"
              placeholder="请输入质粒体积"
              class="!w-full"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="甘油菌规格" prop="glycerinSpec">
            <el-input v-model="formData.glycerinSpec" placeholder="请输入甘油菌规格" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="甘油菌量 μL" prop="glycerinAmount">
            <el-input-number
              v-model="formData.glycerinAmount"
              :min="0"
              :precision="2"
              placeholder="请输入甘油菌量"
              class="!w-full"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="原始质粒冰箱" prop="originalPlasmidFridge">
            <el-input
              v-model="formData.originalPlasmidFridge"
              :placeholder="originalPlasmidPlaceholder('冰箱')"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="原始质粒层" prop="originalPlasmidLayer">
            <el-input
              v-model="formData.originalPlasmidLayer"
              :placeholder="originalPlasmidPlaceholder('层')"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="原始质粒盒" prop="originalPlasmidBox">
            <el-input
              v-model="formData.originalPlasmidBox"
              :placeholder="originalPlasmidPlaceholder('盒')"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="原始质粒位置" prop="originalPlasmidPosition">
            <el-input
              v-model="formData.originalPlasmidPosition"
              :placeholder="originalPlasmidPlaceholder('位置')"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="原始甘油菌冰箱" prop="originalGlycerinFridge">
            <el-input
              v-model="formData.originalGlycerinFridge"
              :placeholder="originalGlycerinPlaceholder('冰箱')"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="原始甘油菌层" prop="originalGlycerinLayer">
            <el-input
              v-model="formData.originalGlycerinLayer"
              :placeholder="originalGlycerinPlaceholder('层')"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="原始甘油菌盒" prop="originalGlycerinBox">
            <el-input
              v-model="formData.originalGlycerinBox"
              :placeholder="originalGlycerinPlaceholder('盒')"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="原始甘油菌位置" prop="originalGlycerinPosition">
            <el-input
              v-model="formData.originalGlycerinPosition"
              :placeholder="originalGlycerinPlaceholder('位置')"
            />
          </el-form-item>
        </el-col>
        <el-col :span="24">
          <el-form-item label="无序列图谱原因" prop="sequenceNoFileReason">
            <el-input
              v-model="formData.sequenceNoFileReason"
              type="textarea"
              placeholder="无序列图谱文件时必填"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="申报初始库存 μL" prop="initialQuantityDeclared">
            <el-input-number
              v-model="formData.initialQuantityDeclared"
              :min="0"
              :precision="2"
              placeholder="请输入申报初始库存数量"
              class="!w-full"
            />
          </el-form-item>
        </el-col>
        <el-col :span="24">
          <el-form-item label="备注" prop="remark">
            <el-input v-model="formData.remark" type="textarea" placeholder="请输入备注" />
          </el-form-item>
        </el-col>
      </el-row>
    </el-form>
    <template #footer>
      <el-button @click="submitForm" type="primary" :disabled="formLoading">确 定</el-button>
      <el-button @click="dialogVisible = false">取 消</el-button>
    </template>
  </Dialog>
</template>
<script setup lang="ts">
import { getStrDictOptions, DICT_TYPE } from '@/utils/dict'
import { PlasmidApi, PlasmidVO } from '@/api/lab/v2/plasmid'
import { PlasmidTypeApi, PlasmidTypeVO } from '@/api/lab/v2/plasmid-type'
import { PlasmidStorageApi } from '@/api/lab/v2/plasmid-storage'

/** 质粒档案（V2）表单 */
defineOptions({ name: 'PlasmidV2PlasmidForm' })

const { t } = useI18n() // 国际化
const message = useMessage() // 消息弹窗

const dialogVisible = ref(false) // 弹窗的是否展示
const dialogTitle = ref('') // 弹窗的标题
const formLoading = ref(false) // 表单的加载中：1）修改时的数据加载；2）提交的按钮禁用
const formType = ref('') // 表单的类型：create - 新增；update - 修改
const formData = ref({
  id: undefined,
  plasmidNo: undefined,
  name: undefined,
  recipient: undefined,
  species: undefined,
  resistance: undefined,
  vectorName: undefined,
  fluorescentTag: [] as string[],
  mutation: undefined,
  modification: undefined,
  tag: undefined,
  plasmidTypeId: undefined,
  storageForm: [] as string[],
  concentration: undefined,
  volume: undefined,
  glycerinSpec: undefined,
  glycerinAmount: undefined,
  originalPlasmidFridge: undefined,
  originalPlasmidLayer: undefined,
  originalPlasmidBox: undefined,
  originalPlasmidPosition: undefined,
  originalGlycerinFridge: undefined,
  originalGlycerinLayer: undefined,
  originalGlycerinBox: undefined,
  originalGlycerinPosition: undefined,
  sequenceNoFileReason: undefined,
  initialQuantityDeclared: undefined,
  remark: undefined
})
const formRules = reactive({
  plasmidNo: [{ required: true, message: '质粒编号不能为空', trigger: 'blur' }],
  name: [{ required: true, message: '质粒名称不能为空', trigger: 'blur' }],
  recipient: [{ required: true, message: '受体名称不能为空', trigger: 'blur' }],
  species: [{ required: true, message: '物种不能为空', trigger: 'change' }],
  resistance: [{ required: true, message: '抗性不能为空', trigger: 'change' }],
  vectorName: [{ required: true, message: '载体名称不能为空', trigger: 'blur' }],
  fluorescentTag: [{ required: true, type: 'array', message: '荧光标签不能为空', trigger: 'change' }],
  mutation: [{ required: true, message: '突变信息不能为空', trigger: 'blur' }],
  modification: [{ required: true, message: '改造信息不能为空', trigger: 'blur' }],
  tag: [{ required: true, message: '标签不能为空', trigger: 'blur' }],
  plasmidTypeId: [{ required: true, message: '质粒类型不能为空', trigger: 'change' }],
  storageForm: [{ required: true, type: 'array', message: '保存形式不能为空', trigger: 'change' }],
  concentration: [{ required: true, message: '质粒浓度不能为空', trigger: 'blur' }]
})
const formRef = ref() // 表单 Ref

/** 原始位置是否已保存标志（PLASMID-STORAGE-MANAGEMENT-02：只用于提示，不含位置值） */
const hasOriginalPlasmidPosition = ref(false)
const hasOriginalGlycerinPosition = ref(false)
/** 原始位置输入框提示：已保存时提示留空保持不变 */
const originalPlasmidPlaceholder = (field: string) =>
  hasOriginalPlasmidPosition.value ? '已保存，留空保持不变' : `请输入原始质粒${field}`
const originalGlycerinPlaceholder = (field: string) =>
  hasOriginalGlycerinPosition.value ? '已保存，留空保持不变' : `请输入原始甘油菌${field}`

/** 质粒类型下拉列表 */
const typeList = ref<PlasmidTypeVO[]>([])
const getTypeList = async () => {
  const data = await PlasmidTypeApi.getPlasmidTypePage({ pageNo: 1, pageSize: 100 })
  typeList.value = data.list
}

/** 荧光标签选择变化：NONE 不能与其他值同时选择 */
const handleFluorescentTagChange = (val: string[]) => {
  if (!val || val.length <= 1) {
    return
  }
  const noneIndex = val.indexOf('NONE')
  if (noneIndex === -1) {
    return
  }
  // 最后选择的是 NONE 时，清除其他值；否则移除 NONE
  if (noneIndex === val.length - 1) {
    formData.value.fluorescentTag = ['NONE']
    message.warning('荧光标签「无」不能与其他标签同时选择')
  } else {
    formData.value.fluorescentTag = val.filter((item) => item !== 'NONE')
    message.warning('荧光标签「无」不能与其他标签同时选择')
  }
}

/** 打开弹窗 */
const open = async (type: string, id?: number) => {
  dialogVisible.value = true
  dialogTitle.value = t('action.' + type)
  formType.value = type
  resetForm()
  getTypeList()
  // 修改时，设置数据
  if (id) {
    formLoading.value = true
    try {
      const data = await PlasmidApi.getPlasmid(id)
      formData.value = {
        ...formData.value,
        ...data,
        fluorescentTag: data.fluorescentTag ? data.fluorescentTag.split(',') : [],
        storageForm: data.storageForm ? data.storageForm.split(',') : []
      }
      // 原始申报位置（PLASMID-STORAGE-MANAGEMENT-02）：
      // 普通用户不得读取任何位置值（含本人登记的原始位置），登记接口只返回"是否已保存"标志；
      // 已保存时通过 placeholder 提示"留空保持不变"，提交整组留空后端保持原值、整组有值整组替换
      try {
        const registration = await PlasmidStorageApi.getRegistrationForEdit(id)
        if (registration) {
          hasOriginalPlasmidPosition.value = !!registration.hasOriginalPlasmidPosition
          hasOriginalGlycerinPosition.value = !!registration.hasOriginalGlycerinPosition
        }
      } catch {
        // 登记人本人以外或状态不允许时忽略（保持空值与默认提示）
      }
    } finally {
      formLoading.value = false
    }
  }
}
defineExpose({ open }) // 提供 open 方法，用于打开弹窗

/** 提交表单 */
const emit = defineEmits(['success']) // 定义 success 事件，用于操作成功后的回调
const submitForm = async () => {
  // 校验表单
  await formRef.value.validate()
  // 提交请求
  formLoading.value = true
  try {
    const data = {
      ...formData.value,
      fluorescentTag: formData.value.fluorescentTag.join(','),
      storageForm: formData.value.storageForm.join(',')
    } as unknown as PlasmidVO
    if (formType.value === 'create') {
      await PlasmidApi.createPlasmid(data)
      message.success(t('common.createSuccess'))
    } else {
      await PlasmidApi.updatePlasmid(data)
      message.success(t('common.updateSuccess'))
    }
    dialogVisible.value = false
    // 发送操作成功的事件
    emit('success')
  } finally {
    formLoading.value = false
  }
}

/** 重置表单 */
const resetForm = () => {
  hasOriginalPlasmidPosition.value = false
  hasOriginalGlycerinPosition.value = false
  formData.value = {
    id: undefined,
    plasmidNo: undefined,
    name: undefined,
    recipient: undefined,
    species: undefined,
    resistance: undefined,
    vectorName: undefined,
    fluorescentTag: [],
    mutation: undefined,
    modification: undefined,
    tag: undefined,
    plasmidTypeId: undefined,
    storageForm: [],
    concentration: undefined,
    volume: undefined,
    glycerinSpec: undefined,
    glycerinAmount: undefined,
    originalPlasmidFridge: undefined,
    originalPlasmidLayer: undefined,
    originalPlasmidBox: undefined,
    originalPlasmidPosition: undefined,
    originalGlycerinFridge: undefined,
    originalGlycerinLayer: undefined,
    originalGlycerinBox: undefined,
    originalGlycerinPosition: undefined,
    sequenceNoFileReason: undefined,
    initialQuantityDeclared: undefined,
    remark: undefined
  }
  formRef.value?.resetFields()
}
</script>
