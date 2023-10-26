# Black Lab Tourette Imaging

This collection of Python and shell scripts can be used to facilitate processing brain MRI data.

## generic_imaging_wrapper.sh

This wrapper script:
- Downloads DICOM data from an [XNAT](https://wiki.xnat.org/xnat-api/how-to-download-files-via-the-xnat-rest-api) project
- Runs [4dfp dcm_sort](https://4dfp.readthedocs.io/en/latest/scripts/dicom-utilities.html#dcm-sort) and prepares [4dfp-style params files](https://4dfp.readthedocs.io/en/latest/params_inst.html#params-file)
- Masks the face in structural images (currently via [XNAT facemasking](https://hub.docker.com/r/xnat/facemasking)), saving as DICOM
- Converts from DICOM to Nifti/[BIDS](https://bids-specification.readthedocs.io/en/stable/04-modality-specific-files/01-magnetic-resonance-imaging-data.html) using [HeuDiConv](https://heudiconv.readthedocs.io/en/latest/)
- Runs [MRIQC](https://mriqc.readthedocs.io/en/latest/)
- Prepares [ENIGMA](https://enigma.ini.usc.edu/)-like input files for the "best" T1 (chosen using MRIQC output), anonymizing subject names if needed

### Prepare necessary input files

There are several files that need to be prepared before running the wrapper script.
- config text file
- scan type mapping json
- BIDS heuristic mapping Python function
- ***optional***: anonymization key csv

#### config text file

Configure a text file like the one below for your study. It will be sourced when running the wrapper script. An example is included in this repository (example_imaging_wrapper_config.txt).

**NOTE:** In the file below, the function parse_BIDS_naming is what controls both which scans will be processed, and what their BIDS and ENIGMA labels will be. 

```bash
# The example below is for the CTS study.
BASE_DIR="/data/nil-bluearc/black"
STUDY_NAME="CTS"
STUDY_DIR=${BASE_DIR}/${STUDY_NAME}

# XNAT info
XNAT_HOST="https://cnda.wustl.edu"
XNAT_PROJECT="NP1035"

# These variables control which sections of the script will run
# NOTE: Downloading DICOM data and dcm_sort will always run
DO_FACEMASK=true
DO_BIDS=true
DO_MRIQC=(true and ${DO_BIDS})
DO_ENIGMA_INPUT=true

# A json file that maps series descriptions to 4dfp params groups
SCAN_TYPE_MAPPING_FILE=${STUDY_DIR}/${STUDY_NAME}"_scan_mapping_config.json"

# XNAT mask_face
MASK_FACE_REDO="0"
MASK_FACE_QA_DIR=${STUDY_DIR}/maskface_QA

# Python environment
VENV_BASE_DIR=${BASE_DIR}/env

# DICOM directory
DICOM_SUBDIR=${STUDY_DIR}/DICOM

# BIDS
BIDS_DIR=${STUDY_DIR}"/BIDS"
BIDS_HEURISTIC=${BIDS_DIR}"/code/"${STUDY_NAME}"_heuristic.py"
BIDS_NAMING_LOG=${STUDY_DIR}/${STUDY_NAME}"_BIDS_naming_log.csv"

# MRIQC
MRIQC_VERSION="23.0.1"
MRIQC_DOCKER_IMAGE="nipreps/mriqc:"${MRIQC_VERSION}
NUM_MRIQC_THREADS=20

# ENIGMA-TS
ENIGMA_BASE_DIR=${BASE_DIR}/ENIGMA-TS
ENIGMA_INPUT_DIR=${ENIGMA_BASE_DIR}/inputs
ENIGMA_OUTPUT_DIR=${ENIGMA_BASE_DIR}/outputs
ANON_KEY_CSV=${STUDY_DIR}/ENIGMA_anonymization_table.csv

# Subject/session name parsing
# The following bash function will:
#   - parse the XNAT Subject and Session labels
#   - define the BIDS Subject and Session labels (or set to "SKIP")
#   - define if anonymization is needed
function parse_BIDS_naming {
    # read function input
    local subject_label=${1}
    local session_label=${2}
    # switch over XNAT subject and session labels to get BIDS subject and session labels
    anon_needed=false
    case "${subject_label}" in
        CTS[1-2][0-9][0-9]_* )
            institution_code="WU"
            # BIDS_subject=${institution_code}${subject_label}
            BIDS_subject=$(echo ${subject_label} | cut -c1-6)
            anon_needed=false
            case "${session_label}" in
                CTS[1-2][0-9][0-9]_* ) BIDS_session="01" ;;
                * ) BIDS_session="SKIP" ;;
            esac ;;
        * ) 
            BIDS_subject="SKIP"
            BIDS_session="SKIP" ;;
    esac
}
```

#### scan type mapping file

Configure a json text file like the one below for your study. It is used when mapping DICOM SeriesDescription to scan type (mpr/T1, BOLD/fmri, DTI, etc.). An example is included in this repository (example_scan_mapping.json).

```json
{
	"series_desc_mapping": {
		"T1_.8x.8x.8_224Slices": "mprs",
		"tfl-multiecho-epinav-711_new_FOVRMS": "mprs",
		"Mprage": "mprs",
		"ABCD_T1w_MPR_vNav": "mprs",
		"T2_.8x.8x.8_224Slices": "tse",
		"t2_spc_1mm_p2": "tse",
		"ABCD_T2w_SPC_vNav": "tse",
		"fcMRI": "fstd",
		"ep2d_bold*rest*": "fstd",
		"ep2d_bold*movie*": "fstd",
		"ep2d_bold1": "fstd",
		"ep2d_bold2": "fstd",
		"ep2d_bold3": "fstd",
		"ep2d_bold_connect": "fstd",
		"ep2d_bold_blink": "fstd",
		"gre_field_mapping": "gre",
		"gre_field_mapping_4x4x4_32": "gre",
		"PCASL": "pcasl",
		"PCASL_M0": "pcasl_m0",
		"ep2d_tra_pasl": "pasl",
		"ADNIASLPERFUSION": "pasl",
		"SSh_FLAIRSENSE": "flair",
		"t2_tirm_tra_dark-fluid": "flair",
		"DTI_ep2d_diff_96x96_NoIPAT": "dwi",
		"DTI_26d_b1400_MDDW_av1_72": "dwi",
		"DTI": "dwi",
		"ep2d_dif_25dir_av1": "dwi"
	},
	"irun": {
		"fcMRI": "",
		"ep2d_bold*rest*": "",
		"ep2d_bold*movie*": "",
		"ep2d_bold1": "",
		"ep2d_bold2": "",
		"ep2d_bold3": "",
		"ep2d_bold_connect": "",
		"ep2d_bold_blink": ""
	}
}
```

#### BIDS heuristic Python script

Configure a Python heuristic file for your study. See [this page](https://heudiconv.readthedocs.io/en/latest/heuristics.html) for more details. Some example lines for T1w images are below. An example file with many of the SeriesDescriptions used throughout WashU Tourette studies is included in this repository (example_heuristic.py).

```python
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
    t1w_series_desc_pattern = '^(ABCD_T1w_MPR_vNav|T1w_MPR|t1_mpr_ns_sag|t1_mpr_ns_sag_ND|t1_mpr_ns_sag_ipat|t1_mpr_1mm_p2_pos50|Mprage|T1_.8x.8x.8_224Slices)$'
    t1w_norm = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_rec-norm_run-{item:02d}_T1w')
    t1w_orig = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_rec-orig_run-{item:02d}_T1w')

    info = { 
        t1w_norm: [], 
        t1w_orig: []
        }

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

        # anat
        if re.match(t1w_series_desc_pattern, s.series_description) and 'NORM' in s.image_type and s.series_files >= 128:
            info[t1w_norm].append(s.series_id)
        if re.match(t1w_series_desc_pattern, s.series_description) and not 'NORM' in s.image_type and s.series_files >= 128:
            info[t1w_orig].append(s.series_id)

    return info

```

#### ***optional***: anonymization key csv

Prepare a csv file like the table below for your study. This is ***optional***, and will only apply to the ENIGMA input files.

| Original Name	| Original Project Name	| New Name | New Project Name | Combined Final Name |
| ----------- | ----------- | ----------- | ----------- | ----------- |
| subj01 | ProjectA | 98 | G | G98 |
| subj02 | ProjectA | 07 | G | G07 |
| ... | ... | ... | ... | ... |
| subj99 | ProjectA | 24 | G | G24 |

### Usage

```bash
cd /project/directory
/this/repo/path/generic_imaging_wrapper.sh <XNAT username> <CONFIG file>
```
