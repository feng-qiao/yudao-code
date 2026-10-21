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
      <el-form-item label="质粒编号" prop="plasmidNo">
        <el-input
          v-model="queryParams.plasmidNo"
          placeholder="请输入质粒编号"
          clearable
          @keyup.enter="handleQuery"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="质粒名称" prop="plasmidName">
        <el-input
          v-model="queryParams.plasmidName"
          placeholder="请输入质粒名称"
          clearable
          @keyup.enter="handleQuery"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="质粒类型" prop="plasmidTypeId">
        <el-select
          v-model="queryParams.plasmidTypeId"
          placeholder="请选择质粒类型"
          clearable
          filterable
          class="!w-200px"
        >
          <el-option
            v-for="item in typeList"
            :key="item.id"
            :label="item.name"
            :value="item.id"
          />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" /> 搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" /> 重置</el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <!-- 位置列表 -->
  <ContentWrap>
    <el-table v-loading="loading" :data="list" :stripe="true" :show-overflow-tooltip="true">
      <el-table-column label="质粒编号" align="center" prop="plasmidNo" width="140px" />
      <el-table-column label="质粒名称" align="center" prop="plasmidName" />
      <el-table-column label="质粒类型" align="center" prop="plasmidTypeName" width="120px" />
      <el-table-column label="正式质粒位置" align="center" min-width="180px">
        <template #default="scope">
          {{ formatPosition(scope.row, 'plasmid') || '—' }}
        </template>
      </el-table-column>
      <el-table-column label="正式甘油菌位置" align="center" min-width="180px">
        <template #default="scope">
          {{ formatPosition(scope.row, 'glycerin') || '—' }}
        </template>
      </el-table-column>
      <el-table-column label="位置状态" align="center" width="100px">
        <template #default="scope">
          <el-tag v-if="scope.row.positionConfirmed" type="success">已确认</el-tag>
          <el-tag v-else type="warning">未确认</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="最后修改人" align="center" prop="lastModifierName" width="110px" />
      <el-table-column
        label="最后修改时间"
        align="center"
        prop="lastModifierTime"
        :formatter="dateFormatter"
        width="170px"
      />
      <el-table-column label="操作" align="center" width="220px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openDetail(scope.row)">查看位置</el-button>
          <el-button
            link
            type="success"
            @click="openEdit(scope.row)"
            v-hasPermi="['lab:plasmid-storage:update']"
          >
            修改位置
          </el-button>
          <el-button link type="info" @click="openHistory(scope.row)">修改历史</el-button>
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

  <!-- ==================== 位置详情 Dialog（正式 + 原始申报分区） ==================== -->
  <Dialog title="存放位置详情" v-model="detailVisible" width="760px">
    <div v-loading="detailLoading">
      <el-divider content-position="left">质粒信息</el-divider>
      <el-descriptions :column="3" border>
        <el-descriptions-item label="质粒编号">{{ detailData.plasmidNo }}</el-descriptions-item>
        <el-descriptions-item label="质粒名称">{{ detailData.plasmidName }}</el-descriptions-item>
        <el-descriptions-item label="质粒类型">{{ detailData.plasmidTypeName }}</el-descriptions-item>
      </el-descriptions>

      <el-divider content-position="left">正式质粒位置</el-divider>
      <el-descriptions :column="4" border>
        <el-descriptions-item label="冰箱">{{ detailData.plasmidFridge || '—' }}</el-descriptions-item>
        <el-descriptions-item label="层">{{ detailData.plasmidLayer || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒">{{ detailData.plasmidBox || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒内位置">{{ detailData.plasmidPosition || '—' }}</el-descriptions-item>
      </el-descriptions>

      <el-divider content-position="left">正式甘油菌位置</el-divider>
      <el-descriptions :column="4" border>
        <el-descriptions-item label="冰箱">{{ detailData.glycerinFridge || '—' }}</el-descriptions-item>
        <el-descriptions-item label="层">{{ detailData.glycerinLayer || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒">{{ detailData.glycerinBox || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒内位置">{{ detailData.glycerinPosition || '—' }}</el-descriptions-item>
      </el-descriptions>

      <el-divider content-position="left">原始申报位置（登记时申报，不随后续修改变化）</el-divider>
      <el-descriptions :column="4" border>
        <el-descriptions-item label="冰箱">{{ detailData.originalPlasmidFridge || '—' }}</el-descriptions-item>
        <el-descriptions-item label="层">{{ detailData.originalPlasmidLayer || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒">{{ detailData.originalPlasmidBox || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒内位置">{{ detailData.originalPlasmidPosition || '—' }}</el-descriptions-item>
      </el-descriptions>
      <el-descriptions :column="4" border class="mt-8px">
        <el-descriptions-item label="冰箱">{{ detailData.originalGlycerinFridge || '—' }}</el-descriptions-item>
        <el-descriptions-item label="层">{{ detailData.originalGlycerinLayer || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒">{{ detailData.originalGlycerinBox || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒内位置">{{ detailData.originalGlycerinPosition || '—' }}</el-descriptions-item>
      </el-descriptions>

      <el-divider content-position="left">状态</el-divider>
      <el-descriptions :column="3" border>
        <el-descriptions-item label="位置状态">
          <el-tag v-if="detailData.positionConfirmed" type="success">已确认</el-tag>
          <el-tag v-else type="warning">未确认</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="最后修改人">{{ detailData.lastModifierName || '—' }}</el-descriptions-item>
        <el-descriptions-item label="最后修改时间">
          {{ detailData.lastModifierTime ? formatDate(detailData.lastModifierTime) : '—' }}
        </el-descriptions-item>
      </el-descriptions>
    </div>
    <template #footer>
      <el-button @click="detailVisible = false">关 闭</el-button>
    </template>
  </Dialog>

  <!-- ==================== 修改位置 Dialog ==================== -->
  <Dialog title="修改存放位置" v-model="editVisible" width="640px">
    <div v-loading="editLoading">
      <el-descriptions :column="3" border class="mb-12px">
        <el-descriptions-item label="质粒编号">{{ editData.plasmidNo }}</el-descriptions-item>
        <el-descriptions-item label="质粒名称">{{ editData.plasmidName }}</el-descriptions-item>
        <el-descriptions-item label="质粒类型">{{ editData.plasmidTypeName }}</el-descriptions-item>
      </el-descriptions>
      <el-form ref="editFormRef" :model="editForm" :rules="editRules" label-width="110px">
        <el-divider content-position="left">正式质粒位置</el-divider>
        <el-form-item label="冰箱" prop="plasmidFridge">
          <el-input v-model="editForm.plasmidFridge" placeholder="请输入冰箱" maxlength="100" />
        </el-form-item>
        <el-form-item label="层" prop="plasmidLayer">
          <el-input v-model="editForm.plasmidLayer" placeholder="请输入层" maxlength="100" />
        </el-form-item>
        <el-form-item label="盒" prop="plasmidBox">
          <el-input v-model="editForm.plasmidBox" placeholder="请输入盒" maxlength="100" />
        </el-form-item>
        <el-form-item label="盒内位置" prop="plasmidPosition">
          <el-input v-model="editForm.plasmidPosition" placeholder="请输入盒内位置" maxlength="100" />
        </el-form-item>
        <el-divider content-position="left">正式甘油菌位置</el-divider>
        <el-form-item label="冰箱" prop="glycerinFridge">
          <el-input v-model="editForm.glycerinFridge" placeholder="请输入冰箱" maxlength="100" />
        </el-form-item>
        <el-form-item label="层" prop="glycerinLayer">
          <el-input v-model="editForm.glycerinLayer" placeholder="请输入层" maxlength="100" />
        </el-form-item>
        <el-form-item label="盒" prop="glycerinBox">
          <el-input v-model="editForm.glycerinBox" placeholder="请输入盒" maxlength="100" />
        </el-form-item>
        <el-form-item label="盒内位置" prop="glycerinPosition">
          <el-input v-model="editForm.glycerinPosition" placeholder="请输入盒内位置" maxlength="100" />
        </el-form-item>
        <el-form-item label="备注" prop="remark">
          <el-input v-model="editForm.remark" type="textarea" :rows="2" placeholder="选填" maxlength="200" />
        </el-form-item>
      </el-form>
      <el-alert
        type="info"
        :closable="false"
        title="修改保存后立即生效，无需审核；原始申报位置不会被改动；每组位置四项需完整填写。"
      />
    </div>
    <template #footer>
      <el-button @click="editVisible = false">取 消</el-button>
      <el-button type="primary" :disabled="editSubmitting" @click="submitEdit">保 存</el-button>
    </template>
  </Dialog>

  <!-- ==================== 修改历史 Dialog ==================== -->
  <Dialog title="位置修改历史" v-model="historyVisible" width="960px">
    <div v-loading="historyLoading">
      <el-descriptions :column="3" border class="mb-12px">
        <el-descriptions-item label="质粒编号">{{ historyPlasmid?.plasmidNo }}</el-descriptions-item>
        <el-descriptions-item label="质粒名称">{{ historyPlasmid?.plasmidName }}</el-descriptions-item>
        <el-descriptions-item label="质粒类型">{{ historyPlasmid?.plasmidTypeName }}</el-descriptions-item>
      </el-descriptions>
      <el-table :data="historyList" :stripe="true" :show-overflow-tooltip="true">
        <el-table-column
          label="修改时间"
          align="center"
          prop="createTime"
          :formatter="dateFormatter"
          width="170px"
        />
        <el-table-column label="修改人" align="center" prop="operatorName" width="110px" />
        <el-table-column label="修改对象" align="center" width="90px">
          <template #default="scope">
            {{ changeTargetLabel(scope.row.changeTarget) }}
          </template>
        </el-table-column>
        <el-table-column label="修改前（质粒）" align="center" min-width="150px">
          <template #default="scope">
            {{ formatHistoryPosition(scope.row, 'before', 'Plasmid') || '—' }}
          </template>
        </el-table-column>
        <el-table-column label="修改后（质粒）" align="center" min-width="150px">
          <template #default="scope">
            {{ formatHistoryPosition(scope.row, 'after', 'Plasmid') || '—' }}
          </template>
        </el-table-column>
        <el-table-column label="修改前（甘油菌）" align="center" min-width="150px">
          <template #default="scope">
            {{ formatHistoryPosition(scope.row, 'before', 'Glycerin') || '—' }}
          </template>
        </el-table-column>
        <el-table-column label="修改后（甘油菌）" align="center" min-width="150px">
          <template #default="scope">
            {{ formatHistoryPosition(scope.row, 'after', 'Glycerin') || '—' }}
          </template>
        </el-table-column>
        <el-table-column label="备注" align="center" prop="remark" min-width="120px" />
      </el-table>
      <Pagination
        :total="historyTotal"
        v-model:page="historyQuery.pageNo"
        v-model:limit="historyQuery.pageSize"
        @pagination="getHistoryList"
      />
    </div>
    <template #footer>
      <el-button @click="historyVisible = false">关 闭</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { dateFormatter, formatDate } from '@/utils/formatTime'
import { PlasmidTypeApi } from '@/api/lab/v2/plasmid-type'
import { PlasmidStorageApi, PlasmidStoragePositionVO } from '@/api/lab/v2/plasmid-storage'

defineOptions({ name: 'PlasmidV2Storage' })

const message = useMessage()

const loading = ref(true)
const total = ref(0)
const list = ref<PlasmidStoragePositionVO[]>([])
const typeList = ref<any[]>([])
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  plasmidNo: undefined,
  plasmidName: undefined,
  plasmidTypeId: undefined
})
const queryFormRef = ref()

/** 查询列表 */
const getList = async () => {
  loading.value = true
  try {
    const data = await PlasmidStorageApi.getPositionPage(queryParams)
    list.value = data.list
    total.value = data.total
  } finally {
    loading.value = false
  }
}

/** 搜索按钮操作 */
const handleQuery = () => {
  queryParams.pageNo = 1
  getList()
}

/** 重置按钮操作 */
const resetQuery = () => {
  queryFormRef.value.resetFields()
  handleQuery()
}

/** 拼接位置展示："冰箱-层-盒-盒内位置" */
const formatPosition = (row: any, prefix: 'plasmid' | 'glycerin') => {
  const segs = [row[`${prefix}Fridge`], row[`${prefix}Layer`], row[`${prefix}Box`], row[`${prefix}Position`]]
  return segs.every((s) => s !== null && s !== undefined && s !== '')
    ? segs.join('-')
    : segs.some((s) => s !== null && s !== undefined && s !== '')
      ? segs.map((s) => s ?? '—').join('-')
      : ''
}

// ==================== 详情 ====================
const detailVisible = ref(false)
const detailLoading = ref(false)
const detailData = ref<Partial<PlasmidStoragePositionVO>>({})

const openDetail = async (row: PlasmidStoragePositionVO) => {
  detailVisible.value = true
  detailLoading.value = true
  try {
    detailData.value = await PlasmidStorageApi.getPositionByPlasmid(row.plasmidId)
  } finally {
    detailLoading.value = false
  }
}

// ==================== 修改位置 ====================
const editVisible = ref(false)
const editLoading = ref(false)
const editSubmitting = ref(false)
const editData = ref<Partial<PlasmidStoragePositionVO>>({})
const editFormRef = ref()
const editForm = reactive({
  plasmidId: undefined as number | undefined,
  plasmidFridge: '',
  plasmidLayer: '',
  plasmidBox: '',
  plasmidPosition: '',
  glycerinFridge: '',
  glycerinLayer: '',
  glycerinBox: '',
  glycerinPosition: '',
  remark: ''
})

/** 组内联动校验：任一段填写则四段必填 */
const groupRequired = (prefix: 'plasmid' | 'glycerin') => {
  return (_rule: any, _value: any, callback: any) => {
    const filled = ['Fridge', 'Layer', 'Box', 'Position'].some((k) => (editForm as any)[`${prefix}${k}`])
    if (!filled) {
      callback()
      return
    }
    const missing = ['Fridge', 'Layer', 'Box', 'Position'].filter((k) => !(editForm as any)[`${prefix}${k}`])
    callback(missing.length ? `${missing.length === 4 ? '该组' : ''}位置四项需完整填写` : undefined)
  }
}

const editRules = {
  plasmidFridge: [{ validator: groupRequired('plasmid'), trigger: 'blur' }],
  plasmidLayer: [{ validator: groupRequired('plasmid'), trigger: 'blur' }],
  plasmidBox: [{ validator: groupRequired('plasmid'), trigger: 'blur' }],
  plasmidPosition: [{ validator: groupRequired('plasmid'), trigger: 'blur' }],
  glycerinFridge: [{ validator: groupRequired('glycerin'), trigger: 'blur' }],
  glycerinLayer: [{ validator: groupRequired('glycerin'), trigger: 'blur' }],
  glycerinBox: [{ validator: groupRequired('glycerin'), trigger: 'blur' }],
  glycerinPosition: [{ validator: groupRequired('glycerin'), trigger: 'blur' }]
}

const openEdit = async (row: PlasmidStoragePositionVO) => {
  // 先重置，避免混入上一条记录的数据
  editData.value = {}
  editForm.plasmidId = row.plasmidId
  editForm.plasmidFridge = ''
  editForm.plasmidLayer = ''
  editForm.plasmidBox = ''
  editForm.plasmidPosition = ''
  editForm.glycerinFridge = ''
  editForm.glycerinLayer = ''
  editForm.glycerinBox = ''
  editForm.glycerinPosition = ''
  editForm.remark = ''
  editVisible.value = true
  editLoading.value = true
  try {
    editData.value = await PlasmidStorageApi.getPositionByPlasmid(row.plasmidId)
    editForm.plasmidFridge = editData.value?.plasmidFridge ?? ''
    editForm.plasmidLayer = editData.value?.plasmidLayer ?? ''
    editForm.plasmidBox = editData.value?.plasmidBox ?? ''
    editForm.plasmidPosition = editData.value?.plasmidPosition ?? ''
    editForm.glycerinFridge = editData.value?.glycerinFridge ?? ''
    editForm.glycerinLayer = editData.value?.glycerinLayer ?? ''
    editForm.glycerinBox = editData.value?.glycerinBox ?? ''
    editForm.glycerinPosition = editData.value?.glycerinPosition ?? ''
  } catch {
    // 错误提示由 axios 拦截器统一弹出；这里恢复可操作状态
    editVisible.value = false
  } finally {
    editLoading.value = false
  }
}

/** 组是否有变更 */
const groupChanged = (prefix: 'plasmid' | 'glycerin') => {
  return ['Fridge', 'Layer', 'Box', 'Position'].some(
    (k) => ((editForm as any)[`${prefix}${k}`] ?? '') !== ((editData.value as any)?.[`${prefix}${k}`] ?? '')
  )
}

const submitEdit = async () => {
  await editFormRef.value.validate()
  if (!groupChanged('plasmid') && !groupChanged('glycerin')) {
    message.warning('位置未发生变化，无需保存')
    return
  }
  editSubmitting.value = true
  try {
    // 仅提交发生变化的组（后端按"组全填或不填"校验）
    const payload: any = { plasmidId: editForm.plasmidId }
    if (groupChanged('plasmid')) {
      payload.plasmidFridge = editForm.plasmidFridge
      payload.plasmidLayer = editForm.plasmidLayer
      payload.plasmidBox = editForm.plasmidBox
      payload.plasmidPosition = editForm.plasmidPosition
    }
    if (groupChanged('glycerin')) {
      payload.glycerinFridge = editForm.glycerinFridge
      payload.glycerinLayer = editForm.glycerinLayer
      payload.glycerinBox = editForm.glycerinBox
      payload.glycerinPosition = editForm.glycerinPosition
    }
    if (editForm.remark) {
      payload.remark = editForm.remark
    }
    await PlasmidStorageApi.updatePosition(payload)
    message.success('位置修改已保存并生效')
    editVisible.value = false
    await getList()
  } finally {
    editSubmitting.value = false
  }
}

// ==================== 修改历史 ====================
const historyVisible = ref(false)
const historyLoading = ref(false)
const historyList = ref<any[]>([])
const historyTotal = ref(0)
const historyPlasmid = ref<PlasmidStoragePositionVO>()
const historyQuery = reactive({ pageNo: 1, pageSize: 10 })

const openHistory = (row: PlasmidStoragePositionVO) => {
  historyVisible.value = true
  historyPlasmid.value = row
  historyQuery.pageNo = 1
  getHistoryList()
}

const getHistoryList = async () => {
  historyLoading.value = true
  try {
    const data = await PlasmidStorageApi.getPositionHistoryPage({
      ...historyQuery,
      plasmidId: historyPlasmid.value?.plasmidId
    })
    historyList.value = data.list
    historyTotal.value = data.total
  } finally {
    historyLoading.value = false
  }
}

const changeTargetLabel = (target: string) => {
  switch (target) {
    case 'PLASMID':
      return '质粒位置'
    case 'GLYCERIN':
      return '甘油菌位置'
    case 'BOTH':
      return '两者'
    default:
      return target
  }
}

const formatHistoryPosition = (row: any, stage: 'before' | 'after', obj: 'Plasmid' | 'Glycerin') => {
  const segs = [
    row[`${stage}${obj}Fridge`],
    row[`${stage}${obj}Layer`],
    row[`${stage}${obj}Box`],
    row[`${stage}${obj}Position`]
  ]
  return segs.every((s) => s !== null && s !== undefined && s !== '') ? segs.join('-') : ''
}

/** 初始化 */
onMounted(async () => {
  await getList()
  try {
    const data = await PlasmidTypeApi.getPlasmidTypePage({ pageNo: 1, pageSize: 100 })
    typeList.value = data.list ?? []
  } catch {
    typeList.value = []
  }
})
</script>
