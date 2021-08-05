/* 
 * Do not change Module name 
*/
module main;

    reg clock;
    reg reset;
    
    reg [511:0] block;
    reg [255:0] initial_hash;
    
    wire [255:0] calculated_hash;
    
    sha256_round sha0 (
        .clock(clock),
        .reset(reset),
        .block(block),
        .initial_hash(initial_hash),
        .calculated_hash(calculated_hash));
        
    always #5 clock = ~clock;

    initial begin
    
        clock <= 0;
        reset <= 0;
        
        block <= 512'h00000058000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000726C64806F20776F68656C6C;
        initial_hash <= 256'h5be0cd191f83d9ab9b05688c510e527fa54ff53a3c6ef372bb67ae856a09e667;
        
        #1 reset <= 1;
        
        $display("%h decimal: %d", calculated_hash, calculated_hash[0 * 32 + 31:0 * 32 + 0]);
        #10 $display("%h decimal: %d", calculated_hash, calculated_hash[0 * 32 + 31:0 * 32 + 0]);
        #10 $display("%h decimal: %d", calculated_hash, calculated_hash[0 * 32 + 31:0 * 32 + 0]);
        #10 $display("%h decimal: %d", calculated_hash, calculated_hash[0 * 32 + 31:0 * 32 + 0]);
        
        
        #600 $display("%h decimal: %d", calculated_hash, calculated_hash[0 * 32 + 31:0 * 32 + 0]);
    
    
        $finish ;
    end
endmodule

//Module FSM representing a single round of (of 64) of the SHA-256 algorithm. This includes expansion (if round number is greater than 16) and compression into an input hash.
//A note about the clock: The rising edge a) shifts the extender shifter and b) stores the outputted hash into the intermediate hash storage. The falling edge incremements the counter
module sha256_round(input clock,
                    input reset,
                    input [511:0] block,
                    input [255:0] initial_hash,
                    output [255:0] calculated_hash);
                    
    // Counter
    wire [5:0] index;
    
    counter ct0 (.clock(clock), .reset(reset), .cnt(index));
                    
    // Shift register
    wire [31:0] selected_word;
    
    wire [31:0] w2;
    wire [31:0] w7;
    wire [31:0] w15;
    wire [31:0] w16;
    
    extender_shifter exs0 (
        .word(selected_word), 
        .clock(clock), 
        .reset(reset), 
        .w2(w2), 
        .w7(w7), 
        .w15(w15), 
        .w16(w16));
        
    // Extension logic
    wire [31:0] extension;
    
    extension_logic el0 (
        .w2(w2),
        .w7(w7),
        .w15(w15),
        .w16(w16),
        .extension(extension));
        
    // Block selecter
    
    wire [31:0] block_word;
    
    block_selector bs0 (.block(block), .index(index[3:0]), .item(block_word));
    
    // Extension/block
    
    extension_selector es0 (
        .extended(extension), 
        .selected(block_word), 
        .index(index), 
        .choice(selected_word));
        
    // Constants
    
    wire [31:0] constant;
    
    constants con0 (.index(index), .constant(constant));
    
    // Compression logic
    
    wire [255:0] compress_hash;
    wire [255:0] compressed_hash;
    
    compression_logic cmp0 (
        .w(selected_word), 
        .k(constant), 
        .input_hash(compress_hash), 
        .output_hash(compressed_hash));
    
    // Rolling hash
    
    wire [255:0] stored_hash;
    
    rolling_hash rh0 (
        .clock(clock), 
        .reset(reset), 
        .in_hash(compressed_hash),
        .out_hash(stored_hash));
    
    // Digest selector 
    
    digest_selector ds0 (
        .initial_hash(initial_hash), 
        .rolling_hash(stored_hash), 
        .index(index), 
        .hash(compress_hash));
        
    assign calculated_hash = compressed_hash;
                        
endmodule

// Stores the rolling 256-bit hash
module rolling_hash(input clock,
                    input reset,
                    input [255:0] in_hash,
                    output reg [255:0] out_hash);
                    
    always @ (posedge clock) begin 
        if (!reset)
            out_hash <= 0;
        else
            out_hash = in_hash;
    end
                    
endmodule

// 64-bit counter
module counter(input clock,
                input reset,
                output reg [5:0] cnt);
                
    always @ (negedge clock) begin 
        if (!reset)
            cnt <= 0;
        else
            cnt = cnt + 1;
    end
                
endmodule

// The first hash used in compression is the initial hash. After this we use the generated hash (rolling hash)
module digest_selector(input [255:0] initial_hash,
                        input [255:0] rolling_hash,
                        input [5:0] index,
                        output [255:0] hash);
                        
    assign hash = index == 0 ? initial_hash : rolling_hash;
                        
endmodule
                        

// Complete one round of compression using the input hash, expanded message schedule array and the round constants 
module compression_logic(input [31:0] w,
                        input [31:0] k,
                        input [255:0] input_hash,
                        output [255:0] output_hash);
         
    wire [31:0] a;
    wire [31:0] b;
    wire [31:0] c;
    wire [31:0] d;
    wire [31:0] e;
    wire [31:0] f;
    wire [31:0] g;
    wire [31:0] h;
    
    wire [31:0] S1;
    wire [31:0] ch;
    wire [31:0] temp1;
    wire [31:0] S0;
    wire [31:0] maj;
    wire [31:0] temp2;
    
    wire [31:0] test;

    assign a = input_hash[31:0];
    assign b = input_hash[63:32];
    assign c = input_hash[95:64];
    assign d = input_hash[127:96];
    assign e = input_hash[159:128];
    assign f = input_hash[191:160];
    assign g = input_hash[223:192];
    assign h = input_hash[255:224];
    
    assign S1 = { e[5:0], e[31:6] } ^ { e[10:0], e[31:11] } ^ { e[24:0], e[31:25] };
    assign ch = (e & f) ^ (~e & g);
    assign temp1 = h + S1 + ch + w + k;
    
    assign S0 = { a[1:0], a[31:2] } ^ { a[12:0], a[31:13] } ^ { a[21:0], a[31:22] };
    assign maj = (a & b) ^ (a & c) ^ (b & c);
    assign temp2 = S0 + maj;
    
    assign test = S1;
    
    assign output_hash = { g, f, e, d + temp1, c, b, a, temp1 + temp2 };
                        
endmodule

//Use index to select from one of the 64 SHA256 round constants
//Node: This would be implemented as a simple lookup-table (6-bit input, 32-bit output)
// Todo: Find a less cumbersome way to do this
module constants(input [5:0] index,
                 output [31:0] constant);

    localparam logic [2047:0] k =  2048'hc67178f2bef9a3f7a4506ceb90befffa8cc7020884c8781478a5636f748f82ee682e6ff35b9cca4f4ed8aa4a391c0cb334b0bcb52748774c1e376c0819a4c116106aa070f40e3585d6990624d192e819c76c51a3c24b8b70a81a664ba2bfe8a192722c8581c2c92e766a0abb650a735453380d134d2c6dfc2e1b213827b70a851429296706ca6351d5a79147c6e00bf3bf597fc7b00327c8a831c66d983e515276f988da5cb0a9dc4a7484aa2de92c6f240ca1cc0fc19dc6efbe4786e49b69c1c19bf1749bdc06a780deb1fe72be5d74550c7dc3243185be12835b01d807aa98ab1c5ed5923f82a459f111f13956c25be9b5dba5b5c0fbcf71374491428a2f98;
    
    assign constant = { k[index * 32 + 31],
                    k[index * 32 + 30],
                    k[index * 32 + 29],
                    k[index * 32 + 28],
                    k[index * 32 + 27],
                    k[index * 32 + 26],
                    k[index * 32 + 25],
                    k[index * 32 + 24],
                    k[index * 32 + 23],
                    k[index * 32 + 22],
                    k[index * 32 + 21],
                    k[index * 32 + 20],
                    k[index * 32 + 19],
                    k[index * 32 + 18],
                    k[index * 32 + 17],
                    k[index * 32 + 16],
                    k[index * 32 + 15],
                    k[index * 32 + 14],
                    k[index * 32 + 13],
                    k[index * 32 + 12],
                    k[index * 32 + 11],
                    k[index * 32 + 10],
                    k[index * 32 + 9],
                    k[index * 32 + 8],
                    k[index * 32 + 7],
                    k[index * 32 + 6],
                    k[index * 32 + 5],
                    k[index * 32 + 4],
                    k[index * 32 + 3],
                    k[index * 32 + 2],
                    k[index * 32 + 1],
                    k[index * 32 + 0]};
        
endmodule

// Use an index to select an element in an array of 64 lots of 32-bit words
// Todo: Find a less cumbersome way to do this
module block_selector(input [511:0] block,
                        input [3:0] index,
                        output [31:0] item);
         
    assign item = { block[index * 32 + 31],
                    block[index * 32 + 30],
                    block[index * 32 + 29],
                    block[index * 32 + 28],
                    block[index * 32 + 27],
                    block[index * 32 + 26],
                    block[index * 32 + 25],
                    block[index * 32 + 24],
                    block[index * 32 + 23],
                    block[index * 32 + 22],
                    block[index * 32 + 21],
                    block[index * 32 + 20],
                    block[index * 32 + 19],
                    block[index * 32 + 18],
                    block[index * 32 + 17],
                    block[index * 32 + 16],
                    block[index * 32 + 15],
                    block[index * 32 + 14],
                    block[index * 32 + 13],
                    block[index * 32 + 12],
                    block[index * 32 + 11],
                    block[index * 32 + 10],
                    block[index * 32 + 9],
                    block[index * 32 + 8],
                    block[index * 32 + 7],
                    block[index * 32 + 6],
                    block[index * 32 + 5],
                    block[index * 32 + 4],
                    block[index * 32 + 3],
                    block[index * 32 + 2],
                    block[index * 32 + 1],
                    block[index * 32 + 0]};
                        
endmodule

// If we need words w[0..15] then we select get them from the 512-bit block. Otherwise we use the value from the extend_logic module 
module extension_selector(input [31:0] extended,
                            input [31:0] selected,
                            input [5:0] index,
                            output [31:0] choice);
         
    assign choice = index < 16 ? selected : extended; 
                            
endmodule

// Logic to extend the last 16 words into a 17th
module extension_logic(input [31:0] w2,
                        input [31:0] w7,
                        input [31:0] w15,
                        input [31:0] w16,
                        output [31:0] extension);

    wire [31:0] s0;
    wire [31:0] s1;

    assign s0 = { w15[6:0], w15[31:7] } ^ { w15[17:0], w15[31:18] } ^ (w15 >> 3);
    assign s1 = { w2[16:0], w2[31:17] } ^ { w2[18:0], w2[31:19] } ^ (w2 >> 10);
    
    assign extension = w16 + s0 + w7 + s1;
               
endmodule

// 16x32-bit shift register exposing words at positions 1, 6, 15 and 16 (for w[i-2], w[i-7], w[i-15] and w[i-16], respectively)
module extender_shifter(input [31:0] word,
                        input clock,
                        input reset,
                        output [31:0] w2,
                        output [31:0] w7,
                        output [31:0] w15,
                        output [31:0] w16);

    // 512-bit register containing the last 16 values in the message extension algorithm
    reg [511:0] w_register;

    // Shift the values by one word and insert the input word at the beginning
    always @ (posedge clock)
        if (!reset)
            w_register <= 0;
        else begin
            w_register <= { w_register[479:0], word };
        end
    
    // Output the 4 values (w[i-2], w[i-7], w[i-15] and w[i-16])
    assign w2 = w_register[1 * 32 + 31:1 * 32];
    assign w7 = w_register[6 * 32 + 31:6 * 32];
    assign w15 = w_register[14 * 32 + 31:14 * 32];
    assign w16 = w_register[15 * 32 + 31:15 * 32];

endmodule