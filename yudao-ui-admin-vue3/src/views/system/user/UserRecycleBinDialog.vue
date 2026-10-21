<template>
  <Dialog v-model="dialogVisible" title="已删除用户（回收站）" width="80%">
    <!-- 搜索 -->
    <el-form class="-mb-15px" :model="queryParams" ref="queryFormRef" :inline="true" label-width="68px">
      <el-form-item label="用户名称" prop="username">
        <el-input
          v-model="queryParams.username"
          placeholder="请输入用户名称"
          clearable
          @keyup.enter="handleQuery"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="用户昵称" prop="nickname">
        <el-input
          v-model="queryParams.nickname"
          placeholder="请输入用户昵称"
          clearable
          @keyup.enter="handleQuery"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item label="手机号码" prop="mobile">
        <el-input
          v-model="queryParams.mobile"
          placeholder="请输入手机号码"
          clearable
          @keyup.enter="handleQuery"
          class="!w-200px"
        />
      </el-form-item>
      <el-form-item>
        <el-button @click="handleQuery"><Icon icon="ep:search" />搜索</el-button>
        <el-button @click="resetQuery"><Icon icon="ep:refresh" />重置</el-button>
      </el-form-item>
    </el-form>

    <el-table v-loading="loading" :data="list">
      <el-table-column label="用户编号" align="center" prop="id" width="90" />
      <el-table-column label="用户名称" align="center" prop="username" :show-overflow-tooltip="true" />
      <el-table-column label="用户昵称" align="center" prop="nickname" :show-overflow-tooltip="true" />
      <el-table-column label="部门" align="center" prop="deptName" :show-overflow-tooltip="true" />
      <el-table-column label="手机号码" align="center" prop="mobile" width="120" />
      <el-table-column label="状态" align="center" prop="status" width="80">
        <template #default="scope">
          <dict-tag :type="DICT_TYPE.COMMON_STATUS" :value="scope.row.status" />
        </template>
      </el-table-column>
      <el-table-column
        label="删除时间"
        align="center"
        prop="updateTime"
        :formatter="dateFormatter"
        width="180"
      />
      <el-table-column label="操作" align="center" width="120" fixed="right">
        <template #default="scope">
          <el-button
            type="primary"
            link
            @click="handleRestore(scope.row)"
            v-hasPermi="['system:user:restore']"
          >
            <Icon icon="ep:refresh-left" />恢复
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    <Pagination
      :total="total"
      v-model:page="queryParams.pageNo"
      v-model:limit="queryParams.pageSize"
      @pagination="getList"
    />
  </Dialog>
</template>

<script lang="ts" setup>
import { DICT_TYPE } from '@/utils/dict'
import { dateFormatter } from '@/utils/formatTime'
import * as UserApi from '@/api/system/user'

defineOptions({ name: 'UserRecycleBinDialog' })

const message = useMessage()

const emit = defineEmits(['restored'])

const dialogVisible = ref(false)
const loading = ref(false)
const total = ref(0)
const list = ref([])
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  username: undefined,
  nickname: undefined,
  mobile: undefined
})
const queryFormRef = ref()

/** 查询已删除用户列表 */
const getList = async () => {
  loading.value = true
  try {
    const data = await UserApi.getDeletedUserPage(queryParams)
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
  queryFormRef.value?.resetFields()
  handleQuery()
}

/** 恢复用户 */
const handleRestore = async (row: UserApi.UserVO) => {
  try {
    await message.confirm(
      '确认恢复用户"' + row.username + '"吗？恢复后需重新分配角色与岗位。'
    )
    await UserApi.restoreUser(row.id)
    message.success('恢复成功')
    await getList()
    emit('restored')
  } catch {}
}

/** 打开弹窗 */
const open = () => {
  dialogVisible.value = true
  queryParams.pageNo = 1
  getList()
}
defineExpose({ open })
</script>
