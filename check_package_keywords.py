#!/usr/bin/env python3

import os
import re
import portage

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

# match an uncommented package entry:
#   - start of the line (0 or more spaces, without a comment)
#   - the version "range" prefix
#   - "<base>-<cat>/<name>"
#   - "-<anything>" (presumably the package version)
pkg_str = \
"^\s*#{0}\s*\
[><=~]?\
(\w+(?:-\w+)?/\w+(?:-[a-zA-Z]+\w*)*){1}"

pk_reg = re.compile(pkg_str)

# reg.findall() also returns empty matches, so filter those with a len() check
packages = [m for l in lines for m in pk_reg.findall(l) if len(m)>0]
packages = unique(packages)

# generate a format string for printing
max_p_len = max([len(p) for p in packages])
form_spec = "{0:>" + str(max_p_len) + "}: {1:>12} -> {2:<12}"

# get a list of all installed packages
var_tree = portage.vartree()
installed_pkgs = var_tree.getallcpv()

for p in packages:
    available = portage.portdb.cp_list(p)
    installed = [b for b in available if b in installed_pkgs]
    av_ver    = unique(['-'.join(portage.pkgsplit(m)[1:]) for m in available])
    ins_ver   = unique(['-'.join(portage.pkgsplit(m)[1:]) for m in installed])

    if ins_ver:
        try:
            idx = av_ver.index(ins_ver[0])
        except ValueError:
            idx = -1
            ins_ver = ["*" + v for v in ins_ver]
            
        # TODO: handle slots explicitly?
        # list all versions higher than the oldest installed version
        cur_ver = [v for v in av_ver[idx+1:] if ins_ver[0] != v]
        
        # TODO: add command line option to filter out live ebuilds
        # skip the package if the only upgrades are live ebuilds
        if all(['9999' in cv for cv in cur_ver]):
            continue

        if cur_ver:
            print(form_spec.format(p, ', '.join(ins_ver), ', '.join(cur_ver)))
    else:
        print(form_spec.format(p, '(none)', ', '.join(av_ver)))
