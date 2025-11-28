# NotifyFilter Makefile
# Build for TrollStore distribution

ARCHS = arm64
TARGET = iphone:clang:14.5:14.0

# Paths
BUNDLE_NAME = NotifyFilter
HELPER_NAME = roothelper

# Main app settings
APPLICATION_NAME = $(BUNDLE_NAME)
$(APPLICATION_NAME)_FILES = \
	NotifyFilter/App/NotifyFilterApp.swift \
	NotifyFilter/App/AppDelegate.swift \
	NotifyFilter/App/ContentView.swift \
	NotifyFilter/Models/FilterRule.swift \
	NotifyFilter/Models/NotificationRecord.swift \
	NotifyFilter/Services/DarwinNotificationCenter.swift \
	NotifyFilter/Services/HelperManager.swift \
	NotifyFilter/Services/CriticalAlertSender.swift \
	NotifyFilter/Services/RuleStorage.swift \
	NotifyFilter/Views/DashboardView.swift \
	NotifyFilter/Views/RulesListView.swift \
	NotifyFilter/Views/RuleEditorView.swift \
	NotifyFilter/Views/AppsListView.swift \
	NotifyFilter/Views/SettingsView.swift

$(APPLICATION_NAME)_FRAMEWORKS = UIKit SwiftUI UserNotifications BackgroundTasks CoreFoundation
$(APPLICATION_NAME)_CODESIGN_FLAGS = -Sentitlements.plist
$(APPLICATION_NAME)_CFLAGS = -fobjc-arc

# Root helper settings
TOOL_NAME = $(HELPER_NAME)
$(HELPER_NAME)_FILES = \
	RootHelper/main.m \
	RootHelper/SEGBParser.m \
	RootHelper/NotificationMonitor.m \
	RootHelper/RuleMatcher.m

$(HELPER_NAME)_FRAMEWORKS = Foundation CoreFoundation
$(HELPER_NAME)_CODESIGN_FLAGS = -SRootHelper/roothelper.entitlements
$(HELPER_NAME)_CFLAGS = -fobjc-arc
$(HELPER_NAME)_INSTALL_PATH = /Applications/$(BUNDLE_NAME).app

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tool.mk

after-stage::
	@echo "Copying root helper to app bundle..."
	@mkdir -p $(THEOS_STAGING_DIR)/Applications/$(BUNDLE_NAME).app
	@cp $(THEOS_OBJ_DIR)/$(HELPER_NAME) $(THEOS_STAGING_DIR)/Applications/$(BUNDLE_NAME).app/
	@echo "Setting permissions..."
	@chmod 755 $(THEOS_STAGING_DIR)/Applications/$(BUNDLE_NAME).app/$(HELPER_NAME)

# Alternative: Build with Xcode
xcode-build:
	@echo "Building with Xcode..."
	xcodebuild -project NotifyFilter.xcodeproj \
		-scheme NotifyFilter \
		-configuration Release \
		-sdk iphoneos \
		-destination 'generic/platform=iOS' \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

# Package for TrollStore
package-trollstore: all
	@echo "Packaging for TrollStore..."
	@mkdir -p packages
	@cd $(THEOS_STAGING_DIR)/Applications && \
		zip -r ../../packages/$(BUNDLE_NAME).tipa $(BUNDLE_NAME).app
	@echo "Created packages/$(BUNDLE_NAME).tipa"

# Sign with ldid for TrollStore
sign:
	@echo "Signing with ldid..."
	ldid -SNotifyFilter/NotifyFilter.entitlements $(THEOS_STAGING_DIR)/Applications/$(BUNDLE_NAME).app/$(BUNDLE_NAME)
	ldid -SRootHelper/roothelper.entitlements $(THEOS_STAGING_DIR)/Applications/$(BUNDLE_NAME).app/$(HELPER_NAME)

clean::
	@rm -rf packages/
	@rm -rf .theos/

.PHONY: xcode-build package-trollstore sign
