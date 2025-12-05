`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/11/2025 10:35:31 AM
// Design Name: 
// Module Name: aes_subword
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module aes_subword(
input [31:0] w,
output [31:0] w_sub
    );
    
    wire [7:0] s3,s2,s1,s0;
    
    s_box S3(.x(w[31:28]), .y(w[27:24]), .out(s3));
    s_box S2(.x(w[23:20]), .y(w[19:16]); 
    
endmodule
