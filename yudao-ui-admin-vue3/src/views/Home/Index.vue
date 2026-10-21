<template>
  <div>
    <!-- 欢迎卡片：保留原有页面框架，仅展示真实用户与当前日期 -->
    <el-card shadow="never">
      <div class="flex items-center">
        <el-avatar :src="avatar" :size="70" class="mr-16px">
          <img src="@/assets/imgs/avatar.gif" alt="" />
        </el-avatar>
        <div>
          <div class="text-20px">
            {{ t('workplace.welcome') }} {{ username }}，{{ t('workplace.happyDay') }}
          </div>
          <div class="mt-10px text-14px text-gray-500">{{ today }}</div>
        </div>
      </div>
    </el-card>

    <!-- 本草基因组学实验室工作台：仅展示真实存在的业务功能入口 -->
    <el-card shadow="never" class="mt-8px">
      <template #header>
        <div class="h-3 flex items-center">
          <span>本草基因组学实验室工作台</span>
        </div>
      </template>
      <el-row :gutter="16">
        <el-col
          v-for="item in filteredWorkbench"
          :key="item.url"
          :xl="8"
          :lg="8"
          :md="8"
          :sm="12"
          :xs="24"
          class="mb-16px"
        >
          <el-card shadow="hover" class="cursor-pointer" @click="handleShortcutClick(item.url)">
            <div class="flex items-center">
              <Icon
                :icon="item.icon"
                :size="28"
                class="mr-12px flex-none"
                :style="{ color: item.color }"
              />
              <span class="text-16px">{{ item.name }}</span>
            </div>
          </el-card>
        </el-col>
        <el-col v-if="filteredWorkbench.length === 0" :xs="24">
          <div class="py-20px text-center text-gray-500">
            暂无工作台功能入口权限，请联系管理员分配。
          </div>
        </el-col>
      </el-row>
    </el-card>

    <!-- 本草吉祥物：十款角色彩色卡通正面（独立裁切图，非九宫格整图） -->
    <el-card shadow="never" class="mt-8px">
      <template #header>
        <div class="h-3 flex items-center">
          <span>本草吉祥物</span>
        </div>
      </template>
      <div class="grid grid-cols-2 gap-12px sm:grid-cols-3 lg:grid-cols-5">
        <div v-for="item in mascots" :key="item.name" class="flex flex-col items-center">
          <img :src="item.img" class="h-200px w-auto object-contain" :alt="item.name" />
          <span class="mt-8px text-14px">{{ item.name }}</span>
        </div>
      </div>
    </el-card>
  </div>
</template>
<script lang="ts" setup>
import { computed } from 'vue'
import { formatTime } from '@/utils'
import { useUserStore } from '@/store/modules/user'
import { usePermissionStore } from '@/store/modules/permission'
import { useRouter } from 'vue-router'
import chuanbeimu from '@/assets/brand/mascots/chuanbeimu.png'
import danshen from '@/assets/brand/mascots/danshen.png'
import hongdoushan from '@/assets/brand/mascots/hongdoushan.png'
import huanghuahao from '@/assets/brand/mascots/huanghuahao.png'
import huanglian from '@/assets/brand/mascots/huanglian.png'
import leigongteng from '@/assets/brand/mascots/leigongteng.png'
import lingzhi from '@/assets/brand/mascots/lingzhi.png'
import qianjinteng from '@/assets/brand/mascots/qianjinteng.png'
import renshen from '@/assets/brand/mascots/renshen.png'
import zisu from '@/assets/brand/mascots/zisu.png'

defineOptions({ name: 'Index' })

const { t } = useI18n()
const router = useRouter()
const userStore = useUserStore()
const permissionStore = usePermissionStore()
const avatar = userStore.getUser.avatar
const username = userStore.getUser.nickname
const today = formatTime(new Date(), 'yyyy-MM-dd')

/** 工作台入口：路由均为项目已存在的真实页面，无虚假统计数据 */
const workbench = [
  { name: '质粒档案', icon: 'ep:notebook', url: '/lab/plasmid-v2/plasmid', color: '#409EFF' },
  { name: '质粒类型', icon: 'ep:collection', url: '/lab/plasmid-v2/plasmid-type', color: '#67C23A' },
  { name: '质粒审核', icon: 'ep:finished', url: '/lab/plasmid-v2/plasmid-audit', color: '#E6A23C' },
  {
    name: '库存台账',
    icon: 'ep:box',
    url: '/lab/plasmid-v2/plasmid-inventory/plasmid-inventory',
    color: '#909399'
  },
  {
    name: '库存流水',
    icon: 'ep:list',
    url: '/lab/plasmid-v2/plasmid-inventory/plasmid-inventory-flow',
    color: '#9C27B0'
  },
  { name: '质粒借用', icon: 'ep:promotion', url: '/lab/plasmid-v2/plasmid-borrow', color: '#F56C6C' },
  { name: '质粒归还', icon: 'ep:back', url: '/lab/plasmid-v2/plasmid-return', color: '#00BCD4' },
  { name: '违规记录', icon: 'ep:warning', url: '/lab/plasmid-v2/plasmid-violation', color: '#FF5722' },
  { name: '借用黑名单', icon: 'ep:lock', url: '/lab/plasmid-v2/plasmid-blacklist', color: '#607D8B' },
  { name: '我的使用资质', icon: 'ep:stamp', url: '/lab/instrument/my-qualification', color: '#00BFA5' },
  { name: '我的信用', icon: 'ep:coin', url: '/lab/instrument/my-credit', color: '#FFB300' }
]

/**
 * 权限匹配的动态工作台：仅展示当前登录用户路由权限范围内的功能入口。
 * 依据：permissionStore.getRouters 为后端按角色菜单过滤后的动态路由，
 * 递归收集其完整 path，工作台 url 与其中 path 精确匹配才保留，确保无越权显示。
 * 采用 computed 包裹，权限变更（重新登录/重新拉取路由后）会自动同步。
 */
const collectPaths = (routes: any[], parentPath = '', acc: Set<string>) => {
  for (const r of routes) {
    let full = r.path || ''
    // 非外链且非绝对路径时，与父路径拼接（对齐 vue-router 嵌套路由解析规则）
    if (full && !full.startsWith('http') && !full.startsWith('/')) {
      full = `${parentPath}/${full}`.replace(/\/+/g, '/')
    }
    if (full) acc.add(full)
    if (r.children?.length) collectPaths(r.children, full, acc)
  }
}

const allowedPaths = computed(() => {
  const paths = new Set<string>()
  // getRouters = 静态路由 + 后端动态路由，均为权限过滤后的可见菜单
  collectPaths(permissionStore.getRouters, '', paths)
  return paths
})

const filteredWorkbench = computed(() => {
  return workbench.filter((item) => allowedPaths.value.has(item.url))
})

const handleShortcutClick = (url: string) => {
  router.push(url)
}

/** 十款本草吉祥物：每款为彩色卡通正面独立裁切图 */
const mascots = [
  { name: '川贝母娃', img: chuanbeimu },
  { name: '丹参娃', img: danshen },
  { name: '红豆杉娃', img: hongdoushan },
  { name: '黄花蒿娃', img: huanghuahao },
  { name: '黄连娃', img: huanglian },
  { name: '雷公藤娃', img: leigongteng },
  { name: '灵芝娃', img: lingzhi },
  { name: '千金藤娃', img: qianjinteng },
  { name: '人参娃', img: renshen },
  { name: '紫苏娃', img: zisu }
]
</script>
