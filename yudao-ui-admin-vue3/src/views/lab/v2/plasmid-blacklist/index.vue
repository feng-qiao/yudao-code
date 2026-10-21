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
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_BLACKLIST_STATUS)"
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
          @click="openAdd"
          v-hasPermi="['lab:plasmid:blacklist:add']"
        >
          <Icon icon="ep:plus" class="mr-5px" /> 添加黑名单
        </el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <!-- 列表 -->
  <ContentWrap>
    <el-table v-loading="loading" :data="list" :stripe="true" :show-overflow-tooltip="true">
      <el-table-column label="用户" align="center" prop="userName" />
      <el-table-column label="加入原因" align="center" prop="reason" />
      <el-table-column
        label="生效时间"
        align="center"
        prop="startTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column
        label="计划结束时间"
        align="center"
        prop="endTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="状态" align="center" prop="status">
        <template #default="scope">
          <dict-tag :type="DICT_TYPE.LAB_PLASMID_BLACKLIST_STATUS" :value="scope.row.status" />
        </template>
      </el-table-column>
      <el-table-column label="操作人" align="center" prop="operatorName" />
      <el-table-column
        label="操作时间"
        align="center"
        prop="operateTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="解除人" align="center" prop="removerName" />
      <el-table-column
        label="解除时间"
        align="center"
        prop="removeTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="解除原因" align="center" prop="removeReason" />
      <el-table-column
        label="创建时间"
        align="center"
        prop="createTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="操作" align="center" width="160px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openDetail(scope.row.id)">详情</el-button>
          <el-button
            link
            type="danger"
            @click="openRemove(scope.row)"
            v-hasPermi="['lab:plasmid:blacklist:remove']"
            v-if="scope.row.status === 'ACTIVE'"
          >
            解除
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

  <!-- 添加黑名单弹窗 -->
  <Dialog title="添加黑名单" v-model="addVisible" width="560px">
    <el-form ref="addFormRef" :model="addForm" :rules="addRules" label-width="110px">
      <el-form-item label="关联违规" prop="violationId">
        <el-select
          v-model="addForm.violationId"
          placeholder="请选择关联违规记录"
          filterable
          clearable
          class="!w-350px"
          @change="handleViolationChange"
        >
          <el-option
            v-for="item in violationList"
            :key="item.id"
            :label="
              (item.violationNo || '') +
              ' / ' +
              (item.userName || 'ID:' + item.userId) +
              ' / ' +
              (item.violationType || '')
            "
            :value="item.id"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="用户ID" prop="userId">
        <el-input-number v-model="addForm.userId" :min="1" placeholder="选择违规后自动填充" class="!w-200px" />
      </el-form-item>
      <el-form-item label="加入原因" prop="reason">
        <el-input v-model="addForm.reason" type="textarea" placeholder="请输入加入原因" />
      </el-form-item>
      <el-form-item label="生效时间" prop="startTime">
        <el-date-picker
          v-model="addForm.startTime"
          type="datetime"
          placeholder="默认为当前时间"
          value-format="YYYY-MM-DD HH:mm:ss"
          class="!w-350px"
        />
      </el-form-item>
      <el-form-item label="计划结束时间" prop="endTime">
        <el-date-picker
          v-model="addForm.endTime"
          type="datetime"
          placeholder="选填，仅参考"
          value-format="YYYY-MM-DD HH:mm:ss"
          class="!w-350px"
        />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="addForm.remark" type="textarea" placeholder="请输入备注" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="addVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitAdd">确 定</el-button>
    </template>
  </Dialog>

  <!-- 解除黑名单弹窗 -->
  <Dialog title="解除黑名单" v-model="removeVisible" width="560px">
    <el-form ref="removeFormRef" :model="removeForm" :rules="removeRules" label-width="110px">
      <el-form-item label="用户">
        <el-input :model-value="removeForm.userName" disabled />
      </el-form-item>
      <el-form-item label="加入原因">
        <el-input :model-value="removeForm.reason" type="textarea" disabled />
      </el-form-item>
      <el-form-item label="解除原因" prop="removeReason">
        <el-input
          v-model="removeForm.removeReason"
          type="textarea"
          placeholder="请输入解除原因（必填）"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="removeVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitRemove">确 定</el-button>
    </template>
  </Dialog>

  <!-- 详情弹窗 -->
  <Dialog title="黑名单详情" v-model="detailVisible" width="720px">
    <el-descriptions :column="2" border v-loading="detailLoading">
      <el-descriptions-item label="用户">{{ detailData.userName }}</el-descriptions-item>
      <el-descriptions-item label="状态">
        <dict-tag :type="DICT_TYPE.LAB_PLASMID_BLACKLIST_STATUS" :value="detailData.status || ''" />
      </el-descriptions-item>
      <el-descriptions-item label="加入原因" :span="2">{{ detailData.reason }}</el-descriptions-item>
      <el-descriptions-item label="生效时间">{{ formatDate(detailData.startTime) }}</el-descriptions-item>
      <el-descriptions-item label="计划结束时间">{{ formatDate(detailData.endTime) }}</el-descriptions-item>
      <el-descriptions-item label="操作人">{{ detailData.operatorName }}</el-descriptions-item>
      <el-descriptions-item label="操作时间">{{ formatDate(detailData.operateTime) }}</el-descriptions-item>
      <el-descriptions-item label="解除人">{{ detailData.removerName }}</el-descriptions-item>
      <el-descriptions-item label="解除时间">{{ formatDate(detailData.removeTime) }}</el-descriptions-item>
      <el-descriptions-item label="解除原因" :span="2">{{ detailData.removeReason }}</el-descriptions-item>
      <el-descriptions-item label="关联违规单号">{{ detailData.violationNo }}</el-descriptions-item>
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
import {
  PlasmidBlacklistApi,
  PlasmidBlacklistVO,
  PlasmidBlacklistAddVO,
  PlasmidBlacklistRemoveVO
} from '@/api/lab/v2/plasmid-blacklist'
import { PlasmidViolationApi, PlasmidViolationVO } from '@/api/lab/v2/plasmid-violation'

/** 借用黑名单（V2） */
defineOptions({ name: 'PlasmidV2Blacklist' })

const message = useMessage()

const loading = ref(true)
const list = ref<PlasmidBlacklistVO[]>([])
const total = ref(0)
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  userId: undefined,
  status: undefined
})
const queryFormRef = ref()

/** 违规列表（添加黑名单时选择关联违规） */
const violationList = ref<PlasmidViolationVO[]>([])
const getViolationList = async () => {
  const data = await PlasmidViolationApi.getViolationPage({ pageNo: 1, pageSize: 100 })
  violationList.value = data.list
}

/** 查询列表 */
const getList = async () => {
  loading.value = true
  try {
    const data = await PlasmidBlacklistApi.getBlacklistPage(queryParams)
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

/** 详情 */
const detailVisible = ref(false)
const detailLoading = ref(false)
const detailData = ref<PlasmidBlacklistVO>({} as PlasmidBlacklistVO)
const openDetail = async (id: number) => {
  detailVisible.value = true
  detailLoading.value = true
  try {
    detailData.value = await PlasmidBlacklistApi.getBlacklist(id)
  } finally {
    detailLoading.value = false
  }
}

// ==================== 添加 ====================
const submitLoading = ref(false)

const addVisible = ref(false)
const addFormRef = ref()
const addForm = reactive({
  violationId: undefined as number | undefined,
  userId: undefined as number | undefined,
  reason: '',
  startTime: '',
  endTime: '',
  remark: ''
})
const addRules = {
  userId: [{ required: true, message: '用户不能为空', trigger: 'blur' }],
  reason: [{ required: true, message: '加入原因不能为空', trigger: 'blur' }]
}

const handleViolationChange = (violationId: number) => {
  const violation = violationList.value.find((v) => v.id === violationId)
  if (violation && violation.userId) {
    addForm.userId = violation.userId
  }
}

const openAdd = () => {
  Object.assign(addForm, {
    violationId: undefined,
    userId: undefined,
    reason: '',
    startTime: '',
    endTime: '',
    remark: ''
  })
  addVisible.value = true
  nextTick(() => addFormRef.value?.clearValidate())
}

const submitAdd = async () => {
  await addFormRef.value.validate()
  submitLoading.value = true
  try {
    const data: PlasmidBlacklistAddVO = {
      userId: addForm.userId!,
      reason: addForm.reason,
      startTime: addForm.startTime || undefined,
      endTime: addForm.endTime || undefined,
      violationId: addForm.violationId || undefined,
      remark: addForm.remark || undefined
    }
    await PlasmidBlacklistApi.addBlacklist(data)
    message.success('添加成功')
    addVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

// ==================== 解除 ====================
const removeVisible = ref(false)
const removeFormRef = ref()
const removeForm = reactive({
  id: 0,
  userName: '',
  reason: '',
  removeReason: ''
})
const removeRules = {
  removeReason: [{ required: true, message: '解除原因不能为空', trigger: 'blur' }]
}

const openRemove = (row: PlasmidBlacklistVO) => {
  Object.assign(removeForm, {
    id: row.id,
    userName: row.userName,
    reason: row.reason,
    removeReason: ''
  })
  removeVisible.value = true
  nextTick(() => removeFormRef.value?.clearValidate())
}

const submitRemove = async () => {
  await removeFormRef.value.validate()
  submitLoading.value = true
  try {
    const data: PlasmidBlacklistRemoveVO = {
      id: removeForm.id,
      removeReason: removeForm.removeReason
    }
    await PlasmidBlacklistApi.removeBlacklist(data)
    message.success('解除成功')
    removeVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

/** 初始化 */
onMounted(() => {
  getViolationList()
  getList()
})
</script>
