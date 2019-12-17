import os
import pandas as pd
import parameter_option_maps
import itertools
import shutil
import numpy as np

this_file = os.path.basename(__file__)
dir_of_this_file = os.path.basename(os.path.dirname(__file__))
parent_dir_of_this_file = os.path.basename(os.path.dirname(os.path.dirname(__file__)))
created_by = os.path.join(parent_dir_of_this_file, dir_of_this_file, this_file)
source = ' using U.S. EIA 2015 Residential Energy Consumption Survey (RECS) microdata'

projects = ['project_singlefamilydetached', 'project_multifamily_beta', 'project_testing']
for project in projects:
    project_dir = os.path.join(os.path.dirname(__file__), project)
    if not os.path.exists(project_dir):
        os.mkdir(project_dir)

count_col_label = '[For Reference Only] Source Sample Size'
weight_col_label = '[For Reference Only] Source Weight'

class TSVMaker():
    
    def __init__(self, file):
        self.df = pd.read_csv(file, index_col=['DOEID'])
        self.df[count_col_label] = 1

    def bedrooms(self):
        df = self.df.copy()
        
        df = parameter_option_maps.map_geometry_building_type(df)
        df = parameter_option_maps.map_geometry_house_size(df)
        df = parameter_option_maps.map_bedrooms(df)
        
        dependency_cols = ['Geometry Building Type', 'Geometry House Size']
        option_col = 'Bedrooms'
        
        for project in projects:
            bedrooms = df.copy()
            
            bedrooms, count, weight = self.groupby_and_pivot(bedrooms, dependency_cols, option_col)
            bedrooms = self.add_missing_dependency_rows(bedrooms, project, count, weight)
            bedrooms = self.rename_cols(bedrooms, dependency_cols, project)
            
            filepath = os.path.join(os.path.dirname(__file__), project, '{}.tsv'.format(option_col))        
            self.export_and_tag(bedrooms, filepath, project)
            self.copy_file_to_project(filepath, project)

    def occupants(self):
        df = self.df.copy()
        
        df = parameter_option_maps.map_geometry_building_type(df)
        df = parameter_option_maps.map_bedrooms(df)
        df = parameter_option_maps.map_occupants(df)
        
        dependency_cols = ['Geometry Building Type', 'Bedrooms']
        option_col = 'Occupants'
        
        for project in projects:
            occupants = df.copy()
        
            occupants, count, weight = self.groupby_and_pivot(occupants, dependency_cols, option_col)
            occupants = self.add_missing_dependency_rows(occupants, project, count, weight)
            occupants = self.rename_cols(occupants, dependency_cols, project)
            
            filepath = os.path.join(os.path.dirname(__file__), project, '{}.tsv'.format(option_col))        
            self.export_and_tag(occupants, filepath, project)
            self.copy_file_to_project(filepath, project)
        
        return occupants
  
    def groupby_and_pivot(self, df, dependency_cols, option_col):
        """
        Subset the dataframe to columns of interest. Pivot the table, row sum the source weights, and divide each element by its row sum.

        Parameters:
          df (dataframe): The path of the tsv file to copy to projects' housing_characteristics folders.
          dependency_cols (list): A list of the dependency column names.
          option_col (str): The name of the tsv file. This dataframe column contains mapped items from the data source.
          
        Returns:
          df (dataframe): A pandas dataframe with dependency/option columns and fractions.
          count (dataframe): A pandas dataframe with dependency columns and source sample sizes.
          weight (dataframe): A pandas dataframe with dependency columns and source weights.

        """
        df = df[dependency_cols + [option_col] + [count_col_label] + ['NWEIGHT']]
        groups = df.groupby(dependency_cols + [option_col]).sum()
        df = groups.reset_index()
        count = df[dependency_cols + [count_col_label]]
        count = count.groupby(dependency_cols).sum()
        count = count.reset_index()        
        df = df.pivot_table(index=dependency_cols, columns=option_col, values='NWEIGHT')
        option_cols = df.columns.values
        df[weight_col_label] = df.sum(axis=1)
        weight = df[[weight_col_label]]
        weight = weight.reset_index()
        df = df[list(option_cols)].div(df[weight_col_label], axis=0)
        df = df[option_cols]
        df = df.fillna(0)
        return df, count, weight

    def add_missing_dependency_rows(self, df, project, count, weight):
        """
        Add combinations of dependencies for which we have no sample data; distribute option probabilities for these rows uniformly.

        Parameters:
          df (dataframe): A pandas dataframe with dependency/option columns and fractions.
          project (str): Name of the project.
          count (dataframe): A pandas dataframe with dependency columns and source sample sizes.
          weight (dataframe): A pandas dataframe with dependency columns and source weights.

        Returns:
          df (dataframe): A pandas dataframe updated with missing dependency rows, source sample sizes, and source weights.

        """
        levels = df.index.levels
        names = df.index.names
        option_cols = df.columns.values
        df = df.reset_index()
        
        if 'testing' in project:
            df = df[0: 0]
        
        for group in itertools.product(*levels):
            if not group in list(df.groupby(names).groups):
                data = dict(zip(names, group))
                data.update(dict(zip(option_cols, [1.0 / len(option_cols)] * len(option_cols))))
                df = df.append(data, ignore_index=True, verify_integrity=True)
        df = df.merge(count, on=names, how='outer')
        df = df.merge(weight, on=names, how='outer')
        df = df.fillna(0)
        return df

    def rename_cols(self, df, dependency_cols, project):
        """
        Prepend 'Dependency=' to dependency columns and 'Option=' to option columns. Sort by levels in order of dependencies from left to right.

        Parameters:
          df (dataframe): A pandas dataframe with dependency/option columns and fractions.
          dependency_cols (list): A list of the dependency column names.
          project (str): Name of the project.

        Returns:
          df (dataframe): A pandas dataframe with updated dependency/column names.

        """
        new_dependency_cols = []
        for dependency_col in dependency_cols:
            new_dependency_col = 'Dependency={}'.format(dependency_col)
            df = df.rename(columns={dependency_col: new_dependency_col})
            new_dependency_cols.append(new_dependency_col)
            
        if 'singlefamilydetached' in project:
            df = df[df['Dependency=Geometry Building Type']=='Single-Family Detached']
            
        df = df.set_index(new_dependency_cols)
        for col in list(df.columns.values):
            if col in [count_col_label, weight_col_label]:
                continue
            df = df.rename(columns={col: 'Option={}'.format(col)})
        df = df.sort_values(by=new_dependency_cols)
        return df

    def export_and_tag(self, df, filepath, project):
        """
        Add bottom-left script and source tag to dataframe (for non testing projects). Save dataframe to tsv file.

        Parameters:
          df (dataframe): A pandas dataframe with dependency/option columns and fractions.
          filepath (str): The path of the tsv file to export.
          project (str): Name of the project.

        """
        names = df.index.names

        tag = created_by
        if 'testing' not in project:
            tag += source

        tag_row = {names[0]: 'Created by: {}'.format(tag)}
        for name in names[1:] + list(df.columns.values):
            tag_row[name] = np.nan
        df = df.reset_index()
        for col in list(df.columns.values):
            if col == count_col_label:
                df[col] = df[col].astype(int)
            else:
                df[col] = df[col].astype(str)
        df = df.append(tag_row, ignore_index=True, verify_integrity=True)
        df[count_col_label] = df[count_col_label].apply(lambda x: str(int(x)) if pd.notnull(x) else x)
        
        if 'testing' in project:
            del df[count_col_label]
            del df[weight_col_label]
        
        df.to_csv(filepath, sep='\t', index=False)
        print '{}...'.format(filepath)

    def copy_file_to_project(self, filepath, project):
        """
        Copy the exported tsv file out into the housing_characteristics folders of projects.

        Parameters:
          filepath (str): The path of the tsv file to copy to projects' housing_characteristics folders.
          project (str): Name of the project.

        """
        resstock_projects_dir = 'c:/OpenStudio/OpenStudio-BuildStock'
    
        project_dir = os.path.join(resstock_projects_dir, project, 'housing_characteristics')
        shutil.copy(filepath, project_dir)

if __name__ == '__main__':    
    recs_filepath = 'c:/recs2015/recs2015_public_v4.csv'

    tsv_maker = TSVMaker(recs_filepath)

    tsv_maker.bedrooms()
    tsv_maker.occupants()