# TimeCapsuleSMB Makefile
#
# Prerequisites (macOS):
#   - Python 3.10+
#   - The Python 3 AirPyrt port checked out at ../airpyrt-tools
#
# Quick start:
#   1) make install   # create .venv and install this project plus AirPyrt
#   2) make discover  # run mDNS discovery to list devices
#   3) make setup     # interactively enable or disable SSH on a selected device

.PHONY: venv install airpyrt discover setup test clean

VENVDIR := .venv
PYTHON := python3
PIP := $(VENVDIR)/bin/pip
PY := $(VENVDIR)/bin/python
AIRPYRT_DIR ?= ../airpyrt-tools

venv:
	$(PYTHON) -m venv $(VENVDIR)
	@echo "Run: source $(VENVDIR)/bin/activate"

install: venv
	@test -f "$(AIRPYRT_DIR)/setup.py" || { \
		echo "Python 3 AirPyrt port not found at $(AIRPYRT_DIR)."; \
		echo "Set AIRPYRT_DIR=/path/to/airpyrt-tools if it is elsewhere."; \
		exit 1; \
	}
	$(PIP) install -U pip
	$(PIP) install -r requirements.txt
	$(PIP) install -e "$(AIRPYRT_DIR)"

# Compatibility target for the previous workflow. AirPyrt now shares .venv.
airpyrt: install
	@echo "AirPyrt installed from $(AIRPYRT_DIR) into $(VENVDIR)."

discover: install
	$(PY) discovery/discover_timecapsules.py

setup: install
	$(PY) setup.py

test: install
	$(PY) -m unittest discover -s tests -v

clean:
	rm -rf $(VENVDIR)
