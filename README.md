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
