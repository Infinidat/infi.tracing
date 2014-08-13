import os
import sys
import glob


def add_infi_tracing_to_sys_path():
    build_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build"))
    lib_paths = glob.glob(os.path.join(build_path, "lib.*"))
    src_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src"))

    if lib_paths:
        sys.path.insert(0, lib_paths[0])
        sys.path.insert(1, src_path)
    else:
        sys.path.insert(0, src_path)
