#!/bin/csh

set study_dir = $cwd
set facemask_bin = /data/nil-bluearc/black/Facemasking/lin64.Dec2017/bin

set subdirs = `find $cwd -maxdepth 1 -type d -name "NT*"`
foreach sdir ( $subdirs )
    set patid = ${sdir:t}

    if ( ! -d ${study_dir}/defaced/${patid} ) then
        pushd ${study_dir}/${patid}
        # source *.{params,cnf}
        source ${patid}"_nih.cnf"

        # if ( ! ${?mprs} ) then
        #    echo "WARNING: no MPRs found for $patid"
        #    popd
        #    continue
        #endif
        if ( ! ${?tse} ) set tse = ()
        if ( ! ${?mprs} ) set mprs = ()
        
        if ( -e temp ) /bin/rm -r temp
        mkdir temp
        cd temp

		# mkdir -p ${study_dir}/defaced/${patid}/DICOM_DEFACED
        foreach scan ( $mprs $tse )
            ${facemask_bin}/mask_face \
                ${sdir}/study${scan} \
                -b 1 \
                -e 1 \
                -o ${study_dir}/defaced/${patid}/DICOM_DEFACED
        end
        
        cd ..
        
        if ( -e temp ) /bin/rm -r temp

        popd
    else 
        echo "Already facemasked: ${patid}"       
    endif
end
