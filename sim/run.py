################################################################################
# Imports
################################################################################
from vunit import VUnit
from glob import glob
import os
import sys
from enum import Enum
from functools import partial

# Import vunit test configurations
from test_configs import modules

################################################################################
# Setup
################################################################################

class Simulator(Enum):
    GHDL = 1
    MODELSIM = 2
    NVC = 3

#Execute from sim directory
os.chdir(os.path.dirname(os.path.realpath(__file__)))

#Argument handling
argv = sys.argv[1:]
SIMULATOR = Simulator.GHDL
USE_COVERAGE = False
GENERATE_VHDL_LS_TOML = False
GENERATE_COMPILE_LIST = False

#Simulator Selection
#.. The environment variable VUNIT_SIMULATOR has precedence over the commandline options.
if "--modelsim" in sys.argv:
    SIMULATOR = Simulator.MODELSIM
    argv.remove("--modelsim")
if "--nvc" in sys.argv:
    SIMULATOR = Simulator.NVC
    argv.remove("--nvc")
if "--ghdl" in sys.argv:
    SIMULATOR = Simulator.GHDL
    argv.remove("--ghdl")
if "--coverage" in sys.argv:
    USE_COVERAGE = True
    argv.remove("--coverage")
    if SIMULATOR != Simulator.MODELSIM:
        raise "Coverage is only allowed with --modelsim"
if "--vhdl_ls" in sys.argv:
    GENERATE_VHDL_LS_TOML = True
    argv.remove("--vhdl_ls")
if "--compile_list" in sys.argv:
    GENERATE_COMPILE_LIST = True
    argv.remove("--compile_list")


# Obviously the simulator must be chosen before sources are added
if 'VUNIT_SIMULATOR' not in os.environ:
    if SIMULATOR == Simulator.GHDL:
        os.environ['VUNIT_SIMULATOR'] = 'ghdl'
    elif SIMULATOR == Simulator.NVC:
        os.environ['VUNIT_SIMULATOR'] = 'nvc'
    else:
        os.environ['VUNIT_SIMULATOR'] = 'modelsim'

# Parse VUnit Arguments
vu = VUnit.from_argv(compile_builtins=False, argv=argv)
vu.add_vhdl_builtins()
vu.add_com()
vu.add_verification_components()

# Create a library
olo = vu.add_library('olo')
lib = vu.add_library('lib')

# Add all open-logic VHDL files
files  = glob('../submodules/open-logic/src/**/*.vhd', recursive=True)
files += glob('../submodules/open-logic/3rdParty/en_cl_fix/hdl/*.vhd', recursive=True)
olo.add_source_files(files)

# Add all source VHDL files
files = glob('../modules/**/rtl/*.vhd', recursive=True)
lib.add_source_files(files)

# Add test helpers
files = glob('../submodules/open-logic/test/tb/*.vhd', recursive=True)
lib.add_source_files(files)

# Add all vunit tb VHDL files
files  = glob('../tests/**/*.vhd', recursive=True)
lib.add_source_files(files)

# Obviously flags must be set after files are imported
vu.add_compile_option('ghdl.a_flags', ['-frelaxed-rules', '-Wno-hide', '-Wno-shared'])
vu.add_compile_option('nvc.a_flags', ['--relaxed'])

################################################################################
# Test bench configurations
################################################################################

## Defined at the top of this file!
modules.add_configs(lib)

################################################################################
# Execution
################################################################################

lib.set_sim_option('ghdl.elab_flags', ['-frelaxed'])
lib.set_sim_option('nvc.heap_size', '5000M')

# Run
vu.main()