<template>
  <Form ref="formRef" :labelWidth="200" :rules="rules" :schema="schema">
    <template #sex="form">
      <el-radio-group v-model="form['sex']">
        <el-radio :value="1">{{ t('profile.user.man') }}</el-radio>
        <el-radio :value="2">{{ t('profile.user.woman') }}</el-radio>
      </el-radio-group>
    </template>
  </Form>
  <div style="text-align: center">
    <el-button type="primary" @click="submit()">{{ t('common.save') }}</el-button>
    <el-button type="danger" @click="init()">{{ t('common.reset') }}</el-button>
  </div>
</template>
<script lang="ts" setup>
import type { FormRules } from 'element-plus'
import { FormSchema } from '@/types/form'
import type { FormExpose } from '@/components/Form'
import {
  getUserProfile,
  updateUserProfile,
  UserProfileUpdateReqVO
} from '@/api/system/user/profile'
import { useUserStore } from '@/store/modules/user'

defineOptions({ name: 'BasicInfo' })

const { t } = useI18n()
const message = useMessage() // 消息弹窗
const userStore = useUserStore()

// 定义事件
const emit = defineEmits<{
  (e: 'success'): void
}>()

// 表单校验
const rules = reactive<FormRules>({
  nickname: [{ required: true, message: t('profile.rules.nickname'), trigger: 'blur' }],
  email: [
    { required: true, message: t('profile.rules.mail'), trigger: 'blur' },
    {
      type: 'email',
      message: t('profile.rules.truemail'),
      trigger: ['blur', 'change']
    }
  ],
  mobile: [
    { required: true, message: t('profile.rules.phone'), trigger: 'blur' },
    {
      pattern: /^1[3-9]\d{9}$/,
      message: t('profile.rules.truephone'),
      trigger: 'blur'
    }
  ]
})
const schema = reactive<FormSchema[]>([
  {
    field: 'nickname',
    label: t('profile.user.nickname'),
    component: 'Input'
  },
  {
    field: 'mobile',
    label: t('profile.user.mobile'),
    component: 'Input'
  },
  {
    field: 'email',
    label: t('profile.user.email'),
    component: 'Input'
  },
  {
    field: 'sex',
    label: t('profile.user.sex'),
    component: 'InputNumber',
    value: 0
  },
  {
    field: 'identityType',
    label: '身份类别',
    component: 'Select',
    componentProps: {
      options: [
        { label: '硕士', value: 1 },
        { label: '博士', value: 2 },
        { label: '博士后', value: 3 },
        { label: '科研助理', value: 4 },
        { label: '教师', value: 5 }
      ]
    }
  },
  {
    field: 'researchDirection',
    label: '研究方向',
    component: 'Select',
    componentProps: {
      options: [
        { label: '中药新药开发与转化平台', value: 1 },
        { label: '中药药效物质及合成生物学创制平台', value: 2 },
        { label: '中医药人工智能平台', value: 3 },
        { label: '生物信息学与GPCR多组学研究平台', value: 4 },
        { label: '药物化学与递送系统开发平台', value: 5 },
        { label: '中药活性成分筛选与分子育种平台', value: 6 },
        { label: '中药受体药理学与靶标发现平台', value: 7 }
      ]
    }
  },
  {
    field: 'supervisor',
    label: '导师',
    component: 'Input',
    componentProps: { maxlength: 50, placeholder: '硕士/博士/博士后必填' }
  },
  {
    field: 'instructor',
    label: '指导教师',
    component: 'Input',
    componentProps: { maxlength: 50 }
  },
  {
    field: 'startYmd',
    label: '开始年月',
    component: 'DatePicker',
    componentProps: { type: 'month', valueFormat: 'YYYY-MM', placeholder: '选择开始年月' }
  },
  {
    field: 'endYmd',
    label: '结束年月',
    component: 'DatePicker',
    componentProps: { type: 'month', valueFormat: 'YYYY-MM', placeholder: '选择结束年月' }
  }
])
const formRef = ref<FormExpose>() // 表单 Ref

// 监听 userStore 中头像的变化，同步更新表单数据
watch(
  () => userStore.getUser.avatar,
  (newAvatar) => {
    if (newAvatar && formRef.value) {
      // 直接更新表单模型中的头像字段
      const formModel = formRef.value.formModel
      if (formModel) {
        formModel.avatar = newAvatar
      }
    }
  }
)

const submit = () => {
  const elForm = unref(formRef)?.getElFormRef()
  if (!elForm) return
  elForm.validate(async (valid) => {
    if (valid) {
      const data = unref(formRef)?.formModel as UserProfileUpdateReqVO
      await updateUserProfile(data)
      message.success(t('common.updateSuccess'))
      const profile = await init()
      await userStore.setUserNicknameAction(profile.nickname)
      // 发送成功事件
      emit('success')
    }
  })
}

const init = async () => {
  const res = await getUserProfile()
  unref(formRef)?.setValues(res)
  return res
}

onMounted(async () => {
  await init()
})
</script>
