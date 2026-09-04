<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="res/icon_transparent.svg" />
    <img src="res/icon_transparent_light.svg" alt="CSG_Blockout Logo" width="180" />
  </picture>
  <h1>CSG_Blockout</h1>

  <p>
    <a href="README.md"><img src="https://img.shields.io/badge/Docs-English-blue?style=flat-square" alt="Docs English" /></a>
    <a href="README_CN.md"><img src="https://img.shields.io/badge/%E6%96%87%E6%A1%A3-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-blue?style=flat-square" alt="文档 简体中文" /></a>
    <a href="TUTORIAL_CN.md"><img src="https://img.shields.io/badge/%E6%95%99%E7%A8%8B-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-orange?style=flat-square" alt="教程 简体中文" /></a>
    <a href="ARCHITECTURE_CN.md"><img src="https://img.shields.io/badge/%E6%9E%B6%E6%9E%84-%E6%8A%80%E6%9C%AF%E5%86%85%E5%B9%95-purple?style=flat-square" alt="架构 技术内幕" /></a>
  </p>

  <p>
    <a href="https://godotengine.org"><img src="https://img.shields.io/badge/Godot-4.7%2B-478cbf?style=flat-square&logo=godotengine&logoColor=white" alt="Godot 引擎" /></a>
    <a href="https://store.godotengine.org/asset/qwqzhanqwq/csg-blockout/"><img src="https://img.shields.io/badge/AssetLib-CSG__Blockout-blueviolet?style=flat-square" alt="Godot AssetLib" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-success?style=flat-square" alt="开源协议: MIT" /></a>
  </p>

  <p>
    <strong>专为 Godot 4.7 打造的高性能、现代化的 3D 关卡白盒（Blockout）与快速原型设计插件。</strong>
  </p>
</div>

---

## 安装指南

### 途径 1：Godot AssetLib 官方资产库（推荐）
1. 在 Godot 4.7 编辑器顶部点击 **AssetLib (资产库)** 选项卡。
2. 搜索 `CSG Blockout`，点击下载并安装到项目中。
3. 也可通过网页版资产库直达：[Godot AssetLib - CSG_Blockout](https://store.godotengine.org/asset/qwqzhanqwq/csg-blockout/)。

### 途径 2：GitHub Releases 发布包
1. 前往项目的 [Releases 页面](https://github.com/qwqzhanqwq/Godot-CSG-Blockout/releases) 下载最新的 `.zip` 归档文件。
2. 解压后将 `addons/csg_blockout` 文件夹复制到你的 Godot 项目根目录下的 `addons/` 目录中。

### 途径 3：Git 源码克隆
在你的 Godot 项目根目录下执行以下命令：
```bash
git clone https://github.com/qwqzhanqwq/Godot-CSG-Blockout.git addons/csg_blockout
```

### 启用插件
打开 Godot 编辑器，依次点击 **项目 (Project) -> 项目设置 (Project Settings) -> 插件 (Plugins)**，找到 **CSG_Blockout** 并勾选 **启用 (Enable)**。

---

## 快速上手

1. **呼出 3D 轮盘**：在 3D 视口中按下快捷键 `Shift + A`，在光标所在位置唤出矢量轮盘菜单（Pie Menu），顺着手势快速创建基础 CSG 形状或切换布尔操作（并集 / 交集 / 差集）。
2. **使用视口侧边栏**：视口左侧边栏提供立方体、球体、圆柱体等一键创建按钮；选中 `CSGCombiner3D` 时自动挂载为子节点，选中独立形状时自动作为同级兄弟节点插入。
3. **程序化世界对齐网格**：侧边栏内置灰白网格、深灰网格、橙色高亮网格等材质通道，支持多选节点后一键批量赋予，物体随意缩放旋转均不拉伸纹理。
4. **一键烘焙与导出**：选中 `CSGRepeater3D` 或 `CSGSpreader3D` 时，顶部工具栏会出现专属按钮，点击 **烘焙 (Bake)** 即可将其固化为常规场景节点。

> 完整图文搭建教程与性能优化最佳实践，请查阅 [快速上手与高级工作流教程 (TUTORIAL_CN.md)](TUTORIAL_CN.md)。

---

## 核心功能特性

- **矢量 3D 轮盘菜单 (3D Pie Menu)**：在 3D 视口通过 `Shift + A` 顺发呼出，多层级布尔运算与几何形状无缝联动，支持中心死区回退与全流程 Undo/Redo。
- **智能工作流侧边栏**：集成 6 种标准 CSG 几何体快捷创建、3 种布尔操作即时切换，无 CSG 节点选中时自动隐藏，保持视口清爽。
- **程序化三平面世界网格 Shader**：摒弃传统 UV 依赖，基于世界空间坐标投影，严格保持真实世界比例尺寸（1m x 1m），内置抗锯齿算法。
- **开箱即用材质预设与批量赋予**：预置浅色、深色、重点强调等度量材质，支持视口中框选多个 CSG 节点一键应用。
- **参数化阵列生成器 (CSGRepeater3D)**：采用策略模式设计，支持网格阵列、环形阵列、螺旋阵列与 3D 噪声体域采样，支持旋转与缩放随机化。
- **物理体积防重叠散布系统 (CSGSpreader3D)**：支持以任意 Godot `Shape3D` 为空间边界进行无重叠填充，采用 $O(1)$ 空间哈希网格算法，彻底避免编辑态卡死。
- **工程级强类型与双语支持**：全线基于 GDScript 2.0 静态强类型开发，无缝对接 `EditorUndoRedoManager`，内置中英文 (i18n) 界面无缝切换。

---

## 与 CSG Toolkit 的关系与全面演进

本项目灵感源自 **LuckyTepot** 开发的优秀开源插件 [CSG Toolkit](https://godotengine.org/asset-library/asset/3057)。原版插件验证了在 Godot 视口内集成快速 CSG 工具栏的卓越体验。

为了满足现代化高精度关卡设计与 Godot 4.7 架构标准，本项目由 [qwqzhanqwq](https://github.com/qwqzhanqwq) 对其进行了**彻底推倒式的架构重写与全方位扩展**：

| 维度 | 原版 CSG Toolkit | CSG_Blockout (本项目) |
| :--- | :--- | :--- |
| **引擎架构** | 面向早期 Godot 4.x，弱类型脚本 | **深度适配 Godot 4.7+**，全线 GDScript 2.0 强类型标注与 ClassDB 校验 |
| **核心交互** | 仅依赖视口固定侧边栏 | **3D 视口矢量轮盘 (Shift+A Pie Menu) + 智能侧边栏** 双工作流 |
| **程序化生成** | 仅支持基础静态图元放置 | **参数化阵列 (Repeater) + 碰撞体体积散布 (Spreader)** |
| **散布避障算法** | 无避障或朴素 $O(N^2)$ 遍历循环 | **自研 3D 空间哈希网格算法 ($O(1)$ 复杂度)**，数百实例实时生成不卡顿 |
| **材质系统** | 依赖基础内置着色器 | **程序化世界对齐三平面网格 Shader** + 5 组预设 + 一键批量赋予 |
| **工程健壮性** | 基础编辑态支持 | **全流程原子级 EditorUndoRedoManager 接入**，严格的编辑器/运行时环境隔离 |
| **国际化** | 仅支持单语言 | **原生双语支持**（简体中文 / English），自动跟随编辑器语言偏好 |

---

## 文档导航

- [快速上手与高级工作流教程 (TUTORIAL_CN.md)](TUTORIAL_CN.md)：手把手教学、动图演示与关键的白盒烘焙性能优化方案。
- [架构设计与技术内幕 (ARCHITECTURE_CN.md)](ARCHITECTURE_CN.md)：3D 空间哈希数学推导、策略模式架构解析与全量 API 字典。
- [开发路线图 (ROADMAP_CN.md)](ROADMAP_CN.md)：项目未来规划与功能排期。

---

## 致谢与开源协议

- **原始概念与界面原型灵感**：[LuckyTepot](https://github.com/LuckyTepot) (CSG Toolkit, Copyright (c) 2023).
- **架构重构、3D 轮盘、空间哈希优化、阵列/散布系统与 GDScript 2.0 重写**：[qwqzhanqwq](https://github.com/qwqzhanqwq) (Copyright (c) 2026).

本项目基于 [MIT License](LICENSE) 开源发布。
