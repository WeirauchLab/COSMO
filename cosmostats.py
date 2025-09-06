#!/usr/bin/env python2
# vim: fileencoding=utf-8
##
##  Compute aggregate statistics for COSMO background scans
##
##  Author:   Jeremy Riddell <riddeljr@mail.uc.edu>
##  License:  GPLv3
##
##  TODO:     Doesn't really need to exist as a separate script, and even if it
##            does, the number of background runs could be detected from files
##            existing on the filesystem.
##
## © 2022 Cincinnati Children's Hospital and contributors
##
from __future__ import print_function
import os
import sys
import glob
import math
import argparse
import numpy as np
from collections import defaultdict as dd
from scipy.stats.distributions import norm

COUNTSFILE = 'cosmo.counts.tab'
DEFAULT_NUMBER = 1
DEBUG = os.getenv('DEBUG')

parser = argparse.ArgumentParser(description='COSMO Composite Motif Scanner - '
                                             'background scan statisticalizer')
parser.add_argument('-N', '--number', type=int, dest='shuffle_number',
                    metavar='BGSCANS',
                    help='number of background scans (default: autodetected '
                         'from filesystem)')

args = parser.parse_args()
result_dict = dd(list)

# if not specified, detect # of bg scans from comso.counts.tab's on filesystem
bgscans = glob.glob(COUNTSFILE + ".*")
nscans = len(bgscans)

if args.shuffle_number:
    if args.shuffle_number != nscans:
        print("WARNING: '-N' / '--number' given as %d, but %d backgrounds scans "
              "were found." % (args.shuffle_number, nscans), file=sys.stderr)
else:
    if sum([int(x.replace(COUNTSFILE + '.', '')) for x in bgscans]) \
            != sum(range(1, nscans + 1)):
        print("ERROR: Background scan filenames must have sequential suffixes, "
              "e.g., 1, 2, 3, …", file=sys.stderr)
        sys.exit(1)
    print("Inferred %d background scans from files found in current directory."
          % nscans, file=sys.stderr)
    args.shuffle_number = nscans

# build the results dictionary from the (unshuffled) counts file
with open(COUNTSFILE, 'r') as f:
    for line in f:
        line = line.strip().split('|')
        key = '|'.join(line[0:4])
        value = line[4]
        result_dict[key].append(int(value))

# append results from background (dinuc-shuffled) counts files
for i in range(1, args.shuffle_number + 1):
    # default to zero counts for this shuffle iteration…
    for key in result_dict:
        result_dict[key].append(0)

    fname = "%s.%d" % (COUNTSFILE, i)
    # …but update with the actual value if the key matches
    with open(fname, 'r') as f:
        for line in f:
            line = line.strip().split('|')
            key = '|'.join(line[0:4])
            value = line[4]
            if key in result_dict:
                result_dict[key][i] = int(value)

print('\t'.join(["TF1|TF2|{F/R}|D", "COUNTS", "n", "mu", "SD", "FC", "Z",
                 "p-value"]))

for key in result_dict:
    scores = result_dict[key]
    xbar = scores[0]
    bg_list = scores[1:]
    n = len(bg_list)

    mu = np.mean(bg_list)
    if mu == 0.0:
        mu = 1.0

    sd = np.std(bg_list, ddof=1)
    if sd == 0.0:
        sd = 1.0

    fc = xbar / mu
    z = (xbar - mu) / sd
    p = 2 * norm.cdf(-np.abs(z))

    print('\t'.join([
        key,
        str(int(xbar)),
        str(int(n)),
        str(mu),
        str(sd),
        str(fc),
        str(z),
        str(p)
    ]))
