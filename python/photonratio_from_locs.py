import numpy as np
import h5py
import os
import pandas as pd
import matplotlib as plt

def locs_from_mat(mat):
    locs = {}
    for key in mat['saveloc']['loc'].keys():
        locs[key] = mat['saveloc']['loc'][key][0,:]
    return locs


def batch_process(paths=None):
    for p in paths:
        hist = main(p)


def main(path):
    filenames = [f for f in os.listdir(path) if f.endswith('.mat')]
    locs = {}
    for f in filenames:
        locs[f]={}
        locs[f]['data'] = h5py.File(os.path.join(path, f), libver='earliest')
        locs[f]['locs'] = locs_from_mat(locs[f]['data'])
        df = pd.DataFrame.from_dict(locs[f]['locs'])
        #df['xnm'].plot.hist()
        df.plot.hist()
        plt.show



    return 


cwd = os.getcwd()
path = r'data'
path = os.path.join(cwd,path)
main(path)
