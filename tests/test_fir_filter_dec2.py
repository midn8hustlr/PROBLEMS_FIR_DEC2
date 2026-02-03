import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer


# Filter coefficients (same as DUT)
H = [2, 4, 6, 10, 14, 20, 26, 32, 26, 32, 14, 20, 6, 10, 2, 4]


def to_signed(val, bits=20):
    """Convert unsigned value to signed interpretation."""
    if val >= (1 << (bits - 1)):
        val -= (1 << bits)
    return val


@cocotb.test()
async def test_impulse_response(dut):
    """Test 1: Impulse Response - impulse at x[0] = 50.
    
    Verifies that the FIR filter with decimation by 2 produces the correct
    impulse response. Due to polyphase decomposition, output y[2n+1] is 
    computed from both even and odd samples.
    """
    # Start clock (10ns period)
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    # Initialize and reset DUT (matching Verilog TB timing)
    dut.rst_n.value = 0
    dut.x_in.value = 0
    
    # Hold reset for 5 cycles
    for _ in range(5):
        await FallingEdge(dut.clk)
    
    # Release reset - impulse is set immediately (no extra wait)
    dut.rst_n.value = 1
    
    dut._log.info("Test 1: Impulse Response (impulse at x[0])")
    dut._log.info("-----------------------------------------")
    
    impulse_value = 50
    test_count = 0
    pass_count = 0
    
    # Apply impulse at x[0] and then zeros
    dut.x_in.value = impulse_value
    await FallingEdge(dut.clk)
    dut.x_in.value = 0
    await FallingEdge(dut.clk)
    
    # Since we are not testing for latency, so let it be variable upto certain clocks
    latency_good = 0
    for i in range(4):
        await FallingEdge(dut.clk)
        if dut.y_out.value != 0:
            latency_good = 1
            y_out_val_first = to_signed(dut.y_out.value.to_unsigned(), 20)
            break

    assert latency_good, "Filter latency is too high > 5 clk cycles"

    # Based on internal implementation of decimation filter, it is possible that either even or odd samples are coming out
    # Lets adjust our comparisions according to that

    if y_out_val_first == H[0] * impulse_value:
        is_first_sample_odd = 0
    elif y_out_val_first == H[1] * impulse_value:
        is_first_sample_odd = 1
    else:
        assert False, f"First sample {y_out_val_first} should match with either {H[0] * impulse_value} or {H[1] * impulse_value}"


    for i in range(16):
        # Check output at odd sample indices (after odd or even sample is captured)
        # y_out is updated after phase 1 (odd sample)
        if i % 2 == is_first_sample_odd:
            test_count += 1
            output_idx = i - 1
            y_out_val = to_signed(dut.y_out.value.to_unsigned(), 20)
            expected = H[i] * impulse_value
            
            if y_out_val == expected:
                pass_count += 1
                dut._log.info(f"  y[{output_idx}] = {y_out_val} [PASS]")
            else:
                dut._log.error(f"  y[{output_idx}] = {y_out_val}, expected {expected} [FAIL]")

        # Wait for clock edge (DUT samples x_in)
        await FallingEdge(dut.clk)
    
    dut._log.info(f"Impulse test: {pass_count}/{test_count} passed")
    assert pass_count == test_count, f"Impulse response test failed: {pass_count}/{test_count} passed"


@cocotb.test()
async def test_step_response(dut):
    """Test 2: Step Response - x[n] = 10 for all n.
    
    Verifies that the FIR filter settles to the correct steady-state value
    when a constant input is applied. The expected output is sum(H) * x_in.
    """
    # Start clock (10ns period)
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    # Set step input before reset (so it's applied immediately)
    step_value = 10
    dut.x_in.value = step_value
    
    # Reset DUT
    dut.rst_n.value = 0
    for _ in range(3):
        await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    
    dut._log.info("Test 2: Step Response (x[n] = 10 for all n)")
    dut._log.info("-------------------------------------------")
    
    # Run for 24 cycles to let filter settle
    for _ in range(22):
        await FallingEdge(dut.clk)
    
    # Calculate expected steady-state output
    expected = sum(H) * step_value
    y_out_val = to_signed(dut.y_out.value.to_unsigned(), 20)
    
    dut._log.info(f"  Final result = {y_out_val}, expected = {expected}")
    
    if y_out_val == expected:
        dut._log.info("  Step response [PASS]")
    else:
        dut._log.error(f"  Step response [FAIL]: got {y_out_val}, expected {expected}")
    
    assert y_out_val == expected, f"Step response test failed: got {y_out_val}, expected {expected}"


def test_fir_filter_dec2_runner():
    """Pytest runner for cocotb tests."""
    import os
    from pathlib import Path
    from cocotb_tools.runner import get_runner
    
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    
    # FIR filter RTL source file
    sources = [
        proj_path / "sources/fir_filter_dec2.v",
    ]
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="fir_filter_dec2",
        always=True,
        waves=True
    )
    
    runner.test(hdl_toplevel="fir_filter_dec2", test_module="test_fir_filter_dec2", waves=True)


if __name__ == "__main__":
    test_fir_filter_dec2_runner()
