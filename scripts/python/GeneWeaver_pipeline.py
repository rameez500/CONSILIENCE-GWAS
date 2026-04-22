import argparse
import sys
from geneweaver.client import auth
import requests
import pandas as pd
import os
#sys.path.insert(0,"/apps/www/project/ldsc/tool/gwaslab")

# Set up argument parser
parser = argparse.ArgumentParser(description="Run the data pipeline.")
parser.add_argument('--GeneID', type=str, required=True, help='Enter the GeneID.')
parser.add_argument('--dir_out', type=str, required=True, help='save output.')
args = parser.parse_args()

         
# Extract the GeneID argument
geneset_id = args.GeneID
dir_out = args.dir_out

#auth = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6Ik56RXlOMFl6UkVKQ1JrSXhPVU0xTXpNd1JEVTBPVGhHTVRRMVJqWkNRa1pEUkRKRU1rRTBOdyJ9.eyJodHRwczovL2N1YmUuamF4Lm9yZy9lbWFpbCI6InJhc3llZDJAZW1vcnkuZWR1IiwiaXNzIjoiaHR0cHM6Ly90aGVqYWNrc29ubGFib3JhdG9yeS5hdXRoMC5jb20vIiwic3ViIjoiYXV0aDB8NjFkNzNmNWEzYThiNzYwMDY4NzNkNTc1IiwiYXVkIjpbImh0dHBzOi8vY3ViZS5qYXgub3JnIiwiaHR0cHM6Ly90aGVqYWNrc29ubGFib3JhdG9yeS5hdXRoMC5jb20vdXNlcmluZm8iXSwiaWF0IjoxNzI4MDczNjIwLCJleHAiOjE3MzA2NjU2MjAsInNjb3BlIjoib3BlbmlkIHByb2ZpbGUgZW1haWwgb2ZmbGluZV9hY2Nlc3MiLCJhenAiOiJmOFFaUGNJclBJRzZESWVXUjJScjNDOFg1Ynp4OHpCeiIsInBlcm1pc3Npb25zIjpbXX0.ddiwA_gZFGLAcfLhG7l0_tZi2CwigUsfmOfs2vbJ0D4-x8jqmtordL5jnmnXXpazj0XWOq1oeIJlkwNM0j_-knCsFE4iKj3WMx-RuN5SJMuoWK7N7MzjS9ZR0PrbyEwqkbAP7FVK1uuexHxYYSPcmgUa5H0NublxE0Qd3Ae4xFJKoGa2e7qjPAFiy1aQDxIGzFGyEMo2XGFgq0AH-ymceAIBfqgRKHXcewxJy5fDtfjjdhTykI81KA5lbwAy0ekra15SIuETME9KIRKRXUcjz-ay31J0s0hirg0LidjXvpg3ZsTp8qmZy5tTgciYwOoDMH_qDpUHnpwlctI81iGcWA'

#Make the request
# response = requests.get(
    # f'https://geneweaver.org/api/genesets/{geneset_id}/values',
    # params={'gene_id_type': "Ensemble Gene"},
    # headers={"Authorization": f"Bearer {auth}"}
# )

response = requests.get(
    f'https://geneweaver.org/api/genesets/{geneset_id}/values',
    params={'gene_id_type': "Ensemble Gene"}
)

# Check if the response is OK
if response.ok:
    # Extract data and convert to DataFrame
    data = response.json()['data']
    data_df = pd.DataFrame(data)
    
    # Save to CSV in the specified output directory
    #output_file = os.path.join(dir_out, 'datadd.csv')
    #output_file = os.path.join(dir_out,geneset_id,'.txt')
    output_file = os.path.join(dir_out, f'{geneset_id}.txt')
    #data_df.to_csv(output_file, index=False)
    first_column = data_df['symbol']
    first_column.to_csv(output_file, index=False, header=False)
    print(f"Data saved to '{output_file}'")
else:
    print(f"Failed to retrieve data for GeneID {geneset_id}. Status code: {response.status_code}")
    


# /apps/conda/project/envs/py39/bin/python \
# /apps/www/project/ldsc/GeneWeaver_pipeline.py \
# --GeneID $geneID \
# --dir_out $result_dir



#