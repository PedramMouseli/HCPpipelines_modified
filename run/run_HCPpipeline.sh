#!/bin/bash
# Author: Pedram Mouseli

set -euo pipefail

timestamp() {
  date +"Date: %D, time: %T"
}

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Required:
  --Subject=SUBJ[,SUBJ2,...]        Subject IDs (space/comma separated accepted)
  --StudyFolder=/path/to/study      Study folder path

Step selection (choose one of the following):
  --all                              Run all steps (melodic excluded)
  --steps=STEP[,STEP2,...]           Run these steps in order
  --from=STEP [--to=STEP]            Run from STEP to end (or to STEP if provided)

Valid steps (order):
  pre-freesurfer, freesurfer, post-freesurfer, fmri-volume, fmri-surface,
  melodic, ica-fix, post-fix, msmall, dedrift

Examples:
  $0 --StudyFolder=/data --Subject=100307 --all
  $0 --StudyFolder=/data --Subject="100307 100610" --steps=freesurfer,post-freesurfer
  $0 --StudyFolder=/data --Subject=100307 --from=fmri-volume --to=post-fix
EOF
}

# Defaults
SubList=""
StudyFolder=""
RUN_MODE=""
STEPS_ARG=""
FROM_STEP=""
TO_STEP=""

# Parse CLI
for arg in "$@"; do
  case "$arg" in
    --Subject=*) SubList=${arg#*=} ;;
    --StudyFolder=*) StudyFolder=${arg#*=} ;;
    --all) RUN_MODE="all" ;;
    --steps=*) RUN_MODE="steps"; STEPS_ARG=${arg#*=} ;;
    --from=*) RUN_MODE="range"; FROM_STEP=${arg#*=} ;;
    --to=*) TO_STEP=${arg#*=} ;;
    --help|-h) print_usage; exit 0 ;;
    *) echo "Unknown option: $arg"; print_usage; exit 1 ;;
  esac
done

# Interactive prompts if not provided
if [ -z "$SubList" ]; then
  read -p "Enter subject IDs: " SubList
fi
if [ -z "$StudyFolder" ]; then
  read -p "Enter the StudyFolder path: " StudyFolder
fi

# Normalize Subject list (accept spaces or commas)
SubList=$(echo "$SubList" | tr ',' ' ')

# Paths
ScriptsFolder="/Users/moayedilab/Library/CloudStorage/OneDrive-UniversityofToronto/PhD/codes/HCP_pipelines/HCPpipelines-4.8.0/Examples/Scripts"

# Ordered step names (include melodic for explicit selection; exclude for --all)
ORDERED_STEPS=(
  pre-freesurfer
  freesurfer
  post-freesurfer
  fmri-volume
  fmri-surface
  melodic
  ica-fix
  post-fix
  msmall
  dedrift
)

# Default TASK parameters for ICA-FIX family (match prior usage)
DEFAULT_TASK_LIST="clench rest localizer stress"
DEFAULT_BANDPASS_TASKS="rest"

step_index() {
  local name="$1"; local i
  for ((i=0; i<${#ORDERED_STEPS[@]}; i++)); do
    if [[ "${ORDERED_STEPS[$i]}" == "$name" ]]; then echo "$i"; return 0; fi
  done
  echo ""; return 1
}

validate_step() {
  local s="$1"; step_index "$s" >/dev/null
}

# Build selected steps
SELECTED=()
if [[ "$RUN_MODE" == "all" ]]; then
  for s in "${ORDERED_STEPS[@]}"; do
    [[ "$s" == "melodic" ]] && continue
    SELECTED+=("$s")
  done
elif [[ "$RUN_MODE" == "steps" ]]; then
  IFS=',' read -r -a tmp <<< "$STEPS_ARG"
  for s in "${tmp[@]}"; do
    s=$(echo "$s" | xargs)
    validate_step "$s" || { echo "Invalid step: $s"; exit 1; }
    SELECTED+=("$s")
  done
elif [[ "$RUN_MODE" == "range" ]]; then
  if [[ -z "$FROM_STEP" ]]; then echo "--from is required for range mode"; exit 1; fi
  validate_step "$FROM_STEP" || { echo "Invalid --from step: $FROM_STEP"; exit 1; }
  local_from=$(step_index "$FROM_STEP")
  if [[ -n "$TO_STEP" ]]; then
    validate_step "$TO_STEP" || { echo "Invalid --to step: $TO_STEP"; exit 1; }
    local_to=$(step_index "$TO_STEP")
  else
    local_to=$((${#ORDERED_STEPS[@]}-1))
  fi
  if (( local_from > local_to )); then echo "--from must be before --to"; exit 1; fi
  for ((i=local_from; i<=local_to; i++)); do SELECTED+=("${ORDERED_STEPS[$i]}"); done
else
  # Default if not specified: run all (excluding melodic)
  for s in "${ORDERED_STEPS[@]}"; do
    [[ "$s" == "melodic" ]] && continue
    SELECTED+=("$s")
  done
fi

run_pre_freesurfer() {
  echo "$(timestamp)"
  echo "Running the Pre-FreeSurfer script"
  "$ScriptsFolder"/PreFreeSurferPipelineBatch.sh --StudyFolder="$StudyFolder" --Subject="$SubList"
}

run_freesurfer() {
  echo "$(timestamp)"
  echo "Running the FreeSurfer script"
  "$ScriptsFolder"/FreeSurferPipelineBatch.sh --StudyFolder="$StudyFolder" --Subject="$SubList"
}

run_post_freesurfer() {
  echo "$(timestamp)"
  echo "Running the Post-FreeSurfer script"
  "$ScriptsFolder"/PostFreeSurferPipelineBatch.sh --StudyFolder="$StudyFolder" --Subject="$SubList"
}

run_fmri_volume() {
  echo "$(timestamp)"
  echo "Running the Generic fMRI Volume Processing script"
  "$ScriptsFolder"/GenericfMRIVolumeProcessingPipelineBatch.sh --StudyFolder="$StudyFolder" --Subject="$SubList"
  # Task runs and volumes can also be specified in the following ways to override the defaults:
  # "$ScriptsFolder"/GenericfMRIVolumeProcessingPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList" --TaskSpec=clench_run-1:2:91 --TaskSpec=localizer_run-3:5:110
  # From file (CSV):
  # --TaskSpecFile=/path/tasks.csv
  # Example CSV:
  # clench_run-1,2,91
  # rest,,
  # stress_run-2,2,54

}

run_fmri_surface() {
  echo "$(timestamp)"
  echo "Running the Generic fMRI Surface Processing script"
  "$ScriptsFolder"/GenericfMRISurfaceProcessingPipelineBatch.sh --StudyFolder="$StudyFolder" --Subject="$SubList"
  # Task runs can also be specified to override the defaults:
  # "$ScriptsFolder"/GenericfMRISurfaceProcessingPipelineBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList" --TaskSpec=clench_run-1 --TaskSpec=localizer_run-3
}

run_melodic() {
  echo "$(timestamp)"
  echo "Running the MELODIC (MelodicOnly) script"
  # Provide default tasks for melodic-only run to ensure processing
  "$ScriptsFolder"/IcaFixMelodicOnlyProcessingBatch.sh --StudyFolder="$StudyFolder" --Subject="$SubList" \
    --task-list="$DEFAULT_TASK_LIST" --bandpass-tasks="$DEFAULT_BANDPASS_TASKS"
}

run_ica_fix() {
  echo "$(timestamp)"
  echo "Running the ICAFIX script"
  "$ScriptsFolder"/IcaFixProcessingBatch.sh --StudyFolder="$StudyFolder" --Subject="$SubList" \
    --task-list="$DEFAULT_TASK_LIST" --bandpass-tasks="$DEFAULT_BANDPASS_TASKS"
}

run_post_fix() {
  echo "$(timestamp)"
  echo "Running the post-ICAFIX script"
  "$ScriptsFolder"/PostFixBatch.sh --StudyFolder="$StudyFolder" --Subject="$SubList"
  # Task runs can also be specified to override the defaults:
  # "$ScriptsFolder"/PostFixBatch.sh --StudyFolder=$StudyFolder --Subject="$SubList" --TaskSpec=clench --TaskSpec=rest
}

run_msmall() {
  echo "$(timestamp)"
  echo "Running the MSMAll script"
  "$ScriptsFolder"/MSMAllPipelineBatch.sh --StudyFolder="$StudyFolder" --Subject="$SubList"
}

run_dedrift() {
  echo "$(timestamp)"
  echo "Running the DeDrift and Resample script"
  "$ScriptsFolder"/DeDriftAndResamplePipelineBatch.sh --StudyFolder="$StudyFolder" --Subject="$SubList"
}

run_step() {
  case "$1" in
    pre-freesurfer) run_pre_freesurfer ;;
    freesurfer) run_freesurfer ;;
    post-freesurfer) run_post_freesurfer ;;
    fmri-volume) run_fmri_volume ;;
    fmri-surface) run_fmri_surface ;;
    melodic) run_melodic ;;
    ica-fix) run_ica_fix ;;
    post-fix) run_post_fix ;;
    msmall) run_msmall ;;
    dedrift) run_dedrift ;;
    *) echo "Unknown step $1"; exit 1 ;;
  esac
}

# Execute selected steps
for step in "${SELECTED[@]}"; do
  run_step "$step"
done

echo "$(timestamp)"
echo "Done!"
