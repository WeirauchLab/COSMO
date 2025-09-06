#!/usr/bin/env python
# vim: fileencoding=utf-8
##
##  Detect enriched composite motifs in genomic sequence data
##
##  Author:   Jeremy Riddell <riddeljr@mail.uc.edu>
##  License:  GPLv3
##
## © 2022 Cincinnati Children's Hospital and contributors
##
from __future__ import print_function

import os
import re
import sys
import math
import random
import string
import argparse
import operator
from collections import defaultdict
import MOODS

DEFAULT_PSEUDO = 1
DEFAULT_THRESHOLD = 0.60
DEFAULT_PWMDIR = 'jpwm'
DEFAULT_NUMBER = 1
DEFAULT_DISTANCE = 10

parser = argparse.ArgumentParser(description='COSMO Composite Motif Scanner')
parser.add_argument('-fa', '--fasta', required=True,
                    help='FASTA file name goes here')
parser.add_argument('-P', '--pseudo', type=int, default=DEFAULT_PSEUDO,
                    help='pseudo count')
parser.add_argument('-t', '--threshold', type=float, default=DEFAULT_THRESHOLD,
                    help='%%MAX LOD score threshold')
parser.add_argument('-s', '--scramflag', '--shuffle', action='store_true',
                    help='use shuffled input sequence')
parser.add_argument('-p', '--pwmdir', default=DEFAULT_PWMDIR,
                    help='PWMs to use')
parser.add_argument('-N', '--number', type=int,
                    help="shuffle run number (use with '-s')")
parser.add_argument('-C', '--coord', action='store_true',
                    help='scan for coordinates only')
parser.add_argument('-d', '--distance', type=int, default=DEFAULT_DISTANCE,
                    help='max PWM distance')
parser.add_argument('--seed', '--random-seed',
                    help='seed the random number generator (for testing)')

args = parser.parse_args()

# seeding the RNG allows for reproducible tests
if args.seed or os.getenv('RANDSEED'):
    seed = args.seed if args.seed else os.getenv('RANDSEED')
    print("Seeding random number generator with '%s'…" % seed, file=sys.stderr)
    random.seed(seed)

fasta_file = args.fasta
pseudo = args.pseudo
threshold = args.threshold
scram_flag = args.scramflag  # FIXME: bad naming, but don't want to break API
pwm_directory = args.pwmdir
shuffle_number = args.number
coord_flag = args.coord
max_distance = args.distance
min_distance = -6
outfile_prefix = "cosmo"

if not os.path.exists(pwm_directory) or not os.access(pwm_directory, os.R_OK):
    print("ERROR: JASPAR PWM path does not exist or isn't readable; try "
          "'--help'.", file=sys.stderr)
    sys.exit(1)

if shuffle_number and not scram_flag:  # just infer it
    print("Inferring '--shuffle' because you supplied '-N' / '--number'.",
          file=sys.stderr)
    scram_flag = True
elif scram_flag and not shuffle_number:
    print("ERROR: The '-s' / '--shuffle' option requires '-N' / '--number'.",
          file=sys.stderr)
    sys.exit(1)
elif scram_flag and coord_flag:
    print("ERROR: The '-s' / '--shuffle' option is mutually-exclusive with "
          " '-C' / '--coord'.", file=sys.stderr)
    sys.exit(1)

if scram_flag:
    if not shuffle_number:
        shuffle_number = DEFAULT_NUMBER
    outfile = outfile_prefix + ".counts.tab." + str(shuffle_number)
elif coord_flag:
    outfile = outfile_prefix + ".coords.bed"
else:
    outfile = outfile_prefix + ".counts.tab"

motif_files = []
motif_dict = {}
seq_dict = {}
tf_list = []
motif_list = []
p_list = []
matrix_list = []
keylist = []
stereo_dict = defaultdict(int)
cmseq_dict = defaultdict(list)
stats_dict = defaultdict(list)
temp = []
outlist = []

#######################################
### START DINUCLEOTIDE SHUFFLE BLOC ###
#######################################


def computeCountAndLists(s):
    #WARNING: Use of function count(s,'UU') returns 1 on word UUU
    #since it apparently counts only nonoverlapping words UU
    #For this reason, we work with the indices.

    #Initialize lists and mono- and dinucleotide dictionaries
    List = {}  #List is a dictionary of lists
    List['A'] = []
    List['C'] = []
    List['G'] = []
    List['T'] = []
    nuclList = ["A", "C", "G", "T"]
    s = s.upper()
    nuclCnt = {}  #empty dictionary
    dinuclCnt = {}  #empty dictionary
    for x in nuclList:
        nuclCnt[x] = 0
        dinuclCnt[x] = {}
        for y in nuclList:
            dinuclCnt[x][y] = 0

    #Compute count and lists
    nuclCnt[s[0]] = 1
    nuclTotal = 1
    dinuclTotal = 0
    for i in range(len(s) - 1):
        x = s[i]
        y = s[i + 1]
        List[x].append(y)
        nuclCnt[y] += 1
        nuclTotal += 1
        dinuclCnt[x][y] += 1
        dinuclTotal += 1
    assert (nuclTotal == len(s))
    assert (dinuclTotal == len(s) - 1)
    return nuclCnt, dinuclCnt, List


def chooseEdge(x, dinuclCnt):
    numInList = 0
    for y in ['A', 'C', 'G', 'T']:
        numInList += dinuclCnt[x][y]
    z = random.random()
    denom = dinuclCnt[x]['A'] + dinuclCnt[x]['C'] + dinuclCnt[x]['G'] \
            + dinuclCnt[x]['T']
    numerator = dinuclCnt[x]['A']
    if z < float(numerator) / float(denom):
        dinuclCnt[x]['A'] -= 1
        return 'A'
    numerator += dinuclCnt[x]['C']
    if z < float(numerator) / float(denom):
        dinuclCnt[x]['C'] -= 1
        return 'C'
    numerator += dinuclCnt[x]['G']
    if z < float(numerator) / float(denom):
        dinuclCnt[x]['G'] -= 1
        return 'G'
    dinuclCnt[x]['T'] -= 1
    return 'T'


def connectedToLast(edgeList, nuclList, lastCh):
    D = {}
    for x in nuclList:
        D[x] = 0
    for edge in edgeList:
        a = edge[0]
        b = edge[1]
        if b == lastCh: D[a] = 1
    for i in range(2):
        for edge in edgeList:
            a = edge[0]
            b = edge[1]
            if D[b] == 1: D[a] = 1
    ok = 0
    for x in nuclList:
        if x != lastCh and D[x] == 0: return 0
    return 1


def eulerian(s):
    nuclCnt, dinuclCnt, List = computeCountAndLists(s)
    #compute nucleotides appearing in s
    nuclList = []
    for x in ["A", "C", "G", "T"]:
        if x in s: nuclList.append(x)
    #compute numInList[x] = number of dinucleotides beginning with x
    numInList = {}
    for x in nuclList:
        numInList[x] = 0
        for y in nuclList:
            numInList[x] += dinuclCnt[x][y]
    #create dinucleotide shuffle L
    firstCh = s[0]  #start with first letter of s
    lastCh = s[-1]
    edgeList = []
    for x in nuclList:
        if x != lastCh:
            edgeList.append([x, chooseEdge(x, dinuclCnt)])
    ok = connectedToLast(edgeList, nuclList, lastCh)
    return ok, edgeList, nuclList, lastCh


def shuffleEdgeList(L):
    n = len(L)
    barrier = n
    for i in range(n - 1):
        z = int(random.random() * barrier)
        tmp = L[z]
        L[z] = L[barrier - 1]
        L[barrier - 1] = tmp
        barrier -= 1
    return L


def dinuclShuffle(s):
    ok = 0
    while not ok:
        ok, edgeList, nuclList, lastCh = eulerian(s)
    nuclCnt, dinuclCnt, List = computeCountAndLists(s)

    #remove last edges from each vertex list, shuffle, then add back
    #the removed edges at end of vertex lists.
    for [x, y] in edgeList:
        List[x].remove(y)
    for x in nuclList:
        shuffleEdgeList(List[x])
    for [x, y] in edgeList:
        List[x].append(y)

    #construct the eulerian path
    L = [s[0]]
    prevCh = s[0]
    for i in range(len(s) - 2):
        ch = List[prevCh][0]
        L.append(ch)
        del List[prevCh][0]
        prevCh = ch
    L.append(s[-1])
    t = string.join(L, "")
    return t


#####################################
### END DINUCLEOTIDE SHUFFLE BLOC ###
#####################################


def get_seq(in_dict, in_id):
    temp = in_dict[in_id].upper()
    out_seq = ''.join(list(temp[0]))
    return (out_seq)


def matrix_max_score(in_matrix):
    nA = nC = nG = nT = nX = pX = max_n = max_score = float(0.0)
    for j in range(0, len(in_matrix[0])):
        nA = float(in_matrix[0][j])
        nC = float(in_matrix[1][j])
        nG = float(in_matrix[2][j])
        nT = float(in_matrix[3][j])
        nX = float(max(nA, nC, nG, nT))
        pX = float(nX / 100)
        max_n = float(float(math.log(pX)) - float(math.log(0.25)))
        max_score = float(max_score + max_n)
    return (max_score)


def matrix_threshold(in_matrix, in_threshold):
    max_score = ()
    max_score = float(matrix_max_score(in_matrix))
    max_score_threshold = float(in_threshold * max_score)
    return (max_score_threshold)


def load_fasta(fasta_file):
    seq_dict = defaultdict()
    with open(fasta_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                seq_name = line[1:]
                continue
            else:
                seq_dict[seq_name] = line.upper()
    return (seq_dict)


bg = MOODS.flatbg()
matrix_max_list = []
matrix_name_list = [
    filename for filename in os.listdir(pwm_directory)
    if filename.endswith('.jpwm')
]
matrix_list = [
    MOODS.load_matrix(os.path.join(pwm_directory, filename))
    for filename in matrix_name_list
]
matrix_list = [
    MOODS.count_log_odds(matrix, bg, pseudo, log_base=2)
    for matrix in matrix_list
]
matrix_max_list = [MOODS.max_score(matrix) for matrix in matrix_list]
threshold_list = [(float(threshold) * matrix_max)
                  for matrix_max in matrix_max_list]

seq_dict = load_fasta(fasta_file)
seq_list = seq_dict.keys()
counter = 0

for seq_id in seq_list:
    counter = counter + 1
    percent_complete = counter / float(len(seq_list)) * 100

    if sys.stdout.isatty():
        print("\r%5.1f%%  %-30s" % (percent_complete, seq_id), end='')
        sys.stdout.flush()
    else:
        print("%5.1f%%  %s" % (percent_complete, seq_id))

    hit_list = []
    result_list = []
    seq_chr, seq_start, seq_end = re.split(r'[-:]', str(seq_id))
    seq = seq_dict[seq_id]
    if scram_flag == True:
        seq = dinuclShuffle(re.sub("N", "", seq))
    result_list = MOODS.search(seq,
                               matrix_list,
                               threshold_list,
                               convert_log_odds=False,
                               threshold_from_p=False,
                               both_strands=True,
                               log_base=2)
    for (matrix, matrix_name, result, matrix_max) in \
            zip(matrix_list, matrix_name_list, result_list, matrix_max_list):
        l = len(matrix[0])
        for (pos, score) in result:
            hit_seq = seq[pos:pos + l]
            if pos < 0:
                start_coord = int(seq_end) + int(pos)
                strand = "-"
                hit_seq = "".join(
                    reversed(
                        map(
                            lambda s: {
                                'A': 'T',
                                'T': 'A',
                                'C': 'G',
                                'G': 'C',
                                'N': 'N'
                            }[s], hit_seq.upper())))
            else:
                start_coord = int(seq_start) + int(pos)
                strand = "+"
            end_coord = int(start_coord) + int(l)
            percent_max = float(score / matrix_max)
            if hit_seq == "":
                hit_seq = "N" * l
            hit_list.append([
                seq_id, seq_chr,
                str(start_coord),
                str(end_coord),
                str(matrix_name),
                str(percent_max),
                str(strand), hit_seq,
                str(score),
                str(matrix_max)
            ])
    hit_list.sort(key=operator.itemgetter(0, 1, 2, 3))
    for i in range(0, len(hit_list) - 1):
        SEQID_1, CHR_1, START_1, END_1, PWMID_1, SCORE_1, STRAND_1, \
                MATCHSEQ_1, LODSCORE_1, MAXPWMSCORE_1 = hit_list[i]
        for j in range(i + 1, len(hit_list)):
            SEQID_2, CHR_2, START_2, END_2, PWMID_2, SCORE_2, STRAND_2, \
                    MATCHSEQ_2, LODSCORE_2, MAXPWMSCORE_2 = hit_list[j]
            distance = int(START_2) - int(END_1)
            if distance > max_distance:
                break
            else:
                if STRAND_1 == "+":
                    stereo_1 = "F"
                else:
                    stereo_1 = "R"
                if STRAND_2 == "+":
                    stereo_2 = "F"
                else:
                    stereo_2 = "R"
                stereo_pair = str(stereo_1) + str(stereo_2)
                if stereo_pair == "FF":
                    p1 = PWMID_1
                    p2 = PWMID_2
                    cm_strand = STRAND_1
                elif stereo_pair == "RR":
                    stereo_pair = "FF"
                    p1 = PWMID_2
                    p2 = PWMID_1
                    cm_strand = STRAND_2
                elif stereo_pair == "FR":
                    p1 = min(PWMID_1, PWMID_2)
                    p2 = max(PWMID_1, PWMID_2)
                    if p1 == PWMID_1:
                        cm_strand = "+"
                    else:
                        cm_strand = "-"
                elif stereo_pair == "RF":
                    p1 = min(PWMID_1, PWMID_2)
                    p2 = max(PWMID_1, PWMID_2)
                    if p1 == PWMID_1:
                        cm_strand = "+"
                    else:
                        cm_strand = "-"
                key_string = "|".join([p1, p2, stereo_pair, str(distance)])
                if distance >= min_distance and coord_flag == False:
                    stereo_dict[key_string] += 1
                if scram_flag == False and coord_flag == True:
                    cm_start = int(min(START_1, START_2))
                    cm_end = int(max(END_1, END_2))
                    if distance >= min_distance:
                        cmseq_dict[key_string].append([
                            str(CHR_1),
                            str(cm_start),
                            str(cm_end),
                            str(p1) + "|" + str(p2) + "|" + str(stereo_pair)
                                    + "|" + str(distance),
                            str(SCORE_1) + "|" + str(SCORE_2),
                            str(cm_strand)
                        ])
    if scram_flag == False and coord_flag == True:
        with open(outfile, 'a') as f:
            for key in cmseq_dict:
                for cm in cmseq_dict[key]:
                    f.write('\t'.join(cm) + '\n')
    for key in cmseq_dict:
        cmseq_dict[key] = []

if sys.stdout.isatty():
    print()  # inline progress had no terminating newline

if coord_flag == False:
    with open(outfile, 'w') as f:
        for key in stereo_dict:
            f.write('|'.join([str(key), str(stereo_dict[key]) + '\n']))
