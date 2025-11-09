--------------------------------------------------------------------------------
-- stream_segmenter
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Libraries
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library olo;
use olo.olo_base_pkg_math.all;

--------------------------------------------------------------------------------
-- Entity
--------------------------------------------------------------------------------
entity stream_segmenter is
    generic (
        G_STREAM_WIDTH         : positive;
        G_MAX_WORDS_PER_PACKET : positive := 255
    );
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;

        ------------------------------------------------------------------------
        -- Static Configuration
        ------------------------------------------------------------------------
        i_en               : in std_logic                                                           := '1';
        i_words_per_packet : in std_logic_vector(log2ceil(G_MAX_WORDS_PER_PACKET + 1) - 1 downto 0) := toUslv(G_MAX_WORDS_PER_PACKET, log2ceil(G_MAX_WORDS_PER_PACKET + 1));

        ------------------------------------------------------------------------
        -- In Stream Interface
        ------------------------------------------------------------------------
        i_in_stream_valid : in  std_logic;
        i_in_stream_last  : in  std_logic := '0';
        o_in_stream_ready : out std_logic;
        i_in_stream_data  : in  std_logic_vector(G_STREAM_WIDTH - 1 downto 0);

        ------------------------------------------------------------------------
        -- Out Stream Interface
        ------------------------------------------------------------------------
        o_out_stream_valid : out std_logic;
        o_out_stream_last  : out std_logic;
        i_out_stream_ready : in  std_logic;
        o_out_stream_data  : out std_logic_vector(G_STREAM_WIDTH - 1 downto 0)
    );
end entity stream_segmenter;

architecture rtl of stream_segmenter is

    ----------------------------------------------------------------------------
    -- Constants
    ----------------------------------------------------------------------------
    constant C_WORDS_PER_PACKET_WIDTH : natural := log2ceil(G_MAX_WORDS_PER_PACKET + 1);

    ----------------------------------------------------------------------------
    -- Types
    ----------------------------------------------------------------------------
    type reg_t is record
        --word_cnt : natural range 0 to C_WORDS_PER_PACKET_WIDTH;
        word_cnt : natural;

        pl_ready : std_logic;
    end record;

    ----------------------------------------------------------------------------
    -- Two Process signals
    ----------------------------------------------------------------------------
    signal r      : reg_t;
    signal r_next : reg_t;

    ----------------------------------------------------------------------------
    -- Instantiation signals
    ----------------------------------------------------------------------------
    signal in_pl_valid       : std_logic;
    signal in_pl_ready       : std_logic;
    signal in_pl_last        : std_logic;
    signal in_pl_concat_data : std_logic_vector(G_STREAM_WIDTH downto 0);

    signal out_pl_concat_data : std_logic_vector(G_STREAM_WIDTH downto 0);

begin

    in_pl_concat_data <= in_pl_last & i_in_stream_data;
    o_in_stream_ready <= r_next.pl_ready;
    --o_in_stream_ready <= in_pl_ready;

    -- break logic chain between in ready and out ready
    u_pl_stage : entity olo.olo_base_pl_stage
        generic map (
            Width_g    => G_STREAM_WIDTH + 1,
            UseReady_g => true,
            Stages_g   => 1
        )
        port map (
            Clk => i_clk,
            Rst => i_rst,

            In_Valid => in_pl_valid,
            In_Ready => in_pl_ready,
            In_Data  => in_pl_concat_data,

            Out_Valid => o_out_stream_valid,
            Out_Ready => i_out_stream_ready,
            Out_Data  => out_pl_concat_data
        );

    o_out_stream_last <= out_pl_concat_data(G_STREAM_WIDTH);
    o_out_stream_data <= out_pl_concat_data(G_STREAM_WIDTH - 1 downto 0);

    ----------------------------------------------------------------------------
    -- Combinatorial process
    ----------------------------------------------------------------------------
    p_comb : process(all)
        variable v : reg_t;
    begin
        -- Hold variables stable
        v := r;

        ------------------------------------------------------------------------
        --
        ------------------------------------------------------------------------
        if (i_en = '1') then
            in_pl_valid <= i_in_stream_valid;
            v.pl_ready  := in_pl_ready;
        else
            in_pl_valid <= '0';
            v.pl_ready  := '0';
        end if;
        in_pl_last <= i_in_stream_last;

        ------------------------------------------------------------------------
        --
        ------------------------------------------------------------------------
        if (in_pl_valid = '1' and in_pl_ready = '1') then
            v.word_cnt := r.word_cnt + 1;

            if (in_pl_last = '1') then
                v.word_cnt := 0;
            end if;

            if (unsigned(i_words_per_packet) = 0) then
                --in_pl_last <= '0';
                v.word_cnt := 0;

            elsif (unsigned(i_words_per_packet) = 1) then
                in_pl_last <= '1';
                v.word_cnt := 0;

            elsif (r.word_cnt > unsigned(i_words_per_packet) - 2) then
                in_pl_last <= '1';
                v.word_cnt := 0;
            end if;
        end if;

        ------------------------------------------------------------------------
        -- Apply to record
        ------------------------------------------------------------------------
        r_next <= v;

    end process;

    ----------------------------------------------------------------------------
    -- Sequential process
    ----------------------------------------------------------------------------
    p_seq : process(i_clk)
    begin
        if rising_edge(i_clk) then
            r <= r_next;
            if (i_rst = '1') then
                r.word_cnt <= 0;
                r.pl_ready <= '0';
            end if;
        end if;
    end process;

end architecture rtl;
