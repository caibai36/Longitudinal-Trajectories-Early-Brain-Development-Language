#!/bin/bash

# Simplified Infant FreeSurfer Pipeline (Without iBEAT)
# Uses existing validated scripts: fs_autorecon2_end.sh and fs_autorecon3_wrap.sh
#
# This script replaces the MATLAB/iBEAT steps with bash equivalents, then
# calls the existing validated processing scripts directly.
#
# Usage: ./run_infant_fs_no_ibeat.sh <subject_id> <age_months> [raw_t1w_path]

set -euo pipefail

# ============================================================================
# Parse arguments
# ============================================================================
if [ $# -lt 2 ]; then
    echo "Usage: $0 <subject_id> <age_months> [raw_t1w_path]"
    echo ""
    echo "Example:"
    echo "  $0 sub-01_ses-03 18 /path/to/T1w.nii.gz"
    echo ""
    echo "If raw_t1w_path not provided, assumes FreeSurfer processing already started"
    exit 1
fi

subject_id=$1
age_months=$2
raw_t1w=${3:-""}

# ============================================================================
# Configuration - EDIT THESE PATHS
# ============================================================================
subjects_dir="${SUBJECTS_DIR:-/data02/share/bin-wu/data/human/brain/harvard_mri/processed/sandbox/freesurfer_output}"
ifs_base_dir="$(dirname ${subjects_dir})/iFS"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/peer-review/1.Structure" && pwd)"

# Paths for existing validated scripts
fs_autorecon2_script="${script_dir}/fs_autorecon2_end.sh"
fs_autorecon3_script="${script_dir}/fs_autorecon3_wrap.sh"

# Subject-specific paths
fp="${subjects_dir}/${subject_id}"
ifp="${ifs_base_dir}/${subject_id}"

echo "============================================================================"
echo "Infant FreeSurfer Pipeline (Without iBEAT)"
echo "============================================================================"
echo "Subject ID:        $subject_id"
echo "Age (months):      $age_months"
echo "FreeSurfer dir:    $fp"
echo "Infant FS dir:     $ifp"
echo "Script dir:        $script_dir"
echo "============================================================================"
echo ""

# Check if scripts exist
if [ ! -f "$fs_autorecon2_script" ]; then
    echo "ERROR: Cannot find fs_autorecon2_end.sh at: $fs_autorecon2_script"
    echo "Make sure you're running from the repository root"
    exit 1
fi

if [ ! -f "$fs_autorecon3_script" ]; then
    echo "ERROR: Cannot find fs_autorecon3_wrap.sh at: $fs_autorecon3_script"
    exit 1
fi

# ============================================================================
# Step 1: Initial FreeSurfer processing (if needed)
# ============================================================================
if [ -n "$raw_t1w" ]; then
    echo "Step 1: Running initial FreeSurfer processing..."
    date

    export SUBJECTS_DIR="$subjects_dir"
    mkdir -p "$subjects_dir"

    if [ ! -f "$raw_t1w" ]; then
        echo "ERROR: T1w file not found: $raw_t1w"
        exit 1
    fi

    # Run full pipeline with -nonuintensitycor flag (matches original)
    recon-all -i "$raw_t1w" -subjid "$subject_id" -all -nonuintensitycor

    echo "Step 1 complete"
    date
    echo ""
else
    echo "Step 1: Skipping initial recon-all (assuming already done)"

    if [ ! -d "$fp" ]; then
        echo "ERROR: FreeSurfer subject directory not found: $fp"
        echo "Either provide raw_t1w_path or ensure recon-all already run"
        exit 1
    fi
    echo ""
fi

# ============================================================================
# Step 2: Clean up files from adult pipeline
# ============================================================================
echo "Step 2: Cleaning up adult-based files..."
date

cd "${fp}/mri"

# Remove adult transforms (matches original line 61)
rm -f transforms/* orig_nu.mgz mri_nu_correct.mni.log
mkdir -p transforms

cd - > /dev/null

echo "Step 2 complete"
date
echo ""

# ============================================================================
# Step 3: Run infant_recon_all
# ============================================================================
echo "Step 3: Setting up and running infant_recon_all (age: $age_months months)..."
date

# Create iFS directory and convert input (matches original lines 65-67)
mkdir -p "$ifp"
mri_convert -i "${fp}/mri/orig.mgz" -o "${ifp}/mprage.nii.gz"

# Run infant_recon_all (matches original lines 72)
# Note: You may need to adjust iFS_wrap.sh or set infant FS environment here
export SUBJECTS_DIR="$ifs_base_dir"
infant_recon_all --s "$subject_id" --age "$age_months"

echo "Step 3 complete: Infant FS segmentation created"
date
echo ""

# ============================================================================
# Step 4: Create aseg.presurf.mgz (replaces ibeat2aseg.m WITHOUT iBEAT merge)
# ============================================================================
echo "Step 4: Creating aseg.presurf.mgz from infant FS aseg..."
date

# Copy infant aseg to FreeSurfer directory as aseg.presurf.nii (for compatibility)
mri_convert -i "${ifp}/mri/aseg.mgz" \
            -o "${fp}/mri/aseg.presurf.nii"

# Fix thalamus labels: 9→10, 48→49 (matches ibeat2aseg.m lines 161-165)
mri_binarize --i "${fp}/mri/aseg.presurf.nii" \
             --replace 9 10 --replace 48 49 \
             --o "${fp}/mri/aseg.presurf.nii"

# Convert to .mgz format
mri_convert -i "${fp}/mri/aseg.presurf.nii" \
            -o "${fp}/mri/aseg.presurf.mgz"

echo "Step 4 complete: aseg.presurf.mgz created"
date
echo ""

# ============================================================================
# Step 5: Create wm.mgz (replaces aseg2wm.m)
# ============================================================================
echo "Step 5: Creating wm.mgz from aseg.presurf..."
date

cd "${fp}/mri"

# Based on aseg2wm.m:
# wm_labs = [2 41 173 174 175]  → label 110
# gm_labs = [4 11 12 13 26 28 43 50 51 52 58 60] → label 250

# Create temporary volume filled with zeros
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

# Clean up
rm -f wm_base.mgz wm_110_mask.mgz gm_250_mask.mgz wm_temp.mgz

cd - > /dev/null

echo "Step 5 complete: wm.mgz created with labels 110 (WM) and 250 (subcortical GM)"
date
echo ""

# ============================================================================
# Step 6: Run fs_autorecon2_end.sh (existing validated script)
# ============================================================================
echo "Step 6: Running fs_autorecon2_end.sh..."
date
echo "This will:"
echo "  - Run intensity normalization with infant brainmask"
echo "  - Tessellate and place white surfaces"
echo "  - Use infant-specific parameters (-in 3000, remeshing, etc.)"
echo ""

# Copy infant transforms first (matches original line 85)
cp "${ifp}/mri/transforms"/talairach*.xfm "${fp}/mri/transforms/"

# Call existing validated script (matches original line 86)
# Arguments: fp (FS path), ifp (iFS path), sub (subject ID)
export SUBJECTS_DIR="$subjects_dir"
"$fs_autorecon2_script" "$fp" "$ifp" "$subject_id"

echo "Step 6 complete: White surfaces created"
date
echo ""

# ============================================================================
# Step 7: Run fs_autorecon3_wrap.sh (existing validated script)
# ============================================================================
echo "Step 7: Running fs_autorecon3_wrap.sh..."
date
echo "This will:"
echo "  - Run autorecon3 with expert.opts"
echo "  - Create pial surfaces with infant parameters"
echo "  - Generate final statistics and parcellations"
echo ""

# Call existing validated script (matches original line 91)
# Arguments: fp (FS path), fun (function/script dir), sub (subject ID)
export SUBJECTS_DIR="$subjects_dir"
"$fs_autorecon3_script" "$fp" "$script_dir" "$subject_id"

echo "Step 7 complete: Pial surfaces and statistics created"
date
echo ""

# ============================================================================
# Quality Control
# ============================================================================
echo "============================================================================"
echo "Quality Control Check"
echo "============================================================================"

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
    echo "SUCCESS: All key outputs generated!"
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
    echo "ERROR: Some required files are missing!"
    echo "Check the logs above for errors"
    exit 1
fi

echo ""
echo "============================================================================"
echo "Pipeline Complete!"
echo "Subject: $subject_id"
echo "Age: $age_months months"
echo "Output: $fp"
echo "============================================================================"
