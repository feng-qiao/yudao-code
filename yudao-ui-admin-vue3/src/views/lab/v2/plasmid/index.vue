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
      <el-form-item label="序列号" prop="seqNo">
        <el-input
          v-model="queryParams.seqNo"
          placeholder="请输入序列号"
          clearable
          @keyup.enter="handleQuery"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="质粒名称" prop="name">
        <el-input
          v-model="queryParams.name"
          placeholder="请输入质粒名称"
          clearable
          @keyup.enter="handleQuery"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="物种" prop="species">
        <el-select
          v-model="queryParams.species"
          placeholder="请选择物种"
          clearable
          class="!w-200px"
        >
          <el-option
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_SPECIES)"
            :key="dict.value"
            :label="dict.label"
            :value="dict.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="抗性" prop="resistance">
        <el-select
          v-model="queryParams.resistance"
          placeholder="请选择抗性"
          clearable
          class="!w-200px"
        >
          <el-option
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_RESISTANCE)"
            :key="dict.value"
            :label="dict.label"
            :value="dict.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="载体名称" prop="vectorName">
        <el-input
          v-model="queryParams.vectorName"
          placeholder="请输入载体名称"
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
      <el-form-item label="审核状态" prop="auditStatus">
        <el-select
          v-model="queryParams.auditStatus"
          placeholder="请选择审核状态"
          clearable
          class="!w-200px"
        >
          <el-option
            v-for="dict in getStrDictOptions(DICT_TYPE.LAB_PLASMID_AUDIT_STATUS)"
            :key="dict.value"
            :label="dict.label"
            :value="dict.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="创建日期" prop="createDate">
        <el-date-picker
          v-model="queryParams.createDate"
          value-format="YYYY-MM-DD"
          type="daterange"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          class="!w-240px"
        />
      </el-form-item>
      <el-form-item label="创建时间" prop="createTime">
        <el-date-picker
          v-model="queryParams.createTime"
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
        <el-button
          type="primary"
          plain
          @click="openForm('create')"
          v-hasPermi="['lab:plasmid:create']"
        >
          <Icon icon="ep:plus" class="mr-5px" /> 新增
        </el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <!-- 列表 -->
  <ContentWrap>
    <el-table v-loading="loading" :data="list" :stripe="true" :show-overflow-tooltip="true">
      <el-table-column label="质粒编号" align="center" prop="plasmidNo" />
      <el-table-column label="序列号" align="center" prop="seqNo" width="80px" />
      <el-table-column label="质粒名称" align="center" prop="name" />
      <el-table-column label="受体名称" align="center" prop="recipient" />
      <el-table-column label="物种" align="center" prop="species">
        <template #default="scope">
          <dict-tag :type="DICT_TYPE.LAB_PLASMID_SPECIES" :value="scope.row.species" />
        </template>
      </el-table-column>
      <el-table-column label="抗性" align="center" prop="resistance">
        <template #default="scope">
          <dict-tag :type="DICT_TYPE.LAB_PLASMID_RESISTANCE" :value="scope.row.resistance" />
        </template>
      </el-table-column>
      <el-table-column label="载体名称" align="center" prop="vectorName" />
      <el-table-column label="荧光标签" align="center" prop="fluorescentTag">
        <template #default="scope">
          <dict-tag
            v-for="tag in splitTags(scope.row.fluorescentTag)"
            :key="tag"
            :type="DICT_TYPE.LAB_PLASMID_FLUORESCENT_TAG"
            :value="tag"
            class="mr-2px"
          />
        </template>
      </el-table-column>
      <el-table-column label="突变" align="center" prop="mutation" />
      <el-table-column label="修饰" align="center" prop="modification" />
      <el-table-column label="标签" align="center" prop="tag" />
      <el-table-column label="质粒类型" align="center" prop="plasmidTypeId">
        <template #default="scope">
          {{ typeNameMap[scope.row.plasmidTypeId] || scope.row.plasmidTypeId }}
        </template>
      </el-table-column>
      <el-table-column label="审核状态" align="center" prop="auditStatus">
        <template #default="scope">
          <dict-tag :type="DICT_TYPE.LAB_PLASMID_AUDIT_STATUS" :value="scope.row.auditStatus" />
        </template>
      </el-table-column>
      <el-table-column
        label="创建时间"
        align="center"
        prop="createTime"
        :formatter="dateFormatter"
        width="180px"
      />
      <el-table-column label="操作" align="center" width="220px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openDetail(scope.row.id)">详情</el-button>
          <el-button
            link
            type="primary"
            @click="openForm('update', scope.row.id)"
            v-hasPermi="['lab:plasmid:update']"
            v-if="scope.row.auditStatus === 'DRAFT'"
          >
            编辑
          </el-button>
          <el-button
            link
            type="warning"
            @click="handleSubmit(scope.row.id)"
            v-hasPermi="['lab:plasmid:submit']"
            v-if="scope.row.auditStatus === 'DRAFT'"
          >
            提交审核
          </el-button>
          <el-button
            link
            type="danger"
            @click="handleDelete(scope.row.id)"
            v-hasPermi="['lab:plasmid:delete']"
            v-if="scope.row.auditStatus === 'DRAFT'"
          >
            删除
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

  <!-- 表单弹窗：添加/修改 -->
  <PlasmidForm ref="formRef" @success="getList" />

  <!-- 详情弹窗 -->
  <Dialog title="质粒详情" v-model="detailVisible" width="720px">
    <el-descriptions :column="2" border v-loading="detailLoading">
      <el-descriptions-item label="质粒编号">{{ detailData.plasmidNo }}</el-descriptions-item>
      <el-descriptions-item label="序列号">{{ detailData.seqNo }}</el-descriptions-item>
      <el-descriptions-item label="质粒名称">{{ detailData.name }}</el-descriptions-item>
      <el-descriptions-item label="受体名称">{{ detailData.recipient }}</el-descriptions-item>
      <el-descriptions-item label="物种">
        <dict-tag :type="DICT_TYPE.LAB_PLASMID_SPECIES" :value="detailData.species ?? ''" />
      </el-descriptions-item>
      <el-descriptions-item label="抗性">
        <dict-tag :type="DICT_TYPE.LAB_PLASMID_RESISTANCE" :value="detailData.resistance ?? ''" />
      </el-descriptions-item>
      <el-descriptions-item label="载体名称">{{ detailData.vectorName }}</el-descriptions-item>
      <el-descriptions-item label="荧光标签">
        <dict-tag
          v-for="tag in splitTags(detailData.fluorescentTag)"
          :key="tag"
          :type="DICT_TYPE.LAB_PLASMID_FLUORESCENT_TAG"
          :value="tag"
          class="mr-2px"
        />
      </el-descriptions-item>
      <el-descriptions-item label="突变">{{ detailData.mutation }}</el-descriptions-item>
      <el-descriptions-item label="修饰">{{ detailData.modification }}</el-descriptions-item>
      <el-descriptions-item label="标签">{{ detailData.tag }}</el-descriptions-item>
      <el-descriptions-item label="质粒类型">
        {{
          detailData.plasmidTypeId == null
            ? ''
            : typeNameMap[detailData.plasmidTypeId] || detailData.plasmidTypeId
        }}
      </el-descriptions-item>
      <el-descriptions-item label="审核状态">
        <dict-tag :type="DICT_TYPE.LAB_PLASMID_AUDIT_STATUS" :value="detailData.auditStatus ?? ''" />
      </el-descriptions-item>
      <el-descriptions-item label="创建日期">{{ detailData.createDate }}</el-descriptions-item>
      <el-descriptions-item label="备注">{{ detailData.remark }}</el-descriptions-item>
      <el-descriptions-item label="创建时间">
        {{ formatDate(detailData.createTime) }}
      </el-descriptions-item>
    </el-descriptions>

    <!-- 存放位置分区：仅有位置查看权限的角色可见；数据来自独立位置接口（后端鉴权） -->
    <template v-if="canViewStorage">
      <el-divider content-position="left">正式存放位置</el-divider>
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
      <el-divider content-position="left">原始申报位置（登记时申报，不随后续修改变化）</el-divider>
      <el-descriptions :column="4" border v-loading="storageLoading">
        <el-descriptions-item label="质粒冰箱">{{ storageData.originalPlasmidFridge || '—' }}</el-descriptions-item>
        <el-descriptions-item label="质粒层">{{ storageData.originalPlasmidLayer || '—' }}</el-descriptions-item>
        <el-descriptions-item label="质粒盒">{{ storageData.originalPlasmidBox || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒内位置">{{ storageData.originalPlasmidPosition || '—' }}</el-descriptions-item>
        <el-descriptions-item label="甘油菌冰箱">{{ storageData.originalGlycerinFridge || '—' }}</el-descriptions-item>
        <el-descriptions-item label="甘油菌层">{{ storageData.originalGlycerinLayer || '—' }}</el-descriptions-item>
        <el-descriptions-item label="甘油菌盒">{{ storageData.originalGlycerinBox || '—' }}</el-descriptions-item>
        <el-descriptions-item label="盒内位置">{{ storageData.originalGlycerinPosition || '—' }}</el-descriptions-item>
      </el-descriptions>
    </template>
    <template #footer>
      <el-button @click="detailVisible = false">关 闭</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { getStrDictOptions, DICT_TYPE } from '@/utils/dict'
import { dateFormatter, formatDate } from '@/utils/formatTime'
import { checkPermi } from '@/utils/permission'
import { PlasmidApi, PlasmidVO } from '@/api/lab/v2/plasmid'
import { PlasmidTypeApi, PlasmidTypeVO } from '@/api/lab/v2/plasmid-type'
import { PlasmidStorageApi, PlasmidStoragePositionVO } from '@/api/lab/v2/plasmid-storage'
import PlasmidForm from './PlasmidForm.vue'

/** 质粒档案（V2）列表 */
defineOptions({ name: 'PlasmidV2Plasmid' })

const message = useMessage() // 消息弹窗
const { t } = useI18n() // 国际化

const loading = ref(true) // 列表的加载中
const list = ref<PlasmidVO[]>([]) // 列表的数据
const total = ref(0) // 列表的总页数
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  plasmidNo: undefined,
  seqNo: undefined,
  name: undefined,
  species: undefined,
  resistance: undefined,
  vectorName: undefined,
  plasmidTypeId: undefined,
  auditStatus: undefined,
  createDate: [],
  createTime: []
})
const queryFormRef = ref() // 搜索的表单

/** 质粒类型列表（用于 id → name 映射与下拉选择） */
const typeList = ref<PlasmidTypeVO[]>([])
const typeNameMap = computed(() => {
  const map: Record<number, string> = {}
  typeList.value.forEach((item) => {
    if (item.id) {
      map[item.id] = item.name || ''
    }
  })
  return map
})
const getTypeList = async () => {
  const data = await PlasmidTypeApi.getPlasmidTypePage({ pageNo: 1, pageSize: 100 })
  typeList.value = data.list
}

/** 荧光标签多值拆分 */
const splitTags = (val?: string) => {
  return val ? val.split(',').filter((item) => !!item) : []
}

/** 查询列表 */
const getList = async () => {
  loading.value = true
  try {
    const data = await PlasmidApi.getPlasmidPage(queryParams)
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

/** 添加/修改操作 */
const formRef = ref()
const openForm = (type: string, id?: number) => {
  formRef.value.open(type, id)
}

/** 详情操作 */
const detailVisible = ref(false)
const detailLoading = ref(false)
const detailData = ref<PlasmidVO>({} as PlasmidVO)

/** 存放位置分区：仅持有 lab:plasmid-storage:query 权限的角色渲染并加载；
 * 普通用户不渲染不请求，且后端接口独立鉴权（菜单/按钮可见性不是安全边界）。 */
const canViewStorage = checkPermi(['lab:plasmid-storage:query'])
const storageLoading = ref(false)
const storageData = ref<Partial<PlasmidStoragePositionVO>>({})
const openDetail = async (id: number) => {
  detailVisible.value = true
  detailLoading.value = true
  storageData.value = {}
  try {
    detailData.value = await PlasmidApi.getPlasmid(id)
    if (canViewStorage) {
      storageLoading.value = true
      try {
        storageData.value = await PlasmidStorageApi.getPositionByPlasmid(id)
      } finally {
        storageLoading.value = false
      }
    }
  } finally {
    detailLoading.value = false
  }
}

/** 提交审核操作 */
const handleSubmit = async (id: number) => {
  try {
    await message.confirm('确认提交审核？提交后不可再编辑或删除。')
    await PlasmidApi.submitPlasmid(id)
    message.success('提交审核成功')
    await getList()
  } catch {}
}

/** 删除按钮操作 */
const handleDelete = async (id: number) => {
  try {
    // 删除的二次确认
    await message.delConfirm()
    // 发起删除
    await PlasmidApi.deletePlasmid(id)
    message.success(t('common.delSuccess'))
    // 刷新列表
    await getList()
  } catch {}
}

/** 初始化 **/
onMounted(() => {
  getTypeList()
  getList()
})
</script>
