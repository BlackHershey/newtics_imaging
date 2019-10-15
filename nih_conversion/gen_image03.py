import csv
import glob
import json
import os
import os.path
import pandas as pd
import pydicom
import sys
sys.path.append('/data/nil-bluearc/black/git/utils')


from getpass import getpass
from instructions import get_first_dicom


study_dir = '/data/nil-bluearc/black/NewTics'

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

columns = ['demo_study_id', 'interview_date', 'image_file', 'image_description', 'experiment_id', 'scan_type']


def gen_image03():
    script_dir = os.getcwd()

    os.chdir(study_dir)
    patids = [ d for d in glob.glob('NT*') if os.path.isdir(d) ]

    with open('NT_config.json') as f:
        scan_mapping = json.load(f)['series_desc_mapping']

    results = []
    processed_zips = []
    for patid in patids:
        if not os.path.exists(os.path.join(patid, 'scans.studies.txt')):
            print('No txt for patid:', patid)
            continue

        os.chdir(patid)



        df = pd.read_table('scans.studies.txt', delim_whitespace=True, names=['id', 'scan_type', 'series_desc', 'file_count'])
        for _, row in df.iterrows():
            if row['series_desc'] not in scan_mapping:
                continue

            scan_info = scan_type_map[scan_mapping[row['series_desc']]]

            scan_zips = [ f for f in glob.glob('../zips/{}*_study{}*.zip'.format(patid, row['id'])) if f not in processed_zips ]
            for zip in scan_zips:
                if not os.path.exists(zip):
                    print('Cannot find zip:', zip)
                    continue

                #print(patid, row['id'])
                scan_date = pydicom.dcmread(get_first_dicom(row['id'], True)).StudyDate
                results.append([patid.split('_')[0], scan_date, zip, scan_info['desc'], scan_info['exp_id'] if 'exp_id' in scan_info else None, scan_info['type']])
                processed_zips.append(zip)

        os.chdir('..')

    os.chdir(script_dir)

    image_df = pd.DataFrame(results, columns=columns).set_index('demo_study_id')
    image_df = image_df.assign(scan_object='Live', image_file_format='DICOM', image_modality='MRI', transformation_performed='No')
    image_df.to_csv('image03_nodemo.csv')


if __name__ == '__main__':
    gen_image03()
