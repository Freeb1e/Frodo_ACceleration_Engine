`include "define.sv"

module A_sampler (
    input  logic [1:0]  frodo_mode, // 01: 976, 10: 1344
    input  logic [63:0] shake_data,
    output logic [63:0] a_data
);
    assign a_data[15:0]  = shake_data[15:0] ;
    assign a_data[31:16] = shake_data[31:16];
    assign a_data[47:32] = shake_data[47:32];
    assign a_data[63:48] = shake_data[63:48];
endmodule
