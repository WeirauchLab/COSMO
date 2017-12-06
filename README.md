# COSMO v1.0

This script allows detection of enriched composite motifs in genomic sequence
data.

## PREREQUISITES

* Python 2.7.x, with the following modules:
  *	NumPy
  *	SciPy
  *	[MOODS v1.0.2.1][moods]
* JASPAR-formatted motifs
* [BEDTOOLS][]-derived FastA DNA sequence file

## INSTALLATION

1. Download the [latest release tarball][targz] ([.zip][zip]) from GitLab,
   then unpack it into a local directory.
2. If necessary, install NumPy and SciPy dependencies.

    **<abbr title="Nota Bene">NB</abbr>**: In most cluster environments, this
    step should not be necessary. (If you want to verify, try running `python`
    at the console, then `import scipy` followed by `import numpy`&mdash;or
    just run the `example.sh` script and see what happens.)

    **Using a package manager**:

    ```bash
    # Debian-like OSes (incl. Ubuntu)
    sudo apt-get install python-numpy python-scipy

    # Fedora/RHEL/CentOS
    sudo yum install python27-numpy python27-scipy

    # OS X / macOS using Homebrew (https://brew.sh)
    brew install numpy scipy

    # MacPorts
    sudo port install py27-numpy py27-scipy

    # Windows
    # FIXME - maybe conda?
    ```

    **Using [pip][] in a virtualenv**:

    ```bash
    cd /path/to/cosmo
    virtualenv venv --python=python2  # or possibly just 'python'
    source venv/bin/activate
    pip install -r requirements.txt
    ```

3. Finally, run `./example.sh` within the "cosmo" directory. A typical
   invocation will look like this:

    ![Sample invocation of the `example.sh` script](img/example.sh.png)

    The sample script defaults to 100 background scan iterations, which may
    take a considerable amount of time to complete. Set `BGSCANS` in the
    environment if you wish to override this, like so:

    ```bash
    BGSCANS=3 ./example.sh
    ```

    Other `example.sh` defaults you can override in a similar fashion are
    `DISTANCE` (COSMO's `-d` option, default: 10), `THRESHOLD` (`-t`,
    default: 0.6), and `PRESERVELOGS` (set to `0` or `false` to remove
    execution logs upon completion). See below for COSMO's other command-line
    options.


## TROUBLESHOOTING

If `example.sh` has trouble auto-detecting your platform, architecture or Python
version (_e.g._ MOODS fails to build), here's how you can perform the same tests
of COSMO's operation manually:

* unpack the MOODS sources, build it, and add the path to `_cmodule.so` to your
  `PYTHONPATH`, like so

    ```bash
    test -d MOODS || tar zxf MOODS-x.y.z.tar.gz  # using the included version

    pushd MOODS/src
    make                                         # add '-j4' if you like
    cd ../python
    python setup.py build
    popd

    # where <ARCH_AND_VERSION> will depend on your platform
    export PYTHONPATH=$PYTHONPATH:MOODS/python/build/lib.<ARCH_AND_VERSION>
    ```

    At this point, you should be able to run `./cosmo_v1.py` and get a usage
    message (but no Python tracebacks).

* unpack the example FASTA file if necessary, and run several background scans
  (in this example, three), specifying the `-C` (save coordinates) option with
  the last one:

    ```bash
    test -f example.fa || gzip -dc <example.fa.gz >example.fa

    # vary these parameters to your liking (see PARAMETERS below)
    defaultargs="-fa example.fa -t 0.6 -d 10 -p ./jpwm"

    ./cosmo_v1.py $defaultargs &>1.log &
    ./cosmo_v1.py $defaultargs &>2.log &
    ./cosmo_v1.py $defaultargs -C &>3.log &
    ```

* wait for all the background jobs to finish, then run a coordinates scan, using
  the results from the three background scans (`-N 3`):

    ```bash
    ./cosmo_v1.py $defaultargs -s -N 3
    ```

* finally, compute statistics for the three scans (`-N 3`):

   ```bash
   ./cosmostats_v1.py -N 3
   ```
    
## PARAMETERS

| Option     | Description
|------------|------------------------------------------------------------
| `-fa PATH` | path to FastA sequence file
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

| Name            | Email                            | Contribution    |
|-----------------|----------------------------------|-----------------|
| Jeremy Riddell  | [riddeljr -at- mail.uc.edu][jr]  | Primary author  |

## LICENSE

`FIXME`

[moods]: https://www.cs.helsinki.fi/group/pssmfind/
[bedtools]: http://bedtools.readthedocs.io/en/latest/
[targz]: https://tfwebdev.research.cchmc.org/gitlab/cosmo/cosmo/repository/master/archive.tar.gz
[zip]: https://tfwebdev.research.cchmc.org/gitlab/cosmo/cosmo/repository/master/archive.zip
[pip]: https://pip.pypa.io/en/stable/installing/
[jr]: mailto:riddeljr%20-at-%20mail.uc.edu
