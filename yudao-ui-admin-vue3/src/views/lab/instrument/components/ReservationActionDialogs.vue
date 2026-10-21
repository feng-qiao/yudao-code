<template>
  <!-- 取消预约（23 §6.3：本人开始前/管理侧任意时刻；管理侧原因必填） -->
  <Dialog title="取消预约" v-model="cancelVisible" width="520px" :close-on-click-modal="false">
    <el-descriptions :column="1" border size="small">
      <el-descriptions-item label="预约单号">{{ current?.reservationNo }}</el-descriptions-item>
      <el-descriptions-item label="设备">{{ current?.deviceName || '-' }}</el-descriptions-item>
      <el-descriptions-item label="预约时间">{{ timeRange(current) }}</el-descriptions-item>
    </el-descriptions>
    <el-alert
      type="warning"
      :closable="false"
      class="!mt-10px"
      title="取消成功后该预约不再占用对应时段；已取消的预约不可恢复。"
    />
    <el-form label-width="90px" class="mt-12px">
      <el-form-item label="取消原因" :required="isManagerSide">
        <el-input
          v-model="cancelReason"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          :placeholder="isManagerSide ? '负责人/管理员代取消时必填' : '选填'"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="cancelVisible = false" :disabled="actionLoading">取 消</el-button>
      <el-button type="danger" :loading="actionLoading" @click="submitCancel">确认取消</el-button>
    </template>
  </Dialog>

  <!-- 调整预约（23 §6.6：仅 PENDING；锁内全链复核；换设备须对新设备有资质与授权） -->
  <Dialog title="调整预约" v-model="adjustVisible" width="560px" :close-on-click-modal="false">
    <el-descriptions :column="1" border size="small">
      <el-descriptions-item label="预约单号">{{ current?.reservationNo }}</el-descriptions-item>
      <el-descriptions-item label="当前设备">{{ current?.deviceName || '-' }}</el-descriptions-item>
      <el-descriptions-item label="当前时间">{{ timeRange(current) }}</el-descriptions-item>
    </el-descriptions>
    <el-form label-width="100px" class="mt-12px">
      <el-form-item label="更换设备">
        <el-select
          v-model="adjustForm.newDeviceId"
          placeholder="不更换设备（仅调整时间）"
          clearable
          filterable
          class="w-full"
        >
          <el-option
            v-for="d in deviceOptions"
            :key="d.id"
            :value="d.id!"
            :label="`${d.name}（${d.deviceNo}）`"
            :disabled="d.id === current?.deviceId"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="新开始时间" required>
        <el-date-picker
          v-model="adjustForm.startTime"
          type="datetime"
          value-format="YYYY-MM-DD HH:mm:ss"
          placeholder="选择新开始时间"
          class="!w-full"
        />
      </el-form-item>
      <el-form-item label="新结束时间" required>
        <el-date-picker
          v-model="adjustForm.endTime"
          type="datetime"
          value-format="YYYY-MM-DD HH:mm:ss"
          placeholder="选择新结束时间"
          class="!w-full"
        />
      </el-form-item>
      <el-form-item label="调整原因" :required="isManagerSide">
        <el-input
          v-model="adjustForm.reason"
          type="textarea"
          :rows="2"
          maxlength="500"
          show-word-limit
          :placeholder="isManagerSide ? '负责人/管理员代调整时必填' : '选填'"
        />
      </el-form-item>
    </el-form>
    <el-alert
      type="info"
      :closable="false"
      title="提交后服务端将重新校验预约人资质、暂停状态、仪器状态、开放时段与时间冲突；校验不通过则原预约保持不变。"
    />
    <template #footer>
      <el-button @click="adjustVisible = false" :disabled="actionLoading">取 消</el-button>
      <el-button type="primary" :loading="actionLoading" @click="submitAdjust">确认调整</el-button>
    </template>
  </Dialog>

  <!-- 手工登记完成（23 §6.4，B11：仅 PENDING；实际起止必填） -->
  <Dialog title="手工登记完成" v-model="finishVisible" width="520px" :close-on-click-modal="false">
    <el-descriptions :column="1" border size="small">
      <el-descriptions-item label="预约单号">{{ current?.reservationNo }}</el-descriptions-item>
      <el-descriptions-item label="设备">{{ current?.deviceName || '-' }}</el-descriptions-item>
      <el-descriptions-item label="预约人">{{ current?.userName || '-' }}</el-descriptions-item>
      <el-descriptions-item label="预约时间">{{ timeRange(current) }}</el-descriptions-item>
    </el-descriptions>
    <el-form label-width="100px" class="mt-12px">
      <el-form-item label="实际开始" required>
        <el-date-picker
          v-model="finishForm.actualStartTime"
          type="datetime"
          value-format="YYYY-MM-DD HH:mm:ss"
          placeholder="实际开始使用的时间"
          class="!w-full"
        />
      </el-form-item>
      <el-form-item label="实际结束" required>
        <el-date-picker
          v-model="finishForm.actualEndTime"
          type="datetime"
          value-format="YYYY-MM-DD HH:mm:ss"
          placeholder="实际结束使用的时间"
          class="!w-full"
        />
      </el-form-item>
      <el-form-item label="备注">
        <el-input v-model="finishForm.remark" type="textarea" :rows="2" maxlength="500" show-word-limit placeholder="选填" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="finishVisible = false" :disabled="actionLoading">取 消</el-button>
      <el-button type="primary" :loading="actionLoading" @click="submitFinish">确认完成</el-button>
    </template>
  </Dialog>

  <!-- 作废预约（23 §6.5：仅管理侧；仅 PENDING；原因必填） -->
  <Dialog title="作废预约" v-model="voidVisible" width="520px" :close-on-click-modal="false">
    <el-descriptions :column="1" border size="small">
      <el-descriptions-item label="预约单号">{{ current?.reservationNo }}</el-descriptions-item>
      <el-descriptions-item label="设备">{{ current?.deviceName || '-' }}</el-descriptions-item>
      <el-descriptions-item label="预约人">{{ current?.userName || '-' }}</el-descriptions-item>
      <el-descriptions-item label="预约时间">{{ timeRange(current) }}</el-descriptions-item>
    </el-descriptions>
    <el-alert
      type="error"
      :closable="false"
      class="!mt-10px"
      title="作废用于异常预约的纠错处理：作废后不再占用时段，且不可恢复。作废原因必填并记入操作历史。"
    />
    <el-form label-width="90px" class="mt-12px">
      <el-form-item label="作废原因" required>
        <el-input
          v-model="voidReason"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          placeholder="必填，将记入操作历史"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="voidVisible = false" :disabled="actionLoading">取 消</el-button>
      <el-button type="danger" :loading="actionLoading" @click="submitVoid">确认作废</el-button>
    </template>
  </Dialog>

  <!-- 操作历史（23 §4.2 history-list；本人或授权负责人/管理员可见） -->
  <el-drawer v-model="historyVisible" title="操作历史" size="520px">
    <div v-loading="historyLoading" class="min-h-120px">
      <el-timeline v-if="historyList.length" class="pl-4px">
        <el-timeline-item
          v-for="h in historyList"
          :key="h.id"
          :timestamp="fmtTime(h.actionTime)"
          placement="top"
        >
          <div class="flex items-center gap-8px">
            <el-tag size="small" :type="actionMeta(h.action).type">{{ actionMeta(h.action).label }}</el-tag>
            <span class="text-13px">{{ h.operatorName || '-' }}</span>
            <span class="text-12px text-[var(--el-text-color-secondary)]">{{ roleText(h.operatorRole) }}</span>
          </div>
          <div v-if="h.beforeStatus !== h.afterStatus && h.afterStatus" class="text-12px mt-4px">
            状态：{{ statusText(h.beforeStatus) }} → {{ statusText(h.afterStatus) }}
          </div>
          <div v-if="h.afterStartTime" class="text-12px mt-2px">
            时段：{{ h.beforeStartTime ? fmtTime(h.beforeStartTime) + ' ~ ' + fmtTime(h.beforeEndTime) : '-' }}
            → {{ fmtTime(h.afterStartTime) }} ~ {{ fmtTime(h.afterEndTime) }}
          </div>
          <div v-if="h.reason" class="text-12px mt-2px">原因：{{ h.reason }}</div>
          <div v-if="h.remark" class="text-12px mt-2px text-[var(--el-text-color-secondary)]">备注：{{ h.remark }}</div>
        </el-timeline-item>
      </el-timeline>
      <el-empty v-else-if="!historyLoading" description="暂无操作记录" :image-size="70" />
    </div>
  </el-drawer>
</template>

<script setup lang="ts">
import dayjs from 'dayjs'
import { useUserStore } from '@/store/modules/user'
import { InstrumentDeviceApi, InstrumentDeviceVO } from '@/api/lab/instrument/device'
import {
  InstrumentReservationApi,
  ReservationRespVO,
  ReservationHistoryRespVO,
  RESERVATION_STATUS
} from '@/api/lab/instrument/reservation'

defineOptions({ name: 'LabInstrumentReservationActionDialogs' })

const message = useMessage()
const emit = defineEmits<{ (e: 'success'): void }>()

const userStore = useUserStore()
const actionLoading = ref(false)
const current = ref<ReservationRespVO>()

/** 管理侧操作（非本人预约）：取消/调整原因必填；本人免填（22 A3 矩阵） */
const isManagerSide = computed(() => !!current.value && current.value.userId !== userStore.user.id)

const fmtTime = (t?: string) => (t ? dayjs(t).format('YYYY-MM-DD HH:mm') : '-')
const timeRange = (r?: ReservationRespVO) => (r ? `${fmtTime(r.startTime)} ~ ${fmtTime(r.endTime)}` : '-')
const statusText = (s?: string) =>
  (Object.values(RESERVATION_STATUS).find((x) => x.value === s) as any)?.label || s || '-'
const roleText = (v?: string) =>
  ({ USER: '本人', MANAGER: '负责人', ADMIN: '管理员' } as Record<string, string>)[v || ''] || v || '-'
const actionMeta = (a?: string): { label: string; type: 'success' | 'info' | 'warning' | 'danger' | 'primary' } =>
  (
    {
      CREATE: { label: '创建', type: 'primary' },
      ADJUST: { label: '调整', type: 'warning' },
      CANCEL: { label: '取消', type: 'info' },
      FINISH: { label: '完成', type: 'success' },
      VOID: { label: '作废', type: 'danger' }
    } as Record<string, any>
  )[a || ''] || { label: a || '-', type: 'info' }

// ========== 取消 ==========
const cancelVisible = ref(false)
const cancelReason = ref('')
const openCancel = (row: ReservationRespVO) => {
  current.value = row
  cancelReason.value = ''
  cancelVisible.value = true
}
const submitCancel = async () => {
  if (!current.value?.id) return
  if (isManagerSide.value && !cancelReason.value.trim()) {
    message.warning('负责人/管理员代取消时请填写取消原因')
    return
  }
  actionLoading.value = true
  try {
    await InstrumentReservationApi.cancel({ id: current.value.id, reason: cancelReason.value.trim() || undefined })
    message.success('预约已取消')
    cancelVisible.value = false
    emit('success')
  } finally {
    actionLoading.value = false
  }
}

// ========== 调整 ==========
const adjustVisible = ref(false)
const deviceOptions = ref<InstrumentDeviceVO[]>([])
const adjustForm = reactive({
  newDeviceId: undefined as number | undefined,
  startTime: '',
  endTime: '',
  reason: ''
})
const openAdjust = async (row: ReservationRespVO) => {
  current.value = row
  adjustForm.newDeviceId = undefined
  adjustForm.startTime = row.startTime ? dayjs(row.startTime).format('YYYY-MM-DD HH:mm:ss') : ''
  adjustForm.endTime = row.endTime ? dayjs(row.endTime).format('YYYY-MM-DD HH:mm:ss') : ''
  adjustForm.reason = ''
  adjustVisible.value = true
  // 候选设备（换设备调整用；服务端复核预约人资质与开放时段，校验不通过不破坏原预约）
  try {
    const data = await InstrumentDeviceApi.getPage({ pageNo: 1, pageSize: 100, status: 'NORMAL' })
    deviceOptions.value = data.list || []
  } catch {
    deviceOptions.value = []
  }
}
const submitAdjust = async () => {
  if (!current.value?.id) return
  if (!adjustForm.startTime || !adjustForm.endTime) {
    message.warning('请选择新的起止时间')
    return
  }
  if (adjustForm.endTime <= adjustForm.startTime) {
    message.warning('结束时间必须晚于开始时间')
    return
  }
  if (isManagerSide.value && !adjustForm.reason.trim()) {
    message.warning('负责人/管理员代调整时请填写调整原因')
    return
  }
  actionLoading.value = true
  try {
    await InstrumentReservationApi.adjust({
      id: current.value.id,
      newDeviceId: adjustForm.newDeviceId,
      startTime: adjustForm.startTime,
      endTime: adjustForm.endTime,
      reason: adjustForm.reason.trim() || undefined
    })
    message.success('预约已调整')
    adjustVisible.value = false
    emit('success')
  } finally {
    actionLoading.value = false
  }
}

// ========== 完成 ==========
const finishVisible = ref(false)
const finishForm = reactive({ actualStartTime: '', actualEndTime: '', remark: '' })
const openFinish = (row: ReservationRespVO) => {
  current.value = row
  finishForm.actualStartTime = row.startTime ? dayjs(row.startTime).format('YYYY-MM-DD HH:mm:ss') : ''
  finishForm.actualEndTime = row.endTime ? dayjs(row.endTime).format('YYYY-MM-DD HH:mm:ss') : ''
  finishForm.remark = ''
  finishVisible.value = true
}
const submitFinish = async () => {
  if (!current.value?.id) return
  if (!finishForm.actualStartTime || !finishForm.actualEndTime) {
    message.warning('请填写实际使用起止时间')
    return
  }
  if (finishForm.actualEndTime <= finishForm.actualStartTime) {
    message.warning('实际结束时间必须晚于实际开始时间')
    return
  }
  actionLoading.value = true
  try {
    await InstrumentReservationApi.finish({
      id: current.value.id,
      actualStartTime: finishForm.actualStartTime,
      actualEndTime: finishForm.actualEndTime,
      remark: finishForm.remark.trim() || undefined
    })
    message.success('已登记完成')
    finishVisible.value = false
    emit('success')
  } finally {
    actionLoading.value = false
  }
}

// ========== 作废 ==========
const voidVisible = ref(false)
const voidReason = ref('')
const openVoid = (row: ReservationRespVO) => {
  current.value = row
  voidReason.value = ''
  voidVisible.value = true
}
const submitVoid = async () => {
  if (!current.value?.id) return
  if (!voidReason.value.trim()) {
    message.warning('请填写作废原因')
    return
  }
  await message.confirm('确认作废该预约？作废后不再占用时段且不可恢复。')
  actionLoading.value = true
  try {
    await InstrumentReservationApi.void({ id: current.value.id, reason: voidReason.value.trim() })
    message.success('预约已作废')
    voidVisible.value = false
    emit('success')
  } finally {
    actionLoading.value = false
  }
}

// ========== 操作历史 ==========
const historyVisible = ref(false)
const historyLoading = ref(false)
const historyList = ref<ReservationHistoryRespVO[]>([])
const openHistory = async (row: ReservationRespVO) => {
  current.value = row
  historyVisible.value = true
  historyLoading.value = true
  historyList.value = []
  try {
    historyList.value = (await InstrumentReservationApi.getHistoryList(row.id)) || []
  } finally {
    historyLoading.value = false
  }
}

defineExpose({ openCancel, openAdjust, openFinish, openVoid, openHistory })
</script>
