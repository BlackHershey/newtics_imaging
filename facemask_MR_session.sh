#!/bin/bash

scripts_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
nih_params_file=${1}
QA_dir=${2}
deface_type=${3}

if [ "$#" -lt 4 ]; then
	redo="0"
else
	redo=${4}
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

# check which defacing type
case "${deface_type}" in
	defaced )
		deface_label="defaced"
		for dicom_series in ${struct_series[@]}
		do
			if [ ! -d "study${dicom_series}_${deface_label}" ] || [ -z "$( ls -A study${dicom_series}_${deface_label} )" ] || [ "${redo}" -gt 0 ]; then
				${scripts_dir}/mask_face_wrapper.sh ${MR_session_dir}/study${dicom_series} ${QA_dir}
			fi
		done ;;
	refaced ) 
		deface_label="refaced"
		for dicom_series in ${mprs[@]}
		do
			if [ ! -d "study${dicom_series}_${deface_label}" ] || [ "${redo}" -gt 0 ]; then
				${scripts_dir}/reface_DICOM_wrapper.sh ${MR_session_dir}/study${dicom_series} T1 ${QA_dir}
			fi
		done
		for dicom_series in ${tse[@]}
		do
			if [ ! -d "study${dicom_series}_${deface_label}" ] || [ "${redo}" -gt 0 ]; then
				${scripts_dir}/reface_DICOM_wrapper.sh ${MR_session_dir}/study${dicom_series} T2 ${QA_dir}
			fi
		done
		for dicom_series in ${flair[@]}
		do
			if [ ! -d "study${dicom_series}_${deface_label}" ] || [ "${redo}" -gt 0 ]; then
				${scripts_dir}/reface_DICOM_wrapper.sh ${MR_session_dir}/study${dicom_series} FLAIR ${QA_dir}
			fi
		done ;;
esac


exit 0
