# Pipeline Visualization Tools

This directory contains tools to visualize and understand each step of the infant brain processing pipeline.

## Tools Available

### 1. Detailed QC Script ⭐ NEW - COMPREHENSIVE (Recommended for Production QC)

**File**: `detailed_qc_visualization.py`

**Best for**: Complete quality control of ALL intermediate processing files with automated error detection.

**Features**:
- Visualizes EVERY intermediate file (orig.mgz, nu.mgz, T1.mgz, brainmask.mgz, etc.)
- Before/after comparisons for each processing step
- Automated quality metrics and error detection
- Template/atlas registration verification
- Quantitative measurements (volumes, SNR, etc.)
- Pass/Warning/Error status for each check
- Generates comprehensive JSON QC report
- Creates PNG images for all steps

**Usage**:
```bash
# Basic usage
python detailed_qc_visualization.py <subjects_dir> <subject_id>

# With your data
python detailed_qc_visualization.py \
    /data02/share/bin-wu/data/human/brain/harvard_mri/processed/freesurfer \
    sub-01_ses-03 \
    --ifs-dir /data02/share/bin-wu/data/human/brain/harvard_mri/processed/iFS \
    --output /path/to/qc_output
```

**What it checks**:
1. **Autorecon1**: orig.mgz, rawavg.mgz, nu.mgz, T1.mgz, brainmask.mgz, norm.mgz, talairach.xfm
2. **Infant FreeSurfer**: iFS aseg.mgz with all label checks
3. **Label Remapping**: Verifies thalamus labels (9→10, 48→49)
4. **White Matter**: wm.mgz with label value validation
5. **Surfaces**: Checks for all surface files and topology
6. **Quality Metrics**: SNR, volumes, correlations, etc.

**Output**:
- Individual PNG for each file (01_orig.png, 02_nu.png, 03_T1.png, ...)
- Comparison PNGs (orig_vs_nu.png, T1_vs_norm.png, ...)
- Overlay visualizations (T1_with_brainmask.png, T1_with_aseg.png, ...)
- `qc_report.json` with all checks and status
- Console output with pass/warning/error summary

**See also**: `INTERMEDIATE_FILES_GUIDE.md` for detailed explanation of every file.

### 2. Interactive Jupyter Notebook (Recommended for Learning)

**File**: `pipeline_visualization.ipynb`

**Best for**: Understanding the complete pipeline step-by-step with detailed explanations and demonstrations.

**Features**:
- Complete walkthrough of all pipeline steps
- Detailed explanations of what each step does
- Demonstrates bash commands with synthetic examples
- Shows label remapping and white matter generation
- Provides quality control guidelines
- Interactive visualization

**Usage**:
```bash
# Install dependencies
pip install -r requirements_notebook.txt

# Launch Jupyter
cd peer-review/1.Structure/
jupyter notebook pipeline_visualization.ipynb
```

**What it covers**:
1. Input data inspection (your T1w image)
2. FreeSurfer format conversion
3. Initial processing demonstration
4. Infant FreeSurfer processing concepts
5. Label remapping visualization
6. White matter generation demonstration
7. Pipeline flow diagram
8. Quality control checklist
9. Complete command reference

### 3. Quick Visualization Script (Recommended for Quick QC)

**File**: `visualize_pipeline_outputs.py`

**Best for**: Quick quality control checks of pipeline outputs.

**Features**:
- Fast visualization of all key outputs
- Automatic file checking
- Saves PNG images for reports
- Label statistics
- QC checklist

**Usage**:
```bash
# Basic usage
python visualize_pipeline_outputs.py <subjects_dir> <subject_id>

# Example with your data
python visualize_pipeline_outputs.py \
    /data02/share/bin-wu/data/human/brain/harvard_mri/processed/freesurfer \
    sub-01_ses-03

# Save to specific directory
python visualize_pipeline_outputs.py \
    /data02/share/bin-wu/data/human/brain/harvard_mri/processed/freesurfer \
    sub-01_ses-03 \
    --output /tmp/qc_viz
```

**Output**:
- Checks which files exist
- Creates PNG images of each file
- Prints label statistics
- Provides QC checklist

## Your Specific Data

Based on your file paths, here's how to use these tools with your data:

### Input Data
```
T1w Image: /data02/share/bin-wu/data/human/brain/harvard_mri/raw/new_england/ds006169-1.0.3/sub-01/ses-03/anat/sub-01_ses-03_T1w.nii.gz
JSON:      /data02/share/bin-wu/data/human/brain/harvard_mri/raw/new_england/ds006169-1.0.3/sub-01/ses-03/anat/sub-01_ses-03_T1w.json
```

### Setup for Jupyter Notebook

Edit the notebook's configuration cell:

```python
# Define paths (in cell 2 of notebook)
INPUT_T1W = "/data02/share/bin-wu/data/human/brain/harvard_mri/raw/new_england/ds006169-1.0.3/sub-01/ses-03/anat/sub-01_ses-03_T1w.nii.gz"
INPUT_JSON = "/data02/share/bin-wu/data/human/brain/harvard_mri/raw/new_england/ds006169-1.0.3/sub-01/ses-03/anat/sub-01_ses-03_T1w.json"

SUBJECTS_DIR = "/data02/share/bin-wu/data/human/brain/harvard_mri/processed/freesurfer"
SUBJECT_ID = "sub-01_ses-03"
```

### Running the Pipeline with Visualization

```bash
# 1. Set up FreeSurfer environment
export FREESURFER_HOME=/usr/local/freesurfer  # Adjust for your system
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export SUBJECTS_DIR=/data02/share/bin-wu/data/human/brain/harvard_mri/processed/freesurfer

# 2. Import T1w to FreeSurfer
recon-all -i /data02/share/bin-wu/data/human/brain/harvard_mri/raw/new_england/ds006169-1.0.3/sub-01/ses-03/anat/sub-01_ses-03_T1w.nii.gz \
          -subjid sub-01_ses-03 \
          -sd $SUBJECTS_DIR

# 3. Visualize input
python visualize_pipeline_outputs.py $SUBJECTS_DIR sub-01_ses-03

# 4. Run pipeline (adjust age in months)
bash reFS_iFS_only_no_matlab.sh sub-01_ses-03 6

# 5. Visualize outputs after each major step
# After initial FS processing:
python visualize_pipeline_outputs.py $SUBJECTS_DIR sub-01_ses-03

# After iFS processing:
python visualize_pipeline_outputs.py $SUBJECTS_DIR sub-01_ses-03

# After final processing:
python visualize_pipeline_outputs.py $SUBJECTS_DIR sub-01_ses-03
```

## Installation

### Python Dependencies

```bash
# Create virtual environment (recommended)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements_notebook.txt
```

### Required Packages

- **nibabel**: Read/write neuroimaging files
- **nilearn**: Neuroimaging visualization
- **numpy**: Numerical operations
- **matplotlib**: Plotting
- **pandas**: Data manipulation
- **jupyter**: Interactive notebooks

## Files Visualized

The visualization tools will check for and visualize these files:

| File | Description | Pipeline Step |
|------|-------------|---------------|
| `mri/orig.mgz` | Original T1w image | Input |
| `mri/T1.mgz` | Normalized T1w | FS processing |
| `mri/brainmask.mgz` | Skull-stripped brain | FS processing |
| `mri/aseg.presurf.mgz` | Tissue segmentation | iFS + remapping |
| `mri/wm.mgz` | White matter mask | WM generation |
| `surf/lh.white` | Left white surface | Surface recon |
| `surf/rh.white` | Right white surface | Surface recon |
| `surf/lh.pial` | Left pial surface | Surface recon |
| `surf/rh.pial` | Right pial surface | Surface recon |

## Understanding the Visualizations

### Anatomical Images (orig.mgz, T1.mgz, brainmask.mgz)

- **Grayscale**: Shows brain anatomy
- **Three views**: Sagittal (left/right), Coronal (front/back), Axial (top/bottom)
- **What to check**:
  - Proper orientation
  - Image quality (no artifacts)
  - Complete brain coverage
  - Proper skull stripping (for brainmask.mgz)

### Segmentation Images (aseg.presurf.mgz, wm.mgz)

- **Color-coded**: Different colors = different brain regions
- **Three views**: Sagittal, Coronal, Axial
- **What to check**:
  - Accurate tissue boundaries (GM/WM/CSF)
  - Proper subcortical structure identification
  - No obvious errors or misclassifications

### Label Statistics

The scripts print statistics about segmentation labels:
- Number of unique labels found
- Voxel counts per label
- Label value ranges

## Quality Control Checklist

After visualization, check these items:

### ✓ Input Quality
- [ ] T1w image has good contrast
- [ ] No major motion artifacts
- [ ] Complete brain coverage
- [ ] Proper orientation

### ✓ Skull Stripping (brainmask.mgz)
- [ ] All skull removed
- [ ] No dura included
- [ ] Cerebellum included
- [ ] No brain tissue removed

### ✓ Tissue Segmentation (aseg.presurf.mgz)
- [ ] GM/WM boundary looks accurate
- [ ] Subcortical structures properly identified
- [ ] Ventricles properly segmented
- [ ] No major errors visible

### ✓ White Matter (wm.mgz)
- [ ] WM mask covers expected regions
- [ ] Clean boundaries
- [ ] No holes or gaps

### ✓ Surfaces (if available)
- [ ] Smooth topology
- [ ] Follows tissue boundaries
- [ ] No self-intersections
- [ ] Complete coverage

## Troubleshooting

### Problem: "Module not found" errors

**Solution**: Install dependencies
```bash
pip install -r requirements_notebook.txt
```

### Problem: "File not found" errors

**Solution**:
1. Check that the pipeline has run for this subject
2. Verify SUBJECTS_DIR is set correctly
3. Check that subject_id matches directory name

### Problem: Blank or black images

**Solution**:
1. Check that .mgz files are not corrupted
2. Try loading with nibabel directly:
   ```python
   import nibabel as nib
   img = nib.load('path/to/file.mgz')
   print(img.header)
   ```

### Problem: Jupyter kernel crashes

**Solution**:
1. Large files may cause memory issues
2. Try the standalone Python script instead
3. Reduce image resolution in plotting functions

## Advanced Usage

### Custom Visualization Function

```python
import nibabel as nib
import matplotlib.pyplot as plt

def quick_check(filepath):
    """Quick visualization of any .mgz file."""
    img = nib.load(filepath)
    data = img.get_fdata()

    plt.figure(figsize=(15, 5))

    plt.subplot(1, 3, 1)
    plt.imshow(data[data.shape[0]//2, :, :].T, cmap='gray')
    plt.title('Sagittal')
    plt.axis('off')

    plt.subplot(1, 3, 2)
    plt.imshow(data[:, data.shape[1]//2, :].T, cmap='gray')
    plt.title('Coronal')
    plt.axis('off')

    plt.subplot(1, 3, 3)
    plt.imshow(data[:, :, data.shape[2]//2].T, cmap='gray')
    plt.title('Axial')
    plt.axis('off')

    plt.tight_layout()
    plt.show()

# Usage
quick_check('/path/to/subject/mri/T1.mgz')
```

### Batch Visualization

```python
import os
from pathlib import Path

subjects_dir = Path('/data/freesurfer')
subjects = ['sub-01', 'sub-02', 'sub-03']

for subject in subjects:
    print(f"Processing {subject}...")
    os.system(f"python visualize_pipeline_outputs.py {subjects_dir} {subject} --output /output/{subject}")
```

## Additional Resources

### FreeSurfer Visualization Tools

For more advanced visualization, use FreeSurfer's built-in tools:

```bash
# Interactive 3D viewer
freeview -v mri/T1.mgz mri/aseg.mgz:colormap=lut:opacity=0.3

# View surfaces
freeview -v mri/T1.mgz -f surf/lh.white:edgecolor=yellow surf/rh.white:edgecolor=yellow

# View both white and pial surfaces
freeview -v mri/T1.mgz \
         -f surf/lh.white:edgecolor=yellow surf/rh.white:edgecolor=yellow \
            surf/lh.pial:edgecolor=red surf/rh.pial:edgecolor=red
```

### Nilearn Documentation

For advanced neuroimaging visualization:
- Documentation: https://nilearn.github.io/
- Examples: https://nilearn.github.io/auto_examples/

### FreeSurfer QA Tools

FreeSurfer provides automated QA tools:
```bash
# Generate QA screenshots
recon-all -subjid <subject> -qcache
```

## Contact

For questions about these visualization tools or the pipeline, please refer to the main README files.

## License

Same as parent repository.
