from ipykernel.kernelapp import IPKernelApp
from traitlets import Type


class OpenDiscIPKernelApp(IPKernelApp):
    
    name = 'opendisc-ipython-kernel'
    
    kernel_class = Type('opendisc.kernel.kernel.OpenDiscIPythonKernel',
                        klass='ipykernel.kernelbase.Kernel')
    
    subcommands = {
        'install': (
            'opendisc.kernel.kernelspec.InstallIPythonKernelSpecApp',
            'Install the Open Discovery IPython kernel'
        ),
    }
