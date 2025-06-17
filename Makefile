# -------- Repo‑wide variables --------
SCHEME        ?= DonnaApp
WORKSPACE     ?= Donna.xcworkspace
DEST          ?= platform=iOS Simulator,OS=26.0,name=iPhone 15 Pro
BUILD_DIR     ?= .build
LOG_FILTER    ?= $(shell which xcbeautify > /dev/null && echo "xcbeautify" || echo "cat")


# -------- Project Generation --------
## generate Xcode project from project.yml
generate:
	xcodegen --spec project.yml --use-cache

## bootstrap including XcodeGen
bootstrap:
	@brew bundle --file=./Brewfile
	@brew install xcodegen  # Add this
	@$(MAKE) generate

# Add a pure SwiftPM build option
## build all SwiftPM targets directly
package-build:
	swift build --configuration release \
		-Xswiftc -strict-concurrency=complete \

# -------- Static analysis & lint --------
## run swift-format + swiftlint
lint:
	swift-format -i `git ls-files '*.swift'`
	swiftlint | $(LOG_FILTER)

## build with strict concurrency + actor data‑race checks
concurrency-check:
	xcodebuild build -workspace $(WORKSPACE) -scheme $(SCHEME) \
		-destination '$(DEST)' \
		-derivedDataPath $(BUILD_DIR) \
		-configuration Debug \
		ENABLE_ACTOR_DATA_RACE_CHECKS=YES \
		OTHER_SWIFT_FLAGS='-strict-concurrency=complete' \
		| $(LOG_FILTER)

# -------- Test targets --------
## unit + logic tests
test:
	xcodebuild test -workspace $(WORKSPACE) -scheme $(SCHEME) \
		-destination '$(DEST)' \
		-derivedDataPath $(BUILD_DIR) \
		-parallel-testing-enabled YES \
		| $(LOG_FILTER)

## UI automation pass – launches Donna, runs Siri shortcut,
## verifies Live Activity pin, tears down.
ui-test:
	xcodebuild test-without-building \
		-workspace $(WORKSPACE) -scheme DonnaUITests \
		-destination '$(DEST)' \
		-test-iterations 1 \
		| $(LOG_FILTER)

# -------- Run the app in a booted sim and stream logs --------
run:
	xcrun simctl bootstatus --watch '$(DEST)'
	xcrun simctl install booted "$(BUILD_DIR)/Build/Products/Debug-iphonesimulator/DonnaApp.app"
	xcrun simctl launch --console booted com.example.DonnaApp

# -------- CLI hooks for JIN agents --------
## invoke a parameter‑less Start Recording shortcut inside the sim,
## wait 10 s, then Stop; exit 0 if Donna returns a completed recording.
smoke-shortcut:
	@out=$$(xcrun simctl shortcuts booted run "Start Recording in Donna" || true); \
	sleep 10; \
	xcrun simctl shortcuts booted run "Stop Recording in Donna" || true; \
	if [ -f "$${HOME}/Library/Developer/CoreSimulator/Devices/$$(xcrun simctl list devices | grep -m1 Booted | awk '{print $$NF}' | tr -d '()')/data/Containers/Data/Application/*/Documents/Recordings/*.m4a" ]; then \
	  echo "✅ shortcut smoke‑test passed"; \
	else \
	  echo "❌ smoke‑test failed: no recording found"; exit 1; \
	fi

clean:
	rm -rf $(BUILD_DIR)