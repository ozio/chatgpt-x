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
RCKIT_DIR := ../../ui
include $(THEOS_PROJECT_DIR)/$(RCKIT_DIR)/RCKit.mk
APPLICATION_NAME := ChatGPTX
ChatGPTX_FILES := main.m ../../chat/OR6ChatCoordinator.m ../../chat/OR6ChatEngine.m ../../chat/OR6ChatRootController.m ../../chat/OR6ChatConversationController.m ../../chat/OR6ChatSessionController.m ../../chat/OR6ChatUIState.m ../../chat/OR6ChatScreens.m ../../chat/OR6ChatWelcomeController.m ../../chat/OR6ChatNativeProvider.m ../../chat/OR6ChatPreparation.m ../../chat/OR6ChatWebPreparation.m ../../chat/OR6ChatNativeHTTP.m ../../chat/OR6ChatNativePolicy.m ../../chat/OR6ChatRecoveryStore.m ../../api/OR6APICore.m ../../api/OR6APISchema.m ../../api/OR6APIOperations.m ../../api/OR6APILocalProvider.m ../../api/OR6APISessionProvider.m ../../api/OR6APIHTTP.m ../../api/OR6APIWire.m ../../api/OR6APIWebAdapter.m ../../OR6Content.m ../../auth/OR6WebSession.m ../../auth/OR6WebStore.m ../../auth/OR6WebCookies.m ../../auth/OR6WebTransport.m ../../auth/OR6WebLoginController.m ../../../prototype-login/ORLHTTP.m
ChatGPTX_FILES += $(wildcard ../../webport/*.m) $(wildcard ../../webport/*.c)
ChatGPTX_FILES += ../../chat/OR6ChatFavicons.m ../../chat/OR6ChatPreparationFactory.m $(wildcard ../../chat/stock/*.m)
ChatGPTX_FILES += ../../ui/priority9/OR6Chat9Actions.m ../../ui/priority9/OR6Chat9Dictation.m ../../ui/priority9/OR6Chat9Content.m ../../ui/priority9/OR6Chat9MessageController.m ../../api/priority9/OR6API9Core.m ../../api/priority9/OR6API9Provider.m ../../api/priority9/OR6API9Policy.m ../../api/priority9/OR6API9Network.m ../../api/priority9/OR6API9AudioRecorder.m ../../OR6Audio.m
ChatGPTX_FILES += $(wildcard ../../ui/priority8/*.m) $(wildcard ../../api/priority8/*.m) ../../OR6Files.m
# API7: complete inventory (composition, seven modules, streaming adapter) and its UI.
ChatGPTX_FILES += $(foreach m,priority7 priority7b priority7c priority7d priority7e priority7f priority7g priority7h priority7all,$(wildcard ../../api/$(m)/*.m)) $(wildcard ../../ui/priority7/*.m)
# API6 sits on the API7 provider; capabilities follow ios/api/priority6all/admission.json.
ChatGPTX_FILES += $(foreach m,priority6a priority6b priority6c priority6d priority6e priority6f priority6all,$(wildcard ../../api/$(m)/*.m)) $(wildcard ../../ui/priority6/*.m)
ChatGPTX_FILES += $(wildcard ../../api/selected20/*.m) $(wildcard ../../ui/selected20/*.m) ../../api/priority4b/OR6API4BPolicy.m
ChatGPTX_FILES += $(wildcard ../../api/voice-realtime/*.m) ../../voice/OR6RealtimeRuntime.m ../../voice/OR6VoiceAudio.m
ChatGPTX_FILES += $(wildcard ../../api/voice8/*.m) $(wildcard ../../chat/voice8/*.m)
ChatGPTX_FILES += $(wildcard ../../api/codex/*.m) $(wildcard ../../api/codex/pair/*.m) $(wildcard ../../chat/codex/*.m) $(wildcard ../../chat/codex/qr/*.c) ../../auth/OR6OAuthCrypto.m
# Preserve the pinned upstream C source; suppress only its existing warnings.
../../chat/codex/qr/identify.c_CFLAGS := -Wno-unused-parameter -Wno-sign-compare
ChatGPTX_FILES += $(foreach m,revisit67all revisit67local revisit67content revisit67account,$(wildcard ../../api/$(m)/*.m))
ChatGPTX_FILES += $(foreach m,priority5a priority5b priority5c priority5d priority5e priority5all revisit5all revisit5local revisit5content revisit5system revisit5asr,$(wildcard ../../api/$(m)/*.m))
ChatGPTX_FRAMEWORKS := EventKit AssetsLibrary CoreLocation MessageUI UIKit Foundation CoreFoundation CoreGraphics CoreText Security CFNetwork AVFoundation AudioToolbox ImageIO MediaPlayer CoreVideo CoreMedia
ChatGPTX_LIBRARIES := z
ChatGPTX_USE_MODULES := 0
ChatGPTX_FILES += $(RCKIT_FILES)
ChatGPTX_RESOURCE_DIRS := Resources $(RCKIT_RESOURCE_DIRS)
ChatGPTX_CFLAGS := -fno-objc-arc -fblocks $(RCKIT_CFLAGS) -I$(THEOS_PROJECT_DIR)/../../chat -I$(THEOS_PROJECT_DIR)/../../api -I$(THEOS_PROJECT_DIR)/../../auth -I$(THEOS_PROJECT_DIR)/../../../prototype-login -I$(OR6_API_MBED_SOURCE)/include -DMBEDTLS_USER_CONFIG_FILE=\"$(THEOS_PROJECT_DIR)/../../../support/native-api/transport/mbed-user-threaded.h\"
ChatGPTX_CFLAGS += $(OR6_ASR_INCLUDE_FLAGS) -DOR6_API8_REAL_HTTP=1 -I$(OR6_CODEX_SSH_SOURCE)/include
ChatGPTX_LDFLAGS := $(OR6_REALTIME_ARCHIVE) -fuse-ld=$(THEOS_LEGACY_PREFIX)/bin/arm-apple-darwin11-ld -mlinker-version=450 -Wl,-no_data_const -Wl,-no_fixup_chains -Wl,-sdk_version,6.1 $(OR6_CODEX_SSH_ARCHIVE) $(OR6_API_MBED_ARCHIVE) $(OR6_ASR_ARCHIVE)
ifeq ($(OR6_CHAT_ACCEPTANCE),1)
ChatGPTX_FILES += ../../../tests/stock-production/PhoneCycle.m ../../../tests/codex-ui/PhoneFixture.m ../../../tests/codex-pair/key-phone.m
ChatGPTX_FILES += ../../chat/OR6ChatAcceptance.m ../../../tests/chat-ui9/PhoneFixture.m
ChatGPTX_FILES += ../../../tests/chat-ui8-physical/PhoneFixture.m
ChatGPTX_FILES += ../../../tests/chat-ui7-live/Policy.m ../../../tests/chat-ui7-live/PhoneProbe.m
ChatGPTX_FILES += ../../../tests/chat-ui7-physical/Backend.m ../../../tests/chat-ui7-physical/PhoneFixture.m
ChatGPTX_CFLAGS += -DOR6_CHAT_ACCEPTANCE
endif
include $(THEOS_MAKE_PATH)/application.mk

