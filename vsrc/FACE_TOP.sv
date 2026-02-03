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
    output logic wen_HASH_2,

    output logic busy
);
assign busy = systolic_busy;
//systolic signals
logic [3:0] current_state;
logic [31:0] bram_addr_1,bram_addr_2,bram_addr_3;
logic [63:0] bram_data_1,bram_data_2,bram_data_3;
logic save_wen;
logic [63:0] bram_savedata;
logic [10:0] MATRIX_SIZE;

logic [6:0] OPCODE;
logic [2:0] FUNC;
//systolic setting regs
logic [18:0] BASE_ADDR;
logic [31:0] BASE_ADDR_LEFT,BASE_ADDR_RIGHT,BASE_ADDR_ADDSRC,BASE_ADDR_SAVE;
logic [1:0] setaddr;//控制设置的BASE_ADDR是哪一个
logic [1:0] ctrl_mode , ctrl_mode_REG;
logic systolic_busy;
parameter IDLE=4'd0;
parameter AS_CALC=4'd1,AS_SAVE=4'd2;
parameter SA_LOADWEIGHT=4'd3,SA_CALC=4'd4;

parameter AS = 2'b00 , SB = 2'b01 , BS = 2'b10 , SA = 2'b11;
//systolic_addr_set

/* verilator lint_off CASEINCOMPLETE */
assign BASE_ADDR = instr[30:12];
assign FUNC = instr[9:7];
assign OPCODE = instr[6:0];
assign setaddr = instr[11:10];
assign ctrl_mode = instr[11:10];
always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        BASE_ADDR_LEFT <= 32'd0;
        BASE_ADDR_RIGHT <= 32'd0;
        BASE_ADDR_ADDSRC <= 32'd0;
        BASE_ADDR_SAVE <= 32'd0;
    end else begin
        if(FUNC == `systolic_addrset_FUNC && OPCODE == `SYSOPCODE)begin
            case(setaddr)
                2'b00: BASE_ADDR_LEFT <= {13'd0,BASE_ADDR};
                2'b01: BASE_ADDR_RIGHT <= {13'd0,BASE_ADDR};
                2'b10: BASE_ADDR_ADDSRC <= {13'd0,BASE_ADDR};
                2'b11: BASE_ADDR_SAVE <= {13'd0,BASE_ADDR};
                default: ;
            endcase
        end
        if(FUNC == `systolic_calc_FUNC && OPCODE == `SYSOPCODE)begin
            if(!systolic_busy)begin
                ctrl_mode_REG <= ctrl_mode;
                calc_init <= 1'b1;
                systolic_busy <= 1'b1;
                MATRIX_SIZE <= instr[22:12];
            end 
        end else begin
            calc_init <= 1'b0;
        end
        if(systolic_done)begin
            systolic_busy <= 1'b0;
        end
    end
end
logic systolic_done;
logic [3:0] last_state; 
always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        systolic_done <= 1'b0;
        last_state <= IDLE;
    end else begin
        last_state <= current_state;
        if(last_state != IDLE && current_state == IDLE)begin
            systolic_done <= 1'b1;
        end else begin
            systolic_done <= 1'b0;
        end
    end
end
//systolic busy&done signal


//systoilc_data_bus
logic [2:0] mem_mode;
logic calc_init;
logic [31:0] addr_HASH_systolic;//脉动阵列读取的HASH地址
logic [63:0] bram_rdata_HASH;//脉动阵列读取的HASH数据
//==========================
assign addr_HASH_1 = addr_HASH_systolic;
assign bram_rdata_HASH = bram_rdata_HASH1;
//==========================
assign mem_mode = (ctrl_mode_REG == SA)? 3'd2:3'd1;
always_comb begin
    case(current_state)
        SA_LOADWEIGHT:begin
            //从dp中读取data放入
            addr_dp_1 = bram_addr_1;
            bram_data_1 = bram_rdata_dp_1;
        end
        SA_CALC:begin
            //从dp中读取累加源与累加结果写回，从HASH中读取权重数据
            addr_dp_1 = bram_addr_1;
            addr_dp_2 = bram_addr_2;
            addr_HASH_systolic = bram_addr_3;
            bram_data_1 = bram_rdata_dp_1;
            bram_wdata_dp_2 = bram_savedata;
            wen_dp_2  = save_wen;
            bram_data_3 = bram_rdata_HASH;
        end
        // AS_CALC:begin
        //     case(ctrl_mode_REG)
        //     endcase
        // end
        // AS_SAVE:begin
        //     case(ctrl_mode_REG)
        //     endcase
        // end
        default: begin
        end
    endcase
end

// output declaration of module mul_top

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