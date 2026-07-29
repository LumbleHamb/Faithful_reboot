import os
import glob
import subprocess
import sys

def batch_convert(bundle_path, output_path, tools_path):
    print(f"Starting batch conversion...")
    print(f"Input bundle path: {bundle_path}")
    print(f"Output path: {output_path}")

    if not os.path.isdir(bundle_path):
        print(f"Error: Input path '{bundle_path}' not found.")
        return

    if not os.path.isdir(output_path):
        print(f"Error: Output path '{output_path}' not found.")
        return

    raw_files = glob.glob(os.path.join(bundle_path, '*.RAW'))
    print(f"Found {len(raw_files)} .RAW files to process.")

    processed_count = 0
    skipped_count = 0
    error_count = 0

    for raw_path in raw_files:
        base_name = os.path.basename(raw_path)
        name_no_ext = os.path.splitext(base_name)[0]
        
        # Convert the .RAW file using the new convert_raw.py
        try:
            output_png_path = os.path.join(output_path, name_no_ext + '.png')
            convert_script_path = os.path.join(tools_path, 'convert_raw.py')
            
            result = subprocess.run(
                [sys.executable, convert_script_path, raw_path, output_png_path],
                capture_output=True, text=True
            )
            
            if result.returncode == 0 and not result.stdout:
                processed_count += 1
            elif result.stdout: # Script prints errors to stdout
                print(f"--- Skipping {base_name}: {result.stdout.strip()}")
                skipped_count += 1
            elif result.stderr:
                 print(f"--- Error processing {base_name}: {result.stderr.strip()}")
                 error_count += 1

        except Exception as e:
            print(f"--- Fatal error processing {base_name}: {e}")
            error_count += 1

    print("\nBatch conversion finished.")
    print(f"Successfully processed: {processed_count}")
    print(f"Skipped (e.g. wrong BPP or header): {skipped_count}")
    print(f"Errors: {error_count}")

if __name__ == "__main__":
    # Assuming the script is run from the 'Faithful_reboot' directory
    bundle_dir = os.path.join('original', 'TradeNations.app', 'bundle')
    converted_dir = os.path.join('assets', 'art', 'converted')
    tools_dir = 'tools'
    batch_convert(bundle_dir, converted_dir, tools_dir)
