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
        input logic next_instr,

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

        output logic [3:0] bitbusy
    );
    assign bitbusy = {1'b0,systolic_busy,shakebusy,1'b0};
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
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            BASE_ADDR_LEFT <= 32'd0;
            BASE_ADDR_RIGHT <= 32'd0;
            BASE_ADDR_ADDSRC <= 32'd0;
            BASE_ADDR_SAVE <= 32'd0;
        end
        else begin
            if(FUNC == `systolic_addrset_FUNC && OPCODE == `SYSOPCODE) begin
                case(setaddr)
                    2'b00:
                        BASE_ADDR_LEFT <= {13'd0,BASE_ADDR};
                    2'b01:
                        BASE_ADDR_RIGHT <= {13'd0,BASE_ADDR};
                    2'b10:
                        BASE_ADDR_ADDSRC <= {13'd0,BASE_ADDR};
                    2'b11:
                        BASE_ADDR_SAVE <= {13'd0,BASE_ADDR};
                    default:
                        ;
                endcase
            end
            if(FUNC == `systolic_calc_FUNC && OPCODE == `SYSOPCODE) begin
                if(!systolic_busy) begin
                    ctrl_mode_REG <= ctrl_mode;
                    calc_init <= 1'b1;
                    systolic_busy <= 1'b1;
                    MATRIX_SIZE <= instr[22:12];
                end
            end
            else begin
                calc_init <= 1'b0;
            end
            if(systolic_done) begin
                systolic_busy <= 1'b0;
            end
        end
    end
    logic systolic_done;
    logic [3:0] last_state;
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            systolic_done <= 1'b0;
            last_state <= IDLE;
        end
        else begin
            last_state <= current_state;
            if(last_state != IDLE && current_state == IDLE) begin
                systolic_done <= 1'b1;
            end
            else begin
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
        addr_HASH_systolic = 32'd0;
        addr_sp_1 = 32'd0;
        addr_sp_2 = 32'd0;
        addr_dp_1 = 32'd0;
        addr_dp_2 = 32'd0;
        wen_sp_1 = 1'b0;
        wen_sp_2 = 1'b0;
        wen_dp_1 = 1'b0;
        wen_dp_2 = 1'b0;
        bram_wdata_sp_1 = 64'd0;
        bram_wdata_sp_2 = 64'd0;
        bram_wdata_dp_1 = 64'd0;
        bram_wdata_dp_2 = 64'd0;
        bram_data_1 = 64'd0;
        bram_data_2 = 64'd0;
        bram_data_3 = 64'd0;
        seed_data_in = 64'd0;
        if(systolic_busy) begin
            case(current_state)
                SA_LOADWEIGHT: begin
                    //从dp中读取data放入
                    addr_dp_1 = bram_addr_1;
                    bram_data_1 = bram_rdata_dp_1;
                end
                SA_CALC: begin
                    //从dp中读取累加源与累加结果写回，从HASH中读取权重数据
                    addr_dp_1 = bram_addr_1;
                    addr_dp_2 = bram_addr_2;
                    addr_HASH_systolic = bram_addr_3;
                    bram_data_1 = bram_rdata_dp_1;
                    bram_wdata_dp_2 = bram_savedata;
                    wen_dp_2  = save_wen;
                    bram_data_3 = bram_rdata_HASH;
                end
                AS_CALC: begin
                    if(ctrl_mode_REG == AS) begin
                        addr_HASH_systolic = bram_addr_1;
                        addr_sp_1 = bram_addr_2;
                        bram_data_1 = bram_rdata_HASH;
                        bram_data_2 = bram_rdata_sp_1;
                    end
                    else begin
                        addr_dp_1 = bram_addr_1;
                        addr_sp_1 = bram_addr_2;
                        bram_data_1 = bram_rdata_dp_1;
                        bram_data_2 = bram_rdata_sp_1;
                    end
                end
                AS_SAVE: begin
                    if(ctrl_mode_REG == AS) begin
                        addr_sp_1 = bram_addr_1;
                        addr_sp_2 = bram_addr_2;
                        bram_wdata_sp_2 = bram_savedata;
                        bram_data_1 = bram_rdata_sp_1;
                        wen_sp_2 = save_wen;
                    end
                    else begin
                        addr_dp_1 = bram_addr_1;
                        addr_dp_2 = bram_addr_2;
                        bram_wdata_dp_2 = bram_savedata;
                        bram_data_1 = bram_rdata_dp_1;
                        wen_dp_2 = save_wen;
                    end
                end
                default: begin
                end
            endcase
        end
        else begin
            if(shakebusy) begin
                addr_sp_1 = sha3_addr_perip;
                seed_data_in = bram_rdata_sp_1;
                if(dumpram_id == 1'b0) begin
                    addr_sp_2 = dump_addr + sha3_addr_perip;
                    wen_sp_2 = dump_wen;
                    bram_wdata_sp_2 = sha3_data_out;
                end else begin
                    addr_dp_2 = dump_addr + sha3_addr_perip;
                    wen_dp_2 = dump_wen;
                    bram_wdata_dp_2 = sha3_data_out;
                end
            end
        end
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

    logic [63:0] seed_data_in;
    logic sha3_start;
    logic sha3_squeezeonce;
    logic sha3_dumponce;

    logic [4:0] sha3_sample_addr;
    logic sha3_ready;
    logic sha3_optready;
    logic [63:0] sha3_data_out;
    logic [31:0] sha3_addr_perip;
    logic dump_wen;

    logic [31:0] SEED_BASE_ADDR;
    logic [7:0] absorb_num,last_block_bytes;
    logic shakebusy;
    logic shakemode; // 0: SHAKE128, 1: SHAKE256

    logic [14:0] dump_BASE_addr;
    logic dumpram_id;
    logic [31:0] dump_addr;
    assign dump_addr = {17'd0,dump_BASE_addr};
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            SEED_BASE_ADDR <= 32'd0;
            absorb_num <= 8'd0;
            last_block_bytes <= 8'd0;
        end
        else begin
            if(OPCODE == `SHAOPCODE) begin
                case(FUNC)
                    `SHAKE_seedaddrset_FUNC: begin
                        SEED_BASE_ADDR <= {17'd0,instr[24:10]};
                    end
                    `SHAKE_seedset_FUNC: begin
                        absorb_num <= instr[17:10];
                        last_block_bytes <= instr[25:18];
                        shakemode <= instr[25];
                        sha3_start <= 1'b1;
                        shakebusy <= 1'b1;
                    end
                    `SHAKE_squeezeonce_FUNC: begin
                        sha3_squeezeonce <= 1'b1;
                        shakebusy <= 1'b1;
                    end
                    `SHAKE_dumponce_FUNC: begin
                        sha3_dumponce <= 1'b1;
                        shakebusy <= 1'b1;
                        dump_BASE_addr <= instr[24:10];
                        dumpram_id <= instr[25];
                    end
                    default: begin

                    end
                endcase
            end
            if(sha3_start) begin
                sha3_start <= 1'b0;
            end
            if(sha3_squeezeonce) begin
                sha3_squeezeonce <= 1'b0;
            end
            if(sha3_ready && !sha3_dumponce && OPCODE != `SHAOPCODE && !sha3_squeezeonce) begin
                shakebusy <= 1'b0;
            end
            if(sha3_dumponce) begin
                sha3_dumponce <= 1'b0;
            end
        end
    end

    sha3_ctrl u_sha3_ctrl(
                  .clk              	(clk               ),
                  .rst_n            	(rst_n             ),
                  .seed_data_in     	(seed_data_in      ),
                  .absorb_num       	(absorb_num        ),
                  .last_block_bytes 	(last_block_bytes  ),
                  .sha3_start       	(sha3_start        ),
                  .sha3_squeezeonce 	(sha3_squeezeonce  ),
                  .sha3_dumponce    	(sha3_dumponce     ),
                  .shakemode        	(shakemode         ),
                  .sha3_sample_addr 	(sha3_sample_addr  ),
                  .sha3_ready       	(sha3_ready        ),
                  .sha3_optready    	(sha3_optready     ),
                  .sha3_data_out    	(sha3_data_out     ),
                  .sha3_addr_perip  	(sha3_addr_perip   ),
                  .dump_wen         	(dump_wen          )
              );


endmodule
