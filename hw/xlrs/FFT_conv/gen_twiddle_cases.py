import math

Q15_ONE = 1 << 15

lengths = [2, 4, 8, 16, 32, 64, 128, 256]

with open("twiddle_cases_256.svh", "w") as f:
    f.write("""task automatic get_twiddle(
  input  logic [31:0] length,
  input  logic [31:0] j,
  input  logic        inverse,
  output logic signed [31:0] re,
  output logic signed [31:0] im
);
  logic signed [31:0] im_fwd;
  begin
    re     = 32'sd0;
    im_fwd = 32'sd0;

    case (length)
""")

    for length in lengths:
        f.write(f"\n      32'd{length}: begin\n")
        f.write("        case (j)\n")

        half = length // 2
        for j in range(half):
            angle = -2.0 * math.pi * j / length

            re = int(math.cos(angle) * Q15_ONE)
            im = int(math.sin(angle) * Q15_ONE)

            f.write(
                f"          32'd{j}: begin re = 32'sd{re}; im_fwd = 32'sd{im}; end\n"
            )

        f.write("          default: begin re = 32'sd0; im_fwd = 32'sd0; end\n")
        f.write("        endcase\n")
        f.write("      end\n")

    f.write("""
      default: begin
        re     = 32'sd0;
        im_fwd = 32'sd0;
      end
    endcase

    if (inverse) begin
      im = -im_fwd;
    end
    else begin
      im = im_fwd;
    end
  end
endtask
""")