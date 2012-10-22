#!/usr/bin/env python3

# TODO: handle slots explicitly?
# TODO: add command line option to filter out live ebuilds

import os
import re
from portage import portdb, dep_getkey, vartree
from portage.versions import cpv_getkey, cpv_getversion

def unique(l):
    "Remove redundant entries from a list"

    from itertools import groupby
    return [a for a,b in groupby(l)]

def get_pkgs_from_package_ak(fname="/etc/portage/package.accept_keywords"):
    "read the raw lines from the package.accept_keywords file(s)"

    if os.path.isfile(fname):
        with open(fname) as pk:
            lines = pk.readlines()
    elif os.path.isdir(fname):
        lines = []
        for root, dirs, files in os.walk(fname):
            files = [os.path.join(root, f) for f in files if not f.endswith('~')]
            for f in files:
                with open(f) as fp:
                    lines += fp.readlines()

    # find all uncommented, non-empty lines and extract the unique cat/pkg-names
    pk_reg = re.compile("^\s*(?!#)\s*(.*)")
    atoms  = [m for l in lines for m in pk_reg.findall(l) if m]
    atoms  = unique([dep_getkey(a) for a in atoms])

    return atoms

def get_upgrade_paths(packages, installed_pkgs):
    "Find available upgrade paths."

    upgrades = []
    for p in packages:
        available = portdb.cp_list(p)
        installed = [ip_v for ip_v,ip in installed_pkgs if p == ip]
        av_ver    = [cpv_getversion(m) for m in available]
        ins_ver   = [cpv_getversion(m) for m in installed]

        if ins_ver:
            # find the first installed version in the tree
            idx = -1
            for i,v in enumerate(ins_ver):
                try:
                    idx = av_ver.index(v)
                    break
                except ValueError:
                    # prefix unavailable versions with a '*'
                    ins_ver[i] = "*" + ins_ver[i]

            # list all versions higher than the oldest installed version
            cur_ver = [v for v in av_ver[idx+1:] if ins_ver[0] != v]
            
            # skip the package if the only upgrades are live ebuilds
            if all(['9999' in cv for cv in cur_ver]):
                continue

            if cur_ver:
                upgrades.append((p, ', '.join(ins_ver), ', '.join(cur_ver)))
        else:
            upgrades.append((p, '(none)', ', '.join(av_ver)))

    return upgrades

packages = get_pkgs_from_package_ak()

# get a list of all installed packages; NOTE: add the cat/pkg string to *very*
# noticeably reduce overhead in the below for-loop
var_tree = vartree()
installed_pkgs = [(p,cpv_getkey(p)) for p in var_tree.dbapi.cpv_all()]

upgrades = get_upgrade_paths(packages, installed_pkgs)

# generate a format string for printing
max_len = tuple(len(max(l, key=len)) for l in zip(*upgrades))
form_spec = "{0:>%i}: {1:>%i} -> {2:<%i}" % max_len

# print the upgrade paths
header = form_spec.format("Name", "Installed", "Available")
print(header, "-"*len(header), sep="\n")
for p in upgrades:
    print(form_spec.format(*p))
