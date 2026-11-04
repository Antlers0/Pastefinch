# Pastefinch

macOS 菜单栏小工具：剪贴板历史 + 截图历史，一只会叼东西的小鸟 🐦

仓库：[github.com/Antlers0/Pastefinch](https://github.com/Antlers0/Pastefinch)

名字来自 **Paste** + **Finch**（雀鸟），好记、好叫，也尽量避开市面上常见剪贴板产品名。

## 功能

- 菜单栏图标打开面板；快捷键 `⌥⌘V` 呼出/收起
- **剪贴板**：记录文本 / 普通图片 / 文件；点击重新复制；上限 200 条自动清理
- **截图**：系统存盘截图 + 复制到剪贴板的截图；上限 100 条
- 点击面板外自动关闭；单条可删除
- 本地存储：`~/Library/Application Support/Pastefinch/`（明文，请勿当密码管理器用）
- 清空/删除截图记录**不会**删除桌面上的系统截图原文件

## 环境要求

- macOS 13+
- Xcode 15+（开发 / 打包）

## 用 Xcode 运行

1. 打开 `ClipShotHistory.xcodeproj`（工程目录名暂未改，产物名为 Pastefinch）
2. 选择 scheme **ClipShotHistory**、目标 **My Mac**
3. 按 `⌘R` 运行
4. 菜单栏会出现小鸟图标；右键可退出

## 命令行构建

```bash
cd ~/Desktop/ClipShotHistory
xcodebuild -project ClipShotHistory.xcodeproj \
  -scheme ClipShotHistory \
  -configuration Release \
  -derivedDataPath ./DerivedData \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO \
  build
```

产物：

`DerivedData/Build/Products/Release/Pastefinch.app`

## 打成 zip

```bash
APP="DerivedData/Build/Products/Release/Pastefinch.app"
ditto -c -k --keepParent "$APP" ./Pastefinch.zip
```

## GitHub Releases 直发

1. 打好 `Pastefinch.zip`
2. 打开 [Releases](https://github.com/Antlers0/Pastefinch/releases) → Draft a new release
3. Tag 例如 `v1.0.0`，上传 zip 附件

未签名时对方需：**右键 App → 打开**。正式分发建议再做 Developer ID 签名与公证。
