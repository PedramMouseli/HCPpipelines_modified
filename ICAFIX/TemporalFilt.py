#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Temporal filtering and detrending for fMRI data (NIFTI or CIFTI).
This script can perform high-pass/low-pass/band-pass filtering and
polynomial detrending.
"""

import argparse
import nibabel as nib
import numpy as np
from scipy import signal

def poly_detrend(data, order, axis=-1):
    """
    Polynomial detrending of a given order along a given axis.
    """
    if order < 0:
        return data

    if axis < 0:
        axis = data.ndim + axis

    data_swapped = np.swapaxes(data, axis, -1)
    
    time_points = data_swapped.shape[-1]
    x = np.arange(time_points)
    regressors = np.vander(x, order + 1)

    flat_data = data_swapped.reshape(-1, time_points)
    
    non_zero_mask = np.any(flat_data != 0, axis=1)
    if not np.any(non_zero_mask):
        return data

    betas, _, _, _ = np.linalg.lstsq(regressors, flat_data[non_zero_mask].T, rcond=None)

    trend = (regressors @ betas).T
    
    detrended_flat_data = flat_data.copy()
    detrended_flat_data[non_zero_mask] -= trend

    detrended_data = detrended_flat_data.reshape(data_swapped.shape)

    return np.swapaxes(detrended_data, -1, axis)


def temporal_filter(data, tr, high_pass_freq, low_pass_freq, axis=-1):
    """
    Apply temporal filtering to data.
    """
    fs = 1.0 / tr
    nyq = fs / 2.0
    
    if high_pass_freq is None or high_pass_freq <= 0:
        high_pass_freq = -1
    
    if low_pass_freq is None or low_pass_freq <= 0:
        low_pass_freq = -1

    if high_pass_freq < 0 and low_pass_freq < 0:
        return data

    if high_pass_freq > 0 and low_pass_freq > 0 and high_pass_freq < low_pass_freq:
        sos = signal.butter(5, [high_pass_freq/nyq, low_pass_freq/nyq], btype='bandpass', output='sos')
    elif high_pass_freq > 0:
        sos = signal.butter(5, high_pass_freq/nyq, btype='highpass', output='sos')
    elif low_pass_freq > 0:
        sos = signal.butter(5, low_pass_freq/nyq, btype='lowpass', output='sos')
    else:
        return data

    if axis < 0:
        axis = data.ndim + axis
        
    data_swapped = np.swapaxes(data, axis, -1)
    flat_data = data_swapped.reshape(-1, data_swapped.shape[-1])
    
    non_zero_mask = np.any(flat_data != 0, axis=1)
    if not np.any(non_zero_mask):
        return data
        
    filtered_flat_data = flat_data.copy()
    filtered_flat_data[non_zero_mask] = signal.sosfiltfilt(sos, flat_data[non_zero_mask], axis=-1)
    
    filtered_data = filtered_flat_data.reshape(data_swapped.shape)
    
    return np.swapaxes(filtered_data, -1, axis)


def main():
    parser = argparse.ArgumentParser(description="Temporal filtering and detrending for fMRI data (NIFTI or CIFTI).")
    parser.add_argument("--input-file", required=True, help="Path to the input fMRI file (.nii.gz or .dtseries.nii)")
    parser.add_argument("--output-file", required=True, help="Path to the output filtered fMRI file")
    parser.add_argument("--tr", type=float, required=True, help="Repetition time in seconds")
    parser.add_argument("--hp", type=float, default=-1.0, help="High-pass filter full-width in seconds (e.g., 2000). hp > 0 will be converted to frequency. hp<=0 means no highpass.")
    parser.add_argument("--lp", type=float, default=-1.0, help="Low-pass filter full-width in seconds. lp > 0 will be converted to frequency. lp<=0 means no lowpass.")
    parser.add_argument("--poly-detrend", type=int, default=-1, help="Order for polynomial detrending. -1 to disable. 0 for demeaning, 1 for linear detrending, etc.")
    parser.add_argument("--add-mean-back", action='store_true', help="Add the mean back to the data after filtering.")

    args = parser.parse_args()

    img = nib.load(args.input_file)
    data = img.get_fdata(caching='unchanged').astype(np.float32)

    is_cifti = isinstance(img, nib.Cifti2Image)

    if is_cifti:
        time_axis = 0
    else:
        time_axis = img.ndim - 1
        
    mean_data = np.mean(data, axis=time_axis, keepdims=True)

    if args.poly_detrend > -1:
        print(f"Applying polynomial detrending of order {args.poly_detrend}...")
        data = poly_detrend(data, args.poly_detrend, axis=time_axis)

    hp_freq = 1.0 / args.hp if args.hp > 0 else None
    lp_freq = 1.0 / args.lp if args.lp > 0 else None

    if hp_freq or lp_freq:
        print(f"Applying temporal filtering...")
        data = temporal_filter(data, args.tr, hp_freq, lp_freq, axis=time_axis)
    
    if args.add_mean_back:
        data += mean_data

    if is_cifti:
        new_img = nib.Cifti2Image(data.astype(np.float32), header=img.header, nifti_header=img.nifti_header)
    elif isinstance(img, (nib.Nifti1Image, nib.Nifti2Image)):
        new_img = nib.Nifti1Image(data.astype(np.float32), img.affine, img.header)
    else:
        raise TypeError(f"Unsupported image type: {type(img)}")

    new_img.to_filename(args.output_file)
    print(f"Filtered file saved to {args.output_file}")


if __name__ == "__main__":
    main()