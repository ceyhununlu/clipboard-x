APP_NAME := ClipboardX
BUNDLE_ID := com.ceyhununlu.clipboardx
APP := build/$(APP_NAME).app
INSTALL_DIR := /Applications

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Compile in debug
	swift build

.PHONY: test
test: ## Run the whole test suite
	swift test

.PHONY: app
app: ## Assemble build/ClipboardX.app (universal, ad-hoc signed by default)
	@Scripts/build-app.sh

.PHONY: dist
dist: app ## Build ad-hoc zip + DMG under build/
	@Scripts/package-release.sh

.PHONY: dmg
dmg: app ## Build an ad-hoc drag-to-Applications DMG under build/
	@Scripts/package-dmg.sh

.PHONY: verify
verify: test app ## Run the tests, then build the bundle

.PHONY: install
install: app ## Copy the app to /Applications and relaunch it
	@if pgrep -x $(APP_NAME) >/dev/null; then \
		echo "==> Quitting the running $(APP_NAME)"; \
		osascript -e 'quit app "$(APP_NAME)"' 2>/dev/null || pkill -x $(APP_NAME) || true; \
		sleep 1; \
	fi
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP)" "$(INSTALL_DIR)/"
	@echo "==> Installed $(INSTALL_DIR)/$(APP_NAME).app"
	@echo "    Tip: IDENTITY=auto make install keeps Accessibility across rebuilds"
	open "$(INSTALL_DIR)/$(APP_NAME).app"

.PHONY: run
run: app ## Build and launch the app from ./build
	@pkill -x $(APP_NAME) 2>/dev/null || true
	open "$(APP)"

.PHONY: stop
stop: ## Quit a running instance
	@pkill -x $(APP_NAME) 2>/dev/null && echo "==> Stopped" || echo "==> Not running"

.PHONY: logs
logs: ## Stream the app's log output
	log stream --predicate 'subsystem == "$(BUNDLE_ID)"' --level debug --style compact

.PHONY: reset-permissions
reset-permissions: ## Forget the Accessibility grant (macOS re-asks next launch)
	tccutil reset Accessibility $(BUNDLE_ID) || true

.PHONY: reset-data
reset-data: ## Delete the stored history and preferences
	rm -rf "$(HOME)/Library/Application Support/$(APP_NAME)"
	defaults delete $(BUNDLE_ID) 2>/dev/null || true
	@echo "==> Cleared history and preferences"

.PHONY: clean
clean: ## Remove build products
	swift package clean
	rm -rf .build build
