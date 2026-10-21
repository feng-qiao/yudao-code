<template>
  <ContentWrap>
    <div class="flex items-center justify-between flex-wrap gap-10px mb-15px">
      <el-tabs v-model="platformTab" class="flex-1" @tab-change="handleQuery">
        <el-tab-pane label="全部平台" name="all" />
        <el-tab-pane v-for="p in options.platforms" :key="p.id" :label="p.name" :name="String(p.id)" />
      </el-tabs>
    </div>
    <el-form :inline="true" :model="queryParams" class="-mb-10px">
      <el-form-item label="实验室">
        <el-select v-model="queryParams.roomId" placeholder="全部实验室" clearable filterable class="!w-180px" @change="handleQuery">
          <el-option v-for="r in options.rooms" :key="r.id" :label="r.name" :value="r.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="类别">
        <el-select v-model="queryParams.category" placeholder="全部类别" clearable class="!w-150px" @change="handleQuery">
          <el-option
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_INSTRUMENT_CATEGORY)"
            :key="dict.value"
            :label="dict.label"
            :value="dict.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="状态">
        <el-select v-model="queryParams.status" placeholder="全部状态" clearable class="!w-130px" @change="handleQuery">
          <el-option v-for="s in statusOptions" :key="s.value" :label="s.label" :value="s.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="关键词">
        <el-input v-model="queryParams.name" placeholder="设备名称" clearable @keyup.enter="handleQuery" class="!w-180px" />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <ContentWrap v-loading="loading">
    <el-empty v-if="!loading && list.length === 0" description="暂无符合条件的仪器" />
    <el-row :gutter="16">
      <el-col v-for="d in list" :key="d.id" :xs="24" :sm="12" :md="8" :lg="6" :xl="6" class="mb-16px">
        <el-card shadow="hover" class="!cursor-pointer" @click="goDetail(d.id)">
          <div class="flex items-center justify-between mb-8px">
            <el-tag size="small" :type="statusMeta(d.status).type">{{ statusMeta(d.status).label }}</el-tag>
            <el-tag size="small" type="info">{{ categoryLabel(d.category) }}</el-tag>
          </div>
          <el-image
            v-if="d.imageUrl"
            :src="d.imageUrl"
            class="w-full !h-160px mb-8px"
            fit="cover"
            :preview-src-list="[d.imageUrl]"
            preview-teleported
            @click.stop
          />
          <div v-else class="w-full h-160px mb-8px flex items-center justify-center bg-[var(--el-fill-color-light)] rounded">
            <Icon icon="ep:monitor" :size="42" class="text-[var(--el-text-color-placeholder)]" />
          </div>
          <div class="font-bold text-15px mb-4px ellipsis">{{ d.name }}</div>
          <div class="text-12px text-[var(--el-text-color-secondary)] mb-4px">编号：{{ d.deviceNo }}</div>
          <div class="text-12px text-[var(--el-text-color-secondary)] mb-4px">
            平台：{{ d.platformName || '未归属' }} ｜ 房间：{{ d.roomName || '未登记' }}
          </div>
          <div class="text-12px text-[var(--el-text-color-secondary)] mb-8px ellipsis">
            负责人：{{ d.managerNames || '暂未分配' }}
          </div>
          <div class="flex items-center justify-between">
            <el-button link type="primary" @click.stop="goDetail(d.id)">
              查看须知<Icon icon="ep:arrow-right" class="ml-2px" />
            </el-button>
            <div>
              <el-button
                size="small"
                v-hasPermi="['lab:instrument:qualification:apply']"
                @click.stop="goApply(d.id)"
              >
                申请资质
              </el-button>
              <el-tooltip :disabled="!!d.bookable" content="该设备未开放预约" placement="top">
                <span>
                  <el-button
                    size="small"
                    type="primary"
                    :disabled="!d.bookable"
                    v-hasPermi="['lab:instrument:reservation:create']"
                    @click.stop="openReservation(d)"
                  >
                    立即预约
                  </el-button>
                </span>
              </el-tooltip>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
    <!-- 仪器预约（INSTRUMENT-03-C；与详情页同一弹窗，C7 功能开关由服务端控制） -->
    <ReservationForm ref="reservationFormRef" @success="getList" />
  </ContentWrap>
</template>

<script setup lang="ts">
import { getStrDictOptions, getDictLabel, DICT_TYPE } from '@/utils/dict'
import { InstrumentDeviceApi, InstrumentDeviceVO, DeviceHallOptions, DEVICE_STATUS } from '@/api/lab/instrument/device'
import ReservationForm from '../device-detail/ReservationForm.vue'

defineOptions({ name: 'LabInstrumentHall' })

const router = useRouter()
const loading = ref(true)
const list = ref<InstrumentDeviceVO[]>([])
const total = ref(0)
const statusOptions = Object.values(DEVICE_STATUS)
const options = ref<DeviceHallOptions>({ platforms: [], rooms: [] })
/**
 * 平台页签选中值（'all' = 全部平台）：必须与查询参数解耦。
 * el-tabs 内部对无 name 的页签会回退为下标（"0"），若直接 v-model 到 platformId，
 * 点"全部平台"会把 platformId 下发为 0，服务端按 platform_id=0 过滤导致列表为空。
 */
const platformTab = ref('all')
const queryParams = reactive({
  pageNo: 1,
  pageSize: 12,
  platformId: undefined as number | undefined,
  roomId: undefined as number | undefined,
  category: undefined as string | undefined,
  status: undefined as string | undefined,
  name: undefined as string | undefined
})

const statusMeta = (status?: string) =>
  Object.values(DEVICE_STATUS).find((s) => s.value === status) || {
    value: status,
    label: status || '',
    type: 'info'
  }
const categoryLabel = (v: string) => getDictLabel(DICT_TYPE.LAB_INSTRUMENT_CATEGORY, v) || v

const getList = async () => {
  loading.value = true
  try {
    const data = await InstrumentDeviceApi.getPage(queryParams)
    list.value = data.list
    total.value = data.total
  } finally {
    loading.value = false
  }
}
const handleQuery = () => {
  queryParams.pageNo = 1
  // 'all' 页签不下发 platformId（服务端 eqIfPresent 会把 0 当作有效过滤条件）
  queryParams.platformId = platformTab.value === 'all' ? undefined : Number(platformTab.value)
  getList()
}
const goDetail = (id?: number) => {
  router.push({ path: '/lab/instrument/device-detail', query: { id } })
}
/** 申请资质：跳转详情页并自动打开申请弹窗（复用详情页既有申请链路） */
const goApply = (id?: number) => {
  router.push({ path: '/lab/instrument/device-detail', query: { id, apply: '1' } })
}
/** 立即预约：复用详情页同一预约弹窗（是否放行由服务端 C7 开关判定） */
const reservationFormRef = ref()
const openReservation = (d: InstrumentDeviceVO) => {
  if (!d.id) return
  reservationFormRef.value.open(d)
}

onMounted(async () => {
  options.value = await InstrumentDeviceApi.getHallOptions()
  await getList()
})
</script>

<style scoped>
.ellipsis {
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}
</style>
