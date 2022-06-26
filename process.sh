#!/bin/bash


############################################
# CORRECTIONS
############################################

# work in tutorial dir which contains the 3 subfolders in the BATMAN folder
cd $tutorialDir

# cat all data into a mif file (mrtrix file)
mrcat b1000_AP/ b2000_AP/ b3000_AP/ dwi_raw.mif

# remove noise
dwidenoise dwi_raw.mif dwi_den.mif -noise noise.mif

# take diff of old and new image file
mrcalc dwi_raw.mif dwi_den.mif -subtract residual.mif
mrview noise.mif residual.mif

# remove gibs artifacts
mrdegibbs dwi_den.mif dwi_den_unr.mif -axes 0,1

# Motion and distortion correction
dwiextract dwi_den_unr.mif - -bzero | mrmath - mean mean_b0_AP.mif
-axis 3

mrconvert b0_PA/ - | mrmath - mean mean_b0_PA.mif -axis 3

dwibiascorrect -ants dwi_den_unr_preproc.mif dwi_den_unr_preproc_unbiased.mif -bias bias.miVeraf

dwi2mask dwi_den_unr_preproc_unbiased.mif mask_den_unr_preproc_unb.mif

############################################
# FIBER ORIENTATION 
############################################

# Now we want to estimate the "response function" of different types of matter in the brain
# white matter (wm), gray matter (gm), and cerebal spinal fluid (csf)
# if we can distinguish between the different kinds of matter we can ignore irrelavant information
dwi2response dhollander dwi_den_unr_preproc_unbiased.mif wm.txt gm.txt csf.txt -voxels voxels.mif

# Response functions in hand we can now differentiate between tissue types and estimate orientation
dwi2fod msmt_csd dwi_den_unr_preproc_unbiased.mif -mask mask_den_unr_preproc_unb.mif wm.txt wmfod.mif gm.txt gmfod.mif csf.txt csffod.mif

mrconvert -coord 3 0 wmfod.mif - | mrcat csffod.mif gmfod.mif - vf.mif
mrview vf.mif -odf.load_sh wmfod.mif

# normalize stuff (not sure why this important, something about group studies)
mtnormalise wmfod.mif wmfod_norm.mif gmfod.mif gmfod_norm.mif csffod.mif csffod_norm.mif -mask mask_den_unr_preproc_unb.mif

mrcat gmfod_norm.mif csffod_norm.mif vf_norm.mif
mrview vf.mif -odf.load_sh wmfod_norm.mif

############################################
# TRACTOGRAM CREATION 
############################################

# In this tutorial we are going to do probabalistic tractography with ACT, so we need a high res T1 image
mrconvert ../T1/ T1_raw.mif
5ttgen fsl T1_raw.mif 5tt_nocoreg.mif

# What this allows us to do is identify where streamlines for end in the brain. Since we are using a probabalistic algorithm we may
# get false positives. IDing where tracks end allows us to easily filter these out. A high res image of the different types of matter makes this eaiser

# Coregister our data
dwiextract dwi_den_unr_preproc_unbiased.mif - -bzero | mrmath - mean mean_b0_preprocessed.mif -axis 3 -force
mrconvert mean_b0_preprocessed.mif mean_b0_preprocessed.nii.gz -force
mrconvert 5tt_nocoreg.mif 5tt_nocoreg.nii.gz -force
flirt -in mean_b0_preprocessed.nii.gz -ref 5tt_nocoreg.nii.gz -interp nearestneighbour -dof 6 -omat diff2struct_fsl.mat -force
transformconvert diff2struct_fsl.mat mean_b0_preprocessed.nii.gz 5tt_nocoreg.nii.gz flirt_import diff2struct_mrtrix.txt -force
mrtransform 5tt_nocoreg.mif -linear diff2struct_mrtrix.txt -inverse 5tt_coreg.mif -force

# View it
mrview dwi_den_unr_preproc_unbiased.mif -overlay.load 5tt_nocoreg.mif -overlay.colourmap 2 -overlay.load 5tt_coreg.mif -overlay.colourmap 1

mrview dwi_den_unr_preproc_unbiased.mif -overlay.load 5tt_coreg.mif -overlay.colourmap 1

mrview dwi_den_unr_preproc_unbiased.mif -overlay.load 5tt_nocoreg.mif -overlay.colourmap 2 


# Similar to getting a layer that tells us where streamlines end, we also would like a layer that tells us where they should start
# IE in gray/white matter boundry

# Mask for seeds that make sense vs not
5tt2gmwmi 5tt_coreg.mif gmwmSeed_coreg.mif

# View
mrview dwi_den_unr_preproc_unbiased.mif -overlay.load gmwmSeed_coreg.mif
mrview dwi_den_unr_preproc_unbiased.mif -overlay.load gmwmSeed_coreg.mif -overlay.colourmap 1 -overlay.load 5tt_coreg.mif -overlay.colourmap 2

# Create our tracks, this can take 4-6 hours
tckgen -act 5tt_coreg.mif -backtrack -seed_gmwmi gmwmSeed_coreg.mif -select 10000000 wmfod_norm.mif tracks_10mio.tck

# There are 10 million tracks in the original file it would be RAM intensive to view them all at once

# Randomly select a smaller subset
tckedit tracks_10mio.tck -number 200k smallerTracks_200k.tck

# View subset
mrview dwi_den_unr_preproc_unbiased.mif -tractography.load smallerTracks_200k.tck

# View with our expected delineations
mrview dwi_den_unr_preproc_unbiased.mif -tractography.load smallerTracks_200k.tck -overlay.load gmwmSeed_coreg.mif -overlay.colourmap 1 -overlay.load 5tt_coreg.mif -overlay.colourmap 2

# Apply filtering (this can also take several hours)
tcksift -act 5tt_coreg.mif -term_number 1000000 tracks_10mio.tck wmfod_norm.mif sift_1mio.tck

# Select and view subset
tckedit sift_1mio.tck -number 200k smallerSIFT_200k.tck
mrview dwi_den_unr_preproc_unbiased.mif -tractography.load smallerSIFT_200k.tck -overlay.load gmwmSeed_coreg.mif -overlay.colourmap 1 -overlay.load 5tt_coreg.mif -overlay.colourmap 2

mrview dwi_den_unr_preproc_unbiased.mif -tractography.load smallerSIFT_200k.tck 



############################################
# CONNECTOME CONSTRUCTION
############################################

# Copy atlas
cp ../Supplementary_Files/hcpmmp1_parcels_coreg.mif .

# Count connection points of tractogram to atlas regions
tck2connectome -symmetric -zero_diagonal -scale_invnodevol sift_1mio.tck hcpmmp1_parcels_coreg.mif hcpmmp1.csv -out_assignment assignments_hcpmmp1.csv

# we can view the connectome hcpmmp1.csv in matlab with the coe in mrtrix.m

# Interesting connections
connectome2tck -nodes 8,188 -exclusive sift_1mio.tck assignments_hcpmmp1.csv moto

# View after grabbing T1_coreg from supplementary files
mrview T1_coreg.mif -tractography.load moto8-188.tck


############################################
# VIEW CONNECTOME 
############################################

# We can use the connectome visualization tool included in MRtrix to look out a graph of our brain
mrview hcpmmp1_parcels_coreg.mif -connectome.init hcpmmp1_parcels_coreg.mif -connectome.load hcpmmp1.csv