# ChatGPTXKit: standalone host for the ChatGPTX component gallery.
# Separate bundle (io.ozio.chatgptx.kit) so it never replaces ChatGPTX.
# Offline build: THEOS=~/theos gmake clean package messages=yes
THEOS ?= $(HOME)/theos
THEOS_LEGACY_PREFIX ?= $(THEOS)/toolchain/legacy
TARGET := iphone:clang:6.1:6.0
ARCHS := armv7
DEBUG := 0
FINALPACKAGE := 1
TARGET_STRIP := $(THEOS_LEGACY_PREFIX)/bin/arm-apple-darwin11-strip
TARGET_CODESIGN_ALLOCATE := $(THEOS_LEGACY_PREFIX)/bin/arm-apple-darwin11-codesign_allocate
TARGET_CODESIGN_FLAGS := -S -Hsha1
OR6_UI_GALLERY ?= 1
include $(THEOS)/makefiles/common.mk
RCKIT_DIR := ..
include $(THEOS_PROJECT_DIR)/../RCKit.mk
APPLICATION_NAME := ChatGPTXKit
ChatGPTXKit_FILES := main.m $(RCKIT_FILES)
ChatGPTXKit_FRAMEWORKS := $(RCKIT_FRAMEWORKS)
ChatGPTXKit_USE_MODULES := 0
ChatGPTXKit_CFLAGS := $(RCKIT_CFLAGS) -Wall -Werror -Wno-unused-function
ChatGPTXKit_LDFLAGS := -fuse-ld=$(THEOS_LEGACY_PREFIX)/bin/arm-apple-darwin11-ld -mlinker-version=450 -Wl,-no_data_const -Wl,-no_fixup_chains -Wl,-sdk_version,6.1
ChatGPTXKit_RESOURCE_DIRS := Resources $(RCKIT_RESOURCE_DIRS)
include $(THEOS_MAKE_PATH)/application.mk
