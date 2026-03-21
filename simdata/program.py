from face_lib import FaceLib

def generate_decap_c_minus_bs(
    bprime_base=10752,
    s_base=0,
    c_base=32256,
    m_base=32384,
    matrix_size=336,
):
    """Generate decap c-BS step: M = C - B'S.

    Address unit is byte address, same as existing systolic_addrset usage.
    Defaults follow current project layout:
    - B' in DP_RAM @ 10752
    - S  in SP_RAM @ 0
    - C  in DP_RAM @ 32256
    - M  in DP_RAM @ 32384 (separate from C to avoid overwrite)
    """
    face = FaceLib()

    # face.comment("Decap c-BS: M = C - B'S")

    # 8x8 output is computed as four 4x4 systolic tiles.
    for row_blk in range(2):
        for col_blk in range(2):
            # BS mode left operand is B' (16-bit), row block stride is 4*1344*2 = 10752 bytes.
            left_addr = bprime_base + row_blk * 10752

            # S is stored column-priority like AS path; col block stride is 1344*4 = 5376 bytes.
            right_addr = s_base + col_blk * 5376

            # C / M are 8x8x16-bit matrices: each 4-row block is 64 bytes, each col block is 8 bytes.
            addsrc_addr = c_base + row_blk * 64 + col_blk * 8
            save_addr = m_base + row_blk * 64 + col_blk * 8

            face.systolic_addrset(left_addr, 0)
            face.systolic_addrset(right_addr, 1)
            face.systolic_addrset(addsrc_addr, 2)
            face.systolic_addrset(save_addr, 3)

            # ctrl_mode=2 => BS, and final AS_SAVE stage performs C - (B'S) in hardware adder.
            face.systolic_calc(matrix_size, 2, 1, 0, 0, 1)

    face.save("simdata/test.asm")

if __name__ == "__main__":
    generate_decap_c_minus_bs()