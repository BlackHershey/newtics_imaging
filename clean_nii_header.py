import argparse
import json
import re
import nibabel as nib

parser = argparse.ArgumentParser()
parser.add_argument('input_nii', help='nifti image to be cleaned')
parser.add_argument('-n', '--nifti_hdr_fields', nargs='+', help='one or more nifti header fields to make blank', required=True)
parser.add_argument('-j', '--json_fields', nargs='+', help='one or more json fields to make blank', required=True)
parser.add_argument('-v', '--verbose', help='turn on verbose print messages', action='store_true')
args = parser.parse_args()

# open input nifti
nii_img = nib.load(args.input_nii)

# loop over nifti header fields
for field in args.nifti_hdr_fields:
    nii_img.header[field] = None

# save nifti image
nib.save(nii_img, args.input_nii)

# open json
json_file = re.sub('nii(\.gz)?$', 'json', args.input_nii)
with open(json_file, 'r') as openfile:
    nii_json = json.load(openfile)

# loop over json fields
for field in args.json_fields:
    nii_json[field] = None

# save json
with open(json_file, "w") as outfile:
    json.dump(nii_json, outfile, indent=2)
