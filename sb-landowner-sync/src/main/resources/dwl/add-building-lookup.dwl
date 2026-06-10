%dw 2.0
output application/java
// Conditional Building lookup (spec 9.2).
// For each flat LandOwner__c record:
//   * if BuildingCode__c is present -> add Building__r external-id relationship
//     and keep BuildingCode__c on the record;
//   * otherwise -> remove the (null) BuildingCode__c key, record stands at
//     project level only.
---
(payload default []) map ((rec) ->
    if (rec.BuildingCode__c != null and rec.BuildingCode__c != "")
        rec ++ { Building__r: { BuildingCode__c: rec.BuildingCode__c } }
    else
        rec - "BuildingCode__c"
)
