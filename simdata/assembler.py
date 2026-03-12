import sys

# ==========================================
# 1. 配置区：请根据你的实际设计修改 OPCODE
# ==========================================
OPCODE_SYSTOLIC = 0b1010101  # Systolic 阵列指令的 opcode
OPCODE_SHAKE    = 0b1010100  # SHAKE 模块指令的 opcode

# ==========================================
# 2. 核心解析与拼接逻辑
# ==========================================
def parse_val(v):
    """支持十进制和十六进制(0x...)字符串转整数"""
    return int(v, 0) 

def assemble_line(line):
    # 移除注释和首尾空白字符
    line = line.split('#')[0].strip()
    if not line:
        return None
    
    # 将逗号替换为空格，统一以空格分割指令和操作数
    parts = line.replace(',', ' ').split()
    inst = parts[0]
    args = [parse_val(a) for a in parts[1:]]

    machine_code = 0

    try:
        if inst == "systolic_addrset":
            # 格式: systolic_addrset BASE_ADDR, SETTAR
            base_addr = args[0] & 0xFFFFF # [31:12] 20 bits
            settar    = args[1] & 0x3     # [11:10] 2 bits
            func      = 0 & 0x7           # [9:7] FUNC = 0
            opcode    = OPCODE_SYSTOLIC & 0x7F
            machine_code = (base_addr << 12) | (settar << 10) | (func << 7) | opcode

        elif inst == "systolic_calc":
            # 格式: systolic_calc MATRIX_SIZE, ctrl_mode
            matrix_size = args[0] & 0x7FF # [22:12] 11 bits
            ctrl_mode   = args[1] & 0x3   # [11:10] 2 bits
            func        = 1 & 0x7         # [9:7] FUNC = 1
            opcode      = OPCODE_SYSTOLIC & 0x7F
            machine_code = (matrix_size << 12) | (ctrl_mode << 10) | (func << 7) | opcode

        elif inst == "SHAKE_seedaddrset":
            # 格式: SHAKE_seedaddrset shakemode, start_addr
            shakemode  = args[0] & 0x1    # [25] 1 bit
            start_addr = args[1] & 0x7FFF # [24:10] 15 bits
            func       = 0 & 0x7          # [9:7] FUNC = 0
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (shakemode << 25) | (start_addr << 10) | (func << 7) | opcode

        elif inst == "SHAKE_seedset":
            # 格式: SHAKE_seedset last_block_bytes, absorb_num
            last_bytes = args[0] & 0xFF   # [25:18] 8 bits
            absorb_num = args[1] & 0xFF   # [17:10] 8 bits
            func       = 1 & 0x7          # [9:7] FUNC = 1
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (last_bytes << 18) | (absorb_num << 10) | (func << 7) | opcode

        elif inst == "SHAKE_squeezeonce":
            # 格式: SHAKE_squeezeonce (无操作数)
            func       = 2 & 0x7          # [9:7] FUNC = 2
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (func << 7) | opcode

        elif inst == "systolic_bufswap":
            # 格式: systolic_bufswap (无操作数)
            func       = 2 & 0x7          # [9:7] FUNC = 2
            opcode     = OPCODE_SYSTOLIC & 0x7F
            machine_code = (func << 7) | opcode

        elif inst == "SHAKE_dumpaword":
            # 格式: SHAKE_dumpaword offset, start_addr
            # offset [29:25], start_addr [24:10]
            offset     = args[0] & 0x1F   # [29:25] 5 bits
            start_addr = args[1] & 0x7FFF # [24:10] 15 bits
            func       = 6 & 0x7          # [9:7] FUNC = 6
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (offset << 25) | (start_addr << 10) | (func << 7) | opcode


        elif inst == "SHAKE_dumponce":
            # 格式: SHAKE_dumponce bram_id, start_addr
            bram_id    = args[0] & 0x1    # [25] 1 bit
            start_addr = args[1] & 0x7FFF # [24:10] 15 bits
            func       = 3 & 0x7          # [9:7] FUNC = 3
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (bram_id << 25) | (start_addr << 10) | (func << 7) | opcode

        elif inst == "SHAKE_gen_A":
            # 格式: SHAKE_gen_A mode, offset, start_addr
            # mode [31:30], offset [29:25], start_addr [24:10]
            mode       = args[0] & 0x3    # [31:30] 2 bits
            offset     = args[1] & 0x1F   # [29:25] 5 bits
            start_addr = args[2] & 0x7FFF # [24:10] 15 bits
            func       = 4 & 0x7          # [9:7] FUNC = 4
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (mode << 30) | (offset << 25) | (start_addr << 10) | (func << 7) | opcode

        elif inst == "SHAKE_gen_SE":
            # 【特殊指令处理】为了避免偏移和 ID 冲突
            # 格式: SHAKE_gen_SE mode, offset, bram_id, word_addr
            # mode [31:30], offset [29:25], bram_id [24], word_addr [23:10]
            mode       = args[0] & 0x3    # [31:30] 2 bits
            offset     = args[1] & 0x1F   # [29:25] 5 bits
            bram_id    = args[2] & 0x1    # [24] 1 bit
            word_addr  = args[3] & 0x3FFF # [23:10] 14 bits (注意：传入的是字地址)
            func       = 5 & 0x7          # [9:7] FUNC = 5
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (mode << 30) | (offset << 25) | (bram_id << 24) | (word_addr << 10) | (func << 7) | opcode

        elif inst == "SHAKE_absorb_genA":
            # 格式: SHAKE_absorb_genA MATRIX_sign, block_num, row_index
            # MATRIX_sign [31], block_num [29:26], row_index [25:10]
            sign       = args[0] & 0x1    # [31] 1 bit
            block_num  = args[1] & 0xF    # [29:26] 4 bits
            row_index  = args[2] & 0xFFFF # [25:10] 16 bits
            func       = 7 & 0x7          # [9:7] FUNC = 7
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (sign << 31) | (block_num << 26) | (row_index << 10) | (func << 7) | opcode

        elif inst == "NOP":
            machine_code = 0xAB000000
        else:
            raise ValueError(f"Unknown instruction: {inst}")

    except IndexError:
        raise ValueError(f"Not enough arguments for instruction: {inst}")

    return machine_code

# ==========================================
# 3. 文件读写
# ==========================================
def main():
    input_file = './simdata/test.asm'
    output_file = './simdata/firmware.bin'

    try:
        # 使用 'wb' 模式（Write Binary）
        with open(input_file, 'r') as f_in, open(output_file, 'wb') as f_out:
            for line_num, line in enumerate(f_in, 1):
                try:
                    code = assemble_line(line)
                    if code is not None:
                        # 将 32-bit 整数打包为 4 个字节，小端序
                        bin_bytes = code.to_bytes(4, byteorder='little', signed=False)
                        f_out.write(bin_bytes)
                        
                        # 打印十六进制方便核对
                        print(f"Line {line_num}: {line.strip():<40} -> {code:08X}")
                except Exception as e:
                    print(f"Error at line {line_num}: {line.strip()} -> {e}")
                    
        print(f"\n✅ Assembly successful! Binary output saved to {output_file}")
    except FileNotFoundError:
        print(f"Error: Input file '{input_file}' not found.")

if __name__ == "__main__":
    main()
