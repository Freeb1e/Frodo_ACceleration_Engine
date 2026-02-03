import os
import struct

def text_to_binary_little_endian(input_file, output_file, debug_file):
    try:
        # 1. 读取并清洗数据 (支持 // 注释)
        binary_string = ""
        
        with open(input_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                # 以 '//' 为界切割，去掉注释
                content_without_comment = line.split('//')[0]
                # 提取有效的 0 和 1
                valid_bits = ''.join(filter(lambda x: x in ['0', '1'], content_without_comment))
                binary_string += valid_bits

        if not binary_string:
            print("错误：文件中没有有效数据。")
            return

        print(f"原始二进制位总数: {len(binary_string)}")

        # 2. 32位对齐 (Padding)
        remainder = len(binary_string) % 32
        if remainder != 0:
            padding_count = 32 - remainder
            binary_string += '0' * padding_count
            print(f"注意：数据长度不是32的倍数，已在末尾补了 {padding_count} 个 '0'")

        output_bytes = bytearray()
        
        # 3. 准备写入文件
        # 同时打开二进制文件(wb)和调试文本文件(w)
        with open(output_file, 'wb') as f_bin, open(debug_file, 'w', encoding='utf-8') as f_txt:
            
            # --- 写入调试文件表头 ---
            # Idx: 序号, Address: 字节地址, Instruction: 机器码
            header = f"{'Idx':<6} | {'Address':<12} | {'Instruction (Hex)':<20}\n"
            f_txt.write(header)
            f_txt.write("-" * 45 + "\n")

            # 控制台也打印个表头方便看
            print("-" * 70)
            print(f"{'Idx':<6} | {'Address':<12} | {'Hex (Native)':<15} | {'Bytes (Little-Endian)':<25}")
            print("-" * 70)

            instruction_index = 0

            # 4. 循环处理每 32 位
            for i in range(0, len(binary_string), 32):
                chunk_str = binary_string[i:i+32]
                
                # 转整数
                val = int(chunk_str, 2)
                
                # 转小端字节序
                chunk_bytes = val.to_bytes(4, byteorder='little')
                output_bytes.extend(chunk_bytes)
                
                # 写入 .bin
                f_bin.write(chunk_bytes)
                
                # --- 计算地址与格式化 ---
                # 假设是32位处理器，字节寻址，每次地址 +4
                current_address = instruction_index * 4 
                
                hex_val_str = f"0x{val:08X}"       # 指令内容
                addr_str = f"0x{current_address:08X}" # 地址内容
                
                # 写入 .txt 调试文件
                # 格式： 0  | 0x00000000 | 0x12345678
                line_content = f"{instruction_index:<6} | {addr_str:<12} | {hex_val_str:<20}\n"
                f_txt.write(line_content)
                
                # 控制台打印
                hex_bytes_str = ' '.join(f"{b:02X}" for b in chunk_bytes)
                print(f"{instruction_index:<6} | {addr_str:<12} | {hex_val_str:<15} | {hex_bytes_str:<25}")

                instruction_index += 1

        print("-" * 70)
        print(f"1. 二进制固件已生成: {output_file}")
        print(f"2. 调试列表已生成:   {debug_file}")

    except FileNotFoundError:
        print(f"找不到文件: {input_file}")
    except Exception as e:
        print(f"发生错误: {e}")

# --- 配置区 ---
input_txt = './simdata/instrom.txt'
output_bin = './simdata/firmware.bin'
output_debug = './simdata/firmware_hex.txt'

if __name__ == '__main__':
    os.makedirs(os.path.dirname(input_txt), exist_ok=True)
    text_to_binary_little_endian(input_txt, output_bin, output_debug)