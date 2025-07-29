# -----------------------------------------------------------------------------
# main.py
#
# This file should be placed in the 'csv-to-parquet-transformer' directory
# of your function's source code repository.
# -----------------------------------------------------------------------------
import os
import functions_framework
import pandas as pd
from google.cloud import storage

# Triggered by a change in a storage bucket
@functions_framework.cloud_event
def transform_csv_to_parquet(cloud_event):
    """
    This function is triggered when a CSV file is uploaded to a GCS bucket.
    It reads the CSV, converts it to Parquet, and saves it to another GCS bucket.
    """
    data = cloud_event.data

    source_bucket_name = data["bucket"]
    source_file_name = data["name"]
    
    # Get the destination bucket name from environment variables
    destination_bucket_name = os.environ.get("RAW_BUCKET_NAME")

    if not destination_bucket_name:
        raise ValueError("Environment variable RAW_BUCKET_NAME is not set.")

    # Ensure we only process CSV files
    if not source_file_name.lower().endswith('.csv'):
        print(f"File {source_file_name} is not a CSV. Skipping.")
        return

    # Construct the full GCS paths
    source_uri = f"gs://{source_bucket_name}/{source_file_name}"
    
    # Create a new filename for the Parquet output
    destination_file_name = source_file_name.replace('.csv', '.parquet')
    destination_uri = f"gs://{destination_bucket_name}/{destination_file_name}"

    print(f"Processing file: {source_uri}")
    print(f"Destination: {destination_uri}")

    try:
        # Use pandas to read the CSV file directly from GCS
        # The gcsfs library (installed via requirements.txt) makes this possible
        df = pd.read_csv(source_uri)

        # Write the DataFrame to a Parquet file in the destination bucket
        df.to_parquet(destination_uri, engine='pyarrow', index=False)

        print(f"Successfully converted {source_file_name} to Parquet and saved to {destination_bucket_name}.")

    except Exception as e:
        print(f"Error processing file {source_file_name}: {e}")
        # Re-raise the exception to signal a failure to Cloud Functions
        raise