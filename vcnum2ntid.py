import argparse
import csv
import numpy as np
import os
import pydicom
import re
import requests
import sys
sys.path.append('/net/zfs-black/BLACK/black/git/utils/cnda')

from cnda_common import get_all_sessions
from getpass import getpass
from glob import glob

# Create master list of vcnum to NTID mapping
# 	Sources patid from dicom headers and then checks against CNDA if it belongs to NT project

parser = argparse.ArgumentParser()
parser.add_argument('inpath', help='top-level directory containing vcnum folders')
parser.add_argument('cnda_username')
parser.add_argument('--outfile', default=os.path.join(os.getcwd(), 'NT_vcnum.csv'), help='where to store vcnum/ntid mappings')
parser.add_argument('--redo', action='store_true')
args = parser.parse_args()

# get all directories in inpath that could be NewTics (either vcnum or NTID)
vcnum_folders = [ d for d in glob(os.path.join(args.inpath, '*')) if os.path.isdir(d) and re.match('(vc|nt)', os.path.basename(d), flags=re.IGNORECASE) ]

# get all CNDA sessions for NewTics
sess = requests.Session()
sess.auth = (args.cnda_username, getpass('Enter CNDA password:'))
cnda_sessions = [ item['label'] for item in get_all_sessions(sess, 'NP919') ]

# get list of ids we've already mapped
# 	speeds up processing since we don't have to repeat API call for every session
existing_vcnums = np.genfromtxt(args.outfile, usecols=0, dtype='str', delimiter=',') if not args.redo and os.path.exists(args.outfile) else []

results = []
for folder in vcnum_folders:
	vcnum = os.path.basename(folder)
	print('Processing {}...'.format(vcnum))

	# if id was already processed, skip to next
	if vcnum in existing_vcnums:
		print('\tvcnum is already mapped')
		continue

	# otherwise, find dicoms for subject
	dcms = glob(os.path.join(folder, '**/*.dcm'), recursive=True)
	if not dcms:
		continue

	# extract patid from dcm headers and split into subject and session
	ds = pydicom.dcmread(dcms[0])
	sub = str(ds.PatientName)
	patid = ds.PatientID
	_, _, ses = patid.partition('_') # assumes everything after first underscore is the session
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
