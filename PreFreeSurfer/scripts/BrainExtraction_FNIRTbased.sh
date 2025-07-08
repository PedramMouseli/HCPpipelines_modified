#!/bin/bash

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR, HCPPIPEDIR_Templates

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Tool for performing brain extraction using non-linear (FNIRT) results"

opts_AddMandatory '--mod' 'Modality' 'modality' 'image modality'

opts_AddMandatory '--in' 'Input' 'image' "input image"

opts_AddMandatory '--outbrain' 'OutputBrainExtractedImage' 'images' "output brain extracted image"

opts_AddMandatory '--outbrainmask' 'OutputBrainMask' 'mask' "output brain mask"

#optional args

opts_AddOptional '--workingdir' 'WD' 'path' 'working dir' "."

opts_AddOptional '--ref' 'Reference' 'image' 'reference image' "${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz"

opts_AddOptional '--refmask' 'ReferenceMask' 'mask' 'reference brain mask' "${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz"

opts_AddOptional '--ref2mm' 'Reference2mm' 'image' 'reference 2mm image' "${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz"

opts_AddOptional '--ref2mmmask' 'Reference2mmMask' 'mask' 'reference 2mm brain mask' "${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz"

opts_AddOptional '--fnirtconfig' 'FNIRTConfig' 'file' 'FNIRT configuration file' "$FSLDIR/etc/flirtsch/T1_2_MNI152_2mm.cnf"

opts_AddOptional '--regfrom' 'RegFrom' 'string' 'which image to use for registration, can be "input" or "alt". Default is "input".' "input"

opts_AddOptional '--in_alt' 'Input_alt' 'string' 'Alternative image used for registration' ""

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR
log_Check_Env_Var HCPPIPEDIR_Templates

################################################### OUTPUT FILES #####################################################

# All except variables starting with $Output are saved in the Working Directory:
#     roughlin.mat "$BaseName"_to_MNI_roughlin.nii.gz   (flirt outputs)
#     NonlinearRegJacobians.nii.gz IntensityModulatedT1.nii.gz NonlinearReg.txt NonlinearIntensities.nii.gz
#     NonlinearReg.nii.gz (the coefficient version of the warpfield)
#     str2standard.nii.gz standard2str.nii.gz   (both warpfields in field format)
#     "$BaseName"_to_MNI_nonlin.nii.gz   (spline interpolated output)
#    "$OutputBrainMask" "$OutputBrainExtractedImage"

################################################## OPTION PARSING #####################################################

BaseName=`${FSLDIR}/bin/remove_ext $Input`;
BaseName=`basename $BaseName`;

# Determine which image to use for registration
Input_alt="${Input}_mp2rage"
InputForReg=""
if [ "${Modality}" = "T1w" ] ; then
	InputForReg="${Input_alt}"
else
	InputForReg="${Input}"
fi

if [ "${RegFrom}" = "input" ] ; then
	InputForReg="${Input}"
elif [ "${RegFrom}" = "alt" ] ; then
	if [ "${Modality}" = "T1w" ] ; then
		InputForReg="${Input_alt}"
	elif [ "${Modality}" != "T1w" ] ; then
		InputForReg="${Input}"
	fi

elif [ -n "${RegFrom}" ] ; then
	log_Err_Abort "Invalid value for --regfrom: ${RegFrom}. Should be 'input' or 'alt'."
fi

verbose_echo "  "
verbose_red_echo " ===> Running FNIRT based brain extraction"
verbose_echo "  "
verbose_echo "  Parameters"
verbose_echo "  WD:                         $WD"
verbose_echo "  Input:                      $Input"
verbose_echo "  InputForReg:                $InputForReg"
verbose_echo "  Reference:                  $Reference"
verbose_echo "  ReferenceMask:              $ReferenceMask"
verbose_echo "  Reference2mm:               $Reference2mm"
verbose_echo "  Reference2mmMask:           $Reference2mmMask"
verbose_echo "  OutputBrainExtractedImage:  $OutputBrainExtractedImage"
verbose_echo "  OutputBrainMask:            $OutputBrainMask"
verbose_echo "  FNIRTConfig:                $FNIRTConfig"
verbose_echo "  BaseName:                   $BaseName"
verbose_echo " "
verbose_echo " START: BrainExtraction_FNIRT"
log_Msg "START: BrainExtraction_FNIRT"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ##########################################

# BET (StbthStrip)
ReferenceBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain.nii.gz"
Reference2mmBrain="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain.nii.gz"

/Applications/freesurfer/7.4.1/bin/mri_synthstrip -i "${Input}.nii.gz" -o "${OutputBrainExtractedImage}.nii.gz" -m "${OutputBrainMask}.nii.gz" --no-csf
if [ $Modality = T1w ] ; then

  verbose_echo " ... non-linear registration to 2mm reference"
  # run ANTs registration in python
  python "${HCPPIPEDIR}/ANTs/antsReg.py" "${InputForReg}.nii.gz" "$Reference" "${WD}/${BaseName}_"
  # Convert ANTs warp to FSL
  c3d_affine_tool -ref "$Reference" -src "${InputForReg}.nii.gz" -itk "${WD}/${BaseName}_0GenericAffine.mat" -ras2fsl -o "$WD"/roughlin.mat
  $CARET7DIR/wb_command -convert-warpfield -from-itk "${WD}/${BaseName}_1Warp.nii.gz" -to-fnirt "${WD}/${BaseName}_fnirt.nii.gz" "$Reference"
  ${FSLDIR}/bin/convertwarp --relout --ref="$Reference2mm" --premat="$WD"/roughlin.mat --warp1="${WD}/${BaseName}_fnirt.nii.gz" --out="$WD"/str2standard.nii.gz
  # Create the jacobian matrix from warp
  # First converting warp field to fnirt coefs equivalent to the fnirt's --cout
  fnirtfileutils --in="$WD"/str2standard.nii.gz --ref="$Reference2mm" --out="$WD"/NonlinearReg.nii.gz --outformat=spline
  # Creat jacobian from the coefs
  fnirtfileutils --in="$WD"/NonlinearReg.nii.gz --ref="$Reference2mm" --jac="$WD"/NonlinearRegJacobians.nii.gz

  # Overwrite the image output from FNIRT with a spline interpolated highres version
  verbose_echo " ... creating spline interpolated hires version"
  ${FSLDIR}/bin/applywarp --rel --interp=spline --in="$Input" --ref="$Reference" -w "$WD"/str2standard.nii.gz --out="$WD"/"$BaseName"_to_MNI_nonlin.nii.gz
  # Overwrite the linear registeration with the original image
  ${FSLDIR}/bin/flirt -in "${Input}.nii.gz" -applyxfm -init "$WD"/roughlin.mat -out "$WD"/"$BaseName"_to_MNI_roughlin.nii.gz -paddingsize 0.0 -interp spline -ref "$ReferenceBrain"

else

  verbose_echo " ... non-linear registration to 2mm reference"
  # run ANTs registration in python
  python "${HCPPIPEDIR}/ANTs/antsReg.py" "${InputForReg}.nii.gz" "$Reference" "${WD}/${BaseName}_"
  # Convert ANTs warp to FSL
  c3d_affine_tool -ref "$Reference" -src "${InputForReg}.nii.gz" -itk "${WD}/${BaseName}_0GenericAffine.mat" -ras2fsl -o "$WD"/roughlin.mat
  $CARET7DIR/wb_command -convert-warpfield -from-itk "${WD}/${BaseName}_1Warp.nii.gz" -to-fnirt "${WD}/${BaseName}_fnirt.nii.gz" "$Reference"
  ${FSLDIR}/bin/convertwarp --relout --ref="$Reference2mm" --premat="$WD"/roughlin.mat --warp1="${WD}/${BaseName}_fnirt.nii.gz" --out="$WD"/str2standard.nii.gz
  # Create the jacobian matrix from warp
  # First converting warp field to fnirt coefs equivalent to the fnirt's --cout
  fnirtfileutils --in="$WD"/str2standard.nii.gz --ref="$Reference2mm" --out="$WD"/NonlinearReg.nii.gz --outformat=spline
  # Creat jacobian from the coefs
  fnirtfileutils --in="$WD"/NonlinearReg.nii.gz --ref="$Reference2mm" --jac="$WD"/NonlinearRegJacobians.nii.gz

  verbose_echo " ... creating spline interpolated hires version"
  ${FSLDIR}/bin/applywarp --rel --interp=spline --in="$Input" --ref="$Reference" -w "$WD"/str2standard.nii.gz --out="$WD"/"$BaseName"_to_MNI_nonlin.nii.gz

  ${FSLDIR}/bin/flirt -in "${Input}.nii.gz" -applyxfm -init "$WD"/roughlin.mat -out "$WD"/"$BaseName"_to_MNI_roughlin.nii.gz -paddingsize 0.0 -interp spline -ref "$ReferenceBrain"

fi

# Invert warp and transform dilated brain mask back into native space, and use it to mask input image
# Input and reference spaces are the same, using 2mm reference to save time
verbose_echo " ... computing inverse warp"
${FSLDIR}/bin/invwarp --ref="$Reference2mm" -w "$WD"/str2standard.nii.gz -o "$WD"/standard2str.nii.gz

verbose_green_echo "---> Finished BrainExtraction FNIRT"

log_Msg "END: BrainExtraction_FNIRT"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the following brain mask does not exclude any brain tissue (and is reasonably good at not including non-brain tissue outside of the immediately surrounding CSF)" >> $WD/qa.txt
echo "fslview $Input $OutputBrainMask -l Red -t 0.5" >> $WD/qa.txt
echo "# Optional debugging: linear and non-linear registration result" >> $WD/qa.txt
echo "fslview $Reference2mm $WD/${BaseName}_to_MNI_roughlin.nii.gz" >> $WD/qa.txt
echo "fslview $Reference $WD/${BaseName}_to_MNI_nonlin.nii.gz" >> $WD/qa.txt

##############################################################################################
