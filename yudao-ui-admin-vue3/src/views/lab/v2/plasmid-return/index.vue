<template>
  <ContentWrap>
    <!-- 搜索工作栏 -->
    <el-form
      class="-mb-15px"
      :model="queryParams"
      ref="queryFormRef"
      :inline="true"
      label-width="80px"
    >
      <el-form-item label="归还单号" prop="returnNo">
        <el-input
          v-model="queryParams.returnNo"
          placeholder="请输入归还单号"
          clearable
          @keyup.enter="handleQuery"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select
          v-model="queryParams.status"
          placeholder="请选择状态"
          clearable
          class="!w-200px"
        >
          <el-option
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_RETURN_STATUS)"
            :key="dict.value"
            :label="dict.label"
            :value="dict.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" /> 搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" /> 重置</el-button>
        <el-button
          type="primary"
          plain
          @click="openApply"
          v-hasPermi="['lab:plasmid:return:apply']"
        >
          <Icon icon="ep:plus" class="mr-5px" /> 申请归还
        </el-button>
        <el-button
          type="warning"
          plain
          @click="handleExport"
          v-hasPermi="['lab:plasmid:return:export']"
        >
          <Icon icon="ep:download" class="mr-5px" /> 导出
        </el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <!-- 列表 -->
  <ContentWrap>
    <el-table v-loading="loading" :data="list" :stripe="true" :show-overflow-tooltip="true">
      <el-table-column label="归还单号" align="center" prop="returnNo" width="180px" />
      <el-table-column label="关联借用单号" align="center" prop="borrowNo" width="180px" />
      <el-table-column label="质粒" align="center">
        <template #default="scope">
          <span v-if="plasmidMap[scope.row.plasmidId]">
            {{ plasmidMap[scope.row.plasmidId].plasmidNo }} /
            {{ plasmidMap[scope.row.plasmidId].name }}
          </span>
          <span v-else>ID: {{ scope.row.plasmidId }}</span>
        </template>
      </el-table-column>
      <el-table-column label="归还人" align="center" prop="returnerName" />
      <el-table-column label="归还类型" align="center" prop="returnType">
        <template #default="scope">
          <dict-tag :type="DICT_TYPE.LAB_PLASMID_RETURN_TYPE" :value="scope.row.returnType" />
        </template>
      </el-table-column>
      <el-table-column label="计划归还(μL)" align="center" prop="plannedQuantity" />
      <el-table-column label="实际归还(μL)" align="center" prop="actualQuantity" />
      <el-table-column label="状态" align="center" prop="status">
        <template #default="scope">
          <dict-tag :type="DICT_TYPE.LAB_PLASMID_RETURN_STATUS" :value="scope.row.status" />
        </template>
      </el-table-column>
      <el-table-column label="审核人" align="center" prop="reviewerName" />
      <el-table-column
        label="审核时间"
        align="center"
        prop="reviewTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="审核结果" align="center" prop="reviewResult" />
      <el-table-column label="审核意见" align="center" prop="reviewOpinion" />
      <el-table-column
        label="申请时间"
        align="center"
        prop="applyTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column
        label="实际归还时间"
        align="center"
        prop="actualReturnTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="操作" align="center" width="180px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openDetail(scope.row.id)">详情</el-button>
          <el-button
            link
            type="warning"
            @click="openAudit(scope.row)"
            v-hasPermi="['lab:plasmid:return:audit']"
            v-if="scope.row.status === 'PENDING'"
          >
            审核
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <!-- 分页 -->
    <Pagination
      :total="total"
      v-model:page="queryParams.pageNo"
      v-model:limit="queryParams.pageSize"
      @pagination="getList"
    />
  </ContentWrap>

  <!-- 申请归还弹窗 -->
  <Dialog title="申请归还" v-model="applyVisible" width="560px">
    <el-form ref="applyFormRef" :model="applyForm" :rules="applyRules" label-width="110px">
      <el-form-item label="借用单" prop="borrowId">
        <el-select
          v-model="applyForm.borrowId"
          placeholder="请选择借用单"
          filterable
          class="!w-350px"
          @change="handleBorrowChange"
        >
          <el-option
            v-for="item in borrowList"
            :key="item.id"
            :label="
              (item.borrowNo || '') +
              ' / ' +
              (plasmidMap[item.plasmidId]?.name || 'ID:' + item.plasmidId) +
              ' (已还:' +
              (item.returnQuantity || 0) +
              '/' +
              (item.approvedQuantity || item.requestedQuantity || 0) +
              ')'
            "
            :value="item.id"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="归还类型" prop="returnType">
        <el-select v-model="applyForm.returnType" placeholder="请选择归还类型" class="!w-350px">
          <el-option
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_RETURN_TYPE)"
            :key="dict.value"
            :label="dict.label"
            :value="dict.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item
        label="其他归还类型"
        prop="otherReturnType"
        v-if="applyForm.returnType === 'OTHER'"
      >
        <el-input v-model="applyForm.otherReturnType" placeholder="请输入其他归还类型说明" />
      </el-form-item>
      <el-form-item label="计划归还(μL)" prop="plannedQuantity">
        <el-input-number
          v-model="applyForm.plannedQuantity"
          :min="0.0001"
          :precision="3"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="applyForm.remark" type="textarea" placeholder="请输入备注" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="applyVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitApply">确 定</el-button>
    </template>
  </Dialog>

  <!-- 审核弹窗 -->
  <Dialog title="归还审核" v-model="auditVisible" width="560px">
    <el-form ref="auditFormRef" :model="auditForm" :rules="auditRules" label-width="110px">
      <el-form-item label="归还单号">
        <el-input :model-value="auditForm.returnNo" disabled />
      </el-form-item>
      <el-form-item label="计划归还(μL)">
        <el-input :model-value="auditForm.plannedQuantity" disabled />
      </el-form-item>
      <el-form-item label="审核结果" prop="reviewResult">
        <el-radio-group v-model="auditForm.reviewResult">
          <el-radio label="APPROVED">通过</el-radio>
          <el-radio label="REJECTED">驳回</el-radio>
        </el-radio-group>
      </el-form-item>
      <el-form-item label="审核意见" prop="reviewOpinion">
        <el-input
          v-model="auditForm.reviewOpinion"
          type="textarea"
          placeholder="驳回时必填审核意见"
        />
      </el-form-item>
      <el-form-item label="实际归还(μL)" prop="actualQuantity" v-if="auditForm.reviewResult === 'APPROVED'">
        <el-input-number
          v-model="auditForm.actualQuantity"
          :min="0.0001"
          :precision="3"
          class="!w-200px"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="auditVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitAudit">确 定</el-button>
    </template>
  </Dialog>

  <!-- 详情弹窗 -->
  <Dialog title="归还详情" v-model="detailVisible" width="720px">
    <el-descriptions :column="2" border v-loading="detailLoading">
      <el-descriptions-item label="归还单号">{{ detailData.returnNo }}</el-descriptions-item>
      <el-descriptions-item label="关联借用单号">{{ detailData.borrowNo }}</el-descriptions-item>
      <el-descriptions-item label="质粒">
        <span v-if="plasmidMap[detailData.plasmidId]">
          {{ plasmidMap[detailData.plasmidId].plasmidNo }} /
          {{ plasmidMap[detailData.plasmidId].name }}
        </span>
        <span v-else>ID: {{ detailData.plasmidId }}</span>
      </el-descriptions-item>
      <el-descriptions-item label="归还人">{{ detailData.returnerName }}</el-descriptions-item>
      <el-descriptions-item label="归还类型">
        <dict-tag :type="DICT_TYPE.LAB_PLASMID_RETURN_TYPE" :value="detailData.returnType || ''" />
      </el-descriptions-item>
      <el-descriptions-item label="其他归还类型" v-if="detailData.returnType === 'OTHER'">
        {{ detailData.otherReturnType }}
      </el-descriptions-item>
      <el-descriptions-item label="计划归还(μL)">{{ detailData.plannedQuantity }}</el-descriptions-item>
      <el-descriptions-item label="实际归还(μL)">{{ detailData.actualQuantity }}</el-descriptions-item>
      <el-descriptions-item label="状态">
        <dict-tag :type="DICT_TYPE.LAB_PLASMID_RETURN_STATUS" :value="detailData.status || ''" />
      </el-descriptions-item>
      <el-descriptions-item label="审核人">{{ detailData.reviewerName }}</el-descriptions-item>
      <el-descriptions-item label="审核时间">{{ formatDate(detailData.reviewTime) }}</el-descriptions-item>
      <el-descriptions-item label="审核结果">{{ detailData.reviewResult }}</el-descriptions-item>
      <el-descriptions-item label="审核意见">{{ detailData.reviewOpinion }}</el-descriptions-item>
      <el-descriptions-item label="申请时间">{{ formatDate(detailData.applyTime) }}</el-descriptions-item>
      <el-descriptions-item label="实际归还时间">{{ formatDate(detailData.actualReturnTime) }}</el-descriptions-item>
      <el-descriptions-item label="备注" :span="2">{{ detailData.remark }}</el-descriptions-item>
    </el-descriptions>
    <template #footer>
      <el-button @click="detailVisible = false">关 闭</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { getStrDictOptions, DICT_TYPE } from '@/utils/dict'
import { dateFormatter, formatDate } from '@/utils/formatTime'
import download from '@/utils/download'
import {
  PlasmidReturnApi,
  PlasmidReturnVO,
  PlasmidReturnApplyVO,
  PlasmidReturnAuditVO
} from '@/api/lab/v2/plasmid-return'
import { PlasmidBorrowApi, PlasmidBorrowVO } from '@/api/lab/v2/plasmid-borrow'
import { PlasmidApi, PlasmidVO } from '@/api/lab/v2/plasmid'

/** 质粒归还（V2） */
defineOptions({ name: 'PlasmidV2Return' })

const message = useMessage()

const loading = ref(true)
const list = ref<PlasmidReturnVO[]>([])
const total = ref(0)
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  returnNo: undefined,
  status: undefined
})
const queryFormRef = ref()

/** 质粒列表（plasmidMap 映射） */
const plasmidList = ref<PlasmidVO[]>([])
const plasmidMap = computed(() => {
  const map: Record<number, { plasmidNo?: string; name?: string }> = {}
  plasmidList.value.forEach((item) => {
    if (item.id) {
      map[item.id] = { plasmidNo: item.plasmidNo, name: item.name }
    }
  })
  return map
})
const getPlasmidList = async () => {
  const data = await PlasmidApi.getPlasmidPage({ pageNo: 1, pageSize: 100 })
  plasmidList.value = data.list
}

/** 本人借用单（用于归还申请选择） */
const borrowList = ref<PlasmidBorrowVO[]>([])
const getBorrowList = async () => {
  const data = await PlasmidBorrowApi.getBorrowPage({ pageNo: 1, pageSize: 100 })
  borrowList.value = data.list
}

/** 查询列表 */
const getList = async () => {
  loading.value = true
  try {
    const data = await PlasmidReturnApi.getReturnPage(queryParams)
    list.value = data.list
    total.value = data.total
  } finally {
    loading.value = false
  }
}

/** 搜索 */
const handleQuery = () => {
  queryParams.pageNo = 1
  getList()
}

/** 重置 */
const resetQuery = () => {
  queryFormRef.value.resetFields()
  handleQuery()
}

/** 导出 */
const handleExport = async () => {
  try {
    await message.exportConfirm()
    const data = await PlasmidReturnApi.exportReturn(queryParams)
    download.excel(data, '归还记录.xls')
  } catch {}
}

/** 详情 */
const detailVisible = ref(false)
const detailLoading = ref(false)
const detailData = ref<PlasmidReturnVO>({} as PlasmidReturnVO)
const openDetail = async (id: number) => {
  detailVisible.value = true
  detailLoading.value = true
  try {
    detailData.value = await PlasmidReturnApi.getReturn(id)
  } finally {
    detailLoading.value = false
  }
}

// ==================== 申请 ====================
const submitLoading = ref(false)

const applyVisible = ref(false)
const applyFormRef = ref()
const applyForm = reactive({
  borrowId: undefined as number | undefined,
  returnType: '',
  otherReturnType: '',
  plannedQuantity: null as number | null,
  remark: ''
})
const applyRules = {
  borrowId: [{ required: true, message: '请选择借用单', trigger: 'change' }],
  returnType: [{ required: true, message: '归还类型不能为空', trigger: 'change' }],
  otherReturnType: [
    {
      validator: (_rule: any, value: string, callback: any) => {
        if (applyForm.returnType === 'OTHER' && (!value || !value.trim())) {
          callback(new Error('其他归还类型说明不能为空'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ],
  plannedQuantity: [
    { required: true, message: '计划归还数量不能为空', trigger: 'blur' },
    {
      validator: (_rule: any, value: number, callback: any) => {
        if (value === undefined || value === null || value <= 0) {
          callback(new Error('计划归还数量必须大于 0'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ]
}

const handleBorrowChange = (borrowId: number) => {
  const borrow = borrowList.value.find((b) => b.id === borrowId)
  if (borrow) {
    const remaining = (borrow.approvedQuantity || borrow.requestedQuantity || 0) - (borrow.returnQuantity || 0)
    if (remaining > 0) {
      applyForm.plannedQuantity = remaining
    }
  }
}

const openApply = () => {
  Object.assign(applyForm, {
    borrowId: undefined,
    returnType: '',
    otherReturnType: '',
    plannedQuantity: null,
    remark: ''
  })
  applyVisible.value = true
  nextTick(() => applyFormRef.value?.clearValidate())
}

const submitApply = async () => {
  await applyFormRef.value.validate()
  submitLoading.value = true
  try {
    await PlasmidReturnApi.applyReturn(applyForm as PlasmidReturnApplyVO)
    message.success('申请成功')
    applyVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

// ==================== 审核 ====================
const auditVisible = ref(false)
const auditFormRef = ref()
const auditForm = reactive({
  id: 0,
  returnNo: '',
  plannedQuantity: 0,
  reviewResult: 'APPROVED' as string,
  reviewOpinion: '',
  actualQuantity: null as number | null
})
const auditRules = {
  reviewResult: [{ required: true, message: '请选择审核结果', trigger: 'change' }],
  reviewOpinion: [
    {
      validator: (_rule: any, value: string, callback: any) => {
        if (auditForm.reviewResult === 'REJECTED' && (!value || !value.trim())) {
          callback(new Error('驳回时审核意见不能为空'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ],
  actualQuantity: [
    {
      validator: (_rule: any, value: number, callback: any) => {
        if (auditForm.reviewResult === 'APPROVED' && (value === undefined || value === null || value <= 0)) {
          callback(new Error('通过时实际归还数量必须大于 0'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ]
}

const openAudit = (row: PlasmidReturnVO) => {
  Object.assign(auditForm, {
    id: row.id,
    returnNo: row.returnNo,
    plannedQuantity: row.plannedQuantity,
    reviewResult: 'APPROVED',
    reviewOpinion: '',
    actualQuantity: row.plannedQuantity
  })
  auditVisible.value = true
  nextTick(() => auditFormRef.value?.clearValidate())
}

const submitAudit = async () => {
  await auditFormRef.value.validate()
  submitLoading.value = true
  try {
    const data: PlasmidReturnAuditVO = {
      id: auditForm.id,
      reviewResult: auditForm.reviewResult,
      reviewOpinion: auditForm.reviewOpinion || undefined,
      actualQuantity:
        auditForm.reviewResult === 'APPROVED' ? auditForm.actualQuantity || undefined : undefined
    }
    await PlasmidReturnApi.auditReturn(data)
    message.success('审核完成')
    auditVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

/** 初始化 */
onMounted(() => {
  getPlasmidList()
  getBorrowList()
  getList()
})
</script>
