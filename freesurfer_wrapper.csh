#!/bin/csh -f

setenv FREESURFER_HOME ${1}
setenv SUBJECTS_DIR ${2}
set BIDS_subject = ${3}
set BIDS_session = ${4}
set input_img = ${5}

source ${FREESURFER_HOME}/SetUpFreeSurfer.csh

set custom_tal_atlas = TRIO_KY_NDC_as_mni_average_305

if ( ${BIDS_subject} =~ "sub-*" ) then
    continue
else
    set BIDS_subject = "sub-"${BIDS_subject}
endif

if ( ${BIDS_session} =~ "ses-*" ) then
    continue
else
    set BIDS_session = "ses-"${BIDS_session}
endif

set subjid = ${BIDS_subject}"_"${BIDS_session}
echo "subjid = "${subjid}

${FREESURFER_HOME}/bin/recon-all -all \
    -custom-tal-atlas ${custom_tal_atlas} \
    -subjid ${subjid} \
    -i ${input_img} \
    -parallel -openmp 10

exit 0
