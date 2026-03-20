#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "VTEST_PLATFORM.h"
#include "VTEST_PLATFORM__Syms.h"
#include "memory.h"
#include <fstream>
#include <iomanip>
#include "testinit.h"
#define MAX_SIM_TIME 27000000
vluint64_t sim_time = 0;
bool trace_on = false; // 控制波形开关：true 开启，false 关闭

VTEST_PLATFORM *dut = nullptr;
VerilatedVcdC *m_trace = nullptr;

extern "C" void test_print_simtime() {
    std::cout << "[DPIC Debug] sim_time = " << sim_time << std::endl;
}


void tick()
{
    dut->clk = 0;
    dut->eval();
    if (trace_on && m_trace) m_trace->dump(sim_time);
    sim_time++;
    dut->clk = 1;
    dut->eval();
    if (trace_on && m_trace) m_trace->dump(sim_time);
    sim_time++;
}

void runtill(){
    do{
        dut->clk ^= 1;
        dut->eval();
        if (trace_on && m_trace) m_trace->dump(sim_time);
        sim_time++;
    }while(sim_time < MAX_SIM_TIME);
}

void init_instram(){
    bool load_bin_to_ram(const char* filename, uint8_t* ram_ptr, uint32_t max_size, uint32_t offset);
    load_bin_to_ram("./simdata/firmware.bin",PC_ROM,PC_ROM_SIZE, 0);
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

void Keygen_init();
void Encap_init();
void Encapss_init();
int main(int argc, char** argv, char** env) {
    dut = new VTEST_PLATFORM;

    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    //init_seedram(mode);
    init_instram();
    dut -> rst_n = 0;
    tick();
    dut -> rst_n = 1;
    Keygen_init();
    //Encap_init();
    //Encapss_init();
    //init_SA_test();
    //init_AS_test();
    //init_seedram(0); // 初始化种子数据到 SP_RAM
    //interactive_memory_query();
    tick();
    runtill();
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

    // 交互式查询循环
   // interactive_memory_query();

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
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
        printf("Loaded S data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load S data into HASH RAM.\n");
    }
    for (int i = 0; i < 12; i++) {
        pmem_write((4036*8 + i*8), 0, 0x4242424242424242, 0xFF);
    }
}

void Encapss_init(){
    test_file = "./simdata/raminit/SP_RAM_encap.bin";
    if(load_bin_to_ram(test_file, sp_ram, RAM_SIZE, 0))
    {
        printf("Loaded S data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load S data into HASH RAM.\n");
    }
    test_file = "./simdata/raminit/DP_RAM_encap.bin";
    if(load_bin_to_ram(test_file, dp_ram, RAM_SIZE, 0))
    {
        printf("Loaded S data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load S data into HASH RAM.\n");
    }

}
