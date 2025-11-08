################################################################################
# utils.py
################################################################################

################################################################################
# Imports
################################################################################
from functools import partial

################################################################################
# Functionality
################################################################################

def named_config(tb, map : dict, pre_config = None, short_name = None):
    cfg_name = "-".join([f"{k}={v}" for k, v in map.items()])
    if short_name is not None:
        cfg_name = short_name
    if pre_config is not None:
        pre_config = partial(pre_config, generics=map)
    tb.add_config(name=cfg_name, generics = map, pre_config=pre_config)


def make_short_name(generics : dict, generic_aliases : dict):
    parts = []
    for k, v in generics.items():
        alias = generic_aliases.get(k, k)  # use alias if defined, else full key
        parts.append(f"{alias}={v}")
    return "_".join(parts)