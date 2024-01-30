from ruamel.yaml import YAML
import pandas as pd
import shutil
import os

# Define yaml function
yaml = YAML()

# Read in combination file
combos = pd.read_csv('ashp-groupings-l2.csv')
combos.columns = ['Vintage Bin', 'Floor Area Bin', 'Frequency']

os.system('cd')
os.chdir('../')

# For loop through each row of vintage and floor area bins
for i in range(52, combos.shape[0]):
    vintage = combos['Vintage Bin'][i]
    floor_area = combos['Floor Area Bin'][i]

    # Open YAML config file
    with open('project_national/new_england_baseline_batch.yml', 'r') as f:
        baseline = yaml.load(f)
    # Edit config
    baseline['sampler']['args']['logic']['and'] = ['Geometry Building Type RECS|Single-Family Detached', 'State|MA',
                                                   'Vintage|'+vintage, 'Geometry Floor Area|'+floor_area]
    # Write config
    with open('project_national/new_england_baseline_batch.yml', 'w') as f:
        yaml.dump(baseline, f)

    # Run buildstock off of it
    os.system('buildstock_local project_national/new_england_baseline_batch.yml --samplingonly')

    # Copy over buildstock result
    source_file = 'project_national/housing_characteristics/buildstock.csv'
    output_dir = 'Mass_Buildstocks/'

    # Strip vintage and floor area of characters that can't be in file names
    vintage = vintage.replace('<', 'less')
    vintage = vintage.replace('s', '')
    floor_area = floor_area.replace('+', 'plus')

    # Copy out file
    shutil.copy2(source_file, output_dir + 'buildstock_' + vintage + '-' + floor_area + '.csv')
