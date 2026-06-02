.PHONY: install require-mise lint lint-python lint-dockerfile lint-md lint-yml lint-json lint-toml lint-sh lint-github-actions lint-duplicates test format install-hooks clean

MISE ?= $(shell command -v mise 2>/dev/null || printf '%s/.local/bin/mise' "$$HOME")

require-mise:
	@test -x "$(MISE)" || { echo "mise is required. Install it with: curl https://mise.run | sh"; exit 1; }

install: require-mise
	$(MISE) install
	$(MISE) run install

lint lint-python lint-dockerfile lint-md lint-yml lint-json lint-toml lint-sh lint-github-actions lint-duplicates test format install-hooks clean: require-mise
	$(MISE) run $@
