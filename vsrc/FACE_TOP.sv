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
        input logic [1:0] prebusy,

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
        output logic [7:0] sp2_wmask,
        output logic [7:0] dp2_wmask,

        output logic [1:0] bitbusy
    );
    parameter IDLE=4'd0;
    parameter AS_CALC=4'd1,AS_SAVE=4'd2;
    parameter SA_LOADWEIGHT=4'd3,SA_CALC=4'd4;
    parameter AS = 2'b00 , SB = 2'b01 , BS = 2'b10 , SA = 2'b11;
    assign bitbusy = {systolic_busy,sha3busy};
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
    logic inpack_REG, outpack_REG;
    logic systolic_busy;
    assign BASE_ADDR = instr[30:12];
    assign FUNC = instr[9:7];
    assign OPCODE = instr[6:0];
    logic sha3busy;
    //systolic_addr_set
    /* verilator lint_off CASEINCOMPLETE */
    logic [31:0] absorb_genA_addr;
    assign setaddr = instr[11:10];
    assign ctrl_mode = instr[11:10];
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            systolic_busy <= 1'b0;
            sha3busy <= 1'b0;
        end
        else begin
            if(systolic_done) begin
                systolic_busy <= 1'b0;
            end
            else begin
                if(~systolic_busy)
                    systolic_busy <=prebusy[1];
            end

            if((sha3_ready_rise && OPCODE != `SHAOPCODE && !sha3_squeezeonce) || sampling_wen || sha3_wait_cmd) begin
                sha3busy <= 1'b0;
            end
            else begin
                if(~sha3busy)
                    sha3busy <= prebusy[0];
            end
        end
    end
    logic sha3_ready_d,sha3_ready_rise;
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sha3_ready_d <= 1'b0;
        end
        else begin
            sha3_ready_d <= sha3_ready;
        end
    end
    assign sha3_ready_rise = sha3_ready && !sha3_ready_d;
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            BASE_ADDR_LEFT <= 32'd0;
            BASE_ADDR_RIGHT <= 32'd0;
            BASE_ADDR_ADDSRC <= 32'd0;
            BASE_ADDR_SAVE <= 32'd0;
            calc_init <= 1'b0;
            ctrl_mode_REG <= 2'b00;
            inpack_REG <= 1'b0;
            outpack_REG <= 1'b0;
            hash_buffer_sel <= 1'b0;
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
                if(!systolic_busy ||1'b1) begin
                    ctrl_mode_REG <= ctrl_mode;
                    inpack_REG <= instr[24];
                    outpack_REG <= instr[23];
                    calc_init <= 1'b1;
                    MATRIX_SIZE <= instr[22:12];
                end
            end
            else begin
                calc_init <= 1'b0;
            end

            if(FUNC == `systolic_bufswap_FUNC && OPCODE == `SYSOPCODE) begin
                hash_buffer_sel <= ~hash_buffer_sel;
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
    //systoilc_data_bus
    logic [2:0] mem_mode;
    logic calc_init;
    logic [31:0] addr_HASH_systolic;//脉动阵列读取的HASH地址
    logic [63:0] bram_rdata_HASH;//脉动阵列读取的HASH数据
    //==========================
    // 乒乓缓存读取路由：Systolic 总是读取由 hash_buffer_sel 选中的那一块
    assign bram_rdata_HASH = (hash_buffer_sel == 1'b0) ? bram_rdata_HASH1 : bram_rdata_HASH2;
    //==========================
    assign mem_mode = (ctrl_mode_REG == SA)? 3'd2:3'd1;
    always_comb begin
        addr_HASH_systolic = 32'd0;
        addr_HASH_1 = 32'd0;
        addr_HASH_2 = 32'd0;
        wen_HASH_1 = 1'b0;
        wen_HASH_2 = 1'b0;
        bram_wdata_HASH = 64'd0;

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
       // absorb_genA_addr = SEED_BASE_ADDR + sha3_addr_perip;

        sp2_wmask = 8'hFF;
        dp2_wmask = 8'hFF;
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

                    // 路由到对应的物理 HASH BRAM
                    if(hash_buffer_sel == 1'b0)
                        addr_HASH_1 = addr_HASH_systolic;
                    else
                        addr_HASH_2 = addr_HASH_systolic;
                end
                AS_CALC: begin
                    if(ctrl_mode_REG == AS) begin
                        addr_HASH_systolic = bram_addr_1;
                        addr_sp_1 = bram_addr_2;
                        bram_data_1 = bram_rdata_HASH;
                        bram_data_2 = bram_rdata_sp_1;

                        // 路由到对应的物理 HASH BRAM
                        if(hash_buffer_sel == 1'b0)
                            addr_HASH_1 = addr_HASH_systolic;
                        else
                            addr_HASH_2 = addr_HASH_systolic;
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
            if(sha3busy) begin
                if(absorb_genA_active) begin
                    addr_sp_1 = absorb_genA_addr;
                    if(MATRIX_sign) begin
                        if(absorb_genA_state == 4'd4)
                            seed_data_in = {seed_A_buffer[47:0], row_index_reg};
                        else if(absorb_genA_state == 4'd5)
                            seed_data_in = {seed_A_buffer[47:0],seed_A_buffer[127:112]};
                        else
                            seed_data_in = {48'd0,seed_A_buffer[127:112]};
                    end
                    else begin
                        if(absorb_genA_state == 4'd4)
                            seed_data_in = {seed_A_buffer[55:0], 8'h5F};
                        else if(absorb_genA_state <block_num + 4'd4)
                            seed_data_in = {seed_A_buffer[55:0],seed_A_buffer[127:120]};
                        else
                            seed_data_in = {56'd0,seed_A_buffer[127:120]};
                    end
                end
                else begin
                    addr_sp_1 = sha3_addr_perip + SEED_BASE_ADDR;
                    seed_data_in = bram_rdata_sp_1;
                end

                if (sample_mode == 2'd1) begin
                    // genA 特殊处理：写入到当前未被 Systolic 占用的 HASH Buffer
                    bram_wdata_HASH = final_sha3_data_out;
                    if (hash_buffer_sel == 1'b0) begin
                        addr_HASH_2 = dump_addr;
                        wen_HASH_2 = sampling_wen;
                    end
                    else begin
                        addr_HASH_1 = dump_addr;
                        wen_HASH_1 = sampling_wen;
                    end
                end
                else if(dumpram_id == 1'b0) begin
                    // 其他指令（genSE等）维持原有 RAM 路由
                    addr_sp_2 = (sample_mode != 2'd0) ? dump_addr : (dump_addr + sha3_addr_perip);
                    wen_sp_2 = sampling_wen;
                    //wen_sp_2 =1; // 只在采样时写入，dump操作由外部控制写使能
                    if(sample_mode == 2'd2 && !is_e_matrix_reg) begin
                        bram_wdata_sp_2 = (addr_sp_2[2] == 1'b0) ? {32'd0, final_sha3_data_out[31:0]} : {final_sha3_data_out[31:0],32'd0};
                        sp2_wmask = (addr_sp_2[2] == 1'b0) ? 8'h0F : 8'hF0; // 根据地址最低位选择写入半个字
                    end
                    else
                        bram_wdata_sp_2 = final_sha3_data_out;
                end
                else begin
                    addr_dp_2 = (sample_mode != 2'd0) ? dump_addr : (dump_addr + sha3_addr_perip);
                    wen_dp_2 = sampling_wen;
                    if(sample_mode == 2'd2 && !is_e_matrix_reg) begin
                        bram_wdata_dp_2 = (addr_dp_2[2] == 1'b0) ? {32'd0, final_sha3_data_out[31:0]} : {final_sha3_data_out[31:0],32'd0};
                        dp2_wmask = (addr_dp_2[2] == 1'b0) ? 8'h0F : 8'hF0; // 根据地址最低位选择写入半个字
                    end
                    else
                        bram_wdata_dp_2 = final_sha3_data_out;
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
                .inpack           	(inpack_REG        ),
                .outpack          	(outpack_REG       ),
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
    logic sha3_absorb;          // 新增：absorb触发信号
    logic [7:0] seg_absorb_num; // 新增：本段吸收块数
    logic [4:0] last_block_words;// 新增：本段最后块字数

    logic [4:0] sha3_sample_addr;
    logic sha3_ready;
    logic sha3_optready;
    logic sha3_wait_cmd;
    logic sha3_processing;
    logic [63:0] sha3_data_out;
    logic [31:0] sha3_addr_perip;

    logic [31:0] SEED_BASE_ADDR;
    logic [7:0] absorb_num,last_block_bytes;

    logic shakemode; // 0: SHAKE128, 1: SHAKE256

    logic [14:0] dump_BASE_addr;
    logic dumpram_id;
    logic [31:0] dump_addr;
    logic [1:0] sample_mode;
    logic [1:0] frodo_mode_reg;
    logic is_e_matrix_reg; // 新增：区分 S 矩阵(8-bit)和 E 矩阵(16-bit)

    logic [15:0] row_index_reg;
    logic [127:0] seed_A_buffer;
    logic absorb_genA_active;
    logic [3:0] absorb_genA_state;
    logic sampling_wen; // 新增：采样单周期写使能

    logic [3:0] block_num;
    logic hash_buffer_sel; // 0: Systolic->HASH1, SHAKE->HASH2 | 1: Systolic->HASH2, SHAKE->HASH1
    logic MATRIX_sign;
    assign dump_addr = {17'd0,dump_BASE_addr};

    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            SEED_BASE_ADDR <= 32'd0;
            absorb_num <= 8'd0;
            last_block_bytes <= 8'd0;
            sha3_start <= 1'b0;
            sha3_squeezeonce <= 1'b0;
            sha3_absorb <= 1'b0;
            seg_absorb_num <= 8'd0;
            last_block_words <= 5'd0;
            shakemode <= 1'b0;
            dump_BASE_addr <= 15'd0;
            dumpram_id <= 1'b0;
            sample_mode <= 2'd0;
            frodo_mode_reg <= 2'd0;
            row_index_reg <= 16'd0;
            absorb_genA_active <= 1'b0;
            absorb_genA_state <= 4'd0;
            seed_A_buffer <= 128'd0;
            sha3_sample_addr <= 5'd0;
            sampling_wen <= 1'b0;
            MATRIX_sign <= 1'b0;
            absorb_genA_addr <= 32'd0;
        end
        else begin
            if(OPCODE == `SHAOPCODE) begin
                case(FUNC)
                    `SHAKE_seedaddrset_FUNC: begin
                        SEED_BASE_ADDR <= {17'd0,instr[24:10]};
                        shakemode <= instr[25];
                    end
                    `SHAKE_seedset_FUNC: begin
                        absorb_num <= instr[17:10];
                        last_block_bytes <= instr[25:18];
                        sha3_start <= 1'b1;
                        absorb_genA_active <= 1'b0;
                    end
                    `SHAKE_squeezeonce_FUNC: begin
                        sha3_squeezeonce <= 1'b1;
                    end
                    `SHAKE_absorb_FUNC: begin
                        sha3_absorb <= 1'b1;
                        seg_absorb_num <= instr[17:10];
                        last_block_words <= instr[22:18];
                    end
                    `SHAKE_gen_A_FUNC: begin
                        sampling_wen <= 1'b1;
                        dump_BASE_addr <= instr[24:10];
                        // dumpram_id <= instr[25]; // Removed
                        sample_mode <= 2'd1;
                        frodo_mode_reg <= instr[31:30];
                        sha3_sample_addr <= instr[29:25];
                    end
                    `SHAKE_gen_SE_FUNC: begin
                        sampling_wen <= 1'b1;
                        dump_BASE_addr <= {instr[22:10], 2'b0};
                        dumpram_id <= instr[24];
                        is_e_matrix_reg <= instr[23];
                        sample_mode <= 2'd2;
                        frodo_mode_reg <= instr[31:30];
                        sha3_sample_addr <= instr[29:25];
                    end
                    `SHAKE_dumpaword_FUNC: begin
                        sampling_wen <= 1'b1;
                        dump_BASE_addr <= instr[24:10];
                        sample_mode <= 2'd0;
                        sha3_sample_addr <= instr[29:25];
                    end
                    `SHAKE_absorb_genA_FUNC: begin
                        row_index_reg <= instr[25:10];
                        block_num <= instr[29:26];
                        MATRIX_sign <= instr[31];
                        absorb_genA_active <= 1'b1;
                        absorb_genA_state <= 4'd1;
                        sha3_start <= 1'b1;
                    end
                    default:
                        ;
                endcase
            end

            // 自动清除单周期脉冲
            if(sampling_wen)
                sampling_wen <= 1'b0;

            case(absorb_genA_state)
                4'd0: begin

                end
                4'd1: begin
                    absorb_genA_state <= 4'd2;
                    sha3_absorb <= 1'b1;
                    if(MATRIX_sign) begin
                        last_block_bytes <= block_num * 4'd8 + 8'd2;
                        last_block_words <= 5'((block_num * 4'd8 + 8'd2) >> 3);
                    end else begin
                        last_block_bytes <= block_num * 4'd8 + 8'd1;
                        last_block_words <= 5'((block_num * 4'd8 + 8'd1) >> 3);
                    end
                    absorb_genA_addr <= SEED_BASE_ADDR; 
                end 
                4'd2: begin
                    absorb_genA_state <= 4'd3;
                    seed_A_buffer[63:0] <= bram_rdata_sp_1;
                    seed_A_buffer[127:64] <= seed_A_buffer[63:0];
                    absorb_genA_addr <= absorb_genA_addr + 32'd8;
                end
                4'd3: begin
                    seed_A_buffer[63:0] <= bram_rdata_sp_1;
                    seed_A_buffer[127:64] <= seed_A_buffer[63:0];
                    absorb_genA_state <= 4'd4;
                    absorb_genA_addr <= absorb_genA_addr + 32'd8;
                end
                4'd4: begin
                    seed_A_buffer[63:0] <= bram_rdata_sp_1;
                    seed_A_buffer[127:64] <= seed_A_buffer[63:0];
                    absorb_genA_state <= 4'd5;
                    absorb_num <= 8'd1;
                    seg_absorb_num <= 8'd1;
                    absorb_genA_addr <= absorb_genA_addr + 32'd8;
                end
                default: begin
                    seed_A_buffer[63:0] <= bram_rdata_sp_1;
                    seed_A_buffer[127:64] <= seed_A_buffer[63:0];
                    absorb_genA_state <= absorb_genA_state + 4'd1;
                    absorb_num <= 8'd1;
                    absorb_genA_addr <= absorb_genA_addr + 32'd8;
                end
            endcase

            if(sha3_start)
                sha3_start <= 1'b0;
            if(sha3_squeezeonce)
                sha3_squeezeonce <= 1'b0;
            if(sha3_absorb)
                sha3_absorb <= 1'b0;
        end
    end

    logic [63:0] sampler_A_out, sampler_SE_out, final_sha3_data_out;

    A_sampler u_A_sampler(
                  .frodo_mode(frodo_mode_reg),
                  .shake_data(sha3_data_out),
                  .a_data(sampler_A_out)
              );

    SE_sampler u_SE_sampler(
                   .frodo_mode(frodo_mode_reg),
                   .is_e_matrix(is_e_matrix_reg),
                   .shake_data(sha3_data_out),
                   .se_data(sampler_SE_out)
               );

    always_comb begin
        case(sample_mode)
            2'd1:
                final_sha3_data_out = sampler_A_out;
            2'd2:
                final_sha3_data_out = sampler_SE_out;
            default:
                final_sha3_data_out = sha3_data_out;
        endcase
    end
    sha3_ctrl u_sha3_ctrl(
                  .clk              	(clk               ),
                  .rst_n            	(rst_n             ),
                  .seed_data_in     	(seed_data_in ),
                  .absorb_num       	(absorb_num        ),
                  .last_block_bytes 	(last_block_bytes  ),
                  .sha3_start       	(sha3_start        ),
                  .sha3_absorb      	(sha3_absorb       ),
                  .seg_absorb_num   	(seg_absorb_num    ),
                  .last_block_words 	(last_block_words  ),
                  .sha3_squeezeonce 	(sha3_squeezeonce  ),
                  .shakemode        	(shakemode         ),
                  .sha3_sample_addr 	(sha3_sample_addr  ),
                  .sha3_ready       	(sha3_ready        ),
                  .sha3_optready    	(sha3_optready     ),
                  .sha3_wait_cmd    	(sha3_wait_cmd     ),
                  .sha3_processing  	(sha3_processing   ),
                  .sha3_data_out    	(sha3_data_out     ),
                  .sha3_addr_perip  	(sha3_addr_perip   )
              );


endmodule
