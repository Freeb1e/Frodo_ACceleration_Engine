import os

def keccak_f1600(state):
    """Keccak-f[1600] permutation (24 rounds)"""
    # Round constants
    RC = [
        0x0000000000000001, 0x0000000000008082, 0x800000000000808a,
        0x8000000080008000, 0x000000000000808b, 0x0000000080000001,
        0x8000000080008081, 0x8000000000008009, 0x000000000000008a,
        0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
        0x000000008000808b, 0x800000000000008b, 0x8000000000008089,
        0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
        0x000000000000800a, 0x800000008000000a, 0x8000000080008081,
        0x8000000000008080, 0x0000000080000001, 0x8000000080008008
    ]

    def ROL64(a, n):
        return ((a << (n % 64)) & 0xFFFFFFFFFFFFFFFF) | (a >> (64 - (n % 64)))

    # Convert state to 5x5 64-bit words
    A = [[0] * 5 for _ in range(5)]
    for x in range(5):
        for y in range(5):
            idx = (x + 5 * y) * 8
            A[x][y] = int.from_bytes(state[idx:idx+8], 'little')

    for round_idx in range(24):
        # Theta
        C = [A[x][0] ^ A[x][1] ^ A[x][2] ^ A[x][3] ^ A[x][4] for x in range(5)]
        D = [C[(x-1)%5] ^ ROL64(C[(x+1)%5], 1) for x in range(5)]
        for x in range(5):
            for y in range(5):
                A[x][y] ^= D[x]

        # Rho & Pi
        B = [[0] * 5 for _ in range(5)]
        x, y = 1, 0
        for t in range(24):
            B[y][(2*x+3*y)%5] = ROL64(A[x][y], ((t+1)*(t+2)//2) % 64)
            x, y = y, (2*x+3*y)%5
        B[0][0] = A[0][0]

        # Chi
        for y in range(5):
            row = [B[x][y] for x in range(5)]
            for x in range(5):
                A[x][y] = row[x] ^ ((~row[(x+1)%5]) & row[(x+2)%5])

        # Iota
        A[0][0] ^= RC[round_idx]

    # Convert back to bytes
    res = bytearray(200)
    for x in range(5):
        for y in range(5):
            idx = (x + 5 * y) * 8
            res[idx:idx+8] = A[x][y].to_bytes(8, 'little')
    return res

def run_shake256_simulation(input_file):
    # Rate for SHAKE256 is 1088 bits = 136 bytes
    r = 136
    
    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found.")
        return

    with open(input_file, 'r') as f:
        hex_data = "".join(f.read().split())
    
    msg = bytearray.fromhex(hex_data)
    
    # SHAKE256 Padding: M || 1111 || 10*1
    # For byte-oriented implementation, 1111 suffix is 0x1f if we follow Keccak's bit ordering
    # msg += b'\x1f'
    # while (len(msg) % r) != (r - 1):
    #     msg += b'\x00'
    # msg += b'\x80'
    
    # Standard SHAKE256 padding on byte-aligned message:
    msg.append(0x1f)
    while len(msg) % r != 0:
        if len(msg) % r == r - 1:
            msg.append(0x80)
        else:
            msg.append(0x00)
    
    num_blocks = len(msg) // r
    print(f"Total blocks to absorb: {num_blocks}")
    
    state = bytearray(200) # 1600 bits
    
    for i in range(num_blocks):
        block = msg[i*r : (i+1)*r]
        # Xor block into state
        for j in range(r):
            state[j] ^= block[j]
        
        # Permute
        state = keccak_f1600(state)
        
        # Print state in hex
        print(f"--- Block {i+1} absorbed and permuted ---")
        print(state.hex().upper())
        print("-" * 40)

    # Output final SHAKE256 64-byte hash (first 64 bytes of state)
    print("FINAL SHAKE256 RESULT (64 bytes):")
    print(state[:64].hex().upper())

if __name__ == "__main__":
    input_path = 'py/pk.txt'
    if not os.path.exists(input_path):
        input_path = 'pk.txt'
    
    run_shake256_simulation(input_path)
