%dw 2.0
output application/json
// Map the Salesforce create result to the API response body (spec section 9).
---
{
    salesforceLeadId: payload.id,
    status: if (payload.success == true) "CREATED" else "FAILED"
}
