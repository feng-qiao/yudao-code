<template>
  <ContentWrap>
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="80px">
      <el-form-item label="平台编码" prop="code">
        <el-input v-model="queryParams.code" placeholder="请输入编码" clearable @keyup.enter="handleQuery" class="!w-180px" />
      </el-form-item>
      <el-form-item label="平台名称" prop="name">
        <el-input v-model="queryParams.name" placeholder="请输入名称" clearable @keyup.enter="handleQuery" class="!w-180px" />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable class="!w-140px">
          <el-option label="启用" value="ENABLE" />
          <el-option label="停用" value="DISABLE" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
        <el-button type="primary" plain @click="openForm('create')" v-hasPermi="['lab:instrument:platform:create']">
          <Icon icon="ep:plus" class="mr-5px" />新增
        </el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <ContentWrap>
    <el-table v-loading="loading" :data="list" stripe>
      <el-table-column label="平台编码" align="center" prop="code" width="140px" />
      <el-table-column label="平台名称" align="center" prop="name" width="180px" />
      <el-table-column label="平台描述" align="center" prop="description" show-overflow-tooltip />
      <el-table-column label="状态" align="center" prop="status" width="90px">
        <template #default="scope">
          <el-tag :type="scope.row.status === 'ENABLE' ? 'success' : 'info'">
            {{ scope.row.status === 'ENABLE' ? '启用' : '停用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="排序" align="center" prop="sort" width="70px" />
      <el-table-column label="备注" align="center" prop="remark" show-overflow-tooltip />
      <el-table-column label="创建时间" align="center" prop="createTime" :formatter="dateFormatter" width="170px" />
      <el-table-column label="操作" align="center" width="240px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="handleStatus(scope.row)" v-hasPermi="['lab:instrument:platform:update']">
            {{ scope.row.status === 'ENABLE' ? '停用' : '启用' }}
          </el-button>
          <el-button link type="primary" @click="openForm('update', scope.row.id)" v-hasPermi="['lab:instrument:platform:update']">编辑</el-button>
          <el-button link type="danger" @click="handleDelete(scope.row.id)" v-hasPermi="['lab:instrument:platform:delete']">删除</el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </ContentWrap>

  <PlatformForm ref="formRef" @success="getList" />
</template>

<script setup lang="ts">
import { dateFormatter } from '@/utils/formatTime'
import { InstrumentPlatformApi, InstrumentPlatformVO } from '@/api/lab/instrument/platform'
import PlatformForm from './PlatformForm.vue'

defineOptions({ name: 'LabInstrumentPlatform' })

const message = useMessage()
const loading = ref(true)
const list = ref<InstrumentPlatformVO[]>([])
const total = ref(0)
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  code: undefined,
  name: undefined,
  status: undefined
})
const queryFormRef = ref()
const formRef = ref()

const getList = async () => {
  loading.value = true
  try {
    const data = await InstrumentPlatformApi.getPage(queryParams)
    list.value = data.list
    total.value = data.total
  } finally {
    loading.value = false
  }
}

const handleQuery = () => {
  queryParams.pageNo = 1
  getList()
}
const resetQuery = () => {
  queryFormRef.value.resetFields()
  handleQuery()
}
const openForm = (type: 'create' | 'update', id?: number) => {
  formRef.value.open(type, id)
}
const handleStatus = async (row: InstrumentPlatformVO) => {
  const target = row.status === 'ENABLE' ? 'DISABLE' : 'ENABLE'
  await message.confirm(`确认${target === 'DISABLE' ? '停用' : '启用'}平台「${row.name}」？`)
  await InstrumentPlatformApi.updateStatus(row.id!, target)
  message.success('操作成功')
  await getList()
}
const handleDelete = async (id: number) => {
  try {
    await message.delConfirm()
    await InstrumentPlatformApi.delete(id)
    message.success('删除成功')
    await getList()
  } catch {}
}

onMounted(() => {
  getList()
})
</script>
