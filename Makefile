GO_EASY_ON_ME=1
#export ARCHS = armv7 armv7s arm64
#export ADDITIONAL_OBJCFLAGS = -fobjc-arc

#export TARGET=iphone:clang:9.3:7.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StatusVolX StatusVolXKit
StatusVolX_FILES = StatusVolX.xm
StatusVolX_FRAMEWORKS = UIKit CoreGraphics
StatusVolXKit_FILES = StatusVolXKit.xm
StatusVolXKit_FRAMEWORKS = QuartzCore CoreGraphics UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
