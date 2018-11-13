class CanonicalAddress < ApplicationRecord
  include ReadWriteIdentity
  class << self
    def search(address = {})
      return nil unless address.present?

      address_string = [address[:line1], address[:line2], address[:town], address[:state], address[:postcode], address[:country]].join(', ').upcase

      query = CanonicalAddress
              .where('search_text % ?', address_string)
              .order("similarity(search_text, #{ApplicationRecord.connection.quote(address_string)}) DESC")
              .select("*, similarity(search_text, #{ApplicationRecord.connection.quote(address_string)}) as similarity")

      if address[:postcode]
        query = query.where(postcode: address[:postcode].to_s.upcase.delete(' '))
      end

      return nil unless ca = query.first
      return ca if ca.similarity > 0.7
    end
  end
end
