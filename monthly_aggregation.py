# -*- coding: utf-8 -*-
"""
Created on Oct 3 2023

@author: Yujuan
"""
import os
import glob
import math

import numpy as np
from tqdm import tqdm
import pandas as pd
import geopandas as gpd
import geopy.distance
# from agg_season import
import metpy.calc as mpcalc
from metpy.units import units
import metpy.constants as mpconsts
from scipy.stats import binned_statistic

os.chdir('/Users/gaoyujuan/REAP Dropbox/Gao yujuan/lightning_bolts/data/Climate_Data')


def cal_distance(point_1, point_2):
    '''
    calculate distance between two geographic points
    input: point: list, (lat,lon)
    output: Vincenty distance
    '''
    return geopy.distance.geodesic(point_1, point_2).km


def find_closest_n_points(n, point, df, geo_df):
    '''
    find closest n points in the dataset
    input: n: number of closest points
           point: village geo location
           df: dataframe that contains geo location and variables
    output: df for n closest points, shape(n*12, variables)
    '''

    geo_df['distance'] = geo_df['CDS_geo'].apply(lambda x: cal_distance(point, x))
    df = df.merge(geo_df[['lat', 'lon', 'distance']], how='left', on=['lat', 'lon'])
    df_subset = df.nsmallest(n * 4 * 29, 'distance')
    return df_subset


def cal_avg(n, df_subset, varlist):
    '''
    calculate average value for variable and distance
    input: subset df with n closest geo points, variable list
    output: df with average for distance and inverse weighted average value for variables group by year
    '''
    point_distance = pd.unique(df_subset['distance'])
    mean_distance = point_distance.mean()
    sum_inverse_distance = sum([1 / (d * d) for d in point_distance])
    df_subset['inverse distance weight'] = (1 / (df_subset['distance'] * df_subset['distance'])) / sum_inverse_distance
    # matrix multi
    for i in varlist:
        df_subset['weighted_' + i + '_' + str(n)] = df_subset[i] * df_subset['inverse distance weight']
    weighted_varlist = ['weighted_' + i + '_' + str(n) for i in varlist]
    weighted_varlist.append('seasons')
    avg_df = df_subset[weighted_varlist].groupby(['seasons']).sum()
    avg_df['avg_distance_' + str(n)] = mean_distance
    avg_df = avg_df.reset_index()
    return avg_df


def point_data(point, df, varlist, geo_df, nlist=[5]):
    '''
    collect monthly data for each individual village point
    input: point: village geo location
           df: dataframe that contains geo location and variables
           varlist
    output: point_df: inverse weighted average of variables and average distance for closest 1/3/5/10
    '''
    point_df = pd.DataFrame()
    for n in nlist:
        df_subset = find_closest_n_points(n, point, df, geo_df)
        avg_df = cal_avg(n, df_subset, varlist)
        if len(point_df) == 0:
            point_df = avg_df
        else:
            point_df = pd.merge(point_df, avg_df, on='seasons')
    # add point geo
    point_df['geo'] = [point] * len(point_df)
    return point_df


def merge_data(gdf, df, varlist, geo_df):
    '''
    merge monthly data for each individual village point
    input: gdf: df with villege geo point
    '''
    vdf = pd.DataFrame()
    for i in tqdm(range(len(gdf))):
        point = gdf.loc[i, 'geo']
        point_df = point_data(point, cds_df, varlist, geo_df)
        vdf = vdf.append(point_df, ignore_index=True)
    return vdf


def wet_bulb(t, RH):
    # formula: Stull (2011), https://journals.ametsoc.org/view/journals/apme/50/11/jamc-d-11-0143.1.xml
    t = np.array(t)
    RH = np.array(RH)
    return t * np.arctan(0.151977 * (RH + 8.313659) ** 0.5) + np.arctan(t + RH) - np.arctan(
        RH - 1.676331) + 0.00391838 * \
        RH ** 1.5 * np.arctan(0.023101 * RH) - 4.686035


def bin_temp(data, min=-40, max=40, step=5):
    data = data.values
    b = binned_statistic(data, data, 'count',
                         bins=(max - min) / step, range=(min, max))
    bin_count = b[0]
    return pd.Series(bin_count)


def bin_temp_ind(data, min=-40, max=40):
    if len(data) == data.isna().sum():
        return np.nan
    b = sum([i >= min and i < max for i in data])
    return (b)


if __name__ == '__main__':

    ystart, yend = 2010, 2011
    # read CDS data
    varlist_files = glob.glob("daily/*.csv")

    action_list = {'Vapour-Pressure-Mean': ['mean'],
                   'Precipitation-Rain-Duration-Fraction': ['mean'],
                   'Temperature-Air-2m-Max-24h': ['mean', 'bar'],
                   'Temperature-Air-2m-Mean-24h': ['mean', 'bar'],
                   'Temperature-Air-2m-Min-24h': ['mean', 'bar'],
                   'Wind-Speed-10m-Mean': ['mean'],
                   'Precipitation-Flux': ['sum'],
                   'Solar-Radiation-Flux': ['mean'],
                   'Apparent-Temperature-2m-Mean': ['mean', 'bar'],
                   'Wet-Bulb-Temperature-2m-Mean': ['mean', 'bar']
                   }
    t_range = [-40, 0, 5, 10, 15, 20, 25, 28, 30, 32, 34, 36, 38, 50]

    for y in range(ystart, yend):
        year_match = [f for f in varlist_files if str(y) in f]

        store_dict = {}
        for f in year_match:
            var = f.split("_")[0].split("/")[-1]
            var = var.split("_")[0].split("\\")[-1]
            store_dict[var] = pd.read_csv(f).sort_values(by=["date", "lat", "lon"])
            if (var == 'Relative-Humidity-2m'):
                store_dict[var].columns = store_dict[var].columns.str.replace("Relative_Humidity_2m_",
                                                                              "Relative_Humidity_2m")
        # calculate temperature indices
        tem_varname = 'Temperature-Air-2m-Mean-24h'
        tem_max_varname = 'Temperature-Air-2m-Max-24h'
        tem_min_varname = 'Temperature-Air-2m-Min-24h'
        rh_varname = 'Relative-Humidity-2m'
        ws_varname = 'Wind-Speed-10m-Mean'
        vp_varname = 'Vapour-Pressure-Mean'
        dp_varname = 'Dew-Point-Temperature-2m-Mean'

        # unit conversion
        store_dict[tem_varname][tem_varname.replace("-", "_")] = store_dict[tem_varname][
                                                                     tem_varname.replace("-", "_")] - 273.15
        store_dict[tem_min_varname][tem_min_varname.replace("-", "_")] = store_dict[tem_min_varname][
                                                                             tem_min_varname.replace("-", "_")] - 273.15
        store_dict[tem_max_varname][tem_max_varname.replace("-", "_")] = store_dict[tem_max_varname][
                                                                             tem_max_varname.replace("-", "_")] - 273.15
        store_dict[dp_varname][dp_varname.replace("-", "_")] = store_dict[dp_varname][
                                                                   dp_varname.replace("-", "_")] - 273.15

        # calculate apparent temperature
        apparent_temp_name = 'Apparent-Temperature-2m-Mean'
        # check if rh has the same size as temp. Repopulate if observing size difference.
        if store_dict[tem_varname][tem_varname.replace("-", "_")].size != store_dict[rh_varname][rh_varname.replace(
                "-", "_")].size:
            new_rh = store_dict[tem_varname].merge(store_dict[rh_varname], on=['lat', 'lon', 'date'], how='left')
            new_rh = new_rh.drop([tem_varname.replace("-", "_")], axis=1)
            store_dict[rh_varname] = new_rh
        apparent_temp = mpcalc.apparent_temperature(
            temperature=store_dict[tem_varname][tem_varname.replace("-", "_")].tolist() * units.degC,
            rh=store_dict[rh_varname][rh_varname.replace("-", "_")].tolist() * units.percent,
            speed=store_dict[ws_varname][ws_varname.replace("-", "_")].tolist() * units.meter / units.second,
            mask_undefined=False)
        # mask = np.isnan(store_dict[tem_varname][tem_varname.replace("-","_")].tolist()) == False
        temp_store = store_dict[tem_varname]
        temp_store[apparent_temp_name.replace("-", "_")] = apparent_temp
        temp_store = temp_store.drop(columns=[tem_varname.replace("-", "_")])
        store_dict[apparent_temp_name] = temp_store
        store_dict[tem_varname] = store_dict[tem_varname].drop(columns=[apparent_temp_name.replace("-", "_")])

        # calculate wet bulb temperature
        wet_bulb_temp_name = 'Wet-Bulb-Temperature-2m-Mean'
        wet_bulb_temp = wet_bulb(
            t=store_dict[tem_varname][tem_varname.replace("-", "_")],
            RH=store_dict[rh_varname][rh_varname.replace("-", "_")]
        )
        temp_store = store_dict[tem_varname]
        temp_store[wet_bulb_temp_name.replace("-", "_")] = wet_bulb_temp
        temp_store = temp_store.drop(columns=[tem_varname.replace("-", "_")])
        store_dict[wet_bulb_temp_name] = temp_store
        store_dict[tem_varname] = store_dict[tem_varname].drop(columns=[wet_bulb_temp_name.replace("-", "_")])
        print('done')

        # aggregate to monthly
        monthly_store = None
        for key in action_list.keys():
            temp_store = store_dict[key]
            temp_store = temp_store.drop_duplicates(['lat', 'lon', 'date'], keep='last')
            temp_store['month'] = temp_store['date'].str.slice(start=5, stop=7)
            temp_store['year'] = temp_store['date'].str.slice(start=0, stop=4)
            temp_store = temp_store[temp_store.year == str(y)]
            temp_store = temp_store.drop('year', axis=1)
            for action in action_list[key]:
                print(f'{y} {key} {action} started')
                if action == 'mean':
                    df = temp_store.groupby(['lat', 'lon', 'month']).mean().reset_index()
                if action == 'sum':
                    df = temp_store.groupby(by=['lat', 'lon', 'month']).sum(min_count=1).reset_index()
                if action == 'bar':
                    # obselete method: progress by 2 degrees
                    # step = 2
                    # xmin = math.floor(temp_store[key.replace("-","_")].min() / step) * step
                    # xmax = math.ceil(temp_store[key.replace("-","_")].max() / step) * step
                    temp_df = temp_store.drop('date', axis=1).groupby(by=['lat', 'lon', 'month']).sum(
                        min_count=1).reset_index()
                    temp_df = temp_df.drop(key.replace("-", "_"), axis=1)
                    columns = []
                    for r in range(len(t_range) - 1):
                        tmin, tmax = t_range[r], t_range[r + 1]
                        bin_name = f'{key}_[{tmin},{tmax})'
                        columns.append(bin_name)
                        temp_df[bin_name] = None
                        temp_calc = temp_store.drop('date', axis=1).groupby(by=['lat', 'lon', 'month'])[key.replace(
                            "-", "_")].apply(lambda x: bin_temp_ind(x, tmin, tmax))
                        temp_df[bin_name] = temp_calc.reset_index()[key.replace("-", "_")]
                        if temp_calc.max() > 31:
                            print(f'problem detected for {str(y)}')
                            print('debug stop')

                        print(f'{bin_name} done')
                    df = temp_df
                if monthly_store is None:
                    monthly_store = df
                    monthly_store['year'] = y
                    monthly_store = monthly_store[['lat', 'lon', 'year', 'month', key.replace("-", "_")]]
                else:
                    monthly_store = monthly_store.merge(df, 'outer', ['lat', 'lon', 'month'])
                print('done')
                # store individual processor
            print('done')
        monthly_store.to_csv(f'monthly_coord/{y}_weather_bycoord.csv')
        print(f'year {y} done')
    print('Monthly aggregation done')

