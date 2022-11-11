// Code your design here
// Code your design here
// Code your design here


module FIFO(input clk,
            input reset,
            input wr,
            input rd,
            input[7:0]data_in,
            output [7:0]data_out,
            output reg full,
            output reg empty);
  
  reg [7:0] data_out1;
  reg [5:0] wr_addr;
  reg [5:0] rd_addr;
 
  reg [6:0] counter;
  
  reg [7:0] mem[63:0];

  
  assign full=(counter==64) ? 1'b1:1'b0;
  assign empty=(counter==0) ? 1'b1:1'b0;
  
  assign data_out=data_out1;
  
  always @(posedge clk, reset)
    begin
      if(reset==1)
            begin
                wr_addr=0;
                rd_addr=0;
                counter=0;
                data_out1=0;
                for(int i=0;i<64;i++)
                begin
                  mem[i]=8'b0;
                end
              
            end
      else
           begin
             if((wr==1)&&(full==0))
                begin
                mem[wr_addr]=data_in;
                counter=counter+1'b1;
                wr_addr=wr_addr+1'b1;
                end

             if((rd==1)&&(empty==0))
                begin
                data_out1=mem[rd_addr];
                counter=counter-1'b1;
                rd_addr=rd_addr+1'b1;
                end
           end
           
    end
        
endmodule 
      



      
interface IF;
  logic clk,reset;
  logic wr,rd;
  logic [7:0]data_in;
  logic [7:0]data_out;
  logic full;
  logic empty;
endinterface
      
  





      
      
      
      
      
      
      
      
      