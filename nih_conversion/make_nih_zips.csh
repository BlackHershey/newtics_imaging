#!/bin/csh

set scripts_dir = '/net/zfs-black/BLACK/black/git/newtics_imaging/nih_conversion'
set study_dir = '/net/zfs-black/BLACK/black/NewTics'
set outdir = ${study_dir}/zips

pushd $study_dir

set error_log = "${study_dir}/zip_error.log"
if ( -e $error_log ) /bin/rm $error_log

if ( -e missing_params.lst ) /bin/rm missing_params.lst

# handle all the functional scans (source from params-like file)
set patids = `find . -maxdepth 1 -type d -name "NT*"`
foreach patid ( $patids )
	pushd $patid

	# keep track of sessions that were skipped
	set params = `ls *.{params,cnf}`
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
		if ( ! -e ${outdir}/${patid}_study${scan}.zip ) then
			python3 ${scripts_dir}/check_headers.py "study${scan}/*.dcm"
			if ( $status ) then
				echo "failed for $patid $scan" >> $error_log
				continue
			endif

			pushd study${scan}
			zip ${outdir}/${patid}_study${scan}.zip *.dcm
			popd
		endif
	end

	popd
end

# handle mprage / t2w separately (make sure we only send defaced structurals)
pushd defaced

set sessions = `find . -maxdepth 1 -type d -name "NT*"`
foreach sess ( $sessions )
	set sess = $sess:t

	pushd $sess

	# zip facemasked scans downloaded from CNDA (structured with extra directory under scan number)
	set scans = `find scans -mindepth 1 -type d -prune`
	foreach scan ( $scans )
		set scan = $scan:t
		if ( ! -e ${outdir}/${sess}_study${scan}_defaced.zip ) then
			pushd scans/${scan}/DICOM_DEFACED
			zip ${outdir}/${sess:t}_study${scan}_defaced.zip *.dcm
			popd
		endif
	end

	# zip facemasked scans that were processed offline 
	# TODO: set up offline facemasking to be structured the same as CNDA
	set scans = `find DICOM_DEFACED -mindepth 1 -type d -name "study*" -prune`
	foreach scan ( $scans )
		set scan = $scan:t
		if ( ! -e ${outdir}/${sess}_${scan}_defaced.zip ) then
			set scandir = DICOM_DEFACED/${scan}
			python3 ${scripts_dir}/check_headers.py "${scandir}/*.dcm"
			if ( $status ) then
				echo "failed for $sess $scan" >> $error_log
				continue
			endif

			pushd $scandir
			zip ${outdir}/${sess:t}_${scan}_defaced.zip *.dcm
			popd
		endif
	end

	popd
end

popd # out of defaced

popd # out of study_dir
