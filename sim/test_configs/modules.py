################################################################################
# modules.py
################################################################################

################################################################################
# Imports
################################################################################
from .utils import named_config, make_short_name
import sys
import os

# Import for fix cosimulations
sys.path.append(os.path.join(os.path.dirname(__file__), '../..'))
from modules import *

################################################################################
# Functionality
################################################################################

def add_configs(lib):
    """
    Add all base testbench configurations to the VUnit Library
    :param lib: Testbench library
    """

    ############################################################################
    # fix_dsp_mac 
    ############################################################################
    tb = lib.test_bench('stream_segmenter_vunit_tb')

    named_config(tb, {'G_STREAM_WIDTH' : 8})
