#/** @file
#
#  Copyright 2025 Cix Technology Group Co., Ltd. All Rights Reserved.
#
#**/

import struct
import argparse

def parse_binary_file(file_path, start_offset):
    with open(file_path, 'rb') as f:
        f.seek(start_offset)
        header = f.read(4)
        if header != b'\xAA\x55\xAA\x55':
            return None

        cfs_version = struct.unpack('I', f.read(4))[0]
        imagine_count = struct.unpack('I', f.read(4))[0]
        reserve = struct.unpack('I', f.read(4))[0]

        records = []
        for _ in range(imagine_count):
            record = struct.unpack('IIII', f.read(16))
            records.append({
                'ImageType': record[0],
                'Offset': record[1],
                'Size': record[2],
                'Reserve': record[3]
            })
        # Default Ec Records
        records.append({
            'ImageType': 0x0,
            'Offset': 0x10000,
            'Size':   0x20000,
            'Reserve': 0
        })

        return cfs_version, imagine_count, reserve, records

def replace_image(in_file, re_file, re_image_type, out_file):

    header_offsets = [0x100000, 0x200000]
    for header_offset in header_offsets:
        result = parse_binary_file(in_file, header_offset)
        if result:
            cfs_version, imagine_count, reserve, records = result
            break
    else:
        raise ValueError("Invalid header at all specified offsets\n Please check the file Image.")

    target_record = next((r for r in records if r['ImageType'] == re_image_type), None)
    if not target_record:
        raise ValueError("ImageType not found in ")

    with open(re_file, 'rb') as rf:
        replacement_data = rf.read()

    with open(in_file, 'rb') as f:
        original_data = f.read()

    with open(out_file, 'wb') as f:
        # Write Data
        f.write(original_data)
        f.seek(target_record['Offset'])
        f.write(bytes([0xFF]*target_record['Size']))
        f.seek(target_record['Offset'])
        f.write(replacement_data)
        #Sync Header records if not EC  sub-image
        target_record['Size'] = len(replacement_data)
        if( target_record['ImageType'] != 0):
          record_start_offset = header_offset + 16 + 16 * records.index(target_record)
          f.seek(record_start_offset + 8)
          f.write(struct.pack('I', target_record['Size']))


def main():
    parser = argparse.ArgumentParser(description="Replace sub-image in a binary file.")
    parser.add_argument('Input_file', help="输入文件路径")
    parser.add_argument('SubImage_file', help="子文件路径")
    parser.add_argument('OutPut_file', help="输出文件路径")
    parser.add_argument('ReplaceSubImageType', type=lambda x: int(x, 0), help='''替换的ImageType (
                        0:ECImage;
                        1:Bootloader1;
                        2:Bootloader2;
                        3:MemConfig;
                        4:PMConfig;
                        6:SEconfig;
                        7:Bootloader3;
                        ''')

    args = parser.parse_args()

    try:
        replace_image(args.Input_file, args.SubImage_file, args.ReplaceSubImageType, args.OutPut_file)
        print("SUCCESS: Replacement completed successfully.")
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    main()

