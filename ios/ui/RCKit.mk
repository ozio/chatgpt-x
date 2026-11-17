# ChatGPTX UI kit (ios/ui) for Theos projects. Include AFTER common.mk:
#   RCKIT_DIR := ../../ui            # path from the project dir to ios/ui
#   include $(THEOS_PROJECT_DIR)/$(RCKIT_DIR)/RCKit.mk
#   App_FILES      += $(RCKIT_FILES)
#   App_CFLAGS     += $(RCKIT_CFLAGS)
#   App_FRAMEWORKS += $(RCKIT_FRAMEWORKS)   # UIKit Foundation CoreGraphics CoreText
#   App_RESOURCE_DIRS := Resources $(RCKIT_RESOURCE_DIRS)
# The component gallery is compiled only with OR6_UI_GALLERY=1 (make variable);
# without it no gallery code or strings are linked into the app.
RCKIT_DIR ?= ../../ui
RCKIT_SOURCES := RCTheme.m RCGlyph.m RCLampView.m RCButton.m RCTitleView.m RCBannerView.m \
	RCUserMessageView.m RCAnswerCardView.m RCActionBar.m RCPartPlaceholderView.m \
	RCComposerView.m RCActivitySheet.m RCRevealController.m RCDrawerController.m \
	RCProgressView.m RCHUD.m RCCodeBlockView.m RCMarkdownView.m RCMarkdownText.m RCPartView.m RCImagePartView.m \
	RCChartPartView.m RCTaskPartView.m RCMailPartView.m RCClarifyPartView.m RCFilePartView.m \
	RCEmptyChatView.m RCDictationView.m RCStage.m RCTextStackView.m RCTransition.m
# Shell screens and small elements (second kit pass).
RCKIT_SOURCES += RCSelectTextViewController.m RCTextSizeSlider.m RCSegmentedControl.m RCAccountHeaderView.m \
	RCSwipeToDelete.m RCWelcomeViewController.m RCWebFrameController.m RCSourcesSheet.m RCVoiceViewController.m \
	RCPINViewController.m RCImageViewerController.m RCScannerViewController.m RCGridViewController.m \
	RCTranslateViewController.m RCShareLinkSheet.m RCReportViewController.m RCLaunchView.m RCFileIcon.m
# Sectioned checklist (model picker: family / mode / thinking effort).
RCKIT_SOURCES += RCChecklistViewController.m RCRefreshControl.m
# API 7/10: grouped settings form and local audio playback controls.
RCKIT_SOURCES += RCFormViewController.m RCPlaybackView.m RCReadAloudBar.m
# Codex tier 1: task history parts and the diff screen.
RCKIT_SOURCES += RCFileChangesPartView.m RCTerminalPartView.m RCApprovalPartView.m RCTimelineNoteView.m RCDiffViewController.m
# Codex tier 2: plan card (review notes live in RCDiffViewController).
RCKIT_SOURCES += RCPlanPartView.m
# Codex tier 3: goal strip, rating row, profile figures (hooks are an RCTimelineNoteView style).
RCKIT_SOURCES += RCGoalStripView.m RCRatingRowView.m RCStatsRowView.m
RCKIT_FILES := $(addprefix $(RCKIT_DIR)/,$(RCKIT_SOURCES))
RCKIT_CFLAGS := -fno-objc-arc -fblocks -I$(THEOS_PROJECT_DIR)/$(RCKIT_DIR)
RCKIT_FRAMEWORKS := UIKit Foundation CoreGraphics CoreText
RCKIT_RESOURCE_DIRS := $(RCKIT_DIR)/Resources
ifeq ($(OR6_UI_GALLERY),1)
RCKIT_FILES += $(addprefix $(RCKIT_DIR)/gallery/,RCGalleryViewController.m RCGalleryDemos.m RCGalleryDemos2.m RCGalleryDemos3.m RCGalleryDemos8.m RCGalleryDemos7.m RCGalleryDemos9.m)
RCKIT_CFLAGS += -DOR6_UI_GALLERY=1 -I$(THEOS_PROJECT_DIR)/$(RCKIT_DIR)/gallery
endif
