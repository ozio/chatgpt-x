THEOS ?= $(HOME)/theos
THEOS_LEGACY_PREFIX ?= $(THEOS)/toolchain/legacy
TARGET := iphone:clang:6.1:6.0
ARCHS := armv7
DEBUG := 0
FINALPACKAGE := 1
TARGET_STRIP := $(THEOS_LEGACY_PREFIX)/bin/arm-apple-darwin11-strip
TARGET_CODESIGN_ALLOCATE := $(THEOS_LEGACY_PREFIX)/bin/arm-apple-darwin11-codesign_allocate
TARGET_CODESIGN_FLAGS := -S -Hsha1
include $(THEOS)/makefiles/common.mk
TOOL_NAME := RCPhoneCheck
RCPhoneCheck_FILES := RCPhoneCheck.m
RCPhoneCheck_FRAMEWORKS := Foundation UIKit CoreGraphics
RCPhoneCheck_USE_MODULES := 0
RCPhoneCheck_CFLAGS := -fno-objc-arc -Wall -Wextra -Werror
RCPhoneCheck_LDFLAGS := -fuse-ld=$(THEOS_LEGACY_PREFIX)/bin/arm-apple-darwin11-ld -mlinker-version=450 -Wl,-no_data_const -Wl,-no_fixup_chains -Wl,-sdk_version,6.1
include $(THEOS_MAKE_PATH)/tool.mk
