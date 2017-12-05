#!/bin/bash

# abort script on any non-zero exit status
set -e

trap 'rm -f log/build.log log/build.err log/bgtask?.log log/bgscans.log' 0

declare -a pids

# allow these to be set in the caller's environment
BGSCANS=${BGSCANS:-100}
DISTANCE=${DISTANCE:-10}
THRESHOLD=${THRESHOLD:-0.6}
COSMOARGS="-fa ./example.fa -t $THRESHOLD -d $DISTANCE -p ./jpwm/"
LOGTAIL=${LOGTAIL:-5}

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
fi

PS4="    ${MAGENTA}>>${RESET} "

# suppress stderr and stdout
silently() { "$@" &>/dev/null; }

# just suppress stderr
quietly() { "$@" 2>/dev/null; }

killp() {
    echo -ne "\n\n${RESET}${BOLD}Received SIGINT;${RESET} " >&2
    echo -e "${BOLD}${RED}killing child processes $*${RESET}\n" >&2
    set -x; kill $*; set +x
}

# platform / arch / Python version so we can add MOODS to PYTHONPATH
# set PYTHONPATH manually and re-run this script if detection fails
pythonver=$(python -c '
from platform import uname, python_version_tuple as ver

print ("%(platform)s-%(arch)s-%(release)s"
       % { "platform": uname()[0].lower(),
           "arch":     uname()[5],
           "release":  ".".join([str(x) for x in ver()[:2]]) });
')

# if necessary, build isolated copy of MOODS from source
if [ ! -f ./MOODS/python/build/lib.$pythonver/MOODS/_cmodule.so ]; then
    echo -ne "\n${BOLD}Unpacking and building MOODS from source...${RESET} "
    silently pushd .
    tar xzf MOODS-*.tar.gz
    cd MOODS/src
    make -j4 >log/build.log 2>log/build.err
    cd ../python
    python setup.py build >>log/build.log 2>>log/build.err
    silently popd
    echo -ne "${BOLD}${GREEN}done.${RESET}\n"
fi

export PYTHONPATH=$PYTHONPATH:./MOODS/python/build/lib.$pythonver

echo -e "\n${BOLD}Running COSMO analyses...${RESET}\n"

# extract the sample FASTA if necessary
test -f ./example.fa || gzip -dc < example.fa.gz > example.fa

# semicolon causes a syntax error after a '&'; see https://tf.cchmc.org/s/c2mri
set -x
./cosmo_v1.py $COSMOARGS &> log/bgtask1.log    & pids[0]=$!
./cosmo_v1.py $COSMOARGS &> log/bgtask2.log    & pids[1]=$!
./cosmo_v1.py $COSMOARGS -C &> log/bgtask3.log & pids[2]=$!
set +x

sleep 1  # give them a sec to finish backgrounding
echo -ne "\n${BOLD}${UL}${YELLOW}NOTE${RESET}: ${BOLD}If they misbehave, you "
echo -e "can terminate these jobs with the command${RESET}\n"
echo -e "      ${BOLD}${BLUE}kill ${pids[*]}${RESET}\n"

# trap CTRL+C and kill background processes before we exit
trap "killp ${pids[*]}; exit 1" 2

read -t 5 -p "${BOLD}Press ENTER to continue (or wait 5s)...${RESET} " JUNK \
    || true  # because of the 'set -e' above

elapsed=0
# tail logfiles while we're waiting for the background jobs to finish
while (( 1 )); do
    clear
    echo -ne "${BOLD}Checking every 5s for completion of "
    echo -ne "PIDs ${BLUE}${pids[*]}${WHITE}...${RESET} "
    echo -e "(${YELLOW}CTRL+C to quit${RESET})\n"

    echo -n "${UL}Last $LOGTAIL lines of background task #1, 2, 3 log files; "
    echo -e "elapsed time $(( elapsed/60 ))m${RESET}\n"

    # suppress column's griping about 'line too long'
    quietly column -c120 <(quietly tail -$LOGTAIL log/bgtask1.log) \
                         <(quietly tail -$LOGTAIL log/bgtask2.log) \
                         <(quietly tail -$LOGTAIL log/gbtask3.log) || true

    sleep 5
    elapsed=$(( elapsed+=5 ))

    # keep the outer (while) loop going unless /none/ of the PIDs are found
    for j in {1..3}; do silently ps -p ${pids[$j]} && continue 2; done

    # otherwise no more background jobs; untrap CTRL+C and get out
    trap - 2
    break
done

# brace expansion happens before variable interpolation (so 'for i in {1..$var}'
# won't work), need an arithmetic 'for' loop; see https://tf.cchmc.org/s/zvu1t
for (( i = 1; i <= $BGSCANS; i++ )); do
    echo -ne "\n${BOLD}Running background scan iteration #$i / "
    echo -n "$BGSCANS${RESET}... "

    echo "==== Commencing scan iteration #$i/$BGSCANS at $(date -R)" \
        >>log/bgscans.log

    ./cosmo_v1.py $COSMOARGS -s -N $i &>>log/bgscans.log

    echo "==== Finished iteration #$i/$BGSCANS at $(date -R)" \
        >>log/bgscans.log

    echo -e "${GREEN}done.${RESET}"
done

echo -ne "\n${BOLD}Collecting stats...${RESET} "
./cosmostats_v1.py -N $BGSCANS >stats.tab 2>stats.err
echo -e "${GREEN}done.${RESET}\n\n"
