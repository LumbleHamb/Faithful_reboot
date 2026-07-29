import sys

def dump_hex(filepath, num_bytes=16):
    try:
        with open(filepath, 'rb') as f:
            bytes_to_dump = f.read(num_bytes)
        
        hex_representation = ' '.join([f'{b:02x}' for b in bytes_to_dump])
        print(hex_representation)
        
    except FileNotFoundError:
        print(f"Error: File not found at {filepath}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python dump_hex.py <filepath> [num_bytes]")
    else:
        file_to_dump = sys.argv[1]
        bytes_to_read = int(sys.argv[2]) if len(sys.argv) > 2 else 16
        dump_hex(file_to_dump, bytes_to_read)
