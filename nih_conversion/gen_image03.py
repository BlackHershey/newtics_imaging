import csv
import glob
import json
import os
import os.path
import pandas as pd
import pydicom
import re
import sys
sys.path.append('/data/nil-bluearc/black/git/utils/4dfp')

# from getpass import getpass
from instructions import find_dicoms


study_dir = '/data/nil-bluearc/black/NewTics'

# Sequence info to include in CSV
scan_type_map = {
    'mprs': {
        'type': 'MR structural (MPRAGE)',
        'desc': 'T1-weighted vNav-corrected',
    },
    'tse': {
        'type': 'MR structural (T2)',
        'desc': 'T2-weighted vNav-corrected'
    },
    'fstd': {
        'type': 'fMRI',
        'desc': 'resting-state BOLD',
        'exp_id': 1098
    },
    'sefm': {
        'type': 'Field Map',
        'desc': 'Spin-echo field map'
    },
    'pcasl': {
        'type': 'pCASL: ASL',
        'desc': 'resting-state 3D pCASL',
        'exp_id': 1099
    }
}

columns = ['demo_study_id', 'interview_date', 'visit', 'image_file', 'image_description', 'experiment_id', 'scan_type']

"""
Create base of image03 NIH submission file 
    - Extracts information pertaining to each scan and stores in CSV alongside zip file path
Note: needs to be run from unix since it relies on the sorted study files amd Windows seems unable to follow the symlinks
Note: image03 data dictionary: https://nda.nih.gov/data_structure.html?short_name=image03
"""
def gen_image03():
    os.chdir(study_dir)
    patids = [ d for d in glob.glob('NT*') if os.path.isdir(d) ]

    # read in config that contains series description/scan type map (same file used for creating params file)
    with open('NT_config.json') as f:
        scan_mapping = json.load(f)['series_desc_mapping']

    results = []
    processed_zips = []
    for patid in patids:
        scan_zips = glob.glob('zips/{}_study*.zip'.format(patid)) # get all zips for patid

        # infer visit_type from patid (screen/baseline, 12mo, etc.)
        if "12mo" in patid:
            visit_type = "12month"
        elif "screen" in patid:
            visit_type = "screening"
        else:
            # ignore anything else
            print('WARNING: skipping {}, not a screen or 12month'.format(patid))
            continue

        print('patid = {}, visit = {}'.format(patid,visit_type))

        os.chdir(patid)
        for zip in scan_zips:
            scan_num = re.search('study(\d+)', zip).group(1)
            
            try:
                ds = pydicom.dcmread(find_dicoms(scan_num, True)[0]) # get pydicom dataset for a DICOM in the series
                scan_info = scan_type_map[scan_mapping[ds.SeriesDescription.replace(" ","")]] # get scan_type_map key from scan_mapping config
                results.append([patid.split('_')[0], ds.StudyDate, visit_type, zip, scan_info['desc'], scan_info['exp_id'] if 'exp_id' in scan_info else None, scan_info['type']])
            except IndexError:
                print('Study folder missing for:', zip)
            except FileNotFoundError:
                print('Symlinks broken for:', zip)
            except KeyError:
                print('Series description "{}" not in map: {}'.format(ds.SeriesDescription, zip))
        os.chdir('..')

    image_df = pd.DataFrame(results, columns=columns).set_index('demo_study_id')
    image_df = image_df.assign(scan_object='Live', image_file_format='DICOM', image_modality='MRI', transformation_performed='No')
    image_df.to_csv('image03_nodemo.csv')


if __name__ == '__main__':
    gen_image03()
