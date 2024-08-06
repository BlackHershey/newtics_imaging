#!/bin/bash
scripts_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# USAGE
if [ "$#" -ne 2 ]; then
	echo "Usage: ./mask_face_wrapper.sh <DICOM directory> <QA dir>"
	echo " e.g.: ./mask_face_wrapper.sh  study10 /path/to/QA_dir"
	exit 1
fi

QA_dir=${2}
mkdir -p ${QA_dir}

docker_image=xnat/facemasking:1.0

dicom_dir=${1}
study_dir=$(basename ${dicom_dir})

dicom_parent_dir=$(dirname ${dicom_dir})
patid=$(basename ${dicom_parent_dir})

pushd ${dicom_parent_dir}

if [ -d {study_dir}"_defaced" ]; then
	/bin/rm -r ${study_dir}"_defaced"
fi
mkdir -p ${study_dir}"_defaced"/${study_dir}"_DICOM"
cd ${study_dir}"_defaced"

# Check for Enhanced DICOM (XA30), use dicom3tools to unenhance if necessary
dicoms=(${dicom_dir}/*)
software_version=$(dckey -key SoftwareVersions ${dicoms[0]} 2>&1 > /dev/null)

if [[ ${software_version} == *"XA30"* ]]; then
	pushd ${study_dir}"_DICOM"
	dcuncat -unenhance -sameseries -instancenumber -of ${patid}"_"${study_dir}"_unenhanced_" ${dicom_dir}/*
	for dcm in *_unenhanced_*; do
		mv ${dcm} ${dcm}.dcm
	done
	popd
else
	cp ${dicom_dir}/*.* ${study_dir}"_DICOM"/
fi

usernum=$(id -u)
groupnum=$(id -g)

docker run -u ${usernum}:${groupnum} -v $(pwd):/docker_mount --rm ${docker_image} mask_face_nomatlab ${study_dir}"_DICOM" -b 1 -e 1

# clean up from mask_face run
/bin/rm *${study_dir}"_DICOM"*.*
mv maskface/${study_dir}"_DICOM_normfilter.png" ${QA_dir}/${patid}"_"${study_dir}"_DICOM_normfilter.png"
mv maskface/${study_dir}"_DICOM_normfilter_surf.png" ${QA_dir}/${patid}"_"${study_dir}"_DICOM_normfilter_surf.png"
mv maskface/${study_dir}"_DICOM"_masked_nii_orig.img ${QA_dir}/${patid}"_"${study_dir}"_DICOM_masked_nii_orig.img"
mv maskface/${study_dir}"_DICOM"_masked_nii_orig.hdr ${QA_dir}/${patid}"_"${study_dir}"_DICOM_masked_nii_orig.hdr"
mv DICOM_DEFACED/${study_dir}"_DICOM"/*.* ./
/bin/rm -r ${study_dir}"_DICOM" maskface DICOM_DEFACED

popd

exit 0

