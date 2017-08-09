from ipykernel.kernelapp import IPKernelApp
from traitlets import Type


class OpenDiscIPKernelApp(IPKernelApp):
    
    # `IPKernelApp` traits
    
    kernel_class = Type('opendisc.kernel.kernel.OpenDiscIPythonKernel',
                        klass='ipykernel.kernelbase.Kernel')
    
    # `IPKernelApp` class variables
    
    subcommands = {
        'install': (
            'opendisc.kernel.kernelspec.InstallIPythonKernelSpecApp',
            'Install the Open Discovery IPython kernel'
        ),
    }
