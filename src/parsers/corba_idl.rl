// corba_idl.rl written by Guilherme Balena Versiani
// guibv<att>comunip<dott>com<dott>br.

/************************* Required for every parser *************************/
#ifndef OHCOUNT_CORBA_IDL_PARSER_H
#define OHCOUNT_CORBA_IDL_PARSER_H

#include "../parser_macros.h"

// the name of the language
const char *CORBA_IDL_LANG = LANG_CORBA_IDL;

// the languages entities
const char *corba_idl_entities[] = {
  "space", "comment", "string", "number", "preproc",
  "keyword", "identifier", "operator", "any", "cfrg_cxx"
};

// constants associated with the entities
enum {
  CORBA_IDL_SPACE = 0, CORBA_IDL_COMMENT, CORBA_IDL_STRING, CORBA_IDL_NUMBER,
  CORBA_IDL_PREPROC, CORBA_IDL_KEYWORD, CORBA_IDL_IDENTIFIER,
  CORBA_IDL_OPERATOR, CORBA_IDL_ANY, CORBA_IDL_CXX_CODEFRAG
};

/*****************************************************************************/

#include "c.h"

%%{
  machine corba_idl;
  write data;
  include common "common.rl";
  #EMBED(c)

  # Line counting machine

  action corba_idl_ccallback {
    switch(entity) {
    case CORBA_IDL_SPACE:
      ls
      break;
    case CORBA_IDL_ANY:
      code
      break;
    case INTERNAL_NL:
      std_internal_newline(CORBA_IDL_LANG)
      break;
    case NEWLINE:
      std_newline(CORBA_IDL_LANG)
    }
  }

  corba_idl_line_comment =
    '//' @comment (
      escaped_newline %{ entity = INTERNAL_NL; } %corba_idl_ccallback
      |
      ws
      |
      (nonnewline - ws) @comment
    )*;
  corba_idl_block_comment =
    '/*' @comment (
      newline %{ entity = INTERNAL_NL; } %corba_idl_ccallback
      |
      ws
      |
      (nonnewline - ws) @comment
    )* :>> '*/';
  corba_idl_comment = corba_idl_line_comment | corba_idl_block_comment;

  corba_idl_sq_str =
    '\'' @code (
      escaped_newline %{ entity = INTERNAL_NL; } %corba_idl_ccallback
      |
      ws
      |
      [^\t '\\] @code
      |
      '\\' nonnewline @code
    )* '\'';
  corba_idl_dq_str =
    '"' @code (
      escaped_newline %{ entity = INTERNAL_NL; } %corba_idl_ccallback
      |
      ws
      |
      [^\t "\\] @code
      |
      '\\' nonnewline @code
    )* '"';
  corba_idl_string = corba_idl_sq_str | corba_idl_dq_str;

  corba_idl_codefrag_outry = '%}' @code;

  # C++ codefrag (Mozilla XPIDL extension)
  corba_idl_cxx_codefrag_entry = '%{' ( ('C'|'c') '++' )? @code;
  corba_idl_cxx_line := |*
    corba_idl_codefrag_outry @{ p = ts; fret; C_LANG = ORIG_C_LANG; };
    # unmodified C++ patterns
    spaces    ${ entity = C_SPACE; } => c_ccallback;
    c_comment;
    c_string;
    newline   ${ entity = NEWLINE; } => c_ccallback;
    ^space    ${ entity = C_ANY;   } => c_ccallback;
  *|;

  corba_idl_line := |*
    # If you want to include other embedded language in IDL code fragments,
    # just describe that codefrag like below. Don't forget to implement the
    # 'entity' machine (see next section).
    corba_idl_cxx_codefrag_entry
      @{ saw(C_LANG); C_LANG = CPP_LANG; } => { fcall corba_idl_cxx_line; };
    spaces    ${ entity = CORBA_IDL_SPACE; } => corba_idl_ccallback;
    corba_idl_comment;
    corba_idl_string;
    newline   ${ entity = NEWLINE; } => corba_idl_ccallback;
    ^space    ${ entity = CORBA_IDL_ANY;   } => corba_idl_ccallback;
  *|;

  # Entity machine

  action corba_idl_ecallback {
    callback(CORBA_IDL_LANG, corba_idl_entities[entity], cint(ts), cint(te), userdata);
  }

  corba_idl_line_comment_entity = '//' (escaped_newline | nonnewline)*;
  corba_idl_block_comment_entity = '/*' any* :>> '*/';
  corba_idl_comment_entity = corba_idl_line_comment_entity | corba_idl_block_comment_entity;

  corba_idl_string_entity = sq_str_with_escapes | dq_str_with_escapes;

  corba_idl_number_entity = float | integer;

  corba_idl_preproc_word =
    'define' | 'elif' | 'else' | 'endif' | 'error' | 'if' | 'ifdef' |
    'ifndef' | 'import' | 'include' | 'line' | 'pragma' | 'undef' |
    'using' | 'warning';

  # Preprocessor declarations does not need to start at the BOL.
  corba_idl_preproc_entity =
    (space* '#') when starts_line space* (
      corba_idl_block_comment_entity space*
    )?
    corba_idl_preproc_word (escaped_newline | nonnewline)*;

  corba_idl_identifier_entity = (alpha | '_') (alnum | '_')*;

  corba_idl_keyword_entity =
    'any' | 'attribute' | 'boolean' | 'case' | 'char' | 'const' | 'context' |
    'default' | 'double' | 'enum' | 'exception' | 'fixed' | 'float' | 'in' |
    'inout' | 'interface' | 'long' | 'module' | 'native' | 'octet' | 'oneway' |
    'out' | 'raises' | 'readonly' | 'sequence' | 'short' | 'string' | 'struct' |
    'switch' | 'typedef' | 'union' | 'unsigned' | 'void' | 'wchar' | 'wstring' |
    'true' | 'false' | '...';

  corba_idl_operator_entity = [+\-/*%<>!=^&|?~:;.,()\[\]{}];

  corba_idl_codefrag_entity_outry = '%}';

  # C++ codefrag (Mozilla XPIDL extension)
  corba_idl_cxx_codefrag_entity_entry = '%{' ( /C++/i )?;
  corba_idl_cxx_entity := |*
    corba_idl_codefrag_entity_outry ${ entity = CORBA_IDL_CXX_CODEFRAG; }
      @corba_idl_ecallback @{ fret; };
    # unmodified C++ patterns
    space+              ${ entity = C_SPACE;      } => c_ecallback;
    c_comment_entity    ${ entity = C_COMMENT;    } => c_ecallback;
    c_string_entity     ${ entity = C_STRING;     } => c_ecallback;
    c_number_entity     ${ entity = C_NUMBER;     } => c_ecallback;
    c_preproc_entity    ${ entity = C_PREPROC;    } => c_ecallback;
    c_identifier_entity ${ entity = C_IDENTIFIER; } => c_ecallback;
    c_keyword_entity    ${ entity = C_KEYWORD;    } => c_ecallback;
    c_operator_entity   ${ entity = C_OPERATOR;   } => c_ecallback;
    ^(space | digit)    ${ entity = C_ANY;        } => c_ecallback;
  *|;

  corba_idl_entity := |*
    corba_idl_cxx_codefrag_entity_entry { fcall corba_idl_cxx_entity; };
    space+                      ${ entity = CORBA_IDL_SPACE;      } => corba_idl_ecallback;
    corba_idl_comment_entity    ${ entity = CORBA_IDL_COMMENT;    } => corba_idl_ecallback;
    corba_idl_string_entity     ${ entity = CORBA_IDL_STRING;     } => corba_idl_ecallback;
    corba_idl_number_entity     ${ entity = CORBA_IDL_NUMBER;     } => corba_idl_ecallback;
    corba_idl_preproc_entity    ${ entity = CORBA_IDL_PREPROC;    } => corba_idl_ecallback;
    corba_idl_identifier_entity ${ entity = CORBA_IDL_IDENTIFIER; } => corba_idl_ecallback;
    corba_idl_keyword_entity    ${ entity = CORBA_IDL_KEYWORD;    } => corba_idl_ecallback;
    corba_idl_operator_entity   ${ entity = CORBA_IDL_OPERATOR;   } => corba_idl_ecallback;
    ^(space | digit)            ${ entity = CORBA_IDL_ANY;        } => corba_idl_ecallback;
  *|;
}%%

/************************* Required for every parser *************************/

/* Parses a string buffer with Corba IDL code.
 *
 * @param *buffer The string to parse.
 * @param length The length of the string to parse.
 * @param count Integer flag specifying whether or not to count lines. If yes,
 *   uses the Ragel machine optimized for counting. Otherwise uses the Ragel
 *   machine optimized for returning entity positions.
 * @param *callback Callback function. If count is set, callback is called for
 *   every line of code, comment, or blank with 'lcode', 'lcomment', and
 *   'lblank' respectively. Otherwise callback is called for each entity found.
 */
void parse_corba_idl(char *buffer, int length, int count,
             void (*callback) (const char *lang, const char *entity, int s,
                               int e, void *udata),
             void *userdata
  ) {
  init

  %% write init;
  cs = (count) ? corba_idl_en_corba_idl_line : corba_idl_en_corba_idl_entity;
  %% write exec;

  // if no newline at EOF; callback contents of last line
  if (count) { process_last_line(CORBA_IDL_LANG) }
}

#endif

/*****************************************************************************/
