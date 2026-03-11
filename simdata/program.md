## AStest
systolic_addrset 0,0
systolic_addrset 0,1
systolic_addrset 10752,2
systolic_addrset 10752,3
systolic_calc 336,0

systolic_addrset 0,0
systolic_addrset 5376,1
systolic_addrset 10760,2
systolic_addrset 10760,3
systolic_calc 336,0

## SAtest
systolic_addrset 0,0
systolic_addrset 0,1
systolic_addrset 10752,2
systolic_addrset 10752,3
systolic_calc 336,3
nop

systolic_addrset 5376,0
systolic_addrset 0,1
systolic_addrset 21504,2
systolic_addrset 21504,3
systolic_calc 336,3
nop

## shake base
SHAKE_seedaddrset 0, 0x2000
SHAKE_seedset 1,1
SHAKE_dumponce 0, 10752
SHAKE_squeezeonce
SHAKE_dumponce 0, 10920
NOP
NOP
NOP


## 采样测试
SHAKE_seedaddrset 0,1
SHAKE_absorb_genA 0x96
SHAKE_gen_A 2, 0, 0x0
SHAKE_gen_A 2, 1, 0x8
SHAKE_gen_SE 2, 0, 0, 10920
SHAKE_dumponce 0, 10752
NOP

## keygen测试
SHAKE_seedaddrset 1,32512
SHAKE_seedset 16,1
SHAKE_dumpaword 0, 32512
SHAKE_dumpaword 1, 32520

SHAKE_seedaddrset 0,32512
SHAKE_absorb_genA 0x0
SHAKE_gen_A 2, 0, 0x0