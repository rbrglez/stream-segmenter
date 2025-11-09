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
    for stall in stall_options:
        named_config(tb, {'G_STREAM_WIDTH' : 8, 'G_RANDOM_STALL' : stall})
