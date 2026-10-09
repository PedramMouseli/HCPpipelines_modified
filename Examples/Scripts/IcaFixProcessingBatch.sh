#!/bin/bash

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/data/Pipelines_ExampleData"
DEFAULT_SUBJECT_LIST="100307 100610"
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/Library/CloudStorage/OneDrive-UniversityofToronto/PhD/codes/HCP_pipelines/HCPpipelines-4.8.0/Examples/Scripts/SetUpHCPPipeline.sh"
DEFAULT_RUN_LOCAL="FALSE"
#DEFAULT_FIXDIR="${HOME}/tools/fix1.06"  ##OPTIONAL: If not set will use $FSL_FIXDIR specified in EnvironmentScript

#
# Function Description
#	Get the command line options for this script
#
# Global Output Variables
#	${StudyFolder}			- Path to folder containing all subjects data in subdirectories named
#							  for the subject id
#	${Subjlist}				- Space delimited list of subject IDs
#	${EnvironmentScript}	- Script to source to setup pipeline environment
#	${FixDir}				- Directory containing FIX
#	${RunLocal}				- Indication whether to run this processing "locally" i.e. not submit
#							  the processing to a cluster or grid
#   ${TaskList}             - Space delimited list of tasks to process
#   ${BandpassTasks}        - Space delimited list of tasks to band-pass filter
#
get_options() {
	local scriptName=$(basename ${0})
	local arguments=("$@")

	# initialize global output variables
	StudyFolder="${DEFAULT_STUDY_FOLDER}"
	Subjlist="${DEFAULT_SUBJECT_LIST}"
	EnvironmentScript="${DEFAULT_ENVIRONMENT_SCRIPT}"
	FixDir="${DEFAULT_FIXDIR}"
	RunLocal="${DEFAULT_RUN_LOCAL}"
    TaskList=""
    BandpassTasks=""

	# parse arguments
	local index=0
	local numArgs=${#arguments[@]}
	local argument

	while [ ${index} -lt ${numArgs} ]
	do
		argument=${arguments[index]}

		case ${argument} in
			--StudyFolder=*)
				StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--Subject=*)
				Subjlist=${argument#*=}
				index=$(( index + 1 ))
				;;
			--EnvironmentScript=*)
				EnvironmentScript=${argument#*=}
				index=$(( index + 1 ))
				;;
			--FixDir=*)
				FixDir=${argument#*=}
				index=$(( index + 1 ))
				;;
            --task-list=*)
                TaskList=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --bandpass-tasks=*)
                BandpassTasks=${argument#*=}
                index=$(( index + 1 ))
                ;;
			--runlocal | --RunLocal)
				RunLocal="TRUE"
				index=$(( index + 1 ))
				;;
			*)
				echo "ERROR: Unrecognized Option: ${argument}"
				exit 1
				;;
		esac
	done

	# check required parameters
	if [ -z "${StudyFolder}" ]
	then
		echo "ERROR: StudyFolder not specified"
		exit 1
	fi

	if [ -z "${Subjlist}" ]
	then
		echo "ERROR: Subjlist not specified"
		exit 1
	fi

	if [ -z "${EnvironmentScript}" ]
	then
		echo "ERROR: EnvironmentScript not specified"
		exit 1
	fi

	# MPH: Allow FixDir to be empty at this point, so users can take advantage of the FSL_FIXDIR setting
	# already in their EnvironmentScript
#    if [ -z "${FixDir}" ]
#    then
#        echo "ERROR: FixDir not specified"
#        exit 1
#    fi

	if [ -z "${RunLocal}" ]
	then
		echo "ERROR: RunLocal is an empty string"
		exit 1
	fi

	# report options
	echo "-- ${scriptName}: Specified Command-Line Options: -- Start --"
	echo "   StudyFolder: ${StudyFolder}"
	echo "   Subjlist: ${Subjlist}"
	echo "   EnvironmentScript: ${EnvironmentScript}"
	if [ -n "${FixDir}" ]; then
		echo "   FixDir: ${FixDir}"
	fi
	echo "   RunLocal: ${RunLocal}"
    echo "   TaskList: ${TaskList}"
    echo "   BandpassTasks: ${BandpassTasks}"
	echo "-- ${scriptName}: Specified Command-Line Options: -- End --"
}  # get_options()

#
# Function Description
#	Main processing of this script
#
#	Gets user specified command line options and runs a batch of ICA+FIX processing
#
main() {
	# get command line options
	get_options "$@"

	# set up pipeline environment variables and software
	source "$EnvironmentScript"

	# MPH: If DEFAULT_FIXDIR is set, or --FixDir argument was used, then use that to
	# override the setting of FSL_FIXDIR in EnvironmentScript
	if [ -n "${FixDir}" ]; then
		export FSL_FIXDIR=${FixDir}
	fi

	# set list of fMRI on which to run ICA+FIX, separate MR FIX groups with %, use spaces (or @ like dedrift...) to otherwise separate runs
	# the MR FIX groups determine what gets concatenated before doing ICA
	# the groups can be whatever you want, you can make a day 1 group and a day 2 group, or just concatenate everything, etc
	# fMRINames="clench_run-1@clench_run-2@clench_run-3@clench_run-4%rest%localizer_run-1@localizer_run-2@localizer_run-3%stress_run-1@stress_run-2@stress_run-3@stress_run-4"

	# If you wish to run "multi-run" (concatenated) FIX, specify the names to give the concatenated output files
	# In this case, all the runs included in ${fMRINames} become the input to multi-run FIX
	# ConcatNames="clench@rest@localizer@stress"  ## Use space (or @) to separate concatenation groups
	# Otherwise, leave ConcatNames empty (in which case "single-run" FIX is executed serially on each run in ${fMRINames})
	#ConcatNames=""

	runs="run-1 run-2 run-3 run-4"

	# set temporal highpass full-width (2*sigma) to use, in seconds, cannot be 0 for single-run FIX
	# MR FIX also supports 0 for a linear detrend, or "pdX" for a polynomial detrend of order X
	# e.g., bandpass=pd1 is linear detrend (functionally equivalent to bandpass=0)
	# bandpass=pd2 is a quadratic detrend
	bandpass_hp=125 # in seconds, equal to f=0.008 Hz (1/125)
    bandpass_lp=12.5 # in seconds, equal to f=0.08 Hz (1/12.5)

	# set whether or not to regress motion parameters (24 regressors)
	# out of the data as part of FIX (TRUE or FALSE)
	domot=TRUE

	# set the training data used in multi-run fix mode
	# MRTrainingData=TMDmodel_PyFIX.pyfix_model
	MRTrainingData=/Volumes/SPRINT/Restingstate_Amygdala_Analysis_copy/Discovery_Cohort_Raw/BIDS_format_2/derivatives/FIX/SPRINTmodel_Stanford.pyfix_model

	# set the training data used in single-run fix mode
	# SRTrainingData=HCP_hp2000.RData
	SRTrainingData=/Volumes/SPRINT/Restingstate_Amygdala_Analysis_copy/Discovery_Cohort_Raw/BIDS_format_2/derivatives/FIX/SPRINTmodel_Stanford.pyfix_model

	# set FIX threshold (controls sensitivity/specificity tradeoff)
	FixThreshold=10

	#delete highpass files (note that delete intermediates=TRUE is not recommended for MR+FIX)
	DeleteIntermediates=FALSE

	#MR FIX config support for non-HCP settings
	config=""
	processingmode="HCPStyleData"
	#uncomment the below two lines for legacy-style data
	#config="$HCPPIPEDIR"/ICAFIX/config/legacy.conf
	#processingmode="LegacyStyleData"

	#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
	#DO NOT include "-q " at the beginning
	#default to no queue, implying run local
	QUEUE=""
	#QUEUE="hcp_priority.q"

	if [[ "$RunLocal" == "TRUE" || "$QUEUE" == "" ]]; then
		queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
	else
		queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
	fi

	for Subject in ${Subjlist}; do
		echo ${Subject}

		ResultsFolder="${StudyFolder}/${Subject}/processed/MNINonLinear/Results"

		## find the task list
		ConcatNames=""
		fMRINamesMulti=""
		fMRINamesSingle=()
        for task in ${TaskList}; do
		  task_runs=()
		  if [ "$task" = "rest" ]; then
		    # Prefer numbered runs if present
		    numbered_runs=()
		    for run in ${runs} ; do
		      if ls "${StudyFolder}/${Subject}/func/${Subject}_task-${task}_${run}"* >/dev/null 2>&1 || \
		         ls "${StudyFolder}/${Subject}/func/${Subject}_${task}_${run}"* >/dev/null 2>&1; then
		        numbered_runs+=("${task}_${run}")
		      fi
		    done
		    if [ ${#numbered_runs[@]} -gt 0 ]; then
		      task_runs=("${numbered_runs[@]}")
		    else
		      # Fall back to unnumbered 'rest' if present (either naming style)
		      if ls "${StudyFolder}/${Subject}/func/${Subject}_${task}"* >/dev/null 2>&1 || \
		         ls "${StudyFolder}/${Subject}/func/${Subject}_task-${task}"* >/dev/null 2>&1; then
		        task_runs+=("${task}")
		      fi
		    fi
		  else
		    # Non-rest tasks: collect numbered runs (accept both naming styles)
		    for run in ${runs} ; do
		      if ls "${StudyFolder}/${Subject}/func/${Subject}_task-${task}_${run}"* >/dev/null 2>&1 || \
		         ls "${StudyFolder}/${Subject}/func/${Subject}_${task}_${run}"* >/dev/null 2>&1; then
		        task_runs+=("${task}_${run}")
		      fi
		    done
		  fi
		  if [ ${#task_runs[@]} -ge 2 ]; then
		    ConcatNames+="${task}_ICA@"
		    task_run_string=$(IFS=@; echo "${task_runs[*]}")
		    fMRINamesMulti+="${task_run_string}%"
		    echo "${task} set for multi-run concatenation (${task_run_string})"
		  elif [ ${#task_runs[@]} -eq 1 ]; then
		    single_run_name="${task_runs[0]}"
		    preferred_name="${task}"
		    # Prefer base task name (no run suffix) for single-run if such results directory exists
		    if [ -d "${ResultsFolder}/${preferred_name}" ]; then
		      fMRINamesSingle+=("${preferred_name}")
		      echo "${preferred_name} added to single-run list"
		    else
		      fMRINamesSingle+=("${single_run_name}")
		      echo "${single_run_name} added to single-run list"
		    fi
		  else
		    echo "No runs found for task ${task}, skipping."
		  fi
		done
		fMRINames="${fMRINamesMulti}"

		if [ -z "${ConcatNames}" ]; then
			# single-run FIX
			fMRINamesFlat=$(echo ${fMRINames} | sed 's/[@%]/ /g')

			# run any single-run entries collected (no concatenation)
			for fMRIName in ${fMRINamesFlat} ${fMRINamesSingle[@]}; do
				echo "  ${fMRIName}"

				InputFile="${ResultsFolder}/${fMRIName}/${fMRIName}"

                lp_arg=""
                for bandpass_task in ${BandpassTasks}; do
                    if [[ "${fMRIName}" == *"${bandpass_task}"* ]]; then
                        lp_arg="${bandpass_lp}"
                        break
                    fi
                done

				cmd=("${queuing_command[@]}" "${HCPPIPEDIR}/ICAFIX/hcp_fix" "${InputFile}" ${bandpass_hp} ${domot} "${SRTrainingData}" ${FixThreshold} "${DeleteIntermediates}" ${lp_arg})
				echo "About to run: ${cmd[*]}"
				"${cmd[@]}"
			done

		else
        	#need arrays to sanity check number of concat groups
        	IFS=' @' read -a concatarray <<< "${ConcatNames}"
        	IFS=% read -a fmriarray <<< "${fMRINames}"

        	if ((${#concatarray[@]} != ${#fmriarray[@]})); then
        	    echo "ERROR: number of names in ConcatNames does not match number of fMRINames groups"
        	    exit 1
        	fi

		    for ((i = 0; i < ${#concatarray[@]}; ++i))
		    do
				ConcatName="${concatarray[$i]}"
				fMRINamesGroup="${fmriarray[$i]}"
				# multi-run FIX
				ConcatFileName="${ResultsFolder}/${ConcatName}/${ConcatName}"

				IFS=' @' read -a namesgrouparray <<< "${fMRINamesGroup}"
				InputFile=""
				for fMRIName in "${namesgrouparray[@]}"; do
					if [[ "$InputFile" == "" ]]; then
						InputFile="${ResultsFolder}/${fMRIName}/${fMRIName}"
					else
						InputFile+="@${ResultsFolder}/${fMRIName}/${fMRIName}"
					fi
				done

				echo "  InputFile: ${InputFile}"

                lp_arg="--low-pass=-1"
                for bandpass_task in ${BandpassTasks}; do
                    if [[ "${ConcatName}" == *"${bandpass_task}"* ]]; then
                        lp_arg="--low-pass=${bandpass_lp}"
                        break
                    fi
                done

				cmd=("${queuing_command[@]}" "${HCPPIPEDIR}/ICAFIX/hcp_fix_multi_run" --fmri-names="${InputFile}" --high-pass=${bandpass_hp} ${lp_arg} --concat-fmri-name="${ConcatFileName}" --motion-regression=${domot} --training-file="${MRTrainingData}" --fix-threshold=${FixThreshold} --delete-intermediates="${DeleteIntermediates}" --config="$config" --processing-mode="$processingmode")
				echo "About to run: ${cmd[*]}"
				"${cmd[@]}"
			done

		fi

	done
}  # main()

#
# Invoke the main function to get things started
#
main "$@"
