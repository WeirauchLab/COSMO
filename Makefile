PKGNAME=COSMO
VER=1.0

# ANSI terminal colors (see 'man tput').
# Don't set these if there isn't a $TERM environment variable
# source: https://linuxtidbits.wordpress.com/2008/08/11/output-color-on-bash-scripts/
ifneq ($(strip $(TERM)),)
BOLD=$(shell tput bold)
UL=$(shell tput sgr 0 1)
RED=$(shell tput setaf 1)
GREEN=$(shell tput setaf 2)
YELLOW=$(shell tput setaf 3)
BLUE=$(shell tput setaf 4)
RESET=$(shell tput sgr0)
endif

help:
	@echo
	@echo "${UL}${BOLD}${PKGNAME} Makefile help${RESET}"
	@echo
	@echo "  ${BOLD}${BLUE}clean${RESET}       - remove build/runtime logs"
	@echo
	@echo "  ${BOLD}${BLUE}reallyclean${RESET} - ${BLUE}clean${RESET} + remove COSMO output data (*.bed, *.tab*)"
	@echo
	@echo "  ${BOLD}${BLUE}distclean${RESET}   - ${BLUE}reallyclean${RESET} + remove locally-built MOODS library"
	@echo "                and uncompressed sample FASTA file"
	@echo
	@false

clean:
	-rm -f log/*.log log/*.err

reallyclean: clean
	-rm -f *.bed *.tab*

distclean: reallyclean
	-rm -rf MOODS example.fa

.PHONY: clean
