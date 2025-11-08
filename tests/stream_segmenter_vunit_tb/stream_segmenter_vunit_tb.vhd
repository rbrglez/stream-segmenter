---------------------------------------------------------------------------------------------------
-- stream_segmenter_vunit_tb
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.vc_context;

library olo;
use olo.olo_base_pkg_math.all;
use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity stream_segmenter_vunit_tb is
    generic (
        runner_cfg : string;

        G_STREAM_WIDTH         : positive := 8;
        G_MAX_WORDS_PER_PACKET : positive := 255;

        G_RANDOM_STALL : boolean := false
    );
end entity;

architecture sim of stream_segmenter_vunit_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant C_CLK_FREQUENCY : real := 100.0e6;
    constant C_CLK_PERIOD    : time := (1 sec) / C_CLK_FREQUENCY;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    shared variable InDelay_v  : time := 0 ns;
    shared variable OutDelay_v : time := 0 ns;

    -- *** Verification Components ***
    constant C_AXIS_MASTER : axi_stream_master_t := new_axi_stream_master (
            data_length  => G_STREAM_WIDTH,
            stall_config => new_stall_config(choose(G_RANDOM_STALL, 0.5, 0.0), 0, 10)
        );

    constant C_AXIS_SLAVE : axi_stream_slave_t := new_axi_stream_slave (
            data_length  => G_STREAM_WIDTH,
            stall_config => new_stall_config(choose(G_RANDOM_STALL, 0.5, 0.0), 0, 10)
        );

    -- *** Procedures ***
    procedure push100 (signal net : inout network_t) is
    begin

        -- Push 100 values
        for i in 0 to 99 loop
            wait for InDelay_v;
            push_axi_stream(net, C_AXIS_MASTER, toUslv(i, G_STREAM_WIDTH));
        end loop;

    end procedure;

    procedure check100 (signal net : inout network_t) is
    begin

        -- Check 100 values
        for i in 0 to 99 loop
            wait for OutDelay_v;
            check_axi_stream(net, C_AXIS_SLAVE, toUslv(i, G_STREAM_WIDTH), blocking => false, msg => "data " & integer'image(i));
        end loop;

    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal i_clk : std_logic := '0';
    signal i_rst : std_logic := '0';

    signal i_en               : std_logic                                                           := '1';
    signal i_words_per_packet : std_logic_vector(log2ceil(G_MAX_WORDS_PER_PACKET + 1) - 1 downto 0) := toUslv(G_MAX_WORDS_PER_PACKET, log2ceil(G_MAX_WORDS_PER_PACKET + 1));

    signal in_stream_valid : std_logic;
    signal in_stream_last  : std_logic := '0';
    signal in_stream_ready : std_logic;
    signal in_stream_data  : std_logic_vector(G_STREAM_WIDTH - 1 downto 0);

    signal out_stream_valid : std_logic;
    signal out_stream_last  : std_logic;
    signal out_stream_ready : std_logic;
    signal out_stream_data  : std_logic_vector(G_STREAM_WIDTH - 1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            InDelay_v  := 0 ns;
            OutDelay_v := 0 ns;

            -- Reset
            wait until rising_edge(i_clk);
            i_rst <= '1';
            wait for 1 us;
            wait until rising_edge(i_clk);
            i_rst <= '0';
            wait until rising_edge(i_clk);

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Basic") then
                i_en <= '1';
                -- One value
                push_axi_stream(net, C_AXIS_MASTER, toUslv(5, G_STREAM_WIDTH));
                check_axi_stream(net, C_AXIS_SLAVE, toUslv(5, G_STREAM_WIDTH), blocking => false, msg => "data a");
                -- Second value
                wait for 5*C_CLK_PERIOD;
                push_axi_stream(net, C_AXIS_MASTER, toUslv(10, G_STREAM_WIDTH));
                check_axi_stream(net, C_AXIS_SLAVE, toUslv(10, G_STREAM_WIDTH), blocking => false, msg => "data b");
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("FullThrottle") then
                i_en <= '1';
                push100(net);
                check100(net);
            end if;


            wait for 1 us;
            wait_until_idle(net, as_sync(C_AXIS_MASTER));
            wait_until_idle(net, as_sync(C_AXIS_SLAVE));

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    i_clk <= not i_clk after 0.5*C_CLK_PERIOD;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    dut : entity work.stream_segmenter
        generic map (
            G_STREAM_WIDTH         => G_STREAM_WIDTH,
            G_MAX_WORDS_PER_PACKET => G_MAX_WORDS_PER_PACKET
        )
        port map (
            i_clk => i_clk,
            i_rst => i_rst,

            i_en               => i_en,
            i_words_per_packet => i_words_per_packet,

            i_in_stream_valid => in_stream_valid,
            i_in_stream_last  => in_stream_last,
            o_in_stream_ready => in_stream_ready,
            i_in_stream_data  => in_stream_data,

            o_out_stream_valid => out_stream_valid,
            o_out_stream_last  => out_stream_last,
            i_out_stream_ready => out_stream_ready,
            o_out_stream_data  => out_stream_data
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity vunit_lib.axi_stream_master
        generic map (
            master => C_AXIS_MASTER
        )
        port map (
            aclk => i_clk,

            tvalid => in_stream_valid,
            tready => in_stream_ready,
            tdata  => in_stream_data,
            tlast  => in_stream_last
        );

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            slave => C_AXIS_SLAVE
        )
        port map (
            aclk => i_clk,

            tvalid => out_stream_valid,
            tready => out_stream_ready,
            tdata  => out_stream_data,
            tlast  => out_stream_last
        );

end architecture;
