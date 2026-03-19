## 内存摆放
|   S   |   E   |  pkh  |   u   | salt  | seed_se |   k   |   s   |   z   |  ss   |
| :---: | :---: | :---: | :---: | :---: | :-----: | :---: | :---: | :---: | :---: |
|   0   | 1344  | 4032  | 4036  | 4040  |  4048   | 4056  | 4060  | 4064  | 4066  |

**depth=4070**  
按照字节进行访问$4070 \times 8 = (0111,1111,0011,0000)_{2}$对sp进行访存最多需要15位数据线

``` c
extern uint8_t sp_ram[RAM_SIZE]; // 对应 bramid = 0
extern uint8_t dp_ram[RAM_SIZE];  // 对应 bramid = 1
extern uint8_t A_buffer_1[BUFFER_SIZE]; //对应 bramid = 2
extern uint8_t A_buffer_2[BUFFER_SIZE]; //对应 bramid = 3
extern uint8_t PC_ROM[PC_ROM_SIZE];
```
## 指令安排
| function          |                                                                          instruction[31:0] | FUNC |
| :---------------- | -----------------------------------------------------------------------------------------: | :--- |
| systolic_addrset  |                               `[31:12]BASE_ADDR` `[11:10]SETTAR` `[9:7]FUNC` `[6:0]OPCODE` | 0    |
| systolic_calc     |          `[24]inpack` `[23]outpack` `[22:12]MATRIX_SIZE` `[11:10]ctrl_mode` `[9:7]FUNC` `[6:0]OPCODE` | 1    |
| systolic_bufswap  |                                                                  `[9:7]FUNC` `[6:0]OPCODE` | 2    |
| SHAKE_seedaddrset |                             `[25]shakemode` `[24:10]start_addr`  `[9:7]FUNC` `[6:0]OPCODE` | 0    |
| SHAKE_seedset     |                   `[25:18]last_block_bytes` `[17:10]absorb_num`  `[9:7]FUNC` `[6:0]OPCODE` | 1    |
| SHAKE_squeezeonce |                                                                  `[9:7]FUNC` `[6:0]OPCODE` | 2    |
| SHAKE_absorb      |                   `[22:18]last_block_words` `[17:10]seg_absorb_num` `[9:7]FUNC` `[6:0]OPCODE` | 3    |
| SHAKE_gen_A       |          `[31:30]mode` `[29]row_len_flag` `[28:26]reserved` `[25:10]row_index` `[9:7]FUNC` `[6:0]OPCODE` | 4    |
| SHAKE_gen_SE      | `[31:30]mode` `[29:25]offset` `[24]bram_id` `[23]esign` `[22:10]word_addr` `[9:7]FUNC` `[6:0]OPCODE` | 5 |
| SHAKE_dumpaword    |                               `[29:25]offset` `[24:10]start_addr`  `[9:7]FUNC` `[6:0]OPCODE` | 6    |
| SHAKE_absorb_genA | `[31]matrix_sign` `[29:26]block_num` `[25:10]row_index` `[9:7]FUNC` `[6:0]OPCODE` | 7    |

### 指令详细解释
| 指令名称              | 功能描述                                                    | 参数说明                                                                                                                    |
| :-------------------- | :---------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------- |
| **systolic_addrset**  | 设置脉动阵列访问内存的基地址寄存器。                        | **BASE_ADDR**: 20位基地址；**SETTAR**: 目标寄存器 (0:LEFT, 1:RIGHT, 2:ADDSRC, 3:SAVE)。                                     |
| **systolic_calc**     | 启动脉动阵列矩阵乘加运算。                                  | **inpack**: 读取时字节交换 (1:启用pack纠正)；**outpack**: 输出时字节交换 (1:启用pack)；**MATRIX_SIZE**: 矩阵维度/计算长度；**ctrl_mode**: 计算阶段模式 (00:AS, 01:S'B, 10:B'S, 11:S'A)。 |
| **systolic_bufswap**  | **乒乓缓存切换**。交换 HASH Buffer 1 和 2 的计算/生成角色。 | 无额外参数。执行后翻转内部 `hash_buffer_sel` 信号。                                                                         |
| **SHAKE_seedaddrset** | 设置 SHAKE 算法吸收入库数据的起始地址和模式。               | **shakemode**: 0 为 SHAKE128, 1 为 SHAKE256；**start_addr**: 种子在内存中的起始地址。                                       |
| **SHAKE_seedset**     | 设置吸收参数并启动 SHAKE Absorb 过程。                      | **absorb_num**: 总吸收的块数；**last_block_bytes**: 最后一个块的有效字节数。                                                |
| **SHAKE_squeezeonce** | 执行一次 SHAKE Squeeze 操作，生成新的内部状态块。           | 无额外参数。                                                                                                                |
| **SHAKE_absorb**      | **分段吸收指令**。在已配置的种子地址基础上继续吸收后续段。 | **last_block_words**: 完整块之后额外读取的 64-bit 字数；**seg_absorb_num**: 本段吸收的完整块数。                            |
| **SHAKE_gen_A**       | A矩阵采样硬件循环：一次指令自动生成连续4行并写入 HASH 乒乓缓存区。           | **mode**: 标准 (0:640, 1:976, 2:1344)；**row_len_flag**: 行长度选择 (0:1344, 1:976)；**row_index**: 起始行号（内部自动生成4行）；写入地址固定从 0 开始。               |
| **SHAKE_gen_SE**      | 从 SHAKE 状态提取数据经采样写入内存。                       | **mode**: 标准 (0:640, 1:976, 2:1344)；**offset**: 字偏移 (0-24)；**bram_id**: 目标 BRAM；**esign**: 标志位 (0:S, 1:E)；**word_addr**: 内存字地址。 |
| **SHAKE_dumpaword**   | 将当前 SHAKE 状态块中指定的 64-bit 字转储到内存。           | **offset**: 字偏移 (0-24)；**start_addr**: 写入内存的起始偏移地址。                                                         |
| **SHAKE_absorb_genA** | 用于生成矩阵 A 或 SE 的特定行处理指令。                     | **matrix_sign**: 矩阵类型 (0:A, 1:SE)；**block_num**: 块编号；**row_index**: 当前处理的行索引。                             |

### 汇编指令格式说明
为了方便编写 `.asm` 文件，汇编器支持以下格式（支持十进制或 `0x` 前缀的十六进制）：

| 汇编指令示例                           | 操作数顺序与意义                                   |
| :------------------------------------- | :------------------------------------------------- |
| `systolic_addrset 0x1000, 0`           | `BASE_ADDR`, `SETTAR`                              |
| `systolic_calc 64, 0, 1, 0`              | `MATRIX_SIZE`, `ctrl_mode`, `inpack`, `outpack`    |
| `systolic_bufswap`                     | (无操作数，触发 HASH Buffer 角色翻转)              |
| `SHAKE_seedaddrset 1, 0x2000`          | `shakemode` (0:128, 1:256), `start_addr`           |
| `SHAKE_seedset 136, 1`                 | `last_block_bytes`, `absorb_num`                   |
| `SHAKE_squeezeonce`                    | (无操作数)                                         |
| `SHAKE_absorb 5, 2`                    | `last_block_words`, `seg_absorb_num`               |
| `SHAKE_gen_A 0, 0, 0x0`                | `mode`, `row_len_flag`, `row_index`                     |
| `SHAKE_gen_SE 2, 0, 0, 0, 0x3000`      | `mode`, `offset`, `bram_id`, `esign`, `word_addr`  |
| `SHAKE_dumpaword 0, 0x0`               | `offset`, `start_addr`                             |
| `SHAKE_absorb_genA 0, 8, 0x1234`       | `matrix_sign`, `block_num`, `row_index`            |
| `NOP`                                  | (空指令，生成 `0xAB000000`)                        |

---
```sv
`define SYSOPCODE 7'b1010101
`define SHAOPCODE 7'b1010100

`define systolic_addrset_FUNC 3'b000
`define systolic_calc_FUNC 3'b001
`define systolic_bufswap_FUNC 3'd2

`define SHAKE_seedaddrset_FUNC 3'd0
`define SHAKE_seedset_FUNC 3'd1
`define SHAKE_squeezeonce_FUNC 3'd2
`define SHAKE_absorb_FUNC 3'd3
`define SHAKE_gen_A_FUNC 3'd4
`define SHAKE_gen_SE_FUNC 3'd5
`define SHAKE_dumpaword_FUNC 3'd6
`define SHAKE_absorb_genA_FUNC 3'd7
```

### GEN指令参数说明:
- **mode** [31:30]: 采样标准选择 (0:640, 1:976, 2:1344)。
- **row_len_flag** [29]: A 矩阵单行长度选择 (0:1344, 1:976)，`SHAKE_gen_A` 内部按该长度循环4行。
- **row_index** [25:10]: `SHAKE_gen_A` 的起始行索引，指令内部自动处理连续4行。
- **reserved** [28:26]: 保留位，当前写 0。
- **bram_id** [24]: 0 为 SP_RAM, 1 为 DP_RAM (仅 gen_SE 有效)。
- **esign** [23]: 0 为 S 矩阵 (8-bit), 1 为 E 矩阵 (16-bit) (仅 gen_SE 有效)。
- **word_addr**: 写入起始字偏移地址。
- **matrix_sign** [31]: 矩阵类型标志位 (0:A, 1:SE)。
- **block_num** [29:26]: 块编号 (4 bits)。
- **row_index** [25:10]: 行索引 (16 bits)。
## systolic模块访存安排
| 计算阶段     | 计算模式 | 左算子来源 | 右算子来源 | 输出累加源 | 输出位置 | 编号 |
| ------------ | -------- | ---------- | ---------- | ---------- | -------- | ---- |
| $AS$         | 左A时序  | A_buffer   | sp-ram     | sp-ram     | sp-ram   | 00   |
| $S^\prime B$ | 左A时序  | dp-ram     | sp-ram     | dp-ram     | dp-ram   | 01   |
| $B^\prime S$ | 左A时序  | dp-ram     | sp-ram     | dp-ram1    | dp-ram   | 10   |
| $S'^A$       | 右A时序  | dp-ram     | A_buffer   | dp-ram     | dp-ram   | 11   |

### systolic 模块内部
- AS_CALC（计算输入）
	- `bram_data1`：left_in
	- `bram_data2`：right_in
	- mode 0：`bram_addr1` -> HASH，`bram_addr2` -> SP
	- mode 1 / mode 2：`bram_addr1` -> DP，`bram_addr2` -> SP

- AS_SAVE（保存输出）
	- `bram_data1`：add_source
	- `bram_savedata`：adder's output
	- mode 0：`bram_addr1` -> SP1，`bram_addr2` -> SP2
	- mode 1 / mode 2：`bram_addr1` -> DP1，`bram_addr2` -> DP2

简明表格：

|    操作 | 字段       | mode 0 | mode 1 / 2 |
| ------: | ---------- | :----: | :--------: |
| AS_CALC | bram_addr1 |  HASH  |     DP     |
| AS_CALC | bram_addr2 |   SP   |     SP     |
| AS_SAVE | bram_addr1 |  SP1   |    DP1     |
| AS_SAVE | bram_addr2 |  SP2   |    DP2     |

 
## BRAM安排
仿真过程一共扩展5片BRAM
SP_RAM，DP_RAM,HASH_buffer1,HASH_buffer2,INSTR_ROM
## SHAKE模块访存安排
**shakemode**: 0 for 128/1 for 256
整个过程中所有需要调用shake算法的位置
|    环节 |            描述            | seed          |   output   |
| ------: | :------------------------: | ------------- | :--------: |
| key_gen |     用随机数z产生seedA     | sp_ram        |   sp_ram   |
| key_gen |    用seedA采样得到A矩阵    | sp_ram        | A的采样器  |
| key_gen |     用seedSE采样得到SE     | sp_ram        | SE的采样器 |
| key_gen |       用B矩阵产生pkh       | sp_ram        |   sp_ram   |
|   encap | 用pkh,u,salt产生新的seedSE | sp_ram        |   sp_ram   |
|   encap |    用seedSE采样得到SEE     | sp_ram        | SE的采样器 |
|   encap |    用seedA采样得到A矩阵    | sp_ram        | A的采样器  |
|   encap |     用B,C,salt,k产生SS     | sp_ram,dp_ram |   sp_ram   |
|   decap | 用pkh,u,salt产生新的seedSE | sp_ram        |   sp_ram   |
|   decap |    用seedSE采样得到SEE     | sp_ram        | SE的采样器 |
|   decap |    用seedA采样得到A矩阵    | sp_ram        | A的采样器  |
|   decap |     用B,C,salt,k产生SS     | sp_ram,dp_ram |   sp_ram   |

### sp-RAM 内存分布表 (32-bit x2)

| 变量名 | 起始地址 (addr) | 长度 (Size/Depth) | 结束地址 (exclusive) |
| :--- | :---: | :---: | :---: |
| **S** | 0 | 1344 | 1344 |
| **E** | 1344 | 2688 | 4032 |
| **pkh** | 4032 | 4 | 4036 |
| **u** | 4036 | 4 | 4040 |
| **salt** | 4040 | 8 | 4048 |
| **seed<sub>SE</sub>** | 4048 | 8 | 4056 |
| **k** | 4056 | 4 | 4060 |
| **s** | 4060 | 4 | 4064 |
| **z** | 4064 | 2 | 4066 |
| **ss** | 4066 | 4 | 4070 |

**总深度 (Total Depth): 4070**

 cmp -l -n 10752 ./output/Bout.bin  ./py/ref_matrix_ST_8bit.bin | awk '{printf "Offset: 0x%04X | A: %3d | B: %3d\n", $1-1, strtonum("0"$2), strtonum("0"$3)}
