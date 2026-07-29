import os
import struct

def inspect_caf(caf_path):
    try:
        with open(caf_path, 'rb') as f:
            # CAF Header
            magic = f.read(4)
            if magic != b'caff':
                return None
            
            version, flags = struct.unpack('>HH', f.read(4))
            
            # Read first chunk (should be 'desc')
            chunk_type = f.read(4)
            chunk_size = struct.unpack('>q', f.read(8))[0] # 64-bit int
            
            if chunk_type == b'desc':
                sample_rate = struct.unpack('>d', f.read(8))[0] # double
                format_id = f.read(4).decode('ascii', errors='ignore')
                format_flags = struct.unpack('>I', f.read(4))[0]
                bytes_per_packet = struct.unpack('>I', f.read(4))[0]
                frames_per_packet = struct.unpack('>I', f.read(4))[0]
                channels_per_frame = struct.unpack('>I', f.read(4))[0]
                bits_per_channel = struct.unpack('>I', f.read(4))[0]
                
                return {
                    "path": caf_path,
                    "format_id": format_id,
                    "sample_rate": sample_rate,
                    "channels": channels_per_frame,
                    "bits": bits_per_channel,
                    "bytes_per_packet": bytes_per_packet,
                    "frames_per_packet": frames_per_packet
                }
    except Exception as e:
        return {"path": caf_path, "error": str(e)}
    return None

if __name__ == "__main__":
    caf_dir = os.path.join("original", "TradeNations.app", "bundle")
    if not os.path.exists(caf_dir):
        print("Bundle directory not found")
        exit(1)
        
    results = []
    for file in os.listdir(caf_dir):
        if file.lower().endswith(".caf"):
            res = inspect_caf(os.path.join(caf_dir, file))
            if res:
                results.append(res)
                
    print(f"Inspected {len(results)} CAF files:")
    formats = {}
    for r in results:
        fmt = r.get("format_id")
        formats[fmt] = formats.get(fmt, 0) + 1
        
    print(f"Formats found: {formats}")
    print("\nDetailed list of first 10 files:")
    for r in results[:10]:
        print(f" - {os.path.basename(r['path'])}: format={r['format_id']}, rate={r['sample_rate']}, channels={r['channels']}, bits={r['bits']}")
