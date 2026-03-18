module sha3_ctrl(
        input logic clk,
        input logic rst_n,
        input logic [63:0] seed_data_in,
        input logic [7:0] absorb_num,
        input logic [7:0] last_block_bytes,
        input logic sha3_start,
        input logic sha3_absorb,          // 触发从当前地址开始吸收
        input logic [7:0] seg_absorb_num,  // 本段完整块数
        input logic [4:0] last_block_words,// 完整块之后额外读取的字数(半块)，0=无
        input logic sha3_squeezeonce,
        input logic shakemode, // 0: SHAKE128, 1: SHAKE256
        input logic [4:0] sha3_sample_addr,
        output logic sha3_ready,
        output logic sha3_optready,
        output logic sha3_wait_cmd,      // 新增：处于WAIT_CMD状态，可接收指令
        output logic sha3_processing,    // 新增：正在处理（ABSORB/WAITABSORB/SQUEEZE）
        output logic [63:0] sha3_data_out,
        output logic [31:0] sha3_addr_perip
    );
    logic       wr_keccak;
    logic [6:0] addr_keccak;
    logic [63:0] din_keccak;
    logic [63:0] dout_keccak;
    logic       init_keccak;
    logic       next_keccak_absorb;
    logic       next_keccak_squeeze;
    logic       ready_keccak;
    logic [7:0] absorb_counter;
    logic [4:0] word_counter,word_counter_delay;
    logic absorb_oncedone;
    logic partial_seg_done;
    logic squeeze_oncedone;

    assign sha3_ready = (current_state == WAITSQUEEZE) ? 1'b1 : 1'b0;
    assign sha3_wait_cmd =(current_state == WAIT_CMD && last_state ==ABSORB) ? 1'b1 : 1'b0;
    assign sha3_processing = (current_state == ABSORB) || (current_state == WAITABSORB) || (current_state == SQUEEZE);
    parameter IDLE         = 3'd0,
              ABSORB       = 3'd1,
              WAITABSORB   = 3'd2,
              WAITSQUEEZE  = 3'd3,
              SQUEEZE      = 3'd4,
              WAIT_CMD     = 3'd5;
    parameter SHAKE128_RATE = 21,
              SHAKE256_RATE = 17;
    logic [2:0] current_state, next_state;
    logic [4:0] words_rate;
    logic [31:0] addr_seed,addr_output;
    logic [7:0] total_absorb_bytes;

    logic [7:0] seg_counter;
    logic [7:0] seg_absorb_num_reg;
    logic [4:0] last_block_words_reg;
    // 组合逻辑：当前是否处于半块模式
    // 保护：当 absorb_counter == absorb_num 时（全部块已吸收完），强制关闭半块模式
    logic doing_partial;
    assign doing_partial = (seg_counter == seg_absorb_num_reg) && (last_block_words_reg != 5'd0)
                           && (absorb_counter != absorb_num);

    logic [6:0] addr_keccak_absorb,addr_keccak_absorb_delay,addr_sample;
    logic [63:0] din_keccak_delay;
    assign addr_keccak_absorb = {1'b0,word_counter , 1'b0};
    assign addr_sample = {1'b1,sha3_sample_addr , 1'b0};
    assign addr_keccak = (current_state == ABSORB)? addr_keccak_absorb_delay : addr_sample;
    assign sha3_addr_perip = (current_state == ABSORB)? addr_seed : addr_output;
    assign sha3_data_out = dout_keccak;
    assign squeeze_oncedone = ready_keccak && (!next_keccak_squeeze);
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            addr_keccak_absorb_delay <= 7'd0;
            din_keccak_delay <= 64'd0;
            word_counter_delay <= 5'd0;
        end else begin
            addr_keccak_absorb_delay <= addr_keccak_absorb;
            din_keccak_delay <= din_keccak;
            if(current_state == ABSORB)
                word_counter_delay <= word_counter;
            else
                word_counter_delay <= 5'd0;
        end
    end

    sha3 u_sha3(
             .clk    	(clk     ),
             .nreset 	(rst_n  ),
             .w      	(wr_keccak ),
             .addr   	(addr_keccak    ),
             .din    	(din_keccak    ),
             .dout   	(dout_keccak    ),
             .start  	(sha3_start   ),
             .init   	(init_keccak    ),
             .next   	(next_keccak_absorb      ),
             .squeeze    (next_keccak_squeeze   ),
             .ready  	(ready_keccak   )
         );

    // ========== 状态寄存器 ==========
    logic [2:0] last_state;    
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_state <= IDLE;
            last_state <= IDLE;
        end else begin
            if(sha3_start) begin
                current_state <= WAIT_CMD;
                words_rate <= shakemode ? SHAKE256_RATE : SHAKE128_RATE;
            end else if(sha3_absorb && current_state == WAIT_CMD) begin
                current_state <= ABSORB;
            end else
                current_state <= next_state;
            last_state <= current_state;
        end
    end

    // ========== 次态组合逻辑 ==========
    always_comb begin
        case(current_state)
            IDLE: begin
                if(sha3_start)
                    next_state = WAIT_CMD;
                else
                    next_state = IDLE;
            end
            WAIT_CMD: begin
                if(sha3_absorb)
                    next_state = ABSORB;
                else
                    next_state = WAIT_CMD;
            end
            ABSORB: begin
                if(absorb_oncedone)
                    next_state = WAITABSORB;
                else if(partial_seg_done)
                    next_state = WAIT_CMD;    // 半块完成，暂停等待下一段
                else
                    next_state = ABSORB;
            end
            WAITABSORB: begin
                if(ready_keccak && !next_keccak_absorb && !init_keccak)begin
                    if(seg_counter == seg_absorb_num_reg) begin
                        // 本段完整块全部吸收完毕
                        if(absorb_num == absorb_counter)
                            next_state = WAITSQUEEZE;  // 全部完成（优先级最高）
                        else if(last_block_words_reg != 5'd0)
                            next_state = ABSORB;       // 还有半块要读
                        else
                            next_state = WAIT_CMD;     // 等待下一段
                    end else
                        next_state = ABSORB;
                end else begin
                    next_state = WAITABSORB;
                end
            end
            WAITSQUEEZE: begin
                if(sha3_squeezeonce)
                    next_state = SQUEEZE;
                else
                    next_state = WAITSQUEEZE;
            end
            SQUEEZE: begin
                if(squeeze_oncedone)
                    next_state = WAITSQUEEZE;
                else
                    next_state = SQUEEZE;
            end
            default:
                next_state = IDLE;
        endcase
    end

    // ========== 计数器逻辑 ==========
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            absorb_counter <= 8'd0;
            word_counter <= 5'd0;
            addr_seed <= 32'd0;
            addr_output <= 32'd0;
            seg_counter <= 8'd0;
            seg_absorb_num_reg <= 8'd0;
            last_block_words_reg <= 5'd0;
            absorb_oncedone <= 1'b0;
            partial_seg_done <= 1'b0;
        end else begin
            if(sha3_start) begin
                absorb_counter <= 8'd0;
                word_counter <= 5'd0;
                addr_seed <= 32'd0;
                addr_output <= 32'd0;
                seg_counter <= 8'd0;
                seg_absorb_num_reg <= 8'd0;
                last_block_words_reg <= 5'd0;
                absorb_oncedone <= 1'b0;
                partial_seg_done <= 1'b0;
            end else if(sha3_absorb && current_state == WAIT_CMD) begin
                // 新段开始：锁存段参数，重置段计数器和地址
                // word_counter 不重置（可能处于半块中间）
                seg_counter <= 8'd0;
                seg_absorb_num_reg <= seg_absorb_num;
                last_block_words_reg <= last_block_words;
                addr_seed <= 32'd0;
                absorb_oncedone <= 1'b0;
                partial_seg_done <= 1'b0;
            end else begin
                if(current_state == ABSORB) begin
                    if(ready_keccak) begin
                        if(doing_partial) begin
                            // 半块模式：读到 last_block_words_reg 就停
                            if(word_counter == last_block_words_reg) begin
                                // 半块读完，保持 word_counter 不动
                            end else begin
                                word_counter <= word_counter + 5'd1;
                                addr_seed <= addr_seed + 32'd8;
                            end
                        end else begin
                            // 完整块模式
                            if(word_counter == words_rate) begin
                                word_counter <= 5'd0;
                                absorb_counter <= absorb_counter + 8'd1;
                                seg_counter <= seg_counter + 8'd1;
                            end else begin
                                word_counter <= word_counter + 5'd1;
                                addr_seed <= addr_seed + 32'd8;
                            end
                        end
                    end else begin
                        if(!doing_partial)
                            word_counter <= 5'd0;
                        // 半块模式下保持 word_counter
                    end
                    absorb_oncedone <= (!doing_partial && word_counter == words_rate - 5'd1) ? 1'b1 : 1'b0;
                    partial_seg_done <= (doing_partial && word_counter == last_block_words_reg - 5'd1) ? 1'b1 : 1'b0;
                end else begin
                    if(current_state != WAIT_CMD)
                        word_counter <= 5'd0;
                    addr_output <= 32'd0;
                    absorb_oncedone <= 1'b0;
                    partial_seg_done <= 1'b0;
                end
            end
        end
    end

    // ========== wr_keccak ==========
    always_ff@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            wr_keccak <= 1'b0;
        end else if (current_state == ABSORB) begin
            if(doing_partial) begin
                wr_keccak <= (word_counter < last_block_words_reg) ? 1'b1 : 1'b0;
            end else begin
                wr_keccak <= (word_counter < words_rate) ? 1'b1 : 1'b0;
            end
        end else begin
            wr_keccak <= 1'b0;
        end
    end

    // ========== init / next / squeeze 控制 ==========
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            init_keccak <= 1'b0;
            next_keccak_absorb <= 1'b0;
            next_keccak_squeeze <= 1'b0;
        end else begin
            if(current_state == ABSORB && !doing_partial) begin
                // 只有完整块才触发 keccak 置换
                if(word_counter_delay == words_rate-1) begin
                    if(absorb_counter == 8'd0)begin
                        init_keccak <= 1'b1;
                    end else begin
                        next_keccak_absorb <=1'b1;
                    end
                end else begin
                    init_keccak <= 1'b0;
                    next_keccak_absorb <=1'b0;
                end
            end else if(current_state == WAITSQUEEZE) begin
                init_keccak <= 1'b0;
                next_keccak_absorb <= 1'b0;
                next_keccak_squeeze <= (sha3_squeezeonce)? 1'b1 : 1'b0;
            end else begin
                init_keccak <= 1'b0;
                next_keccak_absorb <= 1'b0;
                next_keccak_squeeze <= 1'b0;
            end
        end
    end

    // ========== padding / din_keccak ==========
    logic [63:0] padding_typeA, padding_mask, padding_typeB;
    logic [4:0] padding_pos ;
    assign padding_pos = last_block_bytes[7:3];
    logic is_last_block_total;
    assign is_last_block_total = (absorb_counter == absorb_num - 8'd1);
    always_comb begin
        if(word_counter_delay < padding_pos) begin
            padding_typeA = seed_data_in;
        end else if(word_counter_delay == padding_pos)begin
            case(last_block_bytes [2:0])
            3'b000 : padding_typeA = 64'h0000_0000_0000_001F;
            3'b001 : padding_typeA = {56'h0000_0000_0000_1F,seed_data_in[7:0]};
            3'b010 : padding_typeA = {48'h0000_0000_001F,seed_data_in[15:0]};
            3'b011 : padding_typeA = {40'h0000_0000_1F,seed_data_in[23:0]};
            3'b100 : padding_typeA = {32'h0000_001F,seed_data_in[31:0]};
            3'b101 : padding_typeA = {24'h0000_1F,seed_data_in[39:0]};
            3'b110 : padding_typeA = {16'h001F,seed_data_in[47:0]};
            3'b111 : padding_typeA = {8 'h1F,seed_data_in[55:0]};
            default: padding_typeA = 64'h0000_0000_0000_0000;
            endcase
        end else begin
            padding_typeA = 64'h0000_0000_0000_0000;
        end

        if(word_counter_delay == words_rate -5'd1 && last_block_bytes != 8'd0) begin
            padding_mask = 64'h8000_0000_0000_0000;
        end else begin
            padding_mask = 64'h0000_0000_0000_0000;
        end

        if(word_counter_delay == 5'd0) begin
            padding_typeB = 64'h0000_0000_0000_001F;
        end else if(word_counter_delay == words_rate -5'd1) begin
            padding_typeB = 64'h8000_0000_0000_0000;
        end else begin
            padding_typeB = 64'h0000_0000_0000_0000;
        end

        if(is_last_block_total && !doing_partial) begin
            // 整个hash的最后一块（完整块）：应用padding
            if(last_block_bytes != 8'd0)begin
                din_keccak = padding_typeA | padding_mask;
            end else begin
                din_keccak = padding_typeB;
            end
        end else begin
            // 非最后块 或 半块模式：直接传数据
            din_keccak = seed_data_in;
        end
    end

endmodule
