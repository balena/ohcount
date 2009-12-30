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
FILE(GLOB _test_files DESTINATION "test/*")
FILE(COPY ${_test_files} DESTINATION ${CMAKE_BINARY_DIR}/test)
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
FILE(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/hash)
FILE(GLOB _gperf_files "src/hash/*.gperf")
FOREACH(_hsrc ${_gperf_files})
  GET_FILENAME_COMPONENT(_hsrc ${_hsrc} NAME)
  IF(_hsrc STREQUAL "languages.gperf")
    STRING(REPLACE "s.gperf" "_hash.c" _hh ${_hsrc})
  ELSE(_hsrc STREQUAL "languages.gperf")
    STRING(REPLACE "s.gperf" "_hash.h" _hh ${_hsrc})
  ENDIF(_hsrc STREQUAL "languages.gperf")
  LIST(APPEND _gperf_srcs ${CMAKE_BINARY_DIR}/hash/${_hh})
ENDFOREACH(_hsrc)
ADD_CUSTOM_COMMAND(
  OUTPUT ${_gperf_srcs} ${CMAKE_BINARY_DIR}/hash/language_hash.c
  COMMAND cp ${CMAKE_SOURCE_DIR}/src/hash/* ${CMAKE_BINARY_DIR}/hash
  COMMAND ${BASH_EXECUTABLE} ./generate_headers
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/hash
  DEPENDS ${_gperf_files} ${CMAKE_SOURCE_DIR}/src/hash/generate_headers
)
ADD_CUSTOM_TARGET(ohcount_gperf_files
  DEPENDS ${_gperf_srcs} ${CMAKE_BINARY_DIR}/hash/language_hash.c
  SOURCES ${_gperf_files} ${CMAKE_SOURCE_DIR}/src/hash/generate_headers
)
LIST(APPEND _additional_clean_files ${CMAKE_BINARY_DIR}/hash/*)
SET_SOURCE_FILES_PROPERTIES(${_gperf_srcs} PROPERTIES GENERATED TRUE)

# Ragel input files:
FILE(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/parsers)
FILE(GLOB _ragel_files "src/parsers/*.rl")
FOREACH(_parser ${_ragel_files})
  GET_FILENAME_COMPONENT(_name ${_parser} NAME_WE)
  LIST(APPEND _ragel_srcs ${CMAKE_BINARY_DIR}/parsers/${_name}.h)
ENDFOREACH(_parser)
ADD_CUSTOM_COMMAND(
  OUTPUT ${_ragel_srcs}
  COMMAND cp ${CMAKE_SOURCE_DIR}/src/parsers/* ${CMAKE_BINARY_DIR}/parsers
  COMMAND ${BASH_EXECUTABLE} ./compile
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/parsers
  DEPENDS ${_ragel_files} ${CMAKE_SOURCE_DIR}/src/parsers/compile
)
ADD_CUSTOM_TARGET(ohcount_ragel_files
  DEPENDS ${_ragel_srcs}
  SOURCES ${_ragel_files} ${CMAKE_SOURCE_DIR}/src/parsers/compile
)
LIST(APPEND _additional_clean_files ${CMAKE_BINARY_DIR}/parsers/*)
SET_SOURCE_FILES_PROPERTIES(${_ragel_srcs} PROPERTIES GENERATED TRUE)

# Ohcount static library
INCLUDE_DIRECTORIES(
  ${CMAKE_SOURCE_DIR}/src
  ${CMAKE_SOURCE_DIR}/src/parsers
  ${CMAKE_BINARY_DIR}
)
ADD_LIBRARY(libohcount STATIC
  ${_gperf_srcs}
  ${_ragel_srcs}
  src/sourcefile.c
  src/detector.c
  src/licenses.c
  src/parser.c
  src/loc.c
  src/log.c
  src/diff.c
  src/parsed_language.c
)
ADD_DEPENDENCIES(libohcount ohcount_gperf_files ohcount_ragel_files)
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
ADD_TARGET_TEST(UnitTest ohcount_unittest ${CMAKE_BINARY_DIR}/test/unit 0)

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
  FILE(COPY ${CMAKE_SOURCE_DIR}/ruby/print_arch DESTINATION ${CMAKE_BINARY_DIR}/ruby)
  SET(_ruby_files
    "${CMAKE_SOURCE_DIR}/ruby/ohcount.rb"
    "${CMAKE_SOURCE_DIR}/ruby/gestalt.rb"
    "${CMAKE_SOURCE_DIR}/ruby/gestalt"
  )
  FILE(COPY ${_ruby_files} DESTINATION ${CMAKE_BINARY_DIR}/ruby)

  ADD_CUSTOM_COMMAND(
    OUTPUT ${CMAKE_BINARY_DIR}/ruby/ohcount_wrap.c
    COMMAND ${SWIG_EXECUTABLE} -ruby
            -o ${CMAKE_BINARY_DIR}/ruby/ohcount_wrap.c
            ${CMAKE_SOURCE_DIR}/ruby/ohcount.i
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
      LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/ruby/${RUBY_ARCH}
  )
  LIST(APPEND _additional_clean_files "${CMAKE_BINARY_DIR}/ruby/ohcount_wrap.c")
  ADD_COMPLEX_TEST(RubyTest
    "${RUBY_EXECUTABLE} ruby_test.rb"
    ${CMAKE_BINARY_DIR}/test/unit/ruby 0
  )

ENDIF(ENABLE_RUBY)

# Set up Python binding
IF(ENABLE_PYTHON)

  MESSAGE(STATUS "Enabled Python binding")

  # Find Python executable
  FIND_PACKAGE(PythonLibs REQUIRED)
  FIND_PROGRAM(PYTHON_EXECUTABLE python)
  IF(NOT PYTHONLIBS_FOUND OR NOT PYTHON_EXECUTABLE)
    MESSAGE(SEND_ERROR "You need Python to build Python binding")
  ENDIF(NOT PYTHONLIBS_FOUND OR NOT PYTHON_EXECUTABLE)

  FILE(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/python/ohcount)
  FILE(GLOB _python_files "python/*.py")
  FILE(COPY ${_python_files} DESTINATION ${CMAKE_BINARY_DIR}/python/ohcount)

  ADD_CUSTOM_COMMAND(
    OUTPUT ${CMAKE_BINARY_DIR}/python/ohcount_wrap.c
           ${CMAKE_BINARY_DIR}/python/ohcount/ohcount.py
    COMMAND ${SWIG_EXECUTABLE} -python
            -o ${CMAKE_BINARY_DIR}/python/ohcount_wrap.c
            ${CMAKE_SOURCE_DIR}/ruby/ohcount.i
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_BINARY_DIR}/python/ohcount.py
            ${CMAKE_BINARY_DIR}/python/ohcount
    COMMAND ${CMAKE_COMMAND} -E remove -f
            ${CMAKE_BINARY_DIR}/python/ohcount.py
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
  LIST(APPEND _additional_clean_files
    "${CMAKE_BINARY_DIR}/python/ohcount_wrap.c"
    "${CMAKE_BINARY_DIR}/python/ohcount/ohcount.py"
  )
  ADD_TEST(PythonTest ${CMAKE_COMMAND} -E chdir
    "${CMAKE_BINARY_DIR}/test/unit/python"
    "${PYTHON_EXECUTABLE}" "python_test.py"
  )
  SET_TESTS_PROPERTIES(PythonTest PROPERTIES
    ENVIRONMENT "PYTHONPATH=../../../python"
  )

ENDIF(ENABLE_PYTHON)

# Extra clean files:
SET_DIRECTORY_PROPERTIES(
  PROPERTIES ADDITIONAL_MAKE_CLEAN_FILES "${_additional_clean_files}"
)

# Modeline for vim: set tw=79 et ts=2:
