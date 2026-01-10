.PHONY: help build build-local build-source release release-rc release-stable release-wine
.PHONY: watch logs retry release-verify

# Get current version (latest tag from GitHub)
CURRENT_VERSION := $(shell git fetch --tags 2>/dev/null && git tag --sort=-v:refname | head -1)

# Get version from VERSION file
FILE_VERSION := $(shell cat VERSION 2>/dev/null || echo "11.0-rc5")

help:
	@echo "soju - Wine distribution for PodoSoju"
	@echo ""
	@echo "Build:"
	@echo "  make build        - CI build (build-ci.sh)"
	@echo "  make build-local  - local build (package.sh)"
	@echo "  make build-source - source build (build-source.sh, uses VERSION file)"
	@echo ""
	@echo "GitHub Actions:"
	@echo "  make watch        - watch latest workflow run"
	@echo "  make logs         - show failed job logs"
	@echo "  make retry        - rerun failed jobs"
	@echo ""
	@echo "Release:"
	@echo "  make release-rc      - RC version bump (v11.0-rc4 → v11.0-rc5)"
	@echo "  make release-stable  - stable version release (v11.0-rc4 → v11.0)"
	@echo "  make release-wine    - Wine version bump (v11.0 → v11.1)"
	@echo "  make release-verify  - verify release artifacts"
	@echo "  make release VERSION=v11.1-rc1  - manual version"
	@echo ""
	@echo "Current version: $(CURRENT_VERSION)"
	@echo "VERSION file:    $(FILE_VERSION)"

# Build
build:
	./scripts/build-ci.sh

build-local:
	./scripts/package.sh

build-source:
	@echo "Building from source with VERSION=$(FILE_VERSION)"
	WINE_VERSION=$(FILE_VERSION) ./scripts/build-source.sh

# GitHub Actions integration
watch:
	@echo "Watching latest workflow run..."
	gh run watch

logs:
	@echo "Showing failed job logs..."
	gh run view --log-failed

retry:
	@echo "Rerunning failed jobs..."
	gh run rerun --failed

# Release verification
release-verify:
	@echo "Verifying release artifacts for $(CURRENT_VERSION)..."
	@if [ -z "$(CURRENT_VERSION)" ]; then \
		echo "Error: No version tag found"; \
		exit 1; \
	fi
	@echo "Checking release assets..."
	@gh release view $(CURRENT_VERSION) --json assets --jq '.assets[] | "\(.name) (\(.size) bytes)"' || \
		(echo "Error: Release $(CURRENT_VERSION) not found"; exit 1)
	@echo ""
	@echo "Downloading and verifying tarball..."
	@TARBALL=$$(gh release view $(CURRENT_VERSION) --json assets --jq '.assets[] | select(.name | endswith(".tar.gz")) | .name' | head -1); \
	if [ -z "$$TARBALL" ]; then \
		echo "Error: No tarball found in release"; \
		exit 1; \
	fi; \
	echo "  Tarball: $$TARBALL"; \
	gh release download $(CURRENT_VERSION) --pattern "$$TARBALL" --dir /tmp --clobber; \
	echo "  Extracting to verify structure..."; \
	tar -tzf "/tmp/$$TARBALL" | head -20; \
	echo "  ..."; \
	echo "  Checking for SojuVersion.plist..."; \
	if tar -tzf "/tmp/$$TARBALL" | grep -q "SojuVersion.plist"; then \
		echo "  SojuVersion.plist found"; \
	else \
		echo "  Warning: SojuVersion.plist not found"; \
	fi; \
	rm -f "/tmp/$$TARBALL"; \
	echo ""; \
	echo "Verification complete for $(CURRENT_VERSION)"

# Manual release
release:
ifndef VERSION
	$(error Please specify VERSION. e.g. make release VERSION=v11.1-rc1)
endif
	@echo "Release: $(CURRENT_VERSION) → $(VERSION)"
	@git tag -d $(VERSION) 2>/dev/null || true
	@git push origin --delete $(VERSION) 2>/dev/null || true
	@git tag $(VERSION) && git push origin $(VERSION)
	@echo "Done: $(VERSION)"

# RC version bump (v11.0-rc4 → v11.0-rc5)
release-rc:
	@if ! echo "$(CURRENT_VERSION)" | grep -qE '^v[0-9]+\.[0-9]+-rc[0-9]+$$'; then \
		echo "Error: Current version($(CURRENT_VERSION))is not in RC format."; \
		exit 1; \
	fi
	@BASE=$$(echo "$(CURRENT_VERSION)" | sed 's/-rc[0-9]*//'); \
	RC_NUM=$$(echo "$(CURRENT_VERSION)" | grep -oE 'rc[0-9]+' | grep -oE '[0-9]+'); \
	NEW_RC=$$((RC_NUM + 1)); \
	NEW_VERSION="$${BASE}-rc$${NEW_RC}"; \
	echo "Version bump: $(CURRENT_VERSION) → $$NEW_VERSION"; \
	git tag -d $$NEW_VERSION 2>/dev/null || true; \
	git push origin --delete $$NEW_VERSION 2>/dev/null || true; \
	git tag $$NEW_VERSION && git push origin $$NEW_VERSION && \
	echo "Done: $$NEW_VERSION"

# stable version release (v11.0-rc4 → v11.0)
release-stable:
	@if ! echo "$(CURRENT_VERSION)" | grep -qE '^v[0-9]+\.[0-9]+-rc[0-9]+$$'; then \
		echo "Error: Current version($(CURRENT_VERSION))is not in RC format."; \
		exit 1; \
	fi
	@NEW_VERSION=$$(echo "$(CURRENT_VERSION)" | sed 's/-rc[0-9]*//'); \
	echo "stable version Release: $(CURRENT_VERSION) → $$NEW_VERSION"; \
	git tag -d $$NEW_VERSION 2>/dev/null || true; \
	git push origin --delete $$NEW_VERSION 2>/dev/null || true; \
	git tag $$NEW_VERSION && git push origin $$NEW_VERSION && \
	echo "Done: $$NEW_VERSION"

# Wine minor version bump (v11.0 → v11.1)
release-wine:
	@if echo "$(CURRENT_VERSION)" | grep -qE 'rc[0-9]+$$'; then \
		echo "Error: RC version cannot be used. Run release-stable first."; \
		exit 1; \
	fi
	@MAJOR=$$(echo "$(CURRENT_VERSION)" | sed 's/^v//' | cut -d. -f1); \
	MINOR=$$(echo "$(CURRENT_VERSION)" | sed 's/^v//' | cut -d. -f2); \
	NEW_MINOR=$$((MINOR + 1)); \
	NEW_VERSION="v$${MAJOR}.$${NEW_MINOR}"; \
	echo "Version bump: $(CURRENT_VERSION) → $$NEW_VERSION"; \
	git tag -d $$NEW_VERSION 2>/dev/null || true; \
	git push origin --delete $$NEW_VERSION 2>/dev/null || true; \
	git tag $$NEW_VERSION && git push origin $$NEW_VERSION && \
	echo "Done: $$NEW_VERSION"
