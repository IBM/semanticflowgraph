from __future__ import absolute_import

from ipykernel.ipkernel import IPythonKernel
from networkx.readwrite import json_graph
from traitlets import Bool, Instance, Type, default

from ..core.annotator import Annotator
from ..core.flow_graph import flow_graph_to_graphml
from ..core.flow_graph_builder import FlowGraphBuilder
from ..core.graphml import write_graphml_str
from ..core.remote_annotation_db import RemoteAnnotationDB
from ..trace.tracer import Tracer
from .serialize import object_to_json
from .shell import OpenDiscIPythonShell
from .slots import get_slots


class OpenDiscIPythonKernel(IPythonKernel):
    """ IPython kernel with support for execution events and object inspection.
    """
    
    # Annotator for objects and functions.
    annotator = Instance(Annotator)
    
    # `IPythonKernel` traits.
    shell_class = Type(OpenDiscIPythonShell)
    
    # Private traits.
    _builder = Instance(FlowGraphBuilder)
    _tracer = Instance(Tracer, args=())
    _trace_flag = Bool()

    # `OpenDiscIPythonKernel` interface
    
    def get_object(self, obj_id):
        """ Get a tracked object by ID.
        """
        return self._tracer.object_tracker.get_object(obj_id)
    
    def get_object_id(self, obj):
        """ Get the ID of a tracked object.
        """
        return self._tracer.object_tracker.get_id(obj)
    
    # `KernelBase` interface
    
    def do_execute(self, code, silent, *args, **kwargs):
        """ Reimplemented to perform tracing.
        """
        # Do execution, with tracing unless the execution request is `silent`.
        self._builder.reset()
        self._trace_flag = not silent
        reply_content = super(OpenDiscIPythonKernel, self).do_execute(
            code, silent, *args, **kwargs)
        
        # Add flow graph as a payload.
        if self._trace_flag and reply_content['status'] == 'ok':
            graph = self._builder.graph
            graphml = flow_graph_to_graphml(graph, simplify_outputs=True)
            data = write_graphml_str(graphml, prettyprint=False)
            payload = {
                'source': 'flow_graph',
                'mimetype': 'application/graphml+xml',
                'data': data,
            }
            reply_content['payload'].append(payload)
        
        return reply_content
    
    def inspect_request(self, stream, ident, parent):
        """ Reimplemented to handle inspect requests for annotated objects.
        """
        content = parent['content']
        if 'object_id' not in content:
            return super(OpenDiscIPythonKernel, self).inspect_request(
                stream, ident, parent)

        obj_id = content['object_id']
        obj = self.get_object(obj_id)
        if obj is None:
            reply_content = {
                'status': 'ok',
                'found': False,
                'data': {},
                'metadata': {},
            }
        else:
            inspect_data = get_slots(obj, content['slots'])
            reply_content = {
                'status': 'ok',
                'found': True,
                'data': {
                    'application/json': object_to_json(inspect_data),
                },
                'metadata': {},
            }
        
        msg = self.session.send(stream, 'inspect_reply',
                                reply_content, parent, ident)
        self.log.debug("%s", msg)
    
    # Trait initializers
    
    @default('annotator')
    def _annotator_default(self):
        # Inherit database config from kernel.
        db = RemoteAnnotationDB(parent=self)
        return Annotator(db=db)
    
    @default('_builder')
    def _builder_default(self):
        builder = FlowGraphBuilder(annotator=self.annotator)
        
        def handler(changed):
            event = changed['new']
            if event:
                builder.push_event(event)
        self._tracer.observe(handler, 'event')
    
        return builder
