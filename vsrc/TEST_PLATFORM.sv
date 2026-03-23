`include "define.sv"
module TEST_PLATFORM(
        input logic clk,
        input logic rst_n,
        // 添加查询接口以防止综合优化
        input logic [2:0]  query_id,
        input logic [31:0] query_addr,
        output logic [63:0] query_data,
        output logic [1:0]  status
    );
    assign status = bitbusy; // 导出状态信号
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
    logic [31:0] instr_F, instr_D;
    logic [31:0] instr_E_sys, instr_E_sha, instr_E_barrier;
    logic [63:0] instr64;
    logic [1:0] bitbusy;
    logic [31:0] pc_reg, pc_reg_stall;
    logic pc_choose_delay;
    logic [7:0] sp2_wmask, dp2_wmask;

    // ----------------------------------------------------------------
    // 指令队列声明：SHA 队列和 SYSTOLIC 队列各深度 10
    // ----------------------------------------------------------------
    logic [31:0] sha_queue [0:9];
    logic [3:0]  sha_head, sha_tail, sha_count;
    wire         sha_empty = (sha_count == 4'd0);
    wire         sha_full  = (sha_count == 4'd10);

    logic [31:0] sys_queue [0:9];
    logic [3:0]  sys_head, sys_tail, sys_count;
    wire         sys_empty = (sys_count == 4'd0);
    wire         sys_full  = (sys_count == 4'd10);

    // ----------------------------------------------------------------
    // 译码阶段：指令分类
    // ----------------------------------------------------------------
    logic [6:0] OPCODE_D;
    logic [2:0] FUNC_D;
    logic ready;

    assign FUNC_D   = instr_D[9:7];
    assign OPCODE_D = instr_D[6:0];

    // 指令类型判断
    wire is_sha_instr = (OPCODE_D == `SHAOPCODE);
    wire is_sys_instr = (OPCODE_D == `SYSOPCODE) && (FUNC_D != `systolic_bufswap_FUNC);
    wire is_barrier_instr = (OPCODE_D == `SYSOPCODE && FUNC_D == `systolic_bufswap_FUNC)
                          || (OPCODE_D == `TESTOPCODE);
    wire both_queues_drained = sha_empty && sys_empty && (bitbusy == 2'b00);

    // 流水线停顿逻辑：
    //   SHA 指令 → SHA 队列满时停顿
    //   SYS 指令 → SYS 队列满时停顿
    //   Barrier（SWAP/TESTOPCODE）→ 任一队列非空或任一单元 busy 时停顿
    //   其他（NOP 等）→ 不停顿
    assign ready = is_barrier_instr ? both_queues_drained :
                   is_sha_instr     ? !sha_full :
                   is_sys_instr     ? !sys_full :
                   1'b1;

    // ----------------------------------------------------------------
    // 队列弹出（dispatch）逻辑
    // ----------------------------------------------------------------
    // 从队列头部读取待发射指令
    wire [31:0] sha_head_instr = sha_queue[sha_head];
    wire [31:0] sys_head_instr = sys_queue[sys_head];

    // 弹出条件：队列非空且对应单元空闲
    wire sha_dispatch = !sha_empty && !bitbusy[0];
    wire sys_dispatch = !sys_empty && !bitbusy[1];

    // 从弹出的指令计算 prebusy
    wire [2:0] sha_dispatch_func = sha_head_instr[9:7];
    wire [2:0] sys_dispatch_func = sys_head_instr[9:7];

    wire pre_sha3busy_dispatch = sha_dispatch
        && (sha_dispatch_func != `SHAKE_seedaddrset_FUNC)
        && (sha_dispatch_func != `SHAKE_seedset_FUNC);
    wire pre_systolicbusy_dispatch = sys_dispatch
        && (sys_dispatch_func == `systolic_calc_FUNC);

    logic [1:0] prebusy;
    assign prebusy = {pre_systolicbusy_dispatch, pre_sha3busy_dispatch};

    // 发射到 FACE_TOP 的指令：队列弹出时输出有效指令，否则输出 NOP
    // 注意：队列弹出是组合逻辑（与旧设计中 instr 直接送入 FACE_TOP 一致）
    // Barrier 中的 SWAP（SYSOPCODE）通过 instr_E_barrier 送入 FACE_TOP
    assign instr_E_sha = sha_dispatch ? sha_head_instr : 32'hFFFF_FFFF;
    assign instr_E_sys = sys_dispatch ? sys_head_instr : 32'hFFFF_FFFF;

    // ----------------------------------------------------------------
    // FACE_TOP 实例化（双指令输入）
    // ----------------------------------------------------------------
    FACE_TOP u_FACE_TOP(
                 .clk              	(clk               ),
                 .rst_n            	(rst_n             ),
                 .instr_sys        	(instr_E_sys       ),
                 .instr_sha        	(instr_E_sha       ),
                 .instr_barrier    	(instr_E_barrier   ),
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
                 .bitbusy          	(bitbusy           ),
                 .prebusy          	(prebusy           ),
                 .sp2_wmask        	(sp2_wmask         ),
                 .dp2_wmask        	(dp2_wmask         )
             );

    // ----------------------------------------------------------------
    // IF / D 流水线推进 + 入队逻辑
    // ----------------------------------------------------------------
    // 辅助函数：循环指针递增 (0-9)
    function automatic [3:0] next_ptr(input [3:0] ptr);
        next_ptr = (ptr == 4'd9) ? 4'd0 : ptr + 4'd1;
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg         <= 32'd0;
            pc_choose_delay<= 1'b0;
            pc_reg_stall   <= 32'd0;
            instr_D        <= 32'hFFFF_FFFF;
            instr_E_barrier<= 32'hFFFF_FFFF;
            sha_head <= 0; sha_tail <= 0; sha_count <= 0;
            sys_head <= 0; sys_tail <= 0; sys_count <= 0;
        end
        else begin
            // --- Barrier 指令直通（SWAP / TESTOPCODE）---
            if (is_barrier_instr && both_queues_drained)
                instr_E_barrier <= instr_D;
            else
                instr_E_barrier <= 32'hFFFF_FFFF;

            // --- 入队：ready 且为 SHA/SYS 指令时写入对应队列 ---
            if (ready && is_sha_instr) begin
                sha_queue[sha_tail] <= instr_D;
                sha_tail <= next_ptr(sha_tail);
            end
            if (ready && is_sys_instr) begin
                sys_queue[sys_tail] <= instr_D;
                sys_tail <= next_ptr(sys_tail);
            end

            // --- 弹出：dispatch 时移动 head ---
            if (sha_dispatch) begin
                sha_head <= next_ptr(sha_head);
            end
            if (sys_dispatch) begin
                sys_head <= next_ptr(sys_head);
            end

            // --- 队列计数维护（同时入队和弹出时计数不变）---
            case ({(ready && is_sha_instr), sha_dispatch})
                2'b10:   sha_count <= sha_count + 4'd1;
                2'b01:   sha_count <= sha_count - 4'd1;
                default: sha_count <= sha_count; // 00 或 11
            endcase
            case ({(ready && is_sys_instr), sys_dispatch})
                2'b10:   sys_count <= sys_count + 4'd1;
                2'b01:   sys_count <= sys_count - 4'd1;
                default: sys_count <= sys_count;
            endcase

            // --- IF/D 流水线推进 ---
            if (ready) begin
                pc_reg       <= pc_reg + 32'd4;
                instr_D      <= instr_F;
                pc_reg_stall <= pc_reg;
            end
            else begin
                pc_reg  <= pc_reg_stall;
                instr_D <= instr_D;
            end
            pc_choose_delay <= pc_reg[2];
        end
    end

    assign instr_F = (ready_d) ?
        ((pc_choose_delay == 1'b0) ? instr64[31:0] : instr64[63:32])
        : 32'hFFFF_FFFF;

    logic ready_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ready_d <= 1'b0;
        else
            ready_d <= ready;
    end
`ifdef SIMULATION
    TEST_DPIC u_TEST_DPIC(
        .clk  (clk),
        .rst_n(rst_n),
        .instr(instr_E_barrier)
    );

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
                      .wmask 	(sp2_wmask  ),
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
                      .wmask 	(dp2_wmask  ),
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
`else
    // 硬件综合分支：增加查询逻辑防止优化
    logic [63:0] q_data;
    always_comb begin
        case(query_id)
            3'd0: q_data = bram_rdata_sp_1;
            3'd1: q_data = bram_rdata_sp_2;
            3'd2: q_data = bram_rdata_dp_1;
            3'd3: q_data = bram_rdata_dp_2;
            3'd4: q_data = bram_rdata_HASH1;
            3'd5: q_data = bram_rdata_HASH2;
            3'd6: q_data = instr64;
            default: q_data = 64'h0;
        endcase
    end
    assign query_data = q_data;

    // 将查询地址应用到 BRAM（这里采用简单的多路复用，
    // 如果 query_id 在有效范围内，地址将被 query_addr 覆盖，从而保证地址线也被综合）
    logic [31:0] real_addr_sp1, real_addr_sp2, real_addr_dp1, real_addr_dp2;
    logic [31:0] real_addr_h1, real_addr_h2, real_pc;

    assign real_addr_sp1 = (query_id == 3'd0) ? query_addr : addr_sp_1;
    assign real_addr_sp2 = (query_id == 3'd1) ? query_addr : addr_sp_2;
    assign real_addr_dp1 = (query_id == 3'd2) ? query_addr : addr_dp_1;
    assign real_addr_dp2 = (query_id == 3'd3) ? query_addr : addr_dp_2;
    assign real_addr_h1  = (query_id == 3'd4) ? query_addr : addr_HASH_1;
    assign real_addr_h2  = (query_id == 3'd5) ? query_addr : addr_HASH_2;
    assign real_pc       = (query_id == 3'd6) ? query_addr : pc_reg;

    SP_RAM u_SP_RAM (
               .clka(clk),
               .wea(wen_sp_1 ? 8'hFF : 8'h00),
               .addra(real_addr_sp1[14:3]), 
               .dina(bram_wdata_sp_1),
               .douta(bram_rdata_sp_1),
               .clkb(clk),
               .enb(1'b1),
               .web(wen_sp_2 ? sp2_wmask : 8'h00),
               .addrb(real_addr_sp2[14:3]),
               .dinb(bram_wdata_sp_2),
               .doutb(bram_rdata_sp_2)
           );
    IROM u_IROM (
             .clka(clk),
             .wea(8'h00),
             .addra(real_pc[14:3]), 
             .dina(64'd0),
             .douta(instr64),
             .clkb(clk),
             .enb(1'b0),
             .web(8'h00),
             .addrb(12'd0),
             .dinb(64'd0),
             .doutb()
         );
    DP_RAM u_DP_RAM (
               .clka(clk),
               .wea(wen_dp_1 ? 8'hFF : 8'h00),
               .addra(real_addr_dp1[13:3]), 
               .dina(bram_wdata_dp_1),
               .douta(bram_rdata_dp_1),
               .clkb(clk),
               .enb(1'b1),
               .web(wen_dp_2 ? dp2_wmask : 8'h00),
               .addrb(real_addr_dp2[13:3]),
               .dinb(bram_wdata_dp_2),
               .doutb(bram_rdata_dp_2)
           );
    A_buffer1 u_A_buffer1 (
               .clka(clk),
               .wea(wen_HASH_1 ? 8'hFF : 8'h00),
               .addra(real_addr_h1[13:3]), 
               .dina(bram_wdata_HASH),
               .douta(bram_rdata_HASH1),
               .clkb(clk),
               .enb(1'b0),
               .web(8'h00),
               .addrb(11'd0),
               .dinb(64'd0),
               .doutb()
           );
    A_buffer2 u_A_buffer2 (
               .clka(clk),
               .wea(wen_HASH_2 ? 8'hFF : 8'h00),
               .addra(real_addr_h2[13:3]), 
               .dina(bram_wdata_HASH),
               .douta(bram_rdata_HASH2),
               .clkb(clk),
               .enb(1'b0),
               .web(8'h00),
               .addrb(11'd0),
               .dinb(64'd0),
               .doutb()
           );
`endif
endmodule
