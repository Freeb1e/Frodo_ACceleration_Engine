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

    def systolic_calc(self, matrix_size, ctrl_mode):
        self._emit(f"systolic_calc {matrix_size}, {ctrl_mode}")

    def systolic_bufswap(self):
        self._emit("systolic_bufswap")

    # ==========================================
    # 2. SHAKE (SHA-3) 模块指令
    # ==========================================

    def shake_seedaddrset(self, shakemode, start_addr):
        self._emit(f"SHAKE_seedaddrset {shakemode}, {hex(start_addr)}")

    def shake_seedset(self, last_block_bytes, absorb_num):
        self._emit(f"SHAKE_seedset {last_block_bytes}, {absorb_num}")

    def shake_squeezeonce(self):
        self._emit("SHAKE_squeezeonce")

    def shake_gen_a(self, mode, offset, start_addr):
        self._emit(f"SHAKE_gen_A {mode}, {offset}, {hex(start_addr)}")

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

    def shake_dumpaword(self, offset, start_addr):
        self._emit(f"SHAKE_dumpaword {offset}, {hex(start_addr)}")

    def shake_absorb_genA(self, matrix_sign, block_num, row_index):
        self._emit(f"SHAKE_absorb_genA {matrix_sign}, {block_num}, {hex(row_index)}")

    def nop(self):
        self._emit("NOP")

    def save(self, filename="simdata/test.asm"):
        with open(filename, "w") as f:
            for inst in self.instructions:
                f.write(inst + "\n")
        print(f"✅ Assembly file generated: {filename}")
