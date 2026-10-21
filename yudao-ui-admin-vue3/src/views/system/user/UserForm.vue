<template>
  <Dialog v-model="dialogVisible" :title="dialogTitle">
    <el-form
      ref="formRef"
      v-loading="formLoading"
      :model="formData"
      :rules="formRules"
      label-width="80px"
    >
      <el-row>
        <el-col :span="12">
          <el-form-item label="用户昵称" prop="nickname">
            <el-input v-model="formData.nickname" placeholder="请输入用户昵称" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="归属部门" prop="deptId">
            <el-tree-select
              v-model="formData.deptId"
              :data="deptList"
              :props="defaultProps"
              check-strictly
              node-key="id"
              placeholder="请选择归属部门"
            />
          </el-form-item>
        </el-col>
      </el-row>
      <el-row>
        <el-col :span="12">
          <el-form-item label="手机号码" prop="mobile">
            <el-input v-model="formData.mobile" maxlength="11" placeholder="请输入手机号码" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="邮箱" prop="email">
            <el-input v-model="formData.email" maxlength="50" placeholder="请输入邮箱" />
          </el-form-item>
        </el-col>
      </el-row>
      <el-row>
        <el-col :span="12">
          <el-form-item v-if="formData.id === undefined" label="用户名称" prop="username">
            <el-input v-model="formData.username" placeholder="请输入用户名称" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item v-if="formData.id === undefined" label="用户密码" prop="password">
            <el-input
              v-model="formData.password"
              placeholder="请输入用户密码"
              show-password
              type="password"
            />
          </el-form-item>
        </el-col>
      </el-row>
      <el-row>
        <el-col :span="12">
          <el-form-item label="用户性别">
            <el-select v-model="formData.sex" placeholder="请选择">
              <el-option
                v-for="dict in getIntDictOptions(DICT_TYPE.SYSTEM_USER_SEX)"
                :key="dict.value"
                :label="dict.label"
                :value="dict.value"
              />
            </el-select>
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="岗位">
            <el-select v-model="formData.postIds" multiple placeholder="请选择">
              <el-option
                v-for="item in postList"
                :key="item.id"
                :label="item.name"
                :value="item.id!"
              />
            </el-select>
          </el-form-item>
        </el-col>
      </el-row>
      <el-row>
        <el-col :span="12">
          <el-form-item label="身份类别">
            <el-select v-model="formData.identityType" placeholder="请选择身份类别" clearable>
              <el-option label="硕士" :value="1" />
              <el-option label="博士" :value="2" />
              <el-option label="博士后" :value="3" />
              <el-option label="科研助理" :value="4" />
              <el-option label="教师" :value="5" />
            </el-select>
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="研究方向">
            <el-select v-model="formData.researchDirection" placeholder="请选择研究方向" clearable>
              <el-option label="中药新药开发与转化平台" :value="1" />
              <el-option label="中药药效物质及合成生物学创制平台" :value="2" />
              <el-option label="中医药人工智能平台" :value="3" />
              <el-option label="生物信息学与GPCR多组学研究平台" :value="4" />
              <el-option label="药物化学与递送系统开发平台" :value="5" />
              <el-option label="中药活性成分筛选与分子育种平台" :value="6" />
              <el-option label="中药受体药理学与靶标发现平台" :value="7" />
            </el-select>
          </el-form-item>
        </el-col>
      </el-row>
      <el-row>
        <el-col :span="12">
          <el-form-item label="导师">
            <el-input v-model="formData.supervisor" maxlength="50" placeholder="硕士/博士/博士后必填" />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="指导教师">
            <el-input v-model="formData.instructor" maxlength="50" placeholder="请输入指导教师" />
          </el-form-item>
        </el-col>
      </el-row>
      <el-row>
        <el-col :span="12">
          <el-form-item label="开始年月">
            <el-date-picker
              v-model="formData.startYmd"
              type="month"
              value-format="YYYY-MM"
              placeholder="选择开始年月"
              style="width: 100%"
            />
          </el-form-item>
        </el-col>
        <el-col :span="12">
          <el-form-item label="结束年月">
            <el-date-picker
              v-model="formData.endYmd"
              type="month"
              value-format="YYYY-MM"
              placeholder="选择结束年月"
              style="width: 100%"
            />
          </el-form-item>
        </el-col>
      </el-row>
      <el-row>
        <el-col :span="24">
          <el-form-item label="备注">
            <el-input v-model="formData.remark" placeholder="请输入内容" type="textarea" />
          </el-form-item>
        </el-col>
      </el-row>
    </el-form>
    <template #footer>
      <el-button :disabled="formLoading" type="primary" @click="submitForm">确 定</el-button>
      <el-button @click="dialogVisible = false">取 消</el-button>
    </template>
  </Dialog>
</template>
<script lang="ts" setup>
import { DICT_TYPE, getIntDictOptions } from '@/utils/dict'
import { CommonStatusEnum } from '@/utils/constants'
import { defaultProps, handleTree } from '@/utils/tree'
import * as PostApi from '@/api/system/post'
import * as DeptApi from '@/api/system/dept'
import * as UserApi from '@/api/system/user'
import { FormRules } from 'element-plus'

defineOptions({ name: 'SystemUserForm' })

const { t } = useI18n() // 国际化
const message = useMessage() // 消息弹窗

const dialogVisible = ref(false) // 弹窗的是否展示
const dialogTitle = ref('') // 弹窗的标题
const formLoading = ref(false) // 表单的加载中：1）修改时的数据加载；2）提交的按钮禁用
const formType = ref('') // 表单的类型：create - 新增；update - 修改
const formData = ref({
  nickname: '',
  deptId: '',
  mobile: '',
  email: '',
  id: undefined,
  username: '',
  password: '',
  sex: undefined,
  postIds: [],
  remark: '',
  status: CommonStatusEnum.ENABLE,
  roleIds: [],
  identityType: undefined,
  researchDirection: undefined,
  supervisor: '',
  instructor: '',
  startYmd: '',
  endYmd: ''
})
const formRules = reactive<FormRules>({
  username: [{ required: true, message: '用户名称不能为空', trigger: 'blur' }],
  nickname: [{ required: true, message: '用户昵称不能为空', trigger: 'blur' }],
  password: [{ required: true, message: '用户密码不能为空', trigger: 'blur' }],
  email: [
    {
      type: 'email',
      message: '请输入正确的邮箱地址',
      trigger: ['blur', 'change']
    }
  ],
  mobile: [
    {
      pattern: /^1[3-9]\d{9}$/,
      message: '请输入正确的手机号码',
      trigger: 'blur'
    }
  ]
})
const formRef = ref() // 表单 Ref
const deptList = ref<Tree[]>([]) // 树形结构
const postList = ref([] as PostApi.PostVO[]) // 岗位列表

/** 打开弹窗 */
const open = async (type: string, id?: number) => {
  dialogVisible.value = true
  dialogTitle.value = t('action.' + type)
  formType.value = type
  resetForm()
  // 修改时，设置数据
  if (id) {
    formLoading.value = true
    try {
      formData.value = await UserApi.getUser(id)
    } finally {
      formLoading.value = false
    }
  }
  // 加载部门树
  deptList.value = handleTree(await DeptApi.getSimpleDeptList())
  // 加载岗位列表
  postList.value = await PostApi.getSimplePostList()
}
defineExpose({ open }) // 提供 open 方法，用于打开弹窗

/** 提交表单 */
const emit = defineEmits(['success']) // 定义 success 事件，用于操作成功后的回调
const submitForm = async () => {
  // 校验表单
  if (!formRef) return
  const valid = await formRef.value.validate()
  if (!valid) return
  // 提交请求
  formLoading.value = true
  try {
    const data = formData.value as unknown as UserApi.UserVO
    if (formType.value === 'create') {
      await UserApi.createUser(data)
      message.success(t('common.createSuccess'))
    } else {
      await UserApi.updateUser(data)
      message.success(t('common.updateSuccess'))
    }
    dialogVisible.value = false
    // 发送操作成功的事件
    emit('success')
  } finally {
    formLoading.value = false
  }
}

/** 重置表单 */
const resetForm = () => {
  formData.value = {
    nickname: '',
    deptId: '',
    mobile: '',
    email: '',
    id: undefined,
    username: '',
    password: '',
    sex: undefined,
    postIds: [],
    remark: '',
    status: CommonStatusEnum.ENABLE,
    roleIds: [],
    identityType: undefined,
    researchDirection: undefined,
    supervisor: '',
    instructor: '',
    startYmd: '',
    endYmd: ''
  }
  formRef.value?.resetFields()
}
</script>
