<div align="center">

<img src="ClipShotHistory/Resources/PastefinchIcon.png" width="120" alt="Pastefinch">

# Pastefinch

**菜单栏里的剪贴板历史 + 截图历史。**

[English](README.md) · [中文](README.zh-CN.md)

<br>

[![macOS](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)](https://github.com/Antlers0/Pastefinch)
[![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)](https://github.com/Antlers0/Pastefinch)
[![Release](https://img.shields.io/github/v/release/Antlers0/Pastefinch?color=2ea44f)](https://github.com/Antlers0/Pastefinch/releases)
[![Downloads](https://img.shields.io/github/downloads/Antlers0/Pastefinch/total?color=0969da)](https://github.com/Antlers0/Pastefinch/releases)

<br>

[`下载`](https://github.com/Antlers0/Pastefinch/releases) · [`源码构建`](#从源码构建) · [`隐私`](#隐私说明)

</div>

---

## 为什么用 Pastefinch

系统剪贴板只记得最后一次复制。Pastefinch 在后台记住你复制过的内容，以及截过的图——按一下快捷键就能找回。

| | 能力 | 说明 |
| :---: | :--- | :--- |
| 📋 | 剪贴板 | 文本、图片、文件，可搜索 |
| 🖼️ | 截图 | 系统存盘截图 + 复制到剪贴板的截图 |
| ⌨️ | 快捷键 | `⌥⌘V` 呼出 / 收起面板 |
| 🧹 | 清理 | 单条删除、一键清空、按条数自动裁剪 |
| 🔒 | 隐私 | 仅本地存储，不同步云端 |

---

## 安装

1. 从 [Releases](https://github.com/Antlers0/Pastefinch/releases) 下载最新 **`Pastefinch.zip`**
2. 解压后将 **`Pastefinch.app`** 拖入「应用程序」
3. 打开后，在菜单栏找到小鸟图标即可使用

> **提示：** 若未签名构建被系统拦截，可在 Finder 中右键 App → **打开**。

---

## 从源码构建

```bash
xcodebuild \
  -project ClipShotHistory.xcodeproj \
  -scheme ClipShotHistory \
  -configuration Release \
  -derivedDataPath ./DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```text
DerivedData/Build/Products/Release/Pastefinch.app
```

```bash
ditto -c -k --keepParent \
  DerivedData/Build/Products/Release/Pastefinch.app \
  Pastefinch.zip
```

**环境要求：** macOS 13+ · Xcode 15+

---

## 隐私说明

历史记录保存在本机：

```text
~/Library/Application Support/Pastefinch/
```

无账号、无统计、无云同步。  
剪贴板内容以明文存储，请勿当作密码管理器。  
清空截图历史不会删除磁盘上的系统截图原文件。

---

## 许可证

Copyright © 2026 Pastefinch. All rights reserved.
