%dw 2.0
output application/java
// REALS lead -> Salesforce standard Lead (spec section 9).
// LastName and Company are mandatory on the standard Lead.
// Property-of-interest fields (pages 9-10) are carried as custom fields
// (illustrative API names) with a Description fallback summarising the key fields.
---
{
    LastName:   payload.customer.lastName  default "Unknown",
    FirstName:  payload.customer.firstName,
    Email:      payload.customer.email,
    Phone:      payload.customer.phone,
    Company:    payload.customer.company   default "REALS Prospect",
    LeadSource: p('api.leadSource')        default "REALS",

    // Property of interest (pages 9-10). Custom field API names illustrative.
    Apartment_Id__c:       payload.property.apartmentId,
    Project_Name__c:       payload.property.projectName,
    Area_Sqm__c:           payload.property.areaSqm,
    Floor__c:              payload.property.floor,
    Apartment_Type__c:     payload.property.'type',
    Apartment_Area_Sqm__c: payload.property.apartmentArea,
    Balcony_Area_Sqm__c:   payload.property.balconyArea,
    Rooms__c:              payload.property.rooms,
    Air_Directions__c:     payload.property.airDirections,
    Sale_Status__c:        payload.property.saleStatus,
    Has_Storage__c:        payload.property.storage,
    Has_Parking__c:        payload.property.parking,

    Description: "Property of interest: " ++ (payload.property.apartmentId default "")
                 ++ " | Project: " ++ (payload.property.projectName default "")
}
