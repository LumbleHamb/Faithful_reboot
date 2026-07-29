
from PIL import Image
import sys
import os
import struct

def convert_z2raw_to_png(z2raw_path, png_path):
    """
    Converts a z2raw file to a PNG image.
    The z2raw format is now assumed to be:
    - 16-byte header: [format (u32), width (u32), height (u32), bpp_in_header (u32)]
    - The rest of the file is raw, uncompressed pixel data.
    - The bpp in the header is ignored; we calculate it from the data size.
    """
    try:
        with open(z2raw_path, 'rb') as f:
            # Read the 16-byte header
            header = f.read(16)
            if len(header) < 16:
                print(f"Error: Invalid header in {z2raw_path}")
                return

            # Unpack the header
            _format, width, height, bpp_in_header = struct.unpack('<IIII', header)

            # Read the rest of the file as pixel data
            pixel_data = f.read()

        # Calculate actual bytes per pixel
        if width * height == 0:
            print(f"Error: Invalid dimensions ({width}x{height}) in {z2raw_path}")
            return
        
        actual_bpp = len(pixel_data) / (width * height)

        print(f"Info for {os.path.basename(z2raw_path)}: Header_BPP={bpp_in_header}, Actual_BPP={actual_bpp}, Dims={width}x{height}")

        image_mode = None
        if actual_bpp == 2:
            # Most likely 16-bit RGB (5, 6, 5). Pillow mode is "RGB;16"
            image_mode = "RGB;16"
        elif actual_bpp == 4:
            # It could be a simple 32-bit RGBA after all
            image_mode = "RGBA"
        else:
            print(f"Skipping {os.path.basename(z2raw_path)}: Unsupported calculated bytes per pixel: {actual_bpp}")
            return

        # Create image from bytes
        img = Image.frombytes(image_mode, (width, height), pixel_data)

        # The RAW files were BGRA and flipped. Let's see if z2raw is different.
        # For 16-bit, byte order might need swapping depending on endianness of the format.
        # Let's try converting without any channel swapping or flipping first.
        # If colors are off (blue/red swapped), we may need to manually swap bytes.
        # Example for RGB565: `pixel = (b[1] << 8) | b[0]`
        
        # The original .RAW converter did a BGRA -> RGBA swap and a vertical flip.
        # Let's assume the same transformation is needed here for consistency.
        if image_mode == "RGBA":
             pixel_byte_array = bytearray(pixel_data)
             for i in range(0, len(pixel_byte_array), 4):
                 b, g, r, a = pixel_byte_array[i:i+4]
                 pixel_byte_array[i:i+4] = [r, g, b, a]
             img = Image.frombytes("RGBA", (width, height), bytes(pixel_byte_array))

        # Vertical flip seems to be a common feature of this engine's assets
        img = img.transpose(Image.FLIP_TOP_BOTTOM)
        
        img.save(png_path)
        print(f"Successfully converted {os.path.basename(z2raw_path)} to {os.path.basename(png_path)}")

    except Exception as e:
        print(f"An error occurred with {os.path.basename(z2raw_path)}: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_z2raw.py <z2raw_path> <png_path>")
    else:
        z2raw_path = sys.argv[1]
        png_path = sys.argv[2]
        convert_z2raw_to_png(z2raw_path, png_path)
