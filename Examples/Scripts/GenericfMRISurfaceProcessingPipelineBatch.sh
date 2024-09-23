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
EnvironmentScript="${HOME}/Documents/HCP_pipelines/HCPpipelines-4.8.0/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

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

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################
# All the possible tasks
TaskList_general=()
TaskList_general+=(clench_run-1)
TaskList_general+=(clench_run-2)
TaskList_general+=(clench_run-3)
TaskList_general+=(clench_run-4)
TaskList_general+=(rest)
TaskList_general+=(localizer_run-1)
TaskList_general+=(localizer_run-2)
TaskList_general+=(localizer_run-3)
TaskList_general+=(stress_run-1)
TaskList_general+=(stress_run-2)
TaskList_general+=(stress_run-3)
TaskList_general+=(stress_run-4)

# TaskList=()
# TaskList+=(clench_run-1)
# TaskList+=(clench_run-2)
# TaskList+=(clench_run-3)
# TaskList+=(clench_run-4)
# TaskList+=(rest)
# # TaskList+=(localizer_run-1)
# # TaskList+=(localizer_run-2)
# # TaskList+=(localizer_run-3)
# TaskList+=(stress_run-1)
# TaskList+=(stress_run-2)
# TaskList+=(stress_run-3)
# TaskList+=(stress_run-4)

for Subject in $Subjlist ; do
    echo $Subject

    # Finding available task data
    TaskList=()
    for task in "${TaskList_general[@]}" ; do
      if [ -e "${StudyFolder}/${Subject}/func/${Subject}_task-${task}_bold.nii.gz" ]; then
        TaskList+=($task)
        echo "${task} added to the task list"
      fi
    done

    for fMRIName in "${TaskList[@]}" ; do
        echo "  ${fMRIName}"
        LowResMesh="32" #Needs to match what is in PostFreeSurfer, 32 is on average 2mm spacing between the vertices on the midthickness
        FinalfMRIResolution="2" #Needs to match what is in fMRIVolume, i.e. 2mm for 3T HCP data and 1.6mm for 7T HCP data
        SmoothingFWHM="2" #Recommended to be roughly the grayordinates spacing, i.e 2mm on HCP data
        GrayordinatesResolution="2" #Needs to match what is in PostFreeSurfer. 2mm gives the HCP standard grayordinates space with 91282 grayordinates.  Can be different from the FinalfMRIResolution (e.g. in the case of HCP 7T data at 1.6mm)
        RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)

        if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
            echo "About to locally run ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
            queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
        else
            echo "About to use fsl_sub to queue ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
            queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
        fi

        "${queuing_command[@]}" "$HCPPIPEDIR"/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
            --path="$StudyFolder" \
            --subject="$Subject" \
            --fmriname="$fMRIName" \
            --lowresmesh="$LowResMesh" \
            --fmrires="$FinalfMRIResolution" \
            --smoothingFWHM="$SmoothingFWHM" \
            --grayordinatesres="$GrayordinatesResolution" \
            --regname="$RegName"

        # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

        echo "set -- --path=$StudyFolder \
            --subject=$Subject \
            --fmriname=$fMRIName \
            --lowresmesh=$LowResMesh \
            --fmrires=$FinalfMRIResolution \
            --smoothingFWHM=$SmoothingFWHM \
            --grayordinatesres=$GrayordinatesResolution \
            --regname=$RegName"

        echo ". ${EnvironmentScript}"

    done
done
