""" Serialize NetworkX graphs using GraphML.

This module extends the GraphML support in NetworkX in several directions.

    1. Support for structured metadata. Graph, node, and edge metadata can be
       arbitrary JSON-able Python objects.
       
       TODO: We should define a new XML schema that describes the extension,
       as suggested by the GraphML Primer.
    
    2. Support for nested graphs (i.e., nodes containing graphs). Nested graphs
       are already part of the GraphML standard, but NetworkX doesn't support
       them as first-class citizens. To represent a nested graph in NetworkX,
       add node data with key `graph` and value an instance of `nx.Graph`.
       Note that GraphML allows at most one `<graph>` subelement of a `<node>`
       element.
       
       To represent an edge between a node `n` and its parent graph, create an
       edge between `n` and a node named by the parent graph attribute `node`
       (in the undirected case) or the attributes `input_node` or `output_node`
       (in the directed case).
       
    3. Support for ports. Like nested graphs, GraphML supports ports but
       NetworkX does not directly. To represent ports of a NetworkX node,
       add node data with key `ports` and value a dictionary. The keys of the
       dictionary are the names of the ports and the values are dictionaries 
       defining the port attributes. To represent an edge between ports in
       NetworkX, add `sourceport` and `targetport` edge data.

References
----------
GraphML Primer: http://graphml.graphdrawing.org/primer/graphml-primer.html
GraphML Spec: http://graphml.graphdrawing.org/specification/dtd.html
"""
from __future__ import absolute_import

from collections import OrderedDict
from io import BytesIO
import json
try:
    from xml.etree.cElementTree import Element
except ImportError:
    from xml.etree.ElementTree import Element

from ipykernel.jsonutil import json_clean
import networkx as nx
from networkx.readwrite.graphml import GraphMLReader as BaseGraphMLReader, \
    GraphMLWriter as BaseGraphMLWriter
from networkx.utils import open_file, make_str


@open_file(1, mode='wb')
def write_graphml(graph, path, **kwargs):
    """ Write a graph in GraphML XML format.
    
    For documentation, see `networkx.readwrite.graphml.write_graphml`.
    """
    writer = GraphMLWriter(**kwargs)
    writer.add_graph_element(graph)
    writer.dump(path)

@open_file(0, mode='rb')
def read_graphml(path, **kwargs):
    """ Read a graph in GraphML XML format.
    
    For documentation, see `networkx.readwrite.graphml.read_graphml`.
    """
    reader = GraphMLReader(**kwargs)
    graphs = list(reader(path=path))
    return graphs[0]


def write_graphml_str(graph, **kwargs):
    """ Convenience method to write graph to a GraphML string.
    """
    io = BytesIO()
    write_graphml(graph, io, **kwargs)
    return io.getvalue().decode('utf-8')

def read_graphml_str(string, **kwargs):
    """ Conveneince method to read graph from GraphML string.
    """
    io = BytesIO()
    io.write(string.encode('utf-8'))
    io.seek(0)
    return read_graphml(io, **kwargs)
    

class GraphMLWriter(BaseGraphMLWriter):
    """ NetworkX GraphML writer with extensions.
    """
    
    def __init__(self, **kwargs):
        super(GraphMLWriter, self).__init__(**kwargs)
        self.all_nodes = set()
    
    def add_graph_element(self, graph):
        """ Add a top-level graph element.
        
        Reimplemented to delegate to the new `add_graph()` method.
        """
        graph_element = self.add_graph(graph)
        self.xml.append(graph_element)
    
    def add_graph(self, graph, parent_node=None):
        """ Create a graph element (top-level or nested).
        """
        # XXX: Mostly copied from base class `add_graph_element()`.
        default_edge_type = 'directed' if graph.is_directed() else 'undirected'
        graph_element = Element('graph', edgedefault=default_edge_type)
        
        default = {}
        data = { k:v for k,v in graph.graph.items()
                 if k not in ['node_default','edge_default','port_default'] }
        self.add_attributes('graph', graph_element, data, default)
        self.add_nodes(graph, graph_element, parent_node)
        self.add_edges(graph, graph_element, parent_node)
        return graph_element
    
    def add_nodes(self, graph, graph_element, parent_node=None):
        """ Reimplemented to support nested graphs.
        """
        for node, data in graph.nodes_iter(data=True):
            # If the node is a reference to the parent graph, skip it.
            # It has already been added.
            if self.is_parent_reference(graph, node):
                if parent_node is None:
                    msg = "Node {} references non-existent parent node"
                    raise nx.NetworkXError(msg.format(node))
                continue
            
            # Check global uniqueness of node IDs, per GraphML spec.
            node_id = make_str(node)
            if node_id in self.all_nodes:
                msg = "Duplicate node ID '{}' not allowed in GraphML"
                raise nx.NetworkXError(msg.format(node_id))
            self.all_nodes.add(node_id)
            
            # Add node data.
            node_element = Element('node', id=node_id)
            default = graph.graph.get('node_default', {})
            self.add_attributes('node', node_element, data, default)
            
            # Add node ports, if any.
            ports = data.get('ports', {})
            default = graph.graph.get('port_default', {})
            self.add_ports(node_element, ports, default)
            
            # Add nested graph for node, if any.
            nested = data.get('graph')
            if nested and isinstance(nested, nx.Graph):
                nested_element = self.add_graph(nested, parent_node=node)
                node_element.append(nested_element)
            
            graph_element.append(node_element)
    
    def add_ports(self, node_element, ports, default):
        """ Add ports to a <node> element in GraphML.
        """
        for name, data in ports.items():
            port_element = Element('port', name=name)
            self.add_attributes('port', port_element, data, default)
            node_element.append(port_element)
    
    def add_edges(self, graph, graph_element, parent_node=None):
        """ Reimplemented to support ports.
        
        Unlike the base class, we do not store edge keys as data (or at all).
        Cf. this PR for unreleased NetworkX 2.0:
        https://github.com/networkx/networkx/pull/2559
        """
        default = graph.graph.get('edge_default', {})
        for u,v,data in graph.edges_iter(data=True):
            source = parent_node if self.is_parent_reference(graph, u) else u
            target = parent_node if self.is_parent_reference(graph, v) else v
            edge_element = Element('edge',
                source=make_str(source), target=make_str(target))
            
            sourceport = data.get('sourceport')
            if sourceport is not None:
                edge_element.set('sourceport', sourceport)
            
            targetport = data.get('targetport')
            if targetport is not None:
                edge_element.set('targetport', targetport)
            
            self.add_attributes('edge', edge_element, data, default)
            graph_element.append(edge_element)
    
    def add_attributes(self, scope, xml_obj, data, default):
        """ Reimplemented to skip special attributes (nested graph, ports).
        """
        for k,v in data.items():
            if (scope == 'node' and k == 'graph' and isinstance(v, nx.Graph)) or \
               (scope == 'node' and k == 'ports') or \
               (scope == 'edge' and k in ('sourceport', 'targetport')):
                continue
            # Copied from superclass, with one change to avoid premature
            # string coercion of the value.
            default_value = default.get(k)
            obj = self.add_data(make_str(k), type(v), v,
                                scope=scope, default=default_value)
            xml_obj.append(obj)
    
    def add_data(self, name, element_type, value, scope='all', default=None):
        """ Reimplemented to handle JSON data.
        """
        if element_type in BaseGraphMLWriter.xml_type:
            return super(GraphMLWriter, self).add_data(
                name, element_type, value, scope, default)
        
        key_id = self.get_key(name, 'json', scope, default)
        data_element = Element('data', key=key_id)
        data_element.text = json.dumps(json_clean(value))
        return data_element
    
    def is_parent_reference(self, graph, node):
        """ Is the node a reference to the graph itself in the parent graph?
        """
        return any(node == graph.graph[key]
                   for key in ('node', 'input_node', 'output_node')
                   if key in graph.graph)


class GraphMLReader(BaseGraphMLReader):
    """ NetworkX GraphML reader with extensions.
    """
    
    def __init__(self, multigraph=False, **kwargs):
        super(GraphMLReader, self).__init__(**kwargs)
        self.multigraph = multigraph
        self.python_type['json'] = json.loads
    
    def make_graph(self, graph_xml, graphml_keys, defaults, parent_node=None):
        """ Reimplemented to handle nested graphs.
        """
        # set default graph type
        edgedefault = graph_xml.get("edgedefault", None)
        if edgedefault == 'directed':
            graph = nx.MultiDiGraph()
        else:
            graph = nx.MultiGraph()
        
        # set defaults for graph attributes
        for key_id, value in defaults.items():
            key_for = graphml_keys[key_id]['for']
            name = graphml_keys[key_id]['name']
            python_type = graphml_keys[key_id]['type']
            if key_for in ('node', 'edge', 'port'):
                data = graph.graph.setdefault('%s_default' % key_for, {})
                data.update({name: python_type(value)})
        
        # add graph data
        data = self.decode_data_elements(graphml_keys, graph_xml)
        graph.graph.update(data)
        
        # add nodes
        for node_xml in graph_xml.findall("{%s}node" % self.NS_GRAPHML):
            self.add_node(graph, node_xml, graphml_keys, defaults, parent_node)
        # add edges
        for edge_xml in graph_xml.findall("{%s}edge" % self.NS_GRAPHML):
            self.add_edge(graph, edge_xml, graphml_keys, parent_node)
        # hyperedges are not supported
        hyperedge=graph_xml.find("{%s}hyperedge" % self.NS_GRAPHML)
        if hyperedge is not None:
            raise nx.NetworkXError("GraphML reader does not support hyperedges")
        
        # switch to Graph or DiGraph if no parallel edges were found.
        if not self.multigraph:
            if graph.is_directed():
                return nx.DiGraph(graph)
            else:
                return nx.Graph(graph)
        else:
            return graph
    
    def add_node(self, graph, node_xml, graphml_keys, defaults, parent_node):
        """ Reimplemented to handle nested graphs and ports.
        """
        node_id = self.node_type(node_xml.get("id"))
        data = self.decode_data_elements(graphml_keys, node_xml)
        
        # Add ports.
        ports = OrderedDict()
        ports_xml = node_xml.findall('{%s}port' % self.NS_GRAPHML)
        for port_xml in ports_xml:
            name = port_xml.get("name")
            ports[name] = self.decode_data_elements(graphml_keys, port_xml)
        if ports:
            data['ports'] = ports
        
        # Add nested graph, if it exists.
        nested_xml = node_xml.findall('{%s}graph' % self.NS_GRAPHML)
        if len(nested_xml) == 1:
            data['graph'] = self.make_graph(
                nested_xml[0], graphml_keys, defaults, node_id)
        elif len(nested_xml) > 1:
            raise nx.NetworkXError("GraphML allows at most one nested graph per node")
        
        graph.add_node(node_id, data)
    
    def add_edge(self, graph, edge_element, graphml_keys, parent_node):
        """ Reimplemented to handle nested graphs and ports.
        
        Unlike the base class, we do not try to set the NetworkX edge key using
        the GraphML edge ID or `key` data element.
        """
        # Raise error if we find mixed directed and undirected edges
        directed = edge_element.get('directed')
        if graph.is_directed() and directed == 'false':
            raise nx.NetworkXError("Undirected edge found in directed graph")
        if not graph.is_directed() and directed == 'true':
            raise nx.NetworkXError("Directed edge found in undirected graph")

        source = self.node_type(edge_element.get('source'))
        if source == parent_node:
            if 'input_node' in graph.graph:
                source = graph.graph['input_node']
            elif 'node' in graph.graph:
                source = graph.graph['node']
        
        target = self.node_type(edge_element.get('target'))
        if target == parent_node:
            if 'output_node' in graph.graph:
                target = graph.graph['output_node']
            elif 'node' in graph.graph:
                target = graph.graph['node']
        
        data = self.decode_data_elements(graphml_keys, edge_element)
        sourceport = edge_element.get('sourceport')
        targetport = edge_element.get('targetport')
        if sourceport is not None:
            data['sourceport'] = sourceport
        if targetport is not None:
            data['targetport'] = targetport
        
        graph.add_edge(source, target, attr_dict=data)
