# Frodo Acceleration Engine 使用说明

本文档面向当前仓库版本，覆盖工程定位、构建运行、内存布局、指令编码和调试验证流程。

## 工程概述

Frodo Acceleration Engine 是一个面向 FrodoKEM 关键计算路径的硬件加速仿真工程，采用 Verilog/SystemVerilog + DPI-C + Python 协同开发与验证。工程核心是指令驱动的硬件平台 `TEST_PLATFORM`，围绕三类能力展开：
- 脉动阵列计算：完成矩阵乘加、转置路径及相关 pack/unpack 数据通路。
- SHAKE/采样路径：完成种子吸收、squeeze、A/SE 采样与相关状态导出。
- 仿真辅助路径：通过 DPI-C 完成内存模型、测试指令与结果导出。

典型工作流：
1. 使用 Python 脚本生成 `test.asm`（流程级指令序列）。
2. 使用汇编器将指令转换为机器码并装载到仿真环境。
3. 运行 Verilator 仿真，输出波形与 RAM 二进制结果。
4. 使用 Python 参考实现对输出进行一致性比对（包含字节序处理）。

工程分层：`vsrc/` 负责硬件行为，`csrc/` 负责 DPI-C 与内存桥接，`simdata/` 负责指令程序生成，`py/` 负责参考模型与结果比对。

文档约定：
- 字地址：以 64-bit 为 1 字（8 字节）。
- 字节地址：按 byte 线性寻址。
- 表格中的结束地址均为开区间。

## 1. 快速开始

### 1.0 环境要求

- Linux 环境
- `verilator`、`make`
- `python3`
- 可选：`gtkwave`（查看波形）

### 1.1 构建与运行

```bash
make build     # Verilator 编译 + C++ 仿真程序链接
make run       # build 后运行 ./obj_dir/VTEST_PLATFORM
make RUN       # 等价于 make run
make see       # 使用 gtkwave 打开 waveform.vcd
make clean     # 清理 obj_dir 与波形
```

### 1.2 生成汇编

```bash
make asm
```

该命令会依次执行：
- `python3 simdata/program.py`
- `python3 simdata/assembler.py`

默认会生成 `simdata/test.asm` 及对应机器码表，供仿真读取。

### 1.3 最小验证路径

```bash
make asm
make run
```

验证产物：
- 波形：`waveform.vcd`
- 仿真输出：`output/`

## 2. 仓库结构说明

### 2.1 主要目录

| 目录 | 说明 |
| :--- | :--- |
| `vsrc/` | SystemVerilog 设计文件 |
| `vsrc/SYSTOLIC/` | 脉动阵列与访存控制 |
| `vsrc/SHA/` | SHA3/SHAKE 控制与数据通路 |
| `vsrc/SAMPLER/` | A/SE 采样模块 |
| `csrc/` | DPI-C 与仿真侧内存模型 |
| `simdata/` | 汇编生成、测试程序、RAM 初始化素材 |
| `py/` | 参考模型与对比脚本 |
| `output/` | 仿真输出二进制文件 |
| `obj_dir/` | Verilator 生成产物 |

### 2.2 顶层与关键文件

- 顶层模块：`TEST_PLATFORM`（可由 make 变量 `TOP_NAME` 覆盖）
- 宏定义：`vsrc/define.sv`
- 指令程序入口：`simdata/program.py`
- 汇编器：`simdata/assembler.py`

## 3. 内存与 BRAM 约定

地址单位：本章中“字地址”均以 64-bit（8 字节）为单位。

### 3.1 仿真内存对象（C 侧）

```c
extern uint8_t sp_ram[RAM_SIZE];      // bram_id = 0
extern uint8_t dp_ram[RAM_SIZE];      // bram_id = 1
extern uint8_t A_buffer_1[BUFFER_SIZE]; // bram_id = 2
extern uint8_t A_buffer_2[BUFFER_SIZE]; // bram_id = 3
extern uint8_t PC_ROM[PC_ROM_SIZE];
```

### 3.2 SP RAM 关键布局

| 名称 | 起始字地址 | 起始字节地址 | 长度(字) | 结束字地址(开区间) | 结束字节地址(开区间) |
| :--- | ---: | ---: | ---: | ---: | ---: |
| S | 0 | 0 | 1344 | 1344 | 10752 |
| E | 1344 | 10752 | 2688 | 4032 | 32256 |
| pkh | 4032 | 32256 | 4 | 4036 | 32288 |
| u | 4036 | 32288 | 4 | 4040 | 32320 |
| salt | 4040 | 32320 | 8 | 4048 | 32384 |
| seed_se | 4048 | 32384 | 8 | 4056 | 32448 |
| k | 4056 | 32448 | 4 | 4060 | 32480 |
| s | 4060 | 32480 | 4 | 4064 | 32512 |
| z | 4064 | 32512 | 2 | 4066 | 32528 |
| ss | 4066 | 32528 | 4 | 4070 | 32560 |

总深度：4070 字（32560 字节）。

### 3.3 DP RAM 关键布局

说明：下表按当前工程 64-bit RAM（每字 8 字节）给出，与 128-bit 示意图换算结果一致。

| 名称 | 起始字地址 | 起始字节地址 | 长度(字) | 结束字地址(开区间) | 结束字节地址(开区间) |
| :--- | ---: | ---: | ---: | ---: | ---: |
| S' | 0 | 0 | 1344 | 1344 | 10752 |
| E' | 1344 | 10752 | 2688 | 4032 | 32256 |
| E'' | 4032 | 32256 | 16 | 4048 | 32384 |
| C | 4048 | 32384 | 16 | 4064 | 32512 |

总深度：4064 字（32512 字节）。

### 3.4 BRAM 角色

仿真中扩展了 5 片逻辑存储：
- SP_RAM
- DP_RAM
- HASH_buffer1
- HASH_buffer2
- INSTR_ROM

## 4. 指令编码总览

### 4.1 Opcode

```sv
`define SYSOPCODE  7'b1010101
`define SHAOPCODE  7'b1010100
`define TESTOPCODE 7'b1010110
```

### 4.2 FUNC 编码

```sv
`define systolic_addrset_FUNC       3'b000
`define systolic_calc_FUNC          3'b001
`define systolic_bufswap_FUNC       3'd2
`define TEST_frodo_v_encodeu_add_FUNC 3'd0
`define TEST_print_simtime_FUNC     3'd1

`define SHAKE_seedaddrset_FUNC      3'd0
`define SHAKE_seedset_FUNC          3'd1
`define SHAKE_squeezeonce_FUNC      3'd2
`define SHAKE_absorb_FUNC           3'd3
`define SHAKE_gen_A_FUNC            3'd4
`define SHAKE_gen_SE_FUNC           3'd5
`define SHAKE_dumpaword_FUNC        3'd6
`define SHAKE_absorb_genA_FUNC      3'd7
```

### 4.3 32-bit 指令字段

| function |                                                                          instruction[31:0] |
| :------- | -----------------------------------------------------------------------------------------: |
| systolic_addrset |                               `[31:12]BASE_ADDR [11:10]SETTAR [9:7]FUNC [6:0]SYSOPCODE` |
| systolic_calc | `[26]addsrc_unpack [25]inpack_right [24]inpack [23]outpack [22:12]MATRIX_SIZE [11:10]ctrl_mode [9:7]FUNC [6:0]SYSOPCODE` |
| systolic_bufswap |                                                                  `[9:7]FUNC [6:0]SYSOPCODE` |
| frodo_v_encodeu_add |                                                         `[9:7]FUNC [6:0]TESTOPCODE` |
| test_print_simtime |                                                         `[9:7]FUNC [6:0]TESTOPCODE` |
| SHAKE_seedaddrset |              `[26]seedram_id [25]shakemode [24:10]start_addr [9:7]FUNC [6:0]SHAOPCODE` |
| SHAKE_seedset |                   `[25:18]last_block_bytes [17:10]absorb_num [9:7]FUNC [6:0]SHAOPCODE` |
| SHAKE_squeezeonce |                                                                  `[9:7]FUNC [6:0]SHAOPCODE` |
| SHAKE_absorb |                   `[22:18]last_block_words [17:10]seg_absorb_num [9:7]FUNC [6:0]SHAOPCODE` |
| SHAKE_gen_A |          `[31:30]mode [29]row_len_flag [28:26]reserved [25:10]row_index [9:7]FUNC [6:0]SHAOPCODE` |
| SHAKE_gen_SE | `[31:30]mode [29:25]offset [24]bram_id [23]esign [22:10]word_addr [9:7]FUNC [6:0]SHAOPCODE` |
| SHAKE_dumpaword |              `[30]dumpram_id [29:25]offset [24:10]start_addr [9:7]FUNC [6:0]SHAOPCODE` |
| SHAKE_absorb_genA | `[31]matrix_sign [30]pad_sel [29:26]block_num [25:10]row_index [9:7]FUNC [6:0]SHAOPCODE` |

### 4.4 逐字段作用说明（按指令合并）

| 指令 | 位段参数汇总 | 作用汇总 |
| :--- | :--- | :--- |
| systolic_addrset | [31:12] BASE_ADDR; [11:10] SETTAR; [9:7] FUNC; [6:0] SYSOPCODE | 设置 LEFT/RIGHT/ADDSRC/SAVE 基地址寄存器。SETTAR: 0 LEFT, 1 RIGHT, 2 ADDSRC, 3 SAVE。 |
| systolic_calc | [26] addsrc_unpack; [25] inpack_right; [24] inpack; [23] outpack; [22:12] MATRIX_SIZE; [11:10] ctrl_mode; [9:7] FUNC; [6:0] SYSOPCODE | 启动脉动阵列乘加。四个 pack 位控制输入/累加源/输出的 16-bit 打包与解包，ctrl_mode: 00 AS, 01 S'B, 10 B'S, 11 S'A。 |
| systolic_bufswap | [9:7] FUNC; [6:0] SYSOPCODE | 切换 HASH_buffer1/2 的乒乓角色。 |
| frodo_v_encodeu_add | [9:7] FUNC; [6:0] TESTOPCODE | 调用测试路径，执行 V + encode(u)。 |
| test_print_simtime | [9:7] FUNC; [6:0] TESTOPCODE | 调用测试路径，打印当前仿真时间。 |
| SHAKE_seedaddrset | [26] seedram_id; [25] shakemode; [24:10] start_addr; [9:7] FUNC; [6:0] SHAOPCODE | 设置 SHAKE 输入来源与地址。seedram_id: 0 SP, 1 DP；shakemode: 0 SHAKE128, 1 SHAKE256。 |
| SHAKE_seedset | [25:18] last_block_bytes; [17:10] absorb_num; [9:7] FUNC; [6:0] SHAOPCODE | 配置 absorb 次数与最后一块有效字节数。 |
| SHAKE_squeezeonce | [9:7] FUNC; [6:0] SHAOPCODE | 执行一次 squeeze。 |
| SHAKE_absorb | [22:18] last_block_words; [17:10] seg_absorb_num; [9:7] FUNC; [6:0] SHAOPCODE | 分段 absorb：完整 block 数 + 尾部额外 64-bit 字数。 |
| SHAKE_gen_A | [31:30] mode; [29] row_len_flag; [28:26] reserved; [25:10] row_index; [9:7] FUNC; [6:0] SHAOPCODE | 生成 A 采样数据。mode: 0/1/2 对应 640/976/1344，row_len_flag: 0 1344, 1 976。 |
| SHAKE_gen_SE | [31:30] mode; [29:25] offset; [24] bram_id; [23] esign; [22:10] word_addr; [9:7] FUNC; [6:0] SHAOPCODE | 生成 S/E 采样数据并写 RAM。bram_id: 0 SP, 1 DP；esign: 0 S, 1 E。 |
| SHAKE_dumpaword | [30] dumpram_id; [29:25] offset; [24:10] start_addr; [9:7] FUNC; [6:0] SHAOPCODE | 将 SHAKE 状态中指定 64-bit 字写回 RAM。dumpram_id: 0 SP, 1 DP。 |
| SHAKE_absorb_genA | [31] matrix_sign; [30] pad_sel; [29:26] block_num; [25:10] row_index; [9:7] FUNC; [6:0] SHAOPCODE | 启动 A/SE 路径专用 absorb 过程。matrix_sign: 0 A, 1 SE；pad_sel: 0 -> 0x5F, 1 -> 0x96。 |

## 5. Python 编程指引

### 5.1 脚本职责划分

- `simdata/program.py`：组织高层流程（keygen/encap/decap）
- `simdata/face_lib.py`：封装指令级 API（如 `shake_*`、`systolic_*`）
- `simdata/assembler.py`：把 `.asm` 转成机器码表
- `py/`：参考模型与结果对比脚本

建议把流程控制和位段编码分离，避免在 `program.py` 直接手写位拼接。

### 5.2 推荐编写模式

```python
from face_lib import FaceLib

def build_case():
    face = FaceLib()

    # 1) 配置 SHAKE 输入
    face.shake_seedaddrset(1, 32512)
    face.shake_seedset(16, 1)
    face.shake_absorb(0, 1)

    # 2) 产生中间数据
    face.shake_gen_a(2, 0, 0)
    face.systolic_bufswap()
    face.systolic_addrset(0, 0)
    face.systolic_addrset(0, 1)
    face.systolic_addrset(10752, 2)
    face.systolic_addrset(10752, 3)
    face.systolic_calc(336, 0, 0, 1, 0)

    # 3) 输出程序
    face.save("simdata/test.asm")

if __name__ == "__main__":
    build_case()
```

### 5.3 参数与地址规范

- 地址统一使用十进制字节地址，必要时在注释标明来源。
- `systolic_calc` 的可选参数 `addsrc_unpack` 建议显式传入，避免默认值歧义。
- `shake_seedaddrset` 的第三参数 `seedram_id` 建议在关键路径显式写出。

### 5.4 调试与回归建议

- 每次改动后执行：`make asm && make run`。
- 对 B/C 等 16-bit 数据，比较前先统一 pack/unpack 字节序。

### 5.5 常见问题

- 汇编可生成但结果异常：优先检查地址单位是否混用（字地址/字节地址）。
- 与参考模型 mismatch 很多：优先检查 16-bit 字节序与 pack/unpack 开关。
- 流程卡住：先插入 `test_print_simtime` 定位停滞阶段，再查看波形。

## 6. 汇编书写规则

### 6.1 基本格式

- 支持十进制与 `0x` 前缀十六进制
- 参数以逗号分隔
- 支持 `NOP`（编码为 `0xAB000000`）

### 6.2 指令示例

| 示例 | 参数顺序 |
| :--- | :--- |
| `systolic_addrset 0x1000, 0` | BASE_ADDR, SETTAR |
| `systolic_calc 336, 0, 0, 1, 0[, 1]` | MATRIX_SIZE, ctrl_mode, inpack, outpack, inpack_right, addsrc_unpack(可选) |
| `systolic_bufswap` | 无参数 |
| `frodo_v_encodeu_add` | 无参数 |
| `test_print_simtime` | 无参数 |
| `SHAKE_seedaddrset 1, 0x2000[, 1]` | shakemode, start_addr, seedram_id(可选, 默认0) |
| `SHAKE_seedset 136, 1` | last_block_bytes, absorb_num |
| `SHAKE_squeezeonce` | 无参数 |
| `SHAKE_absorb 5, 2` | last_block_words, seg_absorb_num |
| `SHAKE_gen_A 2, 0, 0x0` | mode, row_len_flag, row_index |
| `SHAKE_gen_SE 2, 0, 0, 0, 0x3000` | mode, offset, bram_id, esign, word_addr |
| `SHAKE_dumpaword 0, 0x0[, 1]` | offset, start_addr, dumpram_id(可选, 默认0) |
| `SHAKE_absorb_genA 0, 8, 0x1234[, 1]` | matrix_sign, block_num, row_index, pad_sel(可选) |

## 7. Systolic 访存与模式

### 7.1 ctrl_mode 含义

| ctrl_mode | 计算语义 | 左算子 | 右算子 | add_source | 保存目标 |
| :---: | :---:| :--- | :--- | :--- | :--- |
| 00 | AS | A_buffer | SP_RAM | SP_RAM | SP_RAM |
| 01 | S'B | DP_RAM | SP_RAM | DP_RAM | DP_RAM |
| 10 | B'S | DP_RAM | SP_RAM | DP_RAM | DP_RAM |
| 11 | S'A | DP_RAM | A_buffer | DP_RAM | DP_RAM |

### 7.2 地址通路摘要

| 阶段 | 字段 | mode=0 | mode=1/2 |
| :--- | :--- | :---: | :---: |
| AS_CALC | bram_addr1 | HASH | DP |
| AS_CALC | bram_addr2 | SP | SP |
| AS_SAVE | bram_addr1 | SP1 | DP1 |
| AS_SAVE | bram_addr2 | SP2 | DP2 |

## 8. SHAKE 调用场景

`shakemode`: 0 -> SHAKE128, 1 -> SHAKE256

| 阶段 | 输入 | 输出 | 目的 |
| :--- | :--- | :--- | :--- |
| keygen | z / seedA / B | seedA / A / SE / pkh | 生成公私钥材料 |
| encap | pkh / u / salt / k / B / C | seedSE / SEE / A / ss | 密封装流程 |
| decap | pkh / u / salt / k / B / C | seedSE / SEE / A / ss | 解封装流程 |

## 9. 调试与一致性检查

### 9.1 波形与输出

- 波形文件：`waveform.vcd`
- 输出目录：`output/`

### 9.2 字节序注意事项（重要）

- 在 B/C 等矩阵对比时，常见误差来源是 16-bit 打包字节序不一致。
- 本仓库 C 侧写回存在高低字节顺序约定；与 Python 参考做 byte-to-byte 对比前，先统一 pack/unpack 视图。

建议先做 16-bit 交换后再比较，可显著减少“假性 mismatch”。

### 9.3 常用对比命令

```bash
cmp -l -n 10752 ./output/Bout.bin ./py/ref_matrix_ST_8bit.bin \
| awk '{printf "Offset: 0x%04X | A: %3d | B: %3d\n", $1-1, strtonum("0"$2), strtonum("0"$3)}'
```

### 9.4 推荐排障顺序

1. `make asm` 检查指令程序是否成功生成。
2. `make run` 检查仿真是否正常结束。
3. 打开 `waveform.vcd` 检查关键状态机是否推进。
4. 比对 `output/` 与参考结果，最后处理字节序差异。

## 10. 维护建议

- 修改指令字段时，同步更新 `vsrc/define.sv`、`simdata/face_lib.py`、`simdata/assembler.py`。
- 修改默认流程入口（keygen/encap/decap）时，同步更新本说明的 1.2 与 1.3。
- 新增内存分区时，同时补充“字地址/字节地址”两列，避免地址单位歧义。
