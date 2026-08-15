TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamicByHDang

DynamicByHDang_FILES = Tweak.xm
DynamicByHDang_CFLAGS = -fobjc-arc -w
DynamicByHDang_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation TelephonyUI ReplayKit LocalAuthentication
DynamicByHDang_PRIVATE_FRAMEWORKS = MediaRemote TelephonyUtilities

include $(THEOS_MAKE_PATH)/tweak.mk
