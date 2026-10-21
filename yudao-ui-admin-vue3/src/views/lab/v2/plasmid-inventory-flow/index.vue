<template>
  <ContentWrap>
    <!-- 搜索工作栏 -->
    <el-form
      class="-mb-15px"
      :model="queryParams"
      ref="queryFormRef"
      :inline="true"
      label-width="100px"
    >
      <el-form-item label="质粒" prop="plasmidId">
        <el-select
          v-model="queryParams.plasmidId"
          placeholder="请选择质粒"
          clearable
          filterable
          class="!w-240px"
        >
          <el-option
            v-for="item in plasmidList"
            :key="item.id"
            :label="(item.plasmidNo || '') + ' / ' + (item.name || '')"
            :value="item.id"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="流水类型" prop="flowType">
        <el-select
          v-model="queryParams.flowType"
          placeholder="请选择流水类型"
          clearable
          class="!w-200px"
        >
          <el-option
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_INVENTORY_FLOW_TYPE)"
            :key="dict.value"
            :label="dict.label"
            :value="dict.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="流水单号" prop="flowNo">
        <el-input
          v-model="queryParams.flowNo"
          placeholder="请输入流水单号"
          clearable
          @keyup.enter="handleQuery"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="业务类型" prop="relatedOrderType">
        <el-select
          v-model="queryParams.relatedOrderType"
          placeholder="请选择关联业务类型"
          clearable
          class="!w-200px"
        >
          <el-option
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_INVENTORY_ORDER_TYPE)"
            :key="dict.value"
            :label="dict.label"
            :value="dict.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="流水时间" prop="flowTime">
        <el-date-picker
          v-model="queryParams.flowTime"
          value-format="YYYY-MM-DD HH:mm:ss"
          type="daterange"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          :default-time="[new Date('1 00:00:00'), new Date('1 23:59:59')]"
          class="!w-240px"
        />
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" /> 搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" /> 重置</el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <!-- 列表（只读） -->
  <ContentWrap>
    <el-table v-loading="loading" :data="list" :stripe="true" :show-overflow-tooltip="true">
      <el-table-column label="流水单号" align="center" prop="flowNo" width="180px" />
      <el-table-column label="质粒" align="center">
        <template #default="scope">
          <span v-if="plasmidMap[scope.row.plasmidId]">
            {{ plasmidMap[scope.row.plasmidId].plasmidNo }} /
            {{ plasmidMap[scope.row.plasmidId].name }}
          </span>
          <span v-else>ID: {{ scope.row.plasmidId }}</span>
        </template>
      </el-table-column>
      <el-table-column label="流水类型" align="center" prop="flowType">
        <template #default="scope">
          <dict-tag
            :type="DICT_TYPE.LAB_PLASMID_INVENTORY_FLOW_TYPE"
            :value="scope.row.flowType"
          />
        </template>
      </el-table-column>
      <el-table-column label="变化数量(μL)" align="center" prop="quantity" />
      <el-table-column label="变更前库存(μL)" align="center" prop="beforeQuantity" />
      <el-table-column label="变更后库存(μL)" align="center" prop="afterQuantity" />
      <el-table-column label="业务类型" align="center" prop="relatedOrderType" />
      <el-table-column label="关联单据号" align="center" prop="relatedOrderNo" width="180px" />
      <el-table-column label="操作人" align="center" prop="operatorName" />
      <el-table-column
        label="流水时间"
        align="center"
        prop="flowTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="原因" align="center" prop="reason" />
      <el-table-column label="备注" align="center" prop="remark" />
    </el-table>
    <!-- 分页 -->
    <Pagination
      :total="total"
      v-model:page="queryParams.pageNo"
      v-model:limit="queryParams.pageSize"
      @pagination="getList"
    />
  </ContentWrap>
</template>

<script setup lang="ts">
import { getStrDictOptions, DICT_TYPE } from '@/utils/dict'
import { dateFormatter } from '@/utils/formatTime'
import {
  PlasmidInventoryFlowApi,
  PlasmidInventoryFlowVO
} from '@/api/lab/v2/plasmid-inventory-flow'
import { PlasmidApi, PlasmidVO } from '@/api/lab/v2/plasmid'

/** 质粒库存流水（V2，只读） */
defineOptions({ name: 'PlasmidV2InventoryFlow' })

const loading = ref(true) // 列表的加载中
const list = ref<PlasmidInventoryFlowVO[]>([]) // 列表的数据
const total = ref(0) // 列表的总数
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  plasmidId: undefined,
  flowType: undefined,
  flowNo: undefined,
  relatedOrderType: undefined,
  flowTime: []
})
const queryFormRef = ref() // 搜索的表单

/**
 * 质粒列表（下拉选择 + id → 编号/名称映射）。
 * 单次批量查询（无 N+1）；当前实验室规模（百级以内）下 pageSize=100 可覆盖。
 * 后端流水查询仍按 keeper 数据范围过滤，此处仅作展示辅助。
 */
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
    const data = await PlasmidInventoryFlowApi.getInventoryFlowPage(queryParams)
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

/** 初始化 **/
onMounted(() => {
  getPlasmidList()
  getList()
})
</script>
