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

# Test suite for complex tests (i.e. command + parameters + expected result):
ENABLE_TESTING()
FILE(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/test)
MACRO(ADD_COMPLEX_TEST _testname _command _workingdir _expected_result)
  FILE(WRITE "${CMAKE_BINARY_DIR}/test/${_testname}.cmake"
"EXECUTE_PROCESS(
  COMMAND ${_command}
  WORKING_DIRECTORY ${_workingdir}
  RESULT_VARIABLE _result
  OUTPUT_VARIABLE _output
  ERROR_VARIABLE  _error
)
IF(NOT _result EQUAL ${_expected_result})
  MESSAGE(SEND_ERROR
\"
Test name: ${_testname}
Result:    \${_result}
Expected:  ${_expected_result}
Output:
\${_output}
Error:
\${_error}
\"
  )
ENDIF(NOT _result EQUAL ${_expected_result})"
  )
  ADD_TEST(${_testname} ${CMAKE_COMMAND} -P "${CMAKE_BINARY_DIR}/test/${_testname}.cmake")
ENDMACRO(ADD_COMPLEX_TEST _testname _command _workingdir _expected_result)

MACRO(ADD_TARGET_TEST _testname _target _workingdir _expected_result)
  GET_TARGET_PROPERTY(_executable ${_target} LOCATION)
  ADD_COMPLEX_TEST("${_testname}" "${_executable}" "${_workingdir}" ${_expected_result})
ENDMACRO(ADD_TARGET_TEST _testname _target _workingdir _expected_result)

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

# Unit test
ADD_EXECUTABLE(ohcount_unittest test/unit/all_tests.c)
ADD_DEPENDENCIES(ohcount_unittest libohcount)
TARGET_LINK_LIBRARIES(ohcount_unittest libohcount)
ADD_TARGET_TEST("UnitTest" ohcount_unittest ${CMAKE_SOURCE_DIR}/test/unit 0)

# Ohcount language bindings
SET(ENABLE_RUBY TRUE CACHE BOOLEAN "Enable ruby binding")
SET(ENABLE_PYTHON FALSE CACHE BOOLEAN "Enable python binding")

IF(ENABLE_RUBY OR ENABLE_PYTHON)

  # Find SWIG executable
  FIND_PACKAGE(SWIG REQUIRED)
  IF(NOT SWIG_FOUND)
    MESSAGE(SEND_ERROR "You need SWIG to build ohcount bindings")
  ENDIF(NOT SWIG_FOUND)

ENDIF(ENABLE_RUBY OR ENABLE_PYTHON)

# Set up Ruby binding
IF(ENABLE_RUBY)

  MESSAGE(STATUS "Enabled Ruby binding")

  # Find Ruby executable
  FIND_PACKAGE(Ruby REQUIRED)
  IF(NOT RUBY_FOUND)
    MESSAGE(SEND_ERROR "You need Ruby to build Ruby binding")
  ENDIF(NOT RUBY_FOUND)

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

# Set up Python binding
IF(ENABLE_PYTHON)

  MESSAGE(STATUS "Enabled Python binding")

  # Find Python executable
  FIND_PACKAGE(PythonLibs REQUIRED)
  IF(NOT PYTHONLIBS_FOUND)
    MESSAGE(SEND_ERROR "You need Python to build Python binding")
  ENDIF(NOT PYTHONLIBS_FOUND)

  FILE(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/python/ohcount)
  FILE(GLOB _python_files "${CMAKE_SOURCE_DIR}/python/*.py")
  FILE(COPY ${_python_files} DESTINATION ${CMAKE_BINARY_DIR}/python/ohcount)

  ADD_CUSTOM_COMMAND(
    OUTPUT ${CMAKE_BINARY_DIR}/python/ohcount_wrap.c
           ${CMAKE_BINARY_DIR}/python/ohcount/ohcount.py
    COMMAND ${SWIG_EXECUTABLE} -python -o ${CMAKE_BINARY_DIR}/python/ohcount_wrap.c ${CMAKE_SOURCE_DIR}/ruby/ohcount.i
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/python/ohcount.py ${CMAKE_BINARY_DIR}/python/ohcount
    COMMAND ${CMAKE_COMMAND} -E remove -f ${CMAKE_BINARY_DIR}/python/ohcount.py
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/python/ohcount
    DEPENDS ${CMAKE_SOURCE_DIR}/ruby/ohcount.i
  )

  INCLUDE_DIRECTORIES(${CMAKE_SOURCE_DIR}/python ${PYTHON_INCLUDE_DIRS})
  ADD_LIBRARY(ohcount_python SHARED ${CMAKE_BINARY_DIR}/python/ohcount_wrap.c)
  ADD_DEPENDENCIES(ohcount_python libohcount)
  TARGET_LINK_LIBRARIES(ohcount_python ${PYTHON_LIBRARIES} libohcount)
  SET_TARGET_PROPERTIES(ohcount_python
    PROPERTIES
      OUTPUT_NAME _ohcount
      PREFIX ""
      LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/python/ohcount
  )

ENDIF(ENABLE_PYTHON)

# Modeline for vim: set tw=79 et ts=2:
