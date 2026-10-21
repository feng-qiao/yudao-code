<template>
  <Dialog title="恢复验收" v-model="visible" width="520px">
    <el-form label-width="100px">
      <el-form-item label="工单号">{{ orderRow?.orderNo }}</el-form-item>
      <el-form-item label="设备 ID">{{ orderRow?.deviceId }}</el-form-item>
      <el-form-item label="维修负责人">
        {{ orderRow?.assigneeName || '—' }}
      </el-form-item>
      <el-form-item label="验收结果" required>
        <el-radio-group v-model="restoreType">
          <el-radio value="APPROVED">验收通过，设备恢复使用</el-radio>
          <el-radio value="REJECTED">退回维修，需重新处理</el-radio>
        </el-radio-group>
      </el-form-item>
      <el-form-item label="验收意见" required>
        <el-input
          v-model="opinion"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          placeholder="请填写验收意见；退回维修时请说明原因"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="visible = false">取 消</el-button>
      <el-button
        v-if="restoreType === 'APPROVED'"
        type="success"
        :loading="submitLoading"
        @click="handleSubmit"
      >
        验收通过
      </el-button>
      <el-button
        v-else
        type="danger"
        :loading="submitLoading"
        @click="handleSubmit"
      >
        退回维修
      </el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { InstrumentRepairOrderApi } from '@/api/lab/instrument/repair-order'
import type { RepairOrderVO } from '@/api/lab/instrument/repair-order'

defineOptions({ name: 'RepairOrderRestoreApproveDialog' })

const props = defineProps<{
  visible: boolean
  orderRow: RepairOrderVO | null
}>()
const emit = defineEmits<{
  (e: 'update:visible', v: boolean): void
  (e: 'success'): void
}>()

const message = useMessage()
const submitLoading = ref(false)
const restoreType = ref<'APPROVED' | 'REJECTED'>('APPROVED')
const opinion = ref('')

watch(
  () => props.visible,
  (v) => {
    if (v) {
      restoreType.value = 'APPROVED'
      opinion.value = ''
    }
  }
)

const handleSubmit = async () => {
  if (!opinion.value.trim()) {
    message.warning('验收意见不能为空')
    return
  }
  submitLoading.value = true
  try {
    if (restoreType.value === 'APPROVED') {
      await InstrumentRepairOrderApi.restoreApprove(props.orderRow!.id!, opinion.value.trim())
      message.success('验收通过，设备已恢复使用')
    } else {
      await InstrumentRepairOrderApi.restoreReject(props.orderRow!.id!, opinion.value.trim())
      message.success('已退回维修负责人')
    }
    emit('update:visible', false)
    emit('success')
  } finally {
    submitLoading.value = false
  }
}
</script>
