#!/usr/bin/env python2
# vim: fileencoding=utf-8
##
##  Compute aggregate statistics for COSMO background scans
##
##  Author:   Jeremy Riddell <riddeljr@mail.uc.edu>
##  License:  GPLv3
##
## © 2022 Cincinnati Children's Hospital and contributors
##
from __future__ import print_function
import os
import sys
import math
import argparse
import numpy as np
from collections import defaultdict as dd
from scipy.stats.distributions import norm

DEFAULT_NUMBER = 1
DEBUG = os.getenv('DEBUG')

file1 = "./cosmo.counts.tab"
file2 = "./cosmo.counts.tab."
result_dict = dd(list)

parser = argparse.ArgumentParser(description='COSMOS Composite Motif Scanner v2')
parser.add_argument('-N', '--number', type=int, required=True,
                    dest='shuffle_number', help='number of bg scans')

args = parser.parse_args()

def add_result_dict(fname):
    with open(fname, 'r') as f:
        for line in f:
            line = line.split('|')
            key = '|'.join(line[0:4])
            value = line[4].strip()
            result_dict[key].append(value)

def append_dict(fname, list_index):
    with open(fname, 'r') as g:
        for line in g:
            temp_list = line.split('|')
            key = '|'.join(temp_list[0:4])
            value = temp_list[4].strip()
            if key in result_dict:
                result_dict[key][list_index] = value


add_result_dict(file1)
for i in range(1, args.shuffle_number + 1):
    for key in result_dict:
        result_dict[key].append(0)
    append_dict(file2 + str(i), i)

print('\t'.join(["TF1|TF2|{F/R}|D", "COUNTS", "n", "mu", "SD", "FC", "Z",
                 "p-value"]))
scores = []
score_list = []
for key in result_dict:
    scores = result_dict[key]
    xbar = float(scores[0])
    bg_list = list(map(float, scores[1:]))
    n = float(len(bg_list))
    mu = float(np.mean(bg_list))
    if mu == 0.0:
        mu = 1.0
    sd = float(np.std(bg_list, ddof=1))
    if sd == 0.0:
        sd = 1.0
    fc = float(xbar / mu)
    z = float((xbar - mu) / sd)
    p = float(2 * norm.cdf(-np.abs(z)))
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
