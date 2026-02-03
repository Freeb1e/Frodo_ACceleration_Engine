#include "VTEST_PLATFORM__Dpi.h"
extern bool load_bin_to_ram(const char* filename, uint8_t* ram_ptr, uint32_t max_size, uint32_t offset);
extern bool dump_ram_to_bin(const char* filename, const uint8_t* ram_ptr, uint32_t max_size, uint32_t start_offset, uint32_t write_len);
extern bool dump_ram_to_matrix(const char* filename, const uint8_t* ram_ptr, uint32_t max_size, 
                        uint32_t start_offset, uint32_t rows, uint32_t cols);
extern bool load_bin_to_ram_protect(const char* filename, uint8_t* ram_ptr, uint32_t max_size, uint32_t offset);
#define RAM_SIZE    (64 * 1024)
#define BUFFER_SIZE (10752)
#define PC_ROM_SIZE 1024

extern uint8_t sp_ram[RAM_SIZE]; // 对应 bramid = 0
extern uint8_t dp_ram[RAM_SIZE];  // 对应 bramid = 1
extern uint8_t A_buffer_1[BUFFER_SIZE]; //对应 bramid = 2
extern uint8_t A_buffer_2[BUFFER_SIZE]; //对应 bramid = 3
extern uint8_t PC_ROM[PC_ROM_SIZE];

#define MATRIX_ROWS    8
#define MATRIX_COLS    1344
#define BYTES_PER_ITEM 2