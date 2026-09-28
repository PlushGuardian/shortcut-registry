REGISTRY_DIR ?= $(HOME)/.shortcut-registry
SRC := sc.sh
BASHRC ?= $(HOME)/.bashrc
TS := $(shell date +%Y%m%d-%H%M%S)
HOOK_TAG := sc: shortcut registry

.PHONY: help install uninstall lint test

help:
	@echo "Targets:"
	@echo "  install    install sc.sh into \$$(REGISTRY_DIR), migrate data, hook bashrc"
	@echo "  uninstall  remove code (keeps data unless PURGE=1), unhook bashrc"
	@echo "  lint       bash -n + shellcheck (if available)"
	@echo "  test       clean-shell smoke test of sc add/list/run/rm/help"

install:
	@mkdir -p "$(REGISTRY_DIR)"
	@cp "$(SRC)" "$(REGISTRY_DIR)/sc.sh"
	@chmod 644 "$(REGISTRY_DIR)/sc.sh"
	@if [ -f "$(HOME)/.shortcuts" ] && [ ! -f "$(REGISTRY_DIR)/shortcuts" ]; then \
		cp "$(HOME)/.shortcuts" "$(HOME)/.shortcuts.bak.$(TS)"; \
		mv "$(HOME)/.shortcuts" "$(REGISTRY_DIR)/shortcuts"; \
		echo "Migrated $(HOME)/.shortcuts -> $(REGISTRY_DIR)/shortcuts (backup: $(HOME)/.shortcuts.bak.$(TS))"; \
	elif [ -f "$(HOME)/.shortcuts" ]; then \
		echo "Both $(HOME)/.shortcuts and $(REGISTRY_DIR)/shortcuts exist; leaving both alone"; \
	fi
	@if [ ! -f "$(BASHRC)" ]; then touch "$(BASHRC)"; fi
	@if grep -q "$(HOOK_TAG) BEGIN" "$(BASHRC)"; then \
		echo "bashrc already hooked; nothing to insert"; \
	else \
		cp "$(BASHRC)" "$(BASHRC).bak.$(TS)"; \
		echo "Backed up $(BASHRC) -> $(BASHRC).bak.$(TS)"; \
		H='#'; \
		printf '%s\n' "$$H --- $(HOOK_TAG) BEGIN ---" \
			'export SHORTCUT_REGISTRY_PATH="$${SHORTCUT_REGISTRY_PATH:-$$HOME/.shortcut-registry}"' \
			'for _sc_src in "$$SHORTCUT_REGISTRY_PATH"/*.sh; do' \
			'  [[ -f "$$_sc_src" ]] && source "$$_sc_src"' \
			'done' \
			'unset _sc_src' \
			"$$H --- $(HOOK_TAG) END ---" >> "$(BASHRC)"; \
		echo "Hooked $(BASHRC)"; \
	fi
	@bash -n "$(REGISTRY_DIR)/sc.sh" && echo "Syntax OK"
	@echo "Installed. Run: source ~/.bashrc  (or open a new shell)"

uninstall:
	@rm -f "$(REGISTRY_DIR)/sc.sh"
	@if [ "$(PURGE)" = "1" ]; then \
		rm -f "$(REGISTRY_DIR)/shortcuts"; \
		echo "Removed $(REGISTRY_DIR)/shortcuts (PURGE=1)"; \
	else \
		echo "Kept $(REGISTRY_DIR)/shortcuts (use PURGE=1 to remove data)"; \
	fi
	@if [ -f "$(BASHRC)" ] && grep -q "$(HOOK_TAG) BEGIN" "$(BASHRC)"; then \
		cp "$(BASHRC)" "$(BASHRC).bak.$(TS)"; \
		awk '/sc: shortcut registry BEGIN/{skip=1} !skip{print} /sc: shortcut registry END/{skip=0}' "$(BASHRC)" > "$(BASHRC).tmp" && mv "$(BASHRC).tmp" "$(BASHRC)"; \
		echo "Unhooked $(BASHRC) (backup: $(BASHRC).bak.$(TS))"; \
	else \
		echo "bashrc has no hook; nothing to remove"; \
	fi

lint:
	@bash -n "$(SRC)" && echo "Syntax OK: $(SRC)"
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck "$(SRC)"; else echo "shellcheck not found; skipped"; fi

test:
	@TMPDIR=$$(mktemp -d) && \
	export SHORTCUT_REGISTRY_PATH="$$TMPDIR/reg" && \
	mkdir -p "$$SHORTCUT_REGISTRY_PATH" && \
	cp "$(SRC)" "$$SHORTCUT_REGISTRY_PATH/sc.sh" && \
	bash --norc -c 'source "$$SHORTCUT_REGISTRY_PATH/sc.sh"; sc help >/dev/null; sc add hello "Say hi" :: "echo hi-{1}"; sc list | grep -q hello; sc hello world | grep -q "hi-world"; sc rm hello | grep -q Removed; echo "Smoke test OK"' && \
	rm -rf "$$TMPDIR"
