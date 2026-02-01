module systolic_top#(
        parameter DATA_WIDTH = 16,
        SUM_WIDTH = 16,
        SYSTOLIC_WIDTH = 4
    )(
        input logic clk,
        input logic rst_n,
        input logic [SYSTOLIC_WIDTH*DATA_WIDTH-1:0] a_in_raw,
        input logic [SYSTOLIC_WIDTH*DATA_WIDTH-1:0] b_in_raw,
        input logic [SYSTOLIC_WIDTH*DATA_WIDTH-1:0] sum_in_raw,
        output logic [SYSTOLIC_WIDTH*SUM_WIDTH-1:0] sum_out,
        input logic mode,//mode 1：输出固定 mode 0：权重固定
        input logic state,//state 0：数据传输  state 1：计算
        input logic enable
    );
    logic [DATA_WIDTH-1:0] sum_array [0:SYSTOLIC_WIDTH-1][0:SYSTOLIC_WIDTH-1];
    logic [DATA_WIDTH-1:0] a_reg_array [0:SYSTOLIC_WIDTH-1][0:SYSTOLIC_WIDTH-1];
    logic [DATA_WIDTH-1:0] b_reg_array [0:SYSTOLIC_WIDTH-1][0:SYSTOLIC_WIDTH-1];
    logic [DATA_WIDTH-1:0] a_reg_delayed [0:SYSTOLIC_WIDTH-1];
    logic [DATA_WIDTH-1:0] b_reg_delayed [0:SYSTOLIC_WIDTH-1];
    assign a_reg_delayed[0] = a_in[DATA_WIDTH-1:0];
    assign b_reg_delayed[0] = b_in[DATA_WIDTH-1:0];
    logic [SYSTOLIC_WIDTH*DATA_WIDTH-1:0] a_in;
    logic [SYSTOLIC_WIDTH*DATA_WIDTH-1:0] b_in;
    logic [SYSTOLIC_WIDTH*SUM_WIDTH-1:0] sum_in;
    // Build sum_out dynamically according to SYSTOLIC_WIDTH
    // Each slice of width SUM_WIDTH takes sum_array[SYSTOLIC_WIDTH-1][k]
    always_comb begin
        for (int k = 0; k < SYSTOLIC_WIDTH; k = k + 1) begin
            // assign each SUM_WIDTH-bit slot from LSB upward
            sum_out[ (SYSTOLIC_WIDTH - 1 - k) * SUM_WIDTH +: SUM_WIDTH ] = sum_out_array[SYSTOLIC_WIDTH-1 - k];
        end
    end
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            a_in <= '0;
            b_in <= '0;
            sum_in <= '0;
        end
        else begin
            a_in <= a_in_raw;
            b_in <= b_in_raw;
            sum_in <= sum_in_raw;
        end
    end

    genvar k;
    generate
        for (k = 1; k < SYSTOLIC_WIDTH; k = k + 1) begin : input_split_loop
            delay_reg #(
                          .DATA_WIDTH(DATA_WIDTH),
                          .DELAY_CYCLES(k)
                      ) a_delay_inst (
                          .clk(clk),
                          .rst_n(rst_n),
                          .din(a_in[(k+1)*DATA_WIDTH-1:k*DATA_WIDTH]),
                          .delay_switch(state || mode),
                          .dout(a_reg_delayed[k])
                      );
        end
        for (k = 1; k < SYSTOLIC_WIDTH; k = k + 1) begin : input_split_loop_b
            delay_reg #(
                          .DATA_WIDTH(DATA_WIDTH),
                          .DELAY_CYCLES(k)
                      ) b_delay_inst (
                          .clk(clk),
                          .rst_n(rst_n),
                          .din(b_in[(k+1)*DATA_WIDTH-1:k*DATA_WIDTH]),
                          .delay_switch(state || mode),
                          .dout(b_reg_delayed[k])
                      );
        end
    endgenerate

    genvar i, j;
    generate
        for (i = 0; i < SYSTOLIC_WIDTH; i = i + 1) begin : row_loop
            for (j = 0; j < SYSTOLIC_WIDTH; j = j + 1) begin : col_loop
                systolic_pe #(
                                .DATA_WIDTH(DATA_WIDTH)
                            ) pe_inst (
                                .clk(clk),
                                .rst_n(rst_n),
                                .a_wire((j == 0) ? a_reg_delayed[i] : a_reg_array[i][ j-1 ]),
                                .b_wire((i == 0) ? b_reg_delayed[j] : b_reg_array[ i-1 ][j]),
                                .a_reg(a_reg_array[i][j]),
                                .b_reg(b_reg_array[i][j]),
                                .sum_out(sum_array[i][j]),
                                .sum_wire((i == 0) ? sum_in[(j+1)*SUM_WIDTH-1:j*SUM_WIDTH] : sum_array[i-1][j]),
                                .mode(mode),
                                .state(state),
                                .enable(enable)
                            );
            end
        end
    endgenerate


    genvar p;
    logic [SUM_WIDTH-1:0] sum_out_array [0:SYSTOLIC_WIDTH-1];
    generate
       for(p=0;p<SYSTOLIC_WIDTH-1;p=p+1) begin:output_align_loop
            delay_reg #(
                          .DATA_WIDTH(SUM_WIDTH),
                          .DELAY_CYCLES(SYSTOLIC_WIDTH-p-1)
                      ) sum_delay_inst (
                          .clk(clk),
                          .rst_n(rst_n),
                          .din(sum_array[SYSTOLIC_WIDTH-1][p]),
                          .delay_switch(~mode),
                          .dout(sum_out_array[p])
                      );
        end
    endgenerate
    assign sum_out_array[3] = sum_array[SYSTOLIC_WIDTH-1][3];
endmodule


module systolic_pe#(
        parameter DATA_WIDTH = 16,
        SUM_WIDTH = 16
    )(
        input logic clk,
        input logic rst_n,
        input logic [DATA_WIDTH-1:0] a_wire,
        input logic [DATA_WIDTH-1:0] b_wire,
        input logic [SUM_WIDTH-1:0] sum_wire,
        output logic [SUM_WIDTH-1:0] sum_out,
        output logic [DATA_WIDTH-1:0] a_reg,
        output logic [DATA_WIDTH-1:0] b_reg,
        input logic mode,//mode 1：输出固定 mode 0：权重固定
        input logic state,//state 0：数据传输  state 1：计算
        input logic enable
    );

    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            a_reg<= '0;
            b_reg<= '0;
            sum_out<= '0;
        end
        if(enable) begin
            if(mode==1'b1) begin
                if(state==1'b1) begin
                    a_reg<= a_wire;
                    b_reg<= b_wire;
                    sum_out<= sum_out + a_wire* b_wire;

                end
                else begin
                    a_reg<= a_wire;
                    b_reg<= b_wire;
                    sum_out<= sum_wire;
                end
            end
            else begin
                if(state==1'b0) begin
                    b_reg<= a_wire;
                    a_reg<= a_wire;
                end
                else begin
                    a_reg<= a_wire;
                    sum_out<= sum_wire + a_wire* b_reg;
                end
            end
        end
    end

endmodule


module delay_reg#(
        parameter DATA_WIDTH = 16,
        parameter DELAY_CYCLES = 1
    )(
        input logic clk,
        input logic rst_n,
        input logic [DATA_WIDTH-1:0] din,
        input logic delay_switch,
        output logic [DATA_WIDTH-1:0] dout
    );
    logic [DATA_WIDTH-1:0] shift_reg [0:DELAY_CYCLES-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DELAY_CYCLES; i = i + 1) begin
                shift_reg[i] <= '0;
            end
        end
        else begin
            shift_reg[0] <= din;
            for (int i = 1; i < DELAY_CYCLES; i = i + 1) begin
                shift_reg[i] <= shift_reg[i-1];
            end
        end

    end
    assign dout = (delay_switch)? shift_reg[DELAY_CYCLES-1]:din;
endmodule
