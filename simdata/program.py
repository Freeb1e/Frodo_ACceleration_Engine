from face_lib import FaceLib

def generate_keygen():
    face = FaceLib()

    face.comment("Frodo KeyGen Simulation")
    ## 生成AseedA
    face.shake_seedaddrset(1,32512)
    face.shake_seedset(16, 1)
    face.shake_dumpaword(0,32512)
    face.shake_dumpaword(1,32520)
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
    face.systolic_calc(336, 0)
    
    face.systolic_addrset(0, 0)
    face.systolic_addrset(5376, 1)
    face.systolic_addrset(10760,2)
    face.systolic_addrset(10760,3)
    face.systolic_calc(336, 0)
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
        face.systolic_calc(336, 0)
        
        face.systolic_addrset(0, 0)
        face.systolic_addrset(5376, 1)
        face.systolic_addrset(10760 + 64 * block, 2)
        face.systolic_addrset(10760 + 64 * block, 3)
        face.systolic_calc(336, 0)
    face.save("simdata/test.asm")

if __name__ == "__main__":
    generate_keygen()
