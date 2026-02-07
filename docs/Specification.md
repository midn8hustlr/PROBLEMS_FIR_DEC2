# Specification: Symmetric FIR Filter with Decimation by 2

## 1. FIR Filter Basics

A Finite Impulse Response (FIR) filter computes a weighted sum of input samples:

```
y[n] = Σ h[k] * x[n-k]  for k = 0 to N-1
```

Where:
- `x[n]` is the input signal
- `y[n]` is the output signal
- `h[k]` are the filter coefficients (N taps)

## 2. Symmetric Coefficients

A symmetric FIR filter has coefficients where `h[k] = h[N-1-k]`. For a 16-tap filter:
- h[0] = h[15]
- h[1] = h[14]
- h[2] = h[13]
- ... and so on

This means only N/2 unique coefficients are needed (8 for a 16-tap filter).

### Exploiting Symmetry

With symmetric coefficients, the filter equation can be rewritten:

```
y[n] = h[0]*(x[n] + x[n-(N-1)]) + h[1]*(x[n-1] + x[n-(N-2)]) + ... + h[N/2-1]*(x[n-(N/2-1)] + x[n-N/2])
```

By **pre-adding symmetric sample pairs** before multiplication, we halve the number of multiplications.

## 3. Decimation by 2

With decimation by 2, only every other output sample is computed. Computing y[2n+1]:

```
y[2n+1] = Σ h[k] * x[2n+1-k]  for k = 0 to N-1
```

This means we have 2 input clock cycles available per output sample.

## 4. Polyphase Decomposition

Polyphase decomposition splits the input into separate sub-sequences based on sample index parity:
- **Even samples**: x_e[m] = x[2m] → {x[0], x[2], x[4], ...}
- **Odd samples**: x_o[m] = x[2m+1] → {x[1], x[3], x[5], ...}

Each sub-sequence is stored in its own delay line (shift register), updated on alternate clock cycles.

For the decimated output y[2n+1], each sample x[2n+1-k] belongs to either the odd or even sub-sequence depending on whether (2n+1-k) is odd or even. The designer must derive which delay line index corresponds to each tap k.

## 5. Combining Symmetry with Polyphase Decomposition

When both optimizations are applied together:
1. Map each filter tap to its polyphase sub-sequence and delay index
2. Identify the symmetric pairs (tap k and tap N-1-k)
3. Pre-add the corresponding samples from the appropriate delay lines
4. Multiply each pre-added sum by its shared coefficient

The challenge is correctly deriving the register indices across the two delay lines for each symmetric pair.

## 6. Time-Domain Multiplexing (TDM)

When decimation provides multiple clock cycles per output, multipliers can be time-shared:
- Divide the N/2 multiplications into groups
- Compute one group per clock cycle using shared multiplier hardware
- Accumulate partial results across cycles

This trades computation time for reduced hardware area.

## 7. Fixed-Point Arithmetic and Bitwidth Growth

In fixed-point hardware, signal bitwidths grow with each arithmetic operation:

- **Addition/Subtraction**: Adding two N-bit signed values produces an (N+1)-bit result (carry/borrow bit).
- **Multiplication**: Multiplying an A-bit signed value by a B-bit signed value produces an (A+B)-bit result.
- **Accumulation**: Summing M values each of W bits requires W + ceil(log2(M)) bits to avoid overflow.

The designer must trace bitwidth growth through the entire datapath—from input samples through pre-addition, multiplication, and final accumulation—to determine the minimum output width that prevents overflow across the full dynamic range.
