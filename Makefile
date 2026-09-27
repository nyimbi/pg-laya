# PGXS build for the laya extension (PL/Python only, nothing to compile).
#
#   make install                # copies control + SQL into the server's extension dir
#   make install-serve          # install the systemd unit for the Laya companion server
#   make serve                  # run Laya locally (pip installs the [serve] extra, starts it)
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

.PHONY: dist docker-test serve install-serve
install-serve:
	install -d /etc/systemd/system /etc/laya
	install -m 0644 scripts/laya.conf /etc/systemd/system/laya.service
	echo '# set LAYA_API_KEY here; chmod 600 /etc/laya/env' > /etc/laya/env
	systemctl daemon-reload
	systemctl enable --now laya.service

serve:
	@pip install "laya[serve]" || true
	@bash scripts/serve.sh

dist:
	git archive --format zip --prefix=$(EXTENSION)-$(EXTVERSION)/ -o $(EXTENSION)-$(EXTVERSION).zip HEAD

docker-test:
	docker build --build-arg PG_MAJOR=$(PG_MAJOR) -t pg-laya-test -f test/Dockerfile .
	docker run --rm pg-laya-test
