@AbapCatalog.sqlViewName: 'ZVTARIFFJMP2'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Tariff Jump Analysis V2'

/*
  Tariff Jump Analysis view.
  Consumes Z_I_TariffJumpBase_V2 and adds the calculated tariff-jump
  indicators TariffJumpAtHeading and TariffJumpAtChapter.

  A "tariff jump" occurs when the finished product and its component
  fall under different HS headings (4-digit) or HS chapters (2-digit).
  The flags follow the SAP convention: 'X' = true, '' = false.

  Known limitations:
  - All BOM alternatives are included; filter on BomAlternative if needed.
  - No validity-date filtering; apply WHERE ValidityStartDate / ValidityEndDate
    in the consuming application or Fiori query.
*/

define view Z_I_TariffJumpAnalysis_V2
  as select from Z_I_TariffJumpBase_V2 as _Base
{
  key _Base.FinishedProduct,

      @Consumption.filter: { selectionType: #SINGLE, multipleSelections: true }
  key _Base.Plant,

  key _Base.BomNumber,
  key _Base.BomItemNodeNumber,
      _Base.BomItemNumber,
      _Base.ComponentMaterial,

      _Base.FinishedProductDescription,
      _Base.ComponentDescription,
      _Base.FinishedProductType,
      _Base.ComponentMaterialType,

      @Consumption.filter: { selectionType: #RANGE, multipleSelections: true }
      _Base.FinishedProductMaterialGroup,

      @Consumption.filter: { selectionType: #RANGE, multipleSelections: true }
      _Base.ComponentMaterialGroup,

      _Base.FinishedProductCommodityCode,
      _Base.ComponentCommodityCode,

      @Consumption.filter: { selectionType: #RANGE, multipleSelections: true }
      _Base.FPTariffHeading,

      @Consumption.filter: { selectionType: #RANGE, multipleSelections: true }
      _Base.CompTariffHeading,

      _Base.FPTariffChapter,
      _Base.CompTariffChapter,

      @EndUserText.label: 'Tariff Jump at HS Heading'
      case when _Base.FPTariffHeading = _Base.CompTariffHeading
           then cast( '' as abap.char( 1 ) )
           else cast( 'X' as abap.char( 1 ) )
      end                                                   as TariffJumpAtHeading,

      @EndUserText.label: 'Tariff Jump at HS Chapter'
      case when _Base.FPTariffChapter = _Base.CompTariffChapter
           then cast( '' as abap.char( 1 ) )
           else cast( 'X' as abap.char( 1 ) )
      end                                                   as TariffJumpAtChapter,

      _Base.ComponentQuantity,
      _Base.ComponentUoM,
      _Base.BomItemCategory,
      _Base.ValidityStartDate,
      _Base.ValidityEndDate,
      _Base.BomUsage
}
