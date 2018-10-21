using .RCall

@rimport flowgraph as RFlowGraph

function record_file(inpath::String, outpath::String, ::Val{:r})
  RFlowGraph.record_file(inpath, out=outpath, annotate=true)
end
