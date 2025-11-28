#!/bin/bash

# Generate Xcode project for NotifyFilter
# This creates a minimal xcodeproj that can build the Swift app

set -e

PROJECT_NAME="NotifyFilter"
PROJECT_DIR="$PROJECT_NAME.xcodeproj"

echo "Generating Xcode project..."

# Create project directory
mkdir -p "$PROJECT_DIR"

# Generate project.pbxproj
cat > "$PROJECT_DIR/project.pbxproj" << 'PBXPROJ'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		/* App Swift Files */
		F1001001 /* NotifyFilterApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2001001; };
		F1001002 /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2001002; };
		F1001003 /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2001003; };
		/* Models */
		F1002001 /* FilterRule.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2002001; };
		F1002002 /* NotificationRecord.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2002002; };
		/* Services */
		F1003001 /* DarwinNotificationCenter.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2003001; };
		F1003002 /* HelperManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2003002; };
		F1003003 /* CriticalAlertSender.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2003003; };
		F1003004 /* RuleStorage.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2003004; };
		/* Views */
		F1004001 /* DashboardView.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2004001; };
		F1004002 /* RulesListView.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2004002; };
		F1004003 /* RuleEditorView.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2004003; };
		F1004004 /* AppsListView.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2004004; };
		F1004005 /* SettingsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2004005; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		/* Product */
		F0000001 /* NotifyFilter.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = NotifyFilter.app; sourceTree = BUILT_PRODUCTS_DIR; };
		/* App Swift Files */
		F2001001 /* NotifyFilterApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotifyFilterApp.swift; sourceTree = "<group>"; };
		F2001002 /* AppDelegate.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>"; };
		F2001003 /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
		/* Models */
		F2002001 /* FilterRule.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = FilterRule.swift; sourceTree = "<group>"; };
		F2002002 /* NotificationRecord.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationRecord.swift; sourceTree = "<group>"; };
		/* Services */
		F2003001 /* DarwinNotificationCenter.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = DarwinNotificationCenter.swift; sourceTree = "<group>"; };
		F2003002 /* HelperManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HelperManager.swift; sourceTree = "<group>"; };
		F2003003 /* CriticalAlertSender.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CriticalAlertSender.swift; sourceTree = "<group>"; };
		F2003004 /* RuleStorage.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RuleStorage.swift; sourceTree = "<group>"; };
		/* Views */
		F2004001 /* DashboardView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = DashboardView.swift; sourceTree = "<group>"; };
		F2004002 /* RulesListView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RulesListView.swift; sourceTree = "<group>"; };
		F2004003 /* RuleEditorView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RuleEditorView.swift; sourceTree = "<group>"; };
		F2004004 /* AppsListView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppsListView.swift; sourceTree = "<group>"; };
		F2004005 /* SettingsView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SettingsView.swift; sourceTree = "<group>"; };
		/* Config Files */
		F2005001 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
		F2005002 /* NotifyFilter.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = NotifyFilter.entitlements; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		F3000001 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		F4000001 /* Root */ = {
			isa = PBXGroup;
			children = (
				F4000002 /* NotifyFilter */,
				F4000010 /* Products */,
			);
			sourceTree = "<group>";
		};
		F4000002 /* NotifyFilter */ = {
			isa = PBXGroup;
			children = (
				F4000003 /* App */,
				F4000004 /* Models */,
				F4000005 /* Services */,
				F4000006 /* Views */,
				F2005001 /* Info.plist */,
				F2005002 /* NotifyFilter.entitlements */,
			);
			path = NotifyFilter;
			sourceTree = "<group>";
		};
		F4000003 /* App */ = {
			isa = PBXGroup;
			children = (
				F2001001 /* NotifyFilterApp.swift */,
				F2001002 /* AppDelegate.swift */,
				F2001003 /* ContentView.swift */,
			);
			path = App;
			sourceTree = "<group>";
		};
		F4000004 /* Models */ = {
			isa = PBXGroup;
			children = (
				F2002001 /* FilterRule.swift */,
				F2002002 /* NotificationRecord.swift */,
			);
			path = Models;
			sourceTree = "<group>";
		};
		F4000005 /* Services */ = {
			isa = PBXGroup;
			children = (
				F2003001 /* DarwinNotificationCenter.swift */,
				F2003002 /* HelperManager.swift */,
				F2003003 /* CriticalAlertSender.swift */,
				F2003004 /* RuleStorage.swift */,
			);
			path = Services;
			sourceTree = "<group>";
		};
		F4000006 /* Views */ = {
			isa = PBXGroup;
			children = (
				F2004001 /* DashboardView.swift */,
				F2004002 /* RulesListView.swift */,
				F2004003 /* RuleEditorView.swift */,
				F2004004 /* AppsListView.swift */,
				F2004005 /* SettingsView.swift */,
			);
			path = Views;
			sourceTree = "<group>";
		};
		F4000010 /* Products */ = {
			isa = PBXGroup;
			children = (
				F0000001 /* NotifyFilter.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		F5000001 /* NotifyFilter */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = F7000001 /* Build configuration list for PBXNativeTarget "NotifyFilter" */;
			buildPhases = (
				F6000001 /* Sources */,
				F3000001 /* Frameworks */,
				F6000002 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = NotifyFilter;
			productName = NotifyFilter;
			productReference = F0000001 /* NotifyFilter.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		F8000001 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1520;
				LastUpgradeCheck = 1520;
				TargetAttributes = {
					F5000001 = {
						CreatedOnToolsVersion = 15.2;
					};
				};
			};
			buildConfigurationList = F7000002 /* Build configuration list for PBXProject "NotifyFilter" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = F4000001;
			productRefGroup = F4000010 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				F5000001 /* NotifyFilter */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		F6000002 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		F6000001 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				F1001001 /* NotifyFilterApp.swift in Sources */,
				F1001002 /* AppDelegate.swift in Sources */,
				F1001003 /* ContentView.swift in Sources */,
				F1002001 /* FilterRule.swift in Sources */,
				F1002002 /* NotificationRecord.swift in Sources */,
				F1003001 /* DarwinNotificationCenter.swift in Sources */,
				F1003002 /* HelperManager.swift in Sources */,
				F1003003 /* CriticalAlertSender.swift in Sources */,
				F1003004 /* RuleStorage.swift in Sources */,
				F1004001 /* DashboardView.swift in Sources */,
				F1004002 /* RulesListView.swift in Sources */,
				F1004003 /* RuleEditorView.swift in Sources */,
				F1004004 /* AppsListView.swift in Sources */,
				F1004005 /* SettingsView.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		F9000001 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 14.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		F9000002 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 14.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		F9000003 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = NotifyFilter/NotifyFilter.entitlements;
				CODE_SIGN_IDENTITY = "";
				CODE_SIGN_STYLE = Manual;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = NotifyFilter/Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.notifyfilter.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				PROVISIONING_PROFILE_SPECIFIER = "";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		F9000004 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = NotifyFilter/NotifyFilter.entitlements;
				CODE_SIGN_IDENTITY = "";
				CODE_SIGN_STYLE = Manual;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = NotifyFilter/Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.notifyfilter.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				PROVISIONING_PROFILE_SPECIFIER = "";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		F7000001 /* Build configuration list for PBXNativeTarget "NotifyFilter" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				F9000003 /* Debug */,
				F9000004 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		F7000002 /* Build configuration list for PBXProject "NotifyFilter" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				F9000001 /* Debug */,
				F9000002 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = F8000001 /* Project object */;
}
PBXPROJ

# Create scheme
mkdir -p "$PROJECT_DIR/xcshareddata/xcschemes"

cat > "$PROJECT_DIR/xcshareddata/xcschemes/NotifyFilter.xcscheme" << 'SCHEME'
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1520"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "F5000001"
               BuildableName = "NotifyFilter.app"
               BlueprintName = "NotifyFilter"
               ReferencedContainer = "container:NotifyFilter.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
   </LaunchAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
SCHEME

echo "Xcode project generated successfully!"
echo "Project: $PROJECT_DIR"
