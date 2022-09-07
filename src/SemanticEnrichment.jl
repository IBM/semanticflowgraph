# Copyright 2018 IBM Corp.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

""" The semantic enrichment algorithm for dataflow graphs.
"""
module SemanticEnrichment
export to_semantic_graph

using Base.Iterators: product
using Compat

using Graphs, MetaGraphs

using Catlab.WiringDiagrams
using ..Doctrine
using ..Ontology
using ..RawFlowGraphs

""" Convert a raw flow graph into a semantic flow graph.
"""
function to_semantic_graph(db::OntologyDB, raw::WiringDiagram)::WiringDiagram
  sem = WiringDiagram(to_semantic_ports(db, input_ports(raw)),
                      to_semantic_ports(db, output_ports(raw)))
  
  # Add boxes from raw flow graph, marking some for substitution.
  to_substitute = Int[]
  for v in box_ids(raw)
    raw_box = box(raw, v)
    sem_box = to_semantic_graph(db, raw_box)
    @assert add_box!(sem, sem_box) == v
    if isa(raw_box, Box) && isa(sem_box, WiringDiagram)
      # If the raw box is atomic but the semantic box is a wiring diagram,
      # we should expand it by substitution. We defer the substitution until
      # later so that the box IDs on the wires remain valid.
      push!(to_substitute, v)
    end    
  end
  
  # Add wires from raw flow graph.
  # FIXME: If a raw box expands to a semantic box that is missing a port with
  # incoming or outoging wires in the raw graph (e.g., when an unannotated
  # keyword argument is passed), this logic will fail. We should detect this
  # situation and either raise an informative error or discard the wire.
  add_wires!(sem, wires(raw))
  
  # Perform deferred substitutions (see above).
  sem = substitute(sem, to_substitute)
  
  # Simplify the diagram by collapsing adjacent unannotated boxes.
  collapse_unannotated_boxes(sem)
end

function to_semantic_graph(db::OntologyDB, raw_box::Box{RawNode})::AbstractBox
  if isnothing(raw_box.value.annotation)
    Box(nothing,
        to_semantic_ports(db, input_ports(raw_box)),
        to_semantic_ports(db, output_ports(raw_box)))
  else
    expand_annotated_box(db, raw_box)
  end
end

function to_semantic_ports(db::OntologyDB, ports::AbstractVector)
  [ isnothing(port.annotation) ? nothing : expand_annotated_port(db, port)
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
  note = load_annotation(db, raw_box.value.annotation)::HomAnnotation
  f = WiringDiagram(inputs, outputs)
  v = add_box!(f, to_wiring_diagram(note.definition))
  add_wires!(f, ((input_id(f), i) => (v, port.annotation_index)
                 for (i, port) in enumerate(inputs)
                 if !isnothing(port.annotation_index)))
  add_wires!(f, ((v, port.annotation_index) => (output_id(f), i)
                 for (i, port) in enumerate(outputs)
                 if !isnothing(port.annotation_index)))
  substitute(f, v)
end

function expand_annotated_box(db::OntologyDB, raw_box::Box{RawNode},
                              ::Type{Val{ConstructAnnotation}})
  note = load_annotation(db, raw_box.value.annotation)::ObAnnotation
  to_wiring_diagram(construct(note.definition))
end

function expand_annotated_box(db::OntologyDB, raw_box::Box{RawNode},
                              ::Type{Val{SlotAnnotation}})
  note = load_annotation(db, raw_box.value.annotation)::ObAnnotation
  index = raw_box.value.annotation_index
  to_wiring_diagram(note.slots[index])
end

""" Expand a single annotated port from a raw flow graph.
"""
function expand_annotated_port(db::OntologyDB, raw_port::RawPort)::Monocl.Ob
  note = load_annotation(db, raw_port.annotation)::ObAnnotation
  note.definition
end

""" Collapse adjacent unannotated boxes into single boxes.
"""
function collapse_unannotated_boxes(diagram::WiringDiagram)
  # Find maximal groups of unannotated boxes.
  unannotated = filter(box_ids(diagram)) do v
    isnothing(box(diagram,v).value)
  end
  groups = group_blank_vertices(SimpleDiGraph(graph(diagram)), unannotated)

  # Encapsulate the groups, including groups of size 1 because encapsulation
  # will simplify the ports.
  encapsulate(diagram, groups, discard_boxes=true)
end

""" Group adjacent blank vertices of a directed graph.
"""
function group_blank_vertices(graph::SimpleDiGraph, blank::Vector{Int})::Vector{Vector{Int}}
  # Create transitive closure of graph.
  closure = transitiveclosure(graph)
  has_path(u::Int, v::Int) = has_edge(closure, u, v)
  ancestors(v::Int) = Graphs.inneighbors(closure, v)
  descendants(v::Int) = Graphs.outneighbors(closure, v)
  
  # Initialize groups as singletons.
  graph = MetaDiGraph(graph)
  for v in blank
    set_prop!(graph, v, :vertices, [v])
  end
  get_group(v::Int) = get_prop(graph, v, :vertices)
  is_blank(v::Int) = has_prop(graph, v, :vertices)
  not_blank(v::Int) = !is_blank(v)

  # Definition: Two adjacent blank vertices are mergeable if their merger
  # does not introduce any new dependencies between non-blank vertices.
  # That is, if there is no directed path from non-blank vertex `v1` to
  # non-blank vertex `v2` before merging, there will not be one afterwards.
  #
  # This criterion holds iff it's *not* the case that
  #   there exists a non-blank ancestor of the child that isn't an ancestor of
  #   the parent and a non-blank descendant of the parent isn't a descendant of
  #   the child
  # (because if there was, merging would create a new dependency) iff
  #   each non-blank ancestor of the child is also an ancestor of the parent, or
  #   each non-blank descendant of the parent is also a descendent of the child.
  function is_mergable(u::Int, v::Int)
    (is_blank(u) && is_blank(v)) || return false
    parent, child = if has_edge(graph, u, v); (u, v)
      elseif has_edge(graph, v, u); (v, u)
      else return false end
    all(has_path(v, parent) for v in filter(not_blank, ancestors(child))) ||
      all(has_path(child, v) for v in filter(not_blank, descendants(parent)))
  end
  function merge_blank!(u::Int, v::Int)
    append!(get_group(min(u,v)), get_group(max(u,v)))
    merge_vertices_directed!(graph, [u,v])
    merge_vertices_directed!(closure, [u,v])
  end

  # Merge pairs of mergable vertices until there are no more mergable pairs.
  # The loop maintains the invariant that no two vertices less than the current
  # one are mergable.
  v = 1
  while v <= nv(graph)
    merged = false
    for u in Graphs.all_neighbors(graph, v)
      if u > v && is_mergable(u, v)
        merge_blank!(u, v)
        merged = true
        break
      end
    end
    v += !merged
  end

  Vector{Int}[ get_group(v) for v in vertices(graph) if is_blank(v) ]
end

""" Merge the vertices into a single vertex, preserving edges.

Note: Graphs.merge_vertices! only supports undirected graphs.
"""
function merge_vertices_directed!(graph::AbstractGraph, vs::Vector{Int})
  @assert is_directed(graph)
  vs = sort(vs, rev=true)
  v0 = vs[end]
  for v in vs[1:end-1]
    for u in Graphs.inneighbors(graph, v)
      if !(u in vs)
        add_edge!(graph, u, v0)
      end
    end
    for u in Graphs.outneighbors(graph, v)
      if !(u in vs)
        add_edge!(graph, v0, u)
      end
    end
    rem_vertex!(graph, v)
  end
  v0
end

end
