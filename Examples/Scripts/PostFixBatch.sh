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

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307 100610" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/Library/CloudStorage/OneDrive-UniversityofToronto/PhD/codes/HCP_pipelines/HCPpipelines-4.8.0/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR 

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

########################################## INPUTS ########################################## 

# This script runs on the outputs from ICAFIX

######################################### DO WORK ##########################################

# List of fMRI runs
# If running on output from multi-run FIX, use ConcatName(s) as value for fMRINames (space delimited)
# fMRINames="rfMRI_REST"

TaskList_general=()
TaskList_general+=(clench)
TaskList_general+=(rest)
TaskList_general+=(localizer)
TaskList_general+=(stress)


# for Subject in $Subjlist ; do
#     echo $Subject
#     for task in "${fMRINames[@]}" ; do
#         echo $task
#     done
# done
HighPass="125"
ReUseHighPass="YES" #Use YES if running on output from multi-run FIX, otherwise use NO

MatlabPath="/Applications/MATLAB_R2024b.app/bin/matlab"

DualScene=${HCPPIPEDIR}/ICAFIX/PostFixScenes/ICA_Classification_DualScreenTemplate.scene
SingleScene=${HCPPIPEDIR}/ICAFIX/PostFixScenes/ICA_Classification_SingleScreenTemplate.scene

MatlabMode="1" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab, Mode=2 octave

for Subject in $Subjlist ; do
    ## find the task list
    fMRINames=()
    for task in "${TaskList_general[@]}" ; do
        # echo $task
        if ls "${StudyFolder}/${Subject}/func/${Subject}_task-${task}"* >/dev/null 2>&1; then
        fMRINames+=("${task}_ICA")
        echo "${task} added to the task list"
        fi
    done

    for fMRIName in "${fMRINames[@]}" ; do
        echo "    ${Subject}"
        echo "${fMRIName} task processing"

        if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
            echo "About to locally run ${HCPPIPEDIR}/ICAFIX/PostFix.sh"
            queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
        else
            echo "About to use fsl_sub to queue ${HCPPIPEDIR}/ICAFIX/PostFix.sh"
            queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
        fi

        "${queuing_command[@]}" "$HCPPIPEDIR"/ICAFIX/PostFix.sh \
            --study-folder="$StudyFolder" \
            --subject="$Subject" \
            --fmri-name="$fMRIName" \
            --high-pass="$HighPass" \
            --matlab-path="$MatlabPath" \
            --template-scene-dual-screen="$DualScene" \
            --template-scene-single-screen="$SingleScene" \
            --reuse-high-pass="$ReUseHighPass" \
            --matlab-run-mode="$MatlabMode"
    done
done

