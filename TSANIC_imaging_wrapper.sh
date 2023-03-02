#!/bin/bash

# XNAT info
XNAT_host="https://cnda.wustl.edu"
XNAT_project="TSANIC_ALL"
# XNAT_user is first argument
XNAT_user=${1}

# USAGE
if [ "$#" -ne 1 ]; then
	echo "Usage: ./TSANiC_imaging_wrapper.sh <CNDA_username>"
	echo " e.g.: ./TSANIC_imaging_wrapper.sh jmk1"
	exit 1
fi

DO_FACEMASK=false
DO_BIDS_AND_MRIQC=false
DO_FREESURFER=false
DO_ENIGMA_FREESURFER=false


study_dir='/data/nil-bluearc/black/TSANIC'
study_name='TSANIC'
# ntdb_subject_csv=${study_dir}'/ntdb_subjects.csv'

# 4dfp params file
scan_params_mapping_file=${study_dir}/${study_name}"_scan_mapping_config.json"

# XNAT mask_face
mask_face_redo="0"
mask_face_QA_dir=${study_dir}"/maskface_QA"

# BIDS
BIDS_dir=${study_dir}"/BIDS"
BIDS_heuristic=${BIDS_dir}"/code/"${study_name}"_heuristic.py"
BIDS_naming_log=${study_dir}/${study_name}"_BIDS_naming_log.csv"
echo "subject_id,xnat_subject,xnat_session,bids_subject,bids_session,bids_label,anon_needed" > ${BIDS_naming_log}
dicom_subdir=${study_dir}"/DICOM"
scripts_dir='/data/nil-bluearc/black/git/tourette_imaging'
venv_dir='/data/nil-bluearc/black/env'
machine=$(uname -n)
case "${machine}" in
	hal ) source ${venv_dir}/ts_img_env_hal/bin/activate ;;
	cerbo ) source ${venv_dir}/ts_img_env_cerbo/bin/activate ;;
	* )
		echo "ERROR: This script only runs on cerbo or hal."
		exit 1 ;;
esac


# Freesurfer
best_T1w_log=${study_dir}/${study_name}"_best_T1w_log.csv"
echo "subject_id,xnat_subject,xnat_session,visit_type,bids_subject,bids_session,age,scanner_id,vc_number,best_mprage_snr_total,usable_minutes_rs_fmri,series_number,bids_run,bids_type,series_description,norm_string" > ${best_T1w_log}
case "${machine}" in
	hal ) FREESURFER_HOME="/data/nil-bluearc/hershey/unix/software/freesurfer-7.3.2-centos8" ;;
	cerbo ) FREESURFER_HOME="/data/nil-bluearc/hershey/unix/software/freesurfer-7.3.2-centos7" ;;
	* )
		echo "ERROR: This script only runs on cerbo or hal."
		exit 1 ;;
esac
SUBJECTS_DIR=${BIDS_dir}/derivatives/freesurfer-7.3.2
mkdir -p ${SUBJECTS_DIR}

# ENIGMA-TS
enigma_base_dir='/data/nil-bluearc/black/ENIGMA-TS'
enigma_input_dir=${enigma_base_dir}/inputs
enigma_output_dir=${enigma_base_dir}/outputs
enigma_wrapscripts_dir=${enigma_base_dir}/enigma_wrapscripts
enigma_ts_repo='/data/nil-bluearc/black/git/ENIGMA_TS_T1_pipeline'

# cd into dicom subdir
cd ${dicom_subdir}

# get user id and group number for docker
userid_num=`id -u`
group_num=`id -g`

JSESSION=`curl -u ${XNAT_user} -X POST ${XNAT_host}"/REST/JSESSION"`

# NOTE: This is a call to get all experiments in a project in csv format
curl -b JSESSIONID=${JSESSION} -o ${XNAT_project}"_MR_sessions.csv" "${XNAT_host}/REST/projects/${XNAT_project}/experiments?format=csv&columns=subject_label,label,date&sortBy=subject_label,date,label" \
|| \
( echo "ERROR: Could not authenticate user "${XNAT_user}" on host "${XNAT_hostname} && exit 1 )

# this block of code uses the MR experiments csv downloaded above and loops over the rows.
{
	read
	while IFS=, read -r XNAT_ID XNAT_Subject MR_ID MR_date xsi_type project URI
	do
		BIDS_subject="SKIP"
		BIDS_session="SKIP"
		
		# Define other session variables
		age=""
		scanner_id=""
		vc_number=""
		usable_minutes_rs_fmri=""
		anon_needed=false

		# switch over subject to get BIDS session
		case "${XNAT_Subject}" in
			TSANIC_WU_TRACK?? )
				BIDS_subject="WU"`echo ${XNAT_Subject} | sed "s/TSANIC_WU_//"`
				anon_needed=true
				case "${MR_ID}" in
					TSANIC_WU_TRACK??_s1 ) BIDS_session="01" ;;
					TSANIC_WU_TRACK??_s2 ) BIDS_session="02" ;;
					TSANIC_WU_TRACK??_s3 ) BIDS_session="03" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_WU_TR??? )
				BIDS_subject="WU"`echo ${XNAT_Subject} | sed "s/TSANIC_WU_//"`
				case "${MR_ID}" in
					TSANIC_WU_vc????? ) BIDS_session="01" ;;
					TSANIC_WU_vc?????_MR1 ) BIDS_session="01" ;;
					TSANIC_WU_vc?????_MR2 ) BIDS_session="02" ;;
					TSANIC_WU_vc?????_MR3 ) BIDS_session="03" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_WU_vc????? )
				BIDS_subject="WU"`echo ${XNAT_Subject} | sed "s/TSANIC_WU_//"`
				case "${MR_ID}" in
					TSANIC_WU_vc????? ) BIDS_session="01" ;;
					TSANIC_WU_vc?????_MR1 ) BIDS_session="01" ;;
					TSANIC_WU_vc?????_MR2 ) BIDS_session="02" ;;
					TSANIC_WU_vc?????_MR3 ) BIDS_session="03" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_WU_[a-z][a-z][a-z][0-9][0-9][0-9] )
				BIDS_subject="WU"`echo ${XNAT_Subject} | sed "s/TSANIC_WU_//"`
				case "${MR_ID}" in
					TSANIC_WU_[a-z][a-z][a-z][0-9][0-9][0-9]_d1 ) BIDS_session="01" ;;
					TSANIC_WU_[a-z][a-z][a-z][0-9][0-9][0-9]_d2 ) BIDS_session="02" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_WU_NIC???? )
				BIDS_subject="WU"`echo ${XNAT_Subject} | sed "s/TSANIC_WU_//"`
				case "${MR_ID}" in
					TSANIC_WU_NIC???? ) BIDS_session="01" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_WU_LO5_??? )
				BIDS_subject="WU"`echo ${XNAT_Subject} | sed "s/TSANIC_WU_//" | sed "s/_//"`
				anon_needed=true
				case "${MR_ID}" in
					TSANIC_WU_LO5_??? ) BIDS_session="01" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_WU_[0-9][0-9][0-9][0-9] )
				BIDS_subject="WU"`echo ${XNAT_Subject} | sed "s/TSANIC_WU_//" | sed "s/_//"`
				case "${MR_ID}" in
					TSANIC_WU_[0-9][0-9][0-9][0-9]_d1 ) BIDS_session="01" ;;
					TSANIC_WU_[0-9][0-9][0-9][0-9]_d2 ) BIDS_session="02" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_KKI_TD[0-9][0-9][0-9][0-9] )
				BIDS_subject=`echo ${XNAT_Subject} | sed "s/TSANIC_//" | sed "s/_//"`
				case "${MR_ID}" in
					TSANIC_KKI_TD[0-9][0-9][0-9][0-9]_1 ) BIDS_session="01" ;;
					TSANIC_KKI_TD[0-9][0-9][0-9][0-9]_2 ) BIDS_session="02" ;;
					TSANIC_KKI_TD[0-9][0-9][0-9][0-9]_3 ) BIDS_session="03" ;;
					TSANIC_KKI_TD[0-9][0-9][0-9][0-9]_4 ) BIDS_session="04" ;;
					TSANIC_KKI_TD[0-9][0-9][0-9][0-9]_5 ) BIDS_session="05" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_KKI_TS[0-9][0-9] )
				BIDS_subject=`echo ${XNAT_Subject} | sed "s/TSANIC_//" | sed "s/_//"`
				case "${MR_ID}" in
					TSANIC_KKI_TS[0-9][0-9]_1 ) BIDS_session="01" ;;
					TSANIC_KKI_TS[0-9][0-9]_2 ) BIDS_session="02" ;;
					TSANIC_KKI_TS[0-9][0-9]_3 ) BIDS_session="03" ;;
					TSANIC_KKI_TS[0-9][0-9]_4 ) BIDS_session="04" ;;
					TSANIC_KKI_TS[0-9][0-9]_5 ) BIDS_session="05" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_NYU_[0-9][0-9][0-9][0-9] )
				BIDS_subject=`echo ${XNAT_Subject} | sed "s/TSANIC_//" | sed "s/_//"`
				case "${MR_ID}" in
					TSANIC_NYU_[0-9][0-9][0-9][0-9] ) BIDS_session="01" ;;
					TSANIC_NYU_[0-9][0-9][0-9][0-9]_1 ) BIDS_session="01" ;;
					TSANIC_NYU_[0-9][0-9][0-9][0-9]_2 ) BIDS_session="02" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_UCLA_CIDAR_[0-9][0-9][0-9] )
				BIDS_subject="UCLA"`echo ${XNAT_Subject} | sed "s/TSANIC_UCLA_CIDAR_//"`
				case "${MR_ID}" in
					TSANIC_UCLA_CIDAR_[0-9][0-9][0-9]_1 ) BIDS_session="01" ;;
					TSANIC_UCLA_CIDAR_[0-9][0-9][0-9]_2 ) BIDS_session="02" ;;
					TSANIC_UCLA_CIDAR_[0-9][0-9][0-9]_3 ) BIDS_session="03" ;;
					TSANIC_UCLA_CIDAR_[0-9][0-9][0-9]_4 ) BIDS_session="04" ;;
					TSANIC_UCLA_CIDAR_[0-9][0-9][0-9]_5 ) BIDS_session="05" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_UCLA_CIDAR_[0-9][0-9] )
				BIDS_subject="UCLA0"`echo ${XNAT_Subject} | sed "s/TSANIC_UCLA_CIDAR_//"`
				case "${MR_ID}" in
					TSANIC_UCLA_CIDAR_[0-9][0-9]_1 ) BIDS_session="01" ;;
					TSANIC_UCLA_CIDAR_[0-9][0-9]_2 ) BIDS_session="02" ;;
					TSANIC_UCLA_CIDAR_[0-9][0-9]_3 ) BIDS_session="03" ;;
					TSANIC_UCLA_CIDAR_[0-9][0-9]_4 ) BIDS_session="04" ;;
					TSANIC_UCLA_CIDAR_[0-9][0-9]_5 ) BIDS_session="05" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			TSANIC_UCLA_TSANIC_[0-9][0-9][0-9][0-9] )
				BIDS_subject="UCLATSANIC"`echo ${XNAT_Subject} | sed "s/TSANIC_UCLA_TSANIC_//"`
				case "${MR_ID}" in
					TSANIC_UCLA_TSANIC_[0-9][0-9][0-9][0-9] ) BIDS_session="01" ;;
					* ) BIDS_session="SKIP" ;;
				esac ;;
			* ) 
				BIDS_subject="SKIP"
				BIDS_session="SKIP" ;;
		esac
		
		# Check that a BIDS_subject and BIDS_session were defined
		if [ "${BIDS_subject}" == "SKIP" ] || [ "${BIDS_session}" == "SKIP" ]; then
			echo ","${XNAT_Subject}","${MR_ID}",Skipping - name does not match pattern,,," >> ${BIDS_naming_log}
			continue
		else
			echo ","${XNAT_Subject}","${MR_ID}","${BIDS_subject}","${BIDS_session}",sub-"${BIDS_subject}"_ses-"${BIDS_session}","${anon_needed} >> ${BIDS_naming_log}
			continue
		fi
		# Create directories for DICOMs and dcm_sorted data
		mkdir -p ${XNAT_Subject}/${MR_ID}/${MR_ID}
		mkdir -p ${study_dir}/${MR_ID}

		session_dicom_rootdir=${dicom_subdir}/${XNAT_Subject}/${MR_ID}
		session_dicom_dir=${dicom_subdir}/${XNAT_Subject}/${MR_ID}/${MR_ID}
		
		pushd ${XNAT_Subject}/${MR_ID}
		if [ ! -s "${study_dir}/${MR_ID}/${MR_ID}.studies.txt" ]; then
			curl -b JSESSIONID=${JSESSION} -o ${MR_ID}.zip "${XNAT_host}/data/projects/${XNAT_project}/subjects/${XNAT_Subject}/experiments/${MR_ID}/scans/ALL/resources/DICOM/files?format=zip"
			unzip -u -j ${MR_ID}.zip -d ${MR_ID}
			rm ${MR_ID}.zip
			pushd ${MR_ID}
			dcm_files=(`ls *.*`)
			dcm_first_ext=`echo ${dcm_files[0]##*.}`
			popd
			pushd ${study_dir}/${MR_ID}
			dcm_sort -r${dcm_first_ext} ${session_dicom_dir}
			
			popd
		fi
		# make 4dfp-style .params file 
		python ${scripts_dir}/dcm_reorg_one_session.py ${study_dir} ${MR_ID} ${session_dicom_rootdir} ${scan_params_mapping_file} --duplicates=norm
		
		if ${DO_FACEMASK}; then
			# Run XNAT mask_face face-masking on DICOMs
			pushd ${study_dir}/${MR_ID}
			${scripts_dir}/facemask_MR_session.sh ${study_dir}/${MR_ID}/${MR_ID}"_nih.cnf" ${mask_face_QA_dir} ${mask_face_redo}
			popd
		fi

		if ${DO_BIDS_AND_MRIQC}; then
			# convert to BIDS format
			if [ "${BIDS_session}" != "SKIP" ] && [ ! -f "${BIDS_dir}/sub-${BIDS_subject}/ses-${BIDS_session}/sub-${BIDS_subject}_ses-${BIDS_session}_scans.tsv" ]; then
				${BIDS_dir}/code/NewTics_dcm_to_BIDS.sh ${BIDS_subject} ${BIDS_session} ${study_dir}/${MR_ID}/${MR_ID}"_nih.cnf" ${BIDS_heuristic} 
			fi
			
			# run MRIQC
			if [ ! -d "${BIDS_dir}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}" ]; then
				docker run \
					-u ${userid_num}:${group_num} \
					--rm \
					-v /data/nil-bluearc/black/NewTics/BIDS:/data:ro \
					-v /data/nil-bluearc/black/NewTics/BIDS/derivatives/mriqc:/out \
					nipreps/mriqc:latest /data /out participant \
					--participant-label ${BIDS_subject} \
					--session-id ${BIDS_session}
			fi

			if [ -d "${BIDS_dir}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}/anat" ]; then
				# get ntdb subject id
				ntdb_subject_id=`cat ${ntdb_subject_csv} | grep ${BIDS_subject} | cut -d"," -f1`
				# log best mprage
				pushd ${BIDS_dir}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}/anat
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
				# "subject_id,xnat_subject,xnat_session,visit_type,bids_subject,bids_session,age,scanner_id,vc_number,best_mprage_snr_total,usable_minutes_rs_fmri,series_number,bids_run,bids_type,series_description,norm_string"
				echo "${ntdb_subject_id},${XNAT_Subject},${MR_ID},${visit_type},${BIDS_subject},${BIDS_session},${age},${scanner_id},${vc_number},${best_snr_total},${usable_minutes_rs_fmri},${series_number},${best_T1w_BIDS_run},t1w,${series_description},${norm_string}" >> ${best_T1w_log}
			fi
		fi

		if ${DO_FREESURFER}; then
			# find best T1w image by snr_total
			if [ -d "${BIDS_dir}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}/anat" ]; then
				pushd ${BIDS_dir}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}/anat
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
				
				# run Freesurfer
				aparc_aseg_mgz=${SUBJECTS_DIR}"/sub-"${BIDS_subject}"_ses-"${BIDS_session}"/mri/aparc+aseg.mgz"
				if [ "${best_T1w_BIDS_run}" != "00" ] && [ ! -f "${aparc_aseg_mgz}" ]; then
					/data/nil-bluearc/black/git/newtics_imaging/freesurfer_wrapper.csh \
						${FREESURFER_HOME} \
						${SUBJECTS_DIR} \
						${BIDS_subject} \
						${BIDS_session} \
						${BIDS_dir}/sub-${BIDS_subject}/ses-${BIDS_session}/anat/sub-${BIDS_subject}_ses-${BIDS_session}_rec-${norm_string}_run-${best_T1w_BIDS_run}_T1w.nii.gz
				fi
			fi
		fi

		if ${DO_ENIGMA_FREESURFER}; then
			# find best T1w image by snr_total
			if [ -d "${BIDS_dir}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}/anat" ]; then
				pushd ${BIDS_dir}/derivatives/mriqc/sub-${BIDS_subject}/ses-${BIDS_session}/anat
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
				
				# run ENIGMA TS Freesurfer T1 pipeline
				enigma_subjid="sub-"${BIDS_subject}"_ses-"${BIDS_session}
				aparc_aseg_mgz=${enigma_output_dir}"/"${enigma_subjid}"/mri/aparc+aseg.mgz"
				if [ "${best_T1w_BIDS_run}" != "00" ] && [ ! -f "${aparc_aseg_mgz}" ]; then
					# link input nii.gz to ENIGMA inputs dir
					mkdir -p ${enigma_input_dir}/${enigma_subjid}
					ln -s \
						${BIDS_dir}/sub-${BIDS_subject}/ses-${BIDS_session}/anat/sub-${BIDS_subject}_ses-${BIDS_session}_rec-${norm_string}_run-${best_T1w_BIDS_run}_T1w.nii.gz \
						${enigma_input_dir}/${enigma_subjid}/${enigma_subjid}.nii.gz

					# Run ENIGMA Freesurfer
					${enigma_ts_repo}/1_enigma_runfreesurfer.sh ${enigma_subjid} ${enigma_base_dir}
				fi
			fi
		fi
		
		popd
	done
} < ${XNAT_project}"_MR_sessions.csv"

exit 0

