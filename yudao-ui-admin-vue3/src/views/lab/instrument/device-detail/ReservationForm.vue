<template>
  <Dialog title="预约仪器" v-model="dialogVisible" width="760px" :close-on-click-modal="false">
    <el-alert
      type="info"
      :closable="false"
      class="!mb-12px"
      title="预约创建处于受控开放阶段：若提交时服务端提示功能未开放（116），请等待正式上线通知。"
    />
    <el-form label-width="80px" class="-mb-15px" :inline="true">
      <el-form-item label="设备">
        <span class="font-bold">{{ device.name }}</span>
        <span class="text-[var(--el-text-color-secondary)] ml-6px">{{ device.deviceNo }}</span>
      </el-form-item>
      <el-form-item label="预约日期">
        <el-date-picker
          v-model="selectedDate"
          type="date"
          value-format="YYYY-MM-DD"
          :clearable="false"
          :disabled-date="disabledDate"
          placeholder="选择日期"
          @change="loadDay"
        />
      </el-form-item>
    </el-form>

    <div v-loading="dayLoading" class="min-h-120px">
      <el-alert v-if="dayReason" type="warning" :closable="false" :title="dayReason" />
      <template v-else-if="selectedDate && !dayLoading">
        <!-- 当日开放范围（窗口设备含归属窗口，U3/U5） -->
        <div class="section-label">当日开放范围</div>
        <div v-if="openRanges.length" class="mb-8px">
          <span v-for="(r, i) in openRanges" :key="i" class="range-item">
            <el-tag size="small" type="success">{{ r.windowName || '开放时段' }}</el-tag>
            {{ fmtHm(r.start) }} ~ {{ fmtHm(r.end) }}
          </span>
        </div>
        <el-alert v-else type="info" :closable="false" title="当日无开放时段" class="!mb-8px" />

        <!-- 可预约槽位（点选开始与结束） -->
        <div class="section-label">
          可预约时段<span class="section-tip">先点选开始槽位，再点选结束槽位（右开）</span>
        </div>
        <div v-if="slots.length" class="slot-grid">
          <el-tooltip
            v-for="(s, i) in slots"
            :key="i"
            :disabled="s.available"
            :content="s.reasonMsg || '不可预约'"
            placement="top"
          >
            <span
              class="slot"
              :class="slotClass(s)"
              @click="clickSlot(s)"
            >
              {{ fmtHm(s.start) }}
            </span>
          </el-tooltip>
        </div>
        <el-alert v-else type="info" :closable="false" title="当日无可预约槽位（被占用或超出可约范围）" />

        <!-- 当日占用明细 -->
        <template v-if="occupied.length">
          <div class="section-label">当日占用</div>
          <div class="occupied-list">
            <div v-for="(o, i) in occupied" :key="i" class="occupied-item">
              <el-tag size="small" :type="occupiedTagType(o.type)">{{ occupiedTypeText(o.type) }}</el-tag>
              <span class="ml-6px">{{ o.brief }}</span>
            </div>
          </div>
        </template>
      </template>
    </div>

    <!-- 选择与确认 -->
    <el-form label-width="90px" class="mt-12px">
      <el-row :gutter="12">
        <el-col :span="12">
          <el-form-item label="开始时间">
            <el-input :model-value="startSlot ? fmtFull(startSlot.start) : ''" readonly placeholder="点选上方槽位" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="结束时间">
            <el-input :model-value="endSlot ? fmtFull(endSlot.end) : ''" readonly placeholder="点选上方槽位" />
          </el-form-item>
        </el-col>
      </el-row>
      <el-form-item v-if="isWindowDevice" label="归属窗口">
        <el-tag v-if="matchedRange" type="success">{{ matchedRange.windowName }}</el-tag>
        <span v-else class="text-[var(--el-color-danger)] text-13px">
          {{ startSlot && endSlot ? '所选时段未落在单一开放窗口内（禁止跨窗口预约）' : '选择时段后自动判定' }}
        </span>
      </el-form-item>
      <el-form-item label="时长">
        <span>{{ durationMinutes > 0 ? durationMinutes + ' 分钟' : '-' }}</span>
      </el-form-item>
      <el-form-item label="用途">
        <el-input v-model="form.purpose" maxlength="200" show-word-limit placeholder="请输入用途（选填）" />
      </el-form-item>
      <el-form-item label="备注">
        <el-input v-model="form.remark" type="textarea" :rows="2" maxlength="500" show-word-limit placeholder="选填" />
      </el-form-item>
    </el-form>

    <template #footer>
      <el-button @click="dialogVisible = false" :disabled="submitLoading">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" :disabled="!canSubmit" @click="submit">
        确认预约
      </el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import dayjs from 'dayjs'
import { InstrumentDeviceVO } from '@/api/lab/instrument/device'
import { InstrumentReservationApi } from '@/api/lab/instrument/reservation'

defineOptions({ name: 'LabInstrumentReservationForm' })

type Slot = {
  start: string
  end: string
  available: boolean
  reasonCode?: number
  reasonMsg?: string
}
type Range = { start: string; end: string; windowId?: number; windowName?: string }
type Occupied = { type: string; start: string; end: string; brief: string }

const message = useMessage()
const emit = defineEmits<{ (e: 'success'): void }>()

const dialogVisible = ref(false)
const device = ref<InstrumentDeviceVO>({} as InstrumentDeviceVO)
const selectedDate = ref('')
const dayLoading = ref(false)
const dayReason = ref('')
const openRanges = ref<Range[]>([])
const occupied = ref<Occupied[]>([])
const slots = ref<Slot[]>([])
const startSlot = ref<Slot | null>(null)
const endSlot = ref<Slot | null>(null)
const submitLoading = ref(false)
const form = reactive({ purpose: '', remark: '' })

/** 窗口设备（与后端 DeviceCategoryEnum.MICROPLATE_READER 一致） */
const isWindowDevice = computed(() => device.value.category === 'MICROPLATE_READER')

/** 所选区间归属的开放范围（U3：同设备同时刻窗口不重叠，命中即唯一窗口；跨范围=不合法） */
const matchedRange = computed<Range | null>(() => {
  if (!startSlot.value || !endSlot.value) return null
  const s = startSlot.value.start
  const e = endSlot.value.end
  return openRanges.value.find((r) => r.start <= s && r.end >= e) || null
})

const durationMinutes = computed(() => {
  if (!startSlot.value || !endSlot.value) return 0
  return dayjs(endSlot.value.end).diff(dayjs(startSlot.value.start), 'minute')
})

const canSubmit = computed(() => {
  if (!startSlot.value || !endSlot.value || submitLoading.value) return false
  if (!matchedRange.value) return false // 未落在单一开放范围（含跨窗口）
  if (isWindowDevice.value && !matchedRange.value.windowId) return false
  return true
})

const fmtHm = (t: string) => dayjs(t).format('HH:mm')
const fmtFull = (t: string) => dayjs(t).format('YYYY-MM-DD HH:mm')

/** 今日之前的日期禁止选择（可约范围上限由服务端规则判定，不在前端硬编码） */
const disabledDate = (d: Date) => dayjs(d).isBefore(dayjs().startOf('day'))

const open = (dev: InstrumentDeviceVO) => {
  device.value = dev
  selectedDate.value = dayjs().format('YYYY-MM-DD')
  startSlot.value = null
  endSlot.value = null
  form.purpose = ''
  form.remark = ''
  dialogVisible.value = true
  loadDay()
}
defineExpose({ open })

/** 加载当日日历 + 空闲槽（综合设备状态/规则/窗口/占用，C5） */
const loadDay = async () => {
  if (!selectedDate.value || !device.value.id) return
  dayLoading.value = true
  dayReason.value = ''
  openRanges.value = []
  occupied.value = []
  slots.value = []
  startSlot.value = null
  endSlot.value = null
  try {
    const date = selectedDate.value
    const [calendarItems, freeSlots] = await Promise.all([
      InstrumentReservationApi.getCalendar(device.value.id, date, date),
      InstrumentReservationApi.getFreeSlots(device.value.id, date)
    ])
    const item = (calendarItems || [])[0]
    if (item) {
      openRanges.value = item.openRanges || []
      occupied.value = item.occupied || []
      if (item.reasonCode && !openRanges.value.length) {
        dayReason.value = item.reasonMsg || '当日未开放'
      }
    }
    if (freeSlots) {
      slots.value = freeSlots.slots || []
      if (freeSlots.reasonCode && !slots.value.length && !dayReason.value) {
        dayReason.value = freeSlots.reasonMsg || '当日未开放'
      }
    }
  } finally {
    dayLoading.value = false
  }
}

const slotClass = (s: Slot) => ({
  'slot-disabled': !s.available,
  'slot-available': s.available,
  'slot-picked': s === startSlot.value || s === endSlot.value,
  'slot-in-range':
    startSlot.value && endSlot.value && s.start >= startSlot.value.start && s.end <= endSlot.value.end
})

/** 点选槽位：第一次=开始，第二次=结束（校验区间连续可约），其后重选 */
const clickSlot = (s: Slot) => {
  if (!s.available) return
  if (!startSlot.value || (startSlot.value && endSlot.value)) {
    startSlot.value = s
    endSlot.value = null
    return
  }
  if (s.start <= startSlot.value.start) {
    startSlot.value = s
    return
  }
  // 结束槽位：要求 [start, s.end) 覆盖的槽全部可约（防跨越占用区间）
  const coveredUnavailable = slots.value.some(
    (x) => x.start >= startSlot.value!.start && x.end <= s.end && !x.available
  )
  // 占用槽在后端已被整个剔除；此处再校验槽序列无断档
  const coveredAny = slots.value.filter((x) => x.start >= startSlot.value!.start && x.end <= s.end)
  const gapMinutes = coveredAny.reduce(
    (acc, x) => acc + dayjs(x.end).diff(dayjs(x.start), 'minute'),
    0
  )
  const expectMinutes = dayjs(s.end).diff(dayjs(startSlot.value.start), 'minute')
  if (coveredUnavailable || gapMinutes !== expectMinutes) {
    message.warning('所选区间包含不可预约时段，请重新选择')
    return
  }
  endSlot.value = s
}

const occupiedTypeText = (t: string) =>
  ({ RESERVATION: '预约', MAINTENANCE: '维护' } as Record<string, string>)[t] || t
const occupiedTagType = (t: string): 'primary' | 'warning' | 'danger' =>
  (({ RESERVATION: 'primary', MAINTENANCE: 'warning' }) as Record<string, any>)[t] || 'primary'

/** 提交（C6：提交中状态 + 防重复提交；服务端 @Idempotent 3 秒兜底） */
const submit = async () => {
  if (!startSlot.value || !endSlot.value || !device.value.id) return
  submitLoading.value = true
  try {
    await InstrumentReservationApi.create({
      deviceId: device.value.id,
      windowId: isWindowDevice.value ? matchedRange.value?.windowId : undefined,
      // 服务端全局 Jackson 约定：请求体 LocalDateTime 必须为 Epoch 毫秒（yyyy-MM-dd HH:mm:ss 字符串会被解析为 0 → 089）
      startTime: dayjs(startSlot.value.start).valueOf(),
      endTime: dayjs(endSlot.value.end).valueOf(),
      purpose: form.purpose || undefined,
      remark: form.remark || undefined
    })
    message.success('预约提交成功，可在「我的预约」查看')
    dialogVisible.value = false
    emit('success')
  } finally {
    submitLoading.value = false
  }
}
</script>

<style scoped>
.section-label {
  font-weight: bold;
  font-size: 13px;
  margin: 10px 0 6px;
}
.section-tip {
  font-weight: normal;
  font-size: 12px;
  color: var(--el-text-color-secondary);
  margin-left: 8px;
}
.range-item {
  margin-right: 12px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.slot-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.slot {
  display: inline-block;
  padding: 4px 10px;
  border-radius: 4px;
  font-size: 13px;
  cursor: pointer;
  user-select: none;
  border: 1px solid var(--el-border-color);
}
.slot-available {
  background: var(--el-color-success-light-9);
  border-color: var(--el-color-success-light-5);
  color: var(--el-color-success-dark-2);
}
.slot-available:hover {
  background: var(--el-color-success-light-7);
}
.slot-disabled {
  background: var(--el-fill-color-light);
  color: var(--el-text-color-placeholder);
  cursor: not-allowed;
}
.slot-picked {
  background: var(--el-color-primary) !important;
  border-color: var(--el-color-primary);
  color: #fff;
}
.slot-in-range {
  background: var(--el-color-primary-light-7);
  border-color: var(--el-color-primary-light-3);
}
.occupied-list {
  max-height: 140px;
  overflow-y: auto;
}
.occupied-item {
  display: flex;
  align-items: center;
  margin-bottom: 4px;
  font-size: 13px;
}
</style>
