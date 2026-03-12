`include "define.sv"

module SE_sampler (
    input  logic [1:0]  frodo_mode,  // 00: 640, 01: 976, 10: 1344
    input  logic        is_e_matrix, // 0: S matrix (8-bit), 1: E matrix (16-bit)
    input  logic [63:0] shake_data,
    output logic [63:0] se_data
);
    // CDT tables...
    logic [15:0] CDT_640 [0:12] = '{16'd4643, 16'd13363, 16'd20579, 16'd25843, 16'd29227, 16'd31145, 16'd32103, 16'd32525, 16'd32689, 16'd32745, 16'd32762, 16'd32766, 16'd32767};
    logic [15:0] CDT_976 [0:10] = '{16'd5638, 16'd15915, 16'd23689, 16'd28571, 16'd31116, 16'd32217, 16'd32613, 16'd32731, 16'd32760, 16'd32766, 16'd32767};
    logic [15:0] CDT_1344 [0:6] = '{16'd9142, 16'd23462, 16'd30338, 16'd32361, 16'd32725, 16'd32765, 16'd32767};

    logic [15:0] sampled_coeffs [0:3];

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : sampler_gen
            logic [15:0] r_in;
            logic [14:0] z;
            logic r0;
            logic [15:0] e_val;

            assign r_in = shake_data[i*16 +: 16];
            assign z = r_in[15:1];
            assign r0 = r_in[0];

            always_comb begin
                e_val = '0;
                case (frodo_mode)
                    2'b00: begin
                        for (int j = 0; j < 13; j = j + 1)
                            if (z >= CDT_640[j][14:0]) e_val = e_val + 16'd1;
                    end
                    2'b01: begin
                        for (int j = 0; j < 11; j = j + 1)
                            if (z >= CDT_976[j][14:0]) e_val = e_val + 16'd1;
                    end
                    2'b10: begin
                        for (int j = 0; j < 7; j = j + 1)
                            if (z >= CDT_1344[j][14:0]) e_val = e_val + 16'd1;
                    end
                    default: ;
                endcase

                if (r0 == 1'b1 && e_val != 16'd0) begin
                    e_val = (~e_val + 16'd1);
                end
            end
            assign sampled_coeffs[i] = e_val;
        end
    endgenerate

    always_comb begin
        if (is_e_matrix) begin
            // E 矩阵：每个系数占 16 位，填满 64 位
            se_data = {sampled_coeffs[3], sampled_coeffs[2], sampled_coeffs[1], sampled_coeffs[0]};
        end else begin
            // S 矩阵：每个系数占 8 位，放在低 32 位
            se_data = {32'd0, sampled_coeffs[3][7:0], sampled_coeffs[2][7:0], sampled_coeffs[1][7:0], sampled_coeffs[0][7:0]};
        end
    end
endmodule
