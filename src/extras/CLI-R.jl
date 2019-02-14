using .RCall

@rimport flowgraph as RFlowGraphs

function record_file(inpath::String, outpath::String, args::Dict, ::Val{:r})
  RFlowGraphs.record_file(
    inpath, out=outpath, cwd=dirname(inpath), annotate=true,
    annotations=args["annotations"])
end
