#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "VPLATFORM_TOP.h"
#include "VPLATFORM_TOP__Syms.h"
#include "memory.h"
#include <fstream>
#define MAX_SIM_TIME 20000
vluint64_t sim_time = 0;

VPLATFORM_TOP *dut = nullptr;
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

int main(int argc, char** argv, char** env) {
    dut = new VPLATFORM_TOP;
    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");
    init_seedram(mode);
    
    dut -> rst_n = 0;
    tick();
    dut -> shakemode = mode;
    dut -> rst_n = 1;
    tick();

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
