#!/bin/bash
# Author: Pedram Mouseli

timestamp() {
  date +"Date: %D, time: %T"
}

SubList="sub-C003@sub-C004@sub-C005@sub-C012@sub-C013@sub-C016@sub-C017@sub-C018@sub-C019@sub-C020@sub-C022@sub-C023@sub-C025@sub-C026@sub-C027@sub-C029@sub-C033@sub-C034@sub-C036@sub-C037@sub-C038@sub-C039@sub-C040@sub-C042@sub-C043@sub-C044@sub-C045@sub-C046@sub-C047@sub-C050@sub-C051@sub-C052@sub-C054@sub-C055@sub-C057@sub-C073@sub-C074@sub-C075@sub-C077@sub-C079@sub-C080@sub-P001@sub-P003@sub-P005@sub-P007@sub-P008@sub-P010@sub-P012@sub-P013@sub-P014@sub-P015@sub-P017@sub-P020@sub-P022@sub-P023@sub-P024@sub-P025@sub-P026@sub-P030@sub-P036@sub-P038@sub-P039@sub-P040@sub-P041@sub-P043@sub-P044@sub-P047@sub-P050@sub-P051@sub-P052@sub-P055@sub-P058@sub-P059@sub-P060@sub-P061@sub-P063@sub-P065@sub-P066@sub-P067@sub-P068@sub-P069@sub-P074@sub-P075@sub-P076@sub-P077@sub-P079@sub-P082@sub-P081@sub-P083@sub-P084"

ScriptsFolder=/Users/moayedilab/Library/CloudStorage/OneDrive-UniversityofToronto/PhD/codes/HCP_pipelines/HCPpipelines-4.8.0/TaskfMRIAnalysis
StudyFolder=/Volumes/encrypteddata_2/TMD/CIHR_TMD/Data-BIDS

# Task fMRI Analysis
echo "$(timestamp)"
echo "Running the level 3 Task fMRI Analysis script"

EnvironmentScript="${HOME}/Library/CloudStorage/OneDrive-UniversityofToronto/PhD/codes/HCP_pipelines/HCPpipelines-4.8.0/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

source "$EnvironmentScript"

"$ScriptsFolder"/TaskfMRILevel3.sh \
    --path=$StudyFolder \
    --subjectlist="$SubList" \
    --groupfolder="/Volumes/encrypteddata_2/TMD/CIHR_TMD/Data-BIDS/derivatives/clench_lvl3" \
    --lvl3fsf=/Users/moayedilab/Library/CloudStorage/OneDrive-UniversityofToronto/PhD/codes/fMRI/TMD/ClenchingTask/design/level3_w_sex/clench_level3_w_sex.fsf \
    --lvl2task="clench" \
    --lvl2fsf="clench" \
    --prefixanalysisname="clench_w_runs_w_sex" \
    --finalsmoothingFWHM="3" \
    --temporalfilter="0" \
    --regname="MSMAll" \
    --parcellation="NONE" \
    --vba="NO" \
    --contrastlist="ALL" \
    --procstring="hp125_clean" \
    --level2_cope_num="1"

echo "$(timestamp)"
echo "Done!"