# COSMO v1.0

This script allows detection of enriched composite motifs in genomic sequence
data.


## PREREQUISITES

* Python 2.7.x, with the following packages installed:
  * pip
  * virtualenv
  * numpy and scipy (accounted for by the instructions below)
  * [MOODS v1.0.2.1][moods] (ditto)
* JASPAR-formatted motifs
* [bedtools][]-derived FASTA DNA sequence file(s)

MOODS 1.9.x and Python 3 are not currently supported due to breaking changes
in the MOODS programming interface.

If you have multiple Python versions on your system, please ensure that the
first `python`, `pip`, and `virtualenv` in your [search path][path] are the
Python 2.7 versions. In a typical HPC environment, your module system (_e.g._
[Environment Modules][modules]) should handle this for you.


## QUICK START

1. Clone the source from GitLab (MOODS v1.0.2.1 is provided as a submodule):

        GITLAB=https://tfinternal.research.cchmc.org/gitlab
        git clone --recursive $GITLAB/cosmo/cosmo.git
        cd cosmo

    * as an alternative, download the [latest release tarball][targz]
      ([.zip][zip]) from GitLab, then unpack it into a local directory; see
      the [TROUBLESHOOTING](#troubleshooting) section for instructions on
      downloading and building MOODS from source

2. If you have Docker:

    docker run --rm -it -v .:/src cosmo
    docker run --rm -it -v .:/src cosmo make -j4 test


2. If you want to use a local Python installation instead, create a Python 2.7
   [virtualenv][], activate it, and install any necessary dependencies:

        # in the 'cosmo' subdirectory from 'git clone' above
        python -m virtualenv venv
        . venv/bin/activate
        
        # if you don't already have a 'pip' for Python 2.7.x
        wget https://bootstrap.pypa.io/pip/2.7/get-pip.py
        python get-pip.py
        pip install -r requirements.txt

   If you have some other Python 2.7 environment (such as Conda or Environment
   Modules), you probably know what to do on your own. If you have trouble with
   this step, try the Docker method described [below](#development-and-testing).

2. Next, build the MOODS C library and install the Python module into the
   virtualenv:

        # in the 'cosmo' subdirectory from 'git clone' above
        make moods

3. Finally, to make sure everything works, you run the `make test` target in
   the included [`Makefile`](Makefile) (assumes a Unix environment):

        make test -j4  # run parallel tasks on up to 4 CPU cores

See [DETAILED INSTALLATION](#detailed-installation) below if you're on Windows,
or if you have any problems with the instructions above or the running the
scripts.


### Local installation

Provided you've run the `make moods` target as prescribed above, you can
install `cosmo.py` and `cosmostats.py` as `cosmo` and `cosmostats`,
respectively, making them available in your shell's [search path][path]:

    # use either of these if you create a virtualenv as directed above
    python setup.py install
    pip install .

    # try either of these if the above yields an error about permissions
    python setup.py install --user
    pip install --user .

If if this is succesful, you can run `cosmo` or `cosmostats` from any directory
on your filesystem, without needing to specify the relative pathnames like
`./cosmo.py` in the examples below.


## USAGE

The [`cosmo.py`](cosmo.py) script does the actual scanning of the FASTA, and
[`cosmostats.py`](cosmostats.py) compiles summary statistics into a file
named `stats.tab` in your current working directory.

| Option     | Description
|------------|------------------------------------------------------------
| `-fa PATH` | path to FASTA sequence file
| `-t`       | log-odds score threshold (S/Smax) (default is `0.6`)
| `-P`       | (_optional_) pseudocount for MOODS to use (default is `1`)
| `-p PATH`  | path to JASPAR-format PWMs (default is `./jpwm`)
| `-d`       | maximum allowed distance between motifs (default is `10`)
| `-s`       | boolean flag to dinucleotide shuffle the input sequence
| `-N`       | background run number
| `-C`       | boolean flag to save coordinates rather than counts

### Outputs

COSMO writes counts for stereopairs to the local directory in the file
`cosmo.counts.tab`.  Background scans (with parameters `-s` and `-N <x>`) are
placed into sequential files named `cosmo.counts.tab.<x>`).  Coordinates (with
the `-C` option, explained below) are saved into a [BED][]-formatted file
`cosmo.coords.bed`

### Foreground scan

`cosmo.py` supports the following command-line options:

Example:

    # scan a .fa file in the current working directory, with a specific
    # log-odds threshold score and max. allowed distance between motifs
    # (the defaults are 0.6 and 10, respectively)
    ./cosmo.py -fa h3k27ac.fa -t 0.75 -d 20

### Background scans

Use `-N <number>` to start a specific number of background runs.
Use `-s` to dinucleotide-shuffle the input sequences.

    ./cosmo.py -fa h3k27ac.fa -s -N 1
    ./cosmo.py -fa h3k27ac.fa -s -N 2
    ⋮
    ./cosmo.py -fa h3k27ac.fa -s -N <n>

For a large number of background runs, this is best accomplished in a 'for'
loop in your favorite shell. Assuming Bash or Z shell:

    runs=100
    for (( i=1; i<=runs; i++ )); do
        ./cosmo.py -fa h3k27ac.fa -s -N $i
    done

### Coordinates scan

The `-C` option produces outputs that are genomic coordinates in BED format,
rather than counts:

    ./cosmo.py -fa h3k27ac.fa -C

### Statistics calculation

    # combine existing 'cosmo.counts.tab*' files into summary stats
    ./cosmostats.py -N 100

Combined with the example above, for 100 background scans:

    runs=100

    # assuming Bash or Z shell…
    for (( i=1; i<=runs; i++ )); do
        ./cosmo.py -fa h3k27ac.fa -s -N $i
    done

    ./cosmostats.py -N $runs

## DETAILED INSTALLATION

If you have problems with the [QUICK START](#quick-start) section (_e.g._ MOODS
fails to build), here's a fully-manual installation, spelled out.

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

At this point, you should be able to run `./cosmo.py` and get a usage
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

At this point, you should be able to run `./cosmo.py` and get a usage
message (but no Python tracebacks).

### Running on example FASTA

First, unpack the example FASTA file if necessary, and run several background
scans (in this example, three), specifying the `-C` (save coordinates) option
with the last one:

    cd examples
    test -f example.fa || gunzip example.fa.gz

    # vary these parameters to your liking (see USAGE section, above)
    defaultargs="-fa example.fa -t 0.6 -d 10 -p jpwm"

    ../cosmo.py $defaultargs &>1.log &
    ../cosmo.py $defaultargs &>2.log &
    ../cosmo.py $defaultargs -C &>3.log &

Wait for all the background jobs to finish, then run a coordinates scan, using
the results from the three background scans (`-N 3`):

    ../cosmo.py $defaultargs -s -N 3

Finally, compute statistics for the three scans (`-N 3`) and redirect this
output into a file named `stats.tab`:

    ../cosmostats.py -N 3 > stats.tab

The output `stats.tab` is tab-delimited, and may be viewed in the terminal,
_e.g._, with `column -t`, or opened in a spreadsheet program such as Excel,
Google Sheets, or LibreOffice.


## DEVELOPMENT AND TESTING

You can use the included `Dockerfile` to simplify local development; it builds
a minimal Debian Linux container with GNU Make and the latest release of Python
2.7 inside.

To use it, build the image locally, then bind mount the repository to `/src`
inside the container before running commands inside it. For example:

    docker build . -t cosmo

    # defaults to running `make help` to show Makefile tasks
    docker run --rm -it -v .:/src cosmo

    # run built-in tests, on 4 CPU cores
    docker run --rm -it -v .:/src cosmo make -j4 test

    # run COSMO programs directly, using the Python inside the container
    docker run --rm -it -v .:/src cosmo ./cosmo.py  # or ./cosmostats.py

If you're changing the code, make sure `make test` passes, or at least you can
figure out the reason _why_ it didn't pass (explain this in your commit
message), _before_ committing to the master/main branch.

For breaking changes —­_e.g._ removing a command-line option or changing the
input or output formats in a non-backward-compatible way — then you must:

1. increment the whole number (major) part of the version in the `Makefile`xi
2. …and `git tag vX.Y.Z`, where `X.Y.Z` is the new version number.

See [semver.org][] for more information.


## KNOWN ISSUES

1. FASTA inputs must have headers in `chrN:<start>-<end>` format, where `N` is
   the chromosome number; the nucleotide sequences must also be on a single line.
  * see [GitLab issue #5][issue5]
2. Given FASTA inputs above about 100 MB, COSMO takes a long time to finish;
   see [GitLab issue #7][issue7].
  * As a, workaround split large FASTAs into multiple files before the `>`
    sequence header lines and concatenate the results from COSMO.


## CONTRIBUTORS

| Name                  | Email                            | Role                   |
|-----------------------|----------------------------------|------------------------|
| Jeremy Riddell        | [riddeljr@mail.uc.edu][jr]       | Primary author         |
| Kevin Ernst           | [kevin.ernst@cchmc.org][ke]      | Contributor            |
| Matthew Weirauch, PhD | [matthew.weirauch@cchmc.org][mw] | Principal Investigator |


## LICENSE

The rights holders are Cincinnati Children's Hospital Medical Center and the
contributors.

The software's license is GPLv3, to match [that of MOODS][moodscopy]. See
[`LICENSE.txt`](LICENSE.txt) for details.

[path]: https://en.wikipedia.org/wiki/PATH_(variable)
[moods]: https://www.cs.helsinki.fi/group/pssmfind/
[bedtools]: http://bedtools.readthedocs.io/en/latest/
[virtualenv]: https://virtualenv.pypa.io/en/latest/user_guide.html
[path]: https://en.wikipedia.org/wiki/PATH_(variable)
[modules]: http://modules.sourceforge.net/
[targz]: https://tfinternal.research.cchmc.org/gitlab/cosmo/cosmo/repository/master/archive.tar.gz
[bed]: https://genome.ucsc.edu/FAQ/FAQformat.html#format1
[zip]: https://tfinternal.research.cchmc.org/gitlab/cosmo/cosmo/repository/master/archive.zip
[pip]: https://pip.pypa.io/en/stable/installing/
[jr]: mailto:riddeljr@mail.uc.edu
[ke]: kevin.ernst@cchmc.org
[moodscopy]: https://github.com/jhkorhonen/MOODS/blob/master/COPYING.GPLv3
[semver.org]: https://semver.org
[issue5]: https://tfinternal.research.cchmc.org/gitlab/weirauchlab/cosmo/-/issues/5
[issue7]: https://tfinternal.research.cchmc.org/gitlab/weirauchlab/cosmo/-/issues/7
