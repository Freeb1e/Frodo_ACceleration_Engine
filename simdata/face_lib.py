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

    # ==========================================
    # 1. SYSTOLIC 阵列指令
    # ==========================================

    def systolic_addrset(self, addr, target):
        """
        设置脉动阵列访问内存的基地址寄存器。
        :param addr: 基地址 (19位)
        :param target: 目标寄存器 (0:LEFT, 1:RIGHT, 2:ADDSRC, 3:SAVE)
        """
        self._emit(f"systolic_addrset {hex(addr)}, {target}")

    def systolic_calc(self, matrix_size, ctrl_mode):
        """
        启动脉动阵列矩阵乘加运算。
        :param matrix_size: 矩阵维度/计算长度
        :param ctrl_mode: 计算阶段模式 (0:AS, 1:S'B, 2:B'S, 3:S'A)
        """
        self._emit(f"systolic_calc {matrix_size}, {ctrl_mode}")

    def systolic_bufswap(self):
        """乒乓缓存切换。交换 HASH Buffer 1 和 2 的计算/生成角色。"""
        self._emit("systolic_bufswap")

    # ==========================================
    # 2. SHAKE (SHA-3) 模块指令
    # ==========================================

    def shake_seedaddrset(self, shakemode, start_addr):
        """
        设置 SHAKE 算法吸收入库数据的起始地址和模式。
        :param shakemode: 0 为 SHAKE128, 1 为 SHAKE256
        :param start_addr: 种子在内存中的起始地址
        """
        self._emit(f"SHAKE_seedaddrset {shakemode}, {hex(start_addr)}")

    def shake_seedset(self, last_block_bytes, absorb_num):
        """
        设置吸收参数并启动 SHAKE Absorb 过程。
        :param last_block_bytes: 最后一个块的有效字节数
        :param absorb_num: 吸收的块数
        """
        self._emit(f"SHAKE_seedset {last_block_bytes}, {absorb_num}")

    def shake_squeezeonce(self):
        """执行一次 SHAKE Squeeze 操作，生成新的内部状态块。"""
        self._emit("SHAKE_squeezeonce")

    def shake_gen_a(self, mode, offset, start_addr):
        """
        从 SHAKE 状态提取数据经采样写入 HASH 乒乓缓存区。
        :param mode: 标准 (0:640, 1:976, 2:1344)
        :param offset: 字偏移 (0-20)
        :param start_addr: HASH Buffer 内偏移 (15位)
        """
        self._emit(f"SHAKE_gen_A {mode}, {offset}, {hex(start_addr)}")

    def shake_gen_se(self, mode, offset, bram_id, start_addr):
        """
        从 SHAKE 状态提取数据经采样写入内存。
        :param mode: 标准 (0:640, 1:976, 2:1344)
        :param offset: 字偏移 (0-20)
        :param bram_id: 目标 BRAM (0:SP, 1:DP)
        :param start_addr: 内存地址 (14位)
        """
        self._emit(f"SHAKE_gen_SE {mode}, {offset}, {bram_id}, {hex(start_addr)}")

    def shake_dumpaword(self, offset, start_addr):
        """
        直接从 SHAKE 状态提取一个原始字(64-bit)存入 HASH Buffer。
        :param offset: 字偏移 (0-20)
        :param start_addr: HASH Buffer 内目标地址
        """
        self._emit(f"SHAKE_dumpaword {offset}, {hex(start_addr)}")

    def shake_dumponce(self, bram_id, start_addr):
        """
        将当前 SHAKE 块中的原始数据直接转储到内存。
        :param bram_id: 目标 BRAM
        :param start_addr: 写入内存的起始偏移地址
        """
        self._emit(f"SHAKE_dumponce {bram_id}, {hex(start_addr)}")

    def shake_absorb_genA(self, matrix_sign, block_num, row_index):
        """
        用于生成矩阵 A 的特定行处理指令。
        :param matrix_sign: 符号位 (1 bit, instr[31])
        :param block_num: 块编号 (4 bits, instr[29:26])
        :param row_index: 当前处理的行索引 (16 bits, instr[25:10])
        """
        self._emit(f"SHAKE_absorb_genA {matrix_sign}, {block_num}, {hex(row_index)}")

    # ==========================================
    # 3. 辅助指令
    # ==========================================

    def nop(self):
        """空指令"""
        self._emit("NOP")

    def save(self, filename="simdata/test.asm"):
        """将生成的指令保存到文件"""
        with open(filename, "w") as f:
            for inst in self.instructions:
                f.write(inst + "\n")
        print(f"✅ Assembly file generated: {filename}")
