module Adder_4#(
        parameter DATA_WIDTH = 16
    )(
        input logic [DATA_WIDTH-1:0] a1,
        input logic [DATA_WIDTH-1:0] a2,
        input logic [DATA_WIDTH-1:0] a3,
        input logic [DATA_WIDTH-1:0] a4,
        input logic [DATA_WIDTH-1:0] b1,
        input logic [DATA_WIDTH-1:0] b2,
        input logic [DATA_WIDTH-1:0] b3,
        input logic [DATA_WIDTH-1:0] b4,
        output logic [DATA_WIDTH-1:0] sum1,
        output logic [DATA_WIDTH-1:0] sum2,
        output logic [DATA_WIDTH-1:0] sum3,
        output logic [DATA_WIDTH-1:0] sum4, 
        input logic sub_en, 
        input logic clk,
        input logic rst_n
    );
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum1 <= '0;
            sum2 <= '0;
            sum3 <= '0;
            sum4 <= '0;
        end
        else begin
            if (sub_en) begin
                sum1 <= b1 - a1;
                sum2 <= b2 - a2;
                sum3 <= b3 - a3;
                sum4 <= b4 - a4;
            end
            else begin
                sum1 <= a1 + b1;
                sum2 <= a2 + b2;
                sum3 <= a3 + b3;
                sum4 <= a4 + b4;
            end
        end
    end
endmodule
