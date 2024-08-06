#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# USAGE
if [ "$#" -ne 2 ]; then
	echo "Usage: ./generic_imaging_wrapper.sh <XNAT username> <CONFIG file>"
	echo " e.g.: ./generic_imaging_wrapper.sh  jmk1            CTS_imaging_wrapper_config.txt"
	exit 1
fi

# XNAT user is first argument
XNAT_USER=${1}

# read config file
source ${2} \
|| \
( echo "ERROR: Could not source config file: "${2} && exit 1 )

study_name=${STUDY_NAME}
study_dir=${BASE_DIR}'/'${STUDY_NAME}
# ntdb_subject_csv=${study_dir}'/ntdb_subjects.csv'

# check that study_dir exists
if [ ! -d "${study_dir}" ]; then
	echo "ERROR: "${study_dir}" must be created by hand before running this script."
	echo "       This is to prevent filling a new directory with lots and lots of data downloaded from XNAT."
	echo "       Check the spelling of the study name for errors: "${study_name}
	exit 1
fi

# Initialize BIDS naming log
echo "subject_id,xnat_subject,xnat_session,bids_subject,bids_session,bids_label,anon_needed" > ${BIDS_NAMING_LOG}

# SCRIPT_DIR='/data/nil-bluearc/black/git/tourette_imaging'
machine=$(uname -n)
case "${machine}" in
	hal ) source ${VENV_BASE_DIR}/ts_img_env_hal/bin/activate ;;
	gizmo ) source ${VENV_BASE_DIR}/ts_img_env_gizmo/bin/activate ;;
	* )
		echo "ERROR: This script only runs on gizmo or hal."
		exit 1 ;;
esac

# Freesurfer
best_T1w_log=${study_dir}/${study_name}"_best_T1w_log.csv"
echo "subject_id,xnat_subject,xnat_session,visit_type,bids_subject,bids_session,age,scanner_id,vc_number,best_mprage_snr_total,usable_minutes_rs_fmri,series_number,bids_run,bids_type,series_description,norm_string" > ${best_T1w_log}

# cd into dicom subdir
mkdir -p ${DICOM_SUBDIR}
cd ${DICOM_SUBDIR}

# get user id and group number for docker
userid_num=`id -u`
group_num=`id -g`

JSESSION=`curl -u ${XNAT_USER} -X POST ${XNAT_HOST}"/REST/JSESSION"`

# NOTE: This is a call to get all experiments in a project in csv format
curl -b JSESSIONID=${JSESSION} -o ${XNAT_PROJECT}"_MR_sessions.csv" "${XNAT_HOST}/REST/projects/${XNAT_PROJECT}/experiments?format=csv&columns=subject_label,label,date&sortBy=subject_label,date,label" \
|| \
( echo "ERROR: Could not authenticate user "${XNAT_USER}" on host "${XNAT_HOST} && exit 1 )

# this block of code uses the MR experiments csv downloaded above and loops over the rows (MR sessions).
# First time through the MR sessions, we will just download/sort DICOMs, so the XNAT JSESSION doesn't expire
{
	read
	while IFS=, read -r XNAT_ID XNAT_Subject MR_ID MR_date xsi_type project URI
	do
		# Initialize session variables
		age=""
		scanner_id=""
		vc_number=""
		usable_minutes_rs_fmri=""
		base_subject=""

		parse_BIDS_naming ${XNAT_Subject} ${MR_ID}
		
		# Check that a BIDS_subject and BIDS_session were defined
		if [ "${BIDS_subject}" == "SKIP" ] || [ "${BIDS_session}" == "SKIP" ]; then
			echo ","${XNAT_Subject}","${MR_ID}",Skipping - name does not match pattern,,," >> ${BIDS_NAMING_LOG}
			continue
		else
			echo ","${XNAT_Subject}","${MR_ID}","${BIDS_subject}","${BIDS_session}",sub-"${BIDS_subject}"_ses-"${BIDS_session}","${anon_needed} >> ${BIDS_NAMING_LOG}
			echo "BIDS naming = sub-"${BIDS_subject}"_ses-"${BIDS_session}", anon_needed = "${anon_needed}
			# continue
		fi
		# Create directories for DICOMs and dcm_sorted data
		mkdir -p ${DICOM_SUBDIR}/${XNAT_Subject}/${MR_ID}/${MR_ID}
		mkdir -p ${study_dir}/${MR_ID}

		session_dicom_rootdir=${DICOM_SUBDIR}/${XNAT_Subject}/${MR_ID}
		session_dicom_dir=${DICOM_SUBDIR}/${XNAT_Subject}/${MR_ID}/${MR_ID}
		
		pushd ${DICOM_SUBDIR}/${XNAT_Subject}/${MR_ID}
		if [ ! -s "${study_dir}/${MR_ID}/${MR_ID}.studies.txt" ]; then
			curl -b JSESSIONID=${JSESSION} -o ${MR_ID}.zip "${XNAT_HOST}/data/projects/${XNAT_PROJECT}/subjects/${XNAT_Subject}/experiments/${MR_ID}/scans/ALL/resources/DICOM/files?format=zip"
			unzip -u -j ${MR_ID}.zip -d ${MR_ID}
			rm ${MR_ID}.zip
			pushd ${MR_ID}
			dcm_files=(`ls --ignore="*.SR"`)
			dcm_first_ext=`echo ${dcm_files[0]##*.}`
			if [ ${#dcm_first_ext} -gt 5 ]; then
				dcm_first_ext=`echo ${dcm_files[0]} | cut -c1`
			fi
			popd
			pushd ${study_dir}/${MR_ID}
			dcm_sort -r${dcm_first_ext} ${session_dicom_dir}
			popd
		fi
		# make 4dfp-style .params file 
		python ${SCRIPT_DIR}/dcm_reorg_one_session.py ${study_dir} ${MR_ID} ${session_dicom_rootdir} ${SCAN_TYPE_MAPPING_FILE} --duplicates=norm
		
		popd
	done
} < ${XNAT_PROJECT}"_MR_sessions.csv"

# Loop over MR sessions again (now that we're done with the XNAT credentials)
{
	read
	while IFS=, read -r XNAT_ID XNAT_Subject MR_ID MR_date xsi_type project URI
	do
		# Initialize session variables
		age=""
		scanner_id=""
		vc_number=""
		usable_minutes_rs_fmri=""
		base_subject=""

		parse_BIDS_naming ${XNAT_Subject} ${MR_ID}

		# Check that a BIDS_subject and BIDS_session were defined
		if [ "${BIDS_subject}" == "SKIP" ] || [ "${BIDS_session}" == "SKIP" ]; then
			continue
		fi

		# Fix ImageType in XA30 CMRR and MGH DICOMs
		pushd ${study_dir}/${MR_ID}
		python ${SCRIPT_DIR}/dcm_fix_image_type.py ${study_dir}/${MR_ID}
		popd

		if ${DO_FACEMASK}; then
			# Run XNAT mask_face face-masking on DICOMs
			pushd ${study_dir}/${MR_ID}
			${SCRIPT_DIR}/facemask_MR_session.sh ${study_dir}/${MR_ID}/${MR_ID}"_nih.cnf" ${MASK_FACE_QA_DIR} ${MASK_FACE_TYPE} ${MASK_FACE_REDO}
			popd
		fi

		if ${DO_BIDS}; then
			# convert to BIDS format
			if [ "${BIDS_session}" != "SKIP" ] && [ ! -f "${BIDS_DIR}/sub-${BIDS_subject}/ses-${BIDS_session}/sub-${BIDS_subject}_ses-${BIDS_session}_scans.tsv" ]; then
				${SCRIPT_DIR}/generic_dcm_to_BIDS.sh ${BIDS_subject} ${BIDS_session} ${study_dir}/${MR_ID}/${MR_ID}"_nih.cnf" ${BIDS_HEURISTIC} ${BIDS_DIR} ${MASK_FACE_TYPE}
			fi
		fi

		if ${DO_MRIQC}; then
			# run MRIQC
			if [ ! -d "${BIDS_DIR}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}" ]; then
				docker run \
					-u ${userid_num}:${group_num} \
					--rm \
					-v ${BIDS_DIR}:/data:ro \
					-v ${BIDS_DIR}/derivatives/mriqc:/out \
					${MRIQC_DOCKER_IMAGE} \
					--modalities T1w T2w bold \
					--omp-nthreads ${NUM_MRIQC_THREADS} \
					/data /out participant \
					--participant-label ${BIDS_subject} \
					--session-id ${BIDS_session}
			fi

			if [ -d "${BIDS_DIR}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}/anat" ]; then
				# get ntdb subject id
				# ntdb_subject_id=`cat ${ntdb_subject_csv} | grep ${BIDS_subject} | cut -d"," -f1`
				ntdb_subject_id="999999999"
				# log best mprage
				pushd ${BIDS_DIR}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}/anat
				best_snr_total="0.0"
				best_T1w_BIDS_run="00"
				for mriqc_json in `ls *_T1w.json`; do
					snr_total=`grep snr_total ${mriqc_json} | cut -d":" -f2 | cut -d"," -f1`
					if (( $(echo "${snr_total} > ${best_snr_total}" | bc -l ) )); then
						best_snr_total=${snr_total}
						best_T1w_BIDS_run=`echo ${mriqc_json} | cut -d"_" -f4 | sed "s/run-//"`
						norm_string=`echo ${mriqc_json} | cut -d"_" -f3 | sed "s/rec-//"`
						series_description=`cat ${mriqc_json} | grep SeriesDescription | head -1 | cut -d'"' -f4`
						series_number=`cat ${mriqc_json} | grep SeriesNumber | head -1 | awk '{print $2}' | cut -d ',' -f1`
					fi
				done
				popd
				if [ "${best_T1w_BIDS_run}" != "00" ]; then
					# "subject_id,xnat_subject,xnat_session,visit_type,bids_subject,bids_session,age,scanner_id,vc_number,best_mprage_snr_total,usable_minutes_rs_fmri,series_number,bids_run,bids_type,series_description,norm_string"
					echo "${ntdb_subject_id},${XNAT_Subject},${MR_ID},${visit_type},${BIDS_subject},${BIDS_session},${age},${scanner_id},${vc_number},${best_snr_total},${usable_minutes_rs_fmri},${series_number},${best_T1w_BIDS_run},t1w,${series_description},${norm_string}" >> ${best_T1w_log}
				fi
			fi
		fi

		if ${DO_ENIGMA_INPUT}; then
			# find best T1w image by snr_total
			if [ -d "${BIDS_DIR}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}/anat" ]; then
				pushd ${BIDS_DIR}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}/anat
				best_snr_total="0.0"
				best_T1w_BIDS_run="00"
				for mriqc_json in `ls *_T1w.json`; do
					snr_total=`grep snr_total ${mriqc_json} | cut -d":" -f2 | cut -d"," -f1`
					if (( $(echo "${snr_total} > ${best_snr_total}" | bc -l ) )); then
						best_snr_total=${snr_total}
						best_T1w_BIDS_run=`echo ${mriqc_json} | cut -d"_" -f4 | sed "s/run-//"`
						norm_string=`echo ${mriqc_json} | cut -d"_" -f3 | sed "s/rec-//"`
					fi
				done
				popd
				
				# Prepare for running ENIGMA TS Freesurfer T1 pipeline
				if [ "${best_T1w_BIDS_run}" != "00" ]; then
					if ${anon_needed}; then
						# anonymize subjid using pre-generated identifier
						anon_number=`grep ${base_subject} ${ANON_KEY_CSV} | cut -d"," -f3`
						anon_cohort=`grep ${base_subject} ${ANON_KEY_CSV} | cut -d"," -f4`
						echo "anonymization = "${anon_cohort}" "${anon_number}
						enigma_subjid="sub-"${institution_code}${anon_cohort}${anon_number}"_ses-"${BIDS_session}
					else 
						enigma_subjid="sub-"${BIDS_subject}"_ses-"${BIDS_session}
					fi
					# copy input nii.gz to ENIGMA inputs dir
					mkdir -p ${ENIGMA_INPUT_DIR}/${enigma_subjid}
					cp -upr \
						${BIDS_DIR}/sub-${BIDS_subject}/ses-${BIDS_session}/anat/sub-${BIDS_subject}_ses-${BIDS_session}_rec-${norm_string}_run-${best_T1w_BIDS_run}_T1w.nii.gz \
						${ENIGMA_INPUT_DIR}/${enigma_subjid}/${enigma_subjid}.nii.gz
					cp -upr \
						${BIDS_DIR}/sub-${BIDS_subject}/ses-${BIDS_session}/anat/sub-${BIDS_subject}_ses-${BIDS_session}_rec-${norm_string}_run-${best_T1w_BIDS_run}_T1w.json \
						${ENIGMA_INPUT_DIR}/${enigma_subjid}/${enigma_subjid}.json
					chmod 664 ${ENIGMA_INPUT_DIR}/${enigma_subjid}/*.*
					if ${anon_needed}; then
						# clean nifti header and json
						python ${SCRIPT_DIR}/clean_nii_header.py ${ENIGMA_INPUT_DIR}/${enigma_subjid}/${enigma_subjid}.nii.gz -n aux_file -j ImageComments
					fi

					# Run ENIGMA Freesurfer
					# ${enigma_ts_repo}/1_enigma_runfreesurfer.sh ${enigma_subjid} ${enigma_base_dir}
				fi
			fi
		fi

		# SKIP THE REST OF THE LOOP WHILE DEBUGGING
		continue

	done
} < ${XNAT_PROJECT}"_MR_sessions.csv"

exit 0
