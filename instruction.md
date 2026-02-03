## 指令安排
| function | instruction[31:0] | FUNC |
| :--- | ---: | :--- |
| systolic_addrset | `[31:12]BASE_ADDR` `[11:10]SETTAR` `[9:7]FUNC` `[6:0]OPCODE` | 0 |
| systolic_calc | `[22:12]MATRIX_SIZE` `[11:10]ctrl_mode` `[9:7]FUNC` `[6:0]OPCODE` | 1 |

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