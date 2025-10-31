# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/home/luciano/esp/v5.5.1/esp-idf/components/bootloader/subproject"
  "/opt/lampp/htdocs/aguadaPy/firmware2/gateway_wifi/build/bootloader"
  "/opt/lampp/htdocs/aguadaPy/firmware2/gateway_wifi/build/bootloader-prefix"
  "/opt/lampp/htdocs/aguadaPy/firmware2/gateway_wifi/build/bootloader-prefix/tmp"
  "/opt/lampp/htdocs/aguadaPy/firmware2/gateway_wifi/build/bootloader-prefix/src/bootloader-stamp"
  "/opt/lampp/htdocs/aguadaPy/firmware2/gateway_wifi/build/bootloader-prefix/src"
  "/opt/lampp/htdocs/aguadaPy/firmware2/gateway_wifi/build/bootloader-prefix/src/bootloader-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/opt/lampp/htdocs/aguadaPy/firmware2/gateway_wifi/build/bootloader-prefix/src/bootloader-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/opt/lampp/htdocs/aguadaPy/firmware2/gateway_wifi/build/bootloader-prefix/src/bootloader-stamp${cfgdir}") # cfgdir has leading slash
endif()
