#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

params.input_csv = null
params.test_param = "default"

workflow {
    log.info "input_csv: ${params.input_csv}"
    log.info "test_param: ${params.test_param}"
}