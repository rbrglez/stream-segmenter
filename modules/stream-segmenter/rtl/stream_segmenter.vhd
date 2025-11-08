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
        G_STREAM_WIDTH     : positive;
        G_MAX_PACKET_BYTES : positive := 255
    );
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;

        ------------------------------------------------------------------------
        -- Static Configuration
        ------------------------------------------------------------------------
        i_en           : in std_logic                                                       := '1';
        i_packet_bytes : in std_logic_vector(log2ceil(G_MAX_PACKET_BYTES + 1) - 1 downto 0) := toUslv(G_MAX_PACKET_BYTES, log2ceil(G_MAX_PACKET_BYTES + 1));

        ------------------------------------------------------------------------
        -- In Stream Interface
        ------------------------------------------------------------------------
        i_in_stream_valid : in  std_logic;
        i_in_stream_last  : in  std_logic := '0';
        o_in_stream_ready : out std_logic;
        i_in_stream_be    : in  std_logic_vector(G_STREAM_WIDTH / 8 - 1 downto 0) := (others => '1');
        i_in_stream_data  : in  std_logic_vector(G_STREAM_WIDTH - 1 downto 0);

        ------------------------------------------------------------------------
        -- Out Stream Interface
        ------------------------------------------------------------------------
        o_out_stream_valid : out std_logic;
        o_out_stream_last  : out std_logic;
        i_out_stream_ready : in  std_logic;
        o_out_stream_be    : out std_logic_vector(G_STREAM_WIDTH / 8 - 1 downto 0);
        o_out_stream_data  : out std_logic_vector(G_STREAM_WIDTH - 1 downto 0)
    );
end entity stream_segmenter;

architecture rtl of stream_segmenter is

    ----------------------------------------------------------------------------
    -- Constants
    ----------------------------------------------------------------------------
    -- last + be + data
    constant C_CONCAT_WIDTH : natural := 1 + G_STREAM_WIDTH / 8 + G_STREAM_WIDTH;

    constant C_BYTES_PER_DATA_BEAT : natural := G_STREAM_WIDTH / 8;

    ----------------------------------------------------------------------------
    -- Types
    ----------------------------------------------------------------------------
    -- state type
    type state_t is (
            DATA_S,
            LAST_S,
            DUPLICATE_S
        );

    type reg_t is record
        byte_cnt : natural range 0 to G_MAX_PACKET_BYTES + 1;
        
        in_pl_valid       : std_logic;
        in_pl_data        : std_logic_vector(G_STREAM_WIDTH - 1 downto 0);
        in_pl_last        : std_logic;
        in_pl_be          : std_logic_vector(G_STREAM_WIDTH / 8 - 1 downto 0);
        in_pl_concat_data : std_logic_vector(C_CONCAT_WIDTH - 1 downto 0);

        in_pl_ready : std_logic;

        data_beat_duplicate : std_logic;
        data_duplicate      : std_logic_vector(G_STREAM_WIDTH - 1 downto 0);

        --
        state : state_t;
    end record;

    ----------------------------------------------------------------------------
    -- Two Process signals
    ----------------------------------------------------------------------------
    signal r      : reg_t;
    signal r_next : reg_t;

    ----------------------------------------------------------------------------
    -- Instantiation signals
    ----------------------------------------------------------------------------
    signal in_pl_ready       : std_logic;
    signal in_pl_concat_data : std_logic_vector(C_CONCAT_WIDTH - 1 downto 0);

    signal out_pl_concat_data : std_logic_vector(C_CONCAT_WIDTH - 1 downto 0);

begin

    in_pl_concat_data <= r.in_pl_last & r.in_pl_be & r.in_pl_data;
    o_in_stream_ready <= r.in_pl_ready;

    -- break logic chain between in ready and out ready
    u_pl_stage : entity olo.olo_base_pl_stage
        generic map (
            Width_g    => C_CONCAT_WIDTH,
            UseReady_g => true,
            Stages_g   => 1
        )
        port map (
            Clk => i_clk,
            Rst => i_rst,

            In_Valid => r.in_pl_valid,
            In_Ready => in_pl_ready,
            In_Data  => in_pl_concat_data,

            Out_Valid => o_out_stream_valid,
            Out_Ready => i_out_stream_ready,
            Out_Data  => out_pl_concat_data
        );

    o_out_stream_last <= out_pl_concat_data(C_CONCAT_WIDTH - 1);
    o_out_stream_be   <= out_pl_concat_data((C_CONCAT_WIDTH - 1) - 1 downto G_STREAM_WIDTH);
    o_out_stream_data <= out_pl_concat_data(G_STREAM_WIDTH - 1 downto 0);

    ----------------------------------------------------------------------------
    -- Combinatorial process
    ----------------------------------------------------------------------------
    p_comb : process(all)
        variable v              : reg_t;
        variable packet_bytes_v : unsigned(i_packet_bytes'range);
        variable byte_rem_v     : integer;
    begin
        -- Hold variables stable
        v := r;

        packet_bytes_v := unsigned(i_packet_bytes);
        byte_rem_v     := to_integer(packet_bytes_v) - C_BYTES_PER_DATA_BEAT - r.byte_cnt;

        if (i_en = '1') then
            v.in_pl_valid := i_in_stream_valid;
        else
            v.in_pl_valid := '0';
        end if;

        ------------------------------------------------------------------------
        -- FSM
        ------------------------------------------------------------------------
        case (r.state) is
            --------------------------------------------------------------------
            when DATA_S =>

                v.in_pl_data := i_in_stream_data;
                v.in_pl_last := i_in_stream_last;
                v.in_pl_be   := i_in_stream_be;

                v.in_pl_ready := '1';


                if (r.in_pl_valid = '1' and in_pl_ready = '1') then

                    v.byte_cnt := r.byte_cnt + count(r.in_pl_be, '1');

                    if (r.byte_cnt >= packet_bytes_v - 2*C_BYTES_PER_DATA_BEAT) then

                        v.in_pl_last := '1';

                        v.data_beat_duplicate := '0';

                        if (byte_rem_v /= C_BYTES_PER_DATA_BEAT) then
                            v.in_pl_be                                                              := (others => '0');
                            v.in_pl_be(r.in_pl_be'length - 1 downto r.in_pl_be'length - byte_rem_v) := (others => '1');
                            v.data_beat_duplicate                                                   := '1';
                            v.in_pl_ready                                                           := '0';

                            v.byte_cnt := C_BYTES_PER_DATA_BEAT - byte_rem_v;
                        end if;

                        v.state := LAST_S;
                    end if;
                end if;

            --------------------------------------------------------------------
            when LAST_S =>
                v.in_pl_data := i_in_stream_data;
                v.in_pl_last := i_in_stream_last;
                v.in_pl_be   := i_in_stream_be;

                if (r.in_pl_valid = '1' and in_pl_ready = '1') then
                    v.in_pl_last := '0';

                    v.in_pl_ready := '1';

                    if (r.data_beat_duplicate = '1') then
                        v.data_duplicate := r.in_pl_data;

                        v.in_pl_data := r.in_pl_data;
                        v.in_pl_be   := not r.in_pl_be;

                        v.state := DUPLICATE_S;

                    else

                        v.byte_cnt := 0;
                        v.state    := DATA_S;

                    end if;
                end if;

            --------------------------------------------------------------------
            when DUPLICATE_S =>

                v.in_pl_data := r.data_duplicate;

                if (r.in_pl_valid = '1' and in_pl_ready = '1') then
                    v.in_pl_ready := '1';

                    v.in_pl_data := i_in_stream_data;
                    v.in_pl_last := i_in_stream_last;
                    v.in_pl_be   := i_in_stream_be;

                    v.state := DATA_S;
                end if;


            --------------------------------------------------------------------
            when others =>
                null;
        ------------------------------------------------------------------------
        end case;

        -- Apply to record
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
                r.byte_cnt <= 0;

                r.in_pl_valid <= '0';

                r.data_beat_duplicate <= '0';
                --
                r.state <= DATA_S;
            end if;
        end if;
    end process;

end architecture rtl;
