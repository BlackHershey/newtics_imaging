#!/bin/bash

scripts_dir="/data/nil-bluearc/black/git/newtics_imaging/nih_conversion"
study_dir="/data/nil-bluearc/black/NewTics"
outdir=${study_dir}/zips

redo_func_zips=0
redo_defaced_zips=0

pushd ${study_dir}

error_log="${study_dir}/zip_error.log"
if [ -f "$error_log" ]; then
	/bin/rm ${error_log}
fi

scrub_log="${study_dir}/zip_scrub.log"
if [ -f "$scrub_log" ]; then
	/bin/rm ${scrub_log}
fi

if [ -f "missing_params.lst" ]; then
	/bin/rm missing_params.lst
fi

# handle all the functional scans (source from params-like file)
NT_nih_params_files=(`find ${study_dir} -maxdepth 2 -regextype posix-extended -regex ".*NT.*_(screen|12mo)_nih\.cnf$" -print`)

for nih_params_file in "${NT_nih_params_files[@]}"
do
	patid=`echo ${nih_params_file} | cut -d"/" -f6`
	Subject=`echo ${patid} | cut -c1-5`

	pushd $patid

	# keep track of sessions that were skipped
	if [ ! -f "${patid}_nih.cnf" ]; then
		echo ${patid} >> ../missing_params.lst
		popd
		continue
	fi

	# create separate zip of DICOM data for each scan
	atest=(`echo $test | grep -Eo "[0-9]{1,}"`)
	t1_series=(`cat ${nih_params_file} | grep "mprs" | cut -d"(" -f2 | cut -d")" -f1`)
	t2_series=(`cat ${nih_params_file} | grep "tse" | cut -d"(" -f2 | cut -d")" -f1`)
	bold_series=(`cat ${nih_params_file} | grep "fstd" | cut -d"(" -f2 | cut -d")" -f1`)
	sefm_series=(`cat ${nih_params_file} | grep "sefm" | cut -d"(" -f2 | cut -d")" -f1`)
	pcasl_series=(`cat ${nih_params_file} | grep "pcasl" | cut -d"(" -f2 | cut -d")" -f1`)
	t1_series=`cat ${nih_params_file} | grep "mprs"`
	t2_series=`cat ${nih_params_file} | grep "tse"`
	bold_series=`cat ${nih_params_file} | grep "fstd"`
	sefm_series=`cat ${nih_params_file} | grep "sefm"`
	pcasl_series=`cat ${nih_params_file} | grep "pcasl"`
	struct_series=(`echo "${t1_series}"" ""${t2_series}" | grep -Eo "[0-9]{1,}"`)
	func_series=(`echo "${bold_series}"" ""${sefm_series}"" ""${pcasl_series}" | grep -Eo "[0-9]{1,}"`)

	echo ${Subject}" "${patid}
	echo "Zipping "${#struct_series[@]}" structural series and "${#func_series[@]}" functional series"

	for dicom_series in "${struct_series[@]}"
	do	
		if [ "${dicom_series}" -gt "0" ]; then
			if [ ! -f "${outdir}/${patid}_study${dicom_series}_defaced.zip" ] || [ "${redo_defaced_zips}" -gt "0" ]; then
				python ${scripts_dir}/check_headers.py "study${dicom_series}_defaced/*.*"
				if [ "$?" -ne "0" ]; then
					echo "scrubbing "${patid}" study"${dicom_series}"_defaced" >> ${scrub_log}
					python ${scripts_dir}/clean_headers.py "study${dicom_series}_defaced/*.*"
				fi
				python ${scripts_dir}/check_headers.py "study${dicom_series}_defaced/*.*"
				if [ "$?" -ne "0" ]; then
					echo "failed to scrub "${patid}" study"${dicom_series}"_defaced" >> ${error_log}
					continue
				fi

				pushd study${dicom_series}"_defaced"
				zip ${outdir}/${patid}_study${dicom_series}_defaced.zip *.*
				popd
			fi
		fi
	done

	for dicom_series in "${func_series[@]}"
	do
		if [ "${dicom_series}" -gt "0" ]; then
			if [ ! -f "${outdir}/${patid}_study${dicom_series}.zip" ] || [ ${redo_func_zips} -gt "0" ]; then
				python ${scripts_dir}/check_headers.py "study${dicom_series}/*.*"
				if [ "$?" -ne "0" ]; then
					echo "scrubbing "${patid}" study"${dicom_series} >> ${scrub_log}
					python ${scripts_dir}/clean_headers.py "study${dicom_series}/*.*"
				fi
				python ${scripts_dir}/check_headers.py "study${dicom_series}/*.*"
				if [ "$?" -ne "0" ]; then
					echo "failed to scrub "${patid}" study"${dicom_series} >> ${error_log}
					continue
				fi

				pushd study${dicom_series}
				zip ${outdir}/${patid}_study${dicom_series}.zip *.*
				popd
			fi
		fi
	done

	popd
done

popd # out of study_dir

exit 0