Speedster
=========
Faster iOS animation.\
An iOS extention(Tweak) that increases iOS animation speed.\
Support iOS and iPadOS from 13 to 16 (newer might still be supported)

> **Note / 说明**：This fork is tested on **iPhone 15 Pro with iOS 17.0 (relaxin, roothide-based jailbreak)**. For testing purposes only.\
> 本分支基于 **iPhone 15 Pro / iOS 17.0（relaxin 越狱，roothide 系）** 测试，仅供测试使用。

Function
========
- Speed up app open and close animation.
- Speed up in-app animation.
- Speed up folder open and close animation.
- Add bounce to app open, close and switcher animation.
- Adjust how fast the screen turn on and off.
- Disable icons fly in when unlock.
- Disable icons jitter when editing.
- Disable folder open and close animation
- Disable icons and wallpaper zoom out when enter switcher.

本分支修改记录（基于上游 Hoangdus/Speedster 2.1.3）
========
测试环境：iPhone 15 Pro / iOS 17.0 / relaxin（roothide 系）越狱。

**v2.1.3-Fluid（当前版本）**
- 音量 HUD 修复：系统音量 HUD 与 App 开关动画共用 `SBFFluidBehaviorSettings`，被本插件加速后消失过快。现改为：音量事件发生时临时恢复原生流体参数，且 SpringBoard 启动后约 3.6 秒保护期内不修改流体参数（覆盖 iOS 17 开机时 PrototypeTools 对参数的冻结读取，保护期长度为实测物理下限）
- 设置面板简体中文汉化（跟随系统语言，en/vi 原样保留）
- 剥离全部调试代码（v2.1.4-x 诊断线的日志与探针钩子）

**构建系统**
- CI 改用 GitHub Actions macOS runner（Xcode 工具链）：Linux 工具链（LLVM 10）产出的 arm64e ABI 过旧，导致 SpringBoard 在 dyld 初始化阶段崩溃进安全模式
- 主插件与设置面板均构建为 arm64+arm64e FAT 双架构：iOS 17 arm64e 的设置进程拒绝加载单 arm64 架构的 bundle
- roothide scheme 打包，产物名 `Speedster-roothide-deb`

**设置面板修复**
- Respring 按钮无响应修复：roothide 的 jbroot 路径随机化，原先按 `/usr/lib` 锚点定位 sbreload 必然失败；现以 `/Library/PreferenceBundles` 动态锚定 jbroot，另加 killall SpringBoard 兜底
- LINKS 区块（作者 Twitter / 源码 / 捐助）从页面顶部移至最底部

**动画 / CPU 修复**
- `SwitcherDismiss` 初值 -1（原为 0）：0 值导致 iOS 17 多任务切换动画每帧重算、CPU 占用异常飙升
- App 速度滑条设 0.1 下限：防止 120Hz ProMotion 屏幕上弹簧动画无限振荡

Building
========
You need to have [Theos](https://theos.dev/) installed and configured

Build for rootful
```
make package
```

Build for rootless
```
make package THEOS_PACKAGE_SCHEME=rootless
```

License 
=======
Speedster is licensed under [GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html)
