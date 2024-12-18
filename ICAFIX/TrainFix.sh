#!/bin/bash
# Author: Pedram Mouseli

timestamp() {
  date +"Date: %D, time: %T"
}

# Pre-defined variables
studyFolder="/Volumes/encrypteddata_2/TMD/CIHR_TMD/Data-BIDS"  # Replace with your study folder path
tasks=("clench" "rest" "localizer" "stress")  # Replace with your tasks
highpass=125  # Replace with your highpass value
EnvironmentScript="${HOME}/Library/CloudStorage/OneDrive-UniversityofToronto/PhD/codes/HCP_pipelines/HCPpipelines-4.8.0/Examples/Scripts/SetUpHCPPipeline.sh"
output_dir="${studyFolder}/derivatives/ICA_FIX"

source "${EnvironmentScript}"
PyFIX_DIR="$FSLDIR/bin"

# Check if any subject IDs were provided
if [ $# -eq 0 ]; then
    echo "Error: No subject IDs provided"
    echo "Usage: $0 subject1 subject2 ..."
    exit 1
fi

# Initialize empty list for valid folders
valid_folders=""

# Loop through each subject ID provided as argument
for sub_id in "$@"; do
    # Loop through each task
    for task in "${tasks[@]}"; do
        # Construct folder path
        folder="${studyFolder}/${sub_id}/processed/MNINonLinear/Results/${task}_ICA/${task}_ICA_hp${highpass}.ica"
        
        # Check if folder exists
        if [ -d "$folder" ]; then
            # Extract features
            echo "Extracting features from ${folder}"
            ${PyFIX_DIR}/fix -f ${folder}
            # Add to space-separated list
            valid_folders="${valid_folders:+$valid_folders }$folder"
        fi
    done
done

# You can also check if any folders were found
if [ -z "$valid_folders" ]; then
    echo "No valid folders found"
    exit 1
fi

# Output the list and counts
# echo "Valid folders: $valid_folders"
echo "Number of folders found: $(echo "$valid_folders" | wc -w)"

# Run the fix command
echo "$(timestamp)"
echo "Running fix command..."

${PyFIX_DIR}/fix -t ${output_dir}/TMDmodel_PyFIX -l ${valid_folders}

# classification using an existing model
# fix_model=/Volumes/encrypteddata_2/TMD/CIHR_TMD/Data-BIDS/derivatives/ICA_FIX/TMDmodel_PyFIX.pyfix_model
# ${PyFIX_DIR}/fix -C ${fix_model} ${valid_folders}

echo "$(timestamp)"
echo "Done!"
