`timescale 1ns / 1ps

module tb_stencil3d_comb;

//==========================================================================
// Parametri come in stencil.h
//==========================================================================
parameter integer HEIGHT_SIZE = 32;
parameter integer COL_SIZE    = 32;
parameter integer ROW_SIZE    = 16;
parameter integer SIZE        = (ROW_SIZE * COL_SIZE * HEIGHT_SIZE);

//==========================================================================
// Segnali di I/O per il DUT (Device Under Test)
//==========================================================================
reg  signed [31:0] C0, C1;                        // Coefficienti
reg  signed [(SIZE*32)-1:0] orig_bus;             // Bus di input (orig)
wire signed [(SIZE*32)-1:0] sol_bus;              // Bus di output (sol)

//==========================================================================
// Istanzia il DUT (stencil3d combinazionale con bus)
//==========================================================================
stencil3d_comb #(
  .HEIGHT_SIZE(HEIGHT_SIZE),
  .COL_SIZE(COL_SIZE),
  .ROW_SIZE(ROW_SIZE),
  .SIZE(SIZE)
) dut (
  .C0(C0),
  .C1(C1),
  .orig_bus(orig_bus),
  .sol_bus(sol_bus)
);

//==========================================================================
// Array temporaneo per caricare i dati di input.data in fase di init
//==========================================================================
reg signed [31:0] orig_array [0:SIZE-1];

//==========================================================================
// Variabili per la lettura file e per la scrittura su file di output
//==========================================================================
integer fd, code, i;
integer outfile;

//==========================================================================
// Blocco iniziale: Lettura di input.data + popolamento del bus
//==========================================================================
initial begin
  fd = $fopen("input.data","r");
  if(fd == 0) begin
    $display("ERROR: can't open input.data");
    $finish;
  end

  // Lettura della riga "%%"
  code = $fscanf(fd,"%%%*c");
  // Legge C0
  code = $fscanf(fd,"%d%*c", C0);
  // Legge C1
  code = $fscanf(fd,"%d%*c", C1);
  // L'altra riga "%%"
  code = $fscanf(fd,"%%%*c");

  // Legge i SIZE valori
  for(i=0; i<SIZE; i=i+1) begin
    code = $fscanf(fd, "%d%*c", orig_array[i]);
    if(code != 1) begin
      $display("ERROR: not enough data in input.data, index=%0d", i);
      $finish;
    end
  end

  // 4) Chiudi il file
  $fclose(fd);

  // 5) Carica i valori letti in un bus monodimensionale (orig_bus)
  //    Esempio di slicing discendente:
  //    orig_bus[((i+1)*32)-1 -: 32] = orig_array[i]
  for(i = 0; i < SIZE; i = i + 1) begin
    orig_bus[((i+1)*32) -1 -: 32] = orig_array[i];
  end

  //----------------------------------------------------------------------  
  // Messaggi iniziali di debug
  //----------------------------------------------------------------------
  $display("=== Start Simulation ===");
  $display("Coefficienti letti: C0=%d, C1=%d", C0, C1);
  $display("Esempio: orig_array[0] = %d, orig_array[SIZE-1] = %d",
            orig_array[0], orig_array[SIZE-1]);

  //======================================================================
  // 6) $monitor su alcuni segnali per debug: 
  //    - stampiamo "sol[0]" e "sol[1]" ogni volta che cambiano
  //======================================================================
  $monitor("time=%0t ns | sol[0]=%d | sol[1]=%d",
           $time,
           sol_bus[(1*32)-1 -: 32],
           sol_bus[(2*32)-1 -: 32]);

  //======================================================================
  // 7) Aspettiamo un po' di tempo di simulazione (combinational => 10ns)
  //======================================================================
  #10;

  //======================================================================
  // 8) Stampa "a video" di un subset di risultati (primi 5 e ultimi 5)
  //======================================================================
  $display("--- Primi 5 valori di sol ---");
  for(i = 0; i < 5; i = i + 1) begin
    $display(" sol[%0d] = %d", i, sol_bus[((i+1)*32)-1 -: 32]);
  end

  $display("--- Ultimi 5 valori di sol ---");
  for(i = SIZE-5; i < SIZE; i = i + 1) begin
    $display(" sol[%0d] = %d", i, sol_bus[((i+1)*32)-1 -: 32]);
  end

  //======================================================================
  // 9) A fine simulazione, scriviamo TUTTI i valori di sol in un file
  //======================================================================
  outfile = $fopen("verilog_output.txt", "w");
  if(outfile == 0) begin
    $display("ERROR: Couldn't open verilog_output.txt for writing");
    $finish;
  end

  for(i = 0; i < SIZE; i = i + 1) begin
    $fwrite(outfile, "%0d\n", $signed(sol_bus[((i+1)*32)-1 -: 32]));
  end


  $fclose(outfile);
  $display("Tutti i risultati sono stati scritti in verilog_output.txt");

  //======================================================================
  // 10) Fine simulazione
  //======================================================================
  $display("=== End Simulation ===");
  $finish;
end
endmodule