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
      </el-form-item>
    </el-form>
  </ContentWrap>

  <!-- 审核列表 -->
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
      <el-table-column label="改造信息" align="center" prop="modification" />
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
      <el-table-column label="操作" align="center" width="200px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openDetail(scope.row.id)">详情</el-button>
          <el-button
            link
            type="success"
            @click="openApprove(scope.row.id)"
            v-hasPermi="['lab:plasmid:audit:approve']"
            v-if="scope.row.auditStatus === 'PENDING'"
          >
            审核通过
          </el-button>
          <el-button
            link
            type="danger"
            @click="openReject(scope.row.id)"
            v-hasPermi="['lab:plasmid:audit:reject']"
            v-if="scope.row.auditStatus === 'PENDING'"
          >
            审核驳回
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

  <!-- ==================== 审核详情 Dialog ==================== -->
  <Dialog title="审核详情" v-model="detailVisible" width="900px">
    <div v-loading="detailLoading">
      <!-- A. 基本信息 -->
      <el-divider content-position="left">质粒基本信息</el-divider>
      <el-descriptions :column="2" border>
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
        <el-descriptions-item label="改造信息">{{ detailData.modification }}</el-descriptions-item>
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
        <el-descriptions-item label="创建时间">{{ formatDate(detailData.createTime) }}</el-descriptions-item>
      </el-descriptions>

      <!-- B. 登记信息（original* 只读） -->
      <el-divider content-position="left">登记信息</el-divider>
      <el-descriptions :column="2" border>
        <el-descriptions-item label="保存形式">
          <dict-tag
            v-for="tag in splitTags(detailData.storageForm)"
            :key="tag"
            :type="DICT_TYPE.LAB_PLASMID_STORAGE_FORM"
            :value="tag"
            class="mr-2px"
          />
        </el-descriptions-item>
        <el-descriptions-item label="质粒浓度">{{ detailData.concentration }} ng/μL</el-descriptions-item>
        <el-descriptions-item label="质粒体积">{{ detailData.volume }} μL</el-descriptions-item>
        <el-descriptions-item label="甘油菌规格">{{ detailData.glycerinSpec }}</el-descriptions-item>
        <el-descriptions-item label="甘油菌量">{{ detailData.glycerinAmount }} μL</el-descriptions-item>
        <el-descriptions-item label="申报初始库存">{{ detailData.initialQuantityDeclared }} μL</el-descriptions-item>
        <el-descriptions-item label="原始质粒冰箱">{{ detailData.originalPlasmidFridge }}</el-descriptions-item>
        <el-descriptions-item label="原始质粒层">{{ detailData.originalPlasmidLayer }}</el-descriptions-item>
        <el-descriptions-item label="原始质粒盒">{{ detailData.originalPlasmidBox }}</el-descriptions-item>
        <el-descriptions-item label="原始质粒位置">{{ detailData.originalPlasmidPosition }}</el-descriptions-item>
        <el-descriptions-item label="原始甘油菌冰箱">{{ detailData.originalGlycerinFridge }}</el-descriptions-item>
        <el-descriptions-item label="原始甘油菌层">{{ detailData.originalGlycerinLayer }}</el-descriptions-item>
        <el-descriptions-item label="原始甘油菌盒">{{ detailData.originalGlycerinBox }}</el-descriptions-item>
        <el-descriptions-item label="原始甘油菌位置">{{ detailData.originalGlycerinPosition }}</el-descriptions-item>
        <el-descriptions-item label="序列图谱文件" :span="2">
          <span v-if="detailData.sequenceFileId">{{ detailData.sequenceFileName }}</span>
          <span v-else-if="detailData.sequenceNoFileReason">无文件：{{ detailData.sequenceNoFileReason }}</span>
          <span v-else>-</span>
        </el-descriptions-item>
        <el-descriptions-item label="测序/检测报告" :span="2">
          <span v-if="detailData.sequencingReportFileId">{{ detailData.sequencingReportFileName }}</span>
          <span v-else>-</span>
        </el-descriptions-item>
      </el-descriptions>

      <!-- C. 审核历史 -->
      <el-divider content-position="left">审核历史</el-divider>
      <el-table :data="auditHistoryList" :stripe="true" size="small" max-height="260px">
        <el-table-column label="轮次" align="center" prop="submitCount" width="70px" />
        <el-table-column label="审核结果" align="center" prop="auditResult">
          <template #default="scope">
            <dict-tag :type="DICT_TYPE.LAB_PLASMID_AUDIT_STATUS" :value="scope.row.auditResult" />
          </template>
        </el-table-column>
        <el-table-column label="审核意见" align="center" prop="auditOpinion" :show-overflow-tooltip="true" />
        <el-table-column label="提交人" align="center" prop="submitterName" />
        <el-table-column label="审核人" align="center" prop="auditorName" />
        <el-table-column label="提交时间" align="center" prop="submitTime" :formatter="dateFormatter" width="160px" />
        <el-table-column label="审核时间" align="center" prop="auditTime" :formatter="dateFormatter" width="160px" />
      </el-table>
      <Pagination
        :total="auditHistoryTotal"
        v-model:page="auditHistoryQuery.pageNo"
        v-model:limit="auditHistoryQuery.pageSize"
        @pagination="getAuditHistory"
        small
      />
    </div>
    <template #footer>
      <el-button @click="detailVisible = false">关 闭</el-button>
    </template>
  </Dialog>

  <!-- ==================== 审核通过 Dialog ==================== -->
  <Dialog title="审核通过" v-model="approveVisible" width="900px">
    <div v-loading="approveLoading">
      <!-- 1. 登记信息（全部只读） -->
      <el-divider content-position="left">登记信息（只读）</el-divider>
      <el-descriptions :column="2" border>
        <el-descriptions-item label="保存形式">
          <dict-tag
            v-for="tag in splitTags(approveData.storageForm)"
            :key="tag"
            :type="DICT_TYPE.LAB_PLASMID_STORAGE_FORM"
            :value="tag"
            class="mr-2px"
          />
        </el-descriptions-item>
        <el-descriptions-item label="质粒浓度">{{ approveData.concentration }} ng/μL</el-descriptions-item>
        <el-descriptions-item label="质粒体积">{{ approveData.volume }} μL</el-descriptions-item>
        <el-descriptions-item label="甘油菌规格">{{ approveData.glycerinSpec }}</el-descriptions-item>
        <el-descriptions-item label="甘油菌量">{{ approveData.glycerinAmount }} μL</el-descriptions-item>
        <el-descriptions-item label="申报初始库存">{{ approveData.initialQuantityDeclared }} μL</el-descriptions-item>
        <el-descriptions-item label="原始质粒冰箱">{{ approveData.originalPlasmidFridge }}</el-descriptions-item>
        <el-descriptions-item label="原始质粒层">{{ approveData.originalPlasmidLayer }}</el-descriptions-item>
        <el-descriptions-item label="原始质粒盒">{{ approveData.originalPlasmidBox }}</el-descriptions-item>
        <el-descriptions-item label="原始质粒位置">{{ approveData.originalPlasmidPosition }}</el-descriptions-item>
        <el-descriptions-item label="原始甘油菌冰箱">{{ approveData.originalGlycerinFridge }}</el-descriptions-item>
        <el-descriptions-item label="原始甘油菌层">{{ approveData.originalGlycerinLayer }}</el-descriptions-item>
        <el-descriptions-item label="原始甘油菌盒">{{ approveData.originalGlycerinBox }}</el-descriptions-item>
        <el-descriptions-item label="原始甘油菌位置">{{ approveData.originalGlycerinPosition }}</el-descriptions-item>
        <el-descriptions-item label="序列图谱文件" :span="2">
          <span v-if="approveData.sequenceFileId">{{ approveData.sequenceFileName }}</span>
          <span v-else-if="approveData.sequenceNoFileReason">无文件：{{ approveData.sequenceNoFileReason }}</span>
          <span v-else>-</span>
        </el-descriptions-item>
        <el-descriptions-item label="测序/检测报告" :span="2">
          <span v-if="approveData.sequencingReportFileId">{{ approveData.sequencingReportFileName }}</span>
          <span v-else>-</span>
        </el-descriptions-item>
      </el-descriptions>

      <!-- 2. 审核通过表单 -->
      <el-form
        ref="approveFormRef"
        :model="approveForm"
        :rules="approveFormRules"
        label-width="140px"
      >
        <!-- 正式质粒位置 -->
        <el-divider content-position="left">正式质粒位置（库管员填写）</el-divider>
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="质粒冰箱" prop="storageConfirm.plasmidFridge">
              <el-input v-model="approveForm.storageConfirm.plasmidFridge" placeholder="请输入质粒存放冰箱" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="质粒层数" prop="storageConfirm.plasmidLayer">
              <el-input v-model="approveForm.storageConfirm.plasmidLayer" placeholder="请输入质粒存放层数" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="质粒盒" prop="storageConfirm.plasmidBox">
              <el-input v-model="approveForm.storageConfirm.plasmidBox" placeholder="请输入质粒存放盒" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="质粒盒内位置" prop="storageConfirm.plasmidPosition">
              <el-input v-model="approveForm.storageConfirm.plasmidPosition" placeholder="请输入质粒盒内位置" />
            </el-form-item>
          </el-col>
        </el-row>

        <!-- 正式甘油菌位置 -->
        <el-divider content-position="left">正式甘油菌位置（库管员填写）</el-divider>
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="甘油菌冰箱" prop="storageConfirm.glycerinFridge">
              <el-input v-model="approveForm.storageConfirm.glycerinFridge" placeholder="请输入甘油菌存放冰箱" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="甘油菌层数" prop="storageConfirm.glycerinLayer">
              <el-input v-model="approveForm.storageConfirm.glycerinLayer" placeholder="请输入甘油菌存放层数" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="甘油菌盒" prop="storageConfirm.glycerinBox">
              <el-input v-model="approveForm.storageConfirm.glycerinBox" placeholder="请输入甘油菌存放盒" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="甘油菌盒内位置" prop="storageConfirm.glycerinPosition">
              <el-input v-model="approveForm.storageConfirm.glycerinPosition" placeholder="请输入甘油菌盒内位置" />
            </el-form-item>
          </el-col>
        </el-row>

        <!-- 库存确认 -->
        <el-divider content-position="left">库存确认</el-divider>
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="确认初始库存" prop="initialQuantityConfirmed">
              <el-input-number
                v-model="approveForm.initialQuantityConfirmed"
                :min="0"
                :precision="2"
                placeholder="请输入确认初始库存"
                class="!w-full"
              />
              <span class="ml-5px text-gray-400">μL</span>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="低库存阈值" prop="lowStockThreshold">
              <el-input-number
                v-model="approveForm.lowStockThreshold"
                :min="0"
                :precision="2"
                placeholder="请输入低库存阈值（可选）"
                class="!w-full"
              />
              <span class="ml-5px text-gray-400">μL</span>
            </el-form-item>
          </el-col>
        </el-row>

        <!-- 审核意见 -->
        <el-row :gutter="20">
          <el-col :span="24">
            <el-form-item label="审核意见" prop="opinion">
              <el-input
                v-model="approveForm.opinion"
                type="textarea"
                :rows="3"
                placeholder="审核通过意见（可选）"
              />
            </el-form-item>
          </el-col>
        </el-row>

        <!-- 管理员备注（StorageConfirm.remark） -->
        <el-row :gutter="20">
          <el-col :span="24">
            <el-form-item label="管理员备注" prop="storageConfirm.remark">
              <el-input
                v-model="approveForm.storageConfirm.remark"
                type="textarea"
                :rows="2"
                placeholder="管理员备注（可选）"
              />
            </el-form-item>
          </el-col>
        </el-row>
      </el-form>
    </div>
    <template #footer>
      <el-button @click="approveVisible = false">取 消</el-button>
      <el-button type="primary" @click="submitApprove" :disabled="approveSubmitLoading">确 定</el-button>
    </template>
  </Dialog>

  <!-- ==================== 审核驳回 Dialog ==================== -->
  <Dialog title="审核驳回" v-model="rejectVisible" width="500px">
    <el-form ref="rejectFormRef" :model="rejectForm" :rules="rejectFormRules" label-width="100px">
      <el-form-item label="驳回意见" prop="opinion">
        <el-input
          v-model="rejectForm.opinion"
          type="textarea"
          :rows="4"
          placeholder="请输入驳回意见（必填）"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="rejectVisible = false">取 消</el-button>
      <el-button type="danger" @click="submitReject" :disabled="rejectSubmitLoading">确 定</el-button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { getStrDictOptions, DICT_TYPE } from '@/utils/dict'
import { dateFormatter, formatDate } from '@/utils/formatTime'
import { PlasmidAuditApi, PlasmidAuditViewVO, PlasmidAuditHistoryVO } from '@/api/lab/v2/plasmid-audit'
import { PlasmidTypeApi, PlasmidTypeVO } from '@/api/lab/v2/plasmid-type'

/** 质粒审核（V2）列表 */
defineOptions({ name: 'PlasmidV2Audit' })

const message = useMessage() // 消息弹窗
// ========== 审核列表 ==========
const loading = ref(true) // 列表的加载中
const list = ref<PlasmidAuditViewVO[]>([]) // 列表的数据
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
  auditStatus: 'PENDING', // 默认展示待审核
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

/** 荧光标签/保存形式多值拆分 */
const splitTags = (val?: string) => {
  return val ? val.split(',').filter((item) => !!item) : []
}

/** 查询列表 */
const getList = async () => {
  loading.value = true
  try {
    const data = await PlasmidAuditApi.getPlasmidAuditPage(queryParams)
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
  // 重置后仍保持默认 PENDING
  queryParams.auditStatus = 'PENDING'
  handleQuery()
}

// ========== 审核详情 ==========
const detailVisible = ref(false)
const detailLoading = ref(false)
const detailData = ref<PlasmidAuditViewVO>({} as PlasmidAuditViewVO)
const auditHistoryList = ref<PlasmidAuditHistoryVO[]>([])
const auditHistoryTotal = ref(0)
const auditHistoryQuery = reactive({
  pageNo: 1,
  pageSize: 5,
  plasmidId: undefined as number | undefined
})

const openDetail = async (id: number) => {
  detailVisible.value = true
  detailLoading.value = true
  try {
    detailData.value = await PlasmidAuditApi.getPlasmidAuditView(id)
    // 加载审核历史
    auditHistoryQuery.plasmidId = id
    auditHistoryQuery.pageNo = 1
    await getAuditHistory()
  } finally {
    detailLoading.value = false
  }
}

const getAuditHistory = async () => {
  if (!auditHistoryQuery.plasmidId) return
  const data = await PlasmidAuditApi.getPlasmidAuditHistoryPage(auditHistoryQuery)
  auditHistoryList.value = data.list
  auditHistoryTotal.value = data.total
}

// ========== 审核通过 ==========
const approveVisible = ref(false)
const approveLoading = ref(false)
const approveSubmitLoading = ref(false)
const approveFormRef = ref()
const approveData = ref<PlasmidAuditViewVO>({} as PlasmidAuditViewVO)
const approveForm = ref({
  id: undefined as number | undefined,
  opinion: undefined as string | undefined,
  initialQuantityConfirmed: undefined as number | undefined,
  lowStockThreshold: undefined as number | undefined,
  storageConfirm: {
    plasmidFridge: undefined,
    plasmidLayer: undefined,
    plasmidBox: undefined,
    plasmidPosition: undefined,
    glycerinFridge: undefined,
    glycerinLayer: undefined,
    glycerinBox: undefined,
    glycerinPosition: undefined,
    remark: undefined
  } as Record<string, any>
})
const approveFormRules = reactive({
  initialQuantityConfirmed: [{ required: true, message: '确认初始库存不能为空', trigger: 'blur' }]
})

const openApprove = async (id: number) => {
  approveVisible.value = true
  approveLoading.value = true
  try {
    const data = await PlasmidAuditApi.getPlasmidAuditView(id)
    approveData.value = data
    approveForm.value = {
      id: data.id,
      opinion: undefined,
      initialQuantityConfirmed: undefined,
      lowStockThreshold: undefined,
      storageConfirm: {
        // 登记事实：回传原值（后端有 Storage 记录时强制使用 DB 原值）
        storageForm: data.storageForm,
        concentration: data.concentration,
        volume: data.volume,
        glycerinSpec: data.glycerinSpec,
        glycerinAmount: data.glycerinAmount,
        originalPlasmidFridge: data.originalPlasmidFridge,
        originalPlasmidLayer: data.originalPlasmidLayer,
        originalPlasmidBox: data.originalPlasmidBox,
        originalPlasmidPosition: data.originalPlasmidPosition,
        originalGlycerinFridge: data.originalGlycerinFridge,
        originalGlycerinLayer: data.originalGlycerinLayer,
        originalGlycerinBox: data.originalGlycerinBox,
        originalGlycerinPosition: data.originalGlycerinPosition,
        sequenceFileId: data.sequenceFileId,
        sequenceFileName: data.sequenceFileName,
        sequenceNoFileReason: data.sequenceNoFileReason,
        sequencingReportFileId: data.sequencingReportFileId,
        sequencingReportFileName: data.sequencingReportFileName,
        // 库管员填写：初始为空
        plasmidFridge: undefined,
        plasmidLayer: undefined,
        plasmidBox: undefined,
        plasmidPosition: undefined,
        glycerinFridge: undefined,
        glycerinLayer: undefined,
        glycerinBox: undefined,
        glycerinPosition: undefined,
        remark: undefined
      }
    }
  } finally {
    approveLoading.value = false
  }
}

const submitApprove = async () => {
  const valid = await approveFormRef.value?.validate().catch(() => false)
  if (!valid) return
  approveSubmitLoading.value = true
  try {
    await PlasmidAuditApi.approvePlasmid(approveForm.value as any)
    message.success('审核通过成功')
    approveVisible.value = false
    await getList()
  } finally {
    approveSubmitLoading.value = false
  }
}

// ========== 审核驳回 ==========
const rejectVisible = ref(false)
const rejectSubmitLoading = ref(false)
const rejectFormRef = ref()
const rejectForm = ref({
  id: undefined as number | undefined,
  opinion: undefined as string | undefined
})
const rejectFormRules = reactive({
  opinion: [{ required: true, message: '驳回意见不能为空', trigger: 'blur' }]
})

const openReject = (id: number) => {
  rejectVisible.value = true
  rejectForm.value = {
    id,
    opinion: undefined
  }
}

const submitReject = async () => {
  const valid = await rejectFormRef.value?.validate().catch(() => false)
  if (!valid) return
  rejectSubmitLoading.value = true
  try {
    await PlasmidAuditApi.rejectPlasmid(rejectForm.value as any)
    message.success('审核驳回成功')
    rejectVisible.value = false
    await getList()
  } finally {
    rejectSubmitLoading.value = false
  }
}

/** 初始化 **/
onMounted(() => {
  getTypeList()
  getList()
})
</script>
