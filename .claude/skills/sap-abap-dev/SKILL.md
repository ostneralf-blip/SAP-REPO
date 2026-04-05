---
name: sap-abap-dev
description: SAP ABAP development skill. Use when the user wants to write, review, refactor, or debug ABAP code including classes, function modules, reports, BAPIs, enhancements, and unit tests. Also covers ABAP Git (abapGit) workflows, code push/pull, and transport management.
---

# SAP ABAP Development Skill

Help users develop, review, and maintain ABAP code in SAP systems. This skill covers classic ABAP, ABAP OO, RESTful Application Programming Model (RAP), and abapGit-based workflows.

## Workflow

Make a todo list for all the tasks in this workflow and work on them one after another.

### 1. Understand the Context

Before writing or modifying ABAP code:
- Check for existing objects: reports, classes, function modules, BAPIs, enhancement spots
- Read any relevant ABAP code already in the repo (`.abap`, `.xml` abapGit files)
- Identify the SAP release target (check `package.json`, `.abapgit.xml`, or ask the user)
- Identify whether the object lives in a transport-managed system (DEV → QAS → PRD)

### 2. Coding Standards

Follow these ABAP best practices:

**Naming conventions:**
- Customer namespace prefix: `Z` or `Y` (e.g. `ZCL_MY_CLASS`, `ZFM_MY_FUNC`)
- Local variables: `lv_`, `ls_`, `lt_`, `lo_`, `lr_` (value, structure, table, object, reference)
- Global/class attributes: `mv_`, `ms_`, `mt_`, `mo_`, `mr_`
- Parameters: `iv_`, `is_`, `it_`, `io_`, `ir_`, `ev_`, `es_`, `et_`, `eo_`, `er_`, `cv_`, `cs_`, `ct_`
- Constants: `gc_`, `lc_`
- Types: `ty_`, `gty_`

**Code quality:**
- Prefer ABAP OO over procedural; avoid `FORM`/`PERFORM` in new code
- Use `DATA(...) = ...` inline declarations (ABAP 7.40+)
- Use `FINAL(...)` for read-only inline declarations (ABAP 7.56+)
- Use string templates `` |Hello { lv_name }| `` instead of `CONCATENATE`
- Use `VALUE #(...)` and `CORRESPONDING #(...)` constructors
- Avoid `SELECT *`; always specify columns
- Use `@DATA(lt_result)` in inline `SELECT` into declarations
- Prefer `LOOP AT ... INTO DATA(ls_row)` over `READ TABLE`
- Use class-based exceptions (`CX_*`) instead of `SY-SUBRC` checks where possible
- Write ABAP Unit tests for all business logic (local test classes `LTCL_*`)

### 3. Common Patterns

#### ABAP Class skeleton
```abap
CLASS zcl_my_class DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS:
      constructor
        IMPORTING
          iv_param TYPE string,
      do_something
        RETURNING
          VALUE(rv_result) TYPE string
        RAISING
          cx_sy_conversion_error.

  PRIVATE SECTION.
    DATA mv_param TYPE string.

ENDCLASS.

CLASS zcl_my_class IMPLEMENTATION.

  METHOD constructor.
    mv_param = iv_param.
  ENDMETHOD.

  METHOD do_something.
    rv_result = |Result: { mv_param }|.
  ENDMETHOD.

ENDCLASS.
```

#### ABAP Unit Test skeleton
```abap
CLASS ltcl_my_class DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_my_class.  " CUT = Class Under Test

    METHODS:
      setup,
      test_do_something FOR TESTING.

ENDCLASS.

CLASS ltcl_my_class IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_my_class( iv_param = 'test' ).
  ENDMETHOD.

  METHOD test_do_something.
    DATA(lv_result) = mo_cut->do_something( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_result
      exp = 'Result: test'
    ).
  ENDMETHOD.

ENDCLASS.
```

#### SELECT with inline declaration
```abap
SELECT matnr, maktx
  FROM makt
  WHERE spras = @sy-langu
    AND matnr IN @lt_matnrs
  INTO TABLE @DATA(lt_descriptions).
```

#### Exception handling
```abap
TRY.
    DATA(lv_result) = mo_obj->process( iv_input ).
  CATCH cx_my_exception INTO DATA(lx_exc).
    RAISE EXCEPTION NEW cx_wrapper(
      previous = lx_exc
      textid   = cx_wrapper=>processing_error
    ).
ENDTRY.
```

### 4. abapGit Workflow

When the project uses abapGit (`.abapgit.xml` present):

**Repository structure:**
```
src/
  zcl_my_class.clas.abap          " Class implementation
  zcl_my_class.clas.locals_imp.abap  " Local classes (test classes go here)
  zcl_my_class.clas.xml            " Class metadata
  zmy_report.prog.abap             " Report
  zmy_report.prog.xml              " Report metadata
  package.devc.xml                 " Package definition
.abapgit.xml                       " abapGit config
```

**Typical abapGit commands (run in ABAP system via SE38 or ADT):**
- Pull: sync Git → SAP system
- Push: sync SAP system → Git
- Diff: compare local vs remote

### 5. RAP (RESTful Application Programming Model)

For RAP-based development:
- Business Object (BO) = CDS view entity + behavior definition + behavior implementation
- Use `BDEF` (Behavior Definition) for managed/unmanaged providers
- Use `ABP_` prefix for behavior pool classes
- Implement `VALIDATE`, `DETERMINE`, `ACTION` methods in behavior implementation

```abap
" Behavior implementation handler
CLASS lhc_my_entity DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validate_data FOR VALIDATE ON SAVE
      IMPORTING keys FOR my_entity~ValidateData.
ENDCLASS.
```

### 6. Validate Changes

Before committing:
- Ensure syntax is correct (no obvious ABAP syntax errors)
- Check that all referenced data elements, domains, and types exist
- Confirm unit tests cover the changed logic
- Verify transport object assignments if applicable

### 7. Commit and Push

Use meaningful commit messages:
```
feat(ZCL_MY_CLASS): add input validation for material number

- Add method VALIDATE_MATNR
- Raise ZCX_INVALID_MATERIAL when MATNR is initial or not 18 chars
- Add LTCL_MY_CLASS unit tests for validation logic
```

## Wrap Up

Provide a summary including:
- Objects created or modified (class, report, FM, etc.)
- Key design decisions (OO vs procedural, exception strategy, etc.)
- Unit test coverage added
- abapGit push/pull steps needed to sync with the SAP system
- Any transport requests that need to be released
