#%%
import skimage as skim
import h5py as h5
import os
import numpy as np
import pandas as pd
import re



basepath = r'C:\Users\mengelhardt\data\local\ME019\P2_B1_tubaf647_vimcf660_test_exp30_f35000_2023-08-18_pos0_1'
loc_path =  os.path.join(basepath, 'new_loc\P2_B1_tubaf647_vimcf660_test_exp30_f35000_2023-08-18_pos0_NDTiffStack_1_gaussfit_dc_sml.mat')

locs_filenames = [fname for fname in os.listdir(basepath) if fname.endswith('sml.mat') ]

T_path = os.path.join(basepath, 'new_loc\P2_B1_tubaf647_vimcf660_test_exp30_f35000_2023-08-18_pos0_NDTiffStack_1_gaussfit_T.mat')

#%% mat file loading
fdata = h5.File(loc_path,'r')
#T_data = h5.File(T_path,'r')

#%% casting to np arrays
cols = ['frame', 'locprecnm', 'logLikelihood', 'xnm', 'xpix', 'ynm', 'ypix', 'phot']

locs=[]
with h5.File(loc_path, "r") as h5f:
    for col in cols:
        locs.append(np.array(h5f['saveloc']['loc'][col]).squeeze())
    df = pd.DataFrame(np.transpose(locs), columns=cols)

img = skim.io.imread(image_path)
print(img.shape)
#T = np.array(T_data.get('transformation')).astype(np.float32)
#%%



data_crops = []
coords = []
bbox_size = 15
for frame in df.frame:
    for x,y in zip(df[df.frame==frame].xpix, df[df.frame==frame].ypix):
        data_crops.append(crop_bbox(img[int(frame),:,:], (x,y)))
        coords.append((x,y))
