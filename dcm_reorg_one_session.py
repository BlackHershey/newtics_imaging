import argparse
import glob
import numpy as np
import os
import os.path
import sys
sys.path.append('/data/nil-bluearc/black/git/utils/4dfp')

from params_setup import gen_params_file
from subprocess import call

params_verbosity=False

parser = argparse.ArgumentParser()
parser.add_argument('study_dir', help='root directory where MR sessions have been dcm-sorted')
parser.add_argument('patid', help='MR session patid')
parser.add_argument('dicom_rootdir', help='root directory containing patid-named directory with DICOMs')
parser.add_argument('config_json', help='full path to json file containing DICOM series description mapping')
parser.add_argument('--duplicates', default=None, help='which duplicate to keep based on ImageType (e.g. NORM)')
args = parser.parse_args()
study_dir = args.study_dir
patid = args.patid
dicom_rootdir = args.dicom_rootdir
config_json = args.config_json
duplicates = args.duplicates

os.chdir(study_dir)

print('### dcm-reorg {}'.format(patid))
folder_search = glob.glob(os.path.join(dicom_rootdir, patid))

if not folder_search:
	print('Could not find DICOM folder for {}'.format(patid))
dicom_folder = folder_search[0]

os.chdir(patid)

gen_params_file(patid, config_json, duplicates=duplicates, outfile='{}_nih.cnf'.format(patid), verbose=params_verbosity)

os.chdir('..')

