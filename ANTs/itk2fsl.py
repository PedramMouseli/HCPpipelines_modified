#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Native Apple Silicon (ARM64) / cross-platform converter from ANTs / ITK affine transforms
to FSL FLIRT affine matrix format. Replaces c3d_affine_tool -ras2fsl.

Author: Moayedilab
"""

import sys
import argparse
import numpy as np
import scipy.io as sio
import nibabel as nib


def parse_itk_mat(itk_path):
    """
    Load an ITK affine transform from either a MATLAB binary .mat file
    or an ITK text transform file (.txt / .tfm).
    Returns:
        M (3x3 ndarray): Rotation/scaling matrix (LPS)
        offset (3 ndarray): Translation offset in LPS
    """
    try:
        mat = sio.loadmat(itk_path)
        # Find the AffineTransform key (can be float or double)
        affine_keys = [k for k in mat.keys() if "AffineTransform" in k]
        if not affine_keys:
            raise KeyError(f"No AffineTransform key found in {itk_path}. Keys: {list(mat.keys())}")
        key = affine_keys[0]
        params = mat[key].flatten()
        fixed = mat["fixed"].flatten()

        M = params[:9].reshape(3, 3)
        T = params[9:12]
        offset = T + fixed - M @ fixed
        return M, offset
    except Exception as e_mat:
        # Fallback: try parsing as ITK text format
        try:
            with open(itk_path, "r") as f:
                lines = f.readlines()
            params = None
            fixed = None
            for line in lines:
                line = line.strip()
                if line.startswith("Parameters:"):
                    params = np.array([float(x) for x in line.split()[1:]])
                elif line.startswith("FixedParameters:"):
                    fixed = np.array([float(x) for x in line.split()[1:]])
            if params is not None and fixed is not None and len(params) >= 12 and len(fixed) >= 3:
                M = params[:9].reshape(3, 3)
                T = params[9:12]
                offset = T + fixed - M @ fixed
                return M, offset
        except Exception:
            pass
        raise RuntimeError(f"Failed to read ITK transform from {itk_path}: {e_mat}")


def get_vox2fsl(nii):
    """
    Get the voxel-to-FSL-coordinates affine for a NIfTI image.
    In FSL:
        Voxel coords are scaled by zooms.
        If determinant of sform is positive (radiological orientation),
        x is inverted: x_fsl = (dim0 - 1) * dx - x_vox * dx.
    """
    hdr = nii.header
    zooms = hdr.get_zooms()[:3]
    sform = nii.get_sform()
    v2f = np.diag([zooms[0], zooms[1], zooms[2], 1.0])
    if np.linalg.det(sform) > 0:
        v2f[0, 0] = -zooms[0]
        v2f[0, 3] = (nii.shape[0] - 1) * zooms[0]
    return v2f


def itk2fsl(itk_file, src_file, ref_file, out_file):
    M_lps, offset_lps = parse_itk_mat(itk_file)

    # Convert ITK LPS 4x4 matrix to RAS 4x4 matrix
    A_lps = np.eye(4)
    A_lps[:3, :3] = M_lps
    A_lps[:3, 3] = offset_lps

    # D = diag([-1, -1, 1, 1]) converts between LPS and RAS
    D = np.diag([-1.0, -1.0, 1.0, 1.0])
    A_ras = D @ A_lps @ D

    # In ITK convention for ANTs registration:
    # A_ras maps fixed/reference physical RAS coordinates to moving/source physical RAS coordinates:
    # x_src_ras = A_ras @ x_ref_ras
    # Therefore, the mapping from source to reference in RAS is:
    M_ras = np.linalg.inv(A_ras)

    src_nii = nib.load(src_file)
    ref_nii = nib.load(ref_file)

    src_sform = src_nii.get_sform()
    ref_sform = ref_nii.get_sform()

    src_v2f = get_vox2fsl(src_nii)
    ref_v2f = get_vox2fsl(ref_nii)

    # In FSL convention:
    # x_ref_fsl = M_fsl @ x_src_fsl
    # Expanding through RAS:
    # x_src_vox = src_v2f^-1 @ x_src_fsl
    # x_src_ras = src_sform @ x_src_vox
    # x_ref_ras = M_ras @ x_src_ras
    # x_ref_vox = ref_sform^-1 @ x_ref_ras
    # x_ref_fsl = ref_v2f @ x_ref_vox
    M_fsl = ref_v2f @ np.linalg.inv(ref_sform) @ M_ras @ src_sform @ np.linalg.inv(src_v2f)

    # Save FSL matrix with 6 decimal places (standard FSL format)
    np.savetxt(out_file, M_fsl, fmt="%.6f")
    print(f"Successfully converted ITK affine to FSL matrix: {out_file}")


def main():
    parser = argparse.ArgumentParser(description="Convert ITK/ANTs affine transform to FSL FLIRT format")
    # Support both --flag and -flag conventions
    parser.add_argument("--itk", "-itk", required=True, help="Input ITK/ANTs transform file (.mat or .txt)")
    parser.add_argument("--src", "-src", required=True, help="Moving / source NIfTI image")
    parser.add_argument("--ref", "-ref", required=True, help="Fixed / reference NIfTI image")
    parser.add_argument("--out", "-o", required=True, help="Output FSL FLIRT matrix file (.mat)")
    # Optional flags for compatibility with c3d_affine_tool invocation
    parser.add_argument("-ras2fsl", "--ras2fsl", action="store_true", help="Ignored (for c3d compatibility)")

    args, unknown = parser.parse_known_args()
    itk2fsl(args.itk, args.src, args.ref, args.out)


if __name__ == "__main__":
    main()
