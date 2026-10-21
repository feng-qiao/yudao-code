<template>
  <Dialog :title="dialogTitle" v-model="dialogVisible" width="600px">
    <el-form
      ref="formRef"
      :model="formData"
      :rules="formRules"
      label-width="100px"
      v-loading="formLoading"
    >
      <el-form-item label="类型编码" prop="code">
        <el-input v-model="formData.code" placeholder="请输入类型编码" />
      </el-form-item>
      <el-form-item label="类型名称" prop="name">
        <el-input v-model="formData.name" placeholder="请输入类型名称" />
      </el-form-item>
      <el-form-item label="库管员" prop="managerId">
        <el-select
          v-model="formData.managerId"
          placeholder="请选择库管员"
          filterable
          clearable
          class="!w-full"
          :loading="candidateLoading"
        >
          <el-option
            v-for="item in managerOptions"
            :key="item.id"
            :label="item.label"
            :value="item.id"
            :disabled="item.invalid"
          />
        </el-select>
        <div v-if="managerInvalid" class="manager-invalid-tip">
          当前库管员（ID：{{ formData.managerId }}）已失效（被禁用、删除或已取消库管员角色），请重新选择或清空后再保存。
        </div>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="formData.status" placeholder="请选择状态" class="!w-full">
          <el-option
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_TYPE_STATUS)"
            :key="dict.value"
            :label="dict.label"
            :value="dict.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="排序" prop="sort">
        <el-input-number
          v-model="formData.sort"
          :min="0"
          placeholder="请输入排序"
          class="!w-full"
        />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input
          v-model="formData.remark"
          type="textarea"
          placeholder="请输入管理备注"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="submitForm" type="primary" :disabled="formLoading">确 定</el-button>
      <el-button @click="dialogVisible = false">取 消</el-button>
    </template>
  </Dialog>
</template>
<script setup lang="ts">
import { getStrDictOptions, DICT_TYPE } from '@/utils/dict'
import {
  PlasmidTypeApi,
  PlasmidTypeVO,
  PlasmidTypeManagerCandidateVO
} from '@/api/lab/v2/plasmid-type'

/** 质粒类型（V2）表单 */
defineOptions({ name: 'PlasmidV2TypeForm' })

const { t } = useI18n() // 国际化
const message = useMessage() // 消息弹窗

const dialogVisible = ref(false) // 弹窗的是否展示
const dialogTitle = ref('') // 弹窗的标题
const formLoading = ref(false) // 表单的加载中：1）修改时的数据加载；2）提交的按钮禁用
const formType = ref('') // 表单的类型：create - 新增；update - 修改
const formData = ref({
  id: undefined,
  code: undefined,
  name: undefined,
  managerId: undefined,
  status: undefined,
  sort: undefined,
  remark: undefined
})
const formRules = reactive({
  code: [{ required: true, message: '类型编码不能为空', trigger: 'blur' }],
  name: [{ required: true, message: '类型名称不能为空', trigger: 'blur' }],
  status: [{ required: true, message: '状态不能为空', trigger: 'change' }]
})
const formRef = ref() // 表单 Ref

/** 库管员候选人 */
interface ManagerOption {
  id: number
  label: string
  invalid?: boolean
}
const candidateLoading = ref(false) // 候选人加载中
const candidates = ref<PlasmidTypeManagerCandidateVO[]>([]) // 候选人列表

/** 下拉选项：候选人 + 当前已失效的库管员（如有） */
const managerOptions = computed<ManagerOption[]>(() => {
  const options: ManagerOption[] = candidates.value.map((item) => ({
    id: item.id,
    label: `${item.nickname}（${item.username}）`
  }))
  const currentId = formData.value.managerId
  if (currentId && !candidates.value.some((item) => item.id === currentId)) {
    options.unshift({ id: currentId, label: `ID：${currentId}（已失效）`, invalid: true })
  }
  return options
})

/** 当前库管员是否已失效：有值但不在候选列表中 */
const managerInvalid = computed(() => {
  const currentId = formData.value.managerId
  return !!currentId && !candidates.value.some((item) => item.id === currentId)
})

/** 加载库管员候选人 */
const loadCandidates = async () => {
  candidateLoading.value = true
  try {
    candidates.value = await PlasmidTypeApi.getManagerCandidates()
  } finally {
    candidateLoading.value = false
  }
}

/** 打开弹窗 */
const open = async (type: string, id?: number) => {
  dialogVisible.value = true
  dialogTitle.value = t('action.' + type)
  formType.value = type
  resetForm()
  // 加载库管员候选人
  loadCandidates()
  // 修改时，设置数据
  if (id) {
    formLoading.value = true
    try {
      formData.value = await PlasmidTypeApi.getPlasmidType(id)
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
    const data = formData.value as unknown as PlasmidTypeVO
    if (formType.value === 'create') {
      await PlasmidTypeApi.createPlasmidType(data)
      message.success(t('common.createSuccess'))
    } else {
      await PlasmidTypeApi.updatePlasmidType(data)
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
  formData.value = {
    id: undefined,
    code: undefined,
    name: undefined,
    managerId: undefined,
    status: undefined,
    sort: undefined,
    remark: undefined
  }
  formRef.value?.resetFields()
}
</script>

<style scoped>
.manager-invalid-tip {
  margin-top: 4px;
  font-size: 12px;
  line-height: 1.5;
  color: var(--el-color-danger);
}
</style>
