

import uvm_pkg::*;
`include "uvm_macros.svh"

//sequence_item-------------------------------------------------------------------
class sequence_item extends uvm_sequence_item;
  //`uvm_object_utils(sequence_item);
  
  rand bit rd,wr;
  rand bit[7:0] data_in;
  bit full;
  bit empty;
  bit[7:0] data_out;
  
  function new(string name="sequence_item");
    super.new(name);
  endfunction
    
  `uvm_object_utils_begin(sequence_item)
  `uvm_field_int(rd,UVM_ALL_ON)
  `uvm_field_int(wr,UVM_ALL_ON)
  `uvm_field_int(data_in,UVM_ALL_ON)
  `uvm_field_int(full,UVM_ALL_ON)
  `uvm_field_int(empty,UVM_ALL_ON)
  `uvm_field_int(data_out,UVM_ALL_ON)
  `uvm_object_utils_end
  
  
  constraint wr1{wr dist{1:=60,0:=40};}
                    
  constraint rd1{rd dist{0:=60,1:=40};}                 
  
  constraint wr_rd { rd !=wr ;}
  
endclass
  
  
//Sequence------------------------------------------------------------------------
class fifo_sequence extends uvm_sequence#(sequence_item);
  `uvm_object_utils(fifo_sequence)
  
  sequence_item trans;
  
  function new(string name="fifo_sequence");
    super.new(name);
  endfunction
  
  virtual task body();
    int t=0;
    repeat(256)
    begin
      t=t+1;
      $display("\n");
      $display("Start of transaction number:----------------> %0d",t);
    trans=sequence_item::type_id::create("trans");
    
    wait_for_grant();
    
    trans.randomize();
    
    send_request(trans);
    
    wait_for_item_done();
    end
    
  endtask
endclass


//fifo_sequencer------------------------------------------------------------------
class fifo_sequencer extends uvm_sequencer#(sequence_item);
  `uvm_component_utils(fifo_sequencer)
  
  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction
  
endclass




//fifo_driver---------------------------------------------------------------------
class fifo_driver extends uvm_driver#(sequence_item);
  `uvm_component_utils(fifo_driver)
  
  uvm_analysis_port#(sequence_item) cov_port;
  
  virtual IF if1;
  sequence_item trans;  
  
  
  function new(string name,uvm_component parent);
    super.new(name,parent);
    uvm_config_db#(virtual IF)::get(this,"","if1",if1);
    cov_port=new("cov_port",this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    if1.reset=1;
    #1  if1.reset=0;
    forever 
      begin
        seq_item_port.get_next_item(trans);
        
        cov_port.write(trans);//port for coverage group component
            
        drive();
        
        seq_item_port.item_done();
      end
 endtask
  
  virtual task drive();
    if1.wr <= trans.wr;
    if1.rd <= trans.rd;
    if1.data_in <= trans.data_in;
   
  
    @(posedge if1.clk)
   // `uvm_info(get_type_name(),"Driver after clock",UVM_LOW);
     #3;
  endtask
      
endclass




//fifo_monitor--------------------------------------------------------------------
class fifo_monitor extends uvm_monitor;
  `uvm_component_utils(fifo_monitor)
  virtual IF if1;
  sequence_item tsqnc;
  uvm_analysis_port#(sequence_item) mon_port;// Analysis port
  
  
  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction
  
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
   if(!uvm_config_db#(virtual IF)::get(this,"","if1",if1))
     begin
     $display("Error in {monitor}");
     end
    
    tsqnc=sequence_item::type_id::create("tsqnc");
    mon_port=new("mon_port",this);   // Analysis port creation
 endfunction
  
  
  virtual task run_phase(uvm_phase phase);
    forever
      begin
        @(posedge if1.clk)
        tsqnc.wr=if1.wr;
        tsqnc.rd=if1.rd;
        tsqnc.data_in=if1.data_in;
        #2;
        tsqnc.full=if1.full;
        tsqnc.empty=if1.empty;
        tsqnc.data_out=if1.data_out;
        
        mon_port.write(tsqnc);          // Analysis port transfers
      end
  endtask
  
endclass


//subscriber---------------------------------------------------



class cover_model extends uvm_component;
  
   sequence_item trans;
  uvm_analysis_imp#(sequence_item,cover_model) analysis_imp;
  `uvm_component_utils(cover_model)
  
  covergroup my_cover;
    option.per_instance=1;
    //option.auto_bin_max=256;
    
    c1:coverpoint trans.wr;
    c2:coverpoint trans.rd;
    c3:coverpoint trans.data_in;
  endgroup
  
  
  function new(string name="cover_model",uvm_component parent);
    super.new(name,parent);
    my_cover =new();
    analysis_imp=new("analysis_imp",this);
  endfunction
  
  virtual function void write(sequence_item trans);
    this.trans=trans;
    my_cover.sample();
  endfunction
    
endclass



//fifo_agent---------------------------------------------------------------------

class fifo_agent extends uvm_agent;
  `uvm_component_utils(fifo_agent)
  
   fifo_monitor montr;
   fifo_sequencer seqncr;
   fifo_driver  dvr;
   cover_model cvr;
  
  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    dvr= fifo_driver::type_id::create("dvr",this);
    seqncr= fifo_sequencer::type_id::create("seqncr",this);
    montr=fifo_monitor::type_id::create("montr",this);
    
    cvr=new("cvr",this);
  endfunction
  
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    dvr.seq_item_port.connect(seqncr.seq_item_export);
    dvr.cov_port.connect(cvr.analysis_imp);
  endfunction

endclass
       


//fifo_scoreboard-----------------------------------------------------------------
class fifo_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(fifo_scoreboard)
  
  sequence_item transq[$];
  
  uvm_analysis_imp#(sequence_item,fifo_scoreboard) scr_export;
  bit [7:0] din[$];
  bit [7:0] temp;
  
  
  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction
  
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    scr_export=new("scr_export",this);   //Analysis export creation
  endfunction
  
  virtual function write(sequence_item tsqnc);
    transq.push_back(tsqnc);  // Quee push instruction
  endfunction
  
  
   
  virtual task run_phase(uvm_phase phase);
    sequence_item tsqnc;
    forever
      begin
        wait(transq.size > 0);
        tsqnc=transq.pop_front();
        
        if(tsqnc.wr==1'b1)
          begin
            din.push_front(tsqnc.data_in);
            $display("[SOC] data stored in FIFO :%d ",tsqnc.data_in);
          end


        if(tsqnc.rd==1'b1)
          begin

            if(tsqnc.empty==1'b0)
              begin
                temp=din.pop_back;
                $display("{SOC} data poped from FIFO : %d",temp);
                       if(temp==tsqnc.data_out) 
                           begin
                          `uvm_info(get_type_name(),"DATA IS MATCHED",UVM_LOW);
                           end

                          else
                            `uvm_error(get_type_name(),"DATA IS MIS_MATCHED");
              end
            else
              $display("[SOC] Empty");
         end
       // ->next;
      end
   endtask
  
endclass



//fifo_env---------------------------------------------------------------------

class fifo_env extends uvm_env;
  `uvm_component_utils(fifo_env)
  
  fifo_scoreboard scr_bd;
  fifo_agent agnt;
  
  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    scr_bd= fifo_scoreboard::type_id::create("scr_bd",this);
    agnt= fifo_agent::type_id::create("agnt",this);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agnt.montr.mon_port.connect(scr_bd.scr_export);
  endfunction
 
endclass
       
  

//fifo_test---------------------------------------------------------------------


class fifo_test extends uvm_test;
  `uvm_component_utils(fifo_test)
  
   fifo_sequence seqnce;
   fifo_env env1;

  function new(string name="fifo_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seqnce= fifo_sequence::type_id::create("seqnce");
    env1= fifo_env::type_id::create("env1",this);
  endfunction
  
  task run_phase(uvm_phase phase); 
    phase.raise_objection(this);
    seqnce.start(env1.agnt.seqncr);
    phase.drop_objection(this);
  endtask
  
endclass
       
  

   
//module top---------------------------------------------------------------------

 module top;
 
   IF if1();
   
   FIFO fifo1(.clk(if1.clk),
               .wr(if1.wr),
               .rd(if1.rd),
               .data_in(if1.data_in),
               .reset(if1.reset),
               .data_out(if1.data_out),
               .full(if1.full),
               .empty(if1.empty));
      
   always #5 if1.clk = ~if1.clk;

   initial
     begin
     if1.clk=0;
     uvm_config_db#(virtual IF)::set(null,"*","if1",if1);
     run_test("fifo_test");
     end
   
   initial
     begin
        $dumpfile("dump.vcd"); 
        $dumpvars;
     end
   
 endmodule
  
  
  


















//   initial
//    begin
//    $monitor("data_in:%d rd_addr=%d exp_data:%d @[%0t]",if1.data_in,fifo1.rd_addr-1,if1.data_out,$time);
//    end
   
//    always@(fifo1.mem[0],fifo1.mem[1],fifo1.mem[2],fifo1.mem[3],fifo1.mem[4])
//    begin
//    for(int i=0;i<10;i++)
//       begin
//       $display("mem[%0d]=%0d",i,fifo1.mem[i]);
//       end
//    end
  