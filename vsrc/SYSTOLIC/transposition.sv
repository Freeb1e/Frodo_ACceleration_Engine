module transposition_top_default#(
    parameter DATA_WIDTH = 16,
              SYSTOLIC_WIDTH = 4
)
(
    input logic clk,
    input logic rst_n,
    input logic [SYSTOLIC_WIDTH*DATA_WIDTH-1:0] martix_in,
    output logic [SYSTOLIC_WIDTH*DATA_WIDTH-1:0] martix_out,
    input logic rst_sync,
    input logic mode//mode 0：数据读入 mode 1:数据读出
);
    logic [DATA_WIDTH-1:0] reg_array [0:SYSTOLIC_WIDTH-1][0:SYSTOLIC_WIDTH-1];
    genvar i,j;
    generate
        for(i=0;i<SYSTOLIC_WIDTH;i=i+1)begin: row_loop
            for(j=0;j<SYSTOLIC_WIDTH;j=j+1)begin: col_loop
               transposition_unit #(
                    .DATA_WIDTH(DATA_WIDTH)
               ) transposition_unit_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .data_in_a( (j == 0) ? martix_in[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH] : reg_array[i][j-1] ),
                    .data_in_b( (i == SYSTOLIC_WIDTH-1) ? '0 : reg_array[i+1][j] ),
                    .data_reg(reg_array[i][j]),
                    .rst_sync(rst_sync),
                    .mode(mode)
               );
            end
        end
    endgenerate
    assign martix_out = {reg_array[0][0],reg_array[0][1],reg_array[0][2],reg_array[0][3]};
endmodule

module transposition_top_dynamic #(
    parameter DATA_WIDTH = 16,
    parameter SYSTOLIC_WIDTH = 4
)
(
    input logic clk,
    input logic rst_n,
    input logic [SYSTOLIC_WIDTH*DATA_WIDTH-1:0] martix_in,
    output logic [SYSTOLIC_WIDTH*DATA_WIDTH-1:0] martix_out,
    input logic mode, // mode 0: 读入(水平), mode 1: 读出(垂直)
    input logic rst_sync,
    // 【新增控制信号】
    // 0: 向上推出 (Upward), 1: 向下推出 (Downward)
    input logic dir   
);

    logic [DATA_WIDTH-1:0] reg_array [0:SYSTOLIC_WIDTH-1][0:SYSTOLIC_WIDTH-1];
    
    // 用于暂存两组可能的输出数据：第0行（向上出）和最后一行（向下出）
    logic [SYSTOLIC_WIDTH*DATA_WIDTH-1:0] data_out_top;
    logic [SYSTOLIC_WIDTH*DATA_WIDTH-1:0] data_out_bottom;

    genvar i, j;
    generate
        for(i = 0; i < SYSTOLIC_WIDTH; i = i + 1) begin: row_loop
            for(j = 0; j < SYSTOLIC_WIDTH; j = j + 1) begin: col_loop
                
                // 定义两个方向的候选数据源
                logic [DATA_WIDTH-1:0] src_from_below; // 向上流的数据源（来自下方）
                logic [DATA_WIDTH-1:0] src_from_above; // 向下流的数据源（来自上方）
                logic [DATA_WIDTH-1:0] vertical_mux_out; // 最终选中的数据

                // 1. 准备“来自下方”的数据（对应 dir=0）
                // 如果是最后一行，下方没有数据，补0；否则取 [i+1]
                assign src_from_below = (i == SYSTOLIC_WIDTH-1) ? {DATA_WIDTH{1'b0}} : reg_array[i+1][j];

                // 2. 准备“来自上方”的数据（对应 dir=1）
                // 如果是第0行，上方没有数据，补0；否则取 [i-1]
                assign src_from_above = (i == 0) ? {DATA_WIDTH{1'b0}} : reg_array[i-1][j];

                // 3. 动态选择：根据 dir 信号选择垂直输入源
                assign vertical_mux_out = (dir == 1'b1) ? src_from_above : src_from_below;

                transposition_unit #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) transposition_unit_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    // 水平方向保持不变
                    .data_in_a( (j == 0) ? martix_in[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH] : reg_array[i][j-1] ),
                    // 垂直方向使用选择后的信号
                    .data_in_b( vertical_mux_out ), 
                    .data_reg(reg_array[i][j]),
                    .mode(mode),
                    .rst_sync(rst_sync) 
                );
            end
        end
    endgenerate

    // ------------------------------------------------------------
    // 输出逻辑：同时也需要动态选择输出源
    // ------------------------------------------------------------
    genvar k;
    generate
        for (k = 0; k < SYSTOLIC_WIDTH; k = k + 1) begin : out_bus_assign
            // 构建 Top Row 输出总线 (dir=0 时用) -> reg_array[0][...]
            assign data_out_top[(SYSTOLIC_WIDTH-k)*DATA_WIDTH-1 : (SYSTOLIC_WIDTH-k-1)*DATA_WIDTH] = reg_array[0][k];
            
            // 构建 Bottom Row 输出总线 (dir=1 时用) -> reg_array[Last][...]
            assign data_out_bottom[(SYSTOLIC_WIDTH-k)*DATA_WIDTH-1 : (SYSTOLIC_WIDTH-k-1)*DATA_WIDTH] = reg_array[SYSTOLIC_WIDTH-1][k];
        end
    endgenerate

    // 最终输出多路选择器
    // dir=0: 输出 Top Row; dir=1: 输出 Bottom Row
    assign martix_out = (dir == 1'b1) ? data_out_bottom : data_out_top;

endmodule

module transposition_unit#(
    parameter DATA_WIDTH =16
)
(
    input logic clk,
    input logic rst_n,
    input logic [DATA_WIDTH-1:0] data_in_a,
    input logic [DATA_WIDTH-1:0] data_in_b,
    output logic [DATA_WIDTH-1:0] data_reg,
    input logic rst_sync,
    input logic mode//mode 0：数据读入 mode 1:数据读出
);
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            data_reg <= '0;
        end else begin
            if(rst_sync) begin
                data_reg <= '0;
            end else
            if(mode==1'b0) begin
                data_reg <= data_in_a;
            end else begin
                data_reg <= data_in_b;
            end
        end
    end
endmodule