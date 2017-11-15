module FlowGraph
export MonoclElem, RawNode, RawPort, RawWire, RawNodeAnnotationKind,
  read_raw_graph, read_raw_graph_file,
  read_semantic_graph, read_semantic_graph_file, to_semantic_graph

using Base.Iterators: product

using AutoHashEquals, Parameters
import LightXML
using LightGraphs

using Catlab.Diagram
using ..Doctrine
using ..Ontology

# Raw flow graph
################

@enum(RawNodeAnnotationKind,
  FunctionAnnotation = 0,
  ConstructAnnotation = 1,
  SlotAnnotation = 2)

@with_kw struct RawNode
  language::Dict{String,Any} = Dict{String,Any}()
  annotation::Nullable{String} = Nullable{String}()
  annotation_kind::RawNodeAnnotationKind = FunctionAnnotation
end

@with_kw struct RawPort
  language::Dict{String,Any} = Dict{String,Any}()
  annotation::Nullable{String} = Nullable{String}()
  index::Nullable{Int} = Nullable()
  value::Nullable = Nullable()
end

@with_kw struct RawWire
  language::Dict{String,Any} = Dict{String,Any}()
  id::Nullable{String} = Nullable{String}()
  value::Nullable = Nullable()
end

""" Read raw flow graph from GraphML.
"""
function read_raw_graph(xdoc::LightXML.XMLDocument)
  GraphML.read_graphml(RawNode, RawPort, RawWire, xdoc)
end
read_raw_graph(xml::String) = read_raw_graph(LightXML.parse_string(xml))
read_raw_graph_file(args...) = read_raw_graph(LightXML.parse_file(args...))

function GraphML.convert_from_graphml_data(::Type{RawNode}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  construct = Nullable{String}(pop!(data, "construct_annotation", nothing))
  slot = Nullable{String}(pop!(data, "slot_annotation", nothing))
  if !isnull(construct)
    RawNode(data, construct, ConstructAnnotation)
  elseif !isnull(slot)
    RawNode(data, slot, SlotAnnotation)
  else
    RawNode(data, annotation, FunctionAnnotation)
  end
end

function GraphML.convert_from_graphml_data(::Type{RawPort}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  annotation_index = Nullable{Int}(pop!(data, "annotation_index", nothing))
  value = pop!(data, "value", Nullable())
  RawPort(data, annotation, annotation_index, value)
end

function GraphML.convert_from_graphml_data(::Type{RawWire}, data::Dict)
  pop!(data, "annotation", nothing) # Get object annotation from port, not wire.
  id = Nullable{String}(pop!(data, "id", nothing))
  value = pop!(data, "value", Nullable())
  RawWire(data, id, value)
end

# Semantic flow graph
#####################

""" Object in the Monocl category of elements.
"""
@auto_hash_equals struct MonoclElem
  id::Nullable{String}
  value::Nullable
end
MonoclElem(; id=Nullable{String}(), value=Nullable()) = MonoclElem(id, value)

""" Read semantic flow graph from GraphML.
"""
function read_semantic_graph(xdoc::LightXML.XMLDocument; elements::Bool=true)
  Wire = elements ? MonoclElem : Void
  GraphML.read_graphml(Nullable{Monocl.Hom}, Nullable{Monocl.Ob}, Wire, xdoc)
end
function read_semantic_graph(xml::String; kw...)
  read_semantic_graph(LightXML.parse_string(xml); kw...)
end
function read_semantic_graph_file(args...; kw...)
  read_semantic_graph(LightXML.parse_file(args...); kw...)
end

""" Convert a raw flow graph into a semantic flow graph.
"""
function to_semantic_graph(db::OntologyDB, raw::WiringDiagram;
                           elements::Bool=true)::WiringDiagram
  sem = WiringDiagram(to_semantic_ports(db, input_ports(raw)),
                      to_semantic_ports(db, output_ports(raw)))
  
  # Add boxes.
  to_substitute = Int[]
  for v in box_ids(raw)
    raw_box = box(raw, v)
    sem_box = to_semantic_graph(db, raw_box; elements=elements)
    @assert add_box!(sem, sem_box) == v
    if isa(raw_box, Box) && isa(sem_box, WiringDiagram)
      # If the raw box is atomic but the semantic box is a wiring diagram,
      # we should expand it by substitution. We defer the substitution until
      # later so that the box IDs on the wires remain valid.
      push!(to_substitute, v)
    end    
  end
  
  # Add wires.
  for wire in wires(raw)
    raw_wire = wire.value::RawWire
    elem = elements ? MonoclElem(raw_wire.id, raw_wire.value) : nothing
    add_wire!(sem, Wire(elem, wire.source, wire.target))
  end
  
  # Perform deferred substitutions (see above).
  substitute!(sem, to_substitute)
  
  # Simplify the diagram by collapsing adjacent unannotated boxes.
  collapse_unannotated_boxes!(sem)
  
  return sem
end

function to_semantic_graph(db::OntologyDB, raw_box::Box{RawNode}; kw...)::AbstractBox
  if isnull(raw_box.value.annotation)
    Box(nothing,
        to_semantic_ports(db, input_ports(raw_box)),
        to_semantic_ports(db, output_ports(raw_box)))
  else
    expand_annotated_box(db, raw_box)
  end
end

function to_semantic_ports(db::OntologyDB, ports::Vector{RawPort})
  [ isnull(port.annotation) ? nothing : expand_annotated_port(db, port)
    for port in ports ]
end

""" Expand a single annotated box from a raw flow graph.
"""
function expand_annotated_box(db::OntologyDB, raw_box::Box{RawNode})::WiringDiagram
  expand_annotated_box(db, raw_box, Val{raw_box.value.annotation_kind})
end

function expand_annotated_box(db::OntologyDB, raw_box::Box{RawNode},
                              ::Type{Val{FunctionAnnotation}})
  inputs = input_ports(raw_box)
  outputs = output_ports(raw_box)
  note = load_annotation(db, get(raw_box.value.annotation))::HomAnnotation
  f = WiringDiagram(inputs, outputs)
  v = add_box!(f, to_wiring_diagram(note.definition))
  add_wires!(f, ((input_id(f), i) => (v, get(port.index))
                 for (i, port) in enumerate(inputs) if !isnull(port.index)))
  add_wires!(f, ((v, get(port.index)) => (output_id(f), i)
                 for (i, port) in enumerate(outputs) if !isnull(port.index)))
  substitute!(f, v)
  return f
end

function expand_annotated_box(db::OntologyDB, raw_box::Box{RawNode},
                              ::Type{Val{ConstructAnnotation}})
  note = load_annotation(db, get(raw_box.value.annotation))::ObAnnotation
  to_wiring_diagram(construct(note.definition))
end

function expand_annotated_box(db::OntologyDB, raw_box::Box{RawNode},
                              ::Type{Val{SlotAnnotation}})
  definition = load_concept(db, get(raw_box.value.annotation))::Monocl.Hom
  to_wiring_diagram(definition)
end

""" Expand a single annotated port from a raw flow graph.
"""
function expand_annotated_port(db::OntologyDB, raw_port::RawPort)::Monocl.Ob
  note = load_annotation(db, get(raw_port.annotation))::ObAnnotation
  note.definition
end

""" Collapse adjacent unannotated boxes into single boxes.
"""
function collapse_unannotated_boxes!(diagram::WiringDiagram)
  graph = Wiring.graph(diagram)
  closure = transitiveclosure(graph)
  
  nonboxes = (input_id(diagram), output_id(diagram))
  is_annotated(v::Int) = !(v in nonboxes) && box(diagram,v).value != nothing
  is_unannotated(v::Int) = !(v in nonboxes) && box(diagram,v).value == nothing
  annotated_ancestors(v::Int) = filter(is_annotated, in_neighbors(closure, v))
  annotated_descendants(v::Int) = filter(is_annotated, out_neighbors(closure, v))

  to_collapse = Graph(nv(graph))
  for parent in 1:nv(graph)
    for child in out_neighbors(graph, parent)
      if (is_unannotated(parent) && is_unannotated(child) &&
          all(has_edge(closure, u, v)
              for (u,v) in product(annotated_ancestors(child),
                                   annotated_descendants(parent))))
        add_edge!(to_collapse, parent, child)
      end
    end
  end
  
  # Encapsulate connected sub-diagrams of unannotated boxes. Include even
  # components of size 1 because encapsulation will simplify the ports.
  components = [ c for c in connected_components(to_collapse)
                 if length(c) > 1 || is_unannotated(first(c)) ]
  encapsulate!(diagram, components, nothing)
  return diagram
end

end
