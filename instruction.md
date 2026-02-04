## 内存摆放
|S|E|pkh|u|salt|seed_se|k|s|z|ss|
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | 
|0|1344  |4032|4036|4040|4048|4056|4060|4064|4066|

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
| function | instruction[31:0] | FUNC |
| :--- | ---: | :--- |
| systolic_addrset | `[31:12]BASE_ADDR` `[11:10]SETTAR` `[9:7]FUNC` `[6:0]OPCODE` | 0 |
| systolic_calc | `[22:12]MATRIX_SIZE` `[11:10]ctrl_mode` `[9:7]FUNC` `[6:0]OPCODE` | 1 |
| SHAKE_seedaddrset | `[25]shakemode` `[24:10]start_addr`  `[9:7]FUNC` `[6:0]OPCODE` | 0 |
| SHAKE_seedset | `[25:18]last_block_bytes` `[17:10]absorb_num`  `[9:7]FUNC` `[6:0]OPCODE` | 1 |
| SHAKE_squeezeonce |    `[9:7]FUNC` `[6:0]OPCODE` | 2 |
| SHAKE_dumponce |  `[25]bram_id` `[24:10]start_addr`  `[9:7]FUNC` `[6:0]OPCODE` | 3 |

### SETAR对应寄存器:
| SETTAR | meaning |
| :--- | :--- |
| 0 |BASE_ADDR_LEFT|
| 1 |BASE_ADDR_RIGHT|
| 2 |BASE_ADDR_ADDSRC|
| 3 |BASE_ADDR_SAVE|
## systolic模块访存安排
| 计算阶段         | 计算模式 | 左算子来源    | 右算子来源    | 输出累加源   | 输出位置   | 编号  |
| ------------ | ---- | -------- | -------- | ------- | ------ | --- |
| $AS$         | 左A时序 | A_buffer | sp-ram   | sp-ram  | sp-ram | 00  |
| $S^\prime B$ | 左A时序 | dp-ram   | sp-ram   | dp-ram  | dp-ram | 01  |
| $B^\prime S$ | 左A时序 | dp-ram   | sp-ram   | dp-ram1 | dp-ram | 10  |
| $S^\prime A$ | 右A时序 | dp-ram   | A_buffer | dp-ram  | dp-ram | 11  |

## SHAKE模块访存安排
**shakemode**: 0 for 128/1 for 256