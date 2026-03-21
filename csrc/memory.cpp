#include "memory.h"
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include "config.h"
//#define DEBUG_MESSAGE
#ifdef DEBUG_MESSAGE
#define MEM_ERR_PRINTF(...) printf(__VA_ARGS__)
#else
#define MEM_ERR_PRINTF(...) ((void)0)
#endif

uint8_t sp_ram[RAM_SIZE] = {0}; // 对应 bramid = 0
uint8_t dp_ram[RAM_SIZE] = {0};            // 对应 bramid = 1
uint8_t A_buffer_1[BUFFER_SIZE] = {0}; //对应 bramid = 2
uint8_t A_buffer_2[BUFFER_SIZE] = {0}; //对应 bramid = 3
uint8_t PC_ROM[PC_ROM_SIZE] = {0};
extern "C" {

static uint8_t* get_ram_info(int bramid, uint32_t* size_out) {
    if (bramid == 0) {
        *size_out = RAM_SIZE;
        return sp_ram;
    } 
    else if (bramid == 1) {
        *size_out = RAM_SIZE;
        return dp_ram;
    } 
    else if (bramid == 2) {
        *size_out = BUFFER_SIZE;
        return A_buffer_1;
    } 
    else if (bramid == 3) {
        *size_out = BUFFER_SIZE;
        return A_buffer_2;
    } else if(bramid==4){
        *size_out = PC_ROM_SIZE;
        return PC_ROM;
    }
    
    *size_out = 0;
    return nullptr;
}

void pmem_read(int raddr, int bramid, long long* rdata) {
    uint32_t max_size = 0;
    uint8_t* mem = get_ram_info(bramid, &max_size);
    uint32_t addr = (uint32_t)raddr>>3;
    addr = addr << 3; // 64-bit aligned
    if (mem == nullptr || (addr + 8 > max_size)) {
        *rdata = 0; 
        MEM_ERR_PRINTF("[DPI Error] Read Out of Bounds! ID=%d, Addr=0x%x\n", bramid, addr);
        return;
    }

    uint64_t val = 0;
    val |= (uint64_t)mem[addr + 0] << 0;
    val |= (uint64_t)mem[addr + 1] << 8;
    val |= (uint64_t)mem[addr + 2] << 16;
    val |= (uint64_t)mem[addr + 3] << 24;
    val |= (uint64_t)mem[addr + 4] << 32;
    val |= (uint64_t)mem[addr + 5] << 40;
    val |= (uint64_t)mem[addr + 6] << 48;
    val |= (uint64_t)mem[addr + 7] << 56;

    *rdata = (long long)val;
}

void pmem_write(int waddr, int bramid, long long wdata, char wmask) {
    uint32_t max_size = 0;
    uint8_t* mem = get_ram_info(bramid, &max_size);
    
    uint32_t addr = (uint32_t)waddr>>3;
    addr = addr << 3; // 64-bit aligned
    uint64_t data = (uint64_t)wdata;
    uint8_t  mask = (uint8_t)wmask;

    if (mem == nullptr || (addr + 8 > max_size)) {
        MEM_ERR_PRINTF("[DPI Error] Write Out of Bounds! ID=%d, Addr=0x%x\n", bramid, addr);
        return;
    }

    for (int i = 0; i < 8; i++) {
        if ((mask >> i) & 1) {
            mem[addr + i] = (uint8_t)((data >> (i * 8)) & 0xFF);
        }
    }
}



} // extern "C"

bool load_bin_to_ram(const char* filename, uint8_t* ram_ptr, uint32_t max_size, uint32_t offset) {
    // 1. 打开文件 (二进制只读模式)
    FILE* fp = fopen(filename, "rb");
    if (fp == nullptr) {
        printf("[DPI Error] Cannot open file: %s\n", filename);
        return false;
    }

    // 2. 获取文件大小
    fseek(fp, 0, SEEK_END);    // 移动到文件末尾
    long file_size = ftell(fp); // 获取当前位置（即文件大小）
    rewind(fp);                // 回到文件开头

    // 3. 越界检查
    // 检查起始偏移是否已经超出了内存范围
    if (offset >= max_size) {
        printf("[DPI Error] Offset 0x%x is out of RAM range (Size: 0x%x)\n", offset, max_size);
        fclose(fp);
        return false;
    }

    // 检查 "偏移 + 文件大小" 是否超出内存范围
    if (offset + file_size > max_size) {
        printf("[DPI Error] File %s is too large! (File: %ld + Offset: %d > RAM: %d)\n", 
               filename, file_size, offset, max_size);
        // 这里可以选择截断读取，或者直接报错退出。
        // 为了安全，建议直接报错。
        fclose(fp);
        return false;
    }

    // 4. 读取数据到指定偏移位置
    // ram_ptr + offset 就是数组中开始写入的地址
    size_t result = fread(ram_ptr + offset, 1, file_size, fp);
    
    if (result != (size_t)file_size) {
        printf("[DPI Error] Reading file failed.\n");
        fclose(fp);
        return false;
    }

    // 5. 收尾
    fclose(fp);
    printf("[DPI Info] Loaded %s to RAM @ Offset 0x%x (Size: %ld bytes)\n", filename, offset, file_size);
    return true;
}


bool dump_ram_to_bin(const char* filename, const uint8_t* ram_ptr, uint32_t max_size, uint32_t start_offset, uint32_t write_len) {
    // 1. 范围检查
    if (start_offset >= max_size) {
        printf("[DPI Error] Dump start offset 0x%x out of range (Size: 0x%x)\n", start_offset, max_size);
        return false;
    }

    // 2. 长度处理
    // 如果 write_len 为 0，或者请求长度超过了剩余空间，则修正为剩余的所有字节
    uint32_t actual_len = write_len;
    if (write_len == 0 || (start_offset + write_len > max_size)) {
        actual_len = max_size - start_offset;
        if (write_len != 0) {
            printf("[DPI Warning] Dump length truncated to 0x%x bytes\n", actual_len);
        }
    }

    // 3. 打开文件 (wb: 二进制写模式)
    FILE* fp = fopen(filename, "wb");
    if (fp == nullptr) {
        printf("[DPI Error] Cannot open file for writing: %s\n", filename);
        return false;
    }

    // 4. 写入文件
    // fwrite 返回成功写入的数据块数量
    size_t written = fwrite(ram_ptr + start_offset, 1, actual_len, fp);
    
    fclose(fp);

    if (written == actual_len) {
        printf("[DPI Info] Dumped RAM to %s (Offset: 0x%x, Len: 0x%x bytes)\n", filename, start_offset, actual_len);
        return true;
    } else {
        printf("[DPI Error] Write failed. Expected 0x%x bytes, wrote 0x%lx bytes\n", actual_len, written);
        return false;
    }
}

bool dump_ram_to_matrix(const char* filename, const uint8_t* ram_ptr, uint32_t max_size, 
                        uint32_t start_offset, uint32_t rows, uint32_t cols) {
    
    // 1. 计算所需数据总量 (每个元素 2 字节)
    uint32_t bytes_per_item = 2;
    uint32_t total_bytes_needed = rows * cols * bytes_per_item;

    // 2. 越界检查
    // 如果 ram_ptr 为空，或者 读取范围超过了 max_size
    if (ram_ptr == nullptr) {
        printf("[DPI Error] RAM pointer is NULL\n");
        return false;
    }
    if (start_offset + total_bytes_needed > max_size) {
        printf("[DPI Error] Dump Matrix out of bounds! Offset:0x%x, Need:%d, Max:%d\n", 
               start_offset, total_bytes_needed, max_size);
        return false;
    }

    // 3. 打开文件
    FILE* fp = fopen(filename, "w");
    if (fp == nullptr) {
        printf("[DPI Error] Cannot open output file %s\n", filename);
        return false;
    }

    // 4. 矩阵循环导出
    uint32_t current_addr_base = start_offset;

    for (uint32_t r = 0; r < rows; r++) {
        for (uint32_t c = 0; c < cols; c++) {
            
            // 计算当前数据的字节地址
            uint32_t addr = current_addr_base + (r * cols + c) * bytes_per_item;

            // 拼装 16位 数据 (Little Endian: 低地址存低字节)
            uint8_t lo = ram_ptr[addr];
            uint8_t hi = ram_ptr[addr + 1];
            uint16_t val = (uint16_t)lo | ((uint16_t)hi << 8);

            // 写入文件 (4位宽 16进制，大写)
            // 最后一列不加空格
            if (c == cols - 1) {
                fprintf(fp, "%04X", val);
            } else {
                fprintf(fp, "%04X ", val);
            }
        }
        // 换行
        fprintf(fp, "\n");
    }

    fclose(fp);
    printf("[DPI Info] Dumped %dx%d Matrix to %s (Offset: 0x%x)\n", rows, cols, filename, start_offset);
    return true;
}

bool load_bin_to_ram_protect(const char* filename, uint8_t* ram_ptr, uint32_t max_size, uint32_t offset) {
    // 1. 打开文件
    FILE* fp = fopen(filename, "rb");
    if (fp == nullptr) {
        printf("[DPI Error] Cannot open file: %s\n", filename);
        return false;
    }

    // 2. 获取文件大小
    fseek(fp, 0, SEEK_END);
    long file_size = ftell(fp);
    rewind(fp);

    if (file_size < 0) {
        printf("[DPI Error] Failed to get file size: %s\n", filename);
        fclose(fp);
        return false;
    }

    // 3. 基础越界检查：如果起始偏移本身就在内存之外，无法写入任何数据
    if (offset >= max_size) {
        printf("[DPI Error] Offset 0x%x is out of RAM range (RAM Size: 0x%x)\n", offset, max_size);
        fclose(fp);
        return false;
    }

    // 4. 计算实际需要读取的大小 (截断逻辑)
    // 计算从 offset 开始，内存还剩多少空间
    long available_space = (long)max_size - (long)offset;
    
    size_t bytes_to_read = 0;
    bool is_truncated = false;

    // 如果文件大小 超过了 剩余空间，则截断
    if (file_size > available_space) {
        bytes_to_read = (size_t)available_space;
        is_truncated = true;
        printf("[DPI Warning] File %s is too large! Truncating load.\n", filename);
        printf("              (File: %ld bytes, Available: %ld bytes). Only loading first %ld bytes.\n", 
               file_size, available_space, available_space);
    } else {
        // 否则完全读取
        bytes_to_read = (size_t)file_size;
    }

    // 5. 读取数据
    // 注意：这里读取的长度变成了 bytes_to_read，而不是 file_size
    size_t result = fread(ram_ptr + offset, 1, bytes_to_read, fp);
    
    if (result != bytes_to_read) {
        printf("[DPI Error] Reading file failed. Expected %zu bytes, got %zu\n", bytes_to_read, result);
        fclose(fp);
        return false;
    }

    // 6. 收尾
    fclose(fp);
    
    if (is_truncated) {
        printf("[DPI Info] PARTIALLY Loaded %s to RAM @ Offset 0x%x (Truncated to %zu bytes)\n", filename, offset, bytes_to_read);
    } else {
        printf("[DPI Info] Fully Loaded %s to RAM @ Offset 0x%x (Size: %ld bytes)\n", filename, offset, file_size);
    }
    
    return true;
}

void frodo_v_encodeu_add() {
    // 固定映射：V(c2) 位于 dp_ram[4032*8], u 位于 sp_ram[4036*8]
    const uint32_t V_BASE_ADDR = 4032u * 8u;
    const uint32_t U_BASE_ADDR = 4036u * 8u;
    const uint32_t C_BASE_ADDR = 4032u * 8u; // 原地写回 c2

    const uint32_t NBAR = 8u;
    const uint32_t EXTRACTED_BITS = 4u; // Frodo1344: B=4
    const uint32_t LOGQ = 16u;          // q = 2^16

    const uint32_t COEFFS = NBAR * NBAR;             // 64
    const uint32_t U_BYTES = (COEFFS * EXTRACTED_BITS) / 8u; // 32
    const uint32_t V_BYTES = COEFFS * 2u;            // 128

    if ((U_BASE_ADDR + U_BYTES > RAM_SIZE) ||
        (V_BASE_ADDR + V_BYTES > RAM_SIZE) ||
        (C_BASE_ADDR + V_BYTES > RAM_SIZE)) {
        MEM_ERR_PRINTF("[DPI Error] frodo_v_encodeu_add out of bounds\n");
        return;
    }

    uint8_t c_le[V_BYTES];

    for (uint32_t i = 0; i < COEFFS; ++i) {
        const uint8_t packed = sp_ram[U_BASE_ADDR + (i >> 1)];
        const uint16_t mu_i = (i & 1u) ? ((packed >> 4) & 0x0Fu) : (packed & 0x0Fu);
        const uint16_t enc_i = (uint16_t)(mu_i << (LOGQ - EXTRACTED_BITS));

        const uint32_t v_off = V_BASE_ADDR + (i << 1);
        const uint16_t v_i = (uint16_t)dp_ram[v_off] | ((uint16_t)dp_ram[v_off + 1] << 8);
        const uint16_t c_i = (uint16_t)(v_i + enc_i);

        const uint32_t c_off = (i << 1);
        c_le[c_off] = (uint8_t)(c_i & 0xFFu);
        c_le[c_off + 1] = (uint8_t)(c_i >> 8);
    }

    // 第二阶段统一 pack：逐 16-bit 交换高低字节后写回 DP_RAM。
    for (uint32_t i = 0; i < COEFFS; ++i) {
        const uint32_t off = (i << 1);
        dp_ram[C_BASE_ADDR + off] = c_le[off + 1];
        dp_ram[C_BASE_ADDR + off + 1] = c_le[off];
    }
}

void dump_ALL_BRAM(){
     const char* dump_file = "./output/SP_RAM.bin";
    if(dump_ram_to_bin(dump_file, sp_ram, RAM_SIZE,0, RAM_SIZE))
    {
        printf("Dumped output data from SP_RAM successfully.\n");
    }
    else
    {
        printf("Failed to dump output data from SP_RAM.\n");
    }
    dump_file = "./output/DP_RAM.bin";
    if(dump_ram_to_bin(dump_file, dp_ram, RAM_SIZE,0, RAM_SIZE))
    {
        printf("Dumped output data from SP_RAM successfully.\n");
    }
    else
    {
        printf("Failed to dump output data from SP_RAM.\n");
    }
    dump_file = "./output/A_buffer_2.bin";
    if(dump_ram_to_bin(dump_file, A_buffer_2, BUFFER_SIZE, 0, BUFFER_SIZE))
    {
        printf("Dumped output data from SP_RAM successfully.\n");
    }
    else
    {
        printf("Failed to dump output data from SP_RAM.\n");
    }
    dump_file = "./output/A_buffer_1.bin";
    if(dump_ram_to_bin(dump_file, A_buffer_1, BUFFER_SIZE, 0, BUFFER_SIZE))
    {
        printf("Dumped output data from SP_RAM successfully.\n");
    }
    else
    {
        printf("Failed to dump output data from SP_RAM.\n");
    }
}

void dump_bram_to_terminal(int bramid, uint32_t addr, uint32_t length) {
    uint8_t* ptr = nullptr;
    uint32_t max_size = 0;
    const char* name = "";

    switch(bramid) {
        case 0: ptr = sp_ram; max_size = RAM_SIZE; name = "SP_RAM"; break;
        case 1: ptr = dp_ram; max_size = RAM_SIZE; name = "DP_RAM"; break;
        case 2: ptr = A_buffer_1; max_size = BUFFER_SIZE; name = "A_BUFFER_1"; break;
        case 3: ptr = A_buffer_2; max_size = BUFFER_SIZE; name = "A_BUFFER_2"; break;
        case 4: ptr = PC_ROM; max_size = PC_ROM_SIZE; name = "INSTR_ROM"; break;
        default: printf("Unknown BRAM ID: %d\n", bramid); return;
    }

    printf("\n--- Dumping %s (ID: %d) from 0x%08X, length %d ---\n", name, bramid, addr, length);
    
    for (uint32_t i = 0; i < length; i++) {
        if (addr + i >= max_size) break;
        
        if (i % 16 == 0) printf("0x%08X: ", addr + i);
        
        printf("%02X ", ptr[addr + i]);
        
        if (i % 16 == 15 || i == length - 1) {
            // 对齐打印 ASCII
            if (i % 16 != 15) {
                for (uint32_t j = 0; j < 15 - (i % 16); j++) printf("   ");
            }
            printf(" | ");
            uint32_t start = (i / 16) * 16;
            for (uint32_t j = start; j <= i; j++) {
                uint8_t c = ptr[addr + j];
                printf("%c", (c >= 32 && c <= 126) ? c : '.');
            }
            printf("\n");
        }
    }
    printf("-----------------------------------------------------------\n\n");
}

void interactive_memory_query() {
    printf("\nEntering interactive memory query mode.\n");
    printf("Usage: <bramid> <addr> <length>  (e.g., 0 0x4060 32)\n");
    printf("Enter bramid -1 to quit.\n");

    while (true) {
        int b;
        std::string addr_str, len_str;
        printf("query> ");
        
        if (!(std::cin >> b)) break;
        if (b == -1) break;
        
        if (!(std::cin >> addr_str >> len_str)) break;

        uint32_t a = (uint32_t)strtoul(addr_str.c_str(), NULL, 0);
        uint32_t l = (uint32_t)strtoul(len_str.c_str(), NULL, 0);

        dump_bram_to_terminal(b, a, l);
    }
}