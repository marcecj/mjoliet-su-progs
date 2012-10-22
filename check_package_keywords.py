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

# read the raw lines from the package.accept_keywords file(s)
fname = "/etc/portage/package.accept_keywords"
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
pk_reg   = re.compile("^\s*(?!#)\s*(.*)")
packages = [m for l in lines for m in pk_reg.findall(l) if m]
packages = [dep_getkey(p) for p in unique(packages)]

# generate a format string for printing
max_p_len = max([len(p) for p in packages])
form_spec = "{0:>" + str(max_p_len) + "}: {1:>12} -> {2:<12}"

# get a list of all installed packages; NOTE: add the cat/pkg string to *very*
# noticeably reduce overhead in the below for-loop
var_tree = vartree()
installed_pkgs = [(p,cpv_getkey(p)) for p in var_tree.dbapi.cpv_all()]

for p in packages:
    available = portdb.cp_list(p)
    installed = [ip_v for ip_v,ip in installed_pkgs if p == ip]
    av_ver    = [cpv_getversion(m) for m in available]
    ins_ver   = [cpv_getversion(m) for m in installed]

    if ins_ver:
        try:
            idx = av_ver.index(ins_ver[0])
        except ValueError:
            idx = -1
            ins_ver = ["*" + v for v in ins_ver]
            
        # list all versions higher than the oldest installed version
        cur_ver = [v for v in av_ver[idx+1:] if ins_ver[0] != v]
        
        # skip the package if the only upgrades are live ebuilds
        if all(['9999' in cv for cv in cur_ver]):
            continue

        if cur_ver:
            print(form_spec.format(p, ', '.join(ins_ver), ', '.join(cur_ver)))
    else:
        print(form_spec.format(p, '(none)', ', '.join(av_ver)))
