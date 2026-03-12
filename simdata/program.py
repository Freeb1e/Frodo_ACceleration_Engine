from face_lib import FaceLib

def generate_keygen():
    face = FaceLib()

    face.comment("Frodo KeyGen Simulation")
    
    # face.shake_seedaddrset(1,32512)
    # face.shake_seedset(16, 1)
    # face.shake_dumpaword(0,32512)
    # face.shake_dumpaword(1,32520)
    
    # face.shake_seedaddrset(0,32512)
    # linenum = 0;
    # for i in range(1):
    #     face.comment(f"Round {i}")
    #     face.shake_absorb_genA(1,2,linenum + i)
    #     for j in range(16):
    #         for k in range(21):
    #             face.shake_gen_a(2, k,1344*2*i + 168 * j + 8 * k)
    #         face.shake_squeezeonce()
    
    face.shake_seedaddrset(1,32384)
    face.shake_absorb_genA(0,8,0)
    # for i in range(16):
    #     for j in range(21):
    #         face.shake_gen_se(2, j, 0, 10752 + 1344*i + 8 * 4 * j)
    #     face.shake_squeezeonce()
    face.shake_gen_se(2, 0, 0, 10752)
    face.shake_gen_se(2, 1, 0, 10752+32)
    face.shake_gen_se(2, 2, 0, 10752+64)
    face.shake_gen_se(2, 3, 0, 10752+96)
    face.shake_gen_se(2, 4, 0, 10752+128)
    face.shake_gen_se(2, 5, 0, 10752+160)
    face.save("simdata/test.asm")

if __name__ == "__main__":
    generate_keygen()
