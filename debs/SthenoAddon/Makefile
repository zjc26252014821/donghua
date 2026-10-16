export SYSROOT = $(THEOS)/sdks/iPhoneOS16.5.sdk
export TARGET = iphone:clang:16.5:16.0
export ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SthenoAddon
SthenoAddon_FILES = SthenoAddon.m
SthenoAddon_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
SthenoAddon_FRAMEWORKS = UIKit Foundation
SthenoAddon_LIBRARIES = substrate

# Preference bundle: real PSListController executable + Root.plist resources
BUNDLE_NAME = SthenoPreference
SthenoPreference_FILES = prefs/SthenoPreferenceListController.m
SthenoPreference_INSTALL_PATH = /Library/PreferenceBundles
SthenoPreference_CFLAGS = -fobjc-arc
SthenoPreference_LDFLAGS = -Wl,-undefined,dynamic_lookup
SthenoPreference_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk