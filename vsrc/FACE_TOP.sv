module FACE_TOP(
    input logic clk,
    input logic rst_n,
    input logic [31:0] instr,
    
    input logic [63:0] bram_rdata_sp_1,
    input logic [63:0] bram_rdata_sp_2,
    input logic [63:0] bram_rdata_dp_1,
    input logic [63:0] bram_rdata_dp_2,
    input logic [63:0] bram_rdata_HASH1,
    input logic [63:0] bram_rdata_HASH2,

    output logic [31:0] addr_sp_1,
    output logic [31:0] addr_sp_2,
    output logic [31:0] addr_dp_1,
    output logic [31:0] addr_dp_2,
    output logic [31:0] addr_HASH_1,
    output logic [31:0] addr_HASH_2,
    output logic [63:0] bram_wdata_sp_1,
    output logic [63:0] bram_wdata_sp_2,
    output logic [63:0] bram_wdata_dp_1,
    output logic [63:0] bram_wdata_dp_2,
    
    output logic [63:0] bram_wdata_HASH,
    output logic wen_sp_1,
    output logic wen_sp_2,
    output logic wen_dp_1,
    output logic wen_dp_2,
    output logic wen_HASH_1,
    output logic wen_HASH_2
);
parameter OPCODE = 6'b010101;
parameter systolic_addr_set = 4'd0;

//systolic setting regs
logic [2:0] mem_mode;
logic [1:0] addr_mode;
logic ram_id;
logic [20:0] BASE_ADDR;
logic [31:0] BASE_ADDR_S,BASE_ADDR_HASH,BASE_ADDR_B;
logic ram
assign mem_mode = instr[26:24];
assign addr_mode = instr[23:22];
assign ram_id = instr[21];
assign BASE_ADDR = instr[20:0];

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        BASE_ADDR_S <= 32'd0;
        BASE_ADDR_HASH <= 32'd0;
        BASE_ADDR_B <= 32'd0;
        ram
    end
end




wire [31:0] addr_sb;
wire [31:0] addr_HASH;
wire [31:0] addr_sb_2;
wire wen_sb;
wire wen_HASH;
wire wen_sb_2;
wire [63:0] bram_wdata_sb;
wire [63:0] bram_wdata_sb_2;
wire [63:0] bram_wdata_HASH;

mul_top u_mul_top(
    .clk             	(clk              ),
    .rst_n           	(rst_n            ),
    .mem_mode        	(mem_mode         ),
    .calc_init       	(calc_init        ),

    .bram_data_sb    	(bram_data_sb     ),
    .bram_data_HASH  	(bram_data_HASH   ),
    .bram_data_sb_2  	(bram_data_sb_2   ),

    .BASE_ADDR_S     	(BASE_ADDR_S      ),
    .BASE_ADDR_HASH  	(BASE_ADDR_HASH   ),   
    .BASE_ADDR_B     	(BASE_ADDR_B      ),
    .MATRIX_SIZE     	(MATRIX_SIZE      ),

    .addr_sb         	(addr_sb          ),
    .addr_HASH       	(addr_HASH        ),
    .addr_sb_2       	(addr_sb_2        ),

    .wen_sb          	(wen_sb           ),
    .wen_HASH        	(wen_HASH         ),
    .wen_sb_2        	(wen_sb_2         ),
    
    .bram_wdata_sb   	(bram_wdata_sb    ),
    .bram_wdata_sb_2 	(bram_wdata_sb_2  ),
    .bram_wdata_HASH 	(bram_wdata_HASH  ),

    .HASH_ready      	(HASH_ready       )
);

endmodule 