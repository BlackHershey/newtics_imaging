import argparse
import pydicom

from glob import glob

parser = argparse.ArgumentParser()
parser.add_argument('dcm_pattern')
args = parser.parse_args()

for dcm in glob(args.dcm_pattern):
    need_to_save=False
    ds = pydicom.read_file(dcm)
    for tag in [(0x0008,0x1070), (0x0008, 0x0090), (0x0008,0x1050)]:
        if tag in ds and ds[tag].value != "":
            ds[tag].value = ""
            need_to_save=True
    if need_to_save:
        ds.save_as(dcm)
