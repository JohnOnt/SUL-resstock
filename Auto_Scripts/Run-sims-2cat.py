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
# for i in range(combos.shape[0]):
for i in range(52):
    vintage = combos['Vintage Bin'][i]
    floor_area = combos['Floor Area Bin'][i]
    output_dir = '../Mass_Buildstocks/'

    vintage = vintage.replace('<', 'less')
    vintage = vintage.replace('s', '')
    floor_area = floor_area.replace('+', 'plus')

    # Open YAML config file
    with open('project_national/new_england_baseline_batch_precomp.yml', 'r') as f:
        baseline = yaml.load(f)
    # Edit output directory
    baseline['output_directory'] = 'sim_2cat_output/run' + str(i) + '/'
    # Edit sampler
    baseline['sampler']['args']['sample_file'] = output_dir + 'buildstock_' + vintage + '-' + floor_area + '.csv'
    # Write config
    with open('project_national/new_england_baseline_batch_precomp.yml', 'w') as f:
        yaml.dump(baseline, f)

    # Run buildstock off of it
    os.system('buildstock_local project_national/new_england_baseline_batch_precomp.yml')

    print('Finished ' + vintage + ' ' + floor_area)
    print('On iteration ' + str(i) + ' of ' + str(combos.shape[0]))

