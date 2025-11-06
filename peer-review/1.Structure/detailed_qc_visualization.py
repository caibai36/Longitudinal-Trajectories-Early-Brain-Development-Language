#!/usr/bin/env python3
"""
Detailed Pipeline Quality Control Script

This script provides comprehensive visualization of ALL intermediate files
in the infant brain processing pipeline with quality control metrics.

Usage:
    python detailed_qc_visualization.py <subjects_dir> <subject_id> [--ifs-dir <ifs_dir>]

Features:
    - Visualizes every intermediate processing file
    - Checks registration quality with overlays
    - Provides quantitative QC metrics
    - Detects common processing errors
    - Generates comprehensive QC report
"""

import os
import sys
import argparse
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from pathlib import Path
import json


class PipelineQC:
    """Quality control for infant brain processing pipeline."""

    def __init__(self, subjects_dir, subject_id, ifs_dir=None, output_dir=None):
        self.subjects_dir = Path(subjects_dir)
        self.subject_id = subject_id
        self.subject_path = self.subjects_dir / subject_id

        if ifs_dir:
            self.ifs_path = Path(ifs_dir) / subject_id
        else:
            self.ifs_path = self.subjects_dir.parent / 'iFS' / subject_id

        if output_dir:
            self.output_dir = Path(output_dir)
        else:
            self.output_dir = self.subject_path / 'qc_detailed'

        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.qc_results = {
            'subject_id': subject_id,
            'checks': [],
            'errors': [],
            'warnings': []
        }

    def log_check(self, check_name, status, message=""):
        """Log QC check result."""
        self.qc_results['checks'].append({
            'name': check_name,
            'status': status,
            'message': message
        })

        if status == 'ERROR':
            self.qc_results['errors'].append(f"{check_name}: {message}")
        elif status == 'WARNING':
            self.qc_results['warnings'].append(f"{check_name}: {message}")

    def plot_volume_3view(self, img_data, title, save_name, cmap='gray',
                          vmin=None, vmax=None, overlay_data=None, overlay_alpha=0.3):
        """Plot 3 orthogonal views of a volume with optional overlay."""
        fig, axes = plt.subplots(1, 3, figsize=(15, 5))

        mid_sag = img_data.shape[0] // 2
        mid_cor = img_data.shape[1] // 2
        mid_axi = img_data.shape[2] // 2

        views = [
            (img_data[mid_sag, :, :].T, 'Sagittal'),
            (img_data[:, mid_cor, :].T, 'Coronal'),
            (img_data[:, :, mid_axi].T, 'Axial')
        ]

        if overlay_data is not None:
            overlay_views = [
                overlay_data[mid_sag, :, :].T,
                overlay_data[:, mid_cor, :].T,
                overlay_data[:, :, mid_axi].T
            ]

        for idx, (view, view_name) in enumerate(views):
            axes[idx].imshow(view, cmap=cmap, origin='lower', vmin=vmin, vmax=vmax)

            if overlay_data is not None:
                axes[idx].imshow(overlay_views[idx], cmap='hot', alpha=overlay_alpha,
                               origin='lower')

            axes[idx].set_title(view_name, fontsize=12, fontweight='bold')
            axes[idx].axis('off')

        plt.suptitle(title, fontsize=14, fontweight='bold')
        plt.tight_layout()
        plt.savefig(self.output_dir / save_name, dpi=150, bbox_inches='tight')
        plt.close()

        print(f"  ✓ Saved: {save_name}")

    def plot_comparison(self, img1_data, img2_data, title1, title2, save_name):
        """Plot two volumes side by side for comparison."""
        fig = plt.figure(figsize=(15, 10))
        gs = GridSpec(2, 3, figure=fig)

        mid_sag = img1_data.shape[0] // 2
        mid_cor = img1_data.shape[1] // 2
        mid_axi = img1_data.shape[2] // 2

        # First image - row 0
        ax00 = fig.add_subplot(gs[0, 0])
        ax00.imshow(img1_data[mid_sag, :, :].T, cmap='gray', origin='lower')
        ax00.set_title(f'{title1}\nSagittal', fontsize=10)
        ax00.axis('off')

        ax01 = fig.add_subplot(gs[0, 1])
        ax01.imshow(img1_data[:, mid_cor, :].T, cmap='gray', origin='lower')
        ax01.set_title(f'{title1}\nCoronal', fontsize=10)
        ax01.axis('off')

        ax02 = fig.add_subplot(gs[0, 2])
        ax02.imshow(img1_data[:, :, mid_axi].T, cmap='gray', origin='lower')
        ax02.set_title(f'{title1}\nAxial', fontsize=10)
        ax02.axis('off')

        # Second image - row 1
        ax10 = fig.add_subplot(gs[1, 0])
        ax10.imshow(img2_data[mid_sag, :, :].T, cmap='gray', origin='lower')
        ax10.set_title(f'{title2}\nSagittal', fontsize=10)
        ax10.axis('off')

        ax11 = fig.add_subplot(gs[1, 1])
        ax11.imshow(img2_data[:, mid_cor, :].T, cmap='gray', origin='lower')
        ax11.set_title(f'{title2}\nCoronal', fontsize=10)
        ax11.axis('off')

        ax12 = fig.add_subplot(gs[1, 2])
        ax12.imshow(img2_data[:, :, mid_axi].T, cmap='gray', origin='lower')
        ax12.set_title(f'{title2}\nAxial', fontsize=10)
        ax12.axis('off')

        plt.suptitle('COMPARISON', fontsize=14, fontweight='bold')
        plt.tight_layout()
        plt.savefig(self.output_dir / save_name, dpi=150, bbox_inches='tight')
        plt.close()

        print(f"  ✓ Saved: {save_name}")

    def check_image_quality(self, img_data, img_name):
        """Calculate quality metrics for an image."""
        metrics = {}

        # Basic statistics
        metrics['mean'] = float(np.mean(img_data[img_data > 0]))
        metrics['std'] = float(np.std(img_data[img_data > 0]))
        metrics['min'] = float(np.min(img_data))
        metrics['max'] = float(np.max(img_data))
        metrics['percentile_99'] = float(np.percentile(img_data[img_data > 0], 99))

        # Signal-to-noise ratio estimation (simple)
        foreground = img_data[img_data > metrics['mean'] * 0.1]
        if len(foreground) > 0:
            metrics['snr_estimate'] = float(np.mean(foreground) / np.std(foreground))
        else:
            metrics['snr_estimate'] = 0.0

        # Contrast
        metrics['contrast'] = float(metrics['max'] - metrics['min'])

        return metrics

    def check_registration_quality(self, img1_data, img2_data):
        """Check alignment quality between two images."""
        # Resample if different sizes
        if img1_data.shape != img2_data.shape:
            return {'correlation': None, 'message': 'Different image dimensions'}

        # Calculate normalized cross-correlation
        img1_norm = (img1_data - np.mean(img1_data)) / np.std(img1_data)
        img2_norm = (img2_data - np.mean(img2_data)) / np.std(img2_data)

        correlation = float(np.corrcoef(img1_norm.flatten(), img2_norm.flatten())[0, 1])

        return {
            'correlation': correlation,
            'message': 'Good' if correlation > 0.7 else 'Poor' if correlation < 0.5 else 'Fair'
        }

    def visualize_autorecon1(self):
        """Visualize all autorecon1 outputs."""
        print("\n" + "=" * 80)
        print("STEP 1: AUTORECON1 - Motion Correction, Normalization, Skull Strip")
        print("=" * 80)

        mri_dir = self.subject_path / 'mri'

        # 1. Original image
        orig_file = mri_dir / 'orig.mgz'
        if orig_file.exists():
            print("\n[1.1] Original Image (orig.mgz)")
            orig_img = nib.load(orig_file)
            orig_data = orig_img.get_fdata()

            metrics = self.check_image_quality(orig_data, 'orig.mgz')
            print(f"  Shape: {orig_data.shape}")
            print(f"  Voxel size: {orig_img.header.get_zooms()[:3]} mm")
            print(f"  Intensity range: {metrics['min']:.1f} - {metrics['max']:.1f}")
            print(f"  SNR estimate: {metrics['snr_estimate']:.2f}")

            self.plot_volume_3view(orig_data, 'Original Image (orig.mgz)',
                                  '01_orig.png')
            self.log_check('orig.mgz', 'PASS', 'Original image loaded successfully')
        else:
            print("  ✗ orig.mgz not found")
            self.log_check('orig.mgz', 'ERROR', 'File not found')

        # 2. Motion-corrected (if rawavg exists)
        rawavg_file = mri_dir / 'rawavg.mgz'
        if rawavg_file.exists():
            print("\n[1.2] Motion Corrected (rawavg.mgz)")
            rawavg_img = nib.load(rawavg_file)
            rawavg_data = rawavg_img.get_fdata()

            self.plot_volume_3view(rawavg_data, 'Motion Corrected (rawavg.mgz)',
                                  '02_rawavg.png')

            if orig_file.exists():
                self.plot_comparison(orig_data, rawavg_data,
                                   'Original', 'Motion Corrected',
                                   '02_orig_vs_rawavg.png')
            self.log_check('rawavg.mgz', 'PASS', 'Motion correction completed')

        # 3. Intensity normalization - nu.mgz
        nu_file = mri_dir / 'nu.mgz'
        if nu_file.exists():
            print("\n[1.3] Intensity Normalized (nu.mgz)")
            nu_img = nib.load(nu_file)
            nu_data = nu_img.get_fdata()

            metrics = self.check_image_quality(nu_data, 'nu.mgz')
            print(f"  Intensity range: {metrics['min']:.1f} - {metrics['max']:.1f}")
            print(f"  Mean: {metrics['mean']:.1f}, Std: {metrics['std']:.1f}")

            self.plot_volume_3view(nu_data, 'Intensity Normalized (nu.mgz)',
                                  '03_nu.png')

            if orig_file.exists():
                self.plot_comparison(orig_data, nu_data,
                                   'Original', 'Normalized',
                                   '03_orig_vs_nu.png')

            # Check normalization quality
            if metrics['std'] < 20:
                self.log_check('nu.mgz normalization', 'WARNING',
                             f'Low intensity variance: {metrics["std"]:.1f}')
            else:
                self.log_check('nu.mgz', 'PASS', 'Intensity normalization completed')
        else:
            print("  ✗ nu.mgz not found")
            self.log_check('nu.mgz', 'WARNING', 'Normalization file not found')

        # 4. T1.mgz (further normalized)
        t1_file = mri_dir / 'T1.mgz'
        if t1_file.exists():
            print("\n[1.4] T1-weighted Normalized (T1.mgz)")
            t1_img = nib.load(t1_file)
            t1_data = t1_img.get_fdata()

            metrics = self.check_image_quality(t1_data, 'T1.mgz')
            print(f"  Intensity range: {metrics['min']:.1f} - {metrics['max']:.1f}")
            print(f"  SNR estimate: {metrics['snr_estimate']:.2f}")

            self.plot_volume_3view(t1_data, 'T1-weighted Normalized (T1.mgz)',
                                  '04_T1.png')

            if nu_file.exists():
                self.plot_comparison(nu_data, t1_data,
                                   'nu.mgz', 'T1.mgz',
                                   '04_nu_vs_T1.png')

            self.log_check('T1.mgz', 'PASS', 'T1 normalization completed')
        else:
            print("  ✗ T1.mgz not found")
            self.log_check('T1.mgz', 'ERROR', 'T1 file not found')

        # 5. Brain mask
        brainmask_file = mri_dir / 'brainmask.mgz'
        if brainmask_file.exists():
            print("\n[1.5] Brain Mask (brainmask.mgz)")
            brainmask_img = nib.load(brainmask_file)
            brainmask_data = brainmask_img.get_fdata()

            brain_voxels = np.sum(brainmask_data > 0)
            brain_volume_ml = brain_voxels * np.prod(brainmask_img.header.get_zooms()[:3]) / 1000

            print(f"  Brain voxels: {brain_voxels:,}")
            print(f"  Estimated brain volume: {brain_volume_ml:.1f} ml")

            # Check if brain volume is reasonable for infant
            if brain_volume_ml < 200:
                self.log_check('brainmask volume', 'WARNING',
                             f'Small brain volume: {brain_volume_ml:.1f} ml')
            elif brain_volume_ml > 2000:
                self.log_check('brainmask volume', 'WARNING',
                             f'Large brain volume: {brain_volume_ml:.1f} ml (may include skull)')
            else:
                self.log_check('brainmask volume', 'PASS',
                             f'Brain volume: {brain_volume_ml:.1f} ml')

            self.plot_volume_3view(brainmask_data, 'Brain Mask (brainmask.mgz)',
                                  '05_brainmask.png')

            # Overlay on T1
            if t1_file.exists():
                self.plot_volume_3view(t1_data, 'T1 with Brain Mask Overlay',
                                      '05_T1_with_brainmask.png',
                                      overlay_data=brainmask_data,
                                      overlay_alpha=0.3)
        else:
            print("  ✗ brainmask.mgz not found")
            self.log_check('brainmask.mgz', 'ERROR', 'Brain mask not found')

        # 6. Talairach registration
        talairach_file = self.subject_path / 'mri' / 'transforms' / 'talairach.xfm'
        if talairach_file.exists():
            print("\n[1.6] Talairach Registration")
            print(f"  ✓ Registration file exists: talairach.xfm")
            with open(talairach_file, 'r') as f:
                content = f.read()
                if 'Linear' in content:
                    print("  ✓ Linear registration matrix found")
                    self.log_check('talairach registration', 'PASS',
                                 'Registration completed')
                else:
                    self.log_check('talairach registration', 'WARNING',
                                 'Registration file format unexpected')
        else:
            print("  ✗ talairach.xfm not found")
            self.log_check('talairach registration', 'WARNING',
                         'Registration file not found')

        # 7. norm.mgz (after atlas registration)
        norm_file = mri_dir / 'norm.mgz'
        if norm_file.exists():
            print("\n[1.7] Atlas-Normalized (norm.mgz)")
            norm_img = nib.load(norm_file)
            norm_data = norm_img.get_fdata()

            self.plot_volume_3view(norm_data, 'Atlas-Normalized (norm.mgz)',
                                  '06_norm.png')

            if t1_file.exists():
                self.plot_comparison(t1_data, norm_data,
                                   'T1.mgz', 'norm.mgz',
                                   '06_T1_vs_norm.png')

            self.log_check('norm.mgz', 'PASS', 'Atlas normalization completed')

    def visualize_ifs_processing(self):
        """Visualize Infant FreeSurfer outputs."""
        print("\n" + "=" * 80)
        print("STEP 2: INFANT FREESURFER PROCESSING")
        print("=" * 80)

        if not self.ifs_path.exists():
            print(f"  ✗ iFS directory not found: {self.ifs_path}")
            self.log_check('iFS directory', 'ERROR', 'iFS directory not found')
            return

        ifs_mri = self.ifs_path / 'mri'

        # 1. iFS brain mask
        ifs_brainmask = ifs_mri / 'brainmask.mgz'
        if ifs_brainmask.exists():
            print("\n[2.1] iFS Brain Mask")
            ifs_brain_img = nib.load(ifs_brainmask)
            ifs_brain_data = ifs_brain_img.get_fdata()

            brain_voxels = np.sum(ifs_brain_data > 0)
            brain_volume_ml = brain_voxels * np.prod(ifs_brain_img.header.get_zooms()[:3]) / 1000
            print(f"  Brain volume: {brain_volume_ml:.1f} ml")

            self.plot_volume_3view(ifs_brain_data, 'iFS Brain Mask',
                                  '07_ifs_brainmask.png')
            self.log_check('iFS brainmask', 'PASS',
                         f'iFS brain mask volume: {brain_volume_ml:.1f} ml')

        # 2. iFS aseg (KEY OUTPUT)
        ifs_aseg = ifs_mri / 'aseg.mgz'
        if ifs_aseg.exists():
            print("\n[2.2] iFS Segmentation (aseg.mgz) - KEY OUTPUT")
            ifs_aseg_img = nib.load(ifs_aseg)
            ifs_aseg_data = ifs_aseg_img.get_fdata()

            unique_labels = np.unique(ifs_aseg_data[ifs_aseg_data > 0])
            print(f"  Number of labels: {len(unique_labels)}")
            print(f"  Label range: {ifs_aseg_data.min():.0f} - {ifs_aseg_data.max():.0f}")

            # Check for key structures
            key_labels = {
                2: 'Left Cerebral White Matter',
                41: 'Right Cerebral White Matter',
                3: 'Left Cerebral Cortex',
                42: 'Right Cerebral Cortex',
                9: 'Left Thalamus (iFS)',
                48: 'Right Thalamus (iFS)',
                11: 'Left Caudate',
                50: 'Right Caudate'
            }

            print("\n  Key structures found:")
            for label, name in key_labels.items():
                count = np.sum(ifs_aseg_data == label)
                status = "✓" if count > 0 else "✗"
                print(f"    {status} Label {label:2d}: {name:30s} ({count:6d} voxels)")

                if count == 0 and label in [2, 41, 3, 42]:
                    self.log_check(f'iFS label {label}', 'WARNING',
                                 f'{name} not found')

            self.plot_volume_3view(ifs_aseg_data, 'iFS Segmentation (aseg.mgz)',
                                  '08_ifs_aseg.png', cmap='tab20')

            # Overlay on original
            if (self.subject_path / 'mri' / 'T1.mgz').exists():
                t1_img = nib.load(self.subject_path / 'mri' / 'T1.mgz')
                t1_data = t1_img.get_fdata()

                # Resample if needed (simple check)
                if t1_data.shape == ifs_aseg_data.shape:
                    self.plot_volume_3view(t1_data, 'T1 with iFS Segmentation Overlay',
                                          '08_T1_with_ifs_aseg.png',
                                          overlay_data=ifs_aseg_data,
                                          overlay_alpha=0.4)

            self.log_check('iFS aseg', 'PASS',
                         f'iFS segmentation: {len(unique_labels)} labels')
        else:
            print("  ✗ iFS aseg.mgz not found")
            self.log_check('iFS aseg', 'ERROR', 'iFS segmentation not found')

    def visualize_label_remapping(self):
        """Visualize label remapping step."""
        print("\n" + "=" * 80)
        print("STEP 3: LABEL REMAPPING (iFS → FS compatibility)")
        print("=" * 80)

        aseg_presurf = self.subject_path / 'mri' / 'aseg.presurf.mgz'
        ifs_aseg = self.ifs_path / 'mri' / 'aseg.mgz'

        if not aseg_presurf.exists():
            print("  ✗ aseg.presurf.mgz not found - remapping not yet done")
            self.log_check('label remapping', 'WARNING',
                         'aseg.presurf.mgz not found')
            return

        print("\n[3.1] Remapped Segmentation (aseg.presurf.mgz)")
        aseg_pre_img = nib.load(aseg_presurf)
        aseg_pre_data = aseg_pre_img.get_fdata()

        # Check thalamus labels
        left_thal_old = np.sum(aseg_pre_data == 9)
        left_thal_new = np.sum(aseg_pre_data == 10)
        right_thal_old = np.sum(aseg_pre_data == 48)
        right_thal_new = np.sum(aseg_pre_data == 49)

        print(f"\n  Thalamus Label Check:")
        print(f"    Label  9 (iFS left):  {left_thal_old:6d} voxels {'' if left_thal_old == 0 else '(SHOULD BE 0)'}")
        print(f"    Label 10 (FS left):   {left_thal_new:6d} voxels {'' if left_thal_new > 0 else '(SHOULD EXIST)'}")
        print(f"    Label 48 (iFS right): {right_thal_old:6d} voxels {'' if right_thal_old == 0 else '(SHOULD BE 0)'}")
        print(f"    Label 49 (FS right):  {right_thal_new:6d} voxels {'' if right_thal_new > 0 else '(SHOULD EXIST)'}")

        # QC checks
        if left_thal_old > 0 or right_thal_old > 0:
            self.log_check('thalamus remapping', 'ERROR',
                         'Old thalamus labels (9, 48) still present')
        elif left_thal_new == 0 or right_thal_new == 0:
            self.log_check('thalamus remapping', 'WARNING',
                         'New thalamus labels (10, 49) missing')
        else:
            self.log_check('thalamus remapping', 'PASS',
                         'Thalamus labels correctly remapped')

        self.plot_volume_3view(aseg_pre_data,
                              'Remapped Segmentation (aseg.presurf.mgz)',
                              '09_aseg_presurf.png', cmap='tab20')

        # Compare with iFS aseg if available
        if ifs_aseg.exists():
            ifs_aseg_img = nib.load(ifs_aseg)
            ifs_aseg_data = ifs_aseg_img.get_fdata()

            if ifs_aseg_data.shape == aseg_pre_data.shape:
                diff = np.sum(ifs_aseg_data != aseg_pre_data)
                total = np.prod(aseg_pre_data.shape)
                percent = (diff / total) * 100

                print(f"\n  Comparison with iFS aseg:")
                print(f"    Different voxels: {diff:,} ({percent:.2f}%)")
                print(f"    Expected: ~0.1-1% (only thalamus labels changed)")

                if percent > 5:
                    self.log_check('aseg comparison', 'WARNING',
                                 f'Large difference from iFS aseg: {percent:.2f}%')

                self.plot_comparison(ifs_aseg_data, aseg_pre_data,
                                   'iFS aseg (original)', 'aseg.presurf (remapped)',
                                   '09_ifs_vs_remapped.png')

    def visualize_wm_generation(self):
        """Visualize white matter generation."""
        print("\n" + "=" * 80)
        print("STEP 4: WHITE MATTER GENERATION")
        print("=" * 80)

        wm_file = self.subject_path / 'mri' / 'wm.mgz'
        aseg_file = self.subject_path / 'mri' / 'aseg.presurf.mgz'

        if not wm_file.exists():
            print("  ✗ wm.mgz not found")
            self.log_check('wm.mgz', 'ERROR', 'White matter file not found')
            return

        print("\n[4.1] White Matter File (wm.mgz)")
        wm_img = nib.load(wm_file)
        wm_data = wm_img.get_fdata()

        # Check label values
        unique_values = np.unique(wm_data)
        print(f"  Unique values in wm.mgz: {unique_values}")

        wm_110 = np.sum(wm_data == 110)
        gm_250 = np.sum(wm_data == 250)
        other = np.sum((wm_data > 0) & (wm_data != 110) & (wm_data != 250))

        print(f"\n  Label counts:")
        print(f"    110 (WM):    {wm_110:8d} voxels")
        print(f"    250 (GM):    {gm_250:8d} voxels")
        print(f"    Other:       {other:8d} voxels")

        if wm_110 == 0:
            self.log_check('wm.mgz WM label', 'ERROR', 'No WM voxels (110) found')
        elif gm_250 == 0:
            self.log_check('wm.mgz GM label', 'ERROR', 'No GM voxels (250) found')
        elif other > 0:
            self.log_check('wm.mgz labels', 'WARNING',
                         f'Unexpected label values found: {other} voxels')
        else:
            self.log_check('wm.mgz', 'PASS', 'White matter file correct')

        # Create color-coded visualization
        wm_colored = np.zeros_like(wm_data)
        wm_colored[wm_data == 110] = 1  # WM
        wm_colored[wm_data == 250] = 2  # GM

        self.plot_volume_3view(wm_colored, 'White Matter File (wm.mgz)',
                              '10_wm.png', cmap='Set1', vmin=0, vmax=2)

        # Show with T1
        t1_file = self.subject_path / 'mri' / 'T1.mgz'
        if t1_file.exists():
            t1_img = nib.load(t1_file)
            t1_data = t1_img.get_fdata()

            self.plot_volume_3view(t1_data, 'T1 with WM Overlay',
                                  '10_T1_with_wm.png',
                                  overlay_data=wm_data,
                                  overlay_alpha=0.3)

        # Compare with aseg
        if aseg_file.exists():
            aseg_img = nib.load(aseg_file)
            aseg_data = aseg_img.get_fdata()

            self.plot_comparison(aseg_data, wm_data,
                               'aseg.presurf', 'wm.mgz',
                               '10_aseg_vs_wm.png')

    def visualize_surfaces(self):
        """Check for surface files (basic check)."""
        print("\n" + "=" * 80)
        print("STEP 5: SURFACE RECONSTRUCTION")
        print("=" * 80)

        surf_dir = self.subject_path / 'surf'

        surface_files = [
            ('lh.orig.nofix', 'Left Original Surface'),
            ('rh.orig.nofix', 'Right Original Surface'),
            ('lh.orig', 'Left Original (fixed)'),
            ('rh.orig', 'Right Original (fixed)'),
            ('lh.white', 'Left White Surface'),
            ('rh.white', 'Right White Surface'),
            ('lh.pial', 'Left Pial Surface'),
            ('rh.pial', 'Right Pial Surface'),
            ('lh.inflated', 'Left Inflated'),
            ('rh.inflated', 'Right Inflated'),
        ]

        print("\n[5.1] Surface File Check:")
        for filename, description in surface_files:
            filepath = surf_dir / filename
            exists = filepath.exists()
            status = "✓" if exists else "✗"
            size = filepath.stat().st_size if exists else 0

            print(f"  {status} {description:25s}: {filename:20s} ({size:,} bytes)")

            if exists and size < 1000:
                self.log_check(f'Surface: {filename}', 'WARNING',
                             f'Surface file very small: {size} bytes')
            elif exists:
                self.log_check(f'Surface: {filename}', 'PASS',
                             f'Surface file exists')

        # Check for Euler numbers (topology)
        for hemi in ['lh', 'rh']:
            euler_file = surf_dir / f'{hemi}.orig.nofix.euler'
            if euler_file.exists():
                with open(euler_file, 'r') as f:
                    euler = f.read().strip()
                    print(f"\n  {hemi.upper()} Topology (Euler number): {euler}")
                    # Euler = 2 is perfect sphere (no holes)
                    try:
                        euler_val = int(euler)
                        if euler_val == 2:
                            self.log_check(f'{hemi} topology', 'PASS',
                                         'Perfect topology (Euler=2)')
                        else:
                            holes = (2 - euler_val) // 2
                            self.log_check(f'{hemi} topology', 'WARNING',
                                         f'Topology has ~{holes} defects (Euler={euler_val})')
                    except:
                        pass

    def generate_summary_report(self):
        """Generate summary QC report."""
        print("\n" + "=" * 80)
        print("QUALITY CONTROL SUMMARY")
        print("=" * 80)

        print(f"\nSubject: {self.subject_id}")
        print(f"Total checks: {len(self.qc_results['checks'])}")

        passed = sum(1 for c in self.qc_results['checks'] if c['status'] == 'PASS')
        warnings = sum(1 for c in self.qc_results['checks'] if c['status'] == 'WARNING')
        errors = sum(1 for c in self.qc_results['checks'] if c['status'] == 'ERROR')

        print(f"\n✓ Passed:   {passed}")
        print(f"⚠ Warnings: {warnings}")
        print(f"✗ Errors:   {errors}")

        if errors > 0:
            print("\n" + "=" * 80)
            print("ERRORS FOUND:")
            print("=" * 80)
            for error in self.qc_results['errors']:
                print(f"  ✗ {error}")

        if warnings > 0:
            print("\n" + "=" * 80)
            print("WARNINGS:")
            print("=" * 80)
            for warning in self.qc_results['warnings']:
                print(f"  ⚠ {warning}")

        # Save JSON report
        report_file = self.output_dir / 'qc_report.json'
        with open(report_file, 'w') as f:
            json.dump(self.qc_results, f, indent=2)

        print(f"\n✓ Detailed QC report saved: {report_file}")
        print(f"✓ All visualizations saved to: {self.output_dir}")

        return errors == 0

    def run_full_qc(self):
        """Run complete QC pipeline."""
        print("=" * 80)
        print("DETAILED PIPELINE QUALITY CONTROL")
        print("=" * 80)
        print(f"\nSubject: {self.subject_id}")
        print(f"Subject directory: {self.subject_path}")
        print(f"iFS directory: {self.ifs_path}")
        print(f"Output directory: {self.output_dir}")

        self.visualize_autorecon1()
        self.visualize_ifs_processing()
        self.visualize_label_remapping()
        self.visualize_wm_generation()
        self.visualize_surfaces()

        success = self.generate_summary_report()

        return success


def main():
    parser = argparse.ArgumentParser(
        description="Detailed quality control for infant brain processing pipeline",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('subjects_dir', help='FreeSurfer SUBJECTS_DIR')
    parser.add_argument('subject_id', help='Subject identifier')
    parser.add_argument('--ifs-dir', help='Infant FreeSurfer directory (default: <subjects_dir>/../iFS)')
    parser.add_argument('--output', '-o', help='Output directory for QC images')

    args = parser.parse_args()

    qc = PipelineQC(args.subjects_dir, args.subject_id, args.ifs_dir, args.output)
    success = qc.run_full_qc()

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
