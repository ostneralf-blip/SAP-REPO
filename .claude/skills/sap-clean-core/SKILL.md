---
name: sap-clean-core
description: SAP Clean Core development skill. Use when the user wants to extend SAP S/4HANA following clean core principles — avoiding modifications to standard SAP code and using only released APIs, approved extensibility options (in-app, side-by-side), ABAP Cloud/Tier model, BAdIs, RAP extensions, key user tools, and SAP BTP integration patterns.
---

# SAP Clean Core Development Skill

Help users extend SAP S/4HANA while keeping the core clean: no modifications to SAP standard objects, only released and stable APIs, upgrade-safe extensibility.

## What Is Clean Core?

Clean core means the SAP standard system remains unmodified and upgradeable. All customer-specific logic lives in:
- **In-app extensibility** — runs inside the S/4HANA system using approved extension points
- **Side-by-side extensibility** — runs on SAP BTP, communicates via APIs and events

The guiding rule: **never modify SAP standard code**. Use only SAP-released APIs (`@AbapCatalog.sqlViewAppend`, released BAdIs, released CDS views, `C1` use-allowed APIs).

---

## Extensibility Tiers (ABAP Cloud Model)

| Tier | Who | What | Allowed dependencies |
|------|-----|------|----------------------|
| **Tier 1** | SAP | SAP standard delivery | Everything |
| **Tier 2** | Partners / ISVs | Add-ons, industry solutions | Released SAP APIs only |
| **Tier 3** | Customers | Customer-specific extensions | Released SAP APIs + Tier 2 APIs |

In ABAP Cloud (S/4HANA Cloud / BTP ABAP), every object has a `@AbapCatalog.releaseState` or `C1` contract. Only use objects with `USE_IN_CLOUD_DEVELOPMENT` or `C1` release state.

---

## Workflow

Make a todo list for all tasks in this workflow and work on them one after another.

### 1. Assess the Extension Need

Before writing any code, classify the requirement:

| Requirement | Recommended approach |
|-------------|----------------------|
| Add custom field to standard form/list | Key User Extensibility (Custom Fields app) |
| Add custom logic at a process step | BAdI / Enhancement Spot |
| Build a new custom app | RAP Business Object + Fiori Elements or side-by-side BTP app |
| Replace standard screen with custom UX | Fiori Elements extension / side-by-side |
| Integrate external system | SAP Integration Suite / BTP event mesh |
| Read standard data in external app | OData / released CDS view via API Business Hub |
| Modify standard SAP code | STOP — find the released BAdI or raise an SAP influence request |

### 2. Check for Released APIs

Always verify an API is released before using it.

**In ADT / ABAP Development Tools:**
- Right-click object → Properties → API State must be `Released` (C1 contract)

**In code — check annotation:**
```cds
@AbapCatalog.sqlViewName: 'I_SALESORDITEM'
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Order Item'
@ObjectModel.usageType.serviceQuality: #A
@ObjectModel.usageType.sizeCategory: #XL
@ObjectModel.usageType.dataClass: #MIXED
-- Released indicator present:
@VDM.viewType: #BASIC
define view I_SalesOrderItem ...
```

**Search released APIs:**
- SAP API Business Hub: `api.sap.com`
- In system: transaction `SPAPI` or search in ADT for `C1` objects

### 3. In-App Extensibility Options

#### 3a. Key User Extensibility (no-code / low-code)
Use SAP Fiori apps — no ABAP required:
- **Custom Fields and Logic** app — add fields to standard business objects
- **Custom Business Objects** app — create standalone custom entities
- **Custom Analytical Queries** — extend embedded analytics
- **Custom Communication Scenarios** — expose APIs to external systems

Custom field naming: always use customer namespace, e.g. `YY1_CUSTOMFIELD_BUS`.

#### 3b. BAdI (Business Add-In) — Developer Extensibility

Find the right BAdI using transaction `BADI_EXPLORER` or ADT, then implement it:

```abap
" BAdI implementation class — always in customer namespace
CLASS zcl_my_badi_impl DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_my_badi.   " Generated interface from BAdI definition

ENDCLASS.

CLASS zcl_my_badi_impl IMPLEMENTATION.

  METHOD zif_my_badi~execute.
    " Only use released APIs here
    " iv_context, es_result passed by BAdI framework
    IF iv_context-category = 'A'.
      es_result-discount = '5'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
```

Register via `SE19` or ADT Enhancement Implementation object.

#### 3c. RAP Business Object Extension

Extend a standard RAP BO using `EXTEND`:

```cds
" Extension CDS view — adds custom fields to standard BO root
extend view entity I_SalesOrder with
{
  _Customer.YY1_CustomSegment_bus as CustomSegment
}
```

```abap
" Extension behavior definition
extension using interface entity I_SalesOrder
  implementation in class zbp_ext_salesorder unique;

extend behavior for I_SalesOrder
{
  field (readonly) CustomSegment;

  determination SetCustomSegment on save { field CustomSegment; }
}
```

```abap
" Extension behavior implementation
CLASS lhc_salesorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS set_custom_segment FOR DETERMINE ON SAVE
      IMPORTING keys FOR I_SalesOrder~SetCustomSegment.
ENDCLASS.

CLASS lhc_salesorder IMPLEMENTATION.
  METHOD set_custom_segment.
    " Use only released APIs
    READ ENTITIES OF I_SalesOrder IN LOCAL MODE
      ENTITY I_SalesOrder
        FIELDS ( SalesOrder CustomSegment )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    MODIFY ENTITIES OF I_SalesOrder IN LOCAL MODE
      ENTITY I_SalesOrder
        UPDATE FIELDS ( CustomSegment )
        WITH VALUE #( FOR ls_order IN lt_orders
          ( %tky          = ls_order-%tky
            CustomSegment = 'PREMIUM' ) ).
  ENDMETHOD.
ENDCLASS.
```

#### 3d. Custom CDS Views on Released Views

Build custom analytical or transactional views only on released (`C1`) CDS views:

```cds
@AbapCatalog.sqlViewName: 'ZV_MY_ORDERS'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'My Custom Order View'
define view Z_MyOrders as select from I_SalesOrder {  -- released view
  key SalesOrder,
      SoldToParty,
      TotalNetAmount,
      YY1_CustomSegment_bus as CustomSegment
} where SalesDocumentType = 'OR'
```

### 4. Side-by-Side Extensibility on SAP BTP

Use side-by-side when:
- The extension requires external services, AI, or complex UI
- The process spans multiple systems
- You want full stack freedom (Node.js, Java, Python)

#### 4a. Consume S/4HANA OData API from BTP

```javascript
// CAP (Cloud Application Programming Model) — srv/my-service.cds
using { API_SALES_ORDER_SRV as external } from '../srv/external/API_SALES_ORDER_SRV.csn';

service MyService {
  entity Orders as projection on external.A_SalesOrder {
    SalesOrder, SoldToParty, TotalNetAmount
  }
}
```

```javascript
// srv/my-service.js — delegate to S/4HANA
const cds = require('@sap/cds');
module.exports = cds.service.impl(async function () {
  const S4 = await cds.connect.to('API_SALES_ORDER_SRV');

  this.on('READ', 'Orders', async (req) => {
    return S4.run(req.query);
  });
});
```

#### 4b. SAP BTP Event Mesh — Consume S/4HANA Business Events

S/4HANA 2022+ emits standard business events (e.g. `sap.s4.beh.salesorder.v1.SalesOrder.Created.v1`).

```javascript
// CAP event handler
this.on('sap.s4.beh.salesorder.v1.SalesOrder.Created.v1', async (msg) => {
  const { SalesOrder } = msg.data;
  // React to the event — call BTP services, update custom data, etc.
  await notifyDownstreamSystem(SalesOrder);
});
```

#### 4c. SAP Integration Suite (for process integration)

- Use **Integration Flow (iFlow)** for system-to-system message routing
- Use **API Management** to expose/secure S/4HANA APIs externally
- Use **Open Connectors** for non-SAP SaaS integrations
- Never build point-to-point integrations that bypass Integration Suite in a clean core landscape

### 5. What to Avoid (Anti-Patterns)

| Anti-pattern | Clean Core alternative |
|---|---|
| Modifying SAP standard programs (`Z` copy of SAP report) | Use BAdI / Enhancement Spot |
| Using unreleased internal SAP function modules | Find released BAPI or OData API |
| Direct SELECT on SAP tables (bypassing CDS/API layer) | Use released CDS views or OData |
| Modifying SAP Customizing tables directly in code | Use released APIs or IMG activities |
| Classic enhancements (`CMOD`/`SMOD`) | Replace with explicit BAdI |
| Hard-coding SAP internal keys/constants | Use released constants / Customizing |
| SAP Screen modifications (screen exits with `.append`) | Fiori app or key user custom fields |

### 6. ABAP Cloud Compliance Check

In ADT, run the **ABAP Cloud** check on your code:
- Right-click package → Run As → ABAP Test → Cloud Readiness Check
- All violations (use of unreleased APIs, forbidden statements) must be resolved before deployment to S/4HANA Cloud or BTP ABAP

Forbidden in ABAP Cloud:
```abap
" NOT allowed in ABAP Cloud / Tier 2-3:
CALL FUNCTION 'UNRELEASED_FM'.          " not C1 released
SELECT * FROM dd02l.                    " direct DDIC table access
CALL TRANSACTION 'SE16'.               " GUI transactions
WRITE: / 'output'.                      " classic list output
```

### 7. Transport & Lifecycle

- Customer extensions go in a **customer package** (Z/Y namespace), never in SAP packages
- Use **software components** on BTP ABAP for side-by-side objects
- Extensions must be regression-tested after every SAP upgrade — clean core minimizes this surface
- Tag extension objects with a custom **extension ID** in the object description for traceability

### 8. Validate Changes

Before committing:
- Run ABAP Cloud Readiness Check (ADT) — zero violations
- Confirm all consumed APIs have `C1` / `Released` state
- Run unit tests for BAdI implementations and RAP extensions
- Verify no direct modifications to SAP standard objects
- Check that custom fields use `YY1_` or customer namespace prefix

### 9. Commit and Push

```
feat(ZBADI_PRICING_IMPL): add volume discount via released pricing BAdI

- Implement IF_EX_PRICING_BADI~CALCULATE_DISCOUNT using released API
- Add LTCL_PRICING unit tests for discount tiers
- No unreleased API usage — ABAP Cloud check passes
```

## Wrap Up

Provide a summary including:
- Extensibility approach used (BAdI, RAP extension, key user, side-by-side)
- Released APIs consumed (with C1/release state confirmed)
- ABAP Cloud Readiness Check result
- Anti-patterns avoided and clean core compliance status
- Transport or deployment steps needed
- Upgrade safety assessment: will this extension survive an SAP upgrade without rework?
