################################################################################
# modules.py
################################################################################

################################################################################
# Imports
################################################################################
from .utils import named_config, make_short_name
import sys
import os

################################################################################
# Functionality
################################################################################

def add_configs(lib):
    """
    Add all base testbench configurations to the VUnit Library
    :param lib: Testbench library
    """

    ############################################################################
    # stream_segmenter
    ############################################################################
    tb = lib.test_bench('stream_segmenter_vunit_tb')

    stall_options = [True, False]
    zero_words_mode_options = ["NO_SEGMENT", "ALWAYS_SEGMENT"]
    width_options = [8, 64]
    for stall in stall_options:
        for zero_mode in zero_words_mode_options:
            for width in width_options:
                generics = {
                    "G_STREAM_WIDTH" : width,
                    "G_ZERO_WORDS_MODE" : zero_mode,
                    "G_RANDOM_STALL" : stall
                }
                named_config(tb, generics)
