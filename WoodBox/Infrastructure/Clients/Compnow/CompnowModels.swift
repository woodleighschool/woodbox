import Foundation

// MARK: Create Ticket

/// Request
struct CompnowTicketCreateRequest: Encodable {
  let product: String
  let serial: String
  let firstName: String
  let lastName: String
  let address1: String
  let suburb: String
  let state: String
  let postcode: String
  let email: String
  let phone: String
  let stockCode: String?
  let extras: String?
  let fault: String?
  let condition: String?
  let reference: String?
}

/// Response
struct CompnowTicketCreateResponse: Decodable {
  let message: String
  let ticket: CompnowTicket
}

struct CompnowTicket: Decodable {
  let ticketId: String
}
