PROJECT := Butler.xcodeproj
SCHEME := Butler
DERIVED_DATA := ./DerivedData
ARCHIVE_PATH := ./build/Butler.xcarchive
LOG_DIR ?= /tmp
TEST_LOG := $(LOG_DIR)/butler_make_test.log
TEST_BUILD_LOG := $(LOG_DIR)/butler_make_test_build.log
BUILD_LOG := $(LOG_DIR)/butler_make_build.log

XCODEBUILD_BASE := OS_ACTIVITY_MODE=disable xcodebuild -scheme $(SCHEME) -project $(PROJECT) -destination 'platform=macOS' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
# Signed build (automatic signing with the project's team) for local installs.
XCODEBUILD_SIGNED := OS_ACTIVITY_MODE=disable xcodebuild -scheme $(SCHEME) -project $(PROJECT) -destination 'platform=macOS' -derivedDataPath $(DERIVED_DATA)
APP_NAME := Butler
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app
INSTALL_DIR := /Applications
TRASH_DIR := $(HOME)/.Trash
XCODEBUILD_FILTER := rg -v "CoreSimulatorService connection became invalid|Logging connecton invalid|Error opening log file|SimServiceContext|simdiskimaged"

.PHONY: help test test-build build release install archive clean

help:
	@echo "Targets:"
	@echo "  make test     # Run unit tests"
	@echo "  make test-build  # Build unit tests only (no execution)"
	@echo "  make build    # Build app"
	@echo "  make release  # Build a signed Release app into DerivedData"
	@echo "  make install  # Build Release and replace $(INSTALL_DIR)/$(APP_NAME).app (quits the running app; old copy goes to the Trash)"
	@echo "  make archive  # Archive app"
	@echo "  make clean    # Remove DerivedData and build artifacts"
	@echo "Variables: LOG_DIR=<dir> (default /tmp) controls where xcodebuild logs are written"

test:
	@mkdir -p $(LOG_DIR)
	@$(XCODEBUILD_BASE) -only-testing:ButlerTests test 2>&1 | tee $(TEST_LOG) | $(XCODEBUILD_FILTER) | xcsift -w
	@rg -o "Executed [0-9]+ tests" $(TEST_LOG) >/dev/null || (echo "ERROR: test count not found in $(TEST_LOG)" && exit 1)
	@tests_run=$$(rg -o "Executed [0-9]+ tests" $(TEST_LOG) | tail -n 1 | rg -o "[0-9]+" | tail -n 1); \
		if [ -z "$$tests_run" ]; then echo "ERROR: test count not found in $(TEST_LOG)"; exit 1; fi; \
		echo "tests_run: $$tests_run"

test-build:
	@mkdir -p $(LOG_DIR)
	@$(XCODEBUILD_BASE) build-for-testing 2>&1 | tee $(TEST_BUILD_LOG) | $(XCODEBUILD_FILTER) | xcsift -w

build:
	@mkdir -p $(LOG_DIR)
	@$(XCODEBUILD_BASE) build 2>&1 | tee $(BUILD_LOG) | $(XCODEBUILD_FILTER) | xcsift -w

release:
	@mkdir -p $(LOG_DIR)
	@$(XCODEBUILD_SIGNED) -configuration Release build 2>&1 | tee $(LOG_DIR)/butler_make_release.log | $(XCODEBUILD_FILTER) | xcsift -w
	@echo "built: $(RELEASE_APP) ($$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(RELEASE_APP)/Contents/Info.plist"))"

install: release
	@pkill -x $(APP_NAME) 2>/dev/null && sleep 1 || true
	@if [ -d "$(INSTALL_DIR)/$(APP_NAME).app" ]; then \
		mv "$(INSTALL_DIR)/$(APP_NAME).app" "$(TRASH_DIR)/$(APP_NAME).app.$$(date +%Y%m%d-%H%M%S)"; \
		echo "moved previous app to $(TRASH_DIR)"; \
	fi
	@ditto "$(RELEASE_APP)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "installed: $(INSTALL_DIR)/$(APP_NAME).app ($$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(INSTALL_DIR)/$(APP_NAME).app/Contents/Info.plist"))"

archive:
	@$(XCODEBUILD_BASE) archive -archivePath $(ARCHIVE_PATH) 2>&1 | xcsift -w

clean:
	@rm -rf $(DERIVED_DATA) ./build
