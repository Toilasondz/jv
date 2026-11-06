TARGET := iphone:clang:14.5:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = VideoStar

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VideoStarMacroTool

VideoStarMacroTool_FILES = Tweak.xm
VideoStarMacroTool_FRAMEWORKS = UIKit Foundation CoreGraphics Photos PhotosUI QuartzCore AudioToolbox
VideoStarMacroTool_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 VideoStar" || true
