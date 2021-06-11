cmake_minimum_required(VERSION 3.10)

set(CMAKE_CXX_STANDARD 17)
if(${ESP_PLATFORM})
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(name_of_your_project)
else()
endif()
