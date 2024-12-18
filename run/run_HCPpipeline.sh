#!/bin/bash
# Author: Pedram Mouseli

timestamp() {
  date +"Date: %D, time: %T"
}

read -p "Enter subject IDs: " SubList

# echo "$(timestamp)"
#
ScriptsFolder=/Users/moayedilab/Library/CloudStorage/OneDrive-UniversityofToronto/PhD/codes/HCP_pipelines/HCPpipelines-4.8.0/Examples/Scripts
StudyFolder=/Volumes/encrypteddata_2/TMD/CIHR_TMD/Data-BIDS

# # Pre-FreeSurfer
# echo "$(timestamp)"
# echo "Running the Pre-FreeSurfer script"

# "$ScriptsFolder"/PreFreeSurferPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"

# # FreeSurfer
# echo "$(timestamp)"
# echo "Running the FreeSurfer script"

# "$ScriptsFolder"/FreeSurferPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"

# # Post-FreeSurfer
# echo "$(timestamp)"
# echo "Running the Post-FreeSurfer script"

# "$ScriptsFolder"/PostFreeSurferPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"

# # Generic fMRI Volume Processing
# echo "$(timestamp)"
# echo "Running the Generic fMRI Volume Processing script"

# "$ScriptsFolder"/GenericfMRIVolumeProcessingPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"

# # Generic fMRI Surface Processing
# echo "$(timestamp)"
# echo "Running the Generic fMRI Surface Processing script"

# "$ScriptsFolder"/GenericfMRISurfaceProcessingPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"

# echo "$(timestamp)"
# echo "Running the MELODIC script"

# "$ScriptsFolder"/IcaFixMelodicOnlyProcessingBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"

echo "$(timestamp)"
echo "Running the FIX script"

"$ScriptsFolder"/IcaFixProcessingBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList"

echo "$(timestamp)"
echo "Done!"
