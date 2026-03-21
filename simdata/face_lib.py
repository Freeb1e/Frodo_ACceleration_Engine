# FACE (Frodo ACceleration Engine) Instruction Library
# This library provides a high-level API to generate assembly code for the FACE architecture.

class FaceLib:
    def __init__(self):
        self.instructions = []

    def _emit(self, line):
        self.instructions.append(line)

    def comment(self, text):
        """添加一条注释"""
        self._emit(f"# {text}")

    # ... (SYSTOLIC)

    def systolic_addrset(self, addr, target):
        self._emit(f"systolic_addrset {hex(addr)}, {target}")

    def systolic_calc(self, matrix_size, ctrl_mode, inpack=0, outpack=0, inpack_right=0, addsrc_unpack=0):

        self._emit(f"systolic_calc {matrix_size}, {ctrl_mode}, {inpack}, {outpack}, {inpack_right}, {addsrc_unpack}")

    def systolic_bufswap(self):
        self._emit("systolic_bufswap")

    def frodo_v_encodeu_add(self):
        """仿真专用：触发 DPI-C 在 C 侧执行 V + encode(u)"""
        self._emit("frodo_v_encodeu_add")

    def test_print_simtime(self):
        """仿真专用：触发 DPI-C 打印当前 sim_time"""
        self._emit("test_print_simtime")

    # ==========================================
    # 2. SHAKE (SHA-3) 模块指令
    # ==========================================

    def shake_seedaddrset(self, shakemode, start_addr, seedram_id=0):
        """
        :param shakemode: 0: SHAKE128, 1: SHAKE256
        :param start_addr: 种子读取起始地址
        :param seedram_id: 0: SP_RAM, 1: DP_RAM (默认 0)
        """
        if seedram_id == 0:
            self._emit(f"SHAKE_seedaddrset {shakemode}, {hex(start_addr)}")
        else:
            self._emit(f"SHAKE_seedaddrset {shakemode}, {hex(start_addr)}, {seedram_id}")

    def shake_seedset(self, last_block_bytes, absorb_num):
        self._emit(f"SHAKE_seedset {last_block_bytes}, {absorb_num}")

    def shake_squeezeonce(self):
        self._emit("SHAKE_squeezeonce")

    def shake_absorb(self, last_block_words, seg_absorb_num):
        """
        触发从当前地址开始吸收。
        :param last_block_words: 本段最后块的有效字数 (0表示整块有效)
        :param seg_absorb_num: 本段吸收块数
        """
        self._emit(f"SHAKE_absorb {last_block_words}, {seg_absorb_num}")

    def shake_gen_a(self, mode, row_len_flag, row_index):
        """
        触发 A 矩阵采样硬件循环，一次指令生成连续 4 行。
        :param mode: 标准 (0:640, 1:976, 2:1344)
        :param row_len_flag: 行长度选择 (0:1344, 1:976)
        :param row_index: 起始行号，硬件自动生成 row_index ~ row_index+3
        """
        self._emit(f"SHAKE_gen_A {mode}, {row_len_flag}, {hex(row_index)}")

    def shake_gen_se(self, mode, offset, bram_id, esign, word_addr):
        """
        【特殊指令】生成 S 或 E 矩阵。
        :param mode: 标准 (0:640, 1:976, 2:1344)
        :param offset: 字偏移 (0-24)
        :param bram_id: 目标 BRAM (0:SP, 1:DP)
        :param esign: 标志位 (0: S矩阵-8bit, 1: E矩阵-16bit)
        :param word_addr: 13位字地址
        """
        self._emit(f"SHAKE_gen_SE {mode}, {offset}, {bram_id}, {esign}, {hex(word_addr)}")

    def shake_dumpaword(self, offset, start_addr, dumpram_id=0):
        """
        将 SHAKE 状态中指定 64-bit word 写回 RAM。
        :param offset: 状态字偏移 (0-24)
        :param start_addr: 目标起始地址
        :param dumpram_id: 目标 RAM (0: SP_RAM, 1: DP_RAM)，默认 0
        """
        if dumpram_id == 0:
            self._emit(f"SHAKE_dumpaword {offset}, {hex(start_addr)}")
        else:
            self._emit(f"SHAKE_dumpaword {offset}, {hex(start_addr)}, {dumpram_id}")

    def shake_absorb_genA(self, matrix_sign, block_num, row_index, pad_sel=0):
        """
        :param matrix_sign: 矩阵类型 (0:A, 1:SE)
        :param block_num: 吸收块数参数
        :param row_index: 行索引
        :param pad_sel: 最后一字节补位选择 (0:0x5F, 1:0x96)
        """
        self._emit(f"SHAKE_absorb_genA {matrix_sign}, {block_num}, {hex(row_index)}, {pad_sel}")

    def nop(self):
        self._emit("NOP")

    def save(self, filename="simdata/test.asm"):
        with open(filename, "w") as f:
            for inst in self.instructions:
                f.write(inst + "\n")
        print(f"✅ Assembly file generated: {filename}")
