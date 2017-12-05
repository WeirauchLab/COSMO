# COSMO v1.0

This script allows detection of enriched composite motifs in genomic sequence
data.

## PREREQUISITES

Python 2.7, with modules:

*	NumPy
*	SciPy
*	[MOODS v1.0.2.1][moods]
* JASPAR formatted motifs
* [BEDTOOLS][] derived FastA DNA sequence file

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
    `DISTANCE` (COSMO's `-d` option, default: 10) and `THRESHOLD` (`-t`,
    default: 0.6). See below for COSMO's other command-line options.


## PARAMETERS

| Option     | Description
|------------|----------------------------------------------------------
| `-fa PATH` | to FastA sequence file
| `-t`       | Log-odds score threshold (S/Smax) (default is `0.6`)
| `-P`       | (optional) Pseudocount for MOODS to use (default is `1`)
| `-p`       | PATH to JASPAR-format PWMs (default is `./jpwm/`)
| `-d`       | Maximum allowed distance between motifs (default is `10`)
| `-s`       | Boolean flag to dinucleotide shuffle the input sequence
| `-N`       | Background run number
| `-C`       | Boolean flag to save coordinates rather than counts

## USAGE

### Foreground scan

    ./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10

### Background scans

    ./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10 -s -N 1
    ./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10 -s -N 2
    ...
    ./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10 -s -N 100

### Coordinates scan

    ./cosmo.py -fa ./h3k27ac.fa -t 0.6 -d 10 -C

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
