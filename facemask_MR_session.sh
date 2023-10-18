#!/bin/bash

scripts_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
nih_params_file=${1}
QA_dir=${2}

if [ "$#" -lt 3 ]; then
	redo="0"
else
	redo=${3}
fi

MR_ID=$(basename "${nih_params_file}" | sed 's/_nih.cnf//')
MR_session_dir=$(dirname "${nih_params_file}")
# Subject=`echo ${MR_ID} | cut -c1-5`
echo ${MR_ID}
# echo ${nih_params_file}

mprs=(`cat ${nih_params_file} | grep "mprs" | cut -d"(" -f2 | cut -d")" -f1`)
tse=(`cat ${nih_params_file} | grep "tse" | cut -d"(" -f2 | cut -d")" -f1`)
flair=(`cat ${nih_params_file} | grep "flair" | cut -d"(" -f2 | cut -d")" -f1`)
struct_series=(${mprs[@]} ${tse[@]} ${flair[@]})

# for dicom_series in ${mprs[@]}
# do
# 	echo ${MR_ID}","${dicom_series}",mprage" >> ${output_csv}
# done
# for dicom_series in ${tse[@]}
# do
# 	echo ${MR_ID}","${dicom_series}",T2" >> ${output_csv}
# done

for dicom_series in ${struct_series[@]}
do
	if [ ! -d "study${dicom_series}_defaced" ] || [ "${redo}" -gt 0 ]; then
		${scripts_dir}/mask_face_wrapper.csh ${MR_session_dir}/study${dicom_series} ${QA_dir}
	fi
done

exit 0
