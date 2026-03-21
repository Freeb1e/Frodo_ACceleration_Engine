import sys

# ==========================================
# 1. 配置区：请根据你的实际设计修改 OPCODE
# ==========================================
OPCODE_SYSTOLIC = 0b1010101  # Systolic 阵列指令的 opcode
OPCODE_SHAKE    = 0b1010100  # SHAKE 模块指令的 opcode
OPCODE_TEST     = 0b1010110  # 仿真/调试 DPIC 指令 opcode

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
            # 格式: systolic_calc MATRIX_SIZE, ctrl_mode, inpack, outpack, inpack_right(optional), addsrc_unpack(optional)
            matrix_size = args[0] & 0x7FF # [22:12] 11 bits
            ctrl_mode   = args[1] & 0x3   # [11:10] 2 bits
            inpack      = (args[2] & 0x1) if len(args) > 2 else 0  # [24] 1 bit
            outpack     = (args[3] & 0x1) if len(args) > 3 else 0  # [23] 1 bit
            inpack_right = (args[4] & 0x1) if len(args) > 4 else inpack  # [25] 1 bit
            addsrc_unpack = (args[5] & 0x1) if len(args) > 5 else 0  # [26] 1 bit
            func        = 1 & 0x7         # [9:7] FUNC = 1
            opcode      = OPCODE_SYSTOLIC & 0x7F
            machine_code = (addsrc_unpack << 26) | (inpack_right << 25) | (inpack << 24) | (outpack << 23) | (matrix_size << 12) | (ctrl_mode << 10) | (func << 7) | opcode

        elif inst == "SHAKE_seedaddrset":
            # 格式: SHAKE_seedaddrset shakemode, start_addr, seedram_id(optional)
            # seedram_id: [26] 1 bit, 0=SP_RAM, 1=DP_RAM，缺省为 0
            shakemode   = args[0] & 0x1    # [25] 1 bit
            start_addr  = args[1] & 0x7FFF # [24:10] 15 bits
            seedram_id  = (args[2] & 0x1) if len(args) > 2 else 0
            func       = 0 & 0x7          # [9:7] FUNC = 0
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (seedram_id << 26) | (shakemode << 25) | (start_addr << 10) | (func << 7) | opcode

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

        elif inst == "SHAKE_absorb":
            # 格式: SHAKE_absorb last_block_words, seg_absorb_num
            # last_block_words [22:18] 5 bits, seg_absorb_num [17:10] 8 bits
            last_words = args[0] & 0x1F   # [22:18] 5 bits
            seg_num    = args[1] & 0xFF   # [17:10] 8 bits
            func       = 3 & 0x7          # [9:7] FUNC = 3
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (last_words << 18) | (seg_num << 10) | (func << 7) | opcode

        elif inst == "systolic_bufswap":
            # 格式: systolic_bufswap (无操作数)
            func       = 2 & 0x7          # [9:7] FUNC = 2
            opcode     = OPCODE_SYSTOLIC & 0x7F
            machine_code = (func << 7) | opcode

        elif inst == "frodo_v_encodeu_add":
            # 格式: frodo_v_encodeu_add (无操作数)
            # 仿真专用：触发 DPI-C 在 C 侧执行 V + encode(u)
            func       = 0 & 0x7          # [9:7] FUNC = 0
            opcode     = OPCODE_TEST & 0x7F
            machine_code = (func << 7) | opcode

        elif inst == "test_print_simtime":
            # 格式: test_print_simtime (无操作数)
            # 仿真专用：触发 DPI-C 打印当前 sim_time
            func       = 1 & 0x7          # [9:7] FUNC = 1
            opcode     = OPCODE_TEST & 0x7F
            machine_code = (func << 7) | opcode

        elif inst == "SHAKE_dumpaword":
            # 格式: SHAKE_dumpaword offset, start_addr[, dumpram_id]
            # dumpram_id [30] 1 bit, 0=SP_RAM(默认), 1=DP_RAM
            # offset [29:25], start_addr [24:10]
            dumpram_id = (args[2] & 0x1) if len(args) > 2 else 0
            offset     = args[0] & 0x1F   # [29:25] 5 bits
            start_addr = args[1] & 0x7FFF # [24:10] 15 bits
            func       = 6 & 0x7          # [9:7] FUNC = 6
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (dumpram_id << 30) | (offset << 25) | (start_addr << 10) | (func << 7) | opcode


        elif inst == "SHAKE_gen_A":
            # 格式: SHAKE_gen_A mode, row_len_flag, row_index
            # mode [31:30], row_len_flag [29], row_index [25:10]
            # [28:26] 保留为 0，硬件内部固定从地址0开始循环生成4行
            mode       = args[0] & 0x3     # [31:30] 2 bits
            row_len    = args[1] & 0x1     # [29] 1 bit (0:1344, 1:976)
            row_index  = args[2] & 0xFFFF  # [25:10] 16 bits
            func       = 4 & 0x7          # [9:7] FUNC = 4
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (mode << 30) | (row_len << 29) | (row_index << 10) | (func << 7) | opcode

        elif inst == "SHAKE_gen_SE":
            # 【特殊处理】 mode[31:30], offset[29:25], bram_id[24], esign[23], word_addr[22:10]
            mode       = args[0] & 0x3
            offset     = args[1] & 0x1F
            bram_id    = args[2] & 0x1
            esign      = args[3] & 0x1
            word_addr  = args[4] & 0x1FFF # 13 bits
            func       = 5 & 0x7
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (mode << 30) | (offset << 25) | (bram_id << 24) | (esign << 23) | (word_addr << 10) | (func << 7) | opcode

        elif inst == "SHAKE_absorb_genA":
            # 格式: SHAKE_absorb_genA MATRIX_sign, block_num, row_index, pad_sel(optional)
            # MATRIX_sign [31], pad_sel [30], block_num [29:26], row_index [25:10]
            sign       = args[0] & 0x1    # [31] 1 bit
            pad_sel    = (args[3] & 0x1) if len(args) > 3 else 0  # [30] 1 bit, 0:5F, 1:96
            block_num  = args[1] & 0xF    # [29:26] 4 bits
            row_index  = args[2] & 0xFFFF # [25:10] 16 bits
            func       = 7 & 0x7          # [9:7] FUNC = 7
            opcode     = OPCODE_SHAKE & 0x7F
            machine_code = (sign << 31) | (pad_sel << 30) | (block_num << 26) | (row_index << 10) | (func << 7) | opcode

        elif inst == "NOP":
            machine_code = 0xAB000000
        else:
            raise ValueError(f"Unknown instruction: {inst}")

    except IndexError:
        raise ValueError(f"Not enough arguments for instruction: {inst}")

    return machine_code

# ... (main)
def main():
    input_file = './simdata/test.asm'
    output_file = './simdata/firmware.bin'
    txt_output_file = './simdata/firmware_table.txt'

    try:
        with open(input_file, 'r') as f_in, \
             open(output_file, 'wb') as f_out, \
             open(txt_output_file, 'w') as f_txt:
            for line_num, line in enumerate(f_in, 1):
                try:
                    code = assemble_line(line)
                    if code is not None:
                        bin_bytes = code.to_bytes(4, byteorder='little', signed=False)
                        f_out.write(bin_bytes)
                        
                        log_str = f"Line {line_num}: {line.strip():<40} -> {code:08X}"
                        print(log_str)
                        f_txt.write(log_str + "\n")
                except Exception as e:
                    err_str = f"Error at line {line_num}: {line.strip()} -> {e}"
                    print(err_str)
                    f_txt.write(err_str + "\n")
                    
        print(f"\n✅ Assembly successful! Binary output saved to {output_file}")
        print(f"✅ Translation table saved to {txt_output_file}")
    except FileNotFoundError:
        print(f"Error: Input file '{input_file}' not found.")

if __name__ == "__main__":
    main()
