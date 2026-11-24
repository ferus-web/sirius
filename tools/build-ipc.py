#!/usr/bin/env python3
## This script compiles all IPDL files into their Nim bindings via Sirius' scanner tool.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import os
import subprocess

SCANNER = os.getenv("SCANNER")
if SCANNER == None:
    SCANNER = os.getcwd() + "/scanner"

print(f":: scanner => {SCANNER}")

if not os.path.isfile(SCANNER):
    print(f"Cannot find scanner binary. Run the command below to compile it:\n$ ./tools/bin/neo build scanner")
    quit(1)

def invoke_scanner(ipdl_file: str, output_name: str,
                   interface: str,
                   is_client_bindings: bool = False, dont_generate_fns: bool = False):
    cmd = [SCANNER,
        ipdl_file, f"components/synapse/descriptors/{output_name}.nim",
        interface
    ]
    if is_client_bindings:
        cmd.append("--client")

    if dont_generate_fns:
        cmd.append("--dont-generate-fns")

    print(f"[SCANNER] {ipdl_file} => {cmd[2]} ({interface})")
    subprocess.run(cmd, stdout = None, stderr = None, stdin = None)

invoke_scanner(
    ipdl_file = "ipc/master.ipdl",
    output_name = "master", interface = "Master",
    is_client_bindings = True
)
invoke_scanner(
    ipdl_file = "ipc/renderer.ipdl",
    output_name = "renderer", interface = "Render"
)
invoke_scanner(
    ipdl_file = "ipc/zygote.ipdl",
    output_name = "zygote", interface = "Zygote",
    dont_generate_fns = True
)
