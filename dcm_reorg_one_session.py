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

parser = argparse.ArgumentParser()
parser.add_argument('patid', help='MR session patid')
args = parser.parse_args()
patid = args.patid

os.chdir(study_dir)

subject = patid[0:5]
print('Processing {} {}'.format(subject,patid))
folder_search = glob.glob(os.path.join(rawdata_dir, subject, patid, patid)) # match * instead of vc due to capitalization

if not folder_search:
	print('Could not find DICOM folder for {}'.format(patid))
dicom_folder = folder_search[0]

os.chdir(patid)

gen_params_file(patid, os.path.join(study_dir, 'NT_config.json'), duplicates='norm', outfile='{}_nih.cnf'.format(patid))

os.chdir('..')

