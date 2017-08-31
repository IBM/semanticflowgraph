from __future__ import absolute_import, print_function

from pathlib2 import Path
from textwrap import dedent
import unittest

from ipykernel.tests import utils as tu
from ipykernel.tests.utils import execute, kernel, wait_for_idle
import networkx as nx

from ...core.graphml import read_graphml_str
from ...core.tests import objects as test_objects
from ..kernelspec import get_kernel_name


def inspect(kc, **kwargs):
    """ Send inspect request to kernel and return reply content.
    """
    req_msg = kc.session.msg('inspect_request', kwargs)
    kc.shell_channel.send(req_msg)
    reply = kc.get_shell_msg(timeout=1)
    return reply['content']

def safe_execute(code, kc, **kwargs):
    """ Execute code, raising an error if the status is not OK.
    """
    msg_id, content = execute(code, kc, **kwargs)
    wait_for_idle(kc)
    if content['status'] != 'ok':
        tb = content.pop('traceback', None)
        if tb:
            print("Traceback from kernel:")
            for line in tb:
                print(line)
        raise RuntimeError('Kernel error: {}'.format(content))
    return content


class TestOpenDiscKernel(unittest.TestCase):
    """ Tests the Open Discovery IPython kernel.
    """
    
    @classmethod
    def setUpClass(cls):
        """ Launch kernel and set search path for annotator.
        """
        tu.KM, tu.KC = tu.start_new_kernel(kernel_name=get_kernel_name())
        
        objects_path = Path(test_objects.__file__).parent
        json_path = objects_path.joinpath('data', 'annotations.json')
        code = dedent("""\
        shell = get_ipython()
        shell.kernel.annotator.db.load_file('%s')
        """ % json_path)
        with kernel() as kc:
            safe_execute(code, kc, silent=True)
    
    @classmethod
    def tearDownClass(cls):
        """ Stop the kernel.
        """
        tu.stop_global_kernel()
        
    def setUp(self):
        """ Clear the user namespace before running a test.
        """
        code = dedent("""\
        %reset -f
        from opendisc.core.tests.objects import Foo, Bar, Baz
        """)
        with kernel() as kc:
            safe_execute(code, kc, silent=True)
    
    def test_execute_request(self):
        """ Do execute requests have flow graph payloads?
        """
        with kernel() as kc:
            content = safe_execute('bar = Bar()', kc)
        
        for payload in content['payload']:
            if payload['source'] == 'flow_graph':
                break
        else:
            self.fail("No flow graph payload")
        
        mimetype = payload['mimetype']
        self.assertEqual(mimetype, 'application/graphml+xml')
        
        graph = read_graphml_str(payload['data'])
        self.assertTrue(isinstance(graph, nx.DiGraph))
    
    def test_inspect_request(self):
        """ Are inspect requests for annotated objects processed correctly?
        """
        with kernel() as kc:
            id_expr = 'get_ipython().kernel.get_object_id(foo)'
            content = safe_execute('foo = Foo()', kc,
                                   user_expressions={'id':id_expr})
            obj_id_data = content['user_expressions']['id']
            self.assertEqual(obj_id_data['status'], 'ok')
            obj_id = eval(obj_id_data['data']['text/plain'])
            
            slots = {'x': 'x', 'y': 'y'}
            content = inspect(kc, object_id=obj_id, slots=slots)
            self.assertEqual(content['status'], 'ok')
            self.assertEqual(content['found'], True)
            self.assertEqual(content['data']['application/json'],
                             {'x': 1, 'y': 1})
            
            content = inspect(kc, object_id='XXX', slots=[]) # bad object ID
            self.assertEqual(content['status'], 'ok')
            self.assertEqual(content['found'], False)
    
    def test_inspect_request_spec(self):
        """ Check that the official inspection requests defined by the
        Jupyter messaging spec are not broken.
        """
        with kernel() as kc:
            safe_execute('foo = Foo()', kc)
            msg_id = kc.inspect('foo')
            reply = kc.get_shell_msg(timeout=1)
        
        content = reply['content']
        self.assertEqual(content['status'], 'ok')
        self.assertEqual(content['found'], True)
        self.assertTrue('text/plain' in content['data'])
        

if __name__ == '__main__':
    unittest.main()
