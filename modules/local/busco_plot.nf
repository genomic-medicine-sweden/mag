// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options    = initOptions(params.options)

process BUSCO_PLOT {
    tag "${meta.assembler}-${meta.id}"

    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:'') }

    conda (params.enable_conda ? "bioconda::busco=5.1.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/busco:5.1.0--py_1"
    } else {
        container "quay.io/biocontainers/busco:5.1.0--py_1"
    }

    input:
    tuple val(meta), path(summaries), path(failed_bins)

    output:
    path("${meta.assembler}-${meta.id}-busco_figure.png") , optional:true, emit: png
    path("${meta.assembler}-${meta.id}-busco_figure.R")   , optional:true, emit: rscript
    path("${meta.assembler}-${meta.id}-busco_summary.txt")               , emit: summary
    path '*.version.txt'                                                 , emit: version

    script:
    def software = getSoftwareName(task.process)
    def f        = failed_bins.size() > 0 ? "-f ${failed_bins}" : ""
    """
    if [ -n "${summaries}" ]
    then
        # replace dots in bin names within summary file names by underscores
        # currently (BUSCO v5.1.0) generate_plot.py does not allow further dots
        for sum in ${summaries}; do
            [[ \${sum} =~ short_summary.(.*).${meta.assembler}-${meta.id}.(.*).txt ]];
            db_name=\${BASH_REMATCH[1]}
            bin="${meta.assembler}-${meta.id}.\${BASH_REMATCH[2]}"
            bin_new="\${bin//./_}"
            mv \${sum} short_summary.\${db_name}.\${bin_new}.txt
        done
        generate_plot.py --working_directory .

        mv busco_figure.png "${meta.assembler}-${meta.id}-busco_figure.png"
        mv busco_figure.R "${meta.assembler}-${meta.id}-busco_figure.R"

        summary_busco.py -s short_summary.*.txt $f > "${meta.assembler}-${meta.id}-busco_summary.txt"
    else
        summary_busco.py -f ${failed_bins} > "${meta.assembler}-${meta.id}-busco_summary.txt"
    fi

    busco --version | sed "s/BUSCO //" > ${software}.version.txt
    """
}
