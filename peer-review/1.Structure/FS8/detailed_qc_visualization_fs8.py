#!/usr/bin/env python3
"""
FreeSurfer 8.1.0 Infant Processing - Detailed QC Visualization

This script provides comprehensive quality control visualization for
FreeSurfer 8.1.0 infant processing outputs.

Differences from FS7 version:
- No separate iFS directory (all in one location)
- No label remapping needed (FS8 uses standard labels)
- Simplified workflow and checks

Usage:
    python detailed_qc_visualization_fs8.py <subjects_dir> <subject_id> [--output <output_dir>]

Example:
    python detailed_qc_visualization_fs8.py /data/freesurfer sub-01_ses-03
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


class PipelineQC_FS8:
    """Quality control for FreeSurfer 8.1.0 infant processing."""

    def __init__(self, subjects_dir, subject_id, output_dir=None):
        self.subjects_dir = Path(subjects_dir)
        self.subject_id = subject_id
        self.subject_path = self.subjects_dir / subject_id

        if output_dir:
            self.output_dir = Path(output_dir)
        else:
            self.output_dir = self.subject_path / 'qc_detailed_fs8'

        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.qc_results = {
            'freesurfer_version': '8.1.0',
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

        # Signal-to-noise ratio estimation
        foreground = img_data[img_data > metrics['mean'] * 0.1]
        if len(foreground) > 0:
            metrics['snr_estimate'] = float(np.mean(foreground) / np.std(foreground))
        else:
            metrics['snr_estimate'] = 0.0

        metrics['contrast'] = float(metrics['max'] - metrics['min'])

        return metrics

    def visualize_processing_stages(self):
        """Visualize all FreeSurfer 8.1.0 processing stages."""
        print("\n" + "=" * 80)
        print("FREESURFER 8.1.0 INFANT PROCESSING - Quality Control")
        print("=" * 80)

        mri_dir = self.subject_path / 'mri'

        # Stage 1: Original
        print("\n[1] Original Image (orig.mgz)")
        orig_file = mri_dir / 'orig.mgz'
        if orig_file.exists():
            orig_img = nib.load(orig_file)
            orig_data = orig_img.get_fdata()

            metrics = self.check_image_quality(orig_data, 'orig.mgz')
            print(f"  Shape: {orig_data.shape}")
            print(f"  Voxel size: {orig_img.header.get_zooms()[:3]} mm")
            print(f"  Intensity range: {metrics['min']:.1f} - {metrics['max']:.1f}")
            print(f"  SNR estimate: {metrics['snr_estimate']:.2f}")

            self.plot_volume_3view(orig_data, 'Original Image (orig.mgz)',
                                  '01_orig.png')
            self.log_check('orig.mgz', 'PASS', 'Original image loaded')
        else:
            print("  ✗ orig.mgz not found")
            self.log_check('orig.mgz', 'ERROR', 'File not found')
            return

        # Stage 2: Bias corrected
        print("\n[2] Bias Corrected (nu.mgz)")
        nu_file = mri_dir / 'nu.mgz'
        if nu_file.exists():
            nu_img = nib.load(nu_file)
            nu_data = nu_img.get_fdata()

            metrics = self.check_image_quality(nu_data, 'nu.mgz')
            print(f"  Intensity range: {metrics['min']:.1f} - {metrics['max']:.1f}")
            print(f"  Mean: {metrics['mean']:.1f}, Std: {metrics['std']:.1f}")

            self.plot_volume_3view(nu_data, 'Bias Corrected (nu.mgz)',
                                  '02_nu.png')
            self.plot_comparison(orig_data, nu_data,
                               'Original', 'Bias Corrected',
                               '02_orig_vs_nu.png')

            if metrics['std'] < 20:
                self.log_check('nu.mgz normalization', 'WARNING',
                             f'Low intensity variance: {metrics["std"]:.1f}')
            else:
                self.log_check('nu.mgz', 'PASS', 'Bias correction completed')
        else:
            print("  ⚠ nu.mgz not found (may not be generated yet)")

        # Stage 3: T1 normalized
        print("\n[3] T1 Normalized (T1.mgz)")
        t1_file = mri_dir / 'T1.mgz'
        if t1_file.exists():
            t1_img = nib.load(t1_file)
            t1_data = t1_img.get_fdata()

            metrics = self.check_image_quality(t1_data, 'T1.mgz')
            print(f"  Intensity range: {metrics['min']:.1f} - {metrics['max']:.1f}")
            print(f"  SNR estimate: {metrics['snr_estimate']:.2f}")

            self.plot_volume_3view(t1_data, 'T1 Normalized (T1.mgz)',
                                  '03_T1.png')

            if nu_file.exists():
                self.plot_comparison(nu_data, t1_data,
                                   'nu.mgz', 'T1.mgz',
                                   '03_nu_vs_T1.png')

            self.log_check('T1.mgz', 'PASS', 'T1 normalization completed')
        else:
            print("  ✗ T1.mgz not found")
            self.log_check('T1.mgz', 'ERROR', 'T1 file not found')
            return

        # Stage 4: Brain mask
        print("\n[4] Brain Mask (brainmask.mgz)")
        brainmask_file = mri_dir / 'brainmask.mgz'
        if brainmask_file.exists():
            brainmask_img = nib.load(brainmask_file)
            brainmask_data = brainmask_img.get_fdata()

            brain_voxels = np.sum(brainmask_data > 0)
            brain_volume_ml = brain_voxels * np.prod(brainmask_img.header.get_zooms()[:3]) / 1000

            print(f"  Brain voxels: {brain_voxels:,}")
            print(f"  Brain volume: {brain_volume_ml:.1f} ml")

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
                                  '04_brainmask.png')
            self.plot_volume_3view(t1_data, 'T1 with Brain Mask Overlay',
                                  '04_T1_with_brainmask.png',
                                  overlay_data=brainmask_data,
                                  overlay_alpha=0.3)
            self.log_check('brainmask.mgz', 'PASS', 'Brain mask created')
        else:
            print("  ✗ brainmask.mgz not found")
            self.log_check('brainmask.mgz', 'ERROR', 'Brain mask not found')

        # Stage 5: Segmentation (KEY FOR FS8 - uses standard labels)
        print("\n[5] Segmentation (aseg.mgz) - FreeSurfer 8 Format")
        aseg_file = mri_dir / 'aseg.mgz'
        if aseg_file.exists():
            aseg_img = nib.load(aseg_file)
            aseg_data = aseg_img.get_fdata()

            unique_labels = np.unique(aseg_data[aseg_data > 0])
            print(f"  Number of labels: {len(unique_labels)}")
            print(f"  Label range: {aseg_data.min():.0f} - {aseg_data.max():.0f}")

            # Check for key structures (FS8 uses standard labels)
            key_labels = {
                2: 'Left Cerebral White Matter',
                41: 'Right Cerebral White Matter',
                3: 'Left Cerebral Cortex',
                42: 'Right Cerebral Cortex',
                10: 'Left Thalamus (FS8 standard)',  # Note: 10 not 9!
                49: 'Right Thalamus (FS8 standard)', # Note: 49 not 48!
                11: 'Left Caudate',
                50: 'Right Caudate',
                12: 'Left Putamen',
                51: 'Right Putamen'
            }

            print("\n  Key structures (FS8 standard labels):")
            for label, name in key_labels.items():
                count = np.sum(aseg_data == label)
                status = "✓" if count > 0 else "✗"
                print(f"    {status} Label {label:2d}: {name:35s} ({count:6d} voxels)")

                if count == 0 and label in [2, 41, 3, 42]:
                    self.log_check(f'aseg label {label}', 'WARNING',
                                 f'{name} not found')

            # Check for old iFS labels (shouldn't be present in FS8)
            old_labels = {9: 'Old iFS left thalamus', 48: 'Old iFS right thalamus'}
            print("\n  Checking for old iFS labels (should be 0 in FS8):")
            for label, name in old_labels.items():
                count = np.sum(aseg_data == label)
                if count > 0:
                    print(f"    ✗ Label {label}: {name} - {count} voxels (SHOULD BE 0!)")
                    self.log_check(f'old label {label}', 'ERROR',
                                 f'Old iFS label {label} present ({count} voxels). FS8 should use standard labels.')
                else:
                    print(f"    ✓ Label {label}: {name} - 0 voxels (correct)")

            self.plot_volume_3view(aseg_data, 'Segmentation (aseg.mgz - FS8)',
                                  '05_aseg.png', cmap='tab20')
            self.plot_volume_3view(t1_data, 'T1 with Segmentation Overlay',
                                  '05_T1_with_aseg.png',
                                  overlay_data=aseg_data,
                                  overlay_alpha=0.4)
            self.log_check('aseg.mgz', 'PASS',
                         f'FS8 segmentation: {len(unique_labels)} labels')
        else:
            print("  ✗ aseg.mgz not found")
            self.log_check('aseg.mgz', 'ERROR', 'Segmentation not found')

        # Stage 6: White matter
        print("\n[6] White Matter (wm.mgz)")
        wm_file = mri_dir / 'wm.mgz'
        if wm_file.exists():
            wm_img = nib.load(wm_file)
            wm_data = wm_img.get_fdata()

            unique_values = np.unique(wm_data)
            print(f"  Unique values: {unique_values}")

            wm_110 = np.sum(wm_data == 110)
            gm_250 = np.sum(wm_data == 250)
            other = np.sum((wm_data > 0) & (wm_data != 110) & (wm_data != 250))

            print(f"\n  Label counts:")
            print(f"    110 (WM):    {wm_110:8d} voxels")
            print(f"    250 (GM):    {gm_250:8d} voxels")
            print(f"    Other:       {other:8d} voxels")

            if wm_110 == 0:
                self.log_check('wm.mgz WM', 'ERROR', 'No WM voxels (110)')
            elif gm_250 == 0:
                self.log_check('wm.mgz GM', 'ERROR', 'No GM voxels (250)')
            elif other > 0:
                self.log_check('wm.mgz', 'WARNING',
                             f'Unexpected values: {other} voxels')
            else:
                self.log_check('wm.mgz', 'PASS', 'White matter file correct')

            wm_colored = np.zeros_like(wm_data)
            wm_colored[wm_data == 110] = 1
            wm_colored[wm_data == 250] = 2

            self.plot_volume_3view(wm_colored, 'White Matter (wm.mgz)',
                                  '06_wm.png', cmap='Set1', vmin=0, vmax=2)
            self.plot_volume_3view(t1_data, 'T1 with WM Overlay',
                                  '06_T1_with_wm.png',
                                  overlay_data=wm_data,
                                  overlay_alpha=0.3)
        else:
            print("  ⚠ wm.mgz not found (may not be generated yet)")

        # Check surfaces
        self.check_surfaces()

    def check_surfaces(self):
        """Check surface files."""
        print("\n[7] Surface Files")
        surf_dir = self.subject_path / 'surf'

        surface_files = [
            ('lh.white', 'Left White Surface'),
            ('rh.white', 'Right White Surface'),
            ('lh.pial', 'Left Pial Surface'),
            ('rh.pial', 'Right Pial Surface'),
            ('lh.inflated', 'Left Inflated'),
            ('rh.inflated', 'Right Inflated'),
        ]

        for filename, description in surface_files:
            filepath = surf_dir / filename
            exists = filepath.exists()
            status = "✓" if exists else "✗"
            size = filepath.stat().st_size if exists else 0

            print(f"  {status} {description:25s}: {filename:15s} ({size:,} bytes)")

            if exists and size < 1000:
                self.log_check(f'Surface: {filename}', 'WARNING',
                             f'Surface file very small: {size} bytes')
            elif exists:
                self.log_check(f'Surface: {filename}', 'PASS', 'Surface exists')

        # Check Euler numbers
        for hemi in ['lh', 'rh']:
            # Try different possible locations
            euler_files = [
                surf_dir / f'{hemi}.euler',
                surf_dir / f'{hemi}.orig.euler',
                surf_dir / f'{hemi}.orig.nofix.euler'
            ]

            euler_found = False
            for euler_file in euler_files:
                if euler_file.exists():
                    with open(euler_file, 'r') as f:
                        try:
                            euler = f.read().strip()
                            print(f"\n  {hemi.upper()} Topology (Euler): {euler}")
                            euler_val = int(euler)
                            if euler_val == 2:
                                self.log_check(f'{hemi} topology', 'PASS',
                                             'Perfect topology (Euler=2)')
                            else:
                                holes = (2 - euler_val) // 2
                                self.log_check(f'{hemi} topology', 'WARNING',
                                             f'~{holes} defects (Euler={euler_val})')
                            euler_found = True
                            break
                        except:
                            pass

            if not euler_found:
                print(f"  ⚠ {hemi.upper()} Euler number not found")

    def generate_summary_report(self):
        """Generate summary QC report."""
        print("\n" + "=" * 80)
        print("QUALITY CONTROL SUMMARY - FreeSurfer 8.1.0")
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
        report_file = self.output_dir / 'qc_report_fs8.json'
        with open(report_file, 'w') as f:
            json.dump(self.qc_results, f, indent=2)

        print(f"\n✓ QC report saved: {report_file}")
        print(f"✓ Visualizations saved to: {self.output_dir}")

        return errors == 0

    def run_full_qc(self):
        """Run complete QC pipeline."""
        print("=" * 80)
        print("FreeSurfer 8.1.0 Infant Processing - Quality Control")
        print("=" * 80)
        print(f"\nSubject: {self.subject_id}")
        print(f"Subject directory: {self.subject_path}")
        print(f"Output directory: {self.output_dir}")

        if not self.subject_path.exists():
            print(f"\nERROR: Subject directory not found: {self.subject_path}")
            return False

        self.visualize_processing_stages()
        success = self.generate_summary_report()

        return success


def main():
    parser = argparse.ArgumentParser(
        description="FreeSurfer 8.1.0 infant processing quality control",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('subjects_dir', help='FreeSurfer SUBJECTS_DIR')
    parser.add_argument('subject_id', help='Subject identifier')
    parser.add_argument('--output', '-o', help='Output directory for QC images')

    args = parser.parse_args()

    qc = PipelineQC_FS8(args.subjects_dir, args.subject_id, args.output)
    success = qc.run_full_qc()

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
