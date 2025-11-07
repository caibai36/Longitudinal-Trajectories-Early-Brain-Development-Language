#!/bin/bash

# FreeSurfer 8.1.0 Infant Processing Pipeline
#
# This version uses FreeSurfer 8.1.0's built-in infant processing capabilities
# which are integrated into the main recon-all command.
#
# ADVANTAGES over FreeSurfer 7.3 + Infant FreeSurfer:
#   - Single FreeSurfer installation (no separate iFS needed)
#   - Simplified configuration
#   - Integrated infant processing with --infant flag
#   - Updated algorithms and templates
#   - Better age-specific processing
#
# Requirements:
#   - FreeSurfer 8.1.0 or later
#   - NO separate Infant FreeSurfer installation needed
#   - NO MATLAB needed
#   - NO iBEAT2 needed
#
# Usage:
#   reFS_fs8_infant.sh <subject_id> <age_in_months>
#
# Example:
#   reFS_fs8_infant.sh sub-01_ses-03 6
#
# Processing steps:
#   1. Import T1w to FreeSurfer format
#   2. Run infant_recon_all (FreeSurfer 8's integrated infant processing)
#   3. Quality control checks
#
# NOTE: This script assumes T1w has already been imported via:
#       recon-all -i <T1w.nii.gz> -subjid <subject_id>

set -e  # Exit on error

# Input arguments
SUBJECT_ID=$1
AGE_MONTHS=$2

# Check inputs
if [ $# -ne 2 ]; then
    echo "Usage: $0 <subject_id> <age_in_months>"
    echo ""
    echo "Example:"
    echo "  $0 sub-01_ses-03 6"
    echo ""
    echo "Note: T1w image should already be imported via:"
    echo "  recon-all -i /path/to/T1w.nii.gz -subjid <subject_id>"
    exit 1
fi

# Check FreeSurfer environment
if [ -z "$FREESURFER_HOME" ]; then
    echo "ERROR: FREESURFER_HOME not set"
    echo "Please source FreeSurfer 8.1.0 setup script:"
    echo "  export FREESURFER_HOME=/path/to/freesurfer-8.1.0"
    echo "  source \$FREESURFER_HOME/SetUpFreeSurfer.sh"
    exit 1
fi

if [ -z "$SUBJECTS_DIR" ]; then
    echo "ERROR: SUBJECTS_DIR not set"
    echo "Please set SUBJECTS_DIR:"
    echo "  export SUBJECTS_DIR=/path/to/subjects"
    exit 1
fi

# Check FreeSurfer version
FS_VERSION=$(cat $FREESURFER_HOME/build-stamp.txt 2>/dev/null | head -1 || echo "unknown")
echo "FreeSurfer version: $FS_VERSION"

# Warn if not FreeSurfer 8.x
if ! echo "$FS_VERSION" | grep -q "^8\."; then
    echo "WARNING: This script is designed for FreeSurfer 8.1.0 or later"
    echo "Current version: $FS_VERSION"
    echo "Proceeding anyway, but results may vary..."
    echo ""
fi

# Check age validity
if [ "$AGE_MONTHS" -lt 0 ] || [ "$AGE_MONTHS" -gt 24 ]; then
    echo "WARNING: Age $AGE_MONTHS months is outside typical infant range (0-24 months)"
    echo "Proceeding anyway..."
    echo ""
fi

# Subject paths
SUBJECT_DIR="${SUBJECTS_DIR}/${SUBJECT_ID}"

# Check if subject directory exists
if [ ! -d "$SUBJECT_DIR" ]; then
    echo "ERROR: Subject directory not found: $SUBJECT_DIR"
    echo ""
    echo "Please import T1w first:"
    echo "  recon-all -i /path/to/T1w.nii.gz -subjid $SUBJECT_ID"
    exit 1
fi

# Check if orig.mgz exists, if not create it from orig/001.mgz
if [ ! -f "${SUBJECT_DIR}/mri/orig.mgz" ]; then
    if [ -f "${SUBJECT_DIR}/mri/orig/001.mgz" ]; then
        echo "Creating orig.mgz from orig/001.mgz..."
        mri_convert "${SUBJECT_DIR}/mri/orig/001.mgz" "${SUBJECT_DIR}/mri/orig.mgz"
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to create orig.mgz"
            exit 1
        fi
        echo "✓ orig.mgz created successfully"
    else
        echo "ERROR: Neither orig.mgz nor orig/001.mgz found in ${SUBJECT_DIR}/mri/"
        echo ""
        echo "Please import T1w first:"
        echo "  recon-all -i /path/to/T1w.nii.gz -subjid $SUBJECT_ID"
        exit 1
    fi
fi

echo "=========================================================================="
echo "FreeSurfer 8.1.0 Infant Processing Pipeline"
echo "=========================================================================="
echo ""
echo "Subject ID:       $SUBJECT_ID"
echo "Age (months):     $AGE_MONTHS"
echo "Subject dir:      $SUBJECT_DIR"
echo "FreeSurfer:       $FREESURFER_HOME"
echo "FS Version:       $FS_VERSION"
echo ""
echo "=========================================================================="
echo ""

# Record start time
START_TIME=$(date +%s)
echo "Start time: $(date)"
echo ""

# Create log directory
LOG_DIR="${SUBJECT_DIR}/scripts"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/reFS_fs8_infant.log"

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "=========================================================================="
log_message "Starting FreeSurfer 8.1.0 Infant Processing"
log_message "=========================================================================="
log_message "Subject: $SUBJECT_ID"
log_message "Age: $AGE_MONTHS months"
log_message "FreeSurfer: $FS_VERSION"

# Run infant processing with FreeSurfer 8's integrated infant_recon_all
log_message ""
log_message "Running infant_recon_all with age $AGE_MONTHS months..."
log_message "This will take 20-30 hours depending on your system"
log_message ""

# FreeSurfer 8.1.0 infant processing command
# Uses -age flag to specify age in months
# The -all flag runs complete processing
infant_recon_all \
    -s "$SUBJECT_ID" \
    -age "$AGE_MONTHS" \
    -all \
    2>&1 | tee -a "$LOG_FILE"

RECON_EXIT_CODE=${PIPESTATUS[0]}

if [ $RECON_EXIT_CODE -ne 0 ]; then
    log_message ""
    log_message "ERROR: infant_recon_all failed with exit code $RECON_EXIT_CODE"
    log_message "Check log file: $LOG_FILE"
    exit $RECON_EXIT_CODE
fi

log_message ""
log_message "infant_recon_all completed successfully"

# Calculate processing time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
HOURS=$((DURATION / 3600))
MINUTES=$(( (DURATION % 3600) / 60 ))

log_message ""
log_message "=========================================================================="
log_message "Processing Complete"
log_message "=========================================================================="
log_message "Total time: ${HOURS}h ${MINUTES}m"
log_message "End time: $(date)"
log_message ""

# Quick QC checks
log_message "Running quick QC checks..."

# Check for key output files
check_file() {
    local file="$1"
    local description="$2"

    if [ -f "$file" ]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
        log_message "  ✓ $description: $file ($size bytes)"
        return 0
    else
        log_message "  ✗ $description: $file (NOT FOUND)"
        return 1
    fi
}

QC_PASSED=0
QC_FAILED=0

# Check MRI files
log_message ""
log_message "MRI Files:"
check_file "${SUBJECT_DIR}/mri/orig.mgz" "Original" && ((QC_PASSED++)) || ((QC_FAILED++))
check_file "${SUBJECT_DIR}/mri/T1.mgz" "T1 normalized" && ((QC_PASSED++)) || ((QC_FAILED++))
check_file "${SUBJECT_DIR}/mri/brainmask.mgz" "Brain mask" && ((QC_PASSED++)) || ((QC_FAILED++))
check_file "${SUBJECT_DIR}/mri/aseg.mgz" "Segmentation" && ((QC_PASSED++)) || ((QC_FAILED++))
check_file "${SUBJECT_DIR}/mri/wm.mgz" "White matter" && ((QC_PASSED++)) || ((QC_FAILED++))

# Check surface files
log_message ""
log_message "Surface Files:"
check_file "${SUBJECT_DIR}/surf/lh.white" "Left white surface" && ((QC_PASSED++)) || ((QC_FAILED++))
check_file "${SUBJECT_DIR}/surf/rh.white" "Right white surface" && ((QC_PASSED++)) || ((QC_FAILED++))
check_file "${SUBJECT_DIR}/surf/lh.pial" "Left pial surface" && ((QC_PASSED++)) || ((QC_FAILED++))
check_file "${SUBJECT_DIR}/surf/rh.pial" "Right pial surface" && ((QC_PASSED++)) || ((QC_FAILED++))

# Check stats files
log_message ""
log_message "Statistics Files:"
check_file "${SUBJECT_DIR}/stats/aseg.stats" "Subcortical stats" && ((QC_PASSED++)) || ((QC_FAILED++))
check_file "${SUBJECT_DIR}/stats/lh.aparc.stats" "Left cortical stats" && ((QC_PASSED++)) || ((QC_FAILED++))
check_file "${SUBJECT_DIR}/stats/rh.aparc.stats" "Right cortical stats" && ((QC_PASSED++)) || ((QC_FAILED++))

log_message ""
log_message "QC Summary: $QC_PASSED passed, $QC_FAILED failed"

if [ $QC_FAILED -gt 0 ]; then
    log_message "WARNING: Some expected output files are missing"
    log_message "This may indicate incomplete processing"
fi

log_message ""
log_message "=========================================================================="
log_message "Next Steps:"
log_message "=========================================================================="
log_message ""
log_message "1. Visual QC:"
log_message "   freeview -v $SUBJECT_DIR/mri/T1.mgz \\"
log_message "            -v $SUBJECT_DIR/mri/aseg.mgz:colormap=lut:opacity=0.3 \\"
log_message "            -f $SUBJECT_DIR/surf/lh.white:edgecolor=yellow \\"
log_message "            -f $SUBJECT_DIR/surf/rh.white:edgecolor=yellow \\"
log_message "            -f $SUBJECT_DIR/surf/lh.pial:edgecolor=red \\"
log_message "            -f $SUBJECT_DIR/surf/rh.pial:edgecolor=red"
log_message ""
log_message "2. Automated QC:"
log_message "   python detailed_qc_visualization_fs8.py $SUBJECTS_DIR $SUBJECT_ID"
log_message ""
log_message "3. Extract statistics:"
log_message "   - Subcortical volumes: $SUBJECT_DIR/stats/aseg.stats"
log_message "   - Cortical thickness: $SUBJECT_DIR/stats/lh.aparc.stats"
log_message "   - Cortical thickness: $SUBJECT_DIR/stats/rh.aparc.stats"
log_message ""
log_message "=========================================================================="
log_message "Pipeline completed successfully!"
log_message "=========================================================================="

echo ""
echo "✓ Processing complete!"
echo "✓ Log file: $LOG_FILE"
echo ""

exit 0
