<template>
  <ContentWrap>
    <el-tabs v-model="activeTab" @tab-change="onTabChange">
      <el-tab-pane label="申请审核" name="apply" />
      <el-tab-pane label="资质列表" name="qualification" />
    </el-tabs>

    <!-- 申请审核 -->
    <template v-if="activeTab === 'apply'">
      <el-form class="-mb-15px" :model="applyQuery" ref="applyQueryFormRef" :inline="true" label-width="70px">
        <el-form-item label="状态" prop="status">
          <el-select v-model="applyQuery.status" placeholder="请选择" clearable class="!w-140px">
            <el-option label="待审核" value="PENDING" />
            <el-option label="已通过" value="APPROVED" />
            <el-option label="已驳回" value="REJECTED" />
            <el-option label="已撤回" value="CANCELED" />
          </el-select>
        </el-form-item>
        <el-form-item label="设备" prop="deviceId">
          <el-select v-model="applyQuery.deviceId" placeholder="请选择" clearable filterable class="!w-200px">
            <el-option v-for="d in deviceOptions" :key="d.id" :label="d.name" :value="d.id!" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button @click="handleApplyQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
          <el-button @click="resetApplyQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
        </el-form-item>
      </el-form>
      <div class="mt-15px">
        <el-table v-loading="loading" :data="applyList" stripe>
          <el-table-column label="申请单号" align="center" prop="applyNo" width="200px" />
          <el-table-column label="设备" align="center" prop="deviceName" min-width="140px" show-overflow-tooltip />
          <el-table-column label="申请人" align="center" prop="applicantName" width="100px" />
          <el-table-column label="申请理由" align="center" prop="reason" min-width="140px" show-overflow-tooltip />
          <el-table-column label="状态" align="center" width="100px">
            <template #default="scope">
              <el-tag :type="applyStatusMeta(scope.row.status).type">
                {{ applyStatusMeta(scope.row.status).label }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="申请时间" align="center" prop="applyTime" width="170px" :formatter="dateFormatter" />
          <el-table-column label="审核人" align="center" prop="auditorName" width="100px" />
          <el-table-column label="审核意见" align="center" prop="auditOpinion" min-width="130px" show-overflow-tooltip />
          <el-table-column label="操作" align="center" width="170px" fixed="right">
            <template #default="scope">
              <el-button
                v-if="scope.row.status === 'PENDING'"
                link
                type="primary"
                @click="openAudit(scope.row)"
                v-hasPermi="['lab:instrument:qualification:audit']"
              >
                审核
              </el-button>
              <el-button link type="primary" @click="openHistory(scope.row)">历史</el-button>
            </template>
          </el-table-column>
        </el-table>
        <Pagination
          :total="total"
          v-model:page="applyQuery.pageNo"
          v-model:limit="applyQuery.pageSize"
          @pagination="getApplyList"
        />
      </div>
    </template>

    <!-- 资质列表 -->
    <template v-else>
      <el-form class="-mb-15px" :model="qualQuery" ref="qualQueryFormRef" :inline="true" label-width="70px">
        <el-form-item label="状态" prop="status">
          <el-select v-model="qualQuery.status" placeholder="请选择" clearable class="!w-140px">
            <el-option label="生效中" value="ACTIVE" />
            <el-option label="已到期" value="EXPIRED" />
            <el-option label="已暂停" value="SUSPENDED" />
            <el-option label="已撤销" value="REVOKED" />
          </el-select>
        </el-form-item>
        <el-form-item label="设备" prop="deviceId">
          <el-select v-model="qualQuery.deviceId" placeholder="请选择" clearable filterable class="!w-200px">
            <el-option v-for="d in deviceOptions" :key="d.id" :label="d.name" :value="d.id!" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button @click="handleQualQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
          <el-button @click="resetQualQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
        </el-form-item>
      </el-form>
      <div class="mt-15px">
        <el-table v-loading="qualLoading" :data="qualList" stripe>
          <el-table-column label="设备" align="center" prop="deviceName" min-width="150px" show-overflow-tooltip />
          <el-table-column label="用户" align="center" prop="userName" width="110px" />
          <el-table-column label="状态" align="center" width="100px">
            <template #default="scope">
              <el-tag :type="qualStatusMeta(scope.row.status).type">
                {{ qualStatusMeta(scope.row.status).label }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="授予时间" align="center" prop="grantedTime" width="170px" :formatter="dateFormatter" />
          <el-table-column label="到期时间" align="center" prop="expireTime" width="170px" :formatter="dateFormatter" />
          <el-table-column label="撤销时间" align="center" prop="revokeTime" width="170px" :formatter="dateFormatter" />
          <el-table-column label="备注" align="center" prop="remark" min-width="120px" show-overflow-tooltip />
          <el-table-column label="操作" align="center" width="110px" fixed="right">
            <template #default="scope">
              <el-button
                v-if="scope.row.status === 'ACTIVE'"
                link
                type="danger"
                @click="openRevoke(scope.row)"
                v-hasPermi="['lab:instrument:qualification:manage']"
              >
                撤销
              </el-button>
            </template>
          </el-table-column>
        </el-table>
        <Pagination
          :total="qualTotal"
          v-model:page="qualQuery.pageNo"
          v-model:limit="qualQuery.pageSize"
          @pagination="getQualList"
        />
      </div>
    </template>
  </ContentWrap>

  <!-- 审核申请 -->
  <Dialog title="审核资质申请" v-model="auditVisible" width="520px">
    <el-descriptions :column="1" border class="mb-15px">
      <el-descriptions-item label="申请单号">{{ auditRow?.applyNo }}</el-descriptions-item>
      <el-descriptions-item label="设备">{{ auditRow?.deviceName }}</el-descriptions-item>
      <el-descriptions-item label="申请人">{{ auditRow?.applicantName }}</el-descriptions-item>
      <el-descriptions-item label="申请理由">{{ auditRow?.reason || '-' }}</el-descriptions-item>
    </el-descriptions>
    <el-form ref="auditFormRef" :model="auditForm" :rules="auditRules" label-width="90px">
      <el-form-item label="审核结果" prop="result">
        <el-radio-group v-model="auditForm.result">
          <el-radio value="APPROVED">通过</el-radio>
          <el-radio value="REJECTED">驳回</el-radio>
        </el-radio-group>
      </el-form-item>
      <el-form-item v-if="auditForm.result === 'APPROVED'" label="有效期至">
        <el-date-picker
          v-model="auditForm.expireTime"
          type="datetime"
          value-format="YYYY-MM-DD HH:mm:ss"
          placeholder="不填则长期有效"
          class="!w-full"
        />
      </el-form-item>
      <el-form-item label="审核意见" prop="opinion">
        <el-input
          v-model="auditForm.opinion"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          :placeholder="auditForm.result === 'REJECTED' ? '驳回时必填' : '选填'"
        />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="auditForm.remark" type="textarea" :rows="2" maxlength="500" placeholder="选填" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="auditVisible = false">取 消</el-button>
      <el-button type="primary" :loading="auditLoading" @click="submitAudit">确认提交</el-button>
    </template>
  </Dialog>

  <!-- 撤销资质 -->
  <Dialog title="撤销资质" v-model="revokeVisible" width="480px">
    <el-form ref="revokeFormRef" :model="revokeForm" :rules="revokeRules" label-width="90px">
      <el-form-item label="设备/用户">
        <span>{{ revokeRow?.deviceName }} / {{ revokeRow?.userName }}</span>
      </el-form-item>
      <el-form-item label="撤销原因" prop="reason">
        <el-input
          v-model="revokeForm.reason"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          placeholder="撤销必须填写原因"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="revokeVisible = false">取 消</el-button>
      <el-button type="danger" :loading="revokeLoading" @click="submitRevoke">确认撤销</el-button>
    </template>
  </Dialog>

  <!-- 审核历史（只读，不可变） -->
  <el-drawer v-model="historyVisible" title="申请审核历史" size="480px">
    <el-descriptions :column="1" border class="mb-15px">
      <el-descriptions-item label="申请单号">{{ historyApply?.applyNo }}</el-descriptions-item>
      <el-descriptions-item label="设备">{{ historyApply?.deviceName }}</el-descriptions-item>
      <el-descriptions-item label="申请人">{{ historyApply?.applicantName }}</el-descriptions-item>
    </el-descriptions>
    <el-timeline>
      <el-timeline-item v-for="h in historyList" :key="h.id" :timestamp="h.actionTime || ''">
        {{ actionText(h.action) }}
        <span v-if="h.opinion" class="text-12px text-[var(--el-text-color-secondary)]">意见：{{ h.opinion }}</span>
        <div class="text-12px text-[var(--el-text-color-secondary)]">
          {{ h.operatorName }} · {{ h.fromStatus || '—' }} → {{ h.toStatus || '—' }}
        </div>
      </el-timeline-item>
    </el-timeline>
    <el-empty v-if="!historyList.length" description="暂无历史记录" :image-size="60" />
  </el-drawer>
</template>

<script setup lang="ts">
import { dateFormatter } from '@/utils/formatTime'
import { InstrumentDeviceApi, InstrumentDeviceVO } from '@/api/lab/instrument/device'
import {
  InstrumentQualificationApi,
  InstrumentQualificationVO,
  QualificationApplyVO,
  QualApplyHistoryVO
} from '@/api/lab/instrument/qualification'

defineOptions({ name: 'LabInstrumentQualificationAudit' })

const message = useMessage()
const activeTab = ref('apply')

const deviceOptions = ref<InstrumentDeviceVO[]>([])
const loadDevices = async () => {
  deviceOptions.value = (await InstrumentDeviceApi.getPage({ pageNo: 1, pageSize: 200 })).list || []
}

// ========== 申请审核 ==========
const loading = ref(true)
const applyList = ref<QualificationApplyVO[]>([])
const total = ref(0)
const applyQuery = reactive({
  pageNo: 1,
  pageSize: 10,
  status: 'PENDING' as string | undefined,
  deviceId: undefined as number | undefined
})
const applyQueryFormRef = ref()

const applyStatusMeta = (status?: string) =>
  (
    {
      PENDING: { label: '待审核', type: 'warning' },
      APPROVED: { label: '已通过', type: 'success' },
      REJECTED: { label: '已驳回', type: 'danger' },
      CANCELED: { label: '已撤回', type: 'info' }
    } as Record<string, any>
  )[status || ''] || { label: status || '-', type: 'info' }

const qualStatusMeta = (status?: string) =>
  (
    {
      ACTIVE: { label: '生效中', type: 'success' },
      EXPIRED: { label: '已到期', type: 'info' },
      SUSPENDED: { label: '已暂停', type: 'warning' },
      REVOKED: { label: '已撤销', type: 'danger' }
    } as Record<string, any>
  )[status || ''] || { label: status || '-', type: 'info' }

const actionText = (action?: string) =>
  (
    {
      SUBMIT: '提交申请',
      APPROVE: '审核通过',
      REJECT: '审核驳回',
      CANCEL: '撤回申请',
      RESUBMIT: '重新提交'
    } as Record<string, string>
  )[action || ''] || action || ''

const getApplyList = async () => {
  loading.value = true
  try {
    const data = await InstrumentQualificationApi.getApplyPage(applyQuery)
    applyList.value = data.list
    total.value = data.total
  } finally {
    loading.value = false
  }
}
const handleApplyQuery = () => {
  applyQuery.pageNo = 1
  getApplyList()
}
const resetApplyQuery = () => {
  applyQueryFormRef.value.resetFields()
  handleApplyQuery()
}

// 审核
const auditVisible = ref(false)
const auditLoading = ref(false)
const auditRow = ref<QualificationApplyVO>()
const auditForm = reactive({ result: 'APPROVED', opinion: '', expireTime: undefined as string | undefined, remark: '' })
const auditRules = {
  result: [{ required: true, message: '请选择审核结果', trigger: 'change' }]
}
const auditFormRef = ref()

const openAudit = (row: QualificationApplyVO) => {
  auditRow.value = row
  auditForm.result = 'APPROVED'
  auditForm.opinion = ''
  auditForm.expireTime = undefined
  auditForm.remark = ''
  auditVisible.value = true
}
const submitAudit = async () => {
  // 驳回意见必填（服务端同样校验，前端先行提示）
  if (auditForm.result === 'REJECTED' && !auditForm.opinion?.trim()) {
    message.error('驳回时必须填写审核意见')
    return
  }
  await auditFormRef.value?.validate()
  auditLoading.value = true
  try {
    await InstrumentQualificationApi.audit({
      id: auditRow.value!.id!,
      result: auditForm.result,
      opinion: auditForm.opinion || undefined,
      expireTime: auditForm.result === 'APPROVED' ? auditForm.expireTime || undefined : undefined,
      remark: auditForm.remark || undefined
    })
    message.success(auditForm.result === 'APPROVED' ? '已通过，资质已授予' : '已驳回')
    auditVisible.value = false
    await getApplyList()
  } finally {
    auditLoading.value = false
  }
}

// 撤销
const revokeVisible = ref(false)
const revokeLoading = ref(false)
const revokeRow = ref<InstrumentQualificationVO>()
const revokeForm = reactive({ reason: '' })
const revokeRules = {
  reason: [{ required: true, message: '撤销原因不能为空', trigger: 'blur' }]
}
const revokeFormRef = ref()

const openRevoke = (row: InstrumentQualificationVO) => {
  revokeRow.value = row
  revokeForm.reason = ''
  revokeVisible.value = true
}
const submitRevoke = async () => {
  await revokeFormRef.value?.validate()
  revokeLoading.value = true
  try {
    await InstrumentQualificationApi.revoke({ id: revokeRow.value!.id!, reason: revokeForm.reason })
    message.success('资质已撤销')
    revokeVisible.value = false
    await getQualList()
  } finally {
    revokeLoading.value = false
  }
}

// 历史
const historyVisible = ref(false)
const historyApply = ref<QualificationApplyVO>()
const historyList = ref<QualApplyHistoryVO[]>([])
const openHistory = async (row: QualificationApplyVO) => {
  historyApply.value = row
  historyList.value = (await InstrumentQualificationApi.getApplyHistory(row.id!)) || []
  historyVisible.value = true
}

// ========== 资质列表 ==========
const qualLoading = ref(false)
const qualList = ref<InstrumentQualificationVO[]>([])
const qualTotal = ref(0)
const qualQuery = reactive({
  pageNo: 1,
  pageSize: 10,
  status: undefined as string | undefined,
  deviceId: undefined as number | undefined
})
const qualQueryFormRef = ref()

const getQualList = async () => {
  qualLoading.value = true
  try {
    const data = await InstrumentQualificationApi.getQualificationPage(qualQuery)
    qualList.value = data.list
    qualTotal.value = data.total
  } finally {
    qualLoading.value = false
  }
}
const handleQualQuery = () => {
  qualQuery.pageNo = 1
  getQualList()
}
const resetQualQuery = () => {
  qualQueryFormRef.value.resetFields()
  handleQualQuery()
}

const onTabChange = (tab: string) => {
  if (tab === 'apply') getApplyList()
  else getQualList()
}

onMounted(async () => {
  await loadDevices()
  getApplyList()
})
</script>
