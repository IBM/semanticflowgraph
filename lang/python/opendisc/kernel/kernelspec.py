""" Generate the kernel spec (JSON file).

XXX: Based on `ipykernel.kernelspec`. That is code is not modular enough to be
properly re-used. We resort to a monkey patch instead of a copy-and-paste.
"""
import sys

from ipykernel.kernelspec import make_ipkernel_cmd, InstallIPythonKernelSpecApp


def get_kernel_dict():
    """ Construct dict for kernel.json.
    """
    mod = 'opendisc.kernel'
    return {
        'argv': make_ipkernel_cmd(mod),
        'display_name': 'Python %i [Open Discovery]' % sys.version_info[0],
        'language': 'python',
    }

def get_kernel_name():
    """ Get the (default) name for the kernel.
    """
    return 'opendisc_python%i' % sys.version_info[0]


def main():
    # Monkey-patch!
    from ipykernel import kernelspec
    kernelspec.get_kernel_dict = get_kernel_dict
    kernelspec.KERNEL_NAME = get_kernel_name()
    
    InstallIPythonKernelSpecApp.launch_instance()


if __name__ == '__main__':
    main()
