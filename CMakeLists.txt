# CMake script for Ohcount.
# Written by Guilherme Balena Versiani. guibv<att>comunip.com.br.

CMAKE_MINIMUM_REQUIRED(VERSION 2.8)

# Find bash executable
FIND_PROGRAM(BASH_EXECUTABLE bash)
IF(NOT BASH_EXECUTABLE)
  MESSAGE(SEND_ERROR "Bash executable not found, you need it in order to build ohcount")
ENDIF(NOT BASH_EXECUTABLE)

# Find gperf executable
FIND_PROGRAM(GPERF_EXECUTABLE gperf)
IF(NOT GPERF_EXECUTABLE)
  MESSAGE(SEND_ERROR "GNU gperf executable not found, you need it in order to build ohcount")
ENDIF(NOT GPERF_EXECUTABLE)

# Find Ragel executable
FIND_PROGRAM(RAGEL_EXECUTABLE ragel)
IF(NOT RAGEL_EXECUTABLE)
  MESSAGE(SEND_ERROR "Ragel executable not found, you need it in order to build ohcount")
ENDIF(NOT RAGEL_EXECUTABLE)

# Find PCRE library
FIND_LIBRARY(PCRE_LIBRARY pcre libpcre pcreMD libpcreMD)
IF(NOT PCRE_LIBRARY)
  MESSAGE(SEND_ERROR "PCRE library not found, you need it in order to build ohcount")
ENDIF(NOT PCRE_LIBRARY)

# Gperf input files:
FILE(GLOB _hash_header_srcs "${CMAKE_SOURCE_DIR}/src/hash/*.gperf")

UNSET(_hash_header_headers)
FOREACH(_hsrc ${_hash_header_srcs})
  STRING(REPLACE "s.gperf" "_hash.h" _hh ${_hsrc})
  LIST(APPEND _hash_header_headers ${_hh})
ENDFOREACH(_hsrc)

ADD_CUSTOM_COMMAND(
  OUTPUT ${_hash_header_headers}
         ${CMAKE_SOURCE_DIR}/src/hash/language_hash.c
  COMMAND ${BASH_EXECUTABLE} ./generate_headers
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/hash
  DEPENDS ${_hash_header_srcs}
          ${CMAKE_SOURCE_DIR}/src/hash/generate_headers
          ${GPERF_EXECUTABLE}
)

SET_SOURCE_FILES_PROPERTIES(${_hash_header_headers}
  PROPERTIES
    HEADER_FILE_ONLY TRUE
)

# Ragel input files:
FILE(GLOB _parser_srcs "${CMAKE_SOURCE_DIR}/src/parsers/*.rl")

UNSET(_parser_headers)
FOREACH(_parser ${_parser_srcs})
  GET_FILENAME_COMPONENT(_path ${_parser} PATH)
  GET_FILENAME_COMPONENT(_name ${_parser} NAME_WE)
  LIST(APPEND _parser_headers ${_path}/${_name}.h)
ENDFOREACH(_parser)

ADD_CUSTOM_COMMAND(
  OUTPUT ${_parser_headers}
  COMMAND ${BASH_EXECUTABLE} ./compile
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/parsers
  DEPENDS ${_parser_srcs}
          ${CMAKE_SOURCE_DIR}/src/parsers/compile
          ${RAGEL_EXECUTABLE}
)

SET_SOURCE_FILES_PROPERTIES(${_parser_headers}
  PROPERTIES
    HEADER_FILE_ONLY TRUE
)

# Ohcount static library
ADD_LIBRARY(libohcount STATIC
  ${_hash_header_headers}
  ${_parser_headers}
  src/sourcefile.c
  src/detector.c
  src/licenses.c
  src/parser.c
  src/loc.c
  src/log.c
  src/diff.c
  src/parsed_language.c
  src/hash/language_hash.c
)
SET_TARGET_PROPERTIES(libohcount PROPERTIES OUTPUT_NAME ohcount)
TARGET_LINK_LIBRARIES(libohcount pcre)

# Main executable
ADD_EXECUTABLE(ohcount src/ohcount.c)
ADD_DEPENDENCIES(ohcount libohcount)
TARGET_LINK_LIBRARIES(ohcount libohcount)

SET(ENABLE_RUBY TRUE CACHE BOOLEAN "Enable ruby binding")
IF(ENABLE_RUBY)

  MESSAGE(STATUS "Enabled Ruby binding")

  # Find Ruby executable
  FIND_PACKAGE(Ruby REQUIRED)
  IF(NOT RUBY_FOUND)
    MESSAGE(SEND_ERROR "You need Ruby to build Ruby binding")
  ENDIF(NOT RUBY_FOUND)

  # Find SWIG executable
  FIND_PACKAGE(SWIG REQUIRED)
  IF(NOT SWIG_FOUND)
    MESSAGE(SEND_ERROR "You need SWIG to build Ruby binding")
  ENDIF(NOT SWIG_FOUND)

  FILE(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/ruby/${RUBY_ARCH})

  ADD_CUSTOM_COMMAND(
    OUTPUT ${CMAKE_BINARY_DIR}/ruby/ohcount_wrap.c
    COMMAND ${SWIG_EXECUTABLE} -ruby -o ${CMAKE_BINARY_DIR}/ruby/ohcount_wrap.c ${CMAKE_SOURCE_DIR}/ruby/ohcount.i
    DEPENDS ${CMAKE_SOURCE_DIR}/ruby/ohcount.i
  )

  INCLUDE_DIRECTORIES(${CMAKE_SOURCE_DIR}/ruby ${RUBY_INCLUDE_DIRS})
  ADD_LIBRARY(ohcount_ruby SHARED ${CMAKE_BINARY_DIR}/ruby/ohcount_wrap.c)
  ADD_DEPENDENCIES(ohcount_ruby libohcount)
  TARGET_LINK_LIBRARIES(ohcount_ruby libohcount ${RUBY_LIBRARY})
  SET_TARGET_PROPERTIES(ohcount_ruby
    PROPERTIES
      OUTPUT_NAME ohcount
      PREFIX ""
      LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/ruby/${arch}
  )

ENDIF(ENABLE_RUBY)

# Modeline for vim: set tw=79 et ts=2:
