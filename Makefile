TITLE = COSMO tasks
VERSION = $(shell sed -n "s/.*VERSION *= *['\"]\(.*\)['\"].*/\1/p" setup.py)
HOMEPAGE = $(shell sed -n "s/.*PROJECTHOME *= *['\"]\(.*\)['\"].*/\1/p" setup.py)
LOGDIR = log
SHELL = bash
# this might be 'python2' on some systems like Ubuntu LTS; if that's the case,
# it's best to just create a virtualenv using that Python, then activate it
PYTHON = python
# how many dinuc-shuffled scans to run; specify in the environment to override
BGSCANS = 3
# where to 'make install' to
# see also 'MODULEDESTROOT', 'MODULEFILEDEST', and the 'module:' target, below
PREFIX = /usr/local


help:  # print this help
	@$(PYTHON) -c "$$AUTOGEN_HELP_PY" "$(firstword $(MAKEFILE_LIST))"

moods: have-cloned-moods-submodule moods-python # build MOODS 1.0.2.1 Python module

# define (and export) CLEAN=1 in the environment or pass it on the `make`
# command line to *not* ask to clean up test results; instead, just do it
export CLEAN
test: deps cosmo.coords.bed cosmo.counts.tab stats.tab  # run a basic test suite on COSMO
	@echo
	# testing COSMO outputs to examples/output/*
	@for f in $(filter-out deps,$^); do \
		if [[ ! -s $$f ]]; then \
			echo -e "\n$(ERROR) $$f is empty! Try 'make reallyclean' to start over.\n" >&2; \
			exit 1; \
		fi; \
		echo -e "$(INFO) $$f vs. examples/output/$$f…" >&2; \
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
		echo -e "\n$(ERROR) Output file '$@' was empty. Can't continue.\n" >&2; \
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

# install moods into the default location, probably the active virtualenv
moods-python: have-python-27 have-pip moods-lib
	@echo
	# checking for MOODS Python module…
	@if ! $(call pywhich,MOODS) 2>&1 | grep MOODS; then \
		echo -e "\n# $(BLD)Building MOODS Python module...$(RST)" >&2; \
		: very old versions of 'pip' might fail here; \
		cd MOODS/python && $(PYTHON) setup.py install || exit 1; \
	fi

deps: moods-python
	@echo
	# checking for COSMO's dependencies
	@if ! $(call pywhich,numpy) 2>&1 | grep numpy; then \
		echo -e "\n# $(BLD)Installing dependencies$(RST)" >&2; \
		$(PYTHON) -m pip install -r requirements.txt || exit 1; \
	fi

pyver := $(shell $(PYTHON) -c 'import sys; print("%d.%d.%d" % (sys.version_info.major, sys.version_info.minor, sys.version_info.micro))')

have-python-27:
	@echo
	# $(BLD)Checking for Python 2.7.x...$(RST)
	@if [[ "$(pyver)" == 2.7.* ]]; then \
		echo "$(INFO) Found Python v$(pyver)" >&2; \
	else \
		echo -e "\n$(ERROR) Python interpreter missing or not required version 2.7.x.\n" >&2; \
		exit 1; \
	fi

have-pip:
	@echo
	# $(BLD)Checking for pip...$(RST)
	@if ! $(PYTHON) -c 'import pip'; then \
		echo -e "\n$(ERROR): No pip found for the current Python interpreter." >&2; \
		echo -e "         Maybe you need to create/activate a virtualenv? See the README.\n" >&2; \
		exit 1; \
	fi

moods-lib: MOODS/src/libpssm.a
MOODS/src/libpssm.a:
	@echo
	# $(BLD)Building MOODS C library...$(RST)
	cd MOODS/src && make

install: have-python-27 moods-lib  # [install] install MOODS and COSMO to /usr/local [override with PREFIX=]
	@echo
	# installing the MOODS library
	cd MOODS/python && $(PYTHON) setup.py install --prefix="$(PREFIX)"
	
	@# for some reason, PYTHONPATH has to be defined here, but not for MOODS
	@# I think it's because COSMO installs scripts/entrypoints? ¯\_(ツ)_/¯
	# installing COSMO itself
	PYTHONPATH="$(PREFIX)/lib/python2.7/site-packages" python setup.py install --prefix="$(PREFIX)"

	# symlink 'cosmo' to 'cosmo.py' and likewise for 'cosmostats.py'
	cd $(PREFIX)/bin && \
	ln -sf cosmo.py cosmo && \
	ln -sf cosmostats.py cosmostats
	
	# copying example PWMs
	mkdir -p $(PREFIX)/lib/cosmo
	cp -r examples/jpwm $(PREFIX)/lib/cosmo

# where to install COSMO as a module, and where to put the modulefile
MODULEDESTROOT = $(if $(LABLOCALMODULES),$(LABLOCALMODULES),$(PREFIX)/modules)
MODULEFILEDEST = $(MODULEDESTROOT)/modulefiles/cosmo
# update this as appropriate for your local setup
MODULEPYTHON27MOD = python/2.7.18-wrl
MODULEVERSION = $(VERSION)
MODULEHOMEPAGE = $(HOMEPAGE)
# set to an empty string to *not* ask to set the new modulefile as the default
ASKDEFAULTMODULEVER = 1

module: modulefile  # [install] install COSMO as an Environment Modules module
	@# dummy check, because I would tend to do this…
	@if which $(PYTHON) 2>/dev/null | grep -qE 'v?env/bin'; then \
		echo -e "\nYou should deactivate the virtualenv before running this step:" >&2; \
		echo -e "\n    $$ deactivate" >&2; \
		echo -e "\nThen try running 'make $@' again." >&2; \
		exit 1; \
	fi
	@echo
	# installing the COSMO modulefile
	install -m644 modulefile/modulefile.tcl $(MODULEFILEDEST)/$(VERSION)

ifneq ($(ASKDEFAULTMODULEVER),)
	@read -p $$'\nSet version $(VERSION) as the new default module? [y/N] '; \
	if [[ $$REPLY =~ ^[Yy] ]]; then \
		install -m644 modulefile/dot-version.tcl $(MODULEFILEDEST)/.version; \
		echo; \
	fi
endif

	@# installing MOODS and COSMO
	mkdir -p $(MODULEDESTROOT)/cosmo/$(VERSION)
	make install PREFIX=$(MODULEDESTROOT)/cosmo/$(VERSION)

# note that this will catch a few of Environment Modules *own* variables, too…
M4DEFS = $(foreach V,$(filter MODULE%,$(.VARIABLES)),-D $V='$($V)')
modulefile: modulefile/modulefile.tcl modulefile/dot-version.tcl  # update the Environment Modules modulefile
modulefile/%: modulefile/%.m4
	@echo
	# generating the COSMO Environment Modules modulefile
	m4 -P $(M4DEFS) $< > $@


clean: # [clean] remove build/runtime detritus + logs
	-rm log/*.log log/*.err
	-rm examples/log/*.log examples/log/*.err
	-rmdir log examples/log

reallyclean: clean # [clean] clean + remove COSMO output data (*.bed, *.tab*)
	-rm *.bed *.tab*
	-rm examples/*.bed examples/*.tab*

distclean: reallyclean  # [clean] reallyclean + clean MOODS, remove uncompressed FASTAs
	-cd MOODS/src && make clean
	-rm -r MOODS/python/build
	-find MOODS -name "*.[oa]" -delete
	-rm examples/example*.fa
	-rm *.pyc
	-rm -r build dist *.egg-info

envclean: distclean  # [clean] distclean + remove the virtualenv
	-rm -r venv
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
grouplist = []
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
			if not groups.get(group):
				grouplist.append(group)
				groups[group] = []
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
	for g in grouplist:
		print('\n  [%s]' % g)
		for t in groups[g]:
			print(fmt % (esc('1;34'), t[0], esc(0), t[1]))
print("\n  Homepage: %s%s%s\n" % (esc('0;36'), "$(HOMEPAGE)", esc(0)))
endef
export AUTOGEN_HELP_PY
