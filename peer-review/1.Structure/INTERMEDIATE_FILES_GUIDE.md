# Complete Guide to Pipeline Intermediate Files

This document explains EVERY intermediate file produced during the infant brain processing pipeline, what each represents, and how to perform quality control.

## Table of Contents

1. [Input Stage](#input-stage)
2. [Autorecon1: Motion Correction & Normalization](#autorecon1)
3. [Infant FreeSurfer Processing](#infant-freesurfer)
4. [Label Remapping](#label-remapping)
5. [White Matter Generation](#white-matter-generation)
6. [Autorecon2: Surface Initialization](#autorecon2)
7. [Autorecon3: Surface Refinement](#autorecon3)
8. [Final Outputs](#final-outputs)

---

## Input Stage

### `rawdata/sub-01_ses-03_T1w.nii.gz`
**Description**: Original T1-weighted MRI scan

**What to check**:
- [ ] Good tissue contrast (GM vs WM vs CSF visible)
- [ ] No major motion artifacts
- [ ] Complete brain coverage (including cerebellum)
- [ ] Proper orientation (RAS coordinates)
- [ ] No intensity inhomogeneity streaks

**Typical values**:
- Infant brain volume: 400-1200 ml (depends on age)
- Voxel size: ~1 mm isotropic
- Intensity range: 0-4095 (12-bit) or 0-32767 (16-bit)

**Common issues**:
- Motion blur: Check for ghosting artifacts
- Wrap-around: Check edges of image
- RF inhomogeneity: Gradual intensity changes across image

---

## Autorecon1

### Stage 1.1: Import and Conform

#### `mri/orig.mgz`
**Description**: Imported T1 in FreeSurfer format (256³, 1mm isotropic)

**Processing**: Input image → Conformed to 256×256×256, 1mm³ isotropic

**What to check**:
- [ ] Image properly centered
- [ ] Correct orientation (neurological convention)
- [ ] No cropping of brain tissue
- [ ] Voxel size exactly 1×1×1 mm

**QC visualization**:
```bash
# View with freeview
freeview -v mri/orig.mgz
```

### Stage 1.2: Motion Correction

#### `mri/rawavg.mgz`
**Description**: Motion-corrected average (if multiple inputs)

**Processing**: orig.mgz → Motion correction → rawavg.mgz

**What to check**:
- [ ] Reduced motion artifacts vs orig
- [ ] No alignment errors
- [ ] Improved sharpness

**Note**: If only one input volume, rawavg.mgz = orig.mgz

### Stage 1.3: Intensity Normalization

#### `mri/nu.mgz`
**Description**: Non-uniformity corrected (bias field correction)

**Processing**: orig.mgz → N4 bias correction → nu.mgz

**What to check**:
- [ ] Uniform intensity across brain regions
- [ ] No bright spots in periphery
- [ ] WM appears uniformly bright
- [ ] CSF appears uniformly dark

**Typical values**:
- WM intensity: ~100-120
- GM intensity: ~60-80
- CSF intensity: ~20-40

**QC comparison**:
```bash
# Compare before and after
freeview -v mri/orig.mgz mri/nu.mgz
```

**Common issues**:
- Over-correction: Brain too uniform, loss of contrast
- Under-correction: Still visible intensity gradients

#### `mri/orig_nu.mgz`
**Description**: Copy of nu.mgz for reference

#### `mri/T1.mgz`
**Description**: Further normalized T1

**Processing**: nu.mgz → Atlas-based normalization → T1.mgz

**What to check**:
- [ ] Enhanced contrast between tissues
- [ ] WM brighter than GM
- [ ] Good tissue boundaries
- [ ] No over-brightening

**Typical values**:
- WM: ~110
- GM: ~70
- CSF: ~30

### Stage 1.4: Talairach Registration

#### `mri/transforms/talairach.xfm`
**Description**: Affine registration to MNI305 atlas

**Processing**: nu.mgz → Register to atlas → talairach.xfm

**What to check**:
- [ ] File exists and non-empty
- [ ] Contains valid transformation matrix
- [ ] Reasonable scaling factors (±20%)
- [ ] Reasonable rotation angles (±15°)

**How to check**:
```bash
# View transformation
cat mri/transforms/talairach.xfm

# Expected format:
# Transform_Type = Linear;
# Linear_Transform =
#  0.9xxx  0.0xxx  0.0xxx  xxx.xxx
#  0.0xxx  0.9xxx  0.0xxx  xxx.xxx
#  0.0xxx  0.0xxx  0.9xxx  xxx.xxx;
```

**Common issues**:
- Failed registration: Identity matrix or extreme scaling
- Rotation errors: Large off-diagonal terms

#### `mri/transforms/talairach.lta`
**Description**: Same registration in LTA format

**Note**: Used by newer FreeSurfer commands

### Stage 1.5: Skull Stripping

#### `mri/brainmask.mgz`
**Description**: Brain extracted (skull removed)

**Processing**: T1.mgz + Atlas → Watershed algorithm → brainmask.mgz

**What to check** (CRITICAL):
- [ ] All skull removed (no bright rim at edges)
- [ ] No dura matter included
- [ ] Cerebellum fully included
- [ ] Brainstem included
- [ ] No brain tissue removed
- [ ] Ventricles not clipped
- [ ] No holes in brain

**Typical values**:
- Infant brain volume: 400-1200 ml (age-dependent)
- 0-3 months: ~400-600 ml
- 6-12 months: ~700-1000 ml
- 12-24 months: ~900-1200 ml

**QC visualization**:
```bash
# Overlay mask on T1
freeview -v mri/T1.mgz mri/brainmask.mgz:colormap=heat:opacity=0.3
```

**Common issues**:
- **Under-stripping**: Skull/dura included (appears as bright rim)
- **Over-stripping**: Brain tissue removed (missing cortex edges)
- **Cerebellum clipped**: Bottom of cerebellum cut off
- **Ventricles filled**: CSF spaces incorrectly masked out

**Manual fixes if needed**:
```bash
# Edit brain mask manually
freeview -v mri/T1.mgz -v mri/brainmask.mgz:colormap=lut

# Save edits, then rerun from this point:
recon-all -autorecon2 -autorecon3 -subjid <subject>
```

#### `mri/brainmask.auto.mgz`
**Description**: Automatic brain mask before manual edits

### Stage 1.6: Atlas Normalization

#### `mri/norm.mgz`
**Description**: Intensity normalized using atlas priors

**Processing**: nu.mgz + talairach.xfm + atlas → norm.mgz

**What to check**:
- [ ] Consistent intensity across subjects
- [ ] Good tissue contrast
- [ ] No artifacts introduced

#### `mri/brain.mgz`
**Description**: Final normalized brain

**Processing**: norm.mgz + brainmask.mgz → brain.mgz

**What to check**:
- [ ] Combines good normalization with good mask
- [ ] Ready for segmentation

**This completes Autorecon1** (~8-12 hours)

---

## Infant FreeSurfer Processing

Location: `<ifs_dir>/<subject>/mri/`

### `iFS/*/mri/aseg.mgz`
**Description**: Infant-optimized tissue segmentation (KEY FILE)

**Processing**: Uses age-appropriate atlases for infant brains

**Labels** (FreeSurfer Label-UT):
- **0**: Background/Unknown
- **2**: Left Cerebral White Matter
- **3**: Left Cerebral Cortex
- **4**: Left Lateral Ventricle
- **9**: Left Thalamus (iFS convention)
- **11**: Left Caudate
- **12**: Left Putamen
- **13**: Left Pallidum
- **17**: Left Hippocampus
- **18**: Left Amygdala
- **26**: Left Accumbens
- **28**: Left Ventral DC
- **41**: Right Cerebral White Matter
- **42**: Right Cerebral Cortex
- **43**: Right Lateral Ventricle
- **48**: Right Thalamus (iFS convention)
- **50-60**: Right hemisphere structures (mirror of left)

**What to check** (CRITICAL):
- [ ] GM/WM boundary looks accurate
- [ ] Subcortical structures properly identified
- [ ] Symmetric left/right structures
- [ ] Ventricles not over-segmented
- [ ] No mislabeled voxels
- [ ] Thalamus labeled as 9/48 (will be remapped)

**Typical label counts** (age-dependent):
- WM (2+41): 150,000-400,000 voxels
- Cortex (3+42): 250,000-600,000 voxels
- Ventricles (4+43): 5,000-50,000 voxels

**QC visualization**:
```bash
# View segmentation overlay
freeview -v ../FS/mri/T1.mgz \
         -v mri/aseg.mgz:colormap=lut:opacity=0.4
```

**Common issues**:
- WM/GM confusion: Especially in infant brains with low contrast
- Over-segmented ventricles: CSF labeled as ventricle
- Missing subcortical structures: Check caudate, putamen, thalamus
- Asymmetry: Left/right structures very different sizes

### `iFS/*/mri/brainmask.mgz`
**Description**: iFS brain mask

**What to check**:
- [ ] Compare with FS brainmask
- [ ] May be more accurate for infants

---

## Label Remapping

### `mri/aseg.presurf.mgz`
**Description**: iFS aseg with labels remapped for FS compatibility

**Processing**:
```bash
# Copy iFS aseg
mri_convert iFS/mri/aseg.mgz → aseg.presurf.mgz

# Remap thalamus labels
Label 9  → 10 (left thalamus)
Label 48 → 49 (right thalamus)
```

**What to check** (CRITICAL):
- [ ] Label 9 should have ZERO voxels
- [ ] Label 10 should have >0 voxels (left thalamus)
- [ ] Label 48 should have ZERO voxels
- [ ] Label 49 should have >0 voxels (right thalamus)
- [ ] All other labels unchanged

**QC check**:
```python
import nibabel as nib
import numpy as np

aseg = nib.load('mri/aseg.presurf.mgz').get_fdata()

print(f"Label 9:  {np.sum(aseg == 9)} voxels (should be 0)")
print(f"Label 10: {np.sum(aseg == 10)} voxels (should be >0)")
print(f"Label 48: {np.sum(aseg == 48)} voxels (should be 0)")
print(f"Label 49: {np.sum(aseg == 49)} voxels (should be >0)")
```

**Common issues**:
- Labels not remapped: Still have 9/48 present
- Over-remapping: Other labels accidentally changed

---

## White Matter Generation

### `mri/wm.mgz`
**Description**: White matter file for surface initialization

**Processing**:
```bash
# Extract WM labels (2, 41, 173, 174, 175) → 110
# Extract GM labels (4, 11, 12, 13, 26, 28, ...) → 250
# Combine: WM=110, GM=250
```

**What to check** (CRITICAL):
- [ ] Only values 0, 110, 250 present
- [ ] 110 (WM) covers cerebral WM bilaterally
- [ ] 250 (GM) covers subcortical nuclei
- [ ] No holes or gaps in WM
- [ ] Smooth boundaries

**Label meanings**:
- **0**: Background/other
- **110**: White matter (for surface finding)
- **250**: Gray matter structures (for masking)

**Typical values**:
- Label 110: 150,000-400,000 voxels
- Label 250: 50,000-150,000 voxels

**QC visualization**:
```bash
# View WM file
freeview -v mri/T1.mgz \
         -v mri/wm.mgz:colormap=heat:opacity=0.5
```

**Common issues**:
- Wrong label values: Not 110/250
- Empty WM (110=0 voxels): Label extraction failed
- Disconnected WM: Holes present
- WM extends into cortex: Will cause surface errors

#### `mri/wm.asegedit.mgz`
**Description**: Edited WM file (if manual edits needed)

#### `mri/filled.mgz`
**Description**: WM filled for tessellation

**Processing**: wm.mgz → Fill ventricles and subcortical structures → filled.mgz

**What to check**:
- [ ] Hemispheres separated
- [ ] Ventricles filled in
- [ ] Smooth WM volume

---

## Autorecon2

### Stage 2.1: Tessellation

#### `surf/lh.orig.nofix` / `surf/rh.orig.nofix`
**Description**: Initial surface before topology correction

**Processing**: filled.mgz → Marching cubes → surface mesh

**What to check**:
- [ ] Surface follows WM roughly
- [ ] Topology defects present (normal at this stage)
- [ ] Complete coverage of hemisphere

**Euler number check**:
```bash
# Check topology (should be reported in recon-all.log)
# Euler = 2: Perfect sphere (no defects)
# Euler < 2: Defects present (will be fixed)

mris_euler_number surf/lh.orig.nofix
```

**Common issues**:
- Large holes: WM mask had major gaps
- Handles: Incorrectly filled WM
- Fragmented: WM not continuous

### Stage 2.2: Smoothing

#### `surf/lh.smoothwm.nofix` / `surf/rh.smoothwm.nofix`
**Description**: Smoothed version of orig surface

#### `surf/lh.inflated.nofix` / `surf/rh.inflated.nofix`
**Description**: Inflated surface for visualization

### Stage 2.3: Spherical Mapping

#### `surf/lh.qsphere.nofix` / `surf/rh.qsphere.nofix`
**Description**: Surface mapped to sphere (for topology correction)

### Stage 2.4: Topology Correction

#### `surf/lh.orig` / `surf/rh.orig`
**Description**: Topologically correct surface (no holes/handles)

**Processing**: orig.nofix → Fix topology defects → orig

**What to check** (CRITICAL):
- [ ] Euler number = 2 (perfect sphere topology)
- [ ] No self-intersections
- [ ] Smooth surface
- [ ] Still follows WM boundary

```bash
# Verify topology fixed
mris_euler_number surf/lh.orig  # Should output: 2
```

**Common issues**:
- Euler ≠ 2: Topology correction failed
- Over-smoothing: Lost anatomical detail
- Surface distortion: Doesn't follow anatomy

### Stage 2.5: White Surface Placement

#### `surf/lh.white` / `surf/rh.white`
**Description**: Final white matter surface (GM/WM boundary)

**Processing**: orig → Deform to GM/WM boundary → white

**What to check** (CRITICAL):
- [ ] Follows GM/WM boundary accurately
- [ ] Smooth but captures gyral detail
- [ ] No self-intersections
- [ ] Complete coverage
- [ ] Symmetric between hemispheres

**QC visualization**:
```bash
# View white surface on T1
freeview -v mri/T1.mgz \
         -f surf/lh.white:edgecolor=yellow \
            surf/rh.white:edgecolor=yellow
```

**Common issues**:
- Extends into GM: White surface too far out
- Misses WM: Surface too far in
- Irregular: Noisy or bumpy surface
- Intersects pial: Will cause thickness errors

#### `surf/lh.white.preaparc` / `surf/rh.white.preaparc`
**Description**: White surface before parcellation

### Stage 2.6: Surface Inflation

#### `surf/lh.inflated` / `surf/rh.inflated`
**Description**: Inflated surface for visualization

**Use**: Makes sulci visible for QC

#### `surf/lh.sphere` / `surf/rh.sphere`
**Description**: Surface mapped to perfect sphere

**Use**: For atlas registration and parcellation

---

## Autorecon3

### Stage 3.1: Pial Surface Placement

#### `surf/lh.pial` / `surf/rh.pial`
**Description**: Pial surface (GM/CSF boundary) - FINAL KEY OUTPUT

**Processing**: white → Deform to GM/CSF boundary → pial

**What to check** (CRITICAL):
- [ ] Follows GM/CSF boundary
- [ ] Outside white surface everywhere
- [ ] Captures cortical folding
- [ ] No dura included
- [ ] Follows into sulci
- [ ] No intersection with white surface

**QC visualization**:
```bash
# View both surfaces
freeview -v mri/T1.mgz \
         -f surf/lh.white:edgecolor=yellow \
            surf/lh.pial:edgecolor=red \
            surf/rh.white:edgecolor=yellow \
            surf/rh.pial:edgecolor=red
```

**Common issues**:
- Includes dura: Pial extends beyond brain
- Intersects white: Invalid thickness values
- Misses sulci: Doesn't follow into folds
- Too close to white: Under-estimated thickness

#### `surf/lh.pial.T1` / `surf/rh.pial.T1`
**Description**: Pial surface using only T1 contrast

### Stage 3.2: Cortical Parcellation

#### `label/lh.aparc.annot` / `label/rh.aparc.annot`
**Description**: Cortical parcellation (Desikan-Killiany atlas)

**Regions**: 34 cortical regions per hemisphere

**What to check**:
- [ ] All regions present
- [ ] Reasonable region boundaries
- [ ] Symmetric between hemispheres

#### `label/lh.aparc.a2009s.annot` / `label/rh.aparc.a2009s.annot`
**Description**: Destrieux atlas (more regions)

### Stage 3.3: Morphometric Measurements

#### `surf/lh.thickness` / `surf/rh.thickness`
**Description**: Cortical thickness at each vertex

**Processing**: Distance from white to pial surface

**Typical values** (infants):
- Mean thickness: 2.0-3.5 mm (age-dependent)
- Thicker in infants than adults
- Gradual decrease with age

**What to check**:
- [ ] Reasonable thickness range (1-5 mm)
- [ ] No extreme values (>7 mm)
- [ ] No zero thickness (white=pial)
- [ ] Smooth spatial distribution

**QC visualization**:
```bash
# View thickness map
freeview -f surf/lh.inflated:overlay=surf/lh.thickness
```

#### `surf/lh.curv` / `surf/rh.curv`
**Description**: Cortical curvature

**Use**: Identifies sulci (negative) vs gyri (positive)

#### `surf/lh.area` / `surf/rh.area`
**Description**: Surface area at each vertex

---

## Final Outputs

### Statistics Files

#### `stats/aseg.stats`
**Description**: Volumetric statistics for subcortical structures

**Contains**:
- Volume of each structure (mm³)
- Intensity statistics
- Atlas scaling factors

**Key structures to check**:
- Left/Right Cerebral WM
- Left/Right Cerebral Cortex
- Left/Right Lateral Ventricle
- Left/Right Thalamus
- Left/Right Caudate
- Left/Right Putamen
- Left/Right Hippocampus
- Total brain volume
- Intracranial volume (eTIV)

#### `stats/lh.aparc.stats` / `stats/rh.aparc.stats`
**Description**: Cortical parcellation statistics

**Contains** (per region):
- Surface area (mm²)
- Gray matter volume (mm³)
- Cortical thickness (mm): mean, std
- Curvature metrics
- Intensity statistics

**Key metrics**:
- Total surface area: 50,000-150,000 mm² (age-dependent)
- Mean thickness: 2.0-3.5 mm
- Total GM volume: 200,000-500,000 mm³

#### `stats/lh.aparc.pial.stats` / `stats/rh.aparc.pial.stats`
**Description**: Statistics measured on pial surface

### Segmentation Files

#### `mri/aparc+aseg.mgz`
**Description**: Combined cortical parcellation and subcortical segmentation

**Use**: Complete brain parcellation in volume space

#### `mri/wmparc.mgz`
**Description**: White matter parcellation

**Use**: WM divided by cortical projections

---

## Quality Control Checklist

### Critical Checks

Use the detailed QC script:
```bash
python detailed_qc_visualization.py /path/to/subjects_dir sub-01_ses-03
```

This will check:

#### 1. Input Quality
- [ ] T1w has good contrast
- [ ] No major artifacts
- [ ] Complete coverage

#### 2. Normalization (nu.mgz, T1.mgz)
- [ ] Uniform intensity
- [ ] Good tissue contrast
- [ ] No artifacts introduced

#### 3. Registration (talairach.xfm)
- [ ] Valid transformation
- [ ] Reasonable parameters
- [ ] Good alignment to atlas

#### 4. Skull Stripping (brainmask.mgz)
- [ ] All skull removed
- [ ] Cerebellum included
- [ ] No brain removed
- [ ] Reasonable volume

#### 5. iFS Segmentation (iFS aseg.mgz)
- [ ] Accurate GM/WM boundary
- [ ] Subcortical structures present
- [ ] Symmetric left/right
- [ ] No major errors

#### 6. Label Remapping (aseg.presurf.mgz)
- [ ] Thalamus labels corrected (9→10, 48→49)
- [ ] Other labels preserved
- [ ] No unexpected changes

#### 7. White Matter (wm.mgz)
- [ ] Only labels 0, 110, 250
- [ ] WM complete and connected
- [ ] No holes or gaps

#### 8. White Surface (lh/rh.white)
- [ ] Follows GM/WM boundary
- [ ] Euler number = 2
- [ ] No self-intersections
- [ ] Smooth surface

#### 9. Pial Surface (lh/rh.pial)
- [ ] Follows GM/CSF boundary
- [ ] Outside white everywhere
- [ ] No dura included
- [ ] Captures sulci

#### 10. Thickness (lh/rh.thickness)
- [ ] Reasonable range (1-5 mm)
- [ ] Smooth distribution
- [ ] No extreme outliers

---

## Automated QC

### Run Complete QC

```bash
# Generate all QC images and report
python detailed_qc_visualization.py \
    /data02/share/bin-wu/data/human/brain/harvard_mri/processed/freesurfer \
    sub-01_ses-03 \
    --ifs-dir /data02/share/bin-wu/data/human/brain/harvard_mri/processed/iFS \
    --output /path/to/qc_output

# This generates:
# - PNG images for every intermediate file
# - Before/after comparisons
# - Quantitative metrics
# - JSON QC report
# - Pass/warning/error status for each check
```

### View Results

The script creates:
- `01_orig.png` - Original image
- `02_rawavg.png` - Motion corrected
- `03_nu.png` - Bias corrected
- `04_T1.png` - Normalized T1
- `05_brainmask.png` - Brain mask
- `06_norm.png` - Atlas normalized
- `07_ifs_brainmask.png` - iFS brain mask
- `08_ifs_aseg.png` - iFS segmentation
- `09_aseg_presurf.png` - Remapped segmentation
- `10_wm.png` - White matter file
- Plus comparison images and overlays
- `qc_report.json` - Detailed QC report

---

## Common Problems and Solutions

### Problem: Skull not fully removed

**Symptoms**: Bright rim at edge of brainmask.mgz

**Solutions**:
```bash
# Manually edit brain mask
freeview -v mri/T1.mgz -v mri/brainmask.mgz:colormap=lut

# Paint out skull (use brush tool, value=0)
# Save, then rerun:
recon-all -autorecon2 -autorecon3 -subjid <subject>
```

### Problem: White surface extends into GM

**Symptoms**: Yellow surface (white) too far out

**Solutions**:
```bash
# Edit WM volume
freeview -v mri/T1.mgz -v mri/wm.mgz:colormap=heat

# Paint out errors in WM (value=0)
# Save, then rerun:
recon-all -autorecon2-wm -autorecon3 -subjid <subject>
```

### Problem: Pial surface includes dura

**Symptoms**: Red surface (pial) extends beyond brain

**Solutions**:
```bash
# Edit brain mask or control points
freeview -v mri/T1.mgz \
         -v mri/brainmask.mgz \
         -f surf/lh.pial \
         -f surf/rh.pial

# Option 1: Tighten brain mask
# Option 2: Add control points
# Then rerun from pial step
```

### Problem: Segmentation errors

**Symptoms**: Wrong tissue labels in aseg

**Solutions**:
1. Check if error is in iFS aseg (fix there)
2. Check if error introduced during remapping
3. Manually edit aseg.presurf.mgz if needed

---

## FreeSurfer QC Tools

### View in FreeView

```bash
# Launch FreeView with typical QC view
freeview -v mri/T1.mgz \
         -v mri/aseg.presurf.mgz:colormap=lut:opacity=0.3 \
         -f surf/lh.white:edgecolor=yellow \
         -f surf/rh.white:edgecolor=yellow \
         -f surf/lh.pial:edgecolor=red \
         -f surf/rh.pial:edgecolor=red
```

### Automated QA

```bash
# FreeSurfer's automated QA
recon-all -subjid <subject> -qcache
```

---

## Template/Atlas Comparison

To verify proper registration to brain templates:

```bash
# View subject registered to atlas space
freeview -v $FREESURFER_HOME/average/mni305.cor.mgz \
         -v mri/norm.mgz:reg=mri/transforms/talairach.xfm:sample=trilin:opacity=0.5
```

**What to check**:
- [ ] Subject aligned with atlas
- [ ] Similar brain position and size
- [ ] No extreme rotations or scaling

---

## Export Results

### Extract volumes

```bash
# Subcortical volumes
asegstats2table --subjects sub-01_ses-03 \
                --meas volume \
                --tablefile aseg_volumes.txt

# Cortical thickness
aparcstats2table --subjects sub-01_ses-03 \
                 --hemi lh \
                 --meas thickness \
                 --tablefile lh_thickness.txt
```

### Generate QC snapshots

```bash
# Use our automated script
python detailed_qc_visualization.py /data/freesurfer sub-01_ses-03
```

---

## Additional Resources

- FreeSurfer Wiki: https://surfer.nmr.mgh.harvard.edu/fswiki
- Infant FreeSurfer: https://surfer.nmr.mgh.harvard.edu/fswiki/infantFS
- QC Guidelines: https://surfer.nmr.mgh.harvard.edu/fswiki/QATools

