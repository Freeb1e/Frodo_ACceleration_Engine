from face_lib import FaceLib

def generate_keygen():
    face = FaceLib()

    face.comment("Frodo KeyGen Simulation")
    
    face.shake_seedaddrset(1,32512)
    face.shake_seedset(16, 1)
    face.shake_dumpaword(0,32512)
    face.shake_dumpaword(0,32520)
    
    face.shake_seedaddrset(0,32512)
    
    face.nop()
    face.save("simdata/test.asm")

if __name__ == "__main__":
    generate_keygen()
