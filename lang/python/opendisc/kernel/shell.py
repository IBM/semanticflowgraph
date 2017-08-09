from __future__ import absolute_import

from IPython.core.interactiveshell import InteractiveShellABC
from ipykernel.zmqshell import ZMQInteractiveShell


class OpenDiscIPythonShell(ZMQInteractiveShell):
    """ InteractiveShell for use with OpenDiscIPythonKernel.
    
    Not intended for standalone use.
    """
    
    # `InteractiveShell` interface
    
    def run_code(self, code_obj, result=None):        
        # Delay tracing as long as possible. This is function in the shell
        # that actually calls `exec()` on user code.
        if self.kernel._trace_flag:
            with self.kernel._tracer:
                return super(OpenDiscIPythonShell, self).run_code(
                    code_obj, result)
        else:
            return super(OpenDiscIPythonShell, self).run_code(
                code_obj, result)

    
InteractiveShellABC.register(OpenDiscIPythonShell)
