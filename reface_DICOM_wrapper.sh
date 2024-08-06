#!/bin/bash
scripts_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# USAGE
if [ "$#" -ne 3 ]; then
	echo "Usage: ./reface_DICOM_wrapper.sh <DICOM directory>  <imType>  <QA dir>"
	echo " e.g.: ./reface_DICOM_wrapper.sh  study10            T1        /path/to/QA_dir"
	exit 1
fi

imType_arg=${2}

QA_dir=${3}
mkdir -p ${QA_dir}

dicom_dir=${1}
study_dir=$(basename ${dicom_dir})
series_num=$(echo ${study_dir} | sed "s/study//")

dicom_parent_dir=$(dirname ${dicom_dir})
patid=$(basename ${dicom_parent_dir})
patid_dicom_dir=${dicom_parent_dir}/${patid}"_"${study_dir}
mkdir -p ${patid_dicom_dir}

# Check for Enhanced DICOM (XA30), use dicom3tools to unenhance if necessary
dicoms=(${dicom_dir}/*)
software_version=$(dckey -key SoftwareVersions ${dicoms[0]} 2>&1 > /dev/null)
# echo "############## SoftwareVersions = ${software_version} ###################"

# exit 0

if [[ ${software_version} == *"XA30"* ]]; then
	pushd ${patid_dicom_dir}
	dcuncat -unenhance -sameseries -instancenumber -of ${patid}"_"${study_dir}"_unenhanced_" ${dicom_dir}/*
	for dcm in *_unenhanced_*; do
		mv ${dcm} ${dcm}.dcm
	done
	popd
else
	cp ${dicom_dir}/*.* ${patid_dicom_dir}/
fi

pushd ${dicom_parent_dir}

if [ -d ${patid}"_"${study_dir}"_refaced" ]; then
	/bin/rm -r ${patid}"_"${study_dir}"_refaced"
fi
mkdir -p ${patid}"_"${study_dir}"_refaced"

${scripts_dir}/run_mri_reface_docker.sh ${patid_dicom_dir} ${patid}"_"${study_dir}"_refaced" -imType ${imType_arg}

exit 0

# clean up from mri_reface run
cd ${patid}"_"${study_dir}"_refaced"
orig_nii=$(ls *_${series_num}.nii)
orig_name_root=$(echo ${orig_nii} | sed "s/_${series_num}.nii//")
/bin/rm *MCALT*
mv *.nii ${QA_dir}/
mv *.png ${QA_dir}/
cd dcm
for dcm in *_????.dcm; do
	new_dcm_name=$(echo ${dcm} | sed "s/${orig_name_root}_${series_num}_deFaced_//")
	mv ${dcm} ../${new_dcm_name}
done
cd ..
rmdir dcm
cd ..
mv ${patid}"_"${study_dir}"_refaced" ${study_dir}"_refaced"
/bin/rm -r ${patid_dicom_dir}

popd

exit 0
