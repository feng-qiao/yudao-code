<template>
  <ContentWrap>
    <!-- 设备选择（两个 Tab 共享） -->
    <el-form :inline="true" label-width="80px">
      <el-form-item label="仪器设备">
        <el-select
          v-model="deviceId"
          filterable
          clearable
          placeholder="请选择仪器设备"
          class="!w-320px"
          @change="onDeviceChange"
        >
          <el-option
            v-for="d in deviceOptions"
            :key="d.id"
            :label="`${d.name}（${d.deviceNo}）`"
            :value="d.id!"
          />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-tag v-if="deviceId && ruleLoaded && !hasRule" type="warning">该设备尚未配置预约规则</el-tag>
        <el-tag v-else-if="deviceId && ruleForm.enabled" type="success">规则已启用</el-tag>
        <el-tag v-else-if="deviceId && ruleLoaded" type="info">规则未启用（设备不开放预约）</el-tag>
      </el-form-item>
    </el-form>

    <el-tabs v-model="activeTab">
      <el-tab-pane label="预约规则" name="rule" />
      <el-tab-pane label="开放窗口" name="window" />
    </el-tabs>

    <!-- 预约规则 -->
    <template v-if="activeTab === 'rule'">
      <el-alert
        v-if="deviceId"
        type="info"
        :closable="false"
        class="mb-15px"
        title="未配置或未启用规则时设备不开放预约；启用规则必须完整配置时间粒度与最短时长（特殊设备参数由管理员显式设置，系统不预设默认值）。"
      />
      <el-empty v-if="!deviceId" description="请先选择仪器设备" />
      <el-form
        v-else
        ref="ruleFormRef"
        v-loading="ruleLoading"
        :model="ruleForm"
        :rules="ruleRules"
        label-width="160px"
        style="max-width: 720px"
      >
        <el-form-item label="规则启用" prop="enabled">
          <el-switch v-model="ruleForm.enabled" />
        </el-form-item>
        <el-form-item label="时间粒度（分钟）" prop="granularityMinutes">
          <el-input-number
            v-model="ruleForm.granularityMinutes"
            :min="1"
            :step="5"
            step-strictly
            controls-position="right"
            placeholder="启用预约时必填"
            class="!w-200px"
          />
        </el-form-item>
        <el-form-item label="最短预约时长（分钟）" prop="minDurationMinutes">
          <el-input-number
            v-model="ruleForm.minDurationMinutes"
            :min="1"
            :step="5"
            step-strictly
            controls-position="right"
            placeholder="启用预约时必填"
            class="!w-200px"
          />
        </el-form-item>
        <el-form-item label="最长预约时长（分钟）" prop="maxDurationMinutes">
          <el-input-number
            v-model="ruleForm.maxDurationMinutes"
            :min="1"
            :step="5"
            step-strictly
            controls-position="right"
            placeholder="选填"
            class="!w-200px"
          />
        </el-form-item>
        <el-form-item label="可预约起始偏移（天）" prop="bookableDaysBefore">
          <el-input-number
            v-model="ruleForm.bookableDaysBefore"
            :min="0"
            step-strictly
            controls-position="right"
            placeholder="可提前 N 天预约，选填"
            class="!w-200px"
          />
        </el-form-item>
        <el-form-item label="可预约范围（天）" prop="bookableDaysAhead">
          <el-input-number
            v-model="ruleForm.bookableDaysAhead"
            :min="0"
            step-strictly
            controls-position="right"
            placeholder="往后 N 天内可预约，选填"
            class="!w-200px"
          />
        </el-form-item>
        <el-form-item label="每周开放日" prop="openDayList">
          <el-select
            v-model="ruleForm.openDayList"
            multiple
            collapse-tags
            clearable
            placeholder="不选=每天开放"
            class="!w-320px"
          >
            <el-option v-for="d in WEEK_DAYS" :key="d.value" :label="d.label" :value="d.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="每日开放时段">
          <el-time-picker
            v-model="ruleForm.openStartTime"
            format="HH:mm"
            value-format="HH:mm"
            placeholder="开始时间"
            class="!w-140px"
          />
          <span class="mx-5px">至</span>
          <el-time-picker
            v-model="ruleForm.openEndTime"
            format="HH:mm"
            value-format="HH:mm"
            placeholder="结束时间"
            class="!w-140px"
          />
          <span class="ml-10px text-[var(--el-text-color-secondary)]">均不填=全天</span>
        </el-form-item>
        <el-form-item label="允许跨天预约" prop="allowCrossDay">
          <el-switch v-model="ruleForm.allowCrossDay" />
          <span class="ml-10px text-[var(--el-text-color-secondary)]">关闭或未设置均按不允许跨天处理</span>
        </el-form-item>
        <el-form-item label="允许开始后管理员调整" prop="allowAdminAdjustAfterStart">
          <el-switch v-model="ruleForm.allowAdminAdjustAfterStart" />
        </el-form-item>
        <el-form-item label="备注" prop="remark">
          <el-input v-model="ruleForm.remark" type="textarea" :rows="2" maxlength="500" placeholder="选填" />
        </el-form-item>
        <el-form-item>
          <el-button
            type="primary"
            :loading="ruleSaving"
            v-hasPermi="['lab:instrument:rule:update']"
            @click="saveRule"
          >
            保存规则
          </el-button>
        </el-form-item>
      </el-form>
    </template>

    <!-- 开放窗口 -->
    <template v-else>
      <el-empty v-if="!deviceId" description="请先选择仪器设备" />
      <template v-else>
        <el-alert
          type="info"
          :closable="false"
          class="mb-15px"
          title="窗口容量为该窗口累计可预约能力，容量不得低于已使用量；已有使用记录的窗口禁止删除。开放日→目标日期映射仅作文本说明，系统不做业务化推断。"
        />
        <el-button
          type="primary"
          plain
          class="mb-10px"
          v-hasPermi="['lab:instrument:rule:update']"
          @click="openWindowForm()"
        >
          <Icon icon="ep:plus" class="mr-5px" />新增窗口
        </el-button>
        <el-table v-loading="windowLoading" :data="windowList" stripe>
          <el-table-column label="窗口名称" align="center" prop="windowName" min-width="140px" show-overflow-tooltip />
          <el-table-column label="每周开放日" align="center" width="160px">
            <template #default="scope">{{ formatOpenDays(scope.row.openDays) }}</template>
          </el-table-column>
          <el-table-column label="开放时段" align="center" width="130px">
            <template #default="scope">
              {{ scope.row.openStartTime && scope.row.openEndTime ? `${scope.row.openStartTime} - ${scope.row.openEndTime}` : '不限' }}
            </template>
          </el-table-column>
          <el-table-column label="目标日期范围" align="center" width="200px">
            <template #default="scope">
              {{ scope.row.targetDateStart && scope.row.targetDateEnd ? `${scope.row.targetDateStart} ~ ${scope.row.targetDateEnd}` : '不限' }}
            </template>
          </el-table-column>
          <el-table-column label="容量/已用" align="center" width="110px">
            <template #default="scope">
              {{ scope.row.usedCount }} / {{ scope.row.capacity ?? '不限' }}
            </template>
          </el-table-column>
          <el-table-column label="状态" align="center" width="90px">
            <template #default="scope">
              <el-tag :type="scope.row.status === 'ACTIVE' ? 'success' : 'info'">
                {{ scope.row.status === 'ACTIVE' ? '可用' : '已关闭' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="排序" align="center" prop="sort" width="70px" />
          <el-table-column
            label="操作"
            align="center"
            width="130px"
            fixed="right"
            v-hasPermi="['lab:instrument:rule:update']"
          >
            <template #default="scope">
              <el-button link type="primary" @click="openWindowForm(scope.row)">修改</el-button>
              <el-button link type="danger" @click="handleWindowDelete(scope.row)">删除</el-button>
            </template>
          </el-table-column>
        </el-table>
        <Pagination
          :total="windowTotal"
          v-model:page="windowQuery.pageNo"
          v-model:limit="windowQuery.pageSize"
          @pagination="getWindowList"
        />
      </template>
    </template>
  </ContentWrap>

  <!-- 窗口新增/修改 -->
  <Dialog :title="windowForm.id ? '修改开放窗口' : '新增开放窗口'" v-model="windowVisible" width="640px">
    <el-form ref="windowFormRef" :model="windowForm" :rules="windowRules" label-width="150px">
      <el-form-item label="窗口名称" prop="windowName">
        <el-input v-model="windowForm.windowName" maxlength="100" placeholder="例如：周一至周五 白天批次" />
      </el-form-item>
      <el-form-item label="每周开放日" prop="openDayList">
        <el-select v-model="windowForm.openDayList" multiple collapse-tags clearable placeholder="不选=每天开放" class="!w-full">
          <el-option v-for="d in WEEK_DAYS" :key="d.value" :label="d.label" :value="d.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="每日开放时段">
        <el-time-picker v-model="windowForm.openStartTime" format="HH:mm" value-format="HH:mm" placeholder="开始时间" class="!w-140px" />
        <span class="mx-5px">至</span>
        <el-time-picker v-model="windowForm.openEndTime" format="HH:mm" value-format="HH:mm" placeholder="结束时间" class="!w-140px" />
      </el-form-item>
      <el-form-item label="目标日期范围">
        <el-date-picker
          v-model="windowDateRange"
          type="daterange"
          value-format="YYYY-MM-DD"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          class="!w-full"
        />
      </el-form-item>
      <el-form-item label="开放日映射说明" prop="targetWeekMapping">
        <el-input
          v-model="windowForm.targetWeekMapping"
          type="textarea"
          :rows="2"
          maxlength="500"
          placeholder="仅作文本说明（如：周一→目标日 D+1），系统不做业务化推断"
        />
      </el-form-item>
      <el-form-item label="窗口容量" prop="capacity">
        <el-input-number
          v-model="windowForm.capacity"
          :min="0"
          step-strictly
          controls-position="right"
          placeholder="空=不限"
          class="!w-200px"
        />
        <span v-if="windowForm.id" class="ml-10px text-[var(--el-text-color-secondary)]">
          已使用 {{ windowForm.usedCount ?? 0 }}，容量不得低于该值
        </span>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="windowForm.status" class="!w-200px">
          <el-option label="可用" value="ACTIVE" />
          <el-option label="已关闭" value="CLOSED" />
        </el-select>
      </el-form-item>
      <el-form-item label="排序" prop="sort">
        <el-input-number v-model="windowForm.sort" :min="0" step-strictly controls-position="right" class="!w-200px" />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="windowForm.remark" type="textarea" :rows="2" maxlength="500" placeholder="选填" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="windowVisible = false">取 消</el-button>
      <el-button type="primary" :loading="windowSaving" @click="submitWindow">确 定</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { InstrumentDeviceApi, InstrumentDeviceVO } from '@/api/lab/instrument/device'
import { InstrumentBookingRuleApi, InstrumentBookingRuleVO } from '@/api/lab/instrument/booking-rule'
import { InstrumentBookingWindowApi, InstrumentBookingWindowVO } from '@/api/lab/instrument/booking-window'

defineOptions({ name: 'LabInstrumentBookingConfig' })

const message = useMessage()
const activeTab = ref('rule')

/** 每周开放日 1-7（与后端校验 [1-7] 一致） */
const WEEK_DAYS = [
  { value: 1, label: '周一' },
  { value: 2, label: '周二' },
  { value: 3, label: '周三' },
  { value: 4, label: '周四' },
  { value: 5, label: '周五' },
  { value: 6, label: '周六' },
  { value: 7, label: '周日' }
]
const formatOpenDays = (openDays?: string) => {
  if (!openDays) return '不限'
  return openDays
    .split(',')
    .map((t) => WEEK_DAYS.find((w) => w.value === Number(t.trim()))?.label ?? t.trim())
    .join('、')
}

// ========== 设备选择 ==========
const deviceId = ref<number | undefined>()
const deviceOptions = ref<InstrumentDeviceVO[]>([])
const getDeviceOptions = async () => {
  const data = await InstrumentDeviceApi.getPage({ pageNo: 1, pageSize: 100 })
  deviceOptions.value = data.list
}

// ========== 预约规则 ==========
const ruleLoading = ref(false)
const ruleSaving = ref(false)
const ruleLoaded = ref(false)
const hasRule = ref(false)
const ruleFormRef = ref()
const ruleForm = reactive({
  id: undefined as number | undefined,
  enabled: false,
  granularityMinutes: undefined as number | undefined,
  minDurationMinutes: undefined as number | undefined,
  maxDurationMinutes: undefined as number | undefined,
  bookableDaysBefore: undefined as number | undefined,
  bookableDaysAhead: undefined as number | undefined,
  openDayList: [] as number[],
  openStartTime: undefined as string | undefined,
  openEndTime: undefined as string | undefined,
  allowCrossDay: false,
  allowAdminAdjustAfterStart: false,
  remark: ''
})
const ruleRules = {
  granularityMinutes: [
    {
      validator: (_rule: any, _value: any, callback: any) => {
        if (ruleForm.enabled && !ruleForm.granularityMinutes) callback(new Error('启用预约时必须配置时间粒度'))
        else callback()
      },
      trigger: 'blur'
    }
  ],
  minDurationMinutes: [
    {
      validator: (_rule: any, _value: any, callback: any) => {
        if (ruleForm.enabled && !ruleForm.minDurationMinutes) callback(new Error('启用预约时必须配置最短时长'))
        else callback()
      },
      trigger: 'blur'
    }
  ],
  maxDurationMinutes: [
    {
      validator: (_rule: any, value: any, callback: any) => {
        if (value && ruleForm.minDurationMinutes && value < ruleForm.minDurationMinutes) {
          callback(new Error('最长时长不能小于最短时长'))
        } else callback()
      },
      trigger: 'blur'
    }
  ]
}

const getRule = async () => {
  if (!deviceId.value) return
  ruleLoading.value = true
  try {
    const data = await InstrumentBookingRuleApi.get(deviceId.value)
    Object.assign(ruleForm, {
      id: undefined,
      enabled: false,
      granularityMinutes: undefined,
      minDurationMinutes: undefined,
      maxDurationMinutes: undefined,
      bookableDaysBefore: undefined,
      bookableDaysAhead: undefined,
      openDayList: [],
      openStartTime: undefined,
      openEndTime: undefined,
      allowCrossDay: false,
      allowAdminAdjustAfterStart: false,
      remark: ''
    })
    if (data) {
      hasRule.value = true
      Object.assign(ruleForm, {
        id: data.id,
        enabled: !!data.enabled,
        granularityMinutes: data.granularityMinutes,
        minDurationMinutes: data.minDurationMinutes,
        maxDurationMinutes: data.maxDurationMinutes,
        bookableDaysBefore: data.bookableDaysBefore,
        bookableDaysAhead: data.bookableDaysAhead,
        openDayList: data.openDays ? data.openDays.split(',').map((t) => Number(t.trim())) : [],
        openStartTime: data.openStartTime,
        openEndTime: data.openEndTime,
        allowCrossDay: !!data.allowCrossDay,
        allowAdminAdjustAfterStart: !!data.allowAdminAdjustAfterStart,
        remark: data.remark ?? ''
      })
    } else {
      hasRule.value = false
    }
    ruleLoaded.value = true
  } finally {
    ruleLoading.value = false
  }
}

const saveRule = async () => {
  if (!deviceId.value) return
  await ruleFormRef.value?.validate()
  const data: InstrumentBookingRuleVO = {
    id: ruleForm.id,
    deviceId: deviceId.value,
    granularityMinutes: ruleForm.granularityMinutes,
    minDurationMinutes: ruleForm.minDurationMinutes,
    maxDurationMinutes: ruleForm.maxDurationMinutes,
    bookableDaysBefore: ruleForm.bookableDaysBefore,
    bookableDaysAhead: ruleForm.bookableDaysAhead,
    openDays: ruleForm.openDayList.length ? ruleForm.openDayList.join(',') : undefined,
    openStartTime: ruleForm.openStartTime,
    openEndTime: ruleForm.openEndTime,
    // B7：开关语义与后端一致，false/NULL 均按不允许跨天处理
    allowCrossDay: ruleForm.allowCrossDay ? true : undefined,
    allowAdminAdjustAfterStart: ruleForm.allowAdminAdjustAfterStart ? true : undefined,
    enabled: ruleForm.enabled,
    remark: ruleForm.remark || undefined
  }
  ruleSaving.value = true
  try {
    await InstrumentBookingRuleApi.save(data)
    message.success('预约规则已保存')
    await getRule()
  } finally {
    ruleSaving.value = false
  }
}

// ========== 开放窗口 ==========
const windowLoading = ref(false)
const windowSaving = ref(false)
const windowList = ref<InstrumentBookingWindowVO[]>([])
const windowTotal = ref(0)
const windowQuery = reactive({ pageNo: 1, pageSize: 10 })

const getWindowList = async () => {
  if (!deviceId.value) return
  windowLoading.value = true
  try {
    const data = await InstrumentBookingWindowApi.getPage({
      pageNo: windowQuery.pageNo,
      pageSize: windowQuery.pageSize,
      deviceId: deviceId.value
    })
    windowList.value = data.list
    windowTotal.value = data.total
  } finally {
    windowLoading.value = false
  }
}

const windowVisible = ref(false)
const windowFormRef = ref()
const windowDateRange = ref<[string, string] | undefined>()
const windowForm = reactive({
  id: undefined as number | undefined,
  windowName: '',
  openDayList: [] as number[],
  openStartTime: undefined as string | undefined,
  openEndTime: undefined as string | undefined,
  targetWeekMapping: '',
  capacity: undefined as number | undefined,
  usedCount: undefined as number | undefined,
  status: 'ACTIVE',
  sort: 0,
  remark: ''
})
const windowRules = {
  windowName: [{ required: true, message: '请输入窗口名称', trigger: 'blur' }]
}

const openWindowForm = (row?: InstrumentBookingWindowVO) => {
  windowForm.id = row?.id
  windowForm.windowName = row?.windowName ?? ''
  windowForm.openDayList = row?.openDays ? row.openDays.split(',').map((t) => Number(t.trim())) : []
  windowForm.openStartTime = row?.openStartTime
  windowForm.openEndTime = row?.openEndTime
  windowForm.targetWeekMapping = row?.targetWeekMapping ?? ''
  windowForm.capacity = row?.capacity
  windowForm.usedCount = row?.usedCount
  windowForm.status = row?.status ?? 'ACTIVE'
  windowForm.sort = row?.sort ?? 0
  windowForm.remark = row?.remark ?? ''
  windowDateRange.value =
    row?.targetDateStart && row?.targetDateEnd ? [row.targetDateStart, row.targetDateEnd] : undefined
  windowVisible.value = true
}

const submitWindow = async () => {
  if (!deviceId.value) return
  await windowFormRef.value?.validate()
  if (windowForm.openStartTime && windowForm.openEndTime && windowForm.openStartTime >= windowForm.openEndTime) {
    message.error('开放时段开始时间必须早于结束时间')
    return
  }
  const data: InstrumentBookingWindowVO = {
    id: windowForm.id,
    deviceId: deviceId.value,
    windowName: windowForm.windowName,
    openDays: windowForm.openDayList.length ? windowForm.openDayList.join(',') : undefined,
    openStartTime: windowForm.openStartTime,
    openEndTime: windowForm.openEndTime,
    targetDateStart: windowDateRange.value?.[0],
    targetDateEnd: windowDateRange.value?.[1],
    targetWeekMapping: windowForm.targetWeekMapping || undefined,
    capacity: windowForm.capacity,
    status: windowForm.status,
    sort: windowForm.sort,
    remark: windowForm.remark || undefined
  }
  windowSaving.value = true
  try {
    if (windowForm.id) {
      await InstrumentBookingWindowApi.update(data)
      message.success('窗口已修改')
    } else {
      await InstrumentBookingWindowApi.create(data)
      message.success('窗口已创建')
    }
    windowVisible.value = false
    await getWindowList()
  } finally {
    windowSaving.value = false
  }
}

const handleWindowDelete = async (row: InstrumentBookingWindowVO) => {
  await message.delConfirm(
    `确认删除窗口「${row.windowName}」？已有使用记录的窗口不允许删除，删除后不可恢复。`
  )
  await InstrumentBookingWindowApi.delete(row.id!)
  message.success('删除成功')
  await getWindowList()
}

// ========== 联动 ==========
const onDeviceChange = () => {
  ruleLoaded.value = false
  hasRule.value = false
  getRule()
  windowQuery.pageNo = 1
  getWindowList()
}

onMounted(() => {
  getDeviceOptions()
})
</script>
