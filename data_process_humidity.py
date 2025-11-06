# -*- coding: utf-8 -*-
"""
Created on Wed Feb 16 23:52:56 2022

@author: Liz
"""
import os
import glob
import pandas as pd
import zipfile
import xarray as xr
# import datetime as dt
from sys import platform

os.chdir('../../data/cds_climate')

path = "humidity/raw"
os.chdir(path)

print('start')

def decom(zipfile_name):
    '''
    decompress the downloaded file
    return paths of decompressed files
    '''
    path_list = []
    with zipfile.ZipFile(zipfile_name) as zf:
        for n in zf.namelist():
            path_list.append(zf.extract(n))
    return path_list

# Temperature: 'Temperature_Air_2m_Mean_24h'
# Wind Speed: Wind_Speed_10m_Mean
    
def nc2df(path, variable):
    ds = xr.open_dataset(path, decode_cf=True)
    #subset lat and lon bounds
    lat_bnds, lon_bnds = [28, 19], [87, 94]
    ds = ds.sel(lat=slice(*lat_bnds), lon=slice(*lon_bnds))
    df = ds.to_dataframe()
    df = df.reset_index()
    #change data format
    df['date'] = pd.to_datetime(df['time']).dt.date
    df[variable] = df[variable].astype(float)
    df = df.drop(['time'], axis = 1)
    df = df[['lat','lon','date', variable]]
    return df


var = 'Relative_Humidity_2m_'
all_zip = glob.glob('*.zip')
ystart, yend = 1980, 2022

# unzip and extract netcdf
for y in range(ystart,yend):
    if not os.path.exists('../daily'):
        os.mkdir('../daily')
    year_match = [f for f in all_zip if str(y) in f]
    df_store = pd.DataFrame()
    for f in year_match:
        print(f)
        m = f[4:6]
        path_list = decom(zipfile_name = f)
        splitter = "\\" if platform == "win32" else "/"
        path_list = [p.split(splitter)[-1] for p in path_list]
        hour_list = list(set([p[58:61]for p in path_list]))
        df = pd.DataFrame()
        for h in hour_list:
            hour_match = [f for f in path_list if str(h) in f]
            var1 = var+h
            for p in hour_match:
                df1 = nc2df(path = p, variable = var1)
                df1['hour'] = h
                df1 = df1.rename(columns={var1:var})
                df = df.append(df1)
        df = df.sort_values(by="date")
        df_daily = df.groupby(['lat','lon','date']).mean(numeric_only=True).reset_index()
        print(f+' done')
        df_store = df_store.append(df_daily)
    var1 = var.replace("_","-")[0:-1]
    df_store.to_csv(".." + splitter + "daily" + splitter + var1 + '_' + str(y) + '.csv', index=False)
    print('year ' + str(y) + ' done')

