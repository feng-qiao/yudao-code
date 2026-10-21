<template>
  <Dialog title="指派维修负责人" v-model="visible" width="480px">
    <el-form ref="formRef" :model="form" :rules="rules" label-width="100px">
      <el-form-item label="工单号">
        {{ orderRow?.orderNo }}
      </el-form-item>
      <el-form-item label="设备">
        设备 ID {{ orderRow?.deviceId }}
      </el-form-item>
      <el-form-item label="维修负责人" prop="assigneeUserId">
        <el-select
          v-model="form.assigneeUserId"
          filterable
          remote
          reserve-keyword
          clearable
          placeholder="输入姓名搜索"
          :remote-method="searchCandidates"
          :loading="candidateLoading"
          class="!w-full"
          @visible-change="onCandidateVisible"
        >
          <el-option
            v-for="u in candidates"
            :key="u.id"
            :label="u.nickname + '（' + u.username + '）'"
            :value="u.id"
          >
            {{ u.nickname }}（{{ u.username }}<span v-if="u.mobile">，{{ u.mobile }}</span>）
          </el-option>
        </el-select>
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="visible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="handleSubmit">确认指派</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { InstrumentRepairOrderApi } from '@/api/lab/instrument/repair-order'
import { InstrumentManagerApi } from '@/api/lab/instrument/manager'
import type { RepairOrderVO } from '@/api/lab/instrument/repair-order'

defineOptions({ name: 'RepairOrderAssignDialog' })

const props = defineProps<{
  visible: boolean
  orderRow: RepairOrderVO | null
}>()
const emit = defineEmits<{
  (e: 'update:visible', v: boolean): void
  (e: 'success'): void
}>()

const message = useMessage()
const formRef = ref()
const submitLoading = ref(false)
const candidateLoading = ref(false)

const form = reactive({
  assigneeUserId: undefined as number | undefined
})

const rules = {
  assigneeUserId: [{ required: true, message: '请选择维修负责人', trigger: 'change' }]
}

const candidates = ref<any[]>([])

const searchCandidates = async (keyword: string) => {
  candidateLoading.value = true
  try {
    // 复用 manager 模块的候选接口，或独立的维修负责人候选
    candidates.value = (await InstrumentManagerApi.candidates(keyword)) || []
  } finally {
    candidateLoading.value = false
  }
}

const onCandidateVisible = (visible: boolean) => {
  if (visible && candidates.value.length === 0) searchCandidates('')
}

// 每次打开重置
watch(
  () => props.visible,
  (v) => {
    if (v) {
      form.assigneeUserId = props.orderRow?.assigneeUserId
      candidates.value = []
    }
  }
)

const handleSubmit = async () => {
  await formRef.value.validate()
  submitLoading.value = true
  try {
    await InstrumentRepairOrderApi.assign({
      id: props.orderRow!.id!,
      assigneeUserId: form.assigneeUserId!
    })
    message.success('指派成功')
    emit('update:visible', false)
    emit('success')
  } finally {
    submitLoading.value = false
  }
}
</script>
