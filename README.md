# SuperMesh Mobile

e-bi SuperMesh 移动端 Monorepo，包含两个 App 和共享业务包。

## Apps

| App | 说明 | 目标用户 |
|:----|:-----|:---------|
| **MeshWork** | 员工端 — 移动办公与现场作业 | e-bi 内部员工 |
| **MeshPortal** | 客户端 — 进度透明与信息查询 | e-bi 全球客户 |

## Packages

| Package | 说明 |
|:--------|:-----|
| `ebi_core` | 网络请求 (Dio)、鉴权、工具类 |
| `ebi_ui_kit` | UI 组件库、品牌主题 |
| `ebi_models` | 共享数据模型 |
| `ebi_chat` | IM 聊天模块 |

## Getting Started

```bash
# 安装 Melos
dart pub global activate melos

# 初始化所有包
melos bootstrap

# 运行分析
melos analyze

# 运行测试
melos test

# 运行 MeshWork
cd apps/MeshWork && flutter run

# 运行 MeshPortal
cd apps/MeshPortal && flutter run
```
