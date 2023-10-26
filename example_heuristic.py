import os
import re

def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return template, outtype, annotation_classes

def infotodict(seqinfo):
    """Heuristic evaluator for determining which runs belong where

    allowed template fields - follow python string module:

    item: index within category
    subject: participant id
    seqitem: run number during scanning
    subindex: sub index within group
    """
	
	# anat series (T1w, T2w, FLAIR)
    t1w_series_desc_pattern = '^(ABCD_T1w_MPR_vNav(_active_remeasure_1mm)?|T1w_MPR|t1_mpr_ns_sag|t1_mpr_ns_sag_ND|t1_mpr_ns_sag_ipat|t1_mpr_1mm_p2_pos50|Mprage|tfl-multiecho-epinav-711_new_FOV.*RMS|T1_.8x.8x.8_224Slices|MPRageSeth|MPRageSethMod|MPrage32chan_AX|MPRAGE Yantis|HighResT1|MPRage-3T|MP_RAGE|MPRAGE|Mprage)$'
    t2w_series_desc_pattern = '^(ABCD_T2w_SPC_vNav(_active_remeasure_1mm)?|T2w_SPC|t2_spc_1mm_p2|T2 weighted|T2_.8x.8x.8_224Slices|T2Wveryfast|Matched Bandwidth Hi-Res|Axial T2 3mm|tse_p3|TSE)$'
    flair_series_desc_pattern = '^(SSh_FLAIR SENSE|t2_tirm_tra_dark-fluid)$'
    t1w_norm = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_rec-norm_run-{item:02d}_T1w')
    t2w_norm = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_rec-norm_run-{item:02d}_T2w')
    flair_norm = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_rec-norm_run-{item:02d}_FLAIR')
    t1w_orig = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_rec-orig_run-{item:02d}_T1w')
    t2w_orig = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_rec-orig_run-{item:02d}_T2w')
    flair_orig = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_rec-orig_run-{item:02d}_FLAIR')
    
    # fmap series (field maps for resting-state BOLD and/or DWI)
    ase_AP_series_desc_pattern = '(SpinEchoFieldMap_AP_2p4mm_\\d{2}sl|SpinEchoFieldMap_AP_3p0|ABCD_fMRI_DistortionMap_AP)'
    ase_PA_series_desc_pattern = '(SpinEchoFieldMap_PA_2p4mm_\\d{2}sl|SpinEchoFieldMap_PA_3p0|ABCD_fMRI_DistortionMap_PA)'
    fmap_ase_ap_norm = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-AP_rec-norm_run-{item:02d}_epi')
    fmap_ase_pa_norm = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-PA_rec-norm_run-{item:02d}_epi')
    fmap_ase_ap_orig = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-AP_rec-orig_run-{item:02d}_epi')
    fmap_ase_pa_orig = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-PA_rec-orig_run-{item:02d}_epi')
    
    gre_fmap_series_desc_pattern = '^(gre_field_mapping(_4x4x4_32)?).*$'
    fmap_gre_magnitude = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_run-{item:02d}_magnitude')
    fmap_gre_phasediff = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_run-{item:02d}_phasediff')
    
    # dwi series
    dwi_series_desc_pattern = '^(DTI|DTI_26d_b1400_MDDW_av1_72|DTI_ep2d_diff_96x96_NoIPAT|ep2d_dif _25dir_av1)$'
    dwi_norm = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_rec-norm_run-{item:02d}_dwi')
    dwi_orig = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_rec-orig_run-{item:02d}_dwi')
    # dwi_norm_sbref = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_rec-norm_run-{item:02d}_sbref')
    # dwi_orig_sbref = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_rec-orig_run-{item:02d}_sbref')
    
    
    # func series (for right now, just resting-state BOLD, add new entries for task)
    rest_bold_series_desc_pattern = '^(fMRI_AP_\\w*_te\\d+|rfMRI_REST_AP_\\w*slices|ABCD_fMRI_rest|rest|ep2d_bold_rest|ep2d_bold_rest\\d+|ep2d_bold_connect|RestState_V1|Rest_TR2_4mm|bold.*rest.*|BOLD_Rest|fcMRI|fix_[0-9].*|Rest|(R|r)est[1-9]|(F|f)ix[1-9]|fixation[1-9]|rs_fcMRI)$'
    wm_bold_series_desc_pattern = '^(BOLD EPI - wm|ep2d_bold\\d{1,2})$'
    stop_bold_series_desc_pattern = '^(BOLD EPI - stop)$'
    blinkstaring_bold_series_desc_pattern = '^(BOLD_Blink_Staring.*|ep2d_bold_blink)$'
    sbref_series_desc_pattern = '^(fMRI_AP_\\w*_te\\d+|rfMRI_REST_AP_\\w*slices)_SBRef$'
    func_rest_norm = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_rec-norm_run-{item:02d}_bold')
    func_rest_orig = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_rec-orig_run-{item:02d}_bold')
    func_rest_norm_sbref = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_rec-norm_run-{item:02d}_sbref')
    func_rest_orig_sbref = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_rec-orig_run-{item:02d}_sbref')
    func_wm_norm = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-wm_rec-norm_run-{item:02d}_bold')
    func_wm_orig = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-wm_rec-orig_run-{item:02d}_bold')
    func_stop_norm = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-stop_rec-norm_run-{item:02d}_bold')
    func_stop_orig = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-stop_rec-orig_run-{item:02d}_bold')
    func_blinkstaring_1A_norm = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-blinkstaring_acq-1A_rec-norm_run-{item:02d}_bold')
    func_blinkstaring_1A_orig = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-blinkstaring_acq-1A_rec-orig_run-{item:02d}_bold')
    func_blinkstaring_1B_norm = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-blinkstaring_acq-1B_rec-norm_run-{item:02d}_bold')
    func_blinkstaring_1B_orig = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-blinkstaring_acq-1B_rec-orig_run-{item:02d}_bold')
    func_blinkstaring_2A_norm = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-blinkstaring_acq-2A_rec-norm_run-{item:02d}_bold')
    func_blinkstaring_2A_orig = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-blinkstaring_acq-2A_rec-orig_run-{item:02d}_bold')
    func_blinkstaring_2B_norm = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-blinkstaring_acq-2B_rec-norm_run-{item:02d}_bold')
    func_blinkstaring_2B_orig = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-blinkstaring_acq-2B_rec-orig_run-{item:02d}_bold')
    
    # ASL series
    pasl_series_desc_pattern = '^(ep2d_tra_pasl|ADNI ASL PERFUSION)$'
    pcasl_series_desc_pattern = '^(PCASL)$'
    pcasl_m0_series_desc_pattern = '^(PCASL_M0)$'
    asl_rest = create_key('sub-{subject}/{session}/perf/sub-{subject}_{session}_task-rest_run-{item:02d}_asl')
    pcasl_m0 = create_key('sub-{subject}/{session}/perf/sub-{subject}_{session}_task-rest_run-{item:02d}_m0scan')
    
    info = { 
        t1w_norm: [], 
        t1w_orig: [], 
        t2w_norm: [], 
        t2w_orig: [], 
        flair_norm: [], 
        flair_orig: [], 
        dwi_norm: [], 
        dwi_orig: [], 
        func_rest_norm: [], 
        func_rest_orig: [], 
        func_rest_norm_sbref: [], 
        func_rest_orig_sbref: [], 
        func_wm_norm: [], 
        func_wm_orig: [], 
        func_stop_norm: [], 
        func_stop_orig: [], 
        func_blinkstaring_1A_norm: [], 
        func_blinkstaring_1A_orig: [], 
        func_blinkstaring_1B_norm: [], 
        func_blinkstaring_1B_orig: [], 
        func_blinkstaring_2A_norm: [], 
        func_blinkstaring_2A_orig: [], 
        func_blinkstaring_2B_norm: [], 
        func_blinkstaring_2B_orig: [], 
        asl_rest: [], 
        pcasl_m0: [], 
        fmap_ase_ap_norm: [], 
        fmap_ase_pa_norm: [], 
        fmap_ase_ap_orig: [], 
        fmap_ase_pa_orig: [], 
        fmap_gre_magnitude: [],
        fmap_gre_phasediff: []}
    
    last_run = len(seqinfo)

    for s in seqinfo:
        """
        The namedtuple `s` contains the following fields:

        * total_files_till_now
        * example_dcm_file
        * series_id
        * dcm_dir_name
        * unspecified2
        * unspecified3
        * dim1
        * dim2
        * dim3
        * dim4
        * TR
        * TE
        * protocol_name
        * is_motion_corrected
        * is_derived
        * patient_id
        * study_description
        * referring_physician_name
        * series_description
        * image_type
        """

        # check for type of series
        # print('############ {}:{}:ImageType = {} ##############'.format(s.series_id,s.series_description,s.image_type))
        
        # anat
        if re.match(t1w_series_desc_pattern, s.series_description) and 'NORM' in s.image_type and s.series_files >= 128:
            info[t1w_norm].append(s.series_id)
        if re.match(t1w_series_desc_pattern, s.series_description) and not 'NORM' in s.image_type and s.series_files >= 128:
            info[t1w_orig].append(s.series_id)
        if re.match(t2w_series_desc_pattern, s.series_description) and 'NORM' in s.image_type and s.series_files >= 24:
            info[t2w_norm].append(s.series_id)
        if re.match(t2w_series_desc_pattern, s.series_description) and not 'NORM' in s.image_type and s.series_files >= 24:
            info[t2w_orig].append(s.series_id)
        if re.match(flair_series_desc_pattern, s.series_description) and 'NORM' in s.image_type and s.series_files >= 16:
            info[flair_norm].append(s.series_id)
        if re.match(flair_series_desc_pattern, s.series_description) and not 'NORM' in s.image_type and s.series_files >= 16:
            info[flair_orig].append(s.series_id)
            # print(s)
            # print('series_files = {}'.format(s.series_files))
            # print('dim3         = {}'.format(s.dim3))
            
        # fmap
        if re.match(ase_AP_series_desc_pattern, s.series_description):
            if 'NORM' in s.image_type:
                info[fmap_ase_ap_norm].append(s.series_id)
            else:
                info[fmap_ase_ap_orig].append(s.series_id)
        if re.match(ase_PA_series_desc_pattern, s.series_description):
            if 'NORM' in s.image_type:
                info[fmap_ase_pa_norm].append(s.series_id)
            else:
                info[fmap_ase_pa_orig].append(s.series_id)
        if re.match(gre_fmap_series_desc_pattern, s.series_description):
            if "M" in s.image_type:
                info[fmap_gre_magnitude].append(s.series_id)
            if "P" in s.image_type:
                info[fmap_gre_phasediff].append(s.series_id)

        # dwi
        if re.match(dwi_series_desc_pattern, s.series_description) and 'NORM' in s.image_type and s.series_files >= 5:
            info[dwi_norm].append(s.series_id)
        if re.match(dwi_series_desc_pattern, s.series_description) and not 'NORM' in s.image_type and s.series_files >= 5:
            info[dwi_orig].append(s.series_id)
        
        # func
        if re.match(rest_bold_series_desc_pattern, s.series_description) and s.series_files >= 20:
            if 'NORM' in s.image_type:
                info[func_rest_norm].append(s.series_id)
            else:
                info[func_rest_orig].append(s.series_id)
        if re.match(sbref_series_desc_pattern, s.series_description):
            if 'NORM' in s.image_type:
                info[func_rest_norm_sbref].append(s.series_id)
            else:
                info[func_rest_orig_sbref].append(s.series_id)
        if re.match(wm_bold_series_desc_pattern, s.series_description) and s.series_files >= 20:
            if 'NORM' in s.image_type:
                info[func_wm_norm].append(s.series_id)
            else:
                info[func_wm_orig].append(s.series_id)
        if re.match(stop_bold_series_desc_pattern, s.series_description) and s.series_files >= 20:
            if 'NORM' in s.image_type:
                info[func_stop_norm].append(s.series_id)
            else:
                info[func_stop_orig].append(s.series_id)
        if re.match(blinkstaring_bold_series_desc_pattern, s.series_description) and s.series_files >= 20:
            if 'NORM' in s.image_type:
            	if '1A' in s.series_description:
                    info[func_blinkstaring_1A_norm].append(s.series_id)
                if '1B' in s.series_description:
                    info[func_blinkstaring_1B_norm].append(s.series_id)
                if '2A' in s.series_description:
                    info[func_blinkstaring_2A_norm].append(s.series_id)
                if '2B' in s.series_description:
                    info[func_blinkstaring_2B_norm].append(s.series_id)
            else:
            	if '1A' in s.series_description:
                    info[func_blinkstaring_1A_orig].append(s.series_id)
                if '1B' in s.series_description:
                    info[func_blinkstaring_1B_orig].append(s.series_id)
                if '2A' in s.series_description:
                    info[func_blinkstaring_2A_orig].append(s.series_id)
                if '2B' in s.series_description:
                    info[func_blinkstaring_2B_orig].append(s.series_id)
                
        # ASL
        if re.match(pasl_series_desc_pattern, s.series_description) and s.series_files >= 2:
            info[asl_rest].append(s.series_id)
        if re.match(pcasl_series_desc_pattern, s.series_description) and s.series_files >= 2:
            info[asl_rest].append(s.series_id)
        if re.match(pcasl_m0_series_desc_pattern, s.series_description):
            info[pcasl_m0].append(s.series_id)
        
    # print(info)
    return info