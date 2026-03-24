---
name: sap-fiori-dev
description: SAP Fiori / UI5 development skill. Use when the user wants to build, extend, or debug SAP Fiori applications using SAPUI5 or OpenUI5, including Fiori Elements, freestyle UI5 apps, OData service consumption, manifest configuration, and deployment to SAP BTP or on-premise ABAP frontend server.
---

# SAP Fiori / UI5 Development Skill

Help users build and maintain SAP Fiori applications using SAPUI5/OpenUI5. Covers freestyle UI5, Fiori Elements (V2/V4), OData consumption, BTP deployment, and SAP Business Application Studio (BAS) workflows.

## Workflow

Make a todo list for all the tasks in this workflow and work on them one after another.

### 1. Understand the Context

Before writing or modifying UI5 code:
- Check `manifest.json` for app ID, data sources, models, and routing config
- Identify UI5 version (check `minUI5Version` in `manifest.json` or `neo-app.json`)
- Determine app type: Fiori Elements (List Report, Object Page, etc.) or freestyle UI5
- Check OData version: V2 (`sap.ui.model.odata.v2.ODataModel`) or V4 (`sap.ui.model.odata.v4.ODataModel`)
- Check deployment target: SAP BTP (MTA), ABAP frontend server (abap-deploy), or local

### 2. Project Structure

Standard UI5 app layout:
```
webapp/
  controller/
    App.controller.js       (or .ts)
    Main.controller.js
  view/
    App.view.xml
    Main.view.xml
  model/
    models.js               " Model factory
  i18n/
    i18n.properties         " Default language
    i18n_de.properties      " German translations
  localService/
    mockdata/               " JSON mock files
    metadata.xml            " OData metadata mock
    mockserver.js
  test/
    unit/
    integration/
  Component.js              " App component
  manifest.json             " App descriptor
index.html                  " Local dev entry point
ui5.yaml                    " UI5 tooling config
package.json
```

### 3. Coding Standards

**General:**
- Use `sap.ui.define` / `sap.ui.require` module system; never use globals
- Prefer TypeScript (`.ts`) for new projects when the team supports it
- Follow MVC pattern strictly: logic in controllers, layout in views, data in models
- Never manipulate the DOM directly; use UI5 controls and data binding
- Use `i18n` model for all user-facing strings — no hardcoded strings in views or controllers

**Controllers:**
```javascript
sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/model/json/JSONModel",
    "sap/m/MessageToast"
], function (Controller, JSONModel, MessageToast) {
    "use strict";

    return Controller.extend("com.mycompany.myapp.controller.Main", {

        onInit: function () {
            const oModel = new JSONModel({ busy: false });
            this.getView().setModel(oModel, "view");
        },

        onPress: function (oEvent) {
            const oSource = oEvent.getSource();
            MessageToast.show("Pressed: " + oSource.getText());
        }

    });
});
```

**Views (XML preferred):**
```xml
<mvc:View
    controllerName="com.mycompany.myapp.controller.Main"
    xmlns:mvc="sap.ui.core.mvc"
    xmlns="sap.m"
    displayBlock="true">

    <Page title="{i18n>pageTitle}" busy="{view>/busy}">
        <content>
            <List items="{/Items}">
                <StandardListItem
                    title="{Name}"
                    description="{Description}"
                    press=".onItemPress"/>
            </List>
        </content>
    </Page>

</mvc:View>
```

**OData V4 read example:**
```javascript
const oList = this.byId("myList");
const oBinding = oList.getBinding("items");
oBinding.filter([
    new Filter("Category", FilterOperator.EQ, "Electronics")
]);
```

### 4. manifest.json Key Sections

```json
{
  "sap.app": {
    "id": "com.mycompany.myapp",
    "type": "application",
    "title": "{{appTitle}}",
    "description": "{{appDescription}}",
    "applicationVersion": { "version": "1.0.0" },
    "dataSources": {
      "mainService": {
        "uri": "/sap/opu/odata/sap/MY_SERVICE_SRV/",
        "type": "OData",
        "settings": { "odataVersion": "2.0" }
      }
    }
  },
  "sap.ui5": {
    "rootView": {
      "viewName": "com.mycompany.myapp.view.App",
      "type": "XML",
      "async": true,
      "id": "app"
    },
    "routing": {
      "config": {
        "routerClass": "sap.m.routing.Router",
        "viewType": "XML",
        "viewPath": "com.mycompany.myapp.view",
        "controlId": "app",
        "controlAggregation": "pages",
        "async": true
      },
      "routes": [
        {
          "name": "RouteMain",
          "pattern": "",
          "target": "TargetMain"
        }
      ],
      "targets": {
        "TargetMain": { "viewName": "Main" }
      }
    },
    "models": {
      "": {
        "dataSource": "mainService",
        "settings": { "defaultBindingMode": "TwoWay" }
      },
      "i18n": {
        "type": "sap.ui.model.resource.ResourceModel",
        "settings": { "bundleName": "com.mycompany.myapp.i18n.i18n" }
      }
    }
  }
}
```

### 5. Fiori Elements

For Fiori Elements apps, configuration lives in `manifest.json` under `"sap.ui.generic.app"` (V2) or annotations (V4).

**List Report + Object Page (V4 annotations):**
```cds
annotate service.Products with @(
  UI.LineItem: [
    { Value: ProductID, Label: 'ID' },
    { Value: ProductName, Label: 'Name' },
    { Value: Category }
  ],
  UI.SelectionFields: [ Category, Supplier ],
  UI.HeaderInfo: {
    TypeName: 'Product',
    TypeNamePlural: 'Products',
    Title: { Value: ProductName }
  }
);
```

### 6. UI5 Tooling & Local Dev

```bash
# Install UI5 tooling globally
npm install -g @ui5/cli

# Start local dev server with mock data
ui5 serve --open index.html

# Run with real backend (proxy configured in ui5.yaml)
ui5 serve

# Build for deployment
ui5 build --all
```

`ui5.yaml` proxy example for local dev:
```yaml
specVersion: '3.0'
metadata:
  name: com.mycompany.myapp
type: application
server:
  customMiddleware:
    - name: ui5-middleware-simpleproxy
      mountPath: /sap
      configuration:
        baseUri: https://my-sap-system.example.com
```

### 7. Deployment

**To ABAP frontend server (SAP Fiori Launchpad):**
```bash
npm install -g @sap/ux-ui5-tooling
# Configure in ui5-deploy.yaml, then:
npm run deploy
```

**To SAP BTP via MTA:**
```bash
mbt build
cf deploy mta_archives/myapp_1.0.0.mtar
```

### 8. Testing

**Unit tests (QUnit):**
```javascript
QUnit.test("formatAmount should return currency string", function (assert) {
    const oFormatter = new AmountFormatter();
    assert.strictEqual(oFormatter.formatAmount(1000, "EUR"), "EUR 1,000.00");
});
```

**Integration / OPA5 tests:**
```javascript
opaTest("Should navigate to detail page", function (Given, When, Then) {
    Given.iStartMyApp();
    When.onTheListPage.iPressOnFirstItem();
    Then.onTheDetailPage.iShouldSeeTheDetailPanel();
});
```

Run tests:
```bash
ui5 serve --open test/unit/unitTests.qunit.html
ui5 serve --open test/integration/opaTests.qunit.html
```

### 9. Validate Changes

Before committing:
- Run `ui5 build` and confirm it completes without errors
- Run unit tests and confirm all pass
- Verify i18n keys exist in `i18n.properties` for any new strings
- Check `manifest.json` is valid JSON
- Confirm routing targets match view names

### 10. Commit and Push

Use meaningful commit messages:
```
feat(MainController): add filter by category on List page

- Add onCategoryFilter handler
- Bind FilterBar to OData V4 list binding
- Add i18n keys for filter labels
- Add QUnit test for filter logic
```

## Wrap Up

Provide a summary including:
- Views, controllers, and models created or modified
- OData services consumed and binding paths used
- i18n keys added
- Test results (unit / OPA5)
- Deployment steps needed (abap-deploy, MTA build/deploy)
- Any SAP Fiori Launchpad tile config required
