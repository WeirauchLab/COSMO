#!/usr/bin/env bash

# abort script on *any* non-zero exit status, unset variables
set -eu

MYDIR=$( cd `dirname "$BASH_SOURCE"` && pwd )

# allow these to be set in the caller's environment
BGSCANS=${BGSCANS:-100}
DISTANCE=${DISTANCE:-10}
THRESHOLD=${THRESHOLD:-0.6}
COSMOARGS="-fa ./example.fa -t $THRESHOLD -d $DISTANCE -p ./jpwm/"

# reuse existing cosmo.coords.bed and cosmo.counts.tab?
REUSE=${REUSE:-}
LOGTAIL=${LOGTAIL:-5}
LOGDIR=${LOGDIR:-$MYDIR/log}
# preserve excution logs in $LOGDIR by default
PRESERVELOGS=${PRESERVELOGS:-1}
# prompt for things, use colors?
INTERACTIVE=${INTERACTIVE:-1}

declare -a pids
declare -i elapsed=0
declare -i ret
declare pythonver

if tty -s; then
    UL=$(tput sgr 0 1)
    BOLD=$(tput bold)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    WHITE=$(tput setaf 7)
    RESET=$(tput sgr0)
else
    # so we can use 'set -u' and not crash
    UL=;BOLD=;RED=;GREEN=;YELLOW=;BLUE=;MAGENTA=;WHITE=;RESET=
fi

# 'set -x' prompt string
PS4="  ${MAGENTA}>>${RESET} "

# suppress stderr and stdout
silently() { "$@" &>/dev/null; }

# just suppress stderr
quietly() { "$@" 2>/dev/null; }

# suppress stderr, prevent non-zero exit from terminating when '-e' is set
stoically() { quietly "$@" || true; }

# test for truthiness of the argument (YES|yes|yup|true|1)
is_set() { [[ $1 =~ ^(y|Y|[Tt][Rr][Uu]) || $1 -gt 0 ]]; }

# should we prompt for things?
interactive() { tty -s && is_set INTERACTIVE; }

killp() {
    # don't die in the middle of the die handler
    set +ex
    local sig=$1; shift
    echo -ne "\n${RESET}${MAGENTA}[Caught $sig]:${RESET} " >&2
    echo     "${MAGENTA}Killing child processes $*${RESET}" >&2
    set -x; kill $*; set +x
}

# clean log files on normal exit, unless PRESERVELOGS is set to yes/true/1
cleanup() {
    # don't die in the middle of the die handler
    set +ex
    local sig=$1; shift
    echo -ne "\n${RESET}${MAGENTA}[Caught $sig]:${RESET} " >&2
    if is_set "$PRESERVELOGS"; then 
        echo -ne "${YELLOW}PRESERVELOGS is set; logs from this session are " >&2
        echo     "saved in '$LOGDIR'${RESET}" >&2
    else
        echo -e "${MAGENTA}Cleaning up log files${RESET}" >&2
        set -x; rm -f "$LOGDIR"/*.log "$LOGDIR"/*.err; set +x
    fi
}

trap "cleanup EXIT; exit" EXIT

# platform / arch / Python version so we can add MOODS to PYTHONPATH
# see the "TROUBLESHOOTING" section of the README if autodetection fails
pythonver=$(python -c '
from platform import uname, python_version_tuple as ver

print ("%(platform)s-%(arch)s-%(release)s"
       % { "platform": uname()[0].lower(),
           "arch":     uname()[5],
           "release":  ".".join([str(x) for x in ver()[:2]]) });
')

test -d "$LOGDIR" || mkdir "$LOGDIR"

# if necessary, build isolated copy of MOODS from source
if [ ! -f ./MOODS/python/build/lib.$pythonver/MOODS/_cmodule.so ]; then
    echo -ne "\n${BOLD}Unpacking MOODS sources...${RESET} "
    tar xzf MOODS-*.tar.gz
    echo -ne "${BOLD}${GREEN}done.${RESET}\n"

    silently pushd MOODS/src
    echo -ne "${BOLD}Building and installing to ./MOODS...${RESET} "
    make -j4 >"$LOGDIR/build.log" 2>"$LOGDIR/build.err"

    cd ../python
    python setup.py build >>"$LOGDIR/build.log" 2>>"$LOGDIR/build.err"
    echo -ne "${BOLD}${GREEN}done.${RESET}\n"

    silently popd
fi

export PYTHONPATH=${PYTHONPATH:-}:./MOODS/python/build/lib.$pythonver

# Don't regenerate the counts/coords files if REUSE=yes/true/1
if is_set "$REUSE" && [ -f 'cosmo.coords.bed' -a -f 'cosmo.counts.tab' ]; then
    echo -ne "\n${YELLOW}REUSE is set; re-using existing results "
    echo -e "('cosmo.coords.bed' and 'cosmo.counts.tab')${RESET}\n"
else
    echo -e "\n${BOLD}Running COSMO analyses...${RESET}\n"

    # extract the sample FASTA if necessary
    test -f ./example.fa || gzip -dc < example.fa.gz > example.fa

    # semicolon causes a syntax error after a '&'; see https://tf.cchmc.org/s/c2mri
    set -x
    ./cosmo_v1.py $COSMOARGS &> "$LOGDIR/bgtask1.log"    & pids[0]=$!
    ./cosmo_v1.py $COSMOARGS &> "$LOGDIR/bgtask2.log"    & pids[1]=$!
    ./cosmo_v1.py $COSMOARGS -C &> "$LOGDIR/bgtask3.log" & pids[2]=$!

    # now, trap CTRL+C to kill off background processes before we exit
    trap "killp SIGINT ${pids[*]}; exit 1" SIGINT

    # wait a sec before turning off trace so all the bg jobs show up in the output
    sleep 1
    set +x

    echo -ne "\n${BOLD}${UL}${YELLOW}NOTE${RESET}: ${BOLD}If they misbehave, you "
    echo -e  "can terminate these jobs with the command${RESET}\n"
    echo -e  "      ${BOLD}${BLUE}kill ${pids[*]}${RESET}\n"

    if interactive; then
        read -t 5 -p "${BOLD}Press ENTER to continue (or wait 5s)...${RESET} " \
            JUNK || true  # else script will terminate because of 'set -e'
    fi

    # tail logfiles while we're waiting for the background jobs to finish
    while (( 1 )); do
        if interactive; then clear; fi # only works when TERM is set

        echo -ne "${BOLD}Awaiting completion of PIDs ${BLUE}${pids[*]}${WHITE}; "
        echo -n  "$(( elapsed/60 ))m elapsed${RESET} "
        echo     "(${YELLOW}CTRL+C to quit${RESET})"

        if interactive; then 
            echo -ne "\n${UL}Last $LOGTAIL lines of background task #1, 2, 3 "
            echo -e  "log files, respectively:${RESET}\n"

            # suppress column's griping about 'line too long' and non-zero exit
            # (will terminate script if 'set -e' is set)
            stoically \
                column -c120 <(quietly tail -$LOGTAIL "$LOGDIR/bgtask1.log") \
                             <(quietly tail -$LOGTAIL "$LOGDIR/bgtask2.log") \
                             <(quietly tail -$LOGTAIL "$LOGDIR/bgtask3.log")
        fi

        if interactive; then
            sleep 5; elapsed=$(( elapsed+=5 ))
        else
            sleep 60; elapsed=$(( elapsed+=60 ))
        fi

        # keep the outer (while) loop going unless /none/ of the PIDs are found
        for j in {0..2}; do silently ps -p ${pids[$j]} && continue 2; done

        # otherwise no more background jobs; untrap CTRL+C and get out
        trap - 2
        echo -e "\n"
        break
    done
fi # if REUSE was set and cosmo.coords.bed and cosmo.counts.tab exist

# brace expansion happens before variable interpolation (so 'for i in {1..$var}'
# won't work), need an arithmetic 'for' loop; see https://tf.cchmc.org/s/zvu1t
for (( i = 1; i <= $BGSCANS; i++ )); do
    echo -ne "${BOLD}Running background scan iteration #$i / "
    echo -n  "$BGSCANS${RESET}... "

    echo "==== Commencing scan iteration #$i/$BGSCANS at $(date -R)" \
        >>"$LOGDIR/bgscans.log"

    set +e; ./cosmo_v1.py $COSMOARGS -s -N $i &>>"$LOGDIR/bgscans.log"
    ret=$?
    set -e

    if (( $ret )); then
        echo     "${BOLD}${RED}failed!${RESET}"
        echo -ne "Error in iteration #$i; check '$LOGDIR/bgscans.log'\n" >&2

        echo  "!!!! Failed iteration #$i/$BGSCANS at $(date -R)" \
            >>"$LOGDIR/bgscans.log"
    else
        echo "${GREEN}done.${RESET}"
        echo "==== Finished iteration #$i/$BGSCANS at $(date -R)" \
            >>"$LOGDIR/bgscans.log"
    fi
done

echo -ne "\n${BOLD}Collecting stats...${RESET} "

# had some issues with SciPy errors here
set +e; ./cosmostats_v1.py -N $BGSCANS >stats.tab 2>"$LOGDIR/stats.err"
ret=$?
set -e

if (( $ret )); then
    echo    "${BOLD}${RED}failed!${RESET}"
    echo -e "Error computing stats; check '$LOGDIR/stats.err'\n" >&2
else
    echo -e "${GREEN}done.${RESET}\n"
fi


# end of example.sh
