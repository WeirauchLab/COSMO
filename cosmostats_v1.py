#!/usr/local/python/2.7.5/bin/python
import math
import numpy as np
from scipy.stats.distributions import norm
import sys
import argparse
from collections import defaultdict as dd

file1="./cosmo.counts.tab"
file2="./cosmo.counts.tab."

DEFAULT_NUMBER=int(1)

parser=argparse.ArgumentParser(description='COSMOS Composite Motif Scanner v2')
parser.add_argument('-N', '--number', required=False, help='number of bg scans')

args=parser.parse_args()
shuffle_number=int(args.number)

result_dict=dd(list)
temp_list=[]

def add_result_dict(fname):
	with open(fname, 'r') as f:
		for line in f:
			temp_list=line.split('|')
			key='|'.join(temp_list[0:4])
			value=temp_list[4].strip()
			result_dict[key].append(value)

def append_dict(fname,list_index):
	with open(fname, 'r') as g:
		for line in g:
			temp_list=line.split('|')
			key='|'.join(temp_list[0:4])
			value=temp_list[4].strip()
			if key in result_dict:
				result_dict[key][list_index]=value

zero=int(0)
add_result_dict(file1)
for i in range(1,shuffle_number+1):
	for key in result_dict:
		result_dict[key].append(zero)
	append_dict(str(file2)+str(i),i)

print '\t'.join(["TF1|TF2|{F/R}|D","COUNTS","n","mu","SD","FC","Z","p-value"])
scores=[]
score_list=[]
for key in result_dict:
	scores=result_dict[key]
	xbar=float(scores[0])
	bg_list=list(map(float,scores[1:]))
	n=float(len(bg_list))
	mu=float(np.mean(bg_list))
	if mu == 0.0:
		mu=1.0
	sd=float(np.std(bg_list, ddof=1))
	if sd == 0.0:
		sd=1.0
	fc=float(xbar/mu)
	z=float((xbar-mu)/sd)
	p=float(2*norm.cdf(-np.abs(z)))
	print '\t'.join([key,str(int(xbar)),str(int(n)),str(mu),str(sd),str(fc),str(z),str(p)])
