module TEST_PLATFORM(
        input logic clk,
        input logic rst_n,
        input logic [31:0] instr
    );
    logic [31:0] addr_sp_1,addr_sp_2;
    logic [31:0] addr_dp_1,addr_dp_2;
    logic [31:0] addr_HASH_1,addr_HASH_2;
    logic [63:0] bram_rdata_sp_1,bram_rdata_sp_2;
    logic [63:0] bram_rdata_dp_1,bram_rdata_dp_2;
    logic [63:0] bram_rdata_HASH1,bram_rdata_HASH2;
    logic [63:0] bram_wdata_sp_1,bram_wdata_sp_2;
    logic [63:0] bram_wdata_dp_1,bram_wdata_dp_2;
    logic [63:0] bram_wdata_HASH;
    logic wen_sp_1,wen_sp_2;
    logic wen_dp_1,wen_dp_2;
    logic wen_HASH_1,wen_HASH_2;

    block_ram_dpi #(
                      .BRAM_ID 	(0  ))
                  sp_ram_port_1(
                      .clk   	(clk    ),
                      .raddr 	(addr_sp_1  ),
                      .waddr 	(addr_sp_1  ),
                      .wdata 	(bram_wdata_sp_1  ),
                      .wmask 	(8'hFF  ),
                      .wen   	(wen_sp_1    ),
                      .rdata 	(bram_rdata_sp_1 )
                  );
    block_ram_dpi #(
                      .BRAM_ID 	(0  ))
                  sp_ram_port_2(
                      .clk   	(clk    ),
                      .raddr 	(addr_sp_2  ),
                      .waddr 	(addr_sp_2  ),
                      .wdata 	(bram_wdata_sp_2  ),
                      .wmask 	(8'hFF  ),
                      .wen   	(wen_sp_2    ),
                      .rdata 	(bram_rdata_sp_2 )
                  );
    block_ram_dpi #(
                      .BRAM_ID 	(1  ))
                  dp_ram_port_1(
                      .clk   	(clk    ),
                      .raddr 	(addr_dp_1  ),
                      .waddr 	(addr_dp_1  ),
                      .wdata 	(bram_wdata_dp_1  ),
                      .wmask 	(8'hFF  ),
                      .wen   	(wen_dp_1    ),
                      .rdata 	(bram_rdata_dp_1 )
                  );
    block_ram_dpi #(
                      .BRAM_ID 	(1  ))
                  dp_ram_port_2(
                      .clk   	(clk    ),
                      .raddr 	(addr_dp_2  ),
                      .waddr 	(addr_dp_2  ),
                      .wdata 	(bram_wdata_dp_2  ),
                      .wmask 	(8'hFF  ),
                      .wen   	(wen_dp_2    ),
                      .rdata 	(bram_rdata_dp_2 )
                  );
    block_ram_dpi #(
                      .BRAM_ID 	(2  ))
                  HASH_ram_1(
                      .clk   	(clk    ),
                      .raddr 	(addr_HASH_1  ),
                      .waddr 	(addr_HASH_1  ),
                      .wdata 	(bram_wdata_HASH  ),
                      .wmask 	(8'hFF  ),
                      .wen   	(wen_HASH_1    ),
                      .rdata 	(bram_rdata_HASH1 )
                  );
    block_ram_dpi #(
                      .BRAM_ID 	(3  ))
                  HASH_ram_2(
                      .clk   	(clk    ),
                      .raddr 	(addr_HASH_2  ),
                      .waddr 	(addr_HASH_2  ),
                      .wdata 	(bram_wdata_HASH  ),
                      .wmask 	(8'hFF  ),
                      .wen   	(wen_HASH_2    ),
                      .rdata 	(bram_rdata_HASH2 )
                  );
endmodule
