# COSMO v1.0

This script allows detection of enriched composite motifs in genomic sequence
data.


## PREREQUISITES

* Python 2.7.x, with the following packages installed
    * pip
    * virtualenv
    * numpy
    * scipy
    * [MOODS v1.0.2.1][moods] (included)
* JASPAR-formatted motifs
* [bedtools][]-derived FASTA DNA sequence file(s)

MOODS 1.9.x and Python 3 are not currently supported due to breaking changes
in the MOODS programming interface.

If you have multiple Python versions on your system, please ensure that the
first `python`, `pip`, and `virtualenv` in your [search path][path] are the
Python 2.7 versions. In a typical HPC environment, your module system (_e.g._
[Environment Modules][modules]) should handle this for you.


## INSTALLATION

1. Clone the source from GitLab (MOODS v1.0.2.1 is provided as a submodule):

        GITLAB=https://tfinternal.research.cchmc.org/gitlab
        git clone --recursive $GITLAB/cosmo/cosmo.git

    * as an alternative, download the [latest release tarball][targz]
      ([.zip][zip]) from GitLab, then unpack it into a local directory; see
      the [TROUBLESHOOTING](#troubleshooting) section for instructions on
      downloading and building MOODS from source

2. Switch into the fresh clone and build the MOODS C library and Python module

        cd cosmo
        make moods

3. Finally, run `./example.sh` within the "cosmo" directory. A typical
   invocation will look like this:

    ![Sample invocation of the `example.sh` script](img/example.sh.png)

    The sample script defaults to 100 background scan iterations, which may
    take a considerable amount of time to complete. Set `BGSCANS` in the
    environment if you wish to override this, like so:

        BGSCANS=3 ./example.sh

    Other `example.sh` defaults you can override in a similar fashion are
    `DISTANCE` (COSMO's `-d` option, default: 10), `THRESHOLD` (`-t`,
    default: 0.6), and `PRESERVELOGS` (set to `0` or `false` to remove
    execution logs upon completion). See below for COSMO's other command-line
    options.


## TROUBLESHOOTING

If `example.sh` has trouble auto-detecting your platform, architecture or
Python version (_e.g._ MOODS fails to build), here's how you can perform the
same tests of COSMO's operation manually.

### If you `git clone`d the repository

Did you forget to `git clone --recursive`? If you didn't do that, you don't
have the MOODS submodule. Do this:

    cd cosmo  # if not already there
    
    if test -d .git; then
        git submodule init && git submodule update
        make moods
    else
        echo "Oops, this isn't a Git repository." >&2
        echo "See \"TROUBLESHOOTING\" in 'README.md'." >&2
    fi

When you are reminded, run `source venv/bin/activate` to switch on the Python
virtual environment; this is how COSMO finds MOODS.

At this point, you should be able to run `./cosmo_v1.py` and get a usage
message (but no Python tracebacks).

Skip to "[Running on example FASTA](#running-on-example-fasta)."

### If you don't have Git and downloaded the .zip or tarball

You will need to download the MOODS sources from GitHub first:

    # remove existing 'MOODS' dir; it's where the Git submodule would go
    rmdir MOODS

    # or 'curl -LOJ' if you don't have 'wget'
    wget https://github.com/jhkorhonen/MOODS/archive/v1.0.2.1.zip
    unzip v1.0.2.1.zip && rm -i v1.0.2.1.zip

    # move the unpacked directory to 'MOODS', where the Makefile expects it
    mv MOODS-1.0.2.1 MOODS

You should be able to `make moods` at this point, and the Makefile will guide
you through the rest of the steps. But here's the completely manual way to
reproduce what the Makefile does:

    pushd MOODS/src
    make
    cd ../python
    python setup.py build
    popd

    # install NumPy and SciPy (MOODS dependencies)
    pip install -r requirements.txt

    # add just-built MOODS library to the PYTHONPATH for this login session
    pyplatform=$(python -c 'from distutils.util import get_platform
    print(get_platform())')
    moodspath=$PWD/MOODS/python/build/lib.$pyplatform
    export PYTHONPATH=$moodspath${PYTHONPATH:+:$PYTHONPATH}

At this point, you should be able to run `./cosmo_v1.py` and get a usage
message (but no Python tracebacks).

### Running on example FASTA

First, unpack the example FASTA file if necessary, and run several background
scans (in this example, three), specifying the `-C` (save coordinates) option
with the last one:

    test -f example.fa || gunzip example.fa.gz

    # vary these parameters to your liking (see PARAMETERS below)
    defaultargs="-fa example.fa -t 0.6 -d 10 -p ./jpwm"

    ./cosmo_v1.py $defaultargs &>1.log &
    ./cosmo_v1.py $defaultargs &>2.log &
    ./cosmo_v1.py $defaultargs -C &>3.log &

Wait for all the background jobs to finish, then run a coordinates scan, using
the results from the three background scans (`-N 3`):

    ./cosmo_v1.py $defaultargs -s -N 3

Finally, compute statistics for the three scans (`-N 3`):

    ./cosmostats_v1.py -N 3


## PARAMETERS

| Option     | Description
|------------|------------------------------------------------------------
| `-fa PATH` | path to FASTA sequence file
| `-t`       | log-odds score threshold (S/Smax) (default is `0.6`)
| `-P`       | (_optional_) pseudocount for MOODS to use (default is `1`)
| `-p PATH`  | path to JASPAR-format PWMs (default is `./jpwm/`)
| `-d`       | maximum allowed distance between motifs (default is `10`)
| `-s`       | boolean flag to dinucleotide shuffle the input sequence
| `-N`       | background run number
| `-C`       | boolean flag to save coordinates rather than counts


## USAGE

### Foreground scan

    ./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10

### Background scans

    ./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10 -s -N 1
    ./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10 -s -N 2
    ...
    ./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10 -s -N 100

### Coordinates scan

    ./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10 -C

### Statistics calculation

    ./cosmostats_v1.py -N 100


## OUTPUT

COSMO writes counts for stereopairs to the local directory in the file
`cosmo.counts.tab`.  Background scans (with parameters `-s` and `-N <x>`) are
placed into sequential files named `cosmo.counts.tab.<x>`).  Coordinates are
saved into a BED-formatted file `cosmo.coords.bed`


## CONTRIBUTORS

| Name            | Email                       | Contribution    |
|-----------------|-----------------------------|-----------------|
| Jeremy Riddell  | [riddeljr@mail.uc.edu][jr]  | Primary author  |
| Kevin Ernst     | [kevin.ernst@cchmc.org][ke] | Maintainer      |


## LICENSE

`FIXME`

[path]: https://en.wikipedia.org/wiki/PATH_(variable)
[modules]: http://modules.sourceforge.net/
[moods]: https://www.cs.helsinki.fi/group/pssmfind/
[bedtools]: http://bedtools.readthedocs.io/en/latest/
[targz]: https://tfinternal.research.cchmc.org/gitlab/cosmo/cosmo/repository/master/archive.tar.gz
[zip]: https://tfinternal.research.cchmc.org/gitlab/cosmo/cosmo/repository/master/archive.zip
[pip]: https://pip.pypa.io/en/stable/installing/
[jr]: mailto:riddeljr@mail.uc.edu
[ke]: kevin.ernst@cchmc.org
