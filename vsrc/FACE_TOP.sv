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

    /* verilator lint_off CASEINCOMPLETE */

    // ------------------------------------------------------------------------
    // Local parameters / state encoding
    // ------------------------------------------------------------------------
    parameter IDLE = 4'd0;
    parameter AS_CALC = 4'd1, AS_SAVE = 4'd2;
    parameter SA_LOADWEIGHT = 4'd3, SA_CALC = 4'd4;
    parameter AS = 2'b00, SB = 2'b01, BS = 2'b10, SA = 2'b11;

    localparam [2:0] GENA_IDLE = 3'd0,
                     GENA_ROW_PREP = 3'd1,
                     GENA_WAIT_ABSORB = 3'd2,
                     GENA_SAMPLE_REQ = 3'd3,
                     GENA_SAMPLE_DONE = 3'd4,
                     GENA_ISSUE_SQ = 3'd5,
                     GENA_WAIT_SQ = 3'd6;

    // ------------------------------------------------------------------------
    // Instruction decode signals
    // ------------------------------------------------------------------------
    logic [18:0] BASE_ADDR;
    logic [10:0] MATRIX_SIZE;
    logic [6:0] OPCODE;
    logic [2:0] FUNC;
    logic [1:0] setaddr;   // 控制设置的 BASE_ADDR 是哪一个
    logic [1:0] ctrl_mode;

    // ------------------------------------------------------------------------
    // Busy / status signals
    // ------------------------------------------------------------------------
    logic sha3busy;
    logic systolic_busy;
    logic systolic_done;
    logic [3:0] last_state;

    logic sha3_ready_d;
    logic sha3_ready_rise;

    // ------------------------------------------------------------------------
    // Systolic path registers / wires
    // ------------------------------------------------------------------------
    logic [31:0] bram_addr_1;
    logic [31:0] bram_addr_2;
    logic [31:0] bram_addr_3;
    logic [63:0] bram_data_1;
    logic [63:0] bram_data_2;
    logic [63:0] bram_data_3;
    logic save_wen;
    logic [63:0] bram_savedata;
    logic [3:0] current_state;
    logic calc_init;

    logic [31:0] BASE_ADDR_LEFT;
    logic [31:0] BASE_ADDR_RIGHT;
    logic [31:0] BASE_ADDR_ADDSRC;
    logic [31:0] BASE_ADDR_SAVE;
    logic [1:0] ctrl_mode_REG;
    logic inpack_REG;
    logic inpack_right_REG;
    logic outpack_REG;

    logic hash_buffer_sel;  // 0: Systolic->HASH1, SHAKE->HASH2 | 1: Systolic->HASH2, SHAKE->HASH1
    logic [31:0] addr_HASH_systolic;
    logic [63:0] bram_rdata_HASH;

    // ------------------------------------------------------------------------
    // SHA3 controller interface
    // ------------------------------------------------------------------------
    logic [63:0] seed_data_in;
    logic sha3_start;
    logic sha3_squeezeonce;
    logic sha3_absorb;
    logic [7:0] seg_absorb_num;
    logic [4:0] last_block_words;

    logic [4:0] sha3_sample_addr;
    logic sha3_ready;
    logic sha3_optready;
    logic sha3_wait_cmd;
    logic sha3_processing;
    logic [63:0] sha3_data_out;
    logic [31:0] sha3_addr_perip;

    logic [31:0] SEED_BASE_ADDR;
    logic [7:0] absorb_num;
    logic [7:0] last_block_bytes;
    logic shakemode;  // 0: SHAKE128, 1: SHAKE256
    logic seedram_id;  // 0: SP_RAM, 1: DP_RAM
    logic [63:0] seedram_rdata;

    // ------------------------------------------------------------------------
    // Sampling / dump / genA control
    // ------------------------------------------------------------------------
    logic [14:0] dump_BASE_addr;
    logic dumpram_id;
    logic [31:0] dump_addr;
    logic [1:0] sample_mode;
    logic [1:0] frodo_mode_reg;
    logic is_e_matrix_reg;  // 区分 S 矩阵(8-bit)和 E 矩阵(16-bit)

    logic [15:0] row_index_reg;
    logic [127:0] seed_A_buffer;
    logic absorb_genA_active;
    logic [3:0] absorb_genA_state;
    logic sampling_wen;  // 采样单周期写使能

    logic [3:0] block_num;
    logic MATRIX_sign;
    logic absorb_genA_pad_sel;  // 0: append 8'h5F, 1: append 8'h96

    // 流水对齐：sha3_data_out 已在 sha3_ctrl 中插入 1 拍寄存器，
    // 写使能和地址也需延迟 1 拍以保持对齐
    logic        sampling_wen_d;
    logic [31:0] dump_addr_d;

    logic genA_loop_active;
    logic genA_loop_done_pulse;
    logic [2:0] genA_loop_state;
    logic genA_row_len_flag;  // 0:1344, 1:976
    logic [14:0] genA_curr_addr;
    logic [15:0] genA_work_row_index;
    logic [1:0] genA_row_idx;
    logic [8:0] genA_word_idx;
    logic [8:0] genA_row_words;
    logic [11:0] genA_row_stride;
    logic [4:0] genA_sample_offset;
    logic [31:0] absorb_genA_addr;

    // ------------------------------------------------------------------------
    // Sampler outputs
    // ------------------------------------------------------------------------
    logic [63:0] sampler_A_out;
    logic [63:0] sampler_SE_out;
    logic [63:0] final_sha3_data_out;

    // ------------------------------------------------------------------------
    // Continuous assignments
    // ------------------------------------------------------------------------
    assign BASE_ADDR = instr[30:12];
    assign FUNC = instr[9:7];
    assign OPCODE = instr[6:0];
    assign setaddr = instr[11:10];
    assign ctrl_mode = instr[11:10];

    assign dump_addr = {17'd0, dump_BASE_addr};
    assign bram_rdata_HASH = (hash_buffer_sel == 1'b0) ? bram_rdata_HASH1 : bram_rdata_HASH2;
    assign seedram_rdata = (seedram_id == 1'b0) ? bram_rdata_sp_1 : bram_rdata_dp_1;
    assign bitbusy = {systolic_busy, sha3busy};
    assign sha3_ready_rise = sha3_ready && !sha3_ready_d;

    // ------------------------------------------------------------------------
    // Submodule instantiation
    // ------------------------------------------------------------------------
    mul_top u_mul_top(
        .clk              (clk),
        .rst_n            (rst_n),
        .calc_init        (calc_init),
        .ctrl_mode        (ctrl_mode_REG),
        .inpack           (inpack_REG),
        .inpack_right     (inpack_right_REG),
        .outpack          (outpack_REG),
        .bram_data_1      (bram_data_1),
        .bram_data_2      (bram_data_2),
        .bram_data_3      (bram_data_3),
        .BASE_ADDR_LEFT   (BASE_ADDR_LEFT),
        .BASE_ADDR_RIGHT  (BASE_ADDR_RIGHT),
        .BASE_ADDR_ADDSRC (BASE_ADDR_ADDSRC),
        .BASE_ADDR_SAVE   (BASE_ADDR_SAVE),
        .MATRIX_SIZE      (MATRIX_SIZE),
        .bram_addr_1      (bram_addr_1),
        .bram_addr_2      (bram_addr_2),
        .bram_addr_3      (bram_addr_3),
        .current_state    (current_state),
        .save_wen         (save_wen),
        .bram_savedata    (bram_savedata)
    );

    A_sampler u_A_sampler(
        .frodo_mode (frodo_mode_reg),
        .shake_data (sha3_data_out),
        .a_data     (sampler_A_out)
    );

    SE_sampler u_SE_sampler(
        .frodo_mode  (frodo_mode_reg),
        .is_e_matrix (is_e_matrix_reg),
        .shake_data  (sha3_data_out),
        .se_data     (sampler_SE_out)
    );

    sha3_ctrl u_sha3_ctrl(
        .clk              (clk),
        .rst_n            (rst_n),
        .seed_data_in     (seed_data_in),
        .absorb_num       (absorb_num),
        .last_block_bytes (last_block_bytes),
        .sha3_start       (sha3_start),
        .sha3_absorb      (sha3_absorb),
        .seg_absorb_num   (seg_absorb_num),
        .last_block_words (last_block_words),
        .sha3_squeezeonce (sha3_squeezeonce),
        .shakemode        (shakemode),
        .sha3_sample_addr (sha3_sample_addr),
        .sha3_ready       (sha3_ready),
        .sha3_optready    (sha3_optready),
        .sha3_wait_cmd    (sha3_wait_cmd),
        .sha3_processing  (sha3_processing),
        .sha3_data_out    (sha3_data_out),
        .sha3_addr_perip  (sha3_addr_perip)
    );

    // ------------------------------------------------------------------------
    // Combinational logic
    // ------------------------------------------------------------------------

    // SHA3 输出在原始数据 / A 采样 / SE 采样之间复用
    always_comb begin
        case (sample_mode)
            2'd1: final_sha3_data_out = sampler_A_out;
            2'd2: final_sha3_data_out = sampler_SE_out;
            default: final_sha3_data_out = sha3_data_out;
        endcase
    end

    // BRAM 路由与写回控制
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

        sp2_wmask = 8'hFF;
        dp2_wmask = 8'hFF;

        if (systolic_busy) begin
            case (current_state)
                SA_LOADWEIGHT: begin
                    // 从 dp 中读取 data
                    addr_dp_1 = bram_addr_1;
                    bram_data_1 = bram_rdata_dp_1;
                end
                SA_CALC: begin
                    // 从 dp 中读取/写回，同时从 HASH 中读取权重
                    addr_dp_1 = bram_addr_1;
                    addr_dp_2 = bram_addr_2;
                    addr_HASH_systolic = bram_addr_3;
                    bram_data_1 = bram_rdata_dp_1;
                    bram_wdata_dp_2 = bram_savedata;
                    wen_dp_2 = save_wen;
                    bram_data_3 = bram_rdata_HASH;

                    if (hash_buffer_sel == 1'b0)
                        addr_HASH_1 = addr_HASH_systolic;
                    else
                        addr_HASH_2 = addr_HASH_systolic;
                end
                AS_CALC: begin
                    if (ctrl_mode_REG == AS) begin
                        addr_HASH_systolic = bram_addr_1;
                        addr_sp_1 = bram_addr_2;
                        bram_data_1 = bram_rdata_HASH;
                        bram_data_2 = bram_rdata_sp_1;

                        if (hash_buffer_sel == 1'b0)
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
                    if (ctrl_mode_REG == AS) begin
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
        else if (sha3busy) begin
            if (absorb_genA_active) begin
                if (seedram_id == 1'b0)
                    addr_sp_1 = absorb_genA_addr;
                else
                    addr_dp_1 = absorb_genA_addr;

                if (MATRIX_sign) begin
                    if (absorb_genA_state == 4'd4)
                        seed_data_in = {seed_A_buffer[47:0], row_index_reg};
                    else if (absorb_genA_state == 4'd5)
                        seed_data_in = {seed_A_buffer[47:0], seed_A_buffer[127:112]};
                    else
                        seed_data_in = {48'd0, seed_A_buffer[127:112]};
                end
                else begin
                    if (absorb_genA_state == 4'd4)
                        seed_data_in = {seed_A_buffer[55:0], absorb_genA_pad_sel ? 8'h96 : 8'h5F};
                    else if (absorb_genA_state < block_num + 4'd4)
                        seed_data_in = {seed_A_buffer[55:0], seed_A_buffer[127:120]};
                    else
                        seed_data_in = {56'd0, seed_A_buffer[127:120]};
                end
            end
            else begin
                if (seedram_id == 1'b0) begin
                    addr_sp_1 = sha3_addr_perip + SEED_BASE_ADDR;
                    seed_data_in = bram_rdata_sp_1;
                end
                else begin
                    addr_dp_1 = sha3_addr_perip + SEED_BASE_ADDR;
                    seed_data_in = bram_rdata_dp_1;
                end
            end

            if (sample_mode == 2'd1) begin
                // genA 特殊处理：写到当前未被 systolic 占用的 HASH buffer
                bram_wdata_HASH = final_sha3_data_out;
                if (hash_buffer_sel == 1'b0) begin
                    addr_HASH_2 = dump_addr_d;
                    wen_HASH_2 = sampling_wen_d;
                end
                else begin
                    addr_HASH_1 = dump_addr_d;
                    wen_HASH_1 = sampling_wen_d;
                end
            end
            else if (dumpram_id == 1'b0) begin
                // 其他指令（genSE 等）维持原有 RAM 路由
                addr_sp_2 = (sample_mode != 2'd0) ? dump_addr_d : (dump_addr_d + sha3_addr_perip);
                wen_sp_2 = sampling_wen_d;

                if (sample_mode == 2'd2 && !is_e_matrix_reg) begin
                    bram_wdata_sp_2 = (addr_sp_2[2] == 1'b0) ?
                        {32'd0, final_sha3_data_out[31:0]} :
                        {final_sha3_data_out[31:0], 32'd0};
                    sp2_wmask = (addr_sp_2[2] == 1'b0) ? 8'h0F : 8'hF0;
                end
                else begin
                    bram_wdata_sp_2 = final_sha3_data_out;
                end
            end
            else begin
                addr_dp_2 = (sample_mode != 2'd0) ? dump_addr_d : (dump_addr_d + sha3_addr_perip);
                wen_dp_2 = sampling_wen_d;

                if (sample_mode == 2'd2 && !is_e_matrix_reg) begin
                    bram_wdata_dp_2 = (addr_dp_2[2] == 1'b0) ?
                        {32'd0, final_sha3_data_out[31:0]} :
                        {final_sha3_data_out[31:0], 32'd0};
                    dp2_wmask = (addr_dp_2[2] == 1'b0) ? 8'h0F : 8'hF0;
                end
                else begin
                    bram_wdata_dp_2 = final_sha3_data_out;
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // Sequential logic
    // ------------------------------------------------------------------------

    // sha3_ready 上升沿检测
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sha3_ready_d <= 1'b0;
        end
        else begin
            sha3_ready_d <= sha3_ready;
        end
    end

    // 流水对齐寄存器：匹配 sha3_data_out 的 1 拍延迟
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sampling_wen_d <= 1'b0;
            dump_addr_d    <= 32'd0;
        end else begin
            sampling_wen_d <= sampling_wen;
            dump_addr_d    <= dump_addr;
        end
    end

    // Systolic 配置命令寄存
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            BASE_ADDR_LEFT <= 32'd0;
            BASE_ADDR_RIGHT <= 32'd0;
            BASE_ADDR_ADDSRC <= 32'd0;
            BASE_ADDR_SAVE <= 32'd0;
            calc_init <= 1'b0;
            ctrl_mode_REG <= 2'b00;
            inpack_REG <= 1'b0;
            inpack_right_REG <= 1'b0;
            outpack_REG <= 1'b0;
            hash_buffer_sel <= 1'b0;
        end
        else begin
            if (FUNC == `systolic_addrset_FUNC && OPCODE == `SYSOPCODE) begin
                case (setaddr)
                    2'b00: BASE_ADDR_LEFT <= {13'd0, BASE_ADDR};
                    2'b01: BASE_ADDR_RIGHT <= {13'd0, BASE_ADDR};
                    2'b10: BASE_ADDR_ADDSRC <= {13'd0, BASE_ADDR};
                    2'b11: BASE_ADDR_SAVE <= {13'd0, BASE_ADDR};
                    default: ;
                endcase
            end

            if (FUNC == `systolic_calc_FUNC && OPCODE == `SYSOPCODE) begin
                if (!systolic_busy || 1'b1) begin
                    ctrl_mode_REG <= ctrl_mode;
                    inpack_REG <= instr[24];
                    inpack_right_REG <= instr[25];
                    outpack_REG <= instr[23];
                    calc_init <= 1'b1;
                    MATRIX_SIZE <= instr[22:12];
                end
            end
            else begin
                calc_init <= 1'b0;
            end

            if (FUNC == `systolic_bufswap_FUNC && OPCODE == `SYSOPCODE) begin
                hash_buffer_sel <= ~hash_buffer_sel;
            end
        end
    end

    // Systolic 完成脉冲检测（IDLE 边沿）
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            systolic_done <= 1'b0;
            last_state <= IDLE;
        end
        else begin
            last_state <= current_state;
            if (last_state != IDLE && current_state == IDLE)
                systolic_done <= 1'b1;
            else
                systolic_done <= 1'b0;
        end
    end

    // SHA3 指令解码与输出脉冲控制
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            SEED_BASE_ADDR <= 32'd0;
            absorb_num <= 8'd0;
            last_block_bytes <= 8'd0;
            sha3_start <= 1'b0;
            sha3_squeezeonce <= 1'b0;
            sha3_absorb <= 1'b0;
            seg_absorb_num <= 8'd0;
            last_block_words <= 5'd0;
            shakemode <= 1'b0;
            seedram_id <= 1'b0;

            dump_BASE_addr <= 15'd0;
            dumpram_id <= 1'b0;
            sample_mode <= 2'd0;
            frodo_mode_reg <= 2'd0;
            sha3_sample_addr <= 5'd0;
            sampling_wen <= 1'b0;
        end
        else begin
            if (OPCODE == `SHAOPCODE) begin
                case (FUNC)
                    `SHAKE_seedaddrset_FUNC: begin
                        SEED_BASE_ADDR <= {17'd0, instr[24:10]};
                        shakemode <= instr[25];
                        seedram_id <= instr[26];
                    end
                    `SHAKE_seedset_FUNC: begin
                        absorb_num <= instr[17:10];
                        last_block_bytes <= instr[25:18];
                        sha3_start <= 1'b1;
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
                        sample_mode <= 2'd1;
                        frodo_mode_reg <= instr[31:30];
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
                        sha3_start <= 1'b1;
                    end
                    default: ;
                endcase
            end

            // 自动清除单周期脉冲（保持原有优先级）
            if (sampling_wen)
                sampling_wen <= 1'b0;

            // absorb_genA 对 SHA3 命令参数的驱动
            if (absorb_genA_active) begin
                if (absorb_genA_state == 4'd1) begin
                    sha3_absorb <= 1'b1;
                    if (MATRIX_sign) begin
                        last_block_bytes <= block_num * 4'd8 + 8'd2;
                        last_block_words <= 5'((block_num * 4'd8 + 8'd2) >> 3);
                    end
                    else begin
                        last_block_bytes <= block_num * 4'd8 + 8'd1;
                        last_block_words <= 5'((block_num * 4'd8 + 8'd1) >> 3);
                    end
                end
                else if (absorb_genA_state == 4'd4) begin
                    absorb_num <= 8'd1;
                    seg_absorb_num <= 8'd1;
                end
                else if (absorb_genA_state != 4'd2 && absorb_genA_state != 4'd3) begin
                    absorb_num <= 8'd1;
                end
            end

            // genA 循环对采样与 squeeze 脉冲的驱动
            if (genA_loop_active) begin
                case (genA_loop_state)
                    GENA_ROW_PREP: begin
                        sha3_start <= 1'b1;
                    end
                    GENA_WAIT_ABSORB: begin
                        if (sha3_ready_rise)
                            sample_mode <= 2'd1;
                    end
                    GENA_SAMPLE_REQ: begin
                        dump_BASE_addr <= genA_curr_addr;
                        sha3_sample_addr <= genA_sample_offset;
                        sampling_wen <= 1'b1;
                    end
                    GENA_ISSUE_SQ: begin
                        sha3_squeezeonce <= 1'b1;
                    end
                    default: begin
                    end
                endcase
            end

            if (sha3_start)
                sha3_start <= 1'b0;
            if (sha3_squeezeonce)
                sha3_squeezeonce <= 1'b0;
            if (sha3_absorb)
                sha3_absorb <= 1'b0;
        end
    end

    // genA/absorb 状态机推进
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_index_reg <= 16'd0;
            absorb_genA_active <= 1'b0;
            absorb_genA_state <= 4'd0;
            seed_A_buffer <= 128'd0;
            MATRIX_sign <= 1'b0;
            absorb_genA_pad_sel <= 1'b0;
            absorb_genA_addr <= 32'd0;

            genA_loop_active <= 1'b0;
            genA_loop_done_pulse <= 1'b0;
            genA_loop_state <= GENA_IDLE;
            genA_row_len_flag <= 1'b0;
            genA_curr_addr <= 15'd0;
            genA_work_row_index <= 16'd0;
            genA_row_idx <= 2'd0;
            genA_word_idx <= 9'd0;
            genA_row_words <= 9'd0;
            genA_row_stride <= 12'd0;
            genA_sample_offset <= 5'd0;
        end
        else begin
            genA_loop_done_pulse <= 1'b0;

            if (OPCODE == `SHAOPCODE) begin
                case (FUNC)
                    `SHAKE_seedset_FUNC: begin
                        absorb_genA_active <= 1'b0;
                    end
                    `SHAKE_gen_A_FUNC: begin
                        genA_row_len_flag <= instr[29];
                        genA_curr_addr <= 15'd0;
                        row_index_reg <= instr[25:10];
                        genA_work_row_index <= instr[25:10];
                        genA_row_idx <= 2'd0;
                        genA_word_idx <= 9'd0;
                        genA_sample_offset <= 5'd0;
                        genA_row_stride <= instr[29] ? 12'd1952 : 12'd2688;
                        genA_loop_active <= 1'b1;
                        genA_loop_state <= GENA_ROW_PREP;
                    end
                    `SHAKE_absorb_genA_FUNC: begin
                        row_index_reg <= instr[25:10];
                        block_num <= instr[29:26];
                        absorb_genA_pad_sel <= instr[30];
                        MATRIX_sign <= instr[31];
                        absorb_genA_active <= 1'b1;
                        absorb_genA_state <= 4'd1;
                        genA_loop_active <= 1'b0;
                    end
                    default: ;
                endcase
            end

            if (absorb_genA_active) begin
                case (absorb_genA_state)
                    4'd1: begin
                        absorb_genA_state <= 4'd2;
                        absorb_genA_addr <= SEED_BASE_ADDR;
                    end
                    4'd2: begin
                        absorb_genA_state <= 4'd3;
                        seed_A_buffer[63:0] <= seedram_rdata;
                        seed_A_buffer[127:64] <= seed_A_buffer[63:0];
                        absorb_genA_addr <= absorb_genA_addr + 32'd8;
                    end
                    4'd3: begin
                        seed_A_buffer[63:0] <= seedram_rdata;
                        seed_A_buffer[127:64] <= seed_A_buffer[63:0];
                        absorb_genA_state <= 4'd4;
                        absorb_genA_addr <= absorb_genA_addr + 32'd8;
                    end
                    4'd4: begin
                        seed_A_buffer[63:0] <= seedram_rdata;
                        seed_A_buffer[127:64] <= seed_A_buffer[63:0];
                        absorb_genA_state <= 4'd5;
                        absorb_genA_addr <= absorb_genA_addr + 32'd8;
                    end
                    default: begin
                        seed_A_buffer[63:0] <= seedram_rdata;
                        seed_A_buffer[127:64] <= seed_A_buffer[63:0];
                        absorb_genA_state <= absorb_genA_state + 4'd1;
                        absorb_genA_addr <= absorb_genA_addr + 32'd8;
                    end
                endcase
            end

            if (absorb_genA_active && (sha3_wait_cmd || sha3_ready_rise)) begin
                absorb_genA_active <= 1'b0;
                absorb_genA_state <= 4'd0;
            end

            if (genA_loop_active) begin
                case (genA_loop_state)
                    GENA_IDLE: begin
                        genA_loop_state <= GENA_ROW_PREP;
                    end
                    GENA_ROW_PREP: begin
                        row_index_reg <= genA_work_row_index;
                        block_num <= 4'd2;
                        MATRIX_sign <= 1'b1;
                        absorb_genA_active <= 1'b1;
                        absorb_genA_state <= 4'd1;
                        genA_row_words <= genA_row_len_flag ? 9'd244 : 9'd336;

                        case (genA_row_idx)
                            2'd0: genA_curr_addr <= 15'd0;
                            2'd1: genA_curr_addr <= {3'd0, genA_row_stride};
                            2'd2: genA_curr_addr <= {2'd0, genA_row_stride, 1'b0};
                            default: genA_curr_addr <= {3'd0, genA_row_stride} + {2'd0, genA_row_stride, 1'b0};
                        endcase

                        genA_word_idx <= 9'd0;
                        genA_sample_offset <= 5'd0;
                        genA_loop_state <= GENA_WAIT_ABSORB;
                    end
                    GENA_WAIT_ABSORB: begin
                        if (sha3_ready_rise)
                            genA_loop_state <= GENA_SAMPLE_REQ;
                    end
                    GENA_SAMPLE_REQ: begin
                        genA_loop_state <= GENA_SAMPLE_DONE;
                    end
                    GENA_SAMPLE_DONE: begin
                        if (genA_word_idx + 9'd1 >= genA_row_words) begin
                            if (genA_row_idx == 2'd3) begin
                                genA_loop_active <= 1'b0;
                                genA_loop_state <= GENA_IDLE;
                                genA_loop_done_pulse <= 1'b1;
                            end
                            else begin
                                genA_row_idx <= genA_row_idx + 2'd1;
                                genA_work_row_index <= genA_work_row_index + 16'd1;
                                genA_loop_state <= GENA_ROW_PREP;
                            end
                        end
                        else begin
                            genA_word_idx <= genA_word_idx + 9'd1;
                            genA_curr_addr <= genA_curr_addr + 15'd8;
                            if (genA_sample_offset == 5'd20) begin
                                genA_sample_offset <= 5'd0;
                                genA_loop_state <= GENA_ISSUE_SQ;
                            end
                            else begin
                                genA_sample_offset <= genA_sample_offset + 5'd1;
                                genA_loop_state <= GENA_SAMPLE_REQ;
                            end
                        end
                    end
                    GENA_ISSUE_SQ: begin
                        genA_loop_state <= GENA_WAIT_SQ;
                    end
                    GENA_WAIT_SQ: begin
                        if (sha3_ready_rise)
                            genA_loop_state <= GENA_SAMPLE_REQ;
                    end
                    default: begin
                        genA_loop_state <= GENA_IDLE;
                    end
                endcase
            end
        end
    end

    // 全局 busy 信号管理
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            systolic_busy <= 1'b0;
            sha3busy <= 1'b0;
        end
        else begin
            if (systolic_done) begin
                systolic_busy <= 1'b0;
            end
            else if (!systolic_busy) begin
                systolic_busy <= prebusy[1];
            end

            if (((sha3_ready_rise && OPCODE != `SHAOPCODE && !sha3_squeezeonce) ||sampling_wen_d || sha3_wait_cmd) && !genA_loop_active) begin
                sha3busy <= 1'b0;
            end
            else if (genA_loop_done_pulse) begin
                sha3busy <= 1'b0;
            end
            else if (!sha3busy) begin
                sha3busy <= prebusy[0];
            end
        end
    end
endmodule
