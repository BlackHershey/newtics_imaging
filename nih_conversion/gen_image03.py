import glob
import json
import os
import os.path
import pandas as pd
import pydicom
import re
import sys
import argparse
sys.path.append('/data/nil-bluearc/black/git/utils/4dfp')

# from getpass import getpass
from instructions import find_dicoms

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
def gen_image03(study_dir, scan_mapping_json, patid_glob_pattern):
    os.chdir(study_dir)
    patids = [ d for d in glob.glob(patid_glob_pattern) if os.path.isdir(d) ]

    # read in config that contains series description/scan type map (same file used for creating params file)
    with open(scan_mapping_json) as f:
        scan_mapping = json.load(f)['series_desc_mapping']

    results = []
    processed_zips = []
    for patid in sorted(patids):
        # infer visit_type from patid (screen/baseline, 12mo, etc.)
        if "12mo" in patid:
            visit_type = "12month"
        elif "screen" in patid:
            visit_type = "screening"
        elif "baseline2" in patid:
            visit_type = "baseline2"
        elif "baseline" in patid:
            visit_type = "baseline"
        elif "2YR2" in patid:
            visit_type = "2YR2"
        elif "2YR" in patid:
            visit_type = "2YR"
        else:
            # ignore anything else
            print('WARNING: skipping {}, does not match screen, 12mo, baseline(2) or 2YR(2)'.format(patid))
            continue

        print('patid = {}, visit = {}'.format(patid,visit_type))

        scan_zips = glob.glob('zips/{}_study*.zip'.format(patid)) # get all zips for patid

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
    image_df.to_csv(os.path.join(study_dir, 'image03_nodemo.csv'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('study_dir', help='Base study directory containing 4dfp-style patid directories')
    parser.add_argument('scan_mapping_json', help='JSON file containing the mapping of series description to scan type')
    parser.add_argument('patid_glob_pattern', help="patid glob pattern to match to identify patids to process, e.g. 'NT*', 'LoTS*'")
    args = parser.parse_args()
    gen_image03(
        args.study_dir, 
        args.scan_mapping_json, 
        args.patid_glob_pattern)
