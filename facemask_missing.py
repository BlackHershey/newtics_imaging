import argparse
import numpy as np
import os
import shutil

from subprocess import run


def get_dcm_path(study_dir, sub, scan, out=False):
    return os.path.join(study_dir, sub, 'study' + scan) if not out else os.path.join(study_dir, 'defaced', sub, 'DICOM_DEFACED')


def facemask(study_dir, ref_file):
    data = np.genfromtxt(ref_file, delimiter=',', dtype='str', skip_header=1)

    for sub, scanlst, ref in data:
        subdir = os.path.join(study_dir, sub)
        if not os.path.exists(subdir):
            print('no folder for', sub)
            continue

        if os.path.exists(os.path.join(study_dir, 'defaced', sub)):
            print('Already facemasked', sub)
            continue

        print(subdir)
        os.chdir(subdir)
        os.mkdir('temp')
        os.chdir('temp')
        print(sub)

        refpath = get_dcm_path(study_dir, sub, ref)

        for scan in scanlst.split(';'):
            scanpath = get_dcm_path(study_dir, sub, scan)
            outpath = get_dcm_path(study_dir, sub, scan, out=True)

            run(['/data/cerbo/data1/lin64.Dec2017/bin/mask_face', scanpath, '-b', '1', '-e', '1', '-r', refpath, '-o', outpath])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('study_dir')
    parser.add_argument('ref_file', help='csv containing 3 cols -- patid, scans to deface (semi-colon delimited), deface reference scan')
    args = parser.parse_args()

    facemask(args.study_dir, args.ref_file)
