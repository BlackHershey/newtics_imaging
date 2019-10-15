import glob
import numpy as np
import os
import os.path
import pydicom
import re
import sys
sys.path.append('/net/zfs-black/BLACK/black/git/utils')

from params_setup import gen_params_file
from subprocess import call

rawdata_dir = '/data/cn3/rawdata/tourettes/Prisma'
study_dir = '/net/zfs-black/BLACK/black/NewTics'

subsearch = re.compile('NT(\d{3})', flags=re.IGNORECASE)

os.chdir(study_dir)
vcnums = np.genfromtxt('scripts/vcnum.lst', dtype='str')

for num in vcnums:
	print('Processing vcnum', num)
	folder_search = glob.glob(os.path.join(rawdata_dir, '*{}'.format(num))) # match * instead of vc due to capitalization

	if not folder_search:
		print('Could not find vc folder')
		continue
	vc_folder = folder_search[0]

	dcms = glob.glob(os.path.join(vc_folder, '**', '*.dcm'), recursive=True)

	ds = pydicom.dcmread(dcms[0])
	sub = str(ds.PatientName)
	patid = ds.PatientID

	print(sub, patid)

	if int(subsearch.match(sub).group(1)) < 818: # only care about R01 subjects right now
		continue

	if os.path.exists(patid):
		print('patid folder already exists')
		continue

	os.mkdir(patid)
	os.chdir(patid)

	print('Sorting...')
	dcm_dirname = os.path.dirname(dcms[0])
	if 'SCANS' in dcm_dirname:
		inpath = os.path.join(vc_folder, patid, 'SCANS') if patid in dcm_dirname else os.path.join(vc_folder, 'SCANS')
		call(['pseudo_dcm_sort.csh', inpath, '-r"*"', '-s'])
	else:
		inpath = vc_folder
		call(['dcm_sort', inpath])


	os.chdir('..')

	if not os.path.exists(patid) or not [ f for f in os.listdir(patid) if f.endswith('.studies.txt') ]:
		print('skipping', patid)
		continue

	# TODO: figue out how best to do BOLD + pCASL here --  this is NT specific, so could hard code both; for gen_params -- just outfile name as new option?
	day1_patid = patid.split('_')[0] if patid.endswith('_12mo') else None
	gen_params_file(patid, inpath, os.path.join(study_dir, 'scripts', 'NT_bold_config.json'), duplicates='norm', day1_patid=day1_patid, outfile=patid + '.params')
	gen_params_file(patid, inpath, os.path.join(study_dir, 'scripts', 'NT_pcasl_config.json'), duplicates='norm', day1_patid=patid, outfile=patid + '_pcasl.params')



# if __name__ == '__main__':
# 	parser = argparse.ArgumentParser()
# 	parser.add_argument('inpath', help='directory where study raw data lives')
