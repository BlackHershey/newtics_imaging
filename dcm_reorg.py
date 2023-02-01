import argparse
import glob
import numpy as np
import os
import os.path
import pydicom
import re
import sys
sys.path.append('/data/nil-bluearc/black/git/utils/4dfp')

from params_setup import gen_params_file
from subprocess import call

rawdata_dir = '/data/nil-bluearc/black/NewTics/CNDA_DOWNLOAD'
study_dir = '/data/nil-bluearc/black/NewTics'

subsearch = re.compile('NT(\d{3})', flags=re.IGNORECASE)

# parser = argparse.ArgumentParser()
# parser.add_argument('vcnumfile', help='CSV or single column file containing vcnums to process')
# args = parser.parse_args()

os.chdir(study_dir)
# vcnums = np.genfromtxt(args.vcnumfile, dtype='str', usecols=0,delimiter=',')
MR_session_directories = []
for item in os.listdir(study_dir):
	if os.path.isdir(item) and ( "screen" in item or "12mo" in item ):
		MR_session_directories.append(item)

for patid in MR_session_directories:
	subject = patid[0:5]
	print('Processing {} {}'.format(subject,patid))
	folder_search = glob.glob(os.path.join(rawdata_dir, subject, patid, patid)) # match * instead of vc due to capitalization

	if not folder_search:
		print('Could not find DICOM folder for {}'.format(patid))
		continue
	dicom_folder = folder_search[0]

	# dcms = glob.glob(os.path.join(dicom_folder, '**', '*.dcm'), recursive=True)

	# ds = pydicom.dcmread(dcms[0])
	# sub = str(ds.PatientName)
	# patid = ds.PatientID

	#if int(subsearch.match(subject).group(1)) < 818: # only care about R01 subjects right now
	#	continue

	if ':' in patid:
		print('Invalid patid', patid, dicom_folder)
		continue

	#if os.path.exists(patid):
	#	print('patid folder already exists')
	#	continue

	#os.mkdir(patid)
	os.chdir(patid)

	#print('Sorting...')
	#dcm_dirname = os.path.dirname(dcms[0])
	#if 'SCANS' in dcm_dirname:
	#	inpath = os.path.join(vc_folder, patid, 'SCANS') if patid in dcm_dirname else os.path.join(vc_folder, 'SCANS')
	#	call(['pseudo_dcm_sort.csh', inpath, '-r"*"', '-s'])
	#else:
	#	inpath = vc_folder
	#	call(['dcm_sort', inpath])



	#if not glob.glob('*.studies.txt'):
	#	print('skipping', patid)
	#	continue

	# output file with ".cnf" extension
	# 	set up similar to a params file, but not actually valid for 4dfp processing (took some shortcuts)
	#	(invalid because no day1 logic and pcasl/bold params should be separate)
	gen_params_file(patid, os.path.join(study_dir, 'NT_config.json'), duplicates='norm', outfile='{}_nih.cnf'.format(patid))

	os.chdir('..')


