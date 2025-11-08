#!/bin/bash

# Infant FreeSurfer Pipeline (Without iBEAT)
# Adapted from the validated pipeline in peer-review/1.Structure/
# This script combines infant_recon_all with manual FreeSurfer surface reconstruction
#
# Key differences from simplified approach:
#   - Manually executes autorecon2 steps with infant-specific parameters
#   - Manually creates pial surfaces with infant tissue contrast settings
#   - Uses expert.opts to control recon-all behavior
#   - Generates wm.mgz from aseg.presurf with proper labels

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
stage=0
freesurfer_version="7.3.0"  # Use 7.3 - validated in original pipeline

# Subject and age configuration
subject_id="sub-01_ses-03"
age_months=18

# Data paths
raw_t1w="/data02/share/bin-wu/data/human/brain/harvard_mri/raw/new_england/ds006169-1.0.3/sub-01/ses-03/anat/sub-01_ses-03_T1w.nii.gz"
subjects_dir="/data02/share/bin-wu/data/human/brain/harvard_mri/processed/sandbox/freesurfer_output"
ifs_dir="/data02/share/bin-wu/data/human/brain/harvard_mri/processed/sandbox/iFS"

# Processing parameters
num_jobs=30

# Parse options
. local/scripts/parse_options.sh || exit 1

# ============================================================================
# Stage 0: Verify installation and setup
# ============================================================================
if [ ${stage} -le 0 ]; then
    date
    echo "Stage 0: Verifying FreeSurfer installation..."
    mkdir -p "$subjects_dir" "$ifs_dir"

    recon-all -version
    echo "Input T1w: $raw_t1w"
    echo "Subject ID: $subject_id"
    echo "Age (months): $age_months"
    echo "Output directory: $subjects_dir"

    if [ ! -f "$raw_t1w" ]; then
        echo "Error: Input T1w file not found: $raw_t1w"
        exit 1
    fi

    date
fi

# ============================================================================
# Stage 1: Initial FreeSurfer processing (up to step 15)
# ============================================================================
# What it does:
#   - Creates orig.mgz (FreeSurfer format)
#   - Motion correction and intensity normalization (nu.mgz)
#   - Initial talairach registration
#   - Adult-based skull stripping and segmentation
#
# Note: Using -autorecon1 is faster than -all since surfaces will be redone
#       Original pipeline used -all with -nonuintensitycor flag

if [ ${stage} -le 1 ]; then
    date
    echo "Stage 1: Running initial FreeSurfer processing..."

    export SUBJECTS_DIR="$subjects_dir"

    # Run full pipeline with adult templates
    # The -nonuintensitycor flag skips nu intensity correction (will redo later)
    recon-all -i "$raw_t1w" -subjid "$subject_id" -all -nonuintensitycor -openmp "$num_jobs"

    echo "Stage 1 complete: $subjects_dir/$subject_id/mri/orig.mgz created"

    date
fi

# ============================================================================
# Stage 2: Clean up files from adult pipeline
# ============================================================================
# What it does:
#   - Removes adult-based transform files
#   - Removes files that will be regenerated with infant parameters
#
# Why: These files were created with adult templates and need to be replaced

if [ ${stage} -le 2 ]; then
    date
    echo "Stage 2: Cleaning up adult-based files..."

    cd "$subjects_dir/$subject_id/mri"

    # Remove adult transforms (will use infant transforms)
    rm -f transforms/* orig_nu.mgz mri_nu_correct.mni.log
    mkdir -p transforms

    cd -

    echo "Stage 2 complete: Adult-based files removed"

    date
fi

# ============================================================================
# Stage 3: Run infant_recon_all for age-specific segmentation
# ============================================================================
# What it does:
#   - Age-appropriate brain atlases (0-24 months)
#   - Infant-specific tissue segmentation
#   - Brain extraction optimized for infant anatomy
#   - Subcortical structure segmentation
#
# Key outputs:
#   - aseg.mgz: Infant subcortical segmentation
#   - brainmask.mgz: Infant brain mask
#   - wm.mgz: White matter mask
#   - transforms/talairach*.xfm: Infant atlas registration

if [ ${stage} -le 3 ]; then
    date
    echo "Stage 3: Running infant_recon_all (age: $age_months months)..."

    # Prepare input for infant_recon_all
    mkdir -p "$ifs_dir/$subject_id"
    mri_convert -i "$subjects_dir/$subject_id/mri/orig.mgz" \
                -o "$ifs_dir/$subject_id/mprage.nii.gz"

    # Run infant-specific segmentation
    export SUBJECTS_DIR="$ifs_dir"
    infant_recon_all --s "$subject_id" --age "$age_months"

    echo "Stage 3 complete: Infant segmentation in $ifs_dir/$subject_id"

    date
fi

# ============================================================================
# Stage 4: Generate aseg.presurf.mgz from infant_recon_all aseg
# ============================================================================
# What it does:
#   - Copies infant aseg to aseg.presurf.mgz
#   - Fixes thalamus labels (9→10, 48→49) to match FreeSurfer convention
#
# Note: Original pipeline merged iBEAT tissue labels here, but we skip that

if [ ${stage} -le 4 ]; then
    date
    echo "Stage 4: Preparing aseg.presurf.mgz..."

    # Copy infant aseg to FreeSurfer directory
    cp "$ifs_dir/$subject_id/mri/aseg.mgz" \
       "$subjects_dir/$subject_id/mri/aseg.presurf.mgz"

    # Fix thalamus labels to match FreeSurfer convention
    # iFS uses 9/48 for thalamus, FS expects 10/49
    mri_binarize --i "$subjects_dir/$subject_id/mri/aseg.presurf.mgz" \
                 --replace 9 10 --replace 48 49 \
                 --o "$subjects_dir/$subject_id/mri/aseg.presurf.mgz"

    echo "Stage 4 complete: aseg.presurf.mgz created with corrected labels"

    date
fi

# ============================================================================
# Stage 5: Generate wm.mgz from aseg.presurf
# ============================================================================
# What it does:
#   - Creates wm.mgz with proper labels for surface tessellation
#   - Label 110: White matter (cortical WM, brainstem)
#   - Label 250: Subcortical GM structures (needed for mri_fill)
#
# Based on: aseg2wm.m from original pipeline

if [ ${stage} -le 5 ]; then
    date
    echo "Stage 5: Generating wm.mgz from aseg.presurf..."

    cd "$subjects_dir/$subject_id/mri"

    # White matter labels: 2=left-WM, 41=right-WM, 172-175=brainstem/vermis
    # Map to label 110
    mri_binarize --i aseg.presurf.mgz \
                 --match 2 41 173 174 175 \
                 --o wm_110.mgz
    mri_mask -transfer 110 wm_110.mgz aseg.presurf.mgz wm_temp.mgz

    # Subcortical GM labels: ventricles, caudate, putamen, pallidum, hippocampus, amygdala, accumbens, ventral-DC
    # Map to label 250
    mri_binarize --i aseg.presurf.mgz \
                 --match 4 11 12 13 26 28 43 50 51 52 58 60 \
                 --o gm_250.mgz
    mri_mask -transfer 250 gm_250.mgz wm_temp.mgz wm.mgz

    # Clean up
    rm -f wm_110.mgz gm_250.mgz wm_temp.mgz

    cd -

    echo "Stage 5 complete: wm.mgz created with labels 110 (WM) and 250 (subcortical GM)"

    date
fi

# ============================================================================
# Stage 6: Copy infant transforms and brainmask
# ============================================================================
# What it does:
#   - Replaces adult transforms with infant-specific transforms
#   - Uses infant brainmask for intensity normalization

if [ ${stage} -le 6 ]; then
    date
    echo "Stage 6: Copying infant transforms and brainmask..."

    # Copy infant talairach transforms
    cp "$ifs_dir/$subject_id/mri/transforms"/talairach*.xfm \
       "$subjects_dir/$subject_id/mri/transforms/"

    # Backup adult brainmask and use infant version
    if [ -f "$subjects_dir/$subject_id/mri/brainmask.mgz" ]; then
        cp "$subjects_dir/$subject_id/mri/brainmask.mgz" \
           "$subjects_dir/$subject_id/mri/brainmask.adult.mgz"
    fi

    cp "$ifs_dir/$subject_id/mri/brainmask.mgz" \
       "$subjects_dir/$subject_id/mri/brainmask.mgz"

    echo "Stage 6 complete: Infant transforms and brainmask copied"

    date
fi

# ============================================================================
# Stage 7: Manual autorecon2 - Intensity normalization
# ============================================================================
# What it does:
#   - N4 bias field correction with infant brain mask
#   - Intensity normalization (T1.mgz)
#   - EM registration to infant atlas
#   - CA normalization with infant mask (norm.mgz)
#   - Final brain normalization using aseg.presurf (brain.mgz)
#
# Based on: fs_autorecon2_end.sh lines 16-24
# Critical: Uses infant brainmask and aseg.presurf throughout

if [ ${stage} -le 7 ]; then
    date
    echo "Stage 7: Running intensity normalization with infant parameters..."

    export SUBJECTS_DIR="$subjects_dir"
    cd "$subjects_dir/$subject_id/mri"

    # N4 bias field correction
    mri_nu_correct.mni --i orig.mgz --o nu.mgz \
                       --uchar transforms/talairach.xfm \
                       --n 2 --ants-n4

    # First intensity normalization
    mri_normalize -g 1 -seed 1234 -mprage nu.mgz T1.mgz

    # Mask T1 with infant brainmask
    mri_mask T1.mgz brainmask.mgz brainmask.mgz

    # EM registration to atlas with infant brain mask
    mri_em_register -uns 3 -mask brainmask.mgz nu.mgz \
                    "$FREESURFER_HOME/average/RB_all_2020-01-02.gca" \
                    transforms/talairach.lta

    # CA normalization with infant brain mask
    mri_ca_normalize -c ctrl_pts.mgz -mask brainmask.mgz nu.mgz \
                     "$FREESURFER_HOME/average/RB_all_2020-01-02.gca" \
                     transforms/talairach.lta norm.mgz

    # Final normalization using aseg.presurf
    mri_normalize -seed 1234 -mprage -aseg aseg.presurf.mgz \
                  -mask brainmask.mgz norm.mgz brain.mgz

    cd -

    echo "Stage 7 complete: Intensity normalization with infant parameters"

    date
fi

# ============================================================================
# Stage 8: Manual autorecon2 - White surface reconstruction (Part 1)
# ============================================================================
# What it does:
#   - Final brain mask for surfaces (brain.finalsurfs.mgz)
#   - Fill white matter (filled.mgz)
#   - Tessellate white surface
#   - Extract main component, smooth, inflate
#
# Based on: fs_autorecon2_end.sh lines 28-46
# Critical: Uses aseg.presurf (not aseg.auto) for mri_fill

if [ ${stage} -le 8 ]; then
    date
    echo "Stage 8: White surface tessellation..."

    export SUBJECTS_DIR="$subjects_dir"
    cd "$subjects_dir/$subject_id/mri"

    # Create brain mask for final surfaces
    mri_mask -T 5 brain.mgz brainmask.mgz brain.finalsurfs.mgz

    # Fill white matter using aseg.presurf
    mri_fill -a ../scripts/ponscc.cut.log \
             -xform transforms/talairach.lta \
             -segmentation aseg.presurf.mgz \
             wm.mgz filled.mgz \
             -ctab "$FREESURFER_HOME/SubCorticalMassLUT.txt"

    cp filled.mgz filled.auto.mgz

    # Tessellate left hemisphere (label 255)
    mri_pretess filled.mgz 255 norm.mgz filled-pretess255.mgz
    mri_tessellate filled-pretess255.mgz 255 ../surf/lh.orig.nofix
    rm -f filled-pretess255.mgz

    # Tessellate right hemisphere (label 127)
    mri_pretess filled.mgz 127 norm.mgz filled-pretess127.mgz
    mri_tessellate filled-pretess127.mgz 127 ../surf/rh.orig.nofix
    rm -f filled-pretess127.mgz

    cd "$subjects_dir/$subject_id/surf"

    # Extract main component and smooth
    mris_extract_main_component lh.orig.nofix lh.orig.nofix
    mris_extract_main_component rh.orig.nofix rh.orig.nofix

    mris_smooth -nw -seed 1234 lh.orig.nofix lh.smoothwm.nofix
    mris_smooth -nw -seed 1234 rh.orig.nofix rh.smoothwm.nofix

    mris_inflate -no-save-sulc lh.smoothwm.nofix lh.inflated.nofix
    mris_inflate -no-save-sulc rh.smoothwm.nofix rh.inflated.nofix

    # Sphere inflation - CRITICAL: Use -in 3000 for infants (not default 1000)
    echo "Creating spheres with infant-specific parameters (-in 3000)..."
    mris_sphere -q -p 6 -a 128 -seed 1234 -in 3000 lh.inflated.nofix lh.qsphere.nofix
    mris_sphere -q -p 6 -a 128 -seed 1234 -in 3000 rh.inflated.nofix rh.qsphere.nofix

    cd -

    echo "Stage 8 complete: White surface tessellated"

    date
fi

# ============================================================================
# Stage 9: Manual autorecon2 - White surface reconstruction (Part 2)
# ============================================================================
# What it does:
#   - Topology correction
#   - Surface remeshing (critical for infants)
#   - Remove self-intersections
#   - Autodetect GM/WM stats
#   - Final white surface placement
#
# Based on: fs_autorecon2_end.sh lines 49-73
# Critical: Uses -cover_seg aseg.presurf.mgz (not default aseg.mgz)

if [ ${stage} -le 9 ]; then
    date
    echo "Stage 9: Topology correction and white surface placement..."

    export SUBJECTS_DIR="$subjects_dir"
    cd "$subjects_dir/$subject_id/surf"

    # Copy to working files
    cp lh.orig.nofix lh.orig
    cp rh.orig.nofix rh.orig
    cp lh.qsphere.nofix lh.qsphere
    cp rh.qsphere.nofix rh.qsphere

    # Topology correction
    echo "Running topology correction..."
    mris_topo_fixer -mgz -warnings "$subject_id" lh
    mris_topo_fixer -mgz -warnings "$subject_id" rh

    # Rename corrected surfaces
    mv lh.orig_corrected lh.orig.premesh
    mv rh.orig_corrected rh.orig.premesh
    rm -f lh.orig rh.orig

    # Check Euler number
    mris_euler_number lh.orig.premesh
    mris_euler_number rh.orig.premesh

    # Remesh - CRITICAL for infant surfaces (3 iterations)
    echo "Remeshing surfaces (infant-specific)..."
    mris_remesh --remesh --iters 3 --input lh.orig.premesh --output lh.orig
    mris_remesh --remesh --iters 3 --input rh.orig.premesh --output rh.orig

    # Remove self-intersections
    mris_remove_intersection lh.orig lh.orig
    mris_remove_intersection rh.orig rh.orig

    # Autodetect GM/WM statistics
    mris_autodet_gwstats --o autodet.gw.stats.lh.dat \
                         --i ../mri/brain.finalsurfs.mgz \
                         --wm ../mri/wm.mgz \
                         --surf lh.orig.premesh

    mris_autodet_gwstats --o autodet.gw.stats.rh.dat \
                         --i ../mri/brain.finalsurfs.mgz \
                         --wm ../mri/wm.mgz \
                         --surf rh.orig.premesh

    # Final white surface placement - CRITICAL: Use aseg.presurf not aseg
    echo "Placing white surfaces with aseg.presurf..."
    mris_make_surfaces -output .preaparc -soap -orig_white orig \
                       -aseg aseg.presurf \
                       -cover_seg "$subjects_dir/$subject_id/mri/aseg.presurf.mgz" \
                       -noaparc -whiteonly -mgz \
                       -T1 brain.finalsurfs \
                       "$subject_id" lh

    mris_make_surfaces -output .preaparc -soap -orig_white orig \
                       -aseg aseg.presurf \
                       -cover_seg "$subjects_dir/$subject_id/mri/aseg.presurf.mgz" \
                       -noaparc -whiteonly -mgz \
                       -T1 brain.finalsurfs \
                       "$subject_id" rh

    cd -

    echo "Stage 9 complete: White surfaces placed"

    date
fi

# ============================================================================
# Stage 10: Manual autorecon2 - Finalize white surfaces
# ============================================================================
# What it does:
#   - Generate cortex labels
#   - Smooth white surfaces
#   - Create inflated surfaces
#   - Calculate curvature
#
# Based on: fs_autorecon2_end.sh lines 74-90

if [ ${stage} -le 10 ]; then
    date
    echo "Stage 10: Finalizing white surfaces..."

    export SUBJECTS_DIR="$subjects_dir"
    cd "$subjects_dir/$subject_id/surf"

    # Generate cortex labels
    mri_label2label --label-cortex lh.white.preaparc \
                    ../mri/aseg.presurf.mgz 0 \
                    ../label/lh.cortex.label

    mri_label2label --label-cortex lh.white.preaparc \
                    ../mri/aseg.presurf.mgz 1 \
                    ../label/lh.cortex+hipamyg.label

    mri_label2label --label-cortex rh.white.preaparc \
                    ../mri/aseg.presurf.mgz 0 \
                    ../label/rh.cortex.label

    mri_label2label --label-cortex rh.white.preaparc \
                    ../mri/aseg.presurf.mgz 1 \
                    ../label/rh.cortex+hipamyg.label

    # Smooth white surfaces
    mris_smooth -n 3 -nw -seed 1234 lh.white.preaparc lh.smoothwm
    mris_smooth -n 3 -nw -seed 1234 rh.white.preaparc rh.smoothwm

    # Create inflated surfaces
    mris_inflate lh.smoothwm lh.inflated
    mris_inflate rh.smoothwm rh.inflated

    # Calculate curvature
    mris_curvature -w -seed 1234 lh.white.preaparc
    ln -sf lh.white.preaparc.H lh.white.H
    ln -sf lh.white.preaparc.K lh.white.K
    mris_curvature -seed 1234 -thresh .999 -n -a 5 -w -distances 10 10 lh.inflated

    mris_curvature -w -seed 1234 rh.white.preaparc
    ln -sf rh.white.preaparc.H rh.white.H
    ln -sf rh.white.preaparc.K rh.white.K
    mris_curvature -seed 1234 -thresh .999 -n -a 5 -w -distances 10 10 rh.inflated

    cd -

    echo "Stage 10 complete: White surfaces finalized"

    date
fi

# ============================================================================
# Stage 11: Create expert.opts for autorecon3
# ============================================================================
# What it does:
#   - Creates expert.opts file to control autorecon3
#   - Causes autorecon3 to crash before pial placement
#   - Allows manual pial creation with infant parameters
#
# Based on: expert.opts from original pipeline

if [ ${stage} -le 11 ]; then
    date
    echo "Stage 11: Creating expert.opts..."

    mkdir -p "$subjects_dir/$subject_id/scripts"

    cat > "$subjects_dir/$subject_id/scripts/expert.opts" << 'EOF'
PlaceWhiteSurf --intensity 0
PlaceT1PialSurf --scramble
EOF

    echo "Stage 11 complete: expert.opts created"

    date
fi

# ============================================================================
# Stage 12: Run autorecon3 up to pial step (will crash by design)
# ============================================================================
# What it does:
#   - Runs autorecon3 with expert.opts
#   - Creates sphere.reg, parcellations, etc.
#   - Crashes before pial placement (due to --scramble flag)
#
# Based on: fs_autorecon3_wrap.sh line 12

if [ ${stage} -le 12 ]; then
    date
    echo "Stage 12: Running autorecon3 (will crash at pial step - this is expected)..."

    export SUBJECTS_DIR="$subjects_dir"

    # This will error out at pial step - that's intentional
    set +e
    recon-all -autorecon3 -subjid "$subject_id" \
              -expert "$subjects_dir/$subject_id/scripts/expert.opts" \
              -openmp "$num_jobs"
    pial_exit_code=$?
    set -e

    if [ $pial_exit_code -ne 0 ]; then
        echo "autorecon3 stopped at pial step as expected (exit code: $pial_exit_code)"
    fi

    echo "Stage 12 complete: autorecon3 partial run complete"

    date
fi

# ============================================================================
# Stage 13: Manual pial surface creation with infant parameters
# ============================================================================
# What it does:
#   - Creates pial surfaces with infant-specific tissue contrast
#   - Uses lower intensity threshold (.3 vs default .5)
#   - Searches outward from white surface (grad_dir 1)
#   - Uses pial_offset .25 for infant anatomy
#   - Uses aseg.presurf (not aseg.auto)
#
# Based on: fs_autorecon3_wrap.sh lines 13-18
# CRITICAL: These parameters are tuned for infant GM/CSF contrast

if [ ${stage} -le 13 ]; then
    date
    echo "Stage 13: Creating pial surfaces with infant parameters..."

    export SUBJECTS_DIR="$subjects_dir"

    echo "INFANT-SPECIFIC PARAMETERS:"
    echo "  -grad_dir 1       : Search outward from white"
    echo "  -intensity .3     : Low GM/CSF contrast threshold (infant-specific)"
    echo "  -pial_offset .25  : Infant pial offset"
    echo "  -cover_seg aseg.presurf.mgz : Use infant segmentation"

    # Left hemisphere
    mris_make_surfaces -grad_dir 1 -intensity .3 \
                       -output .tmp -pial_offset .25 \
                       -nowhite -noaparc \
                       -aseg aseg.presurf \
                       -cover_seg "$subjects_dir/$subject_id/mri/aseg.presurf.mgz" \
                       -orig_pial white \
                       "$subject_id" lh

    # Right hemisphere
    mris_make_surfaces -grad_dir 1 -intensity .3 \
                       -output .tmp -pial_offset .25 \
                       -nowhite -noaparc \
                       -aseg aseg.presurf \
                       -cover_seg "$subjects_dir/$subject_id/mri/aseg.presurf.mgz" \
                       -orig_pial white \
                       "$subject_id" rh

    # Rename to standard names
    cd "$subjects_dir/$subject_id/surf"
    mv lh.pial.tmp lh.pial.T1
    mv rh.pial.tmp rh.pial.T1
    ln -sf lh.pial.T1 lh.pial
    ln -sf rh.pial.T1 rh.pial
    cd -

    echo "Stage 13 complete: Pial surfaces created with infant parameters"

    date
fi

# ============================================================================
# Stage 14: Finish autorecon3 (post-pial steps)
# ============================================================================
# What it does:
#   - Runs remaining autorecon3 steps after pial creation
#   - Calculates cortical thickness
#   - Generates statistics
#   - Creates final parcellations
#
# Based on: fs_autorecon3_wrap.sh line 19

if [ ${stage} -le 14 ]; then
    date
    echo "Stage 14: Finishing autorecon3 (post-pial steps)..."

    export SUBJECTS_DIR="$subjects_dir"

    # Run remaining autorecon3 steps from T2pial onward (but skip T2pial itself)
    recon-all -autorecon3-T2pial -noT2pial -subjid "$subject_id" -openmp "$num_jobs"

    echo "Stage 14 complete: autorecon3 finished"

    date
fi

# ============================================================================
# Stage 15: Quality control
# ============================================================================

if [ ${stage} -le 15 ]; then
    date
    echo "Stage 15: Quality control..."

    log_file="$subjects_dir/$subject_id/scripts/recon-all.log"

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
        if [ -f "$subjects_dir/$subject_id/$file" ]; then
            echo "  ✓ $file"
        else
            echo "  ✗ $file (missing)"
            all_exist=false
        fi
    done

    if [ "$all_exist" = true ]; then
        echo ""
        echo "============================================================================"
        echo "SUCCESS: All key outputs generated!"
        echo "============================================================================"
        echo ""
        echo "View results with:"
        echo "  freeview -v $subjects_dir/$subject_id/mri/T1.mgz \\"
        echo "           -v $subjects_dir/$subject_id/mri/aseg.presurf.mgz:colormap=lut:opacity=0.4 \\"
        echo "           -f $subjects_dir/$subject_id/surf/lh.white:edgecolor=yellow \\"
        echo "           -f $subjects_dir/$subject_id/surf/lh.pial:edgecolor=red \\"
        echo "           -f $subjects_dir/$subject_id/surf/rh.white:edgecolor=yellow \\"
        echo "           -f $subjects_dir/$subject_id/surf/rh.pial:edgecolor=red"
        echo ""
        echo "Key differences from original pipeline:"
        echo "  - iBEAT tissue segmentation NOT used (relies on infant_recon_all only)"
        echo "  - aseg.presurf is directly from infant_recon_all (not merged with iBEAT)"
        echo "  - All other steps match the validated pipeline"
        echo ""
        echo "Note: Results may differ from original pipeline because iBEAT provided"
        echo "      superior cortical tissue classification. Consider testing on a"
        echo "      validation dataset and comparing surface quality."
    else
        echo ""
        echo "ERROR: Some outputs missing. Check logs for errors."
        exit 1
    fi

    date
fi

echo ""
echo "============================================================================"
echo "Pipeline complete!"
echo "Subject: $subject_id"
echo "Age: $age_months months"
echo "Output: $subjects_dir/$subject_id"
echo "============================================================================"
