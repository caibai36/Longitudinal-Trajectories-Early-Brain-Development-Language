# FreeSurfer 8.1.0 Infant Processing Pipeline

## Overview

This is a **parallel implementation** of the infant brain processing pipeline using **FreeSurfer 8.1.0's integrated infant processing capabilities**.

### Key Advantages over FreeSurfer 7.3 + Infant FreeSurfer

| Feature | FreeSurfer 7.3 + iFS | FreeSurfer 8.1.0 |
|---------|---------------------|------------------|
| **Installation** | 2 separate installations | Single installation |
| **Configuration** | Complex (2 systems) | Simple (1 system) |
| **Infant Processing** | Separate `infant_recon_all` | Integrated with `-age` flag |
| **MATLAB Required** | ❌ No (with bash version) | ❌ No |
| **iBEAT2 Required** | ❌ No (with iFS-only) | ❌ No |
| **Label Remapping** | Manual (9→10, 48→49) | Automatic |
| **Setup Complexity** | High | Low |
| **Processing Time** | ~20-30 hours | ~20-30 hours |
| **Output Format** | Standard FS format | Standard FS format |
| **Algorithm Version** | Older | Updated |

## Requirements

### Software

- **FreeSurfer 8.1.0 or later** (Download: https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall)
- **NO** separate Infant FreeSurfer installation needed
- **NO** MATLAB needed
- **NO** iBEAT2 needed

### System

- **RAM**: Minimum 8GB, recommended 16GB+
- **Storage**: ~5GB per subject
- **CPU**: Multi-core recommended
- **Time**: 20-30 hours per subject

## Installation

### 1. Install FreeSurfer 8.1.0

```bash
# Download FreeSurfer 8.1.0 from:
# https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall

# Extract and set up
tar -xzvf freesurfer-linux-centos7_x86_64-8.1.0.tar.gz
mv freesurfer /usr/local/freesurfer-8.1.0

# Set up environment
export FREESURFER_HOME=/usr/local/freesurfer-8.1.0
source $FREESURFER_HOME/SetUpFreeSurfer.sh

# Set license
export FS_LICENSE=$FREESURFER_HOME/license.txt
# (Get free license from: https://surfer.nmr.mgh.harvard.edu/registration.html)
```

### 2. Verify Installation

```bash
# Check version
freesurfer --version
# Should output: freesurfer-linux-centos7_x86_64-8.1.0-20230830-e5f9ce8

# Check infant_recon_all is available
which infant_recon_all
# Should output path to command
```

### 3. Set Up Environment (Add to ~/.bashrc)

```bash
# Add to ~/.bashrc for permanent setup
export FREESURFER_HOME=/usr/local/freesurfer-8.1.0
export FS_LICENSE=$FREESURFER_HOME/license.txt
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export SUBJECTS_DIR=/path/to/your/subjects
```

## Usage

### Quick Start

```bash
# 1. Set environment
export SUBJECTS_DIR=/data02/share/bin-wu/data/human/brain/harvard_mri/processed/freesurfer_fs8

# 2. Import T1w image
recon-all \
    -i /data02/share/bin-wu/data/human/brain/harvard_mri/raw/new_england/ds006169-1.0.3/sub-01/ses-03/anat/sub-01_ses-03_T1w.nii.gz \
    -subjid sub-01_ses-03

# 3. Run infant processing (age in months)
bash reFS_fs8_infant.sh sub-01_ses-03 6

# That's it! Much simpler than FS7 version.
```

### Detailed Steps

#### Step 1: Import T1w Image

```bash
recon-all -i <path_to_T1w.nii.gz> -subjid <subject_id>
```

**Example**:
```bash
recon-all \
    -i /data/raw/sub-01/ses-03/anat/sub-01_ses-03_T1w.nii.gz \
    -subjid sub-01_ses-03 \
    -sd /data/processed/freesurfer
```

This creates the subject directory and converts the T1w to FreeSurfer format (`orig.mgz`).

#### Step 2: Run Infant Processing

```bash
bash reFS_fs8_infant.sh <subject_id> <age_in_months>
```

**Example**:
```bash
bash reFS_fs8_infant.sh sub-01_ses-03 6
```

**Age Guidelines**:
- Use actual age in months
- Range: 0-24 months (infant-optimized)
- For older children, use standard `recon-all -all`

#### Step 3: Quality Control

```bash
# Visual QC with FreeView
freeview -v $SUBJECTS_DIR/sub-01_ses-03/mri/T1.mgz \
         -v $SUBJECTS_DIR/sub-01_ses-03/mri/aseg.mgz:colormap=lut:opacity=0.3 \
         -f $SUBJECTS_DIR/sub-01_ses-03/surf/lh.white:edgecolor=yellow \
         -f $SUBJECTS_DIR/sub-01_ses-03/surf/rh.white:edgecolor=yellow \
         -f $SUBJECTS_DIR/sub-01_ses-03/surf/lh.pial:edgecolor=red \
         -f $SUBJECTS_DIR/sub-01_ses-03/surf/rh.pial:edgecolor=red

# Automated QC
python detailed_qc_visualization_fs8.py $SUBJECTS_DIR sub-01_ses-03
```

## What's Different from FS7 Version?

### Simplified Workflow

**FreeSurfer 7.3 + Infant FreeSurfer:**
```bash
# 1. Initial FS processing
recon-all -all -subjid sub-01 -nonuintensitycor

# 2. Prepare for iFS
mri_convert -i FS/mri/orig.mgz -o iFS/mprage.nii.gz

# 3. Run iFS
infant_recon_all --s sub-01 --age 6

# 4. Copy and remap labels (MATLAB or bash)
mri_convert -i iFS/mri/aseg.mgz -o FS/mri/aseg.presurf.mgz
# Remap thalamus: 9→10, 48→49 (manual step)
mri_binarize --i aseg.mgz --match 9 --replace 10 ...

# 5. Generate WM file (MATLAB or bash)
mri_binarize --i aseg.mgz --match 2 41 173 174 175 --replace 110 ...

# 6. Continue FS processing
fs_autorecon2_end.sh
fs_autorecon3_wrap.sh
```

**FreeSurfer 8.1.0:**
```bash
# 1. Import
recon-all -i T1w.nii.gz -subjid sub-01

# 2. Run infant processing (DONE!)
infant_recon_all -s sub-01 -age 6 -all
```

### Technical Differences

| Aspect | FS7 + iFS | FS8 |
|--------|-----------|-----|
| **Command** | Separate `infant_recon_all` | Integrated `infant_recon_all` |
| **Age Specification** | `--age <months>` | `-age <months>` |
| **Segmentation** | Separate iFS aseg | Integrated aseg |
| **Label Conventions** | iFS labels (need remapping) | FS labels (automatic) |
| **Atlas** | Infant-specific (external) | Infant-specific (built-in) |
| **WM Generation** | Manual script | Automatic |
| **Surface Finding** | Custom scripts | Standard pipeline |

### File Structure Differences

**FreeSurfer 7.3 + iFS:**
```
/subjects_dir/
├── sub-01/              # Standard FreeSurfer
│   └── mri/
│       ├── orig.mgz
│       ├── aseg.presurf.mgz  # From iFS (remapped)
│       └── wm.mgz            # Generated manually
└── ../iFS/
    └── sub-01/          # Infant FreeSurfer
        └── mri/
            └── aseg.mgz      # iFS labels (9, 48)
```

**FreeSurfer 8.1.0:**
```
/subjects_dir/
└── sub-01/              # Everything in one place
    └── mri/
        ├── orig.mgz
        ├── aseg.mgz     # Standard FS labels (10, 49)
        └── wm.mgz       # Generated automatically
```

## Output Files

FreeSurfer 8.1.0 produces standard FreeSurfer output structure:

### MRI Volumes

```
mri/
├── orig.mgz                  # Original T1w
├── rawavg.mgz               # Motion-corrected average
├── nu.mgz                   # Bias-corrected
├── T1.mgz                   # Normalized T1
├── brainmask.mgz            # Skull-stripped brain
├── norm.mgz                 # Atlas-normalized
├── aseg.mgz                 # Subcortical segmentation
├── aseg.presurf.mgz         # Pre-surface segmentation
├── brain.mgz                # Normalized brain
├── wm.mgz                   # White matter
├── filled.mgz               # Filled WM (for surfaces)
├── aparc+aseg.mgz           # Cortical + subcortical parcellation
└── wmparc.mgz               # WM parcellation
```

### Surfaces

```
surf/
├── lh.orig                  # Original surface
├── lh.white                 # White matter surface
├── lh.pial                  # Pial surface
├── lh.inflated              # Inflated (for visualization)
├── lh.sphere                # Spherical mapping
├── lh.curv                  # Curvature
├── lh.thickness             # Cortical thickness
├── lh.area                  # Surface area
└── rh.*                     # Right hemisphere (same files)
```

### Statistics

```
stats/
├── aseg.stats               # Subcortical volumes
├── lh.aparc.stats           # Left cortical parcellation
├── rh.aparc.stats           # Right cortical parcellation
├── lh.aparc.a2009s.stats    # Destrieux atlas
└── rh.aparc.a2009s.stats    # Destrieux atlas
```

### Label Files

```
label/
├── lh.aparc.annot           # Desikan-Killiany parcellation
├── lh.aparc.a2009s.annot    # Destrieux parcellation
├── lh.cortex.label          # Cortex mask
└── rh.*                     # Right hemisphere
```

## Label Conventions

### FreeSurfer 8.1.0 Uses Standard Labels

Unlike FS7 + iFS which needs remapping, FS8 uses standard FreeSurfer labels directly:

**Thalamus**:
- Left: **10** (not 9)
- Right: **49** (not 48)

**No manual remapping needed!**

### Key Labels

| Value | Structure |
|-------|-----------|
| 0 | Unknown/Background |
| 2 | Left Cerebral White Matter |
| 3 | Left Cerebral Cortex |
| 4 | Left Lateral Ventricle |
| 5 | Left Inf Lat Vent |
| 7 | Left Cerebellum White Matter |
| 8 | Left Cerebellum Cortex |
| 10 | Left Thalamus |
| 11 | Left Caudate |
| 12 | Left Putamen |
| 13 | Left Pallidum |
| 14 | 3rd Ventricle |
| 15 | 4th Ventricle |
| 16 | Brain-Stem |
| 17 | Left Hippocampus |
| 18 | Left Amygdala |
| 24 | CSF |
| 26 | Left Accumbens area |
| 28 | Left VentralDC |
| 41-60 | Right hemisphere (same as left + 39) |

## Quality Control

### Automated QC Script

Use the FS8-specific QC script:

```bash
python detailed_qc_visualization_fs8.py <subjects_dir> <subject_id> [--output <qc_dir>]
```

**Example**:
```bash
python detailed_qc_visualization_fs8.py \
    /data/freesurfer \
    sub-01_ses-03 \
    --output /data/qc/sub-01_ses-03
```

This generates:
- PNG images for all intermediate files
- Quality metrics
- Pass/warning/error status
- JSON QC report

### Visual QC with FreeView

```bash
# Basic view
freeview -v mri/T1.mgz mri/aseg.mgz:colormap=lut:opacity=0.3

# With surfaces
freeview -v mri/T1.mgz \
         -f surf/lh.white:edgecolor=yellow \
            surf/rh.white:edgecolor=yellow \
            surf/lh.pial:edgecolor=red \
            surf/rh.pial:edgecolor=red

# Check brain mask
freeview -v mri/T1.mgz mri/brainmask.mgz:colormap=heat:opacity=0.3
```

### Key QC Checks

1. **Brain Mask** (`brainmask.mgz`):
   - [ ] All skull removed
   - [ ] Cerebellum included
   - [ ] No brain tissue removed
   - [ ] Volume reasonable (400-1200ml for infants)

2. **Segmentation** (`aseg.mgz`):
   - [ ] GM/WM boundary accurate
   - [ ] Subcortical structures present
   - [ ] Left/right symmetric
   - [ ] No obvious errors

3. **White Surface** (`lh/rh.white`):
   - [ ] Follows GM/WM boundary
   - [ ] Euler number = 2 (no topology defects)
   - [ ] Smooth surface
   - [ ] Complete coverage

4. **Pial Surface** (`lh/rh.pial`):
   - [ ] Follows GM/CSF boundary
   - [ ] Outside white surface everywhere
   - [ ] Captures sulci
   - [ ] No dura included

## Troubleshooting

### FreeSurfer 8 Not Found

```bash
# Check installation
ls $FREESURFER_HOME/bin/infant_recon_all

# If not found, reinstall FreeSurfer 8.1.0
# or check that you're sourcing the correct version
```

### License Error

```bash
# FreeSurfer requires a license file
# Get free license from: https://surfer.nmr.mgh.harvard.edu/registration.html

# Set license path
export FS_LICENSE=/path/to/license.txt

# Or place license.txt in $FREESURFER_HOME/
```

### Processing Fails

```bash
# Check log file
cat $SUBJECTS_DIR/<subject>/scripts/reFS_fs8_infant.log

# Check recon-all.log
cat $SUBJECTS_DIR/<subject>/scripts/recon-all.log

# Common issues:
# - Insufficient memory (need 8GB+)
# - Corrupted input image
# - Disk space full
```

### Poor Segmentation

```bash
# Check input image quality
freeview -v mri/orig.mgz

# If image quality is poor:
# - Check for motion artifacts
# - Check contrast (infant brains have low WM/GM contrast)
# - May need to adjust processing parameters
```

## Performance Optimization

### Multi-threading

FreeSurfer 8 supports multi-threading:

```bash
# Set number of threads (before running)
export OMP_NUM_THREADS=8

# Or specify in command
infant_recon_all -s sub-01 -age 6 -all -threads 8
```

### GPU Acceleration

Some FS8 operations can use GPU:

```bash
# Check if GPU available
nvidia-smi

# FreeSurfer will automatically use GPU if available
# for certain operations (e.g., image registration)
```

## Batch Processing

### Process Multiple Subjects

```bash
#!/bin/bash

SUBJECTS_DIR=/data/freesurfer
INPUT_DIR=/data/raw

# List of subjects and ages
declare -A SUBJECTS
SUBJECTS[sub-01_ses-03]=6
SUBJECTS[sub-02_ses-03]=8
SUBJECTS[sub-03_ses-03]=12

# Process each subject
for SUBJ in "${!SUBJECTS[@]}"; do
    AGE=${SUBJECTS[$SUBJ]}

    echo "Processing $SUBJ (age: $AGE months)..."

    # Import
    recon-all -i $INPUT_DIR/$SUBJ/anat/${SUBJ}_T1w.nii.gz \
              -subjid $SUBJ \
              -sd $SUBJECTS_DIR

    # Run infant processing
    bash reFS_fs8_infant.sh $SUBJ $AGE

    # QC
    python detailed_qc_visualization_fs8.py $SUBJECTS_DIR $SUBJ
done
```

## Extracting Statistics

### Subcortical Volumes

```bash
# Single subject
cat stats/aseg.stats

# Multiple subjects to table
asegstats2table --subjects sub-01 sub-02 sub-03 \
                --meas volume \
                --tablefile aseg_volumes.txt
```

### Cortical Thickness

```bash
# Single subject
cat stats/lh.aparc.stats

# Multiple subjects to table
aparcstats2table --subjects sub-01 sub-02 sub-03 \
                 --hemi lh \
                 --meas thickness \
                 --tablefile lh_thickness.txt
```

### Surface Area

```bash
aparcstats2table --subjects sub-01 sub-02 sub-03 \
                 --hemi lh \
                 --meas area \
                 --tablefile lh_area.txt
```

## Comparison with Original Study

The original study used FreeSurfer 7.3 + Infant FreeSurfer + iBEAT2.

### If Using FS8 for Replication:

**Important Notes**:
1. ✅ **Pros**: Simpler setup, single installation
2. ⚠️ **Cons**: Results may differ slightly from original study
3. 📊 **Recommendation**: Run both versions if exact replication needed

### Differences to Expect:

- **Slight volume differences**: Updated algorithms may give slightly different volumes
- **Thickness differences**: May vary by ~0.1-0.2mm
- **Surface accuracy**: May be better in FS8 (newer methods)
- **Processing time**: Similar (~20-30 hours)

### Validation:

If you need to validate FS8 results against original pipeline:
1. Process a few subjects with both pipelines
2. Compare key metrics (volumes, thickness)
3. Check correlation (should be >0.95)
4. Document any systematic differences

## Migration from FS7 to FS8

### Can I Use Both?

Yes! Keep both versions for comparison:

```bash
# FreeSurfer 7.3
export FREESURFER_HOME=/usr/local/freesurfer-7.3
export SUBJECTS_DIR=/data/freesurfer7

# FreeSurfer 8.1.0
export FREESURFER_HOME=/usr/local/freesurfer-8.1.0
export SUBJECTS_DIR=/data/freesurfer8
```

### Processing Same Subject with Both:

```bash
# Process with FS7
export FREESURFER_HOME=/usr/local/freesurfer-7.3
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export SUBJECTS_DIR=/data/freesurfer7
bash reFS_iFS_only_no_matlab.sh sub-01_ses-03 6

# Process with FS8
export FREESURFER_HOME=/usr/local/freesurfer-8.1.0
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export SUBJECTS_DIR=/data/freesurfer8
bash reFS_fs8_infant.sh sub-01_ses-03 6

# Compare results
python compare_fs7_vs_fs8.py sub-01_ses-03
```

## Additional Resources

### FreeSurfer 8 Documentation
- Main docs: https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurfer8
- Infant processing: https://surfer.nmr.mgh.harvard.edu/fswiki/infantFS
- Release notes: https://surfer.nmr.mgh.harvard.edu/fswiki/ReleaseNotes

### Support
- FreeSurfer mailing list: https://www.mail-archive.com/freesurfer@nmr.mgh.harvard.edu/
- Report bugs: https://surfer.nmr.mgh.harvard.edu/fswiki/BugReports

### Citation

If using FreeSurfer 8.1.0, cite:
```
FreeSurfer. Martinos Center for Biomedical Imaging, Massachusetts General Hospital.
http://surfer.nmr.mgh.harvard.edu/
```

## Summary

### FreeSurfer 8.1.0 Advantages:
✅ Single installation (no separate iFS)
✅ Simpler configuration
✅ Integrated infant processing
✅ No manual label remapping
✅ No MATLAB or iBEAT2 needed
✅ Updated algorithms

### When to Use FS8:
- ✅ New studies/projects
- ✅ Simpler workflow preferred
- ✅ No need for exact replication of original study

### When to Use FS7 + iFS:
- ✅ Exact replication of original study
- ✅ Consistency with existing processed data
- ✅ Specific validation requirements

### Recommendation:
- **New users**: Start with FreeSurfer 8.1.0
- **Replicating original study**: Use FreeSurfer 7.3 + iFS
- **Research**: Consider processing with both and comparing

