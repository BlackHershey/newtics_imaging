#!/bin/bash

# USAGE
if [ "$#" -ne 6 ]; then
	echo "Usage: ./generic_dcm_to_BIDS.sh <BIDS subject> <BIDS session> <params file>                         <heuristic script>                         <BIDS directory>            <defacing type>"
	echo " e.g.: ./generic_dcm_to_BIDS.sh  NT999          screen         /some/directory/NT999_screen_nih.cif  /some/directory/generic_BIDS_heuristic.py  /some/study/directory/BIDS defaced"
	exit 1
fi

converter=dcm2niix
bids_opts="notop"

subject=${1}
session_label=${2}
params_file=${3}
heuristic_script=${4}
bids_dir=${5}
defacing_type=${6}

cd ${bids_dir}

dicom_dirs=""

dcm_sorted_dir=$(dirname "${params_file}")

mprs=(`cat ${params_file} | grep "mprs" | cut -d"(" -f2 | cut -d")" -f1`)
tse=(`cat ${params_file} | grep "tse" | cut -d"(" -f2 | cut -d")" -f1`)
nmw=(`cat ${params_file} | grep "nmw" | cut -d"(" -f2 | cut -d")" -f1`)
megre=(`cat ${params_file} | grep "megre" | cut -d"(" -f2 | cut -d")" -f1`)
flair=(`cat ${params_file} | grep "flair" | cut -d"(" -f2 | cut -d")" -f1`)
pdt2=(`cat ${params_file} | grep "pdt2" | cut -d"(" -f2 | cut -d")" -f1`)
fstd=(`cat ${params_file} | grep "fstd" | cut -d"(" -f2 | cut -d")" -f1`)
sbref=(`cat ${params_file} | grep "sbref" | cut -d"(" -f2 | cut -d")" -f1`)
gre=(`cat ${params_file} | grep "gre" | cut -d"(" -f2 | cut -d")" -f1`)
sefm=(`cat ${params_file} | grep "sefm" | cut -d"(" -f2 | cut -d")" -f1`)
dwi=(`cat ${params_file} | grep "dwi" | cut -d"(" -f2 | cut -d")" -f1`)
pcasl=(`cat ${params_file} | grep "pcasl" | grep -v "pcasl_m0" | cut -d"(" -f2 | cut -d")" -f1`)
pcasl_m0=(`cat ${params_file} | grep "pcasl_m0" | cut -d"(" -f2 | cut -d")" -f1`)
pasl=(`cat ${params_file} | grep "pasl" | grep -v "pasl_m0" | cut -d"(" -f2 | cut -d")" -f1`)
pasl_m0=(`cat ${params_file} | grep "pasl_m0" | cut -d"(" -f2 | cut -d")" -f1`)
struct_series=(${mprs[@]} ${tse[@]} ${flair[@]})
other_series=(${fstd[@]} ${sbref[@]} ${gre[@]} ${sefm[@]} ${dwi[@]} ${pcasl[@]} ${pcasl_m0[@]} ${pasl[@]} ${pasl_m0[@]} ${megre[@]} ${pdt2[@]} ${nmw[@]})

for dicom_series in ${struct_series[@]}
do
	case "${defacing_type}" in
        defaced ) dicom_dirs="${dicom_dirs}"" ${dcm_sorted_dir}/study${dicom_series}_defaced" ;;
		refaced ) dicom_dirs="${dicom_dirs}"" ${dcm_sorted_dir}/study${dicom_series}_refaced" ;;
		none ) dicom_dirs="${dicom_dirs}"" ${dcm_sorted_dir}/study${dicom_series}" ;;
		* ) dicom_dirs="${dicom_dirs}"" ${dcm_sorted_dir}/study${dicom_series}" ;;
    esac
done

for dicom_series in ${other_series[@]}
do
	dicom_dirs="${dicom_dirs}"" ${dcm_sorted_dir}/study${dicom_series}"
done

echo "DICOM DIRS = ${dicom_dirs}"

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
