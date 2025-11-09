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
use olo.olo_base_pkg_string.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity stream_segmenter_vunit_tb is
    generic (
        runner_cfg : string;

        G_STREAM_WIDTH         : positive := 8;
        G_MAX_WORDS_PER_PACKET : positive := 255;
        G_ZERO_WORDS_MODE      : string   := "NO_SEGMENT";

        G_RANDOM_STALL : boolean := false
    );
end entity;

architecture sim of stream_segmenter_vunit_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant C_ZERO_WORDS_MODE : string := toLower(G_ZERO_WORDS_MODE);

    constant C_WORDS_PER_PACKET : natural := 10;

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant C_CLK_FREQUENCY : real := 100.0e6;
    constant C_CLK_PERIOD    : time := (1 sec) / C_CLK_FREQUENCY;

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
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
    procedure pushPacket (
            signal net : inout network_t;
            size       :       integer;
            startVal   :       integer := 1;
            blocking   :       boolean := false
        ) is
        variable Tlast_v : std_logic := '0';
    begin
        -- Loop over data-beats
        for i in 0 to size - 1 loop
            -- Push Data
            if i = size - 1 then
                Tlast_v := '1';
            end if;

            push_axi_stream(net, C_AXIS_MASTER, toUslv(startVal + i, G_STREAM_WIDTH), tlast => Tlast_v);
        end loop;

        if blocking then
            wait_until_idle(net, as_sync(C_AXIS_MASTER));
        end if;
    end procedure;

    procedure checkPacket (
            signal net : inout network_t;
            size       :       integer;
            startVal   :       integer := 1;
            blocking   :       boolean := false
        ) is
        variable Tlast_v : std_logic := '0';
    begin

        -- Loop over data-beats
        for i in 0 to size - 1 loop
            -- Data
            if i = size - 1 then
                Tlast_v := '1';
            end if;

            check_axi_stream(net, C_AXIS_SLAVE, toUslv(startVal + i, G_STREAM_WIDTH), tlast => Tlast_v, blocking => false);
        end loop;

        if blocking then
            wait_until_idle(net, as_sync(C_AXIS_SLAVE));
        end if;
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

            -- Reset
            wait until rising_edge(i_clk);
            i_rst <= '1';
            wait for 1 us;
            wait until rising_edge(i_clk);
            i_rst <= '0';
            wait until rising_edge(i_clk);

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("no_segmentation") then
                i_en               <= '1';
                i_words_per_packet <= toUslv(C_WORDS_PER_PACKET, i_words_per_packet'length);

                for i in 1 to C_WORDS_PER_PACKET loop
                    pushPacket(net, size  => i);
                    checkPacket(net, size => i);
                end loop;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("one_segmentation") then
                i_en               <= '1';
                i_words_per_packet <= toUslv(C_WORDS_PER_PACKET, i_words_per_packet'length);

                for i in C_WORDS_PER_PACKET + 1 to 2*C_WORDS_PER_PACKET loop
                    pushPacket(net, size  => i);
                    checkPacket(net, size => C_WORDS_PER_PACKET);
                    checkPacket(net, size => i- C_WORDS_PER_PACKET, startVal => C_WORDS_PER_PACKET + 1);
                end loop;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("multiple_segmentations") then
                i_en               <= '1';
                i_words_per_packet <= toUslv(C_WORDS_PER_PACKET, i_words_per_packet'length);

                pushPacket(net, size => 10*C_WORDS_PER_PACKET);
                for i in 0 to 10 - 1 loop
                    checkPacket(net, size => C_WORDS_PER_PACKET, startVal => i*C_WORDS_PER_PACKET + 1);
                end loop;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("words_per_packet_change") then
                i_en <= '1';

                ----------------------------------------------------------------
                i_words_per_packet <= toUslv(3, i_words_per_packet'length);
                pushPacket(net, size  => 5);
                checkPacket(net, size => 3);
                checkPacket(net, size => 2, startVal => 4, blocking => true);

                ----------------------------------------------------------------
                i_words_per_packet <= toUslv(8, i_words_per_packet'length);
                pushPacket(net, size  => 7);
                checkPacket(net, size => 7);

                pushPacket(net, size  => 9);
                checkPacket(net, size => 8);
                checkPacket(net, size => 1, startVal => 9, blocking => true);

                ----------------------------------------------------------------
                i_words_per_packet <= toUslv(4, i_words_per_packet'length);
                pushPacket(net, size  => 15);
                checkPacket(net, size => 4);
                checkPacket(net, size => 4, startVal => 4 + 1);
                checkPacket(net, size => 4, startVal => 8 + 1);
                checkPacket(net, size => 3, startVal => 12 + 1, blocking => true);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("en_testing") then
                i_en               <= '0';
                i_words_per_packet <= toUslv(15, i_words_per_packet'length);

                pushPacket(net, size  => 34);
                checkPacket(net, size => 15);
                wait for 50 * C_CLK_PERIOD;
                i_en <= '1';
                wait for 50 * C_CLK_PERIOD;
                checkPacket(net, size => 15, startVal => 15 + 1);
                wait for 50 * C_CLK_PERIOD;
                checkPacket(net, size => 4, startVal => 30 + 1);

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("words_per_packet_edge_case") then
                i_en <= '1';

                for j in 0 to 1 loop

                    ------------------------------------------------------------
                    i_words_per_packet <= toUslv(1, i_words_per_packet'length);
                    pushPacket(net, size => 2*C_WORDS_PER_PACKET);

                    for i in 1 to 2*C_WORDS_PER_PACKET loop
                        if (i = 2*C_WORDS_PER_PACKET) then
                            checkPacket(net, size => 1, startVal => i, blocking => true);
                        else
                            checkPacket(net, size => 1, startVal => i);
                        end if;
                    end loop;

                    ------------------------------------------------------------
                    i_words_per_packet <= toUslv(0, i_words_per_packet'length);
                    pushPacket(net, size => 2*C_WORDS_PER_PACKET);

                    if (C_ZERO_WORDS_MODE = "always_segment") then
                        for i in 1 to 2*C_WORDS_PER_PACKET loop
                            if (i = 2*C_WORDS_PER_PACKET) then
                                checkPacket(net, size => 1, startVal => i, blocking => true);
                            else
                                checkPacket(net, size => 1, startVal => i);
                            end if;
                        end loop;
                    else
                        checkPacket(net, size => 2*C_WORDS_PER_PACKET, blocking => true);
                    end if;
                end loop;

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
            G_MAX_WORDS_PER_PACKET => G_MAX_WORDS_PER_PACKET,
            G_ZERO_WORDS_MODE      => G_ZERO_WORDS_MODE
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
