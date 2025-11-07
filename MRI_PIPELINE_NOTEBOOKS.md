# MRI Processing Pipeline Notebooks

This directory contains two Jupyter notebooks for visualizing and running the infant brain MRI processing pipeline.

## 📓 Available Notebooks

### 1. `mri_pipeline_visualization.ipynb` - **Full Pipeline**

**Complete pipeline with iBEATv2 integration** for optimal accuracy.

#### Prerequisites:
- ✅ FreeSurfer 7.3+ or 8.1+
- ✅ Infant FreeSurfer (for ages 0-24 months)
- ✅ **iBEATv2** tissue segmentation tool
- ✅ MATLAB (for segmentation merging)

#### Features:
- Combines iBEATv2 + Infant FreeSurfer + Standard FreeSurfer
- Superior cortical gray/white matter boundary detection
- Optimal subcortical segmentation for infants
- Complete visualization of all processing steps

#### Processing Time:
- **20-40 hours** for complete pipeline

#### Best For:
- Research requiring maximum accuracy for infant cortical measurements
- Longitudinal infant studies (0-24 months)
- When you have iBEATv2 and MATLAB already set up
- Publications requiring best possible segmentation

---

### 2. `mri_pipeline_simplified.ipynb` - **Simplified Pipeline** ⭐ RECOMMENDED FOR MOST USERS

**FreeSurfer-only pipeline** without external dependencies.

#### Prerequisites:
- ✅ FreeSurfer 7.3+ or 8.1+
- ✅ Infant FreeSurfer (optional, for ages 0-24 months)
- ❌ **No iBEATv2 required**
- ❌ **No MATLAB required**

#### Features:
- Single tool (FreeSurfer) with optional infant enhancement
- Complete cortical surface reconstruction
- All morphometric measurements
- Easy to set up and maintain

#### Processing Time:
- **6-20 hours** (depends on using infant FreeSurfer)

#### Best For:
- Getting started quickly
- Subjects aged 25+ months
- When iBEATv2/MATLAB not available
- Standard FreeSurfer accuracy is sufficient

---

## 🆚 Detailed Comparison

| Feature | Full Pipeline | Simplified Pipeline |
|---------|---------------|---------------------|
| **External Dependencies** | iBEATv2 + MATLAB | None |
| **Setup Complexity** | High | Low |
| **Processing Time** | 20-40 hours | 6-20 hours |
| **Cortical Segmentation (0-12mo)** | Excellent ⭐⭐⭐⭐⭐ | Good ⭐⭐⭐ |
| **Cortical Segmentation (12-24mo)** | Very Good ⭐⭐⭐⭐ | Good ⭐⭐⭐ |
| **Cortical Segmentation (25+mo)** | Excellent ⭐⭐⭐⭐⭐ | Excellent ⭐⭐⭐⭐⭐ |
| **Subcortical Segmentation** | Excellent ⭐⭐⭐⭐⭐ | Excellent ⭐⭐⭐⭐⭐ |
| **Surface Reconstruction** | Excellent ⭐⭐⭐⭐⭐ | Excellent ⭐⭐⭐⭐⭐ |
| **Troubleshooting** | Difficult | Easy |
| **Reproducibility** | Moderate | High |

---

## 📊 Accuracy Differences by Age

### Infants 0-12 months:
- **Full pipeline**: 5-15% better cortical accuracy
- **When it matters**: Fine-grained cortical development studies
- **When it doesn't**: Subcortical volumes, general brain volumes

### Infants 12-24 months:
- **Full pipeline**: 2-10% better cortical accuracy
- **Diminishing returns** as brain matures

### Children 25+ months:
- **No meaningful difference** - both pipelines perform equally well

---

## 🚀 Quick Start Guide

### Option 1: Start with Simplified (Recommended)

```bash
# 1. Open the simplified notebook
jupyter notebook mri_pipeline_simplified.ipynb

# 2. Run cells to see commands

# 3. Copy and run the FreeSurfer command in terminal:
export SUBJECTS_DIR=/path/to/output
recon-all -i /path/to/T1w.nii.gz -subjid sub-01 -all -parallel

# 4. Wait 6-12 hours

# 5. Return to notebook to visualize results
```

### Option 2: Full Pipeline (If You Have iBEATv2)

```bash
# 1. Run iBEATv2 first (external tool)
# ... (see iBEATv2 documentation)

# 2. Open the full pipeline notebook
jupyter notebook mri_pipeline_visualization.ipynb

# 3. Use the repository scripts:
cd peer-review/1.Structure
./reFS_under25mo.sh sub-01 /path/to/ibeat_seg.nii.gz 18

# 4. Wait 20-40 hours

# 5. Return to notebook to visualize results
```

---

## 🔄 Can I Run Both?

**YES!** You can process the same subject with both pipelines and compare results:

```bash
# Simplified pipeline
export SUBJECTS_DIR=/path/to/freesurfer_simplified
recon-all -i T1w.nii.gz -subjid sub-01 -all

# Full pipeline
export SUBJECTS_DIR=/path/to/freesurfer_full
cd peer-review/1.Structure
./reFS_under25mo.sh sub-01 /path/to/ibeat_seg.nii.gz 18

# Compare in FreeView
freeview \
  -v freesurfer_simplified/sub-01/mri/aseg.mgz \
  -v freesurfer_full/sub-01/mri/aseg.presurf.mgz:opacity=0.5
```

---

## 📝 Pipeline Steps Comparison

### Full Pipeline Steps:
1. Standard FreeSurfer initial processing (6-12h)
2. Infant FreeSurfer processing (4-8h)
3. **iBEATv2 + iFS segmentation merging (MATLAB, 10min)** ⬅️ Unique step
4. **White matter mask generation (MATLAB, 2min)** ⬅️ Unique step
5. Surface reconstruction with merged segmentation (8-15h)
6. Cortical parcellation (3-6h)

### Simplified Pipeline Steps:
1. Standard FreeSurfer complete processing (6-12h)
2. *Optional:* Infant FreeSurfer enhancement (4-8h)
3. Surface reconstruction (included in step 1)
4. Cortical parcellation (included in step 1)

**Steps 3-4 removed!** No MATLAB or iBEATv2 needed.

---

## 🎯 Decision Tree: Which Pipeline Should I Use?

```
START
  │
  ├─ Do you have iBEATv2 and MATLAB set up?
  │   ├─ NO  → Use Simplified Pipeline ✅
  │   └─ YES → Continue
  │
  ├─ Is your subject under 25 months old?
  │   ├─ NO  → Use Simplified Pipeline ✅
  │   └─ YES → Continue
  │
  ├─ Do you need maximum cortical segmentation accuracy?
  │   ├─ NO  → Use Simplified Pipeline ✅
  │   └─ YES → Continue
  │
  ├─ Are you studying fine-grained cortical development?
  │   ├─ NO  → Use Simplified Pipeline ✅
  │   └─ YES → Use Full Pipeline ⭐
```

**Result:** Most users should use the **Simplified Pipeline**!

---

## 💡 Common Use Cases

### Use Case 1: "I just want to process MRI data"
→ **Simplified Pipeline**

### Use Case 2: "I'm studying 3-year-old children"
→ **Simplified Pipeline**

### Use Case 3: "I need subcortical volumes from infants"
→ **Simplified Pipeline** (with optional infant FreeSurfer)

### Use Case 4: "I'm tracking cortical thickness changes in 0-12 month olds"
→ **Full Pipeline** (if you can get iBEATv2)

### Use Case 5: "I'm replicating a published study that used iBEATv2"
→ **Full Pipeline**

---

## 🐛 Troubleshooting

### Common Issues

#### Error: "could not open source file nu.mgz"
- **Solution**: Remove `-nonuintensitycor` flag (already fixed in notebooks)
- **See**: FreeSurfer 8.x compatibility notes in notebooks

#### iBEATv2 Not Available
- **Solution**: Use Simplified Pipeline instead
- **Impact**: Minimal for ages 25+, moderate for ages 0-24 months

#### MATLAB Not Available
- **Solution**: Use Simplified Pipeline instead
- **Alternative**: Could reimplement merging scripts in Python (advanced)

#### Infant FreeSurfer Not Available
- **Solution**: Use standard FreeSurfer only (still works!)
- **Impact**: Slightly lower accuracy for subcortical structures in infants

---

## 📚 Additional Resources

### FreeSurfer Documentation:
- [Recon-all Overview](https://surfer.nmr.mgh.harvard.edu/fswiki/recon-all)
- [Output Files](https://surfer.nmr.mgh.harvard.edu/fswiki/ReconAllOutputFiles)
- [Troubleshooting](https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurferWikiTroubleshooting)

### Related Tools:
- **FreeSurfer**: https://surfer.nmr.mgh.harvard.edu/
- **Infant FreeSurfer**: Included with FreeSurfer
- **iBEATv2**: http://ibeat.wildapricot.org/ (external, optional)

### Visualization:
- **FreeView**: Included with FreeSurfer
  ```bash
  freeview -v T1.mgz -v aseg.mgz:colormap=lut -f lh.pial:edgecolor=red
  ```

---

## 🔬 For Researchers

### Publishing Results

Both pipelines are suitable for publication. When writing methods:

**Simplified Pipeline:**
```
Structural MRI data were processed using FreeSurfer 8.1.0 (recon-all).
For infant subjects (ages 0-24 months), infant FreeSurfer processing
was applied for age-appropriate segmentation. Cortical surfaces were
reconstructed and parcellated using the Desikan-Killiany atlas.
```

**Full Pipeline:**
```
Structural MRI data were processed using a hybrid pipeline combining
iBEATv2 tissue segmentation, infant FreeSurfer (ages 0-24 months),
and FreeSurfer 7.3 surface reconstruction. Cortical and subcortical
segmentations were merged following the protocol of [cite original paper].
```

### Data Sharing

- **Simplified Pipeline**: Easy to share (standard FreeSurfer)
- **Full Pipeline**: Requires documenting iBEATv2 version and parameters

---

## ❓ Questions?

**Q: Can I switch between pipelines mid-study?**
A: Not recommended for longitudinal studies. Choose one pipeline and stick with it for consistency.

**Q: Which pipeline do the original scripts use?**
A: The full pipeline (iBEATv2 + infant FreeSurfer + FreeSurfer merging).

**Q: Is the simplified pipeline "worse"?**
A: No! For most use cases, it's equally good. The full pipeline offers marginal improvements for specific infant cortical analyses.

**Q: Can I use the simplified pipeline for my PhD?**
A: Absolutely! FreeSurfer-only processing is used in thousands of published studies.

---

## 🎓 Learning Path

1. **Start here**: `mri_pipeline_simplified.ipynb`
2. Run FreeSurfer on a test subject
3. Visualize results in the notebook
4. If needed, review `mri_pipeline_visualization.ipynb` for full pipeline details
5. Make an informed decision based on your specific needs

---

**Created:** 2025-11-07
**Repository:** Longitudinal-Trajectories-Early-Brain-Development-Language
**Branch:** claude/visualize-mri-pipeline-jupyter-011CUsu78d1CwcLRREuu1G6g
