"! @testing Z_I_TariffJumpAnalysis_V2
CLASS ztc_tariff_jump_analysis_v2 DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    "! OSQL test environment providing doubles for the CDS views and table
    "! consumed by Z_I_TariffJumpBase_V2 (and thus Z_I_TariffJumpAnalysis_V2).
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.

    CLASS-METHODS:
      "! Create the OSQL test environment once for the whole test class.
      class_setup  RAISING cx_static_check,
      "! Destroy the OSQL test environment after all tests have run.
      class_teardown.

    METHODS:
      "! Clear test-double tables before each test method.
      setup,

      "--------------------------------------------------------------------
      " Helper: insert one self-consistent BOM test scenario.
      "   iv_bom_id   – unique BOM number (padded, e.g. '00000001')
      "   iv_fp_mat   – finished-product material number
      "   iv_comp_mat – component material number
      "   iv_plant    – plant
      "   iv_fp_stawn – commodity code for FP  (MARC.STAWN, CHAR 9, may be '')
      "   iv_co_stawn – commodity code for Comp(MARC.STAWN, CHAR 9, may be '')
      "--------------------------------------------------------------------
      _insert_bom_scenario
        IMPORTING
          iv_bom_id   TYPE c
          iv_fp_mat   TYPE c
          iv_comp_mat TYPE c
          iv_plant    TYPE c
          iv_fp_stawn TYPE c DEFAULT ''
          iv_co_stawn TYPE c DEFAULT '',

      "! Finished product and component share the same HS heading → no jump.
      test_no_jump_at_heading           FOR TESTING,
      "! Finished product and component have different HS headings → jump detected.
      test_jump_at_heading              FOR TESTING,
      "! Finished product and component share the same HS chapter → no jump.
      test_no_jump_at_chapter           FOR TESTING,
      "! Finished product and component have different HS chapters → jump detected.
      test_jump_at_chapter              FOR TESTING,
      "! Both STAWN fields are blank → substrings equal '' = '' → no jump.
      test_empty_commodity_codes        FOR TESTING,
      "! Same chapter (84) but different heading → heading 'X', chapter ''.
      test_heading_jump_no_chapter_jump FOR TESTING.

ENDCLASS.


CLASS ztc_tariff_jump_analysis_v2 IMPLEMENTATION.

  METHOD class_setup.
    "  Double every entity in the dependency chain of Z_I_TariffJumpBase_V2:
    "    I_BILLOFMATERIALITEM  – BOM items (released CDS view)
    "    I_MAST                – BOM/material/plant link (released CDS view)
    "    I_PRODUCT             – material master general data (released CDS view)
    "    I_PRODUCTDESCRIPTION  – material descriptions (released CDS view)
    "    MARC                  – plant-level data incl. STAWN commodity code
    go_env = cl_osql_test_environment=>create(
               i_dependency_list = VALUE #(
                 ( 'I_BILLOFMATERIALITEM' )
                 ( 'I_MAST' )
                 ( 'I_PRODUCT' )
                 ( 'I_PRODUCTDESCRIPTION' )
                 ( 'MARC' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
  ENDMETHOD.


  METHOD _insert_bom_scenario.
    "--------------------------------------------------------------------
    " I_BillOfMaterialItem – one stock item (category 'L') per BOM.
    " BillOfMaterialItemNodeNumber is the unique node key used by the
    " analysis view as a key field.
    "--------------------------------------------------------------------
    DATA lt_bom_items TYPE STANDARD TABLE OF i_billofmaterialitem
                      WITH DEFAULT KEY.
    lt_bom_items = VALUE #(
      ( BillOfMaterial              = iv_bom_id
        BillOfMaterialCategory      = 'M'
        BillOfMaterialItemNodeNumber = '0000000001'
        BillOfMaterialItemNumber    = '0010'
        BillOfMaterialComponent     = iv_comp_mat
        BillOfMaterialItemCategory  = 'L'       " required by WHERE clause
        BillOfMaterialItemQuantity  = '1'
        BillOfMaterialItemUnit      = 'PC'
        ValidityStartDate           = '19000101'
        ValidityEndDate             = '99991231' ) ).
    go_env->insert_test_data( lt_bom_items ).

    "--------------------------------------------------------------------
    " I_Mast – links BOM to finished product + plant.
    " BillOfMaterialVariantUsage = '1' is required by the WHERE clause.
    "--------------------------------------------------------------------
    DATA lt_mast TYPE STANDARD TABLE OF i_mast WITH DEFAULT KEY.
    lt_mast = VALUE #(
      ( BillOfMaterial             = iv_bom_id
        BillOfMaterialCategory     = 'M'
        Material                   = iv_fp_mat
        Plant                      = iv_plant
        BillOfMaterialVariantUsage = '1' ) ).  " required by WHERE clause
    go_env->insert_test_data( lt_mast ).

    "--------------------------------------------------------------------
    " I_Product – material master for FP and component.
    "--------------------------------------------------------------------
    DATA lt_products TYPE STANDARD TABLE OF i_product WITH DEFAULT KEY.
    lt_products = VALUE #(
      ( Product      = iv_fp_mat   ProductType = 'FERT' ProductGroup = 'A001' )
      ( Product      = iv_comp_mat ProductType = 'ROH'  ProductGroup = 'B001' ) ).
    go_env->insert_test_data( lt_products ).

    "--------------------------------------------------------------------
    " I_ProductDescription – FP description (inner join: required).
    "                        Component description (left outer: optional).
    "--------------------------------------------------------------------
    DATA lt_desc TYPE STANDARD TABLE OF i_productdescription WITH DEFAULT KEY.
    lt_desc = VALUE #(
      ( Product = iv_fp_mat   Language = 'E'
        ProductDescription = 'Finished Product Test' )
      ( Product = iv_comp_mat Language = 'E'
        ProductDescription = 'Component Test' ) ).
    go_env->insert_test_data( lt_desc ).

    "--------------------------------------------------------------------
    " MARC – plant data with commodity code (STAWN, CHAR 9).
    " Both FP and component use inner join, so both rows are required;
    " passing '' for stawn simulates a material without a commodity code.
    "--------------------------------------------------------------------
    DATA lt_marc TYPE STANDARD TABLE OF marc WITH DEFAULT KEY.
    lt_marc = VALUE #(
      ( matnr = iv_fp_mat   werks = iv_plant stawn = iv_fp_stawn )
      ( matnr = iv_comp_mat werks = iv_plant stawn = iv_co_stawn ) ).
    go_env->insert_test_data( lt_marc ).
  ENDMETHOD.


  METHOD test_no_jump_at_heading.
    " Same heading: 8471 (first 4 chars identical) → both flags must be ''.
    " STAWN is CHAR 9, e.g. '847130000' (HS: 8471.30) and '847180000' (HS: 8471.80).
    _insert_bom_scenario(
      iv_bom_id   = '00000001'
      iv_fp_mat   = 'FP_MAT_A'
      iv_comp_mat = 'CO_MAT_A'
      iv_plant    = '1000'
      iv_fp_stawn = '847130000'
      iv_co_stawn = '847180000' ).   " heading: 8471 = 8471 → no jump

    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MAT_A'
        AND Plant            = '1000'
      INTO @DATA(ls_result).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatheading
      exp = ''
      msg = 'Same heading 8471: no heading jump expected' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatchapter
      exp = ''
      msg = 'Same chapter 84: no chapter jump expected' ).
  ENDMETHOD.


  METHOD test_jump_at_heading.
    " Different headings (8471 vs 8473), same chapter (84).
    " → TariffJumpAtHeading = 'X', TariffJumpAtChapter = ''.
    _insert_bom_scenario(
      iv_bom_id   = '00000002'
      iv_fp_mat   = 'FP_MAT_B'
      iv_comp_mat = 'CO_MAT_B'
      iv_plant    = '1000'
      iv_fp_stawn = '847130000'
      iv_co_stawn = '847330000' ).   " FP: 8471, Comp: 8473, both chapter 84

    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MAT_B'
        AND Plant            = '1000'
      INTO @DATA(ls_result).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatheading
      exp = 'X'
      msg = 'Different headings 8471/8473: heading jump expected' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatchapter
      exp = ''
      msg = 'Same chapter 84: no chapter jump expected' ).
  ENDMETHOD.


  METHOD test_no_jump_at_chapter.
    " Same heading AND chapter (3926 / 39) → both flags must be ''.
    _insert_bom_scenario(
      iv_bom_id   = '00000003'
      iv_fp_mat   = 'FP_MAT_C'
      iv_comp_mat = 'CO_MAT_C'
      iv_plant    = '1000'
      iv_fp_stawn = '392690000'
      iv_co_stawn = '392610000' ).   " both heading 3926, chapter 39

    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MAT_C'
        AND Plant            = '1000'
      INTO @DATA(ls_result).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatheading
      exp = ''
      msg = 'Same heading 3926: no heading jump expected' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatchapter
      exp = ''
      msg = 'Same chapter 39: no chapter jump expected' ).
  ENDMETHOD.


  METHOD test_jump_at_chapter.
    " Different chapters (62 vs 52) → both heading and chapter flags must be 'X'.
    _insert_bom_scenario(
      iv_bom_id   = '00000004'
      iv_fp_mat   = 'FP_MAT_D'
      iv_comp_mat = 'CO_MAT_D'
      iv_plant    = '1000'
      iv_fp_stawn = '620431000'
      iv_co_stawn = '520910000' ).   " FP chapter 62, Comp chapter 52

    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MAT_D'
        AND Plant            = '1000'
      INTO @DATA(ls_result).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatheading
      exp = 'X'
      msg = 'Different headings 6204/5209: heading jump expected' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatchapter
      exp = ''
      msg = 'Different chapters 62/52: chapter jump expected' ).
  ENDMETHOD.


  METHOD test_empty_commodity_codes.
    " Both STAWN = '' → substring(1,4) = '' = '' → no jump at either level.
    " NOTE: _FPPlant and _CompPlant are inner joins in Z_I_TariffJumpBase_V2,
    " so MARC rows MUST exist (with blank stawn) for the BOM item to appear.
    _insert_bom_scenario(
      iv_bom_id   = '00000005'
      iv_fp_mat   = 'FP_MAT_E'
      iv_comp_mat = 'CO_MAT_E'
      iv_plant    = '1000'
      iv_fp_stawn = ''             " blank → FPTariffHeading / Chapter = ''
      iv_co_stawn = '' ).          " blank → CompTariffHeading / Chapter = ''

    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MAT_E'
        AND Plant            = '1000'
      INTO @DATA(ls_result).

    cl_abap_unit_assert=>assert_subrc(
      act = sy-subrc
      exp = 0
      msg = 'Row must be found even when STAWN is blank (MARC rows exist)' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatheading
      exp = ''
      msg = 'Blank STAWN: no heading jump expected' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-tariffjumpatchapter
      exp = ''
      msg = 'Blank STAWN: no chapter jump expected' ).
  ENDMETHOD.


  METHOD test_heading_jump_no_chapter_jump.
    " Same chapter (84) but different headings (8471 vs 8473).
    " Explicit regression guard: heading 'X', chapter ''.
    _insert_bom_scenario(
      iv_bom_id   = '00000006'
      iv_fp_mat   = 'FP_MAT_F'
      iv_comp_mat = 'CO_MAT_F'
      iv_plant    = '2000'
      iv_fp_stawn = '847130000'
      iv_co_stawn = '847330000' ).

    SELECT SINGLE TariffJumpAtHeading, TariffJumpAtChapter
      FROM Z_I_TariffJumpAnalysis_V2
      WHERE FinishedProduct = 'FP_MAT_F'
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
