# COSMO - Composite Motif Scanner

This script allows detection of enriched composite motifs in genomic sequence
data.


## PREREQUISITES

* Python 2.7.x, with the following packages installed:
    * pip
    * numpy and scipy (accounted for by the instructions below)
    * [MOODS v1.0.2.1][moods] (ditto)
* JASPAR-formatted motifs
* [bedtools][]-derived FASTA DNA sequence file(s)

Newer versions of MOODS and Python are not supported. PRs to add this support,
which pass the [included tests](#development-and-testing), would be welcome.

If you have multiple Python versions on your system, please ensure that the
first `python` and `pip` in your [search path][path] are the Python 2.7
versions. In a typical HPC environment, your module system (_e.g._ [Environment
Modules][modules]) should handle this for you.


## QUICK START

1. Clone the source from GitLab (MOODS v1.0.2.1 is provided as a submodule):

        git clone --recursive https://github.com/weirauchlab/cosmo.git
        cd cosmo

    If you already cloned the repository without reading this section first, no
    worries, just run this inside the new clone:

        git submodule init && git submodule update

    As an alternative, download the [latest release archive][zip] from GitHub,
    then unpack it into a local directory; see the [DETAILED
    INSTALLATION](#detailed-installation) section for instructions on
    downloading and building MOODS from source

2. If you have [Docker][] or [Podman][] available (substitute `podman` for
   `docker` below):

        docker build . -t cosmo  # be patient, builds Python 2.7 from source!
        docker run --rm -it cosmo cosmo --help
        docker run --rm -it cosmo cosmostats --help

    See the [DEVELOPMENT AND TESTING](#development-and-testing) section for
    more details.

3. If you want to use a local Python installation instead, you'll probably need
   to load a [module][modules], or build Python 2.7 from source. If you don't
   already have a version of pip that works with Python 2.7, install it:

        wget https://bootstrap.pypa.io/pip/2.7/get-pip.py
        python get-pip.py

    > **Important tip:**<br>
    > At this point, stop and make sure that `python --version` and `pip
    > --version` both report "2.7" in their output; that is, that the first
    > `python` and `pip` in your [search path][path] are _definitely_ the
    > Python 2.7 versions.

    To avoid having to install COSMO's dependencies at the system level, use
    pip to install [virtualenv][] if necessary, then create a Python virtual
    environment and activate it:

        # in the 'cosmo' subdirectory from 'git clone' above
        python -m virtualenv venv
        . venv/bin/activate
        
    If you have some other Python 2.7 environment (such as Conda or Environment
    Modules), you probably know what to do on your own. If you have trouble with
    this step, try the Docker method described [below](#development-and-testing).

4. Next, build the MOODS C library and install COSMO's other Python
   dependencies:

        make deps

    If you get a "permission denied" error here, follow the steps above to
    create a virtualenv, activate it, then try again.

5. Finally, to make sure everything works, you run the `make test` target in
   the included [`Makefile`](Makefile) (assumes a Unix environment):

        make test -j4  # run parallel tasks on up to 4 CPU cores

See [DETAILED INSTALLATION](#detailed-installation) below if you have any
problems with the instructions above or the running the scripts.

### Local installation

If you have MOODS and [COSMO's dependencies](requirements.txt) already
installed, you can just copy `cosmo.py` and `cosmostats.py` to a directory in
your shell's [search path][path] and call it good. However there's an `install`
target in the included [Makefile](Makefile) that will handle the details for
you.

If you are on a Unix/Linux system, run `make install`. The default installation
prefix is `/usr/local` (with scripts being installed to `/usr/local/bin`), so
you will likely need to become root with `sudo` or similar.

A simpler option is to install to your home directory:

    make install PREFIX=$HOME/.local

Most Linux distributions already include `~/.local/bin` in your search path by
default. You may need to log out and back in again for this to take effect. How
to update your shell's `PATH` variable is beyond the scope here.

If this is successful, you can run `cosmo` or `cosmostats` from any directory
on your filesystem, without needing to specify the relative pathnames like
`./cosmo.py` in the examples below.

Windows is not currently supported by [the method we presently use in our
`setup.py`][scripts]. However, if you have success building MOODS on Windows
and would like to have a go at getting COSMO working, too, a patch or pull
request would be welcome.


## USAGE

The [`cosmo.py`](cosmo.py) script does the actual scanning of the FASTA, and
[`cosmostats.py`](cosmostats.py) compiles summary statistics into a file
named `stats.tab` in your current working directory.

`cosmo.py` supports the following command-line options:

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

Example: scan a FASTA file in the current working directory, with a specific
log-odds threshold score and maximum allowed distance between motifs:

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

    # if required, create a Python 2.7 virtualenv and activate it
    python -m virtualenv venv && source venv/bin/activate
    
    if test -d .git; then
        git submodule init && git submodule update
        make deps
    else
        echo "Oops, this isn't a Git repository." >&2
    fi

If your Python is in a virtual environment, **make sure it is activated**,
otherwise the `make deps` step will not do the right thing.

At this point, you should be able to run `./cosmo.py` and get a usage
message (with no Python tracebacks). Skip to "[Running on example
FASTA](#running-on-example-fasta)."

### If you don't have Git and downloaded the .zip or tarball

You will need to download the MOODS sources from GitHub first:

    # remove existing 'MOODS' dir; it's where the Git submodule would go
    rmdir MOODS

    # or 'curl -LOJ' if you don't have 'wget'
    wget https://github.com/jhkorhonen/MOODS/archive/v1.0.2.1.zip
    unzip v1.0.2.1.zip && rm -i v1.0.2.1.zip

    # move the unpacked directory to 'MOODS', where the Makefile expects it
    mv MOODS-1.0.2.1 MOODS

Again, if your Python is in a virtual environment, **make sure it is
activated**.  You should be able to `make deps` at this point, and the
Makefile will guide you through the rest of the steps. But here's the
completely manual way to reproduce what the Makefile does:

    pushd MOODS/src
    make
    cd ../python
    python setup.py install
    popd

    # install NumPy and SciPy (COSMO's dependencies)
    pip install -r requirements.txt

At this point, you should be able to run `./cosmo.py` and get a usage
message (with no Python tracebacks).

### Running on example FASTA

First, unpack the example FASTA file if necessary, and run several background
scans (in this example, three):

    cd examples
    test -f example.fa || gunzip example.fa.gz

    # vary these parameters to your liking (see USAGE section, above)
    args="-fa example.fa -t 0.6 -d 10 -p jpwm"

    # the '&>' syntax assumes Bash or Z shell; it combines stdout and stderr
    ../cosmo.py $args -s -N 1 &>1.log &
    ../cosmo.py $args -s -N 2 &>2.log &
    ../cosmo.py $args -s -N 3 &>2.log &

Run an additional scan with the `-C` (save coordinates) option, so you can see
what that output looks like:

    ../cosmo.py $args -C &>coords.log &

Finally, compute statistics for the three scans (`-N 3`) and redirect this
output into a file named `stats.tab`:

    ../cosmostats.py -N 3 > stats.tab

The output `stats.tab` is tab-delimited, and may be viewed in the terminal,
_e.g._, with `column -t`, or opened in a spreadsheet program such as Excel,
Google Sheets, or LibreOffice.

### Defining a system-wide path to the PWM files

If you define an [environment variable][envvar] named `COSMO_PWMDIR`, it
becomes the default for the `-p` / `--pwmdir` option. Typically, this would be
an absolute path starting at `/`, but you can get creative.

This can be useful, for example, when used with [Environment Modules][modules],
to define a system-wide directory containing the JASPAR-formatted matrices for
all users.

This variable can also be defined in your login scripts, _e.g._ your
`~/.bash_profile` or `~/.profile`; note that the variable set by a `setenv`
statement in a [modulefile][] would still take precedence in that case.

### Creating an Environment Modules / Lmod module

The short answer is:

    make module
    
For members of the Weirauch Lab, this will just do the Right Thing™. To avoid
errors here, purge all your modules, deactivate any virtualenvs, and re-load
`python/2.7.18-wrl` or a comparable Python 2.7.x  module.

For others, this will install the module to `/usr/local/modules/cosmo/x.y.z`
(where `x.y.z` is the currently checked-out version of COSMO) and put the
modulefile in `/usr/local/modules/modulefiles/cosmo/x.y.z`.

For you to be able to `module load cosmo`, you will need to have run `module
use /usr/local/modules/modulefiles` in your current shell session or login
scripts, or to have added that to your sitewide configuration files, _e.g._
`/etc/environment-modules/modulespath` on Debian/Ubuntu systems.

See the definitions of `MODULEDESTROOT` and `MODULEFILEDEST` in [the
Makefile](Makefile) for customization options. For example, if you have custom
modules in `~/modules` and modulefiles in `~/modules/modulefiles`, you can:

    make module MODULEDESTROOT=$HOME/modules

Further help with Environment Modules is beyond the scope of this document. See
its homepage at https://modules.sf.net for more information.


## DEVELOPMENT AND TESTING

You can use the included `Dockerfile` to simplify local development; it builds
a minimal Debian Linux container with GNU Make and the latest release of Python
2.7 inside.

To use it, build the image locally, then bind mount the repository to `/src`
inside the container before running commands inside it. For example:

    docker build . -t cosmo

    # make sure it works
    docker run --rm -it cosmo cosmo --help
    docker run --rm -it cosmo cosmostats --help

[Podman][] will work equally well here. To run tests on sample data included
with repository, on 4 CPU cores:

    docker run --rm -it -v .:/src cosmo make -j4 test

    # or with Podman, assuming your local user ID is 1000
    podman run --userns=keep-id --rm -it -v .:/src cosmo make -j4 test

Podman runs containers without root privileges, with the container's `cosmo`
user in a different namespace than the user on the host system, so you need to
add `--userns=keep-id` to the `docker run` invocation, or else manually adjust
permissions inside the container.[^fn2]

If you're changing the code, make sure `make test` passes, or at least you can
figure out the reason _why_ it didn't pass (explain this in your commit
message), _before_ committing to the master/main branch.

For breaking changes — _e.g._ removing a command-line option or changing the
input or output formats in a non-backward-compatible way — then you must:

1. increment the whole number (major) part of the version in `setup.py`
2. …and `git tag vX.Y.Z`, where `X.Y.Z` is the new version number.

See [semver.org][] for more information.


## KNOWN ISSUES

1. FASTA inputs must have headers in `chrN:<start>-<end>` format, where `N` is
   the chromosome number; the nucleotide sequences must also be on a single line.
2. Given FASTA inputs above about 100 MB, COSMO takes a long time to finish.
    * As a workaround split large FASTAs into multiple files before the `>`
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
[scripts]: https://packaging.python.org/en/latest/guides/distributing-packages-using-setuptools/#scripts
[moods]: https://www.cs.helsinki.fi/group/pssmfind/
[bedtools]: http://bedtools.readthedocs.io/en/latest/
[virtualenv]: https://virtualenv.pypa.io/en/latest/user_guide.html
[path]: https://en.wikipedia.org/wiki/PATH_(variable)
[modules]: http://modules.sourceforge.net/
[zip]: https://github.com/WeirauchLab/cosmo/archive/refs/heads/github.zip
[docker]: https://en.wikipedia.org/wiki/Docker_(software)
[podman]: https://en.wikipedia.org/wiki/Podman
[bed]: https://genome.ucsc.edu/FAQ/FAQformat.html#format1
[pip]: https://pip.pypa.io/en/stable/installing/
[jr]: mailto:riddeljr@mail.uc.edu
[ke]: kevin.ernst@cchmc.org
[mw]: matthew.weirauch@cchmc.org
[moodscopy]: https://github.com/jhkorhonen/MOODS/blob/master/COPYING.GPLv3
[envvar]: https://en.wikipedia.org/wiki/Environment_variable
[modulefile]: https://modules.sourceforge.net/c/modulefile.html
[semver.org]: https://semver.org

[^fn1]: In Podman or "rootless" Docker, this will probably not work for you unless your user ID is 1000 (that of the `cosmo` user inside the container).  The solution is left as an exercise for the reader.
[^fn2]: Helpful background information may be found in [these](https://www.redhat.com/en/blog/user-namespaces-selinux-rootless-containers) [two](https://www.redhat.com/en/blog/user-flag-rootless-containers) Red Hat blog posts.
