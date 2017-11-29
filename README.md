COSMO v1.0

This script allows detection of enriched composite motifs
in genomic sequence data.

PREREQUISITES:

Python 2.7, with modules:
	NumPy
	SciPy
	MOODS v1.0.2.1 (https://www.cs.helsinki.fi/group/pssmfind/)
JASPAR formatted motifs
BEDTOOLS derived FastA DNA sequence file (http://bedtools.readthedocs.io/en/latest/)

INSTALLATION:

Unpack tarball into a local directory, then run "example.sh".

PARAMETERS:

-fa	PATH to FastA sequence file
-t	Log-odds score threshold (S/Smax) (default is 0.6)
-P	(optional) Pseudocount for MOODS to use (default is "1")
-p	PATH to JASPAR-format PWMs (default is "./jpwm/")
-d	Maximum allowed distance between motifs (default is "10")
-s	Boolean flag to dinucleotide shuffle the input sequence
-N	Background run number
-C	Boolean flag to save coordinates rather than counts

USAGE:

Foreground scan
./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10

Background scans
./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10 -s -N 1
./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10 -s -N 2
...
./cosmo_v1.py -fa ./h3k27ac.fa -t 0.6 -d 10 -s -N 100

Coordinates scan
./cosmo.py -fa ./h3k27ac.fa -t 0.6 -d 10 -C

Statistics calculation:
./cosmostats_v1.py -N 100

OUTPUT:

COSMO writes counts for stereopairs to the local directory in the file "cosmo.counts.tab".
Background scans (with parameters -s and -N <x>) are placed into sequential files named "cosmo.counts.tab.<x>").
Coordinates are saved into a BED-formatted file "cosmo.coords.bed"
