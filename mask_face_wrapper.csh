#!/bin/csh

set program = $0; set program = $program:t

# usage
if (${#argv} < 2) then
	echo "Usage: $program <DICOM directory> <QA dir>"
	echo "e.g.,  $program study10 /path/to/QA_dir"
	exit 1
endif

set QA_dir = ${2}
mkdir -p ${QA_dir}

set docker_image = xnat/facemasking:1.0

set dicom_dir=${1}
set study_dir=${dicom_dir:t}

set dicom_parent_dir=${dicom_dir:h}
set patid=${dicom_parent_dir:t}

pushd ${dicom_parent_dir}

if ( -d ${study_dir}"_defaced" ) /bin/rm -r ${study_dir}"_defaced"
mkdir -p ${study_dir}"_defaced"/${study_dir}"_DICOM"
cd ${study_dir}"_defaced"

cp ${dicom_dir}/*.* ${study_dir}"_DICOM"/

set usernum = `id -u`
set groupnum = `id -g`

docker run -u ${usernum}:${groupnum} -v `pwd`:/docker_mount --rm ${docker_image} mask_face_nomatlab ${study_dir}"_DICOM" -b 1 -e 1

# clean up from mask_face run
/bin/rm *${study_dir}"_DICOM"*.*
mv maskface/${study_dir}"_DICOM_normfilter.png" ${QA_dir}/${patid}"_"${study_dir}"_DICOM_normfilter.png"
mv maskface/${study_dir}"_DICOM_normfilter_surf.png" ${QA_dir}/${patid}"_"${study_dir}"_DICOM_normfilter_surf.png"
mv maskface/${study_dir}"_DICOM"_masked_nii_orig.img ${QA_dir}/${patid}"_"${study_dir}"_DICOM_masked_nii_orig.img"
mv maskface/${study_dir}"_DICOM"_masked_nii_orig.hdr ${QA_dir}/${patid}"_"${study_dir}"_DICOM_masked_nii_orig.hdr"
mv DICOM_DEFACED/${study_dir}"_DICOM"/*.* ./
/bin/rm -r ${study_dir}"_DICOM" maskface DICOM_DEFACED

popd

exit 0

