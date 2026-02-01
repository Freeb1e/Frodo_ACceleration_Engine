module block_ram_dpi #(
    parameter int BRAM_ID = 0 // 默认为 0
)(
    input  logic        clk,
    input  logic [31:0] raddr,
    input  logic [31:0] waddr,
    input  logic [63:0] wdata,
    input  logic [7:0]  wmask,
    input  logic        wen,
    output logic [63:0] rdata
);

    import "DPI-C" function void pmem_read(input int raddr, input int bramid ,output longint rdata);
    import "DPI-C" function void pmem_write(input int waddr, input int bramid,input longint wdata, input byte wmask);

    longint rdata_temp; 

    always @(posedge clk) begin
        if(wen) begin
            pmem_write(int'(waddr), BRAM_ID, longint'(wdata), byte'(wmask));
        end
        pmem_read(int'(raddr), BRAM_ID, rdata_temp);
        rdata <= rdata_temp;
    end

endmodule

