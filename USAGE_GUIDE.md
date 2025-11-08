# Usage Guide: Infant FreeSurfer Without iBEAT

## Quick Answer: YES, You Can Use Existing Scripts Directly!

You can use the existing validated scripts (`fs_autorecon2_end.sh` and `fs_autorecon3_wrap.sh`) directly by:
1. Preparing `aseg.presurf.mgz` from infant_recon_all output
2. Creating `wm.mgz` with proper labels (110/250)
3. Calling the existing scripts

## Option 1: Use the Simple Wrapper Script (RECOMMENDED)

The wrapper script `run_infant_fs_no_ibeat.sh` automates everything for you.

### Usage:

```bash
# Make executable
chmod +x run_infant_fs_no_ibeat.sh

# Run from repository root
./run_infant_fs_no_ibeat.sh [options] <subject_id> <age_months> [raw_t1w_path]
```

### Examples:

```bash
# Start from scratch with raw T1w (positional arguments)
./run_infant_fs_no_ibeat.sh sub-01_ses-03 18 /path/to/T1w.nii.gz

# Or if you already ran recon-all, just provide subject ID and age
export SUBJECTS_DIR=/path/to/freesurfer_output
./run_infant_fs_no_ibeat.sh sub-01_ses-03 18

# Using named arguments (Kaldi style)
./run_infant_fs_no_ibeat.sh \
  --subject_id sub-01_ses-03 \
  --age_months 18 \
  --raw_t1w /path/to/T1w.nii.gz \
  --subjects_dir /path/to/output \
  --num_jobs 30

# Resume from stage 5 (if processing interrupted)
./run_infant_fs_no_ibeat.sh --stage 5 sub-01_ses-03 18

# Run only stages 0-3 (for testing)
./run_infant_fs_no_ibeat.sh --stage 0 --stop_stage 3 sub-01_ses-03 18 /path/to/T1w.nii.gz
```

### Options:

- `--stage <N>` - Start from stage N (default: 0)
- `--stop_stage <N>` - Stop at stage N (default: 100)
- `--subject_id <str>` - Subject ID
- `--age_months <N>` - Age in months (0-24)
- `--raw_t1w <path>` - Path to raw T1w image
- `--subjects_dir <path>` - FreeSurfer SUBJECTS_DIR
- `--ifs_dir <path>` - Infant FreeSurfer output directory
- `--num_jobs <N>` - Number of parallel jobs (default: 30)

### What it does:

- **Stage 0**: Runs `recon-all -all -nonuintensitycor` (if raw T1w provided)
- **Stage 1**: Cleans up adult files (removes transforms, orig_nu.mgz)
- **Stage 2**: Runs `infant_recon_all --s <subject> --age <months>`
- **Stage 3**: Creates `aseg.presurf.mgz` from iFS aseg (fixes thalamus labels 9→10, 48→49)
- **Stage 4**: Creates `wm.mgz` with labels 110 (WM) and 250 (subcortical GM)
- **Stage 5**: Calls `fs_autorecon2_end.sh` (white surface reconstruction)
- **Stage 6**: Calls `fs_autorecon3_wrap.sh` (pial surfaces and statistics)
- **Stage 7**: Quality control checks

### Directory structure expected:

```
/your/base/directory/
├── freesurfer_output/          # Standard FreeSurfer SUBJECTS_DIR
│   └── sub-01_ses-03/
│       ├── mri/
│       ├── surf/
│       └── ...
└── iFS/                        # Infant FreeSurfer output
    └── sub-01_ses-03/
        └── mri/
            ├── aseg.mgz
            ├── brainmask.mgz
            └── transforms/
```

---

## Option 2: Manual Step-by-Step (If You Want Full Control)

If you prefer to run each step manually:

### Step 1: Initial FreeSurfer Processing

```bash
export SUBJECTS_DIR=/path/to/freesurfer_output
recon-all -i /path/to/T1w.nii.gz -subjid sub-01_ses-03 -all -nonuintensitycor
```

### Step 2: Clean Up Adult Files

```bash
cd $SUBJECTS_DIR/sub-01_ses-03/mri
rm -f transforms/* orig_nu.mgz mri_nu_correct.mni.log
```

### Step 3: Run Infant FreeSurfer

```bash
# Setup for infant_recon_all
IFS_DIR=/path/to/iFS
mkdir -p $IFS_DIR/sub-01_ses-03
mri_convert -i $SUBJECTS_DIR/sub-01_ses-03/mri/orig.mgz \
            -o $IFS_DIR/sub-01_ses-03/mprage.nii.gz

# Run infant_recon_all
export SUBJECTS_DIR=$IFS_DIR
infant_recon_all --s sub-01_ses-03 --age 18
```

### Step 4: Create aseg.presurf.mgz (Replaces ibeat2aseg.m)

```bash
# Copy infant aseg to FreeSurfer directory
mri_convert -i $IFS_DIR/sub-01_ses-03/mri/aseg.mgz \
            -o $SUBJECTS_DIR/sub-01_ses-03/mri/aseg.presurf.nii

# Fix thalamus labels (9→10, 48→49)
mri_binarize --i $SUBJECTS_DIR/sub-01_ses-03/mri/aseg.presurf.nii \
             --replace 9 10 --replace 48 49 \
             --o $SUBJECTS_DIR/sub-01_ses-03/mri/aseg.presurf.nii

# Convert to .mgz
mri_convert -i $SUBJECTS_DIR/sub-01_ses-03/mri/aseg.presurf.nii \
            -o $SUBJECTS_DIR/sub-01_ses-03/mri/aseg.presurf.mgz
```

### Step 5: Create wm.mgz (Replaces aseg2wm.m)

```bash
cd $SUBJECTS_DIR/sub-01_ses-03/mri

# Create base
mri_binarize --i aseg.presurf.mgz --min 0 --max 0 --o wm_base.mgz

# White matter (2,41,173-175) → label 110
mri_binarize --i aseg.presurf.mgz --match 2 41 173 174 175 --o wm_110_mask.mgz
mri_mask -transfer 110 wm_110_mask.mgz wm_base.mgz wm_temp.mgz

# Subcortical GM (4,11,12,13,26,28,43,50,51,52,58,60) → label 250
mri_binarize --i aseg.presurf.mgz --match 4 11 12 13 26 28 43 50 51 52 58 60 --o gm_250_mask.mgz
mri_mask -transfer 250 gm_250_mask.mgz wm_temp.mgz wm.mgz

# Cleanup
rm -f wm_base.mgz wm_110_mask.mgz gm_250_mask.mgz wm_temp.mgz
```

### Step 6: Copy Transforms and Run Autorecon2

```bash
# Copy infant transforms
cp $IFS_DIR/sub-01_ses-03/mri/transforms/talairach*.xfm \
   $SUBJECTS_DIR/sub-01_ses-03/mri/transforms/

# Run validated autorecon2 script
export SUBJECTS_DIR=$SUBJECTS_DIR
cd /path/to/Longitudinal-Trajectories-Early-Brain-Development-Language
./peer-review/1.Structure/fs_autorecon2_end.sh \
    $SUBJECTS_DIR/sub-01_ses-03 \
    $IFS_DIR/sub-01_ses-03 \
    sub-01_ses-03
```

### Step 7: Run Autorecon3

```bash
export SUBJECTS_DIR=$SUBJECTS_DIR
cd /path/to/Longitudinal-Trajectories-Early-Brain-Development-Language
./peer-review/1.Structure/fs_autorecon3_wrap.sh \
    $SUBJECTS_DIR/sub-01_ses-03 \
    $(pwd)/peer-review/1.Structure \
    sub-01_ses-03
```

---

## What Gets Replaced Without iBEAT?

| Original Pipeline | Without iBEAT |
|------------------|---------------|
| **ibeat2aseg.m** | Just copy iFS aseg → aseg.presurf (with thalamus label fixes) |
| **aseg2wm.m** | Use `mri_binarize` + `mri_mask` to create wm.mgz |
| **Everything else** | **Identical - use existing scripts unchanged!** |

## Key Files Required Before Running Existing Scripts

The existing scripts expect these files to exist:

✅ **In FreeSurfer directory** (`$SUBJECTS_DIR/<subject>/mri/`):
- `aseg.presurf.mgz` - Created in Step 4 above
- `wm.mgz` - Created in Step 5 above
- `orig.mgz` - Already exists from initial recon-all
- `nu.mgz` - Already exists from initial recon-all

✅ **In Infant FS directory** (`$IFS_DIR/<subject>/mri/`):
- `brainmask.mgz` - Created by infant_recon_all
- `aseg.mgz` - Created by infant_recon_all
- `transforms/talairach*.xfm` - Created by infant_recon_all

## Label Definitions for wm.mgz

Based on `aseg2wm.m`:

**Label 110 (White Matter):**
- 2 = Left cerebral white matter
- 41 = Right cerebral white matter
- 173, 174, 175 = Brainstem/vermis

**Label 250 (Subcortical Gray Matter):**
- 4, 43 = Lateral ventricles
- 11, 50 = Caudate
- 12, 51 = Putamen
- 13, 52 = Pallidum
- 26, 58 = Accumbens
- 28, 60 = Ventral DC

*Note: Thalamus (10/49) is NOT included in wm.mgz (per Natu et al. 2021)*

## Validation

After running, check:

```bash
# View surfaces
freeview -v $SUBJECTS_DIR/sub-01_ses-03/mri/T1.mgz \
         -v $SUBJECTS_DIR/sub-01_ses-03/mri/aseg.presurf.mgz:colormap=lut:opacity=0.4 \
         -f $SUBJECTS_DIR/sub-01_ses-03/surf/lh.white:edgecolor=yellow \
         -f $SUBJECTS_DIR/sub-01_ses-03/surf/lh.pial:edgecolor=red \
         -f $SUBJECTS_DIR/sub-01_ses-03/surf/rh.white:edgecolor=yellow \
         -f $SUBJECTS_DIR/sub-01_ses-03/surf/rh.pial:edgecolor=red

# Check for errors
grep -i error $SUBJECTS_DIR/sub-01_ses-03/scripts/recon-all.log

# Check required outputs exist
ls $SUBJECTS_DIR/sub-01_ses-03/surf/{lh,rh}.{white,pial,thickness}
ls $SUBJECTS_DIR/sub-01_ses-03/stats/{aseg,lh.aparc,rh.aparc}.stats
```

## Advantages of This Approach

✅ **Reuses validated code** - No need to rewrite 40+ manual FreeSurfer commands
✅ **Same parameters** - Uses identical infant-specific settings from published pipeline
✅ **No MATLAB** - Simple bash replacements for the two MATLAB scripts
✅ **No iBEAT Docker** - One less dependency
✅ **Well-tested** - fs_autorecon2_end.sh and fs_autorecon3_wrap.sh are already validated

## Trade-offs

⚠️ **Less accurate cortical segmentation** - iBEAT provided superior GM/WM tissue boundaries
⚠️ **May affect cortical surfaces** - Particularly in low-contrast regions
⚠️ **Needs validation** - Compare results to original pipeline on test dataset

---

## Troubleshooting

**Error: "Cannot find fs_autorecon2_end.sh"**
- Make sure you're running from the repository root
- Check that `peer-review/1.Structure/` directory exists

**Error: "infant_recon_all: command not found"**
- Set up Infant FreeSurfer environment first
- Source the appropriate FreeSurfer setup script

**Error: Missing brainmask.mgz or transforms**
- Ensure infant_recon_all completed successfully
- Check `$IFS_DIR/<subject>/mri/` directory

**Surfaces look wrong**
- Visually inspect in FreeView
- Compare to original pipeline results
- May need iBEAT for better tissue segmentation

---

## Summary

**YES, you can use the existing scripts directly!**

The two MATLAB scripts (`ibeat2aseg.m` and `aseg2wm.m`) are easily replaced with bash commands. Everything else in `fs_autorecon2_end.sh` and `fs_autorecon3_wrap.sh` works identically without modification.

**Simplest approach:** Use the wrapper script `run_infant_fs_no_ibeat.sh`

**Most control:** Follow the manual step-by-step instructions above
