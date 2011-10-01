/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * 
 * The C Interface to Clang provides a relatively small API that exposes
 * facilities for parsing source code into an abstract syntax tree (AST),
 * loading already-parsed ASTs, traversing the AST, associating
 * physical source locations with elements within the AST, and other
 * facilities that support Clang-based development tools.
 *
 * This C interface to Clang will never provide all of the information
 * representation stored in Clang's C++ AST, nor should it: the intent is to
 * maintain an API that is relatively stable from one release to the next,
 * providing only the basic functionality needed to support development tools.
 *
 * To avoid namespace pollution, data types are prefixed with "CX" and
 * functions are prefixed with "clang_".
 */
module clang.c.index;

extern (C):

enum bool hasBlocks = false;

/**
 * An "index" that consists of a set of translation units that would
 * typically be linked together into an executable or library.
 */
alias void* CXIndex;

///
struct CXTranslationUnitImpl;

/**
 * A single translation unit, which resides in an index.
 */
alias CXTranslationUnitImpl* CXTranslationUnit;

/**
 * Opaque pointer representing client data that will be passed through
 * to various callbacks and visitors.
 */
alias void* CXClientData;

/**
 * Provides the contents of a file that has not yet been saved to disk.
 *
 * Each CXUnsavedFile instance provides the name of a file on the
 * system along with the current contents of that file that have not
 * yet been saved to disk.
 */
struct CXUnsavedFile {
  /**
   * The file whose contents have not yet been saved.
   *
   * This file must already exist in the file system.
   */
  const char* Filename;

  /**
   * A buffer containing the unsaved contents of this file.
   */
  const char* Contents;

  /**
   * The length of the unsaved contents of this buffer.
   */
  c_ulong Length;
}

/**
 * Describes the availability of a particular entity, which indicates
 * whether the use of this entity will result in a warning or error due to
 * it being deprecated or unavailable.
 */
enum CXAvailabilityKind {
  /**
   * The entity is available.
   */
  CXAvailability_Available,
  /**
   * The entity is available, but has been deprecated (and its use is
   * not recommended).
   */
  CXAvailability_Deprecated,
  /**
   * The entity is not available; any use of it will be an error.
   */
  CXAvailability_NotAvailable
}
  
/**
 * \defgroup CINDEX_STRING String manipulation routines
 *
 * @{
 */

/**
 * A character string.
 *
 * The \c CXString type is used to return strings from the interface when
 * the ownership of that string might different from one call to the next.
 * Use \c clang_getCString() to retrieve the string data and, once finished
 * with the string data, call \c clang_disposeString() to free the string.
 */
struct CXString {
  void* data;
  uint private_flags;
}

/**
 * Retrieve the character data associated with the given string.
 */
const char* clang_getCString(CXString string);

/**
 * Free the given string,
 */
void clang_disposeString(CXString string);

/**
 * @}
 */

/**
 * clang_createIndex() provides a shared context for creating
 * translation units. It provides two options:
 *
 * - excludeDeclarationsFromPCH: When non-zero, allows enumeration of "local"
 * declarations (when loading any new translation units). A "local" declaration
 * is one that belongs in the translation unit itself and not in a precompiled
 * header that was used by the translation unit. If zero, all declarations
 * will be enumerated.
 *
 * Here is an example:
 *
 *   // excludeDeclsFromPCH = 1, displayDiagnostics=1
 *   Idx = clang_createIndex(1, 1);
 *
 *   // IndexTest.pch was produced with the following command:
 *   // "clang -x c IndexTest.h -emit-ast -o IndexTest.pch"
 *   TU = clang_createTranslationUnit(Idx, "IndexTest.pch");
 *
 *   // This will load all the symbols from 'IndexTest.pch'
 *   clang_visitChildren(clang_getTranslationUnitCursor(TU),
 *                       TranslationUnitVisitor, 0);
 *   clang_disposeTranslationUnit(TU);
 *
 *   // This will load all the symbols from 'IndexTest.c', excluding symbols
 *   // from 'IndexTest.pch'.
 *   char* args[] = { "-Xclang", "-include-pch=IndexTest.pch" }
 *   TU = clang_createTranslationUnitFromSourceFile(Idx, "IndexTest.c", 2, args,
 *                                                  0, 0);
 *   clang_visitChildren(clang_getTranslationUnitCursor(TU),
 *                       TranslationUnitVisitor, 0);
 *   clang_disposeTranslationUnit(TU);
 *
 * This process of creating the 'pch', loading it separately, and using it (via
 * -include-pch) allows 'excludeDeclsFromPCH' to remove redundant callbacks
 * (which gives the indexer the same performance benefit as the compiler).
 */
CXIndex clang_createIndex(int excludeDeclarationsFromPCH,
                                         int displayDiagnostics);

/**
 * Destroy the given index.
 *
 * The index must not be destroyed until all of the translation units created
 * within that index have been destroyed.
 */
void clang_disposeIndex(CXIndex index);

/**
 * \defgroup CINDEX_FILES File manipulation routines
 *
 * @{
 */

/**
 * A particular source file that is part of a translation unit.
 */
alias void* CXFile;


/**
 * Retrieve the complete file and path name of the given file.
 */
CXString clang_getFileName(CXFile SFile);

/**
 * Retrieve the last modification time of the given file.
 */
time_t clang_getFileTime(CXFile SFile);

/**
 * Determine whether the given header is guarded against
 * multiple inclusions, either with the conventional
 * #ifndef/#define/#endif macro guards or with #pragma once.
 */
uint 
clang_isFileMultipleIncludeGuarded(CXTranslationUnit tu, CXFile file);

/**
 * Retrieve a file handle within the given translation unit.
 *
 * \param tu the translation unit
 *
 * \param file_name the name of the file.
 *
 * \returns the file handle for the named file in the translation unit \p tu,
 * or a NULL file handle if the file was not a part of this translation unit.
 */
CXFile clang_getFile(CXTranslationUnit tu,
                                    const char* file_name);

/**
 * @}
 */

/**
 * \defgroup CINDEX_LOCATIONS Physical source locations
 *
 * Clang represents physical source locations in its abstract syntax tree in
 * great detail, with file, line, and column information for the majority of
 * the tokens parsed in the source code. These data types and functions are
 * used to represent source location information, either for a particular
 * point in the program or for a range of points in the program, and extract
 * specific location information from those data types.
 *
 * @{
 */

/**
 * Identifies a specific source location within a translation
 * unit.
 *
 * Use clang_getExpansionLocation() or clang_getSpellingLocation()
 * to map a source location to a particular file, line, and column.
 */
struct CXSourceLocation {
  void* ptr_data[2];
  uint int_data;
}

/**
 * Identifies a half-open character range in the source code.
 *
 * Use clang_getRangeStart() and clang_getRangeEnd() to retrieve the
 * starting and end locations from a source range, respectively.
 */
struct CXSourceRange {
  void* ptr_data[2];
  uint begin_int_data;
  uint end_int_data;
}

/**
 * Retrieve a NULL (invalid) source location.
 */
CXSourceLocation clang_getNullLocation();

/**
 * \determine Determine whether two source locations, which must refer into
 * the same translation unit, refer to exactly the same point in the source
 * code.
 *
 * \returns non-zero if the source locations refer to the same location, zero
 * if they refer to different locations.
 */
uint clang_equalLocations(CXSourceLocation loc1,
                                             CXSourceLocation loc2);

/**
 * Retrieves the source location associated with a given file/line/column
 * in a particular translation unit.
 */
CXSourceLocation clang_getLocation(CXTranslationUnit tu,
                                                  CXFile file,
                                                  uint line,
                                                  uint column);
/**
 * Retrieves the source location associated with a given character offset
 * in a particular translation unit.
 */
CXSourceLocation clang_getLocationForOffset(CXTranslationUnit tu,
                                                           CXFile file,
                                                           uint offset);

/**
 * Retrieve a NULL (invalid) source range.
 */
CXSourceRange clang_getNullRange();

/**
 * Retrieve a source range given the beginning and ending source
 * locations.
 */
CXSourceRange clang_getRange(CXSourceLocation begin,
                                            CXSourceLocation end);

/**
 * Determine whether two ranges are equivalent.
 *
 * \returns non-zero if the ranges are the same, zero if they differ.
 */
uint clang_equalRanges(CXSourceRange range1,
                                          CXSourceRange range2);

/**
 * Returns non-zero if \arg range is null.
 */
int clang_Range_isNull(CXSourceRange range);

/**
 * Retrieve the file, line, column, and offset represented by
 * the given source location.
 *
 * If the location refers into a macro expansion, retrieves the
 * location of the macro expansion.
 *
 * \param location the location within a source file that will be decomposed
 * into its parts.
 *
 * \param file [out] if non-NULL, will be set to the file to which the given
 * source location points.
 *
 * \param line [out] if non-NULL, will be set to the line to which the given
 * source location points.
 *
 * \param column [out] if non-NULL, will be set to the column to which the given
 * source location points.
 *
 * \param offset [out] if non-NULL, will be set to the offset into the
 * buffer to which the given source location points.
 */
void clang_getExpansionLocation(CXSourceLocation location,
                                               CXFile* file,
                                               uint* line,
                                               uint* column,
                                               uint* offset);

/**
 * Retrieve the file, line, column, and offset represented by
 * the given source location, as specified in a # line directive.
 *
 * Example: given the following source code in a file somefile.c
 *
 * #123 "dummy.c" 1
 *
 * static int func(void)
 * {
 *     return 0;
 * }
 *
 * the location information returned by this function would be
 *
 * File: dummy.c Line: 124 Column: 12
 *
 * whereas clang_getExpansionLocation would have returned
 *
 * File: somefile.c Line: 3 Column: 12
 *
 * \param location the location within a source file that will be decomposed
 * into its parts.
 *
 * \param filename [out] if non-NULL, will be set to the filename of the
 * source location. Note that filenames returned will be for "virtual" files,
 * which don't necessarily exist on the machine running clang - e.g. when
 * parsing preprocessed output obtained from a different environment. If
 * a non-NULL value is passed in, remember to dispose of the returned value
 * using \c clang_disposeString() once you've finished with it. For an invalid
 * source location, an empty string is returned.
 *
 * \param line [out] if non-NULL, will be set to the line number of the
 * source location. For an invalid source location, zero is returned.
 *
 * \param column [out] if non-NULL, will be set to the column number of the
 * source location. For an invalid source location, zero is returned.
 */
void clang_getPresumedLocation(CXSourceLocation location,
                                              CXString* filename,
                                              uint* line,
                                              uint* column);

/**
 * Legacy API to retrieve the file, line, column, and offset represented
 * by the given source location.
 *
 * This interface has been replaced by the newer interface
 * \see clang_getExpansionLocation(). See that interface's documentation for
 * details.
 */
void clang_getInstantiationLocation(CXSourceLocation location,
                                                   CXFile* file,
                                                   uint* line,
                                                   uint* column,
                                                   uint* offset);

/**
 * Retrieve the file, line, column, and offset represented by
 * the given source location.
 *
 * If the location refers into a macro instantiation, return where the
 * location was originally spelled in the source file.
 *
 * \param location the location within a source file that will be decomposed
 * into its parts.
 *
 * \param file [out] if non-NULL, will be set to the file to which the given
 * source location points.
 *
 * \param line [out] if non-NULL, will be set to the line to which the given
 * source location points.
 *
 * \param column [out] if non-NULL, will be set to the column to which the given
 * source location points.
 *
 * \param offset [out] if non-NULL, will be set to the offset into the
 * buffer to which the given source location points.
 */
void clang_getSpellingLocation(CXSourceLocation location,
                                              CXFile* file,
                                              uint* line,
                                              uint* column,
                                              uint* offset);

/**
 * Retrieve a source location representing the first character within a
 * source range.
 */
CXSourceLocation clang_getRangeStart(CXSourceRange range);

/**
 * Retrieve a source location representing the last character within a
 * source range.
 */
CXSourceLocation clang_getRangeEnd(CXSourceRange range);

/**
 * @}
 */

/**
 * \defgroup CINDEX_DIAG Diagnostic reporting
 *
 * @{
 */

/**
 * Describes the severity of a particular diagnostic.
 */
enum CXDiagnosticSeverity {
  /**
   * A diagnostic that has been suppressed, e.g., by a command-line
   * option.
   */
  CXDiagnostic_Ignored = 0,

  /**
   * This diagnostic is a note that should be attached to the
   * previous (non-note) diagnostic.
   */
  CXDiagnostic_Note    = 1,

  /**
   * This diagnostic indicates suspicious code that may not be
   * wrong.
   */
  CXDiagnostic_Warning = 2,

  /**
   * This diagnostic indicates that the code is ill-formed.
   */
  CXDiagnostic_Error   = 3,

  /**
   * This diagnostic indicates that the code is ill-formed such
   * that future parser recovery is unlikely to produce useful
   * results.
   */
  CXDiagnostic_Fatal   = 4
}

/**
 * A single diagnostic, containing the diagnostic's severity,
 * location, text, source ranges, and fix-it hints.
 */
alias void* CXDiagnostic;

/**
 * Determine the number of diagnostics produced for the given
 * translation unit.
 */
uint clang_getNumDiagnostics(CXTranslationUnit Unit);

/**
 * Retrieve a diagnostic associated with the given translation unit.
 *
 * \param Unit the translation unit to query.
 * \param Index the zero-based diagnostic number to retrieve.
 *
 * \returns the requested diagnostic. This diagnostic must be freed
 * via a call to \c clang_disposeDiagnostic().
 */
CXDiagnostic clang_getDiagnostic(CXTranslationUnit Unit,
                                                uint Index);

/**
 * Destroy a diagnostic.
 */
void clang_disposeDiagnostic(CXDiagnostic Diagnostic);

/**
 * Options to control the display of diagnostics.
 *
 * The values in this enum are meant to be combined to customize the
 * behavior of \c clang_displayDiagnostic().
 */
enum CXDiagnosticDisplayOptions {
  /**
   * Display the source-location information where the
   * diagnostic was located.
   *
   * When set, diagnostics will be prefixed by the file, line, and
   * (optionally) column to which the diagnostic refers. For example,
   *
   * \code
   * test.c:28: warning: extra tokens at end of #endif directive
   * \endcode
   *
   * This option corresponds to the clang flag \c -fshow-source-location.
   */
  CXDiagnostic_DisplaySourceLocation = 0x01,

  /**
   * If displaying the source-location information of the
   * diagnostic, also include the column number.
   *
   * This option corresponds to the clang flag \c -fshow-column.
   */
  CXDiagnostic_DisplayColumn = 0x02,

  /**
   * If displaying the source-location information of the
   * diagnostic, also include information about source ranges in a
   * machine-parsable format.
   *
   * This option corresponds to the clang flag
   * \c -fdiagnostics-print-source-range-info.
   */
  CXDiagnostic_DisplaySourceRanges = 0x04,
  
  /**
   * Display the option name associated with this diagnostic, if any.
   *
   * The option name displayed (e.g., -Wconversion) will be placed in brackets
   * after the diagnostic text. This option corresponds to the clang flag
   * \c -fdiagnostics-show-option.
   */
  CXDiagnostic_DisplayOption = 0x08,
  
  /**
   * Display the category number associated with this diagnostic, if any.
   *
   * The category number is displayed within brackets after the diagnostic text.
   * This option corresponds to the clang flag 
   * \c -fdiagnostics-show-category=id.
   */
  CXDiagnostic_DisplayCategoryId = 0x10,

  /**
   * Display the category name associated with this diagnostic, if any.
   *
   * The category name is displayed within brackets after the diagnostic text.
   * This option corresponds to the clang flag 
   * \c -fdiagnostics-show-category=name.
   */
  CXDiagnostic_DisplayCategoryName = 0x20
}

/**
 * Format the given diagnostic in a manner that is suitable for display.
 *
 * This routine will format the given diagnostic to a string, rendering
 * the diagnostic according to the various options given. The
 * \c clang_defaultDiagnosticDisplayOptions() function returns the set of
 * options that most closely mimics the behavior of the clang compiler.
 *
 * \param Diagnostic The diagnostic to print.
 *
 * \param Options A set of options that control the diagnostic display,
 * created by combining \c CXDiagnosticDisplayOptions values.
 *
 * \returns A new string containing for formatted diagnostic.
 */
CXString clang_formatDiagnostic(CXDiagnostic Diagnostic,
                                               uint Options);

/**
 * Retrieve the set of display options most similar to the
 * default behavior of the clang compiler.
 *
 * \returns A set of display options suitable for use with \c
 * clang_displayDiagnostic().
 */
uint clang_defaultDiagnosticDisplayOptions(void);

/**
 * Determine the severity of the given diagnostic.
 */
enum CXDiagnosticSeverity
clang_getDiagnosticSeverity(CXDiagnostic);

/**
 * Retrieve the source location of the given diagnostic.
 *
 * This location is where Clang would print the caret ('^') when
 * displaying the diagnostic on the command line.
 */
CXSourceLocation clang_getDiagnosticLocation(CXDiagnostic);

/**
 * Retrieve the text of the given diagnostic.
 */
CXString clang_getDiagnosticSpelling(CXDiagnostic);

/**
 * Retrieve the name of the command-line option that enabled this
 * diagnostic.
 *
 * \param Diag The diagnostic to be queried.
 *
 * \param Disable If non-NULL, will be set to the option that disables this
 * diagnostic (if any).
 *
 * \returns A string that contains the command-line option used to enable this
 * warning, such as "-Wconversion" or "-pedantic". 
 */
CXString clang_getDiagnosticOption(CXDiagnostic Diag,
                                                  CXString* Disable);

/**
 * Retrieve the category number for this diagnostic.
 *
 * Diagnostics can be categorized into groups along with other, related
 * diagnostics (e.g., diagnostics under the same warning flag). This routine 
 * retrieves the category number for the given diagnostic.
 *
 * \returns The number of the category that contains this diagnostic, or zero
 * if this diagnostic is uncategorized.
 */
uint clang_getDiagnosticCategory(CXDiagnostic);

/**
 * Retrieve the name of a particular diagnostic category.
 *
 * \param Category A diagnostic category number, as returned by 
 * \c clang_getDiagnosticCategory().
 *
 * \returns The name of the given diagnostic category.
 */
CXString clang_getDiagnosticCategoryName(uint Category);
  
/**
 * Determine the number of source ranges associated with the given
 * diagnostic.
 */
uint clang_getDiagnosticNumRanges(CXDiagnostic);

/**
 * Retrieve a source range associated with the diagnostic.
 *
 * A diagnostic's source ranges highlight important elements in the source
 * code. On the command line, Clang displays source ranges by
 * underlining them with '~' characters.
 *
 * \param Diagnostic the diagnostic whose range is being extracted.
 *
 * \param Range the zero-based index specifying which range to
 *
 * \returns the requested source range.
 */
CXSourceRange clang_getDiagnosticRange(CXDiagnostic Diagnostic,
                                                      uint Range);

/**
 * Determine the number of fix-it hints associated with the
 * given diagnostic.
 */
uint clang_getDiagnosticNumFixIts(CXDiagnostic Diagnostic);

/**
 * Retrieve the replacement information for a given fix-it.
 *
 * Fix-its are described in terms of a source range whose contents
 * should be replaced by a string. This approach generalizes over
 * three kinds of operations: removal of source code (the range covers
 * the code to be removed and the replacement string is empty),
 * replacement of source code (the range covers the code to be
 * replaced and the replacement string provides the new code), and
 * insertion (both the start and end of the range point at the
 * insertion location, and the replacement string provides the text to
 * insert).
 *
 * \param Diagnostic The diagnostic whose fix-its are being queried.
 *
 * \param FixIt The zero-based index of the fix-it.
 *
 * \param ReplacementRange The source range whose contents will be
 * replaced with the returned replacement string. Note that source
 * ranges are half-open ranges [a, b), so the source code should be
 * replaced from a and up to (but not including) b.
 *
 * \returns A string containing text that should be replace the source
 * code indicated by the \c ReplacementRange.
 */
CXString clang_getDiagnosticFixIt(CXDiagnostic Diagnostic,
                                                 uint FixIt,
                                               CXSourceRange* ReplacementRange);

/**
 * @}
 */

/**
 * \defgroup CINDEX_TRANSLATION_UNIT Translation unit manipulation
 *
 * The routines in this group provide the ability to create and destroy
 * translation units from files, either by parsing the contents of the files or
 * by reading in a serialized representation of a translation unit.
 *
 * @{
 */

/**
 * Get the original translation unit source file name.
 */
CXString
clang_getTranslationUnitSpelling(CXTranslationUnit CTUnit);

/**
 * Return the CXTranslationUnit for a given source file and the provided
 * command line arguments one would pass to the compiler.
 *
 * Note: The 'source_filename' argument is optional.  If the caller provides a
 * NULL pointer, the name of the source file is expected to reside in the
 * specified command line arguments.
 *
 * Note: When encountered in 'clang_command_line_args', the following options
 * are ignored:
 *
 *   '-c'
 *   '-emit-ast'
 *   '-fsyntax-only'
 *   '-o <output file>'  (both '-o' and '<output file>' are ignored)
 *
 * \param CIdx The index object with which the translation unit will be
 * associated.
 *
 * \param source_filename - The name of the source file to load, or NULL if the
 * source file is included in \p clang_command_line_args.
 *
 * \param num_clang_command_line_args The number of command-line arguments in
 * \p clang_command_line_args.
 *
 * \param clang_command_line_args The command-line arguments that would be
 * passed to the \c clang executable if it were being invoked out-of-process.
 * These command-line options will be parsed and will affect how the translation
 * unit is parsed. Note that the following options are ignored: '-c',
 * '-emit-ast', '-fsyntex-only' (which is the default), and '-o <output file>'.
 *
 * \param num_unsaved_files the number of unsaved file entries in \p
 * unsaved_files.
 *
 * \param unsaved_files the files that have not yet been saved to disk
 * but may be required for code completion, including the contents of
 * those files.  The contents and name of these files (as specified by
 * CXUnsavedFile) are copied when necessary, so the client only needs to
 * guarantee their validity until the call to this function returns.
 */
CXTranslationUnit clang_createTranslationUnitFromSourceFile(
                                         CXIndex CIdx,
                                         const char* source_filename,
                                         int num_clang_command_line_args,
                                   const char * const* clang_command_line_args,
                                         uint num_unsaved_files,
                                         CXUnsavedFile* unsaved_files);

/**
 * Create a translation unit from an AST file (-emit-ast).
 */
CXTranslationUnit clang_createTranslationUnit(CXIndex,
                                             const char* ast_filename);

/**
 * Flags that control the creation of translation units.
 *
 * The enumerators in this enumeration type are meant to be bitwise
 * ORed together to specify which options should be used when
 * constructing the translation unit.
 */
enum CXTranslationUnit_Flags {
  /**
   * Used to indicate that no special translation-unit options are
   * needed.
   */
  CXTranslationUnit_None = 0x0,

  /**
   * Used to indicate that the parser should construct a "detailed"
   * preprocessing record, including all macro definitions and instantiations.
   *
   * Constructing a detailed preprocessing record requires more memory
   * and time to parse, since the information contained in the record
   * is usually not retained. However, it can be useful for
   * applications that require more detailed information about the
   * behavior of the preprocessor.
   */
  CXTranslationUnit_DetailedPreprocessingRecord = 0x01,

  /**
   * Used to indicate that the translation unit is incomplete.
   *
   * When a translation unit is considered "incomplete", semantic
   * analysis that is typically performed at the end of the
   * translation unit will be suppressed. For example, this suppresses
   * the completion of tentative declarations in C and of
   * instantiation of implicitly-instantiation function templates in
   * C++. This option is typically used when parsing a header with the
   * intent of producing a precompiled header.
   */
  CXTranslationUnit_Incomplete = 0x02,
  
  /**
   * Used to indicate that the translation unit should be built with an 
   * implicit precompiled header for the preamble.
   *
   * An implicit precompiled header is used as an optimization when a
   * particular translation unit is likely to be reparsed many times
   * when the sources aren't changing that often. In this case, an
   * implicit precompiled header will be built containing all of the
   * initial includes at the top of the main file (what we refer to as
   * the "preamble" of the file). In subsequent parses, if the
   * preamble or the files in it have not changed, \c
   * clang_reparseTranslationUnit() will re-use the implicit
   * precompiled header to improve parsing performance.
   */
  CXTranslationUnit_PrecompiledPreamble = 0x04,
  
  /**
   * Used to indicate that the translation unit should cache some
   * code-completion results with each reparse of the source file.
   *
   * Caching of code-completion results is a performance optimization that
   * introduces some overhead to reparsing but improves the performance of
   * code-completion operations.
   */
  CXTranslationUnit_CacheCompletionResults = 0x08,
  /**
   * DEPRECATED: Enable precompiled preambles in C++.
   *
   * Note: this is a* temporary* option that is available only while
   * we are testing C++ precompiled preamble support. It is deprecated.
   */
  CXTranslationUnit_CXXPrecompiledPreamble = 0x10,

  /**
   * DEPRECATED: Enabled chained precompiled preambles in C++.
   *
   * Note: this is a* temporary* option that is available only while
   * we are testing C++ precompiled preamble support. It is deprecated.
   */
  CXTranslationUnit_CXXChainedPCH = 0x20,
  
  /**
   * Used to indicate that the "detailed" preprocessing record,
   * if requested, should also contain nested macro expansions.
   *
   * Nested macro expansions (i.e., macro expansions that occur
   * inside another macro expansion) can, in some code bases, require
   * a large amount of storage to due preprocessor metaprogramming. Moreover,
   * its fairly rare that this information is useful for libclang clients.
   */
  CXTranslationUnit_NestedMacroExpansions = 0x40,

  /**
   * Legacy name to indicate that the "detailed" preprocessing record,
   * if requested, should contain nested macro expansions.
   *
   * \see CXTranslationUnit_NestedMacroExpansions for the current name for this
   * value, and its semantics. This is just an alias.
   */
  CXTranslationUnit_NestedMacroInstantiations =
    CXTranslationUnit_NestedMacroExpansions
}

/**
 * Returns the set of flags that is suitable for parsing a translation
 * unit that is being edited.
 *
 * The set of flags returned provide options for \c clang_parseTranslationUnit()
 * to indicate that the translation unit is likely to be reparsed many times,
 * either explicitly (via \c clang_reparseTranslationUnit()) or implicitly
 * (e.g., by code completion (\c clang_codeCompletionAt())). The returned flag
 * set contains an unspecified set of optimizations (e.g., the precompiled 
 * preamble) geared toward improving the performance of these routines. The
 * set of optimizations enabled may change from one version to the next.
 */
uint clang_defaultEditingTranslationUnitOptions(void);
  
/**
 * Parse the given source file and the translation unit corresponding
 * to that file.
 *
 * This routine is the main entry point for the Clang C API, providing the
 * ability to parse a source file into a translation unit that can then be
 * queried by other functions in the API. This routine accepts a set of
 * command-line arguments so that the compilation can be configured in the same
 * way that the compiler is configured on the command line.
 *
 * \param CIdx The index object with which the translation unit will be 
 * associated.
 *
 * \param source_filename The name of the source file to load, or NULL if the
 * source file is included in \p command_line_args.
 *
 * \param command_line_args The command-line arguments that would be
 * passed to the \c clang executable if it were being invoked out-of-process.
 * These command-line options will be parsed and will affect how the translation
 * unit is parsed. Note that the following options are ignored: '-c', 
 * '-emit-ast', '-fsyntex-only' (which is the default), and '-o <output file>'.
 *
 * \param num_command_line_args The number of command-line arguments in
 * \p command_line_args.
 *
 * \param unsaved_files the files that have not yet been saved to disk
 * but may be required for parsing, including the contents of
 * those files.  The contents and name of these files (as specified by
 * CXUnsavedFile) are copied when necessary, so the client only needs to
 * guarantee their validity until the call to this function returns.
 *
 * \param num_unsaved_files the number of unsaved file entries in \p
 * unsaved_files.
 *
 * \param options A bitmask of options that affects how the translation unit
 * is managed but not its compilation. This should be a bitwise OR of the
 * CXTranslationUnit_XXX flags.
 *
 * \returns A new translation unit describing the parsed code and containing
 * any diagnostics produced by the compiler. If there is a failure from which
 * the compiler cannot recover, returns NULL.
 */
CXTranslationUnit clang_parseTranslationUnit(CXIndex CIdx,
                                                    const char* source_filename,
                                         const char * const* command_line_args,
                                                      int num_command_line_args,
                                            CXUnsavedFile* unsaved_files,
                                                     uint num_unsaved_files,
                                                            uint options);
  
/**
 * Flags that control how translation units are saved.
 *
 * The enumerators in this enumeration type are meant to be bitwise
 * ORed together to specify which options should be used when
 * saving the translation unit.
 */
enum CXSaveTranslationUnit_Flags {
  /**
   * Used to indicate that no special saving options are needed.
   */
  CXSaveTranslationUnit_None = 0x0
}

/**
 * Returns the set of flags that is suitable for saving a translation
 * unit.
 *
 * The set of flags returned provide options for
 * \c clang_saveTranslationUnit() by default. The returned flag
 * set contains an unspecified set of options that save translation units with
 * the most commonly-requested data.
 */
uint clang_defaultSaveOptions(CXTranslationUnit TU);

/**
 * Describes the kind of error that occurred (if any) in a call to
 * \c clang_saveTranslationUnit().
 */
enum CXSaveError {
  /**
   * Indicates that no error occurred while saving a translation unit.
   */
  CXSaveError_None = 0,
  
  /**
   * Indicates that an unknown error occurred while attempting to save
   * the file.
   *
   * This error typically indicates that file I/O failed when attempting to 
   * write the file.
   */
  CXSaveError_Unknown = 1,
  
  /**
   * Indicates that errors during translation prevented this attempt
   * to save the translation unit.
   * 
   * Errors that prevent the translation unit from being saved can be
   * extracted using \c clang_getNumDiagnostics() and \c clang_getDiagnostic().
   */
  CXSaveError_TranslationErrors = 2,
  
  /**
   * Indicates that the translation unit to be saved was somehow
   * invalid (e.g., NULL).
   */
  CXSaveError_InvalidTU = 3
}
  
/**
 * Saves a translation unit into a serialized representation of
 * that translation unit on disk.
 *
 * Any translation unit that was parsed without error can be saved
 * into a file. The translation unit can then be deserialized into a
 * new \c CXTranslationUnit with \c clang_createTranslationUnit() or,
 * if it is an incomplete translation unit that corresponds to a
 * header, used as a precompiled header when parsing other translation
 * units.
 *
 * \param TU The translation unit to save.
 *
 * \param FileName The file to which the translation unit will be saved.
 *
 * \param options A bitmask of options that affects how the translation unit
 * is saved. This should be a bitwise OR of the
 * CXSaveTranslationUnit_XXX flags.
 *
 * \returns A value that will match one of the enumerators of the CXSaveError
 * enumeration. Zero (CXSaveError_None) indicates that the translation unit was 
 * saved successfully, while a non-zero value indicates that a problem occurred.
 */
int clang_saveTranslationUnit(CXTranslationUnit TU,
                                             const char* FileName,
                                             uint options);

/**
 * Destroy the specified CXTranslationUnit object.
 */
void clang_disposeTranslationUnit(CXTranslationUnit);

/**
 * Flags that control the reparsing of translation units.
 *
 * The enumerators in this enumeration type are meant to be bitwise
 * ORed together to specify which options should be used when
 * reparsing the translation unit.
 */
enum CXReparse_Flags {
  /**
   * Used to indicate that no special reparsing options are needed.
   */
  CXReparse_None = 0x0
}
 
/**
 * Returns the set of flags that is suitable for reparsing a translation
 * unit.
 *
 * The set of flags returned provide options for
 * \c clang_reparseTranslationUnit() by default. The returned flag
 * set contains an unspecified set of optimizations geared toward common uses
 * of reparsing. The set of optimizations enabled may change from one version 
 * to the next.
 */
uint clang_defaultReparseOptions(CXTranslationUnit TU);

/**
 * Reparse the source files that produced this translation unit.
 *
 * This routine can be used to re-parse the source files that originally
 * created the given translation unit, for example because those source files
 * have changed (either on disk or as passed via \p unsaved_files). The
 * source code will be reparsed with the same command-line options as it
 * was originally parsed. 
 *
 * Reparsing a translation unit invalidates all cursors and source locations
 * that refer into that translation unit. This makes reparsing a translation
 * unit semantically equivalent to destroying the translation unit and then
 * creating a new translation unit with the same command-line arguments.
 * However, it may be more efficient to reparse a translation 
 * unit using this routine.
 *
 * \param TU The translation unit whose contents will be re-parsed. The
 * translation unit must originally have been built with 
 * \c clang_createTranslationUnitFromSourceFile().
 *
 * \param num_unsaved_files The number of unsaved file entries in \p
 * unsaved_files.
 *
 * \param unsaved_files The files that have not yet been saved to disk
 * but may be required for parsing, including the contents of
 * those files.  The contents and name of these files (as specified by
 * CXUnsavedFile) are copied when necessary, so the client only needs to
 * guarantee their validity until the call to this function returns.
 * 
 * \param options A bitset of options composed of the flags in CXReparse_Flags.
 * The function \c clang_defaultReparseOptions() produces a default set of
 * options recommended for most uses, based on the translation unit.
 *
 * \returns 0 if the sources could be reparsed. A non-zero value will be
 * returned if reparsing was impossible, such that the translation unit is
 * invalid. In such cases, the only valid call for \p TU is 
 * \c clang_disposeTranslationUnit(TU).
 */
int clang_reparseTranslationUnit(CXTranslationUnit TU,
                                                uint num_unsaved_files,
                                          		CXUnsavedFile* unsaved_files,
                                                uint options);

/**
  * Categorizes how memory is being used by a translation unit.
  */
enum CXTUResourceUsageKind {
  CXTUResourceUsage_AST = 1,
  CXTUResourceUsage_Identifiers = 2,
  CXTUResourceUsage_Selectors = 3,
  CXTUResourceUsage_GlobalCompletionResults = 4,
  CXTUResourceUsage_SourceManagerContentCache = 5,
  CXTUResourceUsage_AST_SideTables = 6,
  CXTUResourceUsage_SourceManager_Membuffer_Malloc = 7,
  CXTUResourceUsage_SourceManager_Membuffer_MMap = 8,
  CXTUResourceUsage_ExternalASTSource_Membuffer_Malloc = 9, 
  CXTUResourceUsage_ExternalASTSource_Membuffer_MMap = 10, 
  CXTUResourceUsage_Preprocessor = 11,
  CXTUResourceUsage_PreprocessingRecord = 12,
  CXTUResourceUsage_SourceManager_DataStructures = 13,
  CXTUResourceUsage_Preprocessor_HeaderSearch = 14,
  CXTUResourceUsage_MEMORY_IN_BYTES_BEGIN = CXTUResourceUsage_AST,
  CXTUResourceUsage_MEMORY_IN_BYTES_END =
    CXTUResourceUsage_Preprocessor_HeaderSearch,

  CXTUResourceUsage_First = CXTUResourceUsage_AST,
  CXTUResourceUsage_Last = CXTUResourceUsage_Preprocessor_HeaderSearch
}

/**
  * Returns the human-readable null-terminated C string that represents
  *  the name of the memory category.  This string should never be freed.
  */
CINDEX_LINKAGE
const char* clang_getTUResourceUsageName(CXTUResourceUsageKind kind);

struct CXTUResourceUsageEntry {
  /* The memory usage category. */
  CXTUResourceUsageKind kind;  
  /* Amount of resources used. 
      The units will depend on the resource kind. */
  c_ulong amount;
}

/**
  * The memory usage of a CXTranslationUnit, broken into categories.
  */
struct CXTUResourceUsage {
  /* Private data member, used for queries. */
  void* data;

  /* The number of entries in the 'entries' array. */
  uint numEntries;

  /* An array of key-value pairs, representing the breakdown of memory
            usage. */
  CXTUResourceUsageEntry* entries;

}

/**
  * Return the memory usage of a translation unit.  This object
  *  should be released with clang_disposeCXTUResourceUsage().
  */
CXTUResourceUsage clang_getCXTUResourceUsage(CXTranslationUnit TU);

void clang_disposeCXTUResourceUsage(CXTUResourceUsage usage);

/**
 * @}
 */

/**
 * Describes the kind of entity that a cursor refers to.
 */
enum CXCursorKind {
  /* Declarations */
  /**
   * A declaration whose specific kind is not exposed via this
   * interface.
   *
   * Unexposed declarations have the same operations as any other kind
   * of declaration; one can extract their location information,
   * spelling, find their definitions, etc. However, the specific kind
   * of the declaration is not reported.
   */
  CXCursor_UnexposedDecl                 = 1,
  /** A C or C++ struct. */
  CXCursor_StructDecl                    = 2,
  /** A C or C++ union. */
  CXCursor_UnionDecl                     = 3,
  /** A C++ class. */
  CXCursor_ClassDecl                     = 4,
  /** An enumeration. */
  CXCursor_EnumDecl                      = 5,
  /**
   * A field (in C) or non-static data member (in C++) in a
   * struct, union, or C++ class.
   */
  CXCursor_FieldDecl                     = 6,
  /** An enumerator constant. */
  CXCursor_EnumConstantDecl              = 7,
  /** A function. */
  CXCursor_FunctionDecl                  = 8,
  /** A variable. */
  CXCursor_VarDecl                       = 9,
  /** A function or method parameter. */
  CXCursor_ParmDecl                      = 10,
  /** An Objective-C @interface. */
  CXCursor_ObjCInterfaceDecl             = 11,
  /** An Objective-C @interface for a category. */
  CXCursor_ObjCCategoryDecl              = 12,
  /** An Objective-C @protocol declaration. */
  CXCursor_ObjCProtocolDecl              = 13,
  /** An Objective-C @property declaration. */
  CXCursor_ObjCPropertyDecl              = 14,
  /** An Objective-C instance variable. */
  CXCursor_ObjCIvarDecl                  = 15,
  /** An Objective-C instance method. */
  CXCursor_ObjCInstanceMethodDecl        = 16,
  /** An Objective-C class method. */
  CXCursor_ObjCClassMethodDecl           = 17,
  /** An Objective-C @implementation. */
  CXCursor_ObjCImplementationDecl        = 18,
  /** An Objective-C @implementation for a category. */
  CXCursor_ObjCCategoryImplDecl          = 19,
  /** A typedef */
  CXCursor_TypedefDecl                   = 20,
  /** A C++ class method. */
  CXCursor_CXXMethod                     = 21,
  /** A C++ namespace. */
  CXCursor_Namespace                     = 22,
  /** A linkage specification, e.g. 'extern "C"'. */
  CXCursor_LinkageSpec                   = 23,
  /** A C++ constructor. */
  CXCursor_Constructor                   = 24,
  /** A C++ destructor. */
  CXCursor_Destructor                    = 25,
  /** A C++ conversion function. */
  CXCursor_ConversionFunction            = 26,
  /** A C++ template type parameter. */
  CXCursor_TemplateTypeParameter         = 27,
  /** A C++ non-type template parameter. */
  CXCursor_NonTypeTemplateParameter      = 28,
  /** A C++ template template parameter. */
  CXCursor_TemplateTemplateParameter     = 29,
  /** A C++ function template. */
  CXCursor_FunctionTemplate              = 30,
  /** A C++ class template. */
  CXCursor_ClassTemplate                 = 31,
  /** A C++ class template partial specialization. */
  CXCursor_ClassTemplatePartialSpecialization = 32,
  /** A C++ namespace alias declaration. */
  CXCursor_NamespaceAlias                = 33,
  /** A C++ using directive. */
  CXCursor_UsingDirective                = 34,
  /** A C++ using declaration. */
  CXCursor_UsingDeclaration              = 35,
  /** A C++ alias declaration */
  CXCursor_TypeAliasDecl                 = 36,
  /** An Objective-C @synthesize definition. */
  CXCursor_ObjCSynthesizeDecl            = 37,
  /** An Objective-C @dynamic definition. */
  CXCursor_ObjCDynamicDecl               = 38,
  /** An access specifier. */
  CXCursor_CXXAccessSpecifier            = 39,
  CXCursor_FirstDecl                     = CXCursor_UnexposedDecl,
  CXCursor_LastDecl                      = CXCursor_CXXAccessSpecifier,

  /* References */
  CXCursor_FirstRef                      = 40, /* Decl references */
  CXCursor_ObjCSuperClassRef             = 40,
  CXCursor_ObjCProtocolRef               = 41,
  CXCursor_ObjCClassRef                  = 42,
  /**
   * A reference to a type declaration.
   *
   * A type reference occurs anywhere where a type is named but not
   * declared. For example, given:
   *
   * \code
   * alias uint size_type;
   * size_type size;
   * \endcode
   *
   * The alias is a declaration of size_type (CXCursor_TypedefDecl),
   * while the type of the variable "size" is referenced. The cursor
   * referenced by the type of size is the alias for size_type.
   */
  CXCursor_TypeRef                       = 43,
  CXCursor_CXXBaseSpecifier              = 44,
  /** 
   * A reference to a class template, function template, template
   * template parameter, or class template partial specialization.
   */
  CXCursor_TemplateRef                   = 45,
  /**
   * A reference to a namespace or namespace alias.
   */
  CXCursor_NamespaceRef                  = 46,
  /**
   * A reference to a member of a struct, union, or class that occurs in 
   * some non-expression context, e.g., a designated initializer.
   */
  CXCursor_MemberRef                     = 47,
  /**
   * A reference to a labeled statement.
   *
   * This cursor kind is used to describe the jump to "start_over" in the 
   * goto statement in the following example:
   *
   * \code
   *   start_over:
   *     ++counter;
   *
   *     goto start_over;
   * \endcode
   *
   * A label reference cursor refers to a label statement.
   */
  CXCursor_LabelRef                      = 48,
  
  /**
   * A reference to a set of overloaded functions or function templates
   * that has not yet been resolved to a specific function or function template.
   *
   * An overloaded declaration reference cursor occurs in C++ templates where
   * a dependent name refers to a function. For example:
   *
   * \code
   * template<typename T> void swap(T&, T&);
   *
   * struct X { ... }
   * void swap(X&, X&);
   *
   * template<typename T>
   * void reverse(T* first, T* last) {
   *   while (first < last - 1) {
   *     swap(*first, *--last);
   *     ++first;
   *   }
   * }
   *
   * struct Y { }
   * void swap(Y&, Y&);
   * \endcode
   *
   * Here, the identifier "swap" is associated with an overloaded declaration
   * reference. In the template definition, "swap" refers to either of the two
   * "swap" functions declared above, so both results will be available. At
   * instantiation time, "swap" may also refer to other functions found via
   * argument-dependent lookup (e.g., the "swap" function at the end of the
   * example).
   *
   * The functions \c clang_getNumOverloadedDecls() and 
   * \c clang_getOverloadedDecl() can be used to retrieve the definitions
   * referenced by this cursor.
   */
  CXCursor_OverloadedDeclRef             = 49,
  
  CXCursor_LastRef                       = CXCursor_OverloadedDeclRef,

  /* Error conditions */
  CXCursor_FirstInvalid                  = 70,
  CXCursor_InvalidFile                   = 70,
  CXCursor_NoDeclFound                   = 71,
  CXCursor_NotImplemented                = 72,
  CXCursor_InvalidCode                   = 73,
  CXCursor_LastInvalid                   = CXCursor_InvalidCode,

  /* Expressions */
  CXCursor_FirstExpr                     = 100,

  /**
   * An expression whose specific kind is not exposed via this
   * interface.
   *
   * Unexposed expressions have the same operations as any other kind
   * of expression; one can extract their location information,
   * spelling, children, etc. However, the specific kind of the
   * expression is not reported.
   */
  CXCursor_UnexposedExpr                 = 100,

  /**
   * An expression that refers to some value declaration, such
   * as a function, varible, or enumerator.
   */
  CXCursor_DeclRefExpr                   = 101,

  /**
   * An expression that refers to a member of a struct, union,
   * class, Objective-C class, etc.
   */
  CXCursor_MemberRefExpr                 = 102,

  /** An expression that calls a function. */
  CXCursor_CallExpr                      = 103,

  /** An expression that sends a message to an Objective-C
   object or class. */
  CXCursor_ObjCMessageExpr               = 104,

  /** An expression that represents a block literal. */
  CXCursor_BlockExpr                     = 105,

  CXCursor_LastExpr                      = 105,

  /* Statements */
  CXCursor_FirstStmt                     = 200,
  /**
   * A statement whose specific kind is not exposed via this
   * interface.
   *
   * Unexposed statements have the same operations as any other kind of
   * statement; one can extract their location information, spelling,
   * children, etc. However, the specific kind of the statement is not
   * reported.
   */
  CXCursor_UnexposedStmt                 = 200,
  
  /** A labelled statement in a function. 
   *
   * This cursor kind is used to describe the "start_over:" label statement in 
   * the following example:
   *
   * \code
   *   start_over:
   *     ++counter;
   * \endcode
   *
   */
  CXCursor_LabelStmt                     = 201,
  
  CXCursor_LastStmt                      = CXCursor_LabelStmt,

  /**
   * Cursor that represents the translation unit itself.
   *
   * The translation unit cursor exists primarily to act as the root
   * cursor for traversing the contents of a translation unit.
   */
  CXCursor_TranslationUnit               = 300,

  /* Attributes */
  CXCursor_FirstAttr                     = 400,
  /**
   * An attribute whose specific kind is not exposed via this
   * interface.
   */
  CXCursor_UnexposedAttr                 = 400,

  CXCursor_IBActionAttr                  = 401,
  CXCursor_IBOutletAttr                  = 402,
  CXCursor_IBOutletCollectionAttr        = 403,
  CXCursor_CXXFinalAttr                  = 404,
  CXCursor_CXXOverrideAttr               = 405,
  CXCursor_LastAttr                      = CXCursor_CXXOverrideAttr,
     
  /* Preprocessing */
  CXCursor_PreprocessingDirective        = 500,
  CXCursor_MacroDefinition               = 501,
  CXCursor_MacroExpansion                = 502,
  CXCursor_MacroInstantiation            = CXCursor_MacroExpansion,
  CXCursor_InclusionDirective            = 503,
  CXCursor_FirstPreprocessing            = CXCursor_PreprocessingDirective,
  CXCursor_LastPreprocessing             = CXCursor_InclusionDirective
}

/**
 * A cursor representing some element in the abstract syntax tree for
 * a translation unit.
 *
 * The cursor abstraction unifies the different kinds of entities in a
 * program--declaration, statements, expressions, references to declarations,
 * etc.--under a single "cursor" abstraction with a common set of operations.
 * Common operation for a cursor include: getting the physical location in
 * a source file where the cursor points, getting the name associated with a
 * cursor, and retrieving cursors for any child nodes of a particular cursor.
 *
 * Cursors can be produced in two specific ways.
 * clang_getTranslationUnitCursor() produces a cursor for a translation unit,
 * from which one can use clang_visitChildren() to explore the rest of the
 * translation unit. clang_getCursor() maps from a physical source location
 * to the entity that resides at that location, allowing one to map from the
 * source code into the AST.
 */
struct CXCursor {
  CXCursorKind kind;
  void* data[3];
}

/**
 * \defgroup CINDEX_CURSOR_MANIP Cursor manipulations
 *
 * @{
 */

/**
 * Retrieve the NULL cursor, which represents no entity.
 */
CXCursor clang_getNullCursor(void);

/**
 * Retrieve the cursor that represents the given translation unit.
 *
 * The translation unit cursor can be used to start traversing the
 * various declarations within the given translation unit.
 */
CXCursor clang_getTranslationUnitCursor(CXTranslationUnit);

/**
 * Determine whether two cursors are equivalent.
 */
uint clang_equalCursors(CXCursor, CXCursor);

/**
 * Returns non-zero if \arg cursor is null.
 */
int clang_Cursor_isNull(CXCursor);

/**
 * Compute a hash value for the given cursor.
 */
uint clang_hashCursor(CXCursor);
  
/**
 * Retrieve the kind of the given cursor.
 */
CXCursorKind clang_getCursorKind(CXCursor);

/**
 * Determine whether the given cursor kind represents a declaration.
 */
uint clang_isDeclaration(CXCursorKind);

/**
 * Determine whether the given cursor kind represents a simple
 * reference.
 *
 * Note that other kinds of cursors (such as expressions) can also refer to
 * other cursors. Use clang_getCursorReferenced() to determine whether a
 * particular cursor refers to another entity.
 */
uint clang_isReference(CXCursorKind);

/**
 * Determine whether the given cursor kind represents an expression.
 */
uint clang_isExpression(CXCursorKind);

/**
 * Determine whether the given cursor kind represents a statement.
 */
uint clang_isStatement(CXCursorKind);

/**
 * Determine whether the given cursor kind represents an attribute.
 */
uint clang_isAttribute(CXCursorKind);

/**
 * Determine whether the given cursor kind represents an invalid
 * cursor.
 */
uint clang_isInvalid(CXCursorKind);

/**
 * Determine whether the given cursor kind represents a translation
 * unit.
 */
uint clang_isTranslationUnit(CXCursorKind);

/***
 * Determine whether the given cursor represents a preprocessing
 * element, such as a preprocessor directive or macro instantiation.
 */
uint clang_isPreprocessing(CXCursorKind);
  
/***
 * Determine whether the given cursor represents a currently
 *  unexposed piece of the AST (e.g., CXCursor_UnexposedStmt).
 */
uint clang_isUnexposed(CXCursorKind);

/**
 * Describe the linkage of the entity referred to by a cursor.
 */
enum CXLinkageKind {
  /** This value indicates that no linkage information is available
   * for a provided CXCursor. */
  CXLinkage_Invalid,
  /**
   * This is the linkage for variables, parameters, and so on that
   *  have automatic storage.  This covers normal (non-extern) local variables.
   */
  CXLinkage_NoLinkage,
  /** This is the linkage for static variables and static functions. */
  CXLinkage_Internal,
  /** This is the linkage for entities with external linkage that live
   * in C++ anonymous namespaces.*/
  CXLinkage_UniqueExternal,
  /** This is the linkage for entities with true, external linkage. */
  CXLinkage_External
}

/**
 * Determine the linkage of the entity referred to by a given cursor.
 */
CXLinkageKind clang_getCursorLinkage(CXCursor cursor);

/**
 * Determine the availability of the entity that this cursor refers to.
 *
 * \param cursor The cursor to query.
 *
 * \returns The availability of the cursor.
 */
CXAvailabilityKind 
clang_getCursorAvailability(CXCursor cursor);

/**
 * Describe the "language" of the entity referred to by a cursor.
 */
enum CXLanguageKind {
  CXLanguage_Invalid = 0,
  CXLanguage_C,
  CXLanguage_ObjC,
  CXLanguage_CPlusPlus
}

/**
 * Determine the "language" of the entity referred to by a given cursor.
 */
CXLanguageKind clang_getCursorLanguage(CXCursor cursor);

/**
 * Returns the translation unit that a cursor originated from.
 */
CXTranslationUnit clang_Cursor_getTranslationUnit(CXCursor);


/**
 * A fast container representing a set of CXCursors.
 */
CXCursorSetImpl* CXCursorSet;

/**
 * Creates an empty CXCursorSet.
 */
CXCursorSet clang_createCXCursorSet();

/**
 * Disposes a CXCursorSet and releases its associated memory.
 */
void clang_disposeCXCursorSet(CXCursorSet cset);

/**
 * Queries a CXCursorSet to see if it contains a specific CXCursor.
 *
 * \returns non-zero if the set contains the specified cursor.
*/
uint clang_CXCursorSet_contains(CXCursorSet cset,
                                                   CXCursor cursor);

/**
 * Inserts a CXCursor into a CXCursorSet.
 *
 * \returns zero if the CXCursor was already in the set, and non-zero otherwise.
*/
uint clang_CXCursorSet_insert(CXCursorSet cset,
                                                 CXCursor cursor);

/**
 * Determine the semantic parent of the given cursor.
 *
 * The semantic parent of a cursor is the cursor that semantically contains
 * the given \p cursor. For many declarations, the lexical and semantic parents
 * are equivalent (the lexical parent is returned by 
 * \c clang_getCursorLexicalParent()). They diverge when declarations or
 * definitions are provided out-of-line. For example:
 *
 * \code
 * class C {
 *  void f();
 * }
 *
 * void C::f() { }
 * \endcode
 *
 * In the out-of-line definition of \c C::f, the semantic parent is the 
 * the class \c C, of which this function is a member. The lexical parent is
 * the place where the declaration actually occurs in the source code; in this
 * case, the definition occurs in the translation unit. In general, the 
 * lexical parent for a given entity can change without affecting the semantics
 * of the program, and the lexical parent of different declarations of the
 * same entity may be different. Changing the semantic parent of a declaration,
 * on the other hand, can have a major impact on semantics, and redeclarations
 * of a particular entity should all have the same semantic context.
 *
 * In the example above, both declarations of \c C::f have \c C as their
 * semantic context, while the lexical context of the first \c C::f is \c C
 * and the lexical context of the second \c C::f is the translation unit.
 *
 * For global declarations, the semantic parent is the translation unit.
 */
CXCursor clang_getCursorSemanticParent(CXCursor cursor);

/**
 * Determine the lexical parent of the given cursor.
 *
 * The lexical parent of a cursor is the cursor in which the given \p cursor
 * was actually written. For many declarations, the lexical and semantic parents
 * are equivalent (the semantic parent is returned by 
 * \c clang_getCursorSemanticParent()). They diverge when declarations or
 * definitions are provided out-of-line. For example:
 *
 * \code
 * class C {
 *  void f();
 * }
 *
 * void C::f() { }
 * \endcode
 *
 * In the out-of-line definition of \c C::f, the semantic parent is the 
 * the class \c C, of which this function is a member. The lexical parent is
 * the place where the declaration actually occurs in the source code; in this
 * case, the definition occurs in the translation unit. In general, the 
 * lexical parent for a given entity can change without affecting the semantics
 * of the program, and the lexical parent of different declarations of the
 * same entity may be different. Changing the semantic parent of a declaration,
 * on the other hand, can have a major impact on semantics, and redeclarations
 * of a particular entity should all have the same semantic context.
 *
 * In the example above, both declarations of \c C::f have \c C as their
 * semantic context, while the lexical context of the first \c C::f is \c C
 * and the lexical context of the second \c C::f is the translation unit.
 *
 * For declarations written in the global scope, the lexical parent is
 * the translation unit.
 */
CXCursor clang_getCursorLexicalParent(CXCursor cursor);

/**
 * Determine the set of methods that are overridden by the given
 * method.
 *
 * In both Objective-C and C++, a method (aka virtual member function,
 * in C++) can override a virtual method in a base class. For
 * Objective-C, a method is said to override any method in the class's
 * interface (if we're coming from an implementation), its protocols,
 * or its categories, that has the same selector and is of the same
 * kind (class or instance). If no such method exists, the search
 * continues to the class's superclass, its protocols, and its
 * categories, and so on.
 *
 * For C++, a virtual member function overrides any virtual member
 * function with the same signature that occurs in its base
 * classes. With multiple inheritance, a virtual member function can
 * override several virtual member functions coming from different
 * base classes.
 *
 * In all cases, this function determines the immediate overridden
 * method, rather than all of the overridden methods. For example, if
 * a method is originally declared in a class A, then overridden in B
 * (which in inherits from A) and also in C (which inherited from B),
 * then the only overridden method returned from this function when
 * invoked on C's method will be B's method. The client may then
 * invoke this function again, given the previously-found overridden
 * methods, to map out the complete method-override set.
 *
 * \param cursor A cursor representing an Objective-C or C++
 * method. This routine will compute the set of methods that this
 * method overrides.
 * 
 * \param overridden A pointer whose pointee will be replaced with a
 * pointer to an array of cursors, representing the set of overridden
 * methods. If there are no overridden methods, the pointee will be
 * set to NULL. The pointee must be freed via a call to 
 * \c clang_disposeOverriddenCursors().
 *
 * \param num_overridden A pointer to the number of overridden
 * functions, will be set to the number of overridden functions in the
 * array pointed to by \p overridden.
 */
void clang_getOverriddenCursors(CXCursor cursor, 
                                               CXCursor **overridden,
                                               uint* num_overridden);

/**
 * Free the set of overridden cursors returned by \c
 * clang_getOverriddenCursors().
 */
void clang_disposeOverriddenCursors(CXCursor* overridden);

/**
 * Retrieve the file that is included by the given inclusion directive
 * cursor.
 */
CXFile clang_getIncludedFile(CXCursor cursor);
  
/**
 * @}
 */

/**
 * \defgroup CINDEX_CURSOR_SOURCE Mapping between cursors and source code
 *
 * Cursors represent a location within the Abstract Syntax Tree (AST). These
 * routines help map between cursors and the physical locations where the
 * described entities occur in the source code. The mapping is provided in
 * both directions, so one can map from source code to the AST and back.
 *
 * @{
 */

/**
 * Map a source location to the cursor that describes the entity at that
 * location in the source code.
 *
 * clang_getCursor() maps an arbitrary source location within a translation
 * unit down to the most specific cursor that describes the entity at that
 * location. For example, given an expression \c x + y, invoking
 * clang_getCursor() with a source location pointing to "x" will return the
 * cursor for "x"; similarly for "y". If the cursor points anywhere between
 * "x" or "y" (e.g., on the + or the whitespace around it), clang_getCursor()
 * will return a cursor referring to the "+" expression.
 *
 * \returns a cursor representing the entity at the given source location, or
 * a NULL cursor if no such entity can be found.
 */
CXCursor clang_getCursor(CXTranslationUnit, CXSourceLocation);

/**
 * Retrieve the physical location of the source constructor referenced
 * by the given cursor.
 *
 * The location of a declaration is typically the location of the name of that
 * declaration, where the name of that declaration would occur if it is
 * unnamed, or some keyword that introduces that particular declaration.
 * The location of a reference is where that reference occurs within the
 * source code.
 */
CXSourceLocation clang_getCursorLocation(CXCursor);

/**
 * Retrieve the physical extent of the source construct referenced by
 * the given cursor.
 *
 * The extent of a cursor starts with the file/line/column pointing at the
 * first character within the source construct that the cursor refers to and
 * ends with the last character withinin that source construct. For a
 * declaration, the extent covers the declaration itself. For a reference,
 * the extent covers the location of the reference (e.g., where the referenced
 * entity was actually used).
 */
CXSourceRange clang_getCursorExtent(CXCursor);

/**
 * @}
 */
    
/**
 * \defgroup CINDEX_TYPES Type information for CXCursors
 *
 * @{
 */

/**
 * Describes the kind of type
 */
enum CXTypeKind {
  /**
   * Reprents an invalid type (e.g., where no type is available).
   */
  CXType_Invalid = 0,

  /**
   * A type whose specific kind is not exposed via this
   * interface.
   */
  CXType_Unexposed = 1,

  /* Builtin types */
  CXType_Void = 2,
  CXType_Bool = 3,
  CXType_Char_U = 4,
  CXType_UChar = 5,
  CXType_Char16 = 6,
  CXType_Char32 = 7,
  CXType_UShort = 8,
  CXType_UInt = 9,
  CXType_ULong = 10,
  CXType_ULongLong = 11,
  CXType_UInt128 = 12,
  CXType_Char_S = 13,
  CXType_SChar = 14,
  CXType_WChar = 15,
  CXType_Short = 16,
  CXType_Int = 17,
  CXType_Long = 18,
  CXType_LongLong = 19,
  CXType_Int128 = 20,
  CXType_Float = 21,
  CXType_Double = 22,
  CXType_LongDouble = 23,
  CXType_NullPtr = 24,
  CXType_Overload = 25,
  CXType_Dependent = 26,
  CXType_ObjCId = 27,
  CXType_ObjCClass = 28,
  CXType_ObjCSel = 29,
  CXType_FirstBuiltin = CXType_Void,
  CXType_LastBuiltin  = CXType_ObjCSel,

  CXType_Complex = 100,
  CXType_Pointer = 101,
  CXType_BlockPointer = 102,
  CXType_LValueReference = 103,
  CXType_RValueReference = 104,
  CXType_Record = 105,
  CXType_Enum = 106,
  CXType_Typedef = 107,
  CXType_ObjCInterface = 108,
  CXType_ObjCObjectPointer = 109,
  CXType_FunctionNoProto = 110,
  CXType_FunctionProto = 111,
  CXType_ConstantArray = 112
}

/**
 * The type of an element in the abstract syntax tree.
 *
 */
struct CXType {
  CXTypeKind kind;
  void* data[2];
}

/**
 * Retrieve the type of a CXCursor (if any).
 */
CXType clang_getCursorType(CXCursor C);

/**
 * \determine Determine whether two CXTypes represent the same type.
 *
 * \returns non-zero if the CXTypes represent the same type and 
            zero otherwise.
 */
uint clang_equalTypes(CXType A, CXType B);

/**
 * Return the canonical type for a CXType.
 *
 * Clang's type system explicitly models typedefs and all the ways
 * a specific type can be represented.  The canonical type is the underlying
 * type with all the "sugar" removed.  For example, if 'T' is a typedef
 * for 'int', the canonical type for 'T' would be 'int'.
 */
CXType clang_getCanonicalType(CXType T);

/**
 *  \determine Determine whether a CXType has the "const" qualifier set, 
 *  without looking through typedefs that may have added "const" at a different level.
 */
uint clang_isConstQualifiedType(CXType T);

/**
 *  \determine Determine whether a CXType has the "volatile" qualifier set,
 *  without looking through typedefs that may have added "volatile" at a different level.
 */
uint clang_isVolatileQualifiedType(CXType T);

/**
 *  \determine Determine whether a CXType has the "restrict" qualifier set,
 *  without looking through typedefs that may have added "restrict" at a different level.
 */
uint clang_isRestrictQualifiedType(CXType T);

/**
 * For pointer types, returns the type of the pointee.
 *
 */
CXType clang_getPointeeType(CXType T);

/**
 * Return the cursor for the declaration of the given type.
 */
CXCursor clang_getTypeDeclaration(CXType T);

/**
 * Returns the Objective-C type encoding for the specified declaration.
 */
CXString clang_getDeclObjCTypeEncoding(CXCursor C);

/**
 * Retrieve the spelling of a given CXTypeKind.
 */
CXString clang_getTypeKindSpelling(CXTypeKind K);

/**
 * Retrieve the result type associated with a function type.
 */
CXType clang_getResultType(CXType T);

/**
 * Retrieve the result type associated with a given cursor.  This only
 *  returns a valid type of the cursor refers to a function or method.
 */
CXType clang_getCursorResultType(CXCursor C);

/**
 * Return 1 if the CXType is a POD (plain old data) type, and 0
 *  otherwise.
 */
uint clang_isPODType(CXType T);

/**
 * Return the element type of an array type.
 *
 * If a non-array type is passed in, an invalid type is returned.
 */
CXType clang_getArrayElementType(CXType T);

/**
 * Return the the array size of a constant array.
 *
 * If a non-array type is passed in, -1 is returned.
 */
long long clang_getArraySize(CXType T);

/**
 * Returns 1 if the base class specified by the cursor with kind
 *   CX_CXXBaseSpecifier is virtual.
 */
uint clang_isVirtualBase(CXCursor);
    
/**
 * Represents the C++ access control level to a base class for a
 * cursor with kind CX_CXXBaseSpecifier.
 */
enum CX_CXXAccessSpecifier {
  CX_CXXInvalidAccessSpecifier,
  CX_CXXPublic,
  CX_CXXProtected,
  CX_CXXPrivate
}

/**
 * Returns the access control level for the C++ base specifier
 * represented by a cursor with kind CXCursor_CXXBaseSpecifier or
 * CXCursor_AccessSpecifier.
 */
CX_CXXAccessSpecifier clang_getCXXAccessSpecifier(CXCursor);

/**
 * Determine the number of overloaded declarations referenced by a 
 * \c CXCursor_OverloadedDeclRef cursor.
 *
 * \param cursor The cursor whose overloaded declarations are being queried.
 *
 * \returns The number of overloaded declarations referenced by \c cursor. If it
 * is not a \c CXCursor_OverloadedDeclRef cursor, returns 0.
 */
uint clang_getNumOverloadedDecls(CXCursor cursor);

/**
 * Retrieve a cursor for one of the overloaded declarations referenced
 * by a \c CXCursor_OverloadedDeclRef cursor.
 *
 * \param cursor The cursor whose overloaded declarations are being queried.
 *
 * \param index The zero-based index into the set of overloaded declarations in
 * the cursor.
 *
 * \returns A cursor representing the declaration referenced by the given 
 * \c cursor at the specified \c index. If the cursor does not have an 
 * associated set of overloaded declarations, or if the index is out of bounds,
 * returns \c clang_getNullCursor();
 */
CXCursor clang_getOverloadedDecl(CXCursor cursor, 
                                                uint index);
  
/**
 * @}
 */
  
/**
 * \defgroup CINDEX_ATTRIBUTES Information for attributes
 *
 * @{
 */


/**
 * For cursors representing an iboutletcollection attribute,
 *  this function returns the collection element type.
 *
 */
CXType clang_getIBOutletCollectionType(CXCursor);

/**
 * @}
 */

/**
 * \defgroup CINDEX_CURSOR_TRAVERSAL Traversing the AST with cursors
 *
 * These routines provide the ability to traverse the abstract syntax tree
 * using cursors.
 *
 * @{
 */

/**
 * Describes how the traversal of the children of a particular
 * cursor should proceed after visiting a particular child cursor.
 *
 * A value of this enumeration type should be returned by each
 * \c CXCursorVisitor to indicate how clang_visitChildren() proceed.
 */
enum CXChildVisitResult {
  /**
   * Terminates the cursor traversal.
   */
  CXChildVisit_Break,
  /**
   * Continues the cursor traversal with the next sibling of
   * the cursor just visited, without visiting its children.
   */
  CXChildVisit_Continue,
  /**
   * Recursively traverse the children of this cursor, using
   * the same visitor and client data.
   */
  CXChildVisit_Recurse
}

/**
 * Visitor invoked for each cursor found by a traversal.
 *
 * This visitor function will be invoked for each cursor found by
 * clang_visitCursorChildren(). Its first argument is the cursor being
 * visited, its second argument is the parent visitor for that cursor,
 * and its third argument is the client data provided to
 * clang_visitCursorChildren().
 *
 * The visitor should return one of the \c CXChildVisitResult values
 * to direct clang_visitCursorChildren().
 */
alias CXChildVisitResult (*CXCursorVisitor)(CXCursor cursor,
                                                   CXCursor parent,
                                                   CXClientData client_data);

/**
 * Visit the children of a particular cursor.
 *
 * This function visits all the direct children of the given cursor,
 * invoking the given \p visitor function with the cursors of each
 * visited child. The traversal may be recursive, if the visitor returns
 * \c CXChildVisit_Recurse. The traversal may also be ended prematurely, if
 * the visitor returns \c CXChildVisit_Break.
 *
 * \param parent the cursor whose child may be visited. All kinds of
 * cursors can be visited, including invalid cursors (which, by
 * definition, have no children).
 *
 * \param visitor the visitor function that will be invoked for each
 * child of \p parent.
 *
 * \param client_data pointer data supplied by the client, which will
 * be passed to the visitor each time it is invoked.
 *
 * \returns a non-zero value if the traversal was terminated
 * prematurely by the visitor returning \c CXChildVisit_Break.
 */
uint clang_visitChildren(CXCursor parent,
                                            CXCursorVisitor visitor,
                                            CXClientData client_data);
static if (hasBlocks)
{
	/**
	 * Visitor invoked for each cursor found by a traversal.
	 *
	 * This visitor block will be invoked for each cursor found by
	 * clang_visitChildrenWithBlock(). Its first argument is the cursor being
	 * visited, its second argument is the parent visitor for that cursor.
	 *
	 * The visitor should return one of the \c CXChildVisitResult values
	 * to direct clang_visitChildrenWithBlock().
	 */
	alias CXChildVisitResult 
	     (^CXCursorVisitorBlock)(CXCursor cursor, CXCursor parent);

	/**
	 * Visits the children of a cursor using the specified block.  Behaves
	 * identically to clang_visitChildren() in all other respects.
	 */
	uint clang_visitChildrenWithBlock(CXCursor parent,
	                                      CXCursorVisitorBlock block);
}

/**
 * @}
 */

/**
 * \defgroup CINDEX_CURSOR_XREF Cross-referencing in the AST
 *
 * These routines provide the ability to determine references within and
 * across translation units, by providing the names of the entities referenced
 * by cursors, follow reference cursors to the declarations they reference,
 * and associate declarations with their definitions.
 *
 * @{
 */

/**
 * Retrieve a Unified Symbol Resolution (USR) for the entity referenced
 * by the given cursor.
 *
 * A Unified Symbol Resolution (USR) is a string that identifies a particular
 * entity (function, class, variable, etc.) within a program. USRs can be
 * compared across translation units to determine, e.g., when references in
 * one translation refer to an entity defined in another translation unit.
 */
CXString clang_getCursorUSR(CXCursor);

/**
 * Construct a USR for a specified Objective-C class.
 */
CXString clang_constructUSR_ObjCClass(const char* class_name);

/**
 * Construct a USR for a specified Objective-C category.
 */
CXString
  clang_constructUSR_ObjCCategory(const char* class_name,
                                 const char* category_name);

/**
 * Construct a USR for a specified Objective-C protocol.
 */
CXString
  clang_constructUSR_ObjCProtocol(const char* protocol_name);


/**
 * Construct a USR for a specified Objective-C instance variable and
 *   the USR for its containing class.
 */
CXString clang_constructUSR_ObjCIvar(const char* name,
                                                    CXString classUSR);

/**
 * Construct a USR for a specified Objective-C method and
 *   the USR for its containing class.
 */
CXString clang_constructUSR_ObjCMethod(const char* name,
                                                      uint isInstanceMethod,
                                                      CXString classUSR);

/**
 * Construct a USR for a specified Objective-C property and the USR
 *  for its containing class.
 */
CXString clang_constructUSR_ObjCProperty(const char* property,
                                                        CXString classUSR);

/**
 * Retrieve a name for the entity referenced by this cursor.
 */
CXString clang_getCursorSpelling(CXCursor);

/**
 * Retrieve the display name for the entity referenced by this cursor.
 *
 * The display name contains extra information that helps identify the cursor,
 * such as the parameters of a function or template or the arguments of a 
 * class template specialization.
 */
CXString clang_getCursorDisplayName(CXCursor);
  
/** For a cursor that is a reference, retrieve a cursor representing the
 * entity that it references.
 *
 * Reference cursors refer to other entities in the AST. For example, an
 * Objective-C superclass reference cursor refers to an Objective-C class.
 * This function produces the cursor for the Objective-C class from the
 * cursor for the superclass reference. If the input cursor is a declaration or
 * definition, it returns that declaration or definition unchanged.
 * Otherwise, returns the NULL cursor.
 */
CXCursor clang_getCursorReferenced(CXCursor);

/**
 *  For a cursor that is either a reference to or a declaration
 *  of some entity, retrieve a cursor that describes the definition of
 *  that entity.
 *
 *  Some entities can be declared multiple times within a translation
 *  unit, but only one of those declarations can also be a
 *  definition. For example, given:
 *
 *  \code
 *  int f(int, int);
 *  int g(int x, int y) { return f(x, y); }
 *  int f(int a, int b) { return a + b; }
 *  int f(int, int);
 *  \endcode
 *
 *  there are three declarations of the function "f", but only the
 *  second one is a definition. The clang_getCursorDefinition()
 *  function will take any cursor pointing to a declaration of "f"
 *  (the first or fourth lines of the example) or a cursor referenced
 *  that uses "f" (the call to "f' inside "g") and will return a
 *  declaration cursor pointing to the definition (the second "f"
 *  declaration).
 *
 *  If given a cursor for which there is no corresponding definition,
 *  e.g., because there is no definition of that entity within this
 *  translation unit, returns a NULL cursor.
 */
CXCursor clang_getCursorDefinition(CXCursor);

/**
 * Determine whether the declaration pointed to by this cursor
 * is also a definition of that entity.
 */
uint clang_isCursorDefinition(CXCursor);

/**
 * Retrieve the canonical cursor corresponding to the given cursor.
 *
 * In the C family of languages, many kinds of entities can be declared several
 * times within a single translation unit. For example, a structure type can
 * be forward-declared (possibly multiple times) and later defined:
 *
 * \code
 * struct X;
 * struct X;
 * struct X {
 *   int member;
 * }
 * \endcode
 *
 * The declarations and the definition of \c X are represented by three 
 * different cursors, all of which are declarations of the same underlying 
 * entity. One of these cursor is considered the "canonical" cursor, which
 * is effectively the representative for the underlying entity. One can 
 * determine if two cursors are declarations of the same underlying entity by
 * comparing their canonical cursors.
 *
 * \returns The canonical cursor for the entity referred to by the given cursor.
 */
CXCursor clang_getCanonicalCursor(CXCursor);

/**
 * @}
 */

/**
 * \defgroup CINDEX_CPP C++ AST introspection
 *
 * The routines in this group provide access information in the ASTs specific
 * to C++ language features.
 *
 * @{
 */

/**
 * Determine if a C++ member function or member function template is 
 * declared 'static'.
 */
uint clang_CXXMethod_isStatic(CXCursor C);

/**
 * Determine if a C++ member function or member function template is
 * explicitly declared 'virtual' or if it overrides a virtual method from
 * one of the base classes.
 */
uint clang_CXXMethod_isVirtual(CXCursor C);

/**
 * Given a cursor that represents a template, determine
 * the cursor kind of the specializations would be generated by instantiating
 * the template.
 *
 * This routine can be used to determine what flavor of function template,
 * class template, or class template partial specialization is stored in the
 * cursor. For example, it can describe whether a class template cursor is
 * declared with "struct", "class" or "union".
 *
 * \param C The cursor to query. This cursor should represent a template
 * declaration.
 *
 * \returns The cursor kind of the specializations that would be generated
 * by instantiating the template \p C. If \p C is not a template, returns
 * \c CXCursor_NoDeclFound.
 */
CXCursorKind clang_getTemplateCursorKind(CXCursor C);
  
/**
 * Given a cursor that may represent a specialization or instantiation
 * of a template, retrieve the cursor that represents the template that it
 * specializes or from which it was instantiated.
 *
 * This routine determines the template involved both for explicit 
 * specializations of templates and for implicit instantiations of the template,
 * both of which are referred to as "specializations". For a class template
 * specialization (e.g., \c std::vector<bool>), this routine will return 
 * either the primary template (\c std::vector) or, if the specialization was
 * instantiated from a class template partial specialization, the class template
 * partial specialization. For a class template partial specialization and a
 * function template specialization (including instantiations), this
 * this routine will return the specialized template.
 *
 * For members of a class template (e.g., member functions, member classes, or
 * static data members), returns the specialized or instantiated member. 
 * Although not strictly "templates" in the C++ language, members of class
 * templates have the same notions of specializations and instantiations that
 * templates do, so this routine treats them similarly.
 *
 * \param C A cursor that may be a specialization of a template or a member
 * of a template.
 *
 * \returns If the given cursor is a specialization or instantiation of a 
 * template or a member thereof, the template or member that it specializes or
 * from which it was instantiated. Otherwise, returns a NULL cursor.
 */
CXCursor clang_getSpecializedCursorTemplate(CXCursor C);

/**
 * Given a cursor that references something else, return the source range
 * covering that reference.
 *
 * \param C A cursor pointing to a member reference, a declaration reference, or
 * an operator call.
 * \param NameFlags A bitset with three independent flags: 
 * CXNameRange_WantQualifier, CXNameRange_WantTemplateArgs, and
 * CXNameRange_WantSinglePiece.
 * \param PieceIndex For contiguous names or when passing the flag 
 * CXNameRange_WantSinglePiece, only one piece with index 0 is 
 * available. When the CXNameRange_WantSinglePiece flag is not passed for a
 * non-contiguous names, this index can be used to retreive the individual
 * pieces of the name. See also CXNameRange_WantSinglePiece.
 *
 * \returns The piece of the name pointed to by the given cursor. If there is no
 * name, or if the PieceIndex is out-of-range, a null-cursor will be returned.
 */
CXSourceRange clang_getCursorReferenceNameRange(CXCursor C,
                                                uint NameFlags, 
                                                uint PieceIndex);

enum CXNameRefFlags {
  /**
   * Include the nested-name-specifier, e.g. Foo:: in x.Foo::y, in the
   * range.
   */
  CXNameRange_WantQualifier = 0x1,
  
  /**
   * Include the explicit template arguments, e.g. <int> in x.f<int>, in 
   * the range.
   */
  CXNameRange_WantTemplateArgs = 0x2,

  /**
   * If the name is non-contiguous, return the full spanning range.
   *
   * Non-contiguous names occur in Objective-C when a selector with two or more
   * parameters is used, or in C++ when using an operator:
   * \code
   * [object doSomething:here withValue:there]; // ObjC
   * return some_vector[1]; // C++
   * \endcode
   */
  CXNameRange_WantSinglePiece = 0x4
}
  
/**
 * @}
 */

/**
 * \defgroup CINDEX_LEX Token extraction and manipulation
 *
 * The routines in this group provide access to the tokens within a
 * translation unit, along with a semantic mapping of those tokens to
 * their corresponding cursors.
 *
 * @{
 */

/**
 * Describes a kind of token.
 */
enum CXTokenKind {
  /**
   * A token that contains some kind of punctuation.
   */
  CXToken_Punctuation,

  /**
   * A language keyword.
   */
  CXToken_Keyword,

  /**
   * An identifier (that is not a keyword).
   */
  CXToken_Identifier,

  /**
   * A numeric, string, or character literal.
   */
  CXToken_Literal,

  /**
   * A comment.
   */
  CXToken_Comment
}

/**
 * Describes a single preprocessing token.
 */
struct CXToken {
  uint int_data[4];
  void* ptr_data;
}

/**
 * Determine the kind of the given token.
 */
CXTokenKind clang_getTokenKind(CXToken);

/**
 * Determine the spelling of the given token.
 *
 * The spelling of a token is the textual representation of that token, e.g.,
 * the text of an identifier or keyword.
 */
CXString clang_getTokenSpelling(CXTranslationUnit, CXToken);

/**
 * Retrieve the source location of the given token.
 */
CXSourceLocation clang_getTokenLocation(CXTranslationUnit,
                                                       CXToken);

/**
 * Retrieve a source range that covers the given token.
 */
CXSourceRange clang_getTokenExtent(CXTranslationUnit, CXToken);

/**
 * Tokenize the source code described by the given range into raw
 * lexical tokens.
 *
 * \param TU the translation unit whose text is being tokenized.
 *
 * \param Range the source range in which text should be tokenized. All of the
 * tokens produced by tokenization will fall within this source range,
 *
 * \param Tokens this pointer will be set to point to the array of tokens
 * that occur within the given source range. The returned pointer must be
 * freed with clang_disposeTokens() before the translation unit is destroyed.
 *
 * \param NumTokens will be set to the number of tokens in the \c* Tokens
 * array.
 *
 */
void clang_tokenize(CXTranslationUnit TU, CXSourceRange Range,
                                   CXToken **Tokens, uint* NumTokens);

/**
 * Annotate the given set of tokens by providing cursors for each token
 * that can be mapped to a specific entity within the abstract syntax tree.
 *
 * This token-annotation routine is equivalent to invoking
 * clang_getCursor() for the source locations of each of the
 * tokens. The cursors provided are filtered, so that only those
 * cursors that have a direct correspondence to the token are
 * accepted. For example, given a function call \c f(x),
 * clang_getCursor() would provide the following cursors:
 *
 *   * when the cursor is over the 'f', a DeclRefExpr cursor referring to 'f'.
 *   * when the cursor is over the '(' or the ')', a CallExpr referring to 'f'.
 *   * when the cursor is over the 'x', a DeclRefExpr cursor referring to 'x'.
 *
 * Only the first and last of these cursors will occur within the
 * annotate, since the tokens "f" and "x' directly refer to a function
 * and a variable, respectively, but the parentheses are just a small
 * part of the full syntax of the function call expression, which is
 * not provided as an annotation.
 *
 * \param TU the translation unit that owns the given tokens.
 *
 * \param Tokens the set of tokens to annotate.
 *
 * \param NumTokens the number of tokens in \p Tokens.
 *
 * \param Cursors an array of \p NumTokens cursors, whose contents will be
 * replaced with the cursors corresponding to each token.
 */
void clang_annotateTokens(CXTranslationUnit TU,
                                         CXToken* Tokens, uint NumTokens,
                                         CXCursor* Cursors);

/**
 * Free the given set of tokens.
 */
void clang_disposeTokens(CXTranslationUnit TU,
                                        CXToken* Tokens, uint NumTokens);

/**
 * @}
 */

/**
 * \defgroup CINDEX_DEBUG Debugging facilities
 *
 * These routines are used for testing and debugging, only, and should not
 * be relied upon.
 *
 * @{
 */

/* for debug/testing */
CXString clang_getCursorKindSpelling(CXCursorKind Kind);
void clang_getDefinitionSpellingAndExtent(CXCursor,
                                          const char **startBuf,
                                          const char **endBuf,
                                          uint* startLine,
                                          uint* startColumn,
                                          uint* endLine,
                                          uint* endColumn);
void clang_enableStackTraces(void);
void clang_executeOnThread(void (*fn)(void*), void* user_data,
                                          uint stack_size);

/**
 * @}
 */

/**
 * \defgroup CINDEX_CODE_COMPLET Code completion
 *
 * Code completion involves taking an (incomplete) source file, along with
 * knowledge of where the user is actively editing that file, and suggesting
 * syntactically- and semantically-valid constructs that the user might want to
 * use at that particular point in the source code. These data structures and
 * routines provide support for code completion.
 *
 * @{
 */

/**
 * A semantic string that describes a code-completion result.
 *
 * A semantic string that describes the formatting of a code-completion
 * result as a single "template" of text that should be inserted into the
 * source buffer when a particular code-completion result is selected.
 * Each semantic string is made up of some number of "chunks", each of which
 * contains some text along with a description of what that text means, e.g.,
 * the name of the entity being referenced, whether the text chunk is part of
 * the template, or whether it is a "placeholder" that the user should replace
 * with actual code,of a specific kind. See \c CXCompletionChunkKind for a
 * description of the different kinds of chunks.
 */
alias void* CXCompletionString;

/**
 * A single result of code completion.
 */
struct CXCompletionResult {
  /**
   * The kind of entity that this completion refers to.
   *
   * The cursor kind will be a macro, keyword, or a declaration (one of the
   * *Decl cursor kinds), describing the entity that the completion is
   * referring to.
   *
   * \todo In the future, we would like to provide a full cursor, to allow
   * the client to extract additional information from declaration.
   */
  CXCursorKind CursorKind;

  /**
   * The code-completion string that describes how to insert this
   * code-completion result into the editing buffer.
   */
  CXCompletionString CompletionString;
}

/**
 * Describes a single piece of text within a code-completion string.
 *
 * Each "chunk" within a code-completion string (\c CXCompletionString) is
 * either a piece of text with a specific "kind" that describes how that text
 * should be interpreted by the client or is another completion string.
 */
enum CXCompletionChunkKind {
  /**
   * A code-completion string that describes "optional" text that
   * could be a part of the template (but is not required).
   *
   * The Optional chunk is the only kind of chunk that has a code-completion
   * string for its representation, which is accessible via
   * \c clang_getCompletionChunkCompletionString(). The code-completion string
   * describes an additional part of the template that is completely optional.
   * For example, optional chunks can be used to describe the placeholders for
   * arguments that match up with defaulted function parameters, e.g. given:
   *
   * \code
   * void f(int x, float y = 3.14, double z = 2.71828);
   * \endcode
   *
   * The code-completion string for this function would contain:
   *   - a TypedText chunk for "f".
   *   - a LeftParen chunk for "(".
   *   - a Placeholder chunk for "int x"
   *   - an Optional chunk containing the remaining defaulted arguments, e.g.,
   *       - a Comma chunk for ","
   *       - a Placeholder chunk for "float y"
   *       - an Optional chunk containing the last defaulted argument:
   *           - a Comma chunk for ","
   *           - a Placeholder chunk for "double z"
   *   - a RightParen chunk for ")"
   *
   * There are many ways to handle Optional chunks. Two simple approaches are:
   *   - Completely ignore optional chunks, in which case the template for the
   *     function "f" would only include the first parameter ("int x").
   *   - Fully expand all optional chunks, in which case the template for the
   *     function "f" would have all of the parameters.
   */
  CXCompletionChunk_Optional,
  /**
   * Text that a user would be expected to type to get this
   * code-completion result.
   *
   * There will be exactly one "typed text" chunk in a semantic string, which
   * will typically provide the spelling of a keyword or the name of a
   * declaration that could be used at the current code point. Clients are
   * expected to filter the code-completion results based on the text in this
   * chunk.
   */
  CXCompletionChunk_TypedText,
  /**
   * Text that should be inserted as part of a code-completion result.
   *
   * A "text" chunk represents text that is part of the template to be
   * inserted into user code should this particular code-completion result
   * be selected.
   */
  CXCompletionChunk_Text,
  /**
   * Placeholder text that should be replaced by the user.
   *
   * A "placeholder" chunk marks a place where the user should insert text
   * into the code-completion template. For example, placeholders might mark
   * the function parameters for a function declaration, to indicate that the
   * user should provide arguments for each of those parameters. The actual
   * text in a placeholder is a suggestion for the text to display before
   * the user replaces the placeholder with real code.
   */
  CXCompletionChunk_Placeholder,
  /**
   * Informative text that should be displayed but never inserted as
   * part of the template.
   *
   * An "informative" chunk contains annotations that can be displayed to
   * help the user decide whether a particular code-completion result is the
   * right option, but which is not part of the actual template to be inserted
   * by code completion.
   */
  CXCompletionChunk_Informative,
  /**
   * Text that describes the current parameter when code-completion is
   * referring to function call, message send, or template specialization.
   *
   * A "current parameter" chunk occurs when code-completion is providing
   * information about a parameter corresponding to the argument at the
   * code-completion point. For example, given a function
   *
   * \code
   * int add(int x, int y);
   * \endcode
   *
   * and the source code \c add(, where the code-completion point is after the
   * "(", the code-completion string will contain a "current parameter" chunk
   * for "int x", indicating that the current argument will initialize that
   * parameter. After typing further, to \c add(17, (where the code-completion
   * point is after the ","), the code-completion string will contain a
   * "current paremeter" chunk to "int y".
   */
  CXCompletionChunk_CurrentParameter,
  /**
   * A left parenthesis ('('), used to initiate a function call or
   * signal the beginning of a function parameter list.
   */
  CXCompletionChunk_LeftParen,
  /**
   * A right parenthesis (')'), used to finish a function call or
   * signal the end of a function parameter list.
   */
  CXCompletionChunk_RightParen,
  /**
   * A left bracket ('[').
   */
  CXCompletionChunk_LeftBracket,
  /**
   * A right bracket (']').
   */
  CXCompletionChunk_RightBracket,
  /**
   * A left brace ('{').
   */
  CXCompletionChunk_LeftBrace,
  /**
   * A right brace ('}').
   */
  CXCompletionChunk_RightBrace,
  /**
   * A left angle bracket ('<').
   */
  CXCompletionChunk_LeftAngle,
  /**
   * A right angle bracket ('>').
   */
  CXCompletionChunk_RightAngle,
  /**
   * A comma separator (',').
   */
  CXCompletionChunk_Comma,
  /**
   * Text that specifies the result type of a given result.
   *
   * This special kind of informative chunk is not meant to be inserted into
   * the text buffer. Rather, it is meant to illustrate the type that an
   * expression using the given completion string would have.
   */
  CXCompletionChunk_ResultType,
  /**
   * A colon (':').
   */
  CXCompletionChunk_Colon,
  /**
   * A semicolon (';').
   */
  CXCompletionChunk_SemiColon,
  /**
   * An '=' sign.
   */
  CXCompletionChunk_Equal,
  /**
   * Horizontal space (' ').
   */
  CXCompletionChunk_HorizontalSpace,
  /**
   * Vertical space ('\n'), after which it is generally a good idea to
   * perform indentation.
   */
  CXCompletionChunk_VerticalSpace
}

/**
 * Determine the kind of a particular chunk within a completion string.
 *
 * \param completion_string the completion string to query.
 *
 * \param chunk_number the 0-based index of the chunk in the completion string.
 *
 * \returns the kind of the chunk at the index \c chunk_number.
 */
CXCompletionChunkKind
clang_getCompletionChunkKind(CXCompletionString completion_string,
                             uint chunk_number);

/**
 * Retrieve the text associated with a particular chunk within a
 * completion string.
 *
 * \param completion_string the completion string to query.
 *
 * \param chunk_number the 0-based index of the chunk in the completion string.
 *
 * \returns the text associated with the chunk at index \c chunk_number.
 */
CXString
clang_getCompletionChunkText(CXCompletionString completion_string,
                             uint chunk_number);

/**
 * Retrieve the completion string associated with a particular chunk
 * within a completion string.
 *
 * \param completion_string the completion string to query.
 *
 * \param chunk_number the 0-based index of the chunk in the completion string.
 *
 * \returns the completion string associated with the chunk at index
 * \c chunk_number, or NULL if that chunk is not represented by a completion
 * string.
 */
CXCompletionString
clang_getCompletionChunkCompletionString(CXCompletionString completion_string,
                                         uint chunk_number);

/**
 * Retrieve the number of chunks in the given code-completion string.
 */
uint
clang_getNumCompletionChunks(CXCompletionString completion_string);

/**
 * Determine the priority of this code completion.
 *
 * The priority of a code completion indicates how likely it is that this 
 * particular completion is the completion that the user will select. The
 * priority is selected by various internal heuristics.
 *
 * \param completion_string The completion string to query.
 *
 * \returns The priority of this completion string. Smaller values indicate
 * higher-priority (more likely) completions.
 */
uint
clang_getCompletionPriority(CXCompletionString completion_string);
  
/**
 * Determine the availability of the entity that this code-completion
 * string refers to.
 *
 * \param completion_string The completion string to query.
 *
 * \returns The availability of the completion string.
 */
CXAvailabilityKind 
clang_getCompletionAvailability(CXCompletionString completion_string);

/**
 * Retrieve a completion string for an arbitrary declaration or macro
 * definition cursor.
 *
 * \param cursor The cursor to query.
 *
 * \returns A non-context-sensitive completion string for declaration and macro
 * definition cursors, or NULL for other kinds of cursors.
 */
CXCompletionString
clang_getCursorCompletionString(CXCursor cursor);
  
/**
 * Contains the results of code-completion.
 *
 * This data structure contains the results of code completion, as
 * produced by \c clang_codeCompleteAt(). Its contents must be freed by
 * \c clang_disposeCodeCompleteResults.
 */
struct CXCodeCompleteResults {
  /**
   * The code-completion results.
   */
  CXCompletionResult* Results;

  /**
   * The number of code-completion results stored in the
   * \c Results array.
   */
  uint NumResults;
}

/**
 * Flags that can be passed to \c clang_codeCompleteAt() to
 * modify its behavior.
 *
 * The enumerators in this enumeration can be bitwise-OR'd together to
 * provide multiple options to \c clang_codeCompleteAt().
 */
enum CXCodeComplete_Flags {
  /**
   * Whether to include macros within the set of code
   * completions returned.
   */
  CXCodeComplete_IncludeMacros = 0x01,

  /**
   * Whether to include code patterns for language constructs
   * within the set of code completions, e.g., for loops.
   */
  CXCodeComplete_IncludeCodePatterns = 0x02
}

/**
 * Bits that represent the context under which completion is occurring.
 *
 * The enumerators in this enumeration may be bitwise-OR'd together if multiple
 * contexts are occurring simultaneously.
 */
enum CXCompletionContext {
  /**
   * The context for completions is unexposed, as only Clang results
   * should be included. (This is equivalent to having no context bits set.)
   */
  CXCompletionContext_Unexposed = 0,
  
  /**
   * Completions for any possible type should be included in the results.
   */
  CXCompletionContext_AnyType = 1 << 0,
  
  /**
   * Completions for any possible value (variables, function calls, etc.)
   * should be included in the results.
   */
  CXCompletionContext_AnyValue = 1 << 1,
  /**
   * Completions for values that resolve to an Objective-C object should
   * be included in the results.
   */
  CXCompletionContext_ObjCObjectValue = 1 << 2,
  /**
   * Completions for values that resolve to an Objective-C selector
   * should be included in the results.
   */
  CXCompletionContext_ObjCSelectorValue = 1 << 3,
  /**
   * Completions for values that resolve to a C++ class type should be
   * included in the results.
   */
  CXCompletionContext_CXXClassTypeValue = 1 << 4,
  
  /**
   * Completions for fields of the member being accessed using the dot
   * operator should be included in the results.
   */
  CXCompletionContext_DotMemberAccess = 1 << 5,
  /**
   * Completions for fields of the member being accessed using the arrow
   * operator should be included in the results.
   */
  CXCompletionContext_ArrowMemberAccess = 1 << 6,
  /**
   * Completions for properties of the Objective-C object being accessed
   * using the dot operator should be included in the results.
   */
  CXCompletionContext_ObjCPropertyAccess = 1 << 7,
  
  /**
   * Completions for enum tags should be included in the results.
   */
  CXCompletionContext_EnumTag = 1 << 8,
  /**
   * Completions for union tags should be included in the results.
   */
  CXCompletionContext_UnionTag = 1 << 9,
  /**
   * Completions for struct tags should be included in the results.
   */
  CXCompletionContext_StructTag = 1 << 10,
  
  /**
   * Completions for C++ class names should be included in the results.
   */
  CXCompletionContext_ClassTag = 1 << 11,
  /**
   * Completions for C++ namespaces and namespace aliases should be
   * included in the results.
   */
  CXCompletionContext_Namespace = 1 << 12,
  /**
   * Completions for C++ nested name specifiers should be included in
   * the results.
   */
  CXCompletionContext_NestedNameSpecifier = 1 << 13,
  
  /**
   * Completions for Objective-C interfaces (classes) should be included
   * in the results.
   */
  CXCompletionContext_ObjCInterface = 1 << 14,
  /**
   * Completions for Objective-C protocols should be included in
   * the results.
   */
  CXCompletionContext_ObjCProtocol = 1 << 15,
  /**
   * Completions for Objective-C categories should be included in
   * the results.
   */
  CXCompletionContext_ObjCCategory = 1 << 16,
  /**
   * Completions for Objective-C instance messages should be included
   * in the results.
   */
  CXCompletionContext_ObjCInstanceMessage = 1 << 17,
  /**
   * Completions for Objective-C class messages should be included in
   * the results.
   */
  CXCompletionContext_ObjCClassMessage = 1 << 18,
  /**
   * Completions for Objective-C selector names should be included in
   * the results.
   */
  CXCompletionContext_ObjCSelectorName = 1 << 19,
  
  /**
   * Completions for preprocessor macro names should be included in
   * the results.
   */
  CXCompletionContext_MacroName = 1 << 20,
  
  /**
   * Natural language completions should be included in the results.
   */
  CXCompletionContext_NaturalLanguage = 1 << 21,
  
  /**
   * The current context is unknown, so set all contexts.
   */
  CXCompletionContext_Unknown = ((1 << 22) - 1)
}
  
/**
 * Returns a default set of code-completion options that can be
 * passed to\c clang_codeCompleteAt(). 
 */
uint clang_defaultCodeCompleteOptions(void);

/**
 * Perform code completion at a given location in a translation unit.
 *
 * This function performs code completion at a particular file, line, and
 * column within source code, providing results that suggest potential
 * code snippets based on the context of the completion. The basic model
 * for code completion is that Clang will parse a complete source file,
 * performing syntax checking up to the location where code-completion has
 * been requested. At that point, a special code-completion token is passed
 * to the parser, which recognizes this token and determines, based on the
 * current location in the C/Objective-C/C++ grammar and the state of
 * semantic analysis, what completions to provide. These completions are
 * returned via a new \c CXCodeCompleteResults structure.
 *
 * Code completion itself is meant to be triggered by the client when the
 * user types punctuation characters or whitespace, at which point the
 * code-completion location will coincide with the cursor. For example, if \c p
 * is a pointer, code-completion might be triggered after the "-" and then
 * after the ">" in \c p->. When the code-completion location is afer the ">",
 * the completion results will provide, e.g., the members of the struct that
 * "p" points to. The client is responsible for placing the cursor at the
 * beginning of the token currently being typed, then filtering the results
 * based on the contents of the token. For example, when code-completing for
 * the expression \c p->get, the client should provide the location just after
 * the ">" (e.g., pointing at the "g") to this code-completion hook. Then, the
 * client can filter the results based on the current token text ("get"), only
 * showing those results that start with "get". The intent of this interface
 * is to separate the relatively high-latency acquisition of code-completion
 * results from the filtering of results on a per-character basis, which must
 * have a lower latency.
 *
 * \param TU The translation unit in which code-completion should
 * occur. The source files for this translation unit need not be
 * completely up-to-date (and the contents of those source files may
 * be overridden via \p unsaved_files). Cursors referring into the
 * translation unit may be invalidated by this invocation.
 *
 * \param complete_filename The name of the source file where code
 * completion should be performed. This filename may be any file
 * included in the translation unit.
 *
 * \param complete_line The line at which code-completion should occur.
 *
 * \param complete_column The column at which code-completion should occur.
 * Note that the column should point just after the syntactic construct that
 * initiated code completion, and not in the middle of a lexical token.
 *
 * \param unsaved_files the Tiles that have not yet been saved to disk
 * but may be required for parsing or code completion, including the
 * contents of those files.  The contents and name of these files (as
 * specified by CXUnsavedFile) are copied when necessary, so the
 * client only needs to guarantee their validity until the call to
 * this function returns.
 *
 * \param num_unsaved_files The number of unsaved file entries in \p
 * unsaved_files.
 *
 * \param options Extra options that control the behavior of code
 * completion, expressed as a bitwise OR of the enumerators of the
 * CXCodeComplete_Flags enumeration. The 
 * \c clang_defaultCodeCompleteOptions() function returns a default set
 * of code-completion options.
 *
 * \returns If successful, a new \c CXCodeCompleteResults structure
 * containing code-completion results, which should eventually be
 * freed with \c clang_disposeCodeCompleteResults(). If code
 * completion fails, returns NULL.
 */
CINDEX_LINKAGE
CXCodeCompleteResults* clang_codeCompleteAt(CXTranslationUnit TU,
                                            const char* complete_filename,
                                            uint complete_line,
                                            uint complete_column,
                                            CXUnsavedFile* unsaved_files,
                                            uint num_unsaved_files,
                                            uint options);

/**
 * Sort the code-completion results in case-insensitive alphabetical 
 * order.
 *
 * \param Results The set of results to sort.
 * \param NumResults The number of results in \p Results.
 */
CINDEX_LINKAGE
void clang_sortCodeCompletionResults(CXCompletionResult* Results,
                                     uint NumResults);
  
/**
 * Free the given set of code-completion results.
 */
CINDEX_LINKAGE
void clang_disposeCodeCompleteResults(CXCodeCompleteResults* Results);
  
/**
 * Determine the number of diagnostics produced prior to the
 * location where code completion was performed.
 */
CINDEX_LINKAGE
uint clang_codeCompleteGetNumDiagnostics(CXCodeCompleteResults* Results);

/**
 * Retrieve a diagnostic associated with the given code completion.
 *
 * \param Result the code completion results to query.
 * \param Index the zero-based diagnostic number to retrieve.
 *
 * \returns the requested diagnostic. This diagnostic must be freed
 * via a call to \c clang_disposeDiagnostic().
 */
CINDEX_LINKAGE
CXDiagnostic clang_codeCompleteGetDiagnostic(CXCodeCompleteResults* Results,
                                             uint Index);

/**
 * Determines what compeltions are appropriate for the context
 * the given code completion.
 * 
 * \param Results the code completion results to query
 *
 * \returns the kinds of completions that are appropriate for use
 * along with the given code completion results.
 */
CINDEX_LINKAGE
c_ulong long clang_codeCompleteGetContexts(
                                                CXCodeCompleteResults* Results);

/**
 * Returns the cursor kind for the container for the current code
 * completion context. The container is only guaranteed to be set for
 * contexts where a container exists (i.e. member accesses or Objective-C
 * message sends); if there is not a container, this function will return
 * CXCursor_InvalidCode.
 *
 * \param Results the code completion results to query
 *
 * \param IsIncomplete on return, this value will be false if Clang has complete
 * information about the container. If Clang does not have complete
 * information, this value will be true.
 *
 * \returns the container kind, or CXCursor_InvalidCode if there is not a
 * container
 */
CINDEX_LINKAGE
CXCursorKind clang_codeCompleteGetContainerKind(
                                                 CXCodeCompleteResults* Results,
                                                     uint* IsIncomplete);

/**
 * Returns the USR for the container for the current code completion
 * context. If there is not a container for the current context, this
 * function will return the empty string.
 *
 * \param Results the code completion results to query
 *
 * \returns the USR for the container
 */
CINDEX_LINKAGE
CXString clang_codeCompleteGetContainerUSR(CXCodeCompleteResults* Results);
  
  
/**
 * Returns the currently-entered selector for an Objective-C message
 * send, formatted like "initWithFoo:bar:". Only guaranteed to return a
 * non-empty string for CXCompletionContext_ObjCInstanceMessage and
 * CXCompletionContext_ObjCClassMessage.
 *
 * \param Results the code completion results to query
 *
 * \returns the selector (or partial selector) that has been entered thus far
 * for an Objective-C message send.
 */
CINDEX_LINKAGE
CXString clang_codeCompleteGetObjCSelector(CXCodeCompleteResults* Results);
  
/**
 * @}
 */


/**
 * \defgroup CINDEX_MISC Miscellaneous utility functions
 *
 * @{
 */

/**
 * Return a version string, suitable for showing to a user, but not
 *        intended to be parsed (the format is not guaranteed to be stable).
 */
CXString clang_getClangVersion();

  
/**
 * Enable/disable crash recovery.
 *
 * \param Flag to indicate if crash recovery is enabled.  A non-zero value
 *        enables crash recovery, while 0 disables it.
 */
void clang_toggleCrashRecovery(uint isEnabled);
  
 /**
  * Visitor invoked for each file in a translation unit
  *        (used with clang_getInclusions()).
  *
  * This visitor function will be invoked by clang_getInclusions() for each
  * file included (either at the top-level or by #include directives) within
  * a translation unit.  The first argument is the file being included, and
  * the second and third arguments provide the inclusion stack.  The
  * array is sorted in order of immediate inclusion.  For example,
  * the first element refers to the location that included 'included_file'.
  */
alias void (*CXInclusionVisitor)(CXFile included_file,
                                   CXSourceLocation* inclusion_stack,
                                   uint include_len,
                                   CXClientData client_data);

/**
 * Visit the set of preprocessor inclusions in a translation unit.
 *   The visitor function is called with the provided data for every included
 *   file.  This does not include headers included by the PCH file (unless one
 *   is inspecting the inclusions in the PCH file itself).
 */
void clang_getInclusions(CXTranslationUnit tu,
                                        CXInclusionVisitor visitor,
                                        CXClientData client_data);

/**
 * @}
 */

/** \defgroup CINDEX_REMAPPING Remapping functions
 *
 * @{
 */

/**
 * A remapping of original source files and their translated files.
 */
alias void* CXRemapping;

/**
 * Retrieve a remapping.
 *
 * \param path the path that contains metadata about remappings.
 *
 * \returns the requested remapping. This remapping must be freed
 * via a call to \c clang_remap_dispose(). Can return NULL if an error occurred.
 */
CXRemapping clang_getRemappings(const char* path);

/**
 * Determine the number of remappings.
 */
uint clang_remap_getNumFiles(CXRemapping);

/**
 * Get the original and the associated filename from the remapping.
 * 
 * \param original If non-NULL, will be set to the original filename.
 *
 * \param transformed If non-NULL, will be set to the filename that the original
 * is associated with.
 */
void clang_remap_getFilenames(CXRemapping, uint index,
                                     CXString* original, CXString* transformed);

/**
 * Dispose the remapping.
 */
void clang_remap_dispose(CXRemapping);

/**
 * @}
 */

/**
 * @}
 */