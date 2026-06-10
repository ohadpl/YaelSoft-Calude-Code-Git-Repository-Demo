%dw 2.0
output application/java
// Input: payload = OData response for /registrations (one page already merged
//        into a single { value: [...] } shape upstream, or the raw page).
// Projects each registration record to the slim shape used by the batch.
// Null-safe throughout - Rainbow data is not always consistent.
---
(payload.value default []) map ((reg) -> {
    registrationKey: reg.registrationKey,
    buildingCode:    reg.buildingCode,
    propertyKey:     reg.propertyKey,
    projectCode:     reg.project_code,
    rightType:       reg.righttype,
    plot:            reg.plot
})
