# arm64 only: the Linux CI toolchain emits an outdated arm64e ABI whose PAC
# signatures crash arm64e processes (SpringBoard) at load time. arm64e
# devices run the arm64 slice fine, so keep the package arch roothide wants.
ARCHS = arm64
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
