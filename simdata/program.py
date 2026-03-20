from face_lib import FaceLib

def generate_keygen():
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
            ##生成A矩阵的四行
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
    face.test_print_simtime()
    # C = V + encode(u)
    face.frodo_v_encodeu_add()

    # ss = SHAKE256(Pack(B') || Pack(C) || salt || k)
    # B' : 21504 bytes @ 10752
    # C  :   128 bytes @ 32256
    # salt:   64 bytes @ 4040*8
    # k   :   32 bytes @ 4056*8
    # total: 21728 bytes = 160 blocks * 136, last_block_bytes = 104
    face.shake_seedaddrset(1, 10752)
    face.shake_seedset(104, 160)

    # segment-1: Pack(B') = 158 full blocks + 16 bytes
    face.shake_absorb(2, 158)

    # segment-2: Pack(C) = 128 bytes
    face.shake_seedaddrset(1, 32256)
    face.shake_absorb(16, 0)

    # segment-3: salt = 64 bytes
    face.shake_seedaddrset(1, 4040 * 8)
    face.shake_absorb(8, 0)

    # segment-4: k = 32 bytes
    face.shake_seedaddrset(1, 4056 * 8)
    face.shake_absorb(4, 0)

    # dump ss (256-bit)
    for i in range(4):
        face.shake_dumpaword(i, 4066 * 8 + i * 8)

    face.save("simdata/test.asm")

if __name__ == "__main__":
    generate_keygen()
