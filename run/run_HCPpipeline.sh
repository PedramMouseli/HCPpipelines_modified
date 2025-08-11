#!/bin/bash
# Author: Pedram Mouseli

timestamp() {
  date +"Date: %D, time: %T"
}

read -p "Enter subject IDs: " SubList
read -p "Enter the StudyFolder path: " StudyFolder

# echo "$(timestamp)"
#
ScriptsFolder=/Users/moayedilab/Library/CloudStorage/OneDrive-UniversityofToronto/PhD/codes/HCP_pipelines/HCPpipelines-4.8.0/Examples/Scripts
# StudyFolder=/Volumes/encrypteddata_2/TMD/CIHR_TMD/Data-BIDS

# # Pre-FreeSurfer
# echo "$(timestamp)"
# echo "Running the Pre-FreeSurfer script"

# "$ScriptsFolder"/PreFreeSurferPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"

# FreeSurfer
echo "$(timestamp)"
echo "Running the FreeSurfer script"

"$ScriptsFolder"/FreeSurferPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"

# Post-FreeSurfer
echo "$(timestamp)"
echo "Running the Post-FreeSurfer script"

"$ScriptsFolder"/PostFreeSurferPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"

# Generic fMRI Volume Processing
echo "$(timestamp)"
echo "Running the Generic fMRI Volume Processing script"

"$ScriptsFolder"/GenericfMRIVolumeProcessingPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"
# "$ScriptsFolder"/GenericfMRIVolumeProcessingPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList" --TaskSpec=clench_run-1:2:91 --TaskSpec=localizer_run-3:5:110
# From file (CSV):
# --TaskSpecFile=/path/tasks.csv
# Example CSV:
# clench_run-1,2,91
# rest,,
# stress_run-2,2,54

# Generic fMRI Surface Processing
echo "$(timestamp)"
echo "Running the Generic fMRI Surface Processing script"

"$ScriptsFolder"/GenericfMRISurfaceProcessingPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"
# "$ScriptsFolder"/GenericfMRISurfaceProcessingPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList" --TaskSpec=clench_run-1 --TaskSpec=localizer_run-3

# Running MELODIC for manual ICA classification and FIX model training
# echo "$(timestamp)"
# echo "Running the MELODIC script"

# "$ScriptsFolder"/IcaFixMelodicOnlyProcessingBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList" --TaskList="clench rest localizer stress" --bandpass-tasks="rest"

# Running ICAFIX for classification and cleaning
echo "$(timestamp)"
echo "Running the ICAFIX script"

"$ScriptsFolder"/IcaFixProcessingBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList" --TaskList="clench rest localizer stress" --bandpass-tasks="rest"

# Running Post-ICAFIX
echo "$(timestamp)"
echo "Running the post-ICAFIX script"

"$ScriptsFolder"/PostFixBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"
# "$ScriptsFolder"/PostFixBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList" --TaskSpec=clench --TaskSpec=rest

# Running MSMAll on the resting-state data
echo "$(timestamp)"
echo "Running the MSMAll script"

"$ScriptsFolder"/MSMAllPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"

# Running DeDrift and Resample
echo "$(timestamp)"
echo "Running the DeDrift and Resample script"

"$ScriptsFolder"/DeDriftAndResamplePipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"
# "$ScriptsFolder"/DeDriftAndResamplePipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList" --TaskSpec=clench --TaskSpec=rest

echo "$(timestamp)"
echo "Done!"
