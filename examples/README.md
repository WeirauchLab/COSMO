COSMO Example Inputs and Outputs
================================

Example FASTA input files, an example wrapper script written in Bash, and an
example Makefile, for use with COSMO.

The `make test` target of the Makefile in the parent directory will verify
COSMO's operation against the files in the `output` subdirectory.

These were generated using the `example.40k.fa` input file (containing a
subsect of ~40,000 individual sequences from `example.fa`, 3 background scans,
and 1000 + the shuffle number as the random seed.

    ./
    ├── example.40k.fa.gz        ~40k sequences as test input for `make test`
    ├── example.fa.gz            an example FASTA file
    ├── example.sh               an (overly-complicated) COSMO wrapper script
    ├── jpwm/
    │   ├── M0686_1.02d.jpwm
    │   ├── M1264_1.02d.jpwm
    │   └── M1518_1.02d.jpwm
    ├── Makefile.example         a simple example Makefile for your own analyes
    └── output/
        ├── cosmo.coords.bed     sample outputs used by `make test`
        ├── cosmo.counts.tab
        └── stats.tab
