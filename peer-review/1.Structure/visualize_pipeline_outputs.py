#!/usr/bin/env python3
"""
Quick Pipeline Output Visualization Script

This script visualizes key outputs from the infant brain processing pipeline
at each processing stage.

Usage:
    python visualize_pipeline_outputs.py <subjects_dir> <subject_id>

Example:
    python visualize_pipeline_outputs.py /data/freesurfer sub-01_ses-03
"""

import os
import sys
import argparse
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt
from pathlib import Path


def plot_volume(img_data, title, save_path=None):
    """Plot orthogonal views of a 3D volume."""
    fig, axes = plt.subplots(1, 3, figsize=(15, 5))

    mid_sag = img_data.shape[0] // 2
    mid_cor = img_data.shape[1] // 2
    mid_axi = img_data.shape[2] // 2

    # Sagittal
    axes[0].imshow(img_data[mid_sag, :, :].T, cmap='gray', origin='lower')
    axes[0].set_title('Sagittal', fontsize=14)
    axes[0].axis('off')

    # Coronal
    axes[1].imshow(img_data[:, mid_cor, :].T, cmap='gray', origin='lower')
    axes[1].set_title('Coronal', fontsize=14)
    axes[1].axis('off')

    # Axial
    axes[2].imshow(img_data[:, :, mid_axi].T, cmap='gray', origin='lower')
    axes[2].set_title('Axial', fontsize=14)
    axes[2].axis('off')

    plt.suptitle(title, fontsize=16, fontweight='bold')
    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"  ✓ Saved: {save_path}")

    plt.show()


def plot_segmentation(seg_data, title, save_path=None):
    """Plot segmentation with color map."""
    fig, axes = plt.subplots(1, 3, figsize=(15, 5))

    mid_sag = seg_data.shape[0] // 2
    mid_cor = seg_data.shape[1] // 2
    mid_axi = seg_data.shape[2] // 2

    # Sagittal
    axes[0].imshow(seg_data[mid_sag, :, :].T, cmap='tab20', origin='lower')
    axes[0].set_title('Sagittal', fontsize=14)
    axes[0].axis('off')

    # Coronal
    axes[1].imshow(seg_data[:, mid_cor, :].T, cmap='tab20', origin='lower')
    axes[1].set_title('Coronal', fontsize=14)
    axes[1].axis('off')

    # Axial
    axes[2].imshow(seg_data[:, :, mid_axi].T, cmap='tab20', origin='lower')
    axes[2].set_title('Axial', fontsize=14)
    axes[2].axis('off')

    plt.suptitle(title, fontsize=16, fontweight='bold')
    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"  ✓ Saved: {save_path}")

    plt.show()

    # Print label statistics
    unique_labels = np.unique(seg_data[seg_data > 0])
    print(f"\n  Labels found: {len(unique_labels)}")
    print(f"  Label range: {seg_data.min():.0f} - {seg_data.max():.0f}")


def check_file_exists(filepath, description):
    """Check if file exists and print status."""
    exists = os.path.exists(filepath)
    status = "✓" if exists else "✗"
    print(f"  {status} {description:30s}: {os.path.basename(filepath)}")
    return exists


def visualize_pipeline(subjects_dir, subject_id, output_dir=None):
    """
    Visualize all pipeline outputs for a subject.

    Args:
        subjects_dir: Path to FreeSurfer SUBJECTS_DIR
        subject_id: Subject identifier
        output_dir: Directory to save output images (optional)
    """
    subject_path = Path(subjects_dir) / subject_id

    if not subject_path.exists():
        print(f"Error: Subject directory not found: {subject_path}")
        return

    if output_dir:
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
    else:
        output_dir = subject_path / 'visualizations'
        output_dir.mkdir(exist_ok=True)

    print("=" * 80)
    print(f"PIPELINE VISUALIZATION: {subject_id}")
    print("=" * 80)

    # Check which files exist
    print("\n📋 Checking Files...")
    print("-" * 80)

    files_to_check = {
        'orig.mgz': subject_path / 'mri' / 'orig.mgz',
        'T1.mgz': subject_path / 'mri' / 'T1.mgz',
        'brainmask.mgz': subject_path / 'mri' / 'brainmask.mgz',
        'aseg.presurf.mgz': subject_path / 'mri' / 'aseg.presurf.mgz',
        'wm.mgz': subject_path / 'mri' / 'wm.mgz',
    }

    available_files = {}
    for name, path in files_to_check.items():
        if check_file_exists(path, name):
            available_files[name] = path

    print()

    # Visualize each available file
    for name, path in available_files.items():
        print(f"\n{'=' * 80}")
        print(f"Visualizing: {name}")
        print('=' * 80)

        try:
            img = nib.load(str(path))
            data = img.get_fdata()

            print(f"  Shape: {data.shape}")
            print(f"  Voxel size: {img.header.get_zooms()[:3]} mm")
            print(f"  Data range: {data.min():.1f} - {data.max():.1f}")

            save_path = output_dir / f"{name.replace('.mgz', '.png')}"

            if 'aseg' in name or 'wm' in name:
                plot_segmentation(data, f"{name} - Segmentation", save_path)
            else:
                plot_volume(data, f"{name} - Anatomical Image", save_path)

        except Exception as e:
            print(f"  ⚠️ Error visualizing {name}: {e}")

    print("\n" + "=" * 80)
    print("VISUALIZATION COMPLETE")
    print("=" * 80)
    print(f"\nOutput directory: {output_dir}")

    # Generate QC checklist
    print("\n" + "=" * 80)
    print("QUALITY CONTROL CHECKLIST")
    print("=" * 80)
    print("""
    □ Check orig.mgz: Raw input looks correct
    □ Check T1.mgz: Normalized intensity looks good
    □ Check brainmask.mgz: Skull fully removed, brain complete
    □ Check aseg.presurf.mgz: Tissue segmentation looks accurate
    □ Check wm.mgz: White matter mask looks correct

    To view with FreeSurfer GUI:

      # View segmentation overlay
      freeview -v mri/T1.mgz mri/aseg.presurf.mgz:colormap=lut:opacity=0.3

      # View brain mask
      freeview -v mri/T1.mgz mri/brainmask.mgz:colormap=heat:opacity=0.3

      # View white matter
      freeview -v mri/T1.mgz mri/wm.mgz:colormap=jet:opacity=0.3
    """)


def main():
    parser = argparse.ArgumentParser(
        description="Visualize infant brain processing pipeline outputs",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Visualize outputs for a subject
  python visualize_pipeline_outputs.py /data/freesurfer sub-01_ses-03

  # Save to specific directory
  python visualize_pipeline_outputs.py /data/freesurfer sub-01_ses-03 --output /tmp/viz
        """
    )

    parser.add_argument('subjects_dir',
                        help='Path to FreeSurfer SUBJECTS_DIR')
    parser.add_argument('subject_id',
                        help='Subject identifier')
    parser.add_argument('--output', '-o',
                        help='Output directory for visualizations (optional)')

    args = parser.parse_args()

    visualize_pipeline(args.subjects_dir, args.subject_id, args.output)


if __name__ == '__main__':
    main()
