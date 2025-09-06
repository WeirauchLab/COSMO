TITLE = COSMO tasks
VERSION = $(shell sed -n "s/.*VERSION *= *['\"]\(.*\)['\"].*/\1/p" setup.py)
HOMEPAGE = https://tfinternal.research.cchmc.org/gitlab/weirauchlab/cosmo
LOGDIR = log
SHELL = bash
# this might be 'python2' on some systems like Ubuntu LTS; if that's the case,
# it's best to just create a virtualenv using that Python, then activate it
PYTHON = python
VIRTUALENV = venv
# how many dinuc-shuffled scans to run; specify in the environment to override
BGSCANS = 3

help:  # prints this help
	@$(PYTHON) -c "$$AUTOGEN_HELP_PY" "$(firstword $(MAKEFILE_LIST))"

moods: have-cloned-moods-submodule moods-python # build MOODS 1.0.2.1 Python module

# define (and export) CLEAN=1 in the environment or pass it on the `make`
# command line to *not* ask to clean up test results; instead, just do it
export CLEAN
test: cosmo.coords.bed cosmo.counts.tab stats.tab  # run a basic test suite
	@for f in $^; do \
		echo "$(INFO) Testing $$f vs. examples/output/$$f…" >&2; \
		( set -o pipefail; diff $$f examples/output/$$f | head ); \
		if (( $$? != 0 )); then \
			echo "$(WARN) $$f verification test failed." >&2; \
			failed=$$(( failed + 1 )); \
		fi; \
	done; \
	if (( failed )); then exit 1; fi
	
	@if [[ -z $$CLEAN ]]; then \
		read -p $$'\nClean results from test run now? [y/N] ' CLEAN; \
	fi; \
	if [[ -z $$CLEAN || $$CLEAN =~ ^[Nn] ]]; then \
		echo -e "\nOK, preserving outputs from test run."; \
		echo -e "Run 'make reallyclean' to clean them up later.\n"; \
	else \
		make reallyclean || exit 1; \
	fi; \

EXAMPLEFASTA = examples/example.40k.fa
cosmo.coords.bed: $(EXAMPLEFASTA)
	./cosmo.py -p examples/jpwm -fa $< -C

cosmo.counts.tab: $(EXAMPLEFASTA)
	./cosmo.py -p examples/jpwm -fa $<

bgscans = $(shell echo cosmo.counts.tab.{1..$(BGSCANS)})
stats.tab: cosmo.counts.tab $(bgscans)
	./cosmostats.py > $@
	@if [[ ! -s $@ ]]; then \
		echo "$(ERROR) Output file '$@' was empty. Can't continue." >&2; \
		rm $@; \
		exit 1; \
	fi

# for testing only; RANDSEED is incremented by the shuffle run number,
# otherwise the counts from each of the background scans will be the same
RANDSEED = 1000
cosmo.counts.tab.%: $(EXAMPLEFASTA)
	./cosmo.py -p examples/jpwm -fa $< -N $* --random-seed $$(( $(RANDSEED) + $* ))

examples/example%.fa:
	gunzip -dc $@.gz > $@

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

pyver := $(shell $(PYTHON) -c 'import sys; print("%d.%d.%d" % (sys.version_info.major, sys.version_info.minor, sys.version_info.micro))')

have-python-27:
	@echo
	# $(BLD)Checking for Python 2.7.x...$(RST)
	@if [[ "$(pyver)" == 2.7.* ]]; then \
		echo "$(INFO) Found Python v$(pyver)" >&2; \
	else \
		echo >&2; \
		echo "$(ERROR) Python interpreter missing or not required version 2.7.x." >&2; \
		echo >&2; \
		echo "Create and activate a virtualenv with your system's Python 2.7, e.g.:" >&2; \
		echo >&2; \
		echo "    python2 -m virtualenv venv" >&2; \
		echo >&2; \
		echo "then run this make target again." >&2; \
		echo >&2; \
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
	-rm -f examples/log/*.log examples/log/*.err
	-rmdir log examples/log

reallyclean: clean # clean + remove COSMO output data (*.bed, *.tab*)
	-rm -f *.bed *.tab*
	-rm -f examples/*.bed examples/*.tab*

distclean: reallyclean  # reallyclean + remove venv, MOODS build, and uncompressed FASTA
	-cd MOODS/src && make clean
	-rm -rf MOODS/python/build
	-find MOODS -name "*.[oa]" -delete
	-rm -rf venv
	-rm examples/example*.fa
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
WARN := [$(WRN)WARNING$(RST)]
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
