# FreeSurfer 8.1.0 Infant Processing Pipeline

## Welcome

This directory contains a **complete parallel implementation** of the infant brain processing pipeline using **FreeSurfer 8.1.0**.

This is an **alternative** to the FreeSurfer 7.3 + Infant FreeSurfer pipeline in the parent directory.

## Why FreeSurfer 8.1.0?

### Advantages

✅ **Simpler Installation** - Single FreeSurfer installation (no separate Infant FreeSurfer)
✅ **Easier Configuration** - One system to configure instead of two
✅ **Integrated Workflow** - Infant processing built into FreeSurfer
✅ **No MATLAB Required** - Pure bash/FreeSurfer tools
✅ **No iBEAT2 Required** - Self-contained
✅ **Automatic Label Handling** - No manual thalamus remapping (9→10, 48→49)
✅ **Cleaner File Structure** - Everything in one directory
✅ **Updated Algorithms** - Latest processing methods (2023+)
✅ **Fewer Steps** - 2 commands instead of 10+

### Trade-offs

⚠️ **Different Results** - May differ slightly from original study (updated algorithms)
⚠️ **Not Exact Replication** - Use FS7 version for exact study replication
⚠️ **Newer Software** - Requires FreeSurfer 8.1.0+ (may not be on all systems)

## Quick Start

```bash
# 1. Set up FreeSurfer 8.1.0
export FREESURFER_HOME=/usr/local/freesurfer-8.1.0
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export SUBJECTS_DIR=/data/freesurfer

# 2. Import T1w image (import-only, no auto-processing)
recon-all -i /path/to/T1w.nii.gz -subjid sub-01_ses-03 -noskullstrip

# 3. Create orig.mgz (REQUIRED)
mri_convert $SUBJECTS_DIR/sub-01_ses-03/mri/orig/001.mgz \
            $SUBJECTS_DIR/sub-01_ses-03/mri/orig.mgz

# 4. Run infant processing (20-30 hours)
bash reFS_fs8_infant.sh sub-01_ses-03 6

# 5. Quality control
python detailed_qc_visualization_fs8.py $SUBJECTS_DIR sub-01_ses-03

# Done!
```

## Files in This Directory

| File | Description |
|------|-------------|
| `README.md` | This file |
| `README_FS8_INFANT_PIPELINE.md` | Complete user guide |
| `reFS_fs8_infant.sh` | Main processing script |
| `detailed_qc_visualization_fs8.py` | QC visualization tool |
| `FS7_vs_FS8_COMPARISON.md` | Detailed comparison with FS7 version |

## Documentation

### For Users

**Start Here**: [`README_FS8_INFANT_PIPELINE.md`](README_FS8_INFANT_PIPELINE.md)

Complete guide covering:
- Installation
- Usage
- Output files
- Quality control
- Troubleshooting
- Statistics extraction

### For Developers

**Comparison Guide**: [`FS7_vs_FS8_COMPARISON.md`](FS7_vs_FS8_COMPARISON.md)

Detailed comparison including:
- Installation differences
- Workflow differences
- Algorithm differences
- When to use each version
- Migration strategies

## Requirements

### Software

- **FreeSurfer 8.1.0 or later** (Download: https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall)
- Python 3.6+ with nibabel, numpy, matplotlib (for QC)

### Hardware

- RAM: 8GB minimum, 16GB+ recommended
- Storage: ~5-6GB per subject
- CPU: Multi-core recommended
- Time: ~20-30 hours per subject

## Basic Usage

### Step 1: Install FreeSurfer 8.1.0

```bash
# Download from: https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall

# Extract
tar -xzvpf freesurfer-linux-centos7_x86_64-8.1.0.tar.gz
mv freesurfer /usr/local/freesurfer-8.1.0

# Set up
export FREESURFER_HOME=/usr/local/freesurfer-8.1.0
source $FREESURFER_HOME/SetUpFreeSurfer.sh

# Get free license from: https://surfer.nmr.mgh.harvard.edu/registration.html
export FS_LICENSE=$FREESURFER_HOME/license.txt
```

### Step 2: Process Your Data

```bash
# Set subjects directory
export SUBJECTS_DIR=/data/processed/freesurfer

# Import T1w (import-only, prevents auto-processing errors)
recon-all -i /data/raw/sub-01/anat/T1w.nii.gz -subjid sub-01 -noskullstrip

# Create orig.mgz (REQUIRED for infant_recon_all)
mri_convert $SUBJECTS_DIR/sub-01/mri/orig/001.mgz \
            $SUBJECTS_DIR/sub-01/mri/orig.mgz

# Run pipeline (adjust age in months)
bash reFS_fs8_infant.sh sub-01 6
```

### Step 3: Quality Control

```bash
# Automated QC
python detailed_qc_visualization_fs8.py $SUBJECTS_DIR sub-01

# Visual QC with FreeView
freeview -v $SUBJECTS_DIR/sub-01/mri/T1.mgz \
         -v $SUBJECTS_DIR/sub-01/mri/aseg.mgz:colormap=lut:opacity=0.3 \
         -f $SUBJECTS_DIR/sub-01/surf/lh.white:edgecolor=yellow \
         -f $SUBJECTS_DIR/sub-01/surf/rh.white:edgecolor=yellow \
         -f $SUBJECTS_DIR/sub-01/surf/lh.pial:edgecolor=red \
         -f $SUBJECTS_DIR/sub-01/surf/rh.pial:edgecolor=red
```

## Processing Workflow

FreeSurfer 8.1.0 workflow is much simpler:

```
INPUT: T1w.nii.gz
    ↓
[recon-all -i] → orig.mgz (5 min)
    ↓
[infant_recon_all -age N -all] → Complete processing (20-30 hours)
    ↓
OUTPUT: All standard FreeSurfer outputs
```

Compare to FS7 + iFS (10+ steps):
- Initial FS processing
- Prepare for iFS
- Run iFS
- Remap labels
- Generate WM
- Resume FS processing
- etc...

## Output Files

FreeSurfer 8.1.0 produces standard FreeSurfer outputs:

```
subjects_dir/sub-01/
├── mri/
│   ├── orig.mgz              # Original T1
│   ├── T1.mgz                # Normalized
│   ├── brainmask.mgz         # Brain mask
│   ├── aseg.mgz              # Segmentation (standard FS labels)
│   ├── wm.mgz                # White matter
│   ├── aparc+aseg.mgz        # Parcellation
│   └── wmparc.mgz            # WM parcellation
├── surf/
│   ├── lh.white, rh.white    # White surfaces
│   ├── lh.pial, rh.pial      # Pial surfaces
│   ├── lh.inflated           # Inflated (visualization)
│   ├── lh.thickness          # Cortical thickness
│   └── ...
├── stats/
│   ├── aseg.stats            # Subcortical volumes
│   ├── lh.aparc.stats        # Left cortical stats
│   └── rh.aparc.stats        # Right cortical stats
└── label/
    ├── lh.aparc.annot        # Desikan-Killiany
    └── lh.aparc.a2009s.annot # Destrieux
```

## Label Conventions

### Important: FreeSurfer 8 Uses Standard Labels

Unlike FS7 + Infant FreeSurfer which requires remapping, **FS8 uses standard FreeSurfer labels automatically**:

- **Left Thalamus**: 10 (not 9)
- **Right Thalamus**: 49 (not 48)

**No manual remapping needed!**

All other labels follow standard FreeSurfer conventions.

## Quality Control

### Automated QC Script

```bash
python detailed_qc_visualization_fs8.py <subjects_dir> <subject_id>
```

**Features**:
- Visualizes all intermediate files
- Checks image quality metrics
- Verifies segmentation labels
- Validates surface files
- Generates PNG images for all steps
- Creates JSON QC report
- Automatic error detection

**Output**:
- `qc_detailed_fs8/` directory with:
  - 01_orig.png, 02_nu.png, 03_T1.png, ...
  - Comparison images
  - Overlay visualizations
  - qc_report_fs8.json

### Visual QC

Use FreeSurfer's FreeView:

```bash
# Basic check
freeview -v mri/T1.mgz mri/aseg.mgz:colormap=lut:opacity=0.3

# With surfaces
freeview -v mri/T1.mgz \
         -f surf/lh.white:edgecolor=yellow \
            surf/rh.white:edgecolor=yellow \
            surf/lh.pial:edgecolor=red \
            surf/rh.pial:edgecolor=red
```

## Comparison with FS7 Version

See [`FS7_vs_FS8_COMPARISON.md`](FS7_vs_FS8_COMPARISON.md) for:

- Detailed workflow comparison
- Algorithm differences
- When to use each version
- Migration strategies
- Validation protocols

**Summary**:
- FS8 is **much simpler** (2 steps vs 10+ steps)
- FS8 uses **one directory** instead of two
- FS8 has **automatic label handling**
- Results may differ by **2-5%** (updated algorithms)

## When to Use FS8 vs FS7

### Use FreeSurfer 8.1.0 (This Directory) When:

✅ Starting a new project
✅ Simplicity is important
✅ Don't need exact study replication
✅ Want latest algorithms
✅ Single installation preferred
✅ Teaching/learning

### Use FreeSurfer 7.3 + iFS (Parent Directory) When:

✅ Replicating the original study exactly
✅ Need consistency with existing FS7 data
✅ Published methodology critical
✅ Validation/regulatory requirements

## Batch Processing

Process multiple subjects:

```bash
#!/bin/bash

SUBJECTS_DIR=/data/freesurfer
RAW_DIR=/data/raw

# Subject list with ages
declare -A SUBJECTS
SUBJECTS[sub-01]=6
SUBJECTS[sub-02]=8
SUBJECTS[sub-03]=12

for SUBJ in "${!SUBJECTS[@]}"; do
    AGE=${SUBJECTS[$SUBJ]}

    echo "Processing $SUBJ (age: $AGE months)..."

    # Import (import-only, no auto-processing)
    recon-all -i $RAW_DIR/$SUBJ/anat/${SUBJ}_T1w.nii.gz \
              -subjid $SUBJ \
              -sd $SUBJECTS_DIR \
              -noskullstrip

    # Create orig.mgz (REQUIRED for infant_recon_all)
    mri_convert $SUBJECTS_DIR/$SUBJ/mri/orig/001.mgz \
                $SUBJECTS_DIR/$SUBJ/mri/orig.mgz

    # Process
    bash reFS_fs8_infant.sh $SUBJ $AGE

    # QC
    python detailed_qc_visualization_fs8.py $SUBJECTS_DIR $SUBJ
done
```

## Statistics Extraction

### Subcortical Volumes

```bash
# Single subject
cat stats/aseg.stats

# Multiple subjects
asegstats2table --subjects sub-01 sub-02 sub-03 \
                --meas volume \
                --tablefile aseg_volumes.txt
```

### Cortical Thickness

```bash
aparcstats2table --subjects sub-01 sub-02 sub-03 \
                 --hemi lh \
                 --meas thickness \
                 --tablefile lh_thickness.txt
```

## Troubleshooting

### FreeSurfer 8 Not Found

```bash
# Check version
cat $FREESURFER_HOME/build-stamp.txt

# Should start with "8."
# If not, you may have FS7 environment loaded
```

### infant_recon_all Command Not Found

```bash
# Check if command exists
ls $FREESURFER_HOME/bin/infant_recon_all

# If not found, FreeSurfer 8 not properly installed
```

### Processing Fails

```bash
# Check logs
cat $SUBJECTS_DIR/<subject>/scripts/reFS_fs8_infant.log
cat $SUBJECTS_DIR/<subject>/scripts/recon-all.log

# Common issues:
# - Insufficient memory (need 8GB+)
# - Corrupted input
# - Disk space full
```

## Performance Tips

### Multi-threading

```bash
# Set threads before running
export OMP_NUM_THREADS=8

# Or specify in command
infant_recon_all -s sub-01 -age 6 -all -threads 8
```

### Processing Time

| Hardware | Approximate Time |
|----------|-----------------|
| 8 cores, 16GB RAM | 22-26 hours |
| 16 cores, 32GB RAM | 16-20 hours |
| 32 cores, 64GB RAM | 12-16 hours |

## Additional Resources

### Documentation

- **Main guide**: `README_FS8_INFANT_PIPELINE.md`
- **Comparison**: `FS7_vs_FS8_COMPARISON.md`
- **FreeSurfer 8 docs**: https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurfer8
- **Infant processing**: https://surfer.nmr.mgh.harvard.edu/fswiki/infantFS

### Support

- FreeSurfer mailing list: https://www.mail-archive.com/freesurfer@nmr.mgh.harvard.edu/
- FreeSurfer wiki: https://surfer.nmr.mgh.harvard.edu/fswiki
- Bug reports: https://surfer.nmr.mgh.harvard.edu/fswiki/BugReports

## For Your Data

Based on your file paths:

```bash
# Set up environment
export FREESURFER_HOME=/usr/local/freesurfer-8.1.0
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export SUBJECTS_DIR=/data02/share/bin-wu/data/human/brain/harvard_mri/processed/freesurfer_fs8

# Import your T1w (import-only, no auto-processing)
recon-all \
    -i /data02/share/bin-wu/data/human/brain/harvard_mri/raw/new_england/ds006169-1.0.3/sub-01/ses-03/anat/sub-01_ses-03_T1w.nii.gz \
    -subjid sub-01_ses-03 \
    -sd $SUBJECTS_DIR \
    -noskullstrip

# Create orig.mgz (REQUIRED for infant_recon_all)
mri_convert $SUBJECTS_DIR/sub-01_ses-03/mri/orig/001.mgz \
            $SUBJECTS_DIR/sub-01_ses-03/mri/orig.mgz

# Run processing (adjust age)
bash reFS_fs8_infant.sh sub-01_ses-03 6

# QC
python detailed_qc_visualization_fs8.py $SUBJECTS_DIR sub-01_ses-03
```

## Summary

### Pros

✅ **Much simpler** than FS7 + iFS
✅ **Single installation**
✅ **2 commands** instead of 10+
✅ **Automatic label handling**
✅ **Cleaner file structure**
✅ **Latest algorithms**

### Cons

⚠️ **Not exact replication** of original study
⚠️ **Results may differ** by 2-5%
⚠️ **Newer software** (may not be available everywhere)

### Recommendation

**For most users**: Use FreeSurfer 8.1.0 (this version)

**For exact replication**: Use FreeSurfer 7.3 + iFS (parent directory)

**For validation**: Run both and compare

## License

Same as parent repository.

## Citation

If using FreeSurfer 8.1.0:

```
FreeSurfer. Martinos Center for Biomedical Imaging, Massachusetts General Hospital.
http://surfer.nmr.mgh.harvard.edu/
```

Also cite the original study if extending that work.

---

**Questions?** See the detailed documentation in `README_FS8_INFANT_PIPELINE.md`
