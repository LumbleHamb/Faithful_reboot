from PIL import Image
import sys
import os
import struct

def convert_raw_to_png(raw_path, png_path):
    try:
        with open(raw_path, 'rb') as f:
            # Read the 9-byte header: width (u32), height (u32), bpp (u8)
            header = f.read(9)
            if len(header) < 9:
                print(f"Error: Invalid header in {raw_path}")
                return

            width, height, bpp = struct.unpack('<IIB', header)
            
            # Read the rest of the file as pixel data
            pixel_data = f.read()

        expected_size = width * height * bpp
        if len(pixel_data) != expected_size:
            print(f"Error: Mismatched file size for {raw_path}. Expected {expected_size} pixel bytes, found {len(pixel_data)}.")
            return
            
        if bpp == 4:
            # Assume BGRA and vertically flipped, as discovered before.
            pixel_data = bytearray(pixel_data)
            for i in range(0, len(pixel_data), 4):
                b, g, r, a = pixel_data[i:i+4]
                pixel_data[i:i+4] = [r, g, b, a]
            
            img = Image.frombytes("RGBA", (width, height), bytes(pixel_data))
            img = img.transpose(Image.FLIP_TOP_BOTTOM)
            img.save(png_path)
            # print(f"Successfully converted {os.path.basename(raw_path)}")

        else:
            print(f"Skipping {os.path.basename(raw_path)}: Unsupported bytes per pixel: {bpp}")

    except Exception as e:
        print(f"An error occurred with {os.path.basename(raw_path)}: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_raw.py <raw_path> <png_path>")
    else:
        raw_path = sys.argv[1]
        png_path = sys.argv[2]
        convert_raw_to_png(raw_path, png_path)
