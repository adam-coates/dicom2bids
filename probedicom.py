import os
import pydicom
from collections import defaultdict
import argparse

def get_dicom_metadata(file_path):
    try:
        ds = pydicom.dcmread(file_path, force=True)
        series_uid = ds.get('SeriesInstanceUID', None)
        instance_number = ds.get('InstanceNumber', None)
        series_description = ds.get('SeriesDescription', 'Not available')
        series_number = ds.get('SeriesNumber', 'Not available')
        return series_uid, instance_number, series_description, series_number
    except Exception as e:
        print(f"Error reading metadata from {file_path}: {e}")
        return None, None, 'Error', 'Error'

def find_first_dicom_in_series(directory_path):
    if not os.path.isdir(directory_path):
        print(f"The specified directory does not exist: {directory_path}")
        return {}

    dicom_files = []
    for root, _, files in os.walk(directory_path):
        for file_name in files:
            if not os.path.splitext(file_name)[1]:  # Handles files without extensions
                file_path = os.path.join(root, file_name)
                dicom_files.append(file_path)

    series_dict = defaultdict(list)

    for file_path in dicom_files:
        series_uid, instance_number, series_description, series_number = get_dicom_metadata(file_path)
        if series_uid and instance_number is not None:
            series_dict[series_uid].append((instance_number, file_path, series_description, series_number))

    first_files = {}
    for series_uid, files in series_dict.items():
        # Sort files by instance number and select the first one
        files.sort(key=lambda x: x[0])
        first_files[series_uid] = files[0]  # files[0] contains (instance_number, file_path, series_description, series_number)

    return first_files

def save_to_file(first_files, output_file_path):
    with open(output_file_path, 'w') as file:
        for series_uid, (instance_number, file_path, series_description, series_number) in first_files.items():
            file.write(f"{series_number} {series_description} {file_path}\n")

def main():
    parser = argparse.ArgumentParser(description='Process DICOM files and save series descriptions.')
    parser.add_argument('input_directory', type=str, help='Path to the directory containing DICOM files')
    parser.add_argument('output_file', type=str, help='Path to save the output file')

    args = parser.parse_args()

    # Find the first DICOM file in each series
    first_files = find_first_dicom_in_series(args.input_directory)

    # Save results to file
    if first_files:
        save_to_file(first_files, args.output_file)
        print(f"Results have been saved to {args.output_file}.")
    else:
        print("No DICOM files found.")

if __name__ == '__main__':
    main()

