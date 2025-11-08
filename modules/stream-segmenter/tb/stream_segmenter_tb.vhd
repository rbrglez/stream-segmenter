--------------------------------------------------------------------------------
-- stream_last_append
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xbc;
context xbc.xbc_testbench_context;

library olo;
use olo.olo_base_pkg_logic.all;
use olo.olo_base_pkg_math.all;

entity stream_segmenter_tb is
    generic(
        G_STREAM_WIDTH     : positive := 8 * 3;
        G_MAX_PACKET_BYTES : positive := 15
    );
end entity stream_segmenter_tb;

architecture tb of stream_segmenter_tb is

    constant C_CLK_PERIOD : time := 10 ns;

    ----------------------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------------------
    signal i_clk : std_logic;
    signal i_rst : std_logic;

    signal i_packet_bytes : std_logic_vector(log2ceil(G_MAX_PACKET_BYTES + 1) - 1 downto 0);

    signal in_stream_valid  : std_logic;
    signal in_stream_ready  : std_logic;
    signal i_in_stream_be   : std_logic_vector(G_STREAM_WIDTH / 8 - 1 downto 0) := (others => '1');
    signal i_in_stream_last : std_logic                                         := '0';
    signal in_stream_data   : std_logic_vector(G_STREAM_WIDTH - 1 downto 0);

    signal o_out_stream_valid : std_logic;
    signal o_out_stream_last  : std_logic;
    signal i_out_stream_ready : std_logic;
    signal o_out_stream_be    : std_logic_vector(G_STREAM_WIDTH / 8 - 1 downto 0);
    signal o_out_stream_data  : std_logic_vector(G_STREAM_WIDTH - 1 downto 0);

    ----------------------------------------------------------------------------
    --
    ----------------------------------------------------------------------------
    signal prbs_en : std_logic;

    signal out_prbs_valid : std_logic;
    signal out_prbs_ready : std_logic;
    signal out_prbs_data  : std_logic_vector(G_STREAM_WIDTH - 1 downto 0);

    signal stall      : std_logic;
    signal prbs_stall : std_logic;
    signal stall_en   : std_logic;
begin

    ----------------------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------------------
    dut : entity work.stream_segmenter
        generic map (
            G_STREAM_WIDTH     => G_STREAM_WIDTH,
            G_MAX_PACKET_BYTES => G_MAX_PACKET_BYTES
        )
        port map (
            i_clk => i_clk,
            i_rst => i_rst,

            i_packet_bytes => i_packet_bytes,

            i_in_stream_valid => in_stream_valid,
            i_in_stream_last  => i_in_stream_last,
            o_in_stream_ready => in_stream_ready,
            i_in_stream_be    => i_in_stream_be,
            i_in_stream_data  => in_stream_data,

            o_out_stream_valid => o_out_stream_valid,
            o_out_stream_last  => o_out_stream_last,
            i_out_stream_ready => i_out_stream_ready,
            o_out_stream_be    => o_out_stream_be,
            o_out_stream_data  => o_out_stream_data
        );


    out_prbs_ready  <= in_stream_ready and prbs_en and not(stall);
    in_stream_valid <= out_prbs_valid and prbs_en and not(stall);
    in_stream_data  <= out_prbs_data;

    u_prbs : entity olo.olo_base_prbs
        generic map (
            Polynomial_g    => Polynomial_Prbs16_c,
            Seed_g          => x"1234",
            BitsPerSymbol_g => G_STREAM_WIDTH
        )
        port map (
            Clk => i_clk,
            Rst => i_rst,

            Out_Data  => out_prbs_data,
            Out_Ready => out_prbs_ready,
            Out_Valid => out_prbs_valid
        );

    u_stall_prbs : entity olo.olo_base_prbs
        generic map (
            Polynomial_g    => Polynomial_Prbs16_c,
            Seed_g          => x"F12A",
            BitsPerSymbol_g => 1
        )
        port map (
            Clk => i_clk,
            Rst => i_rst,

            Out_Data(0) => prbs_stall,
            Out_Ready   => stall_en
        );

    stall <= prbs_stall when stall_en = '1' else '0';

    ----------------------------------------------------------------------------
    -- Clock generation
    ----------------------------------------------------------------------------
    tb_clock(i_clk, C_CLK_PERIOD);

    ----------------------------------------------------------------------------
    -- Simulation process
    ----------------------------------------------------------------------------
    p_sim : process is

    begin

        ------------------------------------------------------------------------
        -- Init Signals
        ------------------------------------------------------------------------
        i_rst <= '0';

        stall_en           <= '0';
        i_packet_bytes     <= (others => '0');
        i_out_stream_ready <= '0';

        prbs_en <= '0';

        i_packet_bytes <= toUslv(12, i_packet_bytes'length);
        tb_clk_period(i_clk, 10);

        ------------------------------------------------------------------------
        -- Reset
        ------------------------------------------------------------------------
        i_rst <= '1';
        tb_clk_period(i_clk, 10);
        i_rst <= '0';

        tb_clk_period(i_clk, 10);

        ------------------------------------------------------------------------
        -- NEW TEST
        ------------------------------------------------------------------------
        i_out_stream_ready <= '1';
        tb_clk_period(i_clk);
        prbs_en <= '1';
        tb_clk_period(i_clk, 15);


        i_packet_bytes <= toUslv(11, i_packet_bytes'length);
        tb_clk_period(i_clk, 20);

        ------------------------------------------------------------------------
        -- OLD TEST
        ------------------------------------------------------------------------
        --        tb_clk_period(i_clk);
        --
        --        i_out_stream_ready <= '1';
        --
        --        tb_clk_period(i_clk, 10);
        --
        --        prbs_en <= '1';
        --        tb_clk_period(i_clk, 100);
        --
        --        for i in 0 to 8 - 1 loop
        --            i_packet_bytes <= toUslv(i mod 4, G_PACKET_LENGTH_WIDTH);
        --            tb_clk_period(i_clk, 100);
        --        end loop;
        --
        --
        --        stall_en <= '1';
        --
        --        for i in 0 to 8 - 1 loop
        --            i_packet_bytes <= toUslv(i mod 4, G_PACKET_LENGTH_WIDTH);
        --            tb_clk_period(i_clk, 100);
        --        end loop;
        --
        --        tb_clk_period(i_clk, 100);

        ------------------------------------------------------------------------
        --
        ------------------------------------------------------------------------
        tb_finish;

    end process;

end architecture tb;