This is a modified version of the [HCP pipelines][HCPpipelines]. Some of the changes are:
* The pipeline is modified to work on the BIDS data structure.
* All the outputs will be saved in a folder named "processed" in the subject's folder.
* The brain extraction script is modified to use [SynthStrip][synthstrip] (from FreeSurfer version >= 7.3.0) for a better brain extraction and registration to the standard space.
* An additional T1w image (INV2 from the MP2RAGE sequence) which has more clear edges is used for calculating the linear and non-linear transformations to the standard space.
* FSL FLIRT and FNIRT were replaced with [ANTs][ants] for the linear and non-linear registration. 
* ANTs transformations converted to the FSL format using [c3d_affine_tool][c3d_affine] and [Workbench][wb].
* Option added for excluding volumes from the beginning and end of the fMRI time series in the fMRI volume processing step.
* Option added to PreFreeSurfer step for switching between the original and alternative T1w image for registration.
* The older version of ICAFIX is replaced with [PyFIX][pyfix].
* Movement regressor plots will be generated for each task in in their ICA folder.
* Added the IcaFixMelodicOnlyProcessingBatch.sh script to run ICAFIX only for the melodic output when we want to train our own model and use it for ICAFIX classification and cleaning.

# HCP Pipelines 

The HCP Pipelines product is a set of tools (primarily, but not exclusively,
shell scripts) for processing MRI images for the [Human Connectome Project][HCP]. 
Among other things, these tools implement the Minimal Preprocessing Pipeline 
(MPP) described in [Glasser et al. 2013][GlasserEtAl]

For further information, please see:

* The [Release Notes, Installation, and Usage][release-install-use] document
  for the current release,
* The [FAQ][FAQ], and
* Other documentation in the project [Wiki][wiki]

Discussion of HCP Pipeline usage and improvements can be posted to the 
hcp-users discussion list. Sign up for the [hcp-users Google Group]
and click Sign In. For instructions on joining without a Google account: [hcp-users-join-wiki]


<!-- References -->

[HCP]: http://www.humanconnectome.org
[GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
[release-install-use]: https://github.com/Washington-University/HCPpipelines/wiki/Installation-and-Usage-Instructions
[FAQ]: https://github.com/Washington-University/Pipelines/wiki/FAQ
[wiki]: https://github.com/Washington-University/Pipelines/wiki
[hcp-users Google Group]: https://groups.google.com/u/2/a/humanconnectome.org/g/hcp-users
[hcp-users-join-wiki]: https://wiki.humanconnectome.org/pages/viewpage.action?pageId=140509193
[synthstrip]: https://surfer.nmr.mgh.harvard.edu/docs/synthstrip/
[HCPpipelines]: https://github.com/Washington-University/HCPpipelines
[ants]: https://github.com/ANTsX/ANTsPy
[c3d_affine]: https://github.com/pyushkevich/c3d/tree/master
[wb]: https://www.humanconnectome.org/software/workbench-command/-convert-warpfield
[pyfix]: https://git.fmrib.ox.ac.uk/fsl/pyfix