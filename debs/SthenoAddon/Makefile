export SYSROOT = $(THEOS)/sdks/iPhoneOS16.5.sdk
export TARGET = iphone:clang:16.5:16.0
export ARCHS = arm64 arm64e

# 架构打包方案由 CI 决定:
#   rootless  (默认): iphoneos-arm64
#   roothide  (THEOS_PACKAGE_SCHEME=roothide): iphoneos-arm64e
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SthenoAddon
SthenoAddon_FILES = SthenoAddon.m
SthenoAddon_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
SthenoAddon_FRAMEWORKS = UIKit Foundation
SthenoAddon_LIBRARIES = substrate

# ---- 设置面板 (真 PSListController 子类 + Root.plist specifier) ----
SthenoPreference_BUNDLE = prefs/SthenoPreference.bundle
SthenoPreference_BUNDLE_FILES = prefs/SthenoPreferenceListController.m
SthenoPreference_BUNDLE_INSTALL_PATH = /Library/PreferenceBundles
SthenoPreference_BUNDLE_CFLAGS = -fobjc-arc
# Preferences.framework 无链接 stub, 运行时由 Settings 进程解析 (约定方案)
SthenoPreference_BUNDLE_LDFLAGS = -Wl,-undefined,dynamic_lookup
SthenoPreference_BUNDLE_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk