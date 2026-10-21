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
      <el-form-item label="违规单号" prop="violationNo">
        <el-input
          v-model="queryParams.violationNo"
          placeholder="请输入违规单号"
          clearable
          @keyup.enter="handleQuery"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="用户" prop="userId">
        <el-input
          v-model="queryParams.userId"
          placeholder="请输入用户ID"
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
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_VIOLATION_STATUS)"
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
          @click="openCreate"
          v-hasPermi="['lab:plasmid:violation:create']"
        >
          <Icon icon="ep:plus" class="mr-5px" /> 登记违规
        </el-button>
        <el-button
          type="warning"
          plain
          @click="handleExport"
          v-hasPermi="['lab:plasmid:violation:export']"
        >
          <Icon icon="ep:download" class="mr-5px" /> 导出
        </el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <!-- 列表 -->
  <ContentWrap>
    <el-table v-loading="loading" :data="list" :stripe="true" :show-overflow-tooltip="true">
      <el-table-column label="违规单号" align="center" prop="violationNo" width="180px" />
      <el-table-column label="违规用户" align="center" prop="userName" />
      <el-table-column label="质粒" align="center">
        <template #default="scope">
          <span v-if="plasmidMap[scope.row.plasmidId]">
            {{ plasmidMap[scope.row.plasmidId].plasmidNo }} /
            {{ plasmidMap[scope.row.plasmidId].name }}
          </span>
          <span v-else>ID: {{ scope.row.plasmidId }}</span>
        </template>
      </el-table-column>
      <el-table-column label="关联借用单号" align="center" prop="borrowNo" width="180px" />
      <el-table-column label="违规类型" align="center" prop="violationType">
        <template #default="scope">
          <dict-tag :type="DICT_TYPE.LAB_PLASMID_VIOLATION_TYPE" :value="scope.row.violationType" />
        </template>
      </el-table-column>
      <el-table-column label="描述" align="center" prop="description" />
      <el-table-column
        label="发生时间"
        align="center"
        prop="occurredTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="状态" align="center" prop="status">
        <template #default="scope">
          <dict-tag :type="DICT_TYPE.LAB_PLASMID_VIOLATION_STATUS" :value="scope.row.status" />
        </template>
      </el-table-column>
      <el-table-column label="处理人" align="center" prop="handlerName" />
      <el-table-column
        label="处理时间"
        align="center"
        prop="handleTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="处理结果" align="center" prop="handleResult" />
      <el-table-column
        label="创建时间"
        align="center"
        prop="createTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="操作" align="center" width="180px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openDetail(scope.row.id)">详情</el-button>
          <el-button
            link
            type="warning"
            @click="openHandle(scope.row)"
            v-hasPermi="['lab:plasmid:violation:handle']"
            v-if="scope.row.status === 'PENDING'"
          >
            处理
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

  <!-- 登记违规弹窗 -->
  <Dialog title="登记违规" v-model="createVisible" width="560px">
    <el-form ref="createFormRef" :model="createForm" :rules="createRules" label-width="110px">
      <el-form-item label="违规用户ID" prop="userId">
        <el-input-number v-model="createForm.userId" :min="1" class="!w-200px" />
      </el-form-item>
      <el-form-item label="违规类型" prop="violationType">
        <el-select v-model="createForm.violationType" placeholder="请选择违规类型" class="!w-350px">
          <el-option label="归还不合规" value="RETURN_NONCOMPLIANCE" />
          <el-option label="其他" value="OTHER" />
        </el-select>
      </el-form-item>
      <el-form-item label="违规描述" prop="description">
        <el-input
          v-model="createForm.description"
          type="textarea"
          placeholder="请输入违规描述"
        />
      </el-form-item>
      <el-form-item label="发生时间" prop="occurredTime">
        <el-date-picker
          v-model="createForm.occurredTime"
          type="datetime"
          placeholder="请选择发生时间"
          value-format="YYYY-MM-DD HH:mm:ss"
          class="!w-350px"
        />
      </el-form-item>
      <el-form-item label="关联借用单" prop="borrowId">
        <el-input-number v-model="createForm.borrowId" :min="1" placeholder="选填" class="!w-200px" />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="createForm.remark" type="textarea" placeholder="请输入备注" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="createVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitCreate">确 定</el-button>
    </template>
  </Dialog>

  <!-- 处理违规弹窗 -->
  <Dialog title="处理违规" v-model="handleVisible" width="560px">
    <el-form ref="handleFormRef" :model="handleForm" :rules="handleRules" label-width="110px">
      <el-form-item label="违规单号">
        <el-input :model-value="handleForm.violationNo" disabled />
      </el-form-item>
      <el-form-item label="违规用户">
        <el-input :model-value="handleForm.userName" disabled />
      </el-form-item>
      <el-form-item label="违规类型">
        <dict-tag :type="DICT_TYPE.LAB_PLASMID_VIOLATION_TYPE" :value="handleForm.violationType" />
      </el-form-item>
      <el-form-item label="违规描述">
        <el-input :model-value="handleForm.description" type="textarea" disabled />
      </el-form-item>
      <el-form-item label="处理结果" prop="handleResult">
        <el-input
          v-model="handleForm.handleResult"
          type="textarea"
          placeholder="请输入处理结果"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="handleVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitHandle">确 定</el-button>
    </template>
  </Dialog>

  <!-- 详情弹窗 -->
  <Dialog title="违规详情" v-model="detailVisible" width="720px">
    <el-descriptions :column="2" border v-loading="detailLoading">
      <el-descriptions-item label="违规单号">{{ detailData.violationNo }}</el-descriptions-item>
      <el-descriptions-item label="违规用户">{{ detailData.userName }}</el-descriptions-item>
      <el-descriptions-item label="质粒">
        <span v-if="plasmidMap[detailData.plasmidId]">
          {{ plasmidMap[detailData.plasmidId].plasmidNo }} /
          {{ plasmidMap[detailData.plasmidId].name }}
        </span>
        <span v-else>ID: {{ detailData.plasmidId }}</span>
      </el-descriptions-item>
      <el-descriptions-item label="关联借用单号">{{ detailData.borrowNo }}</el-descriptions-item>
      <el-descriptions-item label="违规类型">
        <dict-tag :type="DICT_TYPE.LAB_PLASMID_VIOLATION_TYPE" :value="detailData.violationType || ''" />
      </el-descriptions-item>
      <el-descriptions-item label="状态">
        <dict-tag :type="DICT_TYPE.LAB_PLASMID_VIOLATION_STATUS" :value="detailData.status || ''" />
      </el-descriptions-item>
      <el-descriptions-item label="发生时间">{{ formatDate(detailData.occurredTime) }}</el-descriptions-item>
      <el-descriptions-item label="处理人">{{ detailData.handlerName }}</el-descriptions-item>
      <el-descriptions-item label="处理时间">{{ formatDate(detailData.handleTime) }}</el-descriptions-item>
      <el-descriptions-item label="处理结果" :span="2">{{ detailData.handleResult }}</el-descriptions-item>
      <el-descriptions-item label="违规描述" :span="2">{{ detailData.description }}</el-descriptions-item>
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
  PlasmidViolationApi,
  PlasmidViolationVO,
  PlasmidViolationCreateVO,
  PlasmidViolationHandleVO
} from '@/api/lab/v2/plasmid-violation'
import { PlasmidApi, PlasmidVO } from '@/api/lab/v2/plasmid'

/** 违规记录（V2） */
defineOptions({ name: 'PlasmidV2Violation' })

const message = useMessage()

const loading = ref(true)
const list = ref<PlasmidViolationVO[]>([])
const total = ref(0)
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  violationNo: undefined,
  userId: undefined,
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

/** 查询列表 */
const getList = async () => {
  loading.value = true
  try {
    const data = await PlasmidViolationApi.getViolationPage(queryParams)
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
    const data = await PlasmidViolationApi.exportViolation(queryParams)
    download.excel(data, '违规记录.xls')
  } catch {}
}

/** 详情 */
const detailVisible = ref(false)
const detailLoading = ref(false)
const detailData = ref<PlasmidViolationVO>({} as PlasmidViolationVO)
const openDetail = async (id: number) => {
  detailVisible.value = true
  detailLoading.value = true
  try {
    detailData.value = await PlasmidViolationApi.getViolation(id)
  } finally {
    detailLoading.value = false
  }
}

// ==================== 登记 ====================
const submitLoading = ref(false)

const createVisible = ref(false)
const createFormRef = ref()
const createForm = reactive({
  userId: undefined as number | undefined,
  violationType: '',
  description: '',
  occurredTime: '',
  borrowId: undefined as number | undefined,
  plasmidId: undefined as number | undefined,
  returnId: undefined as number | undefined,
  remark: ''
})
const createRules = {
  userId: [{ required: true, message: '违规用户不能为空', trigger: 'blur' }],
  violationType: [{ required: true, message: '违规类型不能为空', trigger: 'change' }],
  description: [{ required: true, message: '违规描述不能为空', trigger: 'blur' }],
  occurredTime: [{ required: true, message: '发生时间不能为空', trigger: 'change' }]
}

const openCreate = () => {
  Object.assign(createForm, {
    userId: undefined,
    violationType: '',
    description: '',
    occurredTime: '',
    borrowId: undefined,
    plasmidId: undefined,
    returnId: undefined,
    remark: ''
  })
  createVisible.value = true
  nextTick(() => createFormRef.value?.clearValidate())
}

const submitCreate = async () => {
  await createFormRef.value.validate()
  submitLoading.value = true
  try {
    const data: PlasmidViolationCreateVO = {
      userId: createForm.userId!,
      violationType: createForm.violationType,
      description: createForm.description,
      occurredTime: createForm.occurredTime,
      borrowId: createForm.borrowId || undefined,
      plasmidId: createForm.plasmidId || undefined,
      returnId: createForm.returnId || undefined,
      remark: createForm.remark || undefined
    }
    await PlasmidViolationApi.createViolation(data)
    message.success('登记成功')
    createVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

// ==================== 处理 ====================
const handleVisible = ref(false)
const handleFormRef = ref()
const handleForm = reactive({
  id: 0,
  violationNo: '',
  userName: '',
  violationType: '',
  description: '',
  handleResult: ''
})
const handleRules = {
  handleResult: [{ required: true, message: '处理结果不能为空', trigger: 'blur' }]
}

const openHandle = (row: PlasmidViolationVO) => {
  Object.assign(handleForm, {
    id: row.id,
    violationNo: row.violationNo,
    userName: row.userName,
    violationType: row.violationType,
    description: row.description,
    handleResult: ''
  })
  handleVisible.value = true
  nextTick(() => handleFormRef.value?.clearValidate())
}

const submitHandle = async () => {
  await handleFormRef.value.validate()
  submitLoading.value = true
  try {
    const data: PlasmidViolationHandleVO = {
      id: handleForm.id,
      handleResult: handleForm.handleResult
    }
    await PlasmidViolationApi.handleViolation(data)
    message.success('处理完成')
    handleVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

/** 初始化 */
onMounted(() => {
  getPlasmidList()
  getList()
})
</script>
