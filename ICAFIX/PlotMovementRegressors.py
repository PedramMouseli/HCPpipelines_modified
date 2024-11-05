#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Nov  5 14:59:56 2024

@author: moayedilab
"""

import numpy as np
import matplotlib.pyplot as plt
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("input")
parser.add_argument("output")
args = parser.parse_args()

# BIDS_folder = '/Volumes/encrypteddata_2/TMD/CIHR_TMD/Data-BIDS'
# sub_id = 'sub-P055'

movement_mat = np.loadtxt(args.input)

fig, ax = plt.subplots(2,1, figsize=[8,8])

ax[0].plot(movement_mat[:,:3])
ax[0].set_title('Estimated translation')
ax[0].set_ylabel('Estimated translation (mm)')
ax[0].legend(['x', 'y', 'z'])

ax[1].plot(movement_mat[:,3:6])
ax[1].set_title('Estimated rotation')
ax[1].set_ylabel('Estimated rotation (deg)')
ax[1].legend(['x', 'y', 'z'])

plt.savefig(args.output, dpi=600)