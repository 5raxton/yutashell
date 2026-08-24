# yutashell — Quickshell config for Hyprland
# Pure-QML project: no build step, but install/dist/test/lint targets keep
# the tree honest. `make help` lists everything.

QMLBIN    := /usr/lib/qt6/bin
QMLSRC    := $(shell find . -name '*.qml' -not -path './REFERENCEREADONLY/*' -not -path './theme/matugen/*')
NAME     := yuta-qs
DEST     ?= $(HOME)/.config/quickshell/$(NAME)
DISTDIR  := dist

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "yutashell make targets"
	@echo "  install     install/sync this config to $(DEST) (scripts/install.sh)"
	@echo "  dist        build a release tarball into $(DISTDIR)/"
	@echo "  test        spawn an isolated instance and run IPC smoke checks"
	@echo "  lint-qml    qmllint all sources against installed quickshell types"
	@echo "  fmt         qmlformat in place (opt-in — reflows the whole tree)"

.PHONY: install
install:
	@bash scripts/install.sh

.PHONY: dist
dist: $(DISTDIR)/$(NAME)-$(shell git rev-parse --short HEAD).tar.gz

$(DISTDIR)/$(NAME)-%.tar.gz: 
	@mkdir -p $(DISTDIR)
	git archive --format=tar.gz --prefix=$(NAME)-$*/ -o $@ HEAD
	@echo "wrote $@ ($$(du -h $@ | cut -f1), $$(tar -tzf $@ | wc -l) files)"

.PHONY: test
test:
	@bash scripts/smoke.sh

# Real gate: Qt6 qmllint with quickshell's qmltypes on the default path plus
# a qs.* shim so config-root imports resolve. Findings are reported; the
# target FAILS only on syntax/hard errors — the warning stream contains
# known qmllint-vs-quickshell friction (uncreatable PanelWindow, Process
# signal params, dynamic Loader/inline-component members) tracked in
# ROADMAP PH.08 notes.
.PHONY: lint-qml
lint-qml:
	@mkdir -p .qlint && ln -sfn "$(CURDIR)" .qlint/qs
	@hard=0; files=0; for f in $(QMLSRC); do \
		out=$$($(QMLBIN)/qmllint -I /usr/lib/qt6/qml -I .qlint "$$f" 2>&1); \
		files=$$((files+1)); \
		if echo "$$out" | grep -q "\[syntax\]"; then \
			echo "SYNTAX $$f"; echo "$$out" | head -4; hard=$$((hard+1)); \
		elif [ -n "$$out" ]; then \
			echo "note: findings in $$f"; \
		fi; \
	done; \
	rm -rf .qlint; \
	if [ "$$hard" = 0 ]; then echo "qmllint: no syntax errors across $$files files"; else exit 1; fi

.PHONY: fmt
fmt:
	@for f in $(QMLSRC); do $(QMLBIN)/qmlformat --indent-width 4 -i "$$f"; done
	@echo "reflowed $$(echo $(QMLSRC) | wc -w) files — review the diff before committing"
