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

# Task fMRI Analysis
echo "$(timestamp)"
echo "Running the Task fMRI Analysis script"

"$ScriptsFolder"/TaskfMRIAnalysisBatch.sh --StudyFolder=$StudyFolder --Subjlist="$SubList"

echo "$(timestamp)"
echo "Done!"
