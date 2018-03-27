# -*- coding: utf-8 -*-s
'''
Created on Apr 29, 2014
@author: ewilson
      : jalley
'''
from __future__ import division
import os, sys
import pandas

sys.path.insert(0, os.path.join(os.getcwd(), 'clustering'))
# from medoids_tstat import do_plot
# import itertools
# recs_data_file = os.path.join("..", "RECS STUFF", "recs2009_public.csv")
import psycopg2 as pg
import pandas as pd
from datetime import datetime
# import matplotlib.pyplot as plt
import random
import numpy as np
from collections import OrderedDict

startTime = datetime.now()
#Dictionary for RECS to ResStock terminology
dependency_dict = {'typehuq': 'Building_Type',
                   'regionc': 'Census_Region',
                   'stories': 'Geometry_Stories',
                   'cr': 'Location_Region',
                   'Size': 'Geometry_House_Size',
                   'yearmaderange': 'Vintage',
                   'equipm': 'Heating_Equipment',
                   'fuelh2o': 'Heater_Fuel_Water',
                   'rngfuel': 'Heating_Fuel_Stove',
                   'dryrfuel': 'Heating_Fuel_Dryer',
                   'equipage': 'Heating_Equipment_Age',
                   'cooltype': 'AC_Type',
                   'agecenac': 'Central_AC_Sys_Age',
                   'wwacage': 'Window_AC_Sys_Age',
                   'sizeofgarage': 'Size_of_Garage',
                   'division': 'Location_Census_division',
                   'region': 'Location_Region',
                   'fuelheat': 'Heating_Fuel_Type',
                   'typeglass': 'Glazing_Type',
                   'householder_race': 'Household_Race',
                   'education': 'Education',
                  }

bldg_typ_dict = {1: 'Mobile Home',
                 2: 'Single-Family Detached',
                 3: 'Single-Family Attached',
                 4: 'Multi-Family with 2 - 4 Units',
                 5: 'Multi-Family with 5+ Units'}
race_dict = {1: 'White Alone',
             2: 'Black or African/American Alone',
             3: 'American Indian Alone',
             4: 'Asian Alone',
             5: 'Pacific Islander Alone',
             6: 'Other Race Alone',
             7: '2 or More Races Selected'}
education_dict = {0: 'No Schooling Completed',
                  1: 'Kindergarten to Grade 12',
                  2: 'High School Diploma/GED',
                  3: 'Some College, No Degree',
                  4: "Associate's Degree",
                  5: "Bachelor's Degree",
                  6: "Master's Degree",
                  7: 'Professional Degree',
                  8: 'Doctorate Degree'}
region_def = {1: 'CR01',
              2: 'CR02',
              3: 'CR03',
              4: 'CR04',
              5: 'CR05',
              6: 'CR06',
              7: 'CR07',
              8: 'CR08',
              9: 'CR09',
              10: 'CR10',
              11: 'CR11',
              12: 'CR12'}
vintages = {1: '1950-pre',
            2: '1950s',
            3: '1960s',
            4: '1970s',
            5: '1980s',
            6: '1990s',
            7: '2000s',
            8: '2000s'}
fuels = {1: 'Natural Gas',
         2: 'Propane/LPG',
         3: 'Fuel Oil',
         5: 'Electricity',
         4: 'Other Fuel',
         7: 'Other Fuel',
         8: 'Other Fuel',
         9: 'Other Fuel',
         21: 'Other Fuel',
         -2: 'None'}
cooltype_dict = {1: 'Central System',
                 2: 'Window/wall Units',
                 3: 'Both',
                 -2: 'No A/C'}
equipage_dict = {1: '< 2 yrs',
                 2: '2-4 yrs',
                 3: '5-9 yrs',
                 41: '10-14 yrs',
                 42: '15-19 yrs',
                 5: '20+ yrs',
                 -2: 'N/A'}
agecenac_dict = {1: '< 2 yrs',
                 2: '2-4 yrs',
                 3: '5-9 yrs',
                 41: '10-14 yrs',
                 42: '15-19 yrs',
                 5: '20+ yrs',
                 -2: 'N/A'}
wwacage_dict = {1: '< 2 yrs',
                2: '2-4 yrs',
                3: '5-9 yrs',
                41: '10-14 yrs',
                42: '15-19 yrs',
                5: '20+ yrs',
                -2: 'N/A'}
typeglass_dict = {1: '1 Pane',
                  2: '2+ Pane',
                  3: '2+ Pane',
                  -2: 'No Windows'}
sizes = {500: '0-1499',
         1000: '0-1499',
         2000: '1500-2499',
         3000: '2500-3499',
         4000: '3500+',
         5000: '3500+',
         6000: '3500+',
         7000: '3500+',
         8000: '3500+',
         9000: '3500+',
         10000: '3500+'}
story_dict = {10: 1,
              20: 2,
              40: 2,
              31: 2,
              32: 2}
income_range = {1: '$02,500 and under',
                2: '$02,500 to $4,999',
                3: '$05,000 to $7,499',
                4: '$07,500 to $9,999',
                5: '$10,000 to $14,999',
                6: '$15,000 to $19,999',
                7: '$20,000 to $24,999',
                8: '$25,000 to $29,999',
                9: '$30,000 to $34,999',
                10: '$35,000 to $39,999',
                11: '$40,000 to $44,999',
                12: '$45,000 to $49,999',
                13: '$50,000 to $54,999',
                14: '$55,000 to $59,999',
                15: '$60,000 to $64,999',
                16: '$65,000 to $69,999',
                17: '$70,000 to $74,999',
                18: '$75,000 to $79,999',
                19: '$80,000 to $84,999',
                20: '$85,000 to $89,999',
                21: '$90,000 to $94,999',
                22: '$95,000 to $99,999',
                23: '$100,000 to $119,999',
                24: '$120,000 or More'}
med_income = {1: 1250,
              2: 3250,
              3: 6250,
              4: 8750,
              5: 12250,
              6: 17250,
              7: 22250,
              8: 27250,
              9: 32250,
              10: 37250,
              11: 42250,
              12: 47250,
              13: 52250,
              14: 57250,
              15: 62250,
              16: 67250,
              17: 72250,
              18: 77250,
              19: 82250,
              20: 87250,
              21: 92250,
              22: 97250,
              23: 110000,
              24: 120000}
wall_type = {1: 'Brick',
             2: 'Wood',
             3: 'Siding',
             4: 'Stucco',
             5: 'Composition',
             6: 'Stone',
             7: 'Concrete',
             8: 'Glass',
             9: 'Other'}
roof_type = {1: 'Ceramic/Clay',
             2: 'Wood Shingles/Shakes',
             3: 'Metal',
             4: 'Slate',
             5: 'Composition Shingles',
             6: 'Asphalt',
             7: 'Concrete Tiles',
             8: 'Other'}
fpl16 = {1: 11880,
         2: 16020,
         3: 20160,
         4: 24300,
         5: 28440,
         6: 32580,
         7: 36730,
         8: 40890}  # Add 4,180 for each additional person
fpl09 = {1: 10830,
         2: 14570,
         3: 18310,
         4: 22050,
         5: 25790,
         6: 29530,
         7: 33270,
         8: 37010}
census_div = {1: 'New England Census Division (CT, MA, ME, NH, RI, VT)',
              2: 'Middle Atlantic Census Division (NJ, NY, PA)',
              3: 'East North Central Census Division (IL, IN, MI, OH, WI)',
              4: 'West North Central Census Division (IA, KS, MN, MO, ND, NE, SD)',
              5: 'South Atlantic  Census Division (DC, DE, FL, GA, MD, NC, SC, VA, WV)',
              6: 'East South Central Census Division (AL, KY, MS, TN)',
              7: 'West South Central Census Division (AR, LA, OK, TX)',
              8: 'Mountain North Sub-Division (CO, ID, MT, UT, WY)',
              9: 'Mountain South Sub-Division (AZ, NM, NV)',
              10: 'Pacific Census Division (AK, CA, HI, OR, WA)'}
region_def = {1: 3,
              2: 3,
              3: 7,
              4: 7,
              5: 7,
              6: 4,
              7: 4,
              8: 4,
              9: 2,
              10: 2,
              11: 8,
              12: 8,
              13: 8,
              14: 8,
              15: 9,
              16: 9,
              17: 9,
              18: 9,
              19: 8,
              20: 9,
              21: 9,
              22: 5,
              23: 5,
              24: 10,
              25: 10,
              26: 11,
              27: 6}
cr_str = {1: 'CR01',
          2: 'CR02',
          3: 'CR03',
          4: 'CR04',
          5: 'CR05',
          6: 'CR06',
          7: 'CR07',
          8: 'CR08',
          9: 'CR09',
          10: 'CR10',
          11: 'CR11',
          12: 'CR12'}
garage_dict = {1: "1 Car",
               2: "2 Car",
               3: "3+ Car",
               -2: "None"}
stories_dict = {10: '1',
                20: '2+',
                31: '2+',
                32: '2+',
                40: '2+',
                50: 'Other',
                -2: 'N/a'}
randincome_dict = {-1: 0000,
                   0: 0000,
                   1: 2500,
                   2: 5000,
                   3: 7500,
                   4: 10000,
                   5: 15000,
                   6: 20000,
                   7: 25000,
                   8: 30000,
                   9: 35000,
                   10: 40000,
                   11: 45000,
                   12: 50000,
                   13: 55000,
                   14: 60000,
                   15: 65000,
                   16: 70000,
                   17: 75000,
                   18: 80000,
                   19: 85000,
                   20: 90000,
                   21: 95000,
                   22: 100000,
                   23: 110000,
                   24: 120000,
                   25: 200000}
numglass_dict = {'1 Pane',
                 '2+ Pane',
                 'No Windows'}
fpl = fpl09
heating_types = {2: 'Steam or Hot Water System',  # 'Steam or Hot Water System',
                 3: 'Central Warm-Air Furnace',  # 'Central Warm-Air Furnace'      ,
                 4: 'Heat Pump',  # 'Heat Pump'                     ,
                 5: 'Built-In Electric Units',  # 'Built-In Electric Units'       ,
                 6: 'Floor or Wall Pipeless Furnace',  # 'Floor or Wall Pipeless Furnace',
                 7: 'Floor or Wall Pipeless Furnace',  # 'Built-In Room Heater'          ,
                 8: 'Other Equipment',  # 'Heating Stove'                 ,
                 9: 'Other Equipment',  # 'Fireplace'                     ,
                 10: 'Built-In Electric Units',  # 'Portable Electric Heaters'     ,
                 11: 'Other Equipment',  # 'Portable Kerosene Heaters'     ,
                 12: 'Other Equipment',  # 'Cooking Stove'                 ,
                 21: 'Other Equipment',  # 'Other Equipment'               ,
                 -2: 'Not Applicable'}  # 'Not Applicable'}


def retrieve_data():
    if not os.path.exists('eia.recs_2009_microdata.pkl'):
        con_string = "host = gispgdb.nrel.gov port = 5432 dbname = dav-gis user = jalley password = jalley"
        con = con = pg.connect(con_string)
        sql = """SELECT *
                FROM eia.recs_2009_microdata;"""
        df = pd.read_sql(sql, con)
        df.to_pickle('eia.recs_2009_microdata.pkl')
    df = pd.read_pickle('eia.recs_2009_microdata.pkl')
    return df


def assign_size_bins(df):
    df['Intsize'] = df[['tothsqft', 'totcsqft']].max(axis=1)
    df.loc[:, 'Size'] = 0
    df.loc[(df['Intsize'] < 1500), 'Size'] = '0-1499'
    df.loc[(df['Intsize'] >= 1500) & (df['Intsize'] < 2500), 'Size'] = '1500-2499'
    df.loc[(df['Intsize'] >= 2500) & (df['Intsize'] < 3500), 'Size'] = '2500-3499'
    df.loc[(df['Intsize'] >= 3500), 'Size'] = '3500+'
    return df


def process_data(df):
    # create new fields for numerical processing later (correlation stuff)
    df['num_glass'] = df.apply(lambda x: x['typeglass'] if x['typeglass'] > 0 else 0, axis=1)
    # Select Single Family Detached Housing Only
    #df = df.loc[df['typehuq'] == {1,2,3,4,5}]
    df = df.reset_index()

    # recs_column_names = df.columns.values
    df.columns = [dependency_dict.get(x,x) for x in df.columns]

    # Apply dictionaries for mapping RECS response fields
    field_dicts = {
                   'Building_Type': bldg_typ_dict,
                   'Heating_Equipment': heating_types,
                   'Location_Census_division': census_div,
                   'AC_Type': cooltype_dict,
                   'Vintage': vintages,
                   'Heating_Fuel_Type': fuels,
                   'Heater_Fuel_Water': fuels,
                   'Heating_Fuel_Stove': fuels,
                   'Heating_Fuel_Dryer': fuels,
                   'Heating_Equipment_Age': equipage_dict,
                   'Central_AC_Sys_Age': agecenac_dict,
                   'Window_AC_Sys_Age': wwacage_dict,
                   'Glazing_Type': typeglass_dict,
                   'Household_Race': race_dict,
                   'Education': education_dict,
                   'Size_of_Garage': garage_dict,
                   'Geometry_Stories': stories_dict}
    for field_name, field_dict in field_dicts.iteritems():
        for num, name in field_dict.iteritems():
            df.loc[:, field_name].replace(num, name, inplace=True)
    df = assign_size_bins(df)

    df['Count'] = 1
    return df


def calc_general(df, dependency, char_pd=None, outfile=None, norm=True, outpath="housing_characteristics"):

    dependency = dependency + ['Building_Type']

    if not outfile == 'Infiltration.tsv':

        # following exercise is redundant
        # keep the count and weightage of the concatenated dependencies
        # total_count = df.groupby(dependency)['Count'].sum()
        # total number of occurance of the concatenated string of dependencies in dependency
        # total_nweight = df.groupby(dependency)['nweight'].sum()
        # create pivot table with dependencies as index and "vintage options as values"

        #1. Create the concatenate dependency column by creating a combined list of all the dependencies
        fields = dependency + char_pd
        combos = [list(set(df[field])) for field in fields]  # changes into a list format

        # 2. utilize advanced indexing capabilities of pandas for creating a multiindex
        # which would be useful for automatically populating the target columns based on the indexed dependencies
        index = pd.MultiIndex.from_product(combos, names=fields)

        # create a pivot table based on this indexing

        g = df.groupby(fields).sum()
        g = g['nweight'].reindex(index)
        g = g.fillna(0).reset_index()
        g = pd.pivot_table(g, index=dependency, columns=char_pd, values='nweight').reset_index()
        # add 2 coulmns to the pivot table corresponding to the count and total weightage of each dependency
        #                                                                                       combination "dependency"
        # for now, store the weightage in a seaprate tuple Weight, will add to the dataframe after
    #                                                   the normalization is done for the #values of the pivot table
        Weight = g[g.columns[len(dependency):]].sum(axis=1)
        # total number of occurance of the concatenated string of dependencies in dependency

        # for gettig the count of each row in the pivot table, separate dataframe is required
        ct = df.groupby(fields).sum()
                            # concatenates the dependencies and target characteristisc to utilize it as a indexing
                            # for generating the pivot table; the function: sum() adds up the rows with identical
                            # values of the "fields  "
        ct = ct['Count'].reindex(index)
                            # set the multiindex output as the index of the dataframe containin only the Count coulmn
        ct = ct.fillna(0).reset_index()
                            # fill the empty values with 0 and  get the indexed columns back in dataframe
        ct = pd.pivot_table(ct, index=dependency, columns=char_pd, values='Count').reset_index()
                            # set up the pivot table with the dependencies as index, columnns as column headers and
                            # their corresponding counts as the Values of the pivot table
        length = len(dependency)
                            # save the output in a variable, which can used as the starting point of the range i.e.
                            # to be id'd by the next function

        Count = ct[ct.columns[length:]].sum(axis=1)
                            # get the sum of the input values in the options column of the dataframe and save it
                            # in a separate variable so that it can be merged to the final output dataframe once all
                            # the essential formating operations have been performed on the dataframe 'g'

        # Normalize Data
        if norm:
            total = g.sum(axis=1)
            if isinstance(g.columns, pandas.core.index.MultiIndex):
                for col in g.columns:
                    if not col[0] in dependency:
                        g[col] = g[col] / total
            else:
                for col in g.columns:
                    if not col in dependency:
                        g[col] = g[col] / total
        g['Count'] = Count
        g['Weight'] = Weight

    else:

        g = pd.read_csv('housing_characteristics/Infiltration.tsv', delimiter='\t')
        for col in g.columns:
            g = g.rename(columns={col: col.replace('char_pd=', '')})
            g = g.rename(columns={col: col.replace('Dependency=', '')})
    #Rename columns
    # print dependency
    # dependency = [x.replace('typehuq','Building type') for x in dependency]
    # dependency = [x.replace('yearmaderange', 'Vintage') for x in dependency]
    # dependency = [x.replace('Size', 'Geometry House Size') for x in dependency]
    # dependency = [x.replace('CR', 'Location Region') for x in dependency]
    # dependency = [x.replace('stories', 'Geometry Stories') for x in dependency]
    
    g = g.rename(
        columns={'3+ Car': '3 Car',
                 'East North Central Census Division (IL, IN, MI, OH, WI)': 'East North Central',
                 'East South Central Census Division (AL, KY, MS, TN)': 'East South Central',
                 'Middle Atlantic Census Division (NJ, NY, PA)': 'Middle Atlantic',
                 'Mountain North Sub-Division (CO, ID, MT, UT, WY)': 'Mountain North',
                 'Mountain South Sub-Division (AZ, NM, NV)': 'Mountain South',
                 'New England Census Division (CT, MA, ME, NH, RI, VT)': 'New England',
                 'Pacific Census Division (AK, CA, HI, OR, WA)': 'Pacific',
                 'South Atlantic  Census Division (DC, DE, FL, GA, MD, NC, SC, VA, WV)': 'South Atlantic',
                 'West North Central Census Division (IA, KS, MN, MO, ND, NE, SD)': 'West North Central',
                 'West South Central Census Division (AR, LA, OK, TX)': 'West South Central'})
        # columns = {'typehuq': 'Building type', 'yearmaderange': 'Vintage', 'Size': 'Geometry House Size', '3+ Car': '3 Car',
        #            'CR': 'Location Region', 'Stories': 'Geometry Stories',
        #            'Region': 'Location Region',
        #            'East North Central Census Division (IL, IN, MI, OH, WI)': 'East North Central',
        #            'East South Central Census Division (AL, KY, MS, TN)': 'East South Central',
        #            'Middle Atlantic Census Division (NJ, NY, PA)': 'Middle Atlantic',
        #            'Mountain North Sub-Division (CO, ID, MT, UT, WY)': 'Mountain North',
        #            'Mountain South Sub-Division (AZ, NM, NV)': 'Mountain South',
        #            'New England Census Division (CT, MA, ME, NH, RI, VT)': 'New England',
        #            'Pacific Census Division (AK, CA, HI, OR, WA)': 'Pacific',
        #            'South Atlantic  Census Division (DC, DE, FL, GA, MD, NC, SC, VA, WV)': 'South Atlantic',
        #            'West North Central Census Division (IA, KS, MN, MO, ND, NE, SD)': 'West North Central',
        #            'West South Central Census Division (AR, LA, OK, TX)': 'West South Central'})
    if 'Location_Census_division' in g.columns:
        g['Mountain - Pacific'] = g['Mountain North'].values + g['Mountain South'].values + g['Pacific'].values
        del g['Mountain North']
        del g['Mountain South']
        del g['Pacific']
        g['South Atlantic - East South Central'] = g['South Atlantic'].values + g['East South Central'].values
        del g['South Atlantic']
        del g['East South Central']

        g = g[['Location Region', 'East North Central', 'Middle Atlantic', 'New England', 'West North Central',
           'West South Central', 'Mountain - Pacific', 'South Atlantic - East South Central', 'Count', 'Weight']]

    # Rename rows
    if 'Vintage' in g.columns:
        g['Vintage'] = g['Vintage'].replace({'1950-pre': '<1950'})
        g['Vintage'] = g['Vintage'].replace({'pre-1950': '<1950'})
    if 'Location Region' in g.columns:
        g['Location Region'] = g['Location Region'].replace({1: 'CR01',
            2: 'CR02', 3: 'CR03', 4: 'CR04', 5: 'CR05', 6: 'CR06', 7: 'CR07', 8: 'CR08', 9: 'CR09',
            10: 'CR10', 11: 'CR11', 12: 'CR12'})

    # Add Headers for char_pd and Dependency
    rename_dict = {}
    for col in g.columns:
        if col in ['Weight', 'Count']:
            rename_dict[col] = str(col)
        else:
            if col in dependency:
                rename_dict[col] = 'Dependency=' + str(col)
            else:
                rename_dict[col] = 'char_pd=' + str(col)
    g = g.rename(columns=rename_dict)

    # Reduce garage size for small houses
    if outfile == 'Geometry Garage.tsv':
        g = g.fillna(0)
        g.loc[g['Dependency=Building_Type'] == 'Mobile Home', 'char_pd=1 Car'] = 0
        g.loc[g['Dependency=Building_Type'] == 'Mobile Home', 'char_pd=2 Car'] = 0
        g.loc[g['Dependency=Building_Type'] == 'Mobile Home', 'char_pd=3 Car'] = 0
        g.loc[g['Dependency=Building_Type'] == 'Mobile Home', 'char_pd=None'] = 1

        g.loc[g['Dependency=Building_Type'] == 'Multi-Family with 2 - 4 Units', 'char_pd=1 Car'] = 0
        g.loc[g['Dependency=Building_Type'] == 'Multi-Family with 2 - 4 Units', 'char_pd=2 Car'] = 0
        g.loc[g['Dependency=Building_Type'] == 'Multi-Family with 2 - 4 Units', 'char_pd=3 Car'] = 0
        g.loc[g['Dependency=Building_Type'] == 'Multi-Family with 2 - 4 Units', 'char_pd=None'] = 1

        g.loc[g['Dependency=Building_Type'] == 'Multi-Family with 5+ Units', 'char_pd=1 Car'] = 0
        g.loc[g['Dependency=Building_Type'] == 'Multi-Family with 5+ Units', 'char_pd=2 Car'] = 0
        g.loc[g['Dependency=Building_Type'] == 'Multi-Family with 5+ Units', 'char_pd=3 Car'] = 0
        g.loc[g['Dependency=Building_Type'] == 'Multi-Family with 5+ Units', 'char_pd=None'] = 1
        g.loc[g['Dependency=Geometry_House_Size'] == '0-1499', 'char_pd=2 Car'] =\
            g.loc[g['Dependency=Geometry_House_Size'] == '0-1499', 'char_pd=2 Car'] +\
            g.loc[g['Dependency=Geometry_House_Size'] == '0-1499', 'char_pd=3 Car']
        g.loc[g['Dependency=Geometry_House_Size'] == '0-1499', 'char_pd=3 Car'] = 0

    # Generate Outfile
    if not outfile is None:
        g.to_csv(os.path.join(outpath, outfile), sep='\t', index=False)
        print g
        print os.path.abspath(os.path.join(outpath, outfile))
    return g


def save_to_tsv(g, dependency, char_pd, outfile):
    rename_dict = {}
    for col in g.columns:
        if col in dependency:
            rename_dict[col] = 'Dependency=' + col
        if col in char_pd:
            rename_dict[col] = 'char_pd=' + col
    g = g.rename(char_pd=rename_dict)
    print g
    g.to_csv(outfile, sep='\t', index=False)


def assign_poverty_levels(df):
    # Generate Random Income Distribution
    df['rand_income'] = df['moneypy']
    for i in range(0, df['moneypy'].count()):
        x = df.iloc[i]['moneypy']
        df.loc[(i, 'rand_income')] = random.randint(randincome_dict[x], randincome_dict[(x + 1)])
    #    for b in randincome_dict.iteritems():
    #        if b[0] == 25:
    #            break
    #
    #        df.loc[(df['moneypy']==(b[0]+1)),'rand_income']=random.randint(b[1],randincome_dict[(b[0]+1)])
    df['income_range'] = df['moneypy']
    df['income'] = df['moneypy']
    for income_range_num, income_range_name in income_range.iteritems():
        df['income_range'].replace(income_range_num, income_range_name, inplace=True)
    for num, name in med_income.iteritems():
        df['income'].replace(num, name, inplace=True)
    inflation_2009_to_2016 = 1.125344
    df['inf_income'] = df['income'] * inflation_2009_to_2016
    df['incomelimit'] = df['nhsldmem']
    for fpl_num, fpl_name in fpl.iteritems():
        for field in ['incomelimit']:
            df.loc[:, field].replace(fpl_num, fpl_name, inplace=True)
    df['FPL'] = df['income'] / df['incomelimit'] * 100
    df['FPLALL'] = 1
    levels = ['FPL300', 'FPL250', 'FPL200', 'FPL150', 'FPL100', 'FPL50']
    for lvl in levels:
        df[lvl] = 0
    df.loc[(df['FPL'] <= 300), 'FPL300'] = 1
    df.loc[(df['FPL'] <= 250), 'FPL250'] = 1
    df.loc[(df['FPL'] <= 200), 'FPL200'] = 1
    df.loc[(df['FPL'] <= 150), 'FPL150'] = 1
    df.loc[(df['FPL'] <= 100), 'FPL100'] = 1
    df.loc[(df['FPL'] <= 50), 'FPL50'] = 1
    # Create FPL Bins
    df['FPL_BINS'] = 0
    df.loc[(df['FPL'] >= 300), 'FPL_BINS'] = "300+"
    df.loc[(df['FPL'] >= 250) & (df['FPL'] < 300), 'FPL_BINS'] = "250-300"
    df.loc[(df['FPL'] >= 200) & (df['FPL'] < 250), 'FPL_BINS'] = "200-250"
    df.loc[(df['FPL'] >= 150) & (df['FPL'] < 200), 'FPL_BINS'] = "150-200"
    df.loc[(df['FPL'] >= 100) & (df['FPL'] < 150), 'FPL_BINS'] = "100-150"
    df.loc[(df['FPL'] >= 50) & (df['FPL'] < 100), 'FPL_BINS'] = "50-100"
    df.loc[(df['FPL'] < 50), 'FPL_BINS'] = "0-50"
    return df


def custom_region(df):
    df['CR'] = df['reportable_domain']
    df['CR'].replace(region_def, inplace=True)
    # Split out Kentucky and put in 8:
    df.ix[(df['reportable_domain'] == 18) & (df['aia_zone'] == 3), 'CR'] = 8
    # Split out Hawaii and put in 12:
    df.ix[(df['reportable_domain'] == 27) & ((df['aia_zone'] == 5) | (df['hdd65'] < 4000)), 'CR'] = 12
    # Split out Alaska and put in 1:
    df.ix[(df['reportable_domain'] == 27) & (df['hdd65'] > 6930), 'CR'] = 1  # Source for 6930 HDD: Dennis Barley
    return df


def foundation_type(df):
    # Number of different foundation types
    df['numfoundations'] = 0
    df['numfoundations'] = df.apply(
        lambda x: x['crawl'] + x['cellar'] + x['concrete'] if x['crawl'] > -2 and x['cellar'] > -2 and x[
            'concrete'] > -2 else 0, axis=1)
    # Foundation Type
    df['Foundation Type'] = 'Pier and Beam'
    df.loc[(df['numfoundations'] == 0), 'Foundation Type'] = 'Pier and Beam'
    #    df.loc[(df['numfoundations'] > 1), 'Foundation Type'] = 'Multiple Foundation Types'
    df.loc[(df['numfoundations'] == 1) & (df['crawl'] == 1), 'Foundation Type'] = 'Crawl'
    df.loc[(df['numfoundations'] == 1) & (df['concrete'] == 1), 'Foundation Type'] = 'Slab'
    df.loc[(df['numfoundations'] == 1) & (df['cellar'] == 1) & (
                df['baseheat'] == 1), 'Foundation Type'] = 'Heated Basement'
    df.loc[(df['numfoundations'] == 1) & (df['cellar'] == 1) & (
                df['baseheat'] == 0), 'Foundation Type'] = 'Unheated Basement'
    # Implement Weight and Count Changes
    df['nweight'] = df.apply(lambda x: x['nweight'] / x['numfoundations'] if x['numfoundations'] > 1 else x['nweight'],
                             axis=1)
    df['Count'] = df.apply(lambda x: x['Count'] / x['numfoundations'] if x['numfoundations'] > 1 else x['Count'],
                           axis=1)
    df_new = pd.DataFrame()
    for fnd in ['concrete', 'crawl', 'cellar']:
        df_this_fnd = df.loc[(df['numfoundations'] > 1) & (df[fnd] == 1)]
        df_this_fnd.loc[df_this_fnd['Foundation Type'] == fnd]
        df_new = df_new.append(df_this_fnd)
    df_new.loc[(df_new['Foundation Type'] == 'cellar') & (df['baseheat'] == 1), 'Foundation Type'] = 'Heated Basement'
    df_new.loc[(df_new['Foundation Type'] == 'cellar') & (df['baseheat'] == 0), 'Foundation Type'] = 'Unheated Basement'
    df_new.loc[(df_new['Foundation Type'] == 'concrete'), 'Foundation Type'] = 'Slab'
    df_new.loc[(df_new['Foundation Type'] == 'crawl'), 'Foundation Type'] = 'Crawl'
    df = df.append(df_new)
    return df


# def calc_occupancy(df):
#     dependency = ['Size']#,'Stories']
#     for num, name in stories.iteritems():
#         df['Stories'].replace(num,name, inplace=True)
#     for num, name in sizes.iteritems():
#         df['Size'].replace(num,name, inplace=True)
# #    df[df['Size'] == 0]['Size'] = df[df['Size'] == 0]['SizeExactTotal']
#     df['Size'].replace(0, pandas.np.nan, inplace=True)
#     df['Size'] = df['Size'].combine_first(df['SizeExactTotal'])
#     grouped = df.groupby(dependency)
#     for name, group in grouped:
#         avg_occs = (group['NHSLDMEM'] * group['NWEIGHT'] * 1.0).sum() / group['NWEIGHT'].sum()
#         avg_baths = (group['NumBaths'] * group['NWEIGHT'] * 1.0).sum() / group['NWEIGHT'].sum()
#         avg_size = (group['Size'] * group['NWEIGHT'] * 1.0).sum() / group['NWEIGHT'].sum()
#         print ','.join([name, str(avg_occs), str(avg_baths), str(avg_size)])
def query_stories(df, outfile='recs_query_stories.csv'):
    g = calc_general(df, dependency=['Vintage', 'Size'], char_pd=['stories'], outfile='Geometry stories.tsv')
    fnd_types = ['Crawl',
                 'Heated Basement',
                 'Pier and Beam',
                 'Slab',
                 'Unheated Basement']
    dfs = []
    for fnd_type in fnd_types:
        df2 = g.copy()
        df2['Foundation Type'] = fnd_type
        # Redistribute 1-story weighting factors if not heated basement
        if fnd_type != 'Heated Basement':
            df2.loc[df2['Size'] == '4500+', 2] += df2.loc[df2['Size'] == '4500+', 1]
            df2.loc[df2['Size'] == '4500+', 1] = 0
        dfs.append(df2)
    df = pandas.concat(dfs)
    df = df[['Vintage', 'Size', 'Foundation Type', 1, 2, 3]]
    df.to_csv(outfile, index=False)
    print df


def corr(x, y, w):
    def m(x, w):
        return np.sum(x * w) / np.sum(w)

    def cov(x, y, w):
        return np.sum(w * (x - m(x, w)) * (y - m(y, w))) / np.sum(w)

    return cov(x, y, w) / np.sqrt(cov(x, x, w) * cov(y, y, w))


def med_avg(slice_by, column, df, outfile):
    x = df[slice_by].value_counts()
    idx = sorted(x.index.tolist())
    median = []
    mean = []
    w_mean = []
    for i in range(len(idx)):
        # Implement Weight
        w = df.loc[df[slice_by] == idx[i], 'nweight']
        m = df.loc[df[slice_by] == idx[i], column]
        median.append(m.median())
        mean.append(m.mean())
        w_mean.append((m * w).sum() / w.sum())
    data = {'Median': median, 'Mean': mean, 'Weighted Mean': w_mean}
    g = pd.DataFrame(data)
    g.insert(0, slice_by, idx)
    g.to_csv(outfile, sep='\t', index=False)


def regenerate():
    # Use this to regenerate processed data if changes are made to any of the classes below
    df = retrieve_data()
    df = assign_size_bins(df)
    df = process_data(df)
    df = custom_region(df)
    df = assign_poverty_levels(df)
    # df = foundation_type(df)
    df = df.reset_index()
    df.to_pickle('processed_eia.recs_2009_microdata.pkl')
    return df


def erin_boyd():
    years = ['2009', '2015']
    bldgtypes = {'singlefamily': [2, 3], 'multifamily': [4, 5], 'mobile': [1]}
    fields = ['percentage', 'number']
    field_short_dict = {'percentage': ' (%)',
                        'number': ' (#)'}
    for k, v in bldgtypes.items():
        dfs = []
        for year in years:

            for field in fields:

                if year == '2009':
                    df_2009_full = retrieve_data()
                    df_2009 = df_2009_full.loc[df_2009_full['typehuq'].isin(v)]

                    # #1

                    # % of homes with baseboard heat
                    label = 'Built-in electric units'
                    if field == 'percentage':
                        df = df_2009[df_2009['equipm'] == 5].groupby('division')['nweight'].sum() / \
                             df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[df_2009['equipm'] == 5].groupby('division')['nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # % of homes with electric furnaces
                    label = 'Electric furnace'
                    if field == 'percentage':
                        df = df_2009[(df_2009['equipm'] == 3) & (df_2009['fuelheat'] == 5)].groupby('division')[
                                 'nweight'].sum() / df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[(df_2009['equipm'] == 3) & (df_2009['fuelheat'] == 5)].groupby('division')[
                            'nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # % of homes with heat pumps
                    label = 'Heat pump'
                    if field == 'percentage':
                        df = df_2009[df_2009['equipm'] == 4].groupby('division')['nweight'].sum() / \
                             df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[df_2009['equipm'] == 4].groupby('division')['nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # % of homes with electric heating
                    label = 'Total electric heating'
                    if field == 'percentage':
                        df = df_2009[df_2009['fuelheat'] == 5].groupby('division')['nweight'].sum() / \
                             df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[df_2009['fuelheat'] == 5].groupby('division')['nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # #2
                    label = 'Heat pump with no central AC'
                    if field == 'percentage':
                        # % of homes with heat pump and no central AC
                        df = df_2009[(df_2009['equipm'] == 4) & (
                                    (df_2009['cooltype'] == 2) | (df_2009['cooltype'] == -2))].groupby('division')[
                                 'nweight'].sum() / df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[(df_2009['equipm'] == 4) & (
                                    (df_2009['cooltype'] == 2) | (df_2009['cooltype'] == -2))].groupby('division')[
                            'nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Heat pump used for secondary space heating'
                    if field == 'percentage':
                        # % of homes with heat pump used for secondary space heating
                        df = df_2009[df_2009['reverse'] == 1].groupby('division')['nweight'].sum() / \
                             df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[df_2009['reverse'] == 1].groupby('division')['nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))
                    label = 'Have central duct system'
                    if field == 'percentage':
                        # % of homes with central AC or Central AC/Room AC or furnace
                        df = df_2009[(df_2009['cooltype'] == 1) | (df_2009['cooltype'] == 3) | (
                                    df_2009['equipm'] == 3)].groupby('division')['nweight'].sum() / \
                             df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[
                            (df_2009['cooltype'] == 1) | (df_2009['cooltype'] == 3) | (df_2009['equipm'] == 3)].groupby(
                            'division')['nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # #3
                    label = 'Have central duct system and room AC'
                    if field == 'percentage':
                        # % of homes with both room ACs and central AC or central warm-air furnace
                        df = df_2009[((df_2009['cooltype'] == 2) & (df_2009['equipm'] == 3)) | (
                                    df_2009['cooltype'] == 3)].groupby('division')['nweight'].sum() / \
                             df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[((df_2009['cooltype'] == 2) & (df_2009['equipm'] == 3)) | (
                                    df_2009['cooltype'] == 3)].groupby('division')['nweight'].sum()  # 2009
                        dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Have central duct system and room AC only'
                    if field == 'percentage':
                        # % of homes with both room ACs and central AC or central warm-air furnace
                        df = df_2009[((df_2009['cooltype'] == 2) & (df_2009['equipm'] == 3))].groupby('division')[
                                 'nweight'].sum() / df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[((df_2009['cooltype'] == 2) & (df_2009['equipm'] == 3))].groupby('division')[
                            'nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # label = 'Have central duct system and room AC only or unused central AC' # Not available in RECS 2015, so comment out for 2009
                    # if field == 'percentage':
                    #     # % of homes with both room ACs and central AC or central warm-air furnace
                    #     df = df_2009[((df_2009['cooltype']==2) & (df_2009['equipm']==3)) | (df_2009['cooltypenoac']==1) | (df_2009['cooltypenoac']==3)].groupby('division')['nweight'].sum() / df_2009.groupby('division')['nweight'].sum() # 2009
                    # else:
                    #     df = df_2009[((df_2009['cooltype']==2) & (df_2009['equipm']==3)) | (df_2009['cooltypenoac']==1) | (df_2009['cooltypenoac']==3)].groupby('division')['nweight'].sum() # 2009
                    # dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # #4
                    label = 'Electric heat and central AC'
                    if field == 'percentage':
                        # % of homes with electric heating and central AC
                        df = \
                        df_2009[(df_2009['fuelheat'] == 5) & (df_2009['cooltype'].isin([1, 3]))].groupby('division')[
                            'nweight'].sum() / df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = \
                        df_2009[(df_2009['fuelheat'] == 5) & (df_2009['cooltype'].isin([1, 3]))].groupby('division')[
                            'nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Electric heat and room AC'
                    if field == 'percentage':
                        # % of homes with electric heating and room AC
                        df = \
                        df_2009[(df_2009['fuelheat'] == 5) & (df_2009['cooltype'].isin([2, 3]))].groupby('division')[
                            'nweight'].sum() / df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = \
                        df_2009[(df_2009['fuelheat'] == 5) & (df_2009['cooltype'].isin([2, 3]))].groupby('division')[
                            'nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Electric heat and no AC'
                    if field == 'percentage':
                        # % of homes with electric heating and no AC
                        df = df_2009[(df_2009['fuelheat'] == 5) & (df_2009['cooltype'] == -2)].groupby('division')[
                                 'nweight'].sum() / df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[(df_2009['fuelheat'] == 5) & (df_2009['cooltype'] == -2)].groupby('division')[
                            'nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # 07/19/17
                    label = 'Room AC only'
                    if field == 'percentage':
                        # % of homes with room AC
                        df = df_2009[df_2009['cooltype'].isin([2])].groupby('division')['nweight'].sum() / \
                             df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[df_2009['cooltype'].isin([2])].groupby('division')['nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))
                    label = 'Room AC and Central AC used'
                    if field == 'percentage':
                        # % of homes with room AC
                        df = df_2009[df_2009['cooltype'].isin([2, 3])].groupby('division')['nweight'].sum() / \
                             df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[df_2009['cooltype'].isin([2, 3])].groupby('division')['nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))
                    # 07/20/17
                    label = 'Built-in electric units with ducts'
                    if field == 'percentage':
                        # % of homes with central AC or Central AC/Room AC. and built-in electric heat
                        df = df_2009[((df_2009['cooltype'] == 1) | (df_2009['cooltype'] == 3)) & (
                                    df_2009['equipm'] == 5)].groupby('division')['nweight'].sum() / \
                             df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[((df_2009['cooltype'] == 1) | (df_2009['cooltype'] == 3)) & (
                                    df_2009['equipm'] == 5)].groupby('division')['nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))
                    label = 'Built-in electric units without ducts'
                    if field == 'percentage':
                        # % of homes with room AC or no AC. and built-in electric heat
                        df = df_2009[((df_2009['cooltype'] != 1) & (df_2009['cooltype'] != 3)) & (
                                    df_2009['equipm'] == 5)].groupby('division')['nweight'].sum() / \
                             df_2009.groupby('division')['nweight'].sum()  # 2009
                    else:
                        df = df_2009[((df_2009['cooltype'] != 1) & (df_2009['cooltype'] != 3)) & (
                                    df_2009['equipm'] == 5)].groupby('division')['nweight'].sum()  # 2009
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                elif year == '2015':
                    df_2015_full = pd.read_csv(os.path.join('..', 'recs2015_public_v1.csv'))
                    df_2015_full = df_2015_full.loc[df_2015_full['TYPEHUQ'].isin(v)]
                    df_2015 = df_2015_full.rename(columns={'DIVISION': 'division'})

                    # #1
                    label = 'Built-in electric units'
                    if field == 'percentage':
                        # % of homes with baseboard heat
                        df = df_2015[df_2015['EQUIPM'] == 5].groupby('division')['NWEIGHT'].sum() / \
                             df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[df_2015['EQUIPM'] == 5].groupby('division')['NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Electric furnace'
                    if field == 'percentage':
                        # % of homes with electric furnaces
                        df = df_2015[(df_2015['EQUIPM'] == 3) & (df_2015['FUELHEAT'] == 5)].groupby('division')[
                                 'NWEIGHT'].sum() / df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[(df_2015['EQUIPM'] == 3) & (df_2015['FUELHEAT'] == 5)].groupby('division')[
                            'NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Heat pump'
                    if field == 'percentage':
                        # % of homes with heat pumps
                        df = df_2015[df_2015['EQUIPM'] == 4].groupby('division')['NWEIGHT'].sum() / \
                             df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[df_2015['EQUIPM'] == 4].groupby('division')['NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Total electric heating'
                    if field == 'percentage':
                        # % of homes with electric heating
                        df = df_2015[df_2015['FUELHEAT'] == 5].groupby('division')['NWEIGHT'].sum() / \
                             df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[df_2015['FUELHEAT'] == 5].groupby('division')['NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # #2
                    label = 'Heat pump with no central AC'
                    if field == 'percentage':
                        # % of homes with heat pump and no central AC
                        df = df_2015[(df_2015['EQUIPM'] == 4) & (
                                    (df_2015['COOLTYPE'] == 2) | (df_2015['COOLTYPE'] == -2))].groupby('division')[
                                 'NWEIGHT'].sum() / df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[(df_2015['EQUIPM'] == 4) & (
                                    (df_2015['COOLTYPE'] == 2) | (df_2015['COOLTYPE'] == -2))].groupby('division')[
                            'NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Heat pump used for secondary space heating'
                    if field == 'percentage':
                        # % of homes with heat pump used for secondary space heating
                        df = pd.Series(data=[np.nan] * 10, index=range(1, 11), name='division')
                    else:
                        df = pd.Series(data=[np.nan] * 10, index=range(1, 11), name='division')
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # #3
                    label = 'Have central duct system'
                    if field == 'percentage':
                        # % of homes with central AC or Central AC/Room AC or furnace
                        df = df_2015[(df_2015['COOLTYPE'] == 1) | (df_2015['COOLTYPE'] == 3) | (
                                    df_2015['EQUIPM'] == 3)].groupby('division')['NWEIGHT'].sum() / \
                             df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[
                            (df_2015['COOLTYPE'] == 1) | (df_2015['COOLTYPE'] == 3) | (df_2015['EQUIPM'] == 3)].groupby(
                            'division')['NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Have central duct system and room AC'
                    if field == 'percentage':
                        # % of homes with both room ACs and central AC or central warm-air furnace
                        df = df_2015[((df_2015['COOLTYPE'] == 2) & (df_2015['EQUIPM'] == 3)) | (
                                    df_2015['COOLTYPE'] == 3)].groupby('division')['NWEIGHT'].sum() / \
                             df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[((df_2015['COOLTYPE'] == 2) & (df_2015['EQUIPM'] == 3)) | (
                                    df_2015['COOLTYPE'] == 3)].groupby('division')['NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Have central duct system and room AC only'
                    if field == 'percentage':
                        # % of homes with both room ACs and central AC or central warm-air furnace
                        df = df_2015[((df_2015['COOLTYPE'] == 2) & (df_2015['EQUIPM'] == 3))].groupby('division')[
                                 'NWEIGHT'].sum() / df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[((df_2015['COOLTYPE'] == 2) & (df_2015['EQUIPM'] == 3))].groupby('division')[
                            'NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # #4
                    label = 'Electric heat and central AC'
                    if field == 'percentage':
                        # % of homes with electric heating and central AC
                        df = \
                        df_2015[(df_2015['FUELHEAT'] == 5) & (df_2015['COOLTYPE'].isin([1, 3]))].groupby('division')[
                            'NWEIGHT'].sum() / df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = \
                        df_2015[(df_2015['FUELHEAT'] == 5) & (df_2015['COOLTYPE'].isin([1, 3]))].groupby('division')[
                            'NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Electric heat and room AC'
                    if field == 'percentage':
                        # % of homes with electric heating and room AC
                        df = \
                        df_2015[(df_2015['FUELHEAT'] == 5) & (df_2015['COOLTYPE'].isin([2, 3]))].groupby('division')[
                            'NWEIGHT'].sum() / df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = \
                        df_2015[(df_2015['FUELHEAT'] == 5) & (df_2015['COOLTYPE'].isin([2, 3]))].groupby('division')[
                            'NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    label = 'Electric heat and no AC'
                    if field == 'percentage':
                        # % of homes with electric heating and no AC
                        df = df_2015[(df_2015['FUELHEAT'] == 5) & (df_2015['COOLTYPE'] == -2)].groupby('division')[
                                 'NWEIGHT'].sum() / df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[(df_2015['FUELHEAT'] == 5) & (df_2015['COOLTYPE'] == -2)].groupby('division')[
                            'NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # 07/19/17
                    label = 'Room AC only'
                    if field == 'percentage':
                        # % of homes with room AC
                        df = df_2015[df_2015['COOLTYPE'] == 2].groupby('division')['NWEIGHT'].sum() / \
                             df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[df_2015['COOLTYPE'] == 2].groupby('division')['NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))
                    label = 'Room AC and Central AC used'
                    if field == 'percentage':
                        # % of homes with room AC
                        df = df_2015[df_2015['COOLTYPE'].isin([2, 3])].groupby('division')['NWEIGHT'].sum() / \
                             df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[df_2015['COOLTYPE'].isin([2, 3])].groupby('division')['NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

                    # 07/20/17
                    label = 'Built-in electric units with ducts'
                    if field == 'percentage':
                        # % of homes with central AC or Central AC/Room AC. and built-in electric heat
                        df = df_2015[((df_2015['COOLTYPE'] == 1) | (df_2015['COOLTYPE'] == 3)) & (
                                    df_2015['EQUIPM'] == 5)].groupby('division')['NWEIGHT'].sum() / \
                             df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[((df_2015['COOLTYPE'] == 1) | (df_2015['COOLTYPE'] == 3)) & (
                                    df_2015['EQUIPM'] == 5)].groupby('division')['NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))
                    label = 'Built-in electric units without ducts'
                    if field == 'percentage':
                        # % of homes with room AC or no AC. and built-in electric heat
                        df = df_2015[((df_2015['COOLTYPE'] != 1) & (df_2015['COOLTYPE'] != 3)) & (
                                    df_2015['EQUIPM'] == 5)].groupby('division')['NWEIGHT'].sum() / \
                             df_2015.groupby('division')['NWEIGHT'].sum()  # 2015
                    else:
                        df = df_2015[((df_2015['COOLTYPE'] != 1) & (df_2015['COOLTYPE'] != 3)) & (
                                    df_2015['EQUIPM'] == 5)].groupby('division')['NWEIGHT'].sum()  # 2015
                    dfs.append(df.to_frame((label + field_short_dict[field], year)))

        df = pd.concat(dfs, axis=1)
        df.to_csv('{}.csv'.format(k))

    sys.exit()


# NEW QUERIES
def query(df):
    #    calc_general(df, dependency=['CR', 'FPL_BINS'], char_pd=['Vintage'], outfile='output_calc_CR_FPL_by_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['equipm'], outfile = 'heatingequipment_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['equipm'], outfile = 'heatingequipment_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['fuelheat'], outfile = 'heatingfuel_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['Size'], outfile = 'Size_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['equipage'], outfile = 'heating_equipment_age_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['cooltype'], outfile = 'AC_type_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['agecenac'], outfile = 'Central-AC-Sys-Age_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['wwacage'], outfile = 'Window-AC-Sys-Age_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['temphome'], outfile = 'Temp-Winter-Home_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['tempgone'], outfile = 'Temp-Winter-Gone_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['tempnite'], outfile = 'Temp-Winter-Night_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['temphomeac'], outfile = 'Temp-Summer-Home_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['tempgoneac'], outfile = 'Temp-Summer-Gone_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['tempniteac'], outfile = 'Temp-Summer-Night_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['typeglass'], outfile = 'Window-Type_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['nhsldmem'], outfile = 'Household-Occ-Num_output_by_CR_FPL_vintage.tsv')
    #     calc_general(df, dependency=['CR','FPL_BINS','Vintage'], outfile = '_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Vintage'], char_pd = ['Size_of_Garage'], outfile = 'SizeofGarage_output_by_CR_FPL_vintage.tsv')
    #    calc_general(df, dependency=['FPL_BINS','Vintage'], char_pd = ['Size_of_Garage'], outfile = 'SizeofGarage_output_by_FPL_vintage.tsv')
    #    calc_general(df, dependency=['Vintage','Size'], char_pd = ['Size_of_Garage'], outfile = 'SizeofGarage_output_by_vintage_size.tsv')
    #    calc_general(df, dependency=['Vintage','Size'], char_pd = ['Foundation Type'], outfile = 'FoundationType_output_by_vintage_size.tsv')
    #    calc_general(df, dependency=['CR','FPL_BINS','Size'], char_pd = ['Size_of_Garage'], outfile = 'SizeofGarage_output_by_CR_FPL_Size.tsv')
    #    calc_general(df, dependency=['Vintage','Size','Foundation Type'], char_pd = ['stories'], outfile = 'Stories_output_by_vin_size_fndtype.tsv')
     #   calc_general(df, dependency=['Vintage', 'Size'], char_pd=['stories'], outfile='Geometry Stories.tsv',outpath='../../../project_resstock_multifamily/housing_characteristics')
    #    calc_general(df, dependency=['Vintage','Size'], char_pd = ['Size_of_Garage'], outfile = 'Geometry Garage.tsv', outpath='../../../project_resstock_multifamily/housing_characteristics')
    #    calc_general(df, dependency=['CR'], char_pd = ['division'], outfile = 'Location Census Division.tsv', outpath='../../../project_resstock_national/housing_characteristicsl')
    #    calc_general(df, dependency=['CR','Vintage','Size','stories'], char_pd = [], outfile = 'Infiltration.tsv', outpath='../../../project_resstock_national/housing_characteristics')
    #    calc_general(df, dependency=['CR', 'Vintage','fuels'], char_pd=['stories'], outfile='Geometry Stories.tsv',
                 #outpath='../../../project_resstock_multifamily/housing_characteristics')
    #    calc_general(df, dependency=['CR', 'Vintage', 'fuelheat'], char_pd=['equipm'],
    #        outfile='heatingequipment_output_by_CR_fuel_vintage.tsv')
        calc_general(df, dependency=['Vintage', 'Geometry_House_Size'], char_pd = ['Size_of_Garage'], outfile = 'Geometry Garage.tsv',outpath='../../../project_resstock_multifamily/housing_characteristics')
        pass


if __name__ == '__main__':
    # Choose regerate if you want to redo the processed pkl file, otherwise comment out
    # df = erin_boyd()

    df = regenerate()
    df = pd.read_pickle('processed_eia.recs_2009_microdata.pkl')
    query(df)
    # med_avg('Size','tothsqft',df,'Sizes_mean_median.tsv')
    # med_avg('income_range','rand_income',df,'Income_mean_median.tsv')
    print datetime.now() - startTime
