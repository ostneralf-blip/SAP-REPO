@AbapCatalog.sqlViewName: 'ZVTARIFFBASE2'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Tariff Jump Base V2 (with I_BillOfMaterialItem)'

/*
  Base view for tariff jump analysis – clean-core variant.
  Relies on released CDS views (I_BillOfMaterialItem, I_Mast,
  I_Product, I_ProductDescription) and falls back to the non-released
  MARC table only for the commodity code (STAWN), which has no
  equivalent released CDS API in standard S/4HANA 2023.

  Design notes
  ────────────
  • Filtered to BOM usage '1' (production) and item category 'L' (stock item).
  • Language for descriptions is hardcoded to 'E'. Change to
    $session.system_language for multi-language deployments.
  • The BOM/MAST join is on BillOfMaterial + BillOfMaterialCategory only;
    BillOfMaterialVariant is not part of the join, so BOMs with multiple
    variants within usage '1' will produce duplicate rows. Add the variant
    to the key or add a WHERE clause if that is a concern in your data.
  • _FPText is an inner join: finished products without an English
    description are excluded. Consider changing to left outer join if
    completeness is more important than text availability.
*/

define view Z_I_TariffJumpBase_V2
  as select from I_BillOfMaterialItem as _BomItem

    -- BoM Header: Material + Plant
    inner join   I_Mast as _BomLink
      on  _BomLink.BillOfMaterial         = _BomItem.BillOfMaterial
      and _BomLink.BillOfMaterialCategory = _BomItem.BillOfMaterialCategory

    -- Finished Product: General data + Material Group
    inner join   I_Product as _FPMaster
      on  _FPMaster.Product = _BomLink.Material

    -- Finished Product: Description (inner join – see note above)
    inner join   I_ProductDescription as _FPText
      on  _FPText.Product  = _BomLink.Material
      and _FPText.Language = 'E'

    -- Finished Product: Plant data (Commodity Code via MARC.STAWN)
    inner join   marc as _FPPlant
      on  _FPPlant.matnr = _BomLink.Material
      and _FPPlant.werks = _BomLink.Plant

    -- Component: General data + Material Group
    inner join   I_Product as _CompMaster
      on  _CompMaster.Product = _BomItem.BillOfMaterialComponent

    -- Component: Description (left outer – component may lack a description)
    left outer join I_ProductDescription as _CompText
      on  _CompText.Product  = _BomItem.BillOfMaterialComponent
      and _CompText.Language = 'E'

    -- Component: Plant data (Commodity Code via MARC.STAWN)
    inner join   marc as _CompPlant
      on  _CompPlant.matnr = _BomItem.BillOfMaterialComponent
      and _CompPlant.werks = _BomLink.Plant

{
  key _BomLink.Material                                      as FinishedProduct,
  key _BomLink.Plant                                         as Plant,
  key _BomItem.BillOfMaterial                                as BomNumber,
  key _BomItem.BillOfMaterialItemNodeNumber                  as BomItemNodeNumber,
      _BomItem.BillOfMaterialItemNumber                      as BomItemNumber,
      _BomItem.BillOfMaterialComponent                       as ComponentMaterial,

      _FPText.ProductDescription                             as FinishedProductDescription,
      _CompText.ProductDescription                           as ComponentDescription,
      _FPMaster.ProductType                                  as FinishedProductType,
      _CompMaster.ProductType                                as ComponentMaterialType,

      -- Material Groups
      _FPMaster.ProductGroup                                 as FinishedProductMaterialGroup,
      _CompMaster.ProductGroup                               as ComponentMaterialGroup,

      -- Commodity Codes (MARC.STAWN – intrastat/HS commodity code, CHAR 9)
      _FPPlant.stawn                                         as FinishedProductCommodityCode,
      _CompPlant.stawn                                       as ComponentCommodityCode,

      -- Tariff Heading (first 4 chars) / Chapter (first 2 chars)
      substring( _FPPlant.stawn,   1, 4 )                    as FPTariffHeading,
      substring( _CompPlant.stawn, 1, 4 )                    as CompTariffHeading,
      substring( _FPPlant.stawn,   1, 2 )                    as FPTariffChapter,
      substring( _CompPlant.stawn, 1, 2 )                    as CompTariffChapter,

      -- BoM Item Details
      _BomItem.BillOfMaterialItemQuantity                    as ComponentQuantity,
      _BomItem.BillOfMaterialItemUnit                        as ComponentUoM,
      _BomItem.BillOfMaterialItemCategory                    as BomItemCategory,

      -- Validity
      _BomItem.ValidityStartDate                             as ValidityStartDate,
      _BomItem.ValidityEndDate                               as ValidityEndDate,

      -- BoM Meta
      _BomLink.BillOfMaterialVariantUsage                    as BomUsage
}
where
      _BomLink.BillOfMaterialVariantUsage = '1'
  and _BomItem.BillOfMaterialItemCategory = 'L'
