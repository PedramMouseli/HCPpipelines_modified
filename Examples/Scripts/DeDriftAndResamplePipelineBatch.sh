#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subj=""
    command_line_specified_run_local="FALSE"

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Subject=*)
                command_line_specified_subj=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --runlocal)
                command_line_specified_run_local="TRUE"
                index=$(( index + 1 ))
                ;;
	    *)
		echo ""
		echo "ERROR: Unrecognized Option: ${argument}"
		echo ""
		exit 1
		;;
        esac
    done
}

get_batch_options "$@"

EnvironmentScript="${HOME}/Library/CloudStorage/OneDrive-UniversityofToronto/PhD/codes/HCP_pipelines/HCPpipelines-4.8.0/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR 

# NOTE: this script will error on subjects that are missing some fMRI runs that are specified in the MR FIX arguments

########################################## INPUTS ########################################## 

#This example script is set up for a single subject from the CCF development project

######################################### DO WORK ##########################################

#Example of how CCF Development was run
StudyFolder="/media/myelin/brainmappers/Connectome_Project/CCF_HCD_STG" #Location of Subject folders (named by subjectID)
# Subjlist=(HCD0001305_V1_MR HCD0008117_V1_MR) #List of subject IDs
#Don't edit things between here and MRFixConcatNames unless you know what you are doing
HighResMesh="164"
LowResMesh="32"
#Do not use RegName from MSMAllPipelineBatch.sh
RegName="MSMAll_InitalReg_2_d40_WRN"
DeDriftRegFiles="${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.L.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii@${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.R.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii"
ConcatRegName="MSMAll"
#standard maps to resample
Maps=(sulc curvature corrThickness thickness)
MyelinMaps=(MyelinMap SmoothedMyelinMap) #No _BC, this will be reapplied
#MRFixConcatNames and MRFixNames must exactly match the way MR FIX was run on the subjects
# MRFixConcatNames=(fMRI_CONCAT_ALL)
#SPECIAL: if your data used two (or more) MR FIX runs (which is generally not recommended), specify them like this, with no whitespace before or after the %:
#MRFixConcatNames=(concat12 concat34)
#MRFixNames=(run1 run2%run3 run4)

TaskList_general=()
TaskList_general+=(clench)
TaskList_general+=(rest)
TaskList_general+=(localizer)
TaskList_general+=(stress)

runs="run-1 run-2 run-3 run-4"

# MRFixNames=(rfMRI_REST1_AP rfMRI_REST1_PA tfMRI_GUESSING_PA tfMRI_GUESSING_AP tfMRI_CARIT_PA tfMRI_CARIT_AP tfMRI_EMOTION_PA rfMRI_REST2_AP rfMRI_REST2_PA)
#fixNames are for if single-run ICA FIX was used (not recommended)
fixNames=()
#dontFixNames are for runs that didn't have any kind of ICA artifact removal run on them (very not recommended)
dontFixNames=()
SmoothingFWHM="2" #Should equal previous grayordinates smoothing (because we are resampling from unsmoothed native mesh timeseries)
HighPass="125"
MotionRegression=True
MatlabMode="1" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab, Mode=2 octave
MatlabPath="/Applications/MATLAB_R2024b.app/bin/matlab"

#Example of how older HCP-YA results were originally run
#These settings are no longer recommended - recommendations are to do MR FIX using all of a subject's runs, in the order they were acquired, no motion regression, HighPass 0
#StudyFolder="/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final" #Location of Subject folders (named by subjectID)
#Subjlist=(100307 101006) #List of subject IDs
#HighResMesh="164"
#LowResMesh="32"
#RegName="MSMAll_InitalReg_2_d40_WRN"
#DeDriftRegFiles="${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.L.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii@${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.R.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii"
#ConcatRegName="MSMAll"
#Maps=(sulc curvature corrThickness thickness)
#MyelinMaps=(MyelinMap SmoothedMyelinMap) #No _BC, this will be reapplied
#MRFixConcatNames=()
#MRFixNames=()
#fixNames=(rfMRI_REST1_LR rfMRI_REST1_RL rfMRI_REST2_LR rfMRI_REST2_RL)
#dontFixNames=(tfMRI_EMOTION_LR tfMRI_EMOTION_RL tfMRI_GAMBLING_LR tfMRI_GAMBLING_RL tfMRI_LANGUAGE_LR tfMRI_LANGUAGE_RL tfMRI_MOTOR_LR tfMRI_MOTOR_RL tfMRI_RELATIONAL_LR tfMRI_RELATIONAL_RL tfMRI_SOCIAL_LR tfMRI_SOCIAL_RL tfMRI_WM_LR tfMRI_WM_RL)
#SmoothingFWHM="2" #Should equal previous grayordinates smoothing (because we are resampling from unsmoothed native mesh timeseries)
#HighPass="2000"
#MotionRegression=TRUE
#MatlabMode="0" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab, Mode=2 octave

MSMAllTemplates="${HCPPIPEDIR}/global/templates/MSMAll"
MyelinTargetFile="${MSMAllTemplates}/Q1-Q6_RelatedParcellation210.MyelinMap_BC_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.dscalar.nii"

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Log the originating call
echo "$0" "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

Maps=$(IFS=@; echo "${Maps[*]}")
MyelinMaps=$(IFS=@; echo "${MyelinMaps[*]}")
# MRFixConcatNames=$(IFS=@; echo "${MRFixConcatNames[*]}")
# MRFixNames=$(IFS=@; echo "${MRFixNames[*]}")
fixNames=$(IFS=@; echo "${fixNames[*]}")
dontFixNames=$(IFS=@; echo "${dontFixNames[*]}")

for Subject in $Subjlist ; do
    echo "    ${Subject}"

    # Initialize lists to hold the names for this subject
    MRFixConcatNames_list=()
    MRFixNames_list=()
    # Iterate through the general task list
    for task in "${TaskList_general[@]}" ; do
        # List to hold runs found for the current task
        runs_found_for_task=()

        # Handle 'rest' task specifically if its naming is different
        if [ "$task" == "rest" ]; then
            # Check if any base file for 'rest' task exists
            # Modify this check if your 'rest' files have run numbers
            if ls "${StudyFolder}/${Subject}/func/${Subject}_task-${task}"* >/dev/null 2>&1; then
            # Treat 'rest' itself as the run identifier for the rest_ICA group
            runs_found_for_task+=("rest")
            fi
        else
            # Find actual numbered runs for other tasks
            for run in ${runs} ; do
                # Check if the specific run file exists for this task
                if ls "${StudyFolder}/${Subject}/func/${Subject}_task-${task}_${run}"* >/dev/null 2>&1; then
                    runs_found_for_task+=("${task}_${run}")
                fi
            done
        fi

        # Only proceed if we actually found runs for this task
        if [ ${#runs_found_for_task[@]} -gt 0 ]; then
            echo "Found runs for task ${task}: ${runs_found_for_task[*]}"
            
            # Add the corresponding ICA concatenation name to its list
            MRFixConcatNames_list+=("${task}_ICA")
            # Join the found runs for this task with '@'
            task_run_string=$(IFS=@; echo "${runs_found_for_task[*]}")
            
            # Add this '@'-separated string as one element to the list of run groups
            MRFixNames_list+=("$task_run_string")

        else
            echo "No runs found for task ${task}, skipping."
        fi
    done

    # Join the collected concat names with '@' for the pipeline script argument
    MRFixConcatNames=$(IFS=@; echo "${MRFixConcatNames_list[*]}")
    # Join the collected run groups (which are already '@'-separated) with '%'
    MRFixNames=$(IFS=%; echo "${MRFixNames_list[*]}")

    echo "Generated MRFixConcatNames: ${MRFixConcatNames}"
    echo "Generated MRFixNames: ${MRFixNames}"

    if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/DeDriftAndResample/DeDriftAndResamplePipeline.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/DeDriftAndResample/DeDriftAndResamplePipeline.sh"
        queuing_command=("$FSLDIR"/bin/fsl_sub -q "$QUEUE")
    fi

    "${queuing_command[@]}" "$HCPPIPEDIR"/DeDriftAndResample/DeDriftAndResamplePipeline.sh \
        --path="$StudyFolder" \
        --subject="$Subject" \
        --high-res-mesh="$HighResMesh" \
        --low-res-meshes="$LowResMesh" \
        --registration-name="$RegName" \
        --dedrift-reg-files="$DeDriftRegFiles" \
        --concat-reg-name="$ConcatRegName" \
        --maps="$Maps" \
        --myelin-maps="$MyelinMaps" \
        --multirun-fix-concat-names="$MRFixConcatNames" \
        --multirun-fix-names="$MRFixNames" \
        --fix-names="$fixNames" \
        --dont-fix-names="$dontFixNames" \
        --smoothing-fwhm="$SmoothingFWHM" \
        --high-pass="$HighPass" \
        --matlab-run-mode="$MatlabMode" \
        --matlab-path="$MatlabPath" \
        --motion-regression="$MotionRegression" \
        --myelin-target-file="$MyelinTargetFile"
done

