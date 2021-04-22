# Semantic flow graphs

[![Build Status](https://github.com/IBM/semanticflowgraph/workflows/Tests/badge.svg)](https://github.com/IBM/semanticflowgraph/actions?query=workflow%3ATests)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.1401686.svg)](https://doi.org/10.5281/zenodo.1401686)

**Create semantic dataflow graphs of data science code.**

Using this package, you can convert data science code to dataflow graphs with
semantic content. The package works in tandem with the [Data Science
Ontology](https://github.com/ibm/datascienceontology) and our language-specific
program analysis tools. Currently [Python](https://github.com/ibm/pyflowgraph)
and [R](https://github.com/ibm/rflowgraph) are supported.

For more information, please see our [research
paper](https://www.epatters.org/papers/#2018-semantic-enrichment) on "Teaching
machines to understand data science code by semantic enrichment of dataflow
graphs".

## Command-line interface

We provide a CLI that supports the recording, semantic enrichment, and
visualization of flow graphs. To set up the CLI, install this package and add
the `bin` directory to your `PATH`. Invoke the CLI by running `flowgraphs.jl`
in your terminal.

The CLI includes the following commands:

- `record`: Record a raw flow graph by running a script.  
  **Requirements**: To record a Python script, you must install the Julia
  package [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) and the Python
  package [flowgraph](https://github.com/ibm/pyflowgraph). Likewise, to record
  an R script, you must install the Julia package
  [RCall.jl](https://github.com/JuliaInterop/RCall.jl) and the R package
  [flowgraph](https://github.com/ibm/rflowgraph).
- `enrich`: Convert a raw flow graph to a semantic flow graph.
- `visualize`: Visualize a flow graph using
  [Graphviz](https://gitlab.com/graphviz/graphviz).  
  **Requirements**: To output an image, using the `--to` switch, you must
  install Graphviz.


All the commands take as primary argument either a directory, which is filtered
by file extension, or a single file, arbitrarily named.

### CLI examples

Record all Python/R scripts in the current directory, yielding raw flow graphs:

```
flowgraphs.jl record .
```

Convert a raw flow graph to a semantic flow graph:

```
flowgraphs.jl enrich my_script.py.graphml --out my_script.graphml
```

Visualize a semantic flow graph, creating and opening an SVG file:

```
flowgraphs.jl visualize myscript.graphml --to svg --open
```
