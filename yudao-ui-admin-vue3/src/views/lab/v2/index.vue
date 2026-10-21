<script setup lang="ts">
defineOptions({ name: 'PlasmidV2' })
</script>

<template>
  <ContentWrap title="质粒管理 V2">
    <el-alert
      type="info"
      :closable="false"
      title="质粒管理 V2 入口"
      description="V2 前端基础框架已接入（菜单 / 动态路由 / 权限）。各业务模块页面由后续子任务（C-05-02 ~ C-05-07）逐步实现。V1 质粒管理页面继续保留，不受影响。"
    />
  </ContentWrap>
</template>
