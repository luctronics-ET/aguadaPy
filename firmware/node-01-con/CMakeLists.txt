# Aguada V2 - Node Aguada 01
cmake_minimum_required(VERSION 3.16)

# Adiciona componentes customizados
set(EXTRA_COMPONENT_DIRS "../components")

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(node_aguada_01)
