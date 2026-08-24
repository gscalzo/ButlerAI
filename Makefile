PROJECT := Butler.xcodeproj
SCHEME := Butler
DERIVED_DATA := ./DerivedData
ARCHIVE_PATH := ./build/Butler.xcarchive
LOG_DIR ?= /tmp
TEST_LOG := $(LOG_DIR)/butler_make_test.log
TEST_BUILD_LOG := $(LOG_DIR)/butler_make_test_build.log
BUILD_LOG := $(LOG_DIR)/butler_make_build.log

XCODEBUILD_BASE := OS_ACTIVITY_MODE=disable xcodebuild -scheme $(SCHEME) -project $(PROJECT) -destination 'platform=macOS' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
XCODEBUILD_FILTER := rg -v "CoreSimulatorService connection became invalid|Logging connecton invalid|Error opening log file|SimServiceContext|simdiskimaged"

.PHONY: help test test-build build archive clean

help:
	@echo "Targets:"
	@echo "  make test     # Run unit tests"
	@echo "  make test-build  # Build unit tests only (no execution)"
	@echo "  make build    # Build app"
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

archive:
	@$(XCODEBUILD_BASE) archive -archivePath $(ARCHIVE_PATH) 2>&1 | xcsift -w

clean:
	@rm -rf $(DERIVED_DATA) ./build
