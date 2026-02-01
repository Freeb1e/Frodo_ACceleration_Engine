module mem_ctrl(
        input logic clk,
        input logic rst_n,
        input logic [2:0] mem_mode,
        input logic calc_init,

        // input logic [31:0] BASE_ADDR_S,
        // input logic [31:0] BASE_ADDR_HASH,
        // input logic [31:0] BASE_ADDR_B,

        input logic [31:0] BASE_ADDR_LEFT,
        input logic [31:0] BASE_ADDR_RIGHT,
        input logic [31:0] BASE_ADDR_ADDSRC,
        input logic [31:0] BASE_ADDR_SAVE,
        input logic [10:0] MATRIX_SIZE,

        // input logic [63:0] bram_data_sb,
        // input logic [63:0] bram_data_HASH,
        // input logic [63:0] bram_data_sb_2,

        // output logic [31:0] addr_sb,
        // output logic [31:0] addr_HASH,
        // output logic [31:0] addr_sb_2,

        input logic [63:0] bram_data_1,
        input logic [63:0] bram_data_2,
        input logic [63:0] bram_data_3,

        output logic [31:0] bram_addr_1,
        output logic [31:0] bram_addr_2,
        output logic [31:0] bram_addr_3,

        output logic save_wen,

        output logic [63:0] data_left,
        output logic [63:0] data_right,

        output logic systolic_state,
        output logic systolic_mode,
        output logic systolic_enable,
        output logic [63:0] data_adder,

        output logic [3:0] current_state,

        output logic transposition_slect,
        output logic transposition_rst_sync
    );
    parameter IDLE=4'd0;
    parameter AS_CALC=4'd1,AS_SAVE=4'd2;
    parameter SA_LOADWEIGHT=4'd3,SA_CALC=4'd4;
    logic [31:0] matrix_size_reg;
    //state machine
    logic [3:0] next_state;
    logic [31:0] Frodo_standard_A , Frodo_standard_SE;
    // logic [31:0] BASE_ADDR_B_REG, BASE_ADDR_S_REG, BASE_ADDR_HASH_REG;
    logic [31:0] BASE_ADDR_LEFT_REG, BASE_ADDR_RIGHT_REG, BASE_ADDR_ADDSRC_REG, BASE_ADDR_SAVE_REG;
    logic counter_init;
    logic [31:0] cnt_line;
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_state<= IDLE;
            matrix_size_reg<= '0;
        end
        else begin
            if(calc_init) begin
                /* verilator lint_off WIDTHEXPAND */
                matrix_size_reg<=MATRIX_SIZE;
                Frodo_standard_A <= MATRIX_SIZE * 32'd64;
                Frodo_standard_SE <= MATRIX_SIZE * 32'd32;
                // BASE_ADDR_B_REG <= BASE_ADDR_B;
                // BASE_ADDR_S_REG <= BASE_ADDR_S;
                // BASE_ADDR_HASH_REG <= BASE_ADDR_HASH;
                BASE_ADDR_LEFT_REG <= BASE_ADDR_LEFT;
                BASE_ADDR_RIGHT_REG <= BASE_ADDR_RIGHT;
                BASE_ADDR_ADDSRC_REG <= BASE_ADDR_ADDSRC;
                BASE_ADDR_SAVE_REG <= BASE_ADDR_SAVE;
                /* verilator lint_on WIDTHEXPAND */
            end
            current_state<= next_state;
        end
    end
    assign systolic_enable = 1'b1;
    /* verilator lint_off WIDTH */
    always_comb begin
        counter_init = 1'b0;
        case (current_state)
            IDLE: begin
                if(calc_init) begin
                    next_state=(mem_mode == 3'd1) ? AS_CALC : SA_LOADWEIGHT;
                end
                else begin
                    next_state=IDLE;
                end
            end
            AS_CALC: begin
                if(cnt_line == matrix_size_reg) begin
                    next_state=AS_SAVE;
                end
                else begin
                    next_state=AS_CALC;
                end
            end
            AS_SAVE:
                if(cnt_line == matrix_size_reg + 4 && count_4==2'b11) begin
                    next_state=IDLE;
                end
                else
                    next_state=AS_SAVE;
            SA_LOADWEIGHT: begin
                if(cnt_line == 32'd1) begin
                    next_state=SA_CALC;
                    counter_init =1'b1;
                end
                else
                    next_state=SA_LOADWEIGHT;
            end
            SA_CALC: begin
                if(cnt_line == matrix_size_reg + 4 && count_4==2'b1) begin
                    next_state=IDLE;
                end else
                next_state=SA_CALC;
            end
            default:
                next_state=IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            systolic_mode <= 1'b0;
            systolic_state <= 1'b0;
        end
        else begin // 0:数据传输 1:计算
            if(calc_init) begin
                systolic_mode <= (mem_mode == 3'd1) ? 1'b1 : 1'b0;
            end
            case(current_state)
                AS_CALC:
                    systolic_state <= 1'b1;
                AS_SAVE: begin
                    if(cnt_line==matrix_size_reg + 32'd2 && count_4==2'b11) begin
                        systolic_state <= 1'b0;
                    end
                end
                SA_LOADWEIGHT: begin
                    systolic_state <= 1'b0;
                end
                SA_CALC: begin
                    systolic_state <= 1'b1;
                end
                default: begin
                    systolic_state <= systolic_state;
                end
            endcase
        end
    end
    logic [1:0] count_4;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            count_4<=2'b0;
        end
        else begin
            if(calc_init || counter_init) begin
                count_4 <= 2'b0;
            end
            else begin
                count_4 <=count_4 + 2'b1;
            end
        end
    end

    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_line<='b0;
        end
        else begin
            if(calc_init || counter_init) begin
                cnt_line<='b0;
            end
            else begin
                if(count_4==2'b11) begin
                    if(cnt_line==matrix_size_reg + 32'd4)
                        cnt_line<=32'b0;
                    else
                        cnt_line<=cnt_line+32'b1;
                end
            end
        end
    end

    logic [1:0] save_bias,save_bias_w;
    assign save_bias = 2'b10 - count_4;
    assign save_bias_w = save_bias+2'd2;
    logic [1:0] save_bias_SA;
    assign save_bias_SA = count_4-2'd2;
    /* verilator lint_off WIDTH */
    always_comb begin
        bram_addr_1 = 32'd0;
        bram_addr_2 = 32'd0;
        bram_addr_3 = 32'd0;
        case(current_state)
            AS_CALC: begin
                // addr_HASH =BASE_ADDR_HASH_REG+cnt_line*32'd64+count_4*Frodo_standard_A;
                // addr_sb = BASE_ADDR_S_REG+cnt_line*32'd32+count_4*Frodo_standard_SE;
                bram_addr_1 = BASE_ADDR_LEFT_REG+cnt_line*32'd64+count_4*Frodo_standard_A;
                bram_addr_2 = BASE_ADDR_RIGHT_REG+cnt_line*32'd32+count_4*Frodo_standard_SE;
            end
            AS_SAVE: begin
                // addr_sb = BASE_ADDR_B_REG +save_bias*16*8;
                // addr_sb_2 = BASE_ADDR_B_REG +(save_bias_w)*16*8;
                bram_addr_1 = BASE_ADDR_ADDSRC_REG + save_bias*16*8;
                bram_addr_2 = BASE_ADDR_SAVE_REG + (save_bias_w)*16*8;
            end
            SA_LOADWEIGHT: begin
                // addr_sb = BASE_ADDR_S + (2'd3-count_4)*Frodo_standard_SE;
                bram_addr_1 = BASE_ADDR_LEFT_REG + (2'd3-count_4)*Frodo_standard_SE;
            end
            SA_CALC: begin
                // addr_HASH = BASE_ADDR_HASH_REG + cnt_line*32'd64 + count_4*Frodo_standard_A;
                // if(count_4==2 || count_4 == 3)
                //     addr_sb_2 = BASE_ADDR_B_REG + (cnt_line-32'd4) * 32'd64 + save_bias_SA*Frodo_standard_A;
                // else
                //     addr_sb_2 = BASE_ADDR_B_REG + (cnt_line-32'd5) * 32'd64 + save_bias_SA*Frodo_standard_A;
                // addr_sb=BASE_ADDR_B_REG + (cnt_line-32'd4) * 32'd64 + count_4*Frodo_standard_A;
                bram_addr_3 = BASE_ADDR_RIGHT_REG + cnt_line*32'd64 + count_4*Frodo_standard_A;
                if(count_4==2 || count_4 == 3)
                    bram_addr_2 = BASE_ADDR_SAVE_REG + (cnt_line-32'd4) * 32'd64 + save_bias_SA*Frodo_standard_A;
                else
                    bram_addr_2 = BASE_ADDR_SAVE_REG + (cnt_line-32'd5) * 32'd64 + save_bias_SA*Frodo_standard_A;
                bram_addr_1 = BASE_ADDR_ADDSRC_REG + (cnt_line-32'd4) * 32'd64 + count_4*Frodo_standard_A;
            end
            default: begin
                bram_addr_1 = 32'd0;
                bram_addr_2 = 32'd0;
                bram_addr_3 = 32'd0;
            end
        endcase
    end
    /* verilator lint_on WIDTH */
    always_comb begin
      //  data_adder = bram_data_sb;
          data_adder = bram_data_1;
        case(current_state)
            AS_CALC: begin
                // data_left = bram_data_HASH;
                // data_right = bram_data_sb;
                data_left = bram_data_1;
                data_right = bram_data_2;
            end
            AS_SAVE: begin
                data_left = 64'd0;
                data_right = 64'd0;
            end
            SA_LOADWEIGHT: begin
                // data_left = 64'd0;
                // data_right = bram_data_sb;
                data_left = 64'd0;
                data_right = bram_data_1;
            end
            SA_CALC: begin
                // data_left = bram_data_HASH;
                // data_right = 64'd0;
                data_left = bram_data_3;
                data_right = 64'd0;
            end
            default: begin
                data_left = 64'd0;
                data_right = 64'd0;
            end
        endcase
    end

    always_comb begin
        case(current_state)
            AS_SAVE: begin
                save_wen =(cnt_line==matrix_size_reg + 32'd3 && count_4>0)||(cnt_line ==matrix_size_reg + 32'd4 && count_4 == 0)? 1'b1 : 1'b0;
            end
            SA_CALC: begin
                if (cnt_line == 4) begin
                    save_wen = (count_4 > 1);
                end
                else if (cnt_line > 4 && cnt_line < matrix_size_reg + 32'd4) begin
                    save_wen = 1'b1;
                end
                else if (cnt_line == matrix_size_reg + 32'd4) begin
                    save_wen = (count_4 < 2);
                end
            end
            default: begin
                save_wen = 1'd0;
            end
        endcase
    end

    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            transposition_slect <= 1'b1;
        end
        else if(calc_init) begin
            transposition_slect <= 1'b1;
        end
        else begin
            if(count_4==2'd0) begin
                transposition_slect <= ~transposition_slect;
            end
        end
    end

    always_ff@(posedge clk) begin
        if(calc_init) begin
            transposition_rst_sync <=1'b1;
        end
        else begin
            transposition_rst_sync <=1'b0;
        end
    end

endmodule
