#!/bin/bash

XNAT_host="https://cnda.wustl.edu"
XNAT_project="NP919"
# XNAT_user is first argument
XNAT_user=${1}

# USAGE
if [ "$#" -ne 1 ]; then
	echo "Usage: ./dcm_sort_NewTics_DICOM.sh <CNDA_username>"
	echo " e.g.: ./dcm_sort_NewTics_DICOM.sh jmk1"
	exit 1
fi

DO_FACEMASK=true
DO_BIDS_AND_MRIQC=true
DO_FREESURFER=true


study_dir='/data/nil-bluearc/black/NewTics'
ntdb_subject_csv=${study_dir}'/ntdb_subjects.csv'

# XNAT mask_face
mask_face_redo="0"
mask_face_QA_dir=${study_dir}"/maskface_QA"

# BIDS
BIDS_dir=${study_dir}"/BIDS"
BIDS_heuristic=${BIDS_dir}"/code/NewTics_heuristic.py"
dicom_subdir=${study_dir}"/CNDA_DOWNLOAD"
scripts_dir='/data/nil-bluearc/black/git/newtics_imaging'
source ${scripts_dir}/nt_img_venv_hal/bin/activate # enter virtual env

# Freesurfer
best_T1w_log=${study_dir}/NewTics_best_T1w_log.csv
echo "subject_id,xnat_subject,xnat_session,visit_type,bids_subject,bids_session,age,scanner_id,vc_number,best_mprage_snr_total,usable_minutes_rs_fmri,series_number,bids_run,bids_type,series_description,norm_string" > ${best_T1w_log}
FREESURFER_HOME=/data/nil-bluearc/hershey/unix/software/freesurfer-7.3.2-centos8
SUBJECTS_DIR=${BIDS_dir}/derivatives/freesurfer-7.3.2

# cd into dicom subdir
cd ${dicom_subdir}

# get user id and group number for docker
userid_num=`id -u`
group_num=`id -g`

JSESSION=`curl -u ${XNAT_user} -X POST ${XNAT_host}"/REST/JSESSION"`

# NOTE: This is a call to get all experiments in a project in csv format
curl -b JSESSIONID=$JSESSION -o NewTics_MR_sessions.csv "${XNAT_host}/REST/projects/${XNAT_project}/experiments?format=csv&columns=subject_label,label,date&sortBy=subject_label,date,label" \
|| \
( echo "ERROR: Could not authenticate user "${XNAT_user}" on host "${XNAT_hostname} && exit 1 )

# this block of code uses the MR experiments csv downloaded above and loops over the rows.
{
	read
	while IFS=, read -r XNAT_ID Subject MR_ID MR_date xsi_type project URI
	do
		if [[ ${Subject} =~ ^(NT|NEWT|CTS|MSCPI|NIC|TR|LOTS|TS_M).* && ${MR_ID} =~ ^(NT.*_screen|NT.*_12mo|NEWT.*_s.*|TRACK.*_s.*|NIC1.*|MSCPI.*|CTS.*_vc.*|TR.*_vc.*|LOTS.*_.*|TS_M.*)$ ]]; then
			echo ${Subject}" "${MR_ID}
			BIDS_subject=${Subject}
			mkdir -p ${Subject}/${MR_ID}/${MR_ID}
			mkdir -p ${study_dir}/${MR_ID}
			
			# Define other session variables
			session_type=""
			age=""
			scanner_id=""
			vc_number=""
			usable_minutes_rs_fmri=""

			# switch over subject to get BIDS session
			case "${Subject}" in
				NT* )
    				case "${MR_ID}" in
    					*_screen ) 
							BIDS_session="screen"
							session_type="screen" ;;
    					*_12mo )
							BIDS_session="12mo"
							session_type="12mo" ;;
    					* ) BIDS_session="SKIP" ;;
    				esac ;;
    			NEWT* )
    				case "${MR_ID}" in
    					*_s1 ) BIDS_session="s1" ;;
    					*_s2 ) BIDS_session="s2" ;;
    					*    ) BIDS_session="SKIP" ;;
    				esac ;;
    			TRACK?? )
    				case "${MR_ID}" in
    					*_s1 ) BIDS_session="s1" ;;
    					*_s2 ) BIDS_session="s2" ;;
    					*_s3 ) BIDS_session="s3" ;;
    					*    ) BIDS_session="SKIP" ;;
    				esac ;;
    			CTS* )
    				case "${MR_ID}" in
    					CTS???_vc????? ) 
    						BIDS_session=`echo ${MR_ID} | sed "s/CTS..._vc//"` ;;
    					* ) BIDS_session="SKIP" ;;
    				esac ;;
    			MSCPI* )
    				case "${MR_ID}" in
    					MSCPI??_?????_???????? ) 
    						BIDS_session=`echo ${MR_ID} | sed "s/MSCPI.._//" | sed "s/_........$//"` ;;
    					* ) BIDS_session="SKIP" ;;
    				esac ;;
    			NIC???? )
    				BIDS_session="01" ;;
    			TR??? )
    				case "${MR_ID}" in
    					TR???_vc????? ) 
    						BIDS_session=`echo ${MR_ID} | sed "s/TR..._vc//"` ;;
    					* ) BIDS_session="SKIP" ;;
    				esac ;;
				LOTS* )
    				case "${MR_ID}" in
    					LOTS???_vc????? ) 
    						BIDS_session=`echo ${MR_ID} | sed "s/LOTS..._vc//"` ;;
    					* ) BIDS_session="SKIP" ;;
    				esac ;;
    			TS_M* )
    				BIDS_subject=`echo ${Subject} | sed "s/_//"`
    				case "${MR_ID}" in
    					TS_M??_vc?????_MR* ) 
    						BIDS_session=`echo ${MR_ID} | sed "s/TS_M.._vc//" | sed "s/_//"` ;;
    					* ) BIDS_session="SKIP" ;;
    				esac ;;
    			* ) BIDS_session="SKIP" ;;
    		esac
			
			session_dicom_rootdir=${dicom_subdir}/${Subject}/${MR_ID}
			session_dicom_dir=${dicom_subdir}/${Subject}/${MR_ID}/${MR_ID}
			
			pushd ${Subject}/${MR_ID}
			if [ ! -s "${study_dir}/${MR_ID}/${MR_ID}.studies.txt" ]; then
			 	curl -b JSESSIONID=${JSESSION} -o ${MR_ID}.zip "${XNAT_host}/data/projects/${XNAT_project}/subjects/${Subject}/experiments/${MR_ID}/scans/ALL/resources/DICOM/files?format=zip"
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
			python ${scripts_dir}/dcm_reorg_one_session.py ${study_dir} ${MR_ID} ${session_dicom_rootdir} ${study_dir}/NT_scan_mapping_config.json --duplicates=norm
			
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
					echo "${ntdb_subject_id},${Subject},${MR_ID},${visit_type},${BIDS_subject},${BIDS_session},${age},${scanner_id},${vc_number},${best_snr_total},${usable_minutes_rs_fmri},${series_number},${best_T1w_BIDS_run},t1w,${series_description},${norm_string}" >> ${best_T1w_log}
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
			
			popd
		fi
	done
} < "NewTics_MR_sessions.csv"

exit 0

