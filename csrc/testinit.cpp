#include "memory.h"
#include "testinit.h"
#include <cstdio>
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