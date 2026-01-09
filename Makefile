.PHONY: help build build-local release release-rc release-stable release-wine

# 현재 버전 가져오기 (GitHub에서 최신 태그)
CURRENT_VERSION := $(shell git fetch --tags 2>/dev/null && git tag --sort=-v:refname | head -1)

help:
	@echo "soju - Wine distribution for PodoSoju"
	@echo ""
	@echo "빌드:"
	@echo "  make build        - CI 빌드 (build-ci.sh)"
	@echo "  make build-local  - 로컬 빌드 (package.sh)"
	@echo ""
	@echo "릴리즈:"
	@echo "  make release-rc     - RC 버전업 (v11.0-rc4 → v11.0-rc5)"
	@echo "  make release-stable - 안정 버전 릴리즈 (v11.0-rc4 → v11.0)"
	@echo "  make release-wine   - Wine 버전업 (v11.0 → v11.1)"
	@echo "  make release VERSION=v11.1-rc1  - 수동 버전 지정"
	@echo ""
	@echo "현재 버전: $(CURRENT_VERSION)"

# 빌드
build:
	./scripts/build-ci.sh

build-local:
	./scripts/package.sh

# 수동 릴리즈
release:
ifndef VERSION
	$(error VERSION을 지정하세요. 예: make release VERSION=v11.1-rc1)
endif
	@echo "릴리즈: $(CURRENT_VERSION) → $(VERSION)"
	@git tag -d $(VERSION) 2>/dev/null || true
	@git push origin --delete $(VERSION) 2>/dev/null || true
	@git tag $(VERSION) && git push origin $(VERSION)
	@echo "완료: $(VERSION)"

# RC 버전업 (v11.0-rc4 → v11.0-rc5)
release-rc:
	@if ! echo "$(CURRENT_VERSION)" | grep -qE '^v[0-9]+\.[0-9]+-rc[0-9]+$$'; then \
		echo "Error: 현재 버전($(CURRENT_VERSION))이 RC 형식이 아닙니다."; \
		exit 1; \
	fi
	@BASE=$$(echo "$(CURRENT_VERSION)" | sed 's/-rc[0-9]*//'); \
	RC_NUM=$$(echo "$(CURRENT_VERSION)" | grep -oE 'rc[0-9]+' | grep -oE '[0-9]+'); \
	NEW_RC=$$((RC_NUM + 1)); \
	NEW_VERSION="$${BASE}-rc$${NEW_RC}"; \
	echo "버전업: $(CURRENT_VERSION) → $$NEW_VERSION"; \
	git tag -d $$NEW_VERSION 2>/dev/null || true; \
	git push origin --delete $$NEW_VERSION 2>/dev/null || true; \
	git tag $$NEW_VERSION && git push origin $$NEW_VERSION && \
	echo "완료: $$NEW_VERSION"

# 안정 버전 릴리즈 (v11.0-rc4 → v11.0)
release-stable:
	@if ! echo "$(CURRENT_VERSION)" | grep -qE '^v[0-9]+\.[0-9]+-rc[0-9]+$$'; then \
		echo "Error: 현재 버전($(CURRENT_VERSION))이 RC 형식이 아닙니다."; \
		exit 1; \
	fi
	@NEW_VERSION=$$(echo "$(CURRENT_VERSION)" | sed 's/-rc[0-9]*//'); \
	echo "안정 버전 릴리즈: $(CURRENT_VERSION) → $$NEW_VERSION"; \
	git tag -d $$NEW_VERSION 2>/dev/null || true; \
	git push origin --delete $$NEW_VERSION 2>/dev/null || true; \
	git tag $$NEW_VERSION && git push origin $$NEW_VERSION && \
	echo "완료: $$NEW_VERSION"

# Wine 마이너 버전업 (v11.0 → v11.1)
release-wine:
	@if echo "$(CURRENT_VERSION)" | grep -qE 'rc[0-9]+$$'; then \
		echo "Error: RC 버전에서는 사용할 수 없습니다. release-stable을 먼저 실행하세요."; \
		exit 1; \
	fi
	@MAJOR=$$(echo "$(CURRENT_VERSION)" | sed 's/^v//' | cut -d. -f1); \
	MINOR=$$(echo "$(CURRENT_VERSION)" | sed 's/^v//' | cut -d. -f2); \
	NEW_MINOR=$$((MINOR + 1)); \
	NEW_VERSION="v$${MAJOR}.$${NEW_MINOR}"; \
	echo "버전업: $(CURRENT_VERSION) → $$NEW_VERSION"; \
	git tag -d $$NEW_VERSION 2>/dev/null || true; \
	git push origin --delete $$NEW_VERSION 2>/dev/null || true; \
	git tag $$NEW_VERSION && git push origin $$NEW_VERSION && \
	echo "완료: $$NEW_VERSION"
