#!/bin/bash

# Modified infant brain morphometry pipeline using ONLY infant FreeSurfer (iFS) and standard FreeSurfer (FS)
# This version removes the iBEATv2 dependency from the original pipeline
#
# Pipeline steps:
#   1. Runs FS up to completion
#   2. Deletes transforms and some intermediate files
#   3. Sets up for iFS
#   4. Runs iFS in full
#   5. Processes iFS aseg for FreeSurfer compatibility (thalamus label adjustment)
#   6. Generates wm.mgz from iFS aseg
#   7. Resumes FS recon-all pipeline with adjustments
#   8. Finishes FS recon-all pipeline with autorecon3
#
# Inputs:
#   1. subjid
#   2. age for infant FS (in months)
#
# Note: This version uses iFS tissue segmentation throughout, which may produce
# different results than the hybrid iBEAT2/iFS approach in the original pipeline


#---------------------------------------------------------------------------------------------------------------------------


sub=$1
fp=${SUBJECTS_DIR}/${sub}
if_dir=`dirname ${SUBJECTS_DIR}`/iFS
ifp=${if_dir}/${sub}

m_fp=\'${fp}/mri\' # output location for iFS_aseg_process.m
m_ifp=\'${ifp}\'
m_aseg=\'${fp}/mri/aseg.presurf.nii\' # output from iFS_aseg_process.m and input to aseg2wm_iFS.m
fun=`dirname $(which iFS_aseg_process.m)`
m_fun=\'${fun}\'

echo Using ... $FREESURFER_HOME

# Check inputs
if [ $# -ne 2 ]; then
    echo "Two arguments required: Participant ID and age (in months)."
    echo "Usage: $0 <subject_id> <age_in_months>"
    exit 1
fi

# Step 1.
echo Running first steps of recon-all
recon-all -all -subjid ${sub} -nonuintensitycor


# Step 2.
echo Removing files based on initial FS run
rm ${fp}/mri/transforms/* ${fp}/mri/orig_nu.mgz ${fp}/mri/mri_nu_correct.mni.log


# Step 3.
echo Setting up for infant FS
mkdir -p ${ifp}
mri_convert -i ${fp}/mri/orig.mgz -o ${ifp}/mprage.nii.gz


# Step 4.
echo Running infant FS
iFS_wrap.sh ${if_dir} $1 $2

echo Using ... $FREESURFER_HOME


# Step 5.
echo Processing iFS aseg for FreeSurfer compatibility and generating wm file
matlab -nodesktop -nosplash -r "addpath(${m_fun}); iFS_aseg_process(${m_ifp}, ${m_fp}); aseg2wm_iFS(${m_aseg}); exit;"


# Step 6.
echo Finishing FS recon-all -autorecon2-wm pipeline, including going back and performing some -autorecon1 steps using iFS files
cp ${ifp}/mri/transforms/talairach*xfm ${fp}/mri/transforms
fs_autorecon2_end.sh ${fp} ${ifp} ${sub}


# Step 7.
echo Running FS recon-all -autorecon3 pipeline with adjustments
fs_autorecon3_wrap.sh ${fp} ${fun} ${sub}
