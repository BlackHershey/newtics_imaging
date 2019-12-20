#!/bin/csh

set study_dir = '/net/zfs-black/BLACK/black/NewTics'

pushd $study_dir

    set patids = `find . -maxdepth 1 -type d -name "NT*"`

    foreach patid ( $patids )
        set zips = `ls zips/${patid}_study*.zip`
    end

popd