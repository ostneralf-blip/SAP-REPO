@AbapCatalog.sqlViewName: 'ZVCTARIFFJ2'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Tariff Jump Analysis V2 – Analytical Cube'

/*
  ══════════════════════════════════════════════════════════════════════
  SAP VDM layer  : Consumption (C_*)
  Analytics type : CUBE  → directly queryable via InA service;
                   consumable by SAP Analytics Cloud, Fiori Analytical
                   Apps and embedded BW queries without an intermediate
                   query view.

  Source         : Z_I_TariffJumpAnalysis_V2  (interface / BO layer)

  Measure        : ComponentQuantity  (SUM, linked to ComponentUoM)
  Dimensions     : all remaining fields; TariffJumpAtHeading /
                   TariffJumpAtChapter act as boolean characteristics
                   ideal for slice-and-dice analysis.

  Associations   : _FinishedProduct, _Component → I_Product
                   _Plant                        → I_Plant
                   These expose the full dimension context to the
                   analytical engine for drilldown and text resolution.

  Extensibility  : @Metadata.allowExtensions: true allows key-user
                   tools (Custom Fields & Logic) to append fields
                   without modifying this view.
  ══════════════════════════════════════════════════════════════════════
*/

@Analytics.dataCategory: #CUBE
@VDM.viewType:           #CONSUMPTION
@Metadata.allowExtensions: true

@ObjectModel.usageType: {
  serviceQuality: #A,
  sizeCategory:   #L,
  dataClass:      #MIXED
}

define view Z_C_TariffJumpAnalysis_V2
  as select from Z_I_TariffJumpAnalysis_V2 as _Ana

  -- ── Dimension associations ─────────────────────────────────────────
  association [0..1] to I_Product as _FinishedProduct
    on _FinishedProduct.Product = _Ana.FinishedProduct

  association [0..1] to I_Product as _Component
    on _Component.Product = _Ana.ComponentMaterial

  association [0..1] to I_Plant as _Plant
    on _Plant.Plant = _Ana.Plant

{
  // ── 1. Organizational keys ──────────────────────────────────────────

  @EndUserText.label:    'Finished Product'
  @ObjectModel.text.element: ['FinishedProductDescription']
  @AnalyticsDetails.query.display: #KEY_TEXT
  @UI.selectionField:    [{ position: 10 }]
  @UI.lineItem:          [{ position: 10, label: 'Finished Product' }]
  key _Ana.FinishedProduct,

  @EndUserText.label:    'Plant'
  @AnalyticsDetails.query.display: #KEY_TEXT
  @Consumption.filter:   { selectionType: #SINGLE, multipleSelections: true, mandatory: false }
  @UI.selectionField:    [{ position: 20 }]
  @UI.lineItem:          [{ position: 20, label: 'Plant' }]
  key _Ana.Plant,

  @EndUserText.label:    'BOM Number'
  @AnalyticsDetails.query.display: #KEY
  key _Ana.BomNumber,

  @EndUserText.label:    'BOM Item Node Number'
  @AnalyticsDetails.query.display: #KEY
  key _Ana.BomItemNodeNumber,

  // ── 2. BOM item identification ──────────────────────────────────────

  @EndUserText.label:    'BOM Item Number'
  @AnalyticsDetails.query.display: #KEY
  _Ana.BomItemNumber,

  @EndUserText.label:    'Component'
  @ObjectModel.text.element: ['ComponentDescription']
  @AnalyticsDetails.query.display: #KEY_TEXT
  @UI.lineItem:          [{ position: 30, label: 'Component' }]
  _Ana.ComponentMaterial,

  // ── 3. Descriptions (text elements – not standalone columns) ────────

  @EndUserText.label:    'Finished Product Description'
  @Semantics.text:       true
  @UI.lineItem:          [{ position: 40, label: 'FP Description' }]
  _Ana.FinishedProductDescription,

  @EndUserText.label:    'Component Description'
  @Semantics.text:       true
  @UI.lineItem:          [{ position: 50, label: 'Component Description' }]
  _Ana.ComponentDescription,

  // ── 4. Material classification ──────────────────────────────────────

  @EndUserText.label:    'FP Material Type'
  @AnalyticsDetails.query.display: #KEY_TEXT
  _Ana.FinishedProductType,

  @EndUserText.label:    'Component Material Type'
  @AnalyticsDetails.query.display: #KEY_TEXT
  _Ana.ComponentMaterialType,

  @EndUserText.label:    'FP Material Group'
  @AnalyticsDetails.query.display: #KEY_TEXT
  @Consumption.filter:   { selectionType: #RANGE, multipleSelections: true, mandatory: false }
  @UI.selectionField:    [{ position: 30 }]
  _Ana.FinishedProductMaterialGroup,

  @EndUserText.label:    'Component Material Group'
  @AnalyticsDetails.query.display: #KEY_TEXT
  @Consumption.filter:   { selectionType: #RANGE, multipleSelections: true, mandatory: false }
  _Ana.ComponentMaterialGroup,

  // ── 5. Trade compliance – commodity codes ───────────────────────────

  @EndUserText.label:    'FP Commodity Code (HS)'
  @AnalyticsDetails.query.display: #KEY
  _Ana.FinishedProductCommodityCode,

  @EndUserText.label:    'Component Commodity Code (HS)'
  @AnalyticsDetails.query.display: #KEY
  _Ana.ComponentCommodityCode,

  // ── 6. Trade compliance – tariff headings (HS-4) ────────────────────

  @EndUserText.label:    'FP Tariff Heading (HS4)'
  @AnalyticsDetails.query.display: #KEY
  @Consumption.filter:   { selectionType: #RANGE, multipleSelections: true, mandatory: false }
  @UI.selectionField:    [{ position: 40 }]
  _Ana.FPTariffHeading,

  @EndUserText.label:    'Component Tariff Heading (HS4)'
  @AnalyticsDetails.query.display: #KEY
  @Consumption.filter:   { selectionType: #RANGE, multipleSelections: true, mandatory: false }
  _Ana.CompTariffHeading,

  // ── 7. Trade compliance – tariff chapters (HS-2) ────────────────────

  @EndUserText.label:    'FP Tariff Chapter (HS2)'
  @AnalyticsDetails.query.display: #KEY
  _Ana.FPTariffChapter,

  @EndUserText.label:    'Component Tariff Chapter (HS2)'
  @AnalyticsDetails.query.display: #KEY
  _Ana.CompTariffChapter,

  // ── 8. Key analytical indicators ────────────────────────────────────
  //    'X' = jump exists, '' = no jump.
  //    Annotated with selectionField so analysts can filter to items
  //    that require preferential-origin review in one click.

  @EndUserText.label:    'Tariff Jump at HS Heading'
  @AnalyticsDetails.query.display: #KEY
  @Consumption.filter:   { selectionType: #SINGLE, multipleSelections: true, mandatory: false }
  @UI.selectionField:    [{ position: 50 }]
  @UI.lineItem:          [{ position: 60, label: 'Jump at Heading' }]
  _Ana.TariffJumpAtHeading,

  @EndUserText.label:    'Tariff Jump at HS Chapter'
  @AnalyticsDetails.query.display: #KEY
  @Consumption.filter:   { selectionType: #SINGLE, multipleSelections: true, mandatory: false }
  @UI.selectionField:    [{ position: 60 }]
  @UI.lineItem:          [{ position: 70, label: 'Jump at Chapter' }]
  _Ana.TariffJumpAtChapter,

  // ── 9. Measure ───────────────────────────────────────────────────────
  //    ComponentQuantity is the single numeric fact in this cube.
  //    @DefaultAggregation: #SUM tells the analytical engine how to
  //    roll up values when dimensions are removed from the query axis.

  @EndUserText.label:    'Component Quantity'
  @DefaultAggregation:   #SUM
  @Semantics.quantity.unitOfMeasure: 'ComponentUoM'
  @UI.lineItem:          [{ position: 80, label: 'Quantity' }]
  _Ana.ComponentQuantity,

  @EndUserText.label:    'Unit of Measure'
  @Semantics.unitOfMeasure: true
  _Ana.ComponentUoM,

  // ── 10. BOM metadata ─────────────────────────────────────────────────

  @EndUserText.label:    'BOM Item Category'
  @AnalyticsDetails.query.display: #KEY_TEXT
  _Ana.BomItemCategory,

  @EndUserText.label:    'BOM Usage'
  @AnalyticsDetails.query.display: #KEY_TEXT
  @Consumption.filter:   { selectionType: #SINGLE, multipleSelections: true, mandatory: false }
  _Ana.BomUsage,

  // ── 11. Validity (date dimensions) ───────────────────────────────────

  @EndUserText.label:    'Valid From'
  @Semantics.businessDate.from: true
  _Ana.ValidityStartDate,

  @EndUserText.label:    'Valid To'
  @Semantics.businessDate.to: true
  _Ana.ValidityEndDate,

  // ── 12. Dimension navigation (exposed to analytical engine) ──────────

  _FinishedProduct,
  _Component,
  _Plant
}
