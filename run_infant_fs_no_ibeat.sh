#!/bin/bash

# Simplified Infant FreeSurfer Pipeline (Without iBEAT)
# Uses existing validated scripts: fs_autorecon2_end.sh and fs_autorecon3_wrap.sh
#
# This script replaces the MATLAB/iBEAT steps with bash equivalents, then
# calls the existing validated processing scripts directly.

# Set bash to 'debug' mode, it will exit on:
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands'
set -euo pipefail

# ============================================================================
# General configuration
# ============================================================================
stage=0  # Start from 0 for full pipeline
stop_stage=100

# Subject and age configuration
subject_id=""
age_months=""

# Data paths
raw_t1w=""
subjects_dir="${SUBJECTS_DIR:-}"
ifs_dir=""
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/peer-review/1.Structure" && pwd)"

# Processing parameters
num_jobs=30

# Parse options (e.g., ./run_infant_fs_no_ibeat.sh --stage 1 --subject_id sub-01 --age_months 12)
. local/scripts/parse_options.sh || exit 1

# ============================================================================
# Parse positional arguments (if not set via options)
# ============================================================================
if [ $# -ge 1 ] && [ -z "$subject_id" ]; then
    subject_id=$1
fi

if [ $# -ge 2 ] && [ -z "$age_months" ]; then
    age_months=$2
fi

if [ $# -ge 3 ] && [ -z "$raw_t1w" ]; then
    raw_t1w=$3
fi

# ============================================================================
# Validate required arguments
# ============================================================================
if [ -z "$subject_id" ]; then
    echo "Error: subject_id not specified"
    echo ""
    echo "Usage: $0 [options] <subject_id> <age_months> [raw_t1w]"
    echo ""
    echo "Options:"
    echo "  --stage <N>           Start from stage N (default: 0)"
    echo "  --stop_stage <N>      Stop at stage N (default: 100)"
    echo "  --subject_id <str>    Subject ID (e.g., sub-01_ses-03)"
    echo "  --age_months <N>      Age in months (0-24)"
    echo "  --raw_t1w <path>      Path to raw T1w image"
    echo "  --subjects_dir <path> FreeSurfer SUBJECTS_DIR"
    echo "  --ifs_dir <path>      Infant FreeSurfer output directory"
    echo "  --num_jobs <N>        Number of parallel jobs (default: 30)"
    echo ""
    echo "Examples:"
    echo "  # Positional arguments:"
    echo "  $0 sub-01_ses-03 18 /path/to/T1w.nii.gz"
    echo ""
    echo "  # Named arguments:"
    echo "  $0 --subject_id sub-01_ses-03 --age_months 18 --raw_t1w /path/to/T1w.nii.gz"
    echo ""
    echo "  # Resume from stage 5:"
    echo "  $0 --stage 5 sub-01_ses-03 18"
    echo ""
    echo "  # Run only stages 0-3:"
    echo "  $0 --stage 0 --stop_stage 3 sub-01_ses-03 18 /path/to/T1w.nii.gz"
    exit 1
fi

if [ -z "$age_months" ]; then
    echo "Error: age_months not specified"
    exit 1
fi

# ============================================================================
# Set derived paths
# ============================================================================
if [ -z "$subjects_dir" ]; then
    subjects_dir="/data02/share/bin-wu/data/human/brain/harvard_mri/processed/sandbox/freesurfer_output"
    echo "Warning: SUBJECTS_DIR not set, using default: $subjects_dir"
fi

if [ -z "$ifs_dir" ]; then
    ifs_dir="$(dirname ${subjects_dir})/iFS"
fi

fp="${subjects_dir}/${subject_id}"
ifp="${ifs_dir}/${subject_id}"

# Paths for existing validated scripts
fs_autorecon2_script="${script_dir}/fs_autorecon2_end.sh"
fs_autorecon3_script="${script_dir}/fs_autorecon3_wrap.sh"

echo "============================================================================"
echo "Infant FreeSurfer Pipeline (Without iBEAT)"
echo "============================================================================"
echo "Subject ID:        $subject_id"
echo "Age (months):      $age_months"
echo "FreeSurfer dir:    $fp"
echo "Infant FS dir:     $ifp"
echo "Script dir:        $script_dir"
echo "Stage range:       $stage - $stop_stage"
echo "============================================================================"
echo ""

# Check if scripts exist
if [ ! -f "$fs_autorecon2_script" ]; then
    echo "Error: Cannot find fs_autorecon2_end.sh at: $fs_autorecon2_script"
    echo "Make sure you're running from the repository root"
    exit 1
fi

if [ ! -f "$fs_autorecon3_script" ]; then
    echo "Error: Cannot find fs_autorecon3_wrap.sh at: $fs_autorecon3_script"
    exit 1
fi

# ============================================================================
# Stage 0: Initial FreeSurfer processing
# ============================================================================
if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    echo "Stage 0: Running initial FreeSurfer processing..."
    date

    if [ -z "$raw_t1w" ]; then
        echo "No raw_t1w specified, checking if FreeSurfer processing already done..."

        if [ ! -d "$fp" ] || [ ! -f "$fp/mri/orig.mgz" ]; then
            echo "Error: FreeSurfer subject directory not found or incomplete: $fp"
            echo "Either provide raw_t1w or ensure recon-all already run"
            exit 1
        fi

        echo "Found existing FreeSurfer directory, skipping initial processing"
    else
        export SUBJECTS_DIR="$subjects_dir"
        mkdir -p "$subjects_dir"

        if [ ! -f "$raw_t1w" ]; then
            echo "Error: T1w file not found: $raw_t1w"
            exit 1
        fi

        echo "Running recon-all -all -nonuintensitycor..."
        recon-all -i "$raw_t1w" -subjid "$subject_id" -all -nonuintensitycor -openmp "$num_jobs"
    fi

    echo "Stage 0 complete"
    date
    echo ""
fi

# ============================================================================
# Stage 1: Clean up files from adult pipeline
# ============================================================================
if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    echo "Stage 1: Cleaning up adult-based files..."
    date

    cd "${fp}/mri"

    # Remove adult transforms (will use infant transforms)
    rm -f transforms/* orig_nu.mgz mri_nu_correct.mni.log
    mkdir -p transforms

    cd - > /dev/null

    echo "Stage 1 complete"
    date
    echo ""
fi

# ============================================================================
# Stage 2: Run infant_recon_all
# ============================================================================
if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    echo "Stage 2: Setting up and running infant_recon_all (age: $age_months months)..."
    date

    # Create iFS directory and convert input
    mkdir -p "$ifp"
    mri_convert -i "${fp}/mri/orig.mgz" -o "${ifp}/mprage.nii.gz"

    # Run infant_recon_all
    export SUBJECTS_DIR="$ifs_dir"
    infant_recon_all --s "$subject_id" --age "$age_months"

    echo "Stage 2 complete: Infant FS segmentation created"
    date
    echo ""
fi

# ============================================================================
# Stage 3: Create aseg.presurf.mgz (replaces ibeat2aseg.m)
# ============================================================================
if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    echo "Stage 3: Creating aseg.presurf.mgz from infant FS aseg..."
    date

    # Copy infant aseg to FreeSurfer directory as aseg.presurf.nii
    mri_convert -i "${ifp}/mri/aseg.mgz" \
                -o "${fp}/mri/aseg.presurf.nii"

    # Fix thalamus labels: 9→10, 48→49
    # This matches what ibeat2aseg.m does (lines 161-165)
    mri_binarize --i "${fp}/mri/aseg.presurf.nii" \
                 --replace 9 10 --replace 48 49 \
                 --o "${fp}/mri/aseg.presurf.nii"

    # Convert to .mgz format
    mri_convert -i "${fp}/mri/aseg.presurf.nii" \
                -o "${fp}/mri/aseg.presurf.mgz"

    echo "Stage 3 complete: aseg.presurf.mgz created"
    date
    echo ""
fi

# ============================================================================
# Stage 4: Create wm.mgz (replaces aseg2wm.m)
# ============================================================================
if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then
    echo "Stage 4: Creating wm.mgz from aseg.presurf..."
    date

    cd "${fp}/mri"

    # Based on aseg2wm.m:
    # wm_labs = [2 41 173 174 175]  → label 110 (white matter)
    # gm_labs = [4 11 12 13 26 28 43 50 51 52 58 60] → label 250 (subcortical GM)

    # Create base volume filled with zeros
    mri_binarize --i aseg.presurf.mgz --min 0 --max 0 --o wm_base.mgz

    # White matter labels (2=L-WM, 41=R-WM, 173-175=brainstem/vermis) → 110
    mri_binarize --i aseg.presurf.mgz \
                 --match 2 41 173 174 175 \
                 --o wm_110_mask.mgz

    # Apply label 110 to white matter voxels
    mri_mask -transfer 110 wm_110_mask.mgz wm_base.mgz wm_temp.mgz

    # Subcortical GM labels (ventricles, caudate, putamen, etc.) → 250
    mri_binarize --i aseg.presurf.mgz \
                 --match 4 11 12 13 26 28 43 50 51 52 58 60 \
                 --o gm_250_mask.mgz

    # Apply label 250 to subcortical GM voxels
    mri_mask -transfer 250 gm_250_mask.mgz wm_temp.mgz wm.mgz

    # Clean up temporary files
    rm -f wm_base.mgz wm_110_mask.mgz gm_250_mask.mgz wm_temp.mgz

    cd - > /dev/null

    echo "Stage 4 complete: wm.mgz created with labels 110 (WM) and 250 (subcortical GM)"
    date
    echo ""
fi

# ============================================================================
# Stage 5: Run fs_autorecon2_end.sh (white surface reconstruction)
# ============================================================================
if [ ${stage} -le 5 ] && [ ${stop_stage} -ge 5 ]; then
    echo "Stage 5: Running fs_autorecon2_end.sh..."
    date
    echo "This will:"
    echo "  - Run intensity normalization with infant brainmask"
    echo "  - Tessellate and place white surfaces"
    echo "  - Use infant-specific parameters (-in 3000, remeshing, etc.)"
    echo ""

    # Copy infant transforms first
    cp "${ifp}/mri/transforms"/talairach*.xfm "${fp}/mri/transforms/"

    # Call existing validated script
    # Arguments: fp (FS path), ifp (iFS path), sub (subject ID)
    export SUBJECTS_DIR="$subjects_dir"
    "$fs_autorecon2_script" "$fp" "$ifp" "$subject_id"

    echo "Stage 5 complete: White surfaces created"
    date
    echo ""
fi

# ============================================================================
# Stage 6: Run fs_autorecon3_wrap.sh (pial surfaces and statistics)
# ============================================================================
if [ ${stage} -le 6 ] && [ ${stop_stage} -ge 6 ]; then
    echo "Stage 6: Running fs_autorecon3_wrap.sh..."
    date
    echo "This will:"
    echo "  - Run autorecon3 with expert.opts"
    echo "  - Create pial surfaces with infant parameters"
    echo "  - Generate final statistics and parcellations"
    echo ""

    # Call existing validated script
    # Arguments: fp (FS path), fun (function/script dir), sub (subject ID)
    export SUBJECTS_DIR="$subjects_dir"
    "$fs_autorecon3_script" "$fp" "$script_dir" "$subject_id"

    echo "Stage 6 complete: Pial surfaces and statistics created"
    date
    echo ""
fi

# ============================================================================
# Stage 7: Quality control
# ============================================================================
if [ ${stage} -le 7 ] && [ ${stop_stage} -ge 7 ]; then
    echo "Stage 7: Quality control..."
    date

    log_file="$fp/scripts/recon-all.log"

    # Check for errors
    if [ -f "$log_file" ]; then
        if grep -qi "error" "$log_file"; then
            echo "WARNING: Errors found in processing log"
            grep -i "error" "$log_file" | tail -20
        else
            echo "No errors found in processing log"
        fi
    fi

    # Check key files
    echo ""
    echo "Checking key output files..."
    required_files=(
        "mri/aseg.presurf.mgz"
        "mri/wm.mgz"
        "mri/brainmask.mgz"
        "mri/brain.mgz"
        "mri/norm.mgz"
        "surf/lh.white"
        "surf/rh.white"
        "surf/lh.pial"
        "surf/rh.pial"
        "surf/lh.thickness"
        "surf/rh.thickness"
        "stats/aseg.stats"
        "stats/lh.aparc.stats"
        "stats/rh.aparc.stats"
    )

    all_exist=true
    for file in "${required_files[@]}"; do
        if [ -f "$fp/$file" ]; then
            echo "  ✓ $file"
        else
            echo "  ✗ $file (MISSING)"
            all_exist=false
        fi
    done

    echo ""
    if [ "$all_exist" = true ]; then
        echo "============================================================================"
        echo "SUCCESS: All key outputs generated!"
        echo "============================================================================"
        echo ""
        echo "View results with:"
        echo "  freeview -v $fp/mri/T1.mgz \\"
        echo "           -v $fp/mri/aseg.presurf.mgz:colormap=lut:opacity=0.4 \\"
        echo "           -f $fp/surf/lh.white:edgecolor=yellow \\"
        echo "           -f $fp/surf/lh.pial:edgecolor=red \\"
        echo "           -f $fp/surf/rh.white:edgecolor=yellow \\"
        echo "           -f $fp/surf/rh.pial:edgecolor=red"
        echo ""
        echo "Key difference from original pipeline:"
        echo "  - iBEAT tissue segmentation NOT merged (uses infant_recon_all aseg only)"
        echo "  - All other processing identical to validated pipeline"
    else
        echo "============================================================================"
        echo "ERROR: Some required files are missing!"
        echo "============================================================================"
        echo "Check the logs above for errors"
        exit 1
    fi

    date
    echo ""
fi

echo ""
echo "============================================================================"
echo "Pipeline complete!"
echo "Subject: $subject_id"
echo "Age: $age_months months"
echo "Output: $fp"
echo "Stages run: $stage - $stop_stage"
echo "============================================================================"
