# Fat binary arm64 + arm64e. macOS CI's Xcode clang emits the correct arm64e
# ABI (the Linux toolchain did not, which crashed arm64e processes), and the
# upstream author ships the same fat layout.
ARCHS = arm64 arm64e
SDK_PATH = $(THEOS)/sdks/iPhoneOS13.7.sdk/
SYSROOT = $(SDK_PATH)
export THEOS_DEVICE_IP = localhost
export THEOS_DEVICE_PORT=2222

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Speedster

Speedster_FILES = Speedster.x
Speedster_FRAMEWORKS = UIKit
Speedster_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += speedsterprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "sbreload"
