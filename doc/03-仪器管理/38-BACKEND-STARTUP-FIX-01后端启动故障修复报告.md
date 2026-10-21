# 38-BACKEND-STARTUP-FIX-01 后端启动故障修复报告

> 任务：TASK BACKEND-STARTUP-FIX-01
> 日期：2026-10-19
> 最终判定：**PASS / LOCAL-STARTUP-READY**

---

## 1. 根因

### 1.1 错误现象

IDEA 启动 `YudaoServerApplication`（profile=local，端口 48080）时抛出：

```text
TenantServiceImpl.java:118
java.lang.Error: Unresolved compilation problems:
Cannot invoke setContactUserId(Long) on the primitive type void
Cannot invoke setCode(String) on the primitive type void
```

### 1.2 根因分析

报错涉及两处链式 setter 调用：

- [TenantServiceImpl.java:118](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/tenant/TenantServiceImpl.java#L118)：
  ```java
  tenantMapper.updateById(new TenantDO().setId(tenant.getId()).setContactUserId(userId));
  ```
- [TenantServiceImpl.java:134](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/tenant/TenantServiceImpl.java#L134)：
  ```java
  reqVO.setName(RoleCodeEnum.TENANT_ADMIN.getName()).setCode(RoleCodeEnum.TENANT_ADMIN.getCode())
          .setSort(0).setRemark("系统自动生成");
  ```

源码本身正确，依赖 Lombok 链式访问器（setter 返回 `this`）。项目根目录存在 [lombok.config](file:///E:/lixin/dev/ruoyi-vue-pro/lombok.config)：

```properties
config.stopBubbling = true
lombok.accessors.chain=true
```

**根因**：IDEA 当前使用 **Eclipse Compiler for Java (ECJ/JDT)** 作为编译器（IDE 级默认设置），ECJ 在处理 Lombok 注解时**未正确读取 `lombok.config` 的 `lombok.accessors.chain=true`**，导致 `TenantDO` / `RoleSaveReqVO` 的 setter 被生成为 `void` 返回类型。ECJ 即使遇到编译错误也会生成带错误桩的 `.class` 文件，运行时加载即抛出 `Unresolved compilation problems`。

这些带 `void` setter 的错误桩 `.class` 覆盖了 Maven 正确编译的产物，导致从 IDEA 启动必然失败。

### 1.3 证据链

| 检查项 | 结果 |
|---|---|
| 根目录 `lombok.config` 是否含 `chain=true` | ✅ 存在 |
| Maven `clean compile` 产物 `TenantDO.setId` 返回类型 | `TenantDO`（链式正确） |
| Maven 产物 `TenantServiceImpl` 字节码 `setId` 调用 | `...TenantDO.setId:(J)L.../TenantDO;`（链式） |
| IDEA `compiler.xml` 是否指定编译器 | ❌ 未指定（回退 IDE 默认 ECJ） |
| 错误消息特征 | `Unresolved compilation problems` = ECJ 错误桩典型特征 |

---

## 2. 源码位置

- 报错代码：[TenantServiceImpl.java:118](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/tenant/TenantServiceImpl.java#L118)、[:134](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/service/tenant/TenantServiceImpl.java#L134)
- 关联 DO：[TenantDO.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/dal/dataobject/tenant/TenantDO.java)（`@Data`，依赖全局 `lombok.accessors.chain=true`）
- 关联 VO：[RoleSaveReqVO.java](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/src/main/java/cn/iocoder/yudao/module/system/controller/admin/permission/vo/role/RoleSaveReqVO.java)（`@Data`）
- Lombok 配置：[lombok.config](file:///E:/lixin/dev/ruoyi-vue-pro/lombok.config)

---

## 3. 是否存在 ECJ/JDT 污染

**是。** IDEA 的 ECJ 增量编译在 `target/classes` 中生成了 `void` setter 的错误桩 `.class`，覆盖了 Maven 产物。

**清理方式**：执行 `mvn clean compile` 删除全部 `target/` 并用 Maven（javac + Lombok）重新编译，产物 setter 返回类型恢复为链式。

---

## 4. 修改文件

| 文件 | 修改内容 | 性质 |
|---|---|---|
| [.idea/compiler.xml](file:///E:/lixin/dev/ruoyi-vue-pro/.idea/compiler.xml) | 在 `CompilerConfiguration` 下新增 `<option name="DEFAULT_COMPILER" value="Javac" />`，强制项目级使用 javac 而非 ECJ | IDE 配置 |

**未修改任何 Java 源码、字段类型、数据库结构或 Lombok 全局配置。**

### 修改后 compiler.xml 关键片段

```xml
<component name="CompilerConfiguration">
  <option name="DEFAULT_COMPILER" value="Javac" />
  <annotationProcessing>
    ...
  </annotationProcessing>
</component>
```

---

## 5. Maven 编译结果

```text
mvn clean compile -pl yudao-server -am -DskipTests
[INFO] BUILD SUCCESS
```

`javap` 验证 [TenantServiceImpl.class](file:///E:/lixin/dev/ruoyi-vue-pro/yudao-module-system/target/classes/cn/iocoder/yudao/module/system/service/tenant/TenantServiceImpl.class)：

```
invokevirtual #458  // TenantDO.setId:(Ljava/lang/Long;)Lcn/iocoder/.../TenantDO;
invokevirtual #461  // TenantDO.setContactUserId:(Ljava/lang/Long;)Lcn/iocoder/.../TenantDO;
invokevirtual #191  // RoleSaveReqVO.setCode:(Ljava/lang/String;)L.../RoleSaveReqVO;
```

setter 均返回自身类型，链式调用编译正确。

---

## 6. Maven 测试结果

### 6.1 yudao-module-lab（业务模块）

```text
mvn install -pl yudao-module-lab -am -DskipTests -o   → BUILD SUCCESS
mvn test -pl yudao-module-lab -o
Tests run: 195, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

195/195 全绿。

### 6.2 框架模块预存问题（非本次修复引入）

`mvn clean test -pl yudao-module-lab -am -o` 在依赖模块 `yudao-spring-boot-starter-protection` 的 `ApiSignatureTest.testSignatureGet` 报错：

```text
org.mockito.exceptions.base.MockitoException:
Mockito cannot mock this class: class ...ApiSignatureRedisDAO.
Java: 21
Underlying exception: Could not modify all classes [...]
```

**性质**：Mockito inline mock maker 与 Java 21 的兼容性问题，属于预存环境缺陷，与 TenantServiceImpl 编译修复无关。该测试不涉及 `yudao-module-lab` 业务代码。已通过先 `install -DskipTests` 再 `test -pl yudao-module-lab` 的方式隔离验证，lab 模块 195/195 通过。

---

## 7. IDEA 启动结果

通过 `mvn spring-boot:run -pl yudao-server -Dspring-boot.run.profiles=local` 验证（使用 Maven 编译产物，等价于 javac 编译结果）：

```text
Starting YudaoServerApplication using Java 21.0.12.1
The following 1 profile is active: "local"
Tomcat initialized with port(s): 48080 (http)
dynamic-datasource initial loaded [2] datasource, primary datasource named [master]
Started YudaoServerApplication in 10.456 seconds
项目启动成功！
```

- ✅ Spring Boot 完整启动
- ✅ 无 `BeanCreationException`
- ✅ 无 `Unresolved compilation problems`
- ✅ 后端进程持续运行

### IDEA 侧使用说明

由于修改了 `.idea/compiler.xml`，负责人在 IDEA 中需执行以下任一操作使编译器切换生效：

1. **推荐**：File → Invalidate Caches → 勾选 "Clear file system cache and Local History" → Invalidate and Restart；
2. 或：Settings → Build, Execution, Deployment → Compiler → Java Compiler → 确认 "Use compiler" 为 `Javac`（非 Eclipse），然后 Build → Rebuild Project。

此后从 IDEA 直接运行 `YudaoServerApplication` 即可正常启动。

---

## 8. 48080 监听结果

```text
Test-NetConnection 127.0.0.1:48080 → TcpTestSucceeded = True
```

Tomcat 正常监听 48080，后端当前运行中（PID 由 mvn spring-boot:run 管理）。

---

## 9. 数据库和 Redis 零写入说明

本任务全程：

- ❌ 未执行任何 DDL / DML；
- ❌ 未修改正式 `labplatform` 数据库；
- ❌ 未执行菜单 SQL；
- ❌ 未修改正式 Redis 数据；
- ❌ 未开启 C7；
- ❌ 未删除业务数据。

仅对 `target/` 构建产物和 `.idea/compiler.xml` 进行了修改。后端启动后正常连接 `127.0.0.1:3306/labplatform`（只读启动，无写入操作）。

---

## 10. 是否可以开始负责人手工测试

**可以。** 后端已在 local profile 下正常运行，监听 48080，所有业务模块加载成功。负责人可开始手工测试。

> 提示：当前后端由 `mvn spring-boot:run` 进程承载。若负责人希望从 IDEA 启动，请先按第 7 节说明刷新 IDEA 编译器配置。

---

## 最终判定

**PASS / LOCAL-STARTUP-READY**
