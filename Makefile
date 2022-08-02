PKGNAME = COSMO
VER = 1.0
LOGDIR = log
SHELL = bash
PYTHONVER := $(shell python -c 'import sys; print("%d.%d.%d" % (sys.version_info.major, sys.version_info.minor, sys.version_info.micro))')

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

ERROR := $(ERR)ERROR$(RST)
HINT := $(MAG)$(BLD)HINT$(RST)
NOTE := $(WRN)NOTE$(RST)
INFO := $(CYA)INFO$(RST)

help:
	@echo; \
	echo "${UL}${BLD}${PKGNAME} Makefile help${RST}"; \
	echo; \
	echo -e "  ${BLD}${BLU}make moods${RST}\n\tbuild MOODS 1.0.2.1 Python module"; \
	echo; \
	echo -e "  ${BLD}${BLU}make clean${RST}\n\tremove build/runtime logs"; \
	echo; \
	echo -e "  ${BLD}${BLU}make reallyclean${RST}\n\t${BLU}clean${RST} + remove COSMO output data (*.bed, *.tab*)"; \
	echo; \
	echo -e "  ${BLD}${BLU}make distclean${RST}\n\t${BLU}reallyclean${RST} + remove locally-built MOODS library and"; \
	echo -e "\tuncompressed sample FASTA file"; \
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

moods-python: have-python-27 have-pip have-python-venv moods-lib
	@echo
	# $(BLD)Building MOODS Python module...$(RST)
	source venv/bin/activate && \
		pip install -r requirements.txt  # get NumPy and SciPy if needed
		cd MOODS/python && \
		pip install .  # very old versions of 'pip' might fail here
	
	@echo; \
	echo "$(HINT): $(BLD)Make sure you 'source venv/bin/activate' before running COSMO.$(RST)" >&2

have-python-27:
	@echo
	# $(BLD)Checking for Python 2.7.x...$(RST)
	@if [[ "$(PYTHONVER)" == 2.7.* ]]; then \
		echo "$(INFO): Found Python v$(PYTHONVER)" >&2; \
	else \
		echo "$(ERROR): Python interpreter missing or not required version 2.7.x." >&2; \
		exit 1; \
	fi

have-pip:
	@echo
	# $(BLD)Checking for pip...$(RST)
	@if ! python -c 'import pip'; then \
		echo "$(ERROR): No pip found for the current Python interpreter." >&2; \
		exit 1; \
	fi

have-python-venv:
	@echo
	# $(BLD)Checking for Python virtualenv (or creating one)...$(RST)
	@if ! python -c 'import virtualenv'; then \
		echo "$(ERROR): No virtualenv found for the current Python interpreter." >&2; \
		exit 1; \
	fi
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
