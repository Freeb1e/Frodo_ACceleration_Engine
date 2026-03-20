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
    
    face.systolic_addrset(0, 0)
    face.systolic_addrset(10752, 1)
    face.systolic_addrset(32256, 2)
    face.systolic_addrset(32256, 3)
    face.systolic_calc(336, 1 ,0 ,0 ,1)
    face.save("simdata/test.asm")

if __name__ == "__main__":
    generate_keygen()
