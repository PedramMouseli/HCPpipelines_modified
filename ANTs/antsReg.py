#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Oct 11 15:26:41 2024

@author: moayedilab
"""

import argparse
import ants

parser = argparse.ArgumentParser()
parser.add_argument("input")
parser.add_argument("reference")
parser.add_argument("out")
args = parser.parse_args()


input_img = ants.image_read(args.input)
reference = ants.image_read(args.reference)


mytx = ants.registration(fixed=reference, moving=input_img, type_of_transform = 'SyN', outprefix=args.out)

# print(f'input: {args.input}')
# print(f'reference: {args.reference}')