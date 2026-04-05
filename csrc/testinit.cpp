#include "memory.h"
#include "testinit.h"
#include <cstdio>
#include <iostream>
#include "stdlib.h"
#include <fstream>
#include <cctype>
#include <vector>
#include "config.h"
const char* test_file= nullptr;
const char* dump_file= nullptr;

namespace {

int hex_nibble(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

bool parse_hex_to_bytes(const char* tag, const char* hex, std::vector<uint8_t>& out) {
    out.clear();
    int hi = -1;
    for (const char* p = hex; *p != '\0'; ++p) {
        const int n = hex_nibble(*p);
        if (n < 0) {
            continue;
        }
        if (hi < 0) {
            hi = n;
        } else {
            out.push_back((uint8_t)((hi << 4) | n));
            hi = -1;
        }
    }
    if (hi >= 0) {
        printf("[INIT Error] %s hex has odd digit count\n", tag);
        return false;
    }
    return true;
}

bool write_bytes_segment_to_sp_ram(const char* tag,
                                   const std::vector<uint8_t>& src,
                                   uint32_t src_offset,
                                   uint32_t seg_len,
                                   uint32_t base_addr) {
    if (seg_len == 0) {
        return true;
    }
    if (base_addr >= RAM_SIZE || base_addr + seg_len > RAM_SIZE) {
        printf("[INIT Error] %s address range out of SP_RAM: [0x%X, len=%u]\n",
               tag, base_addr, seg_len);
        return false;
    }
    if ((uint64_t)src_offset + (uint64_t)seg_len > (uint64_t)src.size()) {
        printf("[INIT Error] %s source slice overflow: off=%u len=%u src_size=%zu\n",
               tag, src_offset, seg_len, src.size());
        return false;
    }

    for (uint32_t i = 0; i < seg_len; ++i) {
        sp_ram[base_addr + i] = src[src_offset + i];
    }

    printf("[INIT Info] Loaded %s at SP_RAM[0x%X], len=%u bytes\n", tag, base_addr, seg_len);
    return true;
}

} // namespace
void init_SA_test()
{
    test_file = "./simdata/raminit/SAtest/A_full.bin";
    if(load_bin_to_ram_protect(test_file, A_buffer_1, BUFFER_SIZE, 0))
    {
        printf("Loaded test data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load test data into HASH RAM.\n");
    }
    test_file = "./simdata/raminit/SAtest/S_tr.bin";
    if(load_bin_to_ram(test_file, dp_ram, RAM_SIZE, 0))
    {
        printf("Loaded S data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load S data into HASH RAM.\n");
    }
    test_file = "./simdata/raminit/SAtest/B_matrix0.bin";
    if(load_bin_to_ram_protect(test_file, dp_ram, RAM_SIZE, 1344*8))
    {
        printf("Loaded B matrix 0 data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load B matrix 0 data into HASH RAM.\n");
    }
}

void init_AS_test()
{
    test_file = "./simdata/raminit/AStest/A_buffer.bin";
    if(load_bin_to_ram_protect(test_file, A_buffer_1, BUFFER_SIZE, 0))
    {
        printf("Loaded test data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load test data into HASH RAM.\n");
    }
    test_file = "./simdata/raminit/AStest/S.bin";
    if(load_bin_to_ram(test_file, sp_ram, RAM_SIZE, 0))
    {
        printf("Loaded S data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load S data into HASH RAM.\n");
    }
    test_file = "./simdata/raminit/AStest/B_matrix.bin";
    if(load_bin_to_ram_protect(test_file, sp_ram, RAM_SIZE, 1344*8))
    {
        printf("Loaded B matrix 0 data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load B matrix 0 data into HASH RAM.\n");
    }
}

void init_seedram(int mode) {
    const char* seed_filename = "./simdata/raminit/seedram.bin";

    // 1. 打开文件获取长度
    std::ifstream file(seed_filename, std::ios::binary | std::ios::ate); // ate = at end (打开直接定位到文件尾)
    if (!file.good()) {
        std::cerr << "File not found: " << seed_filename << std::endl;
        exit(EXIT_FAILURE);
    }
    
    std::streamsize file_size = file.tellg(); // 获取当前指针位置（即文件大小）
    file.close(); // 关闭文件，交给 load_bin_to_ram 重新打开

    // 2. 载入文件
    if (!load_bin_to_ram(seed_filename,sp_ram, RAM_SIZE, 0)) {
        std::cerr << "Failed to load seed data" << std::endl;
        exit(EXIT_FAILURE);
    }

    std::cout << "Loaded " << file_size << " bytes from " << seed_filename << std::endl;

    uint32_t lenth = (uint32_t) file_size;
    uint32_t ONCE_LENTH = (mode)? 136 :168;
    uint32_t times = lenth / ONCE_LENTH + 1;
    uint32_t last_lenth = lenth % ONCE_LENTH;
    std::cout << "Total absorb times: " << times << ", Last length: " << last_lenth << std::endl;
    // dut->absorb_num = times;
    // dut->last_block_bytes = last_lenth;
}
//void pmem_write(int waddr, int bramid, long long wdata, char wmask) 
void Keygen_init(){
    std::vector<uint8_t> keygen_random;
    if (!parse_hex_to_bytes("KeyGen randomness", KEYGEN_RANDOM_HEX, keygen_random)) {
        printf("[INIT Error] Keygen_init randomness parse failed.\n");
        exit(EXIT_FAILURE);
    }
    if (KEYGEN_RANDOM_LEN != 0 && keygen_random.size() != KEYGEN_RANDOM_LEN) {
        printf("[INIT Error] KeyGen randomness length mismatch, got %zu bytes, expected %u bytes\n",
               keygen_random.size(), (uint32_t)KEYGEN_RANDOM_LEN);
        exit(EXIT_FAILURE);
    }

    uint32_t off = 0;
    if (!write_bytes_segment_to_sp_ram("KeyGen s", keygen_random, off, KEYGEN_S_LEN, KEYGEN_S_ADDR)) {
        printf("[INIT Error] Keygen_init s injection failed.\n");
        exit(EXIT_FAILURE);
    }
    off += KEYGEN_S_LEN;

    if (!write_bytes_segment_to_sp_ram("KeyGen seedSE", keygen_random, off, KEYGEN_SEEDSE_LEN, KEYGEN_SEEDSE_ADDR)) {
        printf("[INIT Error] Keygen_init seedSE injection failed.\n");
        exit(EXIT_FAILURE);
    }
    off += KEYGEN_SEEDSE_LEN;

    if (!write_bytes_segment_to_sp_ram("KeyGen z", keygen_random, off, KEYGEN_Z_LEN, KEYGEN_Z_ADDR)) {
        printf("[INIT Error] Keygen_init z injection failed.\n");
        exit(EXIT_FAILURE);
    }
    off += KEYGEN_Z_LEN;

    if (off != keygen_random.size()) {
        printf("[INIT Warning] KeyGen randomness has %zu bytes, but segment map consumes %u bytes.\n",
               keygen_random.size(), off);
    }

}
void Encap_init(){
    test_file = "./simdata/raminit/keygendone.bin";
    if(load_bin_to_ram(test_file, sp_ram, RAM_SIZE, 0))
    {
        printf("Loaded %s into SP_RAM successfully.\n", test_file);
    }
    else
    {
        printf("Failed to load %s into SP_RAM.\n", test_file);
    }
    std::vector<uint8_t> encap_random;
    if (!parse_hex_to_bytes("Encap randomness", ENCAP_RANDOM_HEX, encap_random)) {
        printf("[INIT Error] Encap_init randomness parse failed.\n");
        exit(EXIT_FAILURE);
    }
    if (ENCAP_RANDOM_LEN != 0 && encap_random.size() != ENCAP_RANDOM_LEN) {
        printf("[INIT Error] Encap randomness length mismatch, got %zu bytes, expected %u bytes\n",
               encap_random.size(), (uint32_t)ENCAP_RANDOM_LEN);
        exit(EXIT_FAILURE);
    }

    uint32_t off = 0;
    if (!write_bytes_segment_to_sp_ram("Encap mu", encap_random, off, ENCAP_MU_LEN, ENCAP_MU_ADDR)) {
        printf("[INIT Error] Encap_init mu injection failed.\n");
        exit(EXIT_FAILURE);
    }
    off += ENCAP_MU_LEN;

    if (!write_bytes_segment_to_sp_ram("Encap salt", encap_random, off, ENCAP_SALT_LEN, ENCAP_SALT_ADDR)) {
        printf("[INIT Error] Encap_init salt injection failed.\n");
        exit(EXIT_FAILURE);
    }
    off += ENCAP_SALT_LEN;

    if (off != encap_random.size()) {
        printf("[INIT Warning] Encap randomness has %zu bytes, but segment map consumes %u bytes.\n",
               encap_random.size(), off);
    }

}

void Encapss_init(){
    test_file = "./simdata/raminit/SP_RAM_encap.bin";
    if(load_bin_to_ram(test_file, sp_ram, RAM_SIZE, 0))
    {
        printf("Loaded %s into SP_RAM successfully.\n", test_file);
    }
    else
    {
        printf("Failed to load %s into SP_RAM.\n", test_file);
    }
    test_file = "./simdata/raminit/DP_RAM_encap.bin";
    if(load_bin_to_ram(test_file, dp_ram, RAM_SIZE, 0))
    {
        printf("Loaded %s into DP_RAM successfully.\n", test_file);
    }
    else
    {
        printf("Failed to load %s into DP_RAM.\n", test_file);
    }

}

void decap_init(){
    test_file = "./simdata/raminit/SP_RAM_encapdone.bin";
    if(load_bin_to_ram(test_file, sp_ram, RAM_SIZE, 0))
    {
        printf("Loaded %s into SP_RAM successfully.\n", test_file);
    }
    else
    {
        printf("Failed to load %s into SP_RAM.\n", test_file);
    }
    test_file = "./simdata/raminit/DP_RAM_encapdone.bin";
    if(load_bin_to_ram(test_file, dp_ram, RAM_SIZE, 0))
    {
        printf("Loaded %s into DP_RAM successfully.\n", test_file);
    }
    else
    {
        printf("Failed to load %s into DP_RAM.\n", test_file);
    }
}

void Encap_init_976(){
    test_file = "./simdata/raminit/keygen976.bin";
    if(load_bin_to_ram(test_file, sp_ram, RAM_SIZE, 0))
    {
        printf("Loaded %s into SP_RAM successfully.\n", test_file);
    }
    else
    {
        printf("Failed to load %s into SP_RAM.\n", test_file);
    }
    std::vector<uint8_t> encap_random;
    if (!parse_hex_to_bytes("Encap randomness", ENCAP_RANDOM_HEX, encap_random)) {
        printf("[INIT Error] Encap_init randomness parse failed.\n");
        exit(EXIT_FAILURE);
    }
    if (ENCAP_RANDOM_LEN != 0 && encap_random.size() != ENCAP_RANDOM_LEN) {
        printf("[INIT Error] Encap randomness length mismatch, got %zu bytes, expected %u bytes\n",
               encap_random.size(), (uint32_t)ENCAP_RANDOM_LEN);
        exit(EXIT_FAILURE);
    }
    for (int i = 0; i < 9; ++i) {
        pmem_write(32280 + i * 8, 0, 0x4242424242424242, 0xFF); // mu
    }
}

void init_instram(){
    bool load_bin_to_ram(const char* filename, uint8_t* ram_ptr, uint32_t max_size, uint32_t offset);
    load_bin_to_ram("./simdata/firmware.bin",PC_ROM,PC_ROM_SIZE, 0);
}
