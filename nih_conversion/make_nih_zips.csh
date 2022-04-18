#!/bin/csh

set scripts_dir = '/data/nil-bluearc/black/git/newtics_imaging/nih_conversion'
set study_dir = '/data/nil-bluearc/black/NewTics'
set outdir = ${study_dir}/zips

@ redo_func_zips = 0
@ redo_defaced_zips = 0

pushd $study_dir

set error_log = "${study_dir}/zip_error.log"
if ( -e $error_log ) /bin/rm $error_log

set scrub_log = "${study_dir}/zip_scrub.log"
if ( -e $scrub_log ) /bin/rm $scrub_log

if ( -e missing_params.lst ) /bin/rm missing_params.lst

# handle all the functional scans (source from params-like file)
set patids = `find . -maxdepth 1 -type d -name "NT*"`
foreach patid ( $patids )
	pushd $patid

	# keep track of sessions that were skipped
	set params = `ls ${patid}"_nih.cnf"`
	if ( $status ) then
		echo $patid >> ../missing_params.lst
		popd
		continue
	endif

	# iterate over all params files for subject (may be more than one if separate PCASL/BOLD params)
	foreach f ( $params )
		source $f
	end

	# create separate zip of DICOM data for each scan
	foreach scan ( $sefm $fstd $pcasl )
		if ( ! -e ${outdir}/${patid}_study${scan}.zip || $redo_func_zips > 0 ) then
			python ${scripts_dir}/check_headers.py "study${scan}/*.*"
			if ( $status ) then
				echo "scrubbing "${patid}" study"${scan} >> $scrub_log
				python ${scripts_dir}/clean_headers.py "study${scan}/*.*"
			endif
			python ${scripts_dir}/check_headers.py "study${scan}/*.*"
			if ( $status ) then
				echo "failed to scrub "${patid}" study"${scan} >> $error_log
				continue
			endif

			pushd study${scan}
			zip ${outdir}/${patid}_study${scan}.zip *.*
			popd
		endif
	end

	popd
end


# For now, exit after functionals
# exit 0

# handle mprage / t2w separately (make sure we only send defaced structurals)
pushd defaced

set sessions = `find . -maxdepth 1 -type d -name "NT*"`
foreach sess ( $sessions )
	set sess = $sess:t

	pushd $sess

	# zip facemasked scans (structured with extra directory under scan number)
	# set scans = `find scans -mindepth 1 -type d -prune`
	# foreach scan ( $scans )
	#	set scan = $scan:t
	#	if ( ! -e ${outdir}/${sess}_study${scan}_defaced.zip ) then
	#		pushd scans/${scan}/DICOM_DEFACED
	#		zip ${outdir}/${sess:t}_study${scan}_defaced.zip *.dcm
	#		popd
	#	endif
	# end

	# zip facemasked scans that were processed offline 
	# TODO: set up offline facemasking to be structured the same as CNDA
	set scans = `find DICOM_DEFACED -mindepth 1 -type d -name "study*" -prune`
	foreach scan ( $scans )
		set scan = $scan:t
		if ( ! -e ${outdir}/${sess}_${scan}_defaced.zip || ${redo_defaced_zips} > 0 ) then
			set scandir = DICOM_DEFACED/${scan}
			python ${scripts_dir}/check_headers.py "${scandir}/*.*"
			if ( $status ) then
				echo "scrubbing "${sess}" "${scan} >> $scrub_log
				python ${scripts_dir}/clean_headers.py "${scandir}/*.*"
			endif
			python ${scripts_dir}/check_headers.py "${scandir}/*.*"
			if ( $status ) then
				echo "WARNING: failed to scrub "${sess}" "${scan} >> $error_log
				continue
			endif
			
			pushd $scandir
			zip ${outdir}/${sess:t}_${scan}_defaced.zip *.*
			popd
		endif
	end

	popd
end

popd # out of defaced

popd # out of study_dir

exit 0

