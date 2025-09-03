TITLE = COSMO tasks
VERSION = 0.1
HOMEPAGE = https://tfinternal.research.cchmc.org/gitlab/weirauchlab/cosmo
LOGDIR = log
SHELL = bash
# this might be 'python2' on some systems like Ubuntu LTS; if that's the case,
# it's best to just create a virtualenv using that Python, then activate it
PYTHON = python
PYTHONVER := $(shell $(PYTHON) -c 'import sys; print("%d.%d.%d" % (sys.version_info.major, sys.version_info.minor, sys.version_info.micro))')
VIRTUALENV = venv

help:  # prints this help
	@$(PYTHON) -c "$$AUTOGEN_HELP_PY" "$(firstword $(MAKEFILE_LIST))"

moods: have-cloned-moods-submodule moods-python # build MOODS 1.0.2.1 Python module

test: cosmo.coords.bed cosmo.counts.tab stats.tab  # run a basic test suite with 5 background scans
	for f in $^; do \
		diff $$f test/data/$$f || exit 1; \
	done
	@read -p $$'\nClean results from test run now? [Y/n] '; \
	if [[ -z $$REPLY || $$REPLY =~ [^Yy] ]]; then \
		make reallyclean || exit 1; \
	else \
		echo -e "\nOK, preserving outputs from test run"; \
		echo -e "Run $(BLD)make reallyclean$(RST) to clean them up later\n"; \
	fi

cosmo.coords.bed cosmo.counts.tab stats.tab:
	BGSCANS=1 ./example.sh

have-cloned-moods-submodule:
	@echo
	# $(BLD)checking if user did 'git clone --recursive'$(RST)
	@if [[ ! -d MOODS/src ]]; then \
		echo "$(ERROR): MOODS submodule missing" >&2; \
		echo "Please run 'git submodule init && git submodule update' and try again." >&2; \
		exit 1; \
	fi

# locate a Python library
pywhich = $(PYTHON) -c 'm = __import__("$(1)", globals(), locals(), [], 0); print m.__file__'

moods-python: have-python-27 have-pip have-python-venv moods-lib
	@echo
	@if ! $(call pywhich,MOODS) 2>&1 | grep -q $(VIRTUALENV) &>/dev/null; then \
		echo "$(BLD)Building MOODS Python module...$(RST)" >&2; \
		: get NumPy and SciPy if needed; \
		$(PYTHON) -m pip install -r requirements.txt || exit 1; \
		: very old versions of 'pip' might fail here; \
		cd MOODS/python && $(PYTHON) setup.py install || exit 1; \
		echo; \
	fi

have-python-27:
	@echo
	# $(BLD)Checking for Python 2.7.x...$(RST)
	@if [[ "$(PYTHONVER)" == 2.7.* ]]; then \
		echo "$(INFO) Found Python v$(PYTHONVER)" >&2; \
	else \
		echo "$(ERROR) Python interpreter missing or not required version 2.7.x." >&2; \
		exit 1; \
	fi

have-pip:
	@echo
	# $(BLD)Checking for pip...$(RST)
	@if ! $(PYTHON) -c 'import pip'; then \
		echo "$(ERROR): No pip found for the current Python interpreter." >&2; \
		exit 1; \
	fi

have-python-venv:
	@echo
	# $(BLD)Checking for Python virtualenv (or creating one)...$(RST)
	@if [[ ! -d $(VIRTUALENV) ]]; then \
		$(PYTHON) -m virtualenv $(VIRTUALENV); \
	fi
	@if ! which $(PYTHON) | grep -q $(VIRTUALENV)/bin/$(PYTHON) &>/dev/null; then \
		echo "$(NOTE) Please run `. $(VIRTUALENV)/bin/activate` first, then try again." >&2; \
	fi

moods-lib:
	@echo
	# $(BLD)Building MOODS C library...$(RST)
	cd MOODS/src && make

logdir:
	@echo
	# $(BOLD)making sure the log directory exists$(RST)
	test -d $(LOGDIR) || mkdir -p $(LOGDIR)

clean: # remove build/runtime logs
	-rm -f log/*.log log/*.err

reallyclean: clean # clean + remove COSMO output data (*.bed, *.tab*)
	-rm -f *.bed *.tab*

distclean: reallyclean  # reallyclean + remove venv, MOODS build, and uncompressed FASTA
	-cd MOODS/src && make clean
	-rm -rf MOODS/python/build
	-find MOODS -name "*.[oa]" -delete
	-rm -rf venv
	-rm example.fa
	@echo >&2; \
	echo "$(NOTE) Run 'deactivate' to deactivate the Python virtualenv." >&2

.PHONY: clean


##
##  internals you can safely ignore
##

# ANSI terminal colors (see 'man tput').
# Don't set these if there isn't a $TERM environment variable
# source: https://linuxtidbits.wordpress.com/2008/08/11/output-color-on-bash-scripts/
ifneq ($(strip $(TERM)),)
	BLD := $(shell tput bold)
	UL  := $(shell tput sgr 0 1)
	RED := $(shell tput setaf 1)
	GRN := $(shell tput setaf 2)
	YEL := $(shell tput setaf 3)
	BLU := $(shell tput setaf 4)
	MAG := $(shell tput setaf 5)
	CYA := $(shell tput setaf 6)
	RST := $(shell tput sgr0)
	ERR := $(BLD)$(RED)
	WRN := $(BLD)$(YEL)
	OK := $(BLD)$(GRN)
endif

ERROR := [$(ERR)ERROR$(RST)]
HINT := [$(MAG)$(BLD)HINT$(RST)]
NOTE := [$(WRN)NOTE$(RST)]
INFO := [$(CYA)INFO$(RST)]

# automatically generate 'make help' given the name of the Makefile
define AUTOGEN_HELP_PY
from __future__ import print_function
import re, sys
def esc(code):
	return '\033[%sm' % code
max = 0
groups = {}
targets = []
print("\n  %sMakefile targets - %s v%s%s\n" %
	(esc('0;4'), "$(TITLE)", "$(VERSION)", esc(0)))
with open(sys.argv[1], 'r') as makefile:
	for line in makefile:
		groupmatch = re.match(r'^(\w+):.*?# +\[(\w+)\] +(.*)$$', line)
		match = re.match(r'^(\w+):.*?# +(.*)$$', line)
		if groupmatch:
			target, group, help = groupmatch.groups()
			if len(target) > max:
				max = len(target)
			if not groups.get(group): groups[group] = []
			groups[group].append((target, help))
		elif match:
			target, help = match.groups()
			if len(target) > max:
				max = len(target)
			targets.append((target, help))
fmt = '    %smake %-' + str(max) + 's%s    %s'
if targets:
	for t in targets:
		print(fmt % (esc('1;34'), t[0], esc(0), t[1]))
if groups:
	for g in groups:
		print('\n  [%s]' % g)
		for t in groups[g]:
			print(fmt % (esc('1;34'), t[0], esc(0), t[1]))
print("\n  Homepage: %s%s%s\n" % (esc('0;36'), "$(HOMEPAGE)", esc(0)))
endef
export AUTOGEN_HELP_PY
