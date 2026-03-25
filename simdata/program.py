from face_lib import FaceLib

def generate_decap_c_minus_bs(
    bprime_base=10752,
    s_base=0,
    c_base=32256,
    m_base=32384,
    matrix_size=336,
):
    face = FaceLib()

    face.comment("Decap c-BS: M = C - B'S")

    for row_blk in range(2):
        for col_blk in range(2):
            left_addr = bprime_base + row_blk * 10752
            right_addr = s_base + col_blk * 5376
            addsrc_addr = c_base + row_blk * 64 + col_blk * 8
            save_addr = m_base + row_blk * 64 + col_blk * 8

            face.systolic_addrset(left_addr, 0)
            face.systolic_addrset(right_addr, 1)
            face.systolic_addrset(addsrc_addr, 2)
            face.systolic_addrset(save_addr, 3)

            face.systolic_calc(matrix_size, 2, 1, 0, 0, 1)

    face.save("simdata/test.asm")
    
def generate_encap():
    face = FaceLib()
    face.shake_seedaddrset(1, 32256)
    face.shake_seedset(128, 1) 
    face.shake_absorb(0, 1)
    
    for i in range(12):
        face.shake_dumpaword(i, 32384 + i*8)
    
    
    face.shake_seedaddrset(1,32384)
    face.shake_absorb_genA(0,8,0,1)
    esign = 0
    addri = 0
    addrj = 0
    for i in range (318):
        addrj = 0
        for j in range(17):
            face.shake_gen_se(2, j, 1, esign ,(0 +addri + addrj)>>2)
            if i == 158 and j == 1:
                esign = 1
            addrj += 4 if esign == 0 else 8
            if i == 317 and j == 2:
                break
        face.shake_squeezeonce()
        addri += addrj
    
    linenum = 0    
    face.shake_seedaddrset(0,32512)
    face.shake_gen_a(2, 0, linenum)
        
    block = 0
    pack = 0
    for block in range (336):
        if block ==335:
            pack = 1
        face.shake_seedaddrset(0,32512)
        face.shake_gen_a(2, 0, block * 4)
        face.systolic_bufswap()

        face.systolic_addrset(0 + block * 4, 0)
        face.systolic_addrset(0, 1)
        face.systolic_addrset(10752, 2)
        face.systolic_addrset(10752, 3)
        face.systolic_calc(336, 3 ,0 ,pack ,0)

        face.systolic_addrset(5376 + block * 4, 0)
        face.systolic_addrset(0, 1)
        face.systolic_addrset(21504, 2)
        face.systolic_addrset(21504, 3)
        face.systolic_calc(336, 3 ,0 ,pack ,0)
    face.systolic_bufswap()
    # V = S'B + E'' : 4x4 systolic block, use 4 instructions to cover full 8x8 V
    for row_blk in range(2):
        for col_blk in range(2):
            left_addr = row_blk * 5376
            right_addr = 10752 + col_blk * 8
            save_addr = 32256 + row_blk * 64 + col_blk * 8

            face.systolic_addrset(left_addr, 0)
            face.systolic_addrset(right_addr, 1)
            face.systolic_addrset(save_addr, 2)
            face.systolic_addrset(save_addr, 3)
            face.systolic_calc(336, 1, 0, 0, 1)
    
    # C = V + encode(u)
    face.frodo_v_encodeu_add()
    face.systolic_bufswap()
    # ss = SHAKE256(Pack(B') || Pack(C) || salt || k)
    # B' : 21504 bytes @ dp[10752]
    # C  :   128 bytes @ dp[32256]，与 B' 连续
    # salt:   64 bytes @ 4040*8
    # k   :   32 bytes @ 4056*8
    # total: 21728 bytes = 160 blocks * 136, last_block_bytes = 104
    face.shake_seedaddrset(1, 10752, 1)
    face.shake_seedset(104, 160)

    face.shake_absorb(1, 159)

    face.shake_seedaddrset(1, 4040 * 8, 0)
    face.shake_absorb(9, 0)

    face.shake_seedaddrset(1, 4056 * 8, 0)
    face.shake_absorb(0, 1)

    for i in range(4):
        face.shake_dumpaword(i, 4066 * 8 + i * 8)
    face.test_print_simtime()
    face.save("simdata/test.asm")
    
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

    for block in range(0,336):
        ##生成A矩阵的四行
        face.shake_seedaddrset(0,32512)
        face.shake_gen_a(2, 0, block * 4)
        face.systolic_bufswap()
        ##脉动阵列计算
        face.systolic_addrset(0, 0)
        face.systolic_addrset(0, 1)
        face.systolic_addrset(10752 + 64 * block, 2)
        face.systolic_addrset(10752 + 64 * block, 3)
        face.systolic_calc(336, 0, 0, 1, 0)
        
        face.systolic_addrset(0, 0)
        face.systolic_addrset(5376, 1)
        face.systolic_addrset(10760 + 64 * block, 2)
        face.systolic_addrset(10760 + 64 * block, 3)
        face.systolic_calc(336, 0, 0, 1, 0)

    # 生成pkh = SHAKE256(seedA || Pack(B))
    # seedA: 16字节(2字) @ 32512, B: 21504字节(2688字) @ 10752
    # 合计21520字节, 159块, last_block_bytes=32
    face.systolic_bufswap()
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
    face.test_print_simtime()
    face.save("simdata/test.asm")
def specialinput():
    face = FaceLib()
    face.save("simdata/test.asm")
if __name__ == "__main__":
    # generate_decap_c_minus_bs()
    #  generate_keygen()
     generate_encap()
    # specialinput()