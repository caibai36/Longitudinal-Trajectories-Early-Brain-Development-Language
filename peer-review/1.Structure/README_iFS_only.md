# Infant FreeSurfer-Only Pipeline

## Overview

This is a **modified version** of the original structural brain processing pipeline that uses **only Infant FreeSurfer (iFS)** and standard FreeSurfer, eliminating the iBEAT2 dependency.

### Important Notes

⚠️ **Trade-offs**: This simplified pipeline may produce different results compared to the original hybrid iBEAT2/iFS approach. The original pipeline combined:
- iBEAT2 for superior cortical tissue segmentation
- iFS for better subcortical structure segmentation

This version relies entirely on iFS segmentation, which may be less optimal for cortical gray/white matter boundaries in very young infants.

## Pipeline Structure

```
.
├── reFS_iFS_only.sh                        <-- runs infant brain morphometry pipeline (iFS-only version)
    ├── iFS_wrap.sh                         <-- sets environmental variables for iFS and runs it
    ├── iFS_aseg_process.m                  <-- processes iFS aseg for FS compatibility (thalamus labels)
    ├── aseg2wm_iFS.m                       <-- generates FS white matter file using iFS segmentation
    ├── fs_autorecon2_end.sh                <-- runs FS autorecon2 with adjustments
    ├── fs_autorecon3_wrap.sh               <-- runs FS autorecon3 with adjustments (uses expert.opts)
```

## Dependencies

- Infant FreeSurfer
- FreeSurfer 7.3 or later
- MATLAB (for processing scripts)

**Removed dependency**: iBEAT2.0 Docker is NO LONGER REQUIRED

---

## ⭐ Even Simpler Alternative: No MATLAB Version

If you want to avoid MATLAB entirely, see **`README_simplified_pipeline.md`** for a pure bash/FreeSurfer version:
- Script: `reFS_iFS_only_no_matlab.sh`
- **No iBEAT2, No MATLAB** - only FreeSurfer command-line tools
- Same functionality, much simpler dependencies

---

## Usage

```bash
reFS_iFS_only.sh <subject_id> <age_in_months>
```

### Parameters
- `subject_id`: Subject identifier (should match directory name in SUBJECTS_DIR)
- `age_in_months`: Subject age in months (required for iFS processing)

### Example
```bash
export SUBJECTS_DIR=/path/to/freesurfer/subjects
reFS_iFS_only.sh sub-001 6
```

## Requirements

1. **Environment Setup**:
   - The folder containing these scripts must be added to your shell PATH
   - FreeSurfer environment variables must be properly configured
   - SUBJECTS_DIR must be set

2. **Input Data**:
   - T1-weighted MRI image must be imported into FreeSurfer format
   - Image should be named `orig.mgz` in `${SUBJECTS_DIR}/${subject_id}/mri/`

3. **iFS Configuration**:
   - The `iFS_wrap.sh` script needs to be adjusted based on your compute setup
   - Ensure proper paths to Infant FreeSurfer installation

## Key Modifications from Original Pipeline

### What Changed:
1. **Removed**: iBEAT2 tissue segmentation requirement
2. **Removed**: `ibeat2aseg.m` (iBEAT2/iFS merger script)
3. **Added**: `iFS_aseg_process.m` (simplified iFS aseg processing)
4. **Modified**: White matter generation now uses only iFS segmentation
5. **Simplified**: Input requirements (only subject ID and age needed)

### What Stayed the Same:
1. Overall pipeline structure and workflow
2. FreeSurfer autorecon2 and autorecon3 processing steps
3. Final output format and metrics
4. Use of iFS for initial segmentation

## Processing Steps

1. **Initial FreeSurfer Processing**: Runs standard FreeSurfer recon-all to completion
2. **Cleanup**: Removes transform files and intermediate outputs
3. **iFS Setup**: Converts FreeSurfer orig.mgz to format needed by iFS
4. **iFS Processing**: Runs Infant FreeSurfer for age-appropriate segmentation
5. **Label Adjustment**: Converts iFS thalamus labels (9, 48) to FS convention (10, 49)
6. **WM Generation**: Creates white matter file from iFS segmentation
7. **FS Integration**: Resumes FreeSurfer processing using iFS-derived files
8. **Surface Reconstruction**: Completes cortical surface reconstruction with adjustments

## Output

The pipeline produces standard FreeSurfer output in `${SUBJECTS_DIR}/${subject_id}/`, including:
- Cortical surface reconstructions
- Volumetric segmentations
- Morphometric measurements (thickness, area, volume)
- Statistics files (can be consolidated with `consol_stats.sh`)

## Validation

⚠️ **Important**: This modified pipeline has not been validated against the original hybrid approach. If you use this pipeline for research, consider:

1. Comparing results with a subset processed using the original pipeline
2. Quality checking segmentations visually (especially for infants < 6 months)
3. Noting in your methods that you used an iFS-only approach

## Troubleshooting

### Common Issues:

1. **iFS fails to run**:
   - Check that age parameter is reasonable (typically 0-24 months for iFS)
   - Verify iFS installation and environment variables in `iFS_wrap.sh`

2. **MATLAB scripts fail**:
   - Ensure scripts are in your PATH or MATLAB path
   - Check that you have Image Processing Toolbox installed

3. **Surface reconstruction errors**:
   - May indicate poor initial segmentation
   - Consider manual edits to `aseg.presurf.mgz` before continuing

## Citation

If you use this pipeline, please cite the original study and note the modification:

```
Original study: Turesky et al. Longitudinal trajectories of brain development
from infancy to school age and their relationship to literacy development

Modified pipeline: iFS-only version (removed iBEAT2 dependency)
```

## Contact

For questions about the original pipeline: theodore_turesky@gse.harvard.edu

For questions about this modification: [Add your contact information]
