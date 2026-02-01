`include "define.sv"
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
parameter systolic_addr_set = 4'd0;

//systolic setting regs
logic [18:0] BASE_ADDR;
logic [31:0] BASE_ADDR_LEFT,BASE_ADDR_RIGHT,BASE_ADDR_ADDSRC,BASE_ADDR_SAVE;
logic [6:0] OPCODE;
logic [2:0] setaddr;
logic [2:0] FUNC;
logic [2:0] ctrl_mode;

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        BASE_ADDR_LEFT <= 32'd0;
        BASE_ADDR_RIGHT <= 32'd0;
        BASE_ADDR_ADDSRC <= 32'd0;
        BASE_ADDR_SAVE <= 32'd0;
    end else begin
        if(FUNC == systolic_addrset_FUNC && OPCODE == SYSOPCODE)begin
            case(setaddr)
                3'b000: BASE_ADDR_LEFT <= {13'd0,BASE_ADDR};
                3'b001: BASE_ADDR_RIGHT <= {13'd0,BASE_ADDR};
                3'b010: BASE_ADDR_ADDSRC <= {13'd0,BASE_ADDR};
                3'b011: BASE_ADDR_SAVE <= {13'd0,BASE_ADDR};
                default: ;
            endcase
        end
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

// output declaration of module mul_top
wire [31:0] bram_addr_1;
wire [31:0] bram_addr_2;
wire [31:0] bram_addr_3;
wire [3:0] current_state;
wire save_wen;
wire [63:0] bram_savedata;

mul_top u_mul_top(
    .clk              	(clk               ),
    .rst_n            	(rst_n             ),
    .mem_mode         	(mem_mode          ),
    .calc_init        	(calc_init         ),
    .bram_data_1      	(bram_data_1       ),
    .bram_data_2      	(bram_data_2       ),
    .bram_data_3      	(bram_data_3       ),
    .BASE_ADDR_LEFT   	(BASE_ADDR_LEFT    ),
    .BASE_ADDR_RIGHT  	(BASE_ADDR_RIGHT   ),
    .BASE_ADDR_ADDSRC 	(BASE_ADDR_ADDSRC  ),
    .BASE_ADDR_SAVE   	(BASE_ADDR_SAVE    ),
    .MATRIX_SIZE      	(MATRIX_SIZE       ),
    .bram_addr_1      	(bram_addr_1       ),
    .bram_addr_2      	(bram_addr_2       ),
    .bram_addr_3      	(bram_addr_3       ),
    .current_state    	(current_state     ),
    .save_wen         	(save_wen          ),
    .bram_savedata    	(bram_savedata     )
);


endmodule 