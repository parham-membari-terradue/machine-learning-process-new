cwlVersion: v1.2
$namespaces:
  s: https://schema.org/
s:softwareVersion: 1.0.8
schemas:
  - http://schema.org/version/9.0/schemaorg-current-http.rdf
$graph:
  - class: Workflow
    id: tile-sat-inference
    label: Tile-SAT Inference on Sentinel-2 L1C data
    doc: A trained CNN model performs a tile-based inference on Sentinel-2 L1C data to classify image into 11 different classes.
    requirements:
      - class: InlineJavascriptRequirement
      - class: ScatterFeatureRequirement
      - class: SubworkflowFeatureRequirement
    inputs:
      input_reference:
        doc: S2 product
        label: S2 product
        type: Directory[]
    outputs:
      results:
        outputSource:
        - steps_check_calibrate_and_makeinference/results
        type: Directory[]
    steps:
      steps_check_calibrate_and_makeinference:
        in:
          input_reference: input_reference
        out:
        - results
        run: '#check-calibrate-and-inference'
        scatter: input_reference
        scatterMethod: dotproduct

  - class: Workflow
    doc: This service checks if a product is calibrated and, if not, calibrate it, and then applies inference
    id: check-calibrate-and-inference
    label: Check and calibrate if needed, and then apply inference
    requirements:
      InlineJavascriptRequirement: {}
      MultipleInputFeatureRequirement: {}
      NetworkAccess:
        networkAccess: true
    inputs:
      input_reference:
        type: Directory
        doc: Optical acquisition with red, nir and swir22
        label: Optical acquisition with red, nir and swir22
    outputs:
      results:
        outputSource:
          step_make_inference/artifacts
        type: Directory
    steps:
      step_check:
        in:
          input_path: input_reference
        out:
        - prod_type
        run: '#check_prodType'

      step_calib_opt:
        in:
          input_path: input_reference
          prodType: step_check/prod_type
        out:
        - results
        run: '#opt-cal'
        when: $( inputs.prodType.includes("native") )

      step_make_inference:
        run: '#make_inference'
        in:
          input_reference:
            source:
              - step_calib_opt/results
              - input_reference
            pickValue: first_non_null
        out:
        - artifacts
  - baseCommand: opt-calibration
    class: CommandLineTool
    hints:
      DockerRequirement:
        dockerPull: docker.terradue.com/opt-calibration:0.18.0
    id: opt-cal
    arguments:
    - --composite
    - trc
    - --s_expressions
    - "ndvi: (where (& (> nir 0) (> red 0)) (norm_diff nir red) nil)"
    - --s_expressions
    - "ndwi: (where (& (> green 0) (> nir 0)) (norm_diff green nir) nil)"
    - --s_expressions
    - "ndbi: (where (& (> swir16 0) (> nir08 0)) (norm_diff swir16 nir08) nil)"
    - --s_expressions
    - "bav: (where (& (< (+ (/ (- swir16 swir22) (+ swir16 swir22) ) nir) 1000) (> swir16 1000) (< blue 1000) (< ndvi 0.3) (< ndwi 0.1) ) 1 0)"
    inputs:
      input_path:
        inputBinding:
          position: 1
          prefix: --input_path
        type: Directory
    outputs:
      results:
        outputBinding:
          glob: .
        type: Directory
    requirements:
      EnvVarRequirement:
        envDef:
          APP_DOCKER_IMAGE: docker.terradue.com/opt-calibration:0.18.0
          APP_NAME: opt-calibration
          APP_PACKAGE: app-opt-calibration.0.18.0
          APP_VERSION: 0.18.0
          GDAL_CACHEMAX: '4096'
          GDAL_NUM_THREADS: ALL_CPUS
          LC_NUMERIC: C
          LD_LIBRARY_PATH: /srv/conda/envs/env_opt_calibration/conda-otb/lib/:/opt/anaconda/envs/env_opt_calibration/lib/:/usr/lib64
          OTB_APPLICATION_PATH: /srv/conda/envs/env_opt_calibration/conda-otb/lib/otb/applications
          OTB_MAX_RAM_HINT: '8192'
          PATH: /srv/conda/envs/env_opt_calibration/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/srv/conda/envs/env_opt_calibration/bin
          PREFIX: /srv/conda/envs/env_opt_calibration
          PYTHONPATH: /srv/conda/envs/env_opt_calibration/conda-otb/lib/python
          _PROJECT: UTEP
      ResourceRequirement:
        coresMax: 8
        ramMax: 24576

  - baseCommand: ["/bin/bash", "run.sh"]
    stdout: message
    class: CommandLineTool
    hints:
      DockerRequirement:
        dockerPull: docker.io/python:3.9.9-slim-bullseye
    id: check_prodType
    inputs:
      input_path:
        inputBinding:
          position: 1
        type: Directory
    outputs:
      prod_type:
        type: string
        outputBinding:
          glob: message
          loadContents: true
          outputEval:  $( self[0].contents )
    requirements:
      EnvVarRequirement:
        envDef:
          PATH: /srv/conda/envs/env_dim2stac/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
      ResourceRequirement: {
          coresMax: 1,
          ramMax: 1000
          }
      InitialWorkDirRequirement:
        listing:
          - entryname: run.sh
            entry: |-
              set -x
              pip3 install pystac==1.6.1 1>&2
              prod_type=`python p.py "$@"`
              echo "\${prod_type}"
              rm -fr .local .cache p.py run.sh

          - entryname: p.py
            entry: |-
              import json
              import glob
              import sys, os, shutil, pprint
              from collections import OrderedDict
              from shutil import copytree, ignore_patterns
              from pystac import Item, Catalog

              def get_item(catalog) -> Item:
                  cat = Catalog.from_file(catalog)
                  try:
                      collection = next(cat.get_children())
                      item = next(collection.get_items())
                  except StopIteration:
                      item = next(cat.get_items())
                  return item

              paths = sys.argv

              path=paths[1]
              dirname = os.path.basename(path)
              item = get_item(os.path.join(path, 'catalog.json'))
              media_types = [asset.media_type for p,asset in item.get_assets().items()]
              if 'image/tiff; application=geotiff; profile=cloud-optimized' in media_types:
                  print("calibrated")
              else:
                  print("native")




  - class: CommandLineTool
    id: make_inference
    hints:
      DockerRequirement:
        dockerPull: tile-sat-inference:latest
    baseCommand: ["make-inference"]
    inputs:
      input_reference:
        type: Directory
        inputBinding:
          position: 1
          prefix: --input_reference
    outputs:
      artifacts:
        outputBinding:
          glob: .
        type: Directory
    requirements:
      InlineJavascriptRequirement: {}
      NetworkAccess:
        networkAccess: true
      ResourceRequirement:
        coresMax: 1
        ramMax: 3000
