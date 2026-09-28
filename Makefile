# PGXS build for the laya extension (PL/Python only, nothing to compile).
#
#   make install                # copy control + SQL into the server's extension dir, and install the
#                               # companion Ollaya model server as a system service on this machine (NO_SERVE=1 skips)
#   make install-serve          # (re)install just the model server's service (systemd on Linux, launchd on macOS)
#   make serve                  # run the Ollaya model server in the foreground
#   make installcheck           # pg_regress against a running server (needs test/mock_api.py, see README)
#   make docker-test            # full test run inside a throwaway container
#   make dist                   # zip for PGXN

EXTENSION    = laya
EXTVERSION   = $(shell grep default_version $(EXTENSION).control | sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")
DATA         = $(wildcard sql/$(EXTENSION)--*.sql)
DOCS         = README.md
REGRESS      = $(patsubst test/sql/%.sql,%,$(sort $(wildcard test/sql/*.sql)))
REGRESS_OPTS = --inputdir=test --outputdir=test --load-extension=plpython3u
PG_CONFIG   ?= pg_config
PGXS        := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

PG_MAJOR ?= 16

.PHONY: install-serve serve dist docker-test

# The prerequisite installs the companion Ollaya model server as a system service on this machine
# (scripts/install_service.sh: systemd on Linux, launchd on macOS, a printed note in containers and
# CI where there is no service manager). The PGXS recipe then copies the extension files.
# NO_SERVE=1 skips the server — containers, CI, or a deployment where the model server runs elsewhere.
install: install-serve

install-serve:
	@[ "$(NO_SERVE)" = "1" ] && { echo "laya: skipping model server install (NO_SERVE=1)"; exit 0; } || bash scripts/install_service.sh

serve:
	@bash scripts/serve.sh

dist:
	git archive --format zip --prefix=$(EXTENSION)-$(EXTVERSION)/ -o $(EXTENSION)-$(EXTVERSION).zip HEAD

docker-test:
	docker build --build-arg PG_MAJOR=$(PG_MAJOR) -t pg-laya-test -f test/Dockerfile .
	docker run --rm pg-laya-test
