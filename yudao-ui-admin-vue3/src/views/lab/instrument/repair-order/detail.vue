<template>
  <div v-loading="loading">
    <ContentWrap>
      <el-page-header @back="goBack" :content="`维修工单 - ${detail?.orderNo || ''}`">
        <template #content>
          <el-tag :type="statusMeta(detail?.status).type" size="large">
            {{ statusMeta(detail?.status).label }}
          </el-tag>
        </template>
      </el-page-header>
    </ContentWrap>
    <ContentWrap>
      <el-descriptions v-if="detail" :column="3" border>
        <el-descriptions-item label="工单号">{{ detail.orderNo }}</el-descriptions-item>
        <el-descriptions-item label="来源故障 ID">{{ detail.sourceFaultId || '—' }}</el-descriptions-item>
        <el-descriptions-item label="设备 ID">{{ detail.deviceId }}</el-descriptions-item>
        <el-descriptions-item label="维修负责人">{{ detail.assigneeName || '未指派' }}</el-descriptions-item>
        <el-descriptions-item label="创建时间">{{ detail.createTime || '—' }}</el-descriptions-item>
        <el-descriptions-item label="指派时间">{{ detail.assignTime || '—' }}</el-descriptions-item>
        <el-descriptions-item label="开始维修">{{ detail.startTime || '—' }}</el-descriptions-item>
        <el-descriptions-item label="维修完成">{{ detail.finishTime || '—' }}</el-descriptions-item>
        <el-descriptions-item label="恢复验收">{{ detail.restoreTime || '—' }}</el-descriptions-item>
        <el-descriptions-item v-if="detail.restoreOpinion" label="验收意见" :span="3">
          {{ detail.restoreOpinion }}
        </el-descriptions-item>
      </el-descriptions>
      <el-alert
        class="mt-15px"
        type="info"
        :closable="false"
        title="当前后端详情接口只返回工单主表；维修历史和过程记录暂未提供读取接口。"
      />
    </ContentWrap>
  </div>
</template>

<script setup lang="ts">
import { useRoute } from 'vue-router'
import { InstrumentRepairOrderApi, type RepairOrderVO } from '@/api/lab/instrument/repair-order'

defineOptions({ name: 'LabInstrumentRepairOrderDetail' })

const route = useRoute()
const message = useMessage()
const loading = ref(true)
const detail = ref<RepairOrderVO | null>(null)

const statusMeta = (s?: string) =>
  ({
    CONFIRMED: { label: '待指派', type: 'info' },
    ASSIGNED: { label: '已指派', type: 'warning' },
    IN_PROGRESS: { label: '维修中', type: 'primary' },
    REPAIRED: { label: '待验收', type: 'primary' },
    RESTORED: { label: '已验收', type: 'success' },
    REJECTED: { label: '已驳回', type: 'danger' },
    CANCELED: { label: '已取消', type: 'info' },
    REOPENED: { label: '已重开', type: 'warning' }
  } as Record<string, { label: string; type: 'info' | 'warning' | 'danger' | 'primary' | 'success' }>)[s || ''] || { label: s || '—', type: 'info' }

const goBack = () => {
  if (window.history.length > 1) window.history.back()
}

const loadDetail = async () => {
  const id = Number(route.query.id)
  if (!Number.isSafeInteger(id) || id <= 0) {
    message.error('缺少有效工单 ID')
    loading.value = false
    return
  }
  try {
    detail.value = await InstrumentRepairOrderApi.get(id)
  } finally {
    loading.value = false
  }
}

onMounted(loadDetail)
</script>
