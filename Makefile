.PHONY: help build build-local release release-rc release-stable release-wine

# Get current version (latest tag from GitHub)
CURRENT_VERSION := $(shell git fetch --tags 2>/dev/null && git tag --sort=-v:refname | head -1)

help:
	@echo "soju - Wine distribution for PodoSoju"
	@echo ""
	@echo "Build:"
	@echo "  make build        - CI build (build-ci.sh)"
	@echo "  make build-local  - local build (package.sh)"
	@echo ""
	@echo "Release:"
	@echo "  make release-rc     - RC version bump (v11.0-rc4 → v11.0-rc5)"
	@echo "  make release-stable - stable version release (v11.0-rc4 → v11.0)"
	@echo "  make release-wine   - Wine version bump (v11.0 → v11.1)"
	@echo "  make release VERSION=v11.1-rc1  - manual version"
	@echo ""
	@echo "Current version: $(CURRENT_VERSION)"

# Build
build:
	./scripts/build-ci.sh

build-local:
	./scripts/package.sh

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
