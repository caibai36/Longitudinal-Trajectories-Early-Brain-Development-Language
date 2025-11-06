# Simplified Infant FreeSurfer Pipeline (No iBEAT2, No MATLAB)

## Overview

This is a **fully simplified version** of the structural brain processing pipeline that:
- ✅ Uses **only Infant FreeSurfer (iFS)** and standard FreeSurfer
- ✅ **NO iBEAT2 dependency**
- ✅ **NO MATLAB dependency**
- ✅ Pure bash/FreeSurfer command-line tools only

All tissue segmentation processing that previously required MATLAB has been replaced with native FreeSurfer command-line utilities (`mri_binarize`, `mri_mask`, `fscalc`).

## Key Advantages

1. **Simplified Dependencies**: Only FreeSurfer tools required
2. **Easier Installation**: No MATLAB license or iBEAT2 Docker setup needed
3. **Portable**: Pure bash script, runs anywhere FreeSurfer runs
4. **Transparent**: All processing steps visible in bash code

## Dependencies

**Required:**
- Infant FreeSurfer
- FreeSurfer 7.3 or later

**NOT Required:**
- ❌ iBEAT2.0 Docker
- ❌ MATLAB

## Pipeline Structure

```
.
├── reFS_iFS_only_no_matlab.sh              <-- Main pipeline script (bash-only)
    ├── iFS_wrap.sh                         <-- Sets up and runs iFS
    ├── fs_autorecon2_end.sh                <-- Runs FS autorecon2 with adjustments
    ├── fs_autorecon3_wrap.sh               <-- Runs FS autorecon3 with adjustments
```

## Usage

```bash
reFS_iFS_only_no_matlab.sh <subject_id> <age_in_months>
```

### Parameters
- `subject_id`: Subject identifier (should match directory name in SUBJECTS_DIR)
- `age_in_months`: Subject age in months (required for iFS processing)

### Example
```bash
export SUBJECTS_DIR=/path/to/freesurfer/subjects
reFS_iFS_only_no_matlab.sh sub-001 6
```

## What the Script Does

### Processing Steps:

1. **Initial FreeSurfer Run** (`recon-all -all`)
   - Standard FreeSurfer processing to completion

2. **Cleanup**
   - Removes transforms and intermediate files

3. **Infant FreeSurfer Setup**
   - Prepares data for iFS processing

4. **Infant FreeSurfer Processing**
   - Runs age-appropriate brain segmentation

5. **Label Adjustment** (bash-only, replaces MATLAB)
   - Copies iFS aseg to FreeSurfer directory
   - Adjusts thalamus labels for compatibility:
     - 9 (iFS left thalamus) → 10 (FS left thalamus)
     - 48 (iFS right thalamus) → 49 (FS right thalamus)
   - Uses: `mri_convert`, `mri_binarize`, `mri_mask`

6. **White Matter Generation** (bash-only, replaces MATLAB)
   - Creates `wm.mgz` from iFS segmentation
   - White matter labels (2, 41, 173, 174, 175) → 110
   - Gray matter labels (4, 11, 12, 13, 26, 28, 43, 50, 51, 52, 58, 60) → 250
   - Uses: `mri_binarize`, `fscalc`

7. **FreeSurfer Integration**
   - Resumes FreeSurfer autorecon2 with iFS-derived files

8. **Surface Reconstruction**
   - Completes cortical surface reconstruction (autorecon3)

## Technical Details

### Label Remapping (replaces iFS_aseg_process.m)

```bash
# Copy iFS aseg
mri_convert -i ${ifp}/mri/aseg.mgz -o ${fp}/mri/aseg.presurf.mgz

# Remap thalamus labels
mri_binarize --i aseg.presurf.mgz --match 9 --replace 10 --o tmp.mgz
mri_mask -transfer 10 tmp.mgz aseg.presurf.mgz aseg.presurf.mgz

mri_binarize --i aseg.presurf.mgz --match 48 --replace 49 --o tmp.mgz
mri_mask -transfer 49 tmp.mgz aseg.presurf.mgz aseg.presurf.mgz
```

### White Matter Generation (replaces aseg2wm_iFS.m)

```bash
# Extract white matter labels → 110
mri_binarize --i aseg.presurf.mgz --match 2 41 173 174 175 --replace 110 --o wm_tmp.mgz

# Extract gray matter labels → 250
mri_binarize --i aseg.presurf.mgz --match 4 11 12 13 26 28 43 50 51 52 58 60 --replace 250 --o gm_tmp.mgz

# Combine
fscalc wm_tmp.mgz add gm_tmp.mgz --o wm.mgz
```

## Requirements

1. **Environment Setup**:
   - FreeSurfer environment variables properly configured
   - SUBJECTS_DIR must be set
   - iFS installation configured in `iFS_wrap.sh`

2. **Input Data**:
   - T1-weighted MRI in FreeSurfer format
   - File: `${SUBJECTS_DIR}/${subject_id}/mri/orig.mgz`

3. **Scripts in PATH**:
   - Add the directory containing these scripts to your PATH

## Output

Standard FreeSurfer output in `${SUBJECTS_DIR}/${subject_id}/`:
- `/mri/` - Volumetric files (aseg.mgz, brainmask.mgz, etc.)
- `/surf/` - Surface files (white, pial, inflated, etc.)
- `/stats/` - Morphometric statistics

Statistics can be consolidated using the original `consol_stats.sh` script.

## Important Notes

⚠️ **Validation**: This simplified pipeline produces equivalent results to the MATLAB version but has not been validated against the original hybrid iBEAT2/iFS approach used in the published study.

⚠️ **Quality Control**: Always visually inspect:
- `aseg.presurf.mgz` - Check segmentation quality
- `wm.mgz` - Verify white matter mask
- Surface files - Check for topological defects

⚠️ **Age Range**: Infant FreeSurfer is optimized for infants 0-24 months. Performance may vary outside this range.

## Comparison with Other Pipelines

| Feature | Original | iFS-only (MATLAB) | iFS-only (Bash) |
|---------|----------|-------------------|-----------------|
| iBEAT2 Required | ✅ Yes | ❌ No | ❌ No |
| MATLAB Required | ✅ Yes | ✅ Yes | ❌ No |
| Segmentation | Hybrid | iFS only | iFS only |
| Complexity | High | Medium | Low |
| Dependencies | Many | Medium | Minimal |

## Troubleshooting

### FreeSurfer Commands Not Found
**Problem**: `mri_binarize: command not found`

**Solution**: Source FreeSurfer setup script:
```bash
export FREESURFER_HOME=/path/to/freesurfer
source $FREESURFER_HOME/SetUpFreeSurfer.sh
```

### iFS Fails to Run
**Problem**: iFS processing fails

**Solutions**:
- Check age parameter is valid (0-24 months typically)
- Verify iFS installation in `iFS_wrap.sh`
- Check input image quality

### Label Transfer Warnings
**Problem**: Warnings about label transfer

**Solution**: These are usually safe to ignore if segmentation looks good visually

### Surface Reconstruction Errors
**Problem**: Errors during autorecon2/autorecon3

**Solutions**:
- Visually inspect `aseg.presurf.mgz` and `wm.mgz`
- May need manual edits to segmentation
- Check that thalamus labels were properly remapped

## Performance

Runtime is similar to the original pipeline:
- Initial recon-all: ~6-12 hours
- iFS processing: ~2-4 hours
- Final recon-all steps: ~4-8 hours

**Total**: ~12-24 hours per subject (varies by compute resources)

## Citation

If you use this pipeline, please cite:

```
Original study: Turesky et al. Longitudinal trajectories of brain development
from infancy to school age and their relationship to literacy development

Modified pipeline: Simplified iFS-only version (removed iBEAT2 and MATLAB dependencies)
```

## Version History

- **v1.0**: Original hybrid iBEAT2/iFS pipeline (MATLAB required)
- **v2.0**: iFS-only pipeline (MATLAB required)
- **v3.0**: Simplified iFS-only pipeline (bash-only, no MATLAB)

## Contact

For questions about the original pipeline: theodore_turesky@gse.harvard.edu

For questions about the simplified version: [Your contact information]

## License

Same license as original repository.
