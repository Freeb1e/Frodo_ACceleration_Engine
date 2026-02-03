#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "VTEST_PLATFORM.h"
#include "VTEST_PLATFORM__Syms.h"
#include "memory.h"
#include <fstream>
#include "testinit.h"
#define MAX_SIM_TIME 7000
vluint64_t sim_time = 0;

VTEST_PLATFORM *dut = nullptr;
VerilatedVcdC *m_trace = nullptr;


void tick()
{
    dut->clk = 0;
    dut->eval();
    m_trace->dump(sim_time++);
    dut->clk = 1;
    dut->eval();
    m_trace->dump(sim_time++);
}

void runtill(){
    do{
        dut->clk ^= 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }while(sim_time < MAX_SIM_TIME);
}

void init_instram(){
    bool load_bin_to_ram(const char* filename, uint8_t* ram_ptr, uint32_t max_size, uint32_t offset);
    load_bin_to_ram("./simdata/firmware.bin",PC_ROM,PC_ROM_SIZE, 0);
}

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
    init_SA_test();
    tick();
    runtill();
    dump_file = "./output/Bout.bin";
    if(dump_ram_to_bin(dump_file, dp_ram, RAM_SIZE, 1344*8, 1344*8 *2))
    {
        printf("Dumped output data from SP_RAM successfully.\n");
    }
    else
    {
        printf("Failed to dump output data from SP_RAM.\n");
    }
    dump_file = "./output/Bout.txt";
    if(dump_ram_to_matrix(dump_file, dp_ram, RAM_SIZE,1344*8, 1344, 8))
    {
        printf("Dumped output matrix from SP_RAM successfully.\n");
    }
    else
    {
        printf("Failed to dump output matrix from SP_RAM.\n");
    }
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
