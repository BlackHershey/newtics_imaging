import argparse
import pydicom
import sys

from glob import glob

parser = argparse.ArgumentParser()
parser.add_argument('dcm_pattern')
args = parser.parse_args()

for dcm in glob(args.dcm_pattern):
    ds = pydicom.read_file(dcm)
    for tag in [(0x0008,0x1070), (0x0008, 0x0090), (0x0008,0x1050)]:
        if tag in ds and ds[tag].value != "":
            print('Possible PHI -- needs to be checked', dcm)
            sys.exit(1)