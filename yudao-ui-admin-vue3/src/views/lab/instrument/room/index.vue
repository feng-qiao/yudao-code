<template>
  <ContentWrap>
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="80px">
      <el-form-item label="房间编码" prop="code">
        <el-input v-model="queryParams.code" placeholder="请输入编码" clearable @keyup.enter="handleQuery" class="!w-160px" />
      </el-form-item>
      <el-form-item label="房间名称" prop="name">
        <el-input v-model="queryParams.name" placeholder="请输入名称" clearable @keyup.enter="handleQuery" class="!w-160px" />
      </el-form-item>
      <el-form-item label="楼栋" prop="building">
        <el-input v-model="queryParams.building" placeholder="请输入楼栋" clearable @keyup.enter="handleQuery" class="!w-160px" />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择" clearable class="!w-120px">
          <el-option label="启用" value="ENABLE" />
          <el-option label="停用" value="DISABLE" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" class="mr-5px" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" class="mr-5px" />重置</el-button>
        <el-button type="primary" plain @click="openForm('create')" v-hasPermi="['lab:instrument:room:create']">
          <Icon icon="ep:plus" class="mr-5px" />新增
        </el-button>
      </el-form-item>
    </el-form>
  </ContentWrap>

  <ContentWrap>
    <el-table v-loading="loading" :data="list" stripe>
      <el-table-column label="房间编码" align="center" prop="code" width="130px" />
      <el-table-column label="房间名称" align="center" prop="name" width="130px" />
      <el-table-column label="楼栋" align="center" prop="building" width="110px" />
      <el-table-column label="楼层" align="center" prop="floor" width="90px" />
      <el-table-column label="位置描述" align="center" prop="locationDesc" show-overflow-tooltip />
      <el-table-column label="维修负责人" align="center" min-width="160px">
        <template #default="scope">
          <span v-if="(scope.row.repairManagers || []).length">
            <el-tag
              v-for="m in scope.row.repairManagers"
              :key="m.id"
              size="small"
              class="mr-5px"
            >
              {{ m.nickname }}<span v-if="m.mobile">（{{ m.mobile }}）</span>
            </el-tag>
          </span>
          <span v-else class="text-[var(--el-text-color-secondary)]">未分配</span>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" prop="status" width="80px">
        <template #default="scope">
          <el-tag :type="scope.row.status === 'ENABLE' ? 'success' : 'info'">
            {{ scope.row.status === 'ENABLE' ? '启用' : '停用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="160px" fixed="right">
        <template #default="scope">
          <el-button link type="primary" @click="openForm('update', scope.row.id)" v-hasPermi="['lab:instrument:room:update']">编辑</el-button>
          <el-button link type="danger" @click="handleDelete(scope.row.id)" v-hasPermi="['lab:instrument:room:delete']">删除</el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination :total="total" v-model:page="queryParams.pageNo" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </ContentWrap>

  <RoomForm ref="formRef" @success="getList" />
</template>

<script setup lang="ts">
import { InstrumentRoomApi, InstrumentRoomVO } from '@/api/lab/instrument/room'
import RoomForm from './RoomForm.vue'

defineOptions({ name: 'LabInstrumentRoom' })

const message = useMessage()
const loading = ref(true)
const list = ref<InstrumentRoomVO[]>([])
const total = ref(0)
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  code: undefined,
  name: undefined,
  building: undefined,
  status: undefined
})
const queryFormRef = ref()
const formRef = ref()

const getList = async () => {
  loading.value = true
  try {
    const data = await InstrumentRoomApi.getPage(queryParams)
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
const handleDelete = async (id: number) => {
  try {
    await message.delConfirm()
    await InstrumentRoomApi.delete(id)
    message.success('删除成功')
    await getList()
  } catch {}
}

onMounted(() => {
  getList()
})
</script>
