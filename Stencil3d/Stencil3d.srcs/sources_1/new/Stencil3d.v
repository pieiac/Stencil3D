`timescale 1ns / 1ps

module stencil3d_comb #(
    // Define the size parameters for the 3D grid
    parameter integer HEIGHT_SIZE = 32,  // Number of layers (depth)
    parameter integer COL_SIZE    = 32,  // Number of columns (width)
    parameter integer ROW_SIZE    = 16,  // Number of rows (height)
    parameter integer SIZE        = (ROW_SIZE * COL_SIZE * HEIGHT_SIZE) // Total number of elements
)(
    // Coefficients for the stencil computation (C[0], C[1])
    input wire signed [31:0] C0,
    input wire signed [31:0] C1,

    // Input data bus (orig) containing SIZE elements, each 32-bit wide
    input wire signed [(SIZE*32)-1:0] orig_bus,

    // Output data bus (sol) containing SIZE elements, each 32-bit wide
    output wire signed [(SIZE*32)-1:0] sol_bus
);

// ===========================================================================
// 1) Internal arrays for handling input (orig) and output (sol) as indexed elements
//    Each array holds SIZE elements of 32-bit signed values
// ===========================================================================
wire signed [31:0] orig_array [0:SIZE-1]; // Input data array
wire signed [31:0] sol_array  [0:SIZE-1]; // Output data array

// ===========================================================================
// 2) Function to compute the linear index in the 3D grid
//    The 3D grid is indexed using (k, j, i) coordinates, where:
//      - k = row index (0 to ROW_SIZE-1)
//      - j = column index (0 to COL_SIZE-1)
//      - i = height index (0 to HEIGHT_SIZE-1)
//
//    The formula for the linear index is:
//      INDX(k, j, i) = k + ROW_SIZE * (j + COL_SIZE * i)
// ===========================================================================
function integer INDX;
    input integer k;
    input integer j;
    input integer i;
begin
    INDX = k + ROW_SIZE * (j + COL_SIZE * i);
end
endfunction

// ===========================================================================
// 3) Unpacking the input bus (orig_bus) into individual elements of orig_array
//    The bus stores SIZE elements, where each element is 32 bits wide.
//    To extract the ith element from orig_bus:
//      orig_array[i] = orig_bus[(i+1)*32 -1 : i*32]
// ===========================================================================
genvar idx;
generate
    for (idx = 0; idx < SIZE; idx = idx + 1) begin: UNPACK_ORIG
        assign orig_array[idx] = orig_bus[( (idx+1)*32 )-1 : (idx*32)];
    end
endgenerate

// ===========================================================================
// 4) Boundary Conditions - Copying edges of the 3D grid
//    The stencil operation is applied to internal elements, while boundary
//    elements remain unchanged (copied from the input).
// ===========================================================================

// ---------------------------------------------------------------------------
// Copy boundary - top and bottom planes (i = 0 and i = HEIGHT_SIZE-1)
// ---------------------------------------------------------------------------
genvar i, j, k;
generate
    for (j = 0; j < COL_SIZE; j = j + 1) begin : height_bound_col
        for (k = 0; k < ROW_SIZE; k = k + 1) begin : height_bound_row
            assign sol_array[INDX(k, j, 0)]             = orig_array[INDX(k, j, 0)];
            assign sol_array[INDX(k, j, HEIGHT_SIZE-1)] = orig_array[INDX(k, j, HEIGHT_SIZE-1)];
        end
    end
endgenerate

// ---------------------------------------------------------------------------
// Copy boundary - left and right columns (j = 0 and j = COL_SIZE-1)
// Applies to internal height layers (excluding i=0 and i=HEIGHT_SIZE-1)
// ---------------------------------------------------------------------------
generate
    for (i = 1; i < HEIGHT_SIZE-1; i = i + 1) begin : col_bound_height
        for (k = 0; k < ROW_SIZE; k = k + 1) begin : col_bound_row
            assign sol_array[INDX(k, 0, i)]           = orig_array[INDX(k, 0, i)];
            assign sol_array[INDX(k, COL_SIZE-1, i)] = orig_array[INDX(k, COL_SIZE-1, i)];
        end
    end
endgenerate

// ---------------------------------------------------------------------------
// Copy boundary - first and last rows (k = 0 and k = ROW_SIZE-1)
// Applies to internal height layers (excluding i=0 and i=HEIGHT_SIZE-1)
// Also excludes boundary columns (j=0 and j=COL_SIZE-1)
// ---------------------------------------------------------------------------
generate
    for (i = 1; i < HEIGHT_SIZE-1; i = i + 1) begin : row_bound_height
        for (j = 1; j < COL_SIZE-1; j = j + 1) begin : row_bound_col
            assign sol_array[INDX(0, j, i)]          = orig_array[INDX(0, j, i)];
            assign sol_array[INDX(ROW_SIZE-1, j, i)] = orig_array[INDX(ROW_SIZE-1, j, i)];
        end
    end
endgenerate

// ===========================================================================
// 5) Stencil Computation for Internal Elements
//    - Applied to elements inside the grid, excluding boundaries.
//    - Uses a 7-point stencil: center + 6 neighbors (above, below, left, right, front, back).
//    - The new value is computed as:
//        sol[k, j, i] = C0 * orig[k, j, i] + C1 * (sum of 6 neighbors)
// ===========================================================================
generate
    for (i = 1; i < HEIGHT_SIZE-1; i = i + 1) begin: loop_height
        for (j = 1; j < COL_SIZE-1; j = j + 1) begin: loop_col
            for (k = 1; k < ROW_SIZE-1; k = k + 1) begin: loop_row
                wire signed [31:0] sum0, sum1, mul0, mul1;

                // sum0 = central element
                assign sum0 = orig_array[INDX(k, j, i)];

                // sum1 = sum of 6 neighbors
                assign sum1 = orig_array[INDX(k,     j,   i+1)] +
                              orig_array[INDX(k,     j,   i-1)] +
                              orig_array[INDX(k,     j+1, i  )] +
                              orig_array[INDX(k,     j-1, i  )] +
                              orig_array[INDX(k+1,   j,   i  )] +
                              orig_array[INDX(k-1,   j,   i  )];

                // Multiply by coefficients
                assign mul0 = sum0 * C0;
                assign mul1 = sum1 * C1;

                // Compute final stencil output value
                assign sol_array[INDX(k, j, i)] = mul0 + mul1;
            end
        end
    end
endgenerate

// ===========================================================================
// 6) Packing the sol_array back into the output bus (sol_bus)
//    Each 32-bit element from sol_array is placed back into sol_bus.
// ===========================================================================
generate
    for (idx = 0; idx < SIZE; idx = idx + 1) begin: PACK_SOL
        assign sol_bus[((idx+1)*32)-1 : (idx*32)] = sol_array[idx];
    end
endgenerate

endmodule