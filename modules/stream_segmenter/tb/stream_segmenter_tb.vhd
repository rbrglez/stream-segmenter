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
        G_STREAM_WIDTH         : positive := 8 * 3;
        G_MAX_WORDS_PER_PACKET : positive := 20
    );
end entity stream_segmenter_tb;

architecture tb of stream_segmenter_tb is

    constant C_CLK_PERIOD : time := 10 ns;

    ----------------------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------------------
    signal i_clk : std_logic;
    signal i_rst : std_logic;

    signal i_en               : std_logic;
    signal i_words_per_packet : std_logic_vector(log2ceil(G_MAX_WORDS_PER_PACKET + 1) - 1 downto 0);

    signal in_stream_valid : std_logic;
    signal in_stream_ready : std_logic;
    signal in_stream_last  : std_logic;
    signal in_stream_data  : std_logic_vector(G_STREAM_WIDTH - 1 downto 0);

    signal o_out_stream_valid : std_logic;
    signal o_out_stream_last  : std_logic;
    signal i_out_stream_ready : std_logic;
    signal o_out_stream_data  : std_logic_vector(G_STREAM_WIDTH - 1 downto 0);

    ----------------------------------------------------------------------------
    --
    ----------------------------------------------------------------------------
    signal prbs_en : std_logic;

    signal prbs_valid : std_logic;
    signal prbs_ready : std_logic;
    signal prbs_data  : std_logic_vector(G_STREAM_WIDTH - 1 downto 0);

    signal stall         : std_logic;
    signal prbs_stall    : std_logic;
    signal prbs_stall_en : std_logic;

    signal prbs_last    : std_logic;
    signal prbs_last_en : std_logic;

begin

    ----------------------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------------------
    dut : entity work.stream_segmenter
        generic map (
            G_STREAM_WIDTH         => G_STREAM_WIDTH,
            G_MAX_WORDS_PER_PACKET => G_MAX_WORDS_PER_PACKET
        )
        port map (
            i_clk => i_clk,
            i_rst => i_rst,

            i_words_per_packet => i_words_per_packet,

            i_in_stream_valid => in_stream_valid,
            i_in_stream_last  => in_stream_last,
            o_in_stream_ready => in_stream_ready,
            i_in_stream_data  => in_stream_data,

            o_out_stream_valid => o_out_stream_valid,
            o_out_stream_last  => o_out_stream_last,
            i_out_stream_ready => i_out_stream_ready,
            o_out_stream_data  => o_out_stream_data
        );


    prbs_ready      <= in_stream_ready and prbs_en and not(stall);
    in_stream_valid <= prbs_valid and prbs_en and not(stall);

    in_stream_last <= prbs_last when prbs_last_en = '1' else '0';

        in_stream_data <= prbs_data;

        u_prbs : entity olo.olo_base_prbs
            generic map (
                Polynomial_g    => Polynomial_Prbs16_c,
                Seed_g          => x"1234",
                BitsPerSymbol_g => G_STREAM_WIDTH
            )
            port map (
                Clk => i_clk,
                Rst => i_rst,

                Out_Data  => prbs_data,
                Out_Ready => prbs_ready,
                Out_Valid => prbs_valid
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
                Out_Ready   => prbs_stall_en
            );

        stall <= prbs_stall when prbs_stall_en = '1' else '0';


        u_last_prbs : entity olo.olo_base_prbs
            generic map (
                Polynomial_g    => Polynomial_Prbs16_c,
                Seed_g          => x"AB87",
                BitsPerSymbol_g => 1
            )
            port map (
                Clk => i_clk,
                Rst => i_rst,

                Out_Data(0) => prbs_last,
                Out_Ready   => prbs_last_en
            );
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

        i_en               <= '0';
        prbs_stall_en      <= '0';
        i_words_per_packet <= (others => '0');
        i_out_stream_ready <= '0';

        prbs_last_en <= '0';

        prbs_en            <= '1';
        i_out_stream_ready <= '1';

        ------------------------------------------------------------------------
        -- Reset
        ------------------------------------------------------------------------
        i_rst <= '1';
        tb_clk_period(i_clk, 10);
        i_rst <= '0';

        ------------------------------------------------------------------------
        -- NEW TEST
        ------------------------------------------------------------------------

        i_words_per_packet <= toUslv(3, i_words_per_packet'length);
        tb_clk_period(i_clk, 100);


        i_words_per_packet <= toUslv(11, i_words_per_packet'length);
        tb_clk_period(i_clk, 100);


        prbs_last_en <= '1';
        i_words_per_packet <= toUslv(2, i_words_per_packet'length);
        tb_clk_period(i_clk, 100);

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
        --            i_words_per_packet <= toUslv(i mod 4, G_PACKET_LENGTH_WIDTH);
        --            tb_clk_period(i_clk, 100);
        --        end loop;
        --
        --
        --        prbs_stall_en <= '1';
        --
        --        for i in 0 to 8 - 1 loop
        --            i_words_per_packet <= toUslv(i mod 4, G_PACKET_LENGTH_WIDTH);
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