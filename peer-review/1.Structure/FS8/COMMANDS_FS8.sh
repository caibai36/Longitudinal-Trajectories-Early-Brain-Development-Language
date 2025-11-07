#!/bin/bash
# ================================================================================
# FREESURFER 8.1.0 INFANT PROCESSING - Complete Commands
# ================================================================================
# This script contains all commands needed to process infant MRI data with FS8
# Copy-paste ready for terminal execution
# ================================================================================

# 1. Activate FreeSurfer 8.1.0 environment
fs8

# 2. Set your custom subjects directory
export SUBJECTS_DIR=/data02/share/bin-wu/data/human/brain/harvard_mri/processed/freesurfer_fs8

# 3. Create subjects directory if it doesn't exist
mkdir -p $SUBJECTS_DIR

# 4. Import T1w to FreeSurfer format (~5 minutes)
recon-all -i /data02/share/bin-wu/data/human/brain/harvard_mri/raw/new_england/ds006169-1.0.3/sub-01/ses-03/anat/sub-01_ses-03_T1w.nii.gz \
          -subjid sub-01_ses-03 \
          -sd $SUBJECTS_DIR

# 5. Create orig.mgz (REQUIRED - fixes the FileNotFoundError)
mri_convert $SUBJECTS_DIR/sub-01_ses-03/mri/orig/001.mgz \
            $SUBJECTS_DIR/sub-01_ses-03/mri/orig.mgz

# 6. Run FreeSurfer 8.1.0 infant processing (~20-30 hours)
infant_recon_all -s sub-01_ses-03 \
                 -age 6 \
                 -all

# ================================================================================
# OPTIONAL: Run in background with logging
# ================================================================================
# Uncomment below to run in background (recommended for 20-30 hour job):
#
# nohup infant_recon_all -s sub-01_ses-03 -age 6 -all > fs8_processing.log 2>&1 &
#
# Then monitor with:
# tail -f fs8_processing.log
# ================================================================================
