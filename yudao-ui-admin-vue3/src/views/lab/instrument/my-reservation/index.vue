<template>
  <ContentWrap>
    <div class="section-title">我的预约</div>
    <div class="text-12px text-[var(--el-text-color-secondary)] mb-10px">
      仅展示本人预约（全部状态，按创建倒序）；取消、调整按当前预约状态显示可用操作，完成与作废由授权负责人在管理端办理，操作记录可在详情中查看。
    </div>
    <el-table v-loading="loading" :data="list" stripe>
      <el-table-column label="预约单号" align="center" prop="reservationNo" width="170px" show-overflow-tooltip />
      <el-table-column label="设备" align="center" prop="deviceName" min-width="150px" show-overflow-tooltip />
      <el-table-column label="预约时间" align="center" min-width="240px">
        <template #default="scope">
          {{ fmtTime(scope.row.startTime) }} ~ {{ fmtTime(scope.row.endTime) }}
        </template>
      </el-table-column>
      <el-table-column label="时长" align="center" width="90px">
        <template #default="scope">{{ scope.row.durationMinutes ? scope.row.durationMinutes + ' 分钟' : '-' }}</template>
      </el-table-column>
      <el-table-column label="状态" align="center" width="100px">
        <template #default="scope">
          <el-tag :type="statusMeta(scope.row.status).type">{{ statusMeta(scope.row.status).label }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="用途" align="center" prop="purpose" min-width="120px" show-overflow-tooltip />
      <el-table-column label="创建时间" align="center" prop="createTime" width="170px" :formatter="dateFormatter" />
      <el-table-column label="操作" align="center" width="200px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openDetail(scope.row)">详情</el-button>
          <el-button v-if="scope.row.canCancel" link type="danger" @click="actionsRef?.openCancel(scope.row)">
            取消
          </el-button>
          <el-button v-if="scope.row.canAdjust" link type="warning" v-hasPermi="['lab:instrument:reservation:adjust']" @click="actionsRef?.openAdjust(scope.row)">
            调整
          </el-button>
          <el-button link type="info" @click="actionsRef?.openHistory(scope.row)">历史</el-button>
        </template>
      </el-table-column>
    </el-table>
    <el-empty v-if="!loading && !list.length" description="暂无预约，可在设备详情页发起" :image-size="70" />
  </ContentWrap>

  <!-- 预约详情 -->
  <el-drawer v-model="detailVisible" title="预约详情" size="480px">
    <el-descriptions :column="1" border>
      <el-descriptions-item label="预约单号">{{ detail?.reservationNo }}</el-descriptions-item>
      <el-descriptions-item label="设备">{{ detail?.deviceName || '-' }}</el-descriptions-item>
      <el-descriptions-item label="状态">
        <el-tag :type="statusMeta(detail?.status).type">{{ statusMeta(detail?.status).label }}</el-tag>
      </el-descriptions-item>
      <el-descriptions-item label="预约时间">
        {{ detail ? fmtTime(detail.startTime) + ' ~ ' + fmtTime(detail.endTime) : '-' }}
      </el-descriptions-item>
      <el-descriptions-item label="时长">{{ detail?.durationMinutes ? detail.durationMinutes + ' 分钟' : '-' }}</el-descriptions-item>
      <el-descriptions-item label="用途">{{ detail?.purpose || '-' }}</el-descriptions-item>
      <el-descriptions-item label="备注">{{ detail?.remark || '-' }}</el-descriptions-item>
      <el-descriptions-item label="创建时间">{{ fmtTime(detail?.createTime) }}</el-descriptions-item>
      <template v-if="detail?.status === 'CANCELED'">
        <el-descriptions-item label="取消时间">{{ fmtTime(detail?.cancelTime) }}</el-descriptions-item>
        <el-descriptions-item label="取消方">{{ cancelByText(detail?.cancelBy) }}</el-descriptions-item>
        <el-descriptions-item label="取消原因">{{ detail?.cancelReason || '-' }}</el-descriptions-item>
      </template>
      <template v-if="detail?.status === 'FINISHED'">
        <el-descriptions-item label="完成时间">{{ fmtTime(detail?.finishTime) }}</el-descriptions-item>
        <el-descriptions-item label="实际使用">
          {{ detail?.actualStartTime ? fmtTime(detail.actualStartTime) + ' ~ ' + fmtTime(detail.actualEndTime) : '-' }}
        </el-descriptions-item>
      </template>
      <template v-if="detail?.status === 'VOIDED'">
        <el-descriptions-item label="作废时间">{{ fmtTime(detail?.cancelTime) }}</el-descriptions-item>
        <el-descriptions-item label="作废原因">{{ detail?.cancelReason || '-' }}</el-descriptions-item>
      </template>
    </el-descriptions>
    <div class="mt-16px flex gap-10px">
      <el-button v-if="detail?.canCancel" type="danger" plain @click="detail && actionsRef?.openCancel(detail)">
        取消预约
      </el-button>
      <el-button v-if="detail?.canAdjust" type="warning" plain v-hasPermi="['lab:instrument:reservation:adjust']" @click="detail && actionsRef?.openAdjust(detail)">
        调整预约
      </el-button>
      <el-button @click="detail && actionsRef?.openHistory(detail)">操作历史</el-button>
    </div>
  </el-drawer>

  <!-- 生命周期操作（取消/调整/完成/作废/历史，共享组件） -->
  <ReservationActionDialogs ref="actionsRef" @success="handleActionSuccess" />
</template>

<script setup lang="ts">
import dayjs from 'dayjs'
import { dateFormatter } from '@/utils/formatTime'
import {
  InstrumentReservationApi,
  ReservationRespVO,
  RESERVATION_STATUS
} from '@/api/lab/instrument/reservation'
import ReservationActionDialogs from '@/views/lab/instrument/components/ReservationActionDialogs.vue'

defineOptions({ name: 'LabInstrumentMyReservation' })

type TagType = 'success' | 'info' | 'warning' | 'danger' | 'primary'

const loading = ref(true)
const list = ref<ReservationRespVO[]>([])
const detailVisible = ref(false)
const detail = ref<ReservationRespVO>()
const actionsRef = ref<InstanceType<typeof ReservationActionDialogs>>()

const statusMeta = (status?: string): { value: string; label: string; type: TagType } =>
  (Object.values(RESERVATION_STATUS).find((s) => s.value === status) as any) || {
    value: status,
    label: status || '-',
    type: 'info'
  }

const fmtTime = (t?: string) => (t ? dayjs(t).format('YYYY-MM-DD HH:mm') : '-')
const cancelByText = (v?: string) =>
  ({ USER: '本人', MANAGER: '负责人', ADMIN: '管理员' } as Record<string, string>)[v || ''] || v || '-'

const getList = async () => {
  loading.value = true
  try {
    list.value = (await InstrumentReservationApi.getMy()) || []
  } finally {
    loading.value = false
  }
}

const openDetail = (row: ReservationRespVO) => {
  detail.value = row
  detailVisible.value = true
}

/** 生命周期操作成功：刷新列表；若详情抽屉打开则回查最新详情（状态/can* 标记已变化） */
const handleActionSuccess = async () => {
  await getList()
  if (detailVisible.value && detail.value?.id) {
    try {
      detail.value = await InstrumentReservationApi.get(detail.value.id)
    } catch {
      detailVisible.value = false
    }
  }
}

onMounted(() => {
  getList()
})
</script>

<style scoped>
.section-title {
  font-weight: bold;
  font-size: 15px;
  margin-bottom: 12px;
}
</style>
