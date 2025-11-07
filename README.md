## Longitudinal-Trajectories-Early-Brain-Development-Language

This repository houses code (or links to code) used for the following study:

    Turesky et al. Longitudinal trajectories of brain development from infancy to school age and their relationship to literacy development

Broadly, the study involved structural and diffusion processing pipelines followed by statistical analyses. An inventory of the code used for each pipeline is provided below:

### 1. Structure:

    .
    ├── reFS.sh                                 <-- runs infant brain morphometry pipeline
        ├── iFS_wrap.sh                         <-- sets environmental variables for iFS and runs it *this file will need adjustments based on the user's compute setup
        ├── ibeat2aseg.m                        <-- merges iFS and iBEATv2.0 tissue segmentations
            ├── aseg_labels2coords.m            <-- converts aseg labels to coordinates
        ├── aseg2wm.m                           <-- generates FS white matter file using iBEATv2.0 segmentation
        ├── fs_autorecon2_end.sh                <-- runs FS autorecon2 with adjustments
        ├── fs_autorecon3_wrap.sh               <-- runs FS autorecon3 with adjustments, uses expert.opts file included
    ├── consol_stats.sh                         <-- consolidates structural estimates from FS 
    ├── struct_reorg.R                          <-- reorganizes structural estimates

Dependencies: iBEATv2.0 Docker, Infant FreeSurfer, FreeSurfer 7.3, Matlab  
Additional requirements:The folder containing the above scripts also need to be added to your shell PATH, iBEATv2.0 (https://github.com/iBEAT-V2/iBEAT-V2.0-Docker) segmentations need to be generated beforehand.  


### 2. Diffusion:

    .
    ├── dwi_proc_tck_gen_v2.sh                     <-- preprocesses data and runs fiber tracking, *uses eddy_cuda, which requires an slspec file be created in advance, please see FSL documentation
    ├── mrtrix2bids_sep.sh                         <-- reorganizes directory structure to prepare for py(Baby)AFQ
    ├── baby-pyafq-gen.py                          <-- runs tract segmentation for pyBabyAFQ, bids_path needs to be entered in file
    ├── pyafq-gen.py                               <-- runs tract segmenation for pyAFQ, bids_path needs to be entered in file
    ├── plot_viz_inf_cam_trk.py                    <-- visualizes tracts; code adapted from https://yeatmanlab.github.io/pyAFQ/
    ├── plot_viz_inf_cam_trk_core_nodes.py         <-- visualizes tract cores with significant nodes, code adapted from https://yeatmanlab.github.io/pyAFQ
    ├── consol_nodes.sh                            <-- consolidates diffusion estimates from py(Baby)AFQ
    ├── dwi_reorg.R                                <-- reorganizes diffusion estimates

Dependences: MRtrix3, FSL, ANTs, FreeSurfer, GCC libraries for LD_LIBRARY_PATH, pyAFQ  
Additional requirements: the folder containing the above scripts needs to be added to your shell PATH, our first script (indirectly) calls the cuda implementation of eddy, which also requires access to a GPU (we used Nvidia A100), FreeSurfer-style T1 segmentation need to be generated beforehand.


### 3. Statistics:

    .
    ├── longitudinal_model_control.R            <-- set paramaters for statistical analyses visualizations
        ├── long_mod_gen.R                      <-- runs linear models with linear, logarithmic, or quadratic functions - including data cleaning, curve fitting and visualizations, and associations with outcomes
        ├── asym_mod_gen.R                      <-- same as 'long_mod_gen.R' but for nonlinear model with asymptotic functions, leverages a subset of functions provided here: https://github.com/knickmeyer-lab/ORIGINs_ICV-and-Subcortical-volume-development-in-early-childhood
        ├── graph_labels_colors.R               <-- specifies colors used in graphs
        ├── gen_heatmap.R                       <-- runs heatmaps depicting covariate contributions to models
        ├── mod_ages_sages.R                    <-- centers and scales age variables if necessary 
        ├── compare_models.R                    <-- compares fits among longitudinal models (does not include asymptotic functions) or among models with versus without select covariates
        ├── long_model_report_stats.R           <-- generates and reports statistics corrected for multiple comparisons, for structural and average- or quarter-based diffusion analyses
        ├── diff_node_clust.R                   <-- generates and reports statistics corrected for multiple comparisons, for node-based diffusion analyses
        ├── brain_region_ggseg.R                <-- depicts significant brain regions, for structure only
        ├── long_mediate_covs.R                 <-- tests indirect effects between curve features of brain development and reading skills via literacy subskills
        ├── graph_all_meas_regs.R               <-- generates graph of average longitudinal trajectories by measure
        ├── long_graph.R                        <-- generates graph showing longitudinal sample
        ├── long_descriptive_stats.R            <-- reports descriptive stats for study
        ├── long_cov_beh_corr.R                 <-- tests and reports (partial) correlations among covariates and behavioral measures
        ├── gen_histograms_spec.R               <-- generates histograms for brain, behavioral, and demographic measures


Required packages: dplyr, reshape, stringr, ggplot2, ggseg, lm.beta, lme4, lmerTest, nlme, mediation, permuco
Additional requirements: asymptotic functions also require code supplied here: https://github.com/knickmeyer-lab/ORIGINs_ICV-and-Subcortical-volume-development-in-early-childhood.


---

## Alternative Pipelines: Simplified Infant FreeSurfer-Only

Alternative structural processing pipelines are available with reduced dependencies:

### FreeSurfer 7.3 Versions (Original Study Software)

#### Option 1: iFS-only (No iBEAT2, Requires MATLAB)
**Location**: `peer-review/1.Structure/README_iFS_only.md`

**Key files**:
- `reFS_iFS_only.sh` - Main pipeline script
- `iFS_aseg_process.m` - Processes iFS segmentation (MATLAB)
- `aseg2wm_iFS.m` - Generates white matter file (MATLAB)

**Dependencies**: Infant FreeSurfer, FreeSurfer 7.3, MATLAB

#### Option 2: iFS-only (No iBEAT2, No MATLAB)
**Location**: `peer-review/1.Structure/README_simplified_pipeline.md`

**Key files**:
- `reFS_iFS_only_no_matlab.sh` - Complete bash-only pipeline

**Dependencies**: Infant FreeSurfer, FreeSurfer 7.3 (that's it!)

**Advantages**:
- Pure bash/FreeSurfer command-line tools
- No MATLAB license required
- Easiest to install and run (FS7 version)
- Same functionality as MATLAB version

**Note**: Both FS7 simplified approaches may produce different segmentation results compared to the hybrid iBEAT2/iFS pipeline used in the published study.

### FreeSurfer 8.1.0 Version ⭐ NEW - SIMPLEST OPTION

#### Option 3: FreeSurfer 8.1.0 Integrated Infant Processing
**Location**: `peer-review/1.Structure/FS8/`

**Key files**:
- `FS8/README.md` - Quick start guide
- `FS8/README_FS8_INFANT_PIPELINE.md` - Complete documentation
- `FS8/reFS_fs8_infant.sh` - Main pipeline script (just 2 steps!)
- `FS8/detailed_qc_visualization_fs8.py` - QC tool
- `FS8/FS7_vs_FS8_COMPARISON.md` - Detailed comparison with FS7

**Dependencies**: FreeSurfer 8.1.0 **ONLY** (nothing else needed!)

**Advantages**:
- ✅ **Single installation** - No separate Infant FreeSurfer needed
- ✅ **Simplest workflow** - Just 2 commands instead of 10+ steps
- ✅ **No MATLAB** - Pure bash/FreeSurfer
- ✅ **No iBEAT2** - Self-contained
- ✅ **No label remapping** - Automatic (9→10, 48→49)
- ✅ **Cleaner structure** - One directory instead of two
- ✅ **Latest algorithms** - Updated processing methods (2023+)
- ✅ **Easier QC** - Simplified quality control

**When to use**:
- ✅ New projects / studies
- ✅ Want simplest possible workflow
- ✅ Learning / teaching
- ✅ Don't need exact replication of original study

**When NOT to use**:
- ❌ Need exact replication of original study
- ❌ Must match existing FS7 data
- ❌ Validation / regulatory requirements for specific version

**Quick comparison**:

| Feature | FS7 + iFS (bash) | FS8 |
|---------|------------------|-----|
| Installation | 2 systems | 1 system |
| Steps | 10+ steps | 2 steps |
| MATLAB | No | No |
| iBEAT2 | No | No |
| Complexity | Medium | **Very Low** |

See `FS8/README.md` for quick start or `FS8/README_FS8_INFANT_PIPELINE.md` for complete guide.
