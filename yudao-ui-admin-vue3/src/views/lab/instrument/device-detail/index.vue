<template>
  <ContentWrap v-loading="loading">
    <div class="flex items-center justify-between mb-15px">
      <div class="flex items-center">
        <el-button link @click="goBack"><Icon icon="ep:arrow-left" class="mr-5px" />返回</el-button>
        <span class="font-bold text-16px ml-5px">{{ device.name || '仪器详情' }}</span>
        <el-tag v-if="device.status" class="ml-10px" :type="statusMeta(device.status).type">
          {{ statusMeta(device.status).label }}
        </el-tag>
      </div>
      <div>
        <el-button
          v-if="canSubmitFaultReport"
          type="danger"
          plain
          :disabled="!device.id"
          @click="openFaultReport"
        >
          上报故障
        </el-button>
        <el-button
          type="primary"
          plain
          @click="openApplyDialog"
          v-hasPermi="['lab:instrument:qualification:apply']"
        >
          申请资质
        </el-button>
        <el-tooltip
          :disabled="!!device.bookable"
          content="该设备未开放预约"
          placement="top"
        >
          <span>
            <el-button
              type="primary"
              :disabled="!device.bookable"
              @click="openReservation"
              v-hasPermi="['lab:instrument:reservation:create']"
            >
              立即预约
            </el-button>
          </span>
        </el-tooltip>
      </div>
    </div>

    <el-row :gutter="20">
      <el-col :xs="24" :md="10">
        <el-image
          v-if="device.imageUrl"
          :src="device.imageUrl"
          class="w-full !h-300px"
          fit="contain"
          :preview-src-list="[device.imageUrl]"
          preview-teleported
        />
        <div v-else class="h-300px flex items-center justify-center bg-[var(--el-fill-color-light)] rounded">
          <Icon icon="ep:monitor" :size="64" class="text-[var(--el-text-color-placeholder)]" />
        </div>
      </el-col>
      <el-col :xs="24" :md="14">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="设备编号">{{ device.deviceNo }}</el-descriptions-item>
          <el-descriptions-item label="设备名称">{{ device.name }}</el-descriptions-item>
          <el-descriptions-item label="设备类别">{{ categoryLabel(device.category) }}</el-descriptions-item>
          <el-descriptions-item label="维修口径">{{ repairScopeLabel(device.repairScope) }}</el-descriptions-item>
          <el-descriptions-item label="型号">{{ device.model || '-' }}</el-descriptions-item>
          <el-descriptions-item label="规格">{{ device.spec || '-' }}</el-descriptions-item>
          <el-descriptions-item label="资产编号">{{ device.assetNo || '-' }}</el-descriptions-item>
          <el-descriptions-item label="生产厂家">{{ device.manufacturer || '-' }}</el-descriptions-item>
          <el-descriptions-item label="购置日期">{{ device.purchaseDate || '-' }}</el-descriptions-item>
          <el-descriptions-item label="允许预约">{{ device.bookable ? '是' : '否' }}</el-descriptions-item>
          <el-descriptions-item label="所属平台">{{ device.platformName || '未归属' }}</el-descriptions-item>
          <el-descriptions-item label="所在房间">{{ device.roomName || '未登记' }}</el-descriptions-item>
          <el-descriptions-item label="备注" :span="2">{{ device.remark || '-' }}</el-descriptions-item>
        </el-descriptions>
      </el-col>
    </el-row>
  </ContentWrap>

  <ContentWrap v-if="hasQualQuery">
    <div class="section-title">我的使用资质</div>
    <template v-if="myQualification">
      <el-descriptions :column="3" border>
        <el-descriptions-item label="资质状态">
          <el-tag :type="qualStatusMeta(myQualification.status).type">
            {{ qualStatusMeta(myQualification.status).label }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="授予时间">{{ myQualification.grantedTime || '-' }}</el-descriptions-item>
        <el-descriptions-item label="到期时间">{{ myQualification.expireTime || '长期有效' }}</el-descriptions-item>
      </el-descriptions>
      <div v-if="myQualification.status === 'SUSPENDED'" class="text-12px text-[var(--el-color-warning)] mt-8px">
        当前处于人工暂停期，暂停解除后自动恢复使用资格。
      </div>
    </template>
    <div v-else-if="myPendingApply" class="flex items-center gap-10px">
      <el-tag type="warning">审核中</el-tag>
      <span class="text-13px">资质申请 {{ myPendingApply.applyNo }} 待授权负责人审核</span>
      <el-button link type="danger" @click="handleCancelApply" v-hasPermi="['lab:instrument:qualification:apply']">
        撤回申请
      </el-button>
    </div>
    <el-empty
      v-else
      description="尚未持有该设备使用资质，可点击右上角「申请资质」提交申请"
      :image-size="60"
    />
  </ContentWrap>

  <ContentWrap>
    <div class="section-title">当前负责人</div>
    <el-table :data="device.managers || []" border size="small">
      <el-table-column label="负责人类型" align="center" width="140px">
        <template #default="scope">{{ managerTypeText(scope.row.managerType) }}</template>
      </el-table-column>
      <el-table-column label="姓名" align="center" prop="nickname" width="140px" />
      <el-table-column label="登录账号" align="center" prop="username" width="160px" />
      <el-table-column label="联系方式" align="center" prop="mobile" />
    </el-table>
    <el-empty v-if="!(device.managers && device.managers.length)" description="暂未分配负责人" :image-size="60" />
  </ContentWrap>

  <ContentWrap>
    <div class="section-title">
      使用须知
      <el-tag v-if="device.currentNotice" size="small" type="success" class="ml-8px">
        当前生效 V{{ device.currentNotice.version }}
      </el-tag>
    </div>
    <template v-if="device.currentNotice">
      <div class="font-bold mb-8px">{{ device.currentNotice.title }}</div>
      <div class="text-12px text-[var(--el-text-color-secondary)] mb-10px">
        发布时间：{{ device.currentNotice.publishTime || '-' }}
        <span v-if="device.currentNotice.requireAcknowledge" class="ml-10px">使用前需阅读确认（确认环节后续开放）</span>
      </div>
      <div class="whitespace-pre-wrap bg-[var(--el-fill-color-light)] p-12px rounded">
        {{ device.currentNotice.content }}
      </div>
    </template>
    <el-empty v-else description="该设备暂未发布使用须知" :image-size="60" />
  </ContentWrap>

  <!-- 申请使用资质 -->
  <Dialog title="申请仪器使用资质" v-model="applyVisible" width="480px">
    <el-form ref="applyFormRef" :model="applyForm" label-width="90px">
      <el-form-item label="申请设备">
        <span>{{ device.name }}</span>
      </el-form-item>
      <el-form-item label="申请理由" prop="reason">
        <el-input
          v-model="applyForm.reason"
          type="textarea"
          :rows="3"
          maxlength="1000"
          show-word-limit
          placeholder="请输入申请使用该仪器的理由（选填）"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="applyVisible = false">取 消</el-button>
      <el-button type="primary" :loading="applyLoading" @click="submitApply">提交申请</el-button>
    </template>
  </Dialog>

  <!-- 仪器预约（INSTRUMENT-03-C；C7 功能开关由服务端控制） -->
  <ReservationForm ref="reservationFormRef" />
</template>

<script setup lang="ts">
import { getDictLabel, DICT_TYPE } from '@/utils/dict'
import { checkPermi } from '@/utils/permission'
import { useUserStore } from '@/store/modules/user'
import { InstrumentDeviceApi, InstrumentDeviceVO, DEVICE_STATUS } from '@/api/lab/instrument/device'
import {
  InstrumentQualificationApi,
  InstrumentQualificationVO,
  QualificationApplyVO
} from '@/api/lab/instrument/qualification'
import ReservationForm from './ReservationForm.vue'

defineOptions({ name: 'LabInstrumentDeviceDetail' })

const message = useMessage()
const route = useRoute()
const router = useRouter()
const loading = ref(true)
const device = ref<InstrumentDeviceVO>({} as InstrumentDeviceVO)

// ========== 我的使用资质（INSTRUMENT-02） ==========
const hasQualQuery = computed(() => checkPermi(['lab:instrument:qualification:query']))
const canSubmitFaultReport = computed(() =>
  checkPermi(['lab:instrument:fault-report:submit', 'lab:instrument:fault-report:admin'])
)
const userStore = useUserStore()
const myQualification = ref<InstrumentQualificationVO>()
const myPendingApply = ref<QualificationApplyVO>()

const qualStatusMeta = (status?: string) =>
  (
    {
      ACTIVE: { label: '生效中', type: 'success' },
      EXPIRED: { label: '已到期', type: 'info' },
      SUSPENDED: { label: '已暂停', type: 'warning' },
      REVOKED: { label: '已撤销', type: 'danger' }
    } as Record<string, any>
  )[status || ''] || { label: status || '-', type: 'info' }

const applyVisible = ref(false)
const applyLoading = ref(false)
const applyForm = reactive({ reason: '' })

const openApplyDialog = () => {
  applyForm.reason = ''
  applyVisible.value = true
}
const submitApply = async () => {
  applyLoading.value = true
  try {
    await InstrumentQualificationApi.apply({
      deviceId: device.value.id!,
      reason: applyForm.reason || undefined
    })
    message.success('资质申请已提交，请等待授权负责人审核')
    applyVisible.value = false
    await loadMyQualification()
  } finally {
    applyLoading.value = false
  }
}
const handleCancelApply = async () => {
  if (!myPendingApply.value?.id) return
  await message.confirm('确认撤回该设备的资质申请？')
  await InstrumentQualificationApi.cancel(myPendingApply.value.id)
  message.success('已撤回申请')
  await loadMyQualification()
}

/** 加载本人在该设备的资质与待审核申请（无权限/异常时不阻塞详情展示） */
const loadMyQualification = async () => {
  const deviceId = device.value.id
  if (!deviceId || !hasQualQuery.value) return
  myQualification.value = undefined
  myPendingApply.value = undefined
  try {
    const quals = (await InstrumentQualificationApi.getMyQualifications()) || []
    myQualification.value = quals.find((q) => q.targetId === deviceId)
    if (!myQualification.value) {
      const pageData = await InstrumentQualificationApi.getApplyPage({
        deviceId,
        pageNo: 1,
        pageSize: 50
      })
      myPendingApply.value = (pageData.list || []).find(
        (a) => a.status === 'PENDING' && a.applicantUserId === userStore.user.id
      )
    }
  } catch {
    // 忽略：数据范围不足等场景不影响设备详情主内容
  }
}

const statusMeta = (status?: string) =>
  Object.values(DEVICE_STATUS).find((s) => s.value === status) || {
    value: status,
    label: status || '',
    type: 'info'
  }
const categoryLabel = (v?: string) => (v ? getDictLabel(DICT_TYPE.LAB_INSTRUMENT_CATEGORY, v) || v : '-')
const repairScopeLabel = (v?: string) =>
  v ? getDictLabel(DICT_TYPE.LAB_INSTRUMENT_REPAIR_SCOPE, v) || v : '-'
const managerTypeText = (t?: string) =>
  ({ PRIMARY: '主负责人', REPAIR: '维修负责人', BACKUP: '备用负责人' } as Record<string, string>)[t || ''] || t || '-'

const goBack = () => {
  router.back()
}

// ========== 仪器预约（INSTRUMENT-03-C） ==========
const reservationFormRef = ref()
const openReservation = () => {
  if (!device.value.id) return
  reservationFormRef.value.open(device.value)
}

const openFaultReport = () => {
  if (!device.value.id) {
    message.error('设备信息不可用，无法上报故障')
    return
  }
  router.push({ path: '/lab/instrument/fault-report/submit', query: { deviceId: device.value.id, from: 'deviceDetail' } })
}

const load = async () => {
  const id = Number(route.query.id)
  if (!Number.isSafeInteger(id) || id <= 0) {
    message.error('缺少有效设备 ID')
    loading.value = false
    return
  }
  loading.value = true
  try {
    device.value = await InstrumentDeviceApi.get(id)
    if (!device.value?.id) {
      message.error('设备不存在或当前账号无权访问')
      return
    }
    await loadMyQualification()
    // 由大厅「申请资质」带 apply=1 跳入时自动打开申请弹窗；已有生效资质或待审申请则不打开
    if (
      route.query.apply === '1' &&
      !myPendingApply.value &&
      myQualification.value?.status !== 'ACTIVE'
    ) {
      openApplyDialog()
    }
  } catch {
    message.error('设备不存在或当前账号无权访问')
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  load()
})
</script>

<style scoped>
.section-title {
  font-weight: bold;
  font-size: 15px;
  margin-bottom: 12px;
}
</style>
