@AbapCatalog.sqlViewName: 'ZVTARIFFJMPB2'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Tariff Jump Base View V2'

/*
  Base view for tariff jump analysis.
  Joins BOM items with material master and trade data to expose
  commodity codes and derived tariff headings/chapters for both
  the finished product and its components.

  NOTE: Includes all BOM alternatives (STLAL). If only one alternative
  is required, add a WHERE condition on BomAlternative or join via MAST.
  Validity date filtering is the consumer's responsibility – use
  $parameters.KeyDate or a WHERE clause on ValidityStartDate/ValidityEndDate.
*/

define view Z_I_TariffJumpBase_V2
  as select from stpo as BomItem
    inner join stko as BomHeader
      on  BomHeader.stlnr = BomItem.stlnr
      and BomHeader.stlal = BomItem.stlal
      and BomHeader.stlty = 'M'                   -- Material BOM only

    inner join mara as FPMaterial
      on FPMaterial.matnr = BomHeader.matnr

    inner join mara as CompMaterial
      on CompMaterial.matnr = BomItem.idnrk

    left outer join marc as FPMarc
      on  FPMarc.matnr = BomHeader.matnr
      and FPMarc.werks = BomHeader.werks

    left outer join marc as CompMarc
      on  CompMarc.matnr = BomItem.idnrk
      and CompMarc.werks = BomHeader.werks

    left outer join makt as FPDesc
      on  FPDesc.matnr  = BomHeader.matnr
      and FPDesc.spras  = $session.system_language

    left outer join makt as CompDesc
      on  CompDesc.matnr = BomItem.idnrk
      and CompDesc.spras = $session.system_language

{
  key BomHeader.matnr                          as FinishedProduct,
  key BomHeader.werks                          as Plant,
  key BomItem.stlnr                            as BomNumber,
  key BomItem.posnr                            as BomItemNodeNumber,

      BomHeader.stlal                          as BomAlternative,
      BomItem.posnr                            as BomItemNumber,
      BomItem.idnrk                            as ComponentMaterial,

      FPDesc.maktx                             as FinishedProductDescription,
      CompDesc.maktx                           as ComponentDescription,

      FPMaterial.mtart                         as FinishedProductType,
      CompMaterial.mtart                       as ComponentMaterialType,

      FPMaterial.matkl                         as FinishedProductMaterialGroup,
      CompMaterial.matkl                       as ComponentMaterialGroup,

      FPMarc.steuc                             as FinishedProductCommodityCode,
      CompMarc.steuc                           as ComponentCommodityCode,

      -- Tariff heading = first 4 characters of the commodity code (HS heading)
      substring( FPMarc.steuc,   1, 4 )        as FPTariffHeading,
      substring( CompMarc.steuc, 1, 4 )        as CompTariffHeading,

      -- Tariff chapter = first 2 characters of the commodity code (HS chapter)
      substring( FPMarc.steuc,   1, 2 )        as FPTariffChapter,
      substring( CompMarc.steuc, 1, 2 )        as CompTariffChapter,

      BomItem.menge                            as ComponentQuantity,
      BomItem.meins                            as ComponentUoM,
      BomItem.postp                            as BomItemCategory,
      BomItem.datuv                            as ValidityStartDate,
      BomItem.datub                            as ValidityEndDate,
      BomHeader.stlan                          as BomUsage
}
