`include "define.sv"

module TEST_DPIC (
    input logic        clk,
    input logic        rst_n,
    input logic [31:0] instr
);

    logic [6:0] opcode;
    logic [2:0] func;

    assign opcode = instr[6:0];
    assign func = instr[9:7];

    import "DPI-C" function void frodo_v_encodeu_add();
    import "DPI-C" function void test_print_simtime();

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // no state
        end
        else if (opcode == `TESTOPCODE) begin
            case (func)
                `TEST_frodo_v_encodeu_add_FUNC: begin
                    frodo_v_encodeu_add();
                end
                `TEST_print_simtime_FUNC: begin
                    test_print_simtime();
                end
                default: begin
                end
            endcase
        end
    end

endmodule
