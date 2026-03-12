from face_lib import FaceLib

def generate_keygen():
    face = FaceLib()

    face.comment("Frodo KeyGen Simulation")
    
    face.shake_seedaddrset(1,32512)
    face.shake_seedset(16, 1)
    face.shake_dumpaword(0,32512)
    face.shake_dumpaword(1,32520)
    
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
    face.shake_seedaddrset(1,32384)
    face.shake_absorb_genA(0,8,0)
    for i in range (317):
        for j in range(17):
            face.shake_gen_se(2, j, 0, (0 +68 *i + 4 * j)>>1)
            if i == 316 and j == 3:
                break
        face.shake_squeezeonce()
    
    face.systolic_addrset(0, 0)
    face.systolic_addrset(0, 1)
    face.systolic_addrset(10752, 2)
    face.systolic_addrset(10752, 3)
    face.systolic_calc(336, 0)
    
    # face.shake_gen_se(2, 0, 0, (10752)>>1)
    # face.shake_gen_se(2, 1, 0, (10752+4)>>1)
    #face.shake_gen_se(2, 1, 0, 10752+4)
    #face.shake_gen_se(2, 1, 0, 10752+8)
    face.save("simdata/test.asm")

if __name__ == "__main__":
    generate_keygen()
