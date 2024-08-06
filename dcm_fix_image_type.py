import argparse
import glob
import os
import pydicom

parser = argparse.ArgumentParser()
parser.add_argument('session_dir', help='directory containing a single MR session with multiple "study" directories')
parser.add_argument('-v', '--verbose', help='turn on verbose print messages', action='store_true')
args = parser.parse_args()
session_dir = args.session_dir
verbosity=args.verbose

dcm_files = glob.glob(os.path.join(session_dir,'study*', '*'))

if not dcm_files:
	print('Could not find DICOM files in {}/study*'.format(session_dir))

# read first DICOM file, check for XA30
if verbosity:
	print('Check for XA30 DICOMs')
xa30_checked = False
xa30 = False
while not xa30_checked:
	for dcm_file in dcm_files:
		try:
			ds = pydicom.read_file(dcm_file)
			if 'XA30' in ds.SoftwareVersions.upper():
				xa30 = True
			break
		except:
			pass
	xa30_checked = True

if xa30:
	for dcm_file in dcm_files:

		# load DICOM file
		ds = pydicom.read_file(dcm_file)

		# read original ImageType
		image_type = ds.ImageType

		# read ImageType from Vendor private tags
		try:
			private_image_type = ds[0x5200,0x9230][0][0x21,0x11fe][0][0x21,0x1175].value
		except:
			try:
				private_image_type = ds[0x5200,0x9230][0][0x21,0x10fe][0][0x21,0x1075].value
			except:
				private_image_type = image_type

		if private_image_type not in image_type:
			ds.ImageType = private_image_type
			ds.save_as(ds.filename)




