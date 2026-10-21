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
      <el-form-item label="库存状态" prop="inventoryStatus">
        <el-select
          v-model="queryParams.inventoryStatus"
          placeholder="请选择库存状态"
          clearable
          class="!w-200px"
        >
          <el-option
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_INVENTORY_STATUS)"
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
          type="warning"
          plain
          @click="handleExport"
          v-hasPermi="['lab:plasmid:inventory:export']"
        >
          <Icon icon="ep:download" class="mr-5px" /> 导出
        </el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <!-- 列表 -->
  <ContentWrap>
    <el-table v-loading="loading" :data="list" :stripe="true" :show-overflow-tooltip="true">
      <el-table-column label="质粒编号" align="center" prop="plasmidNo" />
      <el-table-column label="质粒名称" align="center" prop="plasmidName" />
      <el-table-column label="质粒类型" align="center" prop="plasmidTypeName" />
      <el-table-column label="当前库存(μL)" align="center" prop="currentQuantity" />
      <el-table-column label="低库存阈值(μL)" align="center" prop="lowStockThreshold" />
      <el-table-column label="库存状态" align="center" prop="inventoryStatus">
        <template #default="scope">
          <dict-tag
            :type="DICT_TYPE.LAB_PLASMID_INVENTORY_STATUS"
            :value="scope.row.inventoryStatus"
          />
        </template>
      </el-table-column>
      <el-table-column
        label="最后流水时间"
        align="center"
        prop="lastFlowTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="备注" align="center" prop="remark" />
      <el-table-column
        label="创建时间"
        align="center"
        prop="createTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="操作" align="center" width="320px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openDetail(scope.row.id)">详情</el-button>
          <el-button
            link
            type="primary"
            @click="openIn(scope.row)"
            v-hasPermi="['lab:plasmid:inventory:in']"
            :disabled="scope.row.inventoryStatus === 'DISABLED'"
          >
            入库
          </el-button>
          <el-button
            link
            type="primary"
            @click="openOut(scope.row)"
            v-hasPermi="['lab:plasmid:inventory:out']"
            :disabled="scope.row.inventoryStatus === 'DISABLED'"
          >
            出库
          </el-button>
          <el-button
            link
            type="warning"
            @click="openStocktake(scope.row)"
            v-hasPermi="['lab:plasmid:inventory:stocktake']"
            :disabled="scope.row.inventoryStatus === 'DISABLED'"
          >
            盘点
          </el-button>
          <el-button
            link
            type="warning"
            @click="openAdjust(scope.row)"
            v-hasPermi="['lab:plasmid:inventory:adjust']"
            :disabled="scope.row.inventoryStatus === 'DISABLED'"
          >
            调整
          </el-button>
          <el-button
            link
            type="success"
            @click="openThreshold(scope.row)"
            v-hasPermi="['lab:plasmid:inventory:threshold']"
            :disabled="scope.row.inventoryStatus === 'DISABLED'"
          >
            设置阈值
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

  <!-- 详情弹窗 -->
  <Dialog title="库存详情" v-model="detailVisible" width="720px">
    <el-descriptions :column="2" border v-loading="detailLoading">
      <el-descriptions-item label="质粒编号">{{ detailData.plasmidNo }}</el-descriptions-item>
      <el-descriptions-item label="质粒名称">{{ detailData.plasmidName }}</el-descriptions-item>
      <el-descriptions-item label="质粒类型">{{ detailData.plasmidTypeName }}</el-descriptions-item>
      <el-descriptions-item label="库存状态">
        <dict-tag
          :type="DICT_TYPE.LAB_PLASMID_INVENTORY_STATUS"
          :value="detailData.inventoryStatus || ''"
        />
      </el-descriptions-item>
      <el-descriptions-item label="初始申报数量(μL)">{{
        detailData.initialQuantityDeclared
      }}</el-descriptions-item>
      <el-descriptions-item label="初始确认数量(μL)">{{
        detailData.initialQuantityConfirmed
      }}</el-descriptions-item>
      <el-descriptions-item label="当前库存(μL)">{{ detailData.currentQuantity }}</el-descriptions-item>
      <el-descriptions-item label="低库存阈值(μL)">{{
        detailData.lowStockThreshold
      }}</el-descriptions-item>
      <el-descriptions-item label="最后流水时间">
        {{ formatDate(detailData.lastFlowTime) }}
      </el-descriptions-item>
      <el-descriptions-item label="创建时间">
        {{ formatDate(detailData.createTime) }}
      </el-descriptions-item>
      <el-descriptions-item label="备注" :span="2">{{ detailData.remark }}</el-descriptions-item>
    </el-descriptions>

    <!-- 存放位置分区：按 plasmidId 关联该库存对应质粒的正式位置；
         仅有位置查看权限的角色可见（数据来自独立位置接口，后端鉴权） -->
    <template v-if="canViewStorage">
      <el-divider content-position="left">存放位置（该质粒正式位置）</el-divider>
      <el-descriptions :column="4" border v-loading="storageLoading">
        <el-descriptions-item label="质粒冰箱">{{ storageData.plasmidFridge || '—' }}</el-descriptions-item>
        <el-descriptions-item label="质粒层">{{ storageData.plasmidLayer || '—' }}</el-descriptions-item>
        <el-descriptions-item label="质粒盒">{{ storageData.plasmidBox || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒内位置">{{ storageData.plasmidPosition || '—' }}</el-descriptions-item>
        <el-descriptions-item label="甘油菌冰箱">{{ storageData.glycerinFridge || '—' }}</el-descriptions-item>
        <el-descriptions-item label="甘油菌层">{{ storageData.glycerinLayer || '—' }}</el-descriptions-item>
        <el-descriptions-item label="甘油菌盒">{{ storageData.glycerinBox || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒内位置">{{ storageData.glycerinPosition || '—' }}</el-descriptions-item>
      </el-descriptions>
    </template>
    <template #footer>
      <el-button @click="detailVisible = false">关 闭</el-button>
    </template>
  </Dialog>

  <!-- 入库弹窗 -->
  <Dialog title="库存入库" v-model="inVisible" width="560px">
    <el-form
      ref="inFormRef"
      :model="inForm"
      :rules="inOutRules"
      label-width="110px"
    >
      <el-form-item label="质粒编号">
        <el-input :model-value="inForm.plasmidNo" disabled />
      </el-form-item>
      <el-form-item label="质粒名称">
        <el-input :model-value="inForm.plasmidName" disabled />
      </el-form-item>
      <el-form-item label="入库数量(μL)" prop="quantity">
        <el-input-number v-model="inForm.quantity" :min="0.0001" :precision="3" class="!w-200px" />
      </el-form-item>
      <el-form-item label="操作原因" prop="reason">
        <el-input v-model="inForm.reason" placeholder="请输入操作原因" />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="inForm.remark" type="textarea" placeholder="请输入备注" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="inVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitIn">确 定</el-button>
    </template>
  </Dialog>

  <!-- 出库弹窗 -->
  <Dialog title="库存出库" v-model="outVisible" width="560px">
    <el-form
      ref="outFormRef"
      :model="outForm"
      :rules="inOutRules"
      label-width="110px"
    >
      <el-form-item label="质粒编号">
        <el-input :model-value="outForm.plasmidNo" disabled />
      </el-form-item>
      <el-form-item label="质粒名称">
        <el-input :model-value="outForm.plasmidName" disabled />
      </el-form-item>
      <el-form-item label="当前库存(μL)">
        <el-input :model-value="outForm.currentQuantity" disabled />
      </el-form-item>
      <el-form-item label="出库数量(μL)" prop="quantity">
        <el-input-number v-model="outForm.quantity" :min="0.0001" :precision="3" class="!w-200px" />
      </el-form-item>
      <el-form-item label="操作原因" prop="reason">
        <el-input v-model="outForm.reason" placeholder="请输入操作原因" />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="outForm.remark" type="textarea" placeholder="请输入备注" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="outVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitOut">确 定</el-button>
    </template>
  </Dialog>

  <!-- 盘点弹窗 -->
  <Dialog title="库存盘点" v-model="stocktakeVisible" width="560px">
    <el-form
      ref="stocktakeFormRef"
      :model="stocktakeForm"
      :rules="stocktakeRules"
      label-width="110px"
    >
      <el-form-item label="质粒编号">
        <el-input :model-value="stocktakeForm.plasmidNo" disabled />
      </el-form-item>
      <el-form-item label="质粒名称">
        <el-input :model-value="stocktakeForm.plasmidName" disabled />
      </el-form-item>
      <el-form-item label="账面库存(μL)">
        <el-input :model-value="stocktakeForm.currentQuantity" disabled />
      </el-form-item>
      <el-form-item label="实盘库存(μL)" prop="actualQuantity">
        <el-input-number
          v-model="stocktakeForm.actualQuantity"
          :min="0"
          :precision="3"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="操作原因" prop="reason">
        <el-input v-model="stocktakeForm.reason" placeholder="请输入操作原因" />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input
          v-model="stocktakeForm.remark"
          type="textarea"
          placeholder="请输入备注"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="stocktakeVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitStocktake">确 定</el-button>
    </template>
  </Dialog>

  <!-- 调整弹窗 -->
  <Dialog title="库存调整" v-model="adjustVisible" width="560px">
    <el-form
      ref="adjustFormRef"
      :model="adjustForm"
      :rules="stocktakeRules"
      label-width="110px"
    >
      <el-form-item label="质粒编号">
        <el-input :model-value="adjustForm.plasmidNo" disabled />
      </el-form-item>
      <el-form-item label="质粒名称">
        <el-input :model-value="adjustForm.plasmidName" disabled />
      </el-form-item>
      <el-form-item label="调整前库存(μL)">
        <el-input :model-value="adjustForm.currentQuantity" disabled />
      </el-form-item>
      <el-form-item label="实际库存(μL)" prop="actualQuantity">
        <el-input-number
          v-model="adjustForm.actualQuantity"
          :min="0"
          :precision="3"
          class="!w-200px"
        />
      </el-form-item>
      <el-alert
        class="mb-15px"
        type="info"
        :closable="false"
        title="调整为强制覆盖：提交后当前库存将直接等于实际库存（非增减量）。"
      />
      <el-form-item label="操作原因" prop="reason">
        <el-input v-model="adjustForm.reason" placeholder="请输入操作原因" />
      </el-form-item>
      <el-form-item label="备注" prop="remark">
        <el-input v-model="adjustForm.remark" type="textarea" placeholder="请输入备注" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="adjustVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitAdjust">确 定</el-button>
    </template>
  </Dialog>

  <!-- 阈值弹窗 -->
  <Dialog title="设置低库存阈值" v-model="thresholdVisible" width="560px">
    <el-form
      ref="thresholdFormRef"
      :model="thresholdForm"
      :rules="thresholdRules"
      label-width="120px"
    >
      <el-form-item label="质粒编号">
        <el-input :model-value="thresholdForm.plasmidNo" disabled />
      </el-form-item>
      <el-form-item label="质粒名称">
        <el-input :model-value="thresholdForm.plasmidName" disabled />
      </el-form-item>
      <el-form-item label="低库存阈值(μL)" prop="threshold">
        <el-input-number
          v-model="thresholdForm.threshold"
          :min="0"
          :precision="3"
          class="!w-200px"
        />
      </el-form-item>
      <el-alert
        class="mb-15px"
        type="info"
        :closable="false"
        title="当当前库存 ≤ 低库存阈值时进入低库存（LOW）状态。"
      />
    </el-form>
    <template #footer>
      <el-button @click="thresholdVisible = false">取 消</el-button>
      <el-button type="primary" :loading="submitLoading" @click="submitThreshold">确 定</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { getStrDictOptions, DICT_TYPE } from '@/utils/dict'
import { dateFormatter, formatDate } from '@/utils/formatTime'
import { generateUUID } from '@/utils'
import download from '@/utils/download'
import { checkPermi } from '@/utils/permission'
import {
  PlasmidInventoryApi,
  PlasmidInventoryVO,
  PlasmidInventoryInOutVO,
  PlasmidInventoryStocktakeVO,
  PlasmidInventoryThresholdVO
} from '@/api/lab/v2/plasmid-inventory'
import { PlasmidTypeApi, PlasmidTypeVO } from '@/api/lab/v2/plasmid-type'
import { PlasmidStorageApi, PlasmidStoragePositionVO } from '@/api/lab/v2/plasmid-storage'

/** 质粒库存台账（V2） */
defineOptions({ name: 'PlasmidV2Inventory' })

const message = useMessage() // 消息弹窗

const loading = ref(true) // 列表的加载中
const list = ref<PlasmidInventoryVO[]>([]) // 列表的数据
const total = ref(0) // 列表的总数
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  plasmidNo: undefined,
  plasmidName: undefined,
  plasmidTypeId: undefined,
  inventoryStatus: undefined
})
const queryFormRef = ref() // 搜索的表单

/** 质粒类型列表（下拉选择） */
const typeList = ref<PlasmidTypeVO[]>([])
const getTypeList = async () => {
  const data = await PlasmidTypeApi.getPlasmidTypePage({ pageNo: 1, pageSize: 100 })
  typeList.value = data.list
}

/** 查询列表 */
const getList = async () => {
  loading.value = true
  try {
    const data = await PlasmidInventoryApi.getInventoryPage(queryParams)
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

/** 导出操作 */
const handleExport = async () => {
  try {
    await message.exportConfirm()
    const data = await PlasmidInventoryApi.exportInventory(queryParams)
    download.excel(data, '库存数据.xls')
  } catch {}
}

/** 详情 */
const detailVisible = ref(false)
const detailLoading = ref(false)
const detailData = ref<PlasmidInventoryVO>({} as PlasmidInventoryVO)

/** 存放位置分区：按库存记录的 plasmidId 可靠关联（非名称匹配）；
 * 仅持有 lab:plasmid-storage:query 权限的角色渲染并请求，后端接口独立鉴权。 */
const canViewStorage = checkPermi(['lab:plasmid-storage:query'])
const storageLoading = ref(false)
const storageData = ref<Partial<PlasmidStoragePositionVO>>({})
const openDetail = async (id: number) => {
  detailVisible.value = true
  detailLoading.value = true
  storageData.value = {}
  try {
    detailData.value = await PlasmidInventoryApi.getInventory(id)
    if (canViewStorage && detailData.value?.plasmidId) {
      storageLoading.value = true
      try {
        storageData.value = await PlasmidStorageApi.getPositionByPlasmid(detailData.value.plasmidId)
      } finally {
        storageLoading.value = false
      }
    }
  } finally {
    detailLoading.value = false
  }
}

// ==================== 入库 / 出库 ====================
const submitLoading = ref(false)

const inOutRules = {
  quantity: [
    { required: true, message: '数量不能为空', trigger: 'blur' },
    {
      validator: (_rule: any, value: number, callback: any) => {
        if (value === undefined || value === null || value <= 0) {
          callback(new Error('数量必须大于 0'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ],
  reason: [{ required: true, message: '操作原因不能为空', trigger: 'blur' }]
}

/** 入库 */
const inVisible = ref(false)
const inFormRef = ref()
const inForm = reactive({
  requestNo: '',
  plasmidId: 0,
  plasmidNo: '',
  plasmidName: '',
  quantity: null as number | null,
  reason: '',
  remark: ''
})
const openIn = (row: PlasmidInventoryVO) => {
  Object.assign(inForm, {
    requestNo: generateUUID(),
    plasmidId: row.plasmidId,
    plasmidNo: row.plasmidNo,
    plasmidName: row.plasmidName,
    quantity: null,
    reason: '',
    remark: ''
  })
  inVisible.value = true
  nextTick(() => inFormRef.value?.clearValidate())
}
const submitIn = async () => {
  await inFormRef.value.validate()
  submitLoading.value = true
  try {
    await PlasmidInventoryApi.inInventory(inForm as PlasmidInventoryInOutVO)
    message.success('入库成功')
    inVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

/** 出库 */
const outVisible = ref(false)
const outFormRef = ref()
const outForm = reactive({
  requestNo: '',
  plasmidId: 0,
  plasmidNo: '',
  plasmidName: '',
  currentQuantity: 0,
  quantity: null as number | null,
  reason: '',
  remark: ''
})
const openOut = (row: PlasmidInventoryVO) => {
  Object.assign(outForm, {
    requestNo: generateUUID(),
    plasmidId: row.plasmidId,
    plasmidNo: row.plasmidNo,
    plasmidName: row.plasmidName,
    currentQuantity: row.currentQuantity,
    quantity: null,
    reason: '',
    remark: ''
  })
  outVisible.value = true
  nextTick(() => outFormRef.value?.clearValidate())
}
const submitOut = async () => {
  await outFormRef.value.validate()
  submitLoading.value = true
  try {
    await PlasmidInventoryApi.outInventory(outForm as PlasmidInventoryInOutVO)
    message.success('出库成功')
    outVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

// ==================== 盘点 / 调整 ====================
const stocktakeRules = {
  actualQuantity: [
    { required: true, message: '库存不能为空', trigger: 'blur' },
    {
      validator: (_rule: any, value: number, callback: any) => {
        if (value === undefined || value === null || value < 0) {
          callback(new Error('库存必须大于等于 0'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ],
  reason: [{ required: true, message: '操作原因不能为空', trigger: 'blur' }]
}

/** 盘点 */
const stocktakeVisible = ref(false)
const stocktakeFormRef = ref()
const stocktakeForm = reactive({
  requestNo: '',
  plasmidId: 0,
  plasmidNo: '',
  plasmidName: '',
  currentQuantity: 0,
  actualQuantity: null as number | null,
  reason: '',
  remark: ''
})
const openStocktake = (row: PlasmidInventoryVO) => {
  Object.assign(stocktakeForm, {
    requestNo: generateUUID(),
    plasmidId: row.plasmidId,
    plasmidNo: row.plasmidNo,
    plasmidName: row.plasmidName,
    currentQuantity: row.currentQuantity,
    actualQuantity: null,
    reason: '',
    remark: ''
  })
  stocktakeVisible.value = true
  nextTick(() => stocktakeFormRef.value?.clearValidate())
}
const submitStocktake = async () => {
  await stocktakeFormRef.value.validate()
  submitLoading.value = true
  try {
    await PlasmidInventoryApi.stocktakeInventory(
      stocktakeForm as PlasmidInventoryStocktakeVO
    )
    message.success('盘点成功')
    stocktakeVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

/** 调整 */
const adjustVisible = ref(false)
const adjustFormRef = ref()
const adjustForm = reactive({
  requestNo: '',
  plasmidId: 0,
  plasmidNo: '',
  plasmidName: '',
  currentQuantity: 0,
  actualQuantity: null as number | null,
  reason: '',
  remark: ''
})
const openAdjust = (row: PlasmidInventoryVO) => {
  Object.assign(adjustForm, {
    requestNo: generateUUID(),
    plasmidId: row.plasmidId,
    plasmidNo: row.plasmidNo,
    plasmidName: row.plasmidName,
    currentQuantity: row.currentQuantity,
    actualQuantity: null,
    reason: '',
    remark: ''
  })
  adjustVisible.value = true
  nextTick(() => adjustFormRef.value?.clearValidate())
}
const submitAdjust = async () => {
  await adjustFormRef.value.validate()
  submitLoading.value = true
  try {
    await PlasmidInventoryApi.adjustInventory(adjustForm as PlasmidInventoryStocktakeVO)
    message.success('调整成功')
    adjustVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

// ==================== 阈值 ====================
const thresholdVisible = ref(false)
const thresholdFormRef = ref()
const thresholdForm = reactive({
  plasmidId: 0,
  plasmidNo: '',
  plasmidName: '',
  threshold: null as number | null
})
const thresholdRules = {
  threshold: [
    { required: true, message: '阈值不能为空', trigger: 'blur' },
    {
      validator: (_rule: any, value: number, callback: any) => {
        if (value === undefined || value === null || value < 0) {
          callback(new Error('阈值必须大于等于 0'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ]
}
const openThreshold = (row: PlasmidInventoryVO) => {
  Object.assign(thresholdForm, {
    plasmidId: row.plasmidId,
    plasmidNo: row.plasmidNo,
    plasmidName: row.plasmidName,
    threshold: row.lowStockThreshold ?? null
  })
  thresholdVisible.value = true
  nextTick(() => thresholdFormRef.value?.clearValidate())
}
const submitThreshold = async () => {
  await thresholdFormRef.value.validate()
  submitLoading.value = true
  try {
    await PlasmidInventoryApi.updateThreshold(
      thresholdForm as PlasmidInventoryThresholdVO
    )
    message.success('阈值设置成功')
    thresholdVisible.value = false
    await getList()
  } finally {
    submitLoading.value = false
  }
}

/** 初始化 **/
onMounted(() => {
  getTypeList()
  getList()
})
</script>
