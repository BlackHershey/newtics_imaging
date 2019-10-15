#!/bin/csh

set study_dir = '/net/zfs-black/BLACK/black/NewTics'

pushd $study_dir

set patids = `find . -maxdepth 1 -type d -name "NT*"`
foreach patid ( $patids )
	if ( ! -e ${patid}/${patid}.params ) then
		echo $patid >> missing_params.lst
		continue
	endif

	pushd $patid

	source ${patid}.params
	foreach scan ( $sefm $fstd $pcasl )
		if ( ! -e ${study_dir}/zips/${patid}_study${scan}.zip ) then
			pushd study${scan}
			zip ${study_dir}/zips/${patid}_study${scan}.zip *.dcm
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

	set scans = `find ${sess}/scans -mindepth 1 -type d -prune`
	foreach scan ( $scans )
		set scan = $scan:t
		if ( ! -e ${study_dir}/zips/${sess}_study${scan}_defaced.zip ) then
			pushd ${sess}/scans/${scan}/DICOM_DEFACED
			zip ${study_dir}/zips/${sess:t}_study${scan}_defaced.zip *.dcm
			popd
		endif
	end

	set scans = `find ${sess}/DICOM_DEFACED -mindepth 1 -type d -name "study*" -prune`
	foreach scan ( $scans )
		set scan = $scan:t
		if ( ! -e ${study_dir}/zips/${sess}_${scan}_defaced.zip ) then
			pushd ${sess}/DICOM_DEFACED/${scan}
			zip ${study_dir}/zips/${sess:t}_${scan}_defaced.zip *.dcm
			popd
		endif
	end
end

popd

popd
