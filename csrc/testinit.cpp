#include "memory.h"
#include "testinit.h"
#include <cstdio>
#include <iostream>
#include "stdlib.h"
#include <fstream>
const char* test_file= nullptr;
const char* dump_file= nullptr;
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
    pmem_write(4064*8, 0, 0x4242424242424242, 0xFF);
    pmem_write(4064*8+8, 0, 0x4242424242424242, 0xFF);
    for(int i=0; i<8; i++){
        pmem_write((4048*8 + i*8), 0, 0x4242424242424242, 0xFF);
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
    for (int i = 0; i < 12; i++) {
        pmem_write((4036*8 + i*8), 0, 0x4242424242424242, 0xFF);
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

void init_instram(){
    bool load_bin_to_ram(const char* filename, uint8_t* ram_ptr, uint32_t max_size, uint32_t offset);
    load_bin_to_ram("./simdata/firmware.bin",PC_ROM,PC_ROM_SIZE, 0);
}
