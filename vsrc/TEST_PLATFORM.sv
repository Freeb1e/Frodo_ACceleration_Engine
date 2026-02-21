`include "define.sv"
module TEST_PLATFORM(
        input logic clk,
        input logic rst_n
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
    logic [31:0] instr_F,instr_D,instr_E;
    logic [63:0] instr64;
    logic [3:0] bitbusy;
    logic [31:0] pc_reg,pc_reg_stall;
    FACE_TOP u_FACE_TOP(
        .clk              	(clk               ),
        .rst_n            	(rst_n             ),
        .instr            	(instr_E             ),
        .bram_rdata_sp_1  	(bram_rdata_sp_1   ),
        .bram_rdata_sp_2  	(bram_rdata_sp_2   ),
        .bram_rdata_dp_1  	(bram_rdata_dp_1   ),
        .bram_rdata_dp_2  	(bram_rdata_dp_2   ),
        .bram_rdata_HASH1 	(bram_rdata_HASH1  ),
        .bram_rdata_HASH2 	(bram_rdata_HASH2  ),
        .addr_sp_1        	(addr_sp_1         ),
        .addr_sp_2        	(addr_sp_2         ),
        .addr_dp_1        	(addr_dp_1         ),
        .addr_dp_2        	(addr_dp_2         ),
        .addr_HASH_1      	(addr_HASH_1       ),
        .addr_HASH_2      	(addr_HASH_2       ),
        .bram_wdata_sp_1  	(bram_wdata_sp_1   ),
        .bram_wdata_sp_2  	(bram_wdata_sp_2   ),
        .bram_wdata_dp_1  	(bram_wdata_dp_1   ),
        .bram_wdata_dp_2  	(bram_wdata_dp_2   ),
        .bram_wdata_HASH  	(bram_wdata_HASH   ),
        .wen_sp_1         	(wen_sp_1          ),
        .wen_sp_2         	(wen_sp_2          ),
        .wen_dp_1         	(wen_dp_1          ),
        .wen_dp_2         	(wen_dp_2          ),
        .wen_HASH_1       	(wen_HASH_1        ),
        .wen_HASH_2       	(wen_HASH_2        ),
        .bitbusy             	(bitbusy              ),
        .next_instr             (next_instr)
    );
    logic instr_valid;
    assign instr_valid = 1'b1;
    logic [3:0] instr_bitbusy;
    logic instr_busytype_systolic_calc,instr_type_shake;
    logic [6:0] OPCODE_D,OPCODE_E;
    logic [2:0] FUNC_D,OPCPDE_E;
    logic ready;
    logic next_instr;

    assign FUNC_D = instr_D[9:7];
    assign OPCODE_D = instr_D[6:0];
    assign instr_busytype_systolic_calc = (OPCODE_D == `SYSOPCODE);
    assign instr_type_shake = (OPCODE_D == `SHAOPCODE); 
    assign instr_bitbusy = {1'b0,instr_busytype_systolic_calc,instr_type_shake,1'b0};
    assign ready =!(|(instr_bitbusy & bitbusy));
    assign next_instr = instr_valid && ready;

    always_ff@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            pc_reg <= 32'd0;
        end else begin
            if(next_instr)begin
                pc_reg <= pc_reg + 32'd4;
                pc_reg_stall <= pc_reg;
                instr_D <= instr_F;
                instr_E <= instr_D;
            end else begin
                instr_D <= instr_D;
                instr_E <= 32'hFFFFFFFF;
                pc_reg <= pc_reg_stall;
            end
    end
    end
    assign instr_F = (pc_reg[2] == 1'b1) ? instr64[31:0] : instr64[63:32];
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
    block_ram_dpi #(
                      .BRAM_ID 	(4  ))
                  INSTR_ROM(
                      .clk   	(clk    ),
                      .raddr 	(pc_reg ),
                      .waddr 	(32'h0  ),
                      .wdata 	(64'd0  ),
                      .wmask 	(8'h0  ),
                      .wen   	(1'h0    ),
                      .rdata 	(instr64)
                  );
endmodule
