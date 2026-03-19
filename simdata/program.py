from face_lib import FaceLib

def generate_keygen():
    face = FaceLib()

    face.comment("Frodo KeyGen Simulation")
    ## 生成AseedA：吸收256位随机数，SHAKE256
    face.shake_seedaddrset(1, 32512)       # SHAKE256, 数据源地址
    face.shake_seedset(16, 1)              # last_block_bytes=32, absorb_num=1, 重置keccak
    face.shake_absorb(0, 1)                # 触发吸收：1个完整块，无半块（padding自动处理）
    face.shake_dumpaword(0, 32512)         # 挤出 word0 → addr 32512
    face.shake_dumpaword(1, 32520)         # 挤出 word1 → addr 32520
  
  
    ##生成S/E矩阵
    face.shake_seedaddrset(1,32384)
    face.shake_absorb_genA(0,8,0)
    esign = 0
    addri = 0
    addrj = 0
    for i in range (317):
        addrj = 0
        for j in range(17):
            face.shake_gen_se(2, j, 0, esign ,(0 +addri + addrj)>>2)
            if i == 158 and j == 1:
                esign = 1
            addrj += 4 if esign == 0 else 8
            if i == 316 and j == 3:
                break
        face.shake_squeezeonce()
        addri += addrj


    ##生成A矩阵的四行
    face.shake_seedaddrset(0,32512)
    linenum = 0;
    for i in range(4):
        face.comment(f"Round {i}")
        face.shake_absorb_genA(1,2,linenum + i)
        for j in range(16):
            for k in range(21):
                face.shake_gen_a(2, k,1344*2*i + 168 * j + 8 * k)
            face.shake_squeezeonce()
    face.systolic_bufswap()
    face.systolic_addrset(0, 0)
    face.systolic_addrset(0, 1)
    face.systolic_addrset(10752,2)
    face.systolic_addrset(10752,3)
    face.systolic_calc(336, 0,0,1)
    
    face.systolic_addrset(0, 0)
    face.systolic_addrset(5376, 1)
    face.systolic_addrset(10760,2)
    face.systolic_addrset(10760,3)
    face.systolic_calc(336, 0,0,1)
    face.shake_seedaddrset(0,32512)
    face.comment("GENA2")
    for block in range(1,336):
        ##生成A矩阵的四行
        face.shake_seedaddrset(0,32512)
        for i in range(4):
            face.comment(f"Round {i}")
            face.shake_absorb_genA(1,2,block *4 + i)
            for j in range(16):
                for k in range(21):
                    face.shake_gen_a(2, k,1344*2*i + 168 * j + 8 * k)
                face.shake_squeezeonce()
        face.systolic_bufswap()
        ##脉动阵列计算
        face.systolic_addrset(0, 0)
        face.systolic_addrset(0, 1)
        face.systolic_addrset(10752 + 64 * block, 2)
        face.systolic_addrset(10752 + 64 * block, 3)
        face.systolic_calc(336, 0,0,1)
        
        face.systolic_addrset(0, 0)
        face.systolic_addrset(5376, 1)
        face.systolic_addrset(10760 + 64 * block, 2)
        face.systolic_addrset(10760 + 64 * block, 3)
        face.systolic_calc(336, 0,0,1)

    # 生成pkh = SHAKE256(seedA || Pack(B))
    # seedA: 16字节(2字) @ 32512, B: 21504字节(2688字) @ 10752
    # 合计21520字节, 159块, last_block_bytes=32
    face.comment("Generate pkh = SHAKE256(seedA || B)")
    face.shake_seedaddrset(1, 32512)       # SHAKE256, seedA地址
    face.shake_seedset(32, 159)            # absorb_num=159, last_block_bytes=32
    face.shake_absorb(2, 0)               # 从seedA读2字(半块)，暂停
    face.shake_seedaddrset(1, 10752)       # 切换到B矩阵地址
    face.shake_absorb(0, 159)             # 补齐第1块+剩余158块，共159次置换
    face.shake_dumpaword(0, 4032*8)        # pkh word0
    face.shake_dumpaword(1, 4032*8+8)      # pkh word1
    face.shake_dumpaword(2, 4032*8+16)     # pkh word2
    face.shake_dumpaword(3, 4032*8+24)     # pkh word3

    face.save("simdata/test.asm")

if __name__ == "__main__":
    generate_keygen()
