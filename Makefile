PKGNAME = COSMO
VER = 1.0
LOGDIR = log
SHELL = bash

# ANSI terminal colors (see 'man tput').
# Don't set these if there isn't a $TERM environment variable
# source: https://linuxtidbits.wordpress.com/2008/08/11/output-color-on-bash-scripts/
ifneq ($(strip $(TERM)),)
	BLD:=$(shell tput bold)
	UL := $(shell tput sgr 0 1)
	RED := $(shell tput setaf 1)
	GRN := $(shell tput setaf 2)
	YEL := $(shell tput setaf 3)
	BLU := $(shell tput setaf 4)
	MAG := $(shell tput setaf 5)
	RST := $(shell tput sgr0)
	ERR := $(BLD)$(RED)
	WRN := $(BLD)$(YEL)
	OK := $(BLD)$(GRN)
endif

ERROR := $(ERR)ERROR$(RST)
HINT := $(MAG)$(BLD)HINT$(RST)
NOTE := $(WRN)NOTE$(RST)

help:
	@echo; \
	echo "${UL}${BLD}${PKGNAME} Makefile help${RST}"; \
	echo; \
	echo "  ${BLD}${BLU}moods${RST}       - build MOODS 1.0.2.1 Python module"; \
	echo; \
	echo "  ${BLD}${BLU}clean${RST}       - remove build/runtime logs"; \
	echo; \
	echo "  ${BLD}${BLU}reallyclean${RST} - ${BLU}clean${RST} + remove COSMO output data (*.bed, *.tab*)"; \
	echo; \
	echo "  ${BLD}${BLU}distclean${RST}   - ${BLU}reallyclean${RST} + remove locally-built MOODS library"; \
	echo "                and uncompressed sample FASTA file"; \
	echo; \

moods: have-cloned-moods-submodule moods-python

have-cloned-moods-submodule:
	@echo
	# $(BLD)checking if user did 'git clone --recursive'$(RST)
	@if [[ ! -d MOODS/src ]]; then \
		echo "$(ERROR): MOODS submodule missing" >&2; \
		echo "Please run 'git submodule init && git submodule update' and try again." >&2; \
		exit 1; \
	fi

moods-python: have-python-venv moods-lib
	@echo
	# $(BLD)Building MOODS Python module...$(RST)
	source venv/bin/activate && \
		pip install -r requirements.txt  # get NumPy and SciPy if needed
		cd MOODS/python && \
		python setup.py install  # 'pip install' doesn't work here for some reason
	
	@echo; \
	echo "$(HINT): $(BLD)Make sure you 'source venv/bin/activate' before running COSMO.$(RST)" >&2

have-python-venv:
	@echo
	# $(BLD)checking for Python virtualenv (or creating one)...$(RST)
	@if [[ ! -d venv ]]; then \
		virtualenv venv; \
	fi; \

moods-lib:
	@echo
	# $(BLD)Building MOODS C library...$(RST)
	cd MOODS/src && make

logdir:
	@echo
	# $(BOLD)making sure the log directory exists$(RST)
	test -d $(LOGDIR) || mkdir -p $(LOGDIR)

clean:
	-rm -f log/*.log log/*.err

reallyclean: clean
	-rm -f *.bed *.tab*

distclean: reallyclean
	-cd MOODS/src && make clean
	-rm -rf MOODS/python/build
	-rm -rf venv
	-rm example.fa
	
	@echo >&2; \
	echo "$(NOTE): Run 'deactivate' to deactivate the Python virtualenv." >&2

.PHONY: clean
