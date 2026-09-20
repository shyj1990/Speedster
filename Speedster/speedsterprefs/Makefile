# arm64 only, see main Makefile: CI toolchain arm64e output crashes arm64e processes
ARCHS = arm64
SDK_PATH = $(THEOS)/sdks/iPhoneOS13.7.sdk/
SYSROOT = $(SDK_PATH)

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SpeedsterPrefs

SpeedsterPrefs_FILES = sdrRootListController.m SdrSwitchCell.m
SpeedsterPrefs_FRAMEWORKS = UIKit
SpeedsterPrefs_PRIVATE_FRAMEWORKS = Preferences
SpeedsterPrefs_INSTALL_PATH = /Library/PreferenceBundles
SpeedsterPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
