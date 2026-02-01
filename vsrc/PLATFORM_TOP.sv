module platform_top(
    input logic clk,
    input logic rst_n,
    input logic calc_init,
    input logic [2:0] mem_mode,
    input logic HASH_ready,
    input logic [31:0] BASE_ADDR_LEFT,
    input logic [31:0] BASE_ADDR_RIGHT,
    input logic [31:0] BASE_ADDR_ADDSRC,
    input logic [31:0] BASE_ADDR_SAVE,
    input logic [10:0] MATRIX_SIZE
);
    parameter IDLE=4'd0;
    parameter AS_CALC=4'd1,AS_SAVE=4'd2;
    parameter SA_LOADWEIGHT=4'd3,SA_CALC=4'd4;
    logic [63:0] bram_data_1;
    logic [63:0] bram_data_2;
    logic [63:0] bram_data_3;
    logic [31:0] bram_addr_1;
    logic [31:0] bram_addr_2;
    logic [31:0] bram_addr_3;
    logic [3:0] current_state;
    logic save_wen;
    logic [63:0] bram_savedata;
    
    mul_top u_mul_top(
        .clk             	(clk              ),
        .rst_n           	(rst_n            ),
        .mem_mode        	(mem_mode         ),
        .calc_init       	(calc_init        ),

        .bram_data_1       (bram_data_1       ),
        .bram_data_2       (bram_data_2       ),
        .bram_data_3       (bram_data_3       ),

        .BASE_ADDR_LEFT   	(BASE_ADDR_LEFT    ),
        .BASE_ADDR_RIGHT  	(BASE_ADDR_RIGHT   ),
        .BASE_ADDR_ADDSRC 	(BASE_ADDR_ADDSRC  ),
        .BASE_ADDR_SAVE   	(BASE_ADDR_SAVE    ),
        .MATRIX_SIZE     	(MATRIX_SIZE      ),

        .bram_addr_1      	(bram_addr_1       ),
        .bram_addr_2      	(bram_addr_2       ),
        .bram_addr_3      	(bram_addr_3       ),

        .current_state    	(current_state     ),

        .save_wen        	(save_wen         ),
        .bram_savedata     	(bram_savedata      )
    );
    
    always_comb begin
                    addr_HASH = 32'd0;
            addr_sb = 32'd0;
            addr_sb_2 = 32'd0;
            wen_sb = 1'b0;
            wen_sb_2 = 1'b0;
            bram_wdata_sb = 64'd0;
            bram_wdata_sb_2 = 64'd0;

            bram_data_1 = 64'd0;
            bram_data_2 = 64'd0;
            bram_data_3 = 64'd0;
        case(current_state)
        AS_CALC: begin
            addr_HASH = bram_addr_1;
            addr_sb = bram_addr_2;
            wen_sb = 1'b0;
            wen_sb_2 = 1'b0;
            bram_wdata_sb = 64'd0;
            bram_data_1 = bram_data_HASH;
            bram_data_2 = bram_data_sb;
        end
        AS_SAVE: begin
            addr_sb = bram_addr_1;
            addr_sb_2 = bram_addr_2;
            bram_wdata_sb_2 = bram_savedata;
            bram_data_1 = bram_data_sb;
            wen_sb_2 = save_wen;
        end
        SA_LOADWEIGHT: begin
            addr_sb = bram_addr_1;
            bram_data_1 = bram_data_sb;
        end
        SA_CALC: begin
            addr_sb = bram_addr_1;
            addr_sb_2 = bram_addr_2;
            addr_HASH = bram_addr_3;

            bram_data_1 = bram_data_sb;
            bram_wdata_sb_2 = bram_savedata;
            wen_sb_2 = save_wen;
            bram_data_3 = bram_data_HASH;
        end
        default: begin
            addr_HASH = 32'd0;
            addr_sb = 32'd0;
            addr_sb_2 = 32'd0;
            wen_sb = 1'b0;
            wen_sb_2 = 1'b0;
            bram_wdata_sb = 64'd0;
            bram_wdata_sb_2 = 64'd0;

            bram_data_1 = 64'd0;
            bram_data_2 = 64'd0;
            bram_data_3 = 64'd0;
        end
        endcase
    end

    logic [31:0] addr_HASH;
    logic [31:0] addr_sb;
    logic [31:0] addr_sb_2;
    logic [63:0] bram_wdata_sb;
    logic [63:0] bram_wdata_sb_2;
    logic wen_sb;
    logic wen_sb_2;
    logic [63:0] bram_data_HASH;
    logic [63:0] bram_data_sb;
    logic [63:0] bram_data_sb_2;
    block_ram_dpi #(
        .BRAM_ID 	(0  ))
    HASH_RAM(
        .clk   	(clk    ),
        .raddr 	(addr_HASH  ),
        .waddr 	(32'h0  ),
        .wdata 	(64'h0  ),
        .wmask 	(8'h0  ),
        .wen   	(1'h0    ),
        .rdata 	(bram_data_HASH )
    );
    block_ram_dpi #(
        .BRAM_ID 	(1  ))
    sp_RAM_port1(
        .clk   	(clk    ),
        .raddr 	(addr_sb  ),
        .waddr 	(addr_sb  ),
        .wdata 	(bram_wdata_sb  ),
        .wmask 	(8'hFF  ),
        .wen   	(wen_sb    ),
        .rdata 	(bram_data_sb  )
    ); 
    block_ram_dpi #(
        .BRAM_ID 	(1  ))
    sp_RAM_port2(
        .clk   	(clk    ),
        .raddr 	(addr_sb_2  ),
        .waddr 	(addr_sb_2  ),
        .wdata 	(bram_wdata_sb_2   ),
        .wmask 	(8'hFF  ),
        .wen   	(wen_sb_2    ),
        .rdata 	(bram_data_sb_2  )
    ); 
endmodule 
