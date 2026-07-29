import os
import struct
import wave

IMA_INDEX_TABLE = [
    -1, -1, -1, -1, 2, 4, 6, 8,
    -1, -1, -1, -1, 2, 4, 6, 8
]

IMA_STEP_TABLE = [
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
    19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
    876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
    5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
]

def decode_ima4_packet(packet):
    if len(packet) != 34:
        raise ValueError(f"Invalid packet size: expected 34, got {len(packet)}")
        
    # Read big-endian uint16 preamble
    header = struct.unpack('>H', packet[0:2])[0]
    
    # Extract initial predictor (high 9 bits, sign-extended to 16 bits)
    predictor = header & 0xFF80
    if predictor & 0x8000:
        predictor -= 0x10000
        
    # Extract initial step index (low 7 bits, clamped to 88)
    step_index = header & 0x007F
    if step_index > 88:
        step_index = 88
        
    samples = []
    
    for b in packet[2:34]:
        # Low nibble first, then high nibble
        n1 = b & 0x0F
        n2 = (b >> 4) & 0x0F
        
        for nibble in (n1, n2):
            sign = nibble & 8
            delta = nibble & 7
            step = IMA_STEP_TABLE[step_index]
            
            # Reconstruct difference
            diff = step >> 3
            if delta & 4: diff += step
            if delta & 2: diff += step >> 1
            if delta & 1: diff += step >> 2
            
            if sign:
                predictor -= diff
            else:
                predictor += diff
                
            # Clamp predictor to 16-bit signed range
            if predictor > 32767:
                predictor = 32767
            elif predictor < -32768:
                predictor = -32768
                
            samples.append(predictor)
            
            # Update step index
            step_index += IMA_INDEX_TABLE[nibble]
            if step_index < 0:
                step_index = 0
            elif step_index > 88:
                step_index = 88
                
    return samples

def convert_caf_to_wav(caf_path, wav_path):
    print(f"Decoding {os.path.basename(caf_path)} -> {os.path.basename(wav_path)}")
    try:
        with open(caf_path, 'rb') as f:
            magic = f.read(4)
            if magic != b'caff':
                raise ValueError("Not a valid CAF file")
            
            # skip version & flags
            f.read(4)
            
            sample_rate = 22050
            channels = 1
            data_bytes = b''
            
            while True:
                chunk_type = f.read(4)
                if len(chunk_type) < 4:
                    break
                chunk_size = struct.unpack('>q', f.read(8))[0]
                
                if chunk_type == b'desc':
                    desc_data = f.read(32)
                    sample_rate_double = struct.unpack('>d', desc_data[0:8])[0]
                    sample_rate = int(sample_rate_double)
                    format_id = desc_data[8:12]
                    channels = struct.unpack('>I', desc_data[24:28])[0]
                    if format_id != b'ima4':
                        raise ValueError(f"Unsupported CAF audio format: {format_id.decode('ascii', errors='ignore')}")
                    if channels != 1:
                        raise ValueError(f"Only mono CAF files are supported, got {channels} channels")
                elif chunk_type == b'data':
                    # First 4 bytes of data chunk is edit count
                    f.read(4)
                    if chunk_size == -1:
                        data_bytes = f.read()
                    else:
                        data_bytes = f.read(chunk_size - 4)
                else:
                    # Skip other chunks
                    f.read(chunk_size)
                    
            if not data_bytes:
                raise ValueError("No data chunk found in CAF file")
                
            # Decode packets sequentially
            # Each packet in mono IMA4 is exactly 34 bytes
            all_samples = []
            num_packets = len(data_bytes) // 34
            
            for i in range(num_packets):
                packet = data_bytes[i*34 : (i+1)*34]
                packet_samples = decode_ima4_packet(packet)
                all_samples.extend(packet_samples)
                
            # Write standard mono 16-bit PCM WAV file
            with wave.open(wav_path, 'wb') as wav_file:
                wav_file.setnchannels(1)
                wav_file.setsampwidth(2) # 16-bit = 2 bytes
                wav_file.setframerate(sample_rate)
                
                # Convert samples list to binary signed 16-bit PCM
                pcm_data = struct.pack(f'<{len(all_samples)}h', *all_samples)
                wav_file.writeframes(pcm_data)
                
        print(f"Successfully converted: {os.path.basename(wav_path)} ({len(all_samples)} samples)")
        return True
    except Exception as e:
        print(f"Failed to convert {os.path.basename(caf_path)}: {e}")
        return False

if __name__ == "__main__":
    caf_dir = os.path.join("original", "TradeNations.app", "bundle")
    wav_dir = os.path.join("assets", "audio")
    
    if not os.path.exists(wav_dir):
        os.makedirs(wav_dir)
        
    print("Starting audio conversion...")
    success_count = 0
    fail_count = 0
    
    for file in os.listdir(caf_dir):
        if file.lower().endswith(".caf"):
            caf_path = os.path.join(caf_dir, file)
            wav_filename = os.path.splitext(file)[0] + ".wav"
            wav_path = os.path.join(wav_dir, wav_filename)
            
            if convert_caf_to_wav(caf_path, wav_path):
                success_count += 1
            else:
                fail_count += 1
                
    print(f"\nAudio conversion complete: {success_count} success, {fail_count} failed.")
