TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamicIslandHome

DynamicIslandHome_FILES = Tweak.xm
DynamicIslandHome_CFLAGS = -fobjc-arc -w
DynamicIslandHome_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation TelephonyUI ReplayKit LocalAuthentication
DynamicIslandHome_PRIVATE_FRAMEWORKS = MediaRemote TelephonyUtilities

include $(THEOS_MAKE_PATH)/tweak.mk
