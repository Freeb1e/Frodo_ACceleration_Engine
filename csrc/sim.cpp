#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "VTEST_PLATFORM.h"
#include "VTEST_PLATFORM__Syms.h"
#include "memory.h"
#include <fstream>
#include <iomanip>
#include "config.h"
#include "testinit.h"

#ifdef TRACE_ON
bool trace_on = true;
#else
bool trace_on = false;
#endif

vluint64_t sim_time = 0;

VTEST_PLATFORM *dut = nullptr;
VerilatedVcdC *m_trace = nullptr;
void tick();
void runtill();

static void print_pkh();
static void print_ss();

int main(int argc, char **argv, char **env)
{

    dut = new VTEST_PLATFORM;

    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    init_instram();
    dut->rst_n = 0;
    tick();
    dut->rst_n = 1;
#if defined(DECAP_TEST)
    decap_init();
#elif defined(ENCAP_TEST)
    Encap_init();
#elif defined(KEYGEN_TEST)
    Keygen_init();
#elif defined(ENCAP976_TEST)
    Encap_init_976();
#else
    std::cout << "[SIM] No test macro enabled, skip test init." << std::endl;
#endif

    // init_seedram(mode);
    // Encapss_init();
    // init_SA_test();
    // init_AS_test();
    // init_seedram(0);
    // interactive_memory_query();
    tick();
    runtill();

#if defined(KEYGEN_TEST)
    print_pkh();
#elif defined(ENCAP_TEST)
    print_ss();
#elif defined(ENCAP976_TEST)
    print_ss();
    #endif

    dump_ALL_BRAM();

#ifdef ENABLE_INTERACTIVE_MEMORY_QUERY
    interactive_memory_query();
#endif

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

extern "C" void test_print_simtime()
{
    std::cout << "[DPIC Debug] sim_time = " << sim_time << std::endl;
    std::cout << "[DPIC Debug] cycles = " << sim_time / 2 << std::endl;
}

void tick()
{
    dut->clk = 0;
    dut->eval();
    if (trace_on && m_trace)
        m_trace->dump(sim_time);
    sim_time++;
    dut->clk = 1;
    dut->eval();
    if (trace_on && m_trace)
        m_trace->dump(sim_time);
    sim_time++;
}

void runtill()
{
    do
    {
        dut->clk ^= 1;
        dut->eval();
        if (trace_on && m_trace)
            m_trace->dump(sim_time);
        sim_time++;
    } while (sim_time < MAX_SIM_TIME);
}
static void print_pkh()
{
    constexpr uint32_t PKH_ADDR = 4032u * 8u;
    constexpr uint32_t OUT_LEN = 32u;

    std::cout << "\n[SIM] pkh (SP_RAM @ 0x" << std::hex << PKH_ADDR
              << ", len=" << std::dec << OUT_LEN << " bytes)" << std::endl;
    dump_bram_to_terminal(0, PKH_ADDR, OUT_LEN);
}

static void print_ss()
{
    constexpr uint32_t SS_ADDR = 4066u * 8u;
    constexpr uint32_t OUT_LEN = 32u;

    std::cout << "\n[SIM] ss (SP_RAM @ 0x" << std::hex << SS_ADDR
              << ", len=" << std::dec << OUT_LEN << " bytes)" << std::endl;
    dump_bram_to_terminal(0, SS_ADDR, OUT_LEN);
}
