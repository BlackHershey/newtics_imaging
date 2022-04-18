#!/bin/sh

# Script to prepare NT imaging data for sharing (both with other PIs and NIH submission)

study_dir='/net/zfs-black/BLACK/black/NewTics'
scripts_dir='/net/zfs-black/BLACK/black/git/newtics_imaging'

source ${scripts_dir}/nt_img_venv_hal/bin/activate # enter virtual env

read -p "Enter CNDA username: " user

pushd $study_dir

# get updated mapping of vcnum to NT id
python3 ${scripts_dir}/vcnum2ntid.py /data/cn3/rawdata/tourettes/Prisma $user

# run dcm_sort on new sessions (and get modified params files for zipping step)
python3 ${scripts_dir}/dcm_reorg.py # ${study_dir}/NT_vcnum.csv

# facemask newer sessions (using first-acquired MPRAGE)
${scripts_dir}/facemask.csh

## NIH submission specific steps 
${scripts_dir}/nih_conversion/make_nih_zips.csh # generate zips for each scan

python3 ${scripts_dir}/nih_conversion/gen_image03.py # generate base submission CSV

deactivate # exit virtual env

# Convert to BIDS + MRIQC
/data/cn6/soyoung/NewTics/BIDS/NT_bids_mriqc.sh


