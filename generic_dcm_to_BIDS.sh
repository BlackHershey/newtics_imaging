#!/bin/bash

# USAGE
if [ "$#" -ne 5 ]; then
	echo "Usage: ./generic_dcm_to_BIDS.sh <BIDS subject> <BIDS session> <params file>                         <heuristic script>                         <BIDS directory>"
	echo " e.g.: ./generic_dcm_to_BIDS.sh  NT999          screen         /some/directory/NT999_screen_nih.cif  /some/directory/generic_BIDS_heuristic.py  /some/study/directory/BIDS"
	exit 1
fi

converter=dcm2niix
bids_opts="notop"

subject=${1}
session_label=${2}
params_file=${3}
heuristic_script=${4}
bids_dir=${5}

cd ${bids_dir}

dicom_dirs=""

dcm_sorted_dir=$(dirname "${params_file}")

mprs=(`cat ${params_file} | grep "mprs" | cut -d"(" -f2 | cut -d")" -f1`)
tse=(`cat ${params_file} | grep "tse" | cut -d"(" -f2 | cut -d")" -f1`)
flair=(`cat ${params_file} | grep "flair" | cut -d"(" -f2 | cut -d")" -f1`)
fstd=(`cat ${params_file} | grep "fstd" | cut -d"(" -f2 | cut -d")" -f1`)
gre=(`cat ${params_file} | grep "gre" | cut -d"(" -f2 | cut -d")" -f1`)
dwi=(`cat ${params_file} | grep "dwi" | cut -d"(" -f2 | cut -d")" -f1`)
pcasl=(`cat ${params_file} | grep "pcasl" | grep -v "pcasl_m0" | cut -d"(" -f2 | cut -d")" -f1`)
pcasl_m0=(`cat ${params_file} | grep "pcasl_m0" | cut -d"(" -f2 | cut -d")" -f1`)
pcasl=(`cat ${params_file} | grep "pasl" | grep -v "pasl_m0" | cut -d"(" -f2 | cut -d")" -f1`)
struct_series=(${mprs[@]} ${tse[@]} ${flair[@]})
other_series=(${fstd[@]} ${gre[@]} ${dwi[@]} ${pcasl[@]} ${pcasl_m0[@]} ${pasl[@]})

for dicom_series in ${struct_series[@]}
do
	dicom_dirs="${dicom_dirs}"" ${dcm_sorted_dir}/study${dicom_series}_defaced"
done

for dicom_series in ${other_series[@]}
do
	dicom_dirs="${dicom_dirs}"" ${dcm_sorted_dir}/study${dicom_series}"
done


heudiconv \
	--outdir ${bids_dir} \
	--converter ${converter} \
	--subjects ${subject} \
	--ses ${session_label} \
	--files ${dicom_dirs} \
	--grouping all \
	--heuristic ${heuristic_script} \
	--overwrite \
	--bids ${bids_opts}

exit 0
