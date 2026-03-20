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