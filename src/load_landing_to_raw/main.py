# src/csv-to-parquet-transformer/main.py

import os
import functions_framework
import pandas as pd
from google.cloud import storage
from datetime import datetime
import pytz # Used for timezone conversion

@functions_framework.cloud_event
def transform_csv_to_parquet(cloud_event):
    """
    This function is triggered when a CSV file is uploaded to a GCS bucket.
    It reads the CSV, converts it to Parquet, and saves it to another GCS
    bucket using Hive partitioning based on the file's creation time.
    """
    data = cloud_event.data

    source_bucket_name = data["bucket"]
    source_file_name = data["name"]
    
    # Get the destination bucket name from environment variables
    destination_bucket_name = os.environ.get("RAW_BUCKET_NAME")

    if not destination_bucket_name:
        raise ValueError("Environment variable RAW_BUCKET_NAME is not set.")

    if not source_file_name.lower().endswith('.csv'):
        print(f"File {source_file_name} is not a CSV. Skipping.")
        return

    # --- NEW: Hive Partitioning Logic ---
    
    # Get the timestamp of when the file was created in GCS.
    # The timestamp is in RFC 3339 format (e.g., '2023-10-27T14:30:00.123Z').
    event_timestamp_str = data["timeCreated"]
    
    event_timestamp = datetime.fromisoformat(event_timestamp_str.replace('Z', '+00:00'))


    year = event_timestamp.strftime('%Y')
    month = event_timestamp.strftime('%m')
    day = event_timestamp.strftime('%d')
    hour = event_timestamp.strftime('%H')

    # Construct the full GCS paths
    source_uri = f"gs://{source_bucket_name}/{source_file_name}"
    
    # Create the Hive-partitioned path.
    # e.g., year=2024/month=10/day=27/hour=14/
    partition_path = f"year={year}/month={month}/day={day}/hour={hour}"
    
    # The output filename can be the same as the source, but with a .parquet extension.
    destination_file_name = os.path.basename(source_file_name).replace('.csv', '.parquet')
    
    destination_uri = f"gs://{destination_bucket_name}/{partition_path}/{destination_file_name}"

    print(f"Processing file source: {source_uri}")
    print(f"Destination: {destination_uri}")

    try:
        # Use pandas to read the CSV file directly from GCS
        df = pd.read_csv(source_uri)

        # Write the DataFrame to a Parquet file in the destination bucket
        df.to_parquet(destination_uri, engine='pyarrow', index=False)

        print(f"Successfully converted and saved to {destination_uri}.")

    except Exception as e:
        print(f"Error processing file {source_file_name}: {e}")
        # Re-raise the exception to signal a failure to Cloud Functions
        raise