# UI-DOC-LINK-01 隐藏管理页面项目文档链接 — 交付报告

**任务**：全局隐藏管理页面中的项目说明/开发文档/帮助文档链接
**执行日期**：2026-10-12
**结论**：**PASS**（真实浏览器验证通过，业务功能零影响）

---

## 1. 文档链接的实际来源

| 类别 | 来源 | 说明 |
|---|---|---|
| A. 全局公共页面入口 | [DocAlert/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/components/DocAlert/index.vue) | 公共组件 `doc-alert`，被 **100 个页面文件**使用（system/wms/erp/crm/oa/mp/pms/infra/ai 等模块），渲染绿色告警条「【XX】文档地址：https://doc.iocoder.cn/...」。组件内置官方开关：`VITE_APP_DOCALERT_ENABLE !== 'false'` 才渲染。角色管理页的「功能权限」「数据权限」文档入口即此组件（[role/index.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/views/system/role/index.vue) 第 2-3 行）。 |
| B. 布局层入口 | [UserInfo.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/layout/components/UserInfo/src/UserInfo.vue) | 右上角用户头像下拉菜单中的「文档」项，点击打开 doc.iocoder.cn。 |
| C. 业务功能（非文档，已区分保留） | 角色管理操作列「菜单权限/数据权限/删除」等 | 真实业务按钮，与 doc-alert 无关，未触碰。 |

**统一开关存在**，故采用「关闭全局开关」方案，不逐页修改 100 个文件。

## 2. 修改文件及修改点（仅 2 个文件，前端）

| 文件 | 修改点 |
|---|---|
| [.env](file:///E:/lixin/dev/yudao-ui-admin-vue3/.env) 第 17 行 | `VITE_APP_DOCALERT_ENABLE=true` → `false`（其余 env 文件均无该变量覆盖，一处生效于所有模式） |
| [UserInfo.vue](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/layout/components/UserInfo/src/UserInfo.vue) | 移除头像下拉中「文档」ElDropdownItem 及其 `toDocument` 函数；「个人中心/锁定屏幕/退出系统」保留 |

未修改：后端 Java、数据库、SQL、菜单数据、角色权限、任何接口、任何业务页面（含角色管理业务功能、质粒 V1/V2）。100 个页面中的 `doc-alert` 标签原样保留，由组件内开关统一不渲染。

## 3. 隐藏范围

**全局**：所有使用 doc-alert 的页面（100 个文件覆盖的全部管理模块）+ 全局头像下拉「文档」入口。

## 4. 验证结果

| 项 | 结果 |
|---|---|
| ESLint（改动文件） | **PASS**（无告警） |
| TypeScript `ts:check` | 15 个错误**全部为存量问题**：分布于 6 个未触碰文件（fms/hrm/lab 模块，最后修改 10/2–10/7），本次 2 个改动文件零错误 |
| 生产构建 `build:local` | **PASS**（exit 0） |
| 角色管理页（浏览器实测） | **PASS**：顶部「功能权限」「数据权限」绿色文档条已消失；操作列「编辑/菜单权限/数据权限/删除」业务按钮全部保留 |
| 用户管理页（浏览器实测） | **PASS**：三条文档条消失；搜索/表格/新增/导入/导出/批量删除/回收站工具栏正常 |
| 菜单管理页（浏览器实测） | **PASS**：文档条消失；搜索表单、新增、展开/折叠、刷新菜单缓存、菜单树正常 |
| 头像下拉（浏览器实测） | **PASS**：仅剩「个人中心/锁定屏幕/退出系统」，无「文档」 |

验证环境：vite dev server（:80，已重启使 env 生效，新进程后台运行）+ 后端 PID 33812（:48080，未动）。

## 5. 仍未隐藏的文档相关残留（刻意保留）

1. [service.ts](file:///E:/lixin/dev/yudao-ui-admin-vue3/src/config/axios/service.ts) 第 210 行：接口返回 901（演示模式）时的错误提示中含"参考 doc.iocoder.cn 教程"——属错误诊断信息，非页面文档入口，保留。
2. 源码注释中的 gitee/github issue 链接：界面上不可见，保留。
3. i18n 词条 `common.document` 变为未使用：无界面影响，保留以便回滚。

## 6. 回滚方法

1. `.env`：`VITE_APP_DOCALERT_ENABLE=false` 改回 `true`，重启 dev server（或重新构建）即恢复全部页面文档条；
2. UserInfo.vue：`git checkout -- src/layout/components/UserInfo/src/UserInfo.vue` 恢复「文档」菜单项。

## 7. 边界确认

仅改动上述 2 个前端文件；未实施任何其他需求；后端、SQL、菜单、权限、质粒 V1/V2 零改动。
