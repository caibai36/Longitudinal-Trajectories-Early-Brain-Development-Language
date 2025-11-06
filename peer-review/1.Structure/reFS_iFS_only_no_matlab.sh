#!/bin/bash

# Modified infant brain morphometry pipeline using ONLY infant FreeSurfer (iFS) and standard FreeSurfer (FS)
# This version removes BOTH iBEAT2 and MATLAB dependencies from the original pipeline
#
# Pipeline steps:
#   1. Runs FS up to completion
#   2. Deletes transforms and some intermediate files
#   3. Sets up for iFS
#   4. Runs iFS in full
#   5. Processes iFS aseg for FreeSurfer compatibility (bash-only, no MATLAB)
#   6. Generates wm.mgz from iFS aseg (bash-only, no MATLAB)
#   7. Resumes FS recon-all pipeline with adjustments
#   8. Finishes FS recon-all pipeline with autorecon3
#
# Inputs:
#   1. subjid
#   2. age for infant FS (in months)
#
# Dependencies: Infant FreeSurfer, FreeSurfer 7.3+ (NO iBEAT2, NO MATLAB)


#---------------------------------------------------------------------------------------------------------------------------


sub=$1
age=$2
fp=${SUBJECTS_DIR}/${sub}
if_dir=`dirname ${SUBJECTS_DIR}`/iFS
ifp=${if_dir}/${sub}

echo Using ... $FREESURFER_HOME

# Check inputs
if [ $# -ne 2 ]; then
    echo "Two arguments required: Participant ID and age (in months)."
    echo "Usage: $0 <subject_id> <age_in_months>"
    exit 1
fi

# Step 1.
echo "Running first steps of recon-all"
recon-all -all -subjid ${sub} -nonuintensitycor


# Step 2.
echo "Removing files based on initial FS run"
rm -f ${fp}/mri/transforms/* ${fp}/mri/orig_nu.mgz ${fp}/mri/mri_nu_correct.mni.log


# Step 3.
echo "Setting up for infant FS"
mkdir -p ${ifp}
mri_convert -i ${fp}/mri/orig.mgz -o ${ifp}/mprage.nii.gz


# Step 4.
echo "Running infant FS"
iFS_wrap.sh ${if_dir} ${sub} ${age}

echo Using ... $FREESURFER_HOME


# Step 5. Process iFS aseg for FreeSurfer compatibility (BASH-ONLY, NO MATLAB)
echo "Processing iFS aseg for FreeSurfer compatibility"

# Copy iFS aseg to working directory
mri_convert -i ${ifp}/mri/aseg.mgz -o ${fp}/mri/aseg.presurf.mgz

# Adjust thalamus labels using FreeSurfer tools
# iFS uses labels 9 (left thalamus) and 48 (right thalamus)
# Standard FS uses labels 10 (left thalamus) and 49 (right thalamus)
echo "Adjusting thalamus labels (9->10, 48->49)"

# Create temporary file for label remapping
tmp_aseg=${fp}/mri/aseg.tmp.mgz

# Change label 9 to 10 (left thalamus)
mri_binarize --i ${fp}/mri/aseg.presurf.mgz --match 9 --replace 10 --o ${tmp_aseg}
# Update the aseg with changed label, keeping other labels intact
mri_mask -transfer 10 ${tmp_aseg} ${fp}/mri/aseg.presurf.mgz ${fp}/mri/aseg.presurf.mgz

# Change label 48 to 49 (right thalamus)
mri_binarize --i ${fp}/mri/aseg.presurf.mgz --match 48 --replace 49 --o ${tmp_aseg}
mri_mask -transfer 49 ${tmp_aseg} ${fp}/mri/aseg.presurf.mgz ${fp}/mri/aseg.presurf.mgz

# Clean up
rm -f ${tmp_aseg}


# Step 6. Generate wm.mgz from aseg (BASH-ONLY, NO MATLAB)
echo "Generating white matter file from iFS aseg"

# White matter labels: 2, 41, 173, 174, 175 -> 110
# Gray matter labels: 4, 11, 12, 13, 26, 28, 43, 50, 51, 52, 58, 60 -> 250

# Initialize empty wm volume
mri_binarize --i ${fp}/mri/aseg.presurf.mgz --match 0 --o ${fp}/mri/wm.mgz

# Add white matter labels (set to 110)
mri_binarize --i ${fp}/mri/aseg.presurf.mgz \
    --match 2 41 173 174 175 \
    --replace 110 \
    --o ${fp}/mri/wm_tmp.mgz

# Add gray matter labels (set to 250)
mri_binarize --i ${fp}/mri/aseg.presurf.mgz \
    --match 4 11 12 13 26 28 43 50 51 52 58 60 \
    --replace 250 \
    --o ${fp}/mri/gm_tmp.mgz

# Combine WM and GM into final wm.mgz
# Use mri_convert with arithmetic to add the volumes
fscalc ${fp}/mri/wm_tmp.mgz add ${fp}/mri/gm_tmp.mgz --o ${fp}/mri/wm.mgz

# Clean up temporary files
rm -f ${fp}/mri/wm_tmp.mgz ${fp}/mri/gm_tmp.mgz


# Step 7.
echo "Finishing FS recon-all -autorecon2-wm pipeline"
cp ${ifp}/mri/transforms/talairach*xfm ${fp}/mri/transforms
fs_autorecon2_end.sh ${fp} ${ifp} ${sub}


# Step 8.
echo "Running FS recon-all -autorecon3 pipeline with adjustments"
fs_autorecon3_wrap.sh ${fp} `dirname $0` ${sub}

echo "Pipeline complete!"
