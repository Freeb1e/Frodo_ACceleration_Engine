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
    logic [1:0] bitbusy;
    logic [31:0] pc_reg,pc_reg_stall;
    logic pc_choose_delay;
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
                 .prebusy               (prebusy               )
             );

    logic [6:0] OPCODE_D,OPCODE_E;
    logic [2:0] FUNC_D,OPCPDE_E;
    logic ready;

    assign FUNC_D = instr_D[9:7];
    assign OPCODE_D = instr_D[6:0];

    //在译码阶段标记需要占用的资源类型
    logic pre_systolicbusy,pre_sha3busy;
    logic [1:0] prebusy,instr_bitbusy;
    assign pre_systolicbusy = (OPCODE_D == `SYSOPCODE)&&(FUNC_D == `systolic_calc_FUNC);
    assign pre_sha3busy = (OPCODE_D == `SHAOPCODE)&&(FUNC_D != `SHAKE_seedaddrset_FUNC);
    assign prebusy = {pre_systolicbusy,pre_sha3busy};
    assign instr_bitbusy = {(OPCODE_D == `SYSOPCODE),(OPCODE_D == `SHAOPCODE)};
    assign ready =!(|(instr_bitbusy & bitbusy));

    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pc_reg <= 32'd0;
            pc_choose_delay <= 1'b0;
            pc_reg_stall <= 32'd0;
        end
        else begin
            if(ready) begin
                pc_reg <= pc_reg + 32'd4;
                instr_D <= instr_F; //指令流在IF阶段取指，D阶段译码，E阶段执行
                instr_E <= instr_D;
                pc_reg_stall <= pc_reg; //记录当前PC值，以便在资源占用时保持PC不变
            end
            else begin
                pc_reg <= pc_reg_stall; //保持PC不变，等待资源空闲
                instr_D <= instr_D; //保持指令不变，等待资源空闲
                instr_E <= 32'hFFFF_FFFF; //保持指令不变，等待资源空闲
            end
            pc_choose_delay <= pc_reg[2];
        end
    end
    assign instr_F = (ready_d)? (pc_choose_delay == 1'b0) ? instr64[31:0] : instr64[63:32] : 32'hFFFF_FFFF; //根据PC的最低两位选择指令的高32位或低32位，资源占用时输出无效指令

    logic ready_d;
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ready_d <= 1'b0;
        end
        else begin
            ready_d <= ready;
        end
    end

    // block RAM instances
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
