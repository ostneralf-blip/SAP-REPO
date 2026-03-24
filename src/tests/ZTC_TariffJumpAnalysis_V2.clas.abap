"! @testing Z_I_TariffJumpAnalysis_V2
CLASS ztc_tariff_jump_analysis_v2 DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    "! OSQL test environment providing doubles for the underlying base tables.
    "! Declared class-level so it is shared across all test methods.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.

    CLASS-METHODS:
      "! Create the OSQL test environment once for the whole test class.
      class_setup  RAISING cx_static_check,
      "! Destroy the OSQL test environment after all tests have run.
      class_teardown.

    METHODS:
      "! Clear test-double tables before each test method.
      setup,
      "! Finished product and component share the same HS heading → no jump.
      test_no_jump_at_heading       FOR TESTING,
      "! Finished product and component have different HS headings → jump detected.
      test_jump_at_heading          FOR TESTING,
      "! Finished product and component share the same HS chapter → no jump.
      test_no_jump_at_chapter       FOR TESTING,
      "! Finished product and component have different HS chapters → jump detected.
      test_jump_at_chapter          FOR TESTING,
      "! Both commodity codes are empty → no jump should be flagged.
      test_empty_commodity_codes    FOR TESTING,
      "! Heading jump does NOT imply chapter jump (same chapter, diff heading).
      test_heading_jump_no_chapter_jump FOR TESTING.

ENDCLASS.


CLASS ztc_tariff_jump_analysis_v2 IMPLEMENTATION.

  METHOD class_setup.
    "  The test environment doubles the base tables read by Z_I_TariffJumpBase_V2.
    "  List every table / CDS view that is accessed by the dependency chain.
    go_env = cl_osql_test_environment=>create(
               i_dependency_list = VALUE #(
                 ( 'STPO' )
                 ( 'STKO' )
                 ( 'MARA' )
                 ( 'MARC' )
                 ( 'MAKT' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
  ENDMETHOD.


  "--------------------------------------------------------------------
  " Helper: insert a minimal, self-consistent set of BOM test records.
  "  fp_matnr  – finished-product material number
  "  co_matnr  – component material number
  "  fp_steuc  – commodity code of the finished product (MARC.STEUC)
  "  co_steuc  – commodity code of the component      (MARC.STEUC)
  "--------------------------------------------------------------------
  METHOD _insert_bom_record ##NEEDED.
    " (local helper – defined in locals_imp include)
  ENDMETHOD.


  METHOD test_no_jump_at_heading.
    " --- Arrange -----------------------------------------------------------
    " Same heading: 8471 (first 4 chars of each commodity code are identical)
    go_env->insert_test_data( VALUE stko_tab(
      ( stlnr = '0000000001' stlal = '01' stlty = 'M'
        matnr = 'FP_MATERIAL_A' werks = '1000' stlan = '1' ) ) ).

    go_env->insert_test_data( VALUE stpo_tab(
      ( stlnr = '0000000001' stlal = '01'
        posnr = '0010' idnrk = 'COMP_MATERIAL_A'
        menge = '1' meins = 'PC' postp = 'L'
        datuv = '19000101' datub = '99991231' ) ) ).

    go_env->insert_test_data( VALUE mara_tab(
      ( matnr = 'FP_MATERIAL_A'   mtart = 'FERT' matkl = 'A001' )
      ( matnr = 'COMP_MATERIAL_A' mtart = 'ROH'  matkl = 'B001' ) ) ).

    go_env->insert_test_data( VALUE marc_tab(
      ( matnr = 'FP_MATERIAL_A'   werks = '1000' steuc = '8471300000' )
      ( matnr = 'COMP_MATERIAL_A' werks = '1000' steuc = '8471800000' ) ) ).
    " Both start with '8471' → same heading, no jump expected.

    " --- Act ---------------------------------------------------------------
    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MATERIAL_A'
        AND Plant            = '1000'
      INTO @DATA(ls_result).

    " --- Assert ------------------------------------------------------------
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatheading
      exp = ''
      msg = 'Expected no tariff jump at heading level' ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatchapter
      exp = ''
      msg = 'Expected no tariff jump at chapter level' ).
  ENDMETHOD.


  METHOD test_jump_at_heading.
    " --- Arrange -----------------------------------------------------------
    " Different headings: 8471 vs 8473 → jump at heading, same chapter (84)
    go_env->insert_test_data( VALUE stko_tab(
      ( stlnr = '0000000002' stlal = '01' stlty = 'M'
        matnr = 'FP_MATERIAL_B' werks = '1000' stlan = '1' ) ) ).

    go_env->insert_test_data( VALUE stpo_tab(
      ( stlnr = '0000000002' stlal = '01'
        posnr = '0010' idnrk = 'COMP_MATERIAL_B'
        menge = '2' meins = 'PC' postp = 'L'
        datuv = '19000101' datub = '99991231' ) ) ).

    go_env->insert_test_data( VALUE mara_tab(
      ( matnr = 'FP_MATERIAL_B'   mtart = 'FERT' matkl = 'A001' )
      ( matnr = 'COMP_MATERIAL_B' mtart = 'ROH'  matkl = 'B001' ) ) ).

    go_env->insert_test_data( VALUE marc_tab(
      ( matnr = 'FP_MATERIAL_B'   werks = '1000' steuc = '8471300000' )
      ( matnr = 'COMP_MATERIAL_B' werks = '1000' steuc = '8473300000' ) ) ).
    " FP heading = 8471, Comp heading = 8473 → jump. Both chapter 84 → no chapter jump.

    " --- Act ---------------------------------------------------------------
    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MATERIAL_B'
        AND Plant            = '1000'
      INTO @DATA(ls_result).

    " --- Assert ------------------------------------------------------------
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatheading
      exp = 'X'
      msg = 'Expected tariff jump flag X at heading level' ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatchapter
      exp = ''
      msg = 'Expected no tariff jump at chapter level (same chapter 84)' ).
  ENDMETHOD.


  METHOD test_no_jump_at_chapter.
    " Same chapter AND same heading → both flags should be empty.
    go_env->insert_test_data( VALUE stko_tab(
      ( stlnr = '0000000003' stlal = '01' stlty = 'M'
        matnr = 'FP_MATERIAL_C' werks = '1000' stlan = '1' ) ) ).

    go_env->insert_test_data( VALUE stpo_tab(
      ( stlnr = '0000000003' stlal = '01'
        posnr = '0010' idnrk = 'COMP_MATERIAL_C'
        menge = '1' meins = 'EA' postp = 'L'
        datuv = '19000101' datub = '99991231' ) ) ).

    go_env->insert_test_data( VALUE mara_tab(
      ( matnr = 'FP_MATERIAL_C'   mtart = 'FERT' matkl = 'A001' )
      ( matnr = 'COMP_MATERIAL_C' mtart = 'ROH'  matkl = 'B001' ) ) ).

    go_env->insert_test_data( VALUE marc_tab(
      ( matnr = 'FP_MATERIAL_C'   werks = '1000' steuc = '3926900000' )
      ( matnr = 'COMP_MATERIAL_C' werks = '1000' steuc = '3926100000' ) ) ).
    " Both chapter 39, both heading 3926 → no jump at either level.

    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MATERIAL_C'
        AND Plant            = '1000'
      INTO @DATA(ls_result).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatheading
      exp = ''
      msg = 'No jump at heading expected' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatchapter
      exp = ''
      msg = 'No jump at chapter expected' ).
  ENDMETHOD.


  METHOD test_jump_at_chapter.
    " Different chapters → chapter jump (and heading jump) must both be flagged.
    go_env->insert_test_data( VALUE stko_tab(
      ( stlnr = '0000000004' stlal = '01' stlty = 'M'
        matnr = 'FP_MATERIAL_D' werks = '1000' stlan = '1' ) ) ).

    go_env->insert_test_data( VALUE stpo_tab(
      ( stlnr = '0000000004' stlal = '01'
        posnr = '0010' idnrk = 'COMP_MATERIAL_D'
        menge = '1' meins = 'KG' postp = 'L'
        datuv = '19000101' datub = '99991231' ) ) ).

    go_env->insert_test_data( VALUE mara_tab(
      ( matnr = 'FP_MATERIAL_D'   mtart = 'FERT' matkl = 'A001' )
      ( matnr = 'COMP_MATERIAL_D' mtart = 'ROH'  matkl = 'B001' ) ) ).

    go_env->insert_test_data( VALUE marc_tab(
      ( matnr = 'FP_MATERIAL_D'   werks = '1000' steuc = '6204310000' )
      ( matnr = 'COMP_MATERIAL_D' werks = '1000' steuc = '5209100000' ) ) ).
    " FP chapter 62, Comp chapter 52 → both chapter jump AND heading jump.

    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MATERIAL_D'
        AND Plant            = '1000'
      INTO @DATA(ls_result).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatheading
      exp = 'X'
      msg = 'Expected heading jump flag X' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatchapter
      exp = 'X'
      msg = 'Expected chapter jump flag X' ).
  ENDMETHOD.


  METHOD test_empty_commodity_codes.
    " Both commodity codes blank → both substring results '' = '' → no jump.
    go_env->insert_test_data( VALUE stko_tab(
      ( stlnr = '0000000005' stlal = '01' stlty = 'M'
        matnr = 'FP_MATERIAL_E' werks = '1000' stlan = '1' ) ) ).

    go_env->insert_test_data( VALUE stpo_tab(
      ( stlnr = '0000000005' stlal = '01'
        posnr = '0010' idnrk = 'COMP_MATERIAL_E'
        menge = '1' meins = 'PC' postp = 'L'
        datuv = '19000101' datub = '99991231' ) ) ).

    go_env->insert_test_data( VALUE mara_tab(
      ( matnr = 'FP_MATERIAL_E'   mtart = 'FERT' matkl = 'A001' )
      ( matnr = 'COMP_MATERIAL_E' mtart = 'ROH'  matkl = 'B001' ) ) ).
    " No MARC rows → LEFT OUTER JOIN → STEUC will be NULL/initial → substrings equal.

    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MATERIAL_E'
        AND Plant            = '1000'
      INTO @DATA(ls_result).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatheading
      exp = ''
      msg = 'Empty commodity codes: no heading jump expected' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatchapter
      exp = ''
      msg = 'Empty commodity codes: no chapter jump expected' ).
  ENDMETHOD.


  METHOD test_heading_jump_no_chapter_jump.
    " Same chapter (84) but different headings (8471 vs 8473).
    " → TariffJumpAtHeading = 'X', TariffJumpAtChapter = ''.
    " (Duplicate of test_jump_at_heading; kept as explicit regression guard.)
    go_env->insert_test_data( VALUE stko_tab(
      ( stlnr = '0000000006' stlal = '01' stlty = 'M'
        matnr = 'FP_MATERIAL_F' werks = '2000' stlan = '1' ) ) ).

    go_env->insert_test_data( VALUE stpo_tab(
      ( stlnr = '0000000006' stlal = '01'
        posnr = '0010' idnrk = 'COMP_MATERIAL_F'
        menge = '1' meins = 'PC' postp = 'L'
        datuv = '19000101' datub = '99991231' ) ) ).

    go_env->insert_test_data( VALUE mara_tab(
      ( matnr = 'FP_MATERIAL_F'   mtart = 'FERT' matkl = 'A001' )
      ( matnr = 'COMP_MATERIAL_F' mtart = 'ROH'  matkl = 'B001' ) ) ).

    go_env->insert_test_data( VALUE marc_tab(
      ( matnr = 'FP_MATERIAL_F'   werks = '2000' steuc = '8471300000' )
      ( matnr = 'COMP_MATERIAL_F' werks = '2000' steuc = '8473300000' ) ) ).

    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MATERIAL_F'
        AND Plant            = '2000'
      INTO @DATA(ls_result).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatheading
      exp = 'X'
      msg = 'Heading jump must be flagged when headings differ' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatchapter
      exp = ''
      msg = 'Chapter jump must NOT be flagged when chapters are equal' ).
  ENDMETHOD.

ENDCLASS.
