export SYSROOT = $(THEOS)/sdks/iPhoneOS16.5.sdk
export TARGET = iphone:clang:16.5:16.0
export ARCHS = arm64 arm64e

# 架构打包方案由 CI 决定:
#   rootless  (默认): iphoneos-arm64
#   roothide  (THEOS_PACKAGE_SCHEME=roothide): iphoneos-arm64e
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SthenoAddon
SthenoAddon_FILES = SthenoAddon.m
SthenoAddon_CFLAGS = -fobjc-arc
SthenoAddon_FRAMEWORKS = UIKit Foundation
SthenoAddon_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk