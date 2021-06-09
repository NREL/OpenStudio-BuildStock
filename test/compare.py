import os
import csv
import pandas as pd

folder = 'comparisons' # comparison csv files will be exported to this folder

dir = os.path.join('test/test_samples_osw', folder)
if not os.path.exists(dir):
  os.makedirs(dir)

def value_counts(df, file):
  value_counts = []
  with open(file, 'w', newline='') as f:

    for col in sorted(df.columns):
      if col == 'Building':
        continue

      value_count = df[col].value_counts(normalize=True)
      value_counts.append([value_count.name])
      value_counts.append(value_count.index.values)
      value_counts.append(value_count.values)
      value_counts.append('\n')

    w = csv.writer(f)
    w.writerows(value_counts)

df = pd.read_csv('reources/base_buildstock.csv')
file = os.path.join(dir, 'base_samples.csv')
value_counts(df, file)

df = pd.read_csv('resources/buildstock.csv')
file = os.path.join(dir, 'feature_samples.csv')
value_counts(df, file)
