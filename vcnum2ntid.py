import argparse
import csv
import numpy as np
import os
import pydicom
import re
import requests
import sys
sys.path.append('/net/zfs-black/BLACK/black/git/utils')

from cnda_common import get_all_sessions
from getpass import getpass
from glob import glob

parser = argparse.ArgumentParser()
parser.add_argument('inpath', help='top-level directory containing vcnum folders')
parser.add_argument('cnda_username')
parser.add_argument('--outfile', default=os.path.join(os.getcwd(), 'NT_vcnum.csv'), help='where to store vcnum/ntid mappings')
parser.add_argument('--redo', action='store_true')
args = parser.parse_args()

vcnum_folders = [ d for d in glob(os.path.join(args.inpath, '*'), recursive=True) if os.path.isdir(d) and re.match('vc', os.path.basename(d), flags=re.IGNORECASE) ]

sess = requests.Session()
sess.auth = (args.cnda_username, getpass())
cnda_sessions = [ item['label'] for item in get_all_sessions(sess, 'NP919') ]

existing_vcnums = np.genfromtxt(args.outfile, usecols=0, dtype='str') if not args.redo and os.path.exists(args.outfile) else []

results = []
for folder in vcnum_folders:
	vcnum = os.path.basename(folder)
	print('Processing {}...'.format(vcnum))

	if vcnum in existing_vcnums:
		print('\tvcnum is already mapped')
		continue

	dcms = glob(os.path.join(folder, '**/*.dcm'), recursive=True)
	if not dcms:
		continue

	ds = pydicom.dcmread(dcms[0])
	sub = str(ds.PatientName)
	patid = ds.PatientID
	_, _, ses = patid.partition('_')
	print(sub,ses)

	# check if subject name appears in any cnda session
	#	session name doesn't necessarily need to match for our purposes, we just need to be know if this vcnum is for a NewTics subject
	if not any(re.search(sub, cnda_sess, flags=re.IGNORECASE) for cnda_sess in cnda_sessions):
		print('\tNo similar CNDA session found for', patid)
		continue

	results.append([vcnum, sub, ses])

mode = 'w' if args.redo else 'a'
with open(args.outfile, mode, newline='') as f:
	writer = csv.writer(f)
	writer.writerows(results)
