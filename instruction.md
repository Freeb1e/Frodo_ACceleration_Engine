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
| function          |                                                        instruction[31:0] | FUNC |
| :---------------- | -----------------------------------------------------------------------: | :--- |
| systolic_addrset  |             `[31:12]BASE_ADDR` `[11:10]SETTAR` `[9:7]FUNC` `[6:0]OPCODE` | 0    |
| systolic_calc     |        `[22:12]MATRIX_SIZE` `[11:10]ctrl_mode` `[9:7]FUNC` `[6:0]OPCODE` | 1    |
| SHAKE_seedaddrset |           `[25]shakemode` `[24:10]start_addr`  `[9:7]FUNC` `[6:0]OPCODE` | 0    |
| SHAKE_seedset     | `[25:18]last_block_bytes` `[17:10]absorb_num`  `[9:7]FUNC` `[6:0]OPCODE` | 1    |
| SHAKE_squeezeonce |                                                `[9:7]FUNC` `[6:0]OPCODE` | 2    |
| SHAKE_dumponce    |             `[25]bram_id` `[24:10]start_addr`  `[9:7]FUNC` `[6:0]OPCODE` | 3    |
```
`define SYSOPCODE 7'b1010101
`define SHAOPCODE 7'b1010100

`define systolic_addrset_FUNC 3'b000
`define systolic_calc_FUNC 3'b001

`define SHAKE_seedaddrset_FUNC 3'd0
`define SHAKE_seedset_FUNC 3'd1
`define SHAKE_squeezeonce_FUNC 3'd2
`define SHAKE_dumponce_FUNC 3'd3
```
### SETAR对应寄存器:
| SETTAR | meaning          |
| :----- | :--------------- |
| 0      | BASE_ADDR_LEFT   |
| 1      | BASE_ADDR_RIGHT  |
| 2      | BASE_ADDR_ADDSRC |
| 3      | BASE_ADDR_SAVE   |
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
|    环节 |            描述            | seed   |   output   |
| ------: | :------------------------: | ------ | :--------: |
| key_gen |     用随机数z产生seedA     | sp_ram |   sp_ram   |
| key_gen |    用seedA采样得到A矩阵    | sp_ram | A的采样器  |
| key_gen |     用seedSE采样得到SE     | sp_ram | SE的采样器 |
| key_gen |       用B矩阵产生pkh       | sp_ram |   sp_ram   |
|   encap | 用pkh,u,salt产生新的seedSE | sp_ram |   sp_ram   |
|   encap |    用seedSE采样得到SEE     | sp_ram | SE的采样器 |
|   encap |    用seedA采样得到A矩阵    | sp_ram | A的采样器  |
|   encap |    用B,C,salt,k产生SS  | sp_ram,dp_ram | sp_ram  |
|   decap | 用pkh,u,salt产生新的seedSE | sp_ram |   sp_ram   |
|   decap |    用seedSE采样得到SEE     | sp_ram | SE的采样器 |
|   decap |    用seedA采样得到A矩阵    | sp_ram | A的采样器  |
|   decap |    用B,C,salt,k产生SS  | sp_ram,dp_ram | sp_ram  |

