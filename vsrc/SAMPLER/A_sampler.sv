`include "define.sv"

module A_sampler (
    input  logic [1:0]  frodo_mode, // 00: 640, 01: 976, 10: 1344
    input  logic [63:0] shake_data,
    output logic [63:0] a_data
);
    logic [15:0] mod_q_mask;
    assign mod_q_mask = (frodo_mode == 2'b00) ? 16'h7FFF : 16'hFFFF;

    assign a_data[15:0]  = shake_data[15:0]  & mod_q_mask;
    assign a_data[31:16] = shake_data[31:16] & mod_q_mask;
    assign a_data[47:32] = shake_data[47:32] & mod_q_mask;
    assign a_data[63:48] = shake_data[63:48] & mod_q_mask;
endmodule
