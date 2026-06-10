import xbox_def_pkg::*;

module FFT_conv (
  input        clk,
  input        rst_n,

  // Command Status Register Interface
  input        [XBOX_NUM_REGS-1:0][31:0] host_regs,
  input  logic [XBOX_NUM_REGS-1:0]       host_regs_valid_pulse,
  output logic [XBOX_NUM_REGS-1:0][31:0] host_regs_data_out,
  output logic [XBOX_NUM_REGS-1:0]       host_regs_valid_out,
  input  logic [XBOX_NUM_REGS-1:0]       host_regs_read_pulse,

  mem_intf_read.client_read   mem_intf_read,
  mem_intf_write.client_write mem_intf_write
);

  // ============================================================
  // Parameters
  // ============================================================

  localparam int MAX_N = 256;

  // ============================================================
  // Register indexes
  // Must match the C code.
  // ============================================================

  enum {
     C_ADDR_REG_IDX     = 0,
     X_ADDR_REG_IDX     = 1,
     Y_ADDR_REG_IDX     = 2,
     N_REG_IDX          = 3,
     MODE_REG_IDX       = 4,
     START_REG_IDX      = 5,
     DONE_REG_IDX       = 6
  } regs_idx;

  // ============================================================
  // Config wires from host registers
  // ============================================================

  logic [XMEM_ADDR_WIDTH-1:0] c_addr;
  logic [XMEM_ADDR_WIDTH-1:0] x_addr;
  logic [XMEM_ADDR_WIDTH-1:0] y_addr;

  logic [31:0] n;
  logic [31:0] mode;

  logic start_accel;
  logic accel_done;
  logic clear_done_on_read;

  assign c_addr = host_regs[C_ADDR_REG_IDX][XMEM_ADDR_WIDTH-1:0];
  assign x_addr = host_regs[X_ADDR_REG_IDX][XMEM_ADDR_WIDTH-1:0];
  assign y_addr = host_regs[Y_ADDR_REG_IDX][XMEM_ADDR_WIDTH-1:0];

  assign n    = host_regs[N_REG_IDX];
  assign mode = host_regs[MODE_REG_IDX];

  assign start_accel = host_regs[START_REG_IDX][0] &&
                       host_regs_valid_pulse[START_REG_IDX];

  assign clear_done_on_read = (host_regs_read_pulse == (1 << DONE_REG_IDX));

  // ============================================================
  // Internal buffers
  // ============================================================

  logic signed [7:0] c_buf [0:MAX_N-1];
  logic signed [7:0] x_buf [0:MAX_N-1];

  // Later we will probably add:
  // A_re/A_im for FFT(C)
  // B_re/B_im for FFT(X)
  // OUT_re/OUT_im for pointwise multiplication + IFFT
  // y_buf for final int8 output

  // Current transaction bookkeeping
  logic [31:0] remaining_size;
  logic [5:0]  crnt_size;

  logic [31:0] index;

  logic [XMEM_ADDR_WIDTH-1:0] crnt_rd_addr;
  logic [XMEM_ADDR_WIDTH-1:0] crnt_wr_addr;

  logic [BYTES_PER_XMEM_LINE-1:0][7:0] write_data;

  // ============================================================
  // FSM states
  // ============================================================

  enum {
    IDLE,

    INIT_LOAD_C,
    LOAD_C,

    INIT_LOAD_X,
    LOAD_X,

    FFT_C,
    FFT_X,
    POINTWISE_MUL,
    IFFT,

    INIT_WRITE_Y,
    WRITE_Y,

    DONE
  } next_state, state;

  // ============================================================
  // DONE register logic
  // Same style as xmemcpy_ref
  // ============================================================

  logic [XBOX_NUM_REGS-1:0][31:0] host_regs_data_out_ps;

  always_comb begin
    host_regs_data_out_ps = host_regs_data_out;

    if (accel_done) begin
      host_regs_data_out_ps[DONE_REG_IDX][0] = 1'b1;
    end
    else if (clear_done_on_read) begin
      host_regs_data_out_ps[DONE_REG_IDX][0] = 1'b0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      host_regs_data_out <= '0;
    end
    else begin
      host_regs_data_out <= host_regs_data_out_ps;
    end
  end

  always_comb begin
    host_regs_valid_out = '0;
    host_regs_valid_out[DONE_REG_IDX] = host_regs_data_out[DONE_REG_IDX][0];
  end

  // ============================================================
  // Current chunk size
  // crnt_size = min(remaining_size, BYTES_PER_XMEM_LINE)
  // ============================================================

  assign crnt_size = (remaining_size >= BYTES_PER_XMEM_LINE) ?
                     BYTES_PER_XMEM_LINE[$clog2(BYTES_PER_XMEM_LINE):0] :
                     remaining_size[$clog2(BYTES_PER_XMEM_LINE):0];

  // ============================================================
  // Prepare write data
  // Stage for now:
  //   Y = C
  //
  // Later:
  //   write_data[b] = y_buf[index + b];
  // ============================================================

  always_comb begin
    write_data = '0;

    for (int b = 0; b < BYTES_PER_XMEM_LINE; b++) begin
      if (b < crnt_size) begin
        write_data[b] = c_buf[index + b];
      end
    end
  end

  // ============================================================
  // FSM combinational logic
  // ============================================================

  always_comb begin

    // Defaults
    next_state = state;

    mem_intf_read.mem_req        = 1'b0;
    mem_intf_read.mem_start_addr = crnt_rd_addr;
    mem_intf_read.mem_size_bytes = crnt_size;

    mem_intf_write.mem_req        = 1'b0;
    mem_intf_write.mem_start_addr = crnt_wr_addr;
    mem_intf_write.mem_size_bytes = crnt_size;
    mem_intf_write.mem_data       = write_data;

    accel_done = 1'b0;

    case (state)

      // ----------------------------------------------------------
      // Wait for software START
      // ----------------------------------------------------------
      IDLE: begin
        if (start_accel) begin
          next_state = INIT_LOAD_C;
        end
      end

      // ----------------------------------------------------------
      // Initialize C loading
      // ----------------------------------------------------------
      INIT_LOAD_C: begin
        next_state = LOAD_C;
      end

      // ----------------------------------------------------------
      // Load C vector from memory into c_buf
      // ----------------------------------------------------------
      LOAD_C: begin
        mem_intf_read.mem_req        = 1'b1;
        mem_intf_read.mem_start_addr = crnt_rd_addr;
        mem_intf_read.mem_size_bytes = crnt_size;

        if (mem_intf_read.mem_valid) begin
          if (remaining_size <= crnt_size) begin
            next_state = INIT_LOAD_X;
          end
        end
      end

      // ----------------------------------------------------------
      // Initialize X loading
      // ----------------------------------------------------------
      INIT_LOAD_X: begin
        next_state = LOAD_X;
      end

      // ----------------------------------------------------------
      // Load X vector from memory into x_buf
      // ----------------------------------------------------------
      LOAD_X: begin
        mem_intf_read.mem_req        = 1'b1;
        mem_intf_read.mem_start_addr = crnt_rd_addr;
        mem_intf_read.mem_size_bytes = crnt_size;

        if (mem_intf_read.mem_valid) begin
          if (remaining_size <= crnt_size) begin
            next_state = FFT_C;
          end
        end
      end

      // ----------------------------------------------------------
      // Placeholder for FFT(C)
      // Later:
      //   start FFT engine on c_buf
      //   wait for fft_done
      // ----------------------------------------------------------
      FFT_C: begin
        next_state = FFT_X;
      end

      // ----------------------------------------------------------
      // Placeholder for FFT(X)
      // Later:
      //   start FFT engine on x_buf
      //   wait for fft_done
      // ----------------------------------------------------------
      FFT_X: begin
        next_state = POINTWISE_MUL;
      end

      // ----------------------------------------------------------
      // Placeholder for pointwise complex multiplication
      // Later:
      //   OUT[k] = FFT_C[k] * FFT_X[k]
      // ----------------------------------------------------------
      POINTWISE_MUL: begin
        next_state = IFFT;
      end

      // ----------------------------------------------------------
      // Placeholder for inverse FFT
      // Later:
      //   run IFFT on OUT
      // ----------------------------------------------------------
      IFFT: begin
        next_state = INIT_WRITE_Y;
      end

      // ----------------------------------------------------------
      // Initialize Y writing
      // ----------------------------------------------------------
      INIT_WRITE_Y: begin
        next_state = WRITE_Y;
      end

      // ----------------------------------------------------------
      // Write Y vector to memory
      // For now: Y = C
      // ----------------------------------------------------------
      WRITE_Y: begin
        mem_intf_write.mem_req        = 1'b1;
        mem_intf_write.mem_start_addr = crnt_wr_addr;
        mem_intf_write.mem_size_bytes = crnt_size;
        mem_intf_write.mem_data       = write_data;

        if (mem_intf_write.mem_ack) begin
          if (remaining_size <= crnt_size) begin
            next_state = DONE;
          end
        end
      end

      // ----------------------------------------------------------
      // Signal done to software
      // ----------------------------------------------------------
      DONE: begin
        accel_done = 1'b1;

        if (clear_done_on_read) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end

    endcase
  end

  // ============================================================
  // FSM sequential logic
  // ============================================================

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end
    else begin
      state <= next_state;
    end
  end

  // ============================================================
  // Datapath sequential logic
  // ============================================================

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin

      remaining_size <= 0;
      index          <= 0;
      crnt_rd_addr   <= 0;
      crnt_wr_addr   <= 0;

      for (int i = 0; i < MAX_N; i++) begin
        c_buf[i] <= '0;
        x_buf[i] <= '0;
      end

    end
    else begin

      case (state)

        // --------------------------------------------------------
        // Setup for loading C
        // --------------------------------------------------------
        INIT_LOAD_C: begin
          crnt_rd_addr   <= c_addr;
          remaining_size <= n;
          index          <= 0;
        end

        // --------------------------------------------------------
        // Store C chunk into c_buf
        // --------------------------------------------------------
        LOAD_C: begin
          if (mem_intf_read.mem_valid) begin

            for (int b = 0; b < BYTES_PER_XMEM_LINE; b++) begin
              if (b < crnt_size) begin
                c_buf[index + b] <= mem_intf_read.mem_data[b];
              end
            end

            crnt_rd_addr   <= crnt_rd_addr + crnt_size;
            index          <= index + crnt_size;
            remaining_size <= remaining_size - crnt_size;
          end
        end

        // --------------------------------------------------------
        // Setup for loading X
        // --------------------------------------------------------
        INIT_LOAD_X: begin
          crnt_rd_addr   <= x_addr;
          remaining_size <= n;
          index          <= 0;
        end

        // --------------------------------------------------------
        // Store X chunk into x_buf
        // --------------------------------------------------------
        LOAD_X: begin
          if (mem_intf_read.mem_valid) begin

            for (int b = 0; b < BYTES_PER_XMEM_LINE; b++) begin
              if (b < crnt_size) begin
                x_buf[index + b] <= mem_intf_read.mem_data[b];
              end
            end

            crnt_rd_addr   <= crnt_rd_addr + crnt_size;
            index          <= index + crnt_size;
            remaining_size <= remaining_size - crnt_size;
          end
        end

        // --------------------------------------------------------
        // Placeholder states.
        // Later these states will update FFT buffers/counters.
        // For now, they do not change datapath.
        // --------------------------------------------------------
        FFT_C: begin
          // Future: run FFT on C vector
        end

        FFT_X: begin
          // Future: run FFT on X vector
        end

        POINTWISE_MUL: begin
          // Future: multiply FFT(C) and FFT(X) pointwise
        end

        IFFT: begin
          // Future: run inverse FFT
        end

        // --------------------------------------------------------
        // Setup for writing Y
        // --------------------------------------------------------
        INIT_WRITE_Y: begin
          crnt_wr_addr   <= y_addr;
          remaining_size <= n;
          index          <= 0;
        end

        // --------------------------------------------------------
        // Write current output chunk into Y
        // For now: output is still c_buf
        // --------------------------------------------------------
        WRITE_Y: begin
          if (mem_intf_write.mem_ack) begin
            crnt_wr_addr   <= crnt_wr_addr + crnt_size;
            index          <= index + crnt_size;
            remaining_size <= remaining_size - crnt_size;
          end
        end

        DONE: begin
          index          <= 0;
          remaining_size <= 0;
        end

        default: begin
          // Hold values
        end

      endcase
    end
  end

  // ============================================================
  // Optional debug prints for simulation
  // You can comment this block out after debug.
  // ============================================================

  
  always @(posedge clk) begin
    if (state != next_state) begin
      $display("[%0t] FFT_conv state %0d -> %0d", $time, state, next_state);
    end
  end

  function string state_name(input int s);
  case (s)
    IDLE:           state_name = "IDLE";
    INIT_LOAD_C:    state_name = "INIT_LOAD_C";
    LOAD_C:         state_name = "LOAD_C";
    INIT_LOAD_X:    state_name = "INIT_LOAD_X";
    LOAD_X:         state_name = "LOAD_X";
    FFT_C:          state_name = "FFT_C";
    FFT_X:          state_name = "FFT_X";
    POINTWISE_MUL:  state_name = "POINTWISE_MUL";
    IFFT:           state_name = "IFFT";
    INIT_WRITE_Y:   state_name = "INIT_WRITE_Y";
    WRITE_Y:        state_name = "WRITE_Y";
    DONE:           state_name = "DONE";
    default:        state_name = "UNKNOWN";
  endcase
endfunction

always @(posedge clk) begin
  if (state != next_state) begin
    $display("[%0t] FFT_conv state: %s -> %s",
             $time, state_name(state), state_name(next_state));
  end
end
endmodule