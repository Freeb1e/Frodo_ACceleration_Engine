//`include "transposition.sv"
//`include "systolic.sv"
module mul_top(
        input logic clk,
        input logic rst_n,
        input logic calc_init,
        input logic [1:0] ctrl_mode, // 00:AS 01:SB 10:BS 11:SA
        input logic inpack,   // 读取时对16bit元素高低字节交换(unpack)
        input logic inpack_right, // 读取时对右矩阵数据进行16bit元素高低字节交换(unpack)
        input logic addsrc_unpack, // 对累加源(addsrc)读取值进行16bit元素高低字节交换(unpack)
        input logic outpack,  // 输出时对16bit元素高低字节交换(pack)

        input logic [63:0] bram_data_1,
        input logic [63:0] bram_data_2,
        input logic [63:0] bram_data_3,

        input logic [31:0] BASE_ADDR_LEFT,
        input logic [31:0] BASE_ADDR_RIGHT,
        input logic [31:0] BASE_ADDR_ADDSRC,
        input logic [31:0] BASE_ADDR_SAVE,
        input logic [10:0] MATRIX_SIZE,

        output logic [31:0] bram_addr_1,
        output logic [31:0] bram_addr_2,
        output logic [31:0] bram_addr_3,

        output logic [3:0] current_state,

        output logic save_wen,
        output logic [63:0] bram_savedata
    );
    logic [63:0] data_left;
    logic [63:0] data_right;

    // inpack: 对读取的左矩阵数据进行16bit元素高低字节交换
    logic [63:0] data_left_unpacked;
    assign data_left_unpacked = inpack ? {
               data_left[55:48], data_left[63:56],
               data_left[39:32], data_left[47:40],
               data_left[23:16], data_left[31:24],
               data_left[7:0],   data_left[15:8]
           } : data_left;
    logic [63:0] data_right_unpacked;
    assign data_right_unpacked = inpack_right ? {
               data_right[55:48], data_right[63:56],
               data_right[39:32], data_right[47:40],
               data_right[23:16], data_right[31:24],
               data_right[7:0],   data_right[15:8]
           } : data_right;
    logic [63:0] data_right_unpacked_d4;
    delay_reg #(
                  .DATA_WIDTH   	(64  ),
                  .DELAY_CYCLES 	(4   ))
              u_delay_reg_data_right_sb(
                  .clk          	(clk           ),
                  .rst_n        	(rst_n         ),
                  .din          	(data_right_unpacked          ),
                  .delay_switch 	(1'b1  ),
                  .dout         	(data_right_unpacked_d4          )
              );
    logic transposition_slect;

    logic [4*16-1:0] martix_out_transposition_1,martix_out_transposition_2;
    logic transposition_mode_1,transposition_mode_2;

    logic [4*16-1:0] martix_out_transposition_3,martix_out_transposition_4;
    logic transposition_mode_3,transposition_mode_4;

    parameter IDLE=4'd0;
    parameter AS_CALC=4'd1,AS_SAVE=4'd2;
    parameter SA_LOADWEIGHT=4'd3,SA_CALC=4'd4;
    parameter AS=2'b00,SB=2'b01,BS=2'b10,SA=2'b11;
    logic transposition_dir;
    logic systolic_enable;
    logic transposition_rst_sync;
    mem_ctrl u_mem_ctrl(
                 .clk            	(clk             ),
                 .rst_n          	(rst_n           ),
                 .ctrl_mode     	(ctrl_mode      ),
                 .calc_init      	(calc_init       ),

                 .BASE_ADDR_LEFT    (BASE_ADDR_LEFT    ),
                 .BASE_ADDR_RIGHT   (BASE_ADDR_RIGHT   ),
                 .BASE_ADDR_ADDSRC  (BASE_ADDR_ADDSRC  ),
                 .BASE_ADDR_SAVE  	(BASE_ADDR_SAVE   ),
                 .MATRIX_SIZE    	(MATRIX_SIZE     ),

                 .bram_data_1    	(bram_data_1     ),
                 .bram_data_2    	(bram_data_2     ),
                 .bram_data_3    	(bram_data_3     ),

                 .bram_addr_1    	(bram_addr_1     ),
                 .bram_addr_2    	(bram_addr_2     ),
                 .bram_addr_3    	(bram_addr_3     ),

                 .save_wen       	(save_wen        ),


                 .data_left      	(data_left       ),
                 .data_right     	(data_right      ),

                 .systolic_state   (systolic_state     ),
                 .systolic_mode   	(systolic_mode),
                 .systolic_enable     (systolic_enable),
                 .data_adder     	(data_adder),

                 .current_state  	(current_state   ),

                 .transposition_slect  (transposition_slect    ),
                 .transposition_rst_sync (transposition_rst_sync)

             );

    // 左矩阵转置器
    assign transposition_mode_1 = transposition_slect ? 1'b1 : 1'b0;
    assign transposition_mode_2 = transposition_slect ? 1'b0 : 1'b1;

    logic sb_mode_as_path;
    logic [63:0] data_left_processed;
    logic [63:0] data_right_matrix;
    logic [63:0] data_right_processed;
    logic [63:0] half_select_source;
    assign sb_mode_as_path = (ctrl_mode == SB) && ((current_state == AS_CALC) || (current_state == AS_SAVE));
    assign half_select_source = sb_mode_as_path ? data_left_unpacked : data_right_unpacked;
    assign data_left_processed = sb_mode_as_path ? HALF_SLECT_DATA : data_left_unpacked;

    transposition_top_default #(
                                  .DATA_WIDTH     	(16  ),
                                  .SYSTOLIC_WIDTH 	(4   ))
                              u_transposition_top_default_1(
                                  .clk        	(clk         ),
                                  .rst_n      	(rst_n       ),
                                  .martix_in  	(data_left_processed   ),
                                  .martix_out 	(martix_out_transposition_1  ),
                                  .mode       	(transposition_mode_1        ),
                                  //.dir        (transposition_dir       ),
                                  .rst_sync (transposition_rst_sync)
                              );

    transposition_top_default #(
                                  .DATA_WIDTH     	(16  ),
                                  .SYSTOLIC_WIDTH 	(4   ))
                              u_transposition_top_default_2(
                                  .clk        	(clk         ),
                                  .rst_n      	(rst_n       ),
                                  .martix_in  	(data_left_processed   ),
                                  .martix_out 	(martix_out_transposition_2  ),
                                  .mode       	(transposition_mode_2      ),
                                  //.dir        (transposition_dir      ),
                                  .rst_sync (transposition_rst_sync)
                              );
    //右矩阵转置器


    logic [63:0] HALF_SLECT_DATA;
    assign HALF_SLECT_DATA = (~delayaddr5) ? {
               {8{half_select_source[31]}}, half_select_source[31:24],  // Byte 3 -> [63:48]
               {8{half_select_source[23]}}, half_select_source[23:16],  // Byte 2 -> [47:32]
               {8{half_select_source[15]}}, half_select_source[15:8],   // Byte 1 -> [31:16]
               {8{half_select_source[7]}}, half_select_source[7:0]     // Byte 0 -> [15:0]
           }: {
               {8{half_select_source[63]}}, half_select_source[63:56],  // Byte 7 -> [63:48]
               {8{half_select_source[55]}}, half_select_source[55:48],  // Byte 6 -> [47:32]
               {8{half_select_source[47]}}, half_select_source[47:40],  // Byte 5 -> [31:16]
               {8{half_select_source[39]}}, half_select_source[39:32]   // Byte 4 -> [15:0]
           };
    logic delayaddr5;
    logic set_addr;
    delay_reg #(
                  .DATA_WIDTH   	(1  ),
                  .DELAY_CYCLES 	(1   ))
              u_delay_reg(
                  .clk          	(clk           ),
                  .rst_n        	(rst_n         ),
                  .din          	(set_addr          ),
                  .delay_switch 	(1'b1  ),
                  .dout         	(delayaddr5          )
              );

    always_comb begin
        case(current_state)
            AS_CALC: begin
                set_addr=(ctrl_mode == SB) ? bram_addr_1[2] : bram_addr_2[2];
            end
            AS_SAVE: begin
                set_addr=bram_addr_1[2];
            end
            SA_LOADWEIGHT: begin
                set_addr=bram_addr_1[2];
            end
            SA_CALC: begin
                set_addr=bram_addr_1[2];
            end
            default:
                set_addr=1'b0;
        endcase
    end
    assign transposition_mode_3 = transposition_slect ? 1'b1 : 1'b0;
    assign transposition_mode_4 = transposition_slect ? 1'b0 : 1'b1;
    assign data_right_matrix = sb_mode_as_path ? data_right_unpacked : HALF_SLECT_DATA;
    assign data_right_processed =(current_state == SA_CALC) ? sum_out : data_right_matrix;
    transposition_top_default #(
                                  .DATA_WIDTH     	(16  ),
                                  .SYSTOLIC_WIDTH 	(4   ))
                              u_transposition_top_default_3(
                                  .clk        	(clk         ),
                                  .rst_n      	(rst_n       ),
                                  .martix_in  	(data_right_processed  ),
                                  .martix_out 	(martix_out_transposition_3  ),
                                  .mode       	(transposition_mode_3        ),
                                  //.dir        (transposition_dir       ),
                                  .rst_sync (transposition_rst_sync)
                              );

    transposition_top_default #(
                                  .DATA_WIDTH     	(16  ),
                                  .SYSTOLIC_WIDTH 	(4   ))
                              u_transposition_top_default_4(
                                  .clk        	(clk         ),
                                  .rst_n      	(rst_n       ),
                                  .martix_in  	(data_right_processed    ),
                                  .martix_out 	(martix_out_transposition_4  ),
                                  .mode       	(transposition_mode_4      ),
                                  //.dir        (transposition_dir       ),
                                  .rst_sync (transposition_rst_sync)
                              );
    logic [63:0] sum_out_transposed;
    assign sum_out_transposed = (transposition_slect) ? martix_out_transposition_3 : martix_out_transposition_4 ;
    // output declaration of module systolic_top
    logic [4*16-1:0] a_in_raw;
    logic [4*16-1:0] b_in_raw;
    logic [4*16-1:0] sum_in_raw;
    logic [4*16-1:0] sum_out;
    logic systolic_mode;//mode 0：权重固定 mode 1：输出固定
    logic systolic_state;//state 0：数据传输  state 1：计算

    always_comb begin
        case(current_state)
            AS_CALC,AS_SAVE: begin
                a_in_raw = transposition_slect ? martix_out_transposition_1 : martix_out_transposition_2 ;
                if (sb_mode_as_path) begin
                    b_in_raw = data_right_unpacked_d4;
                end
                else begin
                    b_in_raw = transposition_slect ? martix_out_transposition_3 : martix_out_transposition_4 ;
                end
            end
            SA_LOADWEIGHT: begin
                a_in_raw = HALF_SLECT_DATA ;
                b_in_raw = 64'd0;
            end
            SA_CALC: begin
                a_in_raw = transposition_slect ? martix_out_transposition_1 : martix_out_transposition_2 ;
                b_in_raw = 0;
            end
            default: begin
                a_in_raw = 64'd0 ;
                b_in_raw = HALF_SLECT_DATA;
            end
        endcase
    end
    systolic_top #(
                     .DATA_WIDTH     	(16  ),
                     .SUM_WIDTH      	(16  ),
                     .SYSTOLIC_WIDTH 	(4   ))
                 u_systolic_top(
                     .clk        	(clk         ),
                     .rst_n      	(rst_n       ),
                     .a_in_raw   	(a_in_raw    ),
                     .b_in_raw   	(b_in_raw    ),
                     .sum_in_raw 	(sum_in_raw  ),
                     .sum_out    	(sum_out     ),
                     .mode       	(systolic_mode        ),
                     .state      	(systolic_state       ),
                     .enable     	(systolic_enable      )
                 );


    //加法器
    wire [16-1:0] sum1;
    wire [16-1:0] sum2;
    wire [16-1:0] sum3;
    wire [16-1:0] sum4;
    logic [4*16-1:0] data_adder;
    logic [4*16-1:0] data_adder_unpacked;
    logic [4*16-1:0] sum_out_mux;
    logic adder_sub_en;
    assign data_adder_unpacked = addsrc_unpack ? {
               data_adder[55:48], data_adder[63:56],
               data_adder[39:32], data_adder[47:40],
               data_adder[23:16], data_adder[31:24],
               data_adder[7:0],   data_adder[15:8]
           } : data_adder;
    always_comb begin
        if(current_state == SA_CALC) begin
            sum_out_mux = sum_out_transposed;
        end
        else begin
            sum_out_mux = sum_out;
        end
    end
    assign adder_sub_en = (ctrl_mode == BS) && (current_state == AS_SAVE);
    Adder_4 #(
                .DATA_WIDTH 	(16  ))
            u_Adder_4(
                .a1   	(sum_out_mux[16*1-1:16*0]   ),
                .a2   	(sum_out_mux[16*2-1:16*1]   ),
                .a3   	(sum_out_mux[16*3-1:16*2]   ),
                .a4   	(sum_out_mux[16*4-1:16*3]   ),
                .b1   	(data_adder_unpacked[16*1-1:16*0] ),
                .b2   	(data_adder_unpacked[16*2-1:16*1] ),
                .b3   	(data_adder_unpacked[16*3-1:16*2] ),
                .b4   	(data_adder_unpacked[16*4-1:16*3] ),
                .sum1 	(sum1  ),
                .sum2 	(sum2  ),
                .sum3 	(sum3  ),
                .sum4 	(sum4  ),
                .sub_en (adder_sub_en),
                .clk   	(clk    ),
                .rst_n 	(rst_n  )
            );
    always_comb begin
        // outpack: 对输出数据进行16bit元素高低字节交换
        if(outpack) begin
            bram_savedata = {sum4[7:0], sum4[15:8], sum3[7:0], sum3[15:8], sum2[7:0], sum2[15:8], sum1[7:0], sum1[15:8]};
        end
        else begin
            bram_savedata = {sum4, sum3, sum2, sum1};
        end
    end
endmodule
