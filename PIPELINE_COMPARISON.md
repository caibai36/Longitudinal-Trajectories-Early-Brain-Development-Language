# Infant FreeSurfer Pipeline Comparison

## Overview

This document compares three approaches to infant FreeSurfer processing:

1. **Original Pipeline** (in `peer-review/1.Structure/`) - Uses iBEAT + iFS + manual FS
2. **Proposed Simplified** - Attempted to use iFS + high-level recon-all commands (FLAWED)
3. **Corrected Pipeline** (`run_infant_freesurfer_corrected.sh`) - Uses iFS + manual FS (validated approach without iBEAT)

---

## Original Pipeline (Validated, Published)

**Files:**
- `reFS_under25mo.sh` - Main pipeline script
- `iFS_wrap.sh` - Runs infant_recon_all
- `ibeat2aseg.m` - Merges iBEAT tissues with iFS subcortical structures
- `aseg2wm.m` - Generates wm.mgz with labels 110/250
- `fs_autorecon2_end.sh` - Manual autorecon2 with infant parameters
- `fs_autorecon3_wrap.sh` - Manual autorecon3 with infant parameters
- `expert.opts` - Controls recon-all behavior

**Workflow:**
1. Run FreeSurfer `-all -nonuintensitycor` (adult templates)
2. Clean up adult-based files
3. Convert to mprage.nii.gz and run infant_recon_all
4. **Merge iBEAT tissue segmentation (1=CSF, 2=GM, 3=WM) with iFS aseg** ← KEY STEP
5. Generate wm.mgz from merged segmentation
6. Manually run ~40 FreeSurfer commands with infant-specific parameters
7. Create pial surfaces with infant tissue contrast settings

**Key Innovation:**
- iBEAT provides superior cortical GM/WM tissue classification
- iFS provides superior subcortical structure segmentation
- Merging gives best of both worlds

**Dependencies:**
- iBEAT v2.0 Docker
- Infant FreeSurfer
- FreeSurfer 7.3
- MATLAB

---

## Proposed Simplified Pipeline (FLAWED - Do Not Use)

**Attempted Workflow:**
1. Run FreeSurfer `-all` (adult templates)
2. Run infant_recon_all
3. Copy 4 files (aseg, wm, brainmask, transforms)
4. Run `recon-all -autorecon2-wm` ← WRONG
5. Run `recon-all -autorecon3` ← WRONG

**Critical Flaws:**

### 1. **Missing Manual Normalization Steps**
- Does not run mri_nu_correct.mni with --ants-n4
- Does not run mri_em_register with infant brainmask
- Does not run mri_ca_normalize with infant brainmask
- Does not create brain.mgz using aseg.presurf

**Result:** Autorecon2-wm will regenerate with adult parameters

### 2. **Wrong wm.mgz**
- Copies iFS wm.mgz directly
- Should generate from aseg.presurf with labels 110 (WM) and 250 (subcortical GM)

**Result:** Surface tessellation may fail or use wrong boundaries

### 3. **Missing Infant-Specific Surface Parameters**
- Does not use `-in 3000` for mris_sphere (infant needs more iterations)
- Does not use `mris_remesh --iters 3` (critical for infant topology)
- Does not use `-cover_seg aseg.presurf.mgz` in mris_make_surfaces

**Result:** Poor surface topology and placement

### 4. **Missing Infant Pial Parameters**
- Does not use `-grad_dir 1` (search outward)
- Does not use `-intensity .3` (infant GM/CSF contrast is lower than adult)
- Does not use `-pial_offset .25` (infant-specific offset)

**Result:** Pial surfaces will be placed incorrectly

### 5. **No iBEAT Tissue Refinement**
- Removes iBEAT but doesn't replace its functionality
- Relies solely on iFS aseg for cortical boundaries

**Result:** Less accurate cortical surfaces than original

### 6. **Missing expert.opts**
- Doesn't control autorecon3 to stop before pial
- Can't manually create pial with infant parameters

**Result:** Uses default adult pial parameters

---

## Corrected Pipeline (Validated Approach Without iBEAT)

**File:** `run_infant_freesurfer_corrected.sh`

**Workflow:**
1. Run FreeSurfer `-all -nonuintensitycor` (matches original)
2. Clean up adult-based files (matches original)
3. Run infant_recon_all (matches original)
4. Use iFS aseg directly as aseg.presurf (skip iBEAT merge)
5. Generate wm.mgz from aseg.presurf with labels 110/250 (matches original)
6. **Manually run all normalization steps** with infant brainmask (matches original)
7. **Manually run all surface steps** with infant parameters (matches original)
8. Create expert.opts to control autorecon3 (matches original)
9. **Manually create pial** with infant parameters (matches original)
10. Finish autorecon3 post-pial steps (matches original)

**Key Fixes from Proposed:**

| Issue | Proposed | Corrected |
|-------|----------|-----------|
| Normalization | Uses autorecon2-wm | Manual with infant brainmask |
| wm.mgz | Direct copy | Generated from aseg.presurf |
| Sphere inflation | Default (1000) | Infant-specific (-in 3000) |
| Surface remeshing | Not done | mris_remesh --iters 3 |
| White placement | Auto with aseg.auto | Manual with aseg.presurf |
| Pial intensity | Default (~0.5) | Infant-specific (0.3) |
| Pial direction | Default | -grad_dir 1 (outward) |
| Pial offset | Default | -pial_offset .25 |
| Expert options | Not used | Controls autorecon3 |

**Differences from Original:**
- ❌ No iBEAT tissue segmentation merge
- ✅ All other steps identical to validated pipeline
- ✅ Uses same infant-specific parameters
- ✅ Uses same manual command sequence

**Trade-offs:**
- **Advantage:** No MATLAB or iBEAT Docker dependency
- **Disadvantage:** Cortical surfaces may be less accurate (no iBEAT tissue refinement)
- **Recommendation:** Validate on test dataset, compare surface quality to original

---

## Command-by-Command Comparison

### Intensity Normalization

**Original (fs_autorecon2_end.sh):**
```bash
mri_nu_correct.mni --i orig.mgz --o nu.mgz --ants-n4
mri_normalize -g 1 -seed 1234 -mprage nu.mgz T1.mgz
mri_mask T1.mgz [iFS]/brainmask.mgz brainmask.mgz
mri_em_register -uns 3 -mask brainmask.mgz nu.mgz ...
mri_ca_normalize -mask brainmask.mgz nu.mgz ... norm.mgz
mri_normalize -aseg aseg.presurf.mgz -mask brainmask.mgz norm.mgz brain.mgz
```

**Proposed:**
```bash
recon-all -autorecon2-wm  # Will regenerate without infant mask
```

**Corrected:**
```bash
# Identical to original ✓
mri_nu_correct.mni --i orig.mgz --o nu.mgz --ants-n4
mri_normalize -g 1 -seed 1234 -mprage nu.mgz T1.mgz
mri_mask T1.mgz brainmask.mgz brainmask.mgz
mri_em_register -uns 3 -mask brainmask.mgz nu.mgz ...
mri_ca_normalize -mask brainmask.mgz nu.mgz ... norm.mgz
mri_normalize -aseg aseg.presurf.mgz -mask brainmask.mgz norm.mgz brain.mgz
```

### Sphere Inflation

**Original (fs_autorecon2_end.sh:46-47):**
```bash
mris_sphere -q -p 6 -a 128 -seed 1234 -in 3000 lh.inflated.nofix lh.qsphere.nofix
```

**Proposed:**
```bash
# Uses default -in 1000 ✗
```

**Corrected:**
```bash
mris_sphere -q -p 6 -a 128 -seed 1234 -in 3000 lh.inflated.nofix lh.qsphere.nofix ✓
```

### Surface Remeshing

**Original (fs_autorecon2_end.sh:64-65):**
```bash
mris_remesh --remesh --iters 3 --input lh.orig.premesh --output lh.orig
```

**Proposed:**
```bash
# Not done ✗
```

**Corrected:**
```bash
mris_remesh --remesh --iters 3 --input lh.orig.premesh --output lh.orig ✓
```

### White Surface Placement

**Original (fs_autorecon2_end.sh:71):**
```bash
mris_make_surfaces -output .preaparc -soap -orig_white orig \
  -aseg aseg.presurf \
  -cover_seg aseg.presurf.mgz \
  -noaparc -whiteonly -mgz -T1 brain.finalsurfs
```

**Proposed:**
```bash
# Uses default aseg.auto ✗
```

**Corrected:**
```bash
mris_make_surfaces -output .preaparc -soap -orig_white orig \
  -aseg aseg.presurf \
  -cover_seg aseg.presurf.mgz \
  -noaparc -whiteonly -mgz -T1 brain.finalsurfs ✓
```

### Pial Surface Creation

**Original (fs_autorecon3_wrap.sh:13):**
```bash
mris_make_surfaces -grad_dir 1 -intensity .3 \
  -output .tmp -pial_offset .25 \
  -nowhite -noaparc \
  -aseg aseg.presurf \
  -cover_seg aseg.presurf.mgz \
  -orig_pial white
```

**Proposed:**
```bash
# Uses default parameters ✗
# -intensity ~0.5 (too high for infants)
# -grad_dir 0 (search inward, wrong for infants)
# -pial_offset default
```

**Corrected:**
```bash
mris_make_surfaces -grad_dir 1 -intensity .3 \
  -output .tmp -pial_offset .25 \
  -nowhite -noaparc \
  -aseg aseg.presurf \
  -cover_seg aseg.presurf.mgz \
  -orig_pial white ✓
```

---

## Validation Recommendations

If using the corrected pipeline without iBEAT:

1. **Visual QC:**
   - Inspect white/pial surfaces in FreeView
   - Check for topology errors
   - Verify surfaces follow tissue boundaries

2. **Quantitative Comparison:**
   - Run both pipelines on validation dataset
   - Compare cortical thickness distributions
   - Compare surface area, volume estimates
   - Check for systematic biases

3. **Statistical Validation:**
   - Test if results replicate published findings
   - Check if age-related trajectories are preserved

4. **Known Limitations:**
   - Without iBEAT, cortical GM/WM boundary may be less accurate
   - Particularly challenging in regions with low tissue contrast
   - May affect cortical thickness precision

---

## Usage

### Original Pipeline (with iBEAT):
```bash
# Requires: iBEAT segmentation already generated
reFS_under25mo.sh subject_id /path/to/ibeat/tissue.nii.gz 18
```

### Corrected Pipeline (without iBEAT):
```bash
# No iBEAT required
./run_infant_freesurfer_corrected.sh --stage 0 --subject_id sub-01_ses-03 --age_months 18
```

---

## References

1. **Original Pipeline:**
   - Turesky et al. "Longitudinal trajectories of brain development from infancy to school age and their relationship to literacy development"

2. **Infant FreeSurfer:**
   - Zöllei et al. (2020). Infant FreeSurfer: An automated segmentation and surface extraction pipeline for T1-weighted neuroimaging data of infants 0-2 years

3. **iBEAT v2.0:**
   - Dai et al. (2013). iBEAT: A toolbox for infant brain magnetic resonance image processing

4. **FreeSurfer:**
   - Fischl et al. (2012). FreeSurfer. NeuroImage, 62(2), 774-781

---

## Contact

For questions about this comparison:
- Original pipeline: See repository authors
- Corrected version: Created based on repository code analysis
